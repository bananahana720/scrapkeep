// The red team's pure half: which runs a wave gets, and how what they left behind becomes a
// ranked findings page. scripts/redteam/run.mjs does the running; nothing here starts Godot.
// Severities and areas are the alpha bug bar's (sketches/core-loop/BUG-BAR.md).

export const PILOTS = ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"];

// A persona is a bot policy played for a reason. stages caps the run (null plays to the end).
export const PERSONAS = [
  { id: "speedrunner", policy: "skipper", stages: null, args: [], hunts: "stalls, softlocks and route skips on the fastest line" },
  { id: "first-timer", policy: "random", stages: null, args: [], hunts: "getting lost, crowd deaths and odd choices" },
  { id: "cautious", policy: "camper", stages: 3, args: [], hunts: "stalls after a Warden breaks, from a player who never closes in" },
  { id: "greedy", policy: "completionist", stages: null, args: ["--late-offer=take"], hunts: "degenerate builds and long-run stability" },
  // The traversal pilot rides from the drop to the beacon and never fights, so it gets one stage,
  // picked by the seed, for 90 s of game time; it is there to find spots the ball gets stuck.
  { id: "line-rider", policy: "traversal", stages: null, route: true, args: [], hunts: "spots the ball gets stuck on the way to the Warden" },
];

export const SEVERITIES = ["blocker", "major", "minor", "watch"];
export const AREAS = [
  "stability", "Wardens and bosses", "core feel", "clarity", "difficulty and pacing", "stage and world design",
  "in-run growth", "pilots", "look", "sound and music", "progression across runs",
];

export const TICKS_PER_SECOND = 90;
export const HITCH_MS = 33;
export const CPU_P99_MS = 10;
export const PILE_WINDOW_TICKS = 90;
export const PILE_SHARE = 0.35;
export const PILE_DEATH_TICKS = 270;
export const LOST_FIND_S = 90;
export const ONE_SHOT_S = 2;
export const PARK_STAGES = 6;
export const ROUTE_TICKS = 90 * TICKS_PER_SECOND;
export const STUCK_DETOURS = 3;
const SETTLE_TICKS = 90;
const SAME_MOMENT_TICKS = 2;

// Seeds no gate uses: wave w owns 1000 + 100w .. 1000 + 100w + 99, so no two waves share one.
export function waveSeed(wave, index) {
  return 1000 + wave * 100 + index;
}

// A sweep (--sweep) is a wider pass on spare compute: its own block, 20000 + 1000w up, past every wave block.
export function sweepSeed(wave, index) {
  return 20000 + wave * 1000 + index;
}

// The persona x pilot grid has 30 cells. k % 5 and k % 6 walk every cell once in 30 steps, so
// consecutive waves take the next `count` cells and the whole grid turns over every 30/count waves.
// A head pass (`persona`) plays one persona on all six pilots, on seeds 60 + 6 x its index up in the
// wave's block, so every head of a wave replays the same runs and a new stall is the head's change.
export function planWave({ wave, count = 10, quick = false, carry = [], seed = waveSeed, persona = null }) {
  if (!Number.isInteger(wave) || wave < 0 || wave > 89) throw new Error("--wave must be an integer from 0 to 89");
  const jobs = [];
  if (persona) {
    const at = PERSONAS.findIndex((p) => p.id === persona);
    if (at < 0) throw new Error("--persona must be one of " + PERSONAS.map((p) => p.id).join(", "));
    PILOTS.forEach((pilot, i) => jobs.push(botJob(PERSONAS[at], pilot, seed(wave, 60 + 6 * at + i), quick)));
  }
  for (let i = 0; i < (persona ? 0 : count); i++) {
    const k = (wave * count + i) % (PERSONAS.length * PILOTS.length);
    const persona = PERSONAS[k % PERSONAS.length];
    jobs.push(botJob(persona, PILOTS[k % PILOTS.length], seed(wave, i), quick));
  }
  for (const [i, c] of carry.entries()) {
    const persona = PERSONAS.find((p) => p.id === c.persona);
    if (!persona || !PILOTS.includes(c.pilot)) continue;
    const job = botJob(persona, c.pilot, c.seed, quick);
    job.id = "carry-" + i + "-" + job.id;
    job.carry = c.title;
    jobs.push(job);
  }
  return jobs;
}

function botJob(persona, pilot, seed, quick) {
  if (persona.route) {
    const stage = 1 + (seed % PARK_STAGES);
    return {
      id: `${persona.id}-${pilot}-${seed}`, kind: "bot", persona: persona.id, policy: persona.policy, pilot, seed, stages: stage,
      args: ["--from-stage=" + stage, "--ticks=" + (quick ? ROUTE_TICKS / 3 : ROUTE_TICKS)],
    };
  }
  const stages = quick ? 1 : persona.stages;
  return {
    id: `${persona.id}-${pilot}-${seed}`, kind: "bot", persona: persona.id, policy: persona.policy, pilot, seed, stages,
    args: [...persona.args, ...(stages ? ["--stages=" + stages] : [])],
  };
}

