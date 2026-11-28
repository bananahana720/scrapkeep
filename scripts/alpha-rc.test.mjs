import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { once } from "node:events";
import {
  chmodSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  utimesSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test, { after, describe } from "node:test";
import {
  MENU_READY,
  TITLE_INTERACTIVE,
  STEP_IDS,
  appImageName,
  buildPlan,
  gitState,
  judgeCommand,
  judgeRedteam,
  judgeTree,
  BOOT_FAILED,
  bootFailure,
  launchAppImage,
  launchEnv,
  placeholderKinds,
  parseArgs,
  processAlive,
  runAlphaRc,
  runProcess,
  verdict,
} from "./alpha-rc.mjs";
import { git as runGit } from "./lib/git.mjs";

const createdTempDirs = [];
const tmp = () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "alpha-rc-test-"));
  createdTempDirs.push(dir);
  return dir;
};
after(() => {
  for (const dir of createdTempDirs) rmSync(dir, { recursive: true, force: true });
});
const head = "79161558ad10650a38fae04d95908db003d59097";
const git = { head, clean: true, dirty: [], commitTime: 1_000 };
const pass = (extra = {}) => ({
  wave: 21,
  commit: head,
  quick: false,
  runs: [{ id: "speedrunner-tally-2600", pilot: "tally", seed: 2600 }],
  findings: [],
  carry: [],
  ...extra,
});
const previous = { wave: 20, commit: "c".repeat(40), runs: [{ id: "x" }], findings: [], carry: [] };
const wave14 = { ...previous, wave: 14 };

function inputs() {
  const dir = tmp();
  const capture = path.join(dir, "capture.csv");
  const redteam = path.join(dir, "findings.json");
  const carryFrom = path.join(dir, "last.json");
  const appimage = path.join(dir, appImageName(head));
  writeFileSync(capture, "fps,frametime\n");
  writeFileSync(redteam, JSON.stringify(pass()));
  writeFileSync(carryFrom, JSON.stringify(previous));
  writeFileSync(appimage, "");
  return {
    dir,
    flags: [
      `--capture=${capture}`,
      `--redteam=${redteam}`,
      `--carry-from=${carryFrom}`,
      `--appimage=${appimage}`,
    ],
  };
}

const allPass = {
  git,
  recheck: () => git,
  run: async () => ({ exit: 0, output: "[]" }),
  launch: async () => ({ status: "pass", note: "menu", ms: 900, output: "" }),
  find: () => null,
  log: () => {},
};

test("parseArgs rejects unknown flags and unknown skip ids", () => {
  assert.throws(() => parseArgs(["--nope"]), /unknown argument/);
  assert.throws(() => parseArgs(["--skip=smoke,fly"]), /unknown step fly/);
  assert.deepEqual([...parseArgs(["--skip=smoke,bots"]).skip], ["smoke", "bots"]);
});

test("the plan runs every gate in order, smoke and bots as gate receipts, and swaps the cloud export", () => {
  const plan = buildPlan(parseArgs([]), git, { find: () => null });
  assert.deepEqual(
    plan.map((s) => s.id),
    STEP_IDS,
  );
  const byId = Object.fromEntries(plan.map((s) => [s.id, s]));
  assert.deepEqual(byId.smoke.args.slice(1), ["--sketch", "core-loop", "--receipt", "gate"]);
  assert.deepEqual(byId.bots.args.slice(1), [
    "--sketch",
    "core-loop",
    "--bots",
    "--receipt",
    "gate-bots",
  ]);
  assert.match(byId.lint.args[0], /sketch-lint\.mjs$/);
  assert.match(byId.export.args[0], /sketch-export\.mjs$/);
  const cloud = buildPlan(parseArgs(["--cloud"]), git, { find: () => null });
  assert.match(cloud.find((s) => s.id === "export").args[0], /cloud\/export-headless\.mjs$/);
});

