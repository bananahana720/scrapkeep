import { spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import {
  mkdir,
  open,
  readFile,
  readdir,
  rename,
  rm,
  writeFile,
} from "node:fs/promises";
import path from "node:path";
import { setTimeout as sleep } from "node:timers/promises";

export const SCHEMA = "scrapkeep-run/1";
export const RESULTS = ["pass", "fail", "inconclusive", "invalid"];

const repositoryRoot = path.resolve(import.meta.dirname, "../..");
export const RUNS_ROOT = path.join(repositoryRoot, "artifacts/local/runs");
export const DEFAULT_SOURCES = [
  "package.json",
  "package-lock.json",
  "src",
  "scripts",
  "tools",
  "sketches",
  "native",
];

const slug = /^[a-z0-9][a-z0-9-]*$/;
const uuidPattern = /^[0-9a-f]{8,}$/;
const lockWaitMs = 10_000;
const tokenFields = [
  "input_tokens",
  "output_tokens",
  "cache_read_input_tokens",
  "cache_creation_input_tokens",
];

function git(repository, ...args) {
  const result = spawnSync("git", args, {
    cwd: repository,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  if (result.status !== 0)
    throw new Error(
      `git ${args[0]} failed in ${repository}: ${(result.stderr || result.error?.message || "").trim()}`,
    );
  return result.stdout;
}

// Registry shape belongs to JL-02, so the writer accepts the forms a merged
// registry is likely to take: a Map or plain object keyed by id, or a list of
// definitions that each carry an `id`.
function metricIds(registry) {
  if (registry instanceof Map) return new Set(registry.keys());
  if (Array.isArray(registry)) return new Set(registry.map((one) => one.id));
  if (registry && typeof registry === "object")
    return new Set(Object.keys(registry));
  throw new Error("createRun needs an injected metric registry.");
}

// Tracked plus untracked-but-not-ignored files, so engine caches and other
// ignored output can change during a run without voiding it, while a new
// source file still counts. A tracked file deleted from the tree is left out,
// which changes the key set and therefore the digest.
async function sourceHashes(repository, sources) {
  const listed = git(
    repository,
    "ls-files",
    "-z",
    "--cached",
    "--others",
    "--exclude-standard",
    "--",
    ...sources,
  )
    .split("\0")
    .filter(Boolean);
  const files = {};
  for (const file of [...new Set(listed)].sort()) {
    let bytes;
    try {
      bytes = await readFile(path.join(repository, file));
    } catch (error) {
      if (error.code === "ENOENT" || error.code === "EISDIR") continue;
      throw error;
    }
    files[file] = createHash("sha256").update(bytes).digest("hex");
  }
  const digest = createHash("sha256");
  for (const [file, hash] of Object.entries(files))
    digest.update(`${file}\0${hash}\n`);
  return { files, digest: digest.digest("hex") };
}

function changedFiles(before, after) {
  return [...new Set([...Object.keys(before), ...Object.keys(after)])]
    .filter((file) => before[file] !== after[file])
    .sort();
}

function checkMeasure(id, measure) {
  const { value, n, ci } = measure ?? {};
  const valid =
    measure !== null &&
    typeof measure === "object" &&
    "ci" in measure &&
    (value === null || Number.isFinite(value)) &&
    Number.isInteger(n) &&
    n >= 0 &&
    (ci === null ||
      (Array.isArray(ci) &&
        ci.length === 2 &&
        ci.every(Number.isFinite) &&
        ci[0] <= ci[1]));
  if (!valid)
    throw new Error(
      `metric "${id}" must be {value, n, ci} with a finite or null value, a whole n and a [low, high] or null ci`,
    );
  return { value, n, ci };
}

function timestamp(now) {
  return now
    .toISOString()
    .replace(/\.\d{3}/, "")
    .replace(/[-:]/g, "");
}

// Tolerant of a corrupted or hand-edited index: blank lines are dropped and
// each remaining one is parsed on its own, so one bad line cannot hide seq
// collisions on every other line.
function parseIndexLines(text) {
  return text
    .split("\n")
    .filter((line) => line.trim() !== "")
    .map((line) => JSON.parse(line));
}

// A line count is wrong the moment a line is missing or duplicated; the next
// seq is one past the highest one actually on disk.
function nextSeq(lines) {
  if (lines.length === 0) return 0;
  return Math.max(...lines.map((line) => line.seq)) + 1;
}

function indexLine(record) {
  return (
    JSON.stringify({
      seq: record.seq,
      id: record.id,
      type: record.type,
      label: record.label,
      result: record.result,
      started_at: record.started_at,
      finished_at: record.finished_at,
      head: record.provenance.head,
      dirty: record.provenance.dirty,
    }) + "\n"
  );
}

// Concurrent runs finish in any order. The lock makes "assign seq, write
// run.json, append" one step, so append order equals seq order and a rebuild
// sorted by seq is byte-identical. A lock left by a killed process is not
// broken automatically: two waiters breaking it at once could both proceed.
async function withIndexLock(root, work) {
  const lock = path.join(root, "index.lock");
  const deadline = Date.now() + lockWaitMs;
  for (;;) {
    try {
      const handle = await open(lock, "wx");
      await handle.writeFile(JSON.stringify({ pid: process.pid }));
      await handle.close();
      break;
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
      if (Date.now() > deadline) {
        const holder = await readFile(lock, "utf8").catch(() => "unreadable");
        throw new Error(
          `${lock} has been held for ${lockWaitMs} ms by ${holder}; remove it once that process is confirmed gone.`,
        );
      }
      await sleep(10);
    }
  }
  try {
    return await work();
  } finally {
    await rm(lock, { force: true });
  }
}

async function buildIndex(root) {
  const records = [];
  let listing;
  try {
    listing = await readdir(root, { withFileTypes: true });
  } catch (error) {
    if (error.code === "ENOENT") return "";
    throw error;
  }
  for (const entry of listing) {
    if (!entry.isDirectory()) continue;
    let text;
    try {
      text = await readFile(path.join(root, entry.name, "run.json"), "utf8");
    } catch (error) {
      if (error.code === "ENOENT") continue;
      throw error;
    }
    const record = JSON.parse(text);
    if (record.schema === SCHEMA) records.push(record);
  }
  records.sort((a, b) => a.seq - b.seq || a.id.localeCompare(b.id));
  return records.map(indexLine).join("");
}

async function replaceIndex(root, text) {
  const index = path.join(root, "index.ndjson");
  const temporary = `${index}.${process.pid}.tmp`;
  await writeFile(temporary, text);
  await rename(temporary, index);
}

async function readIndex(root) {
  try {
    return await readFile(path.join(root, "index.ndjson"), "utf8");
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

export async function rebuildIndex({ root = RUNS_ROOT, write = false } = {}) {
  if (!write) return buildIndex(root);
  return withIndexLock(root, async () => {
    const text = await buildIndex(root);
    await replaceIndex(root, text);
    return text;
  });
}

export async function createRun({
  type,
  label,
  registry,
  root = RUNS_ROOT,
  repository = repositoryRoot,
  sources = DEFAULT_SOURCES,
  config = {},
  versions = {},
  instrument = null,
  now = new Date(),
  uuid = randomUUID().replaceAll("-", ""),
} = {}) {
  if (!slug.test(type ?? ""))
    throw new Error(`run type "${type}" is not a slug`);
  if (!slug.test(label ?? ""))
    throw new Error(`run label "${label}" is not a slug`);
  if (!uuidPattern.test(uuid))
    throw new Error(`uuid "${uuid}" must match ${uuidPattern}`);
  const known = metricIds(registry);
  const provenance = {
    head: git(repository, "rev-parse", "HEAD").trim(),
    branch: git(repository, "branch", "--show-current").trim() || null,
    dirty: git(repository, "status", "--porcelain").trim() !== "",
    sources: null,
    versions: { node: process.version, ...versions },
    instrument,
    jev: {
      model: null,
      calls: 0,
      cache_hits: 0,
      ...Object.fromEntries(tokenFields.map((field) => [field, 0])),
    },
  };
  const start = await sourceHashes(repository, sources);

  const id = `${timestamp(now)}-${type}-${label}-${uuid.slice(0, 8)}`;
  const directory = path.join(root, id);
  await mkdir(directory, { recursive: true });
  // Exclusive creation refuses a second claim even when both callers raced to
  // an empty directory, as in tools/agent-player/run.py.
  const owner = await open(path.join(directory, "run-owner.json"), "wx");
  await owner.writeFile(
    JSON.stringify({
      type,
      label,
      pid: process.pid,
      started_at: now.toISOString(),
    }) + "\n",
  );
  await owner.close();

  const kpis = {};
  const kris = {};
  const findings = [];
  const limits = [];
  let finished = false;

  function measure(bucket, metricId, value) {
    if (!known.has(metricId))
      throw new Error(
        `unknown metric id "${metricId}"; it is not in the registry`,
      );
    if (metricId in kpis || metricId in kris)
      throw new Error(`metric "${metricId}" is already recorded in this run`);
    bucket[metricId] = checkMeasure(metricId, value);
  }

  return {
    id,
    directory,
    provenance,
    kpi: (metricId, value) => measure(kpis, metricId, value),
    kri: (metricId, value) => measure(kris, metricId, value),
    finding(finding) {
      if (typeof finding?.repro !== "string" || finding.repro.trim() === "")
        throw new Error("a finding needs a repro command");
      findings.push(finding);
    },
    limit(text) {
      limits.push(String(text));
    },
    jev({ model, usage = {}, cached = false }) {
      const jev = provenance.jev;
      if (jev.model !== null && model !== jev.model)
        throw new Error(
          `Jev model "${model}" differs from "${jev.model}" earlier in this run`,
        );
      jev.model = model;
      if (cached) {
        jev.cache_hits += 1;
        return;
      }
      jev.calls += 1;
      for (const field of tokenFields) jev[field] += usage[field] ?? 0;
    },
    async finish({ result }) {
      if (finished) throw new Error(`run ${id} is already finished`);
      if (!RESULTS.includes(result))
        throw new Error(
          `result "${result}" is not one of ${RESULTS.join(", ")}`,
        );
      const end = await sourceHashes(repository, sources);
      const changed = changedFiles(start.files, end.files);
      // Per-file hashes are bulky (thousands of entries under DEFAULT_SOURCES)
      // and buildIndex/rebuildIndex never need them, so they live beside
      // run.json rather than inside it; the digests and changed list stay.
      provenance.sources = {
        paths: sources,
        start: start.digest,
        end: end.digest,
        matched: start.digest === end.digest,
        changed,
      };
      if (!provenance.sources.matched) {
        limits.push(
          `${changed.length} source files changed during the run, so the recorded result "${result}" was replaced with "inconclusive".`,
        );
        result = "inconclusive";
      }
      await mkdir(root, { recursive: true });
      const record = await withIndexLock(root, async () => {
        let existing = await readIndex(root);
        if (existing === null) {
          existing = await buildIndex(root);
          await replaceIndex(root, existing);
        }
        const seq = nextSeq(parseIndexLines(existing));
        const built = {
          schema: SCHEMA,
          id,
          type,
          label,
          result,
          seq,
          started_at: now.toISOString(),
          finished_at: new Date().toISOString(),
          provenance,
          config,
          kpis,
          kris,
          findings,
          limits,
        };
        await writeFile(
          path.join(directory, "run.json"),
          JSON.stringify(built, null, 2) + "\n",
        );
        await writeFile(
          path.join(directory, "sources.json"),
          JSON.stringify({ start: start.files, end: end.files }, null, 2) +
            "\n",
        );
        // A missing trailing newline would glue this append onto the last
        // line, so it is repaired on disk before the append lands.
        if (existing.length > 0 && !existing.endsWith("\n")) {
          await replaceIndex(root, existing + "\n");
        }
        await writeFile(path.join(root, "index.ndjson"), indexLine(built), {
          flag: "a",
        });
        return built;
      });
      finished = true;
      return record;
    },
  };
}
