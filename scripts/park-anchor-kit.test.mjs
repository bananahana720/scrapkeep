import assert from "node:assert/strict";
import test from "node:test";
import { kitFor, swap } from "./park-anchor-kit.mjs";

test("kitFor reads the row id before the landform", () => {
  assert.equal(kitFor({ id: "lookout_cairn_1", landform: "mesa_rim" }), "anchor_cairn");
  assert.equal(kitFor({ id: "net_posts_3", landform: "sky_island" }), "anchor_timber");
  assert.equal(kitFor({ id: "east_plateau_spatter", landform: "hoodoo_field" }), "anchor_basalt");
  assert.equal(kitFor({ id: "sentinel_4", landform: "hoodoo_field" }), "anchor_hoodoo");
  assert.equal(kitFor({ id: "east_drift_post_1i", landform: "adit" }), "anchor_timber");
  assert.equal(kitFor({ id: "isle_post_1", landform: "sky_island" }), "anchor_cairn");
  assert.equal(kitFor({ id: "mastery_rock", landform: "hoodoo_field" }), "anchor_hoodoo");
  assert.equal(kitFor({ id: "signal_masts", landform: "mesa_rim" }), "anchor_timber");
  assert.throws(() => kitFor({ id: "x", landform: "glacier" }), /no anchors kit/);
});

test("swap rewrites only greybox anchor field recipes, on their own lines, and is idempotent", () => {
  const text = [
    "{",
    ' "park_rows": [',
    '  {"id": "saguaro_1", "element": "anchor_field", "landform": "saguaro_stand", "recipe": "greybox:anchor_field"},',
    '  {"id": "bank_1", "element": "bank", "landform": "slickrock", "recipe": "greybox:bank"},',
    '  {"id": "hoodoo_1", "element": "anchor_field", "landform": "hoodoo_field", "recipe": "greybox:anchor_field"}',
    " ]",
    "}",
  ].join("\n");
  const once = swap(text);
  assert.deepEqual(once.counts, { anchor_saguaro: 1, anchor_hoodoo: 1 });
  const rows = JSON.parse(once.text).park_rows.map((r) => r.recipe);
  assert.deepEqual(rows, ["anchor_saguaro", "greybox:bank", "anchor_hoodoo"]);
  assert.deepEqual(swap(once.text).counts, {});
});
