import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import * as render from "./model-render-receipt.mjs";
import * as census from "./stand-ins-receipt.mjs";
import * as display from "./display-run.mjs";

const HEAD = "abc1234";
const KINDS = render.KINDS;
const here = path.dirname(fileURLToPath(import.meta.url));

// A committed scratch repo for the dirty-checkout checks.
function repo() {
  const dir = mkdtempSync(path.join(os.tmpdir(), "look-receipts-git-"));
  const git = (...args) =>
    spawnSync("git", ["-c", "user.name=t", "-c", "user.email=t@t", ...args], {
      cwd: dir,
      encoding: "utf8",
    });
  git("init", "-q");
  writeFileSync(path.join(dir, "a.txt"), "one");
  git("add", "a.txt");
  git("commit", "-q", "-m", "one");
  return { dir, head: git("rev-parse", "HEAD").stdout.trim() };
}

// --- models-render ---

function compareLog({
  kinds = KINDS,
  failed = [],
  missing = [],
  plant = "",
  judged = kinds.length - missing.length,
  pinned = 6,
  lines: count,
} = {}) {
  let lines = kinds.map((k) =>
    missing.includes(k)
      ? `FAIL ${k}: no generated model was loaded (res://${k}.glb)`
      : `${failed.includes(k) ? "FAIL" : "PASS"} ${k}: view 0 brightness 0.95 of authored (0.400, authored 0.420), near-black 0.01 (authored 0.01)`,
  );
  if (count !== undefined) lines = lines.slice(0, count);
  lines.push(`SUMMARY ${JSON.stringify({ judged, pinned, failed, missing, plant })}`);
  lines.push(
    `model_render_check: ${failed.length + missing.length ? "FAIL" : "PASS"} (${judged} kinds judged, ...)`,
  );
  return { log: lines.join("\n") };
}
const plantedLog = (failed = KINDS) => compareLog({ failed, plant: "dark_models" });

test("models-render: every kind judged, none failed, the plant caught on every kind -> pass", () => {
  const r = render.buildReceipt(compareLog(), plantedLog(), HEAD);
  assert.deepEqual(Object.keys(r), ["head", "pass", "measured", "plant_caught"]);
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.match(
    r.measured,
    /^no generated enemy model renders darker than its authored one: all 6 kinds/,
  );
  assert.match(
    r.measured,
    /failed all 6 kinds; not judged: pilots, item parts, the camp pet and props .* a brighter, white or recoloured model passes; most of an enemy's material is replaced in code/,
  );
});

test("models-render: a dark model is a miss and is named", () => {
  const r = render.buildReceipt(compareLog({ failed: ["netcaster"] }), plantedLog(), HEAD);
  assert.equal(r.pass, false);
  assert.match(
    r.measured,
    /^1 of 6 generated enemy models render darker than their authored ones: netcaster/,
  );
});

test("models-render: a kind with no generated model loaded is a miss and is named", () => {
  const r = render.buildReceipt(compareLog({ missing: ["swatter"] }), plantedLog(), HEAD);
  assert.equal(r.pass, false);
  assert.match(
    r.measured,
    /^1 kind\(s\) had no generated model loaded, so nothing was judged for them: swatter/,
  );
});

test("models-render: each count guard fails alone (verdict lines, the check's pin, judged)", () => {
  const lines = render.buildReceipt(compareLog({ lines: 5 }), plantedLog(), HEAD);
  assert.equal(lines.pass, false);
  assert.match(lines.measured, /^6 kinds judged with 5 verdict lines, pinned 6/);
  const pinned = render.buildReceipt(compareLog({ pinned: 7 }), plantedLog(), HEAD);
  assert.equal(pinned.pass, false);
  assert.match(pinned.measured, /\(the check pins 7\)/);
  const judged = render.buildReceipt(compareLog({ judged: 5 }), plantedLog(), HEAD);
  assert.equal(judged.pass, false);
  assert.match(judged.measured, /^5 kinds judged with 6 verdict lines/);
  const none = render.buildReceipt({ log: render.NO_DISPLAY }, { log: render.NO_DISPLAY }, HEAD);
  assert.equal(none.pass, false);
  assert.match(
    none.measured,
    /^no SUMMARY line, so no model was judged: not run: the shoot needs a graphics display/,
  );
});

