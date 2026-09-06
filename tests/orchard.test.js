import test from "node:test";
import assert from "node:assert/strict";
import {
  OrchardGame,
  ARENA,
  ENEMY_CONFIG,
  groundHeight,
  LIGHTNING_CONFIG,
  ITEM_CONFIG,
} from "../src/orchard/simulation.js";

const tick = (game, seconds, input = {}, dt = 1 / 120) => {
  for (let time = 0; time < seconds - 1e-9; time += dt)
    game.update(Math.min(dt, seconds - time), input);
};
const aim = (from, to) => Math.atan2(to.x - from.x, from.z - to.z);

function fixture(kind = "snipcart", position = { x: 0, z: -4 }) {
  const game = new OrchardGame().start();
  const enemy = game._makeEnemy(kind, 0, 0, 0);
  enemy.id = "fixture-enemy";
  game._entryCooldown = 1e9;
  game.wave.entries = [];
  game.enemies = [enemy];
  game.pickups = [];
  Object.assign(enemy, {
    x: 0,
    z: 0,
    y: 0,
    yaw: 0,
    active: true,
    state: "approach",
    cooldown: 0,
    weakX: ENEMY_CONFIG[kind].radius + 0.2,
    weakZ: 0,
  });
  Object.assign(game.player, { ...position, y: 1 });
  return { game, enemy };
}

function shoot(game, target, holdSeconds = 0.05) {
  const input = { aimYaw: aim(game.player, target), fire: true };
  tick(game, holdSeconds, input);
  game.update(1 / 120, { aimYaw: input.aimYaw, fire: false });
}

test("exports and reset produce a finite, bounded, detached snapshot", () => {
  const game = new OrchardGame({ seed: 19 });
  assert.equal(game.mode, "ready");
  assert.equal(game.enemies.length, 0);
  assert.equal(game.player.y, 1);
  assert.equal(game.wave.remaining, 10);
  const initial = game.snapshot();
  game.start();
  tick(game, 1, { x: 1 });
  game.reset();
  assert.deepEqual(game.snapshot(), initial);
  initial.player.hp = 0;
  assert.equal(game.player.hp, 100);
  assert.deepEqual(game.drainEvents(), []);
});

test("movement accelerates in supplied world direction and braking stops faster", () => {
  const game = new OrchardGame().start();
  game.enemies = [];
  game._entryCooldown = 1e9;
  game.wave.entries = [];
  tick(game, 0.1, { x: 1, aimYaw: Math.PI });
  assert(game.player.vx > 2 && game.player.vx < 3);
  assert.equal(game.player.vz, 0);
  tick(game, 0.6, { x: 1 });
  assert(Math.abs(game.player.vx - 7.4) < 1e-8);
  const moving = game.player.vx;
  tick(game, 0.1, { brake: true });
  assert(game.player.vx < moving / 2);
  tick(game, 0.15, { brake: true });
  assert.equal(game.player.vx, 0);
});

test("diagonal movement is normalized and burst has an edge and cooldown", () => {
  const game = new OrchardGame().start();
  game.enemies = [];
  game._entryCooldown = 1e9;
  game.wave.entries = [];
  tick(game, 0.5, { x: 1, z: -1 });
  assert(Math.abs(Math.hypot(game.player.vx, game.player.vz) - 7.4) < 1e-8);
  game.update(1 / 120, { x: 1, dash: true });
  assert.equal(game.player.vx, 19);
  assert.equal(game.player.vz, 0);
  assert.equal(game.player.dashTime, 0.24);
  tick(game, 2, { dash: true });
  assert.equal(
    game.drainEvents().filter((e) => e.type === "ram" && e.kind === "burst")
      .length,
    1,
  );
  game.update(1 / 120, { dash: false });
  game.update(1 / 120, { dash: true, aimYaw: -Math.PI / 2 });
  assert(game.player.vx < -18);
});

test("terrain follows the ramp and maximum growth retains both outside routes", () => {
  assert.equal(groundHeight(0, 0), 0);
  assert.equal(groundHeight(0, -18.5), 1.25);
  assert.equal(groundHeight(0, -30), 2.5);
  for (const x of [-17, 17]) {
    const game = new OrchardGame().start();
    game._entryCooldown = 1e9;
    Object.assign(game.player, { x, z: 21, radius: 1.65 });
    tick(game, 9, { z: -1 });
    assert.equal(game.player.hp, 100);
    assert(game.player.z < -30);
    assert(
      Math.abs(
        game.player.y - groundHeight(game.player.x, game.player.z) - 1.65,
      ) < 1e-8,
    );
    assert(
      game.player.x >= ARENA.minX + 1.65 && game.player.x <= ARENA.maxX - 1.65,
    );
  }
});

test("windup commits aim and position and a spatial exit makes the cut miss", () => {
  const { game, enemy } = fixture();
  game.update(1 / 120);
  assert.equal(enemy.state, "windup");
  const locked = { x: enemy.x, z: enemy.z, yaw: enemy.yaw };
  assert.equal(game.hazards[0].previewSegments.length, 34);
  tick(game, 1.1, { x: 1 });
  assert.equal(enemy.x, locked.x);
  assert.equal(enemy.z, locked.z);
  assert.equal(enemy.yaw, locked.yaw);
  tick(game, 0.65, { brake: true });
  assert.equal(enemy.state, "recovery");
  assert.equal(game.player.hp, 100);
});