// A headless run has no sound device, so the game leaves its worker-thread audio warm-ups off and renders
// each radio line and chord on the main thread the first time a bar asks: 70 to 130 ms a tick that a played
// game never has (wave 36, PF-33). --warm-band=1 does what a played game does, and the seed replays the same.
export const PLAYED_AUDIO = "--warm-band=1";

// bot_run.gd plays the legacy maps unless told otherwise; a launched game plays the park table, so the red
// team does too (wave 37: PF-31's stuck detours were a legacy stage 2 crease the park flume does not have).
export const PLAYED_TABLE = "--table=park";

export function botArgs(job, out) {
  return [
    "--headless", "--fixed-fps", "90", "--path", "sketches/core-loop", "--script", "res://tools/bot_run.gd", "--",
    "--out=" + out, "--policy=" + job.policy, "--seeds=" + job.seed, "--pilot=" + job.pilot,
    PLAYED_TABLE, PLAYED_AUDIO, "--bot-audit=1", "--bot-profile=1", ...job.args,
  ];
}

export function replayCommand(job) {
  return "$GODOT_BIN " + botArgs(job, "artifacts/local/replay").filter((a) => !a.startsWith("--bot-")).join(" ");
}

// --- reading one bot job -------------------------------------------------------------------

export function parseNdjson(text) {
  const rows = [];
  for (const line of (text ?? "").split("\n")) {
    if (!line.trim()) continue;
    try {
      rows.push(JSON.parse(line));
    } catch {
      // A line cut short by a crash is itself evidence; the caller reads the exit.
    }
  }
  return rows;
}

// Godot prints a SCRIPT ERROR with its message on the same line and the frames after it.
export function logErrors(text) {
  const out = new Map();
  for (const line of (text ?? "").split("\n")) {
    const m = line.match(/^(SCRIPT ERROR|ERROR): (.*)$/);
    if (!m) continue;
    const key = m[1] + ": " + m[2].replace(/\d+(\.\d+)?/g, "#").slice(0, 160);
    out.set(key, (out.get(key) ?? 0) + 1);
  }
  return [...out].map(([message, count]) => ({ script: message.startsWith("SCRIPT"), message, count }));
}

// The stage each tick belongs to, from the audit's stage_entered events.
export function stageAt(events) {
  const marks = events.filter((e) => e.event === "stage_entered").map((e) => [e.tick, e.args[0]]);
  const arena = events.find((e) => e.event === "boss_arena_entered");
  return (tick) => {
    if (arena && tick >= arena.tick) return "boss";
    let stage = null;
    for (const [t, s] of marks) if (t <= tick) stage = s;
    return stage;
  };
}

// Many hits from several sources inside one window, adding up to a large share of max HP:
// the moment a player says "what hit me". A death soon after makes it one they could not read.
export function pileUps(events, maxHpByStage) {
  const where = stageAt(events);
  const hits = events.filter((e) => e.event === "player_hit");
  const deaths = events.filter((e) => e.event === "player_died").map((e) => e.tick);
  const out = [];
  let i = 0;
  while (i < hits.length) {
    const start = hits[i].tick;
    const window = hits.filter((h) => h.tick >= start && h.tick < start + PILE_WINDOW_TICKS);
    const sources = new Set(window.map((h) => String(h.args[1])));
    const amount = window.reduce((sum, h) => sum + Number(h.args[0] || 0), 0);
    const stage = where(start);
    const maxHp = maxHpByStage[stage] ?? maxHpByStage.default ?? 100;
    if (window.length >= 3 && sources.size >= 2 && amount >= PILE_SHARE * maxHp) {
      const died = deaths.some((d) => d >= start && d <= start + PILE_DEATH_TICKS);
      out.push({ tick: start, stage, hits: window.length, sources: [...sources].sort(), share: amount / maxHp, died });
      i += window.length;
    } else {
      i += 1;
    }
  }
  return out;
}

// Per-tick main-thread cost with the bot's own work taken out. A tick over HITCH_MS is a frame
// over budget whatever the GPU does. Ticks just after a stage loads are counted apart.
export function hitches(profile, events) {
  const wall = profile?.samples?.tick_wall;
  if (!wall) return { spikes: [], loads: 0, p99: null };
  const bot = profile.samples.bot_driver;
  const botBy = new Map((bot?.ticks ?? []).map((t, i) => [t, bot.usec[i]]));
  const where = stageAt(events);
  const loadTicks = events.filter((e) => ["stage_entered", "world_entered", "run_started"].includes(e.event)).map((e) => e.tick);
  const costs = [];
  const spikes = [];
  let loads = 0;
  wall.ticks.forEach((tick, i) => {
    const ms = (wall.usec[i] - (botBy.get(tick) ?? 0)) / 1000;
    if (tick <= SETTLE_TICKS * 2) return;
    costs.push(ms);
    if (ms <= HITCH_MS) return;
    if (loadTicks.some((t) => tick >= t && tick < t + SETTLE_TICKS)) loads += 1;
    else spikes.push({ tick, stage: where(tick), ms: Math.round(ms) });
  });
  costs.sort((a, b) => a - b);
  const p99 = costs.length ? Math.round(costs[Math.floor(costs.length * 0.99)] * 10) / 10 : null;
  return { spikes, loads, p99 };
}

