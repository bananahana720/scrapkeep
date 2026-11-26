import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  ALPHA_PACK_IDS,
  PACK_SPECS,
  applyRetryFeedback,
  buildEarGatePrompt,
  buildFallbackLyriaPrompt,
  buildGeminiEnv,
  buildStage1Prompt,
  buildUpdatedManifest,
  evaluateEarGate,
  extractJsonObject,
  parseArgs,
  runPipeline,
  sanitizeLyriaPrompt,
  updateStemHashesText,
  validateManifestInvariants,
} from "../music/lyria-tune.mjs";

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

test("parseArgs supports --pack, --all-alpha, flags, and rejects bad args", () => {
  const all = parseArgs(["--all-alpha", "--dry-run", "--ssh-host", "ahana"]);
  assert.deepEqual(all.packs, ALPHA_PACK_IDS);
  assert.equal(all.dryRun, true);
  assert.equal(all.sshHost, "ahana");

  const one = parseArgs([
    "--pack=roam_dig",
    "--analyze-only",
    "--ref-dir",
    "/tmp/refs",
    "--out-dir",
    "/tmp/work",
    "--max-attempts",
    "2",
  ]);
  assert.deepEqual(one.packs, ["roam_dig"]);
  assert.equal(one.analyzeOnly, true);
  assert.equal(one.maxAttempts, 2);

  assert.throws(() => parseArgs([]), /--pack/);
  assert.throws(() => parseArgs(["--unknown"]), /unknown argument/);
  assert.throws(() => parseArgs(["--pack", "roam_dig", "--max-attempts", "0"]), /max-attempts/);
});

test("buildGeminiEnv strips GEMINI_API_KEY unless explicit apiKey is provided", () => {
  const stripped = buildGeminiEnv(
    { PATH: "/usr/bin", GEMINI_API_KEY: "stale-key" },
    null,
    "/Users/test",
  );
  assert.equal("GEMINI_API_KEY" in stripped, false);
  assert.match(stripped.PATH, /\/opt\/homebrew\/bin/);
  assert.match(stripped.PATH, /\/Users\/test\/\.local\/bin/);

  const explicit = buildGeminiEnv({ PATH: "/usr/bin" }, "explicit-key", "/Users/test");
  assert.equal(explicit.GEMINI_API_KEY, "explicit-key");
});

test("buildStage1Prompt includes BPM, key, stem filenames, and MUSIC-GEMS constraints", () => {
  const prompt = buildStage1Prompt(
    PACK_SPECS.roam_highdraft,
    { cuts: "measured-beat-phase", timing_verified: false },
    ["/tmp/calm.drums.ogg", "/tmp/calm.bass.ogg", "/tmp/calm.other.ogg"],
  );
  assert.match(prompt, /roam_highdraft/);
  assert.match(prompt, /172 BPM/);
  assert.match(prompt, /calm\.drums\.ogg/);
  assert.match(prompt, /G1-G11/);
  assert.match(prompt, /R1\/R2/);
  assert.match(prompt, /STRICTLY INSTRUMENTAL ONLY/);
  assert.match(prompt, /\[0:00 - \.\.\.\]/);

  const euroPrompt = buildStage1Prompt(
    PACK_SPECS.euro_mind_final,
    { cuts: "measured-beat-phase", timing_verified: false },
    ["/tmp/main.drums.ogg", "/tmp/main.bass.ogg", "/tmp/main.other.ogg"],
  );
  assert.match(euroPrompt, /142 BPM/);
  assert.match(euroPrompt, /16-bar/);
});

test("extractJsonObject handles raw JSON, fenced JSON, and preamble text", () => {
  assert.deepEqual(extractJsonObject('{"pass": true, "has_vocals": false}'), {
    pass: true,
    has_vocals: false,
  });
  assert.deepEqual(
    extractJsonObject(
      'Here is the result:\n```json\n{"lyria_prompt": "[0:00 - 0:30] groove"}\n```',
    ),
    { lyria_prompt: "[0:00 - 0:30] groove" },
  );
  assert.deepEqual(extractJsonObject('Analysis: {"ok": 1, "nested": {"a": "}"}} trailing'), {
    ok: 1,
    nested: { a: "}" },
  });
  assert.throws(() => extractJsonObject("no json here"), /no JSON object/);
});

test("evaluateEarGate enforces instrumental, steady pulse, key/mood, no wubs, and BPM window", () => {
  const pass = evaluateEarGate(
    {
      has_vocals: false,
      steady_pulse: true,
      estimated_bpm: 171.5,
      fits_key_and_mood: true,
      has_r1_r2_wubs: false,
      pass: true,
      reasons: ["clean"],
      retry_adjustment: "",
    },
    PACK_SPECS.roam_dig,
  );
  assert.equal(pass.ok, true);
  assert.deepEqual(pass.failures, []);

  const halfTimePass = evaluateEarGate(
    {
      has_vocals: false,
      steady_pulse: true,
      estimated_bpm: 86,
      fits_key_and_mood: true,
      has_r1_r2_wubs: false,
      pass: true,
    },
    PACK_SPECS.roam_highdraft,
  );
  assert.equal(halfTimePass.ok, true);

  const fail = evaluateEarGate(
    {
      has_vocals: true,
      steady_pulse: false,
      estimated_bpm: 100,
      fits_key_and_mood: true,
      has_r1_r2_wubs: true,
      pass: false,
      retry_adjustment: "remove vocal chops and wubs",
    },
    PACK_SPECS.euro_waking_final,
  );
  assert.equal(fail.ok, false);
  assert.ok(fail.failures.length >= 4);
  assert.equal(fail.adjustment, "remove vocal chops and wubs");

  const retried = applyRetryFeedback("[0:00 - 1:30] euro track", fail.adjustment, 2);
  assert.match(retried, /attempt 2/);
  assert.match(retried, /remove vocal chops and wubs/);
  assert.match(buildEarGatePrompt(PACK_SPECS.euro_waking_final), /142 BPM/);
  assert.equal(
    sanitizeLyriaPrompt("Rhodes Pyramids-style Amen Reese"),
    "warm electric piano layered counter-melody crisp detuned sawtooth",
  );
  assert.match(buildFallbackLyriaPrompt(PACK_SPECS.roam_highdraft), /172 BPM/);
  assert.match(buildFallbackLyriaPrompt(PACK_SPECS.euro_mind_final), /142 BPM/);
});

