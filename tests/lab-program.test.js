import test from "node:test";
import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";
import { SCHEMA } from "../scripts/lab/record.mjs";
import {
  TOKEN_FIELDS,
  parseLedger,
  runProgram,
} from "../scripts/lab/program.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const cli = path.join(root, "scripts/lab/program.mjs");

const HASH_A = "a".repeat(64);
const HASH_B = "b".repeat(64);

function git(repository, args, date) {
  const env = { ...process.env, TZ: "America/Los_Angeles" };
  if (date) {
    env.GIT_AUTHOR_DATE = date;
    env.GIT_COMMITTER_DATE = date;
  }
  const result = spawnSync(
    "git",
    [
      "-c",
      "user.name=Lab Test",
      "-c",
      "user.email=lab@example.invalid",
      "-c",
      "commit.gpgsign=false",
      ...args,
    ],
    { cwd: repository, encoding: "utf8", env },
  );
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}

const INDEX = {
  "JL-00": ["done", "JL-00-A1"],
  "JL-01": ["ready", "none"],
  "JL-02": ["ready", "none"],
  "JL-03": ["ready", "none"],
  "JL-04": ["ready", "none"],
};

function trackingText(index, events, attempts) {
  const rows = Object.entries(index).map(
    ([card, [state, accepted]]) =>
      `| [${card}](BACKLOG.md#${card.toLowerCase()}) | 1 | 2 | ${state} | none | ${accepted} | EV-0484 |`,
  );
  return [
    "# Tracking",
    "",
    "## Task state index",
    "",
    "| Task ID | Card rev | Record rev | State | Blockers / admission | Accepted attempt | Last event |",
    "| --- | --- | --- | --- | --- | --- | --- |",
    ...rows,
    "",
    "## Append-only events",
    "",
    "| Sequence | UTC timestamp | Actor / kind | Affected records | Change and evidence |",
    "| --- | --- | --- | --- | --- |",
    "| EV-0483 | 2026-09-25T00:00:00+00:00 | Coordinator / tooling change | scripts | Before the program. |",
    ...events,
    "",
    ...attempts.map(
      (card) => `## ${card} Jev Lab attempt\n\n- Assignee: writer.\n`,
    ),
  ].join("\n");
}

