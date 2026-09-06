export const ARENA = Object.freeze({
  minX: -19,
  maxX: 19,
  minZ: -37,
  maxZ: 27,
});

export const ENEMY_CONFIG = Object.freeze({
  snipcart: Object.freeze({
    hp: 90,
    radius: 1.3,
    wake: 12,
    speed: 1.7,
    reach: 3.11,
    width: 0.65,
    windup: 1.15,
    active: 0.48,
    recovery: 1.85,
    damage: 17,
    spacing: 3.6,
  }),
  spreadleg: Object.freeze({
    hp: 115,
    radius: 1.45,
    wake: 13,
    speed: 1.4,
    reach: 2.55,
    width: 0.94,
    windup: 1.3,
    active: 0.7,
    recovery: 2,
    damage: 20,
    spacing: 2.8,
  }),
  pruner: Object.freeze({
    hp: 640,
    radius: 2.5,
    wake: 22,
    speed: 0,
    reach: 6.51,
    width: 1.25,
    windup: 1.75,
    active: 0.8,
    recovery: 2.7,
    damage: 27,
    spacing: 7.2,
  }),
});

const STEP = 1 / 120;
const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));
const finite = (n, fallback = 0) => (Number.isFinite(n) ? n : fallback);
const distance = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const facing = (yaw) => ({ x: Math.sin(yaw), z: -Math.cos(yaw) });
const yawTo = (a, b) => Math.atan2(b.x - a.x, a.z - b.z);

export function groundHeight(x, z) {
  return clamp((-finite(z) - 14) / 9, 0, 1) * 2.5;
}

function pointSegmentDistance(x, z, s) {
  const dx = s.x2 - s.x1;
  const dz = s.z2 - s.z1;
  const t = clamp(
    ((x - s.x1) * dx + (z - s.z1) * dz) / (dx * dx + dz * dz || 1),
    0,
    1,
  );
  return Math.hypot(x - s.x1 - dx * t, z - s.z1 - dz * t);
}

// A segment is a world-space capsule from (x1,z1) to (x2,z2), with a round radius.
// The renderer draws these exact capsules. Collision expands them by player.radius.
// Windup previewSegments contains the same capsules sampled over the complete stroke.
// Active segments are the damaging tool position at the current committed phase.
function toolSegments(enemy, phase, preparing = false) {
  const c = ENEMY_CONFIG[enemy.kind];
  const segments = [];
  const world = (x, z) => ({
    x: enemy.x + Math.cos(enemy.yaw) * x - Math.sin(enemy.yaw) * z,
    z: enemy.z + Math.sin(enemy.yaw) * x + Math.cos(enemy.yaw) * z,
  });
  const capsule = (start, end, radius) => {
    const a = world(start.x, start.z);
    const b = world(end.x, end.z);
    return { x1: a.x, z1: a.z, x2: b.x, z2: b.z, radius };
  };
  for (const side of [-1, 1]) {
    if (enemy.kind === "spreadleg") {
      const angle = 0.2 + (preparing ? 0 : phase * 0.83);
      const x =
        side * (0.37 + 1.5 * Math.sin(angle) + 1.4 * Math.sin(angle * 0.3));
      segments.push(capsule({ x, z: -0.185 }, { x, z: -0.155 }, 0.47));
    } else if (enemy.kind === "snipcart") {
      const angle =
        side * (preparing ? 0.12 + 0.46 * phase : 0.58 * (1 - phase));
      segments.push(
        capsule(
          { x: 0, z: -0.73 },
          { x: -Math.sin(angle) * 2.376, z: -0.73 - Math.cos(angle) * 2.376 },
          c.width / 2,
        ),
      );
    } else {
      const sweep = preparing ? -0.67 * phase : -0.67 + 1.34 * phase;
      const jaw = side * (preparing ? 0.12 + 0.23 * phase : 0.35 * (1 - phase));
      const rotateArm = (x, z) => ({
        x: Math.cos(sweep) * x + Math.sin(sweep) * z,
        z: 0.55 - Math.sin(sweep) * x + Math.cos(sweep) * z,
      });
      segments.push(
        capsule(
          rotateArm(0, -2.2),
          rotateArm(-Math.sin(jaw) * 4.86, -2.2 - Math.cos(jaw) * 4.86),
          c.width / 2,
        ),
      );
    }
  }
  return segments;
}