// One bot job's outcome, read from what it left: { job, status, row, run, errors, piles, perf }.
export function readBotJob(job, files) {
  const rows = parseNdjson(files.bots);
  const row = rows.at(-1) ?? null;
  const runs = parseNdjson(files.runs);
  const events = parseNdjson(files.events);
  const maxHp = { default: row?.stages?.[0]?.max_hp ?? 100 };
  for (const s of row?.stages ?? []) maxHp[s.stage] = s.max_hp;
  maxHp.boss = row?.stages?.at(-1)?.max_hp ?? maxHp.default;
  return {
    job, exit: files.exit, timedOut: files.timedOut, row, run: runs.at(-1) ?? null, errors: logErrors(files.log),
    piles: pileUps(events, maxHp), perf: hitches(files.profile, events), events: events.length,
  };
}

// --- turning results into findings -----------------------------------------------------------

const STALLS = new Set(["stalled", "boss_stalled", "fight_capped"]);

function finding(severity, area, key, title, feel, extra = {}) {
  return { severity, area, key, title, feel, runs: [], ...extra };
}

// Each playbook adds to a map keyed by root cause, so twelve runs hitting one bug read as one line.
export function grade(results, extras = {}) {
  const found = new Map();
  const add = (f, result, note) => {
    const have = found.get(f.key) ?? f;
    if (result) have.runs.push({ id: result.job.id, persona: result.job.persona, pilot: result.job.pilot, seed: result.job.seed, note, replay: replayCommand(result.job), carry: result.job.carry ?? null });
    found.set(f.key, have);
  };

  for (const r of results) {
    const { job, row } = r;
    // Crashes and freezes.
    if (r.timedOut) add(finding("blocker", "stability", "freeze", "A run froze and never ended", "The game hangs mid-run and has to be killed."), r, "no end within the job timeout");
    else if (r.exit !== 0 || row === null) add(finding("blocker", "stability", "crash", "A run crashed", "The game closes or dies mid-run."), r, `exit ${r.exit}, ${row ? "row written" : "no bots.ndjson row"}`);
    for (const e of r.errors.filter((e) => e.script)) {
      add(finding("major", "stability", "err:" + e.message, "Script error in play: " + e.message.replace(/^SCRIPT ERROR: /, ""), "Something in the game logic broke; the effect may be invisible or may not be."), r, `${e.count}x`);
    }
    for (const e of r.errors.filter((e) => !e.script)) {
      add(finding("minor", "stability", "err:" + e.message, "Engine error: " + e.message.replace(/^ERROR: /, ""), "Usually nothing on screen; worth a look if it repeats."), r, `${e.count}x`);
    }
    if (!row) continue;

    // Stalls and softlocks.
    const brokeWarden = (row.stages ?? []).some((s) => s.warden_broken_s != null);
    if (row.outcome === "boss") {
      add(finding("blocker", "Wardens and bosses", "boss-missing", "The boss arena had no boss", "The run reaches the end and there is nothing to fight."), r, "outcome boss");
    } else if (STALLS.has(row.outcome) && job.policy !== "traversal" && !(job.policy === "camper" && !brokeWarden)) {
      const inBoss = row.outcome === "boss_stalled";
      const last = (row.stages ?? []).at(-1) ?? {};
      const where = inBoss ? "boss" : `stage ${row.stage_reached}`;
      // stall_state "gates" (or a stage whose Warden broke) is the leg after the fight: the bot never
      // reached an exit gate. That is a different bug from a Warden that never breaks.
      const exitLeg = !inBoss && (last.stall_state === "gates" || last.warden_broken_s != null);
      const hard = ["skipper", "completionist"].includes(job.policy);
      const sev = inBoss || (hard && !exitLeg) ? "blocker" : "major";
      const what = inBoss ? "The boss fight never ends" : row.outcome === "fight_capped" ? "A Warden fight runs past its cap"
        : exitLeg ? "Warden broken, but the run never reaches an exit gate" : "Stuck on a stage: the Warden never breaks";
      add(finding(sev, exitLeg ? "stage and world design" : "Wardens and bosses", `${exitLeg ? "exit" : "stall"}:${where}:${job.pilot}`, `${what} (${where}, ${job.pilot})`, inBoss
        ? "You are in the boss fight and nothing you do finishes it."
        : exitLeg ? "You beat the Warden and then cannot find or reach the way out." : "You are on a stage with no way on but quitting.", { candidate: true }), r, `${row.outcome}${last.stall_state ? ", state " + last.stall_state : ""}${last.stuck_detours ? ", " + last.stuck_detours + " stuck detours" : ""}`);
    }

    // Route skips: a stage left with no fight beat.
    for (const b of row.beats ?? []) {
      if (b.exit && (b.skipped ?? []).includes("fight")) {
        add(finding("watch", "stage and world design", `skip:${b.stage}`, `Stage ${b.stage} cleared without a fight beat`, "A fast player can leave the stage without ever fighting its Warden properly."), r, `beats skipped: ${b.skipped.join(", ")}`);
      }
      const findS = (b.ticks?.find ?? 0) / TICKS_PER_SECOND;
      if (job.persona === "first-timer" && findS > LOST_FIND_S) {
        add(finding("watch", "clarity", `lost:${b.stage}`, `Slow to find the Warden on stage ${b.stage}`, "A new player wanders before finding what to fight."), r, `${Math.round(findS)} s roaming`);
      }
    }

    // Degenerate builds: a Warden or boss erased in an instant.
    // warden_fight_s is the stage clock when the bot turned on the Warden, not a duration.
    for (const s of row.stages ?? []) {
      const from = Math.max(s.warden_engaged_s ?? -1, s.warden_fight_s ?? -1);
      const took = s.warden_broken_s != null && from >= 0 ? s.warden_broken_s - from : null;
      if (took !== null && took < ONE_SHOT_S) {
        add(finding("watch", "in-run growth", `oneshot:${s.stage}`, `Warden on stage ${s.stage} broken in under ${ONE_SHOT_S} s`, "The build deletes the Warden before it can do anything."), r, `${took.toFixed(2)} s, parts: ${(s.parts ?? []).join(" ") || "none"}`);
      }
      if ((s.stuck_detours ?? 0) >= STUCK_DETOURS) {
        add(finding("minor", "stage and world design", `stuck:${s.stage}`, `The ball gets stuck on stage ${s.stage} geometry`, "You roll into a spot and have to back out and steer around, again and again."), r, `${s.stuck_detours} stuck detours as ${job.persona}`);
      }
    }

    // Crowd moments.
    for (const p of r.piles) {
      const sev = p.died ? "major" : "minor";
      add(finding(sev, "clarity", `pile:${p.stage}:${p.died ? "dead" : "hurt"}`, p.died ? `Died to a pile-up on ${label(p.stage)}` : `Pile-up hits on ${label(p.stage)}`,
        p.died ? "Several things hit at once and the run ends before you can read what happened." : "Several things hit at once and a big chunk of health goes in a second."),
        r, `${p.hits} hits from ${p.sources.join(", ")}, ${Math.round(p.share * 100)}% HP in 1 s${p.died ? ", then died" : ""}`);
    }

    if (r.perf.p99 !== null && r.perf.p99 > CPU_P99_MS) {
      add(finding("watch", "stability", "cpu-p99", `Main-thread tick p99 over ${CPU_P99_MS} ms on the cloud box`, "Headroom is thin; check with MangoHud on Andrew's PC."), r, `p99 ${r.perf.p99} ms`);
    }
  }

  for (const f of found.values()) {
    if (f.key.startsWith("pile:") && f.severity === "minor" && f.runs.length >= 3) f.severity = "major";
  }

  // Frame-time spikes. Load on a shared box lands at random moments; a hitch the game causes lands
  // at the same run moment for different seeds and pilots. Only those are graded (the bar's
  // repeating hitch); the rest is one watch line.
  const { shared, scattered } = sharedHitches(results);
  for (const [r, list] of shared) {
    const t = extras.hitchTriage;
    add(finding("major", "stability", "hitch:shared", `Hitch over ${HITCH_MS} ms at the same moment in several runs`,
      "A stutter in play that comes back on a beat, whoever is playing.", { candidate: true,
        counts: t ? { "replayed alone: moments": t.tested, "still hitched": t.alone, "still hitched without the music mix": t.noMix } : undefined }),
    r, `${list.length} shared moment(s), e.g. ${list.slice(0, 4).map((s) => `${(s.tick / TICKS_PER_SECOND).toFixed(1)} s (${s.ms} ms, ${label(s.stage)})`).join(", ")}`);
  }
  if (scattered > 0) {
    add(finding("watch", "stability", "hitch:scattered", `${scattered} scattered ticks over ${HITCH_MS} ms`, "Most likely the shared cloud box; MangoHud on Andrew's PC is the check."), null);
  }

  for (const a of extras.fuzz ?? []) {
    const broken = fuzzSeverity(a.kind) === "major";
    const timed = /frame|tick|time/i.test(a.kind);
    add(finding(broken ? "major" : "watch", "in-run growth", "fuzz:" + a.kind, broken ? `Item fuzz broke a rule: ${a.kind}` : `Item fuzz outlier: ${a.kind}`,
      broken ? "A build pushes a number past what the game allows; it can crash or break a fight." : timed ? "A build costs more time per tick than its cap; timed under load on the cloud box, so recheck alone." : "A build runs far past its peers; fun or broken is Andrew's call."), null);
    found.get("fuzz:" + a.kind).runs.push({ id: "item_fuzz", seed: a.seed, pilot: a.class, note: `${a.reading ?? ""} (cap ${a.cap ?? "-"})${a.build ? ", build " + String(a.build).split(/,\s*/).slice(0, 4).join(" ") + " ..." : ""}`, replay: `$GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/item_fuzz.gd -- --seeds=${a.seed} --seconds=${extras.fuzzSeconds ?? 60} --out=artifacts/local/replay` });
  }
  for (const s of extras.sweep ?? []) {
    add(finding("major", "in-run growth", "sweep:" + s, "Build sweep: " + s, "A build rule the sweep checks is broken."), null);
  }
  const ph = extras.placeholders;
  if (ph && ph.total > 0) {
    add(finding("major", "look", "placeholders", `${ph.total} placeholders still in the build`, "Greybox, stand-in art or text where finished content belongs. Expected until wave 20.", { counts: ph.byKind }), null);
  }
  if (extras.perfBench) {
    const pb = extras.perfBench;
    if (pb.error) add(finding("blocker", "stability", "perfbench-crash", "The dense-fight bench crashed", "The densest fight in the game falls over."), null);
    else if (pb.max > HITCH_MS) add(finding(pb.p99 > HITCH_MS ? "major" : "watch", "stability", "perfbench", `Dense fight CPU frame p99 ${pb.p99} ms, max ${pb.max} ms`, "The biggest crowd the game builds costs more than a frame.", { counts: pb }), null);
  }
  if (extras.exportFailure) add(finding("blocker", "stability", "export", "The Linux build did not export or boot", "The game does not start.", { counts: { reason: extras.exportFailure } }), null);

  return rank([...found.values()]);
}

