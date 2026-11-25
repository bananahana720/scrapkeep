#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SKETCH = path.join(ROOT, "sketches/core-loop");
export const PRINCIPLES = path.join(SKETCH, "design-v3/ui-audit/principles.json");
export const LEDGER = path.join(ROOT, "project-guide/handoff/UI-FINDINGS.tsv");
export const COLUMNS = [
  "id",
  "principle",
  "class",
  "where",
  "finding",
  "evidence",
  "state",
  "guard",
  "added",
];
export const STATES = ["open", "fixed", "accepted"];
const KINDS = ["test", "lint", "capture", "review"];
export const REPEAT = 2;

const defaults = {
  test: (ref) => /^\w+_test\.gd$/.test(ref) && existsSync(path.join(SKETCH, "tests", ref)),
  capture: (ref) => /^\w+\.(gd|py)$/.test(ref) && existsSync(path.join(SKETCH, "tools", ref)),
  lint: (ref) =>
    Object.hasOwn(JSON.parse(readFileSync(path.join(ROOT, "package.json"), "utf8")).scripts, ref),
  read: (ref) =>
    /^\w+_test\.gd$/.test(ref) && existsSync(path.join(SKETCH, "tests", ref))
      ? readFileSync(path.join(SKETCH, "tests", ref), "utf8")
      : "",
};

export function checkPrinciples(list, has = defaults) {
  const errors = [];
  const seen = new Set();
  for (const p of list) {
    const at = p.id ?? "(no id)";
    if (!/^P\d+$/.test(p.id ?? "") || seen.has(p.id))
      errors.push(`${at}: the id is missing, malformed or used twice`);
    seen.add(p.id);
    for (const field of ["name", "rule", "source"])
      if (!p[field]) errors.push(`${at}: no ${field}`);
    if (!["established", "inferred"].includes(p.standing))
      errors.push(`${at}: standing is "${p.standing}", not established or inferred`);
    const checks = p.checks ?? [];
    for (const c of checks) {
      if (!KINDS.includes(c.kind))
        errors.push(`${at}: check kind "${c.kind}" is not one of ${KINDS.join(", ")}`);
      else if (c.kind !== "review" && !has[c.kind](c.ref))
        errors.push(`${at}: ${c.kind} "${c.ref}" does not exist`);
    }
    if (!checks.some((c) => c.kind === "test" || c.kind === "lint") && !p.gap)
      errors.push(`${at}: no automatic check and no gap named`);
  }
  return errors;
}

export function parseLedger(text) {
  const [head, ...lines] = text.split("\n").filter((line) => line.trim() !== "");
  if (head !== COLUMNS.join("\t"))
    throw new Error(`the ledger's header is not ${COLUMNS.join(", ")}`);
  return lines.map((line, i) => {
    const cells = line.split("\t");
    if (cells.length !== COLUMNS.length)
      throw new Error(`ledger row ${i + 1} has ${cells.length} cells, not ${COLUMNS.length}`);
    return Object.fromEntries(COLUMNS.map((name, k) => [name, cells[k]]));
  });
}

const guardExists = (guard, has) => has.test(guard) || has.capture(guard) || has.lint(guard);

export function checkLedger(rows, principles, has = defaults) {
  const errors = [];
  const ids = new Set(principles.map((p) => p.id));
  const seen = new Set();
  const byClass = new Map();
  for (const row of rows) {
    if (!/^UF-\d+$/.test(row.id) || seen.has(row.id))
      errors.push(`${row.id}: the id is malformed or used twice`);
    seen.add(row.id);
    if (!ids.has(row.principle))
      errors.push(`${row.id}: principle "${row.principle}" is not in the list`);
    if (!STATES.includes(row.state))
      errors.push(`${row.id}: state "${row.state}" is not one of ${STATES.join(", ")}`);
    if (!/^[a-z][a-z-]*$/.test(row.class))
      errors.push(`${row.id}: class "${row.class}" is not a short lower-case name`);
    for (const field of ["where", "finding", "evidence"])
      if (!row[field]) errors.push(`${row.id}: no ${field}`);
    if (row.guard && !guardExists(row.guard, has))
      errors.push(`${row.id}: guard "${row.guard}" does not exist`);
    byClass.set(row.class, [...(byClass.get(row.class) ?? []), row]);
  }
  for (const guard of new Set(rows.map((row) => row.guard).filter(Boolean))) {
    for (const id of new Set((has.read?.(guard) ?? "").match(/\bUF-\d+\b/g) ?? [])) {
      if (!seen.has(id)) errors.push(`${guard} names ${id}, which is not a ledger row`);
    }
  }
  for (const [name, group] of byClass) {
    if (group.length >= REPEAT && !group.some((row) => row.guard)) {
      errors.push(
        `lesson owed: "${name}" has been found ${group.length} times (${group.map((row) => row.id).join(", ")}) and no row names a guard. Write the test or lint that fails on it and name it in the guard column`,
      );
    }
  }
  return errors;
}