export class OrchardGame {
  constructor({ seed = 42 } = {}) {
    this.seed = finite(seed, 42) >>> 0;
    this.reset();
  }

  reset() {
    this.mode = "ready";
    this.time = 0;
    this.player = {
      x: 0,
      y: 1,
      z: 21,
      vx: 0,
      vz: 0,
      radius: 1,
      yaw: 0,
      hp: 100,
      maxHp: 100,
      dashCooldown: 0,
      dashTime: 0,
      charge: 0,
      scrap: 0,
      shear: 0,
      brace: 0,
      hurtTime: 0,
      shotCooldown: 0,
    };
    this.enemies = [
      this._makeEnemy("snipcart", -4, 8, 0.25),
      this._makeEnemy("spreadleg", 6, -4, 0.8),
      this._makeEnemy("snipcart", -8, -12, 0.9),
      this._makeEnemy("spreadleg", 8, -14, 1.3),
      this._makeEnemy("pruner", 0, -29, 0.5),
    ];
    this.enemies.forEach((enemy, i) => {
      enemy.id = `enemy-${i + 1}`;
    });
    this.pickups = [];
    for (const [x, z] of [
      [-1, 18],
      [-2, 15],
      [-3, 12],
      [11, 6],
      [13, 1],
      [13, -6],
      [-13, -9],
      [-13, -16],
      [-10, -22],
    ]) {
      this._addPickup("scrap", x, z);
    }
    this.hazards = [];
    this._offcuts = [];
    this._nextOffcutId = 0;
    this.companion = null;
    this.stats = {
      shots: 0,
      hits: 0,
      counters: 0,
      collected: 0,
      damageTaken: 0,
      damageDealt: 0,
    };
    this._events = [];
    this._accumulator = 0;
    this._held = { fire: false, dash: false, deploy: false };
    this._pending = { release: false, dash: false, deploy: false };
    this._ramHits = new Set();
    this._workerGap = 0;
    this._rng = this.seed || 1;
    return this;
  }

  _makeEnemy(kind, x, z, cooldown) {
    const c = ENEMY_CONFIG[kind];
    return {
      id: "",
      kind,
      x,
      y: groundHeight(x, z),
      z,
      yaw: Math.PI,
      radius: c.radius,
      hp: c.hp,
      maxHp: c.hp,
      state: "idle",
      phase: 0,
      active: false,
      weakX: x - c.radius,
      weakZ: z,
      hitFlash: 0,
      attackId: 0,
      stateTime: 0,
      cooldown,
      struck: false,
      primed: 0,
      counteredAttack: -1,
      attackStyle: "sweep",
      tossReleased: false,
    };
  }

  start() {
    if (this.mode === "ready") this.mode = "playing";
    return this;
  }

  pause() {
    if (this.mode === "playing") {
      this.mode = "paused";
      this._clearInput();
    }
    return this;
  }

  resume() {
    if (this.mode === "paused") this.mode = "playing";
    return this;
  }

  _clearInput() {
    this._held = { fire: false, dash: false, deploy: false };
    this._pending = { release: false, dash: false, deploy: false };
    this.player.charge = 0;
    this._accumulator = 0;
  }

  update(dt, input = {}) {
    if (this.mode !== "playing" || !Number.isFinite(dt) || dt <= 0) return;
    input = input && typeof input === "object" ? input : {};
    let x = clamp(finite(input.x), -1, 1);
    let z = clamp(finite(input.z), -1, 1);
    const length = Math.hypot(x, z);
    if (length > 1) {
      x /= length;
      z /= length;
    }
    const next = {
      x,
      z,
      aimYaw: finite(input.aimYaw, this.player.yaw),
      fire: !!input.fire,
      brake: !!input.brake,
    };
    this._pending.release ||= this._held.fire && !next.fire;
    this._pending.dash ||= !!input.dash && !this._held.dash;
    this._pending.deploy ||= !!input.deploy && !this._held.deploy;
    this._held = {
      fire: next.fire,
      dash: !!input.dash,
      deploy: !!input.deploy,
    };
    // Discard suspended-tab time instead of advancing unseen enemy attacks.
    this._accumulator += Math.min(dt, 0.25);
    while (this._accumulator + 1e-10 >= STEP && this.mode === "playing") {
      this._accumulator -= STEP;
      this._step(STEP, next);
    }
  }

