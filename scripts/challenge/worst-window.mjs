// Usage: node scripts/challenge/worst-window.mjs <run folder> [<run folder> ...]
// W1-31: the worst 60 s of damage in each fight of a w1clear read, as a share of max hull, from the bot record's
// worst_60s_hull and worst_60s_hp (tools/bot_driver.gd). A fight a run never reached is left out, so n is the runs
// that fought it. The dam is stage 1's Warden fight, the flume stage 2's, Brindle the boss note.
import fs from "node:fs";

const med = (xs) => {
  const s = xs.filter((x) => x != null).sort((a, b) => a - b);
  return s.length ? s[Math.floor((s.length - 1) / 2)] : null;
};
const mean = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
const pct = (x) => (x == null ? "-" : (100 * x).toFixed(0) + "%");

for (const dir of process.argv.slice(2)) {
  const rows = fs.readFileSync(`${dir}/runs.ndjson`, "utf8").trim().split("\n").map((l) => JSON.parse(l));
  console.log(`# ${dir}`);
  const columns = [...new Set(rows.map((r) => r.column))];
  for (const column of columns) {
    const mine = rows.filter((r) => r.column === column && r.row);
    const fights = { dam: [], flume: [], brindle: [] };
    for (const r of mine) {
      const maxHp = r.row.max_hp ?? 120;
      const note = (n) => (r.row.stages ?? []).find((s) => s.stage === n);
      const add = (key, n, engaged) => {
        if (n && engaged) fights[key].push({ hull: (n.worst_60s_hull ?? 0) / maxHp, hp: (n.worst_60s_hp ?? 0) / maxHp });
      };
      add("dam", note(1), note(1)?.warden_engaged_s != null);
      add("flume", note(2), note(2)?.warden_engaged_s != null);
      add("brindle", r.row.boss, r.row.boss != null);
    }
    for (const [key, list] of Object.entries(fights)) {
      const h = list.map((x) => x.hull);
      const w = list.map((x) => x.hp);
      console.log(`${column} ${key}: n=${list.length} worst-60s hull median ${pct(med(h))} mean ${pct(mean(h))} | hit damage median ${pct(med(w))} mean ${pct(mean(w))}`);
    }
  }
}
