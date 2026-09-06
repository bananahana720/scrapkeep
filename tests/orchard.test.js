import test from "node:test";
import assert from "node:assert/strict";
import {
  OrchardGame,
  ARENA,
  ENEMY_CONFIG,
  groundHeight,
} from "../src/orchard/simulation.js";

const tick = (game, seconds, input = {}, dt = 1 / 120) => {
  for (let time = 0; time < seconds - 1e-9; time += dt)
    game.update(Math.min(dt, seconds - time), input);
};
const aim = (from, to) => Math.atan2(to.x - from.x, from.z - to.z);

function fixture(kind = "snipcart", position = { x: 0, z: -4 }) {
  const game = new OrchardGame().start();
  const enemy = game.enemies.find((e) => e.kind === kind);
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

function shoot(game, target, chargeSeconds = 0.05) {
  const input = { aimYaw: aim(game.player, target), fire: true };
  tick(game, chargeSeconds, input);
  game.update(1 / 120, { aimYaw: input.aimYaw, fire: false });
}

test("exports and reset produce a finite, bounded, detached snapshot", () => {
  const game = new OrchardGame({ seed: 19 });
  assert.equal(game.mode, "ready");
  assert.equal(game.enemies.length, 5);
  assert.equal(game.player.y, 1);
  assert.equal(ENEMY_CONFIG.pruner.hp, game.enemies[4].hp);
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

test("aimed pulse releases once, misses off-axis, and full charge increases ordinary damage", () => {
  const { game, enemy } = fixture("pruner", { x: 0, z: 18 });
  enemy.cooldown = 100;
  tick(game, 0.5, { fire: true, aimYaw: Math.PI / 2 });
  assert.equal(game.stats.shots, 0);
  game.update(1 / 120, { aimYaw: Math.PI / 2 });
  assert.equal(game.stats.shots, 1);
  assert.equal(enemy.hp, enemy.maxHp);
  tick(game, 0.3);
  shoot(game, enemy, 0.05);
  const ordinary = enemy.maxHp - enemy.hp;
  assert(ordinary > 10 && ordinary < 13);
  tick(game, 0.3);
  const before = enemy.hp;
  shoot(game, enemy, 1.1);
  assert(Math.abs(before - enemy.hp - 42) < 1e-8);
  assert.equal(game.stats.shots, 3);
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
  const far = { ...enemy, id: "far", z: -5 };
  game.enemies.push(far);
  shoot(game, far);
  assert(enemy.hp < enemy.maxHp);
  assert.equal(far.hp, far.maxHp);
});

test("housing shots and recovery rams reward aim and loosen salvage once per recovery", () => {
  const { game, enemy } = fixture("pruner", { x: 2.7, z: 8 });
  Object.assign(enemy, { state: "recovery", stateTime: 0, yaw: 0 });
  game.update(1 / 120);
  shoot(game, { x: enemy.weakX, z: enemy.weakZ }, 0.02);
  assert.equal(game.stats.counters, 1);
  assert(enemy.maxHp - enemy.hp > 21);
  assert.equal(game.pickups.length, 2);
  tick(game, 0.3);
  shoot(game, { x: enemy.weakX, z: enemy.weakZ }, 0.02);
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

test("optional companion requires collected shear, deploys once, attacks and primes", () => {
  const { game, enemy } = fixture("pruner", { x: 3.8, z: 0 });
  enemy.cooldown = 100;
  game.update(1 / 120, { deploy: true });
  assert.equal(game.companion, null);
  game.pickups = [
    {
      id: "link",
      kind: "shear",
      x: game.player.x,
      y: 0,
      z: 0,
      collected: false,
    },
  ];
  game.update(1 / 120);
  game.update(1 / 120, { deploy: true, aimYaw: -Math.PI / 2 });
  assert(game.companion?.active);
  tick(game, 0.5, { aimYaw: -Math.PI / 2 });
  assert.equal(enemy.maxHp - enemy.hp, 7);
  assert(enemy.primed > 0);
  const companion = game.companion;
  game.update(1 / 120, { deploy: true });
  assert.equal(game.companion, companion);
  const before = enemy.hp;
  shoot(game, enemy, 0.02);
  assert(before - enemy.hp > 13);
  assert.equal(enemy.primed, 0);
  assert(game.drainEvents().some((e) => e.type === "companion"));
});

test("boss defeat wins without worker kills, damage loses, and terminal modes freeze", () => {
  const game = new OrchardGame().start();
  const boss = game.enemies.find((e) => e.kind === "pruner");
  Object.assign(game.player, { x: 0, z: -20, y: 3 });
  boss.hp = 1;
  shoot(game, boss, 0.02);
  assert.equal(game.mode, "won");
  assert(
    game.enemies
      .filter((e) => e.kind !== "pruner")
      .every((e) => e.state !== "dead"),
  );
  assert(game.drainEvents().some((e) => e.type === "win"));
  const won = game.snapshot();
  tick(game, 3, { fire: true, dash: true, x: 1 });
  assert.deepEqual(game.snapshot(), won);
  game.reset().start();
  assert.equal(game.mode, "playing");
  assert.equal(game.player.hp, 100);

  const loss = fixture();
  loss.game.player.hp = 1;
  tick(loss.game, 2);
  assert.equal(loss.game.mode, "lost");
  assert.equal(loss.game.player.hp, 0);
  assert(loss.game.drainEvents().some((e) => e.type === "lose"));
  const lost = loss.game.snapshot();
  tick(loss.game, 1, { x: 1 });
  assert.deepEqual(loss.game.snapshot(), lost);
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
  assert.equal(game.stats.shots, 0);
  assert(game.time > paused.time);
  game.reset();
  assert.equal(game.mode, "ready");
  assert.equal(game.time, 0);
});

test("30 Hz and 120 Hz input schedules give equivalent state and deterministic drops", () => {
  function run(dt) {
    const game = new OrchardGame({ seed: 172 }).start();
    game.enemies = [];
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

test("worker dismantling drops its recognizable mechanism and ordinary shots can finish a full boss", () => {
  for (const kind of ["snipcart", "spreadleg"]) {
    const { game, enemy } = fixture(kind, { x: 0, z: 9 });
    enemy.hp = 1;
    shoot(game, enemy);
    assert.equal(enemy.state, "dead");
    assert.equal(game.pickups.filter((p) => p.kind === "scrap").length, 4);
    assert.equal(
      game.pickups.filter(
        (p) => p.kind === (kind === "snipcart" ? "shear" : "brace"),
      ).length,
      1,
    );
    assert.equal(game.pickups.filter((p) => p.kind === "heart").length, 1);
    assert.equal(game.hazards.length, 0);
  }
  const { game, enemy } = fixture("pruner", { x: 0, z: 18 });
  for (let i = 0; i < 16 && game.mode === "playing"; i++)
    shoot(game, enemy, 1.1);
  assert.equal(game.mode, "won");
  assert.equal(game.player.shear, 0);
  assert.equal(game.player.brace, 0);
  assert.equal(game.companion, null);
  assert.equal(game.stats.counters, 0);
  assert(
    game.stats.damageTaken > 0,
    "standing at range now takes announced offcut damage",
  );
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