export function ingest(files) {
  const map = {
    small: ["P7", "small-target"],
    unnamed: ["P6", "unnamed-control"],
    "off-edge": ["P4", "off-edge"],
  };
  const out = [];
  for (const [name, text] of files) {
    for (const line of text.split("\n").filter(Boolean)) {
      if (!map[line.split(" ")[0]]) continue;
      const [principle, cls] = map[line.split(" ")[0]];
      out.push({ principle, class: cls, where: name.replace(/\.audit\.txt$/, ""), finding: line });
    }
  }
  return out;
}

export function readResults(receipt) {
  const results = new Map();
  for (const result of receipt.results ?? []) {
    const name = /res:\/\/tests\/([\w.]+\.gd)/.exec(result.label ?? "")?.[1];
    if (name)
      results.set(name, result.ok ? "pass" : result.quarantined ? "quarantined red" : "fail");
  }
  return results;
}

function runTests(principles) {
  const tests = [
    ...new Set(
      principles.flatMap((p) => p.checks.filter((c) => c.kind === "test").map((c) => c.ref)),
    ),
  ];
  const args = [
    path.join(ROOT, "scripts/sketch-smoke.mjs"),
    "--sketch",
    "core-loop",
    "--receipt",
    "ui-audit",
    ...tests.flatMap((ref) => ["--test", ref]),
  ];
  const run = spawnSync(process.execPath, args, {
    cwd: ROOT,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
    maxBuffer: 1 << 28,
  });
  process.stderr.write(run.stdout ?? "");
  const file = /^receipt (.+)$/m.exec(run.stdout ?? "")?.[1];
  const results = file ? readResults(JSON.parse(readFileSync(file, "utf8"))) : new Map();
  for (const ref of tests) if (!results.has(ref)) results.set(ref, "did not run");
  const smoke =
    run.status === 0 && file
      ? ""
      : `sketch:smoke ${run.error ? `did not start (${run.error.message})` : `exited ${run.status ?? run.signal}`}${file ? "" : " and wrote no receipt"}; read its output above`;
  return { results, smoke };
}

export function report(principles, rows, results = new Map()) {
  return principles.map((p) => {
    const tests = p.checks.filter((c) => c.kind === "test").map((c) => c.ref);
    const ran = tests.filter((ref) => results.has(ref));
    const red = ran.filter(
      (ref) => results.get(ref) !== "pass" && results.get(ref) !== "quarantined red",
    );
    const quarantined = ran.filter((ref) => results.get(ref) === "quarantined red");
    const open = rows
      .filter((row) => row.principle === p.id && row.state === "open")
      .map((row) => row.id);
    const held = p.gap ? (tests.length ? "partly" : "gap") : "held";
    return {
      id: p.id,
      name: p.name,
      standing: p.standing,
      held,
      tests: tests.length,
      ran: ran.length,
      red,
      quarantined,
      open,
      gap: p.gap ?? "",
    };
  });
}

function main(argv) {
  const principles = JSON.parse(readFileSync(PRINCIPLES, "utf8")).principles;
  if (argv.includes("--ingest")) {
    const dir = argv[argv.indexOf("--ingest") + 1];
    const files = readdirSync(dir)
      .filter((f) => f.endsWith(".audit.txt"))
      .map((f) => [f, readFileSync(path.join(dir, f), "utf8")]);
    for (const c of ingest(files))
      console.log([c.principle, c.class, c.where, c.finding].join("\t"));
    return 0;
  }
  const rows = parseLedger(readFileSync(LEDGER, "utf8"));
  const errors = [...checkPrinciples(principles), ...checkLedger(rows, principles)];
  const { results, smoke } = argv.includes("--run")
    ? runTests(principles)
    : { results: new Map(), smoke: "" };
  if (smoke) errors.push(smoke);
  const lines = report(principles, rows, results);
  if (argv.includes("--json")) console.log(JSON.stringify({ principles: lines, errors }, null, 2));
  else {
    for (const l of lines) {
      const ran = results.size
        ? `${l.ran - l.red.length - l.quarantined.length}/${l.tests} tests pass`
        : `${l.tests} tests`;
      console.log(
        `${l.id.padEnd(4)}${l.held.padEnd(7)}${ran.padEnd(18)}${l.name}${l.open.length ? `  open: ${l.open.join(", ")}` : ""}${l.red.length ? `  RED: ${l.red.join(", ")}` : ""}${l.quarantined.length ? `  quarantined red: ${l.quarantined.join(", ")}` : ""}`,
      );
    }
    for (const e of errors) console.error(`ui-audit: ${e}`);
  }
  const red = lines.some((l) => l.red.length > 0);
  console.log(
    errors.length || red
      ? "ui-audit: FAIL"
      : `ui-audit: PASS (${principles.length} principles, ${rows.length} ledger rows)`,
  );
  return errors.length || red ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  process.exit(main(process.argv.slice(2)));
