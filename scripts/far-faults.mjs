import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const SKETCH = path.join(root, "sketches/core-loop");
export const FAR_GLOB = "assets/models/park/props/*/*_lod2.glb";
export const LOD0_GLOB = "assets/models/park/props/*/*.glb";
export const CAP = 0.001;

export function insideOut(row) {
  return row.area_m2 > 0 ? row.flipped_m2 / row.area_m2 : 0;
}

export function overCap(rows, cap = CAP) {
  return rows
    .filter((row) => insideOut(row) > cap)
    .map((row) => ({ file: row.file, share: insideOut(row) }));
}

export function scanFaults(files = [FAR_GLOB], cwd = SKETCH) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "far-faults-"));
  try {
    const out = path.join(dir, "faults.json");
    const result = spawnSync(
      "python3",
      [path.join(SKETCH, "tools/model_audit.py"), "faults", ...files, `--out=${out}`],
      { cwd, encoding: "utf8" },
    );
    if (result.status !== 0)
      throw new Error(`model_audit.py faults failed: ${result.stderr.slice(0, 400)}`);
    return JSON.parse(readFileSync(out, "utf8"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

export function scanCover(files = [LOD0_GLOB], cwd = SKETCH) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "far-cover-"));
  try {
    const out = path.join(dir, "cover.json");
    const result = spawnSync(
      "python3",
      [path.join(SKETCH, "tools/model_audit.py"), "cover", ...files, `--out=${out}`],
      { cwd, encoding: "utf8" },
    );
    if (result.status !== 0)
      throw new Error(`model_audit.py cover failed: ${result.stderr.slice(0, 400)}`);
    return JSON.parse(readFileSync(out, "utf8"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function main() {
  const rows = scanFaults();
  const over = overCap(rows);
  for (const o of over)
    console.log(
      `  ${o.file}  ${(o.share * 100).toFixed(2)}% of its area inside out (cap ${(CAP * 100).toFixed(1)}%)`,
    );
  const covers = scanCover();
  const thin = covers.filter((row) => row.under);
  for (const row of thin)
    console.log(`  ${row.file}  fills ${(row.cover * 100).toFixed(1)}% of LOD0's outline`);
  const bad = over.length + thin.length;
  console.log(
    `far faults: ${bad ? "FAIL" : "PASS"} (${rows.length} far meshes, ${covers.length} LODs scored against LOD0)`,
  );
  process.exitCode = bad ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
