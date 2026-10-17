import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// node scripts/park-anchor-kit.mjs [--check]: moves every `greybox:anchor_field` row of the six park maps onto its
// anchors kit recipe (park_recipes.gd ANCHOR_KITS, tools/blender/park/anchors.py). It rewrites only the recipe value on
// each row's own line, so after a merge conflict in a park map, take the other side and run it again. --check rewrites
// nothing and fails while a row is left.
// The family comes from the row id first (what the row is named for), then its landform (anchors.py's docstring).

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const PARKS = ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"];
export const GREY = "greybox:anchor_field";

export const BY_ID = [
  [/cairn/, "anchor_cairn"],
  [/net_post|mast|boom|truss|trestle|pier|fire_lookout/, "anchor_timber"],
  [/spatter|basalt/, "anchor_basalt"],
];

export const BY_LANDFORM = {
  hoodoo_field: "anchor_hoodoo",
  slickrock: "anchor_hoodoo",
  butte: "anchor_hoodoo",
  spire: "anchor_hoodoo",
  mesa_rim: "anchor_hoodoo",
  lava_tube: "anchor_basalt",
  sinkhole: "anchor_basalt",
  cenote_pool: "anchor_basalt",
  adit: "anchor_timber",
  flume: "anchor_timber",
  penstock: "anchor_timber",
  dam_face: "anchor_timber",
  cliff_dwelling: "anchor_timber",
  saguaro_stand: "anchor_saguaro",
  sky_island: "anchor_cairn",
};

export function kitFor(row) {
  for (const [pattern, kit] of BY_ID) if (pattern.test(row.id)) return kit;
  const kit = BY_LANDFORM[row.landform];
  if (!kit) throw new Error(`anchor field ${row.id}: no anchors kit for landform ${row.landform}`);
  return kit;
}

// The map's text with each greybox anchor field's recipe swapped, and the swaps by kit.
export function swap(text) {
  const counts = {};
  const out = text
    .split("\n")
    .map((line) => {
      if (!line.includes(`"recipe": "${GREY}"`)) return line;
      const row = JSON.parse(line.trim().replace(/,$/, ""));
      const kit = kitFor(row);
      counts[kit] = (counts[kit] ?? 0) + 1;
      return line.replace(`"recipe": "${GREY}"`, `"recipe": "${kit}"`);
    })
    .join("\n");
  return { text: out, counts };
}

function main() {
  const check = process.argv.includes("--check");
  let left = 0;
  for (const map of PARKS) {
    const file = path.join(root, "sketches/core-loop/src/world/park", `${map}.json`);
    const before = readFileSync(file, "utf8");
    const { text, counts } = swap(before);
    JSON.parse(text);
    const n = Object.values(counts).reduce((a, b) => a + b, 0);
    left += n;
    if (!check && n > 0) writeFileSync(file, text);
    console.log(`${map}: ${n} ${check ? "left" : "swapped"} ${JSON.stringify(counts)}`);
  }
  if (check && left > 0) process.exitCode = 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