test("one committed stroke hits at most once and burst grants no immunity", () => {
  const { game, enemy } = fixture("snipcart");
  game.update(1 / 120);
  tick(game, 1.75);
  assert.equal(enemy.state, "recovery");
  assert.equal(game.player.hp, 83);
  assert.equal(game.drainEvents().filter((e) => e.type === "hurt").length, 1);

  const other = fixture("snipcart", { x: 1.65, z: -3 });
  Object.assign(other.enemy, {
    state: "active",
    stateTime: 0.28,
    phase: 0.58,
    attackId: 1,
  });
  other.game.update(1 / 120, { dash: true, aimYaw: 0 });
  assert(other.game.player.dashTime > 0);
  assert(other.game.player.hp < 100);
});

test("body contact bumps without damage or repeated ram damage", () => {
  const { game, enemy } = fixture("snipcart", { x: 0, z: -2.2 });
  enemy.cooldown = 100;
  tick(game, 2, { z: 1 });
  assert.equal(game.player.hp, 100);
  assert(
    Math.hypot(game.player.x - enemy.x, game.player.z - enemy.z) >=
      game.player.radius + enemy.radius - 1e-8,
  );
  game.update(1 / 120, { z: 1, dash: true });
  const afterImpact = enemy.hp;
  tick(game, 0.2, { z: 1 });
  assert(afterImpact < enemy.maxHp);
  assert.equal(enemy.hp, afterImpact);
});

test("Spreadleg shoes move outward while Snipcart blades close inward", () => {
  for (const kind of ["snipcart", "spreadleg", "pruner"]) {
    const { game, enemy } = fixture(kind, { x: 15, z: 20 });
    Object.assign(enemy, {
      state: "active",
      phase: 0,
      stateTime: 0,
      attackId: 1,
    });
    game.update(1 / 120);
    const start = game.hazards[0].segments.map((s) => Math.abs(s.x2 - enemy.x));
    tick(game, ENEMY_CONFIG[kind].active * 0.6);
    const end = game.hazards[0].segments.map((s) => Math.abs(s.x2 - enemy.x));
    assert(kind === "spreadleg" ? end[0] > start[0] : end[0] < start[0]);
    assert.equal(
      game.hazards[0].kind,
      kind === "spreadleg" ? "spread" : kind === "pruner" ? "sweep" : "cut",
    );
    assert.equal(
      game.hazards[0].segments[0].radius,
      ENEMY_CONFIG[kind].width / 2,
    );
  }
});

test("active capsule endpoints match the articulated model at arbitrary world yaw", () => {
  for (const kind of ["snipcart", "spreadleg", "pruner"]) {
    const { game, enemy } = fixture(kind, { x: 16, z: 20 });
    Object.assign(enemy, {
      state: "active",
      stateTime: ENEMY_CONFIG[kind].active * 0.4 - 1 / 120,
      yaw: 0.7,
      x: 2,
      z: -3,
    });
    game.update(1 / 120);
    const segment = game.hazards[0].segments[0];
    const local = (x, z) => ({
      x: Math.cos(0.7) * (x - 2) + Math.sin(0.7) * (z + 3),
      z: -Math.sin(0.7) * (x - 2) + Math.cos(0.7) * (z + 3),
    });
    const tip = local(segment.x2, segment.z2);
    if (kind === "snipcart") {
      assert(Math.abs(tip.x - Math.sin(0.58 * 0.6) * 2.376) < 1e-8);
      assert(Math.abs(tip.z + 0.73 + Math.cos(0.58 * 0.6) * 2.376) < 1e-8);
    } else if (kind === "spreadleg") {
      const a = 0.2 + 0.83 * 0.4;
      assert(
        Math.abs(tip.x + 0.37 + 1.5 * Math.sin(a) + 1.4 * Math.sin(0.3 * a)) <
          1e-8,
      );
      assert(Math.abs(tip.z + 0.155) < 1e-8);
    } else {
      const sweep = -0.67 + 1.34 * 0.4;
      const x = Math.sin(0.35 * 0.6) * 4.86;
      const z = -2.2 - Math.cos(0.35 * 0.6) * 4.86;
      assert(
        Math.abs(tip.x - Math.cos(sweep) * x - Math.sin(sweep) * z) < 1e-8,
      );
      assert(
        Math.abs(tip.z - 0.55 + Math.sin(sweep) * x - Math.cos(sweep) * z) <
          1e-8,
      );
    }
  }
});

test("outward foot stroke catches a flank while the forward exit stays clear", () => {
  const flank = fixture("spreadleg", { x: 3.2, z: -0.17 });
  Object.assign(flank.enemy, { state: "windup", stateTime: 0, yaw: 0 });
  tick(flank.game, 2.05);
  assert.equal(flank.game.player.hp, 80);
  const forward = fixture("spreadleg", { x: 0, z: -3.3 });
  Object.assign(forward.enemy, { state: "windup", stateTime: 0, yaw: 0 });
  tick(forward.game, 2.05);
  assert.equal(forward.game.player.hp, 100);
});

