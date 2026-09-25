// JL-20: tags Andrew's playtest verdicts with what his words talk about.
//
// Each tag in verdict-tags.json is one typed Jev Noul over the verdict quote.
// A tag says what the words cover (movement, level shape, abilities...); it
// never says whether he liked the build. His verdict is the quote itself.
//
// Rules this file keeps (plan section 5):
// - Jev decides; the deterministic fallback is "leave tags untouched" and say
//   why, so a missing key, an error, a malformed answer or the call cap never
//   fills anything.
// - An entry's tags are filled only when every tag's Jev answer reproduces
//   that entry's hand label. An entry with no hand label is never filled, and
//   hand labels are only read, never written.
// - Every Noul for a verdict is asked in one request in the vocabulary's
//   order, then again in exact reverse order; the two are averaged and their
//   gap reported, because Jev showed option-order effects in this program
//   (TRACKING EV-0526/EV-0527).
// - The quote is redacted before it leaves the machine; answers are cached per
//   request, so a rerun makes no calls.
// - Nothing on the gate path imports this file.
//
// CLI: node scripts/lab/verdict-tags.mjs [--live] [--write]
//   Without --live it reads the cache only and makes no network call.
//   --write puts reproduced tags into docs/playtests/verdicts.ndjson.
import { createHash } from "node:crypto";
import { appendFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { canonicalJson } from "../../tools/jev-player/protocol/protocol.mjs";
import { apiKey } from "../../tools/jev-player/decide.mjs";
import { openVerdictCache } from "./verdict-cache.mjs";
import { validateVerdicts } from "./verdicts.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..");

export const VOCAB_FILE = path.join(here, "verdict-tags.json");
export const VERDICTS_FILE = path.join(repoRoot, "docs", "playtests", "verdicts.ndjson");
export const LIVE_DIR = path.join(repoRoot, "artifacts", "local", "tasks", "JL-20", "live");
// Live calls authorized at EV-0484 are capped at 20 for this card, across runs.
export const CALL_CAP = 20;

// Same endpoint and alias as tools/jev-player/decide.mjs.
const ENDPOINT = "https://api.typesafe.ai/v1/systemone";
const MODEL = "jev-latest";
const PROTOCOL = "scrapkeep-verdict-tags/1";

export function loadVocab(file = VOCAB_FILE) {
  const bytes = readFileSync(file);
  const sha = createHash("sha256").update(bytes).digest("hex");
  return { ...JSON.parse(bytes), sha };
}

// Applied in order; an earlier pattern's placeholder cannot match a later one.
const REDACTIONS = [
  [/\b[A-Z][A-Z0-9_]*(?:KEY|TOKEN|SECRET|PASSWORD)[A-Z0-9_]*\s*[=:]\s*\S+/g, "[secret]"],
  [/\bBearer\s+\S+/gi, "Bearer [token]"],
  [/\b(?:sk|pk|ts|ghp|gho|xox[abp])[-_][A-Za-z0-9_-]{16,}/g, "[token]"],
  [/[A-Za-z0-9+/_-]{40,}/g, "[token]"],
  [/[\w.+-]+@[\w-]+\.[\w.-]+/g, "[email]"],
  [/\b\d{6,8}\b/g, "[code]"],
];

export function redact(text) {
  let out = text;
  let redactions = 0;
  for (const [pattern, placeholder] of REDACTIONS) {
    out = out.replace(pattern, () => {
      redactions += 1;
      return placeholder;
    });
  }
  return { text: out, redactions };
}

function orderedTags(vocab, order) {
  if (order === "forward") {
    return vocab.tags;
  } else if (order === "reverse") {
    return [...vocab.tags].reverse();
  } else {
    throw new Error(`unknown question order "${order}"`);
  }
}

export function buildRequest(quote, vocab, order) {
  const questions = {};
  for (const tag of orderedTags(vocab, order)) {
    questions[tag.id] = { type: "noul", instructions: tag.instructions, criteria: tag.criteria };
  }
  return { model: MODEL, state: { [vocab.state_field ?? "verdict"]: redact(quote).text }, questions };
}

// canonicalJson sorts keys, so the question order is keyed separately.
export function cacheKey(request) {
  const body = canonicalJson({ protocol: PROTOCOL, request, order: Object.keys(request.questions) });
  return createHash("sha256").update(body).digest("hex");
}

