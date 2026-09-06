export const PATH = [
  [-12, -7],
  [10, -7],
  [10, -2],
  [-10, -2],
  [-10, 4],
  [9, 4],
  [9, 8],
  [3, 8],
];
export const WALLS = [
  { x: -1.2, z: -4.45, w: 19, h: 1.35 },
  { x: 1.3, z: 1.05, w: 18.8, h: 1.4 },
  { x: -2.8, z: 6.9, w: 15, h: 1.15 },
];
export const CLASSES = {
  scavenger: {
    name: "Scavenger",
    tag: "MOBILITY / MAGNETISM",
    icon: "magnet",
    text: "Collect faster. Grow bigger.",
    passive: "+25% roll speed · +50% pickup reach",
    ability: "Scrap surge",
    abilityText: "Pull in nearby scrap and blast enemies.",
    cooldown: 12,
    speed: 8.5,
    magnet: 2.3,
    damage: 1,
    color: "#ffc074",
  },
  engineer: {
    name: "Engineer",
    tag: "FIREPOWER / PRECISION",
    icon: "gear",
    text: "Turn a little scrap into a lot of fire.",
    passive: "+30% turret damage · faster reload",
    ability: "Overclock",
    abilityText: "Double fire rate for 6 seconds.",
    cooldown: 16,
    speed: 6.8,
    magnet: 1.55,
    damage: 1.3,
    color: "#ade8d4",
  },
  warden: {
    name: "Warden",
    tag: "CONTROL / AREA DAMAGE",
    icon: "spark",
    text: "Keep the horde on your terms.",
    passive: "Shots slow enemies · +25 core integrity",
    ability: "Static bloom",
    abilityText: "Shock and freeze enemies in a wide radius.",
    cooldown: 13,
    speed: 7.3,
    magnet: 1.7,
    damage: 1,
    color: "#a7c9f5",
  },
};
export const WEAPONS = {
  bolt: {
    name: "Bolt repeater",
    short: "REPEATER",
    color: "#ffd087",
    damage: 10,
    cooldown: 0.68,
    range: 3.8,
    speed: 20,
  },
  pipe: {
    name: "Pipe mortar",
    short: "MORTAR",
    color: "#ff935a",
    damage: 21,
    cooldown: 1.35,
    range: 5.0,
    speed: 14,
    splash: 1.6,
  },
  coil: {
    name: "Arc coil",
    short: "ARC COIL",
    color: "#99f4d7",
    damage: 8,
    cooldown: 0.85,
    range: 3.5,
    speed: 26,
    chain: 2,
  },
  cactus: {
    name: "Thorn caster",
    short: "THORN",
    color: "#bec68a",
    damage: 6,
    cooldown: 0.4,
    range: 3.4,
    speed: 22,
  },
};
export const UPGRADES = [
  {
    id: "damage",
    title: "Meaner machinery",
    stat: "+25% DAMAGE",
    text: "Every piece of scrap hits harder.",
    icon: "crosshair",
  },
  {
    id: "haste",
    title: "Questionable wiring",
    stat: "+20% FIRE RATE",
    text: "A little hotter. A lot more bullets.",
    icon: "spark",
  },
  {
    id: "range",
    title: "Long-distance trouble",
    stat: "+20% RANGE",
    text: "Give your entire arsenal a longer reach.",
    icon: "scope",
  },
  {
    id: "magnet",
    title: "Personal gravity",
    stat: "+35% PICKUP REACH",
    text: "Bring more of the yard along for the ride.",
    icon: "magnet",
  },
  {
    id: "speed",
    title: "Greased bearings",
    stat: "+15% ROLL SPEED",
    text: "Get to the next problem before it arrives.",
    icon: "arrow",
  },
  {
    id: "repair",
    title: "A little duct tape",
    stat: "+35 CORE INTEGRITY",
    text: "Patch up the thing you are protecting.",
    icon: "heart",
  },
];
export const clamp = (n, a, b) => Math.max(a, Math.min(b, n));
export const distance = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
export function seededRandom(seed = 12345) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}
export function validPosition(x, z, r = 0.7) {
  return (
    Math.abs(x) < 13.2 - r &&
    Math.abs(z) < 10.2 - r &&
    !WALLS.some(
      (w) => Math.abs(x - w.x) < w.w / 2 + r && Math.abs(z - w.z) < w.h / 2 + r,
    )
  );
}
export function pointOnPath(travel) {
  for (let i = 1; i < PATH.length; i++) {
    const a = PATH[i - 1],
      b = PATH[i],
      len = Math.hypot(b[0] - a[0], b[1] - a[1]);
    if (travel <= len)
      return {
        x: a[0] + ((b[0] - a[0]) * travel) / len,
        z: a[1] + ((b[1] - a[1]) * travel) / len,
        angle: Math.atan2(b[0] - a[0], b[1] - a[1]),
        done: false,
      };
    travel -= len;
  }
  return { x: PATH.at(-1)[0], z: PATH.at(-1)[1], angle: 0, done: true };
}
export const PATH_LENGTH = PATH.slice(1).reduce(
  (n, p, i) => n + Math.hypot(p[0] - PATH[i][0], p[1] - PATH[i][1]),
  0,
);
export class Game {
  constructor(seed = 745) {
    this.seed = seed;
    this.reset("scavenger", false);
  }
  reset(classId = this.classId || "scavenger", start = true) {
    this.random = seededRandom(this.seed);
    this.classId = CLASSES[classId] ? classId : "scavenger";
    this.role = CLASSES[this.classId];
    this.mode = start ? "playing" : "menu";
    this.time = 0;
    this.wave = 0;
    this.survived = 0;
    this.score = 0;
    this.kills = 0;
    this.collected = 0;
    this.level = 1;
    this.xp = 0;
    this.xpNext = 65;
    this.maxBase = this.classId === "warden" ? 125 : 100;
    this.base = this.maxBase;
    this.waveState = "gather";
    this.waveTimer = 7;
    this.spawnTimer = 0;
    this.spawnLeft = 0;
    this.enemies = [];
    this.projectiles = [];
    this.pickups = [];
    this.events = [];
    this.id = 0;
    this.player = {
      x: 1,
      z: -2,
      vx: 0,
      vz: 0,
      radius: 0.72,
      dash: 0,
      dashCooldown: 0,
      abilityCooldown: 0,
      overclock: 0,
      heading: 0,
      momentum: 0.65,
    };
    this.buffs = {
      damage: 1,
      haste: this.classId === "engineer" ? 1.1 : 1,
      range: 1,
      magnet: 1,
      speed: 1,
    };
    this.weapons = [];
    this.options = [];
    this.scrapTimer = 9;
    this.combo = 0;
    this.comboTimer = 0;
    this.addWeapon("bolt");
    this.addWeapon("coil");
    const fixed = [
      [2.8, -2.2, "pipe"],
      [-0.9, -2.3, "bolt"],
      [1, -0.9, "cactus"],
      [3, -0.8, "coil"],
      [-3, -2, "pipe"],
      [4.8, -2.6, "bolt"],
      [-6, -2.4, "coil"],
      [7, -2.5, "cactus"],
      [10.6, -4.5, "pipe"],
      [-10.8, -4.5, "bolt"],
      [-8, -7.5, "coil"],
      [-4, -7, "pipe"],
      [0, -7.3, "bolt"],
      [4, -7.2, "cactus"],
      [8, -7, "coil"],
      [-11, 1, "pipe"],
      [-8, 4, "bolt"],
      [-5, 4.4, "cactus"],
      [-1, 4, "coil"],
      [3, 4.3, "pipe"],
      [7, 4, "bolt"],
      [10.5, 6.3, "coil"],
      [-6, 8.5, "pipe"],
      [-10, 8.5, "cactus"],
      [0, 8.5, "bolt"],
    ];
    fixed.forEach(([x, z, type]) =>
      this.pickups.push({ id: ++this.id, x, z, type, born: -2 }),
    );
  }
  emit(type, data = {}) {
    this.events.push({ ...data, kind: data.type, type });
  }
  drainEvents() {
    const e = this.events;
    this.events = [];
    return e;
  }
  addWeapon(type) {
    if (this.weapons.length >= 24) {
      const weakest = this.weapons.reduce((a, b) =>
        a.power < b.power ? a : b,
      );
      weakest.power += 0.18;
      return weakest;
    }
    const i = this.weapons.length;
    const w = {
      id: ++this.id,
      type,
      angle: i * 2.399963 + Math.PI / 4,
      cooldown: i * 0.09,
      power: 1,
      recoil: 0,
      aim: null,
    };
    this.weapons.push(w);
    return w;
  }
  mount(w) {
    const a = w.angle + this.player.heading;
    return {
      x: this.player.x + Math.cos(a) * this.player.radius * 0.88,
      z: this.player.z + Math.sin(a) * this.player.radius * 0.88,
      nx: Math.cos(a),
      nz: Math.sin(a),
    };
  }
  startWave() {
    this.wave++;
    this.waveState = "assault";
    this.spawnLeft = 7 + this.wave * 3;
    this.spawnTimer = 0.15;
    this.emit("wave", { wave: this.wave, boss: this.wave % 5 === 0 });
  }
  spawnEnemy(type) {
    type =
      type ||
      (this.wave % 5 === 0 && this.spawnLeft === 1
        ? "boss"
        : this.wave >= 3 && this.spawnLeft % 5 === 0
          ? "tank"
          : this.wave >= 2 && this.spawnLeft % 3 === 0
            ? "runner"
            : "bug");
    const mult = Math.pow(1.38, Math.max(0, this.wave - 1));
    const hp = { bug: 27, runner: 18, tank: 92, boss: 650 }[type] * mult;
    const e = {
      id: ++this.id,
      type,
      x: PATH[0][0],
      z: PATH[0][1],
      travel: 0,
      hp,
      maxHp: hp,
      speed:
        { bug: 1.75, runner: 2.8, tank: 1.2, boss: 0.92 }[type] *
        (1 + this.wave * 0.05),
      radius: type === "boss" ? 1.1 : type === "tank" ? 0.64 : 0.4,
      angle: Math.PI / 2,
      hit: 0,
      slow: 0,
      freeze: 0,
      ram: 0,
      bob: this.random() * 6.28,
    };
    if (this.wave >= 3 && this.spawnLeft % 3 === 0 && type !== "boss") {
      e.travel = 53;
      Object.assign(e, pointOnPath(e.travel));
    }
    this.enemies.push(e);
    return e;
  }
  collect(item) {
    if (!this.pickups.includes(item)) return;
    this.pickups.splice(this.pickups.indexOf(item), 1);
    this.addWeapon(item.type);
    this.collected++;
    this.player.momentum = Math.min(1, this.player.momentum + 0.16);
    this.score += 10;
    this.combo = this.comboTimer > 0 ? this.combo + 1 : 1;
    this.comboTimer = 2.5;
    this.player.radius = Math.min(1.28, 0.72 + this.collected * 0.022);
    this.emit("collect", { ...item, combo: this.combo });
  }
  hurt(e, amount) {
    if (e.hp <= 0) return;
    e.hp -= amount;
    e.hit = 0.13;
    if (e.hp <= 0) {
      this.kills++;
      this.score += e.type === "boss" ? 500 : e.type === "tank" ? 50 : 25;
      this.xp += e.type === "boss" ? 70 : e.type === "tank" ? 15 : 8;
      this.emit("kill", { x: e.x, z: e.z, type: e.type });
      if (this.xp >= this.xpNext) {
        this.xp -= this.xpNext;
        this.level++;
        this.xpNext = Math.round(this.xpNext * 1.3);
        this.buffs.damage *= 1.08;
        this.emit("level", { level: this.level });
      }
    }
  }
  dash() {
    if (this.mode !== "playing" || this.player.dashCooldown > 0) return false;
    this.player.dash = 0.24;
    this.player.dashCooldown = 2.2;
    this.emit("dash", { x: this.player.x, z: this.player.z });
    return true;
  }
  ability() {
    if (this.mode !== "playing" || this.player.abilityCooldown > 0)
      return false;
    const p = this.player;
    p.abilityCooldown = this.role.cooldown;
    if (this.classId === "scavenger") {
      this.pickups
        .filter((i) => distance(i, p) < 5.5)
        .forEach((i) => this.collect(i));
      this.enemies
        .filter((e) => distance(e, p) < 5)
        .forEach((e) => this.hurt(e, 40 * this.buffs.damage));
    }
    if (this.classId === "engineer") p.overclock = 6;
    if (this.classId === "warden")
      this.enemies
        .filter((e) => distance(e, p) < 10)
        .forEach((e) => {
          e.freeze = 3;
          this.hurt(e, 38 * this.buffs.damage);
        });
    this.emit("ability", { x: p.x, z: p.z, classId: this.classId });
    return true;
  }
  chooseUpgrade(index) {
    if (this.mode !== "upgrade" || !this.options[index]) return false;
    const id = this.options[index].id;
    if (id === "damage") this.buffs.damage *= 1.25;
    if (id === "haste") this.buffs.haste *= 1.2;
    if (id === "range") this.buffs.range *= 1.2;
    if (id === "magnet") this.buffs.magnet *= 1.35;
    if (id === "speed") this.buffs.speed *= 1.15;
    if (id === "repair") this.base = Math.min(this.maxBase, this.base + 35);
    this.mode = "playing";
    this.waveState = "gather";
    this.waveTimer = 4;
    this.emit("upgrade", { id });
    return true;
  }
  pause() {
    if (this.mode === "playing") {
      this.mode = "paused";
      return true;
    }
    if (this.mode === "paused") {
      this.mode = "playing";
      return true;
    }
    return false;
  }
  refillScrap(n = 5) {
    const types = Object.keys(WEAPONS);
    for (let i = 0; i < n && this.pickups.length < 34; i++) {
      for (let j = 0; j < 40; j++) {
        const x = (this.random() - 0.5) * 24,
          z = (this.random() - 0.5) * 18;
        if (
          validPosition(x, z, 0.4) &&
          !this.pickups.some((p) => Math.hypot(p.x - x, p.z - z) < 1.3)
        ) {
          this.pickups.push({
            id: ++this.id,
            x,
            z,
            type: types[Math.floor(this.random() * 4)],
            born: this.time,
          });
          break;
        }
      }
    }
  }
  update(dt, input = { x: 0, z: 0 }) {
    if (this.mode !== "playing") return;
    dt = clamp(dt, 0, 0.0334);
    this.time += dt;
    const p = this.player;
    for (const key of ["dash", "dashCooldown", "abilityCooldown", "overclock"])
      p[key] = Math.max(0, p[key] - dt);
    this.comboTimer -= dt;
    this.scrapTimer -= dt;
    if (this.scrapTimer <= 0) {
      this.refillScrap(4);
      this.scrapTimer = 8;
    }
    let ix = input.x || 0,
      iz = input.z || 0;
    const il = Math.hypot(ix, iz);
    if (il > 1) {
      ix /= il;
      iz /= il;
    }
    const speed = this.role.speed * this.buffs.speed * (p.dash > 0 ? 2.85 : 1);
    const blend = 1 - Math.exp(-dt * (il ? 21 : 29));
    p.vx += (ix * speed - p.vx) * blend;
    p.vz += (iz * speed - p.vz) * blend;
    const oldX = p.x,
      oldZ = p.z;
    const steps = p.dash > 0 ? 3 : 1;
    for (let step = 0; step < steps; step++) {
      p.x = clamp(
        p.x + (p.vx * dt) / steps,
        -12.65 + p.radius * 0.45,
        12.65 - p.radius * 0.45,
      );
      p.z = clamp(
        p.z + (p.vz * dt) / steps,
        -9.65 + p.radius * 0.45,
        9.65 - p.radius * 0.45,
      );
      const r = p.radius * 0.62;
      for (const w of WALLS) {
        const cx = clamp(p.x, w.x - w.w / 2, w.x + w.w / 2),
          cz = clamp(p.z, w.z - w.h / 2, w.z + w.h / 2);
        const dx = p.x - cx,
          dz = p.z - cz,
          len = Math.hypot(dx, dz);
        if (len < r) {
          if (len > 0.0001) {
            p.x += (dx / len) * (r - len);
            p.z += (dz / len) * (r - len);
          } else {
            const left = Math.abs(p.x - (w.x - w.w / 2)),
              right = Math.abs(p.x - (w.x + w.w / 2)),
              up = Math.abs(p.z - (w.z - w.h / 2)),
              down = Math.abs(p.z - (w.z + w.h / 2));
            const min = Math.min(left, right, up, down);
            if (min === left) p.x = w.x - w.w / 2 - r;
            else if (min === right) p.x = w.x + w.w / 2 + r;
            else if (min === up) p.z = w.z - w.h / 2 - r;
            else p.z = w.z + w.h / 2 + r;
          }
        }
      }
    }
    const rolled = Math.hypot(p.x - oldX, p.z - oldZ);
    p.momentum = clamp(
      p.momentum + (rolled > dt * 0.8 ? dt * 2 : -dt * 0.5),
      0,
      1,
    );
    p.heading += rolled * 0.2 + dt * 0.12;
    const reach = this.role.magnet * this.buffs.magnet + p.radius * 0.25;
    for (const item of [...this.pickups]) {
      const d = distance(item, p);
      if (d < reach) {
        if (d < p.radius + 0.35) this.collect(item);
        else {
          item.x += (p.x - item.x) * dt * 12;
          item.z += (p.z - item.z) * dt * 12;
        }
      }
    }
    if (this.waveState === "gather") {
      this.waveTimer -= dt;
      if (this.waveTimer <= 0) this.startWave();
    }
    if (this.waveState === "assault" && this.spawnLeft > 0) {
      this.spawnTimer -= dt;
      if (this.spawnTimer <= 0) {
        this.spawnEnemy();
        this.spawnLeft--;
        this.spawnTimer = Math.max(0.32, 0.8 - this.wave * 0.025);
      }
    }
    for (const e of this.enemies) {
      if (e.hp <= 0) continue;
      e.hit = Math.max(0, e.hit - dt);
      e.slow = Math.max(0, e.slow - dt);
      e.freeze = Math.max(0, e.freeze - dt);
      e.ram = Math.max(0, e.ram - dt);
      e.travel += e.speed * dt * (e.freeze > 0 ? 0.05 : e.slow > 0 ? 0.52 : 1);
      const pt = pointOnPath(e.travel);
      e.x = pt.x;
      e.z = pt.z;
      e.angle = pt.angle;
      if (pt.done) {
        e.hp = 0;
        const dmg = e.type === "boss" ? 35 : e.type === "tank" ? 15 : 8;
        this.base = Math.max(0, this.base - dmg);
        this.emit("breach", { damage: dmg, x: e.x, z: e.z });
        if (this.base <= 0) {
          this.mode = "gameover";
          this.emit("gameover");
        }
        continue;
      }
      if (distance(e, p) < p.radius + e.radius && e.ram <= 0) {
        this.hurt(e, (p.dash > 0 ? 50 : 8) * this.buffs.damage);
        e.ram = 0.48;
        e.slow = 0.8;
        if (p.dash > 0) this.emit("ram", { x: e.x, z: e.z });
      }
    }
    for (const w of this.weapons) {
      const spec = WEAPONS[w.type];
      w.cooldown -=
        dt *
        this.buffs.haste *
        (0.35 + p.momentum * 0.9) *
        (p.overclock > 0 ? 2 : 1);
      w.recoil = Math.max(0, w.recoil - dt * 5);
      if (w.cooldown > 0) continue;
      const mount = this.mount(w);
      let target = null,
        priority = -Infinity;
      for (const e of this.enemies) {
        if (e.hp <= 0) continue;
        const dx = e.x - mount.x,
          dz = e.z - mount.z,
          d = Math.hypot(dx, dz);
        if (d > spec.range * this.buffs.range || d < 0.01) continue;
        if ((dx * mount.nx + dz * mount.nz) / d < -0.08) continue;
        const urgency = e.travel + (e.type === "boss" ? 7 : 0) - d * 0.4;
        if (urgency > priority) {
          priority = urgency;
          target = e;
        }
      }
      if (target) {
        w.cooldown = spec.cooldown;
        w.recoil = 1;
        w.aim = { x: target.x, z: target.z };
        const shot = {
          id: ++this.id,
          x: mount.x,
          z: mount.z,
          y: p.radius + 0.25,
          target: target.id,
          type: w.type,
          damage: spec.damage * w.power * this.role.damage * this.buffs.damage,
          life: 1.2,
          speed: spec.speed,
        };
        this.projectiles.push(shot);
        this.emit("shot", { x: mount.x, z: mount.z, type: w.type });
      }
    }
    for (const shot of this.projectiles) {
      shot.life -= dt;
      const e = this.enemies.find((e) => e.id === shot.target && e.hp > 0);
      if (!e) {
        shot.life = 0;
        continue;
      }
      const d = distance(shot, e);
      if (d < shot.speed * dt + e.radius * 0.5) {
        this.hurt(e, shot.damage);
        if (this.classId === "warden") e.slow = 1.1;
        const spec = WEAPONS[shot.type];
        if (spec.splash)
          this.enemies
            .filter((other) => other !== e && distance(other, e) < spec.splash)
            .forEach((other) => this.hurt(other, shot.damage * 0.65));
        if (spec.chain) {
          let chain = 0;
          for (const other of this.enemies) {
            if (
              other !== e &&
              other.hp > 0 &&
              distance(other, e) < 3 &&
              chain < spec.chain
            ) {
              this.hurt(other, shot.damage * 0.6);
              this.emit("chain", { x: e.x, z: e.z, tx: other.x, tz: other.z });
              chain++;
            }
          }
        }
        this.emit("impact", { x: e.x, z: e.z, type: shot.type });
        shot.life = 0;
      } else {
        shot.x += ((e.x - shot.x) / d) * shot.speed * dt;
        shot.z += ((e.z - shot.z) / d) * shot.speed * dt;
        shot.y += (0.5 - shot.y) * dt * 6;
      }
    }
    this.enemies = this.enemies.filter((e) => e.hp > 0);
    this.projectiles = this.projectiles.filter((p) => p.life > 0);
    if (
      this.mode === "playing" &&
      this.waveState === "assault" &&
      this.spawnLeft === 0 &&
      this.enemies.length === 0
    ) {
      this.survived = this.wave;
      this.score += 1000 + this.wave * 100;
      this.base = Math.min(this.maxBase, this.base + 8);
      this.mode = "upgrade";
      const pool = [...UPGRADES];
      this.options = [];
      for (let i = 0; i < 3; i++)
        this.options.push(
          pool.splice(Math.floor(this.random() * pool.length), 1)[0],
        );
      this.refillScrap(9);
      this.emit("clear", { wave: this.wave });
    }
  }
}
