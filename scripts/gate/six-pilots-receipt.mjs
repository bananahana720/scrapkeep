#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, realpathSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { withoutTeardownNoise } from "../lib/godot-test-runner.mjs";
import {
  COMMIT_SHA_RE,
  cleanHead,
  parseReceiptArgs,
  root,
  runReceiptCliSync,
} from "./receipt-cli.mjs";
import { parseSmokeLog } from "./shard.mjs";

export const TEST = "world1_run_test";
export const COMMIT = COMMIT_SHA_RE;
export const PILOTS = [
  "pylon_engineer",
  "runner_gunner",
  "demolitions_caster",
  "tarn",
  "tally",
  "remembered_cannon",
];
export const REQUIRED_PILOT_CHECKS = [
  "the run reaches stage 3 and quits 0",
  "the dam's exit is taken",
  "the flume is entered",
  "Brindle's arena is entered",
  "Brindle goes down",
  "stage 3 opens",
  "no script error or ERROR line",
  "stages 1, 2 and 3 in order",
];

const PLANT_LINE = "SCRIPT ERROR: planted kit error in pylon_engineer";

export function injectPlantedScriptError(logText) {
  const text = String(logText ?? "");
  const lines = text.split("\n");
  const idx = lines.findIndex((l) => l.startsWith(`[${PILOTS[0]}: `));
  if (idx >= 0) {
    lines.splice(idx + 1, 0, PLANT_LINE);
    return lines.join("\n");
  }
  return `${PLANT_LINE}\n${text}`;
}

export function gradeWorld1Log(logText, { platform = process.platform } = {}) {
  const cleaned = withoutTeardownNoise(String(logText ?? ""), platform);
  const lines = cleaned.split("\n");
  const failedLines = lines.filter((l) => l.trimEnd().endsWith("-> FAIL"));
  const errorLines = lines.filter((l) => /^(?:\s*SCRIPT ERROR|ERROR)\b/.test(l));
  const verdictMatch = /^world1_run_test: PASS \((\d+) checks(?:, (\d+) skipped)?\)/m.exec(cleaned);
  const verdictPass = Boolean(verdictMatch);
  const checks = verdictMatch ? Number(verdictMatch[1]) : 0;
  const skipped = verdictMatch && verdictMatch[2] ? Number(verdictMatch[2]) : 0;

  const cleanPilots = [];
  const missingPilots = [];
  const failedPilots = [];
  for (const pilot of PILOTS) {
    const prefix = `[${pilot}: `;
    const pilotLines = lines.filter((l) => l.startsWith(prefix));
    const pilotFails = pilotLines.filter((l) => l.trimEnd().endsWith("-> FAIL"));
    const missingChecks = REQUIRED_PILOT_CHECKS.filter(
      (check) =>
        !pilotLines.some(
          (l) => l.startsWith(`[${pilot}: ${check}]`) && l.trimEnd().endsWith("-> PASS"),
        ),
    );
    if (pilotFails.length > 0) failedPilots.push(pilot);
    else if (missingChecks.length > 0) missingPilots.push(pilot);
    else cleanPilots.push(pilot);
  }

  const ok =
    verdictPass &&
    skipped === 0 &&
    failedLines.length === 0 &&
    errorLines.length === 0 &&
    cleanPilots.length === PILOTS.length;

  return {
    ok,
    verdictPass,
    checks,
    skipped,
    failedLines,
    errorLines,
    cleanPilots,
    missingPilots,
    failedPilots,
  };
}

