#!/usr/bin/env node
// The receipt for the world 1 done read's row "words-on-screen" (scripts/world1-bands.rows.json):
//   { head, pass, measured, plant_caught }
// On a clean checkout (cleanHead refuses dirty checkouts):
//   1. runs scripts/sketch-lint.mjs --sketch core-loop (must exit 0 with 0 findings);
//   2. runs both word-budget tests (ui_word_budget_test, ui_word_budget_first_find_test) through
//      scripts/sketch-smoke.mjs with SMOKE_LOG_DIR in a temp dir cleaned up in finally;
//   3. runs the real word-lint checker (sketch-lint-words.mjs lintFile + sketch-lint.mjs applyBaseline)
//      on a planted label that restates its value and requires it to fail with W6 (plant_caught).
//
//   node scripts/gate/words-on-screen-receipt.mjs [--out <file>]
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

import { applyBaseline } from "../sketch-lint.mjs";
import { SOURCES, lintFile, parseBoundKeys, parseNames } from "../sketch-lint-words.mjs";
import { withoutTeardownNoise } from "../sketch-smoke.mjs";
import { cleanHead, root } from "./clean-head.mjs";
import { parseSmokeLog } from "./shard.mjs";

export const BUDGET_TESTS = ["ui_word_budget_test", "ui_word_budget_first_find_test"];
export const PLANT_PATH = "sketches/core-loop/src/ui/_planted_label.gd";
export const PLANT_CODE =
  'func _show_metric(label: Label) -> void:\n\tlabel.text = "Speed: 24 m/s"\n';

export function gradeLintOutput(status, output) {
  const text = String(output ?? "");
  const passLine = /^sketch-lint pass: 0 findings\b/m.test(text);
  if (status === 0 && passLine) {
    const wordsLine = /^words: (\d+) player strings read\b/m.exec(text);
    return {
      ok: true,
      stringsRead: wordsLine ? Number(wordsLine[1]) : null,
      reason: null,
    };
  }
  const summary = text
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean)
    .find((l) => l.startsWith("sketch-lint fail:") || /^[A-Z]\w* /.test(l));
  return {
    ok: false,
    stringsRead: null,
    reason: `sketch-lint failed (exit ${status})${summary ? `: ${summary.slice(0, 140)}` : ""}`,
  };
}

export function gradeBudgetLog(
  test,
  logText,
  { runnerOk = true, platform = process.platform } = {},
) {
  const cleaned = withoutTeardownNoise(String(logText ?? ""), platform);
  const lines = cleaned.split("\n");
  const failedLines = lines.filter((l) => l.trimEnd().endsWith("-> FAIL"));
  const errorLines = lines.filter((l) => /^(?:SCRIPT ERROR|ERROR)\b/.test(l));
  const verdictPass = new RegExp(`^${test}: PASS\\b`, "m").test(cleaned);
  const budgetLine = lines.find(
    (l) => l.startsWith("[word budget]") && l.trimEnd().endsWith("-> PASS"),
  );
  const wordsMatch = budgetLine ? /\b(\d+) HUD words\b/.exec(budgetLine) : null;
  const words = wordsMatch ? Number(wordsMatch[1]) : null;
  const ok =
    Boolean(runnerOk) &&
    verdictPass &&
    Boolean(budgetLine) &&
    failedLines.length === 0 &&
    errorLines.length === 0;
  let reason = null;
  if (!ok) {
    if (errorLines.length) reason = `${test}: ${errorLines[0].slice(0, 120)}`;
    else if (failedLines.length) reason = `${test}: ${failedLines[0].slice(0, 120)}`;
    else if (!verdictPass) reason = `${test}: no PASS verdict line`;
    else if (!budgetLine) reason = `${test}: no [word budget] PASS line`;
    else reason = `${test}: runner reported failure`;
  }
  return { ok, test, words, reason };
}

// Runs the real word-lint checker (sketch-lint-words.mjs lintFile + sketch-lint.mjs applyBaseline)
// on a planted UI label that restates its value ("Speed: 24 m/s") and confirms W6 catches it.
export function runPlantedWordLint(cwd = root) {
  const sketchDir = path.join(cwd, "sketches", "core-loop");
  const names = readFileSync(path.join(sketchDir, "design-v3", "NAMES.md"), "utf8");
  const bindings = readFileSync(path.join(sketchDir, "src", "core", "bindings.gd"), "utf8");
  const baselineFile = path.join(cwd, "scripts", "sketch-lint.baseline.json");
  const baseline = existsSync(baselineFile) ? JSON.parse(readFileSync(baselineFile, "utf8")) : {};
  const uiSource = SOURCES.find((s) => s.read === "ui");
  if (!uiSource) throw new Error("sketch-lint-words SOURCES has no ui source");
  const bans = parseNames(names);
  const keys = parseBoundKeys(bindings);
  const raw = lintFile(PLANT_PATH, PLANT_CODE, uiSource, { bans, keys });
  const afterBaseline = applyBaseline(raw.findings, baseline, () => true);
  const findings = afterBaseline.filter((item) => item.path === PLANT_PATH);
  const caught = findings.some((item) => item.rule === "W6");
  return { caught, findings };
}