// A fuzz anomaly that breaks a cap the game promises (speed, charges, cooldowns, finite numbers) is a
// major; an outlier or a tick timed under load is for Andrew's keep-or-kill.
export function fuzzSeverity(kind) {
  if (/^outlier_|frame|tick_p99/i.test(kind)) return "watch";
  return /non_finite|nan|leak|over_cap|bolts|charge|cooldown|floor|stall|crash|speed|reduction|guard/i.test(kind) ? "major" : "watch";
}

// Spikes at the same run tick (within SAME_MOMENT_TICKS) in two or more runs with different seeds.
export function sharedHitches(results) {
  const shared = new Map();
  let scattered = 0;
  for (const r of results) {
    const mine = [];
    for (const s of r.perf.spikes) {
      const again = results.some((o) => o !== r && o.job.seed !== r.job.seed && !o.job.args.some((a) => a.startsWith("--from-stage"))
        && o.perf.spikes.some((x) => Math.abs(x.tick - s.tick) <= SAME_MOMENT_TICKS));
      if (again && !r.job.args.some((a) => a.startsWith("--from-stage"))) mine.push(s);
      else scattered += 1;
    }
    if (mine.length) shared.set(r, mine);
  }
  return { shared, scattered };
}

function label(stage) {
  return stage === "boss" ? "the boss" : stage == null ? "an unknown stage" : `stage ${stage}`;
}

