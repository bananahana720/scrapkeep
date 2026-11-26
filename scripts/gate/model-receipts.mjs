#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const SKILL = ".agents/skills/scrapkeep-verify-formal";
const SRC = "sketches/core-loop/src";
export const TLC_PIN = "1.7.4";
export const TIMEOUT_MIN = 30;

export const ROWS = {
  "run-always-ends": {
    spec: "RunFlow.tla",
    real: [{ cfg: "today-store.cfg", minStates: 1444 }],
    plants: [
      { cfg: "broken-vanish.cfg", rule: "WardenGoneOpens" },
      { cfg: "broken-endguard.cfg", rule: "EndsOnce" },
    ],
    coverage: "references/coverage.md",
    gaps: [],
  },
  "rewards-banked-once": {
    spec: "Rewards.tla",
    real: [
      {
        cfg: "rewards-today-one.cfg",
        minStates: 98319,
        label: "one game, from a fresh start or an older build's run file (W1-117)",
      },
      {
        cfg: "rewards-today-two-once.cfg",
        minStates: 8009266,
        label: "two games on one profile paying once (finding R-2)",
      },
      {
        cfg: "rewards-today-two-lost.cfg",
        minStates: 19042013,
        label: "two games on one profile losing nothing",
      },
    ],
    plants: [
      { cfg: "rewards-broken-ledger.cfg", rule: "AtMostOnce" },
      { cfg: "rewards-broken-midsave.cfg", rule: "NeverLost" },
      { cfg: "rewards-broken-legacyrun.cfg", rule: "NeverLost" },
      { cfg: "rewards-broken-stale.cfg", rule: "AtMostOnce" },
      { cfg: "rewards-broken-nolock.cfg", rule: "AtMostOnce" },
    ],
    coverage: "references/rewards-coverage.md",
    gaps: [
      "the profile's save lock is taken as perfect: a game that waits longer than 250 ms for it, a stale lock broken while its holder still lives, and an older build saving beside this one (it takes no lock) are not modelled",
      "two games pay twice when both profile saves of the first game's earn fail (ruling ea: never lost outranks at most once; rewards-ruled-two-twofail-once)",
      "a profile that builds from 4 October to 16 November left holding a reward key without its unlock (finding R-1) stays unpaid: the model starts from a profile that never held one, and the repair is card W1-121",
    ],
  },
  "hazards-hit-everyone": {
    spec: "HazardCycle.tla",
    real: [
      {
        cfg: "hazard-today.cfg",
        minStates: 45981,
        label: "a storm's sought strike, one ball and one enemy (W44)",
      },
    ],
    plants: [
      { cfg: "hazard-broken-notell.cfg", rule: "TellBeforeStrike" },
      { cfg: "hazard-broken-seekrolling.cfg", rule: "RollingNeverSought" },
      { cfg: "hazard-broken-strikeatball.cfg", rule: "TellBeforeStrike" },
      { cfg: "hazard-broken-skipenemies.cfg", rule: "EnemyStruck" },
      { cfg: "hazard-broken-noseek.cfg", rule: "StalledSought" },
      { cfg: "hazard-broken-hitanywhere.cfg", rule: "BallOnlyWhereTold" },
    ],
    coverage: "references/hazard-coverage.md",
    gaps: [
      "the model counts in ticks with a shortened rest and storm; seconds, the dome's own fixed strike, floods and the industrial cone and ring are left to tests/hazards_hit_everyone_test.gd and the park event tests",
    ],
  },
  "flood-never-held": {
    spec: "ParkFlood.tla",
    real: [
      {
        cfg: "flood-today-timed.cfg",
        minStates: 31616,
        label: "a flood with a live time, as every real flood row has",
      },
      { cfg: "flood-today-noclock.cfg", minStates: 1792, label: "a flood with no live time" },
      {
        cfg: "flood-today-longfill.cfg",
        minStates: 63392,
        label:
          "a fill that outlasts the live time less the wait, still rising past the live time under a parked ball",
      },
    ],
    plants: [
      { cfg: "flood-broken-nosnap.cfg", rule: "FullWaterNeverHeld" },
      { cfg: "flood-broken-nosnap-slot.cfg", rule: "FullWaterFreesItsSlot" },
      { cfg: "flood-broken-nowait.cfg", rule: "NeverRisesUnderBall" },
      { cfg: "flood-broken-endunder.cfg", rule: "NeverEndsUnderBall" },
      { cfg: "flood-broken-nocap.cfg", rule: "WithinCap" },
      { cfg: "flood-broken-nohold.cfg", rule: "HoldEnds" },
      { cfg: "flood-broken-endspent.cfg", rule: "NeverEndsUnderBall" },
      { cfg: "flood-broken-endstop.cfg", rule: "FullWaterNeverHeld" },
      { cfg: "flood-broken-endstop-hold.cfg", rule: "HoldEnds" },
    ],
    coverage: "references/flood-coverage.md",
    gaps: [
      "the wait is counted in ticks (HoldTicks 1 against the real 2 s); the wait for a ball near the basin but outside it (hold_clear_m, 12 to 20 m on real flood rows) is not capped and not modelled, so such a ball still holds the water off (finding PF-3)",
      "collapses and cave-ins are not modelled; their clock shares the rise's helper and park_events_test.gd sweeps it",
    ],
  },
  "destructibles-safe": {
    spec: "Destructibles.tla",
    real: [
      {
        cfg: "destructibles-today.cfg",
        minStates: 83322,
        label: "two pieces (tiers 1 and 3), every heft class, two retries, either tick order (W45)",
      },
    ],
    plants: [
      { cfg: "destructibles-broken-repay.cfg", rule: "PaysOnce" },
      { cfg: "destructibles-broken-nocap.cfg", rule: "PaysOnce" },
      { cfg: "destructibles-broken-cutline.cfg", rule: "NoLineOnRubble" },
      { cfg: "destructibles-broken-dismount.cfg", rule: "NoLineOnRubble" },
      { cfg: "destructibles-broken-staleaim.cfg", rule: "NoLineOnRubble" },
      { cfg: "destructibles-broken-collider.cfg", rule: "NoColliderAfterShatter" },
      { cfg: "destructibles-broken-retryfarm.cfg", rule: "RetryNoFarm" },
      { cfg: "destructibles-broken-keepdrops.cfg", rule: "RetryNoFarm" },
      { cfg: "destructibles-broken-tierstack.cfg", rule: "TierCapNeverStacks" },
    ],
    coverage: "references/destructibles-coverage.md",
    gaps: [
      "the caps are shrunk to bind on two pieces (3 scrap and 1 cog against the real 35 and 20 over 14 pieces); the sweep's geometry, speeds and the refused cue are left to tests/destructibles_test.gd",
      "a line on a body (an enemy, a stake, a moving world anchor) is never cut by a break; a destructible is none of those, so its lines are world lines",
      "a Continue after a quit (it loads the stage-entry save and enters the stage again) is not modelled apart from the retry; lifetime tallies a pickup feeds outside the run are not modelled",
    ],
  },
  "yard-lock-safe": {
    spec: "YardLock.tla",
    real: [
      {
        cfg: "yardlock-today.cfg",
        minStates: 146341,
        label:
          "a played game's yard lock and overtime bell over two stages, any flight or shot at the Warden (W45 FV-2, YL-1 closed by P7)",
      },
      {
        cfg: "yardlock-today-nostore.cfg",
        minStates: 133885,
        label: "the storeless flow's dead screen (tests and bots, YL-2 closed by P7)",
      },
    ],
    plants: [
      { cfg: "yardlock-broken-armedguard.cfg", rule: "NoLockInWardenFight" },
      { cfg: "yardlock-broken-lockedyields.cfg", rule: "NoLockInWardenFight" },
      { cfg: "yardlock-broken-flowspend.cfg", rule: "WallOnlyWhileLocked" },
      { cfg: "yardlock-broken-deadspends.cfg", rule: "WallOnlyWhileLocked" },
      { cfg: "yardlock-broken-wall.cfg", rule: "WallOnlyWhileLocked" },
      { cfg: "yardlock-broken-maxs.cfg", rule: "LockAlwaysOpens" },
      { cfg: "yardlock-broken-repay.cfg", rule: "YardPaysOnce" },
      { cfg: "yardlock-broken-elif.cfg", rule: "StartCardOnce" },
      { cfg: "yardlock-broken-offer.cfg", rule: "OvertimeOnlyAfterWin" },
      { cfg: "yardlock-broken-cash.cfg", rule: "OvertimeOnlyAfterWin" },
      { cfg: "yardlock-broken-ringcap.cfg", rule: "OvertimeOnlyAfterWin" },
    ],
    coverage: "references/yardlock-coverage.md",
    gaps: [
      "a yard opened by a waking Warden pays no panel and offers no bell (the P7 handler calls _unlock(false)); that is a recorded design assumption, not a rule the model checks",
      "the Warden's clamp, the sentry, the wall's spring, the sluice and seconds are not modelled; max_s is 5 ticks and the lock row 2 waves",
    ],
  },
  "earned-save-safe": {
    spec: "EarnedSave.tla",
    real: [
      {
        cfg: "earnedsave-today.cfg",
        minStates: 3014,
        label:
          "the Spare Frame's earned save with one refused run write and a quit, restart or Continue anywhere (ES-1 closed by P7)",
      },
      {
        cfg: "earnedsave-today-inprocess.cfg",
        minStates: 3361,
        label: "two refused writes in one process across a restart or Continue (ES-3 closed by P9)",
      },
      {
        cfg: "earnedsave-today-clearfail.cfg",
        minStates: 6407,
        label: "two refused writes and a quit whose exit flush lands (ES-2 closed by P9)",
      },
      {
        cfg: "earnedsave-today-sustained.cfg",
        minStates: 11102,
        label: "three refused writes across a refused death or restart, disk back before exit (P9)",
      },
    ],
    plants: [
      { cfg: "earnedsave-broken-spendowed.cfg", rule: "SaveOnce" },
      { cfg: "earnedsave-broken-exitflush.cfg", rule: "SaveOnce" },
      { cfg: "earnedsave-broken-resumeforce.cfg", rule: "SaveOnce" },
      { cfg: "earnedsave-broken-clearowed.cfg", rule: "SaveOnce" },
      { cfg: "earnedsave-broken-spendwrite.cfg", rule: "SaveOnce" },
      { cfg: "earnedsave-broken-clearflush.cfg", rule: "SaveOnce" },
      { cfg: "earnedsave-broken-newrunflush.cfg", rule: "SaveOnce" },
    ],
    coverage: "references/earnedsave-coverage.md",
    gaps: [
      "no write order closes a hard crash between the refused spend write and the next write that lands (earnedsave-guarded-crash), or a disk that refuses every write until the game closes (earnedsave-guarded-allfail)",
      "the model holds one run file and one Spare Frame; seconds, the boss arena's own saves and the run's other fields are not modelled",
    ],
  },
  "deferred-effects-safe": {
    spec: "DeferredEffects.tla",
    real: [
      {
        cfg: "deferred-today.cfg",
        minStates: 9955877,
        label:
          "combat's deferred queues, follow-up procs, shot bits and exposure marks across stage entries, arena clears, deaths, quits and new runs (W45 FV-3)",
      },
    ],
    plants: [
      { cfg: "deferred-broken-ungated.cfg", rule: "NoEchoAcrossAttempt" },
      { cfg: "deferred-broken-keepecho.cfg", rule: "NoEchoAcrossAttempt" },
      { cfg: "deferred-broken-keepcast.cfg", rule: "NoEchoAcrossAttempt" },
      { cfg: "deferred-broken-keepguards.cfg", rule: "NoEchoAcrossAttempt" },
      { cfg: "deferred-broken-keeppike.cfg", rule: "NoEchoAcrossAttempt" },
      { cfg: "deferred-broken-keepbolts.cfg", rule: "NoEchoAcrossAttempt" },
      { cfg: "deferred-broken-keepdefproc.cfg", rule: "NoEchoAcrossAttempt" },
      { cfg: "deferred-broken-keepdetcord.cfg", rule: "NoEchoAcrossAttempt" },
      { cfg: "deferred-broken-rakeproc.cfg", rule: "ProcDepthOne" },
      { cfg: "deferred-broken-pikeproc.cfg", rule: "ProcDepthOne" },
      { cfg: "deferred-broken-procbits.cfg", rule: "ProcDepthOne" },
      { cfg: "deferred-broken-echoagain.cfg", rule: "ProcDepthOne" },
      { cfg: "deferred-broken-tollagain.cfg", rule: "ProcDepthOne" },
      { cfg: "deferred-broken-shockagain.cfg", rule: "ProcDepthOne" },
      { cfg: "deferred-broken-reelagain.cfg", rule: "ProcDepthOne" },
      { cfg: "deferred-broken-nestproc.cfg", rule: "ProcDepthOne" },
      { cfg: "deferred-broken-detcordagain.cfg", rule: "ProcDepthOne" },
      { cfg: "deferred-broken-childsplit.cfg", rule: "ShotBitsCap" },
      { cfg: "deferred-broken-childpull.cfg", rule: "ShotBitsCap" },
      { cfg: "deferred-broken-childhoar.cfg", rule: "ShotBitsCap" },
      { cfg: "deferred-broken-rebounce.cfg", rule: "ShotBitsCap" },
      { cfg: "deferred-broken-pikebits.cfg", rule: "ShotBitsCap" },
      { cfg: "deferred-broken-contactmark.cfg", rule: "ShotBitsCap" },
      { cfg: "deferred-broken-deathmark.cfg", rule: "ShotBitsCap" },
    ],
    coverage: "references/deferred-coverage.md",
    gaps: [
      "each queue holds one waiting item, one bolt lineage is followed through a split and one enemy carries the exposure marks; MAX_LIVE eviction, seconds and geometry are left to tests/w45_combat_formal_fixes_test.gd",
      "the upgrade tree's own procs are kept from leading back to their trigger by UpgradeTree.problems at build time, which the model does not check; it checks only that the verb items and shot bits named here stay at depth 1",
      "Backwash's strip is laid on a dash or boost fact without an in_play check; the model lets the ball dash only in play (its input is frozen otherwise)",
    ],
  },
  "brindle-presses": {
    spec: "BrindleReel.tla",
    real: [
      {
        cfg: "brindlereel-today.cfg",
        minStates: 635,
        label:
          "Brindle keeps pressing across phases 1 to 3 while reeling, with every tell >= 0.6 s and no gap over 6 s without a committed attack (W46-05)",
      },
    ],
    plants: [
      { cfg: "brindlereel-broken-stop.cfg", rule: "NoLongReelGap" },
      { cfg: "brindlereel-broken-unclamped.cfg", rule: "NoLongReelGap" },
      { cfg: "brindlereel-broken-shorttell.cfg", rule: "TellFloor" },
      { cfg: "brindlereel-broken-transition.cfg", rule: "NoTransitionCommit" },
      { cfg: "brindlereel-broken-dropcue.cfg", rule: "CuedPromiseKept" },
    ],
    coverage: "references/brindlereel-coverage.md",
    gaps: [
      "the model steps in 1 s ticks over the three hull phases with shortened phase floors (12 s vs 28/24/22 s) and tracks commit cadence, transition beats, stuns, cued promises and reel gaps; 3D geometry, aim lead, physics knockback and the chase scooter are checked by tests/brindle_reel_test.gd, tests/boss_telegraph_test.gd and tests/boss_lead_line_test.gd",
      "the Phase 1 reel-entry clamp under a raised brindle.period_mult dial is not modelled (the model's crane cadence is fixed); tests/brindle_reel_test.gd checks it",
    ],
  },
  "sound-arbiter-safe": {
    spec: "SoundArbiter.tla",
    real: [
      {
        cfg: "sound-today.cfg",
        minStates: 4890,
        label:
          "music deck ownership arbiter, melody lease, epoch-stamped trims and deck pump/shots across stage, champion, Warden, boss, radio, ultimate, warning and death (Sound V4)",
      },
    ],
    plants: [
      { cfg: "sound-broken-warden-champ.cfg", rule: "WardenOwnsFightMusic" },
      { cfg: "sound-broken-unpin-boss.cfg", rule: "BossMusicInArena" },
      { cfg: "sound-broken-ult-champ.cfg", rule: "UltimateRestoresChampion" },
      { cfg: "sound-broken-death-ult.cfg", rule: "DeathClearsUltFlight" },
      { cfg: "sound-broken-melody-clash.cfg", rule: "OneMelodyNoClash" },
      { cfg: "sound-broken-stale-trim.cfg", rule: "NoStaleTrim" },
      { cfg: "sound-broken-deck-arbiter.cfg", rule: "DeckObeysArbiter" },
      { cfg: "sound-broken-stale-shot.cfg", rule: "NoStaleShot" },
    ],
    coverage: "references/sound-coverage.md",
    gaps: [
      "sample-accurate timing, Music bus DSP filter cutoffs and StingerMusic reverb (music_dsp.gd) are left to tests/music_dsp_test.gd; SFX voice-class budgets (sfx_budget.gd) are left to tests/sound_arbiter_test.gd; festival deck synthesis and warning-lane spectrum (deck_fx.gd) are left to tests/deck_moves_test.gd",
      "jukebox title spins, launch-to-next-stage landings (covered by RunFlow.tla), and miniboss or moment tunes below champion priority are not modelled",
    ],
  },
  "weapon-cadence-safe": {
    spec: "WeaponCadence.tla",
    real: [
      {
        cfg: "weaponcadence-today.cfg",
        minStates: 12415,
        label:
          "all six pilots (Rivet press, Sable tap_charge, Kest lob_snap, Tarn beats, Tally stamp, Cannon lock), boundaries, interrupts and proc isolation (W46 E1-17, E2-08, WC-1 closed by W46-FIX1)",
      },
    ],
    plants: [
      { cfg: "weaponcadence-broken-play-gate.cfg", rule: "NoShotOutsidePlay" },
      { cfg: "weaponcadence-broken-boundary-reset.cfg", rule: "RestAfterBoundary" },
      { cfg: "weaponcadence-broken-title-reset.cfg", rule: "RestAfterBoundary" },
      { cfg: "weaponcadence-broken-jam-freeze.cfg", rule: "BoundedReadyAfterInterrupt" },
      { cfg: "weaponcadence-broken-interrupt-hold.cfg", rule: "BoundedReadyAfterInterrupt" },
      { cfg: "weaponcadence-broken-lock-stuck.cfg", rule: "BoundedReadyAfterInterrupt" },
      { cfg: "weaponcadence-broken-hold-repeat.cfg", rule: "OneVolleyPerPress" },
      { cfg: "weaponcadence-broken-beats-hold-repeat.cfg", rule: "OneVolleyPerPress" },
      { cfg: "weaponcadence-broken-snap-hold-lock.cfg", rule: "OneVolleyPerPress" },
      { cfg: "weaponcadence-broken-proc-touch.cfg", rule: "OneVolleyPerPress" },
      { cfg: "weaponcadence-broken-early-mash.cfg", rule: "WindowPaysAtMostOnce" },
      { cfg: "weaponcadence-broken-double-notch.cfg", rule: "WindowPaysAtMostOnce" },
      { cfg: "weaponcadence-broken-double-snap.cfg", rule: "WindowPaysAtMostOnce" },
      { cfg: "weaponcadence-broken-detline-double.cfg", rule: "WindowPaysAtMostOnce" },
      { cfg: "weaponcadence-broken-beats-skip.cfg", rule: "WindowPaysAtMostOnce" },
      { cfg: "weaponcadence-broken-refund.cfg", rule: "RefundNeverExceedsSpend" },
    ],
    coverage: "references/weaponcadence-coverage.md",
    gaps: [
      "seconds, DPS ceilings, Overdrive Sprint fan, speed-tier charge multipliers, multi-charge Cluster scatter, Beat 3 speed scaling, Compound Interest streak cap and lane geometry are left to weapon_driver_test.gd, weapon_cadence_test.gd and weapon_envelope_test.gd",
    ],
  },
};