export function runSketchLint(cwd = root) {
  const res = spawnSync(
    process.execPath,
    [path.join(cwd, "scripts", "sketch-lint.mjs"), "--sketch", "core-loop"],
    { cwd, encoding: "utf8", maxBuffer: 1 << 24 },
  );
  return {
    status: res.status ?? 1,
    output: `${res.stdout ?? ""}${res.stderr ?? ""}`,
  };
}

export function runWordBudgetTests(cwd = root) {
  const logsDir = mkdtempSync(path.join(os.tmpdir(), "words-on-screen-"));
  try {
    const args = [path.join(cwd, "scripts", "sketch-smoke.mjs"), "--sketch", "core-loop"];
    for (const test of BUDGET_TESTS) args.push("--test", test);
    const res = spawnSync(process.execPath, args, {
      cwd,
      env: { ...process.env, SMOKE_LOG_DIR: logsDir },
      encoding: "utf8",
      maxBuffer: 1 << 26,
    });
    const parsed = parseSmokeLog(String(res.stdout ?? ""));
    const byTest = new Map(parsed.map((row) => [row.test, row]));
    const runs = {};
    for (const test of BUDGET_TESTS) {
      const file = path.join(logsDir, `${test}.log`);
      const log = existsSync(file)
        ? readFileSync(file, "utf8")
        : `runner exit ${res.status}, no ${test}.log`;
      const row = byTest.get(test);
      runs[test] = {
        ok: res.status === 0 && (row ? row.ok : existsSync(file)),
        log,
      };
    }
    return { status: res.status ?? 1, runs };
  } finally {
    rmSync(logsDir, { recursive: true, force: true });
  }
}

export function buildReceipt({ lint, budget, plant, head, platform = process.platform }) {
  const lintGrade = gradeLintOutput(lint?.status ?? 1, lint?.output ?? "");
  const budgetGrades = BUDGET_TESTS.map((test) => {
    const entry = budget?.runs?.[test];
    return gradeBudgetLog(test, entry?.log ?? "", {
      runnerOk: Boolean(entry?.ok),
      platform,
    });
  });
  const plantCaught = Boolean(plant?.caught);
  const budgetOk = budgetGrades.every((g) => g.ok);
  const pass = lintGrade.ok && budgetOk && plantCaught;
  const parts = [];
  if (lintGrade.ok) {
    parts.push(
      `sketch-lint pass (0 findings${lintGrade.stringsRead !== null ? `, ${lintGrade.stringsRead} strings` : ""})`,
    );
  } else {
    parts.push(lintGrade.reason);
  }
  const budgetSummary = budgetGrades.map((g) =>
    g.ok ? `${g.test} PASS${g.words !== null ? ` (${g.words} HUD words)` : ""}` : g.reason,
  );
  parts.push(budgetSummary.join("; "));
  parts.push(
    plantCaught
      ? 'plant: W6 flagged planted label "Speed: 24 m/s"'
      : 'plant: planted label "Speed: 24 m/s" was not flagged by W6',
  );
  return { head, pass, measured: parts.join("; "), plant_caught: plantCaught };
}

export function produce({
  cwd = root,
  runLint = runSketchLint,
  runBudget = runWordBudgetTests,
  runPlant = runPlantedWordLint,
  platform = process.platform,
} = {}) {
  const head = cleanHead(cwd);
  const lint = runLint(cwd);
  const budget = runBudget(cwd);
  const plant = runPlant(cwd);
  return buildReceipt({ lint, budget, plant, head, platform });
}

export function parseArgs(argv) {
  const args = { out: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--out") {
      const val = argv[++i];
      if (!val || val.startsWith("--")) throw new Error("--out requires a value");
      args.out = val;
    } else if (a.startsWith("--out=")) {
      args.out = a.slice("--out=".length);
    } else {
      throw new Error(`unknown argument: ${a}`);
    }
  }
  return args;
}

function main(argv) {
  let args;
  let receipt;
  try {
    args = parseArgs(argv);
    receipt = produce();
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
