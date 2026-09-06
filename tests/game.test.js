import test from "node:test";
import assert from "node:assert/strict";
import {
  Game,
  PATH_LENGTH,
  pointOnPath,
  WALLS,
  CLASSES,
  FLANK_POINT,
  FLANK_DISTANCE,
  validPosition,
  PATH,
} from "../src/game.js";
const advance = (g, s, input) => {
  for (let i = 0; i < Math.ceil(s * 60); i++) g.update(1 / 60, input);
};
test("scenery is absorbed and becomes a working weapon, increasing ball size", () => {
  const g = new Game();
  g.reset();
  const count = g.weapons.length;
  const p = g.pickups[0];
  g.player.x = p.x;
  g.player.z = p.z;
  advance(g, 0.1);
  assert.ok(g.weapons.length > count);
  assert.ok(g.player.radius > 1);
  assert.ok(g.score >= 10);
  assert.ok(g.drainEvents().some((e) => e.type === "collect"));
});
test("outward turrets kill a real marching enemy and award XP", () => {
  const g = new Game();
  g.reset("engineer");
  g.pickups = [];
  g.player.x = -11;
  g.player.z = -7;
  g.wave = 1;
  g.weapons[0].angle = Math.PI;
  g.weapons[1].angle = Math.PI;
  g.spawnEnemy("bug");
  advance(g, 4);
  assert.equal(g.kills, 1);
  assert.ok(g.score >= 25);
  assert.ok(g.xp > 0);
});
test("pause freezes simulation; restart clears run and retains selected class", () => {
  const g = new Game();
  g.reset("warden");
  g.pause();
  advance(g, 10, { x: 1, z: 0 });
  assert.equal(g.time, 0);
  assert.equal(g.player.x, 1);
  g.pause();
  advance(g, 1);
  assert.ok(g.time > 0.9);
  g.score = 5000;
  g.reset();
  assert.equal(g.score, 0);
  assert.equal(g.classId, "warden");
  assert.equal(g.base, 125);
  assert.equal(g.weapons.length, 2);
});
test("enemies completing the entire maze damage the base", () => {
  const g = new Game();
  g.reset();
  g.weapons = [];
  g.wave = 1;
  const e = g.spawnEnemy();
  e.travel = PATH_LENGTH - 0.001;
  advance(g, 0.1);
  assert.equal(g.base, 92);
  assert.equal(g.enemies.length, 0);
  assert.equal(g.kills, 0);
  assert.ok(pointOnPath(PATH_LENGTH + 1).done);
});
test("wave clear scores survival and upgrade resumes next wave", () => {
  const g = new Game();
  g.reset();
  g.pickups = [];
  g.startWave();
  g.spawnLeft = 0;
  advance(g, 0.1);
  assert.equal(g.mode, "upgrade");
  assert.equal(g.survived, 1);
  assert.equal(g.score, 1100);
  assert.equal(new Set(g.options.map((o) => o.id)).size, 3);
  assert.ok(g.chooseUpgrade(0));
  advance(g, 4.1);
  assert.equal(g.wave, 2);
  assert.equal(g.mode, "playing");
});
test("movement is normalized and does not cross walls even during a dash", () => {
  const a = new Game(),
    b = new Game();
  a.reset();
  b.reset();
  a.pickups = [];
  b.pickups = [];
  a.player.x = b.player.x = -1;
  a.player.z = b.player.z = -8;
  advance(a, 0.3, { x: 1, z: 0 });
  advance(b, 0.3, { x: 1, z: 1 });
  assert.ok(
    Math.abs(
      Math.hypot(a.player.x + 1, a.player.z + 8) -
        Math.hypot(b.player.x + 1, b.player.z + 8),
    ) < 0.05,
  );
  const g = new Game();
  g.reset();
  g.pickups = [];
  const wall = WALLS[0];
  g.player.x = wall.x;
  g.player.z = wall.z + wall.h / 2 + 1.2;
  g.dash();
  advance(g, 1, { x: 0, z: -1 });
  assert.ok(g.player.z >= wall.z + wall.h / 2 + g.player.radius * 0.6);
});
test("classes have distinct effective abilities and cooldowns", () => {
  for (const key of Object.keys(CLASSES)) {
    const g = new Game();
    g.reset(key);
    assert.ok(g.ability());
    assert.ok(g.player.abilityCooldown > 0);
    assert.equal(g.ability(), false);
    if (key === "engineer") assert.equal(g.player.overclock, 6);
    if (key === "scavenger") assert.ok(g.collected > 0);
  }
});
test("fatal breaches reach game over and cannot be unpaused", () => {
  const g = new Game();
  g.reset();
  g.base = 1;
  g.weapons = [];
  const e = g.spawnEnemy();
  e.travel = PATH_LENGTH - 0.001;
  advance(g, 0.1);
  assert.equal(g.mode, "gameover");
  assert.equal(g.base, 0);
  assert.equal(g.pause(), false);
});
test("a valid outward target near the entrance fires even with negative urgency", () => {
  const g = new Game();
  g.reset("engineer");
  g.pickups = [];
  g.player.x = -8;
  g.player.z = -7;
  g.weapons = [g.weapons[0]];
  g.weapons[0].angle = Math.PI;
  g.weapons[0].cooldown = 0;
  g.wave = 1;
  g.spawnEnemy("bug");
  g.update(1 / 60);
  assert.ok(g.projectiles.length > 0);
  assert.ok(g.drainEvents().some((e) => e.type === "shot"));
});
test("scrap stays bounded and overflow strengthens a mounted turret", () => {
  const g = new Game();
  g.reset();
  for (let i = 0; i < 50; i++) g.addWeapon("bolt");
  assert.equal(g.weapons.length, 24);
  assert.ok(g.weapons.some((w) => w.power > 1));
  for (let i = 0; i < 50; i++) g.refillScrap(10);
  assert.ok(g.pickups.length <= 34);
});
test("rolling charges turrets while resting discharges, and wall pushing adds no charge", () => {
  const moving = new Game();
  moving.reset();
  moving.pickups = [];
  moving.player.momentum = 0;
  advance(moving, 0.5, { x: 1, z: 0 });
  assert.ok(moving.player.momentum > 0.8);
  advance(moving, 3);
  assert.equal(moving.player.momentum, 0);
  const blocked = new Game();
  blocked.reset();
  blocked.pickups = [];
  blocked.player.x = WALLS[0].x;
  blocked.player.z = WALLS[0].z + WALLS[0].h / 2 + 1.2;
  blocked.player.momentum = 0;
  advance(blocked, 5, { x: 0, z: -1 });
  assert.equal(blocked.player.momentum, 0);
});
test("wave three opens the flank route while heavy enemies take the full maze", () => {
  const g = new Game();
  g.reset();
  g.wave = 3;
  g.spawnLeft = 6;
  const flank = g.spawnEnemy("bug");
  assert.equal(flank.travel, FLANK_DISTANCE);
  assert.deepEqual([flank.x, flank.z], FLANK_POINT);
  const heavy = g.spawnEnemy("boss");
  assert.equal(heavy.travel, 0);
  g.wave = 2;
  assert.equal(g.spawnEnemy("bug").travel, 0);
});

