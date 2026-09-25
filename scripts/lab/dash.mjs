// `scrapkeep dash` (plan § 4 "Output"): one local HTML page of the lab's
// state, written to artifacts/local/dash/index.html. No script, no network,
// inline SVG only. Every colour, glyph and status word comes from
// metrics/status.mjs, so the page, `scrapkeep stats` and the gate cannot
// disagree about what a reading means.
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";

import { catalogue } from "../play.mjs";
import { ARMS } from "../../tools/jev-player/protocol/protocol.mjs";
import { METRICS } from "./metrics/index.mjs";
import { EXIT, PAGE, STATUS, evaluate } from "./metrics/status.mjs";
import {
  compareToPin,
  describeEpoch,
  latestReading,
  loadModel,
  loadPins,
  seriesOf,
} from "./model.mjs";
import { RUNS_ROOT } from "./record.mjs";
import { changeText, number } from "./stats-cli.mjs";
import { SCORE_LABELS } from "./triage.mjs";
import { validateVerdicts } from "./verdicts.mjs";

const repositoryRoot = path.resolve(import.meta.dirname, "../..");
export const DASH_FILE = path.join(
  repositoryRoot,
  "artifacts",
  "local",
  "dash",
  "index.html",
);
export const CSP =
  "default-src 'none'; style-src 'unsafe-inline'; img-src data:";

export const SECTIONS = Object.freeze([
  { id: "waiting", title: "Waiting for Andrew" },
  { id: "layers", title: "Layers" },
  { id: "arms", title: "Arms by scenario" },
  { id: "trends", title: "Trends" },
  { id: "test-loop", title: "Jev in the test loop" },
  { id: "findings", title: "Findings and limits" },
]);

// Builds for Andrew live on the main line and the proto/ sketch branches;
// wt/ and claude/ worktrees are agent work in progress.
const SKETCH_BRANCH = /^(main|proto\/.+)$/;

// A score tracked without thresholds: shown, never judged.
const SHOWN = evaluate(
  { id: "admitted", sentinel: false, thresholds: null },
  { value: 0, n: 0 },
);

// Facts the coordinator admitted in TRACKING that no run record carries.
// Each cites its row; change the row and this table together.
export const ADMITTED = {
  gameplay: {
    source: "EV-0534 (JL-13 review)",
    lines: [
      "Rigid mode: a centred stomp is not credited.",
      "Rigid mode: the grounded flag flickers on flat ground, so jump, brake and drive flicker with it.",
      "Kinematic mode: the tilted boxes' raised ends leave wedge gaps narrower than the ball, and a pinned ball reports rising speed and a cruise tier while it does not move.",
      "Service ramp: about 1.6 m step at the top.",
    ],
  },
  triage: {
    title: "Failure triage (JL-19)",
    source: "scores EV-0534, qualifications EV-0532",
    scores: [
      { role: "blind", earned: 65, possible: 71 },
      { role: "authored", earned: 73, possible: 81 },
    ],
    note: "0 severe misses; both controls answered by Jev.",
    advisory:
      "Advisory only: a rerun counts toward flake_rate and never turns a failing result into a passing one.",
    advisorySource: "BACKLOG JL-19 DoD 3",
  },
  tagging: {
    title: "Verdict tagging (JL-20)",
    source: "score EV-0531, qualification EV-0534",
    scores: [{ role: "hand labels", earned: 14, possible: 14 }],
    qualification:
      "Easy cases (Nouls at 0.02 to 0.10 or 0.97 to 0.99) with a vocabulary that echoes words from the two quotes, so it is close to lexical matching, not calibration. It can only confirm hand labels, so it cannot tag a new entry on its own.",
  },
  parked: {
    source: "EV-0540, EV-0541",
    line: "Jev as player is parked for this program: it reads the options correctly but overweights an option that names the level's goal, so it failed the free-cache control in every order. The scripted and random arms carry the mechanics metrics; Jev keeps its test-loop roles.",
    qualification:
      "Under the per-option yes/no method, take_cache ranked first in all 18 free-cache calls and failed only on the pre-registered 0.2 margin (EV-0541).",
  },
};

const ADMITTED_AS_OF = JSON.stringify(ADMITTED)
  .match(/EV-\d{4}/g)
  .toSorted()
  .at(-1);