const num = (s) => Number(s.replaceAll(",", ""));

export function parseTlc(text) {
  const lines = text.split("\n").map((l) => l.trim());
  const rules = [];
  let temporal = false;
  let deadlock = false;
  const other = [];
  for (const line of lines) {
    const inv = line.match(/^Error: Invariant (\w+) is violated/);
    if (inv) rules.push(inv[1]);
    else if (/^Error: Temporal properties were violated/.test(line)) temporal = true;
    else if (/^Error: Deadlock reached/.test(line)) deadlock = true;
    else if (
      /^Error: (The behavior up to this point is|The following behavior constitutes a counter-example)/.test(
        line,
      )
    )
      continue;
    else if (/^Error:|Parse Error|^Semantic errors|^\*\*\* Errors/.test(line)) other.push(line);
  }
  const stats = text.match(
    /([\d,]+) states generated, ([\d,]+) distinct states found, ([\d,]+) states left on queue/g,
  );
  const last = stats
    ? stats[stats.length - 1].match(/([\d,]+) states generated, ([\d,]+) distinct states found/)
    : null;
  const generated = last ? num(last[1]) : null;
  const distinct = last ? num(last[2]) : null;
  const finished = /Model checking completed\. No error has been found\./.test(text);
  let outcome;
  if (other.length) outcome = "error";
  else if (rules.length || temporal || deadlock) outcome = "violated";
  else if (finished && distinct !== null) outcome = "clean";
  else outcome = "error";
  return {
    outcome,
    rules,
    temporal,
    deadlock,
    generated,
    distinct,
    error: other[0] ?? (outcome === "error" ? "no finished TLC run in the output" : null),
  };
}

