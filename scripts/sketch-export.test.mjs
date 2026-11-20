import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import {
  BOSS_SMOKE,
  bootFailures,
  bossSmokeCommand,
  bossSmokeFailures,
  bossSmokeLine,
  bossSmokeFailLine,
  bossSmokeCrash,
  BOSS_SMOKE_CRASH_SCRIPT,
  BOSS_SMOKE_QUEUE_WAIT_S,
  BOSS_SMOKE_TIMEOUT_S,
  exitText,
  buildStamp,
  runBossSmoke,
  defaultStemsFrom,
  howToRun,
  nextStepLine,
  missingStems,
  missingStemsMessage,
  packageName,
  parseArgs,
  playProofTries,
  parsePresets,
  proofPresetDrift,
  releaseGateFailures,
  tarArgs,
  trackedManifests,
  winProofFailures,
  winProofLine,
  WIN_PROOFS,
  WIN_PROOF_TIMEOUT_S,
  winProofBotArgs,
  winProofTimeoutMs,
  proofLibraries,
  selfPlayPresetText,
} from "./sketch-export.mjs";

test("proofLibraries picks each add-on's linux debug library and nothing else", () => {
  const files = [
    "addons/terrain_3d/bin/libterrain.linux.debug.x86_64.so",
    "addons/terrain_3d/bin/libterrain.linux.release.x86_64.so",
    "addons/terrain_3d/bin/libterrain.windows.debug.x86_64.dll",
    "addons/terrain_3d/terrain.gdextension",
    "src/world/terrain.gd",
  ];
  assert.deepEqual(proofLibraries(files), [
    "addons/terrain_3d/bin/libterrain.linux.debug.x86_64.so",
  ]);
});

const manifest = {
  stems: ["drums", "bass"],
  clips: {
    calm: { files: { drums: "calm.drums.ogg", bass: "calm.bass.ogg" } },
    open: { files: { drums: "open.drums.ogg", bass: "open.bass.ogg" } },
  },
};

test("a manifest whose stems all exist reports none missing", () => {
  assert.deepEqual(
    missingStems(manifest, "/d", () => true),
    [],
  );
});

test("a stem file the manifest names but the folder lacks is reported", () => {
  const present = new Set(["/d/calm.drums.ogg", "/d/calm.bass.ogg", "/d/open.drums.ogg"]);
  assert.deepEqual(
    missingStems(manifest, "/d", (file) => present.has(file)),
    ["open.bass.ogg"],
  );
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
  assert.deepEqual(
    releaseGateFailures("[skip] x\nrelease_gate_placeholder_test: PASS (3 checks)\n", 0),
    [],
  );
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
  assert.equal(
    releaseGateFailures("release_gate_placeholder_test: PASS (3 checks)\n", 1).length,
    1,
  );
  assert.equal(releaseGateFailures("nothing", 0).length, 1);
});

test("parseArgs reads both --stems-from forms, defaults to null and rejects others", () => {
  assert.deepEqual(parseArgs([]), {
    stemsFrom: null,
    winProof: false,
    bossSmokeOnly: false,
    selfPlay: false,
  });
  assert.deepEqual(parseArgs(["--stems-from=/a"]), {
    stemsFrom: "/a",
    winProof: false,
    bossSmokeOnly: false,
    selfPlay: false,
  });
  assert.deepEqual(parseArgs(["--stems-from", "/b"]), {
    stemsFrom: "/b",
    winProof: false,
    bossSmokeOnly: false,
    selfPlay: false,
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
    bossSmokeOnly: false,
    selfPlay: false,
  });
  assert.deepEqual(parseArgs(["--stems-from=/a", "--win-proof"]), {
    stemsFrom: "/a",
    winProof: true,
    bossSmokeOnly: false,
    selfPlay: false,
  });
});

const presetsText = readFileSync(
  new URL("../sketches/core-loop/export_presets.cfg", import.meta.url),
  "utf8",
);

