import { existsSync, readdirSync, readFileSync, statSync, writeFileSync, mkdirSync } from "node:fs";
import path from "node:path";

const opts = {};
for (const a of process.argv.slice(2)) {
  const m = /^--([a-z]+)=(.*)$/.exec(a);
  if (m) opts[m[1]] = m[2];
}
if (!opts.pace || !opts.out) {
  console.error("usage: --pace=<dir> --out=<dir>");
  process.exit(2);
}

const walk = (dir) =>
  readdirSync(dir).flatMap((f) => {
    const p = path.join(dir, f);
    return statSync(p).isDirectory() ? walk(p) : [p];
  });
const runs = walk(opts.pace)
  .filter((f) => /pace-\d+\.ndjson$/.test(path.basename(f)))
  .sort()
  .map((f) => {
    const rows = readFileSync(f, "utf8")
      .trim()
      .split("\n")
      .map((l) => JSON.parse(l));
    const bots = path.join(path.dirname(f), "bots.ndjson");
    const pilot = existsSync(bots)
      ? String(JSON.parse(readFileSync(bots, "utf8").trim().split("\n")[0]).class || "")
      : "";
    return {
      seed: Number(/pace-(\d+)/.exec(f)[1]),
      pilot,
      seconds: rows.filter((r) => r.kind === "second"),
      lessons: rows.filter((r) => r.kind === "lesson"),
    };
  });

const minutes = Math.max(...runs.map((r) => Math.ceil(r.seconds.at(-1).t / 60)));
const inMinute = (rows, m) => rows.filter((x) => x.t > m * 60 && x.t <= (m + 1) * 60);
const rows = [];
for (let m = 0; m < minutes; m++) {
  const live = runs.filter((r) => inMinute(r.seconds, m).length);
  const mean = (f) => (live.length ? live.reduce((s, r) => s + f(r), 0) / live.length : 0);
  rows.push({
    minute: m,
    new_things: +mean(
      (r) =>
        r.lessons.filter((x) => (m === 0 ? x.t <= 60 : x.t > m * 60 && x.t <= (m + 1) * 60)).length,
    ).toFixed(1),
    damage: +mean((r) => inMinute(r.seconds, m).reduce((s, x) => s + x.damage, 0)).toFixed(1),
    hits: +mean((r) => inMinute(r.seconds, m).reduce((s, x) => s + x.hits, 0)).toFixed(1),
    enemies: +mean((r) => {
      const s = inMinute(r.seconds, m);
      return s.reduce((a, x) => a + x.enemies, 0) / s.length;
    }).toFixed(1),
    runs: live.length,
  });
}
const summary = runs.map((r) => {
  const low = r.seconds.reduce((a, x) => (x.hp < a.hp ? x : a), r.seconds[0]);
  const perMinute = [];
  for (let m = 0; m * 60 < r.seconds.at(-1).t; m++) {
    const s = inMinute(r.seconds, m);
    perMinute.push({
      minute: m,
      stage: s.length ? s.at(-1).stage : 0,
      lessons: r.lessons
        .filter((x) => (m === 0 ? x.t <= 60 : x.t > m * 60 && x.t <= (m + 1) * 60))
        .map((x) => x.id),
      damage: +s.reduce((a, x) => a + x.damage, 0).toFixed(1),
      hp_max: s.length ? s.at(-1).hp_max : 0,
    });
  }
  return {
    seed: r.seed,
    pilot: r.pilot,
    seconds: r.seconds.at(-1).t,
    hp_max_first: r.seconds[0].hp_max,
    hp_max_last: r.seconds.at(-1).hp_max,
    hp_lowest: low.hp,
    hp_lowest_at: low.t,
    hp_max_at_lowest: low.hp_max,
    minutes: perMinute,
    lessons_first_20s: r.lessons.filter((x) => x.t <= 20).map((x) => [x.id, x.t]),
    lessons: r.lessons.map((x) => [x.id, x.t, x.stage]),
  };
});
mkdirSync(opts.out, { recursive: true });
writeFileSync(
  path.join(opts.out, "data.json"),
  JSON.stringify({ rows, runs: summary }, null, 1) + "\n",
);

const W = 720,
  H = 360,
  L = 60,
  R = 20,
  band = (W - L - R) / minutes;
const maxNew = Math.max(1, ...rows.map((r) => r.new_things));
const maxDmg = Math.max(1, ...rows.map((r) => r.damage));
const top = (v) => 150 - (v / maxNew) * 110;
const bot = (v) => 320 - (v / maxDmg) * 110;
const bars = rows
  .map((r, i) => {
    const x = L + i * band + band * 0.15,
      w = band * 0.7;
    return (
      `<rect x="${x.toFixed(1)}" y="${top(r.new_things).toFixed(1)}" width="${w.toFixed(1)}" height="${(150 - top(r.new_things)).toFixed(1)}" fill="#3b7dd8"/>` +
      `<text x="${(x + w / 2).toFixed(1)}" y="${(top(r.new_things) - 4).toFixed(1)}" font-size="11" text-anchor="middle">${r.new_things}</text>` +
      `<rect x="${x.toFixed(1)}" y="${bot(r.damage).toFixed(1)}" width="${w.toFixed(1)}" height="${(320 - bot(r.damage)).toFixed(1)}" fill="#d8573b"/>` +
      `<text x="${(x + w / 2).toFixed(1)}" y="${(bot(r.damage) - 4).toFixed(1)}" font-size="11" text-anchor="middle">${r.damage}</text>` +
      `<text x="${(x + w / 2).toFixed(1)}" y="340" font-size="11" text-anchor="middle">${r.minute}</text>`
    );
  })
  .join("");
const svg =
  `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" font-family="sans-serif">` +
  `<rect width="${W}" height="${H}" fill="#fff"/>` +
  `<text x="${L}" y="22" font-size="13">New things to learn, per game minute (mean of ${runs.length} first-timer bot runs)</text>` +
  `<line x1="${L}" y1="150" x2="${W - R}" y2="150" stroke="#888"/>` +
  `<text x="${L}" y="192" font-size="13">Hull damage taken, per game minute (same runs)</text>` +
  `<line x1="${L}" y1="320" x2="${W - R}" y2="320" stroke="#888"/>` +
  bars +
  `<text x="${W / 2}" y="356" font-size="11" text-anchor="middle">game minute (in play)</text></svg>\n`;
writeFileSync(path.join(opts.out, "chart.svg"), svg);
console.log(JSON.stringify(rows));
