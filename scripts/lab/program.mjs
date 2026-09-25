import { spawnSync } from "node:child_process";
import { readFile, readdir } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";
import { RUNS_ROOT, createRun } from "./record.mjs";
import { METRICS, getMetric } from "./metrics/index.mjs";
import { evaluate } from "./metrics/status.mjs";
import { distribution, wilson } from "./stats.mjs";

const repositoryRoot = path.resolve(import.meta.dirname, "../..");

export const TOKEN_FIELDS = [
  "input_tokens",
  "cache_read_input_tokens",
  "cache_creation_input_tokens",
  "output_tokens",
];
const LEDGER_COLUMN = {
  input_tokens: "input_tokens",
  cache_read_input_tokens: "cache_read_tokens",
  cache_creation_input_tokens: "cache_creation_tokens",
  output_tokens: "output_tokens",
};
export const COLLECTED = [
  "first_pass_review",
  "cycle_time_h",
  "tokens_per_card",
  "rework_per_card",
  "blocked_cards",
  "model_substitution",
  "untracked_commits",
  "event_time_skew",
];
export const DEFAULTS = {
  ledger: path.join(os.homedir(), ".claude/state/delegates.tsv"),
  map: "artifacts/jev-lab-2026-09-25/agent-map.tsv",
  tracking: "TRACKING.md",
  agents: ".claude/agents",
  since: "EV-0484",
  family: "JL",
};
const HOUR_MS = 3_600_000;
const UNCOMMITTED = /^0{40}$/;
const EVENT_ROW = /^\| (EV-\d+) \|/;

function git(repository, ...args) {
  const result = spawnSync("git", args, {
    cwd: repository,
    encoding: "utf8",
    maxBuffer: 256 * 1024 * 1024,
  });
  if (result.status !== 0)
    throw new Error(
      `git ${args[0]} failed in ${repository}: ${(result.stderr || result.error?.message || "").trim()}`,
    );
  return result.stdout;
}

function tryGit(repository, ...args) {
  try {
    return git(repository, ...args);
  } catch {
    return null;
  }
}

const round4 = (value) => Number(value.toFixed(4));
const short = (sha) => sha.slice(0, 7);
const isoSeconds = (ms) => new Date(ms).toISOString().replace(/\.\d{3}Z$/, "Z");
const nothing = () => ({ value: null, n: 0, ci: null });

function parseTsv(text) {
  const lines = text.split("\n").filter((line) => line.trim() !== "");
  const columns = (lines.shift() ?? "").split("\t");
  return lines.map((line) => {
    const cells = line.split("\t");
    return Object.fromEntries(
      columns.map((column, index) => [column, cells[index] ?? ""]),
    );
  });
}

// Each ledger row sums the delegate's whole transcript at that stop
// (~/.claude/hooks/lib/ledger.py), so a resumed delegate's later row already
// contains its earlier ones. The latest row per agent_id is the delegate.
export function parseLedger(text) {
  const rows = parseTsv(text);
  const agents = new Map();
  for (const row of rows) {
    const id = row.agent_id;
    if (!id) continue;
    const seen = agents.get(id);
    const count = (seen?.rows ?? 0) + 1;
    if (seen && seen.ts > row.ts) {
      seen.rows = count;
      continue;
    }
    agents.set(id, {
      agent_id: id,
      agent_type: row.agent_type ?? "",
      model_actual: row.model_actual ?? "",
      ts: row.ts ?? "",
      rows: count,
      tokens: Object.fromEntries(
        TOKEN_FIELDS.map((field) => [
          field,
          Number(row[LEDGER_COLUMN[field]]) || 0,
        ]),
      ),
    });
  }
  return { rows: rows.length, agents };
}

function attemptNumbers(text) {
  return String(text)
    .split(",")
    .map((one) => Number(one.trim().replace(/^A/, "")))
    .filter((number) => Number.isInteger(number) && number > 0);
}

export function parseAgentMap(text) {
  const agents = new Map();
  for (const row of parseTsv(text)) {
    if (!row.agent_id) continue;
    const seen = agents.get(row.agent_id);
    agents.set(row.agent_id, {
      agent_id: row.agent_id,
      card: row.card,
      role: row.role,
      pinned_model: row.pinned_model?.trim() || seen?.pinned_model || "",
      attempts: [...(seen?.attempts ?? []), ...attemptNumbers(row.attempt)],
    });
  }
  return agents;
}

