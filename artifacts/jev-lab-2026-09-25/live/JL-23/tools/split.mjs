// Merges labelled batches into the dev set and the check set as assigned in the
// mutation files, and records the check set's sha256 before any Jev call.
// - A check that fails on the unmodified scratch copy (baseline) cannot be
//   labelled there, so it is removed from that universe's list in every case.
// - A case whose import pass failed, or where no check failed, has no first
//   failing check to rank and is dropped.
// - The control pair is recomputed after that filter by the same rule as
//   label.mjs: the first failing check that directly loads a changed file, and
//   the first passing check that loads none.
// usage: node split.mjs <baseline labelled.json> <out-dir> <labelled.json>...
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const [baselineFile, out, ...files] = process.argv.slice(2);
const baseline = JSON.parse(readFileSync(baselineFile, "utf8"));
const broken = Object.fromEntries(baseline.map((b) => [b.universe, new Set(b.failing)]));
const labelled = files.flatMap((f) => JSON.parse(readFileSync(f, "utf8")));

function pickControl(tests, changed, failing) {
  const touched = new Set(changed);
  const imports = (t) => touched.has(t.file ?? t.id) || t.refs.some((r) => touched.has(r));
  const x = tests.find((t) => failing.includes(t.id) && imports(t));
  const y = tests.find((t) => !failing.includes(t.id) && !imports(t));
  return x && y ? { imports: x.id, not: y.id } : undefined;
}

const keep = [];
const dropped = [];
for (const raw of labelled) {
  const skip = broken[raw.universe] ?? new Set();
  const tests = raw.tests.filter((t) => !skip.has(t.id));
  const failing = raw.failing.filter((id) => !skip.has(id));
  const durations = Object.fromEntries(Object.entries(raw.durations).filter(([id]) => !skip.has(id)));
  const item = { ...raw, tests, failing, durations, removed_for_baseline: [...skip] };
  item.control = pickControl(tests, item.changed, failing);
  if (!item.import_ok) dropped.push({ id: item.id, set: item.set, reason: "import pass failed" });
  else if (failing.length === 0) dropped.push({ id: item.id, set: item.set, reason: "no check failed" });
  else keep.push(item);
}
const strip = ({ set, import_ok, ...rest }) => rest;
const write = (name, role, items) => {
  const body = `${JSON.stringify({ role, labelled_by: "execution of the real checks on a scratch copy (tools/label.mjs); checks failing on the unmodified copy removed (tools/split.mjs)", cases: items.map(strip) }, null, 2)}\n`;
  writeFileSync(path.join(out, name), body);
  return createHash("sha256").update(body).digest("hex");
};
const devItems = keep.filter((i) => i.set === "cases");
const checkItems = keep.filter((i) => i.set === "check");
const dev = write("dev-set.json", "authored", devItems);
const check = write("check-set.json", "check", checkItems);
writeFileSync(path.join(out, "dropped.json"), `${JSON.stringify(dropped, null, 2)}\n`);
const stamp = new Date().toISOString();
writeFileSync(
  path.join(out, "check-set-frozen.sha256"),
  `${check}  check-set.json\n# frozen ${stamp}, before any Jev call for JL-23; never edited after\n# dev-set.json ${dev}\n`,
);
for (const [name, items, digest] of [["dev", devItems, dev], ["check", checkItems, check]]) {
  console.log(`${name}: ${items.length} cases (${items.filter((i) => i.universe === "godot").length} godot, ${items.filter((i) => i.universe === "node").length} node), ${items.filter((i) => i.control).length} with a control, sha256 ${digest}`);
}
console.log(`frozen ${stamp}`);
console.log(`dropped ${dropped.map((d) => `${d.id}[${d.set}]: ${d.reason}`).join("; ")}`);
