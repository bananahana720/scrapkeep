import test from "node:test";
import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { STATUS, PAGE, evaluate } from "../scripts/lab/metrics/status.mjs";
import { METRICS, getMetric } from "../scripts/lab/metrics/index.mjs";
import { SCHEMA } from "../scripts/lab/record.mjs";
import { SCORE_LABELS } from "../scripts/lab/triage.mjs";
import { catalogue, labRoute, resolve } from "../scripts/play.mjs";
import * as dashModule from "../scripts/lab/dash.mjs";

const { CSP, DASH_FILE, SECTIONS, sketchState } = dashModule;

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const dashScript = path.join(root, "scripts/lab/dash.mjs");
const HOUR = 3_600_000;
const Q1 = "1".repeat(64);
const Q2 = "2".repeat(64);

function record(id, overrides = {}) {
  const finished = new Date(
    Date.UTC(2026, 8, 25, 12) + (overrides.seq ?? 0) * HOUR,
  );
  const suite = (overrides.type ?? "suite") === "suite";
  const base = {
    schema: SCHEMA,
    id,
    type: "suite",
    label: "ball-lab",
    result: "pass",
    seq: 0,
    started_at: new Date(finished.getTime() - HOUR).toISOString(),
    finished_at: finished.toISOString(),
    provenance: {
      head: "a".repeat(40),
      branch: "lab",
      dirty: false,
      sources: null,
      versions: { node: process.version },
      instrument: null,
      jev: { model: null, calls: 0, cache_hits: 0 },
    },
    config: {},
    kpis: suite ? { suite_wall_s: { value: 10, n: 20, ci: null } } : {},
    kris: suite
      ? {
          suite_pass: { value: 0, n: 20, ci: null },
          flake_rate: { value: 0, n: 40, ci: null },
        }
      : {},
    findings: [],
    limits: [],
  };
  const { provenance = {}, kpis = {}, kris = {}, ...rest } = overrides;
  return {
    ...base,
    ...rest,
    provenance: { ...base.provenance, ...provenance },
    kpis: { ...base.kpis, ...kpis },
    kris: { ...base.kris, ...kris },
  };
}

const instrument = (questions_sha, model = "jev-1") => ({
  instrument: { questions_sha, model },
  jev: { model },
});

async function fixture(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-dash-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const runs = path.join(temporary, "runs");
  const artifacts = path.join(temporary, "artifacts");
  const repo = path.join(temporary, "repo");
  const out = path.join(temporary, "out", "index.html");
  await mkdir(runs, { recursive: true });
  await mkdir(path.join(repo, "docs", "playtests"), { recursive: true });
  const write = async (run) => {
    await mkdir(path.join(runs, run.id), { recursive: true });
    await writeFile(path.join(runs, run.id, "run.json"), JSON.stringify(run));
    const line = { seq: run.seq, id: run.id, type: run.type, label: run.label };
    await writeFile(
      path.join(runs, "index.ndjson"),
      JSON.stringify(line) + "\n",
      {
        flag: "a",
      },
    );
    return run;
  };
  const dash = (...args) => {
    const result = spawnSync(
      process.execPath,
      [
        dashScript,
        "--runs",
        runs,
        "--artifacts",
        artifacts,
        "--repo",
        repo,
        "--out",
        out,
        ...args,
      ],
      { encoding: "utf8" },
    );
    const html = existsSync(out)
      ? readFile(out, "utf8")
      : Promise.resolve(null);
    return {
      code: result.status,
      out: result.stdout,
      err: result.stderr,
      html,
    };
  };
  return { temporary, runs, artifacts, repo, out, write, dash };
}

