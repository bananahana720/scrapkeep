import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
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
  missingInputs,
  oggLongestPage,
  pageFindings,
  run,
  missingCues,
  parseArgs,
  parseEbur128,
  report,
  seamStep,
  specialCues,
  staleAgainstManifest,
  stemHashMismatches,
  wiredSet,
  writeStemHashes,
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
  for (const id of [
    "splitter_break_split",
    "linker_spawn",
    "stinger_boss_defeated",
    "hype_drop",
    "euro-mind-final",
    "brindle",
  ])
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
    [
      "sound hype_drop has no audio in the game or the render folders",
      "track mind-final rendered (mind-final-s2701.mp3) but not in the game",
    ],
  );
  assert.ok(bankIds('"a_b": 1, "c"').has("a_b"));
});

test("cue findings need the game's sound bank and feed the placeholder gate", () => {
  const none = project({ "src/core/park_defs.gd": "" });
  const game = project({
    "src/presentation/sfx_bank.gd": '"boss_arena_in" "boss_phase" "stinger_boss_defeated"',
  });
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

test("a wrong project or music path never reads as a pass", () => {
  const empty = project({ "README.md": "" });
  try {
    const args = parseArgs([
      "--project",
      empty,
      "--music",
      path.join(empty, "nope"),
      "--cues-only",
    ]);
    assert.deepEqual(
      missingInputs(args, []).map((f) => f.what),
      ["no src/presentation/sfx_bank.gd; cues not checked", "music folder not found"],
    );
    assert.equal(missingInputs({ ...args, cuesOnly: false }, [{ clips: {} }]).length, 3);
    assert.notEqual(run(args).findings.length, 0);
  } finally {
    rmSync(empty, { recursive: true, force: true });
  }
});

test("parseEbur128 reads the summary, not the running lines", () => {
  const stderr =
    "[Parsed_ebur128_0] t: 1 M: -20 S: -20 I: -19.0 LUFS\nSummary:\n\n  Integrated loudness:\n    I:         -16.2 LUFS\n\n  True peak:\n    Peak:       -2.9 dBFS\n";
  assert.deepEqual(parseEbur128(stderr), { lufs: -16.2, truePeak: -2.9 });
  assert.deepEqual(parseEbur128("nothing"), { lufs: null, truePeak: null });
});

test("seamStep passes a whole-cycle loop and catches a wrap that clicks", () => {
  const loop = (frames, cut = frames) => {
    const s = new Float32Array(frames * 2);
    for (let f = 0; f < frames; f++)
      s[f * 2] = s[f * 2 + 1] = Math.sin((2 * Math.PI * f) / 48) * 0.5;
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

test(
  "judge measures loudness, true peak and seams through ffmpeg",
  { skip: !hasFfmpeg() && "no ffmpeg" },
  () => {
    const dir = project({
      // A full-scale stereo sine reads 0 LUFS, so amplitude 0.158 reads about -16.
      "on-target-loop.wav": sineWav(48000 * 12, 0.158),
      "loud-click-loop.wav": sineWav(48000 * 12 + 12, 0.5),
    });
    try {
      const good = judge("on-target", decode(path.join(dir, "on-target-loop.wav")), 48000, {
        loop: true,
      });
      assert.deepEqual(good.found, []);
      assert.ok(Math.abs(good.row.lufs + 16) < 0.3, String(good.row.lufs));
      const bad = judge("loud", decode(path.join(dir, "loud-click-loop.wav")), 48000, {
        loop: true,
      });
      assert.deepEqual(bad.found.map((f) => f.kind).sort(), ["loudness", "seam"]);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  },
);

// A stale Ogg under the right file name is the failure these tests plant (the zone packs' Oggs were
// 17 days older than their manifests and every export played them). Each check runs on a good pack
// first, so a zero is only trusted after the same check has failed on the planted one.
test("a clip whose length or loudness differs from its manifest is stale", () => {
  const t = { name: "spillway/calm", frames: 988672, measuredLufs: -16 };
  assert.deepEqual(staleAgainstManifest(t, 988672, -15.9), []);
  assert.deepEqual(
    staleAgainstManifest(t, 988673, -16).map((f) => f.kind),
    ["stale"],
  );
  assert.deepEqual(
    staleAgainstManifest(t, 988672, -14.2).map((f) => f.kind),
    ["stale"],
  );
  assert.deepEqual(
    staleAgainstManifest({ name: "old/calm", frames: null, measuredLufs: null }, 5, -3),
    [],
  );
});

test("STEMS.sha256 rejects a stale, an unlisted and a re-encoded stem and names each", () => {
  const dir = project({
    "spillway/calm.drums.ogg": "fresh drums",
    "spillway/calm.bass.ogg": "fresh bass",
    "spillway/calm.other.ogg": "fresh other",
  });
  const named = ["spillway/calm.drums.ogg", "spillway/calm.bass.ogg", "spillway/calm.other.ogg"];
  const list = path.join(dir, "STEMS.sha256");
  try {
    assert.equal(stemHashMismatches(list, dir, named), null, "no list is not a pass");
    assert.equal(writeStemHashes(list, dir, named), 3);
    assert.deepEqual(stemHashMismatches(list, dir, named), [], "the good pack passes");
    writeFileSync(path.join(dir, "spillway/calm.bass.ogg"), "an older mix under the same name");
    const bad = stemHashMismatches(list, dir, named);
    assert.deepEqual(
      bad.map((r) => r.file),
      ["spillway/calm.bass.ogg"],
      "the planted stale Ogg is named and nothing else",
    );
    assert.match(bad[0].why, /sha256 differs/);
    const unlisted = stemHashMismatches(list, dir, [...named, "spillway/build.drums.ogg"]);
    assert.deepEqual(
      unlisted.map((r) => r.file),
      ["spillway/calm.bass.ogg"],
      "a named file that is not on disk is not this check's finding",
    );
    writeFileSync(path.join(dir, "spillway/build.drums.ogg"), "new, never hashed");
    assert.ok(
      stemHashMismatches(list, dir, [...named, "spillway/build.drums.ogg"]).some(
        (r) => r.file === "spillway/build.drums.ogg" && /not listed/.test(r.why),
      ),
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// The fixture packs are Ogg Vorbis, which an ffmpeg built without libvorbis (Homebrew's) cannot write.
const hasLibvorbis = () =>
  hasFfmpeg() &&
  /libvorbis/.test(String(spawnSync("ffmpeg", ["-hide_banner", "-encoders"]).stdout));

test(
  "the gate flags a stale pack and an unhashed one, and passes the good pack",
  { skip: !hasLibvorbis() && "no ffmpeg with libvorbis" },
  () => {
    const dir = mkdtempSync(path.join(os.tmpdir(), "audio-gate-stale-"));
    const music = path.join(dir, "assets/music_ace/zone");
    mkdirSync(music, { recursive: true });
    const tone = (file, seconds, level) =>
      spawnSync("ffmpeg", [
        "-v",
        "error",
        "-y",
        "-f",
        "lavfi",
        "-i",
        `sine=frequency=440:duration=${seconds}:sample_rate=44100`,
        "-af",
        `volume=${level}`,
        "-ac",
        "2",
        "-c:a",
        "libvorbis",
        file,
      ]);
    try {
      for (const stem of ["drums", "bass", "other"])
        tone(path.join(music, `calm.${stem}.ogg`), 12, 0.02);
      const manifest = {
        theme: "zone",
        rate: 44100,
        level_db: 0,
        stems: ["drums", "bass", "other"],
        clips: {
          calm: {
            files: { drums: "calm.drums.ogg", bass: "calm.bass.ogg", other: "calm.other.ogg" },
          },
        },
      };
      const write = (clip) =>
        writeFileSync(
          path.join(music, "manifest.json"),
          JSON.stringify({ ...manifest, clips: { calm: { ...manifest.clips.calm, ...clip } } }),
        );
      write({});
      const base = parseArgs(["--project", dir]);
      const kinds = () =>
        run(base)
          .findings.filter((f) => f.kind === "stale" || f.where.endsWith("STEMS.sha256"))
          .map((f) => f.kind);
      assert.deepEqual(kinds(), ["unchecked"], "no hash list: unchecked, never a pass");
      writeStemHashes(
        path.join(dir, "assets/music_ace", "STEMS.sha256"),
        path.join(dir, "assets/music_ace"),
        ["zone/calm.drums.ogg", "zone/calm.bass.ogg", "zone/calm.other.ogg"],
      );
      const measured = run(base).rows[0].lufs;
      write({ measured: { lufs: measured } });
      assert.deepEqual(kinds(), [], "the good pack: hashes match, loudness matches its manifest");
      write({ measured: { lufs: measured + 2 } });
      assert.deepEqual(kinds(), ["stale"], "a manifest cut from a louder mix flags the clip");
      write({ measured: { lufs: measured } });
      tone(path.join(music, "calm.bass.ogg"), 12, 0.02);
      assert.ok(kinds().includes("stale"), "a re-encoded stem differs from the hash list");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  },
);

// A minimal Ogg Vorbis byte stream: an identification page, then one page per granule position.
function oggOf(granules, rate = 44100) {
  const page = (granule, body) => {
    const head = Buffer.alloc(27 + 1);
    head.write("OggS", 0, "latin1");
    head.writeBigInt64LE(BigInt(granule), 6);
    head[26] = 1;
    head[27] = body.length;
    return Buffer.concat([head, body]);
  };
  const id = Buffer.alloc(30);
  id.write("\x01vorbis", 0, "latin1");
  id[11] = 2;
  id.writeUInt32LE(rate, 12);
  return Buffer.concat([
    page(0, id),
    ...granules.map((g) => page(g, Buffer.from("OggS is not a page here"))),
  ]);
}

test("a packed Ogg stored in one-second pages is named, a short-paged one passes", () => {
  const long = oggOf([44100, 88200, 132300]);
  const short = oggOf(Array.from({ length: 150 }, (_, i) => (i + 1) * 882));
  assert.equal(oggLongestPage(long), 1);
  assert.equal(oggLongestPage(short), 0.02);
  assert.equal(oggLongestPage(Buffer.from("fresh drums")), null, "not an Ogg is not judged");
  assert.equal(
    oggLongestPage(long.subarray(0, 40)),
    null,
    "a file cut off inside its first page is not judged, and does not throw",
  );
  const manifest = (pack, files) => ({ dir: pack, clips: { calm: { files } } });
  const dir = project({
    "assets/music_ace/spillway/calm.drums.ogg": short,
    "assets/music_ace/spillway/calm.bass.ogg": long,
  });
  try {
    const found = pageFindings(dir, [
      manifest("spillway", {
        drums: "calm.drums.ogg",
        bass: "calm.bass.ogg",
        other: "calm.other.ogg",
      }),
    ]);
    assert.deepEqual(
      found.map((f) => [f.kind, f.where]),
      [["pages", "spillway/calm.bass.ogg"]],
      "the long-paged stem is named; the short one and the absent one are not",
    );
    assert.match(found[0].what, /repage\.py apply/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