export function rank(findings) {
  return findings.sort((a, b) =>
    SEVERITIES.indexOf(a.severity) - SEVERITIES.indexOf(b.severity)
    || b.runs.length - a.runs.length
    || AREAS.indexOf(a.area) - AREAS.indexOf(b.area)
    || a.key.localeCompare(b.key));
}

// --- the page --------------------------------------------------------------------------------

export function renderMarkdown({ wave, commit, started, minutes, results, findings, extras = {} }) {
  const count = (s) => findings.filter((f) => f.severity === s).length;
  const lines = [
    `# Red team, wave ${wave}`,
    "",
    `Build \`${commit.slice(0, 10)}\`, ${started}, ${minutes} min in a 4-core cloud container. ` +
      `${results.length} bot runs across ${new Set(results.map((r) => r.job.persona)).size} personas and ${new Set(results.map((r) => r.job.pilot)).size} pilots.`,
    "",
    `**${count("blocker")} blocker, ${count("major")} major, ${count("minor")} minor, ${count("watch")} to watch.**`,
    "",
    "## What Andrew would feel, worst first",
    "",
  ];
  const bugs = findings.filter((f) => f.severity !== "watch");
  if (bugs.length === 0) lines.push("Nothing the bug bar grades.", "");
  bugs.forEach((f, i) => lines.push(...findingLines(f, i + 1)));
  const watch = findings.filter((f) => f.severity === "watch");
  if (watch.length) {
    lines.push("## Watch (not bugs on the bar; taste or tuning)", "");
    watch.forEach((f, i) => lines.push(...findingLines(f, i + 1)));
  }
  lines.push("## Runs", "", "| Persona | Pilot | Seed | Outcome | Stage | Game min | Hits/piles | Tick p99 ms |", "| --- | --- | --- | --- | --- | --- | --- | --- |");
  for (const r of results) {
    const row = r.row;
    const outcome = r.timedOut ? "TIMEOUT" : row ? row.outcome : `CRASH (exit ${r.exit})`;
    lines.push(`| ${r.job.persona}${r.job.carry ? " (carry)" : ""} | ${r.job.pilot} | ${r.job.seed} | ${outcome} | ${row?.stage_reached ?? "-"} | ${row ? (row.game_seconds / 60).toFixed(1) : "-"} | ${(row?.stages ?? []).reduce((n, s) => n + (s.hits ?? 0), 0)}/${r.piles.length} | ${r.perf.p99 ?? "-"} |`);
  }
  lines.push("");
  if (extras.fuzzSummary) lines.push(`Item fuzz: ${extras.fuzzSummary}.`, "");
  if (extras.placeholders) lines.push(`Placeholders by kind: ${Object.entries(extras.placeholders.byKind).map(([k, n]) => `${k} ${n}`).join(", ") || "none"}.`, "");
  lines.push(
    "## Limits",
    "",
    "Bots play the real game from the source tree headless, so this finds stalls, crashes, script errors, pile-ups, rule-breaking builds and CPU hitches. " +
      "It does not see the GPU, the picture or feel: hitches are main-thread ticks on a shared 4-core box, and a stall is a candidate until a replay confirms it. " +
      "Andrew's sitting and MangoHud on his PC decide those.",
    "",
  );
  return lines.join("\n");
}