async function populated(t) {
  const context = await fixture(t);
  const { write } = context;
  const wall = (value) => ({ suite_wall_s: { value, n: 20, ci: null } });
  await write(record("s0", { seq: 0, kpis: wall(10) }));
  await write(record("s1", { seq: 1, kpis: wall(12) }));
  await write(
    record("s2", {
      seq: 2,
      kpis: wall(11),
      kris: { flake_rate: { value: 0.03, n: 40, ci: null } },
      findings: [
        {
          summary: "a <script>alert(1)</script> finding",
          repro: "node scripts/play.mjs test ball-lab --repeat=5",
        },
      ],
      limits: ["timings come from one machine"],
    }),
  );
  for (const [seq, arm, value] of [
    [3, "scripted", 0.9],
    [4, "random", 0.4],
  ])
    await write(
      record(`b-${arm}`, {
        seq,
        type: "batch",
        label: `downhill-run-${arm}`,
        config: { scenario: "downhill-run", arm, requested_trials: 20 },
        kpis: { route_choice: { value, n: 20, ci: null } },
        kris: {
          stuck_per_trial: {
            value: arm === "random" ? 0.6 : 0.1,
            n: 20,
            ci: null,
          },
        },
      }),
    );
  for (const [seq, sha, value] of [
    [5, Q1, 0.8],
    [6, Q1, 0.75],
    [7, Q2, 0.6],
    [8, Q2, 0.55],
  ])
    await write(
      record(`j${seq}`, {
        seq,
        type: "program",
        label: "wt",
        provenance: instrument(sha),
        kpis: { first_pass_review: { value, n: 10, ci: null } },
      }),
    );
  return context;
}

function sectionOrder(html) {
  return [...html.matchAll(/<section[^>]*data-section="([^"]+)"/g)].map(
    (m) => m[1],
  );
}

test("labRoute sends dash to scripts/lab/dash.mjs with its arguments", () => {
  const routed = labRoute(["dash", "--runs", "x"], { exists: () => true });
  assert.deepEqual(routed, {
    script: path.join(root, "scripts/lab/dash.mjs"),
    args: ["--runs", "x"],
  });
});

test("dash writes the page with its sections in the card's order", async (t) => {
  const { dash, out } = await populated(t);
  const result = dash();
  assert.equal(result.code, 0, result.err);
  assert.ok(result.out.includes(out), "prints where the page went");
  const html = await result.html;
  assert.deepEqual(
    sectionOrder(html),
    SECTIONS.map((one) => one.id),
  );
  assert.deepEqual(
    SECTIONS.map((one) => one.id),
    ["waiting", "layers", "arms", "trends", "test-loop", "findings"],
  );
  assert.match(html, /<h2[^>]*>Waiting for Andrew<\/h2>/);
  assert.equal(
    DASH_FILE,
    path.join(root, "artifacts", "local", "dash", "index.html"),
  );
});

test("every registry metric has exactly one tile, carrying its STATUS glyph and word", async (t) => {
  const { dash } = await populated(t);
  const html = await dash().html;
  const tiles = [...html.matchAll(/data-metric="([^"]+)"/g)].map((m) => m[1]);
  assert.deepEqual(tiles.toSorted(), METRICS.map((one) => one.id).toSorted());
  const flake = html.match(
    /<article[^>]*data-metric="flake_rate"[\s\S]*?<\/article>/,
  )[0];
  const status = evaluate(getMetric("flake_rate"), { value: 0.03, n: 40 });
  assert.ok(flake.includes(status.glyph), "glyph");
  assert.ok(flake.includes(status.word), "word");
  assert.ok(flake.includes(`--status: ${status.hex}`), "colour");
  assert.match(flake, /<svg[^>]*class="spark"/, "sparkline");
});

