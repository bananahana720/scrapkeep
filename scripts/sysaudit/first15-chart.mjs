// Systems audit pass E (docs/systems-audit/first-15/): a chart of how hard each minute of world 1 is
// beside how many new things it asks a first-timer to learn.
//
//   node scripts/sysaudit/first15-chart.mjs --probes=<dir of probe-*.json> --pace=<dir> --out=<dir>
//
// --probes: scripts/first-timer.mjs output (one probe per pilot, park table). A "new thing" is the
// first tick of each lesson the screen showed (a key prompt, a first-meet tip or an objective row);
// pilot cards shown before play are left out. First needs (tools/first_timer.gd NEEDS) are listed
// beside them in data.json but not counted. Counted per game minute,
// median over the pilots. --pace: tools/sysaudit/first15_pace.gd rows (pace-<seed>.ndjson, any depth),
// damage taken and live enemies per game minute, mean over the runs. Writes data.json and chart.svg.
import { readdirSync, readFileSync, statSync, writeFileSync, mkdirSync } from "node:fs";
import path from "node:path";

const opts = {};
for (const a of process.argv.slice(2)) {
  const m = /^--([a-z]+)=(.*)$/.exec(a);
  if (m) opts[m[1]] = m[2];
}
if (!opts.probes || !opts.pace || !opts.out) {
  console.error("usage: --probes=<dir> --pace=<dir> --out=<dir>");
  process.exit(2);
}

const walk = (dir) => readdirSync(dir).flatMap((f) => {
  const p = path.join(dir, f);
  return statSync(p).isDirectory() ? walk(p) : [p];
});
const median = (xs) => {
  const s = [...xs].sort((a, b) => a - b);
  return s.length ? (s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2) : 0;
};

const probes = walk(opts.probes).filter((f) => /probe-.*\.json$/.test(path.basename(f))).map((f) => JSON.parse(readFileSync(f, "utf8")));
const paces = walk(opts.pace).filter((f) => /pace-\d+\.ndjson$/.test(path.basename(f)))
  .map((f) => readFileSync(f, "utf8").trim().split("\n").map((l) => JSON.parse(l)));

const minutes = Math.max(
  ...probes.map((p) => Math.ceil(p.ticks / p.tick_hz / 60)),
  ...paces.map((rows) => Math.ceil(rows.at(-1).t / 60)),
);

const perPilot = probes.map((p) => {
  const counts = Array(minutes).fill(0);
  const items = Array.from({ length: minutes }, () => []);
  const firsts = Object.entries(p.taught).filter(([k, v]) => v.tick >= 0 && !k.startsWith("card:")).map(([k, v]) => [k, v.tick]);
  const needs = Object.entries(p.needed).map(([k, v]) => [k, +(v.tick / p.tick_hz).toFixed(1)]).sort((a, b) => a[1] - b[1]);
  for (const [k, tick] of firsts) {
    const m = Math.min(minutes - 1, Math.floor(tick / p.tick_hz / 60));
    counts[m] += 1;
    items[m].push(k);
  }
  const first10 = firsts.filter(([, t]) => t / p.tick_hz < 10).map(([k, t]) => [k, +(t / p.tick_hz).toFixed(1)]).sort((a, b) => a[1] - b[1]);
  return { pilot: p.pilot, counts, items, first10, needs };
});

const rows = [];
for (let m = 0; m < minutes; m++) {
  const pace = paces.map((r) => r.filter((x) => x.t > m * 60 && x.t <= (m + 1) * 60)).filter((r) => r.length);
  const mean = (f) => (pace.length ? pace.reduce((s, r) => s + f(r), 0) / pace.length : 0);
  rows.push({
    minute: m,
    new_things: median(perPilot.map((p) => p.counts[m])),
    damage: +mean((r) => r.reduce((s, x) => s + x.damage, 0)).toFixed(1),
    hits: +mean((r) => r.reduce((s, x) => s + x.hits, 0)).toFixed(1),
    enemies: +mean((r) => r.reduce((s, x) => s + x.enemies, 0) / r.length).toFixed(1),
    runs: pace.length,
  });
}
mkdirSync(opts.out, { recursive: true });
writeFileSync(path.join(opts.out, "data.json"), JSON.stringify({ rows, pilots: perPilot }, null, 1) + "\n");

// Two bar rows sharing one minute axis: new things on top, damage taken below.
const W = 720, H = 360, L = 60, R = 20, band = (W - L - R) / minutes;
const maxNew = Math.max(1, ...rows.map((r) => r.new_things));
const maxDmg = Math.max(1, ...rows.map((r) => r.damage));
const top = (v) => 150 - (v / maxNew) * 110;
const bot = (v) => 320 - (v / maxDmg) * 110;
const bars = rows.map((r, i) => {
  const x = L + i * band + band * 0.15, w = band * 0.7;
  return `<rect x="${x.toFixed(1)}" y="${top(r.new_things).toFixed(1)}" width="${w.toFixed(1)}" height="${(150 - top(r.new_things)).toFixed(1)}" fill="#3b7dd8"/>` +
    `<text x="${(x + w / 2).toFixed(1)}" y="${(top(r.new_things) - 4).toFixed(1)}" font-size="11" text-anchor="middle">${r.new_things}</text>` +
    `<rect x="${x.toFixed(1)}" y="${bot(r.damage).toFixed(1)}" width="${w.toFixed(1)}" height="${(320 - bot(r.damage)).toFixed(1)}" fill="#d8573b"/>` +
    `<text x="${(x + w / 2).toFixed(1)}" y="${(bot(r.damage) - 4).toFixed(1)}" font-size="11" text-anchor="middle">${Math.round(r.damage)}</text>` +
    `<text x="${(x + w / 2).toFixed(1)}" y="340" font-size="11" text-anchor="middle">${r.minute}</text>`;
}).join("");
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" font-family="sans-serif">` +
  `<rect width="${W}" height="${H}" fill="#fff"/>` +
  `<text x="${L}" y="22" font-size="13">New things to learn, per game minute (median of ${perPilot.length} pilots)</text>` +
  `<line x1="${L}" y1="150" x2="${W - R}" y2="150" stroke="#888"/>` +
  `<text x="${L}" y="192" font-size="13">Hull damage taken, per game minute (mean of ${paces.length} first-timer bot runs)</text>` +
  `<line x1="${L}" y1="320" x2="${W - R}" y2="320" stroke="#888"/>` +
  bars + `<text x="${W / 2}" y="356" font-size="11" text-anchor="middle">game minute</text></svg>\n`;
writeFileSync(path.join(opts.out, "chart.svg"), svg);
console.log(JSON.stringify(rows));
