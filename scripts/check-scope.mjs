import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const uiPaths = [/^index\.html$/, /^orchard\.html$/, /^src\//, /^public\//];
const noBuildToolingPaths = [/^scripts\/.*\.mjs$/, /^tests\/.*\.test\.js$/];
// Order matters: the first matching class wins, so sketch, configuration,
// native and native-player paths are claimed before the broad Markdown rule.
const classes = [
  {
    name: "sketch",
    build: false,
    patterns: [/^sketches\//],
    commands: ["npm run sketch:smoke"],
    evidence:
      "headless Godot boot and sketch tests; feel needs Andrew's play (ORCHESTRATOR, Light play lane)",
  },
  {
    name: "configuration",
    build: false,
    patterns: [
      /^\.claude\//,
      /^\.agents\//,
      /^\.codex\//,
      /^AGENTS\.md$/,
      /^CLAUDE\.md$/,
      /^\.gitignore$/,
      /^\.env\.example$/,
    ],
    commands: [
      "npm run check:docs",
      "scenario review of the changed instructions or configuration against ORCHESTRATOR.md and AGENTS.md",
    ],
    evidence: "structural documentation checks plus a manual scenario review",
  },
  {
    name: "native",
    build: true,
    patterns: [
      /\.gd$/,
      /\.tscn$/,
      /\.tres$/,
      /(^|\/)project\.godot$/,
      /(^|\/)export_presets\.cfg$/,
    ],
    commands: [
      "npm run check:godot (reserved name, currently unavailable until the engineering handoff)",
    ],
    evidence: "unavailable; no native check command exists yet",
  },
  {
    name: "documentation-only",
    build: false,
    patterns: [/^(?!scripts\/|tests\/).*\.(md|tsv)$/, /^docs\//, /^adr\//, /^artifacts\//],
    commands: ["npm run check:docs", "npm run check:project"],
    evidence: "structural documentation checks; no build or runtime evidence",
  },
  {
    name: "browser-proof",
    build: true,
    patterns: [...uiPaths, /^vite\.config\.js$/],
    commands: ["npm run verify"],
    evidence: "asserted tests and a production build; no browser session implied",
  },
  {
    name: "tooling-no-build",
    build: false,
    // No single path claims this class; toolingNoBuild promotes a whole change
    // set out of tooling below, so classify() must never select it per file.
    patterns: [],
    commands: ["npm test", "npm run check:docs", "npm run check:project"],
    evidence:
      "asserted tests and structural documentation checks; no build, browser session or dependency change implied",
  },
  {
    name: "tooling",
    build: true,
    patterns: [/^scripts\//, /^tests\//, /^package\.json$/, /^tools\//],
    commands: ["npm run verify"],
    evidence: "asserted tests and a production build; no browser session implied",
  },
  {
    name: "other",
    build: true,
    patterns: [/./],
    commands: ["npm run verify"],
    evidence: "unclassified path; treated as build-requiring until a class claims it",
  },
];

function parseArguments(argv) {
  const options = { root: scriptRoot, noBuild: false, revisions: [] };
  for (let index = 0; index < argv.length; index++) {
    const value = argv[index];
    if (value === "--no-build") options.noBuild = true;
    else if (value === "--root" && argv[index + 1]) options.root = path.resolve(argv[++index]);
    else if (value.startsWith("--")) throw new Error("Unknown flag: " + value);
    else options.revisions.push(value);
  }
  if (options.revisions.length !== 2)
    throw new Error(
      "Usage: node scripts/check-scope.mjs <base> <candidate> [--no-build] [--root <dir>]",
    );
  return options;
}

function changedFiles(root, base, candidate) {
  const git = spawnSync("git", ["-C", root, "diff", "--name-only", base, candidate, "--"], {
    encoding: "utf8",
  });
  if (git.status !== 0) throw new Error("git diff failed: " + git.stderr.trim());
  return git.stdout.split("\n").filter(Boolean);
}

function classify(file) {
  return classes.find((entry) => entry.patterns.some((pattern) => pattern.test(file)));
}

function readJsonAtRevision(root, revision, file) {
  const git = spawnSync("git", ["-C", root, "show", revision + ":" + file], {
    encoding: "utf8",
  });
  if (git.status !== 0) return null;
  try {
    return JSON.parse(git.stdout);
  } catch {
    return null;
  }
}

// package.json holds scripts beside dependencies, so its path cannot say which
// one moved; an unreadable or unparsable revision counts as a dependency change.
function packageJsonScriptsOnly(root, base, candidate) {
  const before = readJsonAtRevision(root, base, "package.json");
  const after = readJsonAtRevision(root, candidate, "package.json");
  if (!before || !after) return false;
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  keys.delete("scripts");
  return [...keys].every((key) => JSON.stringify(before[key]) === JSON.stringify(after[key]));
}

function toolingNoBuild(groups, scriptsOnlyPackage) {
  const tooling = groups.get("tooling");
  if (!tooling) return false;
  const beside = [...groups.keys()].filter(
    (name) => name !== "tooling" && name !== "documentation-only",
  );
  if (beside.length) return false;
  return tooling.every(
    (file) =>
      noBuildToolingPaths.some((pattern) => pattern.test(file)) ||
      (file === "package.json" && scriptsOnlyPackage),
  );
}

function main() {
  const options = parseArguments(process.argv.slice(2));
  const [base, candidate] = options.revisions;
  const files = changedFiles(options.root, base, candidate);
  const groups = new Map();
  for (const file of files) {
    const entry = classify(file);
    if (!groups.has(entry.name)) groups.set(entry.name, []);
    groups.get(entry.name).push(file);
  }
  if (
    toolingNoBuild(
      groups,
      files.includes("package.json") && packageJsonScriptsOnly(options.root, base, candidate),
    )
  ) {
    groups.clear();
    groups.set("tooling-no-build", files);
  }
  const present = classes.filter((entry) => groups.has(entry.name));
  const scope = present.length === 0 ? "empty" : present.length === 1 ? present[0].name : "mixed";
  const buildRequired = present.filter((entry) => entry.build);
  const uiChanged = files.some((file) => uiPaths.some((pattern) => pattern.test(file)));
  const commands = new Set();
  for (const entry of present) for (const command of entry.commands) commands.add(command);
  if (uiChanged)
    commands.add("CONTRIBUTING.md Verification browser checks for the changed UI paths");

  console.log("check:scope " + base + ".." + candidate);
  console.log("scope: " + scope + " (" + files.length + " changed paths)");
  for (const entry of present) {
    console.log("class " + entry.name + " [evidence: " + entry.evidence + "]");
    for (const file of groups.get(entry.name)) console.log("  " + file);
  }
  console.log("required commands:");
  for (const command of commands) console.log("  " + command);
  if (commands.size === 0) console.log("  none (no changed paths)");
  console.log(
    "This selector classifies paths and names commands. It runs none of them and proves nothing about their outcome.",
  );
  if (options.noBuild && buildRequired.length) {
    console.log(
      "refused: --no-build was given but the change set includes build-requiring classes: " +
        buildRequired.map((entry) => entry.name).join(", "),
    );
    process.exitCode = 1;
  }
}

try {
  main();
} catch (error) {
  console.error("check:scope internal error: " + (error?.message ?? error));
  process.exitCode = 2;
}