test("shots hit the nearest body and all live armor phases take ordinary damage", () => {
  for (const state of ["idle", "approach", "windup", "active", "recovery"]) {
    const { game, enemy } = fixture("pruner", { x: 0, z: 18 });
    Object.assign(enemy, {
      state,
      active: state !== "idle",
      cooldown: 100,
      stateTime: 0,
      yaw: Math.PI,
    });
    shoot(game, enemy, 0.02);
    assert(enemy.hp < enemy.maxHp, state);
    assert.equal(game.stats.counters, 0);
  }
  const { game, enemy } = fixture("snipcart", { x: 0, z: 12 });
  enemy.cooldown = 100;
  const far = { ...enemy, id: "far", z: -8 };
  game.enemies.push(far);
  shoot(game, far);
  assert(enemy.hp < enemy.maxHp);
  assert.equal(far.hp, far.maxHp);
});

test("housing shots and recovery rams reward aim and loosen salvage once per recovery", () => {
  const { game, enemy } = fixture("pruner", { x: 2.4, z: 8 });
  Object.assign(enemy, { state: "recovery", stateTime: 0, yaw: 0 });
  game.update(1 / 120);
  shoot(game, { x: enemy.weakX - 0.3, z: enemy.weakZ }, 0.02);
  assert.equal(game.stats.counters, 1);
  assert(enemy.maxHp - enemy.hp > 21);
  assert.equal(game.pickups.length, 2);
  tick(game, 0.3);
  shoot(game, { x: enemy.weakX - 0.3, z: enemy.weakZ }, 0.02);
  assert.equal(game.stats.counters, 2);
  assert.equal(game.pickups.length, 2);

  const ram = fixture("pruner", { x: 3.65, z: 0 });
  Object.assign(ram.enemy, { state: "recovery", stateTime: 0, yaw: 0 });
  ram.game.update(1 / 120, { x: -1, dash: true });
  assert.equal(ram.game.stats.counters, 1);
  assert(Math.abs(ram.enemy.maxHp - ram.enemy.hp - 23 * 2.1) < 1e-8);
});

test("collecting mechanisms changes ram damage, burst recovery, protection and bounded growth", () => {
  const { game, enemy } = fixture("pruner", { x: 3.6, z: 0 });
  enemy.cooldown = 100;
  game.pickups = ["shear", "brace", ...Array(100).fill("scrap")].map(
    (kind, i) => ({
      id: `part-${i}`,
      x: game.player.x,
      y: 0,
      z: 0,
      kind,
      collected: false,
    }),
  );
  game.update(1 / 120);
  assert.equal(game.player.shear, 1);
  assert.equal(game.player.brace, 1);
  assert.equal(game.player.radius, 1.65);
  Object.assign(game.player, {
    x: enemy.radius + game.player.radius + 0.1,
    z: 0,
  });
  game.update(1 / 120, { x: -1, dash: true });
  assert.equal(enemy.maxHp - enemy.hp, 32);
  assert(Math.abs(game.player.dashCooldown - 1.23) < 1e-8);
  assert.equal(game.stats.collected, 102);
  const protection = fixture("snipcart");
  protection.game.player.brace = 1;
  tick(protection.game, 1.8);
  assert(Math.abs(protection.game.stats.damageTaken - 17 * 0.85) < 1e-8);
});

test("pause freezes time and queued actions, resume and restart behave explicitly", () => {
  const game = new OrchardGame().start();
  tick(game, 0.2, { x: 1, fire: true });
  game.pause();
  const paused = game.snapshot();
  tick(game, 3, { dash: true, fire: true, x: -1 });
  assert.deepEqual(game.snapshot(), paused);
  game.resume();
  tick(game, 0.1);
  assert.equal(game.stats.shots, 1);
  assert(game.time > paused.time);
  game.reset();
  assert.equal(game.mode, "ready");
  assert.equal(game.time, 0);
});

test("30 Hz and 120 Hz input schedules give equivalent state and deterministic drops", () => {
  function run(dt) {
    const game = new OrchardGame({ seed: 172 }).start();
    game.enemies = [];
    game._entryCooldown = 1e9;
    game.wave.entries = [];
    for (const [duration, input] of [
      [1, { x: 1, z: -1 }],
      [0.5, { z: -1, fire: true }],
      [0.5, { x: -1 }],
      [0.5, { x: -1, dash: true }],
      [1, { brake: true }],
    ])
      tick(game, duration, input, dt);
    return game.snapshot();
  }
  assert.deepEqual(run(1 / 30), run(1 / 120));
  const a = fixture("snipcart", { x: 0, z: 9 });
  const b = fixture("snipcart", { x: 0, z: 9 });
  a.enemy.hp = b.enemy.hp = 1;
  shoot(a.game, a.enemy);
  shoot(b.game, b.enemy);
  assert.deepEqual(a.game.pickups, b.game.pickups);
});

