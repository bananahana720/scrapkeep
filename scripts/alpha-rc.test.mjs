// Rules: ambition-map RC-GATE. Missing inputs read "not run", never pass; GO only when every step passed.
import assert from "node:assert/strict";
import { chmodSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  MENU_READY,
  STEP_IDS,
  buildPlan,
  judgeCommand,
  judgeRedteam,
  launchAppImage,
  parseArgs,
  runAlphaRc,
  verdict,
} from "./alpha-rc.mjs";

const tmp = () => mkdtempSync(path.join(os.tmpdir(), "alpha-rc-test-"));
const head = "79161558ad10650a38fae04d95908db003d59097";
const findings = (extra = {}) => ({ wave: 21, commit: head, runs: [], findings: [], carry: [], ...extra });

function inputs() {
  const dir = tmp();
  const capture = path.join(dir, "capture.csv");
  const redteam = path.join(dir, "findings.json");
  const appimage = path.join(dir, "Scrapkeep.AppImage");
  writeFileSync(capture, "fps,frametime\n");
  writeFileSync(redteam, JSON.stringify(findings()));
  writeFileSync(appimage, "");
  return { dir, capture, redteam, appimage };
}

const allPass = { run: async () => ({ exit: 0, output: "[]" }), launch: async () => ({ status: "pass", note: "menu", ms: 900, output: "" }), log: () => {} };

test("parseArgs rejects unknown flags and unknown skip ids", () => {
  assert.throws(() => parseArgs(["--nope"]), /unknown argument/);
  assert.throws(() => parseArgs(["--skip=smoke,fly"]), /unknown step fly/);
  assert.deepEqual([...parseArgs(["--skip=smoke,bots"]).skip], ["smoke", "bots"]);
  assert.equal(parseArgs([], { HOME: "/h" }).appimage, "/h/.local/share/scrapkeep/Scrapkeep.AppImage");
});

test("the plan runs every gate in order and swaps the cloud export under --cloud", () => {
  const plan = buildPlan(parseArgs([], { HOME: "/nowhere" }));
  assert.deepEqual(plan.map((s) => s.id), STEP_IDS);
  assert.match(plan[3].args[0], /sketch-export\.mjs$/);
  assert.match(buildPlan(parseArgs(["--cloud"], { HOME: "/nowhere" }))[3].args[0], /cloud\/export-headless\.mjs$/);
});

test("with no inputs, frame time, red team and launch read not run, and the verdict is never GO", async () => {
  const args = parseArgs([], { HOME: tmp() });
  const { results, outcome, page } = await runAlphaRc(args, { ...allPass, head });
  const byId = Object.fromEntries(results.map((r) => [r.id, r.status]));
  assert.deepEqual(byId, { placeholders: "pass", smoke: "pass", bots: "pass", export: "pass", frametime: "not run", redteam: "not run", launch: "not run" });
  assert.equal(outcome.verdict, "INCOMPLETE");
  assert.equal(outcome.exit, 2);
  assert.match(page, /⬜ not run \| no --capture/);
});

