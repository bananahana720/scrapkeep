import {
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmdirSync,
  rmSync,
  statSync,
  unlinkSync,
  utimesSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { processId, processLive } from "./proc.mjs";

function slotRoot() {
  return path.join(process.env.SCRAPKEEP_LOCK_DIR || "/tmp", "scrapkeep-sketch-smoke.slots");
}

export function machineSlotCount(env = process.env) {
  const slots = Number(env.SMOKE_SLOTS ?? 2);
  if (!Number.isSafeInteger(slots) || slots < 1)
    throw new Error("SMOKE_SLOTS must be a positive integer");
  return slots;
}

export const HEARTBEAT_MS = 15_000;
export const STALE_CLAIM_MS = 90_000;

function slotOwner(slot) {
  try {
    const owner = readdirSync(slot).find((name) => name.startsWith("claim-"));
    if (!owner) return null;
    const live = processLive(readFileSync(path.join(slot, owner), "utf8"));
    if (live === null) throw new Error(`invalid slot pid in ${slot}`);
    if (!live) return { owner, alive: false };
    const age = Date.now() - statSync(path.join(slot, owner)).mtimeMs;
    return { owner, alive: age < STALE_CLAIM_MS };
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

function releaseSlot(slot, owner) {
  try {
    unlinkSync(path.join(slot, owner));
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  try {
    rmdirSync(slot);
  } catch (error) {
    if (!["ENOENT", "ENOTEMPTY", "EEXIST"].includes(error.code)) throw error;
  }
}

function touch(target) {
  const now = new Date();
  try {
    utimesSync(target, now, now);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
}

function sweepStaleWaiters(directory, own) {
  for (const name of readdirSync(directory)) {
    if (!name.startsWith("claim-") || name === own) continue;
    const dir = path.join(directory, name);
    try {
      if (Date.now() - statSync(dir).mtimeMs < STALE_CLAIM_MS) continue;
      releaseSlot(dir, name);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  }
}

export const QUIET_HOLD = "scrapkeep-quiet-hold";
export const QUIET_MAX_MS = 2 * 60 * 60 * 1000;
const QUIET_LOCK_STALE_MS = 60 * 1000;

function quietRoot() {
  return process.env.SCRAPKEEP_QUIET_DIR || "/tmp";
}

export function quietHolder(directory = quietRoot()) {
  const file = path.join(directory, QUIET_HOLD);
  try {
    const pid = processId(readFileSync(file, "utf8"));
    if (pid === null) return null;
    if (Date.now() - statSync(file).mtimeMs > QUIET_MAX_MS) return null;
    return processLive(pid) ? pid : null;
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

export function holdQuietSync({
  directory = slotRoot(),
  quietDirectory = quietRoot(),
  pollMs = 2000,
  timeoutMs = 45 * 60 * 1000,
  pid = process.pid,
  log = console.log,
  sleepSync = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms),
} = {}) {
  mkdirSync(directory, { recursive: true });
  mkdirSync(quietDirectory, { recursive: true });
  const file = path.join(quietDirectory, QUIET_HOLD);
  const lock = file + ".lock";
  const started = Date.now();
  const late = () => Date.now() - started > timeoutMs;
  const release = () => {
    try {
      if (processId(readFileSync(file, "utf8")) === pid) unlinkSync(file);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  };
  const claim = () => {
    for (;;) {
      try {
        mkdirSync(lock);
        break;
      } catch (error) {
        if (error.code !== "EEXIST") throw error;
        if (late())
          throw new Error(`the quiet hold's lock (${lock}) is stuck; no frame reading taken`);
        try {
          if (Math.abs(Date.now() - statSync(lock).mtimeMs) > QUIET_LOCK_STALE_MS)
            rmSync(lock, { recursive: true, force: true });
        } catch (gone) {
          if (gone.code !== "ENOENT") throw gone;
        }
        sleepSync(20);
      }
    }
    try {
      const other = quietHolder(quietDirectory);
      if (other !== null) return other;
      writeFileSync(file, String(pid));
      return pid;
    } finally {
      rmSync(lock, { recursive: true, force: true });
    }
  };
  for (;;) {
    let told = false;
    for (;;) {
      const other = claim();
      if (other === pid) break;
      if (late())
        throw new Error(
          `another frame reading (pid ${other}) still holds the machine after ${Math.round(timeoutMs / 60000)} min; no frame reading taken`,
        );
      if (!told)
        log(`waiting: another frame reading (pid ${other}) holds the machine quiet (${file})`);
      told = true;
      sleepSync(pollMs);
    }
    told = false;
    let lost = false;
    for (;;) {
      const busy = readdirSync(directory).filter(
        (name) => name.startsWith("slot-") && slotOwner(path.join(directory, name))?.alive,
      );
      if (quietHolder(quietDirectory) !== pid) {
        lost = true;
        break;
      }
      if (busy.length === 0) break;
      if (late()) {
        release();
        throw new Error(
          `${busy.length} test runner(s) still hold the machine after ${Math.round(timeoutMs / 60000)} min; no frame reading taken`,
        );
      }
      if (!told)
        log(`waiting for ${busy.length} test runner(s) to finish before the frame reading starts`);
      told = true;
      sleepSync(pollMs);
    }
    if (!lost) break;
  }
  touch(file);
  return { waitMs: Date.now() - started, release };
}

export async function acquireSlot({
  directory = slotRoot(),
  slots = machineSlotCount(),
  pollMs = 2000,
  heartbeatMs = HEARTBEAT_MS,
  sleep = (ms) => new Promise((r) => setTimeout(r, ms)),
  log = console.log,
  quietDirectory = quietRoot(),
  beforePublish = () => {},
} = {}) {
  if (!Number.isSafeInteger(slots) || slots < 1)
    throw new Error("slots must be a positive integer");
  mkdirSync(directory, { recursive: true });
  const started = Date.now();
  const claim = mkdtempSync(path.join(directory, `claim-${process.pid}-`));
  const owner = path.basename(claim);
  let told = false;
  let toldQuiet = false;
  const quietWait = async () => {
    const holder = quietHolder(quietDirectory);
    if (holder === null) return false;
    if (!toldQuiet)
      log(
        `sketch:smoke waiting: a frame reading (pid ${holder}) holds the machine quiet (${path.join(quietDirectory, QUIET_HOLD)})`,
      );
    toldQuiet = true;
    await sleep(pollMs);
    return true;
  };
  try {
    writeFileSync(path.join(claim, owner), String(process.pid));
    for (;;) {
      sweepStaleWaiters(directory, owner);
      touch(claim);
      if (await quietWait()) continue;
      for (let index = 0; index < slots; index++) {
        const slot = path.join(directory, `slot-${index}`);
        const holder = slotOwner(slot);
        if (holder && !holder.alive) releaseSlot(slot, holder.owner);
        try {
          beforePublish();
          touch(path.join(claim, owner));
          renameSync(claim, slot);
          if (quietHolder(quietDirectory) !== null) {
            releaseSlot(slot, owner);
            mkdirSync(claim, { recursive: true });
            writeFileSync(path.join(claim, owner), String(process.pid));
            break;
          }
          let released = false;
          const claimFile = path.join(slot, owner);
          const beat = setInterval(() => touch(claimFile), heartbeatMs);
          beat.unref();
          return {
            slot,
            waitMs: Date.now() - started,
            release: () => {
              if (released) return;
              clearInterval(beat);
              releaseSlot(slot, owner);
              released = true;
            },
          };
        } catch (error) {
          if (!["EEXIST", "ENOTEMPTY"].includes(error.code)) throw error;
        }
      }
      if (quietHolder(quietDirectory) !== null) continue;
      if (!told) log(`sketch:smoke waiting for a machine slot (${slots} occupied)`);
      told = true;
      await sleep(pollMs);
    }
  } finally {
    rmSync(claim, { recursive: true, force: true });
  }
}

export async function acquireMachine(pollMs = 2000) {
  const lease = await acquireSlot({ pollMs });
  process.once("exit", lease.release);
  return lease.waitMs;
}