  _step(dt, input) {
    this.time += dt;
    const p = this.player;
    for (const key of ["dashCooldown", "dashTime", "hurtTime", "shotCooldown"])
      p[key] = Math.max(0, p[key] - dt);
    this._workerGap = Math.max(0, this._workerGap - dt);
    p.yaw = input.aimYaw;
    if (this._pending.dash && p.dashCooldown <= 0) {
      const length = Math.hypot(input.x, input.z);
      const dir =
        length > 0.1
          ? { x: input.x / length, z: input.z / length }
          : facing(p.yaw);
      p.vx = dir.x * 19;
      p.vz = dir.z * 19;
      p.dashTime = 0.24;
      p.dashCooldown = Math.max(0.85, 1.45 - p.brace * 0.22);
      this._ramHits.clear();
      this._event("ram", p, { text: "Burst", kind: "burst" });
    }
    if (this._pending.deploy && p.shear > 0 && !this.companion) {
      this.companion = {
        x: p.x,
        y: p.y,
        z: p.z,
        yaw: p.yaw,
        active: true,
        cooldown: 0.25,
        flash: 0,
      };
      this._event("deploy", p, { text: "Shear buddy deployed" });
    }
    if (this._pending.release) this._shoot();
    this._pending = { release: false, dash: false, deploy: false };
    if (this.mode !== "playing") return;
    if (input.fire) p.charge = Math.min(1, p.charge + dt / 1.1);
    else p.charge = 0;

    if (p.dashTime <= 0) {
      const speed = input.brake ? 2.2 : 7.4;
      const targetX = input.x * speed;
      const targetZ = input.z * speed;
      const dx = targetX - p.vx;
      const dz = targetZ - p.vz;
      const delta = Math.hypot(dx, dz);
      const acceleration = (input.brake ? 48 : 25) + p.brace * 4;
      const scale = delta > 0 ? Math.min(1, (acceleration * dt) / delta) : 0;
      p.vx += dx * scale;
      p.vz += dz * scale;
    }
    p.x += p.vx * dt;
    p.z += p.vz * dt;
    this._boundPlayer();
    this._updateEnemies(dt);
    if (this.mode !== "playing") return;
    this._updateOffcuts(dt);
    if (this.mode !== "playing") return;
    this._collect();
    this._updateCompanion(dt);
    p.y = groundHeight(p.x, p.z) + p.radius;
  }

  _boundPlayer() {
    const p = this.player;
    const x = clamp(p.x, ARENA.minX + p.radius, ARENA.maxX - p.radius);
    const z = clamp(p.z, ARENA.minZ + p.radius, ARENA.maxZ - p.radius);
    if (x !== p.x) p.vx = 0;
    if (z !== p.z) p.vz = 0;
    p.x = x;
    p.z = z;
    p.y = groundHeight(x, z) + p.radius;
  }

  _transition(enemy, state) {
    enemy.state = state;
    enemy.stateTime = 0;
    enemy.phase = 0;
    if (state === "windup") {
      enemy.attackId++;
      enemy.struck = false;
      enemy.tossReleased = false;
      enemy.yaw = yawTo(enemy, this.player);
      this._event("phase", enemy, {
        kind: enemy.kind,
        text:
          enemy.attackStyle === "toss"
            ? "Offcut roll incoming"
            : enemy.kind === "spreadleg"
              ? "Feet sweep outward"
              : "Jaws closing inward",
      });
    }
    if (state === "recovery")
      this._event("phase", enemy, {
        kind: enemy.kind,
        text: "Housing exposed",
      });
  }

