import { Game } from "../src/game.js";
import { performance } from "node:perf_hooks";
import assert from "node:assert/strict";

export function simulate(classId, policy = "patrol", seed = 745, risk = false) {
  const g = new Game(seed);
  g.reset(classId);
  g.setRisk(risk);
  let waypoint = 0;
  let lastWave = 0;
  const waves = [];
  const route = [
    [1, -2],
    [-2, -5.5],
    [-5, -7],
    [0, -7],
    [10, -7],
    [10, -0.5],
    [3, 0.5],
    [-3, 0],
    [-10, -0.5],
    [-10, 5.5],
    [-4, 5.5],
    [-3, 4.5],
    [3, 6],
    [9, 6],
    [9, 8],
    [0, 8],
    [-11, 8],
    [-11, -7],
  ];
  for (
    let tick = 0;
    tick < 60 * 1600 && !["victory", "gameover"].includes(g.mode);
    tick++
  ) {
    if (g.mode === "upgrade") {
      const priority =
        g.base < 55
          ? [
              "repair",
              "damage",
              "haste",
              "range",
              "pipe",
              "coil",
              "bolt",
              "cactus",
              "magnet",
              "speed",
            ]
          : [
              "damage",
              "haste",
              "range",
              "pipe",
              "coil",
              "bolt",
              "cactus",
              "magnet",
              "speed",
              "repair",
            ];
      g.setRisk(risk);
      g.chooseUpgrade(
        g.options.reduce(
          (best, option, index) =>
            priority.indexOf(option.id) < priority.indexOf(g.options[best].id)
              ? index
              : best,
          0,
        ),
      );
    }
    let input = { x: 0, z: 0 };
    if (policy === "patrol") {
      let target = route[waypoint];
      if (Math.hypot(g.player.x - target[0], g.player.z - target[1]) < 1) {
        waypoint = (waypoint + 1) % route.length;
        target = route[waypoint];
      }
      const dx = target[0] - g.player.x,
        dz = target[1] - g.player.z,
        d = Math.hypot(dx, dz);
      input = { x: dx / d, z: dz / d };
      g.ability();
    }
    g.update(1 / 60, input);
    g.drainEvents();
    if (g.survived > lastWave) {
      lastWave = g.survived;
      waves.push({ wave: lastWave, seconds: Math.round(g.time), base: g.base });
    }
  }
  return {
    classId,
    policy,
    seed,
    risk,
    outcome: g.mode,
    wave: g.wave,
    survived: g.survived,
    seconds: +g.time.toFixed(1),
    score: g.score,
    collected: g.collected,
    base: g.base,
    upgrades: g.upgradeHistory.map((u) => u.id),
    waves,
  };
}
if (process.argv[1]?.endsWith("expedition-balance.mjs")) {
  const start = performance.now();
  const runs = [];
  for (const classId of ["scavenger", "engineer", "warden"]) {
    for (const policy of ["idle", "patrol"])
      runs.push(simulate(classId, policy));
    for (const seed of [745, 42, 20260905])
      runs.push(simulate(classId, "patrol", seed, true));
  }
  assert.ok(
    runs
      .filter((r) => r.policy === "idle")
      .every((r) => r.outcome === "gameover"),
  );
  assert.ok(
    runs
      .filter((r) => r.policy === "patrol" && !r.risk)
      .every((r) => r.outcome === "victory"),
  );
  assert.ok(runs.some((r) => r.risk && r.outcome === "gameover"));
  assert.ok(runs.some((r) => r.risk && r.outcome === "victory"));
  assert.ok(runs.every((r) => ["victory", "gameover"].includes(r.outcome)));
  console.log(
    JSON.stringify(
      {
        note: "Deterministic input-only patrol; no combat state mutations, teleporting, or extra weapons. Simulation seconds exclude upgrade decisions. This is a balance probe, not a retention study.",
        wallSeconds: +((performance.now() - start) / 1000).toFixed(2),
        runs,
      },
      null,
      2,
    ),
  );
}