export function timedOut(minutes) {
  return {
    outcome: "error",
    rules: [],
    temporal: false,
    deadlock: false,
    generated: null,
    distinct: null,
    error: `did not finish in ${minutes} min`,
  };
}

export function cfgRules(text) {
  const words = (key) => {
    const m = text.match(new RegExp(`^${key}\\b(.*)$`, "m"));
    return m ? m[1].trim().split(/\s+/).filter(Boolean) : [];
  };
  return { invariants: words("INVARIANTS"), properties: words("PROPERTIES") };
}

export function brokeRule(parsed, rules, rule) {
  if (parsed.outcome !== "violated") return false;
  if (rules.invariants.includes(rule)) return parsed.rules.includes(rule);
  if (rules.properties.includes(rule)) return parsed.temporal;
  return false;
}

export function syncCommit(text) {
  const line =
    text
      .split("\n")
      .map((l) => l.trim())
      .filter(Boolean)
      .pop() ?? "";
  return line.match(/\b[0-9a-f]{7,40}\b/)?.[0] ?? null;
}

export function coveredFiles(text) {
  return [...new Set(text.match(new RegExp(`${SRC}/[A-Za-z0-9_/]+\\.gd`, "g")) ?? [])].sort();
}

const states = (p) => (p.distinct === null ? "?" : p.distinct.toLocaleString("en-US"));
const said = (p) =>
  p.outcome === "clean"
    ? "no break"
    : p.outcome === "error"
      ? `stopped: ${p.error}`
      : `broke ${[...p.rules, ...(p.temporal ? ["a temporal property"] : []), ...(p.deadlock ? ["deadlock"] : [])].join(", ")}`;