test("distant Pruner declares a locked toss path and releases at the flat-arm phase", () => {
  const { game, enemy } = fixture("pruner", { x: 0, z: 18 });
  game.update(1 / 120);
  assert.equal(enemy.attackStyle, "toss");
  assert.equal(enemy.state, "windup");
  const preview = game.hazards[0];
  assert.equal(preview.kind, "offcut");
  assert.equal(preview.previewSegments.length, 1);
  assert(Math.abs(preview.z - 6.51) < 1e-8);
  assert(Math.abs(preview.previewSegments[0].z2 - 38.01) < 1e-8);
  const yaw = enemy.yaw;
  tick(game, ENEMY_CONFIG.pruner.windup);
  assert.equal(enemy.state, "active");
  assert.equal(game.drainEvents().filter((e) => e.type === "toss").length, 0);
  tick(game, 0.25);
  assert.equal(game.drainEvents().filter((e) => e.type === "toss").length, 0);
  tick(game, 1 / 60);
  const events = game.drainEvents().filter((e) => e.type === "toss");
  assert.equal(events.length, 1);
  assert(Math.abs(events[0].z - 6.51) < 1e-8);
  assert.equal(enemy.yaw, yaw);
  const projectile = game.hazards.find(
    (h) => h.kind === "offcut" && h.state === "active",
  );
  assert(projectile);
  assert.equal(projectile.bodyRadius, 0.65);
  const previousZ = projectile.z;
  tick(game, 0.1);
  const later = game.hazards.find((h) => h.id === projectile.id);
  assert(Math.abs(later.z - previousZ - 0.9) < 1e-8);
});

test("moving sideways after toss lock dodges without retargeting or range immunity", () => {
  const { game, enemy } = fixture("pruner", { x: 0, z: 18 });
  game.update(1 / 120);
  const committedYaw = enemy.yaw;
  tick(game, 1, { x: 1 });
  tick(game, 3.5, { brake: true });
  assert.equal(enemy.yaw, committedYaw);
  assert.equal(game.player.hp, 100);
  assert(game.drainEvents().some((e) => e.type === "toss"));
  const before = enemy.hp;
  shoot(game, enemy, 0.02);
  assert(enemy.hp < before);
});

test("rolling offcut hurts once, respects hit recovery and never drops loot", () => {
  for (const protectedPlayer of [false, true]) {
    const { game } = fixture("pruner", { x: 0, z: 18 });
    if (protectedPlayer) game.player.hurtTime = 10;
    tick(game, 4);
    assert.equal(game.player.hp, protectedPlayer ? 100 : 82);
    assert.equal(
      game.drainEvents().filter((e) => e.type === "hurt").length,
      protectedPlayer ? 0 : 1,
    );
    assert.equal(
      game.hazards.filter((h) => h.kind === "offcut" && h.state === "active")
        .length,
      0,
    );
    assert.equal(game.pickups.length, 0);
  }
});

test("released offcut survives arm state changes, pauses, expires and resets", () => {
  const { game, enemy } = fixture("pruner", { x: 0, z: 18 });
  tick(game, 2.1);
  const released = game.hazards.find(
    (h) => h.kind === "offcut" && h.state === "active",
  );
  assert(released);
  game.pause();
  const paused = game.snapshot();
  tick(game, 8);
  assert.deepEqual(game.snapshot(), paused);
  game.resume();
  Object.assign(game.player, { x: 16, z: 18 });
  enemy.state = "recovery";
  game.enemies = [];
  game._entryCooldown = 1e9;
  game.wave.entries = [];
  tick(game, 0.1);
  assert(game.hazards.some((h) => h.id === released.id));
  tick(game, 3.5);
  assert.equal(game.hazards.length, 0);
  assert.equal(game.player.hp, 100);

  const reset = fixture("pruner", { x: 0, z: 18 });
  tick(reset.game, 2.1);
  assert(
    reset.game.hazards.some((h) => h.kind === "offcut" && h.state === "active"),
  );
  reset.game.reset().start();
  reset.game.enemies = [];
  tick(reset.game, 0.1);
  assert.equal(reset.game.hazards.length, 0);
  assert.equal(reset.game.player.hp, 100);
});

test("offcut count stays bounded even with repeated release fixtures", () => {
  const { game, enemy } = fixture("pruner", { x: 16, z: 18 });
  for (let i = 0; i < 9; i++) {
    Object.assign(enemy, {
      state: "active",
      stateTime: 0.4,
      attackStyle: "toss",
      tossReleased: false,
      yaw: 0,
    });
    game.update(1 / 120);
  }
  assert.equal(
    game.hazards.filter((h) => h.kind === "offcut" && h.state === "active")
      .length,
    4,
  );
  assert.equal(game.drainEvents().filter((e) => e.type === "toss").length, 4);
});

test("invalid boundary input and long mixed operation keep every number finite", () => {
  const game = new OrchardGame().start();
  game.update(NaN, { x: NaN });
  game.update(-2);
  game.update(1 / 60, { x: Infinity, z: NaN, aimYaw: Infinity });
  for (let i = 0; i < 3600; i++) {
    game.update(1 / 60, {
      x: Math.sin(i / 60),
      z: -Math.cos(i / 70),
      aimYaw: i / 30,
      fire: i % 80 < 60,
      dash: i % 120 === 0,
      deploy: i % 30 === 0,
    });
    if (game.mode === "lost") game.reset().start();
  }
  function finiteTree(value) {
    if (typeof value === "number") assert(Number.isFinite(value));
    else if (value && typeof value === "object")
      for (const child of Object.values(value)) finiteTree(child);
  }
  finiteTree({
    player: game.player,
    enemies: game.enemies,
    pickups: game.pickups,
    hazards: game.hazards,
    companion: game.companion,
    stats: game.stats,
  });
  assert(game.player.radius <= 1.65);
  assert(game.player.hp >= 0 && game.player.hp <= game.player.maxHp);
});

