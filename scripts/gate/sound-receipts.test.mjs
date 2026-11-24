import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

import { buildReceipt as recipesReceipt, cleanHead, produce } from "./sound-recipes-receipt.mjs";
import {
  PLANT_RATE,
  buildReceipt as levelsReceipt,
  measure,
  measureAsync,
  parseArgs as parseLevelsArgs,
  runPlants,
  tone,
} from "./sound-levels-receipt.mjs";
import { hasFfmpeg } from "../audio-gate.mjs";
import { receiptRow } from "../world1-bands.mjs";

const HEAD = "3adc2fd0e8563b13c87f921b2ae85763467fec03";
const ffmpeg = hasFfmpeg();

// --- sound-own-recipes ----------------------------------------------------------------------

const recipesRow = {
  id: "sound-own-recipes",
  plant: "a cue with its recipe removed must be counted",
  producer: "x",
};
const cue = (name, own = true, plays = own ? name : "slam_boom") =>
  `CUE ${JSON.stringify({ cue: name, own, how: own ? "own sound" : "plays its row's shared sound, not a sound of its own", plays, facts: 1, fact: `ROWS:${name}` })}`;
const recipesLog = ({
  n = 40,
  short = [],
  plant = true,
  fail = 0,
  checks = 5,
  summary = null,
} = {}) => {
  const before = short.length;
  const total = n + short.length;
  return [
    ...Array.from(
      { length: checks },
      (_, i) => `[check ${i}] detail -> ${i < fail ? "FAIL" : "PASS"}`,
    ),
    ...Array.from({ length: n }, (_, i) => cue(`cue_${i}`)),
    ...short.map((c) => cue(c, false)),
    ...(plant
      ? [
          `PLANT ${JSON.stringify({ fact: "ROWS:cue_0", cue: "plant_recipe_removed", before, after: before + 1, caught: true })}`,
        ]
      : []),
    `SUMMARY ${JSON.stringify(summary ?? { facts: 60, cues: total, pinned: total, short: before })}`,
  ].join("\n");
};

test("recipes: every world 1 cue plays its own sound and the plant was counted, so the done table passes it", () => {
  const r = recipesReceipt(recipesLog(), HEAD);
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.match(
    r.measured,
    /^all 40 world 1 cues play a sound of their own; plant: ROWS:cue_0's recipe removed read 0 -> 1/,
  );
  assert.deepEqual(receiptRow(recipesRow, r, HEAD), { measured: r.measured, pass: true });
});

test("recipes: a cue with no sound of its own fails the receipt and names what plays in its place", () => {
  const r = recipesReceipt(recipesLog({ short: ["flood_drop", "line_load"] }), HEAD);
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, true);
  assert.match(
    r.measured,
    /^2 of 42 world 1 cues play no sound of their own: flood_drop -> slam_boom, line_load -> slam_boom/,
  );
});

test("recipes: no PLANT line, or a plant that did not raise the count by one, voids the receipt", () => {
  const none = recipesReceipt(recipesLog({ plant: false }), HEAD);
  assert.equal(none.plant_caught, false);
  assert.match(
    receiptRow(recipesRow, none, HEAD).measured,
    /^void, the planted fault was not shown caught/,
  );
  const flat = recipesLog().replace(/"after":1/, '"after":0');
  assert.equal(recipesReceipt(flat, HEAD).plant_caught, false);
});

test("recipes: cues that vanish against the SUMMARY or the pin fail; a failed check and an empty log fail", () => {
  const vanished = recipesReceipt(
    recipesLog({ summary: { facts: 60, cues: 182, pinned: 182, short: 0 } }),
    HEAD,
  );
  assert.equal(vanished.pass, false);
  assert.match(
    vanished.measured,
    /^40 CUE lines, SUMMARY counted 182, pinned 182: world 1 cues appeared or vanished/,
  );
  assert.equal(
    recipesReceipt(recipesLog({ summary: { facts: 60, cues: 40, pinned: 182, short: 0 } }), HEAD)
      .pass,
    false,
  );
  assert.equal(recipesReceipt(recipesLog({ fail: 1 }), HEAD).pass, false);
  assert.equal(recipesReceipt(recipesLog({ checks: 2 }), HEAD).pass, false);
  assert.equal(recipesReceipt("", HEAD).pass, false);
  assert.match(recipesReceipt("", HEAD).measured, /^no CUE or SUMMARY lines/);
});