test("models-render: a plant that misses one kind, or whose stats do not show it, is not caught", () => {
  const one = render.buildReceipt(
    compareLog(),
    plantedLog(KINDS.filter((k) => k !== "netcaster")),
    HEAD,
  );
  assert.equal(one.plant_caught, false);
  assert.equal(one.pass, false);
  assert.match(one.measured, /compare missed netcaster/);
  const unplanted = render.buildReceipt(compareLog(), compareLog({ failed: KINDS }), HEAD);
  assert.equal(
    unplanted.plant_caught,
    false,
    "every kind failing without the plant in the stats proves nothing",
  );
  assert.match(unplanted.measured, /the planted shoot's stats do not show the plant \(none\)/);
  assert.equal(render.buildReceipt(compareLog(), { log: "" }, HEAD).plant_caught, false);
});

test("models-render: a plant switch that reached the real shoot fails the receipt", () => {
  const r = render.buildReceipt(
    compareLog({ failed: KINDS, plant: "dark_models" }),
    plantedLog(),
    HEAD,
  );
  assert.equal(r.pass, false);
  assert.match(r.measured, /^the real shoot ran planted \(dark_models\)/);
});

test("models-render: the producer takes the head from git and refuses a dirty checkout", async () => {
  const { dir, head } = repo();
  let ran = 0;
  const ok = await render.produce({
    cwd: dir,
    run: async () => {
      ran += 1;
      return { real: compareLog(), plant: plantedLog() };
    },
  });
  assert.equal(ok.head, head);
  assert.equal(ok.pass, true);
  writeFileSync(path.join(dir, "a.txt"), "two");
  await assert.rejects(
    render.produce({
      cwd: dir,
      run: async () => {
        ran += 1;
        return {};
      },
    }),
    /refusing: uncommitted changes/,
  );
  assert.equal(ran, 1, "a dirty checkout never runs the shoot");
});

test("models-render: runShoots shoots authored, tripo-all, compares, then shoots and compares the plant", async () => {
  const { dir } = repo();
  const calls = [];
  const window = async ({ args, extraEnv, engineArgs, script }) => {
    calls.push({ args, extraEnv });
    assert.equal(script, "res://tools/model_render_check.gd");
    assert.ok(!engineArgs.includes("--headless"));
    const compare = args.find((a) => a.startsWith("--compare="));
    if (!compare) return { exit: 0, output: "shot", supported: true };
    return {
      exit: 0,
      output: (compare.includes("tripo-planted") ? plantedLog() : compareLog()).log,
      supported: true,
    };
  };
  const r = await render.runShoots(dir, { window });
  assert.equal(calls.length, 5);
  assert.deepEqual(
    calls.map((c) => c.extraEnv),
    [{}, {}, {}, { RENDER_PLANT: "dark_models" }, {}],
  );
  assert.ok(
    calls[1].args.includes("--models=tripo-all") && calls[3].args.includes("--models=tripo-all"),
  );
  assert.ok(!calls[0].args.includes("--models=tripo-all"));
  assert.ok(r.dir.startsWith(path.join(dir, "artifacts/local/model-render-")));
  assert.equal(render.buildReceipt(r.real, r.plant, HEAD).pass, true);
});

test("models-render: no display, or a failed shoot, is a miss that says why", async () => {
  const { dir } = repo();
  const none = await render.runShoots(dir, {
    window: async () => ({
      exit: null,
      output: "not supported here: no DISPLAY",
      supported: false,
    }),
  });
  const r = render.buildReceipt(none.real, none.plant, HEAD);
  assert.equal(r.pass, false);
  assert.match(
    r.measured,
    /^no SUMMARY line, so no model was judged: not run: the shoot needs a graphics display and display-run\.mjs found none: not supported here/,
  );
  const crash = await render.runShoots(dir, {
    window: async () => ({
      exit: 2,
      output: "x\nmodel_render_check: a kind drew under 2000 pixels",
      supported: true,
    }),
  });
  assert.match(
    render.buildReceipt(crash.real, crash.plant, HEAD).measured,
    /authored shoot exit 2: x \| model_render_check: a kind drew under 2000 pixels/,
  );
});

// --- display-run ---

const noSlot =
  (events = []) =>
  async () => {
    events.push("acquire");
    return { release: () => events.push("release") };
  };

test("display-run: takes a slot, sets a scratch home, never passes --headless, removes the home after", async () => {
  const { dir } = repo();
  const events = [];
  let seen;
  const start = async (command, argv, { env }) => {
    events.push("start");
    seen = { command, argv, env };
    return { exit: 0, signal: null, output: "ok", timedOut: false };
  };
  const r = await display.runWindowed({
    platform: "linux",
    cwd: dir,
    script: "res://tools/x.gd",
    args: ["--out=/a"],
    binary: "/bin/godot",
    env: { DISPLAY: ":0", HOME: "/Users/real" },
    acquire: noSlot(events),
    start,
  });
  assert.deepEqual(events, ["acquire", "start", "release"]);
  assert.equal(r.exit, 0);
  assert.ok(r.home.startsWith(path.join(dir, "artifacts/local/display-run/home-")));
  assert.deepEqual(seen.argv, [
    "--path",
    path.join(dir, "sketches/core-loop"),
    "--script",
    "res://tools/x.gd",
    "--",
    "--out=/a",
  ]);
  assert.equal(seen.env.HOME, r.home);
  assert.ok(!existsSync(r.home), "the scratch home is removed after the run");
  const kept = await display.runWindowed({
    platform: "linux",
    cwd: dir,
    script: "res://x.gd",
    binary: "/bin/godot",
    env: { DISPLAY: ":0", KEEP_DISPLAY_HOME: "1" },
    acquire: noSlot(),
    start,
  });
  assert.ok(existsSync(kept.home), "KEEP_DISPLAY_HOME=1 keeps it");
});

test("display-run: the scratch home wins over a caller's HOME and platform, on every platform", async () => {
  const { dir } = repo();
  let env;
  const start = async (command, argv, opts) => {
    env = opts.env;
    return { exit: 0, output: "", timedOut: false };
  };
  const r = await display.runWindowed({
    platform: "linux",
    cwd: dir,
    script: "res://x.gd",
    binary: "/bin/godot",
    env: { DISPLAY: ":0", HOME: "/Users/real" },
    extraEnv: { HOME: "/Users/real", XDG_DATA_HOME: "/x" },
    acquire: noSlot(),
    start,
  });
  assert.equal(env.HOME, r.home);
  assert.equal(env.XDG_DATA_HOME, path.join(r.home, "data"));
  assert.ok(env.XDG_CONFIG_HOME.startsWith(r.home) && env.XDG_CACHE_HOME.startsWith(r.home));
  const scratch = display.scratchEnv(dir);
  assert.ok(scratch.home.startsWith(path.resolve(dir, "artifacts/local") + path.sep));
});

test("display-run: refuses window-defeating engine flags and a script that is not res://", async () => {
  const { dir } = repo();
  const start = async () => assert.fail("must not start");
  for (const flag of [
    "--headless",
    "--display-driver",
    "--display-driver=headless",
    "--rendering-driver",
    "--path",
  ]) {
    const events = [];
    await assert.rejects(
      display.runWindowed({
        platform: "linux",
        cwd: dir,
        script: "res://x.gd",
        engineArgs: [flag, "x"],
        binary: "/bin/godot",
        acquire: noSlot(events),
        start,
      }),
      /refusing engine flag/,
    );
    assert.deepEqual(events, [], `${flag}: no slot taken`);
  }
  await assert.rejects(
    display.runWindowed({
      platform: "linux",
      cwd: dir,
      script: "/abs/x.gd",
      binary: "/bin/godot",
      acquire: noSlot(),
      start,
    }),
    /res:\/\//,
  );
});

test("display-run: releases the slot when the launch throws", async () => {
  const { dir } = repo();
  const events = [];
  await assert.rejects(
    display.runWindowed({
      platform: "linux",
      cwd: dir,
      script: "res://x.gd",
      binary: "/bin/godot",
      env: { DISPLAY: ":0" },
      acquire: noSlot(events),
      start: async () => {
        throw new Error("boom");
      },
    }),
    /boom/,
  );
  assert.deepEqual(events, ["acquire", "release"]);
});

test("display-run: the timeout kills the whole run, a forked child or an exec, in under 2 s", async () => {
  const { dir } = repo();
  for (const body of ["sleep 30 &\nwait\n", "exec sleep 30\n"]) {
    const fake = path.join(dir, `fake-${body.length}.sh`);
    writeFileSync(fake, `#!/bin/sh\necho started "$@"\n${body}`, { mode: 0o755 });
    const events = [];
    const t0 = Date.now();
    const r = await display.runWindowed({
      platform: "linux",
      cwd: dir,
      script: "res://x.gd",
      binary: fake,
      env: { DISPLAY: ":0" },
      timeoutMs: 300,
      acquire: noSlot(events),
    });
    assert.ok(Date.now() - t0 < 2000, `${body.trim()}: returned in ${Date.now() - t0} ms`);
    assert.equal(r.timedOut, true);
    assert.equal(r.exit, null);
    assert.match(r.output, /^started --path .* --script res:\/\/x\.gd --/);
    assert.deepEqual(events, ["acquire", "release"]);
  }
});

test("display-run: SIGTERM to the node process kills the run's group", async () => {
  const { dir } = repo();
  const pids = path.join(dir, "pids");
  const fake = path.join(dir, "fake-group.sh");
  writeFileSync(fake, `#!/bin/sh\nsleep 30 &\necho $$ $! > "${pids}"\nwait\n`, { mode: 0o755 });
  const runner = path.join(dir, "runner.mjs");
  writeFileSync(
    runner,
    `import { runWindowed } from ${JSON.stringify(path.join(here, "display-run.mjs"))};
await runWindowed({ platform: "linux", env: { DISPLAY: ":0" }, cwd: ${JSON.stringify(dir)}, script: "res://x.gd", binary: ${JSON.stringify(fake)}, timeoutMs: 20000, acquire: async () => ({ release() { console.error("released"); } }) });
process.exit(1); // An interrupted receipt producer must never reach its next step.
`,
  );
  const node = spawn(process.execPath, [runner], { stdio: "ignore" });
  const until = async (ok, ms) => {
    const end = Date.now() + ms;
    while (!ok() && Date.now() < end) await new Promise((r) => setTimeout(r, 50));
    return ok();
  };
  assert.ok(
    await until(
      () => existsSync(pids) && readFileSync(pids, "utf8").trim().split(" ").length === 2,
      5000,
    ),
    "the fake started",
  );
  const [shell, sleeper] = readFileSync(pids, "utf8").trim().split(" ").map(Number);
  const exited = new Promise((r) => node.on("exit", (code) => r(code)));
  node.kill("SIGTERM");
  assert.equal(await exited, 143);
  const alive = (pid) => {
    try {
      process.kill(pid, 0);
      return true;
    } catch {
      return false;
    }
  };
  assert.ok(
    await until(() => !alive(shell) && !alive(sleeper), 2000),
    "the shell and its child are gone",
  );
});

test("display-run: no display on Linux, or another platform, is not supported and starts nothing", async () => {
  let started = 0;
  const start = async () => {
    started += 1;
    return {};
  };
  const acquire = async () => {
    throw new Error("no slot needed");
  };
  const linux = await display.runWindowed({
    script: "res://x.gd",
    binary: "/bin/godot",
    platform: "linux",
    env: {},
    acquire,
    start,
  });
  assert.equal(linux.supported, false);
  assert.match(linux.output, /^not supported here: no DISPLAY or WAYLAND_DISPLAY/);
  assert.equal(
    (
      await display.runWindowed({
        script: "res://x.gd",
        binary: "/bin/godot",
        platform: "win32",
        env: {},
        acquire,
        start,
      })
    ).supported,
    false,
  );
  assert.equal(display.displayProblem("linux", { DISPLAY: ":0" }), "");
  assert.equal(started, 0);
});

// --- no-code-stand-ins ---

const STAKE = {
  file: "stakes.gd",
  mesh: "CylinderMesh",
  shape: "SableStakes/Stake/MeshInstance3D",
  row: "W1-23",
  path: "SableStakes/Stake1/m",
  stage: 1,
};
const SPHERE = {
  file: "build_read.gd",
  mesh: "SphereMesh",
  shape: "SubViewport/Node3D/MeshInstance3D",
  row: "W1-46",
  path: "PauseMenu/BuildRead/m",
  stage: 1,
};
const BOX = {
  file: "activities.gd",
  mesh: "BoxMesh",
  shape: "Activities/Activity_enemy_camp/PlantedStandIn",
  row: "",
  path: "Activities/Activity_enemy_camp/PlantedStandIn",
  stage: 1,
};
const PIN_TEXT = [
  "# comment",
  "build_read.gd\tSphereMesh\tSubViewport/Node3D/MeshInstance3D\tstand-in\tW1-46\tpause build preview: a grey sphere",
  "stakes.gd\tCylinderMesh\tSableStakes/Stake/MeshInstance3D\tstand-in\tW1-23\ttrade spot body (ruling ci, project-guide/handoff/DECISIONS.md:117: the bodies land after the sitting)",
  "stakes.gd\tTorusMesh\tSableStakes/Stake/MeshInstance3D\tstand-in\tW1-23\ttrade spot body (ruling ci: no cite)",
  "bay.gd\tBoxMesh\tMossBay/Barge/MeshInstance3D\tcode\t-\tbay marks",
].join("\n");
const WAITING = census.waitingFromPin(PIN_TEXT);

function censusRun({
  surfaces = census.PINNED_SURFACES,
  pinned = census.PINNED_SURFACES,
  standIns = [],
  fresh = [],
  stale = [],
  plant = "",
  ok,
  stage = true,
  verdict = true,
} = {}) {
  const failing = (fresh.length ? 1 : 0) + (stale.length ? 1 : 0) + (stage ? 0 : 1);
  const lines = [
    "[the pin reads]  -> PASS",
    `[the bot played through Brindle into stage 3] until at stage ${stage ? 3 : 2} -> ${stage ? "PASS" : "FAIL"}`,
    `[no primitive surface outside the pin] ${fresh.length} new -> ${fresh.length ? "FAIL" : "PASS"}`,
  ];
  lines.push(
    `SUMMARY ${JSON.stringify({ surfaces, pinned, stand_ins: standIns, new: fresh, stale, plant })}`,
  );
  if (verdict) lines.push(`${census.TEST}: ${failing ? `FAIL (${failing})` : "PASS (11 checks)"}`);
  return { ok: ok ?? failing === 0, log: lines.join("\n") };
}
const censusPlant = (fresh = [BOX]) =>
  censusRun({ surfaces: census.PINNED_SURFACES + 1, fresh, plant: "dam_box" });
const judge = (run, plant = censusPlant()) =>
  census.buildReceipt(run, plant, HEAD, { waiting: WAITING });

test("no-code-stand-ins: no stand-in, no new primitive, enough surfaces, the plant caught -> pass", () => {
  const r = judge(censusRun());
  assert.deepEqual(Object.keys(r), ["head", "pass", "measured", "plant_caught"]);
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.match(
    r.measured,
    new RegExp(
      `^${census.PINNED_SURFACES} primitive surfaces counted .*; no code-built stand-in left; plant: .* failed and named it new; what is not judged`,
    ),
  );
});

test("no-code-stand-ins: the pin's ruled rows wait, matched on the exact key and only with a cite", () => {
  assert.deepEqual(WAITING, [
    {
      key: "stakes.gd|CylinderMesh|SableStakes/Stake/MeshInstance3D",
      row: "W1-23",
      cite: "project-guide/handoff/DECISIONS.md:117",
    },
    { key: "stakes.gd|TorusMesh|SableStakes/Stake/MeshInstance3D", row: "W1-23", cite: "" },
  ]);
  const held = judge(censusRun({ standIns: [STAKE] }));
  assert.equal(held.pass, true);
  assert.match(
    held.measured,
    /no code-built stand-in left but those ruled to wait; waiting: SableStakes\/Stake\/MeshInstance3D in stakes\.gd \(CylinderMesh, owed by W1-23\) \(project-guide\/handoff\/DECISIONS\.md:117\)/,
  );
  const noCite = judge(censusRun({ standIns: [{ ...STAKE, mesh: "TorusMesh" }] }));
  assert.equal(noCite.pass, false, "a ruled row with an empty cite excuses nothing");
  const other = judge(
    censusRun({ standIns: [{ ...STAKE, shape: "SableStakes/Lamp/MeshInstance3D" }] }),
  );
  assert.equal(other.pass, false, "a new stakes.gd surface is not excused by the W1-23 rows");
  assert.match(
    other.measured,
    /1 code-built stand-in\(s\) left: SableStakes\/Lamp\/MeshInstance3D in stakes\.gd/,
  );
});

test("no-code-stand-ins: a stand-in the pin allows still fails and is named by file and row", () => {
  const r = judge(censusRun({ standIns: [SPHERE, STAKE] }));
  assert.equal(r.pass, false);
  assert.match(
    r.measured,
    /1 code-built stand-in\(s\) left: SubViewport\/Node3D\/MeshInstance3D in build_read\.gd \(SphereMesh, owed by W1-46\)/,
  );
});

test("no-code-stand-ins: each guard fails alone", () => {
  const few = judge(censusRun({ surfaces: census.PINNED_SURFACES - 1 }));
  assert.equal(few.pass, false);
  assert.match(
    few.measured,
    new RegExp(
      `^the census counted ${census.PINNED_SURFACES - 1} primitive surfaces, pinned at least ${census.PINNED_SURFACES}`,
    ),
  );
  const pin = judge(censusRun({ pinned: 100 }));
  assert.equal(pin.pass, false);
  assert.match(pin.measured, /\(test pin 100\)/);
  const stage = judge(censusRun({ stage: false, ok: true }));
  assert.equal(stage.pass, false);
  assert.match(stage.measured, /^the bot did not reach stage 3/);
  const runner = judge(censusRun({ ok: false }));
  assert.equal(runner.pass, false);
  assert.match(runner.measured, /; the runner did not pass the test/);
  assert.equal(judge(censusRun({ verdict: false })).pass, false, "no verdict line");
  const none = judge(
    { ok: false, log: "runner exit 1, no prim_census_test.log" },
    { ok: false, log: "" },
  );
  assert.equal(none.pass, false);
  assert.equal(none.plant_caught, false);
  assert.match(none.measured, /^no SUMMARY line, so nothing was counted/);
  const fresh = judge(censusRun({ fresh: [{ ...BOX, shape: "Dam/Gate/MeshInstance3D" }] }));
  assert.equal(fresh.pass, false);
  assert.match(
    fresh.measured,
    /1 new primitive\(s\) no pin row covers: Dam\/Gate\/MeshInstance3D in activities\.gd/,
  );
  const stale = judge(
    censusRun({
      stale: [{ line: 15, file: "build_read.gd", mesh: "SphereMesh", shape: "x", row: "W1-46" }],
    }),
  );
  assert.equal(stale.pass, false);
  assert.match(stale.measured, /stale stand-in row\(s\): pin line 15 build_read\.gd/);
});

test("no-code-stand-ins: a plant not caught voids the pass", () => {
  assert.equal(
    judge(censusRun(), censusRun({ plant: "dam_box" })).plant_caught,
    false,
    "the planted run passed",
  );
  assert.equal(
    judge(censusRun(), censusPlant([{ ...BOX, shape: "Dam/Other/MeshInstance3D" }])).plant_caught,
    false,
    "failed for another box",
  );
  assert.equal(judge(censusRun(), { ok: false, log: "" }).plant_caught, false);
});

test("no-code-stand-ins: a plant switch that reached the counting run fails the receipt", () => {
  const r = judge(censusPlant());
  assert.equal(r.pass, false);
  assert.match(r.measured, /^the counting run ran planted \(dam_box\)/);
});

test("no-code-stand-ins: the producer runs the test then the plant, reads the pin, takes the head from git, refuses a dirty checkout", () => {
  const { dir, head } = repo();
  const calls = [];
  const run = (cwd, name, env = {}) => {
    calls.push([name, env]);
    return env.PRIM_PLANT ? censusPlant() : censusRun({ standIns: [STAKE] });
  };
  const noPin = census.produce({ cwd: dir, run });
  assert.equal(noPin.pass, false, "with no pin file nothing waits");
  const pinDir = path.join(dir, path.dirname(census.PIN));
  spawnSync("mkdir", ["-p", pinDir]);
  writeFileSync(path.join(dir, census.PIN), PIN_TEXT);
  spawnSync("git", ["-c", "user.name=t", "-c", "user.email=t@t", "add", "."], { cwd: dir });
  spawnSync("git", ["-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "pin"], {
    cwd: dir,
  });
  const r = census.produce({ cwd: dir, run });
  assert.notEqual(r.head, head);
  assert.equal(r.pass, true);
  assert.deepEqual(calls.slice(0, 2), [
    ["prim_census_test", {}],
    ["prim_census_test", { PRIM_PLANT: "dam_box" }],
  ]);
  writeFileSync(path.join(dir, "a.txt"), "two");
  assert.throws(() => census.produce({ cwd: dir, run }), /refusing: uncommitted changes/);
  assert.equal(calls.length, 4, "a dirty checkout never runs the test");
});
