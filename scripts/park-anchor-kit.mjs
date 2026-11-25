import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const PARKS = [
  "park_dam",
  "park_flume",
  "park_pit",
  "park_sinkhole",
  "park_islands",
  "park_crown",
];
export const GREY = "greybox:anchor_field";

const word = (alternatives) => new RegExp(`(^|_)(${alternatives})(?=_|\\d|$)`);
export const BY_ID = [
  [word("cairns?"), "anchor_cairn"],
  [word("net_posts?|masts?|booms?|truss(es)?|trestles?|piers?|fire_lookout"), "anchor_timber"],
  [word("spatter|basalt"), "anchor_basalt"],
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