function rayTo(game, point, origin = game._weaponOrigin()) {
  return {
    origin: { ...origin },
    direction: {
      x: point.x - origin.x,
      y: point.y - origin.y,
      z: point.z - origin.z,
    },
  };
}

function clearWave(game) {
  game._waveQueue = [];
  game.wave.entries = [];
  for (const enemy of game.enemies) game._damage(enemy, 1e6, false, "fixture");
  game.update(1 / 120);
}

test("held primary repeats on its interval and releases without an extra bolt", () => {
  const { game, enemy } = fixture("pruner", { x: 0, z: 18 });
  enemy.cooldown = 100;
  tick(game, 0.5, { fire: true, aimYaw: 0 });
  assert.equal(game.stats.shots, 3);
  assert.equal(enemy.maxHp - enemy.hp, LIGHTNING_CONFIG.bolt.damage * 3);
  tick(game, 0.5);
  assert.equal(game.stats.shots, 3);
  assert.equal(game.player.charge, 0);
});

test("double jump permits one air jump, resets on landing, and buffers a landing jump", () => {
  const { game } = fixture("snipcart", { x: 12, z: 15 });
  game.update(1 / 120, { jump: true, x: 1 });
  assert(!game.player.grounded);
  assert.equal(game.player.airJumps, 1);
  tick(game, 0.12, { x: -1 });
  assert(game.player.vx < 0, "air control changes direction");
  game.update(1 / 120, { jump: true });
  assert.equal(game.player.airJumps, 0);
  game.update(1 / 120);
  const before = game.player.vy;
  game.update(1 / 120, { jump: true });
  assert(game.player.vy < before, "a third press cannot jump");
  tick(game, 1.5);
  assert(game.player.grounded);
  assert.equal(game.player.airJumps, 1);
  Object.assign(game.player, { grounded: false, airJumps: 0, y: 1.02, vy: -4 });
  game.update(1 / 120, { jump: true });
  assert(game.player.grounded);
  game.update(1 / 120);
  assert(!game.player.grounded);
  assert(game.player.vy > 9);
});

test("descending contact rebounds once, restores an air jump, and preserves vertical separation", () => {
  const { game, enemy } = fixture("snipcart", { x: 0, z: 0 });
  Object.assign(enemy, { cooldown: 100, state: "recovery", stateTime: 0 });
  Object.assign(game.player, {
    y: enemy.bodyHeight + 1.03,
    vy: -8,
    grounded: false,
    airJumps: 0,
  });
  game.update(1 / 120);
  assert.equal(enemy.maxHp - enemy.hp, 42);
  assert.equal(game.player.vy, 8.5);
  assert.equal(game.player.airJumps, 1);
  assert.equal(game.player.z, 0);
  tick(game, 0.2);
  assert.equal(enemy.maxHp - enemy.hp, 42);
  assert.equal(
    game.drainEvents().filter((event) => event.type === "bounce").length,
    1,
  );
  const high = fixture("pruner", { x: 0, z: 0 });
  Object.assign(high.game.player, { y: 9, vy: -1, grounded: false });
  high.enemy.cooldown = 100;
  high.game.update(1 / 120);
  assert.equal(
    high.game.player.z,
    0,
    "passing over a body does not create a side bump",
  );
});

test("low tools and rolling offcuts miss airborne bodies while taller strokes remain dangerous", () => {
  const low = fixture("spreadleg", { x: 3.2, z: -0.17 });
  Object.assign(low.enemy, { state: "active", stateTime: 0.45, yaw: 0 });
  Object.assign(low.game.player, { y: 2, vy: 0, grounded: false });
  low.game.update(1 / 120);
  assert.equal(low.game.player.hp, 100);
  assert(low.game.hazards[0].jumpable);
  assert.equal(low.game.hazards[0].yMax, 0.53);
  const tall = fixture("pruner", { x: 0, z: -5 });
  Object.assign(tall.enemy, { state: "active", stateTime: 0.4, yaw: 0 });
  Object.assign(tall.game.player, { y: 2.7, vy: 0, grounded: false });
  tall.game.update(1 / 120);
  assert(tall.game.player.hp < 100);
  assert(!tall.game.hazards[0].jumpable);
  const rolling = fixture("pruner", { x: 0, z: 18 });
  rolling.enemy.cooldown = 100;
  rolling.game._offcuts = [
    { id: "air-test", x: 0, z: 18, vx: 0, vz: 9, yaw: 0, age: 0 },
  ];
  Object.assign(rolling.game.player, { y: 3, vy: 0, grounded: false });
  rolling.game.update(1 / 120);
  assert.equal(rolling.game.player.hp, 100);
  assert.equal(rolling.game._offcuts.length, 1);
});

test("bolt preview and committed geometry agree for elevated targets and terrain obstructions", () => {
  const { game, enemy } = fixture("snipcart", { x: 0, z: 10 });
  enemy.y = 6;
  enemy.cooldown = 100;
  const inputAim = rayTo(game, { x: 0, y: 7, z: 0 });
  const before = game.snapshot();
  const preview = game.previewAttack("bolt", inputAim);
  assert.deepEqual(game.snapshot(), before, "preview is read-only");
  assert.deepEqual(preview.targetIds, [enemy.id]);
  assert(preview.point.y > 6);
  game.update(1 / 120, { fire: true, aim: inputAim });
  const cast = game.drainEvents().find((event) => event.type === "attack");
  assert.deepEqual(cast.attack, preview);
  assert(enemy.hp < enemy.maxHp);

  Object.assign(game.player, { x: 0, z: -10, y: 1 });
  Object.assign(enemy, { x: 0, z: -30, y: 2.5 });
  const horizontal = game.previewAttack(
    "bolt",
    rayTo(game, { x: 0, y: 1.45, z: -40 }),
  );
  assert(horizontal.blocked);
  assert.equal(horizontal.targetIds.length, 0);
  assert(horizontal.point.z > -23);
  assert(
    Math.abs(
      horizontal.point.y - groundHeight(horizontal.point.x, horizontal.point.z),
    ) < 1e-7,
  );
});