test("the real proof preset matches the shipped preset except name, runnable and tools/*", () => {
  const presets = parsePresets(presetsText);
  assert.deepEqual(Object.keys(presets), ["Linux x64", "Linux x64 proof", "macOS"]);
  assert.equal(presets["Linux x64 proof"].options["texture_format/s3tc_bptc"], "true");
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
  assert.deepEqual(winProofFailures("bot_run: skipper seed 1 -> won\n", 0, row("won") + "\n"), []);
});

test("a lost row fails", () => {
  assert.equal(winProofFailures("", 0, row("lost", 3)).length, 1);
});

test("a stalled or until row fails", () => {
  assert.equal(winProofFailures("", 0, row("stalled", 4)).length, 1);
  assert.equal(winProofFailures("", 0, row("until", 6)).length, 1);
});

test("two rows fail", () => {
  assert.equal(winProofFailures("", 0, row("won") + "\n" + row("won") + "\n").length, 1);
});

test("an ERROR line fails beside a won row", () => {
  assert.equal(winProofFailures("ERROR: boom\n", 0, row("won")).length, 1);
});

test("status 1 fails beside a won row", () => {
  assert.equal(winProofFailures("", 1, row("won")).length, 1);
});

test("buildStamp has each key", () => {
  const text = buildStamp({
    sha: "abc1234def",
    dirty: false,
    stamp: "20261005T051752",
    godot: "4.7.2.stable",
    stems: 24,
    stemsFrom: "/m/music_ace",
  });
  for (const line of [
    "commit: abc1234def",
    "dirty: false",
    "built: 20261005T051752",
    "godot: 4.7.2.stable",
    "stems: 24 from /m/music_ace",
  ])
    assert.ok(text.split("\n").includes(line), line);
});

test("howToRun names the files, the save folder and H, with no table", () => {
  const text = howToRun({ sha7: "abc1234" });
  assert.ok(text.startsWith("Scrapkeep core-loop alpha (abc1234)\n"));
  for (const part of [
    "music_ace",
    "core-loop.x86_64",
    "app_userdata/core-loop",
    "press H",
    "./core-loop.x86_64 -- --profile=sitting",
  ])
    assert.ok(text.includes(part), part);
  assert.ok(!text.includes("|"));
  assert.ok(text.split(/\s+/).filter(Boolean).length < 140);
});

test("packageName and tarArgs", () => {
  assert.equal(packageName("abc1234"), "scrapkeep-core-loop-abc1234");
  assert.deepEqual(tarArgs("/a/b/20261005T051752", "abc1234"), [
    "-czf",
    "/a/b/scrapkeep-core-loop-abc1234.tar.gz",
    "-C",
    "/a/b",
    "--transform=s,^20261005T051752,scrapkeep-core-loop-abc1234,",
    "20261005T051752",
  ]);
});

test("packageName and tarArgs add -dirty on a dirty tree", () => {
  assert.equal(packageName("abc1234", true), "scrapkeep-core-loop-abc1234-dirty");
  assert.equal(packageName("abc1234", false), "scrapkeep-core-loop-abc1234");
  assert.deepEqual(tarArgs("/a/b/20261005T051752", "abc1234", true), [
    "-czf",
    "/a/b/scrapkeep-core-loop-abc1234-dirty.tar.gz",
    "-C",
    "/a/b",
    "--transform=s,^20261005T051752,scrapkeep-core-loop-abc1234-dirty,",
    "20261005T051752",
  ]);
});

test("buildStamp records the win proof line or says it did not run", () => {
  const base = {
    sha: "abc1234def",
    dirty: false,
    stamp: "20261005T051752",
    godot: "4.7.2.stable",
    stems: 24,
    stemsFrom: "/m/music_ace",
  };
  const line =
    "win proof: won at stage 6, 100 ticks, 1.5 s wall, policy skipper seed 1, pack /x/proof.pck";
  assert.ok(
    buildStamp({ ...base, winProof: line })
      .split("\n")
      .includes(line),
  );
  assert.ok(buildStamp(base).split("\n").includes("win proof: not run (pass --win-proof)"));
});