  _updateEnemies(dt) {
    this.hazards = [];
    for (const enemy of this.enemies) {
      if (enemy.state === "dead") continue;
      const c = ENEMY_CONFIG[enemy.kind];
      enemy.hitFlash = Math.max(0, enemy.hitFlash - dt);
      enemy.primed = Math.max(0, enemy.primed - dt);
      enemy.cooldown = Math.max(0, enemy.cooldown - dt);
      if (!enemy.active && distance(enemy, this.player) <= c.wake) {
        enemy.active = true;
        this._transition(enemy, "approach");
      }
      if (!enemy.active) continue;
      if (enemy.state === "idle") this._transition(enemy, "approach");
      if (enemy.state === "approach") {
        const gap = distance(enemy, this.player);
        enemy.yaw = yawTo(enemy, this.player);
        if (gap > c.spacing && c.speed) {
          const dir = facing(enemy.yaw);
          enemy.x = clamp(enemy.x + dir.x * c.speed * dt, -13, 13);
          enemy.z = clamp(enemy.z + dir.z * c.speed * dt, -23, 16);
        }
        const workerReady =
          enemy.kind === "pruner" ||
          (this._workerGap <= 0 &&
            !this.enemies.some(
              (other) =>
                other !== enemy &&
                other.kind !== "pruner" &&
                other.state === "windup",
            ));
        const attackReach =
          enemy.kind === "pruner" ? 30 : c.reach + this.player.radius + 0.5;
        if (gap <= attackReach && enemy.cooldown <= 0 && workerReady) {
          enemy.attackStyle =
            enemy.kind === "pruner" && gap > c.reach + this.player.radius + 0.5
              ? "toss"
              : "sweep";
          this._transition(enemy, "windup");
          if (enemy.kind !== "pruner") this._workerGap = 0.8;
        }
      } else {
        enemy.stateTime += dt;
        enemy.phase = clamp(enemy.stateTime / c[enemy.state], 0, 1);
        if (enemy.phase >= 1 - 1e-9) {
          if (enemy.state === "windup") this._transition(enemy, "active");
          else if (enemy.state === "active")
            this._transition(enemy, "recovery");
          else if (enemy.state === "recovery") {
            this._transition(enemy, "approach");
            enemy.cooldown = 0.35;
          }
        }
      }
      enemy.y = groundHeight(enemy.x, enemy.z);
      const side = facing(enemy.yaw + Math.PI / 2);
      enemy.weakX = enemy.x + side.x * (enemy.radius + 0.2);
      enemy.weakZ = enemy.z + side.z * (enemy.radius + 0.2);
      if (
        enemy.attackStyle === "toss" &&
        enemy.state === "active" &&
        enemy.phase >= 1 / 3 &&
        !enemy.tossReleased
      ) {
        enemy.tossReleased = true;
        this._releaseOffcut(enemy);
      }
      if (enemy.attackStyle === "toss" && enemy.state === "windup") {
        const path = this._offcutPath(enemy);
        this.hazards.push({
          id: `${enemy.id}-${enemy.attackId}`,
          kind: "offcut",
          state: "windup",
          x: path.x1,
          z: path.z1,
          yaw: enemy.yaw,
          range: 31.5,
          width: 1.3,
          radius: 0.65,
          bodyRadius: 0.65,
          phase: enemy.phase,
          segments: [path],
          previewSegments: [path],
        });
      } else if (
        enemy.attackStyle !== "toss" &&
        (enemy.state === "windup" || enemy.state === "active")
      ) {
        const hazard = {
          id: `${enemy.id}-${enemy.attackId}`,
          kind:
            enemy.kind === "spreadleg"
              ? "spread"
              : enemy.kind === "pruner"
                ? "sweep"
                : "cut",
          x: enemy.x,
          z: enemy.z,
          yaw: enemy.yaw,
          range: c.reach,
          width: c.width,
          phase: enemy.phase,
          state: enemy.state,
          segments: toolSegments(enemy, enemy.phase, enemy.state === "windup"),
        };
        if (enemy.state === "windup") {
          hazard.previewSegments = [];
          for (let sample = 0; sample <= 16; sample++)
            hazard.previewSegments.push(...toolSegments(enemy, sample / 16));
        }
        this.hazards.push(hazard);
        if (
          enemy.state === "active" &&
          !enemy.struck &&
          hazard.segments.some(
            (segment) =>
              pointSegmentDistance(this.player.x, this.player.z, segment) <=
              segment.radius + this.player.radius,
          )
        ) {
          enemy.struck = true;
          this._hurt(c.damage, enemy);
        }
      }
      if (this.mode !== "playing") break;
      this._bodyContact(enemy);
      if (this.mode !== "playing") break;
    }
  }