test("recipes: the producer takes the head from git and refuses a checkout with uncommitted tracked changes", () => {
  const repo = mkdtempSync(path.join(os.tmpdir(), "sound-recipes-git-"));
  const git = (...args) =>
    spawnSync("git", ["-c", "user.name=t", "-c", "user.email=t@t", ...args], {
      cwd: repo,
      encoding: "utf8",
    });
  git("init", "-q");
  writeFileSync(path.join(repo, "a.txt"), "one");
  git("add", "a.txt");
  git("commit", "-q", "-m", "one");
  const head = git("rev-parse", "HEAD").stdout.trim();
  let ran = 0;
  const r = produce({
    cwd: repo,
    run: () => {
      ran += 1;
      return recipesLog();
    },
  });
  assert.equal(r.head, head);
  assert.equal(r.pass, true);
  writeFileSync(path.join(repo, "a.txt"), "two");
  assert.throws(
    () =>
      produce({
        cwd: repo,
        run: () => {
          ran += 1;
          return recipesLog();
        },
      }),
    /refusing: uncommitted changes/,
  );
  assert.equal(ran, 1, "a dirty checkout never runs the test");
  git("checkout", "-q", "--", "a.txt");
  // An untracked file elsewhere is fine; one under the game's src or assets is refused (an uncommitted rendered sound
  // would count as a cue's own sound for a head that lacks it).
  writeFileSync(path.join(repo, "notes.txt"), "x");
  assert.equal(cleanHead(repo), head);
  mkdirSync(path.join(repo, "sketches/core-loop/assets/audio/sfx"), { recursive: true });
  writeFileSync(path.join(repo, "sketches/core-loop/assets/audio/sfx/new.wav"), "x");
  assert.throws(() => cleanHead(repo), /refusing: untracked files under the game's src or assets/);
  assert.throws(
    () =>
      produce({
        cwd: repo,
        run: () => {
          ran += 1;
          return recipesLog();
        },
      }),
    /refusing: untracked/,
  );
  assert.equal(ran, 1);
});

// --- sound-levels ---------------------------------------------------------------------------

const levelsRow = { id: "sound-levels", plant: "a stem 6 LU too loud must fail", producer: "x" };
const caught = { caught: true, what: "plants caught" };
const row = (name, lufs = -16, truePeak = -2, seam = true) => ({
  name,
  seconds: 60,
  lufs,
  truePeak,
  ...(seam ? { seamWrap: 0.001, seamP999: 0.01 } : {}),
});

test("levels: no stems on this machine is no data, never a pass", () => {
  const r = levelsReceipt({ head: HEAD, clips: 256, present: 0, plant: caught });
  assert.equal(r.pass, false);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /^no data: 0 of 256 music clips have their stems on this machine/);
  assert.equal(
    levelsReceipt({
      head: HEAD,
      clips: 3,
      present: 3,
      ffmpeg: false,
      plant: null,
    }).measured.startsWith("no data: ffmpeg not found"),
    true,
  );
  assert.match(
    levelsReceipt({ head: HEAD, clips: 0, present: 0, plant: caught }).measured,
    /^no data: no assets\/music_ace manifest/,
  );
});

test("levels: every clip measured inside the limits, plant caught: passes in the done table", () => {
  const r = levelsReceipt({
    head: HEAD,
    clips: 2,
    present: 2,
    rows: [row("a/x"), row("b/y", -15.8, -1.4)],
    found: [],
    plant: caught,
  });
  assert.equal(r.pass, true);
  assert.match(
    r.measured,
    /^2 of 2 music clips measured: true peak on 2 \(at most -1.4 dBTP\), loudness on 2 \(-16 to -15.8 LUFS\) \(0 under 10 s, skipped by EBU R 128 programme loudness\), seams on 2 loops; every check that ran is inside the limits/,
  );
  assert.deepEqual(receiptRow(levelsRow, r, HEAD), { measured: r.measured, pass: true });
});

test("levels: a finding, a missing clip or an uncaught plant does not pass", () => {
  const loud = levelsReceipt({
    head: HEAD,
    clips: 1,
    present: 1,
    rows: [row("a/x", -10)],
    found: [{ kind: "loudness", where: "a/x", what: "-10 LUFS" }],
    plant: caught,
  });
  assert.equal(loud.pass, false);
  assert.match(loud.measured, /1 over the limits .*loudness a\/x -10 LUFS/);
  const partial = levelsReceipt({
    head: HEAD,
    clips: 2,
    present: 1,
    rows: [row("a/x")],
    found: [],
    plant: caught,
  });
  assert.equal(partial.pass, false);
  assert.match(partial.measured, /1 clip\(s\) not measured/);
  const blind = levelsReceipt({
    head: HEAD,
    clips: 1,
    present: 1,
    rows: [row("a/x")],
    found: [],
    plant: { caught: false, what: "plants not caught: loudness" },
  });
  assert.equal(blind.plant_caught, false);
  assert.match(receiptRow(levelsRow, blind, HEAD).measured, /^void/);
});

