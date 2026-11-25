import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

import { root } from "./clean-head.mjs";
import {
  buildReceipt as installedBuildReceipt,
  defaultAppImage,
  gradeBuildTxt,
  mismatchedCommit,
  produce as installedBuildProduce,
} from "./installed-build-receipt.mjs";
import {
  gradeTallyRun,
  plantRedShard,
  produce as releaseGateProduce,
} from "./release-gate-receipt.mjs";
import { gateLists } from "./shard.mjs";
import {
  PILOTS,
  REQUIRED_PILOT_CHECKS,
  buildReceipt as sixPilotsReceipt,
  gradeWorld1Log,
  injectPlantedScriptError,
  produce as sixPilotsProduce,
} from "./six-pilots-receipt.mjs";
import {
  CONTROL_CHECKS,
  buildReceipt as snagSweepReceipt,
  evaluate as snagSweepEvaluate,
  gradeControlLog,
  gradeMapReport,
  injectPlantedSnag,
  produce as snagSweepProduce,
} from "./snag-sweep-receipt.mjs";
import { expectedShards } from "./tally.mjs";
import {
  BUDGET_TESTS,
  buildReceipt as wordsReceipt,
  gradeBudgetLog,
  gradeLintOutput,
  produce as wordsProduce,
  runPlantedWordLint,
} from "./words-on-screen-receipt.mjs";
import { receiptRow } from "../world1-bands.mjs";

const HEAD = "e1cf07102537244bbc25eeeb1c3b8b29f287952f";
const OTHER_HEAD = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

