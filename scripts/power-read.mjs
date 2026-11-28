import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  realpathSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { resolveGodotBinary } from "./godot-home.mjs";
import { pool, runProcess } from "./lib/proc.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sketch = path.join(root, "sketches/core-loop");

export const PILOTS = [
  { id: "pylon_engineer", name: "Sable" },
  { id: "runner_gunner", name: "Rivet" },
  { id: "demolitions_caster", name: "Kest" },
  { id: "tarn", name: "Tarn" },
  { id: "tally", name: "Tally" },
  { id: "remembered_cannon", name: "Cannon" },
];
export const DEPTHS = [0, 4];
export const TARGETS = { presence: 3, area: 1.5, knock: 2, layers: 2 };
export const CENTRE_LIMIT = 1.25;
const PRESENCE_PARTS = ["energy", "heat", "ink"];
export const SIZE = "960x540";

export class PowerReadError extends Error {}

export function parseArgs(argv) {
  const args = {
    pilots: PILOTS.map((p) => p.id),
    out: null,
    jobs: 2,
    rows: null,
    render: "xvfb",
    gate: false,
  };
  for (const arg of argv) {
    if (arg.startsWith("--pilots=")) {
      args.pilots = arg.slice(9).split(",").filter(Boolean);
      const unknown = args.pilots.filter((id) => !PILOTS.some((p) => p.id === id));
      if (unknown.length) throw new PowerReadError(`unknown pilot: ${unknown.join(", ")}`);
    } else if (arg.startsWith("--out=")) args.out = path.resolve(arg.slice(6));
    else if (arg.startsWith("--rows=")) args.rows = path.resolve(arg.slice(7));
    else if (arg.startsWith("--jobs=")) {
      args.jobs = Number(arg.slice(7));
      if (!Number.isInteger(args.jobs) || args.jobs < 1)
        throw new PowerReadError(`--jobs needs a whole number: ${arg}`);
    } else if (arg === "--native") args.render = "native";
    else if (arg === "--no-render") args.render = "none";
    else if (arg === "--gate") args.gate = true;
    else throw new PowerReadError(`unknown argument: ${arg}`);
  }
  return args;
}

export function command({ binary, pilot, depth, out, render }) {
  const user = ["--", `--pilot=${pilot}`, `--depth=${depth}`, `--out=${out}`];
  const tool = ["--path", sketch, "--fixed-fps", "60", "--script", "res://tools/power_read.gd"];
  if (render === "none")
    return { cmd: binary, argv: ["--headless", ...tool, ...user, "--render=0"] };
  const view = ["--audio-driver", "Dummy", "--resolution", SIZE, ...tool, ...user];
  if (render === "native") return { cmd: binary, argv: view };
  return {
    cmd: "xvfb-run",
    argv: ["-a", "-s", `-screen 0 ${SIZE}x24`, binary, "--rendering-driver", "opengl3", ...view],
  };
}

export function parseRow(stdout) {
  const line = stdout
    .split("\n")
    .reverse()
    .find((l) => l.startsWith("power_read row: "));
  return line ? JSON.parse(line.slice("power_read row: ".length)) : null;
}

const ratio = (grown, first) => (first > 0 ? grown / first : grown > 0 ? Infinity : null);

export const net = (row, k) =>
  row.rendered ? Math.max(0, row[k] - (row[`noise_${k}`] ?? 0)) : null;

function presence(first, grown) {
  const parts = PRESENCE_PARTS.map((k) =>
    first.rendered ? ratio(net(grown, k), net(first, k)) : null,
  );
  if (parts.some((v) => v === null)) return null;
  if (parts.some((v) => v === Infinity)) return Infinity;
  return Math.cbrt(parts[0] * parts[1] * parts[2]);
}

export function summarize(rows, targets = TARGETS) {
  const pilots = [];
  for (const pilot of PILOTS) {
    const first = rows.find((r) => r.pilot === pilot.id && r.depth === 0);
    const grown = rows.find((r) => r.pilot === pilot.id && r.depth === 4);
    if (!first && !grown) continue;
    const entry = {
      id: pilot.id,
      name: pilot.name,
      first,
      grown,
      errors: [first, grown].filter((r) => r?.error).map((r) => r.error),
    };
    if (first && grown && !entry.errors.length) {
      entry.ratios = {
        presence: presence(first, grown),
        area: first.rendered ? ratio(net(grown, "area"), net(first, "area")) : null,
        knock: ratio(grown.knock_m, first.knock_m),
        layers: ratio(grown.sound_layers, first.sound_layers),
      };
      entry.damage = ratio(grown.damage, first.damage);
      entry.parts = Object.fromEntries(
        PRESENCE_PARTS.map((k) => [k, first.rendered ? ratio(net(grown, k), net(first, k)) : null]),
      );
      const centre = first.rendered ? ratio(net(grown, "centre"), net(first, "centre")) : null;
      entry.centre = {
        ratio: centre,
        clear: centre === null ? null : centre <= CENTRE_LIMIT + 1e-9,
      };
      entry.meets = Object.fromEntries(
        Object.entries(entry.ratios).map(([k, v]) => [
          k,
          v === null ? null : v >= targets[k] - 1e-9,
        ]),
      );
    }
    pilots.push(entry);
  }
  const met = (k) => pilots.filter((p) => p.meets?.[k] === true).length;
  const measured = (k) => pilots.filter((p) => p.meets && p.meets[k] !== null).length;
  const damages = pilots.map((p) => p.damage).filter((v) => Number.isFinite(v));
  return {
    targets,
    damage: damages.length ? damages.reduce((a, b) => a + b, 0) / damages.length : null,
    pilots,
    totals: Object.fromEntries(
      Object.keys(targets).map((k) => [k, { met: met(k), measured: measured(k) }]),
    ),
  };
}

