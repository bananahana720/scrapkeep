import assert from "node:assert/strict";
import { access, readFile, readdir } from "node:fs/promises";
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

async function markdown(directory) {
  const files = [];
  for (const item of await readdir(path.join(root, directory), {
    withFileTypes: true,
  })) {
    const file = path.join(directory, item.name);
    if (item.isDirectory()) files.push(...(await markdown(file)));
    else if (item.isFile() && file.endsWith(".md")) files.push(file);
  }
  return files;
}
const files = [
  "README.md",
  "AGENTS.md",
  "CONTRIBUTING.md",
  "artifacts/README.md",
  ...(await markdown("docs")),
];
const failures = [];
let checkedLinks = 0;
for (const file of files) {
  const content = (await readFile(path.join(root, file), "utf8")).replace(/```[\s\S]*?```/g, "");
  for (const match of content.matchAll(/!?\[[^\]]*\]\((<[^>]+>|[^)]+)\)/g)) {
    let target = match[1].replace(/^<|>$/g, "").trim();
    if (/^(?:[a-z][a-z0-9+.-]*:|#)/i.test(target)) continue;
    target = target.split("#")[0];
    if (!target) continue;
    checkedLinks++;
    try {
      await access(path.resolve(root, path.dirname(file), decodeURIComponent(target)));
    } catch {
      failures.push(file + " -> " + target);
    }
  }
}
assert.equal(failures.length, 0, "Broken local Markdown file links:\n" + failures.join("\n"));
console.log(
  "Project checks passed: " +
    files.length +
    " Markdown files, " +
    checkedLinks +
    " file links, package/lock metadata.",
);
console.log(
  "Remote URLs, anchors, runtime behavior and full import analysis are outside this check.",
);