function nouls(answers, vocab) {
  const out = {};
  for (const tag of vocab.tags) {
    const answer = answers?.[tag.id];
    const value = answer?.noul;
    if (answer?.type !== "noul" || typeof value !== "number" || !(value >= 0 && value <= 1)) {
      throw new Error(`Jev returned no Noul for "${tag.id}"`);
    }
    out[tag.id] = value;
  }
  return out;
}

class Fallback extends Error {}

// Scores each hand-labelled record. `call(request, meta)` returns
// { answers, model, usage } or throws; null means no live call is allowed.
// `maxCalls` bounds live calls in this run; cache hits are free.
export async function tagVerdicts({ records, vocab, call, cache, maxCalls = CALL_CAP }) {
  const threshold = vocab.decision.yes_at_or_above;
  const run = {
    vocab_version: vocab.version,
    vocab_sha: vocab.sha,
    tag_order_forward: vocab.tags.map((tag) => tag.id),
    calls: 0,
    cache_hits: 0,
    usage: { input_tokens: 0, output_tokens: 0 },
    models: [],
    max_order_gap: 0,
    entries: [],
  };
  const models = new Set();

  const ask = async (record, order) => {
    const request = buildRequest(record.quote, vocab, order);
    const key = cacheKey(request);
    const cached = await cache.get(key);
    if (cached !== null) {
      run.cache_hits += 1;
      models.add(cached.model);
      return nouls(cached.answers, vocab);
    }
    if (typeof call !== "function") {
      throw new Fallback("not cached and no live call authorized (run with --live)");
    }
    if (run.calls >= maxCalls) {
      throw new Fallback(`live call cap of ${maxCalls} reached`);
    }
    run.calls += 1;
    let reply;
    try {
      reply = await call(request, { entry: record.entry, order, key });
    } catch (error) {
      throw new Fallback(error.message);
    }
    run.usage.input_tokens += reply.usage?.input_tokens ?? 0;
    run.usage.output_tokens += reply.usage?.output_tokens ?? 0;
    models.add(reply.model);
    let values;
    try {
      values = nouls(reply.answers, vocab);
    } catch (error) {
      throw new Fallback(error.message);
    }
    await cache.put(key, { request, answers: reply.answers, model: reply.model, usage: reply.usage });
    return values;
  };

  for (const record of records) {
    const labels = vocab.hand_labels.entries[String(record.entry)];
    if (labels === undefined) {
      run.entries.push({ entry: record.entry, outcome: "unlabelled", reason: "no hand label; never filled" });
      continue;
    }
    let forward;
    let reverse;
    try {
      forward = await ask(record, "forward");
      reverse = await ask(record, "reverse");
    } catch (error) {
      if (error instanceof Fallback) {
        run.entries.push({ entry: record.entry, outcome: "fallback", reason: error.message });
        continue;
      }
      throw error;
    }
    const perTag = vocab.tags.map((tag) => {
      const mean = (forward[tag.id] + reverse[tag.id]) / 2;
      const jev = mean >= threshold;
      const gap = Math.abs(forward[tag.id] - reverse[tag.id]);
      run.max_order_gap = Math.max(run.max_order_gap, gap);
      return {
        id: tag.id,
        hand: labels[tag.id],
        forward: forward[tag.id],
        reverse: reverse[tag.id],
        mean,
        order_gap: gap,
        jev,
        agrees: jev === labels[tag.id],
      };
    });
    const disagreements = perTag.filter((row) => !row.agrees);
    const result = { entry: record.entry, outcome: disagreements.length === 0 ? "reproduced" : "disagrees" };
    if (result.outcome === "reproduced") {
      result.tags = perTag.filter((row) => row.hand === true).map((row) => row.id);
    }
    result.disagreements = disagreements;
    result.per_tag = perTag;
    run.entries.push(result);
  }
  run.models = [...models];
  return run;
}

// Rewrites only the lines of reproduced entries, and only their tags.
export function applyTags(text, run) {
  const fill = new Map(
    run.entries.filter((result) => result.outcome === "reproduced").map((result) => [result.entry, result.tags]),
  );
  return text
    .split("\n")
    .map((line) => {
      if (line.trim().length === 0) {
        return line;
      }
      const record = JSON.parse(line);
      if (!fill.has(record.entry)) {
        return line;
      }
      record.tags = fill.get(record.entry);
      return JSON.stringify(record);
    })
    .join("\n");
}

