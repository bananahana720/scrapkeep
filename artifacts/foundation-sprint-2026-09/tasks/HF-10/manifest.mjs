// Lists the foundation section outputs with sha256 and their retained receipt directories.
import { createHash } from "node:crypto";
import { readFileSync, existsSync, readdirSync } from "node:fs";
const root = process.argv[2] ?? ".";
const ids = ["HF-01", "HF-02", "HF-03a", "HF-03b", "HF-04a", "HF-04b", "HF-05", "HF-06a", "HF-06b", "HF-07a", "HF-07b", "HF-08", "HF-09"];
const dir = `${root}/docs/tech/sections`;
const rows = ids.map((id) => {
  const files = readdirSync(dir).filter((f) => f.startsWith(`${id}-`));
  const receipts = `artifacts/foundation-sprint-2026-09/tasks/${id}`;
  return { id, outputs: files.map((f) => ({ path: `docs/tech/sections/${f}`, sha256: createHash("sha256").update(readFileSync(`${dir}/${f}`)).digest("hex") })), receipts: existsSync(`${root}/${receipts}`) ? readdirSync(`${root}/${receipts}`) : null };
});
console.log(JSON.stringify({ generatedAt: new Date().toISOString(), rows }, null, 2));