const name = (cfg) => cfg.replace(/\.cfg$/, "");

export function buildReceipt({ head, real, plants, drift, gaps = [] }) {
  const caught = plants.length > 0 && plants.every((p) => brokeRule(p.parsed, p.rules, p.rule));
  const enough = (r) => r.minStates == null || (r.parsed.distinct ?? 0) >= r.minStates;
  const clean = real.length > 0 && real.every((r) => r.parsed.outcome === "clean" && enough(r));
  const synced = drift.sync !== null && drift.files.length === 0;
  const few = (r) =>
    r.parsed.outcome === "clean" && !enough(r)
      ? ` (fewer than the ${r.minStates.toLocaleString("en-US")} pinned)`
      : "";
  const realText = real
    .map(
      (r) =>
        `${r.label ? `${r.label}, ` : ""}${name(r.cfg)}: ${said(r.parsed)} in ${states(r.parsed)} distinct states${few(r)}`,
    )
    .join("; ");
  const plantText = plants
    .map(
      (p) =>
        `${name(p.cfg)} ${brokeRule(p.parsed, p.rules, p.rule) ? `broke ${p.rule}` : `did not break ${p.rule} (${said(p.parsed)})`} in ${states(p.parsed)} states`,
    )
    .join("; ");
  let measured = `${realText}; plants: ${plantText}`;
  if (gaps.length) measured += `; not checked: ${gaps.join("; ")}`;
  if (drift.sync === null) measured = `no sync commit on the model's coverage page; ${measured}`;
  else if (drift.files.length)
    measured = `model not synced: ${drift.files.join(", ")} changed since ${drift.sync}; ${measured}`;
  return { head, pass: clean && caught && synced, measured, plant_caught: caught };
}

