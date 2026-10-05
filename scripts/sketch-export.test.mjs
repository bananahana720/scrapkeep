import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import {
  bootFailures,
  defaultStemsFrom,
  missingStems,
  missingStemsMessage,
  parseArgs,
  parsePresets,
  proofPresetDrift,
  releaseGateFailures,
  winProofFailures,
} from "./sketch-export.mjs";

const manifest = {
  stems: ["drums", "bass"],
  clips: {
    calm: { files: { drums: "calm.drums.ogg", bass: "calm.bass.ogg" } },
    open: { files: { drums: "open.drums.ogg", bass: "open.bass.ogg" } },
  },
};

test("a manifest whose stems all exist reports none missing", () => {
  assert.deepEqual(missingStems(manifest, "/d", () => true), []);
});

test("a stem file the manifest names but the folder lacks is reported", () => {
  const present = new Set(["/d/calm.drums.ogg", "/d/calm.bass.ogg", "/d/open.drums.ogg"]);
  assert.deepEqual(missingStems(manifest, "/d", (file) => present.has(file)), ["open.bass.ogg"]);
});

test("a clip with no file named for a stem is reported", () => {
  const broken = { stems: ["drums"], clips: { calm: { files: {} } } };
  assert.equal(missingStems(broken, "/d", () => true).length, 1);
});

test("boot output passes only with a ready ACE_CHECK and no error line", () => {
  assert.deepEqual(bootFailures("ACE_CHECK ready=true clips=9 streams=27 missing=\n"), []);
  assert.equal(bootFailures("SCRIPT ERROR: x\nACE_CHECK ready=true clips=9 streams=27").length, 1);
  assert.equal(bootFailures("ACE_CHECK ready=false clips=0 streams=0 missing=/x").length, 1);
  assert.equal(bootFailures("nothing").length, 1);
});

test("release gate output passes only with exit 0 and a PASS line", () => {
  assert.deepEqual(releaseGateFailures("[skip] x\nrelease_gate_placeholder_test: PASS (3 checks)\n", 0), []);
});

test("release gate FAIL lines are returned", () => {
  const out = [
    "[placeholder row 3] The Dig: placeholder on the gorge -> FAIL",
    "[placeholder row 4] The High Cables: placeholder on the reach -> FAIL",
    "release_gate_placeholder_test: FAIL (2 of 5 checks)",
  ].join("\n");
  assert.equal(releaseGateFailures(out, 1).length, 3);
});

test("release gate with status 1 fails even beside a PASS line", () => {
  assert.equal(releaseGateFailures("release_gate_placeholder_test: PASS (3 checks)\n", 1).length, 1);
  assert.equal(releaseGateFailures("nothing", 0).length, 1);
});

test("parseArgs reads both --stems-from forms, defaults to null and rejects others", () => {
  assert.deepEqual(parseArgs([]), { stemsFrom: null, winProof: false });
  assert.deepEqual(parseArgs(["--stems-from=/a"]), {
    stemsFrom: "/a",
    winProof: false,
  });
  assert.deepEqual(parseArgs(["--stems-from", "/b"]), {
    stemsFrom: "/b",
    winProof: false,
  });
  assert.throws(() => parseArgs(["--nope"]), /unknown argument: --nope/);
});

test("defaultStemsFrom points at the main checkout's music_ace folder", () => {
  assert.equal(
    defaultStemsFrom("/home/x/repo/.git"),
    "/home/x/repo/sketches/core-loop/assets/music_ace",
  );
});

test("missingStemsMessage names the folder, the flag and the default, never a regeneration tool", () => {
  const message = missingStemsMessage(["a.ogg", "b.ogg"], "/d", "/m");
  assert.equal(
    message,
    "2 stem file(s) named by the manifest are missing from /d, first a.ogg. The ACE stems are gitignored and cannot be regenerated; pass --stems-from=<music_ace folder that holds spillway/*.ogg> (default: /m).",
  );
  assert.ok(message.includes("--stems-from="));
  assert.ok(!message.includes("package_music"));
});

test("parseArgs reads --win-proof beside --stems-from", () => {
  assert.deepEqual(parseArgs(["--win-proof"]), {
    stemsFrom: null,
    winProof: true,
  });
  assert.deepEqual(parseArgs(["--stems-from=/a", "--win-proof"]), {
    stemsFrom: "/a",
    winProof: true,
  });
});

const presetsText = readFileSync(
  new URL("../sketches/core-loop/export_presets.cfg", import.meta.url),
  "utf8",
);

test("the real proof preset matches the shipped preset except name, runnable and tools/*", () => {
  const presets = parsePresets(presetsText);
  assert.deepEqual(Object.keys(presets), ["Linux x64", "Linux x64 proof"]);
  assert.equal(
    presets["Linux x64 proof"].options["texture_format/s3tc_bptc"],
    "true",
  );
  assert.deepEqual(proofPresetDrift(presets), []);
});

test("a changed proof option is one drift", () => {
  const mutated = presetsText.replace(
    /(\[preset\.1\.options\][^[]*texture_format\/s3tc_bptc=)true/,
    "$1false",
  );
  assert.notEqual(mutated, presetsText);
  assert.equal(proofPresetDrift(parsePresets(mutated)).length, 1);
});

const row = (outcome, stage = 6) =>
  JSON.stringify({
    policy: "skipper",
    seed: 1,
    outcome,
    stage_reached: stage,
    ticks: 9000,
  });

test("a single won row with exit 0 and no error line passes", () => {
  assert.deepEqual(
    winProofFailures("bot_run: skipper seed 1 -> won\n", 0, row("won") + "\n"),
    [],
  );
});

test("a lost row fails", () => {
  assert.equal(winProofFailures("", 0, row("lost", 3)).length, 1);
});

test("a stalled or until row fails", () => {
  assert.equal(winProofFailures("", 0, row("stalled", 4)).length, 1);
  assert.equal(winProofFailures("", 0, row("until", 6)).length, 1);
});

test("two rows fail", () => {
  assert.equal(
    winProofFailures("", 0, row("won") + "\n" + row("won") + "\n").length,
    1,
  );
});

test("an ERROR line fails beside a won row", () => {
  assert.equal(winProofFailures("ERROR: boom\n", 0, row("won")).length, 1);
});

test("status 1 fails beside a won row", () => {
  assert.equal(winProofFailures("", 1, row("won")).length, 1);
});