// The live caller. It logs each call's resolved model and token fields
// separately to <logDir>/calls.ndjson; the key is sent only as a header.
export function liveCaller({ key, logDir = LIVE_DIR, fetchImpl = fetch }) {
  return async (request, meta) => {
    const started = Date.now();
    const response = await fetchImpl(ENDPOINT, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify(request),
    });
    const ms = Date.now() - started;
    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Jev ${response.status}: ${body.slice(0, 300)}`);
    }
    const data = await response.json();
    await mkdir(logDir, { recursive: true });
    await appendFile(
      path.join(logDir, "calls.ndjson"),
      JSON.stringify({
        at: new Date().toISOString(),
        entry: meta.entry,
        order: meta.order,
        cache_key: meta.key,
        ms,
        requested_model: request.model,
        resolved_model: data.model ?? null,
        input_tokens: data.usage?.input_tokens ?? null,
        output_tokens: data.usage?.output_tokens ?? null,
      }) + "\n",
    );
    return { answers: data.answers, model: data.model, usage: data.usage };
  };
}

async function priorLiveCalls(logDir) {
  try {
    const text = await readFile(path.join(logDir, "calls.ndjson"), "utf8");
    return text.split("\n").filter((line) => line.trim().length > 0).length;
  } catch (error) {
    if (error.code === "ENOENT") {
      return 0;
    }
    throw error;
  }
}

function formatRow(row) {
  const p = (value) => value.toFixed(3);
  const mark = row.agrees ? "agrees" : "DISAGREES";
  return `  ${row.id.padEnd(14)} hand=${String(row.hand).padEnd(5)} fwd=${p(row.forward)} rev=${p(row.reverse)} mean=${p(row.mean)} gap=${p(row.order_gap)} ${mark}`;
}

async function main(argv) {
  const live = argv.includes("--live");
  const write = argv.includes("--write");
  const vocab = loadVocab();
  const text = await readFile(VERDICTS_FILE, "utf8");
  const records = text
    .split("\n")
    .filter((line) => line.trim().length > 0)
    .map((line) => JSON.parse(line));

  let call = null;
  let maxCalls = 0;
  if (live) {
    const key = apiKey();
    if (key === null) {
      console.error("verdict-tags: no TypeSafe key; falling back to the cache only");
    } else {
      call = liveCaller({ key });
      maxCalls = Math.max(0, CALL_CAP - (await priorLiveCalls(LIVE_DIR)));
    }
  }
  const cache = openVerdictCache(path.join(LIVE_DIR, "cache"));
  const run = await tagVerdicts({ records, vocab, call, cache, maxCalls });

  await mkdir(LIVE_DIR, { recursive: true });
  await writeFile(path.join(LIVE_DIR, "report.json"), JSON.stringify(run, null, 2) + "\n");

  console.log(`vocabulary ${run.vocab_version}, forward order: ${run.tag_order_forward.join(", ")}`);
  for (const result of run.entries) {
    console.log(`entry ${result.entry}: ${result.outcome}${result.reason ? ` (${result.reason})` : ""}`);
    for (const row of result.per_tag ?? []) {
      console.log(formatRow(row));
    }
  }
  console.log(
    `live calls ${run.calls}, cache hits ${run.cache_hits}, input_tokens ${run.usage.input_tokens}, ` +
      `output_tokens ${run.usage.output_tokens}, models ${run.models.join(", ") || "none"}, ` +
      `max order gap ${run.max_order_gap.toFixed(3)}`,
  );

  if (write) {
    const next = applyTags(text, run);
    if (next !== text) {
      await writeFile(VERDICTS_FILE, next);
      const { ok, problems } = validateVerdicts();
      if (!ok) {
        await writeFile(VERDICTS_FILE, text);
        console.error(`verdict-tags: restored ${VERDICTS_FILE}; validation failed:\n${problems.join("\n")}`);
        return 1;
      }
      console.log("verdict-tags: wrote reproduced tags; verdicts.mjs validation passes");
    } else {
      console.log("verdict-tags: nothing to write");
    }
  }
  const settled = run.entries.every((result) => result.outcome === "reproduced" || result.outcome === "unlabelled");
  return settled ? 0 : 1;
}

function isMain() {
  const invoked = process.argv[1] ? path.resolve(process.argv[1]) : "";
  return invoked === fileURLToPath(import.meta.url);
}

if (isMain()) {
  process.exitCode = await main(process.argv.slice(2));
}