function findingLines(f, n) {
  const sev = f.severity.toUpperCase();
  const lines = [`${n}. **${sev}** · ${f.area} · ${f.title}${f.candidate ? " (candidate, replay to confirm)" : ""}`, `   ${f.feel}`];
  if (f.runs.length) {
    const seen = f.runs.slice(0, 3).map((r) => `${r.pilot ?? "-"} seed ${r.seed}${r.persona ? " as " + r.persona : ""}: ${r.note ?? ""}`.trim());
    lines.push(`   Seen in ${f.runs.length}: ${seen.join("; ")}${f.runs.length > 3 ? "; ..." : ""}`);
    if (f.runs[0].replay) lines.push("   Replay: `" + f.runs[0].replay + "`");
  }
  if (f.counts) lines.push("   " + Object.entries(f.counts).map(([k, v]) => `${k} ${v}`).join(", "));
  lines.push("");
  return lines;
}

// The runs a later wave replays: every blocker and major that came from a bot run.
export function carryList(findings) {
  const out = [];
  for (const f of findings) {
    if (!["blocker", "major"].includes(f.severity)) continue;
    const run = f.runs.find((r) => r.persona && r.pilot && Number.isInteger(r.seed));
    if (run && !out.some((c) => c.persona === run.persona && c.pilot === run.pilot && c.seed === run.seed)) {
      out.push({ persona: run.persona, pilot: run.pilot, seed: run.seed, title: f.title });
    }
  }
  return out.slice(0, 4);
}

// ---- The player's-eye pass (README, "The player's-eye pass") ----
// A filmed run (sketches/core-loop/tools/eye_film.gd) is read cold by someone who has never seen
// the game, in a persona, and a judge sets what they said beside what the game knew.

// Who reads. The card is all the reader is told about themselves.
export const READERS = {
  "first-timer": "You have never played this game or seen anything about it. You read what the screen offers, try what it suggests, and give up on anything you cannot work out in a few seconds.",
  cautious: "You have never played this game. You play carefully: you read every word before you move on, hang back from fights, and avoid anything that looks risky. Being hit by something you could not see coming, and words that leave before you have read them, annoy you more than anything.",
  speedrunner: "You have played many games like this and want to go fast. You skip what you can, resent every screen that holds you, and notice every second in which nothing is asked of you.",
  greedy: "You want everything the game will give you: every pickup, every upgrade, every optional job. You read every offer closely and want to know exactly what each choice gives and costs.",
};

// What is filmed. `whole` is world 1 start to finish on the fastest line; `wait` is a player who
// hangs back in the dam until a planted death (the cause line names a chaser: it is scripted),
// then starts again, so the death screen and a second briefing are on film.
export const FILMS = {
  whole: { policy: "skipper", args: ["--self-play-until=3", "--self-play-hold=5"], says: "world 1 start to finish, the fastest line" },
  wait: { policy: "camper", args: ["--self-play-plant-death=240", "--self-play-hold=8"], says: "hanging back in the dam for four minutes, a death, and the start of a second run" },
};
export const FILM_OF = { cautious: "wait" };

