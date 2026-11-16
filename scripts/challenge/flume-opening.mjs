// Usage: node scripts/challenge/flume-opening.mjs <run folder> [<run folder> ...]
// W1-31: how much of the flume (stage 2) is a rest, from the bot record's stage note: the stage seconds to the first hit,
// and the hit damage taken before the Warden is engaged (stage 2's hp_lost minus the fight's, so the Warden's own pulses
// stay out). Runs that never reached stage 2 are left out; a run with no hit by then reads as its Warden engagement time.
import fs from "node:fs";

const med = (xs) => {
  const s = xs.filter((x) => x != null).sort((a, b) => a - b);
  return s.length ? s[Math.floor((s.length - 1) / 2)] : null;
};
const f = (x, d = 1) => (x == null ? "-" : x.toFixed(d));

for (const dir of process.argv.slice(2)) {
  const rows = fs.readFileSync(`${dir}/runs.ndjson`, "utf8").trim().split("\n").map((l) => JSON.parse(l));
  console.log(`# ${dir}`);
  for (const column of [...new Set(rows.map((r) => r.column))]) {
    const notes = rows.filter((r) => r.column === column && r.row).map((r) => (r.row.stages ?? []).find((s) => s.stage === 2)).filter(Boolean);
    const firstHit = notes.map((n) => n.first_hit_s ?? n.warden_engaged_s ?? n.exit_s ?? null);
    const noHit = notes.filter((n) => n.first_hit_s == null).length;
    const dmgBefore = notes.map((n) => (n.warden_engaged_s != null ? n.hp_lost - (n.hp_lost_45s ?? 0) : n.hp_lost ?? 0));
    console.log(`${column}: n=${notes.length} stage-2 first hit median ${f(med(firstHit))} s (no hit at all in ${noHit}) | hit damage outside the first 45 s of the Warden fight, median ${f(med(dmgBefore), 0)} (max hull ${f(med(notes.map((n) => n.max_hp)), 0)}) | hits median ${f(med(notes.map((n) => n.hits)), 0)}`);
  }
}