test("winProofLine formats a won row", () => {
  const won = {
    outcome: "won",
    stage_reached: 6,
    ticks: 34170,
    wall_seconds: 86.65,
  };
  assert.equal(
    winProofLine(won, "/x/proof.pck"),
    "win proof: won at stage 6, 34170 ticks, 86.65 s wall, policy skipper seed 1, pack /x/proof.pck",
  );
});

test("WIN_PROOFS plays Rivet's seed 1 first, then the cannon, Tally and the park pilot pinned by --pilot", () => {
  assert.deepEqual(
    WIN_PROOFS.map((proof) => [proof.label, proof.seed, proof.pilot ?? null]),
    [
      ["win proof", 1, null],
      ["win proof (cannon)", 11, "remembered_cannon"],
      ["win proof (tally)", 1, "tally"],
      ["win proof (park)", 2, "pylon_engineer"],
    ],
  );
  assert.equal(new Set(WIN_PROOFS.map((proof) => proof.dir)).size, WIN_PROOFS.length);
});

test("each world proof gets 900 s and the park proof, twice as long a run, gets 1800 s", () => {
  assert.equal(WIN_PROOF_TIMEOUT_S, 900);
  assert.deepEqual(
    WIN_PROOFS.map((proof) => [proof.dir, winProofTimeoutMs(proof)]),
    [
      ["", 900_000],
      ["cannon", 900_000],
      ["tally", 900_000],
      ["park", 1_800_000],
    ],
  );
});

test("winProofLine formats the cannon proof with its pilot", () => {
  const won = {
    outcome: "won",
    stage_reached: 6,
    ticks: 34249,
    wall_seconds: 180.84,
  };
  assert.equal(
    winProofLine(won, "/x/proof.pck", WIN_PROOFS[1]),
    "win proof (cannon): won at stage 6, 34249 ticks, 180.84 s wall, policy skipper seed 11 pilot remembered_cannon, pack /x/proof.pck",
  );
  assert.equal(winProofLine(won, "/x/proof.pck", WIN_PROOFS[0]), winProofLine(won, "/x/proof.pck"));
});

test("trackedManifests ships every track folder that holds a manifest, sorted", () => {
  const folders = ["title", "spillway", "renders", "mind"];
  const held = new Set([
    "/m/title/manifest.json",
    "/m/spillway/manifest.json",
    "/m/mind/manifest.json",
  ]);
  assert.deepEqual(
    trackedManifests(
      "/m",
      () => folders,
      (file) => held.has(file),
    ),
    ["mind", "spillway", "title"],
  );
});

const vulkanBanner =
  "Vulkan 1.4.341 - Forward+ - Using Device #1: NVIDIA - NVIDIA GeForce RTX 3060";
const smokeOut = (boss) =>
  [
    "Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org",
    vulkanBanner,
    `BOSS_SMOKE boss=${boss} stage=4 ticks=300 in_arena=true rendering=forward_plus driver=vulkan device=NVIDIA GeForce RTX 3060 PASS`,
  ].join("\n");

test("boss smoke boots each boss through the GPU queue on Vulkan with the queue's card index and two timeouts", () => {
  assert.deepEqual(BOSS_SMOKE, ["bowl", "waking", "mind"]);
  const { command, args } = bossSmokeCommand({
    queue: "/q.sh",
    binary: "/godot",
    project: "/p",
    boss: "waking",
  });
  assert.equal(command, "/q.sh");
  assert.deepEqual(args.slice(0, args.indexOf("--") + 1), [
    "--gpu",
    "1",
    "--need",
    "3000",
    "--name",
    "boss-smoke-waking",
    "--display",
    "--shared",
    "--timeout",
    String(BOSS_SMOKE_QUEUE_WAIT_S),
    "--",
  ]);
  const inner = args.slice(args.indexOf("--") + 1);
  assert.deepEqual(inner.slice(0, 4), ["timeout", "-k", "10", String(BOSS_SMOKE_TIMEOUT_S)]);
  assert.ok(inner.includes('exec "$0" --gpu-index "$SCRAPKEEP_GPU_INDEX" "$@"'));
  assert.deepEqual(
    inner.slice(inner.indexOf("--rendering-driver"), inner.indexOf("--rendering-driver") + 2),
    ["--rendering-driver", "vulkan"],
  );
  assert.deepEqual(
    inner.slice(inner.indexOf("--display-driver"), inner.indexOf("--display-driver") + 2),
    ["--display-driver", "x11"],
  );
  assert.deepEqual(
    inner.slice(inner.indexOf("--audio-driver"), inner.indexOf("--audio-driver") + 2),
    ["--audio-driver", "Dummy"],
  );
  assert.ok(
    inner.indexOf("--audio-driver") < inner.indexOf("--script"),
    "an engine flag goes before --script",
  );
  assert.equal(inner[inner.indexOf("--script") + 1], "res://tools/look_harness.gd");
  assert.equal(args.at(-1), "--boss=waking");
});

