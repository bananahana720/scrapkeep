import assert from "node:assert/strict";
import test from "node:test";
import {
  FILMS,
  FILM_OF,
  FINDINGS_HEADER,
  PERSONAS,
  PILOTS,
  PLAYED_AUDIO,
  PLAYED_TABLE,
  READERS,
  botArgs,
  replayCommand,
  sweepSeed,
  carryList,
  filmArgs,
  grade,
  hitches,
  judgeSheet,
  logErrors,
  overdueFindings,
  parseFindings,
  pileUps,
  planWave,
  readBotJob,
  readerBrief,
  readerPack,
  renderMarkdown,
} from "./lib.mjs";

const job = (over = {}) => ({
  id: "speedrunner-tarn-2500",
  kind: "bot",
  persona: "speedrunner",
  policy: "skipper",
  pilot: "tarn",
  seed: 2500,
  stages: null,
  args: [],
  ...over,
});
const result = (over = {}) => ({
  job: job(),
  exit: 0,
  timedOut: false,
  row: { outcome: "won", stage_reached: 7, game_seconds: 600, stages: [], beats: [] },
  errors: [],
  piles: [],
  perf: { spikes: [], loads: 0, p99: 4 },
  ...over,
});

test("a wave's runs cover every persona and new cells each wave", () => {
  const w15 = planWave({ wave: 15 });
  assert.equal(w15.length, 10);
  for (const p of PERSONAS) assert.equal(w15.filter((j) => j.persona === p.id).length, 2);
  const cells = new Set();
  for (const w of [15, 16, 17])
    for (const j of planWave({ wave: w })) cells.add(j.persona + j.pilot);
  assert.equal(cells.size, PERSONAS.length * PILOTS.length);
  const seeds = new Set([...planWave({ wave: 15 }), ...planWave({ wave: 16 })].map((j) => j.seed));
  assert.equal(seeds.size, 20);
  assert.throws(() => planWave({ wave: 1.5 }));
  const sweep = planWave({ wave: 15, count: 60, seed: sweepSeed });
  assert.equal(new Set(sweep.map((j) => j.persona + j.pilot)).size, 30);
  assert.equal(sweep[0].seed, 35000);
});

test("a head pass plays one persona on every pilot, on seeds every head of the wave shares", () => {
  const jobs = planWave({
    wave: 16,
    persona: "greedy",
    carry: [{ persona: "first-timer", pilot: "tally", seed: 36416, title: "x" }],
  });
  assert.equal(jobs.length, 7);
  assert.deepEqual(
    jobs.slice(0, 6).map((j) => j.pilot),
    PILOTS,
  );
  assert.ok(
    jobs.slice(0, 6).every((j) => j.persona === "greedy" && j.args.includes("--late-offer=take")),
  );
  assert.deepEqual(
    planWave({ wave: 16, persona: "greedy" }).map((j) => j.seed),
    jobs.slice(0, 6).map((j) => j.seed),
  );
  const regular = new Set(planWave({ wave: 16, count: 30 }).map((j) => j.seed));
  assert.ok(jobs.every((j) => !regular.has(j.seed)));
  assert.throws(() => planWave({ wave: 16, persona: "nobody" }));
});

test("quick runs stop after stage 1 and carried runs replay their seed", () => {
  const jobs = planWave({
    wave: 3,
    count: 2,
    quick: true,
    carry: [
      { persona: "greedy", pilot: "tally", seed: 1311, title: "x" },
      { persona: "nobody", pilot: "tally", seed: 1 },
    ],
  });
  assert.equal(jobs.length, 3);
  assert.ok(jobs.every((j) => j.args.includes("--stages=1")));
  assert.equal(jobs[2].seed, 1311);
  const rider = planWave({ wave: 0, count: 5 }).find((j) => j.persona === "line-rider");
  assert.deepEqual(rider.args, ["--from-stage=" + (1 + (rider.seed % 6)), "--ticks=8100"]);
  assert.ok(jobs[2].args.includes("--late-offer=take"));
});

