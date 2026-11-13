#!/usr/bin/env node
// Point-of-interest spacing along the pilot ride lines of a park map.
// Reads sketches/core-loop/src/world/park/park_<map>.json and assets/park/park_<map>/lines.json.
// A site is an activity row, a rescue row or the Warden; it counts for a line that comes within
// REACH_M of it. Gaps are seconds at SPEED_MPS. Prints medians over the pilots, or JSON with --json.
// --check fails when a map is under the pass line (BACKLOG, "World 1 now: points of interest").
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const REACH_M = 60;
export const SPEED_MPS = 20;
export const PASS = { sites: 7, gap_s: 20 };
const STEP_M = 5;

const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
const median = (xs) => {
  const s = [...xs].sort((a, b) => a - b);
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

// The game ends a pilot line at the landmark's beacon, where the Warden's ring stands.
const beacon = (park) => park.landmark.beacon ?? park.landmark.at;

export function sites(park) {
  const out = [];
  for (const row of [...(park.activity_rows ?? []), ...(park.rescue_rows ?? [])]) {
    if (row.at) out.push({ id: row.id, kind: row.activity ?? "rescue", at: row.at });
  }
  out.push({ id: "warden", kind: "warden", at: beacon(park) });
  return out;
}

function points(park, waypoints) {
  // Park rows win over activity ids, as in the game (tools/traversal_line.gd).
  const named = { drop_in: park.spawn.at, landmark: beacon(park) };
  const known = new Set(Object.keys(named));
  for (const row of [...(park.park_rows ?? []), ...(park.activity_rows ?? [])]) {
    known.add(row.id);
    named[row.id] ??= row.at;
  }
  return waypoints.map((w) => {
    if (typeof w !== "string") return w;
    if (!named[w]) throw new Error(known.has(w) ? `pilot line names "${w}", which has no position in ${park.map}` : `pilot line names "${w}", which is no row of ${park.map}`);
    return named[w];
  });
}

export function ride(park, waypoints, list = sites(park)) {
  const pts = points(park, waypoints);
  const samples = [];
  let length = 0;
  for (let i = 0; i + 1 < pts.length; i += 1) {
    const seg = dist(pts[i], pts[i + 1]);
    const n = Math.max(1, Math.floor(seg / STEP_M));
    for (let k = 0; k < n; k += 1) {
      const t = k / n;
      samples.push([length + seg * t, [pts[i][0] + (pts[i + 1][0] - pts[i][0]) * t, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t]]);
    }
    length += seg;
  }
  samples.push([length, pts[pts.length - 1]]);
  const hits = [];
  const kinds = new Set();
  for (const site of list) {
    let best = samples[0];
    for (const s of samples) if (dist(s[1], site.at) < dist(best[1], site.at)) best = s;
    if (dist(best[1], site.at) <= REACH_M) {
      hits.push(best[0]);
      kinds.add(site.kind);
    }
  }
  hits.sort((a, b) => a - b);
  const marks = [0, ...hits, length];
  let gap = 0;
  for (let i = 0; i + 1 < marks.length; i += 1) gap = Math.max(gap, marks[i + 1] - marks[i]);
  return { length_m: length, sites: hits.length, kinds: kinds.size, gap_s: gap / SPEED_MPS };
}

export function census(park, lines) {
  const rides = Object.entries(lines.pilots).map(([pilot, spec]) => ({ pilot, ...ride(park, spec.waypoints) }));
  return {
    map: park.map,
    sites_on_map: sites(park).length,
    sites: median(rides.map((r) => r.sites)),
    gap_s: Math.round(median(rides.map((r) => r.gap_s)) * 10) / 10,
    length_m: Math.round(median(rides.map((r) => r.length_m))),
    rides,
  };
}

export const passes = (row) => row.sites >= PASS.sites && row.gap_s <= PASS.gap_s;

export function main(argv) {
  const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "sketches", "core-loop");
  const maps = argv.filter((a) => !a.startsWith("--"));
  const rows = (maps.length ? maps : ["park_dam", "park_flume"]).map((map) =>
    census(
      JSON.parse(readFileSync(path.join(root, "src/world/park", `${map}.json`), "utf8")),
      JSON.parse(readFileSync(path.join(root, "assets/park", map, "lines.json"), "utf8")),
    ),
  );
  if (argv.includes("--json")) console.log(JSON.stringify(rows, null, 1));
  else {
    for (const r of rows) {
      console.log(`${r.map}: ${r.sites_on_map} sites on the map; a ride of ${r.length_m} m passes ${r.sites} (pass ${PASS.sites}+), longest stretch with none ${r.gap_s} s (pass ${PASS.gap_s} s or less): ${passes(r) ? "PASS" : "UNDER"}`);
    }
  }
  if (argv.includes("--check") && !rows.every(passes)) process.exitCode = 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main(process.argv.slice(2));