test(
  "levels: the plants run through audio-gate's own judge, and a judge that sees nothing is not caught",
  { skip: !ffmpeg && "ffmpeg not installed" },
  () => {
    const real = runPlants();
    assert.equal(real.caught, true, real.what);
    const blind = runPlants({ judgeFn: (name) => ({ row: { name }, found: [] }) });
    assert.equal(blind.caught, false);
    assert.match(blind.what, /loudness, peak, seam, short_peak/);
  },
);

// A WAV of a float stereo buffer, 16-bit, so ffmpeg reads it as a stem.
function wav(file, samples, rate) {
  const data = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i++)
    data.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767))), i * 2);
  const head = Buffer.alloc(44);
  head.write("RIFF", 0);
  head.writeUInt32LE(36 + data.length, 4);
  head.write("WAVEfmt ", 8);
  head.writeUInt32LE(16, 16);
  head.writeUInt16LE(1, 20);
  head.writeUInt16LE(2, 22);
  head.writeUInt32LE(rate, 24);
  head.writeUInt32LE(rate * 4, 28);
  head.writeUInt16LE(4, 32);
  head.writeUInt16LE(16, 34);
  head.write("data", 36);
  head.writeUInt32LE(data.length, 40);
  writeFileSync(file, Buffer.concat([head, data]));
}

test(
  "levels: a fixture pack measured end to end; a stem 6 LU too loud fails it",
  { skip: !ffmpeg && "ffmpeg not installed" },
  () => {
    const project = mkdtempSync(path.join(os.tmpdir(), "sound-levels-"));
    const pack = path.join(project, "assets/music_ace/fixture");
    mkdirSync(pack, { recursive: true });
    // amp 0.25 cosine at 240 Hz meters near -12.9 LUFS; level_db brings the mix to the target.
    const stem = tone(12, PLANT_RATE, 240, 0.25);
    wav(path.join(pack, "a.wav"), stem, PLANT_RATE);
    const manifest = (level) => ({
      theme: "fixture",
      level_db: level,
      clips: { main: { rate: PLANT_RATE, files: { full: "a.wav" }, loop: true } },
    });
    writeFileSync(path.join(pack, "manifest.json"), JSON.stringify(manifest(-3.1)));
    const ok = measure(project);
    assert.match(ok.measured, /^1 of 1 music clips measured/);
    assert.equal(ok.pass, true, ok.measured);
    writeFileSync(path.join(pack, "manifest.json"), JSON.stringify(manifest(-3.1 + 6)));
    const loud = measure(project);
    assert.equal(loud.pass, false);
    assert.match(loud.measured, /loudness fixture\/main/);
  },
);

test("levels: parseArgs accepts --out and --jobs in both forms", () => {
  assert.deepEqual(parseLevelsArgs(["--out", "a.json", "--jobs=4"]), { out: "a.json", jobs: 4 });
  assert.deepEqual(parseLevelsArgs(["--out=b.json", "--jobs", "2"]), { out: "b.json", jobs: 2 });
  assert.throws(() => parseLevelsArgs(["--jobs=0"]));
  assert.throws(() => parseLevelsArgs(["--nope"]));
});

test(
  "levels: measureAsync matches measure bit-for-bit across multiple clips and workers",
  { skip: !ffmpeg && "ffmpeg not installed" },
  async () => {
    const project = mkdtempSync(path.join(os.tmpdir(), "sound-levels-async-"));
    try {
      const pack = path.join(project, "assets/music_ace/fixture");
      mkdirSync(pack, { recursive: true });
      wav(path.join(pack, "a.wav"), tone(12, PLANT_RATE, 240, 0.25), PLANT_RATE);
      wav(path.join(pack, "b.wav"), tone(11, PLANT_RATE, 240, 0.25), PLANT_RATE);
      wav(path.join(pack, "c.wav"), tone(2, PLANT_RATE, 240, 0.25), PLANT_RATE);
      const write = (level) =>
        writeFileSync(
          path.join(pack, "manifest.json"),
          JSON.stringify({
            theme: "fixture",
            level_db: level,
            clips: {
              a: { rate: PLANT_RATE, files: { full: "a.wav" }, loop: true },
              b: { rate: PLANT_RATE, files: { full: "b.wav" }, loop: true },
              c: { rate: PLANT_RATE, files: { full: "c.wav" }, loop: false },
            },
          }),
        );
      write(-3.1);
      const syncOk = measure(project);
      const asyncOk = await measureAsync(project, { jobs: 3 });
      assert.deepEqual(asyncOk, syncOk);
      assert.equal(asyncOk.pass, true, asyncOk.measured);

      write(-3.1 + 6);
      const syncLoud = measure(project);
      const asyncLoud = await measureAsync(project, { jobs: 3 });
      assert.deepEqual(asyncLoud, syncLoud);
      assert.equal(asyncLoud.pass, false);
    } finally {
      rmSync(project, { recursive: true, force: true });
    }
  },
);
