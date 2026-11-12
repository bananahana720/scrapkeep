import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { GRACE_TICKS, MECHANICS, audit, judge, main, parseArgs } from "./first-timer.mjs";

const mechanic = (id) => MECHANICS.find((m) => m.id === id);

// A probe in tools/first_timer.gd's shape, trimmed to what the judge reads.
const probe = (taught, needed, pilot = "runner_gunner") => ({
  tool: "first_timer", seed: 1, pilot, stages: 2, ticks: 10000, tick_hz: 90, stage_reached: 3,
  card: [], taught, needed,
});

test("a lesson on screen before the need passes", () => {
  const p = probe({ "objective:roll_gate": { tick: 100, stage: 1 } }, { reward_offered: { tick: 200, stage: 1 } });
  assert.equal(judge(mechanic("gates"), p).verdict, "ok");
});

test("a lesson within the grace after the need still passes", () => {
  const p = probe({ "objective:break_guard": { tick: 432, stage: 1 } }, { warden_engaged: { tick: 431, stage: 1 } });
  assert.equal(judge(mechanic("warden"), p).verdict, "ok");
});

test("the clamp plate teaches the Warden: it holds the plate from engage until the clamp opens", () => {
  const p = probe(
    { "objective:break_clamp_crews": { tick: 4362, stage: 1 }, "objective:break_guard": { tick: 6186, stage: 1 } },
    { warden_engaged: { tick: 4362, stage: 1 } },
  );
  assert.equal(judge(mechanic("warden"), p).verdict, "ok");
});

test("a lesson after the grace fails a required mechanic", () => {
  const p = probe(
    { "objective:roll_gate": { tick: 200 + GRACE_TICKS + 1, stage: 1 } },
    { reward_offered: { tick: 200, stage: 1 } },
  );
  assert.equal(judge(mechanic("gates"), p).verdict, "late");
  assert.equal(audit([p]).ok, false);
});

test("a required mechanic with no lesson fails", () => {
  const p = probe({}, { stage_entered: { tick: 0, stage: 1 } });
  assert.equal(judge(mechanic("roll"), p).verdict, "never");
  assert.equal(audit([p]).rows.find((r) => r.id === "roll").failed, true);
});

test("the pilot card alone passes but is flagged", () => {
  const p = probe({ "card:smash": { tick: -1, stage: 0 } }, { warden_staggered: { tick: 1410, stage: 1 } });
  const verdict = judge(mechanic("slam"), p);
  assert.equal(verdict.verdict, "card_only");
  assert.equal(audit([p]).rows.find((r) => r.id === "slam").failed, false);
});

test("an optional mechanic used untaught never fails the audit", () => {
  const p = probe({}, { bay_entered: { tick: 50, stage: 1 } });
  assert.equal(judge(mechanic("shop"), p).verdict, "never");
  assert.equal(audit([p]).rows.find((r) => r.id === "shop").failed, false);
});

test("a need the run never reaches is not a miss", () => {
  const p = probe({}, {});
  assert.equal(judge(mechanic("retry"), p).verdict, "not_reached");
  assert.equal(audit([p]).rows.find((r) => r.id === "retry").failed, false);
});

test("one failing pilot fails the mechanic", () => {
  const good = probe({ "screen:run_over": { tick: 11, stage: 1 } }, { dead: { tick: 10, stage: 1 } }, "tally");
  const bad = probe({}, { dead: { tick: 10, stage: 1 } }, "tarn");
  assert.equal(audit([good, bad]).rows.find((r) => r.id === "retry").failed, true);
});

test("--from re-judges saved probes and exits 1 on a miss", async () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "first-timer-"));
  writeFileSync(path.join(dir, "probe-tally-1.json"), JSON.stringify(probe({}, { stage_entered: { tick: 0, stage: 1 } }, "tally")));
  const code = await main([`--from=${dir}`, `--out=${dir}`]);
  assert.equal(code, 1);
  assert.match(readFileSync(path.join(dir, "report.md"), "utf8"), /Roll and steer the ball \*\*FAIL\*\*/);
});

test("parseArgs rejects an unknown pilot", () => {
  assert.throws(() => parseArgs(["--pilots=nobody"]), /unknown pilot/);
  assert.deepEqual(parseArgs(["--pilots=tarn,tally"]).pilots, ["tarn", "tally"]);
});

test("probes play the park table by default, the maps a launched game plays", () => {
  assert.equal(parseArgs([]).table, "park");
  assert.equal(parseArgs(["--table=default"]).table, "default");
});

test("Brindle's park plate teaches the stagger: its phase 1 row is up from the arena's first frame", () => {
  const p = probe(
    { "objective:shoot_magnets": { tick: 39490, stage: 2 } },
    { boss_arena_entered: { tick: 39490, stage: 2 }, boss_staggered: { tick: 40383, stage: 2 } },
  );
  assert.equal(judge(mechanic("boss"), p).verdict, "ok");
});

// HELP-REFRESH (WHATS-LEFT row 8): the seven verbs the help page names each have a row, taught by
// the first-meet tip, and a row that is optional says why.
const HELP_VERBS = { grip: "grip_used", jam: "jam_hit", cast: "cast_started", radio: "radio_live", stake: "relay_met", companion: "companion_full", active: "active_racked" };

test("the seven help verbs each have a row taught by their tip", () => {
  for (const [id, need] of Object.entries(HELP_VERBS)) {
    const row = mechanic(id);
    assert.ok(row, `${id} row`);
    assert.equal(row.need, need);
    assert.deepEqual(row.teach, [`prompt:tip_${id}`]);
    if (row.needed === "optional") assert.ok(row.note && row.note.length > 20, `${id} optional needs a stated reason`);
  }
});

test("a tip on the same tick as the verb's first need passes, one long after fails", () => {
  for (const [id, need] of Object.entries(HELP_VERBS)) {
    const ok = probe({ [`prompt:tip_${id}`]: { tick: 300, stage: 1 } }, { [need]: { tick: 300, stage: 1 } });
    assert.equal(judge(mechanic(id), ok).verdict, "ok", id);
    const late = probe({ [`prompt:tip_${id}`]: { tick: 300 + GRACE_TICKS + 1, stage: 1 } }, { [need]: { tick: 300, stage: 1 } });
    assert.equal(judge(mechanic(id), late).verdict, "late", id);
  }
});

test("the radio dial is optional, with a reason: an untaught dial is listed but fails nothing", () => {
  const row = mechanic("radio");
  assert.equal(row.needed, "optional");
  assert.ok(row.note && row.note.length > 20, "radio states why it is optional");
  const p = probe({}, { radio_live: { tick: 10, stage: 1 } });
  const radio = audit([p]).rows.find((r) => r.id === "radio");
  assert.equal(radio.failed, false);
  assert.equal(judge(row, p).verdict, "never");
});
