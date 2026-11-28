#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import { isMain, parseCliArgs } from "./lib/cli.mjs";
import { DEFAULT_MAX_BUFFER, cwdDecidesRepository, git } from "./lib/git.mjs";

export const LIST_PATH = "scripts/ci/dated-records.json";
const RULES = ["frozen", "log"];
const MISSING = "of the base copy changed or went missing";
const ADVICE =
  "A dated record keeps the names and paths it was written with. Put the new fact in the page that describes the project today, or add a new dated entry. " +
  `If the page should no longer be protected, remove it from ${LIST_PATH} in the same change and say why in the pull request.`;

export class CouldNotRun extends Error {}

function attempt(what, todo, fn) {
  try {
    return fn();
  } catch (error) {
    throw new CouldNotRun(`${what}: ${error.message}\n  ${todo}`);
  }
}

export function parseList(text, source) {
  const parsed = attempt(`${source} is not valid JSON`, "Fix the file so it parses.", () =>
    JSON.parse(text),
  );
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new CouldNotRun(
      `${source} needs a JSON object with "frozen" and "log" arrays.\n  Fix the file.`,
    );
  }
  const rules = new Map();
  for (const rule of RULES) {
    const pages = parsed[rule];
    if (!Array.isArray(pages) || pages.some((p) => typeof p !== "string" || !p)) {
      throw new CouldNotRun(
        `${source} needs "${rule}" as an array of repo-relative paths.\n  Fix the file.`,
      );
    }
    for (const page of pages) {
      if (rules.has(page)) {
        throw new CouldNotRun(`${source} lists ${page} twice.\n  Keep it under one rule.`);
      }
      rules.set(page, rule);
    }
  }
  return rules;
}

export function datedRecordPaths(cwd) {
  try {
    const listed = parseList(readFileSync(path.join(cwd, LIST_PATH), "utf8"), LIST_PATH);
    return new Set([LIST_PATH, ...listed.keys()]);
  } catch {
    return null;
  }
}

function treeEntries(commit, pages, cwd) {
  const ids = new Map();
  if (pages.length === 0) return ids;
  const out = attempt(
    `could not list the tree of ${commit}`,
    "Fetch the commit (git fetch origin) and run the check again.",
    () =>
      git(["--literal-pathspecs", "ls-tree", "-r", "-z", commit, "--", ...pages], {
        cwd,
        trim: false,
      }),
  );
  for (const entry of out.split("\0").filter(Boolean)) {
    const [meta, page] = entry.split("\t");
    const [mode, , id] = meta.split(" ");
    ids.set(page, { mode, id });
  }
  return ids;
}

function readBlob(commit, page, { id }, cwd) {
  const todo =
    "The page is in that commit's tree but git could not give its content (a blobless clone fetches it on demand). Fetch it (git fetch origin) and run the check again; the check does not pass a page it could not read.";
  const ran = spawnSync("git", ["cat-file", "blob", id], {
    cwd,
    env: cwdDecidesRepository(),
    maxBuffer: DEFAULT_MAX_BUFFER,
  });
  if (ran.error || ran.status !== 0) {
    const why = ran.error?.message || String(ran.stderr).trim();
    throw new CouldNotRun(`could not read ${page} at ${commit}: ${why}\n  ${todo}`);
  }
  const algorithm = id.length === 64 ? "sha256" : "sha1";
  const got = createHash(algorithm)
    .update(`blob ${ran.stdout.length}\0`)
    .update(ran.stdout)
    .digest("hex");
  if (got !== id) {
    throw new CouldNotRun(
      `could not read ${page} at ${commit}: the content git gave does not match its blob id ${id}\n  ${todo}`,
    );
  }
  return ran.stdout;
}

function lines(bytes) {
  return bytes.toString("latin1").replace(/\n$/, "").split("\n");
}

function quoted(line) {
  return Buffer.from(line, "latin1").toString("utf8");
}

export function firstBrokenLine(rule, baseBytes, headBytes) {
  if (baseBytes.equals(headBytes)) return null;
  const base = lines(baseBytes);
  const head = lines(headBytes);
  if (rule === "frozen") {
    let i = 0;
    while (i < base.length && i < head.length && base[i] === head[i]) i++;
    if (i < base.length) return { line: i + 1, text: quoted(base[i]), kind: MISSING };
    if (i < head.length) {
      return { line: i + 1, text: quoted(head[i]), kind: "was added at the head" };
    }
    return { endNewline: true };
  }
  if (baseBytes.length === 0) return null;
  let h = 0;
  for (let b = 0; b < base.length; b++) {
    while (h < head.length && head[h] !== base[b]) h++;
    if (h === head.length) return { line: b + 1, text: quoted(base[b]), kind: MISSING };
    h++;
  }
  return null;
}

