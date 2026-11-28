import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { gitOptional } from "../../scripts/lib/git.mjs";

const LIVE_SAVE_SEGMENT =
  /(?:\.local\/share\/godot\/app_userdata\/core-loop|Library\/Application Support\/godot\/app_userdata\/core-loop)(?:\b|\/|$)/i;
const LIVE_SAVE_SEGMENT_GLOBAL =
  /(?:\.local\/share\/godot\/app_userdata\/core-loop|Library\/Application Support\/godot\/app_userdata\/core-loop)(?:\b|\/|$)/gi;
const SCRATCH_ARTIFACTS_PREFIX = /(?:^|\/)artifacts\/local\//;
const PARENT_TRAVERSAL = /(?:^|\/)\.\.(?:\/|$)/;
const SHELL_EXPANSION = /[{}*$?[\]`\\'"]/;
const NPM_PUBLISH = /\bnpm\s+publish\b/;
const GH_REPO_DELETE = /\bgh\s+repo\s+delete\b/;
const NPM_PKG_MUTATE = /\bnpm\s+(?:install|i|uninstall)(?:\s|$)/;
const GH_REPO_OR_API = /\bgh\s+(?:repo|api)\b/;

const FILE_WRITE_TOOLS = new Set([
  "edit_file",
  "write_file",
  "write_to_file",
  "replace_file_content",
  "multi_replace_file_content",
]);

const GIT_GLOBAL_VALUE_FLAGS = new Set([
  "-C",
  "-c",
  "--git-dir",
  "--work-tree",
  "--namespace",
  "--super-prefix",
  "--config-env",
  "--exec-path",
]);

function allow(reason = "Allowed by Scrapkeep PreToolUse safety gate.") {
  return { decision: "allow", reason };
}

function deny(reason) {
  return { decision: "deny", reason };
}

function ask(reason) {
  return { decision: "ask", reason };
}

function splitShellSegments(commandLine) {
  return String(commandLine)
    .split(/(?:&&|\|\||;|\n|\|)/)
    .map((s) => s.trim())
    .filter(Boolean);
}

function tokenize(segment) {
  const tokens = [];
  const re = /"((?:\\.|[^"])*)"|'([^']*)'|(\S+)/g;
  let m;
  while ((m = re.exec(segment)) !== null) {
    tokens.push(m[1] ?? m[2] ?? m[3]);
  }
  return tokens;
}

function splitShellWords(text) {
  return String(text).match(/(?:"(?:\\.|[^"])*"|'[^']*'|\\.|[^\s"'])+/g) ?? [];
}

function normalizeForLiveSaveMatch(text) {
  return String(text).replace(/\\ /g, " ").replace(/%20/gi, " ").replace(/["']/g, "");
}

function unwrapScratchPart(part) {
  let cleaned = part;
  if (
    cleaned.length >= 2 &&
    ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
      (cleaned.startsWith("'") && cleaned.endsWith("'")))
  ) {
    cleaned = cleaned.slice(1, -1);
  }
  return cleaned.replace(/\\ /g, " ").replace(/%20/gi, " ");
}

function isAllowedScratchSavePath(part) {
  const cleaned = unwrapScratchPart(part);
  if (PARENT_TRAVERSAL.test(cleaned) || SHELL_EXPANSION.test(cleaned) || cleaned.startsWith("~")) {
    return false;
  }
  const scratchMatch = SCRATCH_ARTIFACTS_PREFIX.exec(cleaned);
  if (!scratchMatch) return false;
  const liveMatch = LIVE_SAVE_SEGMENT.exec(cleaned);
  if (!liveMatch) return false;
  return scratchMatch.index < liveMatch.index;
}

function touchesLiveSavePath(text, { isFilePath = false } = {}) {
  const str = String(text);
  const normalizedFull = normalizeForLiveSaveMatch(str);
  const totalMatches = normalizedFull.match(LIVE_SAVE_SEGMENT_GLOBAL)?.length ?? 0;
  if (totalMatches === 0) return false;
  if (isFilePath) {
    return !isAllowedScratchSavePath(str);
  }
  let allowedMatches = 0;
  for (const word of splitShellWords(str)) {
    for (const part of word.split(/[=<>|;&()]+/).filter(Boolean)) {
      const partMatches =
        normalizeForLiveSaveMatch(part).match(LIVE_SAVE_SEGMENT_GLOBAL)?.length ?? 0;
      if (partMatches === 0) continue;
      if (!isAllowedScratchSavePath(part)) return true;
      allowedMatches += partMatches;
    }
  }
  return allowedMatches < totalMatches;
}

function parseGitInvocation(segment) {
  const tokens = tokenize(segment);
  const gitIdx = tokens.findIndex((t) => t === "git" || t.endsWith("/git"));
  if (gitIdx === -1) return null;

  let cDir = null;
  let i = gitIdx + 1;
  while (i < tokens.length) {
    const tok = tokens[i];
    if (tok === "--") {
      i += 1;
      break;
    }
    if (GIT_GLOBAL_VALUE_FLAGS.has(tok)) {
      if (tok === "-C" && i + 1 < tokens.length) {
        cDir = cDir ? path.join(cDir, tokens[i + 1]) : tokens[i + 1];
      }
      i += 2;
      continue;
    }
    if (tok.startsWith("-C") && tok.length > 2) {
      const val = tok.slice(2);
      cDir = cDir ? path.join(cDir, val) : val;
      i += 1;
      continue;
    }
    if (
      tok.startsWith("--git-dir=") ||
      tok.startsWith("--work-tree=") ||
      tok.startsWith("--namespace=") ||
      tok.startsWith("--exec-path=") ||
      tok.startsWith("--config-env=")
    ) {
      i += 1;
      continue;
    }
    if (tok.startsWith("-")) {
      i += 1;
      continue;
    }
    return { subcommand: tok, args: tokens.slice(i + 1), cDir };
  }
  return null;
}

function isForcePushArgs(args) {
  let seenRemote = false;
  for (let i = 0; i < args.length; i += 1) {
    const a = args[i];
    if (
      a === "--force" ||
      a === "-f" ||
      /^-[a-zA-Z]*f[a-zA-Z]*$/.test(a) ||
      a === "--force-with-lease" ||
      a === "--force-if-includes" ||
      a.startsWith("--force-with-lease=")
    ) {
      return true;
    }
    if (
      a === "-o" ||
      a === "--push-option" ||
      a === "--repo" ||
      a === "--receive-pack" ||
      a === "--exec"
    ) {
      i += 1;
      continue;
    }
    if (a.startsWith("-")) continue;
    if (!seenRemote) {
      seenRemote = true;
      continue;
    }
    if (a.startsWith("+")) return true;
  }
  return false;
}

function isPushToMainArgs(args) {
  const positionals = [];
  for (let i = 0; i < args.length; i += 1) {
    const a = args[i];
    if (
      a === "--repo" ||
      a === "--receive-pack" ||
      a === "--exec" ||
      a === "-o" ||
      a === "--push-option"
    ) {
      i += 1;
      continue;
    }
    if (a.startsWith("-")) continue;
    positionals.push(a);
  }
  if (positionals.length <= 1) return true;
  const refspecs = positionals.slice(1);
  return refspecs.some(
    (ref) =>
      ref === "main" ||
      ref.endsWith(":main") ||
      ref === "refs/heads/main" ||
      ref.endsWith(":refs/heads/main"),
  );
}

const GIT_TIMEOUT_MS = 3000;

function findRepoRoot(startDir) {
  let dir = path.resolve(startDir);
  for (;;) {
    if (existsSync(path.join(dir, ".git"))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

export function defaultInspectProjectGodot(
  repoDir,
  { checkWorkingTree = false, spawn = spawnSync } = {},
) {
  if (!repoDir) return false;
  let repoRoot = findRepoRoot(repoDir);
  if (!repoRoot) {
    repoRoot =
      gitOptional(["-C", repoDir, "rev-parse", "--show-toplevel"], {
        spawn,
        timeout: GIT_TIMEOUT_MS,
      }) || repoDir;
  }
  const wtPath = path.join(repoRoot, "sketches/core-loop/project.godot");
  if (existsSync(wtPath)) {
    const wtText = readFileSync(wtPath, "utf8");
    if (!wtText.includes("McpBridge")) return false;
    if (checkWorkingTree) return true;
  }
  const staged = gitOptional(
    ["-C", repoRoot, "diff", "--cached", "--name-only", "--", "sketches/core-loop/project.godot"],
    { spawn, timeout: GIT_TIMEOUT_MS },
  );
  if (staged) {
    const show = gitOptional(["-C", repoRoot, "show", ":sketches/core-loop/project.godot"], {
      spawn,
      timeout: GIT_TIMEOUT_MS,
    });
    if (show?.includes("McpBridge")) return true;
  }
  return false;
}

const COMMIT_VALUE_FLAGS = new Set([
  "-m",
  "--message",
  "-F",
  "--file",
  "-C",
  "--reuse-message",
  "-c",
  "--reedit-message",
  "--author",
  "--date",
  "--cleanup",
  "-t",
  "--template",
  "-u",
  "--untracked-files",
  "--fixup",
  "--squash",
  "-S",
  "--gpg-sign",
]);

function commitMayReadWorkingTree(args) {
  let afterDash = false;
  for (let i = 0; i < args.length; i += 1) {
    const a = args[i];
    if (afterDash) return true;
    if (a === "--") {
      afterDash = true;
      continue;
    }
    if (
      a === "-a" ||
      a === "--all" ||
      a === "-i" ||
      a === "--include" ||
      a === "-o" ||
      a === "--only" ||
      a === "--pathspec-from-file" ||
      a.startsWith("--pathspec-from-file=") ||
      (/^-[a-zA-Z]+$/.test(a) && (a.includes("a") || a.includes("i") || a.includes("o")))
    ) {
      return true;
    }
    if (COMMIT_VALUE_FLAGS.has(a)) {
      i += 1;
      continue;
    }
    if (a.startsWith("-")) continue;
    return true;
  }
  return false;
}

export function evaluateHook(payload, { inspectProjectGodot = defaultInspectProjectGodot } = {}) {
  const toolName = payload?.toolCall?.name ?? "";
  const args = payload?.toolCall?.args ?? {};
  const cwd = payload?.cwd ?? "";

  if (FILE_WRITE_TOOLS.has(toolName)) {
    const targetPath = String(
      args.Path ?? args.path ?? args.AbsolutePath ?? args.TargetFile ?? args.target_file ?? "",
    );
    if (touchesLiveSavePath(targetPath, { isFilePath: true })) {
      return deny(
        "Blocked by AGENTS.md: never modify Andrew's live Godot saves under ~/.local/share/godot/app_userdata/core-loop or ~/Library/Application Support/godot/app_userdata/core-loop. Use artifacts/local/ instead.",
      );
    }
    if (
      targetPath === "sketches/core-loop/package.json" ||
      targetPath.endsWith("/sketches/core-loop/package.json")
    ) {
      return ask(
        "AGENTS.md requires Andrew's go-ahead before editing sketches/core-loop/package.json.",
      );
    }
    return allow();
  }

  if (toolName === "run_command") {
    const cmd = String(args.CommandLine ?? args.commandLine ?? "");
    if (NPM_PUBLISH.test(cmd)) {
      return deny("Blocked by Scrapkeep safety policy: npm publish is denied.");
    }
    if (GH_REPO_DELETE.test(cmd)) {
      return deny("Blocked by AGENTS.md: deleting a repository is denied.");
    }
    if (touchesLiveSavePath(cmd)) {
      return deny(
        "Blocked by AGENTS.md: never access or modify Andrew's live Godot saves under ~/.local/share/godot/app_userdata/core-loop or ~/Library/Application Support/godot/app_userdata/core-loop. Set XDG_DATA_HOME/HOME under artifacts/local/.",
      );
    }

    const segments = splitShellSegments(cmd);
    let sawGitAdd = false;
    let askReason = null;

    for (const seg of segments) {
      const git = parseGitInvocation(seg);
      if (!git) continue;

      if (git.subcommand === "add") {
        sawGitAdd = true;
        continue;
      }

      if (git.subcommand === "push") {
        if (isForcePushArgs(git.args)) {
          return deny(
            "Blocked by AGENTS.md: force-push / history rewrite requires Andrew's explicit go-ahead.",
          );
        }
        const pushPos = [];
        for (let i = 0; i < git.args.length; i += 1) {
          const a = git.args[i];
          if (
            a === "--repo" ||
            a === "--receive-pack" ||
            a === "--exec" ||
            a === "-o" ||
            a === "--push-option"
          ) {
            i += 1;
            continue;
          }
          if (!a.startsWith("-")) pushPos.push(a);
        }
        const hasColonDelete = pushPos.slice(1).some((ref) => ref.startsWith(":"));
        if (
          git.args.some(
            (a) => a === "--delete" || a === "-d" || /^-[a-zA-Z]*d[a-zA-Z]*$/.test(a),
          ) ||
          hasColonDelete
        ) {
          askReason ??=
            "Confirm before deleting a remote branch with git push --delete or :<branch>.";
        }
        if (isPushToMainArgs(git.args)) {
          askReason ??=
            "Confirm before pushing directly to main or running an unqualified git push.";
        }
        continue;
      }

      if (git.subcommand === "commit") {
        const baseCwd = cwd || process.cwd();
        const repoDir = git.cDir ? path.resolve(baseCwd, git.cDir) : baseCwd;
        const stagesAll = sawGitAdd || commitMayReadWorkingTree(git.args);
        if (inspectProjectGodot(repoDir, { checkWorkingTree: stagesAll })) {
          return deny(
            "Blocked: McpBridge is present/staged in sketches/core-loop/project.godot. Call godot stop_project and remove McpBridge before committing.",
          );
        }
        continue;
      }

      if (git.subcommand === "reset" && git.args.includes("--hard")) {
        askReason ??= "Confirm before running git reset --hard.";
      }
      if (
        git.subcommand === "branch" &&
        git.args.some(
          (a) =>
            a === "-D" ||
            a === "-f" ||
            a === "--force" ||
            a === "-M" ||
            a === "-C" ||
            /^-[a-zA-Z]*[DfMC][a-zA-Z]*$/.test(a),
        )
      ) {
        askReason ??= "Confirm before force-deleting or overwriting a local branch.";
      }
    }

    if (askReason) return ask(askReason);
    if (NPM_PKG_MUTATE.test(cmd)) {
      return ask(
        "AGENTS.md requires Andrew's go-ahead for dependency changes (npm install/uninstall). Use npm ci for lockfile installs.",
      );
    }
    if (GH_REPO_OR_API.test(cmd)) {
      return ask("Confirm before running GitHub repo/API mutations (gh repo / gh api).");
    }
    return allow();
  }

  return allow();
}

function main() {
  const raw = readFileSync(0, "utf8");
  let payload;
  try {
    payload = JSON.parse(raw);
  } catch {
    process.stdout.write(
      JSON.stringify(ask("PreToolUse safety hook could not parse JSON stdin; confirm manually.")) +
        "\n",
    );
    return;
  }
  const result = evaluateHook(payload);
  process.stdout.write(JSON.stringify(result) + "\n");
}

if (
  process.argv[1] &&
  realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url))
) {
  main();
}