// The self-play flags for one film (after `--`). plant is "" or "objective" (the control run).
export function filmArgs({ film, seed = 1, pilot = "", out, world = 1, plant = "", deathAt = 0, save = "", live = false }) {
  const spec = FILMS[film];
  if (!spec) throw new Error("--film must be one of " + Object.keys(FILMS).join(", "));
  // deathAt moves the wait film's planted death (a short control run does not need four minutes).
  const args = spec.args.map((a) => (deathAt > 0 && a.startsWith("--self-play-plant-death=") ? `--self-play-plant-death=${deathAt}` : a));
  return [
    "--self-play", `--self-play-seed=${seed}`, `--self-play-policy=${spec.policy}`, "--self-play-keys=1", "--self-play-eyes=1",
    "--self-play-watch=1", `--self-play-save=${save || `eye-${film}-${seed}`}`, "--self-play-stall=600", `--self-play-film=${out}`,
    ...(pilot ? [`--self-play-pilot=${pilot}`] : []), ...(world < 1 ? [`--self-play-film-world=${world}`] : []),
    ...(plant ? [`--self-play-plant-hide=${plant}`] : []), ...(live ? ["--self-play-film-live=1"] : []), ...args,
  ];
}

// The film's rows as the reader gets them: numbered in order, with no word of why each frame was
// taken (a file called "death" tells the answer). A hit's or a death's lead-in, the frame itself
// and the frame after make one set, so the reader can be asked whether they saw it coming.
// Returns { frames: [{ n, file, set }], sets: [{ id, first, last, moment }], key: [row with n] }.
export function readerPack(rows) {
  rows = withoutLeadInDoubles(rows);
  const frames = [];
  const sets = [];
  const key = [];
  let open = null;
  rows.forEach((row, i) => {
    const n = i + 1;
    const why = String(row.why || "");
    const base = why.replace(/-(lead|after)$/, "");
    const beat = /^(hit-\d+|death)$/.test(base) ? base : "";
    // A killing hit is one moment: its death frames join the hit's set. A set opens only on a
    // lead-in frame, since the question it asks is what the earlier pictures showed.
    // (a death more than a second after the hit is its own moment, and asks its own question)
    const at = Number(row.t) || 0;
    const joins = open && (open.beat === beat || (beat === "death" && at - open.at <= 1));
    if (beat && !joins) {
      open = why.endsWith("-lead") ? { beat, id: sets.length + 1, first: n, last: n, moment: n, at } : null;
      if (open) sets.push(open);
    }
    if (!beat) open = null;
    if (open) {
      open.last = n;
      if (why === open.beat) {
        open.moment = n;
        open.at = at;
      }
    }
    frames.push({ n, file: row.file, set: open ? open.id : 0 });
    key.push({ n, ...row });
  });
  return { frames, sets: sets.map(({ id, first, last, moment }) => ({ id, first, last, moment })), key };
}

// The film writes a moment's lead-in when the hit lands. Any other picture taken between the
// first lead-in frame and the hit is already in the file by then, so it would sit before the
// lead-in, out of game order. It is left out: the lead-in's own pictures, 0.4 s apart, show
// that stretch, and the reader's pictures run in game order. Rows with no game time are kept.
function withoutLeadInDoubles(rows) {
  const beatOf = (row) => {
    const base = String(row.why || "").replace(/-(lead|after)$/, "");
    return /^(hit-\d+|death)$/.test(base) ? base : "";
  };
  const timed = (row) => row.t != null && row.t !== "" && Number.isFinite(Number(row.t));
  const windows = new Map();
  for (const row of rows) {
    if (!String(row.why || "").endsWith("-lead") || !timed(row)) continue;
    const at = Number(row.t);
    const span = windows.get(beatOf(row)) || { from: at, to: at };
    windows.set(beatOf(row), { from: Math.min(span.from, at), to: Math.max(span.to, at) });
  }
  // The window runs on to the moment itself, when the film has it.
  for (const row of rows) {
    const span = windows.get(String(row.why || ""));
    if (span && timed(row)) span.to = Math.max(span.to, Number(row.t));
  }
  const spans = [...windows.values()];
  return rows.filter((row) => beatOf(row) || !timed(row) || !spans.some((span) => Number(row.t) >= span.from && Number(row.t) <= span.to));
}

const pad = (n) => String(n).padStart(3, "0");