  _offcutPath(enemy) {
    const dir = facing(enemy.yaw);
    const x1 = enemy.x + dir.x * 6.51;
    const z1 = enemy.z + dir.z * 6.51;
    return {
      x1,
      z1,
      x2: x1 + dir.x * 31.5,
      z2: z1 + dir.z * 31.5,
      radius: 0.65,
    };
  }

  _releaseOffcut(enemy) {
    if (this._offcuts.length >= 4) return;
    const path = this._offcutPath(enemy);
    const dir = facing(enemy.yaw);
    const offcut = {
      id: `offcut-${++this._nextOffcutId}`,
      x: path.x1,
      z: path.z1,
      yaw: enemy.yaw,
      vx: dir.x * 9,
      vz: dir.z * 9,
      age: 0,
    };
    this._offcuts.push(offcut);
    this._event(
      "toss",
      { ...offcut, y: groundHeight(offcut.x, offcut.z) + 0.65 },
      {
        kind: "offcut",
        targetX: path.x2,
        targetY: groundHeight(path.x2, path.z2) + 0.65,
        targetZ: path.z2,
        text: "Rolling offcut",
      },
    );
  }

  _updateOffcuts(dt) {
    const remaining = [];
    for (const offcut of this._offcuts) {
      const segment = {
        x1: offcut.x,
        z1: offcut.z,
        x2: offcut.x + offcut.vx * dt,
        z2: offcut.z + offcut.vz * dt,
        radius: 0.65,
      };
      offcut.x = segment.x2;
      offcut.z = segment.z2;
      offcut.age += dt;
      if (
        offcut.age >= 3.5 ||
        offcut.x < ARENA.minX - 2 ||
        offcut.x > ARENA.maxX + 2 ||
        offcut.z < ARENA.minZ - 2 ||
        offcut.z > ARENA.maxZ + 2
      )
        continue;
      if (
        pointSegmentDistance(this.player.x, this.player.z, segment) <=
        this.player.radius + segment.radius
      ) {
        this._hurt(18, { kind: "offcut" });
        if (this.mode !== "playing") break;
        continue;
      }
      remaining.push(offcut);
      // The short swept capsule prevents tunneling; x/z remains the visible chunk center.
      this.hazards.push({
        id: offcut.id,
        kind: "offcut",
        state: "active",
        x: offcut.x,
        y: groundHeight(offcut.x, offcut.z),
        z: offcut.z,
        yaw: offcut.yaw,
        range: 31.5,
        width: 1.3,
        radius: 0.65,
        bodyRadius: 0.65,
        phase: offcut.age / 3.5,
        segments: [segment],
      });
    }
    this._offcuts = remaining;
  }

  _bodyContact(enemy) {
    const p = this.player;
    const gap = distance(p, enemy);
    const reach = p.radius + enemy.radius;
    if (gap >= reach) return;
    if (p.dashTime > 0 && !this._ramHits.has(enemy.id)) {
      this._ramHits.add(enemy.id);
      const weakGap = Math.hypot(p.x - enemy.weakX, p.z - enemy.weakZ);
      const counter = enemy.state === "recovery" && weakGap < p.radius + 1.9;
      this._damage(enemy, 23 + Math.min(p.shear, 3) * 9, counter, "ram");
      this._event("ram", p, {
        kind: "impact",
        targetX: enemy.x,
        targetY: enemy.y,
        targetZ: enemy.z,
      });
      if (enemy.state === "dead") return;
    }
    const dx = gap > 0.001 ? (p.x - enemy.x) / gap : 1;
    const dz = gap > 0.001 ? (p.z - enemy.z) / gap : 0;
    p.x = enemy.x + dx * reach;
    p.z = enemy.z + dz * reach;
    const inward = p.vx * dx + p.vz * dz;
    if (inward < 0) {
      p.vx -= inward * dx;
      p.vz -= inward * dz;
    }
    this._boundPlayer();
  }