test("validateManifestInvariants catches home paths, LUFS drift, and accepts clean Lyria manifests", () => {
  const existing = {
    format: 1,
    theme: "euro_waking_final",
    bank: "single",
    flat: true,
    rate: 44100,
    key: "D",
    key_offset: 0,
    stems: ["drums", "bass", "other"],
    level_db: 0,
    pre_roll: 4096,
    post_roll: 1024,
    loop_join: 441,
    clips: {},
  };
  const stage3 = {
    raw_sha256: "a".repeat(64),
    stretched_sha256: "b".repeat(64),
    bpm_before: 141.8,
    bpm_after: 142.0,
    stretch_mode: "rubberband:1.001410",
    stem_hashes: {
      drums: "1".repeat(64),
      bass: "2".repeat(64),
      other: "3".repeat(64),
      vocals: "4".repeat(64),
    },
    clips: {
      main: {
        source_bars: "5-20",
        source_start: 300000,
        take_start: 300000,
        bpm: 142,
        beat: 18634,
        bar: 74536,
        beats_per_bar: 4,
        bars: 16,
        entry: 4096,
        exit: 1196672,
        loop: true,
        loop_offset: 4096,
        loop_to_bar: 1,
        sample_count: 1196672,
        key: "D",
        key_offset: 0,
        files: { drums: "main.drums.ogg", bass: "main.bass.ogg", other: "main.other.ogg" },
        gain_db: -1.1,
        measured: { lufs: -16.02, true_peak: -1.65, note: "summed decoded Ogg stems" },
        seam: { wrap: 0.01, p999: 0.09 },
      },
    },
  };
  const updated = buildUpdatedManifest(
    existing,
    PACK_SPECS.euro_waking_final,
    { tonal_centre: "D minor" },
    stage3,
  );
  assert.deepEqual(validateManifestInvariants(updated, PACK_SPECS.euro_waking_final), []);

  const badHome = structuredClone(updated);
  badHome.sources.main.source = "/home/andrew/leak.wav";
  assert.ok(
    validateManifestInvariants(badHome, PACK_SPECS.euro_waking_final).some((e) =>
      /home path/.test(e),
    ),
  );

  const badLufs = structuredClone(updated);
  badLufs.clips.main.measured.lufs = -14.2;
  assert.ok(
    validateManifestInvariants(badLufs, PACK_SPECS.euro_waking_final).some((e) => /lufs/.test(e)),
  );
});

test("updateStemHashesText merges and sorts sha256 rows cleanly", () => {
  const a = "a".repeat(64);
  const b = "b".repeat(64);
  const c = "c".repeat(64);
  const initial = `${a}  euro_mind_final/main.drums.ogg\n${b}  roam_dig/calm.bass.ogg\n`;
  const updated = updateStemHashesText(initial, {
    "euro_mind_final/main.drums.ogg": c,
    "anthem_brindle/main.bass.ogg": a,
  });
  assert.equal(
    updated,
    `${a}  anthem_brindle/main.bass.ogg\n${c}  euro_mind_final/main.drums.ogg\n${b}  roam_dig/calm.bass.ogg\n`,
  );
});

test("runPipeline --dry-run runs offline with zero external calls and mx lyria delegates cleanly", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "lyria-tune-test-"));
  try {
    writeFileSync(path.join(tmp, "main.drums.ogg"), "stub");
    writeFileSync(path.join(tmp, "main.bass.ogg"), "stub");
    writeFileSync(path.join(tmp, "main.other.ogg"), "stub");
    let calls = 0;
    const opts = parseArgs([
      "--all-alpha",
      "--dry-run",
      "--ref-dir",
      tmp,
      "--out-dir",
      path.join(tmp, "out"),
    ]);
    const out = runPipeline(opts, {
      runCommand: () => {
        calls++;
        return "";
      },
    });
    assert.equal(calls, 0);
    assert.equal(out.results.length, 4);
    assert.equal(out.totalStemHashes, null);

    const mxRun = spawnSync(
      "bash",
      [
        path.join(REPO_ROOT, "scripts", "music", "mx"),
        "lyria",
        "--pack",
        "roam_highdraft",
        "--dry-run",
        "--ref-dir",
        tmp,
      ],
      { encoding: "utf8" },
    );
    assert.equal(mxRun.status, 0, mxRun.stderr);
    const parsed = JSON.parse(mxRun.stdout);
    assert.equal(parsed.results.length, 1);
    assert.equal(parsed.results[0].pack, "roam_highdraft");
    assert.equal(parsed.results[0].dryRun, true);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
