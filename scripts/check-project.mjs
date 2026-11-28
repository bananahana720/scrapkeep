import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import path from "node:path";
import { REPO_ROOT } from "./lib/git.mjs";

const root = REPO_ROOT;
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
  "scripts/toolchain.json",
  "tools/cloud/godot-version.env",
  "tools/cloud/setup.sh",
  ".github/actions/setup-godot/action.yml",
];
for (const file of required) await access(path.join(root, file));
const pkg = JSON.parse(await readFile(path.join(root, "package.json"), "utf8"));
const lock = JSON.parse(await readFile(path.join(root, "package-lock.json"), "utf8"));
for (const field of ["name", "version", "engines", "dependencies", "devDependencies"])
  assert.deepEqual(pkg[field], lock.packages[""][field], "Package/lock root mismatch: " + field);
assert.ok(pkg.engines?.node, "Declare the supported Node range");

const toolchain = JSON.parse(await readFile(path.join(root, "scripts/toolchain.json"), "utf8"));
for (const key of [
  "godotVersion",
  "godotNumericVersion",
  "godotTemplateVersion",
  "godotZipSha512",
  "godotBinSha256",
  "sketchDir",
]) {
  assert.ok(
    typeof toolchain[key] === "string" && toolchain[key].length > 0,
    `scripts/toolchain.json missing ${key}`,
  );
}

const envText = await readFile(path.join(root, "tools/cloud/godot-version.env"), "utf8");
const envMap = Object.fromEntries(
  envText
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"))
    .map((line) => {
      const eq = line.indexOf("=");
      return [line.slice(0, eq), line.slice(eq + 1).replace(/^['"]|['"]$/g, "")];
    }),
);
assert.equal(
  envMap.GODOT_VERSION,
  toolchain.godotVersion,
  "godot-version.env GODOT_VERSION mismatch",
);
assert.equal(
  envMap.GODOT_NUMERIC_VERSION,
  toolchain.godotNumericVersion,
  "godot-version.env GODOT_NUMERIC_VERSION mismatch",
);
assert.equal(
  envMap.GODOT_TEMPLATE_VERSION,
  toolchain.godotTemplateVersion,
  "godot-version.env GODOT_TEMPLATE_VERSION mismatch",
);
assert.equal(
  envMap.GODOT_ZIP_SHA512,
  toolchain.godotZipSha512,
  "godot-version.env GODOT_ZIP_SHA512 mismatch",
);
assert.equal(
  envMap.GODOT_BIN_SHA256,
  toolchain.godotBinSha256,
  "godot-version.env GODOT_BIN_SHA256 mismatch",
);
if (toolchain.godotTemplatesSha512) {
  assert.equal(
    envMap.GODOT_TEMPLATES_SHA512,
    toolchain.godotTemplatesSha512,
    "godot-version.env GODOT_TEMPLATES_SHA512 mismatch",
  );
}

const ciYml = await readFile(path.join(root, ".github/workflows/ci.yml"), "utf8");
const ciEnv = (name) => {
  const m = new RegExp(`^\\s*${name}:\\s*['"]?([^'"\\s#]+)['"]?`, "m").exec(ciYml);
  assert.ok(m, `.github/workflows/ci.yml missing env ${name}`);
  return m[1];
};
assert.equal(ciEnv("GODOT_VERSION"), toolchain.godotVersion, "ci.yml GODOT_VERSION mismatch");
assert.equal(
  ciEnv("GODOT_ZIP_SHA512"),
  toolchain.godotZipSha512,
  "ci.yml GODOT_ZIP_SHA512 mismatch",
);
assert.equal(
  ciEnv("GODOT_BIN_SHA256"),
  toolchain.godotBinSha256,
  "ci.yml GODOT_BIN_SHA256 mismatch",
);

const setupSh = await readFile(path.join(root, "tools/cloud/setup.sh"), "utf8");
const setupFallback = (name) => {
  const m = new RegExp(`^${name}="\\$\\{${name}:-([^}]+)\\}"$`, "m").exec(setupSh);
  assert.ok(m, `tools/cloud/setup.sh missing fallback ${name}`);
  return m[1];
};
assert.equal(
  setupFallback("GODOT_VERSION"),
  toolchain.godotVersion,
  "setup.sh GODOT_VERSION fallback mismatch",
);
assert.equal(
  setupFallback("GODOT_TEMPLATE_VERSION"),
  toolchain.godotTemplateVersion,
  "setup.sh GODOT_TEMPLATE_VERSION fallback mismatch",
);
assert.equal(
  setupFallback("GODOT_ZIP_SHA512"),
  toolchain.godotZipSha512,
  "setup.sh GODOT_ZIP_SHA512 fallback mismatch",
);
assert.equal(
  setupFallback("GODOT_BIN_SHA256"),
  toolchain.godotBinSha256,
  "setup.sh GODOT_BIN_SHA256 fallback mismatch",
);
if (toolchain.godotTemplatesSha512) {
  assert.equal(
    setupFallback("GODOT_TEMPLATES_SHA512"),
    toolchain.godotTemplatesSha512,
    "setup.sh GODOT_TEMPLATES_SHA512 fallback mismatch",
  );
}

console.log(
  "Project checks passed: " +
    required.length +
    " required files, package/lock metadata, toolchain sync.",
);
console.log(
  "Markdown links and anchors are checked by npm run check:docs; runtime behavior and full import analysis are outside this check.",
);
