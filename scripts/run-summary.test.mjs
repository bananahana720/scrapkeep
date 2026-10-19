import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";

import { defaultLog, readRuns, summarize } from "./run-summary.mjs";

const scripts = path.dirname(fileURLToPath(import.meta.url));
const scratch = mkdtempSync(path.join(tmpdir(), "run-summary-"));
after(() => rmSync(scratch, { recursive: true, force: true }));

const oldRecord = {
  run_id: "1790530056-723432",
  class: "runner_gunner",
  outcome: "abandoned",
  bites: 3,
  smashes: 1,
  stages: [{ stage: 1, ticks_to_warden_engaged: 900, ticks_to_warden_break: 5400 }],
};
const newRecord = {
  run_id: "1790573499-910844",
  class: "runner_gunner",
  table: "slice",
  outcome: "won",
  bites: 4,
  smashes: 2,
  stages: [
    {
      stage: 1,
      ticks_to_warden_engaged: 1800,
      ticks_to_warden_break: 9000,
      posture: { staggers: 2, chunks_lost: 1, glances: 0, fight_ticks: 468 },
      packs: ["fleet", "fleet", "swarm"],
      causes: { wrecking_ball: 8 },
    },
  ],
};

test("an old record prints dashes for what it lacks", () => {
  const line = summarize(oldRecord, 90);
  assert.equal(
    line,
    "2026-09-27 17:27Z | runner_gunner | - | abandoned | stage 1 | engage 10.0s break 60.0s | staggers - chunks - | bites 3 smashes 1 | packs - | causes -",
  );
});

test("a new record prints the table, posture, packs and causes", () => {
  const line = summarize(newRecord, 90);
  assert.equal(
    line,
    "2026-09-28 05:31Z | runner_gunner | slice | won | stage 1 | engage 20.0s break 100.0s | staggers 2 chunks 1 | bites 4 smashes 2 | packs fleetx2,swarmx1 | causes wrecking_ballx8",
  );
});

test("wave 13 pack rows print the faction with its kinds", () => {
  const stages = [{ ...newRecord.stages[0], packs: [
    { faction: "fleet", kinds: ["chaser", "lobber"] },
    { faction: "fleet", kinds: ["chaser", "lobber"] },
    { faction: "swarm", kinds: [] },
  ] }];
  const line = summarize({ ...newRecord, stages }, 90);
  assert.match(line, /\| packs fleet\[chaser\+lobber\]x2,swarmx1 \|/);
});

test("the last line of a run is the run, and the CLI reads both kinds", () => {
  const early = { ...newRecord, outcome: "running" };
  const text = [oldRecord, early, newRecord].map((one) => JSON.stringify(one)).join("\n");
  assert.equal(readRuns(text).length, 2);
  const file = path.join(scratch, "runs.ndjson");
  writeFileSync(file, text + "\n");
  const result = spawnSync(process.execPath, [path.join(scripts, "run-summary.mjs"), "--file", file, "--last", "1"], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  const lines = result.stdout.trim().split("\n");
  assert.equal(lines[0], `# ${file}`);
  assert.equal(lines.length, 2);
  assert.match(lines[1], /\| won \|/);
});

test("defaultLog follows the custom user dir, so the Scrapkeep rename still finds the saves", () => {
  assert.equal(defaultLog({ XDG_DATA_HOME: "/d" }, "/h"), "/d/godot/app_userdata/core-loop/runs.ndjson");
  assert.equal(defaultLog({}, "/h"), "/h/.local/share/godot/app_userdata/core-loop/runs.ndjson");
});