test("bolt height, range and intervening enemy bodies determine the actual impact", () => {
  const { game, enemy } = fixture("snipcart", { x: 0, z: 10 });
  enemy.cooldown = 100;
  const over = game.previewAttack("bolt", rayTo(game, { x: 0, y: 20, z: 0 }));
  assert.equal(over.targetIds.length, 0);
  assert(
    Math.abs(
      Math.hypot(
        over.point.x - over.origin.x,
        over.point.y - over.origin.y,
        over.point.z - over.origin.z,
      ) - LIGHTNING_CONFIG.bolt.range,
    ) < 1e-7,
  );
  const behind = { ...enemy, id: "behind", z: -12 };
  game.enemies.push(behind);
  const hit = game.previewAttack("bolt", rayTo(game, { x: 0, y: 1, z: -12 }));
  assert.deepEqual(hit.targetIds, [enemy.id]);
  assert(hit.point.z > 0);
  Object.assign(enemy, { z: -35 });
  game.enemies = [enemy];
  assert.equal(
    game.previewAttack("bolt", rayTo(game, { x: 0, y: 1, z: -35 })).targetIds
      .length,
    0,
  );
});

test("Q prepares and casts on release; invalid terrain, cancel and pause spend no cooldown", () => {
  const { game, enemy } = fixture("snipcart", { x: 0, z: 10 });
  enemy.cooldown = 100;
  const inputAim = rayTo(game, { x: 0, y: 0, z: 0 });
  const preview = game.previewAttack("strike", inputAim);
  assert(preview.valid);
  game.update(1 / 120, { strike: true, aim: inputAim });
  assert.equal(game.preparedAbility, "strike");
  assert.equal(enemy.hp, enemy.maxHp);
  game.update(1 / 120, { aim: inputAim });
  assert(game.player.strikeCooldown > 0);
  assert.equal(enemy.maxHp - enemy.hp, LIGHTNING_CONFIG.strike.damage);
  const cast = game.drainEvents().find((event) => event.type === "attack");
  assert.deepEqual(cast.attack, preview);
  game.player.strikeCooldown = 0;
  game.update(1 / 120, { strike: true, aim: inputAim });
  game.update(1 / 120, { cancel: true, aim: inputAim });
  assert.equal(game.player.strikeCooldown, 0);
  game.update(1 / 120, { strike: true, aim: inputAim });
  game.pause().resume();
  game.update(1 / 120, { aim: inputAim });
  assert.equal(game.player.strikeCooldown, 0);
  const upward = rayTo(game, { x: 0, y: 30, z: 0 });
  game.update(1 / 120, { strike: true, aim: upward });
  game.update(1 / 120, { aim: upward });
  assert.equal(game.player.strikeCooldown, 0);
  assert(
    !game.previewAttack("strike", rayTo(game, { x: 30, y: 0, z: 0 })).valid,
  );
});

test("ground casts use weapon obstruction and radius geometry when firing from the air", () => {
  const { game, enemy } = fixture("snipcart", { x: 0, z: 10 });
  Object.assign(game.player, { y: 8, grounded: false });
  const target = { x: 0, y: 0, z: 0 };
  const preview = game.previewAttack("strike", rayTo(game, target));
  assert(preview.valid);
  assert.deepEqual(preview.point, target);
  assert.deepEqual(preview.targetIds, [enemy.id]);
  assert.equal(preview.origin.y, 8.45);
  assert.equal(preview.radius, LIGHTNING_CONFIG.strike.radius);
  Object.assign(game.player, { y: 1, z: -10 });
  const blocked = game.previewAttack("strike", {
    origin: { x: 0, y: 10, z: -10 },
    direction: { x: 0, y: -10, z: -25 },
  });
  assert(
    !blocked.valid,
    "camera terrain point beyond range cannot bypass weapon limits",
  );
});

test("conductors cost no scrap, replace oldest, share preview targets, link and attack autonomously", () => {
  const { game, enemy } = fixture("pruner", { x: 0, z: 10 });
  enemy.cooldown = 100;
  for (const x of [-3, 3, 1]) {
    game.player.conductorCooldown = 0;
    const inputAim = rayTo(game, { x, y: 0, z: 0 });
    game.update(1 / 120, { conductor: true, aim: inputAim });
    game.update(1 / 120, { aim: inputAim });
  }
  assert.equal(game.conductors.length, 2);
  assert(game.conductors.every((conductor) => conductor.id !== "conductor-1"));
  assert.equal(game.player.scrap, 0);
  tick(game, 0.2);
  assert(enemy.hp < enemy.maxHp);
  assert.equal(game.conductorLinks.length, 1);
  const pulse = game
    .drainEvents()
    .find((event) => event.type === "attack" && event.source === "conductor");
  assert(pulse.attack.targetIds.includes(enemy.id));
  const placement = game.previewAttack(
    "conductor",
    rayTo(game, { x: 1, y: 0, z: 0 }),
  );
  assert.deepEqual(
    placement.targetIds,
    game._conductorAttack(placement.point, game.conductors.slice(-1)).targetIds,
  );
});