function withTempDir(prefix, fn) {
  const dir = mkdtempSync(path.join(os.tmpdir(), prefix));
  try {
    return fn(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function initTempGitRepo(dir, files = { "sketches/core-loop/src/a.gd": "extends Node\n" }) {
  const git = (...args) =>
    spawnSync("git", ["-c", "user.name=t", "-c", "user.email=t@t", ...args], {
      cwd: dir,
      encoding: "utf8",
    });
  git("init", "-q");
  for (const [rel, content] of Object.entries(files)) {
    mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    writeFileSync(path.join(dir, rel), content);
  }
  git("add", ".");
  git("commit", "-q", "-m", "init");
  return { git, head: git("rev-parse", "HEAD").stdout.trim() };
}

function runCli(scriptRel, argv) {
  return spawnSync(process.execPath, [path.join(root, scriptRel), ...argv], {
    cwd: root,
    encoding: "utf8",
  });
}

const INSTALLED_ROW = {
  id: "installed-build",
  plant: "an image built from another commit must read as a miss",
  producer: "node scripts/gate/installed-build-receipt.mjs",
};

test("installed-build: passes on clean matching BUILD.txt (full and prefix) and integrates with receiptRow", () => {
  const text = `commit: ${HEAD}\ndirty: false\nbuilt: 20261124T120000\ngodot: 4.7.2.stable\n`;
  const rFull = installedBuildReceipt(text, HEAD);
  assert.equal(rFull.pass, true);
  assert.equal(rFull.plant_caught, true);
  assert.equal(rFull.head, HEAD);
  assert.deepEqual(receiptRow(INSTALLED_ROW, rFull, HEAD), {
    measured: rFull.measured,
    pass: true,
  });

  const shortHead = HEAD.slice(0, 9);
  const rPrefix = installedBuildReceipt(text, shortHead);
  assert.equal(rPrefix.pass, true);
  assert.equal(rPrefix.plant_caught, true);
  assert.equal(receiptRow(INSTALLED_ROW, rPrefix, HEAD).pass, true);
  assert.equal(receiptRow(INSTALLED_ROW, rFull, OTHER_HEAD).noData, true);
});

test("installed-build: rejects mismatched commit, -dirty suffix, dirty: true, bad hex, and missing commit", () => {
  assert.equal(installedBuildReceipt(`commit: ${OTHER_HEAD}\ndirty: false\n`, HEAD).pass, false);
  assert.equal(
    installedBuildReceipt(`commit: ${HEAD.slice(0, 12)}-dirty\ndirty: false\n`, HEAD).pass,
    false,
  );
  assert.equal(installedBuildReceipt(`commit: ${HEAD}\ndirty: true\n`, HEAD).pass, false);
  assert.equal(installedBuildReceipt("commit: not-hex-value\ndirty: false\n", HEAD).pass, false);
  assert.equal(installedBuildReceipt("built: 20261124\n", HEAD).pass, false);
  const zeroHead = "0000000abcdef0123456789abcdef01234567890";
  assert.notEqual(mismatchedCommit(zeroHead)[0], "0");
  assert.equal(
    gradeBuildTxt(`commit: ${mismatchedCommit(zeroHead)}\ndirty: false\n`, zeroHead).ok,
    false,
  );
});

test("installed-build: defaultAppImage honors XDG_DATA_HOME and falls back to ~/.local/share", () => {
  assert.equal(
    defaultAppImage({ XDG_DATA_HOME: "/custom/data" }, "/home/u"),
    "/custom/data/scrapkeep/Scrapkeep.AppImage",
  );
  assert.equal(defaultAppImage({}, "/home/u"), "/home/u/.local/share/scrapkeep/Scrapkeep.AppImage");
});

test("installed-build: extracts usr/lib/scrapkeep/BUILD.txt from an executable AppImage and cleans up temp dir", () => {
  withTempDir("installed-build-test-", (dir) => {
    const fakeAppImage = path.join(dir, "Scrapkeep.AppImage");
    writeFileSync(
      fakeAppImage,
      [
        "#!/bin/sh",
        'if [ "$1" = "--appimage-extract" ] && [ "$2" = "usr/lib/scrapkeep/BUILD.txt" ]; then',
        "  mkdir -p squashfs-root/usr/lib/scrapkeep",
        `  printf 'commit: ${HEAD}\\ndirty: false\\n' > squashfs-root/usr/lib/scrapkeep/BUILD.txt`,
        "  exit 0",
        "fi",
        "exit 1",
        "",
      ].join("\n"),
    );
    chmodSync(fakeAppImage, 0o755);

    const r = installedBuildProduce({ head: HEAD, appImage: fakeAppImage });
    assert.equal(r.pass, true);
    assert.equal(r.plant_caught, true);

    const missing = installedBuildProduce({
      head: HEAD,
      appImage: path.join(dir, "missing.AppImage"),
    });
    assert.equal(missing.pass, false);
    assert.equal(missing.plant_caught, true);
    assert.match(missing.measured, /AppImage not found/);

    const buildTxt = path.join(dir, "BUILD.txt");
    writeFileSync(buildTxt, `commit: ${HEAD}\ndirty: false\n`);
    const outFile = path.join(dir, "out", "installed-build.json");
    const okCli = runCli("scripts/gate/installed-build-receipt.mjs", [
      "--head",
      HEAD,
      "--build-txt",
      buildTxt,
      "--out",
      outFile,
    ]);
    assert.equal(okCli.status, 0, okCli.stderr);
    const written = JSON.parse(readFileSync(outFile, "utf8"));
    assert.equal(written.pass, true);
    assert.equal(written.plant_caught, true);

    writeFileSync(buildTxt, `commit: ${OTHER_HEAD}\ndirty: false\n`);
    const missCli = runCli("scripts/gate/installed-build-receipt.mjs", [
      "--head",
      HEAD,
      "--build-txt",
      buildTxt,
    ]);
    assert.equal(missCli.status, 1);

    const badCli = runCli("scripts/gate/installed-build-receipt.mjs", ["--head", "bad"]);
    assert.equal(badCli.status, 2);
  });
});

const WORDS_ROW = {
  id: "words-on-screen",
  plant: "a label that restates its value must fail the lint",
  producer: "node scripts/gate/words-on-screen-receipt.mjs",
};

const makeBudgetLog = (
  testName,
  { words = 18, fail = false, error = false, teardown = false } = {},
) =>
  [
    `[word budget] ${words} HUD words in a stage-1 posture fight (budget 25); 2 more on world signs -> ${fail ? "FAIL" : "PASS"}`,
    ...(error ? ["SCRIPT ERROR: planted UI error"] : []),
    `${testName}: ${fail ? "FAIL (1)" : "PASS"}`,
    ...(teardown
      ? [
          "ERROR: 2 RID allocations of type 'N13RendererDummy15MaterialStorage11DummyShaderE' were leaked at exit.",
        ]
      : []),
  ].join("\n");

test("words-on-screen: real planted word-lint catches a label that restates its value with W6", () => {
  const planted = runPlantedWordLint(root);
  assert.equal(planted.caught, true);
  assert.ok(planted.findings.some((f) => f.rule === "W6"));
});

test("words-on-screen: grades passing and failing lint, word-budget logs, teardown noise, and plant_caught", () => {
  const lintPass = {
    status: 0,
    output:
      "words: 3100 player strings read; offences before baseline W1=0\nsketch-lint pass: 0 findings, baseline entries L1=0, 42ms\n",
  };
  const budgetPass = {
    status: 0,
    runs: {
      ui_word_budget_test: { ok: true, log: makeBudgetLog("ui_word_budget_test", { words: 14 }) },
      ui_word_budget_first_find_test: {
        ok: true,
        log: makeBudgetLog("ui_word_budget_first_find_test", { words: 16 }),
      },
    },
  };
  const plantOk = { caught: true, findings: [{ rule: "W6" }] };

  const ok = wordsReceipt({ lint: lintPass, budget: budgetPass, plant: plantOk, head: HEAD });
  assert.equal(ok.pass, true);
  assert.equal(ok.plant_caught, true);
  assert.deepEqual(receiptRow(WORDS_ROW, ok, HEAD), { measured: ok.measured, pass: true });

  const lintBad = wordsReceipt({
    lint: {
      status: 1,
      output: "W6 sketches/core-loop/src/ui/hud.gd:10 colon\nsketch-lint fail: 1 findings\n",
    },
    budget: budgetPass,
    plant: plantOk,
    head: HEAD,
  });
  assert.equal(lintBad.pass, false);
  assert.equal(gradeLintOutput(1, "sketch-lint fail: 1 findings\n").ok, false);

  const budgetBad = wordsReceipt({
    lint: lintPass,
    budget: {
      status: 1,
      runs: {
        ...budgetPass.runs,
        ui_word_budget_first_find_test: {
          ok: false,
          log: makeBudgetLog("ui_word_budget_first_find_test", { words: 32, fail: true }),
        },
      },
    },
    plant: plantOk,
    head: HEAD,
  });
  assert.equal(budgetBad.pass, false);
  assert.match(budgetBad.measured, /ui_word_budget_first_find_test/);

  const unCaught = wordsReceipt({
    lint: lintPass,
    budget: budgetPass,
    plant: { caught: false, findings: [] },
    head: HEAD,
  });
  assert.equal(unCaught.pass, false);
  assert.equal(unCaught.plant_caught, false);
  assert.match(receiptRow(WORDS_ROW, unCaught, HEAD).measured, /^void, the planted fault/);

  const teardownLog = makeBudgetLog("ui_word_budget_test", { teardown: true });
  assert.equal(gradeBudgetLog("ui_word_budget_test", teardownLog, { platform: "darwin" }).ok, true);
  assert.equal(gradeBudgetLog("ui_word_budget_test", teardownLog, { platform: "linux" }).ok, false);
});

test("words-on-screen: refuses dirty checkout via cleanHead", () => {
  withTempDir("words-dirty-", (dir) => {
    initTempGitRepo(dir);
    writeFileSync(path.join(dir, "sketches/core-loop/src/a.gd"), "extends Node\n# dirty\n");
    assert.throws(
      () =>
        wordsProduce({
          cwd: dir,
          runLint: () => ({ status: 0, output: "sketch-lint pass: 0 findings\n" }),
          runBudget: () => ({ status: 0, runs: {} }),
          runPlant: () => ({ caught: true, findings: [] }),
        }),
      /uncommitted changes/,
    );
  });
});

const SIX_PILOTS_ROW = {
  id: "six-pilots-clear",
  plant: "a script error planted in one pilot's kit must fail that pilot",
  producer: "node scripts/gate/six-pilots-receipt.mjs",
};

function makeWorld1Log({
  failPilot = null,
  dropCheck = null,
  extraError = null,
  omitVerdict = false,
  skipped = 0,
} = {}) {
  const lines = [
    "world1_run_test: 0 of 6 pilots needed a second go",
    "[no more than 2 pilots died on their first go] 0 of 6 -> PASS",
  ];
  for (const pilot of PILOTS) {
    for (const check of REQUIRED_PILOT_CHECKS) {
      if (dropCheck && dropCheck.pilot === pilot && dropCheck.check === check) continue;
      const bad = failPilot === pilot && check === "Brindle goes down";
      lines.push(`[${pilot}: ${check}] detail -> ${bad ? "FAIL" : "PASS"}`);
    }
  }
  if (extraError) lines.push(extraError);
  if (!omitVerdict) {
    lines.push(
      failPilot
        ? "world1_run_test: FAIL (1 of 49 checks)"
        : `world1_run_test: PASS (49 checks${skipped > 0 ? `, ${skipped} skipped` : ""})`,
    );
  }
  return lines.join("\n") + "\n";
}

test("six-pilots: passes when all 6 pilots clear cleanly and planted SCRIPT ERROR is caught", () => {
  const log = makeWorld1Log();
  const r = sixPilotsReceipt(log, HEAD);
  assert.equal(r.pass, true);
  assert.equal(r.plant_caught, true);
  assert.match(r.measured, /all 6 of 6 pilots/);
  assert.deepEqual(receiptRow(SIX_PILOTS_ROW, r, HEAD), { measured: r.measured, pass: true });

  const plantedGrade = gradeWorld1Log(injectPlantedScriptError(log));
  assert.equal(plantedGrade.ok, false);
  assert.ok(plantedGrade.errorLines.some((l) => l.includes("SCRIPT ERROR: planted")));
});

test("six-pilots: rejects failed pilot, missing pilot check, error line, skipped check, or missing verdict", () => {
  assert.equal(sixPilotsReceipt(makeWorld1Log({ failPilot: "tally" }), HEAD).pass, false);
  assert.equal(
    sixPilotsReceipt(makeWorld1Log({ dropCheck: { pilot: "tarn", check: "stage 3 opens" } }), HEAD)
      .pass,
    false,
  );
  assert.equal(
    sixPilotsReceipt(makeWorld1Log({ extraError: "SCRIPT ERROR: Nil base" }), HEAD).pass,
    false,
  );
  assert.equal(
    sixPilotsReceipt(makeWorld1Log({ extraError: "ERROR: physics fail" }), HEAD).pass,
    false,
  );
  assert.equal(sixPilotsReceipt(makeWorld1Log({ omitVerdict: true }), HEAD).pass, false);
  assert.equal(sixPilotsReceipt(makeWorld1Log({ skipped: 1 }), HEAD).pass, false);
  assert.equal(sixPilotsReceipt(makeWorld1Log(), HEAD, { runnerOk: false }).pass, false);
});

test("six-pilots: CLI --log mode and dirty-checkout refusal without --log", () => {
  withTempDir("six-pilots-test-", (dir) => {
    const logFile = path.join(dir, "world1_run_test.log");
    writeFileSync(logFile, makeWorld1Log());
    const outFile = path.join(dir, "six-pilots-clear.json");
    const okCli = runCli("scripts/gate/six-pilots-receipt.mjs", [
      "--head",
      HEAD,
      "--log",
      logFile,
      "--out",
      outFile,
    ]);
    assert.equal(okCli.status, 0, okCli.stderr);
    const receipt = JSON.parse(readFileSync(outFile, "utf8"));
    assert.equal(receipt.pass, true);
    assert.equal(receipt.plant_caught, true);

    writeFileSync(logFile, makeWorld1Log({ failPilot: "remembered_cannon" }));
    const failCli = runCli("scripts/gate/six-pilots-receipt.mjs", [
      "--head",
      HEAD,
      "--log",
      logFile,
    ]);
    assert.equal(failCli.status, 1);

    const badCli = runCli("scripts/gate/six-pilots-receipt.mjs", ["--log", logFile]);
    assert.equal(badCli.status, 2);

    const repoDir = path.join(dir, "repo");
    mkdirSync(repoDir, { recursive: true });
    const { head } = initTempGitRepo(repoDir);
    const cleanRun = sixPilotsProduce({
      cwd: repoDir,
      run: () => ({ ok: true, log: makeWorld1Log() }),
    });
    assert.equal(cleanRun.pass, true);
    assert.equal(cleanRun.head, head);

    writeFileSync(path.join(repoDir, "sketches/core-loop/src/a.gd"), "extends Node\n# dirty\n");
    assert.throws(
      () => sixPilotsProduce({ cwd: repoDir, run: () => ({ ok: true, log: makeWorld1Log() }) }),
      /uncommitted changes/,
    );
  });
});

const RELEASE_GATE_ROW = {
  id: "release-gate",
  plant: "a test made to fail on a scratch copy of the head must turn the tally red",
  producer: "node scripts/gate/release-gate-receipt.mjs",
};

function makeFullReleasePlan({
  today = new Date().toISOString().slice(0, 10),
  shardOverride = {},
} = {}) {
  const lists = gateLists(path.join(root, "sketches", "core-loop"));
  const testCount = lists.tests.length;
  const botCount = lists.bots.length;
  const weeklyCount = lists.weekly.tests.length + lists.weekly.bots.length;
  const shardRows = [
    [`tests 1-${testCount}`, "PASS, no new red. Receipt tests/receipt.md"],
    ...expectedShards(botCount).map((name) => [
      name,
      name === "red team"
        ? "CLEAR. Receipt redteam/receipt.md"
        : "PASS, no new red. Receipt shard/receipt.md",
    ]),
    ...(weeklyCount > 0 ? [["weekly sweep", `PASS ${today}. Receipt weekly/receipt.md`]] : []),
  ].map(([name, verdict]) => [name, shardOverride[name] ?? verdict]);

  return [
    "# Release gate plan",
    "",
    "| Check | Verdict |",
    "| --- | --- |",
    "| node tests | PASS. 1600 tests, 0 fail. Receipt node/summary.txt |",
    "",
    "| Shard | Verdict |",
    "| --- | --- |",
    ...shardRows.map(([name, verdict]) => `| ${name} | ${verdict} |`),
    "",
  ].join("\n");
}

test("release-gate: runs real scripts/gate/tally.mjs (no --wave), passes CLEAN plan, and catches planted RED shard", () => {
  const actualHead = spawnSync("git", ["-C", root, "rev-parse", "HEAD"], {
    encoding: "utf8",
  }).stdout.trim();
  const shortHead = actualHead.slice(0, 8);

  withTempDir("release-gate-real-", (dir) => {
    const planPath = path.join(dir, `w46-${shortHead}-gate-plan.md`);
    writeFileSync(planPath, makeFullReleasePlan());

    const r = releaseGateProduce({ planPath, head: actualHead, cwd: root });
    assert.equal(r.pass, true, r.measured);
    assert.equal(r.plant_caught, true, r.measured);
    assert.deepEqual(receiptRow(RELEASE_GATE_ROW, r, actualHead), {
      measured: r.measured,
      pass: true,
    });

    const deferredPath = path.join(dir, `w46-${shortHead}-gate-plan.md`);
    writeFileSync(
      deferredPath,
      makeFullReleasePlan({
        shardOverride: { "bands A": "DEFERRED, last read in receipt w45/bands-a.md" },
      }),
    );
    const deferred = releaseGateProduce({ planPath: deferredPath, head: actualHead, cwd: root });
    assert.equal(deferred.pass, false);
    assert.equal(deferred.plant_caught, true);

    const wrongHead = releaseGateProduce({ planPath, head: OTHER_HEAD, cwd: root });
    assert.equal(wrongHead.pass, false);
    assert.match(wrongHead.measured, /plan gates/);

    writeFileSync(planPath, makeFullReleasePlan());
    const outFile = path.join(dir, "release-gate.json");
    const okCli = runCli("scripts/gate/release-gate-receipt.mjs", [
      "--plan",
      planPath,
      "--head",
      actualHead,
      "--out",
      outFile,
    ]);
    assert.equal(okCli.status, 0, okCli.stdout + okCli.stderr);
    assert.equal(JSON.parse(readFileSync(outFile, "utf8")).pass, true);

    const missCli = runCli("scripts/gate/release-gate-receipt.mjs", [
      "--plan",
      planPath,
      "--head",
      OTHER_HEAD,
    ]);
    assert.equal(missCli.status, 1);

    const badCli = runCli("scripts/gate/release-gate-receipt.mjs", [
      "--plan",
      path.join(dir, "nope.md"),
      "--head",
      actualHead,
    ]);
    assert.equal(badCli.status, 2);
  });
});

test("release-gate: voids receipt when injected tally stub fails to reject planted RED shard", () => {
  withTempDir("release-gate-stub-", (dir) => {
    const planPath = path.join(dir, `w46-${HEAD.slice(0, 8)}-gate-plan.md`);
    const planText = makeFullReleasePlan();
    writeFileSync(planPath, planText);

    const mutated = plantRedShard(planText);
    assert.ok(mutated.shard);
    assert.match(mutated.mutated, /RED: planted failing test/);

    const fakeClean = {
      status: 0,
      stdout:
        "release gate: every shard, nothing deferred\ngate tally: 10 rows, 100 non-bot tests, 10 bot tests. Every row is filled; CLEAN may be written.\n",
      stderr: "",
    };
    assert.equal(gradeTallyRun(fakeClean).ok, true);

    const r = releaseGateProduce({ planPath, head: HEAD, run: () => fakeClean });
    assert.equal(r.plant_caught, false);
    assert.equal(r.pass, false);
    assert.match(receiptRow(RELEASE_GATE_ROW, r, HEAD).measured, /^void, the planted fault/);
  });
});

const SNAG_ROW = {
  id: "snag-sweep",
  plant: "the planted snag of snag_sweep_test must be found",
  producer: "node scripts/gate/snag-sweep-receipt.mjs",
};

function makeSnagReport(map, overrides = {}) {
  return {
    map,
    seed: 1,
    shard: "merged 0/4,1/4,2/4,3/4",
    display: "headless",
    multimesh_trusted: false,
    pieces_total: 40,
    pieces_off_map: 2,
    pieces_in_shard: 40,
    lanes_run: 480,
    lanes_skipped: 20,
    skipped_reasons: {},
    controls_run: 24,
    loss: 0.5,
    window_s: 0.2,
    max_angle_deg: 45.0,
    complete: true,
    snags: [],
    controls: [],
    classes_raw: { piece: 0, ground: 0, other: 0, moving: 0 },
    places: [],
    classes_places: { piece: 0, ground: 0, other: 0, moving: 0 },
    ride_places: [],
    classes_ride_places: { piece: 0, ground: 0, other: 0, moving: 0 },
    classes_ride_raw: { piece: 0, ground: 0, other: 0, moving: 0 },
    seams: [],
    ...overrides,
  };
}

function makeControlLog({ missingCheck = null, fail = false, error = false } = {}) {
  const lines = [
    "[the lip and the wall are large pieces, the floor is one too] ok -> PASS",
    ...CONTROL_CHECKS.filter((c) => c !== missingCheck).map(
      (c) => `[${c}] ok -> ${fail && c === CONTROL_CHECKS[0] ? "FAIL" : "PASS"}`,
    ),
    ...(error ? ["SCRIPT ERROR: control broke"] : []),
    `snag_sweep_test: ${fail ? "FAIL (1 of 12 checks)" : "PASS (12 checks)"}`,
  ];
  return lines.join("\n") + "\n";
}

test("snag-sweep: passes clean dam+flume (allowing moving ride snags and reporting graze wall/cluster hits), verifies control log & planted dam ride snag", () => {
  const dam = makeSnagReport("park_dam", {
    snags: [
      { at: [1, 2, 3], hit: "/root/Lift", piece: "/root/Lift", class: "moving", lane: "ride" },
      {
        at: [50, 100, 50],
        hit: "/root/Park_saguaro_4/Collider#1",
        piece: "/root/Park_saguaro_4/Collider",
        class: "piece",
        lane: "graze",
      },
      {
        at: [60, 100, 60],
        hit: "/root/Park_hoodoo_5/Collider#2",
        piece: "/root/Park_saguaro_4/Collider",
        class: "other",
        lane: "graze",
      },
    ],
    classes_raw: { piece: 1, ground: 0, other: 1, moving: 1 },
    classes_places: { piece: 1, ground: 0, other: 1, moving: 1 },
    places: [
      { at: [1, 2, 3], hit: "/root/Lift", class: "moving", count: 1, worst_loss: 0.7 },
      { at: [50, 100, 50], hit: "/root/Park_saguaro_4/Collider#1", class: "piece", count: 1 },
      { at: [60, 100, 60], hit: "/root/Park_hoodoo_5/Collider#2", class: "other", count: 1 },
    ],
    ride_places: [{ at: [1, 2, 3], hit: "/root/Lift", class: "moving", count: 1, worst_loss: 0.7 }],
    classes_ride_places: { piece: 0, ground: 0, other: 0, moving: 1 },
    classes_ride_raw: { piece: 0, ground: 0, other: 0, moving: 1 },
  });
  const flume = makeSnagReport("park_flume", {
    snags: [
      {
        at: [10, 20, 30],
        hit: "/root/Stage2/Ground/Tiles/Tile5_4",
        piece: "/root/Stage2/ParkRows/Pier/Collider",
        class: "ground",
        lane: "graze",
      },
    ],
    classes_raw: { piece: 0, ground: 1, other: 0, moving: 0 },
    classes_places: { piece: 0, ground: 1, other: 0, moving: 0 },
    places: [
      { at: [10, 20, 30], hit: "/root/Stage2/Ground/Tiles/Tile5_4", class: "ground", count: 1 },
    ],
  });
  const controlLog = makeControlLog();

  const res = snagSweepEvaluate({ dam, flume, controlLog, head: HEAD });
  assert.equal(res.receipt.pass, true, res.receipt.measured);
  assert.equal(res.receipt.plant_caught, true);
  assert.match(res.receipt.measured, /park_dam ride 0, seams 0.*graze 2 wall\/cluster hits/);
  assert.match(res.receipt.measured, /park_flume ride 0, seams 0.*graze 1 wall\/cluster hits/);
  assert.deepEqual(res.mapcheckLines, [
    "MAPCHECK park_dam snags 0 pass<=0 PASS",
    "MAPCHECK park_flume snags 0 pass<=0 PASS",
  ]);
  assert.deepEqual(receiptRow(SNAG_ROW, res.receipt, HEAD), {
    measured: res.receipt.measured,
    pass: true,
  });

  const planted = gradeMapReport(injectPlantedSnag(dam), "park_dam");
  assert.equal(planted.ok, false);
  assert.equal(planted.rideSnags, 1);
  assert.equal(planted.snagCount, 1);
});

test("snag-sweep: rejects incomplete run, wrong map, unmerged shard, >20% skip, any ride snag (piece/ground/other), seam, or bad control log", () => {
  const dam = makeSnagReport("park_dam");
  const flume = makeSnagReport("park_flume");
  const ctl = makeControlLog();

  assert.equal(
    snagSweepReceipt({
      dam: makeSnagReport("park_dam", { complete: false }),
      flume,
      controlLog: ctl,
      head: HEAD,
    }).pass,
    false,
  );
  assert.equal(
    snagSweepReceipt({ dam: makeSnagReport("park_flume"), flume, controlLog: ctl, head: HEAD })
      .pass,
    false,
  );
  assert.equal(
    snagSweepReceipt({
      dam: makeSnagReport("park_dam", { pieces_in_shard: 10 }),
      flume,
      controlLog: ctl,
      head: HEAD,
    }).pass,
    false,
  );
  assert.equal(
    snagSweepReceipt({
      dam: makeSnagReport("park_dam", { lanes_run: 79, lanes_skipped: 21 }),
      flume,
      controlLog: ctl,
      head: HEAD,
    }).pass,
    false,
  );
  for (const cls of ["piece", "ground", "other"]) {
    const rideRow = {
      at: [0, 0, 0],
      hit: `/root/Hit_${cls}`,
      piece: "/root/Deck",
      class: cls,
      lane: "ride",
    };
    const r = snagSweepReceipt({
      dam,
      flume: makeSnagReport("park_flume", {
        snags: [rideRow],
        classes_raw: { piece: 0, ground: 0, other: 0, moving: 0, [cls]: 1 },
        classes_places: { piece: 0, ground: 0, other: 0, moving: 0, [cls]: 1 },
        places: [{ at: [0, 0, 0], hit: rideRow.hit, class: cls, count: 1 }],
        ride_places: [{ at: [0, 0, 0], hit: rideRow.hit, class: cls, count: 1 }],
        classes_ride_places: { piece: 0, ground: 0, other: 0, moving: 0, [cls]: 1 },
        classes_ride_raw: { piece: 0, ground: 0, other: 0, moving: 0, [cls]: 1 },
      }),
      controlLog: ctl,
      head: HEAD,
    });
    assert.equal(r.pass, false, `ride snag of class ${cls} must fail`);
    assert.equal(r.plant_caught, true);
  }
  assert.equal(
    gradeMapReport(
      makeSnagReport("park_flume", {
        snags: [
          { at: [0, 0, 0], hit: "/root/Wall", piece: "/root/Deck", class: "other", lane: "ride" },
        ],
        ride_places: undefined,
        classes_ride_places: undefined,
      }),
      "park_flume",
    ).ok,
    false,
  );
  assert.equal(
    snagSweepReceipt({
      dam: makeSnagReport("park_dam", {
        seams: [{ at: [0, 0, 0], hit: "/root/Tiles/T0", class: "ground" }],
        controls: [{ at: [0, 0, 0], hit: "/root/Tiles/T0", class: "ground", lane: "control" }],
      }),
      flume,
      controlLog: ctl,
      head: HEAD,
    }).pass,
    false,
  );

  const badCtl = snagSweepReceipt({
    dam,
    flume,
    controlLog: makeControlLog({ missingCheck: CONTROL_CHECKS[0] }),
    head: HEAD,
  });
  assert.equal(badCtl.pass, false);
  assert.equal(badCtl.plant_caught, false);
  assert.match(receiptRow(SNAG_ROW, badCtl, HEAD).measured, /^void, the planted fault/);
  assert.equal(gradeControlLog(makeControlLog({ error: true })).ok, false);
});

test("snag-sweep: CLI writes receipt + prints MAPCHECK with --out, handles --mapcheck, miss exit 1, error exit 2", () => {
  withTempDir("snag-sweep-cli-", (dir) => {
    const damPath = path.join(dir, "park_dam.json");
    const flumePath = path.join(dir, "park_flume.json");
    const ctlPath = path.join(dir, "snag_sweep_test.log");
    const outPath = path.join(dir, "snag-sweep.json");
    writeFileSync(damPath, JSON.stringify(makeSnagReport("park_dam")));
    writeFileSync(flumePath, JSON.stringify(makeSnagReport("park_flume")));
    writeFileSync(ctlPath, makeControlLog());

    const res = snagSweepProduce({ damPath, flumePath, controlLogPath: ctlPath, head: HEAD });
    assert.equal(res.receipt.pass, true);

    const okCli = runCli("scripts/gate/snag-sweep-receipt.mjs", [
      "--dam",
      damPath,
      "--flume",
      flumePath,
      "--control-log",
      ctlPath,
      "--head",
      HEAD,
      "--out",
      outPath,
    ]);
    assert.equal(okCli.status, 0, okCli.stderr);
    assert.ok(existsSync(outPath));
    assert.equal(JSON.parse(readFileSync(outPath, "utf8")).pass, true);
    assert.match(okCli.stdout, /MAPCHECK park_dam snags 0 pass<=0 PASS/);
    assert.match(okCli.stdout, /MAPCHECK park_flume snags 0 pass<=0 PASS/);

    const jsonCli = runCli("scripts/gate/snag-sweep-receipt.mjs", [
      "--dam",
      damPath,
      "--flume",
      flumePath,
      "--control-log",
      ctlPath,
      "--head",
      HEAD,
    ]);
    assert.equal(jsonCli.status, 0);
    assert.equal(JSON.parse(jsonCli.stdout).pass, true);

    writeFileSync(
      flumePath,
      JSON.stringify(
        makeSnagReport("park_flume", {
          snags: [
            { at: [1, 0, 0], hit: "/a", piece: "/a", class: "piece", lane: "ride" },
            { at: [9, 0, 0], hit: "/b", piece: "/b", class: "piece", lane: "ride" },
          ],
          classes_raw: { piece: 2, ground: 0, other: 0, moving: 0 },
          classes_places: { piece: 2, ground: 0, other: 0, moving: 0 },
          places: [
            { at: [1, 0, 0], hit: "/a", class: "piece" },
            { at: [9, 0, 0], hit: "/b", class: "piece" },
          ],
          ride_places: [
            { at: [1, 0, 0], hit: "/a", class: "piece" },
            { at: [9, 0, 0], hit: "/b", class: "piece" },
          ],
          classes_ride_places: { piece: 2, ground: 0, other: 0, moving: 0 },
          classes_ride_raw: { piece: 2, ground: 0, other: 0, moving: 0 },
        }),
      ),
    );
    const missCli = runCli("scripts/gate/snag-sweep-receipt.mjs", [
      "--dam",
      damPath,
      "--flume",
      flumePath,
      "--control-log",
      ctlPath,
      "--head",
      HEAD,
      "--mapcheck",
    ]);
    assert.equal(missCli.status, 1);
    assert.match(missCli.stdout, /MAPCHECK park_flume snags 2 pass<=0 FAIL/);

    const errCli = runCli("scripts/gate/snag-sweep-receipt.mjs", ["--head", HEAD]);
    assert.equal(errCli.status, 2);
  });
});

test("sitting-producers: BUDGET_TESTS lists both required word-budget tests", () => {
  assert.deepEqual(BUDGET_TESTS, ["ui_word_budget_test", "ui_word_budget_first_find_test"]);
});