function cells(line) {
  return line
    .split(/(?<!\\)\|/)
    .slice(1, -1)
    .map((cell) => cell.trim());
}

function cardsIn(text, family) {
  const found = new Set();
  const pattern = new RegExp(
    `\\b${family}-(\\d+)\\b(?:\\s+to\\s+${family}-(\\d+)\\b)?`,
    "g",
  );
  for (const [, first, last] of text.matchAll(pattern)) {
    const to = last === undefined ? Number(first) : Number(last);
    for (let number = Number(first); number <= to; number += 1)
      found.add(`${family}-${String(number).padStart(first.length, "0")}`);
  }
  return found;
}

export function parseTracking(text, family) {
  const events = [];
  const index = new Map();
  const attempts = new Map();
  const taskRow = new RegExp(`^\\| \\[(${family}-\\d+)\\]`);
  const heading = new RegExp(`^## (${family}-\\d+)-A(\\d+)\\b`);
  for (const line of text.split("\n")) {
    const event = line.match(EVENT_ROW);
    if (event) {
      const [, stated, kind, affected] = cells(line);
      events.push({
        id: event[1],
        seq: Number(event[1].slice(3)),
        stated: stated ?? "",
        statedMs: Date.parse(stated ?? ""),
        kind: kind ?? "",
        cards: cardsIn(affected ?? "", family),
        text: line,
      });
      continue;
    }
    const task = line.match(taskRow);
    if (task) {
      const row = cells(line);
      index.set(task[1], { state: row[3], accepted: row[5] });
      continue;
    }
    const attempt = line.match(heading);
    if (attempt)
      attempts.set(
        attempt[1],
        Math.max(attempts.get(attempt[1]) ?? 0, Number(attempt[2])),
      );
  }
  return { events, index, attempts };
}

function blameRows(repository, file, revision) {
  const args = ["blame", "--line-porcelain"];
  if (revision) args.push(revision);
  const rows = new Map();
  let sha = null;
  let time = null;
  for (const line of git(repository, ...args, "--", file).split("\n")) {
    const header = line.match(/^([0-9a-f]{40}) \d+ \d+/);
    if (header) {
      sha = header[1];
      continue;
    }
    if (line.startsWith("committer-time ")) {
      time = Number(line.slice("committer-time ".length)) * 1000;
      continue;
    }
    if (!line.startsWith("\t")) continue;
    const event = line.slice(1).match(EVENT_ROW);
    if (event) rows.set(event[1], { sha, time });
  }
  return rows;
}

// Blame names the last commit that touched a row, which is a later edit when
// the coordinator reworded it (048e80e rewrote EV-0487). While the blamed
// commit's first parent already has the row, blame again from that parent.
// Committer time is read as epoch seconds, so the committer's zone never
// enters the comparison.
export function addingCommits(repository, file, ids) {
  const blames = new Map();
  const blameAt = (revision) => {
    const key = revision ?? "";
    if (!blames.has(key))
      blames.set(key, blameRows(repository, file, revision));
    return blames.get(key);
  };
  const found = new Map();
  for (const id of ids) {
    let current = blameAt(null).get(id);
    while (current && !UNCOMMITTED.test(current.sha)) {
      const parent = `${current.sha}^`;
      const earlier = tryGit(repository, "show", `${parent}:${file}`);
      if (earlier === null || !earlier.includes(`\n| ${id} |`)) break;
      const blamed = blameAt(parent).get(id);
      if (!blamed) break;
      current = blamed;
    }
    if (current) found.set(id, current);
  }
  return found;
}

function eventTimeSkew(events, adding) {
  const measured = [];
  const uncommitted = [];
  for (const event of events) {
    const commit = adding.get(event.id);
    if (!commit || UNCOMMITTED.test(commit.sha)) {
      uncommitted.push(event.id);
      continue;
    }
    if (!Number.isFinite(event.statedMs)) continue;
    measured.push({
      event: event.id,
      stated: event.stated,
      committed: isoSeconds(commit.time),
      commit: short(commit.sha),
      skew_h: round4((event.statedMs - commit.time) / HOUR_MS),
    });
  }
  const largest = measured.reduce(
    (worst, one) =>
      worst === null || Math.abs(one.skew_h) > Math.abs(worst.skew_h)
        ? one
        : worst,
    null,
  );
  return {
    measure: {
      value: largest === null ? null : Math.abs(largest.skew_h),
      n: measured.length,
      ci: null,
    },
    detail: {
      rule: "stated UTC time minus the committer time of the commit that added the row (blame, walked back past later edits); the value is the largest absolute gap in hours",
      largest: largest?.event ?? null,
      events: measured,
      uncommitted,
    },
  };
}

