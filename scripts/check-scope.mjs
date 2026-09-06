import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const uiPaths = [/^index\.html$/, /^orchard\.html$/, /^src\//, /^public\//];
// Order matters: the first matching class wins, so configuration and native
// paths are claimed before the broad Markdown rule.
const classes = [
  {
    name: "configuration",
    build: false,
    patterns: [
      /^\.claude\//,
      /^\.agents\//,
      /^\.codex\//,
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
      /^native\//,
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
    patterns: [
      /^(?!scripts\/|tests\/).*\.(md|tsv)$/,
      /^docs\//,
      /^adr\//,
      /^artifacts\//,
    ],
    commands: ["npm run check:docs", "npm run check:project"],
    evidence: "structural documentation checks; no build or runtime evidence",
  },
  {
    name: "browser-proof",
    build: true,
    patterns: [...uiPaths, /^vite\.config\.js$/],
    commands: ["npm run verify"],
    evidence:
      "asserted tests and a production build; no browser session implied",
  },
  {
    name: "tooling",
    build: true,
    patterns: [/^scripts\//, /^tests\//, /^package\.json$/, /^tools\//],
    commands: ["npm run verify"],
    evidence:
      "asserted tests and a production build; no browser session implied",
  },
  {
    name: "other",
    build: true,
    patterns: [/./],
    commands: ["npm run verify"],
    evidence:
      "unclassified path; treated as build-requiring until a class claims it",
  },
];

function parseArguments(argv) {
  const options = { root: scriptRoot, noBuild: false, revisions: [] };
  for (let index = 0; index < argv.length; index++) {
    const value = argv[index];
    if (value === "--no-build") options.noBuild = true;
    else if (value === "--root" && argv[index + 1])
      options.root = path.resolve(argv[++index]);
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
  const git = spawnSync(
    "git",
    ["-C", root, "diff", "--name-only", base, candidate, "--"],
    { encoding: "utf8" },
  );
  if (git.status !== 0)
    throw new Error("git diff failed: " + git.stderr.trim());
  return git.stdout.split("\n").filter(Boolean);
}

function classify(file) {
  return classes.find((entry) =>
    entry.patterns.some((pattern) => pattern.test(file)),
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
  const present = classes.filter((entry) => groups.has(entry.name));
  const scope =
    present.length === 0
      ? "empty"
      : present.length === 1
        ? present[0].name
        : "mixed";
  const buildRequired = present.filter((entry) => entry.build);
  const uiChanged = files.some((file) =>
    uiPaths.some((pattern) => pattern.test(file)),
  );
  const commands = new Set();
  for (const entry of present)
    for (const command of entry.commands) commands.add(command);
  if (uiChanged)
    commands.add(
      "CONTRIBUTING.md Verification browser checks for the changed UI paths",
    );

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
