import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  bankIds,
  cueFindings,
  cueKey,
  cueList,
  decode,
  hasFfmpeg,
  judge,
  missingCues,
  parseArgs,
  parseEbur128,
  report,
  seamStep,
  specialCues,
  wiredSet,
} from "./audio-gate.mjs";
import { scan } from "./placeholder-gate.mjs";

function project(files) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "audio-gate-"));
  for (const [rel, data] of Object.entries(files)) {
    mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    writeFileSync(path.join(dir, rel), data);
  }
  return dir;
}

// 16-bit stereo PCM WAV of a sine, frames long.
function sineWav(frames, amplitude, hz = 1000, rate = 48000) {
  const data = Buffer.alloc(frames * 4);
  for (let f = 0; f < frames; f++) {
    const v = Math.round(Math.sin((2 * Math.PI * hz * f) / rate) * amplitude * 32767);
    data.writeInt16LE(v, f * 4);
    data.writeInt16LE(v, f * 4 + 2);
  }
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
  return Buffer.concat([head, data]);
}

test("cueKey makes files, theme folders and clip ids comparable", () => {
  assert.equal(cueKey("euro-brindle-p3-s2801.wav"), "euro_brindle_p3");
  assert.equal(cueKey("boss-mind-s2402-129bpm.mp3"), "boss_mind");
  assert.equal(cueKey("brindle-p2-furnace"), "brindle_p2_furnace");
  assert.equal(cueKey("foreman_presence.wav"), "foreman_presence");
});

test("the cue list covers all 17 special WAVs and the boss cues", () => {
  assert.equal(specialCues().length, 17);
  const ids = cueList().map((c) => c.id);
  for (const id of ["splitter_break_split", "linker_spawn", "stinger_boss_defeated", "hype_drop", "euro-mind-final", "brindle"])
    assert.ok(ids.includes(id), id);
});

test("a cue is present when the bank, a theme or a file can play it", () => {
  const wired = wiredSet({
    bank: 'const TRIM_DB := {"boss_phase": -4.0}\n\tmatch id:\n\t\t"foreman_tell":\n',
    manifests: [{ theme: "brindle", clips: { calm: {} } }, { theme: "euro_waking_final" }],
    files: ["/x/assets/sfx/linker_break.ogg"],
  });
  const cues = [
    { id: "boss_phase", type: "sound", group: "boss" },
    { id: "foreman_tell", type: "sound", group: "special" },
    { id: "linker_break", type: "sound", group: "special" },
    { id: "brindle", type: "track", group: "boss" },
    { id: "euro-waking-final", type: "track", group: "boss" },
    { id: "hype_drop", type: "sound", group: "boss" },
    { id: "mind-final", type: "track", group: "boss" },
  ];
  const missing = missingCues(cues, wired, ["/renders/mind-final-s2701.mp3"]);
  assert.deepEqual(
    missing.map((f) => f.what),
    ["sound hype_drop has no audio in the game or the render folders", "track mind-final rendered (mind-final-s2701.mp3) but not in the game"],
  );
  assert.ok(bankIds('"a_b": 1, "c"').has("a_b"));
});

test("cue findings need the game's sound bank and feed the placeholder gate", () => {
  const none = project({ "src/core/park_defs.gd": "" });
  const game = project({ "src/presentation/sfx_bank.gd": '"boss_arena_in" "boss_phase" "stinger_boss_defeated"' });
  try {
    assert.deepEqual(cueFindings(none), []);
    assert.equal(cueFindings(game).length, cueList().length - 3);
    const audio = scan(game).filter((f) => f.kind === "audio");
    assert.equal(audio.length, cueList().length - 3);
  } finally {
    rmSync(none, { recursive: true, force: true });
    rmSync(game, { recursive: true, force: true });
  }
});

test("parseEbur128 reads the summary, not the running lines", () => {
  const stderr = "[Parsed_ebur128_0] t: 1 M: -20 S: -20 I: -19.0 LUFS\nSummary:\n\n  Integrated loudness:\n    I:         -16.2 LUFS\n\n  True peak:\n    Peak:       -2.9 dBFS\n";
  assert.deepEqual(parseEbur128(stderr), { lufs: -16.2, truePeak: -2.9 });
  assert.deepEqual(parseEbur128("nothing"), { lufs: null, truePeak: null });
});

test("seamStep passes a whole-cycle loop and catches a wrap that clicks", () => {
  const loop = (frames, cut = frames) => {
    const s = new Float32Array(frames * 2);
    for (let f = 0; f < frames; f++) s[f * 2] = s[f * 2 + 1] = Math.sin((2 * Math.PI * f) / 48) * 0.5;
    return { s, cut };
  };
  const clean = loop(4800);
  assert.equal(seamStep(clean.s, 4800, 0).ok, true);
  const click = loop(4800 + 12);
  assert.equal(seamStep(click.s, 4812, 0).ok, false);
  // A loop that wraps to a later loop point is judged from that point.
  assert.equal(seamStep(clean.s, 4800, 480).ok, true);
});

test("parseArgs takes repeated music folders and a loop pattern", () => {
  const args = parseArgs(["--music", "a", "--music=b", "--loops", "seam", "--json", "--cues-only"]);
  assert.deepEqual(args.music, [path.resolve("a"), path.resolve("b")]);
  assert.ok(args.loops.test("x-seam.wav"));
  assert.equal(args.json && args.cuesOnly, true);
  assert.throws(() => parseArgs(["--nope"]));
});

test("report lists each kind and never passes with findings", () => {
  assert.equal(report([]), "audio gate: PASS");
  const text = report([{ kind: "unchecked", where: "ffmpeg", what: "not found" }]);
  assert.match(text, /Not checked: 1/);
  assert.match(text, /FAIL/);
});

test("judge measures loudness, true peak and seams through ffmpeg", { skip: !hasFfmpeg() && "no ffmpeg" }, () => {
  const dir = project({
    // A full-scale stereo sine reads 0 LUFS, so amplitude 0.158 reads about -16.
    "on-target-loop.wav": sineWav(48000 * 12, 0.158),
    "loud-click-loop.wav": sineWav(48000 * 12 + 12, 0.5),
  });
  try {
    const good = judge("on-target", decode(path.join(dir, "on-target-loop.wav")), 48000, { loop: true });
    assert.deepEqual(good.found, []);
    assert.ok(Math.abs(good.row.lufs + 16) < 0.3, String(good.row.lufs));
    const bad = judge("loud", decode(path.join(dir, "loud-click-loop.wav")), 48000, { loop: true });
    assert.deepEqual(bad.found.map((f) => f.kind).sort(), ["loudness", "seam"]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
