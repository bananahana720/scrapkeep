#!/usr/bin/env node
// Writes the receipts that scripts/world1-bands.mjs reads for the two rows backed by the TLA+ models in
// .agents/skills/scrapkeep-verify-formal: "run-always-ends" (RunFlow.tla) and "rewards-banked-once" (Rewards.tla).
//   { head, pass, measured, plant_caught }
// For each row it runs TLC, the TLA+ model checker, on the config that stands for the code (the skill's today-*
// config) and on each planted fault (a broken-* config with one guard off). It passes only when the code's config
// reports no break, every plant reports a break of the rule it names (plant_caught), and no covered source file
// changed since the model's sync commit (the skill's "Is this change covered?" step 1: a changed file means the
// model may no longer describe the code until someone reads the diff and moves the sync commit).
//
//   node scripts/gate/model-receipts.mjs --out <dir> [--row <id>] [--head <commit>] [--jar <tla2tools.jar>] [--workers <n>]
//
// TLC is plain TLC (the skill's rewards-coverage.md command): java -XX:+UseParallelGC -cp <jar> tlc2.TLC. The jar is
// --jar, else $TLA2TOOLS, else the pinned jar that the astack statechart skill's `statechart install-tlc` puts in
// ${XDG_DATA_HOME:-~/.local/share}/astack/tlc. Java is $JAVA, else java on PATH. Each run works in a new temp folder,
// so nothing is written beside the models.
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const SKILL = ".agents/skills/scrapkeep-verify-formal";
const SRC = "sketches/core-loop/src";
export const TLC_PIN = "1.7.4";

export const ROWS = {
  "run-always-ends": {
    spec: "RunFlow.tla",
    real: "today-store.cfg",
    plants: [
      { cfg: "broken-vanish.cfg", rule: "WardenGoneOpens" },
      { cfg: "broken-endguard.cfg", rule: "EndsOnce" },
    ],
    coverage: "references/coverage.md",
    // SKILL.md, "Is this change covered?" step 1.
    covered: ["core/flow.gd", "presentation/launch_take.gd", "game.gd", "ui/pause_menu.gd", "ui/screens.gd"],
  },
  "rewards-banked-once": {
    spec: "Rewards.tla",
    real: "rewards-today-one.cfg",
    plants: [
      { cfg: "rewards-broken-ledger.cfg", rule: "AtMostOnce" },
      { cfg: "rewards-broken-midsave.cfg", rule: "NeverLost" },
    ],
    coverage: "references/rewards-coverage.md",
    // SKILL.md's description: the files the rewards model stands for.
    covered: ["core/profile.gd", "core/safe_store.gd", "core/run_store.gd", "core/progress.gd"],
  },
};

const num = (s) => Number(s.replaceAll(",", ""));

// TLC's printed output -> what it found. outcome: "clean" (it finished and found no error), "violated" (it names
// one or more breaks) or "error" (it stopped for any other reason, or the text is not a finished TLC run).
export function parseTlc(text) {
  const lines = text.split("\n").map((l) => l.trim());
  const rules = [];
  let temporal = false;
  let deadlock = false;
  const other = [];
  for (const line of lines) {
    const inv = line.match(/^Error: Invariant (\w+) is violated/);
    if (inv) rules.push(inv[1]);
    else if (/^Error: Temporal properties were violated/.test(line)) temporal = true;
    else if (/^Error: Deadlock reached/.test(line)) deadlock = true;
    else if (/^Error: (The behavior up to this point is|The following behavior constitutes a counter-example)/.test(line)) continue;
    else if (/^Error:|Parse Error|^Semantic errors|^\*\*\* Errors/.test(line)) other.push(line);
  }
  const stats = text.match(/([\d,]+) states generated, ([\d,]+) distinct states found, ([\d,]+) states left on queue/g);
  const last = stats ? stats[stats.length - 1].match(/([\d,]+) states generated, ([\d,]+) distinct states found/) : null;
  const generated = last ? num(last[1]) : null;
  const distinct = last ? num(last[2]) : null;
  const finished = /Model checking completed\. No error has been found\./.test(text);
  let outcome;
  if (other.length) outcome = "error";
  else if (rules.length || temporal || deadlock) outcome = "violated";
  else if (finished && distinct !== null) outcome = "clean";
  else outcome = "error";
  return { outcome, rules, temporal, deadlock, generated, distinct, error: other[0] ?? (outcome === "error" ? "no finished TLC run in the output" : null) };
}

// A config's checked rules: { invariants, properties }.
export function cfgRules(text) {
  const words = (key) => {
    const m = text.match(new RegExp(`^${key}\\b(.*)$`, "m"));
    return m ? m[1].trim().split(/\s+/).filter(Boolean) : [];
  };
  return { invariants: words("INVARIANTS"), properties: words("PROPERTIES") };
}

// Did this run break the named rule? An invariant is named by TLC; a temporal property is not, so a temporal break
// counts for a rule only when the config checks that rule as a property.
export function brokeRule(parsed, rules, rule) {
  if (parsed.outcome !== "violated") return false;
  if (rules.invariants.includes(rule)) return parsed.rules.includes(rule);
  if (rules.properties.includes(rule)) return parsed.temporal;
  return false;
}

// The model's sync commit: the first commit id on the last non-empty line of its coverage page.
export function syncCommit(text) {
  const line = text.split("\n").map((l) => l.trim()).filter(Boolean).pop() ?? "";
  return line.match(/\b[0-9a-f]{7,40}\b/)?.[0] ?? null;
}

