import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// The far-mesh fault check on every park prop (SG-16): tools/model_audit.py faults over the props kit's far meshes
// (assets/models/park/props/<map>/*_lod2.glb, what the game draws past its second LOD distance). A file fails when
// more than CAP of its area is lit inside out (flipped_m2 over area_m2). On 10 Nov 94 of 286 far meshes had such faces,
// seven over 10% of their area (the world 1 visual assets audit, finding 11); W1-29 fixed the kit's decimate() and on
// 12 Nov none had any, so the cap only leaves room for a sliver shut inside a body. sketch:fast runs
// scripts/far-faults.test.mjs when a park prop recipe or file changes.
// The far meshes must also keep the prop's shape: model_audit.py cover scores how much of LOD0's outline each LOD fills, and
// marks a LOD `under` (it fails) by model_audit.under: under COVER_MIN with triangles left under the kit's cap, or under
// COVER_FLOOR at all. On 14 Nov the dam's cable drums drew as floating rings at 100 m with no face flipped:
// the collapse had eaten the barrel (W1-29); the kit now raises such a LOD's triangles.
// Run: node scripts/far-faults.mjs   (needs python3 with numpy)

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const SKETCH = path.join(root, "sketches/core-loop");
export const FAR_GLOB = "assets/models/park/props/*/*_lod2.glb";
export const LOD0_GLOB = "assets/models/park/props/*/*.glb";
export const CAP = 0.001;

export function insideOut(row) {
  return row.area_m2 > 0 ? row.flipped_m2 / row.area_m2 : 0;
}

// rows: model_audit.py faults rows. Returns the rows over the cap as {file, share}.
export function overCap(rows, cap = CAP) {
  return rows.filter((row) => insideOut(row) > cap).map((row) => ({ file: row.file, share: insideOut(row) }));
}

// model_audit.py faults over `files` (paths or globs, relative to `cwd`); its JSON rows.
export function scanFaults(files = [FAR_GLOB], cwd = SKETCH) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "far-faults-"));
  try {
    const out = path.join(dir, "faults.json");
    const result = spawnSync("python3", [path.join(SKETCH, "tools/model_audit.py"), "faults", ...files, `--out=${out}`], { cwd, encoding: "utf8" });
    if (result.status !== 0) throw new Error(`model_audit.py faults failed: ${result.stderr.slice(0, 400)}`);
    return JSON.parse(readFileSync(out, "utf8"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

// model_audit.py cover over LOD0 files (paths or globs, relative to `cwd`): one row per LOD beside each,
// {file, cover, tris, lod0_tris, under}, under as model_audit.under decides.
export function scanCover(files = [LOD0_GLOB], cwd = SKETCH) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "far-cover-"));
  try {
    const out = path.join(dir, "cover.json");
    const result = spawnSync("python3", [path.join(SKETCH, "tools/model_audit.py"), "cover", ...files, `--out=${out}`], { cwd, encoding: "utf8" });
    if (result.status !== 0) throw new Error(`model_audit.py cover failed: ${result.stderr.slice(0, 400)}`);
    return JSON.parse(readFileSync(out, "utf8"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function main() {
  const rows = scanFaults();
  const over = overCap(rows);
  for (const o of over) console.log(`  ${o.file}  ${(o.share * 100).toFixed(2)}% of its area inside out (cap ${(CAP * 100).toFixed(1)}%)`);
  const covers = scanCover();
  const thin = covers.filter((row) => row.under);
  for (const row of thin) console.log(`  ${row.file}  fills ${(row.cover * 100).toFixed(1)}% of LOD0's outline`);
  const bad = over.length + thin.length;
  console.log(`far faults: ${bad ? "FAIL" : "PASS"} (${rows.length} far meshes, ${covers.length} LODs scored against LOD0)`);
  process.exitCode = bad ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