test("crashes, timeouts and skipper stalls are blockers; camper stalls without a break are expected", () => {
  const f = grade([
    result({ exit: 139, row: null }),
    result({ timedOut: true, row: null }),
    result({
      row: {
        outcome: "stalled",
        stage_reached: 2,
        stages: [{ stage: 2, stall_state: "beacon" }],
        beats: [],
      },
    }),
    result({
      job: job({ policy: "camper", persona: "cautious" }),
      row: {
        outcome: "stalled",
        stage_reached: 1,
        stages: [{ stage: 1, warden_broken_s: null }],
        beats: [],
      },
    }),
    result({
      job: job({ policy: "random", persona: "first-timer", pilot: "tally" }),
      row: { outcome: "stalled", stage_reached: 3, stages: [{ stage: 3 }], beats: [] },
    }),
  ]);
  const keys = f.map((x) => `${x.severity} ${x.key}`);
  assert.deepEqual(keys.filter((k) => k.startsWith("blocker")).sort(), [
    "blocker crash",
    "blocker freeze",
    "blocker stall:stage 2:tarn",
  ]);
  assert.ok(keys.includes("major stall:stage 3:tally"));
  assert.ok(f.every((x) => !x.key.includes("stage 1")));
  const exit = grade([
    result({
      job: job({ policy: "completionist", persona: "greedy", pilot: "pylon_engineer" }),
      row: {
        outcome: "stalled",
        stage_reached: 6,
        stages: [{ stage: 6, stall_state: "gates", warden_broken_s: 230.67 }],
        beats: [],
      },
    }),
  ]);
  assert.equal(exit[0].key, "exit:stage 6:pylon_engineer");
  assert.equal(exit[0].severity, "major");
  assert.match(exit[0].title, /never reaches an exit gate/);
});

test("pile-ups need three hits from two sources worth a third of max HP", () => {
  const hit = (tick, amount, source) => ({ tick, event: "player_hit", args: [amount, source] });
  const events = [
    { tick: 0, event: "stage_entered", args: [1, false] },
    hit(100, 15, "chaser"),
    hit(120, 15, "lobber"),
    hit(150, 10, "chaser"),
    { tick: 300, event: "player_died", args: [] },
    hit(1000, 10, "chaser"),
    hit(1010, 10, "chaser"),
    hit(1020, 10, "chaser"),
  ];
  const piles = pileUps(events, { 1: 100 });
  assert.equal(piles.length, 1);
  assert.deepEqual(piles[0].sources, ["chaser", "lobber"]);
  assert.equal(piles[0].died, true);
  const f = grade([result({ piles }), result({ piles })]);
  assert.equal(f[0].severity, "major");
  assert.equal(f[0].runs.length, 2);
});

test("hitches ignore the bot's own cost and stage loads, and repeats become major", () => {
  const ticks = Array.from({ length: 400 }, (_, i) => i + 1);
  const usec = ticks.map((t) =>
    t === 250 ? 50_000 : t === 305 ? 60_000 : t === 350 ? 45_000 : 5_000,
  );
  const bot = ticks.map((t) => (t === 350 ? 40_000 : 1000));
  const events = [{ tick: 300, event: "stage_entered", args: [2, false] }];
  const h = hitches(
    { samples: { tick_wall: { ticks, usec }, bot_driver: { ticks, usec: bot } } },
    events,
  );
  assert.deepEqual(h.spikes, [{ tick: 250, stage: null, ms: 49 }]);
  assert.equal(h.loads, 1);
  const r1 = result({
    perf: {
      spikes: [
        { tick: 900, stage: 2, ms: 40 },
        { tick: 50, stage: 1, ms: 90 },
      ],
      loads: 0,
      p99: 4,
    },
  });
  const r2 = result({
    job: job({ id: "other", seed: 2501 }),
    perf: { spikes: [{ tick: 901, stage: 2, ms: 41 }], loads: 0, p99: 12 },
  });
  const r3 = result({
    job: job({ id: "same-seed" }),
    perf: { spikes: [{ tick: 50, stage: 1, ms: 80 }], loads: 0, p99: 4 },
  });
  const f = grade([r1, r2, r3], { hitchTriage: { tested: 2, alone: 2, noMix: 0 } });
  const shared = f.find((x) => x.key === "hitch:shared");
  assert.equal(shared.severity, "major");
  assert.equal(shared.runs.length, 2);
  assert.equal(shared.counts["still hitched without the music mix"], 0);
  assert.equal(f.find((x) => x.key === "hitch:scattered").title, "2 scattered ticks over 33 ms");
  assert.equal(f.find((x) => x.key === "cpu-p99").severity, "watch");
});

