export const ARENA = Object.freeze({
  minX: -19,
  maxX: 19,
  minZ: -37,
  maxZ: 27,
});

export const ENEMY_CONFIG = Object.freeze({
  snipcart: Object.freeze({
    hp: 90,
    bodyHeight: 1.9,
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
    bodyHeight: 3.8,
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
    bodyHeight: 4.5,
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

export const LIGHTNING_CONFIG = Object.freeze({
  bolt: Object.freeze({
    damage: 24,
    interval: 0.22,
    range: 32,
    chainRange: 6,
    chainTargets: 3,
  }),
  strike: Object.freeze({ damage: 70, radius: 4.8, range: 30, cooldown: 4.5 }),
  conductor: Object.freeze({
    damage: 18,
    radius: 7,
    range: 24,
    cooldown: 3,
    interval: 1.1,
    max: 2,
    linkRadius: 0.5,
    linkHalfHeight: 1,
  }),
  ultimate: Object.freeze({
    duration: 8,
    chainMultiplier: 1.8,
    conductorMultiplier: 2.5,
  }),
  movement: Object.freeze({
    jumpSpeed: 10.5,
    airJumpSpeed: 9.5,
    gravity: 25,
    ramDamage: 23,
    shearRamBonus: 9,
    maxShearBonus: 3,
    ramCooldown: 1.45,
    braceCooldownBonus: 0.22,
    minRamCooldown: 0.85,
    braceProtection: 0.15,
    maxBraceProtection: 0.3,
  }),
  companion: Object.freeze({ damage: 7, interval: 2.5, range: 4.8 }),
});
export const ITEM_CONFIG = Object.freeze({
  "ground-loop": Object.freeze({
    id: "ground-loop",
    name: "Ground Loop",
    description:
      "Body impacts chain lightning to nearby enemies. Applies to rams and landing rebounds; Echo can repeat this lightning.",
  }),
  echo: Object.freeze({
    id: "echo",
    name: "Echo",
    description:
      "Player lightning, Ground Loop, conductor and companion attacks repeat once after 0.22 seconds at 50% strength. Echoes cannot repeat.",
  }),
});
const WAVES = [
  [8, 2, 0],
  [14, 4, 0],
  [20, 4, 1],
];
const ENTRY_POINTS = [
  { x: -14, z: 13 },
  { x: 14, z: 13 },
  { x: -14, z: -25 },
  { x: 14, z: -25 },
];
const copy = (value) => JSON.parse(JSON.stringify(value));
const length3 = (a, b) => Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);
const unit = (v) => {
  const length = Math.hypot(v.x, v.y, v.z) || 1;
  return { x: v.x / length, y: v.y / length, z: v.z / length };
};
const towards = (a, b) => unit({ x: b.x - a.x, y: b.y - a.y, z: b.z - a.z });
const along = (o, d, t) => ({
  x: o.x + d.x * t,
  y: o.y + d.y * t,
  z: o.z + d.z * t,
});
const inside = (p) =>
  p.x >= ARENA.minX && p.x <= ARENA.maxX && p.z >= ARENA.minZ && p.z <= ARENA.maxZ;
const center = (enemy) => ({
  x: enemy.x,
  y: enemy.y + enemy.bodyHeight / 2,
  z: enemy.z,
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
  const t = clamp(((x - s.x1) * dx + (z - s.z1) * dz) / (dx * dx + dz * dz || 1), 0, 1);
  return Math.hypot(x - s.x1 - dx * t, z - s.z1 - dz * t);
}

export function toolSegments(enemy, phase, preparing = false) {
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
      const x = side * (0.37 + 1.5 * Math.sin(angle) + 1.4 * Math.sin(angle * 0.3));
      segments.push(capsule({ x, z: -0.185 }, { x, z: -0.155 }, 0.47));
    } else if (enemy.kind === "snipcart") {
      const angle = side * (preparing ? 0.12 + 0.46 * phase : 0.58 * (1 - phase));
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
      vy: 0,
      grounded: true,
      airJumps: 1,
      landingImpact: 0,
      strikeCooldown: 0,
      conductorCooldown: 0,
      ultimateCharge: 0,
      ultimateTime: 0,
    };
    this.enemies = [];
    this.wave = {
      index: 1,
      total: 3,
      remaining: 10,
      queued: 10,
      active: 0,
      cleared: 0,
      rewardChosen: false,
      entries: [],
    };
    this.rewards = [];
    this.inventory = { acquired: [], equipped: [] };
    this.conductors = [];
    this.conductorLinks = [];
    this.targeting = null;
    this.preparedAbility = null;
    this._waveQueue = [];
    this._entryCooldown = 0;
    this._nextEnemyId = 0;
    this._nextConductorId = 0;
    this._echoes = [];
    this._jumpBuffer = 0;
    this._landingHits = new Set();
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
    this._held = {};
    this._pending = {};
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
      bodyHeight: c.bodyHeight,
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
    if (this.mode === "ready") {
      this.mode = "playing";
      this._beginWave(1);
    }
    return this;
  }

  pause() {
    if (this.mode === "playing" || this.mode === "intermission") {
      this._resumeMode = this.mode;
      this.mode = "paused";
      this.cancelActions();
      this.player.vx = this.player.vz = 0;
    }
    return this;
  }

  resume() {
    if (this.mode === "paused") {
      this.mode = this._resumeMode;
      this.cancelActions();
    }
    return this;
  }

  cancelActions() {
    this._held = {};
    this._pending = {};
    this.preparedAbility = null;
    this.targeting = null;
    this._jumpBuffer = 0;
    this.player.charge = 0;
    this._accumulator = 0;
    return this;
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
      aim: this._sanitizeAim(input.aim, input.aimYaw),
      fire: !!input.fire,
      brake: !!input.brake,
    };
    if (input.cancel) {
      this.cancelActions();
      next.fire = false;
    } else {
      for (const action of ["dash", "jump", "ultimate"])
        this._pending[action] ||= !!input[action] && !this._held[action];
      for (const action of ["strike", "conductor"]) {
        if (input[action] && !this._held[action]) this.preparedAbility = action;
        if (!input[action] && this._held[action] && this.preparedAbility === action) {
          this._pending.cast = action;
          this.preparedAbility = null;
        }
      }
    }
    this._held = Object.fromEntries(
      ["fire", "dash", "jump", "ultimate", "strike", "conductor"].map((key) => [key, !!input[key]]),
    );
    this._accumulator += Math.min(dt, 0.25);
    while (this._accumulator + 1e-10 >= STEP && this.mode === "playing") {
      this._accumulator -= STEP;
      this._step(STEP, next);
    }
  }

  _sanitizeAim(aim, yaw) {
    const fallback = facing(finite(yaw, this.player.yaw));
    if (
      !aim ||
      !aim.origin ||
      !aim.direction ||
      ![
        aim.origin.x,
        aim.origin.y,
        aim.origin.z,
        aim.direction.x,
        aim.direction.y,
        aim.direction.z,
      ].every(Number.isFinite) ||
      Math.hypot(aim.direction.x, aim.direction.y, aim.direction.z) < 0.001
    )
      return { origin: this._weaponOrigin(), direction: { ...fallback, y: 0 } };
    return { origin: { ...aim.origin }, direction: unit(aim.direction) };
  }

  _weaponOrigin() {
    const p = this.player;
    return { x: p.x, y: p.y + p.radius * 0.45, z: p.z };
  }

  _step(dt, input) {
    this.time += dt;
    const p = this.player;
    for (const key of [
      "dashCooldown",
      "dashTime",
      "hurtTime",
      "shotCooldown",
      "strikeCooldown",
      "conductorCooldown",
      "ultimateTime",
      "landingImpact",
    ])
      p[key] = Math.max(0, p[key] - dt);
    this._workerGap = Math.max(0, this._workerGap - dt);
    this._jumpBuffer = Math.max(0, this._jumpBuffer - dt);
    p.yaw = Math.atan2(input.aim.direction.x, -input.aim.direction.z);
    if (this._pending.jump) this._jumpBuffer = 0.14;
    if (this._jumpBuffer > 0 && (p.grounded || p.airJumps > 0)) {
      p.vy = p.grounded
        ? LIGHTNING_CONFIG.movement.jumpSpeed
        : LIGHTNING_CONFIG.movement.airJumpSpeed;
      if (!p.grounded) p.airJumps--;
      p.grounded = false;
      this._jumpBuffer = 0;
      this._event("jump", p, { kind: p.airJumps ? "jump" : "air-jump" });
    }
    if (this._pending.dash && p.dashCooldown <= 0) {
      const length = Math.hypot(input.x, input.z);
      const dir = length > 0.1 ? { x: input.x / length, z: input.z / length } : facing(p.yaw);
      p.vx = dir.x * 19;
      p.vz = dir.z * 19;
      p.dashTime = 0.24;
      p.dashCooldown = Math.max(
        LIGHTNING_CONFIG.movement.minRamCooldown,
        LIGHTNING_CONFIG.movement.ramCooldown -
          p.brace * LIGHTNING_CONFIG.movement.braceCooldownBonus,
      );
      this._ramHits.clear();
      this._event("ram", p, { text: "Burst", kind: "burst" });
    }
    if (this._pending.ultimate && p.ultimateCharge >= 100 && p.ultimateTime === 0) {
      p.ultimateTime = LIGHTNING_CONFIG.ultimate.duration;
      p.ultimateCharge = 0;
      this._event("ultimate", p, { text: "Overstorm · 8 seconds" });
    }
    if (this._pending.cast) this._cast(this._pending.cast, input.aim);
    if (input.fire && p.shotCooldown <= 0) this._cast("bolt", input.aim);
    this._pending = {};
    if (p.dashTime <= 0) {
      const speed = input.brake && p.grounded ? 2.2 : 7.4;
      const dx = input.x * speed - p.vx;
      const dz = input.z * speed - p.vz;
      const delta = Math.hypot(dx, dz);
      const acceleration =
        ((input.brake && p.grounded ? 48 : 25) + p.brace * 4) * (p.grounded ? 1 : 0.85);
      const scale = delta > 0 ? Math.min(1, (acceleration * dt) / delta) : 0;
      p.vx += dx * scale;
      p.vz += dz * scale;
    }
    this._previousBottom = p.y - p.radius;
    p.x += p.vx * dt;
    p.z += p.vz * dt;
    if (!p.grounded) {
      p.vy -= LIGHTNING_CONFIG.movement.gravity * dt;
      p.y += p.vy * dt;
    }
    this._boundPlayer();
    for (const id of this._landingHits) {
      const enemy = this.enemies.find((candidate) => candidate.id === id);
      if (
        !enemy ||
        enemy.state === "dead" ||
        p.y - p.radius > enemy.y + enemy.bodyHeight + 0.1 ||
        distance(p, enemy) > p.radius + enemy.radius + 0.1
      )
        this._landingHits.delete(id);
    }
    this._updateEnemies(dt);
    if (this.mode !== "playing") return;
    this._updateOffcuts(dt);
    if (this.mode !== "playing") return;
    this._collect();
    this._updateCompanion(dt);
    this._updateConductors(dt);
    const due = this._echoes.filter((echo) => echo.time <= this.time);
    this._echoes = this._echoes.filter((echo) => echo.time > this.time);
    for (const echo of due)
      this._executeAttack(this._repeatAttack(echo.attack), echo.amount, echo.source, true);
    this._updateWaves(dt);
    if (this.mode === "playing")
      this.targeting = this.previewAttack(this.preparedAbility || "bolt", input.aim);
  }

  _boundPlayer() {
    const p = this.player;
    const x = clamp(p.x, ARENA.minX + p.radius, ARENA.maxX - p.radius);
    const z = clamp(p.z, ARENA.minZ + p.radius, ARENA.maxZ - p.radius);
    if (x !== p.x) p.vx = 0;
    if (z !== p.z) p.vz = 0;
    p.x = x;
    p.z = z;
    const floor = groundHeight(x, z) + p.radius;
    if (p.grounded || p.y <= floor) {
      if (!p.grounded && p.vy < -1) {
        p.landingImpact = clamp(-p.vy / 30, 0.1, 0.65);
        this._event("land", p, { amount: -p.vy });
      }
      p.y = floor;
      p.vy = 0;
      p.grounded = true;
      p.airJumps = 1;
      this._landingHits.clear();
    }
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
          enemy.x = clamp(
            enemy.x + dir.x * c.speed * dt,
            ARENA.minX + c.radius,
            ARENA.maxX - c.radius,
          );
          enemy.z = clamp(
            enemy.z + dir.z * c.speed * dt,
            ARENA.minZ + c.radius,
            ARENA.maxZ - c.radius,
          );
        }
        if (c.speed) {
          for (const other of this.enemies) {
            if (other === enemy || other.state === "dead") continue;
            const separation = distance(enemy, other);
            const preferred = enemy.radius + other.radius + 0.3;
            if (separation >= preferred) continue;
            const push = Math.min(1.2, preferred - separation) * dt;
            const direction =
              separation > 0.001
                ? {
                    x: (enemy.x - other.x) / separation,
                    z: (enemy.z - other.z) / separation,
                  }
                : facing(enemy.yaw + Math.PI / 2);
            enemy.x = clamp(
              enemy.x + direction.x * push,
              ARENA.minX + c.radius,
              ARENA.maxX - c.radius,
            );
            enemy.z = clamp(
              enemy.z + direction.z * push,
              ARENA.minZ + c.radius,
              ARENA.maxZ - c.radius,
            );
          }
        }
        const workerReady =
          enemy.kind === "pruner" ||
          (this._workerGap <= 0 &&
            this.enemies.filter(
              (other) => other !== enemy && other.kind !== "pruner" && other.state === "windup",
            ).length < 2);
        const attackReach = enemy.kind === "pruner" ? 30 : c.reach + this.player.radius + 0.5;
        if (gap <= attackReach && enemy.cooldown <= 0 && workerReady) {
          enemy.attackStyle =
            enemy.kind === "pruner" && gap > c.reach + this.player.radius + 0.5 ? "toss" : "sweep";
          this._transition(enemy, "windup");
          if (enemy.kind !== "pruner") this._workerGap = 0.35;
        }
      } else {
        enemy.stateTime += dt;
        enemy.phase = clamp(enemy.stateTime / c[enemy.state], 0, 1);
        if (enemy.phase >= 1 - 1e-9) {
          if (enemy.state === "windup") this._transition(enemy, "active");
          else if (enemy.state === "active") this._transition(enemy, "recovery");
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
          yMin: Math.min(groundHeight(path.x1, path.z1), groundHeight(path.x2, path.z2)),
          yMax: Math.max(groundHeight(path.x1, path.z1), groundHeight(path.x2, path.z2)) + 1.3,
          jumpable: true,
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
          kind: enemy.kind === "spreadleg" ? "spread" : enemy.kind === "pruner" ? "sweep" : "cut",
          x: enemy.x,
          z: enemy.z,
          yaw: enemy.yaw,
          range: c.reach,
          width: c.width,
          phase: enemy.phase,
          state: enemy.state,
          yMin:
            enemy.y + (enemy.kind === "spreadleg" ? 0.03 : enemy.kind === "snipcart" ? 1.16 : 1.4),
          yMax:
            enemy.y +
            (enemy.kind === "spreadleg"
              ? 0.53
              : enemy.kind === "snipcart"
                ? enemy.state === "windup"
                  ? 1.64
                  : 1.56
                : 2.1),
          jumpable: enemy.kind !== "pruner",
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
          this.player.y + this.player.radius >= hazard.yMin &&
          this.player.y - this.player.radius <= hazard.yMax &&
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
      const floor = groundHeight(offcut.x, offcut.z);
      if (
        this.player.y + this.player.radius >= floor &&
        this.player.y - this.player.radius <= floor + 1.3 &&
        pointSegmentDistance(this.player.x, this.player.z, segment) <=
          this.player.radius + segment.radius
      ) {
        this._hurt(18, { kind: "offcut" });
        if (this.mode !== "playing") break;
        continue;
      }
      remaining.push(offcut);
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
        yMin: floor,
        yMax: floor + 1.3,
        jumpable: true,
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
    const top = enemy.y + enemy.bodyHeight;
    if (p.y + p.radius < enemy.y) return;
    if (
      p.vy < 0 &&
      !p.grounded &&
      enemy.kind !== "pruner" &&
      enemy.radius <= p.radius * 1.5 &&
      this._previousBottom >= top - 0.08 &&
      p.y - p.radius <= top &&
      !this._landingHits.has(enemy.id)
    ) {
      this._landingHits.add(enemy.id);
      p.y = top + p.radius;
      p.vy = 8.5;
      p.airJumps = 1;
      p.landingImpact = 0.45;
      this._damage(enemy, 42 + Math.min(p.shear, 3) * 7, false, "impact");
      this._groundLoop(enemy);
      this._event("bounce", p, {
        amount: 8.5,
        targetX: enemy.x,
        targetY: top,
        targetZ: enemy.z,
      });
      return;
    }
    if (p.y - p.radius > top) return;
    if (p.dashTime > 0 && !this._ramHits.has(enemy.id)) {
      this._ramHits.add(enemy.id);
      const weakGap = Math.hypot(p.x - enemy.weakX, p.z - enemy.weakZ);
      const counter = enemy.state === "recovery" && weakGap < p.radius + 1.9;
      this._damage(
        enemy,
        LIGHTNING_CONFIG.movement.ramDamage +
          Math.min(p.shear, LIGHTNING_CONFIG.movement.maxShearBonus) *
            LIGHTNING_CONFIG.movement.shearRamBonus,
        counter,
        "ram",
      );
      this._groundLoop(enemy);
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
    if (inward < -2) {
      p.landingImpact = Math.max(p.landingImpact, 0.18);
      this._event("bounce", p, { kind: "bump", amount: -inward });
    }
    if (inward < 0) {
      p.vx -= inward * dx;
      p.vz -= inward * dz;
    }
    this._boundPlayer();
  }

  _terrainRay(origin, direction, range) {
    let nearest = null;
    for (const [slope, offset, minZ, maxZ] of [
      [0, 0, -14, Infinity],
      [-2.5 / 9, -35 / 9, -23, -14],
      [0, 2.5, -Infinity, -23],
    ]) {
      const divisor = direction.y - slope * direction.z;
      if (Math.abs(divisor) < 1e-10) continue;
      const t = (slope * origin.z + offset - origin.y) / divisor;
      if (t < 0.001 || t > range) continue;
      const point = along(origin, direction, t);
      if (point.z < minZ - 1e-8 || point.z > maxZ + 1e-8 || !inside(point)) continue;
      if (nearest === null || t < nearest) nearest = t;
    }
    return nearest;
  }

  _bodyRay(origin, direction, range, enemy) {
    const dx = origin.x - enemy.x,
      dz = origin.z - enemy.z;
    const a = direction.x ** 2 + direction.z ** 2;
    const b = 2 * (dx * direction.x + dz * direction.z);
    const c = dx ** 2 + dz ** 2 - enemy.radius ** 2;
    let enter = 0,
      leave = range;
    if (a < 1e-10) {
      if (c > 0) return null;
    } else {
      const discriminant = b * b - 4 * a * c;
      if (discriminant < 0) return null;
      enter = Math.max(enter, (-b - Math.sqrt(discriminant)) / (2 * a));
      leave = Math.min(leave, (-b + Math.sqrt(discriminant)) / (2 * a));
    }
    const bottom = enemy.y,
      top = enemy.y + enemy.bodyHeight;
    if (Math.abs(direction.y) < 1e-10) {
      if (origin.y < bottom || origin.y > top) return null;
    } else {
      const y1 = (bottom - origin.y) / direction.y,
        y2 = (top - origin.y) / direction.y;
      enter = Math.max(enter, Math.min(y1, y2));
      leave = Math.min(leave, Math.max(y1, y2));
    }
    return leave + 1e-7 >= enter && enter <= range + 1e-7 ? Math.min(enter, range) : null;
  }

  _ray(origin, direction, range, bodies = true) {
    const terrain = this._terrainRay(origin, direction, range);
    let t = terrain ?? range;
    let enemy = null;
    if (bodies)
      for (const candidate of this.enemies) {
        if (candidate.state === "dead") continue;
        const hit = this._bodyRay(origin, direction, t, candidate);
        if (hit !== null && hit <= t) {
          t = hit;
          enemy = candidate;
        }
      }
    return {
      point: along(origin, direction, t),
      enemy,
      terrain: !enemy && terrain !== null,
      distance: t,
    };
  }

  _visible(from, to) {
    const span = length3(from, to);
    const terrain = this._terrainRay(from, towards(from, to), span);
    return terrain === null || terrain >= span - 0.025;
  }

  _chain(
    attack,
    first,
    reach = LIGHTNING_CONFIG.bolt.chainRange,
    count = LIGHTNING_CONFIG.bolt.chainTargets,
  ) {
    let source = first;
    attack.targetIds.push(first.id);
    for (let i = 0; i < count; i++) {
      const candidates = this.enemies.filter(
        (e) =>
          e.state !== "dead" &&
          !attack.targetIds.includes(e.id) &&
          length3(center(source), center(e)) <= reach &&
          this._visible(center(source), center(e)),
      );
      candidates.sort(
        (a, b) =>
          length3(center(source), center(a)) - length3(center(source), center(b)) ||
          a.id.localeCompare(b.id),
      );
      if (!candidates.length) break;
      const next = candidates[0];
      attack.segments.push({ from: center(source), to: center(next) });
      attack.targetIds.push(next.id);
      source = next;
    }
  }

  previewAttack(kind, aim) {
    if (!["bolt", "strike", "conductor"].includes(kind))
      throw new Error(`Unknown attack kind ${kind}`);
    const config = LIGHTNING_CONFIG[kind];
    const origin = this._weaponOrigin();
    aim = this._sanitizeAim(aim);
    const camera = this._ray(
      aim.origin,
      aim.direction,
      config.range + length3(aim.origin, origin),
      kind === "bolt",
    );
    const direction = towards(origin, camera.point);
    const requested = length3(origin, camera.point);
    const ray = this._ray(origin, direction, Math.min(config.range, requested), kind === "bolt");
    const attack = {
      kind,
      valid: true,
      origin,
      point: ray.point,
      segments: [{ from: { ...origin }, to: { ...ray.point } }],
      radius: kind === "bolt" ? 0 : config.radius,
      targetIds: [],
      blocked: ray.terrain,
    };
    if (kind === "bolt") {
      if (ray.enemy)
        this._chain(
          attack,
          ray.enemy,
          LIGHTNING_CONFIG.bolt.chainRange *
            (this.player.ultimateTime > 0 ? LIGHTNING_CONFIG.ultimate.chainMultiplier : 1),
        );
    } else {
      const onTerrain = Math.abs(ray.point.y - groundHeight(ray.point.x, ray.point.z)) < 0.03;
      attack.valid =
        camera.terrain &&
        requested <= config.range + 0.001 &&
        inside(ray.point) &&
        onTerrain &&
        this._visible(origin, camera.point);
      attack.blocked = !this._visible(origin, camera.point);
      if (attack.valid) {
        attack.point = {
          ...camera.point,
          y: groundHeight(camera.point.x, camera.point.z),
        };
        attack.segments[0].to = { ...attack.point };
        if (kind === "conductor") {
          const pulse = this._conductorAttack(
            attack.point,
            this.conductors.slice(-(LIGHTNING_CONFIG.conductor.max - 1)),
          );
          attack.targetIds = pulse.targetIds;
          attack.segments.push(...pulse.segments);
          attack.corridors = pulse.corridors;
        } else
          attack.targetIds = this.enemies
            .filter(
              (e) =>
                e.state !== "dead" &&
                distance(e, attack.point) <= config.radius + e.radius &&
                e.y + e.bodyHeight >= attack.point.y &&
                e.y <= attack.point.y + 12 &&
                this._visible({ ...attack.point, y: attack.point.y + 1.35 }, center(e)),
            )
            .map((e) => e.id);
      }
    }
    return attack;
  }

  _cast(kind, aim) {
    const cooldown = kind === "bolt" ? "shotCooldown" : `${kind}Cooldown`;
    if (this.player[cooldown] > 0) return false;
    const attack = this.previewAttack(kind, aim);
    if (!attack.valid) return false;
    const config = LIGHTNING_CONFIG[kind];
    this.player[cooldown] = config.cooldown ?? config.interval;
    if (kind === "conductor") {
      if (this.conductors.length >= config.max) this.conductors.shift();
      this.conductors.push({
        id: `conductor-${++this._nextConductorId}`,
        ...attack.point,
        cooldown: 0.1,
        flash: 0,
      });
      this._event("attack", attack.origin, {
        attack,
        source: "player",
        echo: false,
        amount: 0,
      });
    } else {
      if (kind === "bolt") this.stats.shots++;
      this._executeAttack(attack, config.damage, "player");
    }
    return true;
  }

  _repeatAttack(original) {
    const attack = copy(original);
    attack.targetIds = this.enemies
      .filter((enemy) => {
        if (enemy.state === "dead") return false;
        if (attack.kind === "strike")
          return (
            distance(enemy, attack.point) <= attack.radius + enemy.radius &&
            enemy.y + enemy.bodyHeight >= attack.point.y &&
            enemy.y <= attack.point.y + 12 &&
            this._visible({ ...attack.point, y: attack.point.y + 1.35 }, center(enemy))
          );
        if (attack.kind === "conductor")
          return (
            this._visible(attack.origin, center(enemy)) &&
            (length3(attack.origin, center(enemy)) <= attack.radius + enemy.radius ||
              (attack.corridors || []).some((corridor) => this._corridorHits(corridor, enemy)))
          );
        return attack.segments.some(
          ({ from, to }) =>
            this._bodyRay(from, towards(from, to), length3(from, to), enemy) !== null,
        );
      })
      .map((enemy) => enemy.id);
    return attack;
  }

  _executeAttack(attack, amount, source, echo = false) {
    let hitCount = 0;
    for (const id of attack.targetIds) {
      const enemy = this.enemies.find(
        (candidate) => candidate.id === id && candidate.state !== "dead",
      );
      if (!enemy) continue;
      const segment = attack.segments[0];
      const weakAcross = segment
        ? pointSegmentDistance(enemy.weakX, enemy.weakZ, {
            x1: segment.from.x,
            z1: segment.from.z,
            x2: segment.to.x,
            z2: segment.to.z,
          })
        : Infinity;
      const counter =
        !echo &&
        source === "player" &&
        attack.kind === "bolt" &&
        id === attack.targetIds[0] &&
        enemy.state === "recovery" &&
        weakAcross <= 0.9;
      this._damage(enemy, amount, counter, source);
      if (source === "companion" && enemy.state !== "dead") enemy.primed = 3;
      hitCount++;
    }
    this._event("attack", attack.origin, {
      attack: copy(attack),
      source,
      echo,
      amount,
    });
    if (hitCount > 1 && this.player.ultimateTime <= 0)
      this.player.ultimateCharge = Math.min(
        100,
        this.player.ultimateCharge + (hitCount - 1) * (echo ? 2 : 5),
      );
    if (!echo && this.inventory.equipped.includes("echo"))
      this._echoes.push({
        time: this.time + 0.22,
        attack: copy(attack),
        amount: amount * 0.5,
        source,
      });
  }

  _groundLoop(enemy) {
    if (!this.inventory.equipped.includes("ground-loop")) return;
    const origin = center(enemy);
    const attack = {
      kind: "ground-loop",
      valid: true,
      origin,
      point: origin,
      segments: [{ from: { ...origin }, to: { ...origin } }],
      radius: LIGHTNING_CONFIG.bolt.chainRange,
      targetIds: [],
      blocked: false,
    };
    this._chain(
      attack,
      enemy,
      LIGHTNING_CONFIG.bolt.chainRange *
        (this.player.ultimateTime > 0 ? LIGHTNING_CONFIG.ultimate.chainMultiplier : 1),
    );
    this._executeAttack(attack, 20, "player");
  }

  _conductorCorridors(conductor, others = this.conductors) {
    const from = { x: conductor.x, y: conductor.y + 1.35, z: conductor.z };
    return others
      .filter(
        (other) =>
          other !== conductor &&
          distance(other, conductor) <= LIGHTNING_CONFIG.conductor.radius * 2 &&
          this._visible(from, { ...other, y: other.y + 1.35 }),
      )
      .map((other) => {
        const to = { x: other.x, y: other.y + 1.35, z: other.z };
        return {
          from: { ...from },
          to,
          radius: LIGHTNING_CONFIG.conductor.linkRadius,
          yMin: Math.min(from.y, to.y) - LIGHTNING_CONFIG.conductor.linkHalfHeight,
          yMax: Math.max(from.y, to.y) + LIGHTNING_CONFIG.conductor.linkHalfHeight,
        };
      });
  }

  _corridorHits(corridor, enemy) {
    return (
      pointSegmentDistance(enemy.x, enemy.z, {
        x1: corridor.from.x,
        z1: corridor.from.z,
        x2: corridor.to.x,
        z2: corridor.to.z,
      }) <=
        enemy.radius + corridor.radius &&
      enemy.y <= corridor.yMax &&
      enemy.y + enemy.bodyHeight >= corridor.yMin
    );
  }

  _conductorAttack(conductor, others = this.conductors) {
    const origin = { x: conductor.x, y: conductor.y + 1.35, z: conductor.z };
    const attack = {
      kind: "conductor",
      valid: true,
      origin,
      point: { ...origin },
      segments: [],
      radius: LIGHTNING_CONFIG.conductor.radius,
      targetIds: [],
      blocked: false,
    };
    attack.corridors = this._conductorCorridors(conductor, others);
    attack.segments.push(...attack.corridors);
    for (const enemy of this.enemies) {
      if (enemy.state === "dead" || !this._visible(origin, center(enemy))) continue;
      const linked = attack.corridors.some((corridor) => this._corridorHits(corridor, enemy));
      if (
        length3(origin, center(enemy)) <= LIGHTNING_CONFIG.conductor.radius + enemy.radius ||
        linked
      ) {
        attack.targetIds.push(enemy.id);
        attack.segments.push({ from: { ...origin }, to: center(enemy) });
      }
    }
    return attack;
  }

  _updateConductors(dt) {
    this.conductorLinks =
      this.conductors.length === 2
        ? this._conductorCorridors(this.conductors[0], [this.conductors[1]])
        : [];
    for (const conductor of this.conductors) {
      conductor.cooldown = Math.max(0, conductor.cooldown - dt);
      conductor.flash = Math.max(0, conductor.flash - dt);
      if (conductor.cooldown > 0) continue;
      const attack = this._conductorAttack(conductor);
      conductor.cooldown =
        LIGHTNING_CONFIG.conductor.interval /
        (this.player.ultimateTime > 0 ? LIGHTNING_CONFIG.ultimate.conductorMultiplier : 1);
      conductor.flash = 0.18;
      if (attack.targetIds.length || attack.segments.length)
        this._executeAttack(attack, LIGHTNING_CONFIG.conductor.damage, "conductor");
    }
  }

  _beginWave(index) {
    const [snips, spreadlegs, boss] = WAVES[index - 1];
    this.enemies = [];
    this.hazards = [];
    this.conductors = [];
    this.conductorLinks = [];
    this._offcuts = [];
    this._echoes = [];
    this._waveQueue = [];
    for (let i = 0; i < snips; i++) {
      this._waveQueue.push("snipcart");
      if (i < spreadlegs) this._waveQueue.push("spreadleg");
    }
    if (boss) this._waveQueue.unshift("pruner");
    this.wave = {
      index,
      total: 3,
      remaining: snips + spreadlegs + boss,
      queued: snips + spreadlegs + boss,
      active: 0,
      cleared: index - 1,
      rewardChosen: false,
      entries: [],
    };
    this._entryCooldown = 0;
    this.rewards = [];
    this.cancelActions();
    this._event("wave", this.player, {
      text: `Wave ${index} · ${this.wave.remaining} machines`,
    });
  }

  _updateWaves(dt) {
    this._entryCooldown = Math.max(0, this._entryCooldown - dt);
    const pending = [];
    for (const entry of this.wave.entries) {
      if (entry.time > this.time) {
        pending.push(entry);
        continue;
      }
      if (distance(entry, this.player) < 9) {
        const safer = [...ENTRY_POINTS].sort(
          (a, b) => distance(b, this.player) - distance(a, this.player),
        )[0];
        Object.assign(entry, safer, { time: this.time + 1.2 });
        this._event("spawn", entry, {
          text: "Incoming group moved to a clear entrance",
          delay: 1.2,
        });
        pending.push(entry);
        continue;
      }
      entry.kinds.forEach((kind, i) => {
        const enemy = this._makeEnemy(
          kind,
          entry.x + (i % 2 ? 1.8 : -1.8),
          entry.z + Math.floor(i / 2) * 2.5,
          1.2,
        );
        enemy.id = `enemy-${++this._nextEnemyId}`;
        enemy.active = true;
        enemy.state = "approach";
        this.enemies.push(enemy);
      });
    }
    this.wave.entries = pending;
    const living = this.enemies.filter((enemy) => enemy.state !== "dead");
    const workers = living.filter((enemy) => enemy.kind !== "pruner").length;
    const reserved = pending
      .flatMap((entry) => entry.kinds)
      .filter((kind) => kind !== "pruner").length;
    const room = 14 - workers - reserved;
    if (this._waveQueue.length && this._entryCooldown <= 0 && room > 0) {
      const kinds = [];
      let admittedWorkers = 0;
      while (this._waveQueue.length && kinds.length < 4 && admittedWorkers < room) {
        const kind = this._waveQueue.shift();
        kinds.push(kind);
        if (kind !== "pruner") admittedWorkers++;
      }
      const entrance = [...ENTRY_POINTS].sort(
        (a, b) => distance(b, this.player) - distance(a, this.player),
      )[0];
      this.wave.entries.push({ ...entrance, kinds, time: this.time + 1.2 });
      this._entryCooldown = 3;
      this._event("spawn", entrance, {
        text: `${kinds.length} machines incoming`,
        delay: 1.2,
      });
    }
    this.wave.active = living.length;
    this.wave.queued =
      this._waveQueue.length +
      this.wave.entries.reduce((sum, entry) => sum + entry.kinds.length, 0);
    this.wave.remaining = this.wave.active + this.wave.queued;
    if (this.wave.remaining !== 0) return;
    this.wave.cleared = this.wave.index;
    this.cancelActions();
    this.hazards = [];
    this._offcuts = [];
    this.conductors = [];
    this.conductorLinks = [];
    this._echoes = [];
    this.player.vx = this.player.vz = 0;
    if (this.wave.index === 3) {
      this.mode = "won";
      this._event("win", this.player, { text: "All three waves cleared" });
    } else {
      this.mode = "intermission";
      this.rewards =
        this.wave.index === 1
          ? [
              ITEM_CONFIG["ground-loop"],
              {
                id: "brace-package",
                name: "Brace package",
                description: "Two Brace parts improve burst recovery and damage protection.",
              },
            ]
          : [
              ITEM_CONFIG.echo,
              {
                id: "shear-package",
                name: "Shear package",
                description:
                  "Two Shear Linkages strengthen body rams and unlock the priming companion.",
              },
            ];
      this._event("wave", this.player, {
        text: "Wave cleared · choose a reward and prepare",
      });
    }
  }

  chooseReward(id) {
    if (
      this.mode !== "intermission" ||
      this.wave.rewardChosen ||
      !this.rewards.some((reward) => reward.id === id)
    )
      return false;
    if (ITEM_CONFIG[id]) {
      if (!this.inventory.acquired.includes(id)) this.inventory.acquired.push(id);
      if (!this.inventory.equipped.includes(id)) this.inventory.equipped.push(id);
    } else if (id === "brace-package") this.player.brace += 2;
    else if (id === "shear-package") {
      this.player.shear += 2;
      this._unlockCompanion();
    }
    this.player.radius = Math.min(
      1.65,
      1 + this.player.scrap * 0.022 + this.player.shear * 0.045 + this.player.brace * 0.045,
    );
    this._boundPlayer();
    this.wave.rewardChosen = true;
    this._event("collect", this.player, {
      kind: id,
      text: this.rewards.find((reward) => reward.id === id).description,
    });
    return true;
  }

  continueWave() {
    if (this.mode !== "intermission" || !this.wave.rewardChosen) return false;
    this.mode = "playing";
    this._beginWave(this.wave.index + 1);
    return true;
  }

  setItemEnabled(id, enabled) {
    if (this.mode !== "intermission" || !this.inventory.acquired.includes(id)) return false;
    this.inventory.equipped = this.inventory.equipped.filter((item) => item !== id);
    if (enabled) this.inventory.equipped.push(id);
    return true;
  }

  setCompanionEnabled(enabled) {
    if (this.mode !== "intermission" || !this.companion) return false;
    this.companion.enabled = this.companion.active = !!enabled;
    return true;
  }

  _unlockCompanion() {
    if (this.player.shear > 0 && !this.companion) {
      const p = this.player;
      this.companion = {
        x: p.x,
        y: groundHeight(p.x, p.z),
        z: p.z,
        yaw: p.yaw,
        active: true,
        enabled: true,
        cooldown: 0.25,
        flash: 0,
      };
      this._event("deploy", p, {
        text: "Shear companion equipped · attacks prime housings",
      });
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
        if (enemy.kind === "pruner") this._addPickup("heart", enemy.weakX + 0.7, enemy.weakZ);
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
      this.hazards = this.hazards.filter((hazard) => !hazard.id.startsWith(`${enemy.id}-`));
      for (let i = 0; i < 4; i++) {
        const angle = this._random() * Math.PI * 2;
        this._addPickup("scrap", enemy.x + Math.cos(angle) * 1.3, enemy.z + Math.sin(angle) * 1.3);
      }
      this._addPickup(enemy.kind === "spreadleg" ? "brace" : "shear", enemy.x, enemy.z);
      this._addPickup("heart", enemy.x + 1, enemy.z);
    }
  }

  _hurt(amount, enemy) {
    const p = this.player;
    if (p.hurtTime > 0 || this.mode !== "playing") return;
    const damage =
      amount *
      (1 -
        Math.min(
          LIGHTNING_CONFIG.movement.maxBraceProtection,
          p.brace * LIGHTNING_CONFIG.movement.braceProtection,
        ));
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
      if (pickup.kind === "shear") {
        p.shear++;
        this._unlockCompanion();
      }
      if (pickup.kind === "brace") p.brace++;
      if (pickup.kind === "heart") p.hp = Math.min(p.maxHp, p.hp + 16);
      p.radius = Math.min(1.65, 1 + p.scrap * 0.022 + p.shear * 0.045 + p.brace * 0.045);
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
    if (!buddy || !buddy.active || !buddy.enabled) return;
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
          candidate.state !== "dead" &&
          length3(center(candidate), {
            x: buddy.x,
            y: buddy.y + 0.7,
            z: buddy.z,
          }) < LIGHTNING_CONFIG.companion.range &&
          this._visible({ x: buddy.x, y: buddy.y + 0.7, z: buddy.z }, center(candidate)),
      )
      .sort((a, b) => distance(a, buddy) - distance(b, buddy))[0];
    buddy.yaw = enemy ? yawTo(buddy, enemy) : p.yaw;
    if (enemy && buddy.cooldown <= 0) {
      buddy.cooldown = LIGHTNING_CONFIG.companion.interval;
      buddy.flash = 0.24;
      const origin = { x: buddy.x, y: buddy.y + 0.7, z: buddy.z };
      const point = center(enemy);
      this._executeAttack(
        {
          kind: "companion",
          valid: true,
          origin,
          point,
          segments: [{ from: origin, to: point }],
          radius: 0,
          targetIds: [enemy.id],
          blocked: false,
        },
        LIGHTNING_CONFIG.companion.damage,
        "companion",
      );
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
        wave: this.wave,
        rewards: this.rewards,
        inventory: this.inventory,
        conductors: this.conductors,
        conductorLinks: this.conductorLinks,
        targeting: this.targeting,
        preparedAbility: this.preparedAbility,
      }),
    );
  }
}
