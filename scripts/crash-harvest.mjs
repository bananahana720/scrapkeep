import { mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { isMain } from "./lib/cli.mjs";
import { walkSync } from "./lib/walk.mjs";

export const SEVERITIES = ["blocker", "major", "minor", "watch"];
const LOG_FILE = /(^log$|\.(txt|log|out|err)$)/i;
const MAX_BYTES = 256 * 1024 * 1024;
const ANSI = /\x1b\[[0-9;]*m/g;
const HEADER = /^\s*(SCRIPT ERROR|USER SCRIPT ERROR|ERROR|USER ERROR|WARNING|USER WARNING): (.*)$/;
const AT = /^\s*at: (.*?) \((.+?:\d+)\)\s*$/;
const FRAME = /^\s*\[\d+\] (.*?) \((res:\/\/.+?:\d+)\)\s*$/;
const CRASH = /Program crashed with signal (\d+)/;
const NATIVE_FRAME = /^\s*\[\d+\] \S+ \(([^)+]+\+[0-9a-f]+)\)/;
const SAMPLE_LINES = 12;

export function normalize(message) {
  return message
    .replace(/(res:\/\/[^\s'"]+)|0x[0-9a-f]+|\d+(\.\d+)?/gi, (m, res) => res ?? "#")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 200);
}

export function parseLog(text) {
  const lines = (text ?? "").replace(ANSI, "").split("\n");
  const events = [];
  let open = null;
  let lastError = null;
  let closedAt = -1;
  const close = (i) => {
    if (open) {
      events.push(open);
      closedAt = i;
    }
    open = null;
  };
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const last = events.at(-1);
    if (
      !open &&
      last &&
      last.kind !== "crash" &&
      i - closedAt <= 1 &&
      (AT.test(line) || FRAME.test(line))
    )
      open = events.pop();
    const crash = line.match(CRASH);
    if (crash) {
      close(i);
      open = {
        kind: "crash",
        message: `Program crashed with signal ${crash[1]}`,
        cause: lastError && i - lastError.end <= 3 ? lastError.message : null,
        at: null,
        frames: [],
        native: [],
        line: i + 1,
        sample: [line],
      };
      continue;
    }
    const head = line.match(HEADER);
    if (head) {
      if (open?.kind === "crash") {
        open.sample.push(line);
        continue;
      }
      close(i);
      if (head[1].includes("WARNING")) {
        lastError = null;
        continue;
      }
      const script = head[1].includes("SCRIPT") || /^Failed to load script/.test(head[2]);
      open = {
        kind: script ? "script" : "error",
        message: head[2].trim(),
        at: null,
        frames: [],
        line: i + 1,
        end: i,
        sample: [line],
      };
      lastError = open;
      continue;
    }
    if (!open) continue;
    if (open.kind === "crash" && !line.trim()) continue;
    const at = line.match(AT);
    const frame = line.match(FRAME);
    const native = open.kind === "crash" && line.match(NATIVE_FRAME);
    if (at && !open.at) open.at = at[2];
    else if (frame) open.frames.push(frame[2]);
    else if (native) {
      if (!/^lib(c|pthread|m)\b/.test(native[1])) open.native.push(native[1]);
    } else if (
      !/^\s/.test(line) &&
      !/^(=+|-- END OF|Engine version|Dumping the backtrace|Load address|GDScript backtrace)/.test(
        line.trim(),
      )
    ) {
      close(i);
      continue;
    }
    open.end = i;
    if (open.sample.length < SAMPLE_LINES) open.sample.push(line);
  }
  close(lines.length);
  return events;
}

export function where(event) {
  const gameAt = event.at?.startsWith("res://") ? event.at : null;
  return (
    event.frames[0] ??
    gameAt ??
    (event.kind === "crash" && event.native.length
      ? event.native.slice(0, 3).join(" < ")
      : event.at) ??
    "unknown"
  );
}

export function signature(event) {
  const message = event.kind === "crash" ? event.message : normalize(event.message);
  return {
    kind: event.kind,
    where: where(event),
    message,
    key: `${event.kind}:${where(event)}:${message}`,
  };
}

export function runOf(file, base) {
  const rel = path.relative(base, file) || path.basename(file);
  const parts = rel.split(path.sep);
  const job = parts.indexOf("jobs");
  const id =
    job >= 0 && parts[job + 1] && job + 1 < parts.length - 1
      ? parts[job + 1]
      : rel.replace(/\.[^./]+$/, "");
  const m = id.match(/^(.+)-([a-z_]+)-(\d+)$/);
  return {
    id,
    persona: m?.[1] ?? null,
    pilot: m?.[2] ?? null,
    seed: m ? Number(m[3]) : null,
    log: rel,
  };
}

const SEVERITY = { crash: "blocker", script: "major", error: "minor" };
const AREA = "stability";
const FEEL = {
  crash: "The game closes or dies mid-run.",
  script: "Something in the game logic broke; the effect may be invisible or may not be.",
  error: "Usually nothing on screen; worth a look if it repeats.",
};
const TITLE = { crash: "Crash", script: "Script error", error: "Engine error" };

export function harvest(logs, { base = process.cwd(), ignore = [] } = {}) {
  const found = new Map();
  for (const { file, text } of logs) {
    const run = runOf(file, base);
    const perKey = new Map();
    for (const event of parseLog(text)) {
      const sig = signature(event);
      if (ignore.some((re) => re.test(sig.key))) continue;
      const seen = perKey.get(sig.key);
      if (seen) seen.count += 1;
      else perKey.set(sig.key, { sig, event, count: 1 });
    }
    for (const { sig, event, count } of perKey.values()) {
      const shownMessage =
        sig.kind === "crash" && event.cause ? `${event.message}: ${event.cause}` : event.message;
      const f = found.get(sig.key) ?? {
        severity: SEVERITY[sig.kind],
        area: AREA,
        key: sig.key,
        title: `${TITLE[sig.kind]} at ${sig.where}: ${shownMessage.slice(0, 160)}`,
        feel: FEEL[sig.kind],
        signature: { kind: sig.kind, where: sig.where, message: sig.message },
        count: 0,
        sample: event.sample,
        runs: [],
      };
      f.count += count;
      f.runs.push({
        ...run,
        note: `${count}x, first at ${run.log}:${event.line}`,
        replay: null,
        carry: null,
      });
      found.set(sig.key, f);
    }
  }
  return rank([...found.values()]);
}

export function rank(findings) {
  return findings.sort(
    (a, b) =>
      SEVERITIES.indexOf(a.severity) - SEVERITIES.indexOf(b.severity) ||
      b.runs.length - a.runs.length ||
      b.count - a.count ||
      a.key.localeCompare(b.key),
  );
}

export function carryList(findings) {
  const carry = [];
  for (const f of findings) {
    if (!["blocker", "major"].includes(f.severity)) continue;
    const run = f.runs.find((r) => r.seed !== null);
    if (run)
      carry.push({
        persona: run.persona,
        pilot: run.pilot,
        seed: run.seed,
        title: f.title,
      });
  }
  return carry;
}

export function renderMarkdown({ inputs, logs, findings, skipped = [] }) {
  const count = (s) => findings.filter((f) => f.severity === s).length;
  const out = [
    "# Crash harvest",
    "",
    `${logs} log(s) read from ${inputs.join(", ")}. ${count("blocker")} blocker, ${count("major")} major, ${count("minor")} minor.`,
    "",
  ];
  if (!findings.length) out.push("No crash, SCRIPT ERROR or ERROR lines found.", "");
  findings.forEach((f, i) => {
    const runs =
      f.runs
        .slice(0, 5)
        .map((r) => r.id)
        .join(", ") + (f.runs.length > 5 ? `, and ${f.runs.length - 5} more` : "");
    out.push(
      `${i + 1}. **${f.severity.toUpperCase()}** · ${f.area} · ${f.title}`,
      `   ${f.count}x in ${f.runs.length} run(s): ${runs}`,
      "",
    );
  });
  if (skipped.length) out.push(`Skipped: ${skipped.join("; ")}`, "");
  out.push(
    "Severity per sketches/core-loop/BUG-BAR.md: a crash is always a blocker. Logs show what the engine printed, not what the player saw; a bot's freeze or a kill with no crash handler output leaves no line here.",
  );
  return out.join("\n") + "\n";
}

const SKIP_DIRS = new Set(["node_modules", ".git", ".godot"]);

export function collect(inputs) {
  const files = [];
  const skipped = [];
  const addFile = (p, explicit) => {
    const st = statSync(p, { throwIfNoEntry: false });
    if (!st) return skipped.push(`${p} (missing)`);
    if (LOG_FILE.test(path.basename(p)) || explicit) {
      if (st.size > MAX_BYTES) skipped.push(`${p} (over ${MAX_BYTES / 1024 / 1024} MB)`);
      else files.push(p);
    }
  };
  for (const input of inputs) {
    const st = statSync(input, { throwIfNoEntry: false });
    if (!st) {
      skipped.push(`${input} (missing)`);
      continue;
    }
    if (st.isDirectory()) {
      for (const entry of walkSync(input, {
        sort: true,
        prune: (item) => SKIP_DIRS.has(item.name),
      })) {
        addFile(entry.full, false);
      }
    } else {
      addFile(input, true);
    }
  }
  return { files, skipped };
}

export function parseArgs(argv) {
  const args = {
    out: null,
    failOn: null,
    ignore: [],
    inputs: [],
    wave: null,
    commit: "unknown",
  };
  for (const arg of argv) {
    if (arg.startsWith("--out=")) args.out = arg.slice(6);
    else if (arg.startsWith("--fail-on=")) args.failOn = arg.slice(10);
    else if (arg.startsWith("--wave=")) args.wave = Number(arg.slice(7));
    else if (arg.startsWith("--commit=")) args.commit = arg.slice(9);
    else if (arg.startsWith("--ignore=")) args.ignore.push(new RegExp(arg.slice(9)));
    else if (arg.startsWith("--")) throw new Error(`unknown option ${arg}`);
    else args.inputs.push(arg);
  }
  if (args.failOn && !SEVERITIES.slice(0, 3).includes(args.failOn))
    throw new Error("--fail-on takes blocker, major or minor");
  if (!args.inputs.length)
    throw new Error(
      "usage: crash-harvest.mjs [--out=<dir>] [--fail-on=<severity>] [--ignore=<regex>] [--wave=<n>] [--commit=<sha>] <log or dir>...",
    );
  return args;
}

export function main(argv, log = console.log) {
  let args;
  try {
    args = parseArgs(argv);
  } catch (error) {
    log("crash-harvest: " + error.message);
    return 2;
  }
  const { files, skipped } = collect(args.inputs);
  const base =
    args.inputs.length === 1 && statSync(args.inputs[0], { throwIfNoEntry: false })?.isDirectory()
      ? args.inputs[0]
      : process.cwd();
  const logs = [];
  for (const file of files) {
    try {
      logs.push({ file, text: readFileSync(file, "utf8") });
    } catch (error) {
      skipped.push(`${file} (${error.code ?? error.message})`);
    }
  }
  const findings = harvest(logs, { base, ignore: args.ignore });
  const page = renderMarkdown({
    inputs: args.inputs,
    logs: logs.length,
    findings,
    skipped,
  });
  if (args.out) {
    mkdirSync(args.out, { recursive: true });
    writeFileSync(path.join(args.out, "findings.md"), page);
    writeFileSync(
      path.join(args.out, "findings.json"),
      JSON.stringify(
        {
          tool: "crash-harvest",
          wave: args.wave,
          commit: args.commit,
          started: new Date().toISOString(),
          minutes: 0,
          inputs: args.inputs,
          logs: logs.map(({ file }) => path.relative(base, file) || file),
          skipped,
          runs: [],
          extras: {},
          findings,
          carry: carryList(findings),
        },
        null,
        2,
      ) + "\n",
    );
  }
  log(page.trimEnd());
  if (!logs.length) return 2;
  if (
    args.failOn &&
    findings.some((f) => SEVERITIES.indexOf(f.severity) <= SEVERITIES.indexOf(args.failOn))
  )
    return 1;
  return 0;
}

if (isMain(import.meta.url)) process.exitCode = main(process.argv.slice(2));