test("every bot run, the hitch replays and the printed replay command warm the audio as a played game does", () => {
  assert.equal(PLAYED_AUDIO, "--warm-band=1");
  const args = botArgs(job(), "out");
  assert.ok(
    args.includes(PLAYED_AUDIO),
    "a bot run renders its audio on the main thread without it",
  );
  assert.ok(
    args.indexOf(PLAYED_AUDIO) > args.indexOf("--"),
    "the flag belongs to bot_run.gd, after the separator",
  );
  const triage = botArgs({ ...job(), args: ["--ticks=9000", "--bot-no-mix=1"] }, "out");
  assert.ok(triage.includes(PLAYED_AUDIO) && triage.includes("--bot-no-mix=1"));
  assert.ok(
    replayCommand(job()).includes(PLAYED_AUDIO),
    "a replay without it shows stalls the pass did not see",
  );
});

test("every bot run and its printed replay play the park table, the maps a launched game plays", () => {
  assert.equal(PLAYED_TABLE, "--table=park");
  const args = botArgs(job(), "out");
  assert.ok(
    args.indexOf(PLAYED_TABLE) > args.indexOf("--"),
    "the flag belongs to bot_run.gd, after the separator",
  );
  assert.ok(
    botArgs({ ...job(), args: ["--from-stage=3", "--ticks=8100"] }, "out").includes(PLAYED_TABLE),
    "the line-rider rides a park stage",
  );
  assert.ok(
    replayCommand(job()).includes(PLAYED_TABLE),
    "a replay on the legacy maps shows stalls the pass did not see",
  );
});

test("log errors group by message with numbers folded", () => {
  const errs = logErrors(
    "SCRIPT ERROR: Invalid index 3 on base Array\n   at x\nSCRIPT ERROR: Invalid index 7 on base Array\nERROR: thing\nWARNING: fine\n",
  );
  assert.deepEqual(
    errs.map((e) => [e.script, e.count]),
    [
      [true, 2],
      [false, 1],
    ],
  );
});

test("readBotJob tolerates a run cut short and the page ranks blockers first", () => {
  const r = readBotJob(job(), {
    exit: 1,
    timedOut: false,
    log: "",
    bots: "",
    runs: "{bad",
    events: "",
    profile: null,
  });
  assert.equal(r.row, null);
  const findings = grade(
    [
      r,
      result({
        row: {
          outcome: "won",
          stage_reached: 7,
          game_seconds: 60,
          stages: [
            {
              stage: 1,
              warden_fight_s: 0.01,
              warden_engaged_s: 3,
              warden_broken_s: 4.5,
              parts: ["a"],
            },
            { stage: 2, warden_fight_s: 2, warden_engaged_s: 3, warden_broken_s: 30 },
          ],
          beats: [],
        },
      }),
    ],
    { placeholders: { total: 5, byKind: { park: 5 } } },
  );
  assert.deepEqual(
    findings.map((f) => f.severity),
    ["blocker", "major", "watch"],
  );
  const page = renderMarkdown({
    wave: 15,
    commit: "abcdef0123456",
    started: "now",
    minutes: 1,
    results: [r],
    findings,
  });
  assert.match(page, /1 blocker, 1 major, 0 minor, 1 to watch/);
  assert.match(page, /1\. \*\*BLOCKER\*\* · stability · A run crashed/);
  assert.deepEqual(carryList(findings), [
    { persona: "speedrunner", pilot: "tarn", seed: 2500, title: "A run crashed" },
  ]);
});