  _shoot() {
    const p = this.player;
    const charge = p.charge;
    p.charge = 0;
    if (p.shotCooldown > 0) return;
    p.shotCooldown = 0.28;
    this.stats.shots++;
    const dir = facing(p.yaw);
    let selected = null;
    let nearest = 27;
    for (const enemy of this.enemies) {
      if (enemy.state === "dead") continue;
      const dx = enemy.x - p.x;
      const dz = enemy.z - p.z;
      const along = dx * dir.x + dz * dir.z;
      const across = Math.abs(dx * dir.z - dz * dir.x);
      const r = enemy.radius + 0.3;
      if (along < 0 || across > r) continue;
      const entry = Math.max(0, along - Math.sqrt(r * r - across * across));
      if (entry < nearest) {
        nearest = entry;
        selected = enemy;
      }
    }
    const target = selected || {
      x: p.x + dir.x * 27,
      y: p.y,
      z: p.z + dir.z * 27,
    };
    this._event("shoot", p, {
      targetX: target.x,
      targetY: target.y + 1,
      targetZ: target.z,
      amount: charge,
    });
    if (selected) {
      const weakAcross = Math.abs(
        (selected.weakX - p.x) * dir.z - (selected.weakZ - p.z) * dir.x,
      );
      const counter = selected.state === "recovery" && weakAcross <= 0.9;
      this._damage(selected, 10 + 32 * charge, counter, "shot");
    }
  }

  _damage(enemy, amount, counter, source) {
    if (enemy.state === "dead") return;
    enemy.active = true;
    const primed = enemy.primed > 0 && source !== "companion";
    const damage = amount * (counter ? 2.1 : 1) * (primed ? 1.3 : 1);
    if (primed) enemy.primed = 0;
    const dealt = Math.min(enemy.hp, damage);
    enemy.hp = Math.max(0, enemy.hp - damage);
    enemy.hitFlash = 0.2;
    this.stats.hits++;
    this.stats.damageDealt += dealt;
    if (counter) {
      this.stats.counters++;
      if (enemy.counteredAttack !== enemy.attackId) {
        enemy.counteredAttack = enemy.attackId;
        this._addPickup("scrap", enemy.weakX, enemy.weakZ);
        if (enemy.kind === "pruner")
          this._addPickup("heart", enemy.weakX + 0.7, enemy.weakZ);
      }
    }
    this._event("hit", enemy, {
      kind: source,
      amount: dealt,
      text: counter ? "Housing counter!" : primed ? "Primed hit!" : "",
    });
    if (enemy.hp <= 0) {
      enemy.state = "dead";
      enemy.phase = 1;
      enemy.active = false;
      this.hazards = this.hazards.filter(
        (hazard) => !hazard.id.startsWith(`${enemy.id}-`),
      );
      for (let i = 0; i < 4; i++) {
        const angle = this._random() * Math.PI * 2;
        this._addPickup(
          "scrap",
          enemy.x + Math.cos(angle) * 1.3,
          enemy.z + Math.sin(angle) * 1.3,
        );
      }
      this._addPickup(
        enemy.kind === "spreadleg" ? "brace" : "shear",
        enemy.x,
        enemy.z,
      );
      this._addPickup("heart", enemy.x + 1, enemy.z);
      if (enemy.kind === "pruner") {
        this.mode = "won";
        this.hazards = [];
        this._event("win", enemy, { text: "Grand Pruner dismantled" });
      }
    }
  }

