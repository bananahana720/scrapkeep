#!/usr/bin/env node
import { readFileSync, realpathSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { cleanHead, root } from "./clean-head.mjs";
import { runAlone } from "./solo-run.mjs";

export const TEST = "prim_census_test";
export const PINNED_SURFACES = 77;
export const PLANT_ENV = { PRIM_PLANT: "dam_box" };
export const PLANT_NAME = "PlantedStandIn";
export const PIN = "sketches/core-loop/tools/prim_census_pin.tsv";
const CITE = /project-guide\/handoff\/DECISIONS\.md:\d+/;
const WAIT_ROW = /\bruling [a-z]{1,3}\b/;
export const NOT_SEEN =
  "what is not judged: one seed, one pilot and one table, so a surface the run never builds is not seen, a second primitive under a key already pinned is not seen, and a model that does exist says nothing about how it looks";

const summaryOf = (text) => {
  const line = String(text ?? "")
    .split("\n")
    .find((l) => l.startsWith("SUMMARY {"));
  try {
    return line ? JSON.parse(line.slice("SUMMARY ".length)) : null;
  } catch {
    return null;
  }
};
const verdictLine = (text) =>
  String(text ?? "")
    .split("\n")
    .find((l) => l.startsWith(`${TEST}: `)) ?? "";
const named = (r) => `${r.shape} in ${r.file} (${r.mesh}${r.row ? `, owed by ${r.row}` : ""})`;

export function waitingFromPin(text) {
  return String(text)
    .split("\n")
    .filter((l) => l.trim() && !l.startsWith("#"))
    .map((l) => l.split("\t"))
    .filter((c) => c.length >= 6 && c[3].startsWith("stand-in") && WAIT_ROW.test(c[5]))
    .map((c) => ({
      key: `${c[0]}|${c[1]}|${c[2]}`,
      row: c[4],
      cite: (c[5].match(CITE) ?? [""])[0],
    }));
}

const STAGE_CHECK = "[the bot played through Brindle into stage 3]";

export function buildReceipt(run, plant, head, { waiting = [] } = {}) {
  const s = summaryOf(run.log);
  const p = summaryOf(plant.log);
  const lines = String(run.log ?? "").split("\n");
  const failed = lines.filter((l) => l.endsWith("-> FAIL"));
  const reached = lines.some((l) => l.startsWith(STAGE_CHECK) && l.endsWith("-> PASS"));
  const clean = Boolean(s) && s.plant === "";
  const counted =
    Boolean(s) &&
    Number.isInteger(s.surfaces) &&
    s.pinned === PINNED_SURFACES &&
    s.surfaces >= PINNED_SURFACES;
  const waits = (r) => waiting.find((w) => w.cite && w.key === `${r.file}|${r.mesh}|${r.shape}`);
  const held = (s?.stand_ins ?? []).filter(waits);
  const standIns = (s?.stand_ins ?? []).filter((r) => !waits(r));
  const fresh = s?.new ?? [];
  const stale = s?.stale ?? [];
  const caught =
    Boolean(p) &&
    !plant.ok &&
    p.plant === PLANT_ENV.PRIM_PLANT &&
    verdictLine(plant.log).includes("FAIL") &&
    (p.new ?? []).some((r) => String(r.shape).endsWith(`/${PLANT_NAME}`)) &&
    !fresh.some((r) => String(r.shape).endsWith(`/${PLANT_NAME}`));
  const pass =
    run.ok &&
    failed.length === 0 &&
    reached &&
    clean &&
    counted &&
    standIns.length === 0 &&
    fresh.length === 0 &&
    stale.length === 0 &&
    caught &&
    verdictLine(run.log).startsWith(`${TEST}: PASS`);
  let measured;
  if (!s)
    measured = `no SUMMARY line, so nothing was counted: ${(failed[0] ?? verdictLine(run.log) ?? "").slice(0, 200) || "the test did not finish"}`;
  else if (!clean)
    measured = `the counting run ran planted (${s.plant}): a plant switch reached the run that counts`;
  else if (!counted)
    measured = `the census counted ${s.surfaces} primitive surfaces, pinned at least ${PINNED_SURFACES} (test pin ${s.pinned}): the run built less than it should`;
  else if (!reached)
    measured = `the bot did not reach stage 3, so the flume and Brindle were not all built: ${(lines.find((l) => l.startsWith(STAGE_CHECK)) ?? "no stage line").slice(-160)}`;
  else {
    const parts = [
      `${s.surfaces} primitive surfaces counted over one bot run through the dam, the flume and Brindle`,
    ];
    parts.push(
      standIns.length
        ? `${standIns.length} code-built stand-in(s) left: ${standIns.map(named).join("; ")}`
        : held.length
          ? "no code-built stand-in left but those ruled to wait"
          : "no code-built stand-in left",
    );
    if (fresh.length)
      parts.push(
        `${fresh.length} new primitive(s) no pin row covers: ${fresh.map(named).join("; ")}`,
      );
    if (stale.length)
      parts.push(
        `${stale.length} stale stand-in row(s): ${stale.map((r) => `pin line ${r.line} ${r.file}|${r.mesh}|${r.shape} (${r.row})`).join("; ")}`,
      );
    if (held.length)
      parts.push(`waiting: ${held.map((r) => `${named(r)} (${waits(r).cite})`).join("; ")}`);
    if (!run.ok)
      parts.push(
        `the runner did not pass the test (${run.exit ?? "no exit"}), so its census is not trusted`,
      );
    if (failed.length) parts.push(`${failed.length} check(s) failed: ${failed[0].slice(0, 160)}`);
    measured = parts.join("; ");
  }
  if (p)
    measured += `; plant: with the control box judged as real (PRIM_PLANT=dam_box) the test ${plant.ok ? "still passed" : caught ? "failed and named it new" : "failed but did not name the box"}`;
  else measured += "; plant: the planted run printed no SUMMARY";
  measured += `; ${NOT_SEEN}`;
  return { head, pass, measured, plant_caught: caught };
}

export function produce({ cwd = root, run = runAlone } = {}) {
  const head = cleanHead(cwd);
  const main = run(cwd, TEST);
  const plant = run(cwd, TEST, PLANT_ENV);
  let pin = "";
  try {
    pin = readFileSync(path.join(cwd, PIN), "utf8");
  } catch {}
  return buildReceipt(main, plant, head, { waiting: waitingFromPin(pin) });
}

function produceAll() {
  const ride = produce();
  const measure = (plant) => {
    const run = runAlone(root, TEST, {
      PRIM_SCOPE: "all",
      ...(plant ? { PRIM_PLANT: plant } : {}),
    });
    const line = run.log.split("\n").find((l) => l.startsWith("AREAS "));
    return { run, scope: line ? JSON.parse(line.slice(6)) : null };
  };
  const base = measure("");
  const planted = measure("camp_box");
  const campBox = (hit) =>
    hit.area === "camp" && hit.mesh === "BoxMesh" && hit.path.endsWith("/PlantedCampBox");
  const caught =
    base.run.ok &&
    base.scope?.plant === "" &&
    !base.scope.findings.some(campBox) &&
    !planted.run.ok &&
    planted.scope?.plant === "camp_box" &&
    planted.scope.findings.some(campBox) &&
    verdictLine(planted.run.log).startsWith(TEST + ": FAIL (1 of ") &&
    planted.run.log
      .split("\n")
      .some((l) => l.startsWith("[camp has no planted box]") && l.endsWith("-> FAIL"));
  const findings = base.scope?.findings ?? [];
  const waiting = waitingFromPin(readFileSync(path.join(root, PIN), "utf8"));
  const unlisted = new Set();
  for (const hit of findings) {
    const key = `${hit.file}|${hit.mesh}|${hit.shape}`;
    if (!waiting.some((w) => w.cite && w.key === key)) unlisted.add(key);
  }
  if (cleanHead(root) !== ride.head) throw new Error("checkout changed during the census");
  return {
    head: ride.head,
    pass: Boolean(ride.pass && caught && unlisted.size === 0),
    measured: base.scope
      ? `${Object.keys(base.scope.areas).length} stations, ${unlisted.size} distinct unlisted primitive keys`
      : "area run did not finish",
    areas: base.scope?.areas ?? {},
    findings,
    unlisted_stand_ins: base.scope ? unlisted.size : null,
    ride,
    camp_plant_caught: Boolean(caught),
    plant_caught: Boolean(ride.plant_caught && caught),
  };
}

function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--scope=all") args.all = true;
    else if (argv[i] === "--out" && argv[i + 1]) args.out = argv[++i];
    else {
      console.error("usage: stand-ins-receipt.mjs [--scope=all] [--out file]");
      return 2;
    }
  }
  let receipt;
  try {
    receipt = args.all ? produceAll() : produce();
  } catch (e) {
    console.error(String(e.message ?? e));
    return 2;
  }
  const text = JSON.stringify(receipt, null, 2) + "\n";
  if (args.out) writeFileSync(args.out, text);
  else process.stdout.write(text);
  return receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url))
  process.exit(main(process.argv.slice(2)));
