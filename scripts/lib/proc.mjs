import { spawn, spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";

export function killGroup(child, signal = "SIGKILL") {
  if (!child) return;
  if (process.platform !== "win32" && Number.isInteger(child.pid) && child.pid > 0) {
    try {
      process.kill(-child.pid, signal);
      return;
    } catch {}
  }
  try {
    child.kill(signal);
  } catch {}
}

export function groupLive(pgid) {
  if (!Number.isInteger(pgid) || pgid <= 0) return false;
  try {
    process.kill(-pgid, 0);
  } catch (error) {
    if (error.code === "ESRCH") return false;
  }
  const ps = spawnSync("ps", ["-e", "-o", "pgid=,state="], { encoding: "utf8" });
  if (ps.status !== 0) return true;
  return (ps.stdout || "").split("\n").some((line) => {
    const parts = line.trim().split(/\s+/);
    return Number(parts[0]) === pgid && Boolean(parts[1]) && !parts[1].startsWith("Z");
  });
}

export function waitGroupDead(pgid, budgetMs = 1500) {
  return new Promise((resolve) => {
    const deadline = Date.now() + budgetMs;
    const poll = () => {
      if (!groupLive(pgid) || Date.now() >= deadline) return resolve();
      setTimeout(poll, 15);
    };
    poll();
  });
}

export function stopGroup(child, { graceMs = 2000, waitBudgetMs = 1500 } = {}) {
  const pgid = child?.pid;
  if (!pgid) return Promise.resolve();
  if (process.platform === "win32") {
    try {
      child.kill("SIGKILL");
    } catch {}
    return Promise.resolve();
  }
  return new Promise((resolve) => {
    const send = (sig) => killGroup(child, sig);
    const finishKill = () => {
      send("SIGKILL");
      waitGroupDead(pgid, waitBudgetMs).then(resolve);
    };
    if (graceMs <= 0 || child.exitCode !== null || child.signalCode !== null) {
      return finishKill();
    }
    const force = setTimeout(() => send("SIGKILL"), graceMs);
    force.unref?.();
    child.once("exit", () => {
      clearTimeout(force);
      finishKill();
    });
    send("SIGTERM");
  });
}

export function runProcess(
  command,
  args = [],
  {
    cwd,
    env,
    timeoutMs,
    killGraceMs = 0,
    signal,
    logFile,
    binaryOutput = false,
    stdio = ["ignore", "pipe", "pipe"],
    onChild,
    reapGroup = true,
    reapOnClose = false,
    exitDrainMs = 0,
    forwardSignals = false,
  } = {},
) {
  signal?.throwIfAborted();
  return new Promise((resolve) => {
    const started = Date.now();
    const detached = Boolean(reapGroup && process.platform !== "win32");
    let child;
    let interrupted;
    const onSignal = (sig) => {
      interrupted = sig === "SIGINT" ? 130 : 143;
      process.exitCode = interrupted;
      terminate(true);
    };
    const forward = (listen) => {
      if (!forwardSignals) return;
      for (const sig of ["SIGINT", "SIGTERM"]) {
        if (listen) process.on(sig, onSignal);
        else process.off(sig, onSignal);
      }
    };
    forward(true);
    try {
      child = spawn(command, args, { cwd, env, stdio, detached });
    } catch (error) {
      forward(false);
      const msg = String(error?.message ?? error);
      resolve({
        pid: null,
        exit: null,
        signal: null,
        stdout: "",
        stderr: msg,
        output: msg,
        timedOut: false,
        aborted: false,
        interrupted: undefined,
        error,
        ms: Date.now() - started,
      });
      return;
    }

    onChild?.(child);

    let stdout = "";
    let stderr = "";
    let output = "";
    const chunksOut = [];
    let timedOut = false;
    let aborted = false;
    let stopping = null;
    let killTimer = null;
    let drainTimer = null;
    let done = false;

    const sendSig = (sig) => {
      if (detached) killGroup(child, sig);
      else {
        try {
          child.kill(sig);
        } catch {}
      }
    };

    const terminate = (forceImmediate) => {
      if (reapOnClose) {
        stopping ??= stopGroup(child, { graceMs: forceImmediate ? 0 : killGraceMs });
        return;
      }
      if (forceImmediate || killGraceMs <= 0) {
        sendSig("SIGKILL");
        return;
      }
      sendSig("SIGTERM");
      if (!killTimer) {
        killTimer = setTimeout(() => sendSig("SIGKILL"), killGraceMs);
        killTimer.unref?.();
      }
    };

    const onAbort = () => {
      aborted = true;
      terminate(true);
    };
    signal?.addEventListener("abort", onAbort, { once: true });

    if (child.stdout) {
      if (binaryOutput) {
        child.stdout.on("data", (chunk) => chunksOut.push(Buffer.from(chunk)));
      } else {
        child.stdout.setEncoding("utf8");
        child.stdout.on("data", (chunk) => {
          stdout += chunk;
          output += chunk;
        });
      }
    }
    if (child.stderr) {
      if (binaryOutput) {
        child.stderr.on("data", (chunk) => chunksOut.push(Buffer.from(chunk)));
      } else {
        child.stderr.setEncoding("utf8");
        child.stderr.on("data", (chunk) => {
          stderr += chunk;
          output += chunk;
        });
      }
    }

    const timer =
      Number.isFinite(timeoutMs) && timeoutMs > 0
        ? setTimeout(() => {
            timedOut = true;
            terminate(false);
          }, timeoutMs)
        : null;

    const finish = async (exit, sig, error) => {
      if (done) return;
      done = true;
      if (timer) clearTimeout(timer);
      if (killTimer) clearTimeout(killTimer);
      if (drainTimer) clearTimeout(drainTimer);
      forward(false);
      signal?.removeEventListener("abort", onAbort);
      if (reapOnClose && !error) {
        if (stopping) await stopping;
        else if (child.pid) await stopGroup(child, { graceMs: killGraceMs });
        child.stdout?.destroy();
        child.stderr?.destroy();
      }
      if (logFile) {
        writeFileSync(logFile, binaryOutput ? Buffer.concat(chunksOut) : output);
      }
      resolve({
        pid: child.pid ?? null,
        exit,
        signal: sig ?? null,
        stdout,
        stderr,
        output,
        timedOut,
        aborted,
        interrupted,
        error,
        ms: Date.now() - started,
      });
    };

    child.on("error", (error) => {
      finish(null, null, error);
    });
    child.on("close", (code, sig) => {
      finish(code, sig, null);
    });
    if (exitDrainMs > 0) {
      child.on("exit", (code, sig) => {
        drainTimer = setTimeout(() => finish(code, sig, null), exitDrainMs);
        drainTimer.unref?.();
      });
    }
  });
}

export async function pool(tasks, width, { onDone } = {}) {
  const results = new Array(tasks.length);
  if (tasks.length === 0) return results;
  let next = 0;
  const slots = Math.max(1, Math.min(width, tasks.length));
  await Promise.all(
    Array.from({ length: slots }, async () => {
      while (next < tasks.length) {
        const index = next++;
        results[index] = await tasks[index]();
        if (onDone) onDone(results[index], index);
      }
    }),
  );
  return results;
}
