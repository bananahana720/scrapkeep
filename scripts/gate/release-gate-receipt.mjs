#!/usr/bin/env node
// The receipt for the world 1 done read's row "release-gate" (scripts/world1-bands.rows.json):
//   { head, pass, measured, plant_caught }
// Runs scripts/gate/tally.mjs --plan <plan> WITHOUT --wave (full release gate; nothing deferred)
// and confirms CLEAN (exit 0). Planted check: writes a temp copy of <plan> with the same filename
// pattern (cleaned up in finally) with one shard row changed to RED, runs the real tally.mjs on it,
// and confirms it exits non-zero and refuses CLEAN (plant_caught).
//
//   node scripts/gate/release-gate-receipt.mjs --plan <gate-plan.md> --head <sha> [--out <file>]
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { root } from "./clean-head.mjs";
import { isPass, planHead, tallyRows } from "./tally.mjs";

export const COMMIT = /^[0-9a-f]{7,40}$/;

export function commitsMatch(a, b) {
  return (
    typeof a === "string" &&
    typeof b === "string" &&
    COMMIT.test(a) &&
    COMMIT.test(b) &&
    (a.startsWith(b) || b.startsWith(a))
  );
}

// Mutates the newest passing shard row (or the last shard row if none pass) to RED so tally.mjs
// must reject the mutated plan on that shard.
export function plantRedShard(planText) {
  const rows = tallyRows(planText, "shard");
  if (rows.length === 0) return { mutated: null, shard: null };
  const target = [...rows].reverse().find((r) => isPass(r.verdict)) ?? rows[rows.length - 1];
  const lines = planText.split("\n");
  lines[target.line - 1] =
    `| ${target.shard} | RED: planted failing test (receipt planted/receipt.md) |`;
  return { mutated: lines.join("\n"), shard: target.shard };
}

export function runTally(planPath, { cwd = root } = {}) {
  const res = spawnSync(
    process.execPath,
    [path.join(cwd, "scripts", "gate", "tally.mjs"), "--plan", planPath],
    { cwd, encoding: "utf8", maxBuffer: 1 << 24 },
  );
  return {
    status: res.status ?? 1,
    stdout: String(res.stdout ?? ""),
    stderr: String(res.stderr ?? ""),
  };
}

export function gradeTallyRun(run) {
  const stdout = String(run?.stdout ?? "");
  const problems = stdout
    .split("\n")
    .filter((l) => l.startsWith("PROBLEM "))
    .map((l) => l.slice("PROBLEM ".length).trim());
  const cleanLine = /Every row is filled; CLEAN may be written/.test(stdout);
  const releaseLine = /release gate: every shard, nothing deferred/.test(stdout);
  const ok = run?.status === 0 && problems.length === 0 && cleanLine && releaseLine;
  const summaryLine =
    stdout
      .split("\n")
      .find((l) => l.startsWith("gate tally:"))
      ?.trim() ?? null;
  return { ok, status: run?.status ?? 1, problems, cleanLine, releaseLine, summaryLine };
}

export function produce({ planPath, head, cwd = root, run = runTally } = {}) {
  if (!planPath) throw new Error("--plan <gate-plan.md> is required");
  if (typeof head !== "string" || !COMMIT.test(head)) {
    throw new Error(`--head requires 7 to 40 lowercase hex characters; got "${head ?? ""}"`);
  }
  if (!existsSync(planPath)) {
    throw new Error(`gate plan not found: ${planPath}`);
  }
  const planText = readFileSync(planPath, "utf8");
  const gated = planHead(planPath);
  const headProblems = [];
  if (!gated) {
    headProblems.push(
      `plan filename "${path.basename(planPath)}" does not match w<N>-<head>-gate-plan.md`,
    );
  } else if (!commitsMatch(gated, head)) {
    headProblems.push(`plan gates ${gated}, judging ${head.slice(0, 12)}`);
  }

  const mainGrade = gradeTallyRun(run(planPath, { cwd }));

  let plantCaught = false;
  let plantShard = null;
  let plantDetail = "plan has no shard row to mutate";
  const planted = plantRedShard(planText);
  if (planted.mutated !== null) {
    plantShard = planted.shard;
    const tmp = mkdtempSync(path.join(os.tmpdir(), "release-gate-plant-"));
    try {
      const tempPlan = path.join(tmp, path.basename(planPath));
      writeFileSync(tempPlan, planted.mutated);
      const plantGrade = gradeTallyRun(run(tempPlan, { cwd }));
      const sawPlantedProblem = plantGrade.problems.some(
        (p) => p.includes(`"${plantShard}"`) && p.includes("does not open with PASS"),
      );
      plantCaught = !plantGrade.ok && plantGrade.status !== 0 && sawPlantedProblem;
      plantDetail = plantCaught
        ? `planted RED shard "${plantShard}" refused CLEAN (exit ${plantGrade.status})`
        : `planted RED shard "${plantShard}" was not rejected by tally.mjs (exit ${plantGrade.status})`;
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  }

  const pass = headProblems.length === 0 && mainGrade.ok && plantCaught;
  const issues = [...headProblems];
  if (!mainGrade.ok) {
    issues.push(
      mainGrade.problems.length > 0
        ? `tally not clean (${mainGrade.problems.length} problem(s)): ${mainGrade.problems[0].slice(0, 140)}`
        : `tally exited ${mainGrade.status} without CLEAN`,
    );
  }
  const measured =
    issues.length === 0
      ? `release gate CLEAN on ${head.slice(0, 12)} (${mainGrade.summaryLine ?? "all shards pass"}); plant: ${plantDetail}`
      : `${issues.join("; ")}; plant: ${plantDetail}`;
  return { head, pass, measured, plant_caught: plantCaught };
}

export function parseArgs(argv) {
  const args = { planPath: null, head: null, out: null };
  const take = (i, flag) => {
    const val = argv[i + 1];
    if (val === undefined || val === "" || val.startsWith("--")) {
      throw new Error(`${flag} requires a value`);
    }
    return val;
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--plan") args.planPath = take(i++, a);
    else if (a.startsWith("--plan=")) args.planPath = a.slice("--plan=".length);
    else if (a === "--head") args.head = take(i++, a);
    else if (a.startsWith("--head=")) args.head = a.slice("--head=".length);
    else if (a === "--out") args.out = take(i++, a);
    else if (a.startsWith("--out=")) args.out = a.slice("--out=".length);
    else throw new Error(`unknown argument: ${a}`);
  }
  if (!args.planPath || !args.head) {
    throw new Error(
      "usage: release-gate-receipt.mjs --plan <gate-plan.md> --head <sha> [--out <file>]",
    );
  }
  if (!COMMIT.test(args.head)) {
    throw new Error(`--head requires 7 to 40 lowercase hex characters; got "${args.head}"`);
  }
  return args;
}

function main(argv) {
  let args;
  let receipt;
  try {
    args = parseArgs(argv);
    receipt = produce(args);
  } catch (e) {
    console.error(String(e?.message ?? e));
    return 2;
  }
  const text = JSON.stringify(receipt, null, 2) + "\n";
  if (args.out) {
    mkdirSync(path.dirname(path.resolve(args.out)), { recursive: true });
    writeFileSync(args.out, text);
  } else {
    process.stdout.write(text);
  }
  return receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(main(process.argv.slice(2)));
}
