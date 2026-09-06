import test from "node:test";
import assert from "node:assert/strict";
import { Game, UPGRADES, PATH_LENGTH } from "../src/game.js";
import {
  createProfile,
  parseProfile,
  serializeProfile,
  settleRun,
  masteryFor,
  dailySeed,
  encodeChallenge,
  decodeChallenge,
  challengeUrl,
  HEROES,
  SECTORS,
} from "../src/campaign.js";
const clear = (g) => {
  g.startWave();
  g.spawnLeft = 0;
  g.enemies = [];
  g.update(1 / 60);
};
const snapshot = (g) =>
  JSON.stringify(g, (key, value) => (key === "events" ? undefined : value));

test("the expedition ends at fifteen; terminal frames and wave starts cannot resume it", () => {
  const g = new Game();
  g.reset();
  g.pickups = [];
  for (let i = 1; i <= 15; i++) {
    clear(g);
    assert.equal(g.survived, i);
    if (i < 15) assert.equal(g.chooseUpgrade(0), true);
  }
  assert.equal(g.mode, "victory");
  assert.equal(g.sector.name, SECTORS[2].name);
  assert.equal(g.upgradeHistory.length, 14);
  const state = snapshot(g);
  for (let i = 0; i < 100; i++) g.update(1 / 60, { x: 1, z: 0 });
  assert.equal(g.startWave(), false);
  assert.equal(g.pause(), false);
  assert.equal(g.ability(), false);
  assert.equal(g.dash(), false);
  assert.equal(snapshot(g), state);
});

test("risk can only change before an assault; it changes health and clear reward", () => {
  const safe = new Game(12),
    risky = new Game(12);
  safe.reset();
  risky.reset();
  assert.equal(risky.setRisk(true), true);
  safe.startWave();
  risky.startWave();
  assert.ok(risky.spawnEnemy("tank").hp > safe.spawnEnemy("tank").hp);
  assert.equal(risky.setRisk(false), false);
  for (const g of [safe, risky]) {
    g.pickups = [];
    g.enemies = [];
    g.spawnLeft = 0;
    g.update(1 / 60);
  }
  assert.equal(risky.score - safe.score, 550);
  assert.equal(risky.waveBonus.risk, 550);
  assert.equal(risky.setRisk(false), true);
});

test("no-breach objective pays only when the assault preserves the core", () => {
  for (const breach of [false, true]) {
    const g = new Game();
    g.reset();
    g.pickups = [];
    g.wave = 1;
    g.startWave();
    g.spawnLeft = 0;
    if (breach) {
      g.weapons = [];
      g.spawnEnemy("bug").travel = PATH_LENGTH;
    }
    g.update(1 / 60);
    assert.equal(g.waveBonus.objective, breach ? 0 : 250);
    assert.equal(g.objective.complete, !breach);
    assert.equal(g.objective.progress, breach ? 0 : 1);
    assert.equal(
      g.score,
      Object.values(g.scoreBreakdown).reduce((a, b) => a + b, 0),
    );
  }
});

test("bosses are named by sector and modifiers change marching speed and armor", () => {
  const g = new Game();
  g.reset();
  for (const wave of [5, 10, 15]) {
    g.wave = wave - 1;
    g.waveState = "gather";
    g.startWave();
    assert.equal(g.spawnEnemy("boss").name, SECTORS[wave / 5 - 1].boss);
  }
  g.wave = 1;
  g.waveState = "gather";
  g.startWave();
  assert.equal(g.waveModifier.id, "rush");
  const rush = g.spawnEnemy("bug");
  assert.equal(rush.speed, 1.75 * (1 + 2 * 0.025) * 1.12);
  g.waveState = "gather";
  g.startWave();
  assert.equal(g.waveModifier.hp, 1.18);
});

test("specializations change projectile damage and slow; ranks are capped and recorded", () => {
  const shoot = (upgraded) => {
    const g = new Game();
    g.reset("engineer");
    g.pickups = [];
    g.player.x = -8;
    g.player.z = -7;
    g.weapons = [g.weapons[0]];
    g.weapons[0].type = "cactus";
    g.weapons[0].angle = Math.PI;
    g.weapons[0].cooldown = 0;
    if (upgraded) {
      g.mode = "upgrade";
      g.options = [UPGRADES.find((u) => u.id === "cactus")];
      for (let i = 0; i < 3; i++) {
        g.mode = "upgrade";
        assert.ok(g.chooseUpgrade(0));
      }
      g.mode = "upgrade";
      assert.equal(g.chooseUpgrade(0), false);
      g.mode = "playing";
    }
    const e = g.spawnEnemy("tank");
    g.update(1 / 60);
    const damage = g.projectiles[0].damage;
    for (let i = 0; i < 50; i++) g.update(1 / 60);
    return { g, e, damage };
  };
  const safe = shoot(false),
    specialized = shoot(true);
  assert.ok(specialized.damage > safe.damage * 2);
  assert.ok(specialized.e.slow > 0);
  assert.equal(safe.e.slow, 0);
  assert.equal(specialized.g.upgradeHistory.length, 3);
});