test("the crash control swaps in the crashing entry script for one boss only", () => {
  const { args } = bossSmokeCommand({
    queue: "/q.sh",
    binary: "/godot",
    project: "/p",
    boss: "mind",
    crash: true,
  });
  assert.equal(args[args.indexOf("--script") + 1], BOSS_SMOKE_CRASH_SCRIPT);
  assert.equal(BOSS_SMOKE_CRASH_SCRIPT, "res://tools/boss_smoke_crash.gd");
  assert.equal(args.at(-1), "--boss=mind");
});

test("the crash control is off unless SCRAPKEEP_BOSS_SMOKE_CRASH names a boss, and a typo is refused", () => {
  assert.equal(bossSmokeCrash({}), null);
  assert.equal(bossSmokeCrash({ SCRAPKEEP_BOSS_SMOKE_CRASH: "" }), null);
  assert.equal(bossSmokeCrash({ SCRAPKEEP_BOSS_SMOKE_CRASH: "waking" }), "waking");
  assert.throws(
    () => bossSmokeCrash({ SCRAPKEEP_BOSS_SMOKE_CRASH: "wakng" }),
    /SCRAPKEEP_BOSS_SMOKE_CRASH=wakng is not one of bowl, waking, mind/,
  );
});

test("exitText names the timeout and the signal behind a shell exit code", () => {
  assert.equal(exitText(0, null), "exit 0");
  assert.equal(exitText(124, null), `exit 124 (timed out after ${BOSS_SMOKE_TIMEOUT_S} s)`);
  assert.equal(exitText(139, null), "exit 139 (SIGSEGV)");
  assert.equal(exitText(134, null), "exit 134 (SIGABRT)");
  assert.equal(exitText(3, null), "exit 3");
  assert.equal(exitText(null, "SIGTERM"), "signal SIGTERM");
});

test("boss smoke passes a clean Vulkan run and names exit, wall time and device", () => {
  assert.deepEqual(bossSmokeFailures("waking", smokeOut("waking"), 0), []);
  assert.equal(
    bossSmokeLine("waking", smokeOut("waking"), { status: 0, signal: null, wall: 41234 }),
    "boss smoke waking: PASS, exit 0, 41.2 s wall, stage 4 arena, 300 ticks, Vulkan on NVIDIA - NVIDIA GeForce RTX 3060",
  );
});

