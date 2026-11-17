// The replay page (JL-31): one self-contained HTML file that plays a retained
// trial as a top-down view at a selectable speed, with every decision on a
// timeline. It reads the trial's protocol files (hello, states, intents,
// events.ndjson, done or error) and, when the trial was watched, the watch
// side file beside it for probabilities, latency and how each decision was
// made. The page has one inline script pinned by its sha256 in the CSP, no
// network and no outside resource. Colours and shapes come from
// metrics/status.mjs, the same table the Godot overlay draws from.
//
//   node scripts/lab/replay.mjs <run dir | trial io dir> [--trial NNN] [--out file.html]
import { createHash } from "node:crypto";
import { existsSync, realpathSync } from "node:fs";
import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

import { EXIT, INTENT, PAGE, SOURCE, WATCH } from "./metrics/status.mjs";

export const REPLAY_CSP_BASE =
  "default-src 'none'; style-src 'unsafe-inline'; img-src data:; script-src";
export const SPEEDS = Object.freeze([0.25, 0.5, 1, 2, 4, 8]);

const STATE = /^state-(\d{6})\.json$/;
const INTENT_FILE = /^intent-(\d{6})\.json$/;

async function json(file) {
  try {
    return JSON.parse(await readFile(file, "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

async function ndjson(file) {
  let text;
  try {
    text = await readFile(file, "utf8");
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
  const out = [];
  for (const line of text.split("\n")) {
    if (line.trim() === "") continue;
    try {
      out.push(JSON.parse(line));
    } catch {
      // A torn last line from a killed writer carries nothing to draw.
    }
  }
  return out;
}

// A run directory resolves to one of its trials; a trial directory to itself.
async function locate(target, trial) {
  const resolved = path.resolve(target);
  if (existsSync(path.join(resolved, "run.json"))) {
    const name =
      trial ?? (await readdir(path.join(resolved, "trials"))).sort()[0];
    return {
      run: resolved,
      io: path.join(resolved, "trials", name),
      trial: name,
    };
  }
  if (existsSync(path.join(resolved, "hello.json"))) {
    const run = path.dirname(path.dirname(resolved));
    return {
      run: existsSync(path.join(run, "run.json")) ? run : null,
      io: resolved,
      trial: path.basename(resolved),
    };
  }
  throw new Error(`${target} is neither a run directory nor a trial directory`);
}

function kindOf(intent) {
  if (intent.source === "forced") return "forced";
  if (intent.meta?.low_confidence === true) return "fallback";
  return intent.source;
}

export async function replayData(target, { trial } = {}) {
  const where = await locate(target, trial);
  const { io } = where;
  const hello = await json(path.join(io, "hello.json"));
  const done = await json(path.join(io, "done.json"));
  const error = await json(path.join(io, "error.json"));
  const record =
    where.run === null ? null : await json(path.join(where.run, "run.json"));
  const events = await ndjson(path.join(io, "events.ndjson"));
  const watchDir =
    where.run === null ? null : path.join(where.run, "watch", where.trial);
  const watched =
    watchDir === null
      ? []
      : await ndjson(path.join(watchDir, "decisions.ndjson"));
  const bySeq = new Map(watched.map((line) => [line.seq, line]));
  const files = await readdir(io);
  const states = new Map();
  const intents = new Map();
  for (const name of files) {
    const state = STATE.exec(name);
    if (state !== null)
      states.set(Number(state[1]), await json(path.join(io, name)));
    const intent = INTENT_FILE.exec(name);
    if (intent !== null)
      intents.set(Number(intent[1]), await json(path.join(io, name)));
  }
  const applied = new Map(
    events
      .filter((event) => event.kind === "intent")
      .map((event) => [event.seq, event.tick]),
  );
  const decisions = [...intents.keys()]
    .sort((a, b) => a - b)
    .map((seq) => {
      const intent = intents.get(seq);
      const state = states.get(seq);
      const seen = bySeq.get(seq);
      return {
        seq,
        tick: state?.tick ?? null,
        apply_tick: applied.get(seq) ?? null,
        intent: intent.intent,
        arm: intent.arm,
        kind: seen?.kind ?? kindOf(intent),
        rule: intent.meta?.rule ?? null,
        confidence: intent.meta?.confidence ?? null,
        raw_intent: intent.meta?.raw_intent ?? intent.intent,
        offered:
          seen?.offered.map((option) => option.id) ??
          state?.jev.options.map((option) => option.id) ??
          [],
        gated: seen?.gated ?? [],
        probabilities: seen?.probabilities ?? null,
        latency_ms: seen?.latency_ms ?? null,
      };
    });
  const trace = events
    .filter((event) => event.kind === "trace")
    .map((event) => [event.tick, event.pos[0], event.pos[2], event.pos[1]]);
  const marks = events
    .filter((event) => ["knock", "anomaly"].includes(event.kind))
    .map((event) => ({
      tick: event.tick,
      kind: event.kind,
      what: event.what ?? null,
    }));
  const endTick = done?.ticks ?? error?.tick ?? trace.at(-1)?.[0] ?? 0;
  const watch = record?.config?.watch ?? null;
  const entry = record?.config?.trials?.find(
    (one) => one.io === path.relative(where.run ?? "", io),
  );
  return {
    run_id: record?.id ?? null,
    trial: where.trial,
    scenario: hello?.scenario ?? null,
    arm: record?.config?.arm ?? decisions[0]?.arm ?? null,
    mode: hello?.physics_mode ?? null,
    seed: hello?.seed ?? null,
    tick_hz: hello?.tick_hz ?? 90,
    hold_ticks: hello?.hold_ticks ?? null,
    outcome:
      done?.reason ?? (error === null ? "unfinished" : `error ${error.code}`),
    end_tick: endTick,
    trace_hash: done?.trace_hash ?? null,
    abort: entry?.abort ?? null,
    label: watch?.label ?? null,
    demo: watch?.demo === true,
    trace,
    decisions,
    marks,
    source: { run: where.run, io },
  };
}

const ESCAPES = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
};
const esc = (text) => String(text).replace(/[&<>"']/g, (one) => ESCAPES[one]);
const num = (value) => Number(value.toFixed(2));

function lookOf(id) {
  return (
    INTENT[id] ?? {
      word: id,
      hex: PAGE.muted,
      glyph: "?",
      shape: INTENT.take_cache.shape,
    }
  );
}

function polygon(shape, x, y, size) {
  return shape
    .map(([u, v]) => `${num(x + u * size)},${num(y + v * size)}`)
    .join(" ");
}

// Where the ball was at `tick`, interpolated along the 10 Hz trace.
function positionAt(trace, tick) {
  if (trace.length === 0) return [0, 0];
  if (tick <= trace[0][0]) return [trace[0][1], trace[0][2]];
  for (let i = 1; i < trace.length; i += 1) {
    if (trace[i][0] >= tick) {
      const [t0, x0, z0] = trace[i - 1];
      const [t1, x1, z1] = trace[i];
      const f = t1 === t0 ? 0 : (tick - t0) / (t1 - t0);
      return [x0 + (x1 - x0) * f, z0 + (z1 - z0) * f];
    }
  }
  return [trace.at(-1)[1], trace.at(-1)[2]];
}

// Trace samples split into runs by the intent held at each sample, so the
// path is drawn in the colour of what the ball was doing there.
function heldSpans(trace, decisions) {
  const changes = decisions
    .filter((one) => one.apply_tick !== null)
    .map((one) => [one.apply_tick, one.intent]);
  const spans = [];
  let current = null;
  for (const sample of trace) {
    let held = null;
    for (const [tick, intent] of changes) if (tick <= sample[0]) held = intent;
    if (current === null || current.intent !== held) {
      const start = current === null ? [] : [current.points.at(-1)];
      current = { intent: held, points: [...start] };
      spans.push(current);
    }
    current.points.push([sample[1], sample[2]]);
  }
  return spans;
}

function mapSvg(data) {
  const xs = data.trace.map((one) => one[1]);
  const zs = data.trace.map((one) => one[2]);
  const pad = 6;
  const [loX, hiX] =
    xs.length === 0 ? [0, 0] : [Math.min(...xs), Math.max(...xs)];
  const [loZ, hiZ] =
    zs.length === 0 ? [0, 0] : [Math.min(...zs), Math.max(...zs)];
  const span = Math.max(hiX - loX, hiZ - loZ, 8) + pad * 2;
  const minX = (loX + hiX) / 2 - span / 2;
  const minZ = (loZ + hiZ) / 2 - span / 2;
  const unit = span / 100;
  const box = `${num(minX)} ${num(minZ)} ${num(span)} ${num(span)}`;
  const paths = heldSpans(data.trace, data.decisions)
    .map((one) => {
      const hex = one.intent === null ? PAGE.muted : lookOf(one.intent).hex;
      const points = one.points
        .map(([x, z]) => `${num(x)},${num(z)}`)
        .join(" ");
      return `<polyline points="${points}" fill="none" stroke="${hex}" stroke-width="${num(unit * 0.9)}" stroke-linejoin="round" stroke-linecap="round" opacity="0.55"/>`;
    })
    .join("");
  const markers = data.decisions
    .filter((one) => one.apply_tick !== null)
    .map((one, index) => {
      const [x, z] = positionAt(data.trace, one.apply_tick);
      const look = lookOf(one.intent);
      return `<polygon class="dm" data-i="${index}" points="${polygon(look.shape, x, z, unit * 1.6)}" fill="${look.hex}" stroke="${PAGE.deep}" stroke-width="${num(unit * 0.25)}"/>`;
    })
    .join("");
  const [x0, z0] =
    data.trace.length > 0 ? [data.trace[0][1], data.trace[0][2]] : [0, 0];
  return `<svg id="map" viewBox="${box}" data-unit="${num(unit)}" role="img" aria-label="Top-down path of the ball">
<rect x="${num(minX)}" y="${num(minZ)}" width="${num(span)}" height="${num(span)}" fill="${PAGE.deep}"/>
<g>${paths}</g>
<polyline id="recent" points="" fill="none" stroke="${PAGE.bright}" stroke-width="${num(unit * 0.5)}" stroke-linejoin="round" opacity="0.9"/>
<g>${markers}</g>
<circle id="ball" cx="${num(x0)}" cy="${num(z0)}" r="${num(unit * 1.4)}" fill="${PAGE.bright}" stroke="${PAGE.deep}" stroke-width="${num(unit * 0.3)}"/>
</svg>`;
}

function timelineSvg(data) {
  const end = Math.max(1, data.end_tick);
  const x = (tick) => num((tick / end) * 1000);
  const chips = data.decisions
    .map((one, index) => {
      const at = one.apply_tick ?? one.tick ?? 0;
      const look = lookOf(one.intent);
      const dim = ["forced", "fallback", "failed"].includes(one.kind)
        ? ' opacity="0.55"'
        : "";
      return `<polygon class="tc" data-i="${index}" points="${polygon(look.shape, x(at), 22, 9)}" fill="${look.hex}"${dim}><title>#${one.seq} ${esc(one.intent)} at tick ${at} (${esc(SOURCE[one.kind]?.word ?? one.kind)})</title></polygon>`;
    })
    .join("");
  const knocks = data.marks
    .map(
      (one) =>
        `<rect x="${x(one.tick) - 1}" y="38" width="2" height="10" fill="${(one.kind === "anomaly" ? WATCH.anomaly : WATCH.knock).hex}"><title>${esc(one.kind)}${one.what ? ` ${esc(one.what)}` : ""} at tick ${one.tick}</title></rect>`,
    )
    .join("");
  const seconds = [];
  for (let s = 0; s * data.tick_hz <= end; s += 5) {
    seconds.push(
      `<text x="${x(s * data.tick_hz)}" y="62" fill="${PAGE.soft}" font-size="10" text-anchor="middle">${s}s</text>`,
    );
  }
  return `<svg id="timeline" viewBox="-12 0 1024 66" preserveAspectRatio="none" role="img" aria-label="Decisions over time">
<rect x="0" y="20" width="1000" height="4" fill="${PAGE.rule}"/>
${chips}${knocks}${seconds.join("")}
<rect id="playhead" x="0" y="4" width="2" height="46" fill="${PAGE.bright}"/>
</svg>`;
}

function barsFor(one) {
  const ids = one.offered.length > 0 ? one.offered : [one.intent];
  return ids
    .map((id) => {
      const look = lookOf(id);
      const p = one.probabilities?.[id];
      const chosen = id === one.intent;
      const width =
        typeof p === "number" ? Math.round(p * 100) : chosen ? 100 : 0;
      const value =
        typeof p === "number"
          ? `${Math.round(p * 100)}%`
          : chosen
            ? "chosen"
            : "";
      return `<div class="bar${chosen ? " chosen" : ""}"><span class="swatch" style="--c: ${look.hex}">${esc(look.glyph)}</span><span class="name">${esc(id)}</span><span class="track"><span class="fill" style="--c: ${look.hex}; width: ${width}%"></span></span><span class="value">${esc(value)}</span></div>`;
    })
    .join("");
}

function cardFor(one, index) {
  const look = lookOf(one.intent);
  const source = SOURCE[one.kind] ?? { word: one.kind, hex: PAGE.soft };
  const facts = [
    `tick ${one.apply_tick ?? one.tick ?? "?"}`,
    one.latency_ms === null ? null : `${one.latency_ms} ms`,
    one.confidence === null ? null : `confidence ${num(one.confidence)}`,
    one.rule === null ? null : `rule ${one.rule}`,
    one.raw_intent !== one.intent ? `Jev leaned ${one.raw_intent}` : null,
    one.gated.length > 0 ? `gated ${one.gated.join(", ")}` : null,
  ].filter((fact) => fact !== null);
  return `<section class="card" data-i="${index}"${index === 0 ? "" : " hidden"}>
<h2><span class="swatch" style="--c: ${look.hex}">${esc(look.glyph)}</span> #${one.seq} ${esc(one.intent)} <span class="source" style="--c: ${source.hex}">${esc(source.word)}</span></h2>
<p class="facts">${esc(facts.join(" · "))}</p>
${barsFor(one)}
</section>`;
}

function legend(data) {
  const ids = [...new Set(data.decisions.map((one) => one.intent))];
  return ids
    .map((id) => {
      const look = lookOf(id);
      return `<li><span class="swatch" style="--c: ${look.hex}">${esc(look.glyph)}</span>${esc(id)}</li>`;
    })
    .join("");
}

// The page's one script: it moves the ball, the recent trail, the playhead and
// the decision card; every element it touches is already in the page.
const SCRIPT = `
const data = JSON.parse(document.getElementById("data").textContent);
const trace = data.trace;
const ball = document.getElementById("ball");
const recent = document.getElementById("recent");
const playhead = document.getElementById("playhead");
const readout = document.getElementById("readout");
const play = document.getElementById("play");
const speed = document.getElementById("speed");
const cards = [...document.querySelectorAll(".card")];
const markers = [...document.querySelectorAll(".dm")];
const chips = [...document.querySelectorAll(".tc")];
const end = Math.max(1, data.end_tick);
const applied = data.decisions.map((one) => one.apply_tick ?? one.tick ?? 0);
let tick = 0;
let playing = false;
let last = null;
let shown = -1;
function at(t) {
  if (trace.length === 0) return [0, 0, 0];
  let lo = 0;
  let hi = trace.length - 1;
  if (t <= trace[0][0]) return [trace[0][1], trace[0][2], 0];
  if (t >= trace[hi][0]) return [trace[hi][1], trace[hi][2], hi];
  while (hi - lo > 1) {
    const mid = (lo + hi) >> 1;
    if (trace[mid][0] <= t) lo = mid; else hi = mid;
  }
  const f = (t - trace[lo][0]) / (trace[hi][0] - trace[lo][0]);
  return [trace[lo][1] + (trace[hi][1] - trace[lo][1]) * f, trace[lo][2] + (trace[hi][2] - trace[lo][2]) * f, lo];
}
function draw() {
  const [x, z, index] = at(tick);
  ball.setAttribute("cx", x.toFixed(2));
  ball.setAttribute("cy", z.toFixed(2));
  const from = Math.max(0, index - 30);
  const points = trace.slice(from, index + 1).map((one) => one[1].toFixed(2) + "," + one[2].toFixed(2));
  points.push(x.toFixed(2) + "," + z.toFixed(2));
  recent.setAttribute("points", points.join(" "));
  playhead.setAttribute("x", ((tick / end) * 1000).toFixed(1));
  let current = 0;
  for (let i = 0; i < applied.length; i += 1) if (applied[i] <= tick) current = i;
  if (current !== shown) {
    cards.forEach((card, i) => { card.hidden = i !== current; });
    markers.forEach((one) => one.classList.toggle("now", Number(one.dataset.i) === current));
    chips.forEach((one) => one.classList.toggle("now", Number(one.dataset.i) === current));
    shown = current;
  }
  const seconds = tick / data.tick_hz;
  readout.textContent = "tick " + Math.round(tick) + " · " + seconds.toFixed(1) + " s of " + (end / data.tick_hz).toFixed(1) + " s";
}
function frame(now) {
  if (!playing) { last = null; return; }
  if (last !== null) tick = Math.min(end, tick + ((now - last) / 1000) * data.tick_hz * Number(speed.value));
  last = now;
  draw();
  if (tick >= end) { playing = false; play.textContent = "Play"; last = null; return; }
  requestAnimationFrame(frame);
}
function toggle() {
  if (!playing && tick >= end) tick = 0;
  playing = !playing;
  play.textContent = playing ? "Pause" : "Play";
  if (playing) requestAnimationFrame(frame);
}
play.addEventListener("click", toggle);
document.addEventListener("keydown", (event) => {
  if (event.code === "Space" && event.target === document.body) { event.preventDefault(); toggle(); }
});
document.getElementById("timeline").addEventListener("click", (event) => {
  const box = event.currentTarget.getBoundingClientRect();
  const x = ((event.clientX - box.left) / box.width) * 1024 - 12;
  tick = Math.max(0, Math.min(end, (x / 1000) * end));
  draw();
});
chips.forEach((one) => one.addEventListener("click", (event) => {
  event.stopPropagation();
  tick = applied[Number(one.dataset.i)];
  draw();
}));
draw();
`;

function style() {
  return `:root { color-scheme: dark; }
body { margin: 0; background: ${PAGE.background}; color: ${PAGE.text}; font: 15px/1.45 system-ui, sans-serif; }
main { max-width: 1180px; margin: 0 auto; padding: 20px; }
h1 { font-size: 20px; margin: 0 0 4px; color: ${PAGE.bright}; }
.sub { color: ${PAGE.soft}; margin: 0 0 12px; }
.label { display: inline-block; padding: 2px 10px; border-radius: 4px; font-weight: 700; margin-left: 8px; background: var(--c); color: ${PAGE.deep}; }
.grid { display: grid; grid-template-columns: minmax(0, 3fr) minmax(260px, 2fr); gap: 16px; }
@media (max-width: 760px) { .grid { grid-template-columns: 1fr; } }
#map { width: 100%; aspect-ratio: 1; background: ${PAGE.deep}; border: 1px solid ${PAGE.rule}; border-radius: 6px; }
.dm.now { stroke: ${PAGE.bright}; }
.tc { cursor: pointer; }
.tc.now { stroke: ${PAGE.bright}; stroke-width: 2; }
aside { background: ${PAGE.panel}; border: 1px solid ${PAGE.rule}; border-radius: 6px; padding: 12px 14px; }
.controls { display: flex; gap: 10px; align-items: center; margin: 12px 0 6px; flex-wrap: wrap; }
button, select { background: ${PAGE.panel}; color: ${PAGE.bright}; border: 1px solid ${PAGE.muted}; border-radius: 4px; padding: 6px 14px; font: inherit; }
button:focus-visible, select:focus-visible { outline: 2px solid ${PAGE.accent}; outline-offset: 2px; }
#readout { color: ${PAGE.soft}; font-variant-numeric: tabular-nums; }
#timeline { width: 100%; height: 72px; background: ${PAGE.panel}; border: 1px solid ${PAGE.rule}; border-radius: 6px; cursor: crosshair; }
.card h2 { font-size: 17px; margin: 0 0 4px; color: ${PAGE.bright}; }
.facts { color: ${PAGE.soft}; margin: 0 0 10px; font-size: 13px; }
.source { font-size: 11px; font-weight: 700; letter-spacing: 0.06em; color: var(--c); border: 1px solid var(--c); border-radius: 3px; padding: 1px 5px; vertical-align: middle; }
.swatch { color: var(--c); display: inline-block; width: 1.2em; text-align: center; }
.bar { display: grid; grid-template-columns: 1.4em 9.5em 1fr 4em; align-items: center; gap: 6px; margin: 3px 0; color: ${PAGE.soft}; }
.bar.chosen { color: ${PAGE.bright}; font-weight: 600; }
.name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 13px; }
.track { height: 10px; background: ${PAGE.deep}; border-radius: 5px; overflow: hidden; }
.fill { display: block; height: 100%; background: var(--c); }
.value { text-align: right; font-variant-numeric: tabular-nums; font-size: 13px; }
ul.legend { list-style: none; padding: 0; margin: 12px 0 0; display: flex; flex-wrap: wrap; gap: 4px 14px; color: ${PAGE.soft}; font-size: 13px; }
footer { color: ${PAGE.soft}; font-size: 12px; margin-top: 14px; }`;
}

export function renderReplay(data) {
  const scriptHash = createHash("sha256").update(SCRIPT).digest("base64");
  const csp = `${REPLAY_CSP_BASE} 'sha256-${scriptHash}'`;
  const badge =
    data.label === null
      ? ""
      : `<span class="label" style="--c: ${data.demo ? WATCH.demo.hex : WATCH.watch.hex}">${esc(data.label)}</span>`;
  const payload = JSON.stringify({
    trace: data.trace,
    decisions: data.decisions.map(({ apply_tick, tick }) => ({
      apply_tick,
      tick,
    })),
    end_tick: data.end_tick,
    tick_hz: data.tick_hz,
  }).replaceAll("<", "\\u003c");
  const options = SPEEDS.map(
    (value) =>
      `<option value="${value}"${value === 1 ? " selected" : ""}>${value}×</option>`,
  ).join("");
  const title = `${data.scenario ?? "trial"} · ${data.arm ?? "?"} arm`;
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="${csp}">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Replay · ${esc(title)}</title>
<style>${style()}</style>
</head>
<body>
<main>
<h1>Replay · ${esc(title)}${badge}</h1>
<p class="sub">${esc(
    [
      data.mode,
      `seed ${data.seed}`,
      `trial ${data.trial}`,
      `${data.outcome} at tick ${data.end_tick}`,
      data.abort === null ? null : `${data.abort.cause}: ${data.abort.message}`,
      `${data.decisions.length} decisions`,
      data.trace_hash === null ? null : `trace ${data.trace_hash.slice(0, 12)}`,
      data.run_id,
    ]
      .filter((part) => part !== null && part !== undefined)
      .join(" · "),
  )}</p>
<div class="grid">
<div>${mapSvg(data)}</div>
<aside>${data.decisions.map(cardFor).join("")}<ul class="legend">${legend(data)}</ul></aside>
</div>
<div class="controls"><button id="play" type="button">Play</button><label>Speed <select id="speed">${options}</select></label><span id="readout"></span></div>
${timelineSvg(data)}
<footer>Top-down, x across and z down, from events.ndjson's 10 Hz trace. Chips on the timeline are decisions at the tick they applied; click one, or the bar, to jump. Space plays and pauses. Automated play; not a feel verdict.</footer>
</main>
<script type="application/json" id="data">${payload}</script>
<script>${SCRIPT}</script>
</body>
</html>
`;
}

export async function buildReplay(target, options = {}) {
  const data = await replayData(target, options);
  return { data, html: renderReplay(data) };
}

export async function writeReplay(target, { out, trial } = {}) {
  const { html, data } = await buildReplay(target, { trial });
  const file =
    out ??
    path.join(
      data.source.run ?? path.dirname(data.source.io),
      `replay-${data.trial}.html`,
    );
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, html);
  return file;
}

async function main(argv) {
  let parsed;
  try {
    parsed = parseArgs({
      args: argv,
      allowPositionals: true,
      options: { trial: { type: "string" }, out: { type: "string" } },
    });
  } catch (error) {
    console.error(error.message);
    return EXIT.usage;
  }
  const { values, positionals } = parsed;
  if (positionals.length !== 1) {
    console.error(
      "usage: replay.mjs <run dir | trial io dir> [--trial NNN] [--out file.html]",
    );
    return EXIT.usage;
  }
  try {
    const file = await writeReplay(positionals[0], {
      trial: values.trial,
      out: values.out === undefined ? undefined : path.resolve(values.out),
    });
    console.log(`replay page: ${file}`);
    return EXIT.pass;
  } catch (error) {
    console.error(error.message);
    return EXIT.usage;
  }
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = await main(process.argv.slice(2));
}