function diffLines(repository, parent, sha, file) {
  const removed = [];
  const added = [];
  for (const line of git(
    repository,
    "diff",
    "-U0",
    "--no-color",
    parent,
    sha,
    "--",
    file,
  ).split("\n")) {
    if (line.startsWith("---") || line.startsWith("+++")) continue;
    const normal = line.slice(1).replace(/\b[0-9a-f]{64}\b/g, "<sha256>");
    if (line.startsWith("-")) removed.push(normal);
    else if (line.startsWith("+")) added.push(normal);
  }
  return { removed: removed.toSorted(), added: added.toSorted() };
}

function boardPath(repository, parent, sha, file) {
  if (file === "TRACKING.md" || file === "BACKLOG.md") return true;
  if (/^artifacts\/jev-lab-[^/]+\//.test(file)) return true;
  if (!file.startsWith("docs/")) return false;
  const { removed, added } = diffLines(repository, parent, sha, file);
  return (
    removed.length > 0 &&
    removed.length === added.length &&
    removed.every((line, index) => line === added[index])
  );
}

// A board commit only records work: it changes TRACKING.md, BACKLOG.md, files
// under artifacts/jev-lab-*/, or docs lines whose only change is a SHA-256
// token. Board commits are named by the events they add, never by SHA, so
// they are excluded. Every other commit, merges included (diffed against the
// first parent), needs an event row that cites at least 7 characters of it.
function untrackedCommits(repository, since, allEvents, sinceId) {
  const cited = new Set();
  for (const event of allEvents)
    for (const [token] of event.text.matchAll(/\b[0-9a-f]{7,40}\b/g))
      cited.add(token);
  const log = git(
    repository,
    "log",
    "--reverse",
    "--format=%H%x09%P%x09%s",
    `${since}..HEAD`,
  )
    .split("\n")
    .filter(Boolean);
  const boardOnly = [];
  const named = [];
  const untracked = [];
  for (const line of log) {
    const [sha, parents, subject] = line.split("\t");
    const parent = parents.split(" ")[0];
    const changed = parent
      ? git(repository, "diff", "--name-only", "--no-renames", parent, sha)
          .split("\n")
          .filter(Boolean)
      : ["(root)"];
    if (changed.every((file) => boardPath(repository, parent, sha, file))) {
      boardOnly.push(short(sha));
      continue;
    }
    if ([...cited].some((token) => sha.startsWith(token)))
      named.push(short(sha));
    else untracked.push({ commit: short(sha), subject });
  }
  return {
    measure: {
      value: untracked.length,
      n: named.length + untracked.length,
      ci: null,
    },
    detail: {
      rule: "commits on HEAD after the since event's commit, excluding board-only commits (TRACKING.md, BACKLOG.md, artifacts/jev-lab-*/, docs SHA-256 token lines), that no event row cites by a 7+ character SHA prefix",
      since_event: sinceId,
      since_commit: short(since),
      examined: log.length,
      board_only: boardOnly,
      named,
      untracked,
    },
  };
}

function tokensPerCard(map, ledger) {
  const perCard = {};
  const missing = [];
  for (const agent of [...map.values()].toSorted((a, b) =>
    a.agent_id.localeCompare(b.agent_id),
  )) {
    const row = ledger.agents.get(agent.agent_id);
    if (!row) {
      missing.push(agent.agent_id);
      continue;
    }
    const card = (perCard[agent.card] ??= {
      delegates: 0,
      ...Object.fromEntries(TOKEN_FIELDS.map((field) => [field, 0])),
    });
    card.delegates += 1;
    for (const field of TOKEN_FIELDS) card[field] += row.tokens[field];
  }
  const cards = Object.values(perCard);
  const mean = Object.fromEntries(
    TOKEN_FIELDS.map((field) => [
      field,
      cards.length === 0
        ? null
        : cards.reduce((sum, card) => sum + card[field], 0) / cards.length,
    ]),
  );
  const repeated = [...map.keys()].filter(
    (id) => (ledger.agents.get(id)?.rows ?? 0) > 1,
  );
  return {
    measure: { value: mean.output_tokens, n: cards.length, ci: null },
    detail: {
      fields: TOKEN_FIELDS,
      value_field: "output_tokens",
      dedupe:
        "latest ledger row per agent_id; each row is the cumulative sum of that delegate's transcript, so earlier rows are not added",
      ledger_rows: ledger.rows,
      repeated_delegates: repeated,
      per_card: perCard,
      mean_per_card: mean,
      missing_delegates: missing,
    },
  };
}

async function agentDefinitionPins(directory) {
  const pins = new Map();
  let entries;
  try {
    entries = await readdir(directory);
  } catch (error) {
    if (error.code === "ENOENT") return pins;
    throw error;
  }
  for (const entry of entries.filter((name) => name.endsWith(".md"))) {
    const text = await readFile(path.join(directory, entry), "utf8");
    const front = text.match(/^---\n([\s\S]*?)\n---/)?.[1] ?? "";
    const name = front.match(/^name:\s*(.+)$/m)?.[1]?.trim();
    const model = front.match(/^model:\s*(.+)$/m)?.[1]?.trim();
    if (name && model) pins.set(name, model);
  }
  return pins;
}

function modelSubstitution(map, ledger, pins) {
  const substituted = [];
  const unpinned = [];
  const unknownActual = [];
  const conflicts = [];
  let compared = 0;
  for (const agent of [...map.values()].toSorted((a, b) =>
    a.agent_id.localeCompare(b.agent_id),
  )) {
    const row = ledger.agents.get(agent.agent_id);
    if (!row) continue;
    const definition = pins.get(row.agent_type) ?? "";
    const pinned = agent.pinned_model || definition;
    const source = agent.pinned_model ? "map" : "agent definition";
    if (agent.pinned_model && definition && agent.pinned_model !== definition)
      conflicts.push({
        agent_id: agent.agent_id,
        map: agent.pinned_model,
        definition,
      });
    if (!pinned) {
      unpinned.push(agent.agent_id);
      continue;
    }
    if (!row.model_actual) {
      unknownActual.push(agent.agent_id);
      continue;
    }
    compared += 1;
    if (row.model_actual !== pinned)
      substituted.push({
        agent_id: agent.agent_id,
        card: agent.card,
        agent_type: row.agent_type,
        pinned,
        actual: row.model_actual,
        pin_source: source,
      });
  }
  return {
    measure: { value: substituted.length, n: compared, ci: null },
    detail: {
      rule: "ledger model_actual against the map row's pinned_model, or the agent definition's model when the map row names none",
      substituted,
      unpinned,
      unknown_actual: unknownActual,
      pin_conflicts: conflicts,
    },
  };
}

function cardMetrics(tracking, map, programEvents, adding) {
  const attempts = new Map();
  const raise = (card, number) =>
    attempts.set(card, Math.max(attempts.get(card) ?? 0, number));
  for (const [card, number] of tracking.attempts) raise(card, number);
  for (const agent of map.values())
    for (const number of agent.attempts) raise(agent.card, number);
  for (const [card, { accepted }] of tracking.index) {
    const number = accepted?.match(/-A(\d+)$/)?.[1];
    if (number) raise(card, Number(number));
  }

  const decided = [];
  const passed = [];
  const started = [];
  const blocked = [];
  for (const [card, { state, accepted }] of tracking.index) {
    const count = attempts.get(card) ?? 0;
    const admitted = state === "done" && /-A\d+$/.test(accepted ?? "");
    if (count >= 1) started.push({ card, rework: count - 1 });
    if (state === "blocked") blocked.push(card);
    if (!admitted && count < 2) continue;
    decided.push(card);
    if (admitted && accepted.endsWith("-A1") && count === 1) passed.push(card);
  }

  const cycles = {};
  for (const card of tracking.index.keys()) {
    const start = programEvents.find(
      (event) =>
        event.cards.has(card) && /\b(assignment|lease)\b/i.test(event.kind),
    );
    if (!start) continue;
    const end = programEvents.find(
      (event) =>
        event.seq > start.seq &&
        event.cards.has(card) &&
        /\b(integration|completion)\b/i.test(event.kind),
    );
    const from = adding.get(start.id);
    const to = end && adding.get(end.id);
    if (!from || !to || UNCOMMITTED.test(from.sha) || UNCOMMITTED.test(to.sha))
      continue;
    cycles[card] = {
      start: start.id,
      admitted: end.id,
      hours: round4((to.time - from.time) / HOUR_MS),
    };
  }
  const hours = Object.values(cycles).map((one) => one.hours);
  const interval =
    decided.length > 0 ? wilson(passed.length, decided.length) : null;

  return {
    first_pass_review: {
      measure: {
        value: decided.length > 0 ? passed.length / decided.length : null,
        n: decided.length,
        ci: interval && [interval.lower, interval.upper],
      },
      detail: {
        rule: "admitted on attempt 1 with no later attempt, over cards admitted or given a second attempt",
        passed,
        decided,
      },
    },
    rework_per_card: {
      measure: {
        value:
          started.length > 0
            ? started.reduce((sum, one) => sum + one.rework, 0) / started.length
            : null,
        n: started.length,
        ci: null,
      },
      detail: {
        rule: "highest attempt number minus one, from attempt-record headings, accepted attempts and the agent map",
        cards: Object.fromEntries(started.map((one) => [one.card, one.rework])),
      },
    },
    blocked_cards: {
      measure: { value: blocked.length, n: tracking.index.size, ci: null },
      detail: { cards: blocked },
    },
    cycle_time_h: {
      measure: {
        value: distribution(hours).p50,
        n: hours.length,
        ci: null,
      },
      detail: {
        rule: "median hours between the commits that added a card's first assignment or lease event and its first later integration or completion event",
        cards: cycles,
      },
    },
  };
}

async function readOptional(file) {
  try {
    return await readFile(file, "utf8");
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

export async function collect({
  repository = repositoryRoot,
  ledger = DEFAULTS.ledger,
  map = DEFAULTS.map,
  tracking = DEFAULTS.tracking,
  agents = DEFAULTS.agents,
  since = DEFAULTS.since,
  family = DEFAULTS.family,
} = {}) {
  const resolve = (file) => path.resolve(repository, file);
  const limits = [];
  const board = parseTracking(
    await readFile(resolve(tracking), "utf8"),
    family,
  );
  const sinceSeq = Number(since.replace(/^EV-/, ""));
  const programEvents = board.events.filter((event) => event.seq >= sinceSeq);
  const adding = addingCommits(
    repository,
    path.relative(repository, resolve(tracking)),
    programEvents.map((event) => event.id),
  );

  const ledgerText = await readOptional(resolve(ledger));
  const mapText = await readOptional(resolve(map));
  const ledgerRows = ledgerText === null ? null : parseLedger(ledgerText);
  const agentMap = mapText === null ? new Map() : parseAgentMap(mapText);
  if (ledgerText === null) limits.push(`No delegate ledger at ${ledger}.`);
  if (mapText === null) limits.push(`No agent map at ${map}.`);

  const results = {
    ...cardMetrics(board, agentMap, programEvents, adding),
    event_time_skew: eventTimeSkew(programEvents, adding),
  };
  const sinceCommit = adding.get(since);
  if (sinceCommit && !UNCOMMITTED.test(sinceCommit.sha)) {
    results.untracked_commits = untrackedCommits(
      repository,
      sinceCommit.sha,
      board.events,
      since,
    );
  } else {
    results.untracked_commits = { measure: nothing(), detail: null };
    limits.push(
      `${since} has no committed row, so untracked_commits is not measured.`,
    );
  }
  if (ledgerRows === null || mapText === null) {
    results.tokens_per_card = { measure: nothing(), detail: null };
    results.model_substitution = { measure: nothing(), detail: null };
  } else {
    results.tokens_per_card = tokensPerCard(agentMap, ledgerRows);
    results.model_substitution = modelSubstitution(
      agentMap,
      ledgerRows,
      await agentDefinitionPins(resolve(agents)),
    );
    const missing = results.tokens_per_card.detail.missing_delegates;
    if (missing.length > 0)
      limits.push(
        `${missing.length} mapped delegates have no ledger row: ${missing.join(", ")}.`,
      );
  }
  const uncommitted = results.event_time_skew.detail.uncommitted;
  if (uncommitted.length > 0)
    limits.push(
      `${uncommitted.length} event rows are not committed yet and are not measured: ${uncommitted.join(", ")}.`,
    );
  limits.push(
    "tokens_per_card's value is mean output_tokens per card because the record keeps only {value, n, ci}; all four token fields, per card and as means, are in config.breakdown.tokens_per_card and are never summed together.",
    "cycle_time_h uses the commit time of each event's row, not its stated time (EV-0492).",
  );
  const skipped = METRICS.filter(
    (metric) => metric.layer === "program" && !COLLECTED.includes(metric.id),
  ).map((metric) => metric.id);
  if (skipped.length > 0)
    limits.push(`This collector does not measure ${skipped.join(" or ")}.`);

  return {
    results,
    limits,
    config: {
      since,
      family,
      tracking,
      ledger,
      map,
      agents,
      breakdown: Object.fromEntries(
        COLLECTED.map((id) => [id, results[id].detail]),
      ),
    },
  };
}

function findingsFor(results, { ledger, tracking }) {
  const findings = [];
  for (const one of results.model_substitution.detail?.substituted ?? [])
    findings.push({
      summary: `${one.agent_id} (${one.card}, ${one.agent_type}) ran on ${one.actual}; its ${one.pin_source} pin is ${one.pinned}.`,
      repro: `grep ${one.agent_id} ${ledger}`,
    });
  for (const one of results.untracked_commits.detail?.untracked ?? [])
    findings.push({
      summary: `Commit ${one.commit} (${one.subject}) is cited by no event row.`,
      repro: `git show --stat ${one.commit}`,
    });
  for (const card of results.blocked_cards.detail.cards)
    findings.push({
      summary: `${card} is blocked.`,
      repro: `grep -n '\\[${card}\\]' ${tracking}`,
    });
  const skew = results.event_time_skew;
  const largest = skew.detail.events.find(
    (one) => one.event === skew.detail.largest,
  );
  if (
    largest &&
    evaluate(getMetric("event_time_skew"), skew.measure).gate !== "pass"
  )
    findings.push({
      summary: `${largest.event} states ${largest.stated}; the commit that added it is ${largest.committed} (${largest.skew_h} h).`,
      repro: `git log -1 --format=%cI ${largest.commit}`,
    });
  return findings;
}

function overall(gates) {
  if (gates.includes("fail")) return "fail";
  if (gates.includes("inconclusive")) return "inconclusive";
  return "pass";
}

export async function runProgram({
  repository = repositoryRoot,
  root,
  label,
  sources,
  now,
  ...inputs
} = {}) {
  const { results, limits, config } = await collect({ repository, ...inputs });
  const run = await createRun({
    type: "program",
    label: label ?? defaultLabel(repository),
    registry: METRICS,
    root,
    repository,
    sources,
    now,
    config,
  });
  const gates = [];
  for (const id of COLLECTED) {
    const metric = getMetric(id);
    const measure = results[id].measure;
    if (metric.kind === "kpi") run.kpi(id, measure);
    else run.kri(id, measure);
    gates.push(evaluate(metric, measure).gate);
  }
  for (const finding of findingsFor(results, config)) run.finding(finding);
  for (const line of limits) run.limit(line);
  return run.finish({ result: overall(gates) });
}

function defaultLabel(repository) {
  const branch = tryGit(repository, "branch", "--show-current")?.trim() ?? "";
  const slug = branch
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug || "program";
}

function line(id, measure, tty) {
  const status = evaluate(getMetric(id), measure);
  const value = measure.value === null ? "none" : round4(measure.value);
  const text = `${status.glyph} ${id} ${value} n=${measure.n} ${status.gate}`;
  return tty ? `${status.ansi}${text}\x1b[0m` : text;
}

async function main(argv) {
  let parsed;
  try {
    parsed = parseArgs({
      args: argv,
      options: {
        repository: { type: "string" },
        root: { type: "string" },
        ledger: { type: "string" },
        map: { type: "string" },
        tracking: { type: "string" },
        agents: { type: "string" },
        since: { type: "string" },
        family: { type: "string" },
        label: { type: "string" },
      },
      strict: true,
      allowPositionals: false,
    }).values;
  } catch (error) {
    process.stderr.write(
      `${error.message}\nUsage: node scripts/lab/program.mjs [--repository dir] [--root runs] [--ledger tsv] [--map tsv] [--tracking md] [--agents dir] [--since EV-nnnn] [--family JL] [--label slug]\n`,
    );
    return 2;
  }
  const repository = path.resolve(parsed.repository ?? repositoryRoot);
  const root = parsed.root && path.resolve(parsed.root);
  const record = await runProgram({ ...parsed, repository, root });
  const tty = process.stdout.isTTY === true;
  const kinds = { ...record.kpis, ...record.kris };
  for (const id of COLLECTED)
    process.stdout.write(`${line(id, kinds[id], tty)}\n`);
  process.stdout.write(`result ${record.result}\n`);
  process.stdout.write(
    `record ${path.join(root ?? RUNS_ROOT, record.id, "run.json")}\n`,
  );
  return 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href)
  process.exitCode = await main(process.argv.slice(2));