test("chain hits charge the eight-second ultimate and idle/single-target attacks do not", () => {
  const { game, enemy } = fixture("pruner", { x: 0, z: 12 });
  enemy.cooldown = 100;
  game.update(1 / 120, { fire: true, aimYaw: 0 });
  assert.equal(game.player.ultimateCharge, 0);
  const second = { ...enemy, id: "chain-two", x: 5, hp: 1000, maxHp: 1000 };
  game.enemies.push(second);
  game.player.shotCooldown = 0;
  game.update(1 / 120, { fire: true, aimYaw: 0 });
  assert.equal(game.player.ultimateCharge, 5);
  game.player.ultimateCharge = 100;
  game.update(1 / 120, { ultimate: true });
  assert.equal(game.player.ultimateTime, 8);
  assert.equal(game.player.ultimateCharge, 0);
  const third = { ...second, id: "distant-chain", x: 14 };
  game.enemies.push(third);
  assert(
    game
      .previewAttack("bolt", rayTo(game, { x: 0, y: 1, z: 0 }))
      .targetIds.includes(third.id),
  );
  game.player.shotCooldown = 0;
  game.update(1 / 120, { fire: true, aimYaw: 0 });
  assert.equal(game.player.ultimateCharge, 0);
  tick(game, 8);
  assert.equal(game.player.ultimateTime, 0);
  assert.equal(game.player.ultimateCharge, 0);
});

test("Ground Loop and Echo combine across sources without recursive echoes and can be disabled", () => {
  const { game, enemy } = fixture("pruner", { x: 3.6, z: 0 });
  enemy.cooldown = 100;
  game.inventory = {
    acquired: ["ground-loop", "echo"],
    equipped: ["ground-loop", "echo"],
  };
  const other = { ...enemy, id: "loop-target", x: -5, hp: 1000, maxHp: 1000 };
  game.enemies.push(other);
  game.update(1 / 120, { dash: true, x: -1 });
  assert(other.hp < other.maxHp);
  tick(game, 0.24);
  let events = game.drainEvents().filter((event) => event.type === "attack");
  assert.equal(
    events.filter((event) => event.attack.kind === "ground-loop" && !event.echo)
      .length,
    1,
  );
  assert.equal(
    events.filter((event) => event.attack.kind === "ground-loop" && event.echo)
      .length,
    1,
  );
  tick(game, 0.5);
  assert.equal(game._echoes.length, 0);
  assert(!game.setItemEnabled("echo", false));
  game.mode = "intermission";
  assert(game.setItemEnabled("echo", false));
  assert(game.setItemEnabled("ground-loop", false));
  game.mode = "playing";
  game.drainEvents();
  game._groundLoop(enemy);
  assert.equal(game.drainEvents().length, 0);
  for (const source of ["player", "conductor", "companion"]) {
    game.inventory.equipped = ["echo"];
    const attack = {
      kind: source === "player" ? "bolt" : source,
      valid: true,
      origin: game._weaponOrigin(),
      point: { x: other.x, y: 1, z: other.z },
      radius: 0,
      blocked: false,
      segments: [
        {
          from: { x: other.x, y: 1, z: other.z },
          to: { x: other.x, y: 1, z: other.z },
        },
      ],
      targetIds: [other.id],
    };
    const before = other.hp;
    game._executeAttack(attack, 10, source);
    tick(game, 0.23);
    events = game.drainEvents().filter((event) => event.type === "attack");
    assert.equal(events.length, 2, source);
    assert.equal(events.filter((event) => event.echo).length, 1, source);
    assert(Math.abs(before - other.hp - 15) < 1e-8, source);
  }
});

test("first collected Shear auto-equips one priming companion and toggles only at intermission", () => {
  const { game, enemy } = fixture("pruner", { x: 3.8, z: 0 });
  enemy.cooldown = 100;
  game._addPickup("shear", game.player.x, game.player.z);
  game.update(1 / 120);
  assert(game.companion?.enabled);
  const companion = game.companion;
  game._addPickup("shear", game.player.x, game.player.z);
  tick(game, 0.5, { aimYaw: -Math.PI / 2 });
  assert.equal(game.companion, companion);
  assert(enemy.primed > 0);
  assert.equal(enemy.maxHp - enemy.hp, 7);
  assert(!game.setCompanionEnabled(false));
  game.mode = "intermission";
  assert(game.setCompanionEnabled(false));
  assert(!game.companion.enabled);
  assert(game.setCompanionEnabled(true));
});