test("every step green gives GO and writes RC.md and rc.json", async () => {
  const { capture, redteam, appimage, dir } = inputs();
  const outDir = path.join(dir, "out");
  const args = parseArgs([`--capture=${capture}`, `--redteam=${redteam}`, `--appimage=${appimage}`]);
  const { outcome } = await runAlphaRc(args, { ...allPass, head, outDir });
  assert.equal(outcome.verdict, "GO");
  assert.equal(outcome.exit, 0);
  assert.match(readFileSync(path.join(outDir, "RC.md"), "utf8"), /^# Release candidate: GO/);
  assert.equal(JSON.parse(readFileSync(path.join(outDir, "rc.json"), "utf8")).results.length, 7);
});

test("a cloud run that passes everything is only a rehearsal", async () => {
  const { capture, redteam, appimage } = inputs();
  const args = parseArgs(["--cloud", `--capture=${capture}`, `--redteam=${redteam}`, `--appimage=${appimage}`]);
  const { outcome } = await runAlphaRc(args, { ...allPass, head });
  assert.deepEqual(outcome, { verdict: "REHEARSAL PASSED", exit: 2 });
});

test("one failing step makes it NO-GO and the page carries its last lines", async () => {
  const { capture, redteam, appimage } = inputs();
  const args = parseArgs([`--capture=${capture}`, `--redteam=${redteam}`, `--appimage=${appimage}`]);
  const run = async (step) => (step.id === "bots" ? { exit: 1, output: "FAIL bot skipper seed 3: boss_stalled" } : { exit: 0, output: "[]" });
  const { outcome, page } = await runAlphaRc(args, { ...allPass, run, head });
  assert.equal(outcome.verdict, "NO-GO");
  assert.equal(outcome.exit, 1);
  assert.match(page, /boss_stalled/);
});

test("--skip turns a step into not run", async () => {
  const { capture, redteam, appimage } = inputs();
  const args = parseArgs([`--capture=${capture}`, `--redteam=${redteam}`, `--appimage=${appimage}`, "--skip=export"]);
  const { results } = await runAlphaRc(args, { ...allPass, head });
  assert.deepEqual(results.find((r) => r.id === "export"), { id: "export", label: "Export proofs", criterion: "the shipped pack wins", status: "not run", note: "skipped with --skip", ms: null });
});

test("sub-command exits are read in each tool's terms", () => {
  assert.deepEqual(judgeCommand({ id: "placeholders" }, { exit: 1, output: '[{"kind":"park"},{"kind":"icon"}]' }), { status: "fail", note: "2 placeholders" });
  assert.equal(judgeCommand({ id: "frametime" }, { exit: 2, output: "" }).status, "not run");
  assert.equal(judgeCommand({ id: "frametime" }, { exit: 1, output: "" }).status, "fail");
  assert.equal(judgeCommand({ id: "smoke" }, { exit: null, output: "" }).note, "timed out or killed");
  assert.equal(judgeCommand({ id: "smoke" }, { exit: null, output: "", error: "ENOENT" }).status, "fail");
});

test("red team: a blocker fails, a stale commit is not run, and an unreplayed carry fails", () => {
  assert.equal(judgeRedteam(findings({ findings: [{ severity: "major" }] }), head).status, "pass");
  assert.match(judgeRedteam(findings({ findings: [{ severity: "blocker", title: "Brindle stalls" }] }), head).note, /Brindle stalls/);
  assert.equal(judgeRedteam(findings({ commit: "cf63e622" }), head).status, "not run");
  const previous = { carry: [{ pilot: "tally", seed: 2506, title: "stall" }] };
  assert.equal(judgeRedteam(findings(), head, previous).status, "fail");
  const replayed = findings({ runs: [{ id: "carry-0-first-timer-tally-2506", pilot: "tally", seed: 2506 }] });
  assert.equal(judgeRedteam(replayed, head, previous).status, "pass");
});

test("the real w15 findings read as zero blockers", { skip: !process.env.SCRAPKEEP_W15_FINDINGS }, () => {
  const w15 = JSON.parse(readFileSync(process.env.SCRAPKEEP_W15_FINDINGS, "utf8"));
  assert.equal(judgeRedteam(w15, w15.commit).status, "pass");
});

test("cold launch passes on the menu-ready line, fails on an early exit or silence, with a fresh profile", async () => {
  const dir = tmp();
  const fake = (name, body) => {
    const file = path.join(dir, name);
    writeFileSync(file, `#!/bin/sh\n${body}\n`);
    chmodSync(file, 0o755);
    return file;
  };
  const ready = fake("ready.sh", `echo "home=$HOME"; echo "${MENU_READY} ms=800"; sleep 30`);
  const pass = await launchAppImage(ready, { seconds: 5 });
  assert.equal(pass.status, "pass");
  assert.match(pass.output, /home=.*scrapkeep-rc-home-/);
  assert.notEqual(pass.output.match(/home=(\S+)/)[1], os.homedir());
  assert.equal((await launchAppImage(fake("crash.sh", "exit 3"), { seconds: 5 })).status, "fail");
  const silent = await launchAppImage(fake("silent.sh", "sleep 30"), { seconds: 0.5 });
  assert.match(silent.note, /no SCRAPKEEP_MENU_READY line within 0.5 s/);
});

test("verdict order: any fail beats not run", () => {
  assert.equal(verdict([{ status: "fail" }, { status: "not run" }]).verdict, "NO-GO");
  assert.equal(verdict([{ status: "pass" }]).verdict, "GO");
});
