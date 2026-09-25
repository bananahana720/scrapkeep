// JL-07: validates docs/playtests/verdicts.ndjson against the playtest log
// it indexes and the repository's commit history. PLAYTEST-LOG.md stays the
// prose source; this file never writes it.
//
// Usage as a library: validateVerdicts({ file, log, git }) -> { ok, problems }
// Usage as a CLI: `node scripts/lab/verdicts.mjs` exits 0 when the default
// file is valid, 1 otherwise, printing each problem to stderr.

import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..");

const DEFAULT_FILE = path.join(repoRoot, "docs", "playtests", "verdicts.ndjson");
const DEFAULT_LOG = path.join(repoRoot, "docs", "playtests", "PLAYTEST-LOG.md");
const DEFAULT_GIT = repoRoot;

const FULL_SHA = /^[0-9a-f]{40}$/;

// GitHub's heading-anchor algorithm, close enough for our headings: lower
// case, drop anything that is not a word character, space or hyphen, then
// turn runs of whitespace into single hyphens.
function slugifyHeading(text) {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^\w\- ]+/g, "")
    .replace(/\s+/g, "-");
}

function headingSlugs(logText) {
  const slugs = new Set();
  for (const line of logText.split(/\r?\n/)) {
    const heading = /^#{1,6}\s+(.*\S)\s*$/.exec(line);
    if (heading) {
      slugs.add(slugifyHeading(heading[1]));
    }
  }
  return slugs;
}

function commitExists(gitDir, sha) {
  const result = spawnSync("git", ["-C", gitDir, "cat-file", "-e", `${sha}^{commit}`], {
    encoding: "utf8",
  });
  return result.status === 0;
}

// Validates an NDJSON verdict index. Every argument is a filesystem path;
// `git` points at the repository (or any checkout of it) used to confirm
// each build_sha names a real commit.
export function validateVerdicts({ file = DEFAULT_FILE, log = DEFAULT_LOG, git = DEFAULT_GIT } = {}) {
  const problems = [];

  let raw;
  try {
    raw = readFileSync(file, "utf8");
  } catch (err) {
    return { ok: false, problems: [`cannot read verdicts file ${file}: ${err.message}`] };
  }

  let logText;
  try {
    logText = readFileSync(log, "utf8");
  } catch (err) {
    return { ok: false, problems: [`cannot read playtest log ${log}: ${err.message}`] };
  }

  const slugs = headingSlugs(logText);
  const lines = raw.split(/\r?\n/).filter((line) => line.trim().length > 0);

  const seenEntries = new Set();

  lines.forEach((line, index) => {
    const lineNo = index + 1;
    let record;
    try {
      record = JSON.parse(line);
    } catch (err) {
      problems.push(`line ${lineNo}: not valid JSON (${err.message})`);
      return;
    }

    if (record === null || typeof record !== "object" || Array.isArray(record)) {
      problems.push(`line ${lineNo}: record must be a JSON object`);
      return;
    }

    const { entry, build_sha: buildSha, anchor, quote, tags } = record;

    if (!Number.isInteger(entry) || entry < 1) {
      problems.push(`line ${lineNo}: "entry" must be a positive integer`);
    } else if (seenEntries.has(entry)) {
      problems.push(`line ${lineNo}: "entry" ${entry} is duplicated`);
    } else {
      seenEntries.add(entry);
    }

    if (typeof buildSha !== "string" || !FULL_SHA.test(buildSha)) {
      problems.push(`line ${lineNo}: "build_sha" must be a full 40-hex commit sha`);
    } else if (!commitExists(git, buildSha)) {
      problems.push(`line ${lineNo}: "build_sha" ${buildSha} is not a commit in the repository`);
    }

    if (typeof anchor !== "string" || anchor.indexOf("#") === -1) {
      problems.push(`line ${lineNo}: "anchor" must contain "#<heading>"`);
    } else {
      const fragment = anchor.slice(anchor.indexOf("#") + 1);
      if (fragment.length === 0 || !slugs.has(fragment)) {
        problems.push(`line ${lineNo}: "anchor" ${anchor} does not resolve to a heading in the log`);
      }
    }

    if (typeof quote !== "string" || quote.length === 0) {
      problems.push(`line ${lineNo}: "quote" must be a non-empty string`);
    } else if (!logText.includes(quote)) {
      problems.push(`line ${lineNo}: "quote" was not found verbatim in the playtest log`);
    }

    if (!Array.isArray(tags)) {
      problems.push(`line ${lineNo}: "tags" must be an array`);
    }
  });

  return { ok: problems.length === 0, problems };
}

function isMain() {
  const invoked = process.argv[1] ? path.resolve(process.argv[1]) : "";
  return invoked === fileURLToPath(import.meta.url);
}

if (isMain()) {
  const { ok, problems } = validateVerdicts({});
  if (ok) {
    console.log("verdicts: every line checks out");
    process.exit(0);
  } else {
    for (const problem of problems) {
      console.error(problem);
    }
    process.exit(1);
  }
}