// What the reader is handed. Nothing here names a file, a system or what the game knew.
// look: the film is the real game's picture (a PC film, ruling cp), so the reader judges how it looks too.
export function readerBrief(persona, pack, { look = false } = {}) {
  const card = READERS[persona];
  if (!card) throw new Error("--persona must be one of " + Object.keys(READERS).join(", "));
  const lines = [
    "# Read this film as a player",
    "",
    card,
    "",
    `The folder holds ${pack.frames.length} pictures of one play of a game, in order: ${pad(1)}.jpg to ${pad(pack.frames.length)}.jpg. They are what was on the screen. Read only these pictures. Do not look at anything else on this machine, and do not guess from file names or sizes.`,
    "",
    look
      ? "The pictures are the real game's own picture. Judge what a player can read, understand and act on, and also how it looks: say where colour, light or an effect hides something, where two things look the same and should not, and where something looks unfinished."
      : "The pictures come from a software renderer: colour, lighting and effects are rougher than the real game, so do not judge how it looks. Judge what a player can read, understand and act on.",
    "",
    "For every picture, answer in one table row (keep each cell short):",
    "",
    "| n | what is on the screen | what I think I am meant to do now | words I read that I do not understand, quoted | anything I cannot see, cannot read or that looks broken |",
    "",
    "Say \"cannot tell\" when you cannot tell. That is the most useful answer you can give; never fill a cell with a guess.",
  ];
  if (pack.sets.length) {
    lines.push("", "Some runs of pictures are 0.4 seconds apart and end at a moment something happened to you. For each, answer after the table:", "");
    for (const s of pack.sets) lines.push(`- Pictures ${pad(s.first)} to ${pad(s.last)}: something happens at ${pad(s.moment)}. Looking only at the pictures before it, what was about to happen, and what on the screen told you? If nothing told you, say so.`);
  }
  lines.push("", "Then finish with:", "", "1. The five things most likely to confuse, bore or annoy the player on your card, worst first, each with the picture numbers that show it.", "2. Three things the screen told you clearly.", "3. In your own words, what this game is and what the goal is, as far as the pictures told you.");
  return lines.join("\n") + "\n";
}

// The judge's sheet: each picture beside what the game knew when it was taken. The judge fills
// the last column from the reader's table; a row where the two disagree is a finding.
export function judgeSheet(pack) {
  const cell = (v) => String(v ?? "").replace(/\|/g, "/");
  const lines = ["| n | why it was taken | game s | state | objective the game set | hull | hit by | what the reader said (fill in) |", "| --- | --- | --- | --- | --- | --- | --- | --- |"];
  for (const r of pack.key) {
    lines.push(`| ${pad(r.n)} | ${cell(r.why)} | ${cell(r.t)} | ${cell(r.flow)}${r.paused ? " (held)" : ""} | ${cell(r.plate)} | ${cell(r.hp)}/${cell(r.hp_max)} | ${cell(r.source ? `${r.source} ${r.amount}` : "")} | |`);
  }
  return lines.join("\n") + "\n";
}

// The play findings list: project-guide/handoff/PLAY-FINDINGS.tsv. One row for each open thing a
// player would feel, with an owner and a review date. The pull request that fixes one removes
// its row. A finding never holds a promotion (ruling cn): a row past its date is reported, and
// its owner fixes it or re-dates it.
export const FINDINGS_FILE = "project-guide/handoff/PLAY-FINDINGS.tsv";
export const FINDINGS_HEADER = ["id", "grade", "meets", "evidence", "owner", "added", "review"];
// check: seen on a cloud film only; a PC film decides before anyone acts.
export const FINDING_GRADES = ["blocker", "major", "minor", "check"];

// { rows, problems: [{ line, message }] }
export function parseFindings(text) {
  const lines = String(text || "").split("\n").map((line) => line.replace(/\r$/, ""));
  const rows = [];
  const problems = [];
  if (lines[0] !== FINDINGS_HEADER.join("\t")) return { rows, problems: [{ line: 1, message: "the header must be: " + FINDINGS_HEADER.join(" TAB ") }] };
  const seen = new Set();
  lines.slice(1).forEach((line, index) => {
    if (!line.trim()) return;
    const at = index + 2;
    const cells = line.split("\t").map((cell) => cell.trim());
    if (cells.length !== FINDINGS_HEADER.length || cells.some((cell) => !cell)) return problems.push({ line: at, message: "a row needs " + FINDINGS_HEADER.join(", ") + ", with no cell empty" });
    const row = Object.fromEntries(FINDINGS_HEADER.map((name, i) => [name, cells[i]]));
    if (!/^PF-\d+$/.test(row.id) || seen.has(row.id)) problems.push({ line: at, message: `the id must be PF-<n> and used once, got ${row.id}` });
    seen.add(row.id);
    if (!FINDING_GRADES.includes(row.grade)) problems.push({ line: at, message: "the grade must be one of " + FINDING_GRADES.join(", ") });
    for (const date of ["added", "review"]) if (!/^\d{4}-\d{2}-\d{2}$/.test(row[date]) || !realDate(row[date])) problems.push({ line: at, message: `${date} must be a date, YYYY-MM-DD` });
    rows.push(row);
  });
  return { rows, problems };
}

// 2026-02-31 is not a date, whatever Date.parse makes of it.
function realDate(text) {
  const date = new Date(text + "T00:00:00Z");
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === text;
}

// The rows past their review date on `today` (YYYY-MM-DD).
export function overdueFindings(rows, today) {
  return rows.filter((row) => row.review < today);
}
