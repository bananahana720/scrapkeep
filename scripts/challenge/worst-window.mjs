import fs from "node:fs";
import { isMain } from "../lib/cli.mjs";

export const med = (xs) => {
  const s = xs.filter((x) => x != null).sort((a, b) => a - b);
  return s.length ? s[Math.floor((s.length - 1) / 2)] : null;
};
const mean = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
const pct = (x) => (x == null ? "-" : (100 * x).toFixed(0) + "%");

export function fightMaxHp(note, row) {
  if (note.worst_60s_max_hp != null) return { maxHp: note.worst_60s_max_hp, from: "window" };
  if (note.max_hp != null) return { maxHp: note.max_hp, from: "entry" };
  return { maxHp: row.max_hp ?? 120, from: "run_end" };
}

export function fightNotes(row) {
  const stage = (n) => (row?.stages ?? []).find((s) => s.stage === n);
  const fought = (n) => (n?.warden_engaged_s != null ? n : null);
  return { dam: fought(stage(1)), flume: fought(stage(2)), brindle: row?.boss ?? null };
}

export function worstWindows(rows) {
  const out = {};
  for (const column of [...new Set(rows.map((r) => r.column))]) {
    const fights = { dam: [], flume: [], brindle: [] };
    for (const r of rows.filter((x) => x.column === column && x.row)) {
      for (const [key, n] of Object.entries(fightNotes(r.row))) {
        if (!n) continue;
        const { maxHp, from } = fightMaxHp(n, r.row);
        fights[key].push({
          hull: (n.worst_60s_hull ?? 0) / maxHp,
          hp: (n.worst_60s_hp ?? 0) / maxHp,
          from,
        });
      }
    }
    out[column] = fights;
  }
  return out;
}

function main() {
  for (const dir of process.argv.slice(2)) {
    const rows = fs
      .readFileSync(`${dir}/runs.ndjson`, "utf8")
      .trim()
      .split("\n")
      .map((l) => JSON.parse(l));
    console.log(`# ${dir}`);
    for (const [column, fights] of Object.entries(worstWindows(rows))) {
      for (const [key, list] of Object.entries(fights)) {
        const h = list.map((x) => x.hull);
        const w = list.map((x) => x.hp);
        const counts = {};
        for (const x of list) counts[x.from] = (counts[x.from] ?? 0) + 1;
        const from = Object.entries(counts)
          .map(([k, v]) => `${k} ${v}`)
          .join(", ");
        console.log(
          `${column} ${key}: n=${list.length} worst-60s hull median ${pct(med(h))} mean ${pct(mean(h))} | hit damage median ${pct(med(w))} mean ${pct(mean(w))} | max hull from ${from || "-"}`,
        );
      }
    }
  }
}

if (isMain(import.meta.url)) main();