const film = [
  {
    file: "0001-screen-title.jpg",
    why: "screen-title",
    t: 0.5,
    flow: "title",
    plate: "",
    hp: 100,
    hp_max: 100,
  },
  {
    file: "0002-hit-1-lead.jpg",
    why: "hit-1-lead",
    t: 40.0,
    flow: "stage",
    plate: "Clear the camp",
    hp: 100,
    hp_max: 100,
    source: "chaser",
    amount: 12,
  },
  {
    file: "0003-hit-1-lead.jpg",
    why: "hit-1-lead",
    t: 40.4,
    flow: "stage",
    plate: "Clear the camp",
    hp: 100,
    hp_max: 100,
    source: "chaser",
    amount: 12,
  },
  {
    file: "0004-hit-1.jpg",
    why: "hit-1",
    t: 40.8,
    flow: "stage",
    plate: "Clear the camp",
    hp: 88,
    hp_max: 100,
    source: "chaser",
    amount: 12,
  },
  {
    file: "0005-hit-1-after.jpg",
    why: "hit-1-after",
    t: 41.1,
    flow: "stage",
    plate: "Clear the camp",
    hp: 88,
    hp_max: 100,
    source: "chaser",
    amount: 12,
  },
  {
    file: "0006-held.jpg",
    why: "held",
    t: 50,
    flow: "stage",
    paused: true,
    plate: "Clear the camp",
    hp: 88,
    hp_max: 100,
  },
  {
    file: "0007-death-lead.jpg",
    why: "death-lead",
    t: 60,
    flow: "stage",
    plate: "Find | the Warden",
    hp: 3,
    hp_max: 100,
  },
  { file: "0008-death.jpg", why: "death", t: 60.4, flow: "dead", plate: "", hp: 0, hp_max: 100 },
  {
    file: "0009-death-after.jpg",
    why: "death-after",
    t: 60.9,
    flow: "dead",
    plate: "",
    hp: 0,
    hp_max: 100,
  },
  {
    file: "0010-death-screen.jpg",
    why: "death-screen",
    t: 62.9,
    flow: "dead",
    plate: "",
    hp: 0,
    hp_max: 100,
  },
];

test("a film is handed to the reader with no word of why a frame was taken", () => {
  const pack = readerPack(film);
  assert.deepEqual(
    pack.frames.map((f) => f.set),
    [0, 1, 1, 1, 1, 0, 2, 2, 2, 0],
  );
  assert.deepEqual(pack.sets, [
    { id: 1, first: 2, last: 5, moment: 4 },
    { id: 2, first: 7, last: 9, moment: 8 },
  ]);
  assert.equal(pack.key[3].n, 4);
  const brief = readerBrief("cautious", pack);
  assert.ok(brief.includes(READERS.cautious));
  assert.ok(brief.includes("Pictures 002 to 005: something happens at 004."));
  assert.ok(brief.includes("001.jpg to 010.jpg"));
  for (const told of ["hit-1", "death", "chaser", "Clear the camp", "film.ndjson", "0004-"])
    assert.ok(!brief.includes(told), "the brief gives away: " + told);
  assert.throws(() => readerBrief("nobody", pack));
  const killed = readerPack(
    [
      "hit-2-lead",
      "hit-2",
      "death",
      "hit-2-after",
      "death-after",
      "roam",
      "hit-3",
      "hit-3-after",
    ].map((why) => ({ file: why + ".jpg", why })),
  );
  assert.deepEqual(killed.sets, [{ id: 1, first: 1, last: 5, moment: 2 }]);
  assert.deepEqual(
    killed.frames.map((f) => f.set),
    [1, 1, 1, 1, 1, 0, 0, 0],
  );
  const later = readerPack(
    [
      ["hit-1-lead", 10],
      ["hit-1", 10.4],
      ["death-lead", 11.6],
      ["death", 12],
    ].map(([why, t]) => ({ file: why + ".jpg", why, t })),
  );
  assert.deepEqual(later.sets, [
    { id: 1, first: 1, last: 2, moment: 2 },
    { id: 2, first: 3, last: 4, moment: 4 },
  ]);
  const doubled = readerPack(
    [
      ["plate", 250.9],
      ["plate", 253.0],
      ["roam", 253.94],
      ["roam", 254.0],
      ["hit-1-lead", 252.34],
      ["hit-1-lead", 253.94],
      ["hit-2-lead", 254.0],
      ["hit-1", 254.1],
      ["death", 254.1],
      ["hit-2", 254.4],
      ["roam", 263.9],
      ["title", ""],
    ].map(([why, t], i) => ({ file: i + ".jpg", why, t })),
  );
  assert.deepEqual(
    doubled.key.map((row) => row.t),
    [250.9, 252.34, 253.94, 254.0, 254.1, 254.1, 254.4, 263.9, ""],
  );
  assert.deepEqual(
    doubled.sets.map((set) => set.id),
    [1, 2],
  );
  assert.ok(readerBrief("first-timer", pack, { look: true }).includes("how it looks: say where"));
  assert.ok(!readerBrief("first-timer", pack, { look: true }).includes("software renderer"));
});