test("boss smoke fails a crash, a timeout, a missing PASS, an error before PASS and a non-Vulkan device", () => {
  assert.deepEqual(bossSmokeFailures("mind", smokeOut("mind"), null, "SIGSEGV"), [
    "mind: killed by SIGSEGV",
  ]);
  assert.deepEqual(bossSmokeFailures("mind", smokeOut("mind"), 139), ["mind: exit 139 (SIGSEGV)"]);
  assert.deepEqual(bossSmokeFailures("mind", vulkanBanner, 124), [
    `mind: exit 124 (timed out after ${BOSS_SMOKE_TIMEOUT_S} s)`,
    "mind: no BOSS_SMOKE PASS line",
  ]);
  assert.deepEqual(bossSmokeFailures("mind", vulkanBanner, 0), ["mind: no BOSS_SMOKE PASS line"]);
  const crashLine = "ERROR: BUG, indexing did not unpair geometries from light.";
  const early = [vulkanBanner, crashLine, smokeOut("mind").split("\n").at(-1)].join("\n");
  assert.deepEqual(bossSmokeFailures("mind", early, 0), ["mind: " + crashLine]);
  const gl = smokeOut("bowl").replace(
    vulkanBanner,
    "OpenGL API 3.3.0 NVIDIA 610.57.04 - Compatibility - Using Device: NVIDIA - NVIDIA GeForce RTX 3060",
  );
  assert.deepEqual(bossSmokeFailures("bowl", gl, 0), ['bowl: no "Using Device" line']);
  const fallback = smokeOut("bowl").replace("Vulkan 1.4.341", "OpenGL 3.3");
  assert.deepEqual(bossSmokeFailures("bowl", fallback, 0), ["bowl: renderer OpenGL, not Vulkan"]);
  const teardown = smokeOut("bowl") + "\n" + crashLine;
  assert.deepEqual(bossSmokeFailures("bowl", teardown, 0), []);
  assert.match(
    bossSmokeLine("bowl", teardown, { status: 0, signal: null, wall: 1000 }),
    /, 1 teardown error lines$/,
  );
});

test("a failed boss prints one FAIL line with exit, wall time and the reasons", () => {
  assert.equal(
    bossSmokeFailLine("mind", ["mind: exit 134 (SIGABRT)", "mind: no BOSS_SMOKE PASS line"], {
      status: 134,
      signal: null,
      wall: 12049,
    }),
    "boss smoke mind: FAIL, exit 134 (SIGABRT), 12.0 s wall: exit 134 (SIGABRT); no BOSS_SMOKE PASS line",
  );
});

test("runBossSmoke prints a PASS or FAIL line for every boss and fails on any crash", () => {
  const calls = [];
  let clock = 0;
  const now = () => (clock += 5000);
  const runner = (command, args) => {
    calls.push(args.at(-1));
    const boss = args.at(-1).slice("--boss=".length);
    return boss === "mind"
      ? { status: 139, signal: null, stdout: vulkanBanner, stderr: "" }
      : { status: 0, signal: null, stdout: smokeOut(boss), stderr: "" };
  };
  const result = runBossSmoke({ runner, queue: "/q.sh", binary: "/godot", project: "/p", now });
  assert.deepEqual(calls, ["--boss=bowl", "--boss=waking", "--boss=mind"]);
  assert.equal(result.lines.length, 3);
  assert.match(result.lines[0], /^boss smoke bowl: PASS, exit 0, 5\.0 s wall,/);
  assert.match(result.lines[1], /^boss smoke waking: PASS, exit 0, 5\.0 s wall,/);
  assert.equal(
    result.lines[2],
    "boss smoke mind: FAIL, exit 139 (SIGSEGV), 5.0 s wall: exit 139 (SIGSEGV); no BOSS_SMOKE PASS line",
  );
  assert.deepEqual(result.failures, ["mind: exit 139 (SIGSEGV)", "mind: no BOSS_SMOKE PASS line"]);
});

test("runBossSmoke builds the crash command only for the boss the control names", () => {
  const scripts = [];
  const runner = (command, args) => {
    scripts.push(args[args.indexOf("--script") + 1]);
    return {
      status: 0,
      signal: null,
      stdout: smokeOut(args.at(-1).slice("--boss=".length)),
      stderr: "",
    };
  };
  runBossSmoke({
    runner,
    queue: "/q.sh",
    binary: "/godot",
    project: "/p",
    crash: "waking",
    now: () => 0,
  });
  assert.deepEqual(scripts, [
    "res://tools/look_harness.gd",
    BOSS_SMOKE_CRASH_SCRIPT,
    "res://tools/look_harness.gd",
  ]);
});