// The EV-0484 to EV-0491 history of the real board: each row's stated time
// and the Pacific-time commit that recorded it (EV-0492 lists the UTC times).
// EV-0487's row is edited by a later commit, as 048e80e did on the real board.
async function fixture(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-program-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const repository = path.join(temporary, "repository");
  const runs = path.join(temporary, "runs");
  await mkdir(path.join(repository, "src"), { recursive: true });
  await mkdir(path.join(repository, "scripts/lab"), { recursive: true });
  await mkdir(path.join(repository, "docs/product/sections"), {
    recursive: true,
  });
  await mkdir(path.join(repository, ".claude/agents"), { recursive: true });
  git(repository, ["init", "-q", "-b", "coord"]);

  const index = structuredClone(INDEX);
  const events = [];
  const attempts = [];
  const write = (file, text) => writeFile(path.join(repository, file), text);
  const board = () =>
    write("TRACKING.md", trackingText(index, events, attempts));
  const commit = async (date, message) => {
    await board();
    git(repository, ["add", "-A"], date);
    git(repository, ["commit", "-q", "-m", message], date);
    return git(repository, ["rev-parse", "HEAD"]);
  };
  const event = (id, stated, kind, affected, change) =>
    events.push(`| ${id} | ${stated} | ${kind} | ${affected} | ${change} |`);

  await write("src/game.js", "export const speed = 4;\n");
  await write("BACKLOG.md", "# Backlog\n");
  await write(
    "docs/product/sections/PD-01.md",
    `- BACKLOG.md bytes SHA256 \`${HASH_A}\` at this base.\n`,
  );
  await write(
    ".claude/agents/scrapkeep-writer.md",
    "---\nname: scrapkeep-writer\nmodel: claude-opus-5-5\neffort: high\n---\nWriter.\n",
  );
  await commit("2026-09-25T10:08:11-07:00", "before the program");

  event(
    "EV-0484",
    "2026-09-25T17:10:00+00:00",
    "Andrew / authorization",
    "Jev Lab program",
    "Authorized.",
  );
  const authorization = await commit("2026-09-25T10:09:28-07:00", "EV-0484");
  event(
    "EV-0485",
    "2026-09-25T17:16:00+00:00",
    "Reviewer / audit; coordinator / definition import",
    "JL-00 to JL-04",
    "Audit.",
  );
  await commit("2026-09-25T10:15:21-07:00", "EV-0485");
  event(
    "EV-0486",
    "2026-09-25T17:20:00+00:00",
    "Coordinator / assignment, lease",
    "JL-01, JL-02, JL-03",
    "Wave 1 dispatched.",
  );
  index["JL-01"][0] = "in_progress";
  index["JL-02"][0] = "in_progress";
  index["JL-03"][0] = "in_progress";
  attempts.push("JL-01-A1", "JL-02-A1", "JL-03-A1");
  await commit("2026-09-25T10:16:09-07:00", "EV-0486");

  git(repository, ["checkout", "-q", "-b", "wt/JL-01"]);
  await write("scripts/lab/record.mjs", "export const record = 1;\n");
  const writer = await commit("2026-09-25T10:20:48-07:00", "JL-01 writer");
  git(repository, ["checkout", "-q", "coord"]);

  event(
    "EV-0487",
    "2026-09-25T17:30:00+00:00",
    "Coordinator / correction",
    "BACKLOG.md",
    "Hashes re-pointed.",
  );
  await write("BACKLOG.md", "# Backlog\n\nJL cards.\n");
  await write(
    "docs/product/sections/PD-01.md",
    `- BACKLOG.md bytes SHA256 \`${HASH_B}\` at this base.\n`,
  );
  const addedEv0487 = await commit("2026-09-25T10:22:54-07:00", "EV-0487");
  events[events.length - 1] = events.at(-1).replace("BACKLOG.md", "files");
  const editedEv0487 = await commit(
    "2026-09-25T10:23:10-07:00",
    "EV-0487 wording",
  );

  event(
    "EV-0488",
    "2026-09-25T17:45:00+00:00",
    "Worker handoff / review admission",
    "JL-01",
    `Candidate ${writer.slice(0, 7)}.`,
  );
  index["JL-01"][0] = "review";
  await commit("2026-09-25T10:27:37-07:00", "EV-0488");
  git(
    repository,
    ["merge", "-q", "--no-ff", "-m", "Merge JL-01", "wt/JL-01"],
    "2026-09-25T10:27:54-07:00",
  );
  const merge = git(repository, ["rev-parse", "HEAD"]);
  event(
    "EV-0489",
    "2026-09-25T17:55:00+00:00",
    "Reviewer / review; coordinator / integration",
    "JL-01",
    "Merged into coord.",
  );
  index["JL-01"] = ["done", "JL-01-A1"];
  await commit("2026-09-25T10:28:44-07:00", "EV-0489");
  event(
    "EV-0490",
    "2026-09-25T18:00:00+00:00",
    "Reviewer / review; coordinator / changes requested, assignment",
    "JL-02",
    "Attempt 2.",
  );
  attempts.push("JL-02-A2");
  await commit("2026-09-25T10:30:14-07:00", "EV-0490");
  event(
    "EV-0491",
    "2026-09-25T18:10:00+00:00",
    "Coordinator / block",
    "JL-03",
    "Blocked.",
  );
  index["JL-03"][0] = "blocked";
  await commit("2026-09-25T10:35:01-07:00", "EV-0491");

  await write("src/game.js", "export const speed = 5;\n");
  const stray = await commit("2026-09-25T10:36:00-07:00", "unrecorded tuning");
  await write(
    "docs/product/sections/PD-01.md",
    `- BACKLOG.md bytes SHA256 \`${HASH_B}\` at this base, and new prose.\n`,
  );
  const prose = await commit("2026-09-25T10:37:00-07:00", "unrecorded prose");

  const ledger = path.join(temporary, "delegates.tsv");
  const header =
    "ts\tproject\tsession_id\tagent_id\tagent_type\tmodel_actual\teffort_pinned\tturns\ttool_uses\tinput_tokens\tcache_read_tokens\tcache_creation_tokens\toutput_tokens\tthinking_tokens\tseconds\tverdict\tevidence_level\treceipt\toverclaim";
  const row = (ts, agent, type, model, [input, read, creation, output]) =>
    [
      ts,
      "/p",
      "s",
      agent,
      type,
      model,
      "high",
      5,
      3,
      input,
      read,
      creation,
      output,
      1,
      60,
      "PASS",
      "4",
    ].join("\t");
  await writeFile(
    ledger,
    [
      header,
      row(
        "2026-09-25T17:20:00Z",
        "aw01",
        "scrapkeep-writer",
        "claude-opus-5-5",
        [10, 1000, 100, 50],
      ),
      row(
        "2026-09-25T17:36:59Z",
        "aw02",
        "scrapkeep-writer",
        "claude-opus-5-5",
        [250, 3000, 80, 30],
      ),
      row(
        "2026-09-25T17:24:55Z",
        "aw02",
        "scrapkeep-writer",
        "claude-opus-5-5",
        [100, 1000, 50, 10],
      ),
      row(
        "2026-09-25T17:27:25Z",
        "ar01",
        "scrapkeep-reviewer",
        "claude-opus-5-5",
        [5, 500, 40, 20],
      ),
      row(
        "2026-09-25T17:28:00Z",
        "aw03",
        "scrapkeep-writer",
        "claude-sonnet-5",
        [7, 700, 70, 7],
      ),
      row(
        "2026-09-25T17:29:00Z",
        "aother",
        "pstack:pstack-scout",
        "claude-sonnet-5",
        [1, 1, 1, 1],
      ),
    ].join("\n") + "\n",
  );
  const map = path.join(temporary, "agent-map.tsv");
  await writeFile(
    map,
    [
      "agent_id\tcard\tattempt\trole\tpinned_model",
      "ar00\tJL-00\tA1\treviewer\tclaude-fable-5-1",
      "aw01\tJL-01\tA1\twriter\tclaude-opus-5-5",
      "ar01\tJL-01\tA1\treviewer\tclaude-fable-5-1",
      "aw02\tJL-02\tA1,A2\twriter\tclaude-opus-5-5",
      "aw03\tJL-03\tA1\twriter\t",
    ].join("\n") + "\n",
  );
  return {
    repository,
    runs,
    ledger,
    map,
    commits: {
      authorization,
      writer,
      merge,
      stray,
      prose,
      addedEv0487,
      editedEv0487,
    },
    run: () =>
      runProgram({ repository, root: runs, ledger, map, label: "fixture" }),
  };
}