function git(root, args) {
  const r = spawnSync("git", args, { cwd: root, encoding: "utf8" });
  if (r.status !== 0) throw new Error(`git ${args.join(" ")}: ${r.stderr.trim()}`);
  return r.stdout.trim();
}

export function findJar(arg) {
  const data = process.env.XDG_DATA_HOME || join(homedir(), ".local/share");
  return (
    [arg, process.env.TLA2TOOLS, join(data, "tlc", `tla2tools-${TLC_PIN}.jar`)].find(
      (p) => p && existsSync(p),
    ) ?? null
  );
}

function runTlc({ java, jar, workers, minutes, models, spec, cfg }) {
  const dir = mkdtempSync(join(tmpdir(), "model-receipt-"));
  try {
    copyFileSync(join(models, spec), join(dir, spec));
    copyFileSync(join(models, cfg), join(dir, cfg));
    const r = spawnSync(
      java,
      [
        "-XX:+UseParallelGC",
        "-cp",
        jar,
        "tlc2.TLC",
        "-workers",
        String(workers),
        "-metadir",
        join(dir, "states"),
        "-config",
        cfg,
        spec,
      ],
      {
        cwd: dir,
        encoding: "utf8",
        maxBuffer: 256 * 1024 * 1024,
        timeout: minutes * 60_000,
        killSignal: "SIGKILL",
      },
    );
    if (r.error?.code === "ETIMEDOUT" || r.signal === "SIGKILL") return timedOut(minutes);
    return parseTlc(`${r.stdout ?? ""}\n${r.stderr ?? ""}`);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

export function produce(id, { root, head, java, jar, workers, minutes, log = () => {} }) {
  const row = ROWS[id];
  const models = join(root, SKILL, "models");
  const page = readFileSync(join(root, SKILL, row.coverage), "utf8");
  const sync = syncCommit(page);
  const files =
    sync === null
      ? []
      : git(root, ["diff", "--name-only", sync, "--", ...coveredFiles(page)])
          .split("\n")
          .filter(Boolean);
  const check = (cfg) => {
    log(`${id}: TLC ${row.spec} ${cfg}`);
    return runTlc({ java, jar, workers, minutes, models, spec: row.spec, cfg });
  };
  const real = row.real.map((r) => ({ ...r, parsed: check(r.cfg) }));
  const plants = row.plants.map((p) => ({
    ...p,
    rules: cfgRules(readFileSync(join(models, p.cfg), "utf8")),
    parsed: check(p.cfg),
  }));
  return buildReceipt({ head, real, plants, drift: { sync, files }, gaps: row.gaps });
}

function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) args[argv[i].replace(/^--/, "")] = argv[i + 1];
  if (!args.out || (args.row && !ROWS[args.row])) {
    console.error(
      `usage: model-receipts.mjs --out <dir> [--row ${Object.keys(ROWS).join("|")}] [--jar <tla2tools.jar>] [--workers <n>] [--timeout-min <n>]`,
    );
    return 2;
  }
  const root = git(process.cwd(), ["rev-parse", "--show-toplevel"]);
  const dirty = git(root, ["status", "--porcelain", "--untracked-files=all", "--", SKILL, SRC]);
  if (dirty) {
    console.error(
      `model-receipts: uncommitted changes under ${SKILL} or ${SRC}; commit them first, the receipt names a commit:\n${dirty}`,
    );
    return 2;
  }
  const head = git(root, ["rev-parse", "HEAD"]);
  const java = process.env.JAVA || "java";
  const jar = findJar(args.jar);
  const javaOk = spawnSync(java, ["-version"], { encoding: "utf8" }).status === 0;
  if (!javaOk || !jar) {
    if (!javaOk)
      console.error(
        `model-receipts: no working Java (${java} -version failed); set JAVA or install a JDK`,
      );
    if (!jar)
      console.error(
        `model-receipts: no TLC jar; pass --jar, set TLA2TOOLS, or place tla2tools-${TLC_PIN}.jar in ~/.local/share/tlc/ (see .agents/skills/scrapkeep-verify-formal/SKILL.md)`,
      );
    return 2;
  }
  mkdirSync(args.out, { recursive: true });
  let ok = true;
  for (const id of args.row ? [args.row] : Object.keys(ROWS)) {
    const receipt = produce(id, {
      root,
      head,
      java,
      jar,
      workers: Number(args.workers ?? 4),
      minutes: Number(args["timeout-min"] ?? TIMEOUT_MIN),
      log: (m) => console.error(m),
    });
    const file = resolve(args.out, `${id}.json`);
    writeFileSync(file, JSON.stringify(receipt, null, 2) + "\n");
    console.log(`${id}: ${receipt.pass ? "PASS" : "FAIL"} ${receipt.measured} -> ${file}`);
    ok &&= receipt.pass;
  }
  return ok ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url))
  process.exit(main(process.argv.slice(2)));
