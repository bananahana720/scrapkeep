import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { GTAOPass } from "three/addons/postprocessing/GTAOPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";
import * as THREE from "three";
import { WEAPONS } from "./game.js";
import { createHeroModel } from "./heroes.js";
import {
  C,
  mat,
  mesh,
  geos,
  weaponModel,
  enemyModel,
  buildYard,
  makeBallCore,
} from "./art.js";
function glowTexture() {
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = 64;
  const ctx = canvas.getContext("2d"),
    gradient = ctx.createRadialGradient(32, 32, 0, 32, 32, 32);
  gradient.addColorStop(0, "rgba(255,255,255,.6)");
  gradient.addColorStop(0.25, "rgba(255,255,255,.2)");
  gradient.addColorStop(1, "rgba(255,255,255,0)");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, 64, 64);
  return new THREE.CanvasTexture(canvas);
}
export class World {
  constructor(canvas) {
    this.renderer = new THREE.WebGLRenderer({
      canvas,
      antialias: true,
      powerPreference: "high-performance",
    });
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, 1.65));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.VSMShadowMap;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.12;
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(C.navy);
    this.scene.fog = new THREE.Fog(C.navy, 65, 130);
    this.camera = new THREE.OrthographicCamera(-24, 24, 17, -17, 0.1, 180);
    this.camera.position.set(-29, 27, -32);
    this.camera.lookAt(0, 0, 0);
    this.cameraBase = this.camera.position.clone();
    this.scene.add(new THREE.HemisphereLight(0xd9eee6, 0x7a8177, 2.15));
    const sun = new THREE.DirectionalLight(0xffe5bf, 3);
    sun.position.set(15, 28, -12);
    sun.castShadow = true;
    sun.shadow.mapSize.set(1024, 1024);
    Object.assign(sun.shadow.camera, {
      left: -23,
      right: 23,
      top: 23,
      bottom: -23,
      near: 1,
      far: 90,
    });
    sun.shadow.bias = -0.00025;
    sun.shadow.normalBias = 0.04;
    sun.shadow.radius = 12;
    sun.shadow.blurSamples = 8;
    this.scene.add(sun);
    this.ambientTime = 0;
    this.shake = 0;
    this.menuShift = 0;
    this.entityMaps = {
      pickups: new Map(),
      enemies: new Map(),
      weapons: new Map(),
    };
    this.lastRun = -1;
    this.lastX = 1;
    this.lastZ = -2;
    this.buildBoard();
    this.buildPlayer();
    this.glowMap = glowTexture();
    this.addGlow(this.crystal, 0, 1.4, 0, 4.2, C.mint, 0.28);
    this.particleMesh = new THREE.InstancedMesh(
      geos.cube,
      new THREE.MeshBasicMaterial({ color: 0xffffff }),
      600,
    );
    this.particleMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.particleMesh.frustumCulled = false;
    this.scene.add(this.particleMesh);
    this.particles = [];
    this.shotMesh = new THREE.InstancedMesh(
      geos.cube,
      new THREE.MeshBasicMaterial({ color: 0xffffff }),
      220,
    );
    this.shotMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.shotMesh.frustumCulled = false;
    this.scene.add(this.shotMesh);
    this.healthMesh = new THREE.InstancedMesh(
      geos.cube,
      new THREE.MeshBasicMaterial({ color: 0xffffff }),
      180,
    );
    this.healthMesh.frustumCulled = false;
    this.scene.add(this.healthMesh);
    this.dummy = new THREE.Object3D();
    this.color = new THREE.Color();
    this.rings = [];
    this.templates = {
      pickups: Object.fromEntries(
        Object.keys(WEAPONS).map((k) => [k, weaponModel(k, true)]),
      ),
      weapons: Object.fromEntries(
        Object.keys(WEAPONS).map((k) => [k, weaponModel(k)]),
      ),
      enemies: Object.fromEntries(
        ["bug", "runner", "tank", "boss"].map((k) => [k, enemyModel(k)]),
      ),
    };
    this.composer = new EffectComposer(this.renderer);
    this.composer.renderTarget1.samples = 4;
    this.composer.renderTarget2.samples = 4;
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    this.ao = new GTAOPass(
      this.scene,
      this.camera,
      800,
      600,
      undefined,
      { radius: 0.8, samples: 8, thickness: 1, distanceExponent: 2 },
      { radius: 5, samples: 8 },
    );
    this.ao.blendIntensity = 0.8;
    this.composer.addPass(this.ao);
    this.bloom = new UnrealBloomPass(
      new THREE.Vector2(800, 600),
      0.25,
      0.4,
      1.15,
    );
    this.composer.addPass(this.bloom);
    this.composer.addPass(new OutputPass());
    this.renderer.info.autoReset = false;
    this.setQuality(
      new URLSearchParams(location.search).get("quality") === "low" ||
        window.innerWidth < 700,
    );
    this.resize();
    window.addEventListener("resize", () => this.resize());
  }
  setQuality(low) {
    this.lowQuality = low;
    this.renderer.setPixelRatio(
      low ? Math.min(devicePixelRatio, 1) : Math.min(devicePixelRatio, 1.65),
    );
    this.renderer.shadowMap.enabled = !low;
    if (this.composer) this.resize();
  }
  addGlow(parent, x, y, z, size, color, opacity = 0.3) {
    const sprite = new THREE.Sprite(
      new THREE.SpriteMaterial({
        map: this.glowMap,
        color,
        transparent: true,
        opacity,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
      }),
    );
    sprite.position.set(x, y, z);
    sprite.scale.set(size, size, size);
    parent.add(sprite);
    return sprite;
  }
  buildBoard() {
    this.crystal = buildYard(this.scene);
    this.scene.add(this.crystal);
  }
  buildPlayer() {
    this.player = new THREE.Group();
    this.core = makeBallCore();
    this.player.add(this.core);
    this.face = new THREE.Group();
    for (const x of [-0.24, 0.24])
      mesh(this.face, "box", C.mint, x, 0.1, 1.05, 0.15, 0.1, 0.08, C.mint);
    this.player.add(this.face);
    this.scene.add(this.player);
    this.playerHalo = new THREE.Mesh(
      new THREE.RingGeometry(1.05, 1.08, 64),
      new THREE.MeshBasicMaterial({
        color: C.mint,
        transparent: true,
        opacity: 0.65,
        side: THREE.DoubleSide,
        depthWrite: false,
      }),
    );
    this.playerHalo.rotation.x = -Math.PI / 2;
    this.playerHalo.position.y = 0.19;
    this.scene.add(this.playerHalo);
    this.rangeRing = new THREE.Mesh(
      new THREE.RingGeometry(3.8, 3.815, 96),
      new THREE.MeshBasicMaterial({
        color: C.mint,
        transparent: true,
        opacity: 0.13,
        side: THREE.DoubleSide,
        depthWrite: false,
      }),
    );
    this.rangeRing.rotation.x = -Math.PI / 2;
    this.rangeRing.position.y = 0.175;
    this.scene.add(this.rangeRing);
  }
  resize() {
    const w = window.innerWidth,
      h = window.innerHeight;
    this.renderer.setSize(w, h);
    this.composer?.setSize(w, h);
    this.width = w;
    this.height = h;
    this.updateCamera();
  }
  updateCamera() {
    const aspect = this.width / this.height;
    const half = Math.max(12.25, 20.3 / aspect);
    this.camera.left = -half * aspect - this.menuShift;
    this.camera.right = half * aspect - this.menuShift;
    this.camera.top = half + 0.9;
    this.camera.bottom = -half + 0.9;
    this.camera.updateProjectionMatrix();
  }
  screenDirection(x, z) {
    const r = new THREE.Vector3().setFromMatrixColumn(
      this.camera.matrixWorld,
      0,
    );
    r.y = 0;
    r.normalize();
    const d = new THREE.Vector3().setFromMatrixColumn(
      this.camera.matrixWorld,
      1,
    );
    d.y = 0;
    d.normalize().negate();
    return { x: r.x * x + d.x * z, z: r.z * x + d.z * z };
  }
  screenPoint(x, y, z) {
    const v = new THREE.Vector3(x, y, z).project(this.camera);
    return {
      x: ((v.x + 1) / 2) * this.width,
      y: ((1 - v.y) / 2) * this.height,
    };
  }
  floorPoint(clientX, clientY) {
    const ray = new THREE.Raycaster();
    ray.setFromCamera(
      new THREE.Vector2(
        (clientX / this.width) * 2 - 1,
        (-clientY / this.height) * 2 + 1,
      ),
      this.camera,
    );
    return ray.ray.intersectPlane(
      new THREE.Plane(new THREE.Vector3(0, 1, 0), 0),
      new THREE.Vector3(),
    );
  }
  burst(x, z, color, count = 12, power = 3) {
    for (let i = 0; i < count && this.particles.length < 590; i++) {
      const a = Math.random() * 6.283,
        force = Math.random() * power;
      this.particles.push({
        x,
        y: 0.5 + Math.random() * 0.5,
        z,
        vx: Math.cos(a) * force,
        vz: Math.sin(a) * force,
        vy: 1.5 + Math.random() * 3,
        life: 0.35 + Math.random() * 0.5,
        max: 0.9,
        size: 0.05 + Math.random() * 0.12,
        color,
      });
    }
  }
  ring(x, z, color, size = 5) {
    const m = new THREE.Mesh(
      new THREE.RingGeometry(0.93, 1, 64),
      new THREE.MeshBasicMaterial({
        color,
        transparent: true,
        opacity: 0.75,
        side: THREE.DoubleSide,
        depthWrite: false,
      }),
    );
    m.rotation.x = -Math.PI / 2;
    m.position.set(x, 0.2, z);
    this.scene.add(m);
    this.rings.push({ m, time: 0, size });
  }
  event(e) {
    if (e.type === "shot" && this.particles.length < 580) {
      this.particles.push({
        x: e.x,
        y: e.y,
        z: e.z,
        vx: 0,
        vz: 0,
        vy: 0,
        life: 0.09,
        max: 0.09,
        size: 0.23,
        color: 0xffe3a0,
      });
    }

    if (e.type === "collect") {
      this.burst(e.x, e.z, WEAPONS[e.kind].color, 16, 2);
      this.shake = Math.max(this.shake, 0.045);
    }
    if (e.type === "kill") {
      this.burst(e.x, e.z, C.orange, e.kind === "boss" ? 50 : 15, 4);
      this.shake = Math.max(this.shake, e.kind === "boss" ? 0.24 : 0.065);
    }
    if (e.type === "impact")
      this.burst(e.x, e.z, WEAPONS[e.kind].color, 3, 1.4);
    if (e.type === "dash") {
      this.burst(e.x, e.z, C.mint, 12, 2);
      this.shake = 0.05;
    }
    if (e.type === "ability") {
      this.ring(
        e.x,
        e.z,
        e.classId === "warden" ? 0xa7c9f5 : C.mint,
        e.classId === "warden" ? 10 : 7,
      );
      this.burst(e.x, e.z, C.mint, 45, 7);
      this.shake = 0.18;
    }
    if (e.type === "breach") {
      this.shake = 0.38;
      this.burst(3, 8, C.orange, 32, 5);
      this.ring(3, 8, C.orange, 3);
    }
    if (e.type === "ram") {
      this.shake = 0.1;
      this.burst(e.x, e.z, C.orange, 8, 3);
    }
    if (e.type === "chain") {
      for (let i = 0; i < 7; i++) {
        const t = i / 7;
        this.burst(
          e.x + (e.tx - e.x) * t,
          e.z + (e.tz - e.z) * t,
          C.mint,
          1,
          0.3,
        );
      }
    }
    if (e.type === "level" || e.type === "clear")
      this.ring(this.player.position.x, this.player.position.z, C.mint, 4);
  }
  clearDynamic() {
    for (const map of Object.values(this.entityMaps)) {
      for (const mesh of map.values()) this.scene.remove(mesh);
      map.clear();
    }
    this.particles = [];
    for (const r of this.rings) {
      this.scene.remove(r.m);
      r.m.geometry.dispose();
      r.m.material.dispose();
    }
    this.rings = [];
    this.core.quaternion.identity();
  }
  syncEntities(list, key, update) {
    const map = this.entityMaps[key],
      live = new Set(list.map((e) => e.id));
    for (const [id, o] of map) {
      if (!live.has(id)) {
        this.scene.remove(o);
        map.delete(id);
      }
    }
    for (const e of list) {
      let o = map.get(e.id);
      if (!o) {
        o = this.templates[key][e.type].clone();
        map.set(e.id, o);
        this.scene.add(o);
      }
      update(o, e);
    }
  }
  render(game, dt) {
    this.ambientTime += dt;
    const t = this.ambientTime,
      p = game.player,
      menu = game.mode === "menu";
    const target = menu && this.width > 900 ? 7 : 0;
    const next = THREE.MathUtils.damp(this.menuShift, target, 6, dt);
    if (Math.abs(next - this.menuShift) > 0.002) {
      this.menuShift = next;
      this.updateCamera();
    }
    if (game.time < this.lastRun) this.clearDynamic();
    this.lastRun = game.time;
    const rollingDistance = Math.hypot(p.x - this.lastX, p.z - this.lastZ);
    if (rollingDistance > 0.0001 && rollingDistance < 1) {
      const axis = new THREE.Vector3(
        p.z - this.lastZ,
        0,
        -(p.x - this.lastX),
      ).normalize();
      this.core.quaternion.premultiply(
        new THREE.Quaternion().setFromAxisAngle(
          axis,
          rollingDistance / p.radius,
        ),
      );
    }
    this.lastX = p.x;
    this.lastZ = p.z;
    const bounce = menu
      ? Math.sin(t * 2) * 0.04
      : Math.min(0.08, rollingDistance * 0.35) * Math.sin(t * 25);
    this.player.position.set(p.x, p.radius + 0.16 + bounce, p.z);
    const squash = 1 + (p.dash > 0 ? 0.09 : 0);
    this.player.scale.set(p.radius * squash, p.radius / squash, p.radius);
    this.face.visible = false;
    if (this.heroClass !== game.classId) {
      if (this.hero) this.scene.remove(this.hero);
      this.hero = createHeroModel(game.classId);
      this.heroClass = game.classId;
      this.hero.scale.setScalar(0.9);
      this.scene.add(this.hero);
    }
    this.hero.position.set(p.x, p.radius * 2 + 0.12 + bounce, p.z);
    this.hero.rotation.y =
      Math.atan2(this.cameraBase.x, this.cameraBase.z) +
      Math.sin(t * 1.4) * 0.08;
    this.hero.rotation.z = -p.vx * 0.009;
    this.playerHalo.position.set(p.x, 0.19, p.z);
    this.playerHalo.scale.setScalar(p.radius);
    this.playerHalo.material.opacity = p.dashCooldown === 0 ? 0.65 : 0.25;
    this.rangeRing.position.set(p.x, 0.175, p.z);
    this.rangeRing.scale.setScalar(game.buffs.range);
    this.rangeRing.visible = game.mode === "playing";
    this.crystal.position.y = 1.15 + Math.sin(t * 1.8) * 0.045;
    this.crystal.rotation.y = Math.sin(t * 0.5) * 0.02;
    this.syncEntities(game.pickups, "pickups", (o, e) => {
      o.position.set(e.x, 0.22 + Math.sin(t * 2 + e.id) * 0.045, e.z);
      o.rotation.y = e.id * 0.81 + Math.sin(t * 0.6 + e.id) * 0.1;
      const grow = Math.min(1, (game.time - e.born) * 3);
      o.scale.setScalar(1.18 * Math.max(0.1, grow));
    });
    this.syncEntities(game.enemies, "enemies", (o, e) => {
      const scale =
        e.type === "boss"
          ? 2.55
          : e.type === "tank"
            ? 1.4
            : e.type === "runner"
              ? 0.85
              : 1;
      o.position.set(
        e.x,
        0.13 + Math.abs(Math.sin(t * (e.freeze > 0 ? 1 : 14) + e.bob)) * 0.08,
        e.z,
      );
      o.rotation.set(0, e.angle, Math.sin(t * 12 + e.bob) * 0.07);
      o.scale.setScalar(scale * (e.hit > 0 ? 1.1 : 1));
    });
    this.syncEntities(game.weapons, "weapons", (o, w) => {
      const m = game.mount(w);
      const normal = new THREE.Vector3(m.nx, m.ny, m.nz);
      o.position.set(m.x, m.y, m.z);
      o.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), normal);
      o.scale.setScalar(0.78 + Math.min(0.22, game.collected * 0.005));
      o.position.addScaledVector(normal, -w.recoil * 0.1);
    });
    const hurtEnemies = game.enemies
      .filter((e) => e.hp < e.maxHp || e.type === "boss")
      .slice(0, 90);
    this.healthMesh.count = hurtEnemies.length * 2;
    hurtEnemies.forEach((e, i) => {
      const width = e.type === "boss" ? 2.3 : 0.9,
        y = e.type === "boss" ? 2.8 : e.type === "tank" ? 1.7 : 1.2;
      this.dummy.quaternion.copy(this.camera.quaternion);
      this.dummy.position.set(e.x, y, e.z);
      this.dummy.scale.set(width, 0.075, 0.035);
      this.dummy.updateMatrix();
      this.healthMesh.setMatrixAt(i * 2, this.dummy.matrix);
      this.healthMesh.setColorAt(i * 2, this.color.set(C.dark));
      this.dummy.position.y += 0.007;
      this.dummy.position.addScaledVector(
        this.cameraBase.clone().normalize(),
        0.06,
      );
      this.dummy.scale.x = width * Math.max(0, e.hp / e.maxHp);
      this.dummy.updateMatrix();
      this.healthMesh.setMatrixAt(i * 2 + 1, this.dummy.matrix);
      this.healthMesh.setColorAt(
        i * 2 + 1,
        this.color.set(e.freeze > 0 ? C.mint : C.orange),
      );
    });
    this.healthMesh.instanceMatrix.needsUpdate = true;
    if (this.healthMesh.instanceColor)
      this.healthMesh.instanceColor.needsUpdate = true;
    this.shotMesh.count = Math.min(game.projectiles.length, 220);
    game.projectiles.slice(0, 220).forEach((s, i) => {
      this.dummy.position.set(s.x, s.y, s.z);
      const target = game.enemies.find((e) => e.id === s.target);
      const direction = new THREE.Vector3(
        target ? target.x - s.x : 0,
        target
          ? (target.type === "boss"
              ? 1.45
              : target.type === "tank"
                ? 0.85
                : 0.6) - s.y
          : 0,
        target ? target.z - s.z : 1,
      ).normalize();
      this.dummy.quaternion.setFromUnitVectors(
        new THREE.Vector3(0, 0, 1),
        direction,
      );
      this.dummy.scale.set(
        s.type === "pipe" ? 0.18 : 0.065,
        0.055,
        s.type === "pipe" ? 0.3 : 0.8,
      );
      this.dummy.updateMatrix();
      this.shotMesh.setMatrixAt(i, this.dummy.matrix);
      this.shotMesh.setColorAt(
        i,
        this.color.set(WEAPONS[s.type].color).multiplyScalar(3),
      );
    });
    this.shotMesh.instanceMatrix.needsUpdate = true;
    if (this.shotMesh.instanceColor)
      this.shotMesh.instanceColor.needsUpdate = true;
    if (
      game.mode === "playing" &&
      rollingDistance > 0.025 &&
      Math.random() < 0.55
    )
      this.particles.push({
        x: p.x,
        y: 0.2,
        z: p.z,
        vx: 0,
        vz: 0,
        vy: 0.2,
        life: 0.3,
        max: 0.3,
        size: p.dash > 0 ? 0.15 : 0.06,
        color: p.dash > 0 ? C.mint : 0x809591,
      });
    this.particles = this.particles.filter((part) => {
      part.life -= dt;
      if (part.life <= 0) return false;
      part.x += part.vx * dt;
      part.z += part.vz * dt;
      part.y += part.vy * dt;
      part.vy -= dt * 7;
      if (part.y < 0.14) {
        part.y = 0.14;
        part.vy *= -0.3;
      }
      return true;
    });
    this.particleMesh.count = this.particles.length;
    this.particles.forEach((a, i) => {
      this.dummy.position.set(a.x, a.y, a.z);
      this.dummy.rotation.set(t * 2 + i, t * 3 + i, 0);
      this.dummy.scale.setScalar(a.size * Math.min(1, a.life * 4));
      this.dummy.updateMatrix();
      this.particleMesh.setMatrixAt(i, this.dummy.matrix);
      this.particleMesh.setColorAt(i, this.color.set(a.color));
    });
    this.particleMesh.instanceMatrix.needsUpdate = true;
    if (this.particleMesh.instanceColor)
      this.particleMesh.instanceColor.needsUpdate = true;
    this.rings = this.rings.filter((r) => {
      r.time += dt;
      r.m.scale.setScalar(0.3 + r.time * r.size * 2);
      r.m.material.opacity = (1 - r.time * 1.7) * 0.65;
      if (r.time > 0.58) {
        this.scene.remove(r.m);
        r.m.geometry.dispose();
        r.m.material.dispose();
        return false;
      }
      return true;
    });
    this.shake = Math.max(0, this.shake - dt * 1.2);
    this.camera.position.copy(this.cameraBase);
    this.camera.position.x += (Math.random() - 0.5) * this.shake;
    this.camera.position.y += (Math.random() - 0.5) * this.shake;
    this.renderer.info.reset();
    if (this.lowQuality) this.renderer.render(this.scene, this.camera);
    else this.composer.render(dt);
  }
}