test("the ledger keeps each delegate's latest cumulative row", () => {
  const text = [
    "ts\tagent_id\tmodel_actual\tinput_tokens\tcache_read_tokens\tcache_creation_tokens\toutput_tokens",
    "2026-09-25T17:36:59Z\ta1\tm\t238\t14564062\t493380\t128265",
    "2026-09-25T17:24:55Z\ta1\tm\t142\t6716243\t317664\t76726",
    "2026-09-25T17:30:00Z\ta2\tm\t1\t2\t3\t4",
  ].join("\n");
  const { agents, rows } = parseLedger(text);
  assert.equal(rows, 3);
  assert.equal(agents.size, 2);
  assert.deepEqual(agents.get("a1").tokens, {
    input_tokens: 238,
    cache_read_input_tokens: 14564062,
    cache_creation_input_tokens: 493380,
    output_tokens: 128265,
  });
  assert.equal(agents.get("a1").rows, 2);
});

test("the program record carries every collected metric under its registry kind", async (t) => {
  const { run, runs } = await fixture(t);
  const record = await run();
  assert.equal(record.schema, SCHEMA);
  assert.equal(record.type, "program");
  assert.deepEqual(Object.keys(record.kpis).toSorted(), [
    "cycle_time_h",
    "first_pass_review",
    "tokens_per_card",
  ]);
  assert.deepEqual(Object.keys(record.kris).toSorted(), [
    "blocked_cards",
    "event_time_skew",
    "model_substitution",
    "rework_per_card",
    "untracked_commits",
  ]);
  const onDisk = JSON.parse(
    await readFile(path.join(runs, record.id, "run.json"), "utf8"),
  );
  assert.deepEqual(onDisk, record);
  assert.ok(
    record.limits.some((line) => line.includes("escaped_defects")),
    "uncollected program metrics are named as limits",
  );
});

test("event_time_skew reproduces the EV-0486 to EV-0491 skew from the adding commits", async (t) => {
  const { run } = await fixture(t);
  const record = await run();
  const skew = record.kris.event_time_skew;
  assert.equal(skew.n, 8);
  assert.ok(Math.abs(skew.value - 0.58) < 0.01, `skew ${skew.value}`);
  assert.equal(skew.value, Number((2099 / 3600).toFixed(4)));
  const events = record.config.breakdown.event_time_skew.events;
  const largest = events.find((one) => one.event === "EV-0491");
  assert.equal(largest.committed, "2026-09-25T17:35:01Z");
  const edited = events.find((one) => one.event === "EV-0487");
  assert.equal(
    edited.committed,
    "2026-09-25T17:22:54Z",
    "the adding commit, not the later edit",
  );
  assert.equal(edited.skew_h, Number((426 / 3600).toFixed(4)));
  const authorization = events.find((one) => one.event === "EV-0484");
  assert.equal(authorization.skew_h, Number((32 / 3600).toFixed(4)));
});