test("with no inputs, frame time, red team and launch read not run, and the verdict is never GO", async () => {
  const { results, outcome, page } = await runAlphaRc(parseArgs([]), allPass);
  const byId = Object.fromEntries(results.map((r) => [r.id, r.status]));
  assert.deepEqual(byId, {
    tree: "pass",
    placeholders: "pass",
    lint: "pass",
    smoke: "pass",
    bots: "pass",
    export: "pass",
    frametime: "not run",
    redteam: "not run",
    launch: "not run",
  });
  assert.deepEqual(outcome, { verdict: "INCOMPLETE", exit: 2 });
  assert.match(page, /⬜ not run \| no --capture/);
});

test("red team without --carry-from reads not run", async () => {
  const { flags } = inputs();
  const { results } = await runAlphaRc(
    parseArgs(flags.filter((f) => !f.startsWith("--carry-from"))),
    allPass,
  );
  assert.match(results.find((r) => r.id === "redteam").note, /no --carry-from/);
  assert.equal(results.find((r) => r.id === "redteam").status, "not run");
});

test("every step green on a clean tree gives GO and writes RC.md and rc.json", async () => {
  const { dir, flags } = inputs();
  const outDir = path.join(dir, "out");
  const { outcome } = await runAlphaRc(parseArgs(flags), { ...allPass, outDir });
  assert.deepEqual(outcome, { verdict: "GO", exit: 0 });
  assert.match(readFileSync(path.join(outDir, "RC.md"), "utf8"), /^# Release candidate: GO/);
  assert.equal(
    JSON.parse(readFileSync(path.join(outDir, "rc.json"), "utf8")).results.length,
    STEP_IDS.length,
  );
});

test("a dirty tree or a missing HEAD keeps it off GO", async () => {
  const { flags } = inputs();
  const dirty = await runAlphaRc(parseArgs(flags), {
    ...allPass,
    git: { ...git, clean: false, dirty: ["src/game.gd"] },
  });
  assert.equal(dirty.outcome.verdict, "NO-GO");
  assert.match(dirty.results[0].note, /src\/game\.gd/);
  assert.equal(judgeTree({ head: null, clean: false, dirty: [] }).status, "not run");
  const changed = await runAlphaRc(parseArgs(flags), {
    ...allPass,
    recheck: () => ({ ...git, clean: false, dirty: ["project.godot"] }),
  });
  assert.equal(changed.outcome.verdict, "NO-GO");
  assert.match(changed.results.at(-1).note, /project\.godot/);
});

test("a cloud run that passes everything is only a rehearsal", async () => {
  const { flags } = inputs();
  const { outcome } = await runAlphaRc(parseArgs(["--cloud", ...flags]), allPass);
  assert.deepEqual(outcome, { verdict: "REHEARSAL PASSED", exit: 2 });
});

test("one failing step makes it NO-GO and the page carries its last lines", async () => {
  const { flags } = inputs();
  const run = async (step) =>
    step.id === "bots"
      ? { exit: 1, output: "FAIL bot skipper seed 3: boss_stalled" }
      : { exit: 0, output: "[]" };
  const { outcome, page } = await runAlphaRc(parseArgs(flags), { ...allPass, run });
  assert.deepEqual(outcome, { verdict: "NO-GO", exit: 1 });
  assert.match(page, /boss_stalled/);
});

test("--skip turns a step into not run", async () => {
  const { flags } = inputs();
  const { results } = await runAlphaRc(parseArgs([...flags, "--skip=export"]), allPass);
  assert.deepEqual(
    results.find((r) => r.id === "export"),
    {
      id: "export",
      label: "Export proofs",
      criterion: "the shipped pack wins",
      status: "not run",
      note: "skipped with --skip",
      ms: null,
    },
  );
});

test("the AppImage must be this commit's build", () => {
  const { dir } = inputs();
  const plan = (args, find = () => null) =>
    buildPlan(parseArgs(args), git, { find }).find((s) => s.id === "launch");
  const installed = path.join(dir, "Scrapkeep.AppImage");
  writeFileSync(installed, "");
  assert.match(
    plan([`--appimage=${installed}`]).needs,
    /is not this commit's Scrapkeep-7916155-x86_64\.AppImage/,
  );
  const other = path.join(dir, "Scrapkeep-cf63e62-x86_64.AppImage");
  writeFileSync(other, "");
  assert.ok(plan([`--appimage=${other}`]).needs);
  const dirty = path.join(dir, "Scrapkeep-7916155-dirty-x86_64.AppImage");
  writeFileSync(dirty, "");
  assert.ok(plan([`--appimage=${dirty}`]).needs);
  assert.match(plan([]).needs, /no Scrapkeep-7916155-x86_64\.AppImage under artifacts/);
  assert.equal(plan([], () => "/found/it").appimage, "/found/it");
  assert.match(
    buildPlan(parseArgs([]), { ...git, head: null }, { find: () => "/x" }).find(
      (s) => s.id === "launch",
    ).needs,
    /no git HEAD/,
  );
});

test("a capture older than the commit reads not run", () => {
  const dir = tmp();
  const capture = path.join(dir, "old.csv");
  writeFileSync(capture, "");
  utimesSync(capture, 500, 500);
  const step = buildPlan(parseArgs([`--capture=${capture}`]), git, { find: () => null }).find(
    (s) => s.id === "frametime",
  );
  assert.match(step.needs, /older than the commit/);
});

test("sub-command exits are read in each tool's terms", () => {
  assert.deepEqual(
    judgeCommand({ id: "placeholders" }, { exit: 1, output: '[{"kind":"park"},{"kind":"icon"}]' }),
    { status: "fail", note: "2 placeholders" },
  );
  assert.equal(judgeCommand({ id: "frametime" }, { exit: 2, output: "" }).status, "not run");
  assert.equal(judgeCommand({ id: "frametime" }, { exit: 1, output: "" }).status, "fail");
  assert.equal(judgeCommand({ id: "smoke" }, { exit: 2, output: "" }).status, "not run");
  assert.equal(judgeCommand({ id: "smoke" }, { exit: 3, output: "" }).status, "fail");
  assert.equal(
    judgeCommand({ id: "smoke" }, { exit: null, output: "" }).note,
    "timed out or killed",
  );
  assert.equal(
    judgeCommand({ id: "smoke" }, { exit: null, output: "", error: "ENOENT" }).status,
    "fail",
  );
  assert.equal(
    judgeCommand({ id: "smoke" }, { exit: 0, output: "sketch:smoke pass" }).status,
    "pass",
  );
});

test("red team: shape, commit, quick, blockers and carry replays", () => {
  assert.equal(
    judgeRedteam(pass({ findings: [{ severity: "major" }] }), head, previous).status,
    "pass",
  );
  assert.match(
    judgeRedteam(
      pass({ findings: [{ severity: "blocker", title: "Brindle stalls" }] }),
      head,
      previous,
    ).note,
    /Brindle stalls/,
  );
  assert.equal(judgeRedteam({}, head, previous).status, "fail");
  assert.equal(judgeRedteam(pass({ runs: [] }), head, previous).status, "fail");
  assert.equal(judgeRedteam(pass(), head, {}).status, "fail");
  assert.match(judgeRedteam(pass(), head, { ...previous, wave: 21 }).note, /not an earlier wave/);
  assert.equal(judgeRedteam(pass(), head, { ...previous, commit: head }).status, "fail");
  assert.equal(judgeRedteam(pass({ commit: "" }), head, previous).status, "not run");
  assert.equal(judgeRedteam(pass({ commit: head.slice(0, 8) }), head, previous).status, "not run");
  assert.equal(judgeRedteam(pass(), null, previous).status, "not run");
  assert.equal(judgeRedteam(pass({ quick: true }), head, previous).status, "not run");
  const carrying = { ...previous, carry: [{ pilot: "tally", seed: 2506, title: "stall" }] };
  assert.equal(judgeRedteam(pass(), head, carrying).status, "fail");
  const replayed = pass({
    runs: [{ id: "carry-0-first-timer-tally-2506", pilot: "tally", seed: 2506 }],
  });
  assert.equal(judgeRedteam(replayed, head, carrying).status, "pass");
});

const W15 = "/mnt/project-files/redteam/w15/findings.json";
test(
  "the real w15 findings: zero blockers on their own commit, not run on another",
  { skip: !existsSync(W15) && "w15 findings not mounted" },
  () => {
    const w15 = JSON.parse(readFileSync(W15, "utf8"));
    assert.equal(judgeRedteam(w15, w15.commit, wave14).status, "pass");
    assert.equal(judgeRedteam(w15, "cf63e622" + "0".repeat(32), wave14).status, "not run");
  },
);

test("gitState reads HEAD and dirtiness through git, including in a linked worktree", () => {
  const repo = tmp();
  const g = (...a) => runGit(a, { cwd: repo });
  g("init", "-q");
  g("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "x");
  const sha = g("rev-parse", "HEAD");
  assert.deepEqual(gitState(repo).head, sha);
  assert.equal(gitState(repo).clean, true);
  const wt = path.join(repo, "..", path.basename(repo) + "-wt");
  g("worktree", "add", "-q", wt);
  assert.equal(gitState(wt).head, sha);
  writeFileSync(path.join(wt, "stray"), "");
  assert.deepEqual(gitState(wt).dirty, ["stray"]);
  rmSync(wt, { recursive: true, force: true });
  assert.equal(gitState(tmp()).head, null);
});

test("launch env drops GODOT_BIN and shadows each godot on PATH with a failing shim, keeping the rest", () => {
  const withGodot = tmp();
  writeFileSync(path.join(withGodot, "godot4"), "#!/bin/sh\nexit 0\n");
  chmodSync(path.join(withGodot, "godot4"), 0o755);
  writeFileSync(path.join(withGodot, "tool"), "#!/bin/sh\necho tool-ran\n");
  chmodSync(path.join(withGodot, "tool"), 0o755);
  const clean = tmp();
  const home = tmp();
  const env = launchEnv(
    { PATH: `${withGodot}:${clean}`, GODOT_BIN: "/opt/godot", DISPLAY: ":0" },
    { HOME: home },
  );
  assert.equal(env.PATH, `${path.join(home, ".no-godot")}:${withGodot}:${clean}`);
  assert.equal(env.GODOT_BIN, undefined);
  assert.equal(env.DISPLAY, ":0");
  assert.equal(env.HOME, home);
  const godot = spawnSync("godot4", [], { env, encoding: "utf8" });
  assert.equal(godot.status, 127);
  assert.match(godot.stderr, /godot4 called on a machine without Godot/);
  assert.equal(spawnSync("tool", [], { env, encoding: "utf8" }).stdout.trim(), "tool-ran");
});

function fake(dir, name, body) {
  const file = path.join(dir, name);
  writeFileSync(file, `#!/bin/sh\necho $$ >> "${path.join(dir, "groups")}"\n${body}\n`);
  chmodSync(file, 0o755);
  return file;
}

function reapFakes(t, dir) {
  t.after(() => {
    const groups = path.join(dir, "groups");
    if (!existsSync(groups)) return;
    for (const pgid of readFileSync(groups, "utf8").split("\n").filter(Boolean)) {
      try {
        process.kill(-Number(pgid), "SIGKILL");
      } catch (error) {
        if (error.code !== "ESRCH") throw error;
      }
    }
  });
}

const alive = processAlive;
const GUARD_S = 30;
const LATE_S = GUARD_S + 15;

test("processAlive detects a live child on both Linux and macOS and clears once killed", async () => {
  const sleeper = spawn("sleep", ["30"], { stdio: "ignore" });
  try {
    assert.equal(alive(sleeper.pid), true);
  } finally {
    sleeper.kill("SIGKILL");
    await once(sleeper, "exit");
  }
  assert.equal(alive(sleeper.pid), false);
});

test(
  "cold launch: menu-ready line passes on a fresh XDG profile, and the profile and the game's process group go away",
  { timeout: GUARD_S * 1000 },
  async (t) => {
    const dir = tmp();
    reapFakes(t, dir);
    const pidFile = path.join(dir, "pid");
    const before = readdirSync(os.tmpdir()).filter((n) =>
      n.startsWith("scrapkeep-rc-home-"),
    ).length;
    const ready = fake(
      dir,
      "ready.sh",
      `sleep ${LATE_S} & echo $! > ${pidFile}; echo "home=$HOME cfg=$XDG_CONFIG_HOME data=$XDG_DATA_HOME godot=$GODOT_BIN"; echo "${TITLE_INTERACTIVE} ms=700"; sleep 0.2; echo "${MENU_READY} ms=2500"; wait`,
    );
    const result = await launchAppImage(ready, {
      seconds: GUARD_S,
      env: { ...process.env, GODOT_BIN: "/opt/godot" },
    });
    assert.equal(result.status, "pass");
    assert.match(
      result.note,
      /interactive title in \d\.\d s \(budget 30 s\), 3D title in \d\.\d s/,
    );
    assert.ok(result.titleMs !== null && result.menuMs >= result.titleMs);
    const home = result.output.match(/home=(\S+)/)[1];
    assert.match(home, /scrapkeep-rc-home-/);
    assert.equal(result.output.match(/cfg=(\S+)/)[1], path.join(home, ".config"));
    assert.equal(result.output.match(/data=(\S+)/)[1], path.join(home, ".local/share"));
    assert.match(result.output, /godot=\n/);
    assert.equal(existsSync(home), false);
    assert.equal(
      readdirSync(os.tmpdir()).filter((n) => n.startsWith("scrapkeep-rc-home-")).length,
      before,
    );
    assert.equal(alive(Number(readFileSync(pidFile, "utf8"))), false);
  },
);

describe("cold launch and process timeouts", { concurrency: true, timeout: GUARD_S * 1000 }, () => {
  test("cold launch fails on an early exit, on silence, and outlasts a game that ignores SIGTERM", async (t) => {
    const dir = tmp();
    reapFakes(t, dir);
    const [crash, silent, noMenu, late, stubborn] = await Promise.all([
      launchAppImage(fake(dir, "crash.sh", "exit 3"), { seconds: GUARD_S }),
      launchAppImage(fake(dir, "silent.sh", `exec sleep ${LATE_S}`), { seconds: 0.5 }),
      launchAppImage(
        fake(dir, "nomenu.sh", `echo "${TITLE_INTERACTIVE} ms=900"; exec sleep ${LATE_S}`),
        {
          seconds: GUARD_S,
          menuWaitSeconds: 0.6,
        },
      ),
      launchAppImage(
        fake(
          dir,
          "late.sh",
          `sleep ${LATE_S}; echo "${TITLE_INTERACTIVE} ms=800"; echo "${MENU_READY} ms=900"; sleep ${LATE_S}`,
        ),
        { seconds: 0.4 },
      ),
      launchAppImage(fake(dir, "stubborn.sh", "trap '' TERM; while true; do sleep 0.1; done"), {
        seconds: 0.3,
      }),
    ]);
    assert.match(crash.note, /exited \(3\)/);
    assert.match(silent.note, /no SCRAPKEEP_TITLE_INTERACTIVE line within 0.5 s/);
    assert.equal(noMenu.status, "fail");
    assert.match(
      noMenu.note,
      /no SCRAPKEEP_MENU_READY line within 0.6 s \(title card at \d\.\d s\)/,
    );
    assert.equal(late.status, "fail");
    assert.match(late.note, /no SCRAPKEEP_TITLE_INTERACTIVE line within 0.4 s/);
    assert.equal(stubborn.status, "fail");
  });

  test("cold launch: a build that says it did not load fails at once, with the boot's reason, and does not wait out the menu", async (t) => {
    const dir = tmp();
    reapFakes(t, dir);
    const [card, headless, held, quoted] = await Promise.all([
      launchAppImage(
        fake(
          dir,
          "card.sh",
          `echo "${TITLE_INTERACTIVE} ms=300"; echo "${BOOT_FAILED} the game scene's script did not load"; sleep ${LATE_S}; echo "${MENU_READY} ms=${LATE_S}300"; exec sleep ${LATE_S}`,
        ),
        { seconds: GUARD_S, menuWaitSeconds: LATE_S },
      ),
      launchAppImage(
        fake(
          dir,
          "headless.sh",
          `echo "${BOOT_FAILED} res://scenes/main.tscn did not load"; exit 1`,
        ),
        { seconds: GUARD_S },
      ),
      launchAppImage(
        fake(dir, "held.sh", `(sleep ${LATE_S}; echo pipes closed) & echo last words; exit 3`),
        { seconds: GUARD_S },
      ),
      launchAppImage(
        fake(
          dir,
          "quoted.sh",
          `echo "note: ${BOOT_FAILED} is the failure marker"; echo "${TITLE_INTERACTIVE} ms=300"; echo "${MENU_READY} ms=400"; exec sleep ${LATE_S}`,
        ),
        { seconds: GUARD_S },
      ),
    ]);
    assert.equal(card.status, "fail");
    assert.equal(
      card.note,
      "the build said it did not load (SCRAPKEEP_BOOT_FAILED): the game scene's script did not load",
    );
    assert.equal(card.menuMs, null);
    assert.doesNotMatch(card.output, /SCRAPKEEP_MENU_READY/);
    assert.equal(headless.status, "fail");
    assert.match(
      headless.note,
      /the build said it did not load \(SCRAPKEEP_BOOT_FAILED\): res:\/\/scenes\/main\.tscn did not load$/,
    );
    assert.match(held.note, /^exited \(3\) before the main menu$/);
    assert.match(held.output, /last words/);
    assert.doesNotMatch(held.output, /pipes closed/);
    assert.equal(quoted.status, "pass");
  });

  test("runProcess returns the exit, and a timeout kills the group and reads as killed", async (t) => {
    const dir = tmp();
    reapFakes(t, dir);
    const pidFile = path.join(dir, "pid");
    const [ok, hung] = await Promise.all([
      runProcess({ command: fake(dir, "ok.sh", "echo hi; exit 4"), args: [] }),
      runProcess(
        { command: fake(dir, "hang.sh", `sleep ${LATE_S} & echo $! > ${pidFile}; wait`), args: [] },
        300,
      ),
    ]);
    assert.equal(ok.exit, 4);
    assert.equal(hung.exit, null);
    assert.equal(judgeCommand({ id: "smoke" }, hung).note, "timed out or killed");
    assert.equal(alive(Number(readFileSync(pidFile, "utf8"))), false);
  });
});

test("bootFailure reads the reason from one whole line that starts with the marker", () => {
  assert.equal(bootFailure(""), null);
  assert.equal(bootFailure(`${TITLE_INTERACTIVE} ms=300\n${MENU_READY} ms=900\n`), null);
  assert.equal(
    bootFailure(`${BOOT_FAILED} the game scene's scr`),
    null,
    "a line still arriving is not read yet",
  );
  assert.equal(
    bootFailure(
      `${TITLE_INTERACTIVE} ms=300\n${BOOT_FAILED} the game scene's script did not load\nERROR: boot: x\n`,
    ),
    "the game scene's script did not load",
  );
  assert.equal(bootFailure(`${BOOT_FAILED} why\r\n`), "why");
  assert.equal(bootFailure(`${BOOT_FAILED}\n`), "no reason given");
  assert.equal(bootFailure(`ERROR: saw ${BOOT_FAILED} somewhere\n`), null);
  assert.equal(bootFailure(`${BOOT_FAILED}_TWICE x\n`), null);
});

test("verdict order: any fail beats not run; a note with a newline stays one table row", async () => {
  assert.equal(verdict([{ status: "fail" }, { status: "not run" }]).verdict, "NO-GO");
  assert.equal(verdict([{ status: "pass" }]).verdict, "GO");
  const { flags } = inputs();
  const run = async (step) =>
    step.id === "lint" ? { exit: 1, output: "x" } : { exit: 0, output: "[]" };
  const launch = async () => ({ status: "fail", note: "line one\nline two", ms: 1, output: "" });
  const { page } = await runAlphaRc(parseArgs(flags), { ...allPass, run, launch });
  assert.match(page, /\| line one line two \|/);
});

test("placeholder failures list counts by kind", () => {
  assert.equal(
    placeholderKinds('[{"kind":"park"},{"kind":"icon"},{"kind":"park"}]'),
    "park 2\nicon 1",
  );
  assert.equal(placeholderKinds("not json"), "not json");
});