const states = (p) => (p.distinct === null ? "?" : p.distinct.toLocaleString("en-US"));
const said = (p) => (p.outcome === "clean" ? "no break" : p.outcome === "error" ? `stopped: ${p.error}`
  : `broke ${[...p.rules, ...(p.temporal ? ["a temporal property"] : []), ...(p.deadlock ? ["deadlock"] : [])].join(", ")}`);

// real: { cfg, parsed }; plants: [{ cfg, rule, rules, parsed }]; drift: { sync, files } (files changed since sync).
export function buildReceipt({ head, real, plants, drift }) {
  const caught = plants.length > 0 && plants.every((p) => brokeRule(p.parsed, p.rules, p.rule));
  const clean = real.parsed.outcome === "clean";
  const synced = drift.sync !== null && drift.files.length === 0;
  const plantText = plants.map((p) => `${p.cfg.replace(/\.cfg$/, "")} ${brokeRule(p.parsed, p.rules, p.rule) ? `broke ${p.rule}` : `did not break ${p.rule} (${said(p.parsed)})`} in ${states(p.parsed)} states`).join("; ");
  let measured = `${real.cfg.replace(/\.cfg$/, "")}: ${said(real.parsed)} in ${states(real.parsed)} distinct states; plants: ${plantText}`;
  if (drift.sync === null) measured = `no sync commit on the model's coverage page; ${measured}`;
  else if (drift.files.length) measured = `model not synced: ${drift.files.join(", ")} changed since ${drift.sync}; ${measured}`;
  return { head, pass: clean && caught && synced, measured, plant_caught: caught };
}

function git(root, args) {
  const r = spawnSync("git", args, { cwd: root, encoding: "utf8" });
  if (r.status !== 0) throw new Error(`git ${args.join(" ")}: ${r.stderr.trim()}`);
  return r.stdout.trim();
}

function findJar(arg) {
  const data = process.env.XDG_DATA_HOME || join(homedir(), ".local/share");
  return [arg, process.env.TLA2TOOLS, join(data, "astack/tlc", `tla2tools-${TLC_PIN}.jar`)].find((p) => p && existsSync(p)) ?? null;
}

function runTlc({ java, jar, workers, models, spec, cfg }) {
  const dir = mkdtempSync(join(tmpdir(), "model-receipt-"));
  try {
    copyFileSync(join(models, spec), join(dir, spec));
    copyFileSync(join(models, cfg), join(dir, cfg));
    const r = spawnSync(java, ["-XX:+UseParallelGC", "-cp", jar, "tlc2.TLC", "-workers", String(workers), "-noGenerateSpecTE",
      "-metadir", join(dir, "states"), "-config", cfg, spec], { cwd: dir, encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });
    return `${r.stdout ?? ""}\n${r.stderr ?? ""}`;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

export function produce(id, { root, head, java, jar, workers, log = () => {} }) {
  const row = ROWS[id];
  const models = join(root, SKILL, "models");
  const sync = syncCommit(readFileSync(join(root, SKILL, row.coverage), "utf8"));
  const files = sync === null ? [] : git(root, ["diff", "--name-only", sync, "--", ...row.covered.map((f) => `${SRC}/${f}`)]).split("\n").filter(Boolean);
  const check = (cfg) => {
    log(`${id}: TLC ${row.spec} ${cfg}`);
    return runTlc({ java, jar, workers, models, spec: row.spec, cfg });
  };
  const real = { cfg: row.real, parsed: parseTlc(check(row.real)) };
  const plants = row.plants.map((p) => ({ ...p, rules: cfgRules(readFileSync(join(models, p.cfg), "utf8")), parsed: parseTlc(check(p.cfg)) }));
  return buildReceipt({ head, real, plants, drift: { sync, files } });
}

function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) args[argv[i].replace(/^--/, "")] = argv[i + 1];
  if (!args.out || (args.row && !ROWS[args.row])) {
    console.error(`usage: model-receipts.mjs --out <dir> [--row ${Object.keys(ROWS).join("|")}] [--head <commit>] [--jar <tla2tools.jar>] [--workers <n>]`);
    return 2;
  }
  const root = git(process.cwd(), ["rev-parse", "--show-toplevel"]);
  const at = git(root, ["rev-parse", "HEAD"]);
  const head = args.head ?? at;
  if (!at.startsWith(head)) {
    console.error(`--head ${head} is not the checked-out commit ${at}; the receipt would name a commit it did not check`);
    return 2;
  }
  const java = process.env.JAVA || "java";
  const jar = findJar(args.jar);
  const javaOk = spawnSync(java, ["-version"], { encoding: "utf8" }).status === 0;
  if (!javaOk || !jar) {
    if (!javaOk) console.error(`model-receipts: no working Java (${java} -version failed); set JAVA or install a JDK`);
    if (!jar) console.error(`model-receipts: no TLC jar; pass --jar, set TLA2TOOLS, or run the astack statechart skill's install-tlc (TLC ${TLC_PIN})`);
    return 2;
  }
  mkdirSync(args.out, { recursive: true });
  let ok = true;
  for (const id of args.row ? [args.row] : Object.keys(ROWS)) {
    const receipt = produce(id, { root, head: at, java, jar, workers: Number(args.workers ?? 4), log: (m) => console.error(m) });
    const file = resolve(args.out, `${id}.json`);
    writeFileSync(file, JSON.stringify(receipt, null, 2) + "\n");
    console.log(`${id}: ${receipt.pass ? "PASS" : "FAIL"} ${receipt.measured} -> ${file}`);
    ok &&= receipt.pass;
  }
  return ok ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main(process.argv.slice(2)));