test("all waves admit exact rosters under cap, telegraph entries and require rewards plus continue", () => {
  const game = new OrchardGame().start();
  const expected = [
    [8, 2, 0],
    [14, 4, 0],
    [20, 4, 1],
  ];
  for (let wave = 0; wave < 3; wave++) {
    const roster = [];
    const seen = new Set();
    game.player.hurtTime = 1e6;
    for (let i = 0; i < 6000 && game.mode === "playing"; i++) {
      game.update(1 / 120);
      assert(
        game.enemies.filter((e) => e.state !== "dead" && e.kind !== "pruner")
          .length <= 14,
      );
      assert(
        game.enemies.filter((e) => e.state === "windup" && e.kind !== "pruner")
          .length <= 2,
      );
      for (const enemy of game.enemies)
        if (!seen.has(enemy.id)) {
          seen.add(enemy.id);
          roster.push(enemy.kind);
          assert(
            Math.hypot(enemy.x - game.player.x, enemy.z - game.player.z) > 6,
          );
          game._damage(enemy, 1e6, false, "fixture");
        }
    }
    assert.deepEqual(
      ["snipcart", "spreadleg", "pruner"].map(
        (kind) => roster.filter((value) => value === kind).length,
      ),
      expected[wave],
    );
    assert.equal(game.wave.remaining, 0);
    if (wave < 2) {
      assert.equal(game.mode, "intermission");
      assert(!game.continueWave());
      assert(!game.chooseReward("invalid"));
      const item = wave === 0 ? "ground-loop" : "echo";
      assert(game.chooseReward(item));
      assert(!game.chooseReward(item));
      assert(game.inventory.equipped.includes(item));
      const state = game.snapshot();
      tick(game, 2, { fire: true, dash: true });
      assert.deepEqual(game.snapshot(), state);
      game.pause().resume();
      assert.equal(game.mode, "intermission");
      assert(game.continueWave());
    } else assert.equal(game.mode, "won");
  }
  assert.deepEqual(game.inventory.acquired, ["ground-loop", "echo"]);
  assert(game.drainEvents().some((event) => event.type === "spawn"));
  const won = game.snapshot();
  tick(game, 1);
  assert.deepEqual(game.snapshot(), won);
});

test("boss death alone does not win; packages, final clear, loss and restart use explicit lifecycle", () => {
  const game = new OrchardGame().start();
  clearWave(game);
  assert(game.chooseReward("brace-package"));
  assert.equal(game.player.brace, 2);
  assert(game.continueWave());
  clearWave(game);
  assert(game.chooseReward("shear-package"));
  assert.equal(game.player.shear, 2);
  assert(game.companion.enabled);
  assert(game.continueWave());
  tick(game, 1.3);
  const boss = game.enemies.find((enemy) => enemy.kind === "pruner");
  assert(boss);
  game._damage(boss, 1e6, false, "fixture");
  game.update(1 / 120);
  assert.equal(game.mode, "playing");
  clearWave(game);
  assert.equal(game.mode, "won");
  game.reset().start();
  assert.equal(game.player.shear, 0);
  assert.equal(game.companion, null);
  assert.deepEqual(game.inventory.equipped, []);
  game.player.hp = 1;
  game._hurt(17, { kind: "snipcart" });
  assert.equal(game.mode, "lost");
  const lost = game.snapshot();
  tick(game, 1, { fire: true });
  assert.deepEqual(game.snapshot(), lost);
});

test("wave cap and worker preparation cap hold while queues wait for living enemies", () => {
  const game = new OrchardGame().start();
  game._beginWave(3);
  game.player.hurtTime = 1e6;
  tick(game, 45);
  assert.equal(
    game.enemies.filter((enemy) => enemy.kind !== "pruner").length,
    14,
  );
  assert.equal(
    game.enemies.filter((enemy) => enemy.kind === "pruner").length,
    1,
  );
  assert.equal(game.wave.queued, 10);
  for (let i = 0; i < 1200; i++) {
    game.update(1 / 120);
    assert(
      game.enemies.filter(
        (enemy) => enemy.kind !== "pruner" && enemy.state === "windup",
      ).length <= 2,
    );
  }
});

test("Echo repeats committed space and does not damage an enemy that has left its path", () => {
  const { game, enemy } = fixture("pruner", { x: 0, z: 10 });
  enemy.cooldown = 100;
  game.inventory.equipped = ["echo"];
  game.update(1 / 120, { fire: true, aimYaw: 0 });
  const after = enemy.hp;
  enemy.x = 12;
  tick(game, 0.24);
  assert.equal(enemy.hp, after);
  const repeat = game
    .drainEvents()
    .find((event) => event.type === "attack" && event.echo);
  assert(repeat);
  assert.deepEqual(repeat.attack.targetIds, []);
});

test("conductor activity accelerates during ultimate and ordinary fire can dismantle a full boss", () => {
  const { game, enemy } = fixture("pruner", { x: 0, z: 18 });
  enemy.cooldown = 100;
  game.conductors = [
    { id: "test-conductor", x: 1, y: 0, z: 0, cooldown: 0, flash: 0 },
  ];
  game.player.ultimateTime = 8;
  game.update(1 / 120);
  assert.equal(
    game.conductors[0].cooldown,
    LIGHTNING_CONFIG.conductor.interval /
      LIGHTNING_CONFIG.ultimate.conductorMultiplier,
  );
  game.conductors = [];
  game.player.ultimateTime = 0;
  tick(game, 6, { fire: true, aimYaw: 0 });
  assert.equal(enemy.state, "dead");
  assert.equal(game.player.shear, 0);
  assert.equal(game.companion, null);
  assert.equal(
    game.pickups.filter((pickup) => pickup.kind === "scrap").length,
    4,
  );
});