test("grown ball fits the entire maze route and all initial scrap is reachable", () => {
  const g = new Game();
  g.reset();
  for (let travel = 0; travel < PATH_LENGTH; travel += 0.1) {
    const p = pointOnPath(travel);
    assert.ok(
      validPosition(p.x, p.z, 1.75 * 0.98),
      `Blocked path at ${travel}: ${p.x},${p.z}`,
    );
  }
  for (const p of g.pickups) assert.ok(validPosition(p.x, p.z, 0.45));
});

test("elevated projectiles descend to the enemy before impact", () => {
  const g = new Game();
  g.reset("engineer");
  g.pickups = [];
  g.player.x = -8;
  g.player.z = -7;
  g.player.radius = 1.75;
  const w = g.weapons[1];
  w.angle = Math.PI;
  g.weapons[0].cooldown = 100;
  w.cooldown = 0;
  const enemy = g.spawnEnemy("bug");
  const hp = enemy.hp;
  advance(g, 1 / 60);
  const shot = g.projectiles[0];
  assert.ok(shot.y > 2);
  let previousY = shot.y;
  while (enemy.hp === hp && g.time < 1) {
    previousY = shot.y;
    advance(g, 1 / 60);
  }
  assert.ok(enemy.hp < hp);
  assert.ok(previousY < 1.2, `Impact from height ${previousY}`);
});
