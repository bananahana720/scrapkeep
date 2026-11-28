import path from "node:path";
import { fileURLToPath } from "node:url";
import { runLinuxExport } from "../sketch-export.mjs";

export function runCloudExport(argv = process.argv.slice(2), options = {}) {
  return runLinuxExport({
    headless: true,
    winProof: argv.includes("--win-proof"),
    ...options,
  });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  await runCloudExport();
