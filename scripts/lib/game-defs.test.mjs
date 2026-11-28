import assert from "node:assert/strict";
import test from "node:test";
import {
  ALPHA_MAPS,
  PARK_MAPS,
  PILOT_IDS,
  WORLD1_MAPS,
  loadGameDefs,
  parsePilotIds,
  parseStageDefs,
} from "./game-defs.mjs";

test("game-defs parses canonical pilot, park, world 1, and alpha map IDs in exact order", () => {
  assert.deepEqual(PILOT_IDS, [
    "pylon_engineer",
    "runner_gunner",
    "demolitions_caster",
    "tarn",
    "tally",
    "remembered_cannon",
  ]);
  assert.deepEqual(PARK_MAPS, [
    "park_dam",
    "park_flume",
    "park_pit",
    "park_sinkhole",
    "park_islands",
    "park_crown",
  ]);
  assert.deepEqual(WORLD1_MAPS, ["park_dam", "park_flume"]);
  assert.deepEqual(ALPHA_MAPS, [
    "spillway",
    "reach",
    "dig",
    "dig_deep",
    "highdraft",
    "highdraft_crown",
  ]);
  const reloaded = loadGameDefs();
  assert.equal(reloaded.parkStages.length, 6);
  assert.equal(reloaded.alphaStages.length, 6);
});

test("game-defs parsers throw loudly on empty or malformed GDScript sources", () => {
  assert.throws(() => parsePilotIds("extends Resource\n"), /parsed 0 pilot IDs/);
  assert.throws(() => parseStageDefs("extends RefCounted\n"), /could not find const DEFS/);
  assert.throws(() => parseStageDefs("const DEFS := [\n]\n"), /parsed 0 stage defs/);
});
