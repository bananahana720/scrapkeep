import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// The far-mesh fault check on every park prop (SG-16): tools/model_audit.py faults over the props kit's far meshes
// (assets/models/park/props/<map>/*_lod2.glb, the mesh the game draws past its second LOD distance), against a ceiling on
// each file's inside-out area (flipped_m2 over area_m2). A file in the ceiling list may not get worse than its row; any
// other file may carry at most NEW_CAP. The rows were set by the files of 12 November 2026 (94 of 286 far meshes had
// inside-out faces, seven over 10% of their area: the world 1 visual assets audit, finding 11). When W1-29 fixes a file,
// rerun with --record so its row falls; --record never raises a row.
// Run: node scripts/far-faults.mjs [--record]   (needs python3 with numpy)

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const SKETCH = path.join(root, "sketches/core-loop");
export const FAR_GLOB = "assets/models/park/props/*/*_lod2.glb";
export const CEILING_FILE = "tools/blender/park/props/far_faults.json";
export const NEW_CAP = 0.005;

const round = (x) => Math.ceil(x * 10000) / 10000;

export function insideOut(row) {
  return row.area_m2 > 0 ? row.flipped_m2 / row.area_m2 : 0;
}

// rows: model_audit.py faults rows with `file` relative to the sketch. Returns {over: [{file, share, ceiling}], scanned}.
export function judge(rows, ceilings, cap = NEW_CAP) {
  const over = [];
  for (const row of rows) {
    const share = insideOut(row);
    const ceiling = ceilings[row.file] ?? cap;
    if (share > ceiling) over.push({ file: row.file, share, ceiling });
  }
  return { over, scanned: rows.length };
}

// The ceiling list after a pass: every file over NEW_CAP keeps the lower of its row and today's share (rounded up).
export function record(rows, ceilings, cap = NEW_CAP) {
  const out = {};
  for (const row of [...rows].sort((a, b) => a.file.localeCompare(b.file))) {
    const share = round(insideOut(row));
    if (share <= cap) continue;
    out[row.file] = row.file in ceilings ? Math.min(ceilings[row.file], share) : share;
  }
  return out;
}

export function scanFaults(sketch = SKETCH, glob = FAR_GLOB) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "far-faults-"));
  try {
    const out = path.join(dir, "faults.json");
    const result = spawnSync("python3", [path.join(sketch, "tools/model_audit.py"), "faults", glob, `--out=${out}`], { cwd: sketch, encoding: "utf8" });
    if (result.status !== 0) throw new Error(`model_audit.py faults failed: ${result.stderr.slice(0, 400)}`);
    return JSON.parse(readFileSync(out, "utf8"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

export function readCeilings(sketch = SKETCH) {
  return JSON.parse(readFileSync(path.join(sketch, CEILING_FILE), "utf8"));
}

function main() {
  const rows = scanFaults();
  const ceilings = readCeilings();
  if (process.argv.includes("--record")) {
    const next = record(rows, ceilings);
    writeFileSync(path.join(SKETCH, CEILING_FILE), JSON.stringify(next, null, 2) + "\n");
    console.log(`far faults: ${Object.keys(next).length} file row(s) recorded (was ${Object.keys(ceilings).length})`);
    return;
  }
  const { over, scanned } = judge(rows, ceilings);
  for (const o of over) console.log(`  ${o.file}  inside-out ${(o.share * 100).toFixed(2)}% over ceiling ${(o.ceiling * 100).toFixed(2)}%`);
  console.log(`far faults: ${over.length ? "FAIL" : "PASS"} (${scanned} far meshes, ${Object.keys(ceilings).length} with a ceiling row)`);
  process.exitCode = over.length ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
