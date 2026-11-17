// Usage: node scripts/challenge/flume-opening.mjs <run folder> [<run folder> ...]
// W1-31: how much of the flume (stage 2) is a rest, from the bot record's stage note: the stage seconds to the first hit,
// and the hit damage taken outside the first 45 s of the Warden fight (stage 2's hp_lost minus the fight's hp_lost_45s).
// Only those first 45 s are subtracted: Warden pulses after them, and any hit after the break, stay in the figure.
// Runs that never reached stage 2 are left out; a run with no hit by then reads as its Warden engagement time.
import fs from "node:fs";
import { realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { med } from "./worst-window.mjs";

const f = (x, d = 1) => (x == null ? "-" : x.toFixed(d));

// rows: runs.ndjson lines. Returns {column: {n, firstHit, noHit, dmgOutside, maxHp, hits}}, one list entry per run.
export function flumeOpening(rows) {
  const out = {};
  for (const column of [...new Set(rows.map((r) => r.column))]) {
    const notes = rows.filter((r) => r.column === column && r.row).map((r) => (r.row.stages ?? []).find((s) => s.stage === 2)).filter(Boolean);
    out[column] = {
      n: notes.length,
      firstHit: notes.map((n) => n.first_hit_s ?? n.warden_engaged_s ?? n.exit_s ?? null),
      noHit: notes.filter((n) => n.first_hit_s == null).length,
      dmgOutside: notes.map((n) => (n.warden_engaged_s != null ? n.hp_lost - (n.hp_lost_45s ?? 0) : n.hp_lost ?? 0)),
      maxHp: notes.map((n) => n.max_hp),
      hits: notes.map((n) => n.hits),
    };
  }
  return out;
}

function main() {
  for (const dir of process.argv.slice(2)) {
    const rows = fs.readFileSync(`${dir}/runs.ndjson`, "utf8").trim().split("\n").map((l) => JSON.parse(l));
    console.log(`# ${dir}`);
    for (const [column, c] of Object.entries(flumeOpening(rows))) {
      console.log(`${column}: n=${c.n} stage-2 first hit median ${f(med(c.firstHit))} s (no hit at all in ${c.noHit}) | hit damage outside the first 45 s of the Warden fight, median ${f(med(c.dmgOutside), 0)} (max hull ${f(med(c.maxHp), 0)}) | hits median ${f(med(c.hits), 0)}`);
    }
  }
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) main();
