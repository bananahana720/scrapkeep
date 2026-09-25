// JL-07: validates docs/playtests/verdicts.ndjson against the playtest log
// it indexes and the repository's commit history. PLAYTEST-LOG.md stays the
// prose source; this file never writes it.
//
// Usage as a library: validateVerdicts({ file, log, git }) -> { ok, problems }
// Usage as a CLI: `node scripts/lab/verdicts.mjs [--file <path>] [--log <path>]`
// exits 0 when the file is valid, 1 otherwise, printing each problem to
// stderr. `--file`/`--log` default to the real deliverable paths.

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
const LOG_ANCHOR_PREFIX = "docs/playtests/PLAYTEST-LOG.md";

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

// Splits the log into its "## ..." sections. Every section carries its own
// heading slug and body text; numbered "## N. ..." sections also carry
// their entry number, so a verdict record can be checked against its own
// section instead of the log as a whole.
function sections(logText) {
  const lines = logText.split(/\r?\n/);
  const headingRegex = /^##\s+(.*\S)\s*$/;
  const numberedRegex = /^(\d+)\./;
  const byEntry = new Map();
  let current = null;

  const flush = () => {
    if (current) {
      current.body = current.bodyLines.join("\n");
      if (current.entry !== null) {
        byEntry.set(current.entry, current);
      }
    }
  };

  for (const line of lines) {
    const heading = headingRegex.exec(line);
    if (heading) {
      flush();
      const text = heading[1];
      const numbered = numberedRegex.exec(text);
      current = {
        entry: numbered ? Number(numbered[1]) : null,
        slug: slugifyHeading(text),
        bodyLines: [],
      };
    } else if (current) {
      current.bodyLines.push(line);
    }
  }
  flush();

  return byEntry;
}

// Pulls just the "- **Verdict.** ..." bullet out of a section body, from its
// marker up to the next top-level bullet or the end of the section.
function verdictBullet(body) {
  const match = /-\s*\*\*Verdict\.\*\*[\s\S]*?(?=\n-\s*\*\*|$)/.exec(body);
  return match ? match[0] : "";
}

function commitExists(gitDir, sha) {
  const result = spawnSync("git", ["-C", gitDir, "cat-file", "-e", `${sha}^{commit}`], {
    encoding: "utf8",
  });
  return result.status === 0;
}

// Validates an NDJSON verdict index. `file` and `log` are filesystem paths;
// `git` points at the repository (or any checkout of it) used to confirm
// each build_sha names a real commit. Every field is checked against the
// specific PLAYTEST-LOG section its own "entry" names, not the log at
// large, so a quote, anchor or sha copied from a different entry fails.
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

  const bySection = sections(logText);
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

    let section = null;
    if (!Number.isInteger(entry) || entry < 1) {
      problems.push(`line ${lineNo}: "entry" must be a positive integer`);
    } else if (seenEntries.has(entry)) {
      problems.push(`line ${lineNo}: "entry" ${entry} is duplicated`);
    } else {
      seenEntries.add(entry);
      section = bySection.get(entry) ?? null;
      if (!section) {
        problems.push(`line ${lineNo}: "entry" ${entry} has no matching "## ${entry}." heading in the log`);
      }
    }

    let shaOk = false;
    if (typeof buildSha !== "string" || !FULL_SHA.test(buildSha)) {
      problems.push(`line ${lineNo}: "build_sha" must be a full 40-hex commit sha`);
    } else if (!commitExists(git, buildSha)) {
      problems.push(`line ${lineNo}: "build_sha" ${buildSha} is not a commit in the repository`);
    } else {
      shaOk = true;
    }

    if (shaOk && section) {
      const short = buildSha.slice(0, 7);
      if (!section.body.includes(`\`${short}\``)) {
        problems.push(
          `line ${lineNo}: "build_sha" ${buildSha} is not named as \`${short}\` in entry ${entry}'s section`,
        );
      }
    }

    if (typeof anchor !== "string" || anchor.indexOf("#") === -1) {
      problems.push(`line ${lineNo}: "anchor" must contain "#<heading>"`);
    } else if (section) {
      const expected = `${LOG_ANCHOR_PREFIX}#${section.slug}`;
      if (anchor !== expected) {
        problems.push(
          `line ${lineNo}: "anchor" ${anchor} does not equal entry ${entry}'s own heading anchor ${expected}`,
        );
      }
    }

    if (typeof quote !== "string" || quote.length === 0) {
      problems.push(`line ${lineNo}: "quote" must be a non-empty string`);
    } else if (section) {
      const bullet = verdictBullet(section.body);
      if (!bullet.includes(quote)) {
        problems.push(`line ${lineNo}: "quote" was not found verbatim in entry ${entry}'s Verdict bullet`);
      }
    }

    if (!Array.isArray(tags)) {
      problems.push(`line ${lineNo}: "tags" must be an array`);
    }
  });

  return { ok: problems.length === 0, problems };
}

function parseArgs(argv) {
  const args = { file: DEFAULT_FILE, log: DEFAULT_LOG };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--file" && argv[i + 1] !== undefined) {
      args.file = path.resolve(argv[i + 1]);
      i += 1;
    } else if (argv[i] === "--log" && argv[i + 1] !== undefined) {
      args.log = path.resolve(argv[i + 1]);
      i += 1;
    }
  }
  return args;
}

function isMain() {
  const invoked = process.argv[1] ? path.resolve(process.argv[1]) : "";
  return invoked === fileURLToPath(import.meta.url);
}

if (isMain()) {
  const { file, log } = parseArgs(process.argv.slice(2));
  const { ok, problems } = validateVerdicts({ file, log });
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