test("seed and choices reproduce pickup, encounter, reward, and upgrade state", () => {
  const a = new Game(1),
    b = new Game(2);
  a.reset("warden", true, { seed: 123 });
  b.reset("warden", true, { seed: 123 });
  for (let i = 0; i < 15000; i++) {
    for (const g of [a, b]) {
      if (g.mode === "upgrade") g.chooseUpgrade(0);
      g.update(1 / 60, { x: Math.sin(i / 80), z: Math.cos(i / 80) });
      g.drainEvents();
    }
  }
  assert.equal(snapshot(a), snapshot(b));
});

test("fatal breach stops the current frame and all later simulation frames", () => {
  const g = new Game();
  g.reset();
  g.base = 1;
  g.weapons = [];
  for (let i = 0; i < 3; i++) g.spawnEnemy("bug").travel = PATH_LENGTH;
  g.update(1 / 60);
  assert.equal(g.mode, "gameover");
  assert.equal(g.drainEvents().filter((e) => e.type === "breach").length, 1);
  const state = snapshot(g);
  g.update(1 / 60);
  assert.equal(snapshot(g), state);
});

test("mastery survives failed and abandoned runs and each run settles exactly once", () => {
  let p = createProfile();
  for (const [i, outcome] of ["gameover", "abandoned", "victory"].entries()) {
    const run = {
      id: `run-${i}`,
      classId: "scavenger",
      seed: 10,
      score: 4000,
      survived: outcome === "victory" ? 15 : 5,
      outcome,
    };
    const result = settleRun(p, run);
    p = result.profile;
    assert.equal(result.awarded, outcome === "victory" ? 200 : 50);
    const duplicate = settleRun(parseProfile(serializeProfile(p)), run);
    assert.equal(duplicate.awarded, 0);
    assert.deepEqual(duplicate.profile, p);
  }
  assert.equal(p.classes.scavenger.xp, 300);
  assert.equal(p.classes.scavenger.runs, 3);
  assert.equal(p.classes.scavenger.wins, 1);
  assert.deepEqual(p.blueprints, [HEROES.scavenger.blueprint]);
  assert.equal(masteryFor(p, "scavenger").badge, "Scrap keeper");
  assert.equal(p.classes.engineer.xp, 0);
});

test("profile parsing recovers from malformed storage and does not admit corrupt fields", () => {
  assert.deepEqual(parseProfile("{broken"), createProfile());
  assert.deepEqual(parseProfile(null), createProfile());
  const p = parseProfile({
    version: 1,
    classes: { scavenger: { xp: -2, bestWave: 99, runs: "12", wins: 2 } },
    settled: ["good", "good", {}, "bad ID"],
  });
  assert.equal(p.classes.scavenger.xp, 0);
  assert.equal(p.classes.scavenger.bestWave, 0);
  assert.equal(p.classes.scavenger.runs, 0);
  assert.deepEqual(p.settled, ["good"]);
  assert.equal(
    settleRun(p, {
      id: "x",
      classId: "constructor",
      seed: 1,
      score: 2,
      survived: 1,
      outcome: "gameover",
    }).awarded,
    0,
  );
  assert.equal(
    settleRun(p, {
      id: "x",
      classId: "scavenger",
      seed: 1,
      score: 2,
      survived: 1,
      outcome: "victory",
    }).awarded,
    0,
  );
});

test("daily and shared challenges retain seed, class and target with strict validation", () => {
  assert.equal(
    dailySeed(new Date("2026-09-05T00:00:00Z")),
    dailySeed("2026-09-05"),
  );
  assert.notEqual(dailySeed("2026-09-05"), dailySeed("2026-09-06"));
  assert.throws(() => dailySeed("2026-02-30"));
  assert.throws(() => dailySeed("2026-99-01"));
  const challenge = { seed: 0xffffffff, classId: "warden", targetScore: 42000 };
  assert.deepEqual(decodeChallenge(encodeChallenge(challenge)), challenge);
  const url = new URL(
    challengeUrl("https://example.test/play?foo=1", challenge),
  );
  assert.deepEqual(
    decodeChallenge(new URLSearchParams(url.hash.slice(1)).get("challenge")),
    challenge,
  );
  for (const raw of [
    "",
    null,
    "1.4294967296.warden.1",
    "1.1.unknown.0",
    "1.2.warden.-1",
    "1.1.constructor.10",
    "1.1.warden.1000000001",
  ])
    assert.equal(decodeChallenge(raw), null);
});