const esc = (s) =>
  String(s).replace(
    /[&<>"]/g,
    (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c],
  );
const fx = (v, digits = 1) =>
  v === null || v === undefined ? "n/a" : v === Infinity ? "new" : `${v.toFixed(digits)}x`;

function meter(label, value, target, detail) {
  const scale = Math.max(target * 1.25, value === Infinity || value === null ? 0 : value);
  const fill = value === null ? 0 : value === Infinity ? 100 : Math.min(100, (value / scale) * 100);
  const tick = (target / scale) * 100;
  const state = value === null ? "none" : value >= target - 1e-9 ? "ok" : "short";
  return `<div class="meter ${state}">
  <div class="meter-head"><span class="label">${esc(label)}</span><span class="val">${fx(value)}</span><span class="goal">goal ${target}x</span></div>
  <div class="track" role="img" aria-label="${esc(label)} ${fx(value)} of ${target}x goal"><div class="bar" style="width:${fill.toFixed(1)}%"></div><div class="tick" style="left:${tick.toFixed(1)}%"></div><div class="one" style="left:${((1 / scale) * 100).toFixed(1)}%"></div></div>
  <div class="detail">${esc(detail)}</div>
</div>`;
}

const pct = (v) => (v === null ? "not rendered" : `${(v * 100).toFixed(1)}% of screen`);

export function renderPage(summary, { images = {}, version = "", stamp = "", renderer = "" } = {}) {
  const t = summary.targets;
  const head = [
    ["Presence", "presence", t.presence],
    ["Area", "area", t.area],
    ["Knockback", "knock", t.knock],
    ["Sound", "layers", t.layers],
  ];
  const tiles = head
    .map(([label, k, target]) => {
      const { met, measured } = summary.totals[k];
      return `<div class="tile ${measured && met === measured ? "ok" : "short"}"><span class="tile-n">${met}<small>/${measured}</small></span><span class="tile-l">${label} at ${target}x</span></div>`;
    })
    .join("");
  const cards = summary.pilots
    .map((p) => {
      if (!p.ratios)
        return `<section class="pilot"><h2>${esc(p.name)}</h2><p class="err">Not measured: ${esc(p.errors.join("; ") || "a depth is missing")}</p></section>`;
      const still = (row, depth, caption) => {
        const src = images[`${p.id}-d${depth}`];
        return `<figure>${src ? `<img src="${src}" alt="${esc(p.name)} ${caption} at the hit's biggest frame" loading="lazy">` : `<div class="noimg">no still</div>`}<figcaption><b>${caption}</b> heft ${row.heft.toFixed(1)}, ${row.parts.length} parts, ${row.picks.length} picks</figcaption></figure>`;
      };
      return `<section class="pilot">
<h2>${esc(p.name)}</h2>
<div class="pair">${still(p.first, 0, "First fight")}${still(p.grown, 4, "Grown")}</div>
<div class="meters">
${meter("Presence", p.ratios.presence, t.presence, `strength ${fx(p.parts.energy)}, colour heat ${fx(p.parts.heat)}, edge ink ${fx(p.parts.ink)}`)}
${meter("Area", p.ratios.area, t.area, `${pct(net(p.first, "area"))} to ${pct(net(p.grown, "area"))}`)}
${meter("Knockback", p.ratios.knock, t.knock, `${p.first.knock_m.toFixed(1)} m to ${p.grown.knock_m.toFixed(1)} m`)}
${meter("Sound", p.ratios.layers, t.layers, `${p.first.sound_layers} to ${p.grown.sound_layers} layers: ${p.grown.sounds.join(", ")}`)}
</div>
<p class="small centre ${p.centre.clear === false ? "busy" : ""}">Centre ${p.centre.clear === null ? "not rendered" : p.centre.clear ? "clear" : "busier"}: the grown hit changes ${fx(p.centre.ratio)} as much of the middle of the screen (limit ${CENTRE_LIMIT}x).</p>
${net(p.first, "area") > 0.5 ? `<p class="small">The first-fight hit already changes most of the screen, so its area cannot grow much; presence has to come from heat and ink.</p>` : ""}
<p class="small">Damage ${p.first.damage.toFixed(0)} to ${p.grown.damage.toFixed(0)}. Effects spawned ${p.first.fx_spawned} to ${p.grown.fx_spawned}.</p>
</section>`;
    })
    .join("\n");
  return `<title>Power Read</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@600;800&family=DM+Sans:wght@400;600&family=IBM+Plex+Mono:wght@500&display=swap">
<style>
/* One column of pilot cards; each card is a before/after pair over three goal meters. */
:root {
  --bg: #eef1f4; --panel: #ffffff; --ink: #1b2129; --muted: #5b6673; --line: #d5dbe2;
  --accent: #d9821e; --ok: #2f8a57; --short: #c2452d; --track: #e2e7ec;
  --display: "Barlow Condensed", "Arial Narrow", sans-serif;
  --body: "DM Sans", system-ui, sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #12161b; --panel: #1b2128; --ink: #e8edf2; --muted: #9aa6b3; --line: #2c343e;
  --accent: #f0a043; --ok: #5cc48a; --short: #f07a5f; --track: #2a323b; color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #12161b; --panel: #1b2128; --ink: #e8edf2; --muted: #9aa6b3; --line: #2c343e;
  --accent: #f0a043; --ok: #5cc48a; --short: #f07a5f; --track: #2a323b; color-scheme: dark }
body { background: var(--bg); color: var(--ink); font: 15px/1.5 var(--body); }
main { max-width: 760px; margin: 0 auto; padding-block: 20px 40px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); display: grid; gap: 20px; }
h1 { font: 800 2.6rem/1 var(--display); letter-spacing: .01em; margin: 0; text-transform: uppercase; }
h1 span { color: var(--accent); }
.lede { margin: 6px 0 0; color: var(--muted); max-width: 60ch; }
.tiles { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; }
@media (max-width: 520px) { .tiles { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
.centre.busy { color: var(--short); }
.tile { background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 10px 12px; display: grid; }
.tile-n { font: 800 2rem/1 var(--display); font-variant-numeric: tabular-nums; }
.tile-n small { font-size: 1rem; color: var(--muted); }
.tile.ok .tile-n { color: var(--ok); } .tile.short .tile-n { color: var(--short); }
.tile-l { font-size: .8rem; color: var(--muted); text-transform: uppercase; letter-spacing: .06em; }
.pilot { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 14px; display: grid; gap: 12px; min-width: 0; }
.pilot h2 { font: 800 1.7rem/1 var(--display); margin: 0; text-transform: uppercase; letter-spacing: .02em; }
.pair { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
@media (max-width: 520px) { .pair { grid-template-columns: 1fr; } }
figure { margin: 0; display: grid; gap: 4px; min-width: 0; }
figure img, .noimg { width: 100%; aspect-ratio: 16 / 9; border-radius: 6px; object-fit: cover; background: var(--track); display: grid; place-items: center; color: var(--muted); }
figcaption { font-size: .8rem; color: var(--muted); }
figcaption b { color: var(--ink); }
.meters { display: grid; gap: 10px; }
.meter-head { display: flex; align-items: baseline; gap: 8px; }
.label { font: 600 1.05rem var(--display); text-transform: uppercase; letter-spacing: .05em; }
.val { font: 500 1rem var(--mono); font-variant-numeric: tabular-nums; }
.meter.ok .val { color: var(--ok); } .meter.short .val { color: var(--short); }
.goal { margin-left: auto; font: 500 .8rem var(--mono); color: var(--muted); }
.track { position: relative; height: 12px; background: var(--track); border-radius: 6px; overflow: hidden; }
.bar { position: absolute; inset: 0 auto 0 0; background: var(--short); border-radius: 6px; }
.meter.ok .bar { background: var(--ok); }
.tick { position: absolute; top: 0; bottom: 0; width: 3px; margin-left: -1px; background: var(--accent); }
.one { position: absolute; top: 3px; bottom: 3px; width: 1px; background: var(--muted); opacity: .6; }
.detail, .small { font-size: .82rem; color: var(--muted); margin: 0; }
.finding { margin: 10px 0 0; font-weight: 600; border-left: 3px solid var(--accent); padding-left: 10px; max-width: 60ch; }
.err { color: var(--short); margin: 0; }
footer { font-size: .78rem; color: var(--muted); display: grid; gap: 4px; }
</style>
<main>
<header>
<h1>Power <span>Read</span></h1>
<p class="lede">The same slam on the same enemy, first fight against a grown build (four picks, four parts, heft class IV). Goals from your cards: ${t.presence}x the presence (strength, colour heat, edge ink) with the centre kept clear, at least ${t.area}x the area, ${t.knock}x the knockback and ${t.layers}x the sound. The orange tick is the goal; the grey line is no change.</p>
${summary.damage ? `<p class="finding">Grown builds deal ${fx(summary.damage)} the damage on average. The meters show how much of that the player can see, feel and hear.</p>` : ""}
</header>
<div class="tiles">${tiles}</div>
${cards}
<footer>
<span>Pilots meeting each goal. Pixel readings are peaks over the hit's first 0.25 s with combat warnings hidden, minus what the scene changes on its own with no hit. Presence is the geometric mean of strength (how far pixels change), colour heat and edge ink (changed pixels that end dark).</span>
<span>Measured ${esc(stamp)} on ${esc(version)}${renderer ? `, ${esc(renderer)}` : ""}. Software rendering in the cloud draws the game's GL fallback, not the Vulkan look; ratios compare like with like.</span>
</footer>
</main>
`;
}

function gitVersion() {
  const r = spawnSync("git", ["rev-parse", "--short", "HEAD"], { cwd: root, encoding: "utf8" });
  return r.status === 0 ? r.stdout.trim() : "unknown";
}

async function runOne(spec) {
  const res = await runProcess(spec.cmd, spec.argv, { cwd: root, timeoutMs: 15 * 60 * 1000 });
  return (
    parseRow(res.output) ?? {
      error: `no row (exit ${res.exit}): ${res.output
        .split("\n")
        .filter((l) => /ERROR/.test(l))
        .slice(0, 3)
        .join(" | ")}`,
    }
  );
}

function readRows(dir) {
  return readdirSync(dir)
    .filter((f) => /-d\d+\.json$/.test(f))
    .map((f) => JSON.parse(readFileSync(path.join(dir, f), "utf8")));
}

export async function main(argv = process.argv.slice(2)) {
  const args = parseArgs(argv);
  const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  const out = args.out ?? args.rows ?? path.join(root, "artifacts/local/power-read", stamp);
  mkdirSync(out, { recursive: true });
  let rows;
  if (args.rows) rows = readRows(args.rows);
  else {
    const binary = resolveGodotBinary();
    if (!binary || !existsSync(binary))
      throw new PowerReadError(
        `Godot binary not found${binary ? ` at ${binary}` : ""}; set GODOT_BIN`,
      );
    let render = args.render;
    if (render === "xvfb" && spawnSync("sh", ["-c", "command -v xvfb-run"]).status !== 0) {
      console.error(
        "power-read: xvfb-run not found, reading without pixels (use --native for this display)",
      );
      render = "none";
    }
    const tasks = args.pilots.flatMap((pilot) =>
      DEPTHS.map((depth) => async () => {
        const row = await runOne(command({ binary, pilot, depth, out, render }));
        console.log(
          `power-read: ${pilot} depth ${depth} ${row.error ? `FAILED ${row.error}` : "ok"}`,
        );
        return { pilot, depth, ...row };
      }),
    );
    rows = await pool(tasks, args.jobs);
  }
  const summary = summarize(rows);
  const images = {};
  for (const row of rows) {
    const file = path.join(out, `${row.pilot}-d${row.depth}-peak.png`);
    if (existsSync(file))
      images[`${row.pilot}-d${row.depth}`] =
        `data:image/png;base64,${readFileSync(file).toString("base64")}`;
  }
  const renderer = rows.find((r) => r.renderer)?.renderer ?? "";
  writeFileSync(
    path.join(out, "report.json"),
    JSON.stringify({ stamp, version: gitVersion(), renderer, ...summary }, null, 2),
  );
  writeFileSync(
    path.join(out, "page.html"),
    renderPage(summary, { images, version: gitVersion(), stamp, renderer }),
  );
  for (const p of summary.pilots) {
    if (!p.ratios) console.log(`${p.name.padEnd(7)} not measured`);
    else
      console.log(
        `${p.name.padEnd(7)} presence ${fx(p.ratios.presence)}  area ${fx(p.ratios.area)}  centre ${fx(p.centre.ratio)}  knock ${fx(p.ratios.knock)}  sound ${fx(p.ratios.layers)}`,
      );
  }
  console.log(`power-read: ${out}/page.html`);
  const failed = rows.some((r) => r.error);
  const missed = summary.pilots.some(
    (p) => p.meets && Object.values(p.meets).some((v) => v === false),
  );
  return failed ? 2 : args.gate && missed ? 1 : 0;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().then(
    (code) => process.exit(code),
    (error) => {
      console.error(error instanceof PowerReadError ? `power-read: ${error.message}` : error);
      process.exit(2);
    },
  );
}