  _hurt(amount, enemy) {
    const p = this.player;
    if (p.hurtTime > 0 || this.mode !== "playing") return;
    const damage = amount * (1 - Math.min(0.3, p.brace * 0.15));
    const dealt = Math.min(p.hp, damage);
    p.hp = Math.max(0, p.hp - damage);
    p.hurtTime = 1.05;
    this.stats.damageTaken += dealt;
    this._event("hurt", p, {
      amount: dealt,
      kind: enemy.kind,
      text: "Tool strike",
    });
    if (p.hp <= 0) {
      this.mode = "lost";
      this.hazards = [];
      this._event("lose", p, { text: "Machine stalled" });
    }
  }

  _random() {
    this._rng = (Math.imul(1664525, this._rng) + 1013904223) >>> 0;
    return this._rng / 4294967296;
  }

  _addPickup(kind, x, z) {
    if (!this.pickups) this.pickups = [];
    this.pickups.push({
      id: `pickup-${this.pickups.length + 1}`,
      x,
      y: groundHeight(x, z),
      z,
      kind,
      collected: false,
    });
  }

  _collect() {
    const p = this.player;
    for (const pickup of this.pickups) {
      if (pickup.collected || distance(p, pickup) > p.radius + 0.65) continue;
      pickup.collected = true;
      this.stats.collected++;
      if (pickup.kind === "scrap") p.scrap++;
      if (pickup.kind === "shear") p.shear++;
      if (pickup.kind === "brace") p.brace++;
      if (pickup.kind === "heart") p.hp = Math.min(p.maxHp, p.hp + 16);
      p.radius = Math.min(
        1.65,
        1 + p.scrap * 0.022 + p.shear * 0.045 + p.brace * 0.045,
      );
      const labels = {
        scrap: "Scrap fitted",
        shear: "Shear linkage: stronger ram + buddy",
        brace: "Brace: quicker burst + protection",
        heart: "Repair +16",
      };
      this._event("collect", pickup, {
        kind: pickup.kind,
        amount: 1,
        text: labels[pickup.kind],
      });
    }
    this._boundPlayer();
  }

  _updateCompanion(dt) {
    const buddy = this.companion;
    if (!buddy || !buddy.active) return;
    buddy.cooldown = Math.max(0, buddy.cooldown - dt);
    buddy.flash = Math.max(0, buddy.flash - dt);
    const p = this.player;
    const dir = facing(p.yaw);
    const target = {
      x: p.x - dir.x * 0.6 + Math.cos(p.yaw) * 1.8,
      z: p.z - dir.z * 0.6 + Math.sin(p.yaw) * 1.8,
    };
    const follow = 1 - Math.exp(-4 * dt);
    buddy.x += (target.x - buddy.x) * follow;
    buddy.z += (target.z - buddy.z) * follow;
    buddy.y = groundHeight(buddy.x, buddy.z);
    const enemy = this.enemies
      .filter(
        (candidate) =>
          candidate.state !== "dead" && distance(candidate, buddy) < 4.8,
      )
      .sort((a, b) => distance(a, buddy) - distance(b, buddy))[0];
    buddy.yaw = enemy ? yawTo(buddy, enemy) : p.yaw;
    if (enemy && buddy.cooldown <= 0) {
      buddy.cooldown = 2.5;
      buddy.flash = 0.24;
      this._damage(enemy, 7, false, "companion");
      enemy.primed = 3;
      this._event("companion", buddy, {
        targetX: enemy.x,
        targetY: enemy.y + 0.5,
        targetZ: enemy.z,
        text: "Shear buddy primed a housing",
      });
    }
  }

  _event(type, position, data = {}) {
    this._events.push({
      type,
      x: position.x,
      y: position.y || 0,
      z: position.z,
      ...data,
    });
  }

  drainEvents() {
    const events = this._events;
    this._events = [];
    return events;
  }

  snapshot() {
    return JSON.parse(
      JSON.stringify({
        mode: this.mode,
        time: this.time,
        player: this.player,
        enemies: this.enemies,
        pickups: this.pickups,
        hazards: this.hazards,
        companion: this.companion,
        stats: this.stats,
      }),
    );
  }
}
