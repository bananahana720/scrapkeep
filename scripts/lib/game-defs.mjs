import { readFileSync } from "node:fs";
import path from "node:path";
import { REPO_ROOT } from "./git.mjs";

const TOOLCHAIN = JSON.parse(readFileSync(new URL("../toolchain.json", import.meta.url), "utf8"));
export const DEFAULT_SKETCH_DIR = path.join(REPO_ROOT, TOOLCHAIN.sketchDir);

export function parsePilotIds(classDefSource) {
  const allMatch = /static\s+func\s+all\(\)[\s\S]*?return\s+list/.exec(classDefSource);
  const block = allMatch ? allMatch[0] : classDefSource;
  const ids = [...block.matchAll(/make\(\s*\{\s*"id"\s*:\s*"([a-z0-9_]+)"/g)].map((m) => m[1]);
  if (ids.length === 0) {
    throw new Error("game-defs: parsed 0 pilot IDs from class_def.gd");
  }
  return ids;
}

export function parseStageDefs(defsSource) {
  const tableMatch = /const\s+DEFS\s*:?=\s*\[([\s\S]*?)\n\]/.exec(defsSource);
  if (!tableMatch) {
    throw new Error("game-defs: could not find const DEFS in stage defs source");
  }
  const stages = [];
  for (const match of tableMatch[1].matchAll(
    /^\s*\{"stage":\s*(\d+),\s*"world":\s*(\d+),[^\n]*"map":\s*"([a-z0-9_]+)"/gm,
  )) {
    stages.push({
      stage: Number(match[1]),
      world: Number(match[2]),
      map: match[3],
    });
  }
  if (stages.length === 0) {
    throw new Error("game-defs: parsed 0 stage defs from DEFS table");
  }
  return stages;
}

export function loadGameDefs(sketchDir = DEFAULT_SKETCH_DIR) {
  const read = (rel) => readFileSync(path.join(sketchDir, rel), "utf8");
  const pilotIds = parsePilotIds(read("src/core/class_def.gd"));
  const parkStages = parseStageDefs(read("src/core/park_defs.gd"));
  const alphaStages = parseStageDefs(read("src/core/alpha_defs.gd"));
  const parkMaps = parkStages.map((row) => row.map);
  const world1Maps = parkStages.filter((row) => row.world === 1).map((row) => row.map);
  const alphaMaps = alphaStages.map((row) => row.map);
  return {
    pilotIds,
    parkStages,
    parkMaps,
    world1Maps,
    alphaStages,
    alphaMaps,
  };
}

const loaded = loadGameDefs();
export const PILOT_IDS = loaded.pilotIds;
export const PARK_MAPS = loaded.parkMaps;
export const WORLD1_MAPS = loaded.world1Maps;
export const ALPHA_MAPS = loaded.alphaMaps;
