import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const required = [
  "AGENTS.md",
  "CONTRIBUTING.md",
  "README.md",
  "artifacts/README.md",
  "adr/README.md",
  "project-guide/handoff/START-HERE.md",
  "project-guide/handoff/STATE.md",
  "project-guide/handoff/DECISIONS.md",
  "docs/FIRST-BUILD-CONTRACT.md",
  "docs/FIRST-BUILD-VERIFICATION.md",
];
for (const file of required) await access(path.join(root, file));
const pkg = JSON.parse(await readFile(path.join(root, "package.json"), "utf8"));
const lock = JSON.parse(await readFile(path.join(root, "package-lock.json"), "utf8"));
for (const field of ["name", "version", "engines", "dependencies", "devDependencies"])
  assert.deepEqual(pkg[field], lock.packages[""][field], "Package/lock root mismatch: " + field);
assert.ok(pkg.engines?.node, "Declare the supported Node range");

console.log(
  "Project checks passed: " + required.length + " required files, package/lock metadata.",
);
console.log(
  "Markdown links and anchors are checked by npm run check:docs; runtime behavior and full import analysis are outside this check.",
);