const ESCAPES = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
};
const esc = (text) => String(text).replace(/[&<>"']/g, (one) => ESCAPES[one]);
const short = (sha) => (sha ?? "none").slice(0, 7);
const valueText = (measure) =>
  Number.isFinite(measure?.value) ? number(measure.value) : "none";
const tint = (status) =>
  `style="--status: ${status.hex}; --ink: ${status.ink}"`;
const breakable = (id) => id.replaceAll("_", "_<wbr>");

// A sketch waits for Andrew until some verdict's build differs from the
// branch head only in paths that do not change play (IGNORED). `last` is the
// newest verdict whose build held the sketch; `changes` are the commit
// subjects since it that touch play.
export function sketchState(entry, verdicts, probe) {
  let last = null;
  let played = false;
  for (const verdict of verdicts) {
    if (!probe.present(verdict.build_sha, entry.sketch)) continue;
    if (last === null || verdict.entry > last.entry)
      last = { entry: verdict.entry, build_sha: verdict.build_sha };
    if (
      entry.head &&
      probe.changed(verdict.build_sha, entry.head, entry.sketch).length === 0
    )
      played = true;
  }
  const changes =
    played || last === null || !entry.head
      ? []
      : probe.subjects(last.build_sha, entry.head, entry.sketch);
  return { waiting: !played, last, changes };
}

// Headless tests, Godot uid files and the README do not change what Andrew
// would play.
const IGNORED = (sketch) => [
  `sketches/${sketch}`,
  `:(exclude)sketches/${sketch}/tests`,
  `:(exclude,glob)sketches/${sketch}/**/*.uid`,
  `:(exclude,glob)sketches/${sketch}/**/README.md`,
];

function gitProbe(repo) {
  const run = (...args) =>
    spawnSync("git", ["-C", repo, ...args], { encoding: "utf8" });
  const lines = (result) =>
    result.status === 0 ? result.stdout.split("\n").filter(Boolean) : [];
  return {
    present: (sha, sketch) =>
      run("cat-file", "-e", `${sha}:sketches/${sketch}`).status === 0,
    changed: (from, to, sketch) =>
      lines(run("diff", "--name-only", from, to, "--", ...IGNORED(sketch))),
    subjects: (from, to, sketch) =>
      lines(
        run(
          "log",
          "--format=%h %s",
          `${from}..${to}`,
          "--",
          ...IGNORED(sketch),
        ),
      ),
  };
}

// The card's line is the sketch's own README: its bolded question, else its
// first heading, else its first line.
function readmeLine(directory) {
  let text;
  try {
    text = readFileSync(path.join(directory, "README.md"), "utf8").slice(
      0,
      2000,
    );
  } catch {
    return "";
  }
  const asked = text.match(/\*\*([^*]{12,160}\?)\*\*/);
  if (asked !== null) return asked[1].replace(/\s+/g, " ").trim();
  const lines = text
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
  const heading = lines.find((line) => line.startsWith("#"));
  return (heading ?? lines[0] ?? "").replace(/^#+\s*/, "");
}

function readVerdicts(file) {
  let text;
  try {
    text = readFileSync(file, "utf8");
  } catch {
    return [];
  }
  const verdicts = [];
  for (const line of text.split("\n")) {
    try {
      const verdict = JSON.parse(line);
      if (typeof verdict?.build_sha === "string") verdicts.push(verdict);
    } catch {
      continue;
    }
  }
  return verdicts;
}

export async function collect({ runs, artifacts, repo }) {
  const model = await loadModel({ root: runs });
  const pins = await loadPins(artifacts);
  const file = path.join(repo, "docs", "playtests", "verdicts.ndjson");
  const verdicts = readVerdicts(file);
  const index = validateVerdicts({
    file,
    log: path.join(repo, "docs", "playtests", "PLAYTEST-LOG.md"),
    git: repo,
  });
  const probe = gitProbe(repo);
  const sketches = catalogue(repo)
    .filter((entry) => entry.primary && SKETCH_BRANCH.test(entry.branch ?? ""))
    .map((entry) => ({
      ...entry,
      line: readmeLine(entry.directory),
      ...sketchState(entry, verdicts, probe),
    }));
  return { model, pins, verdicts, index, sketches };
}

function sparkline(segments, hex) {
  const points = segments.flatMap((segment) => segment.points);
  const values = points.map((point) => point.value).filter(Number.isFinite);
  if (values.length === 0)
    return `<svg class="spark" viewBox="0 0 100 28" preserveAspectRatio="none" aria-hidden="true"><line x1="0" y1="14" x2="100" y2="14" stroke="${PAGE.muted}" stroke-dasharray="2 3" vector-effect="non-scaling-stroke"/></svg>`;
  const low = Math.min(...values);
  const span = Math.max(...values) - low || 1;
  const step = points.length > 1 ? 100 / (points.length - 1) : 0;
  let position = 0;
  const marks = [];
  for (const segment of segments) {
    const coords = [];
    for (const point of segment.points) {
      const x = points.length > 1 ? position * step : 50;
      position += 1;
      if (!Number.isFinite(point.value)) continue;
      coords.push([x, 25 - ((point.value - low) / span) * 22]);
    }
    if (coords.length > 1)
      marks.push(
        `<polyline points="${coords.map(([x, y]) => `${x.toFixed(1)},${y.toFixed(1)}`).join(" ")}" fill="none" stroke="${hex}" stroke-width="2" vector-effect="non-scaling-stroke"/>`,
      );
    if (coords.length === 1) {
      const [[x, y]] = coords;
      marks.push(
        `<line x1="${Math.max(0, x - 4).toFixed(1)}" y1="${y.toFixed(1)}" x2="${Math.min(100, x + 4).toFixed(1)}" y2="${y.toFixed(1)}" stroke="${hex}" stroke-width="3" vector-effect="non-scaling-stroke"/>`,
      );
    }
  }
  return `<svg class="spark" viewBox="0 0 100 28" preserveAspectRatio="none" aria-hidden="true">${marks.join("")}</svg>`;
}

// Where a missing reading has an answer elsewhere on the page, say where.
const NO_READING = {
  unplayed_green:
    'not yet recorded; <a href="#waiting">see Waiting for Andrew</a>',
};

function tile(metric, data) {
  const reading = latestReading(data.model, metric.id);
  const measure = reading?.measure ?? { value: null, n: 0 };
  const status = evaluate(metric, measure);
  const segments =
    reading === null
      ? []
      : (data.model.trends.get(metric.id)?.get(reading.series) ?? []);
  const where =
    reading === null
      ? (NO_READING[metric.id] ?? "no reading")
      : `${esc(reading.series)} · seq ${reading.record.seq}`;
  const change =
    reading === null
      ? ""
      : `<p class="change">${esc(changeText(compareToPin(reading, data.pins)))}</p>`;
  return `<article class="tile" id="m-${metric.id}" data-metric="${metric.id}" ${tint(status)}>
<header><span class="glyph">${status.glyph}</span><code class="id">${breakable(metric.id)}</code><span class="word">${status.word}</span></header>
<p class="value">${valueText(measure)} <small>n=${measure.n ?? 0} · ${metric.kind}${metric.sentinel ? " · sentinel" : ""}</small></p>
${sparkline(segments, status.hex)}
${change}<p class="says">${esc(metric.says)}</p>
<p class="where">${where}</p>
</article>`;
}

function tally(data) {
  const counts = new Map(Object.values(STATUS).map((status) => [status, 0]));
  for (const metric of METRICS) {
    const measure = latestReading(data.model, metric.id)?.measure ?? {
      value: null,
      n: 0,
    };
    const status = evaluate(metric, measure);
    counts.set(status, counts.get(status) + 1);
  }
  return [...counts]
    .map(
      ([status, count]) =>
        `<li class="chip${count === 0 ? " none" : ""}" ${tint(status)}><span class="glyph">${status.glyph}</span> ${count} ${status.word}</li>`,
    )
    .join("");
}

function waiting(data) {
  const due = data.sketches.filter((entry) => entry.waiting);
  const cards = due
    .map((entry) => {
      const history =
        entry.last === null
          ? "never played"
          : `changed since entry ${entry.last.entry} (build ${short(entry.last.build_sha)})`;
      const changes =
        entry.changes.length === 0
          ? ""
          : `<ul class="changes">${entry.changes
              .slice(0, 5)
              .map((subject) => `<li>${esc(subject)}</li>`)
              .join(
                "",
              )}${entry.changes.length > 5 ? `<li>and ${entry.changes.length - 5} more</li>` : ""}</ul>`;
      return `<li class="build" data-sketch="${esc(entry.sketch)}"><strong>${esc(entry.id)}</strong>${entry.id === entry.sketch ? "" : ` <span class="where">sketch ${esc(entry.sketch)}</span>`} <span class="where">${esc(entry.branch)}@${esc(entry.head)}</span>
<span class="history">${history}</span>${entry.line === "" ? "" : `<q>${esc(entry.line)}</q>`}${changes}</li>`;
    })
    .join("\n");
  const steps = due
    .map(
      (entry) =>
        `<li class="play"><code>scrapkeep ${esc(entry.id)}</code></li>`,
    )
    .join("");
  const latest = data.verdicts.at(-1);
  const index = data.index.ok
    ? `${data.verdicts.length} verdicts, index valid.`
    : `${data.verdicts.length} verdicts; the index has ${data.index.problems.length} problem(s): ${data.index.problems.map(esc).join("; ")}`;
  const lastVerdict =
    latest === undefined
      ? ""
      : ` Latest: entry ${latest.entry} on build ${short(latest.build_sha)}${latest.tags?.length ? `, tagged ${latest.tags.map(esc).join(", ")}` : ""}.`;
  return `<p class="lead"><span class="count">${due.length}</span> ${due.length === 1 ? "build waits" : "builds wait"} for your play. Headless checks prove the systems run; feel needs you.</p>
${due.length === 0 ? "" : `<ul class="builds">${cards}</ul>`}
<h3>Playtest checklist</h3>
<ol class="checklist">${steps}<li>Write the verdict in <code>docs/playtests/PLAYTEST-LOG.md</code>, add its line to <code>verdicts.ndjson</code>, then <code>scrapkeep lab verdicts</code>.</li></ol>
<h3>Verdict index</h3>
<p>${index}${lastVerdict}</p>
<h3>Gameplay findings to look for</h3>
<ul>${ADMITTED.gameplay.lines.map((line) => `<li>${esc(line)}</li>`).join("")}</ul>
<p class="source">Admitted at ${ADMITTED.gameplay.source}.</p>`;
}

function layers(data) {
  const names = [...new Set(METRICS.map((metric) => metric.layer))];
  return names
    .map(
      (layer) => `<h3>${layer}</h3>
<div class="tiles">${METRICS.filter((metric) => metric.layer === layer)
        .map((metric) => tile(metric, data))
        .join("\n")}</div>`,
    )
    .join("\n");
}

function arms(data) {
  const byScenario = new Map();
  for (const record of data.model.latest.values()) {
    if (record.type !== "batch") continue;
    const arm = record.config?.arm ?? record.label.split("-").at(-1);
    const scenario =
      record.config?.scenario ?? record.label.slice(0, -arm.length - 1);
    if (!byScenario.has(scenario)) byScenario.set(scenario, new Map());
    byScenario.get(scenario).set(arm, record);
  }
  const parked = `<p class="note">No jev column: Jev as player is parked (<a href="#parked">why</a>).</p>`;
  if (byScenario.size === 0)
    return `<p>No batch runs yet. <code>scrapkeep lab run &lt;scenario&gt; --arm scripted</code> records one.</p>${parked}`;
  const order = Object.keys(ARMS);
  return [...byScenario]
    .toSorted(([a], [b]) => a.localeCompare(b))
    .map(([scenario, runs]) => {
      const columns = [...runs.keys()].toSorted(
        (a, b) => order.indexOf(a) - order.indexOf(b),
      );
      const ids = METRICS.filter((metric) =>
        columns.some((arm) => {
          const record = runs.get(arm);
          return (
            metric.id in (record.kpis ?? {}) || metric.id in (record.kris ?? {})
          );
        }),
      );
      const cell = (metric, record) => {
        const measure = record.kpis?.[metric.id] ?? record.kris?.[metric.id];
        if (measure === undefined) return `<td class="empty">·</td>`;
        const status = evaluate(metric, measure);
        return `<td ${tint(status)}><span class="glyph">${status.glyph}</span> ${valueText(measure)}</td>`;
      };
      const rows = [
        `<tr data-row="result"><th>result</th>${columns.map((arm) => `<td>${esc(runs.get(arm).result)}</td>`).join("")}</tr>`,
        `<tr data-row="trials"><th>trials</th>${columns
          .map((arm) => {
            const config = runs.get(arm).config ?? {};
            return `<td>${config.trials?.length ?? config.requested_trials ?? "?"}</td>`;
          })
          .join("")}</tr>`,
        ...ids.map(
          (metric) =>
            `<tr data-row="${metric.id}"><th><a href="#m-${metric.id}">${metric.id}</a></th>${columns.map((arm) => cell(metric, runs.get(arm))).join("")}</tr>`,
        ),
      ];
      return `<h3>${esc(scenario)}</h3>
<div class="scroll"><table><thead><tr><th></th>${columns.map((arm) => `<th>${esc(arm)}<br><small>seq ${runs.get(arm).seq}</small></th>`).join("")}</tr></thead>
<tbody>${rows.join("\n")}</tbody></table></div>`;
    })
    .join("\n")
    .concat(runsHaveJev(data) ? "" : parked);
}

function runsHaveJev(data) {
  return [...data.model.latest.values()].some(
    (record) => record.type === "batch" && record.config?.arm === "jev",
  );
}

// The warn and fail bands take their status from evaluate() at a value
// inside each band, so a band always matches the status a reading there gets.
// The fail band is filled more heavily, so the two differ by fill as well as
// by hue.
function bands(metric, low, high) {
  const { thresholds } = metric;
  if (metric.sentinel || thresholds === null) return [];
  const { warn, fail, worse } = thresholds;
  const beyond = worse === "higher" ? high : low;
  const probe = (value) => evaluate(metric, { value, n: metric.min_n });
  return [
    { from: warn, to: fail, status: probe((warn + fail) / 2), opacity: 0.1 },
    {
      from: fail,
      to: beyond,
      status: probe(fail + (fail - warn)),
      opacity: 0.3,
    },
  ];
}

function trendChart(metric, series, segments) {
  const points = segments.flatMap((segment) => segment.points);
  const values = points.map((point) => point.value).filter(Number.isFinite);
  const limits = metric.thresholds
    ? [metric.thresholds.warn, metric.thresholds.fail]
    : [];
  let low = Math.min(...values, ...limits);
  let high = Math.max(...values, ...limits);
  const pad = (high - low || Math.abs(high) || 1) * 0.15;
  low = low >= 0 ? Math.max(0, low - pad) : low - pad;
  high += pad;
  const [W, H, L, R, T, B] = [320, 110, 44, 8, 8, 16];
  const axis = (value) => String(Number(value.toPrecision(3)));
  const x = (index) =>
    L +
    (points.length === 1
      ? (W - L - R) / 2
      : (index * (W - L - R)) / (points.length - 1));
  const y = (value) => T + ((high - value) / (high - low)) * (H - T - B);
  const clamp = (value) => Math.min(high, Math.max(low, value));
  const parts = [];
  for (const band of bands(metric, low, high)) {
    const top = y(clamp(Math.max(band.from, band.to)));
    const bottom = y(clamp(Math.min(band.from, band.to)));
    if (bottom - top < 0.5) continue;
    const edge = y(clamp(band.from));
    const { hex, ink, gate } = band.status;
    parts.push(
      `<rect class="band" x="${L}" y="${top.toFixed(1)}" width="${W - L - R}" height="${(bottom - top).toFixed(1)}" fill="${hex}" fill-opacity="${band.opacity}"/>`,
      `<line x1="${L}" y1="${edge.toFixed(1)}" x2="${W - R}" y2="${edge.toFixed(1)}" stroke="${hex}" stroke-opacity="0.7" stroke-dasharray="4 3"/>`,
      `<text class="band-label" x="${W - R - 3}" y="${(Math.abs(edge - bottom) < 0.5 ? bottom - 3 : top + 9).toFixed(1)}" text-anchor="end" style="fill: ${ink}">${gate}</text>`,
    );
  }
  parts.push(
    `<line x1="${L}" y1="${H - B}" x2="${W - R}" y2="${H - B}" stroke="${PAGE.rule}"/>`,
    `<text class="axis" x="${L - 4}" y="${(T + 8).toFixed(1)}" text-anchor="end">${axis(high)}</text>`,
    `<text class="axis" x="${L - 4}" y="${H - B}" text-anchor="end">${axis(low)}</text>`,
  );
  let index = 0;
  for (const [position, segment] of segments.entries()) {
    const coords = segment.points.map((point) => [x(index++), point]);
    if (position > 0) {
      const at = (x(index - segment.points.length - 1) + coords[0][0]) / 2;
      parts.push(
        `<line class="epoch-rule" x1="${at.toFixed(1)}" y1="${T}" x2="${at.toFixed(1)}" y2="${H - B}" stroke="${PAGE.epoch}" stroke-dasharray="3 3"><title>epoch change: ${esc(describeEpoch(JSON.parse(segment.epoch)))}</title></line>`,
      );
    }
    const finite = coords.filter(([, point]) => Number.isFinite(point.value));
    if (finite.length > 1)
      parts.push(
        `<polyline points="${finite.map(([px, point]) => `${px.toFixed(1)},${y(point.value).toFixed(1)}`).join(" ")}" fill="none" stroke="${PAGE.soft}" stroke-width="1.5"/>`,
      );
    for (const [px, point] of finite) {
      const status = evaluate(metric, point);
      parts.push(
        `<circle cx="${px.toFixed(1)}" cy="${y(point.value).toFixed(1)}" r="3.2" fill="${status.hex}"><title>seq ${point.seq}: ${number(point.value)} n=${point.n} ${status.word}</title></circle>`,
      );
    }
  }
  const first = points[0].seq;
  const last = points.at(-1).seq;
  return `<figure class="trend" data-trend="${metric.id} ${esc(series)}">
<figcaption><a href="#m-${metric.id}">${metric.id}</a> · ${esc(series)} · seq ${first}${first === last ? "" : ` to ${last}`}</figcaption>
<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${metric.id} over ${points.length} runs">${parts.join("")}</svg>
</figure>`;
}

function trends(data) {
  const epochs = data.model.epochs
    .map(
      (epoch, position) =>
        `<li>epoch ${position + 1}: ${esc(describeEpoch(epoch.identity))}, ${epoch.runs} runs</li>`,
    )
    .join("");
  const breaks = data.model.boundaries
    .map(
      (boundary) =>
        `<li>trend break in ${esc(boundary.series)} at seq ${boundary.seq}</li>`,
    )
    .join("");
  const charts = [];
  for (const metric of METRICS) {
    const bySeries = data.model.trends.get(metric.id);
    if (bySeries === undefined) continue;
    for (const [series, segments] of bySeries) {
      const finite = segments
        .flatMap((segment) => segment.points)
        .filter((point) => Number.isFinite(point.value));
      if (finite.length < 2) continue;
      charts.push(trendChart(metric, series, segments));
    }
  }
  const legend = `<p class="note">Shaded bands are the warn and fail zones; a dashed <span class="epoch">epoch rule</span> marks an instrument change, and the line never joins two epochs.</p>`;
  return `${legend}
<ul class="epochs">${epochs}${breaks}</ul>
${charts.length === 0 ? "<p>No series has two readings yet.</p>" : `<div class="charts">${charts.join("\n")}</div>`}`;
}

function scoreTile({ role, earned, possible }, qualification) {
  const share = `${((earned / possible) * 100).toFixed(1)}%`;
  return `<div class="score" ${tint(SHOWN)}>
<p class="role"><span class="glyph">${SHOWN.glyph}</span> ${esc(role)}</p>
<p class="value">${earned} of ${possible} <small>${share}</small></p>
<p class="qualification">${esc(qualification)}</p>
</div>`;
}

function testLoop() {
  const { triage, tagging, parked } = ADMITTED;
  return `<aside class="parked" id="parked"><h3>Parked instrument</h3><p>${esc(parked.line)}</p><p>${esc(parked.qualification)}</p><p class="source">${parked.source}</p></aside>
<div class="loop">
<div class="card"><h3>${triage.title}</h3>
<div class="pair">${triage.scores.map((score) => scoreTile(score, SCORE_LABELS[score.role])).join("")}</div>
<p>${esc(triage.note)}</p><p class="source">${triage.source}</p>
<p>${esc(triage.advisory)}</p><p class="source">${triage.advisorySource}</p></div>
<div class="card"><h3>${tagging.title}</h3>
<div class="pair">${tagging.scores.map((score) => scoreTile(score, tagging.qualification)).join("")}</div>
<p class="source">${tagging.source}</p></div>
</div>
<p class="note"><span class="glyph" ${tint(SHOWN)}>${SHOWN.glyph}</span> ${SHOWN.word}: shown as admitted, never gated.</p>`;
}

function findings(data) {
  const items = [];
  const limits = [];
  for (const record of [...data.model.latest.values()].toSorted(
    (a, b) => b.seq - a.seq,
  )) {
    const series = esc(seriesOf(record));
    for (const finding of record.findings ?? [])
      items.push(
        `<li><p>${esc(finding.summary ?? JSON.stringify(finding))}</p><p class="where">${series} · seq ${record.seq}</p>${typeof finding.repro === "string" && finding.repro.trim() !== "" ? `<pre><code>${esc(finding.repro)}</code></pre>` : `<p class="where">no repro recorded</p>`}</li>`,
      );
    for (const limit of record.limits ?? [])
      limits.push(
        `<li>${esc(limit)} <span class="where">${series}</span></li>`,
      );
  }
  const problems = data.model.problems.map(
    (problem) => `<li>${esc(problem)}</li>`,
  );
  return `<h3>Findings</h3>${items.length === 0 ? "<p>No findings in the latest runs.</p>" : `<ul class="findings">${items.join("")}</ul>`}
<h3>Limits</h3>${limits.length === 0 ? "<p>None recorded.</p>" : `<ul>${limits.join("")}</ul>`}
${problems.length === 0 ? "" : `<h3>Problems reading the runs</h3><ul>${problems.join("")}</ul>`}`;
}

const STYLE = `
:root { color-scheme: dark; --bg: ${PAGE.background}; --deep: ${PAGE.deep}; --panel: ${PAGE.panel}; --rule: ${PAGE.rule}; --muted: ${PAGE.muted}; --text: ${PAGE.text}; --soft: ${PAGE.soft}; --bright: ${PAGE.bright}; --accent: ${PAGE.accent}; --epoch: ${PAGE.epoch}; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--text); font: 15px/1.5 system-ui, sans-serif; }
code, pre, .value, .where, .chip, figcaption, svg text, td, th a { font-family: ui-monospace, "JetBrainsMono Nerd Font", "JetBrains Mono", monospace; }
main { max-width: 76rem; margin: 0 auto; padding: 1rem clamp(0.75rem, 3vw, 2rem) 3rem; }
header.top h1 { margin: 0; color: var(--bright); font-size: 1.5rem; letter-spacing: 0.02em; }
header.top p { margin: 0.25rem 0; color: var(--soft); overflow-wrap: anywhere; }
nav { display: flex; flex-wrap: wrap; gap: 0.25rem 1rem; margin: 0.75rem 0; font-size: 0.9rem; }
a { color: var(--soft); }
.chips { display: flex; flex-wrap: wrap; gap: 0.5rem; padding: 0; margin: 0.75rem 0 0; list-style: none; }
.chip.none { border-style: dashed; }
.chip { padding: 0.15rem 0.6rem; border: 1px solid var(--status); border-radius: 999px; color: var(--ink); font-size: 0.85rem; }
section { margin-top: 1.5rem; padding: 1rem clamp(0.75rem, 2vw, 1.25rem); background: var(--deep); border: 1px solid var(--rule); border-radius: 10px; }
section h2 { margin: 0 0 0.5rem; color: var(--bright); font-size: 1.2rem; }
h3 { margin: 1.1rem 0 0.4rem; color: var(--soft); font-size: 0.95rem; text-transform: uppercase; letter-spacing: 0.06em; }
section[data-section="waiting"] { border-color: var(--accent); box-shadow: 0 0 0 1px var(--accent), 0 0 24px color-mix(in srgb, var(--accent) 22%, transparent); }
section[data-section="waiting"] h2 { color: var(--accent); }
.lead { font-size: 1.05rem; color: var(--bright); }
.count { display: inline-block; min-width: 1.8em; padding: 0 0.4em; border-radius: 999px; background: var(--accent); color: var(--deep); font-weight: 700; text-align: center; animation: breathe 2.8s ease-in-out infinite; }
@keyframes breathe { 50% { box-shadow: 0 0 14px var(--accent); } }
.builds { list-style: none; padding: 0; display: grid; gap: 0.5rem; }
.build { padding: 0.5rem 0.75rem; background: var(--panel); border-left: 3px solid var(--accent); border-radius: 6px; }
.build strong { color: var(--bright); }
.build .history { display: block; color: var(--accent); font-size: 0.85rem; }
.build q { display: block; color: var(--soft); font-style: italic; }
.checklist li { margin: 0.2rem 0; }
.checklist code, .findings code { color: var(--bright); }
.where, .source, small { color: var(--soft); font-size: 0.8rem; }
.tiles { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 15rem), 1fr)); gap: 0.6rem; }
.tile { padding: 0.6rem 0.7rem; background: var(--panel); border: 1px solid var(--rule); border-left: 4px solid var(--status); border-radius: 8px; min-width: 0; }
.tile:target { outline: 2px solid var(--status); }
.tile header { display: flex; align-items: baseline; gap: 0.4rem; }
.tile .id { color: var(--bright); overflow-wrap: break-word; flex: 1; min-width: 0; }
.tile .word { color: var(--ink); font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; }
.glyph { color: var(--ink); }
.tile .value { margin: 0.2rem 0 0; font-size: 1.25rem; color: var(--bright); }
.tile p { margin: 0.15rem 0; }
.tile .says { color: var(--soft); font-size: 0.85rem; }
.tile .change { font-size: 0.8rem; color: var(--text); }
.spark { display: block; width: 100%; height: 28px; margin: 0.3rem 0; overflow: visible; }
.scroll { overflow-x: auto; }
table { border-collapse: collapse; min-width: 100%; font-size: 0.9rem; }
th, td { padding: 0.3rem 0.6rem; border-bottom: 1px solid var(--rule); text-align: left; white-space: nowrap; }
td[style] { color: var(--ink); }
td.empty { color: var(--muted); }
.charts { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 20rem), 1fr)); gap: 0.75rem; }
.trend { margin: 0; padding: 0.5rem; background: var(--panel); border-radius: 8px; }
.trend figcaption { font-size: 0.8rem; color: var(--soft); overflow-wrap: anywhere; }
.trend svg { width: 100%; height: auto; }
.trend text { fill: var(--soft); font-size: 9px; }
.epoch { color: var(--epoch); }
.epochs { font-size: 0.85rem; color: var(--soft); overflow-wrap: anywhere; }
.note { color: var(--soft); font-size: 0.85rem; }
.parked { padding: 0.5rem 0.75rem; border: 1px dashed var(--muted); border-radius: 8px; color: var(--soft); }
.parked h3 { margin-top: 0; }
.loop { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 22rem), 1fr)); gap: 0.75rem; margin-top: 0.75rem; }
.card { padding: 0.5rem 0.75rem; background: var(--panel); border-radius: 8px; }
.card h3 { margin-top: 0.2rem; }
.pair { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 10rem), 1fr)); gap: 0.5rem; }
.score { padding: 0.5rem; border: 1px solid var(--rule); border-top: 3px solid var(--status); border-radius: 6px; }
.score p { margin: 0.15rem 0; }
.score .value { font-size: 1.2rem; color: var(--bright); }
.score .qualification { font-size: 0.8rem; color: var(--soft); }
.findings { list-style: none; padding: 0; }
.findings li { margin-bottom: 0.6rem; }
.findings p { margin: 0; }
pre { margin: 0.2rem 0 0; padding: 0.4rem 0.6rem; background: var(--panel); border-radius: 6px; overflow-x: auto; }
@media (prefers-reduced-motion: reduce) { * { animation: none !important; } }
`;

export function renderPage(data, { now = new Date() } = {}) {
  const body = {
    waiting: waiting(data),
    layers: layers(data),
    arms: arms(data),
    trends: trends(data),
    "test-loop": testLoop(),
    findings: findings(data),
  };
  const runs =
    data.model.records.length === 0
      ? `no runs under ${esc(data.model.root)}`
      : `${data.model.records.length} runs under ${esc(data.model.root)}`;
  const sections = SECTIONS.map(
    ({ id, title }) =>
      `<section id="${id}" data-section="${id}"><h2>${title}</h2>\n${body[id]}\n</section>`,
  ).join("\n");
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="${CSP}">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark">
<title>Scrapkeep lab</title>
<style>${STYLE}</style>
</head>
<body>
<main>
<header class="top"><h1>Scrapkeep lab</h1>
<p>${runs} · written ${now.toISOString()} · admitted results as of ${ADMITTED_AS_OF}</p>
<ul class="chips">${tally(data)}</ul>
<nav>${SECTIONS.map(({ id, title }) => `<a href="#${id}">${title}</a>`).join("")}</nav>
</header>
${sections}
</main>
</body>
</html>
`;
}

const USAGE = `Usage:
  node scripts/lab/dash.mjs [--runs dir] [--artifacts dir] [--repo dir] [--out file]
  scrapkeep dash
Writes ${path.relative(repositoryRoot, DASH_FILE)} by default.`;

export async function main(
  argv,
  { out = process.stdout, err = process.stderr } = {},
) {
  let values;
  try {
    ({ values } = parseArgs({
      args: argv,
      options: {
        runs: { type: "string" },
        artifacts: { type: "string" },
        repo: { type: "string" },
        out: { type: "string" },
      },
      allowPositionals: false,
      strict: true,
    }));
  } catch (error) {
    err.write(`${error.message}\n${USAGE}\n`);
    return EXIT.usage;
  }
  const target = path.resolve(values.out ?? DASH_FILE);
  const data = await collect({
    runs: path.resolve(values.runs ?? RUNS_ROOT),
    artifacts: path.resolve(
      values.artifacts ?? path.join(repositoryRoot, "artifacts"),
    ),
    repo: path.resolve(values.repo ?? repositoryRoot),
  });
  await mkdir(path.dirname(target), { recursive: true });
  await writeFile(target, renderPage(data));
  out.write(`${target}\n`);
  return EXIT.pass;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  try {
    process.exitCode = await main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`${error.stack ?? error}\n`);
    process.exitCode = EXIT.invalid;
  }
}