export function buildReceipt(logText, head, { runnerOk = true, platform = process.platform } = {}) {
  const main = gradeWorld1Log(logText, { platform });
  const planted = gradeWorld1Log(injectPlantedScriptError(logText), { platform });
  const plantCaught = !planted.ok && planted.errorLines.some((line) => line.includes(PLANT_LINE));
  const pass = Boolean(runnerOk) && main.ok && plantCaught;
  const issues = [];
  if (!runnerOk) issues.push("runner exited non-zero");
  if (!main.verdictPass) issues.push("no world1_run_test PASS verdict line");
  if (main.skipped > 0) issues.push(`${main.skipped} skipped check(s)`);
  if (main.failedPilots.length) issues.push(`failed pilot(s): ${main.failedPilots.join(", ")}`);
  if (main.missingPilots.length)
    issues.push(`incomplete pilot(s): ${main.missingPilots.join(", ")}`);
  if (main.failedLines.length)
    issues.push(`${main.failedLines.length} FAIL line(s): ${main.failedLines[0].slice(0, 120)}`);
  if (main.errorLines.length)
    issues.push(`${main.errorLines.length} error line(s): ${main.errorLines[0].slice(0, 120)}`);
  const plantNote = plantCaught
    ? "plant: injected SCRIPT ERROR rejected"
    : "plant: injected SCRIPT ERROR was not rejected";
  const measured =
    issues.length === 0
      ? `all ${PILOTS.length} of ${PILOTS.length} pilots (${PILOTS.join(", ")}) cleared world1_run_test (${main.checks} checks, 0 errors); ${plantNote}`
      : `${main.cleanPilots.length} of ${PILOTS.length} pilots clean; ${issues.join("; ")}; ${plantNote}`;
  return { head, pass, measured, plant_caught: plantCaught };
}

export function runWorld1Test(cwd = root) {
  const logsDir = mkdtempSync(path.join(os.tmpdir(), "six-pilots-"));
  try {
    const res = spawnSync(
      process.execPath,
      [path.join(cwd, "scripts", "sketch-smoke.mjs"), "--sketch", "core-loop", "--test", TEST],
      {
        cwd,
        env: { ...process.env, SMOKE_LOG_DIR: logsDir },
        encoding: "utf8",
        maxBuffer: 1 << 26,
      },
    );
    const line = parseSmokeLog(String(res.stdout ?? "")).find((r) => r.test === TEST);
    const file = path.join(logsDir, `${TEST}.log`);
    const log = existsSync(file)
      ? readFileSync(file, "utf8")
      : `runner exit ${res.status}, no ${TEST}.log`;
    return { ok: res.status === 0 && (line ? line.ok : existsSync(file)), log };
  } finally {
    rmSync(logsDir, { recursive: true, force: true });
  }
}

export function produce({
  cwd = root,
  head = null,
  logPath = null,
  run = runWorld1Test,
  platform = process.platform,
} = {}) {
  if (logPath) {
    if (typeof head !== "string" || !COMMIT.test(head)) {
      throw new Error("--head <7..40 hex sha> is required when using --log");
    }
    if (!existsSync(logPath)) {
      throw new Error(`log file not found: ${logPath}`);
    }
    return buildReceipt(readFileSync(logPath, "utf8"), head, { runnerOk: true, platform });
  }
  const actualHead = cleanHead(cwd);
  if (head !== null) {
    if (!COMMIT.test(head)) {
      throw new Error(`--head requires 7 to 40 lowercase hex characters; got "${head}"`);
    }
    if (!actualHead.startsWith(head) && !head.startsWith(actualHead)) {
      throw new Error(
        `--head ${head} does not match clean checkout HEAD ${actualHead.slice(0, 12)}`,
      );
    }
  }
  const ran = run(cwd);
  return buildReceipt(ran.log, actualHead, { runnerOk: ran.ok, platform });
}

export function parseArgs(argv) {
  const args = parseReceiptArgs(argv, {
    valueFlags: { "--log": { key: "logPath" } },
    defaults: { head: null, logPath: null, out: null },
    head: "optional",
  });
  if (args.logPath && !args.head) {
    throw new Error(
      "usage: six-pilots-receipt.mjs --head <sha> --log <world1_run_test.log> [--out <file>] (or omit both --log and --head to run on a clean checkout)",
    );
  }
  return args;
}

function main(argv) {
  return runReceiptCliSync(() => {
    const args = parseArgs(argv);
    return { receipt: produce(args), out: args.out };
  });
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(main(process.argv.slice(2)));
}
