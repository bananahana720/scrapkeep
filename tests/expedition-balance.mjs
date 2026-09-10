import { Game, PATH } from "../src/game.js";
import { performance } from "node:perf_hooks";
import assert from "node:assert/strict";

/**
 * Patrol geometry for the asserted gate.
 *
 * The expedition ships one route: `PATH` in `src/game.js`. The gate derives its
 * patrol from that binding point for point instead of restating geometry by
 * hand, so a change to `PATH` moves this route with it and the gate cannot stay
 * green while exercising a path the game does not use. The non-asserted probe
 * at `tests/balance.mjs:22` walks the same exported `PATH`.
 */
export function patrolRoute(source = PATH) {
  assert.ok(
    Array.isArray(source) && source.length > 1,
    "the shipped PATH needs at least two points to patrol",
  );
  return source.map(([x, z]) => [x, z]);
}

export function simulate(
  classId,
  policy = "patrol",
  seed = 745,
  risk = false,
  route = patrolRoute(),
) {
  const g = new Game(seed);
  g.reset(classId);
  g.setRisk(risk);
  let waypoint = 0;
  let direction = 1;
  let lastWave = 0;
  const waves = [];
  const visited = new Set();
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
      // Walk the shipped path end to end and back, with the probe's traversal in
      // `tests/balance.mjs`: aim at the current waypoint, advance on arrival,
      // reverse at the ends. A modulo wrap would instead aim the player from the
      // last shipped point straight back to the first, across the maze and off
      // the route the game publishes, so the gate would stop patrolling the
      // geometry it claims to patrol.
      const target = route[waypoint];
      const dx = target[0] - g.player.x,
        dz = target[1] - g.player.z,
        d = Math.hypot(dx, dz);
      if (d < 1) {
        if (waypoint === route.length - 1) direction = -1;
        if (waypoint === 0) direction = 1;
        waypoint += direction;
        visited.add(waypoint);
      } else input = { x: dx / d, z: dz / d };
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
    routePoints: route.length,
    visited: [...visited].sort((a, b) => a - b),
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
  const route = patrolRoute();
  // Drift-proof property, first half: the asserted route *is* the shipped path.
  assert.deepEqual(
    route,
    PATH.map(([x, z]) => [x, z]),
    "the asserted patrol route must be the shipped PATH",
  );
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
    "idle play must lose",
  );
  assert.ok(
    runs
      .filter((r) => r.policy === "patrol" && !r.risk)
      .every((r) => r.outcome === "victory"),
    "safe patrol must complete the expedition",
  );
  assert.ok(
    runs.some((r) => r.risk && r.outcome === "gameover"),
    "risk play must be able to lose",
  );
  assert.ok(
    runs.some((r) => r.risk && r.outcome === "victory"),
    "risk play must be able to win",
  );
  assert.ok(
    runs.every((r) => ["victory", "gameover"].includes(r.outcome)),
    "every run must terminate in victory or gameover",
  );
  assert.ok(
    runs.every((r) => r.policy === "idle" || r.routePoints === route.length),
    "every patrolling run must walk the shipped geometry",
  );
  // Drift-proof property, second half: a deliberate change to the path moves the
  // asserted route. This mutates a local copy only; `src/game.js` is untouched
  // and no gameplay value changes.
  const driftedSource = PATH.map(([x, z]) => [x, z]);
  driftedSource.push([
    (driftedSource.at(-1)[0] + driftedSource.at(-2)[0]) / 2,
    (driftedSource.at(-1)[1] + driftedSource.at(-2)[1]) / 2,
  ]);
  const driftedRoute = patrolRoute(driftedSource);
  assert.equal(
    driftedRoute.length,
    PATH.length + 1,
    "a PATH that gained a point must lengthen the asserted route",
  );
  assert.notDeepEqual(
    driftedRoute,
    route,
    "a PATH that gained a point must move the asserted route",
  );
  const driftedRun = simulate("scavenger", "patrol", 745, false, driftedRoute);
  assert.ok(
    driftedRun.visited.includes(driftedRoute.length - 1),
    "the run must patrol the added point of the drifted route",
  );
  console.log(
    JSON.stringify(
      {
        note: `Deterministic input-only patrol over the shipped PATH (${route.length} points imported from src/game.js), walked end to end and back; no combat state mutations, teleporting, or extra weapons. Simulation seconds exclude upgrade decisions. This is a balance probe, not a retention study.`,
        route: { source: "src/game.js PATH", points: route },
        driftCheck: {
          method:
            "local copy of PATH with the midpoint of its final segment appended; src/game.js unchanged",
          shippedPoints: route.length,
          driftedPoints: driftedRoute.length,
          driftedRunPatrolledAddedPoint: driftedRun.visited.includes(
            driftedRoute.length - 1,
          ),
        },
        wallSeconds: +((performance.now() - start) / 1000).toFixed(2),
        runs,
      },
      null,
      2,
    ),
  );
}