test("untracked_commits counts unnamed code, prose and merge commits after the since event", async (t) => {
  const { run, commits } = await fixture(t);
  const record = await run();
  const untracked = record.kris.untracked_commits;
  const detail = record.config.breakdown.untracked_commits;
  assert.equal(detail.since_commit, commits.authorization.slice(0, 7));
  assert.deepEqual(
    detail.untracked.map((one) => one.commit).toSorted(),
    [commits.merge, commits.stray, commits.prose]
      .map((sha) => sha.slice(0, 7))
      .toSorted(),
  );
  assert.deepEqual(detail.named, [commits.writer.slice(0, 7)]);
  assert.equal(untracked.value, 3);
  assert.equal(untracked.n, 4);
  assert.ok(
    detail.board_only.includes(commits.addedEv0487.slice(0, 7)),
    "a board commit whose docs change is only a hash token is excluded",
  );
});

test("tokens_per_card keeps the four token fields separate and never sums them", async (t) => {
  const { run } = await fixture(t);
  const record = await run();
  const detail = record.config.breakdown.tokens_per_card;
  assert.deepEqual(detail.fields, TOKEN_FIELDS);
  assert.deepEqual(TOKEN_FIELDS, [
    "input_tokens",
    "cache_read_input_tokens",
    "cache_creation_input_tokens",
    "output_tokens",
  ]);
  assert.deepEqual(detail.per_card["JL-01"], {
    delegates: 2,
    input_tokens: 15,
    cache_read_input_tokens: 1500,
    cache_creation_input_tokens: 140,
    output_tokens: 70,
  });
  assert.deepEqual(detail.per_card["JL-02"], {
    delegates: 1,
    input_tokens: 250,
    cache_read_input_tokens: 3000,
    cache_creation_input_tokens: 80,
    output_tokens: 30,
  });
  assert.deepEqual(detail.missing_delegates, ["ar00"]);
  assert.deepEqual(Object.keys(detail.mean_per_card), TOKEN_FIELDS);
  assert.equal(detail.mean_per_card.input_tokens, (15 + 250 + 7) / 3);
  assert.equal(record.kpis.tokens_per_card.value, (70 + 30 + 7) / 3);
  assert.equal(record.kpis.tokens_per_card.n, 3);
  const serialized = JSON.stringify(detail);
  assert.doesNotMatch(serialized, /total_input|all_input|"input"/);
});

test("model_substitution compares each delegate with its map pin or its agent definition", async (t) => {
  const { run } = await fixture(t);
  const record = await run();
  const detail = record.config.breakdown.model_substitution;
  assert.equal(record.kris.model_substitution.value, 2);
  assert.equal(record.kris.model_substitution.n, 4);
  assert.deepEqual(
    detail.substituted.map((one) => [
      one.agent_id,
      one.pinned,
      one.actual,
      one.pin_source,
    ]),
    [
      ["ar01", "claude-fable-5-1", "claude-opus-5-5", "map"],
      ["aw03", "claude-opus-5-5", "claude-sonnet-5", "agent definition"],
    ],
  );
  assert.ok(
    record.findings.some(
      (one) => one.summary.includes("ar01") && one.repro.includes("ar01"),
    ),
  );
});

test("review, rework, blocked and cycle metrics come from the task index, attempt records and event commits", async (t) => {
  const { run } = await fixture(t);
  const record = await run();
  const first = record.kpis.first_pass_review;
  assert.equal(first.n, 3);
  assert.equal(first.value, 2 / 3);
  assert.equal(first.ci.length, 2);
  assert.ok(first.ci[0] < first.value && first.value < first.ci[1]);
  assert.deepEqual(record.kris.rework_per_card, {
    value: 0.25,
    n: 4,
    ci: null,
  });
  assert.deepEqual(record.kris.blocked_cards, { value: 1, n: 5, ci: null });
  const cycle = record.kpis.cycle_time_h;
  assert.equal(cycle.n, 1);
  assert.equal(cycle.value, Number((755 / 3600).toFixed(4)));
  assert.deepEqual(record.config.breakdown.cycle_time_h.cards["JL-01"], {
    start: "EV-0486",
    admitted: "EV-0489",
    hours: Number((755 / 3600).toFixed(4)),
  });
});

test("the CLI writes a program record and prints its path", async (t) => {
  const { repository, runs, ledger, map } = await fixture(t);
  const result = spawnSync(
    process.execPath,
    [
      cli,
      "--repository",
      repository,
      "--root",
      runs,
      "--ledger",
      ledger,
      "--map",
      map,
      "--label",
      "cli",
    ],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  const written = result.stdout.match(/^record (.+run\.json)$/m);
  assert.ok(written, result.stdout);
  const record = JSON.parse(await readFile(written[1], "utf8"));
  assert.equal(record.type, "program");
  assert.equal(record.label, "cli");
  assert.equal(record.kris.untracked_commits.value, 3);
});

test("an unknown option is a usage error", () => {
  const result = spawnSync(process.execPath, [cli, "--bogus"], {
    encoding: "utf8",
  });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /--bogus/);
});