export function checkDatedRecords({ base, head = "HEAD", cwd }) {
  if (!base) {
    throw new CouldNotRun(
      "--base <ref> is missing.\n  Name the commit to compare with: the pull request's base in CI, the pushed range's base in the hook.",
    );
  }
  const resolve = (flag, ref) =>
    attempt(
      `${flag} ${ref} is not a commit git can resolve`,
      `Fetch it (git fetch origin) or name another ref.`,
      () => git(["rev-parse", "--verify", "--end-of-options", `${ref}^{commit}`], { cwd }),
    );
  const baseSha = resolve("--base", base);
  const headSha = resolve("--head", head);
  const mergeBase = attempt(
    `git merge-base ${base} ${head} failed`,
    "The two commits share no history in this clone. Fetch the full history (git fetch --unshallow origin) and run the check again.",
    () => git(["merge-base", baseSha, headSha], { cwd }),
  );

  const listText = attempt(
    `could not read the list ${LIST_PATH}`,
    "Run the check from a checkout that has the list.",
    () => readFileSync(path.join(cwd, LIST_PATH), "utf8"),
  );
  const rules = parseList(listText, LIST_PATH);
  const pages = [...rules.keys()];
  const atBase = treeEntries(mergeBase, pages, cwd);
  const atHead = treeEntries(headSha, pages, cwd);
  const tracked = new Set(
    pages.length === 0
      ? []
      : attempt("could not list the tracked files", "Run the check inside the repository.", () =>
          git(["--literal-pathspecs", "ls-files", "-z", "--", ...pages], { cwd, trim: false }),
        ).split("\0"),
  );
  const unknown = pages.filter((p) => !atBase.has(p) && !atHead.has(p) && !tracked.has(p));
  if (unknown.length) {
    throw new CouldNotRun(
      `${LIST_PATH} names ${unknown.join(", ")}, which matches no tracked file.\n  Fix the path, or remove it from the list.`,
    );
  }

  let dropped = [];
  const listAtBase = treeEntries(mergeBase, [LIST_PATH], cwd).get(LIST_PATH);
  if (listAtBase) {
    const baseRules = parseList(
      readBlob(mergeBase, LIST_PATH, listAtBase, cwd).toString("utf8"),
      `${LIST_PATH} at ${base}`,
    );
    const gone = [...baseRules.keys()].filter((p) => !rules.has(p));
    const present = treeEntries(mergeBase, gone, cwd);
    dropped = gone.filter((p) => present.has(p));
  }

  const findings = [];
  for (const [page, rule] of rules) {
    if (!atBase.has(page)) continue;
    if (!atHead.has(page)) {
      findings.push({ page, rule, gone: true });
      continue;
    }
    const was = atBase.get(page);
    const now = atHead.get(page);
    if (rule === "frozen" && was.mode !== now.mode) {
      findings.push({ page, rule, mode: [was.mode, now.mode] });
    }
    if (was.id === now.id) continue;
    const broken = firstBrokenLine(
      rule,
      readBlob(mergeBase, page, was, cwd),
      readBlob(headSha, page, now, cwd),
    );
    if (broken) findings.push({ page, rule, ...broken });
  }
  return { findings, dropped, checked: pages.length, mergeBase, headSha };
}

function describe(finding) {
  if (finding.gone) return "is gone at the head (deleted or renamed)";
  if (finding.mode) {
    const [was, now] = finding.mode;
    return `changed its file mode from ${was} to ${now}; set it back to ${was}`;
  }
  if (finding.endNewline) {
    return "has the newline at the end of the file added or removed; make the end of the file exactly as it is at the base";
  }
  const text = finding.text === "" ? "(an empty line)" : finding.text;
  return `line ${finding.line} ${finding.kind}:\n    ${text}`;
}

export function formatFinding(finding) {
  const what = describe(finding);
  return `dated-records: ${finding.page} (${finding.rule}) ${what}\n  ${ADVICE}`;
}

if (isMain(import.meta.url)) {
  try {
    const opts = attempt(
      "bad arguments",
      "Usage: node scripts/dated-records.mjs --base <ref> [--head <ref>]",
      () =>
        parseCliArgs(process.argv.slice(2), {
          values: { "--base": "base", "--head": "head" },
          defaults: { head: "HEAD" },
        }),
    );
    const cwd = attempt("not inside a git checkout", "Run the check inside the repository.", () =>
      git(["rev-parse", "--show-toplevel"], { cwd: process.cwd() }),
    );
    const result = checkDatedRecords({ base: opts.base, head: opts.head, cwd });
    for (const page of result.dropped) {
      console.log(`dated-records: ${page} was dropped from the list and is no longer checked`);
    }
    for (const finding of result.findings) console.error(formatFinding(finding));
    const range = `${result.mergeBase.slice(0, 9)}..${result.headSha.slice(0, 9)}`;
    if (result.findings.length) {
      console.error(
        `dated-records: FAIL, ${result.findings.length} finding(s) on listed pages (${range})`,
      );
      process.exitCode = 1;
    } else if (result.checked === 0) {
      console.log(`dated-records: PASS, no page is listed in ${LIST_PATH} (${range})`);
    } else {
      console.log(
        `dated-records: PASS, ${result.checked} listed page(s) kept their rule (${range})`,
      );
    }
  } catch (error) {
    console.error(`dated-records: could not run: ${error.message}`);
    process.exitCode = 2;
  }
}