test("the page uses only STATUS and PAGE colours, no script and a default-src 'none' policy", async (t) => {
  const { dash } = await populated(t);
  const html = await dash().html;
  const allowed = new Set(
    [
      ...Object.values(STATUS).flatMap((one) => [one.hex, one.ink]),
      ...Object.values(PAGE),
    ].map((hex) => hex.toLowerCase()),
  );
  const used = [...html.matchAll(/#[0-9a-f]{3,8}\b/gi)].map((m) =>
    m[0].toLowerCase(),
  );
  assert.ok(used.length > 0);
  for (const hex of used)
    assert.ok(allowed.has(hex), `${hex} is not a STATUS or PAGE colour`);
  assert.doesNotMatch(html, /\b(rgb|rgba|hsl|hsla)\(/i);
  assert.doesNotMatch(html, /<script/i);
  assert.doesNotMatch(html, /\son[a-z]+=/i);
  assert.doesNotMatch(html, /<link|@import|url\(|src=|https?:/i);
  assert.equal(
    CSP,
    "default-src 'none'; style-src 'unsafe-inline'; img-src data:",
  );
  assert.ok(
    html.includes(
      `<meta http-equiv="Content-Security-Policy" content="${CSP}">`,
    ),
  );
  assert.match(
    html,
    /<meta name="viewport" content="width=device-width, initial-scale=1">/,
  );
  assert.match(html, /<meta name="color-scheme" content="dark">/);
  assert.doesNotMatch(html, /<script>alert/, "finding text is escaped");
  assert.match(html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
});

test("arms sit side by side per scenario", async (t) => {
  const { dash } = await populated(t);
  const html = await dash().html;
  const arms = html.match(
    /<section[^>]*data-section="arms"[\s\S]*?<\/section>/,
  )[0];
  assert.match(arms, /downhill-run/);
  const header = arms.match(/<thead>[\s\S]*?<\/thead>/)[0];
  assert.ok(
    header.indexOf("scripted") !== -1 && header.indexOf("random") !== -1,
  );
  const stuck = arms.match(/<tr data-row="stuck_per_trial">[\s\S]*?<\/tr>/)[0];
  assert.ok(
    stuck.includes(STATUS.red.glyph),
    "the random arm's stuck rate is past its fail line",
  );
  assert.ok(stuck.includes(STATUS.green.glyph));
  assert.match(stuck, /href="#m-stuck_per_trial"/);
});

test("trends draw threshold bands and an epoch rule where a series changes instrument", async (t) => {
  const { dash } = await populated(t);
  const html = await dash().html;
  const trends = html.match(
    /<section[^>]*data-section="trends"[\s\S]*?<\/section>/,
  )[0];
  const review = trends.match(
    /<figure[^>]*data-trend="first_pass_review program\/wt"[\s\S]*?<\/figure>/,
  )[0];
  assert.ok(review.includes(`fill="${STATUS.amber.hex}"`), "warn band");
  assert.ok(review.includes(`fill="${STATUS.red.hex}"`), "fail band");
  assert.equal((review.match(/class="epoch-rule"/g) ?? []).length, 1);
  assert.equal(
    (review.match(/<polyline/g) ?? []).length,
    2,
    "one line per epoch segment",
  );
  const wall = trends.match(
    /<figure[^>]*data-trend="suite_wall_s suite\/ball-lab"[\s\S]*?<\/figure>/,
  )[0];
  assert.equal((wall.match(/class="epoch-rule"/g) ?? []).length, 0);
});

test("the test loop shows scores with their qualifications and names the parked player", async (t) => {
  const { dash } = await populated(t);
  const html = await dash().html;
  const loop = html.match(
    /<section[^>]*data-section="test-loop"[\s\S]*?<\/section>/,
  )[0];
  assert.ok(loop.includes(SCORE_LABELS.blind), "blind qualification");
  assert.ok(loop.includes(SCORE_LABELS.authored), "authored qualification");
  assert.match(loop, /65 of 71/);
  assert.match(loop, /73 of 81/);
  assert.match(loop, /14 of 14/);
  assert.match(loop, /Easy cases/);
  assert.match(loop, /echoes words from the two quotes/);
  assert.match(loop, /EV-0532/);
  assert.match(loop, /EV-0534/);
  const parked = loop.match(/<aside[^>]*class="parked"[\s\S]*?<\/aside>/)[0];
  assert.match(parked, /parked/);
  assert.match(parked, /EV-0540/);
});

test("findings, limits and problems close the page", async (t) => {
  const { dash } = await populated(t);
  const html = await dash().html;
  const closing = html.match(
    /<section[^>]*data-section="findings"[\s\S]*?<\/section>/,
  )[0];
  assert.match(closing, /node scripts\/play\.mjs test ball-lab --repeat=5/);
  assert.match(closing, /timings come from one machine/);
});

test("an empty run root still renders every tile and says there are no runs", async (t) => {
  const { dash } = await fixture(t);
  const result = dash();
  assert.equal(result.code, 0, result.err);
  const html = await result.html;
  assert.equal([...html.matchAll(/data-metric="/g)].length, METRICS.length);
  assert.match(html, /no runs under/);
  assert.match(html, /cannot read verdicts file/);
});

test("dash refuses an unknown argument with exit 2", async (t) => {
  const { dash } = await fixture(t);
  const result = dash("--bogus");
  assert.equal(result.code, 2);
  assert.match(result.err, /Usage/);
});

function git(cwd, ...args) {
  const result = spawnSync(
    "git",
    [
      "-c",
      "user.name=t",
      "-c",
      "user.email=t@example.invalid",
      "-c",
      "commit.gpgsign=false",
      ...args,
    ],
    { cwd, encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}

async function put(tree, file, text) {
  await mkdir(path.dirname(path.join(tree, file)), { recursive: true });
  await writeFile(path.join(tree, file), text);
}

async function commit(tree, subject, files) {
  for (const [file, text] of Object.entries(files)) await put(tree, file, text);
  git(tree, "add", "-A");
  git(tree, "commit", "-q", "-m", subject);
  return git(tree, "rev-parse", "HEAD");
}

// main holds alpha, played at its first commit; proto/beta adds beta, whose
// README has a heading but no bolded question; wt/agent is agent work.
async function sketchRepo(t) {
  const context = await fixture(t);
  const { temporary, repo } = context;
  git(repo, "init", "-q", "-b", "main");
  const played = await commit(repo, "alpha: first greybox", {
    "sketches/alpha/project.godot": "a1\n",
    "sketches/alpha/src/roll.gd": "speed = 1\n",
    "sketches/alpha/README.md":
      "# alpha\n\n**Does the alpha sketch feel good to roll through?**\n",
  });
  await commit(repo, "docs: record the alpha verdict", {
    "docs/playtests/verdicts.ndjson":
      JSON.stringify({
        entry: 1,
        build_sha: played,
        anchor: "x",
        quote: '"fun"',
        tags: [],
      }) + "\n",
  });
  const beta = path.join(temporary, "beta");
  git(repo, "worktree", "add", "-q", beta, "-b", "proto/beta");
  await commit(beta, "beta: a bench to push against", {
    "sketches/beta/project.godot": "b1\n",
    "sketches/beta/README.md":
      "# beta bench\n\nA long opening sentence that the play list would fall back to here.\n",
  });
  git(
    repo,
    "worktree",
    "add",
    "-q",
    path.join(temporary, "agent"),
    "-b",
    "wt/agent",
  );
  return { ...context, played, beta };
}

const section = (html, id) =>
  html.match(
    new RegExp(`<section[^>]*data-section="${id}"[\\s\\S]*?</section>`),
  )[0];
const checklistIds = (html) =>
  [
    ...section(html, "waiting")
      .match(/<ol[^>]*class="checklist"[\s\S]*?<\/ol>/)[0]
      .matchAll(/<li class="play"><code>scrapkeep ([^<]+)<\/code>/g),
  ].map((m) => m[1]);

test("sketchState: played when a verdict's build differs only in tests, uid files or README", () => {
  const probe = (changed) => ({
    present: (sha) => sha !== "absent",
    changed: () => changed,
    subjects: () => ["abc1234 alpha: faster roll"],
  });
  const verdicts = [
    { entry: 1, build_sha: "old" },
    { entry: 2, build_sha: "absent" },
  ];
  const entry = { sketch: "alpha", head: "new" };
  assert.deepEqual(sketchState(entry, verdicts, probe([])), {
    waiting: false,
    last: { entry: 1, build_sha: "old" },
    changes: [],
  });
  assert.deepEqual(
    sketchState(entry, verdicts, probe(["sketches/alpha/src/roll.gd"])),
    {
      waiting: true,
      last: { entry: 1, build_sha: "old" },
      changes: ["abc1234 alpha: faster roll"],
    },
  );
  assert.deepEqual(sketchState(entry, [verdicts[1]], probe([])), {
    waiting: true,
    last: null,
    changes: [],
  });
});

// Review B1: the page is written from a linked worktree, but `scrapkeep`
// runs from the main checkout, so every printed id must resolve there.
test("checklist ids written from a linked worktree resolve to their own entries from main", async (t) => {
  const { repo, beta, dash } = await sketchRepo(t);
  await commit(repo, "alpha: faster roll", {
    "sketches/alpha/src/roll.gd": "speed = 2\n",
  });
  const html = await dash("--repo", beta).html;
  const ids = checklistIds(html);
  assert.deepEqual(ids.toSorted(), ["alpha", "beta"]);
  const entries = catalogue(repo);
  for (const id of ids) {
    const found = resolve(entries, id);
    assert.equal(found.entry?.id, id, `scrapkeep ${id} is ambiguous or wrong`);
  }
  assert.doesNotMatch(section(html, "waiting"), /scrapkeep agent/);
});

test("waiting ignores tests, uid files and README; a real change lists its commit subjects", async (t) => {
  const { repo, dash } = await sketchRepo(t);
  await commit(repo, "alpha: add a camera test", {
    "sketches/alpha/tests/camera_test.gd": "extends Node\n",
    "sketches/alpha/tests/camera_test.gd.uid": "uid://x\n",
    "sketches/alpha/src/roll.gd.uid": "uid://y\n",
    "sketches/alpha/README.md": "# alpha\n\n**Does it roll?**\n",
  });
  let waiting = section(await dash().html, "waiting");
  assert.deepEqual(
    checklistIds(waiting),
    ["beta"],
    "alpha is unchanged where it counts",
  );
  await commit(repo, "alpha: faster roll", {
    "sketches/alpha/src/roll.gd": "speed = 2\n",
  });
  waiting = section(await dash().html, "waiting");
  assert.deepEqual(checklistIds(waiting), ["alpha", "beta"]);
  const alpha = waiting.match(
    /<li class="build"[^>]*data-sketch="alpha"[\s\S]*?<\/li>/,
  )[0];
  assert.match(alpha, /changed since entry 1/);
  assert.match(alpha, /alpha: faster roll/);
  assert.doesNotMatch(alpha, /add a camera test/);
});

test("a card shows its own README's bolded question, else its own first heading", async (t) => {
  const { dash } = await sketchRepo(t);
  const waiting = section(await dash().html, "waiting");
  const beta = waiting.match(
    /<li class="build"[^>]*data-sketch="beta"[\s\S]*?<\/li>/,
  )[0];
  assert.match(beta, /never played/);
  assert.match(beta, /beta bench/);
  assert.doesNotMatch(beta, /opening sentence|alpha/);
});

test("every EV row cited by the admitted results exists in TRACKING, and the page stamps the newest", async (t) => {
  const tracking = path.join(root, "TRACKING.md");
  assert.ok(
    existsSync(tracking),
    "TRACKING.md must exist; this check fails closed",
  );
  // An event may have moved from the board into a declared archive
  // (docs/project/tracking/, each under a "## Event archive" heading);
  // scripts/check-docs.mjs owns that rule. A cited id must be a row in one of them.
  const archives = path.join(root, "docs/project/tracking");
  const sources = [tracking];
  for (const name of existsSync(archives) ? await readdir(archives) : []) {
    const file = path.join(archives, name);
    if (!name.endsWith(".md")) continue;
    if (/^## Event archive$/m.test(await readFile(file, "utf8"))) sources.push(file);
  }
  const rows = new Set();
  for (const file of sources) {
    for (const match of (await readFile(file, "utf8")).matchAll(/^\| (EV-\d{4}) \|/gm))
      rows.add(match[1]);
  }
  const cited = [
    ...new Set(JSON.stringify(dashModule.ADMITTED).match(/EV-\d{4}/g)),
  ].toSorted();
  assert.ok(cited.length > 0);
  for (const id of cited)
    assert.ok(rows.has(id), `${id} is not an event row in TRACKING or a declared event archive`);
  const { dash } = await fixture(t);
  const html = await dash().html;
  assert.match(html, new RegExp(`admitted results as of ${cited.at(-1)}`));
  const text = JSON.stringify(dashModule.ADMITTED);
  assert.match(text, /about 1\.6 m step/);
  assert.doesNotMatch(text, /radius|needs a jump/);
  assert.match(text, /BACKLOG JL-19 DoD 3/);
  assert.match(text, /all 18/);
  assert.match(text, /pre-registered 0\.2 margin/);
});

function luminance(hex) {
  const [r, g, b] = [1, 3, 5]
    .map((at) => parseInt(hex.slice(at, at + 2), 16) / 255)
    .map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

const contrast = (a, b) => {
  const [hi, lo] = [luminance(a), luminance(b)].toSorted((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};

function hue(hex) {
  const [r, g, b] = [1, 3, 5].map((at) => parseInt(hex.slice(at, at + 2), 16));
  const max = Math.max(r, g, b);
  const d = max - Math.min(r, g, b);
  if (d === 0) return 0;
  const h =
    max === r
      ? ((g - b) / d) % 6
      : max === g
        ? (b - r) / d + 2
        : (r - g) / d + 4;
  return (h * 60 + 360) % 360;
}

test("status ink reads at 4.5:1 on every page surface, in its colour's hue family", async (t) => {
  for (const status of Object.values(STATUS)) {
    for (const surface of [PAGE.panel, PAGE.deep, PAGE.background])
      assert.ok(
        contrast(status.ink, surface) >= 4.5,
        `${status.word} ink ${status.ink} on ${surface}: ${contrast(status.ink, surface).toFixed(2)}`,
      );
    assert.ok(
      Math.abs(hue(status.ink) - hue(status.hex)) <= 10,
      `${status.word} hue`,
    );
  }
  const { dash } = await fixture(t);
  const html = await dash().html;
  const chipRule = html.match(/\.chip\.none \{[^}]*\}/)[0];
  assert.doesNotMatch(chipRule, /opacity/, "a zero chip keeps full contrast");
  assert.match(html, /\.tile \.word \{[^}]*color: var\(--ink\)/);
});

test("warn and fail bands differ in fill and label; a count axis never goes negative", async (t) => {
  const { dash } = await populated(t);
  const html = await dash().html;
  const review = section(html, "trends").match(
    /<figure[^>]*data-trend="first_pass_review program\/wt"[\s\S]*?<\/figure>/,
  )[0];
  const bands = [...review.matchAll(/<rect[^>]*class="band"[^>]*>/g)].map(
    (m) => m[0],
  );
  assert.equal(bands.length, 2);
  const opacity = bands.map((band) => band.match(/fill-opacity="([^"]+)"/)[1]);
  assert.notEqual(opacity[0], opacity[1], "fills differ, not only the edges");
  for (const status of [STATUS.amber, STATUS.red])
    assert.ok(
      review.includes(`>${status.gate}</text>`),
      `${status.gate} label`,
    );
  for (const [, label] of section(html, "trends").matchAll(
    /<text[^>]*class="axis"[^>]*>([^<]*)<\/text>/g,
  ))
    assert.ok(!label.startsWith("-"), `negative axis label ${label}`);
});

test("unplayed_green with no reading points to the waiting section instead of a value", async (t) => {
  const { dash } = await fixture(t);
  const tile = (await dash().html).match(
    /<article[^>]*data-metric="unplayed_green"[\s\S]*?<\/article>/,
  )[0];
  assert.match(
    tile,
    /not yet recorded; <a href="#waiting">see Waiting for Andrew<\/a>/,
  );
  assert.match(tile, /none/);
});

test("non-finite readings and a finding with no repro do not break the page", async (t) => {
  const { write, dash } = await fixture(t);
  for (const [seq, value] of [
    [0, null],
    [1, "NaN"],
    [2, null],
  ])
    await write(
      record(`n${seq}`, {
        seq,
        kpis: { suite_wall_s: { value, n: 20, ci: null } },
        findings: seq === 2 ? [{ summary: "no command to rerun" }] : [],
      }),
    );
  const result = dash();
  assert.equal(result.code, 0, result.err);
  const html = await result.html;
  const rendered = html.replace(/<p class="says">[^<]*<\/p>/g, "");
  assert.equal(
    rendered.match(/[^\n]{0,60}(NaN|Infinity|undefined)[^\n]{0,20}/)?.[0] ??
      null,
    null,
  );
  assert.match(section(html, "findings"), /no command to rerun/);
  assert.match(section(html, "findings"), /no repro recorded/);
});