test("the judge's sheet sets every picture beside what the game knew", () => {
  const sheet = judgeSheet(readerPack(film)).split("\n");
  assert.equal(sheet.length, 2 + film.length + 1);
  assert.ok(
    sheet[5].startsWith("| 004 | hit-1 | 40.8 | stage | Clear the camp | 88/100 | chaser 12 |"),
  );
  assert.ok(sheet[7].includes("stage (held)"));
  assert.ok(sheet[8].includes("Find / the Warden"), "a bar in the words must not break the table");
});

test("a film's flags: a player's game by its keys, the persona's default film, the control's plant", () => {
  const whole = filmArgs({ film: "whole", seed: 7, out: "/tmp/f" });
  for (const flag of [
    "--self-play",
    "--self-play-keys=1",
    "--self-play-eyes=1",
    "--self-play-seed=7",
    "--self-play-policy=skipper",
    "--self-play-film=/tmp/f",
    "--self-play-until=3",
  ])
    assert.ok(whole.includes(flag), flag);
  assert.ok(!whole.some((a) => a.startsWith("--self-play-plant")));
  assert.ok(!whole.includes("--self-play-film-live=1"));
  assert.ok(
    filmArgs({ film: "whole", out: "/tmp/f", live: true }).includes("--self-play-film-live=1"),
  );
  const wait = filmArgs({
    film: FILM_OF.cautious,
    out: "/tmp/f",
    world: 0.5,
    plant: "objective",
    pilot: "tarn",
  });
  for (const flag of [
    "--self-play-policy=camper",
    "--self-play-plant-death=240",
    "--self-play-film-world=0.5",
    "--self-play-plant-hide=objective",
    "--self-play-pilot=tarn",
  ])
    assert.ok(wait.includes(flag), flag);
  assert.throws(() => filmArgs({ film: "nope", out: "/tmp/f" }));
  assert.deepEqual(Object.keys(FILMS), ["whole", "wait"]);
});

test("the play findings list: every row has an owner and a date, and a late row is reported", () => {
  const head = FINDINGS_HEADER.join("\t");
  const good = parseFindings(
    head +
      "\nPF-01\tmajor\tThe kit pick cannot be read\tclean 005\tdesign\t2026-11-10\t2026-11-14\n\nPF-02\tcheck\tA fan covers the view\tclean 026\tsight\t2026-11-10\t2026-11-20\n",
  );
  assert.deepEqual(good.problems, []);
  assert.deepEqual(overdueFindings(good.rows, "2026-11-14"), []);
  assert.deepEqual(
    overdueFindings(good.rows, "2026-11-15").map((row) => row.id),
    ["PF-01"],
  );
  assert.equal(parseFindings("id\tgrade").problems.length, 1);
  const bad = parseFindings(
    head +
      "\nPF-01\tsevere\tx\ty\tz\t2026-11-10\tsoon\nPF-01\tminor\tx\ty\t\t2026-11-10\t2026-11-11\nF2\tminor\tx\ty\tz\t2026-11-10\t2026-11-11",
  );
  assert.deepEqual(
    bad.problems.map((problem) => problem.line),
    [2, 2, 3, 4],
  );
  assert.deepEqual(
    parseFindings(
      head +
        "\nPF-03\tminor\tx\ty\tz\t2026-11-10\t2026-11-11\nPF-03\tminor\tx\ty\tz\t2026-11-10\t2026-11-11",
    ).problems.map((problem) => problem.line),
    [3],
  );
  assert.deepEqual(
    parseFindings(head + "\nPF-04\tminor\tx\ty\tz\t2026-11-10\t2026-02-31").problems.map(
      (problem) => problem.line,
    ),
    [2],
  );
});