test("parseArgs reads --boss-smoke-only", () => {
  assert.deepEqual(parseArgs(["--boss-smoke-only"]), {
    stemsFrom: null,
    winProof: false,
    bossSmokeOnly: true,
    selfPlay: false,
  });
});

test("a won row below stage 6 fails the win proof", () => {
  assert.equal(winProofFailures("", 0, row("won", 5)).length, 1);
});

test("the park win proof is mandatory, pins pylon_engineer seed 2 and the park table, and has its own folder", () => {
  const parkProofs = WIN_PROOFS.filter((proof) => proof.table === "park");
  assert.equal(parkProofs.length, 1);
  const [park] = parkProofs;
  assert.equal(park.pilot, "pylon_engineer");
  assert.equal(park.seed, 2);
  assert.equal(WIN_PROOFS.filter((proof) => proof.dir === park.dir).length, 1);
  assert.equal(WIN_PROOFS.filter((proof) => proof.table).length, 1);
  assert.throws(() => parseArgs(["--win-proof", "--park-win-proof"]), /unknown argument/);
  const won = { outcome: "won", stage_reached: 6, ticks: 1, wall_seconds: 2 };
  assert.match(winProofLine(won, "/x/proof.pck", park), /pilot pylon_engineer table park, pack/);
});

test("only the park proof retries, up to 3 tries, and every try's outcome reaches the summary", async () => {
  assert.deepEqual(
    WIN_PROOFS.filter((proof) => (proof.tries ?? 1) > 1).map((proof) => [proof.label, proof.tries]),
    [["win proof (park)", 3]],
  );
  const park = WIN_PROOFS.find((proof) => proof.table === "park");
  const scripted = (results) => {
    const seen = [];
    return {
      seen,
      play: async (attempt) => {
        seen.push(attempt);
        return results[attempt - 1];
      },
    };
  };
  const stall = (stage) => ({
    ok: false,
    failure: "stalled " + stage,
    summary: "outcome stalled at stage " + stage,
  });
  const win = { ok: true, line: "win proof (park): won at stage 6" };

  const second = scripted([stall(6), win, win]);
  const passed = await playProofTries(park, second.play);
  assert.equal(passed.ok, true);
  assert.deepEqual(second.seen, [1, 2]);
  assert.equal(
    passed.line,
    "win proof (park): won at stage 6 (try 2 of 3; try 1: outcome stalled at stage 6)",
  );

  const never = scripted([stall(6), stall(3), stall(6)]);
  const failed = await playProofTries(park, never.play);
  assert.equal(failed.ok, false);
  assert.deepEqual(never.seen, [1, 2, 3]);
  assert.equal(failed.failure, "stalled 6");

  const once = scripted([stall(2), win]);
  const single = await playProofTries(
    WIN_PROOFS.find((proof) => proof.dir === "cannon"),
    once.play,
  );
  assert.equal(single.ok, false);
  assert.deepEqual(once.seen, [1]);

  const first = scripted([win]);
  assert.equal(
    (await playProofTries(park, first.play)).line,
    "win proof (park): won at stage 6 (try 1 of 3)",
  );

  for (const file of ["./sketch-export.mjs", "./cloud/export-headless.mjs"])
    assert.match(
      readFileSync(new URL(file, import.meta.url), "utf8"),
      /playProofTries\(proof, /,
      file,
    );
});

test("every win proof's bot args carry its pilot and table, and the cloud export builds them the same way", () => {
  for (const proof of WIN_PROOFS) {
    const args = winProofBotArgs(proof, "/x/run");
    assert.ok(args.includes("--seeds=" + proof.seed), proof.label);
    assert.equal(args.includes("--pilot=" + proof.pilot), Boolean(proof.pilot), proof.label);
    assert.equal(args.includes("--table=" + proof.table), Boolean(proof.table), proof.label);
  }
  assert.ok(
    winProofBotArgs(
      WIN_PROOFS.find((proof) => proof.table === "park"),
      "/x/run",
    ).includes("--table=park"),
  );
  const cloud = readFileSync(new URL("./cloud/export-headless.mjs", import.meta.url), "utf8");
  assert.match(cloud, /\.\.\.winProofBotArgs\(proof, out\)/);
  assert.doesNotMatch(cloud, /"--seeds=" \+/);
  const local = readFileSync(new URL("./sketch-export.mjs", import.meta.url), "utf8");
  assert.match(local, /\.\.\.winProofBotArgs\(proof, out\)/);
  assert.equal(local.match(/"--seeds=" \+/g).length, 1);
});

test("buildStamp records the boss smoke lines before the win proof", () => {
  const text = buildStamp({
    sha: "a",
    dirty: false,
    stamp: "s",
    godot: "g",
    stems: 1,
    stemsFrom: "f",
    bossSmoke: "boss smoke bowl: PASS",
  });
  assert.match(text, /stems: 1 from f\nboss smoke bowl: PASS\nwin proof: not run/);
});

test("parseArgs reads --self-play and the default leaves it off", () => {
  assert.equal(parseArgs([]).selfPlay, false);
  assert.equal(parseArgs(["--self-play"]).selfPlay, true);
  assert.equal(parseArgs(["--win-proof", "--self-play"]).selfPlay, true);
});

test("--self-play keeps tools/ in the shipped preset and nothing else changes", () => {
  const swapped = selfPlayPresetText(presetsText);
  const exclude = (text, name) => {
    const lines = text.split("\n");
    const start = lines.findIndex((line) => line === `name="${name}"`);
    return lines.slice(start).find((line) => line.startsWith("exclude_filter="));
  };
  assert.match(exclude(presetsText, "Linux x64"), /tools\/\*/);
  assert.doesNotMatch(exclude(swapped, "Linux x64"), /tools\//);
  assert.equal(
    exclude(swapped, "Linux x64"),
    'exclude_filter="tests/*, design-v2/*, design-v3/*, perf-lab/*, assets/music_ace/*"',
  );
  // The other preset, and every other line, are untouched.
  assert.equal(exclude(swapped, "Linux x64 proof"), exclude(presetsText, "Linux x64 proof"));
  const before = presetsText.split("\n");
  const after = swapped.split("\n");
  assert.equal(after.length, before.length);
  assert.equal(after.filter((line, i) => line !== before[i]).length, 1);
  // The default path never goes through the swap: the committed shipped preset still excludes tools/.
  assert.match(parsePresets(presetsText)["Linux x64"].fields.exclude_filter, /tools\/\*/);
  assert.throws(() => selfPlayPresetText('[preset.9]\nname="other"\n'), /missing/);
});

test("the self-play package is named apart from the shipped one", () => {
  assert.equal(packageName("abc1234", false, true), "scrapkeep-core-loop-abc1234-selfplay");
  assert.equal(packageName("abc1234", true, true), "scrapkeep-core-loop-abc1234-dirty-selfplay");
  assert.equal(packageName("abc1234"), "scrapkeep-core-loop-abc1234");
  assert.ok(
    tarArgs("/a/b/20261005T051752", "abc1234", false, true)[1].endsWith("abc1234-selfplay.tar.gz"),
  );
  assert.deepEqual(tarArgs("/a/b/s", "abc1234"), tarArgs("/a/b/s", "abc1234", false, false));
});

test("BUILD.txt records a self-play pack and the default stamp does not", () => {
  const base = {
    sha: "a",
    dirty: false,
    stamp: "s",
    godot: "g",
    stems: 1,
    stemsFrom: "/x",
    winProof: null,
    bossSmoke: null,
  };
  assert.match(buildStamp({ ...base, selfPlay: true }), /^self-play pack \(tools\/ included\)$/m);
  assert.equal(buildStamp(base), buildStamp({ ...base, selfPlay: false }));
  assert.doesNotMatch(buildStamp(base), /self-play/);
});

test("nextStepLine points at sketch:appimage and the launcher check", () => {
  const line = nextStepLine();
  assert.ok(!line.includes("\n"));
  assert.match(line, /npm run sketch:appimage/);
  assert.match(line, /app menu/);
});
