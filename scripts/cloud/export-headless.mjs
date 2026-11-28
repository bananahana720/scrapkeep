import { isMain } from "../lib/cli.mjs";
import { runLinuxExport } from "../sketch-export.mjs";

export function runCloudExport(argv = process.argv.slice(2), options = {}) {
  return runLinuxExport({
    headless: true,
    winProof: argv.includes("--win-proof"),
    ...options,
  });
}

if (isMain(import.meta.url)) await runCloudExport();
