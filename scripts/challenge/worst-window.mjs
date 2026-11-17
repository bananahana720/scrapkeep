// Usage: node scripts/challenge/worst-window.mjs <run folder> [<run folder> ...]
// W1-31: the worst 60 s of damage in each fight of a w1clear read, as a share of max hull, from the bot record's
// worst_60s_hull and worst_60s_hp (tools/bot_driver.gd). A fight a run never reached is left out, so n is the runs
// that fought it. The dam is stage 1's Warden fight, the flume stage 2's, Brindle the boss note.
// The share divides by the max hull at that fight, not at the end of the run (max hull grows during a run): the
// note's worst_60s_max_hp (max hull when the worst window peaked), else the stage note's max_hp (max hull at stage
// entry; a boss note from before worst_60s_max_hp has none), else the run's end max_hp.
import fs from "node:fs";
import { realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";

export const med = (xs) => {
  const s = xs.filter((x) => x != null).sort((a, b) => a - b);
  return s.length ? s[Math.floor((s.length - 1) / 2)] : null;
};
const mean = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
const pct = (x) => (x == null ? "-" : (100 * x).toFixed(0) + "%");

// The max hull a fight's shares divide by, and which field gave it.
export function fightMaxHp(note, row) {
  if (note.worst_60s_max_hp != null) return { maxHp: note.worst_60s_max_hp, from: "window" };
  if (note.max_hp != null) return { maxHp: note.max_hp, from: "entry" };
  return { maxHp: row.max_hp ?? 120, from: "run_end" };
}

// rows: runs.ndjson lines. Returns {column: {dam|flume|brindle: [{hull, hp, from}]}}.
export function worstWindows(rows) {
  const out = {};
  for (const column of [...new Set(rows.map((r) => r.column))]) {
    const fights = { dam: [], flume: [], brindle: [] };
    for (const r of rows.filter((x) => x.column === column && x.row)) {
      const note = (n) => (r.row.stages ?? []).find((s) => s.stage === n);
      const add = (key, n, engaged) => {
        if (!n || !engaged) return;
        const { maxHp, from } = fightMaxHp(n, r.row);
        fights[key].push({ hull: (n.worst_60s_hull ?? 0) / maxHp, hp: (n.worst_60s_hp ?? 0) / maxHp, from });
      };
      add("dam", note(1), note(1)?.warden_engaged_s != null);
      add("flume", note(2), note(2)?.warden_engaged_s != null);
      add("brindle", r.row.boss, r.row.boss != null);
    }
    out[column] = fights;
  }
  return out;
}

function main() {
  for (const dir of process.argv.slice(2)) {
    const rows = fs.readFileSync(`${dir}/runs.ndjson`, "utf8").trim().split("\n").map((l) => JSON.parse(l));
    console.log(`# ${dir}`);
    for (const [column, fights] of Object.entries(worstWindows(rows))) {
      for (const [key, list] of Object.entries(fights)) {
        const h = list.map((x) => x.hull);
        const w = list.map((x) => x.hp);
        const counts = {};
        for (const x of list) counts[x.from] = (counts[x.from] ?? 0) + 1;
        const from = Object.entries(counts).map(([k, v]) => `${k} ${v}`).join(", ");
        console.log(`${column} ${key}: n=${list.length} worst-60s hull median ${pct(med(h))} mean ${pct(mean(h))} | hit damage median ${pct(med(w))} mean ${pct(mean(w))} | max hull from ${from || "-"}`);
      }
    }
  }
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) main();
