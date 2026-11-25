import * as THREE from "three";
import { mergeGeometries } from "three/addons/utils/BufferGeometryUtils.js";
import { groundHeight } from "./simulation.js";
import {
  createHero,
  updateHero,
  createEnemy,
  updateEnemy,
  createPickup,
  createCompanion,
  createConductor,
  createGreenhouse,
} from "./models.js";

const palette = {
  soil: 0xbbae7e,
  path: 0xd4c59a,
  sage: 0x718a61,
  leaf: 0x4b7445,
  lightLeaf: 0x8aa45b,
  cream: 0xeee2bb,
  dark: 0x23443b,
  orange: 0xf28c42,
  mint: 0x8ee6c0,
};
const UP = new THREE.Vector3(0, 1, 0);
const clamp = (n, min, max) => Math.max(min, Math.min(max, n));
function material(color, roughness = 0.85) {
  return new THREE.MeshStandardMaterial({ color, roughness });
}
function box(parent, material, x, y, z, sx, sy, sz) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), material);
  mesh.position.set(x, y, z);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}
function batch(group) {
  const bins = new Map();
  group.updateMatrixWorld(true);
  group.traverse((o) => {
    if (!o.isMesh || Array.isArray(o.material)) return;
    const geometry = o.geometry.clone().applyMatrix4(o.matrixWorld);
    if (!bins.has(o.material)) bins.set(o.material, []);
    bins.get(o.material).push(geometry);
  });
  const out = new THREE.Group();
  for (const [mat, geometries] of bins) {
    const merged = mergeGeometries(geometries, false);
    if (merged) {
      const mesh = new THREE.Mesh(merged, mat);
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      out.add(mesh);
    }
    for (const g of geometries) g.dispose();
  }
  return out;
}
function rng(seed) {
  return () => {
    seed = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    seed ^= seed + Math.imul(seed ^ (seed >>> 7), 61 | seed);
    return ((seed ^ (seed >>> 14)) >>> 0) / 4294967296;
  };
}

export class OrchardScene {
  constructor(canvas) {
    this.canvas = canvas;
    this.renderer = new THREE.WebGLRenderer({
      canvas,
      antialias: true,
      powerPreference: "high-performance",
    });
    this.low = new URLSearchParams(location.search).has("low") || innerWidth < 760;
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, this.low ? 1 : 1.6));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.25;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0xb4cbd0);
    this.scene.fog = new THREE.Fog(0xb4cbd0, 48, 110);
    this.camera = new THREE.PerspectiveCamera(65, 1, 0.12, 180);
    this.yaw = 0;
    this.pitch = 0.24;
    this.zoom = 1;
    this.view = { aiming: false, sensitivity: 1, impactShake: 0.35 };
    this.focusBlend = 0;
    this.cameraReady = false;
    this.shake = 0;
    this.follow = new THREE.Vector3();
    this.raycaster = new THREE.Raycaster();
    this.blockers = [];
    this.tmp = new THREE.Vector3();
    this.target = new THREE.Vector3();
    this.scene.add(new THREE.HemisphereLight(0xe2f2ee, 0x84714e, 2.25));
    const sun = new THREE.DirectionalLight(0xffe8b8, 3.2);
    sun.position.set(-24, 38, 12);
    sun.castShadow = true;
    sun.shadow.mapSize.set(this.low ? 1024 : 2048, this.low ? 1024 : 2048);
    Object.assign(sun.shadow.camera, {
      left: -44,
      right: 44,
      top: 48,
      bottom: -48,
      near: 1,
      far: 100,
    });
    sun.shadow.bias = -0.0003;
    sun.shadow.normalBias = 0.08;
    this.scene.add(sun);
    const rim = new THREE.DirectionalLight(0xd4edec, 0.8);
    rim.position.set(12, 10, -35);
    this.scene.add(rim);
    this.buildEnvironment();
    this.hero = createHero();
    this.scene.add(this.hero);
    this.enemies = new Map();
    this.enemyPool = new Map();
    this.conductors = new Map();
    this.conductorPool = [];
    this.pickups = new Map();
    this.pickupPool = new Map();
    this.hazards = new Map();
    this.companion = createCompanion();
    this.companion.visible = false;
    this.scene.add(this.companion);
    this.effects = [];
    this.effectGeo = new THREE.CylinderGeometry(1, 1, 1, 6);
    this.effectPool = [];
    this.preview = this.makeAttackVisual();
    this.preview.group.visible = false;
    this.conductorLink = this.makeAttackVisual();
    this.particles = [];
    this.particleMesh = new THREE.InstancedMesh(
      new THREE.BoxGeometry(0.1, 0.1, 0.1),
      new THREE.MeshBasicMaterial({ color: 0xffffff }),
      220,
    );
    this.particleMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.particleMesh.frustumCulled = false;
    this.particleMesh.count = 0;
    this.scene.add(this.particleMesh);
    this.dummy = new THREE.Object3D();
    this.resize();
  }
  buildEnvironment() {
    const geo = new THREE.PlaneGeometry(100, 116, 40, 116);
    geo.rotateX(-Math.PI / 2);
    const positions = geo.attributes.position,
      colors = [];
    const a = new THREE.Color(),
      random = rng(83451);
    for (let i = 0; i < positions.count; i++) {
      const x = positions.getX(i),
        z = positions.getZ(i);
      positions.setY(i, groundHeight(x, z) - 0.07 + (Math.abs(x) > 19 ? random() * 0.14 : 0));
      const inPath = Math.abs(x) < 18.9;
      const c = inPath ? (Math.abs(x) < 7 ? palette.path : palette.soil) : palette.sage;
      a.setHex(c).multiplyScalar(0.96 + random() * 0.08);
      colors.push(a.r, a.g, a.b);
    }
    geo.setAttribute("color", new THREE.Float32BufferAttribute(colors, 3));
    geo.computeVertexNormals();
    const ground = new THREE.Mesh(
      geo,
      new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 1 }),
    );
    ground.receiveShadow = true;
    this.scene.add(ground);

    const deco = new THREE.Group(),
      wood = material(0x847353),
      cream = material(palette.cream),
      iron = material(palette.dark),
      stone = material(0xa6a08a),
      green = material(0x607752);
    for (const side of [-1, 1]) {
      for (let z = -36; z < 28; z += 4) {
        const y = groundHeight(side * 20, z);
        box(deco, wood, side * 20.1, y + 0.75, z, 0.18, 1.5, 0.18);
        box(deco, wood, side * 20.1, y + 0.9, z + 1.9, 0.11, 0.15, 3.8);
        box(deco, wood, side * 20.1, y + 0.4, z + 1.9, 0.11, 0.12, 3.8);
        box(deco, stone, side * 19.8, y + 0.13, z + 1.9, 0.45, 0.25, 3.6);
      }
      for (let z = 19; z > -34; z -= 17) {
        const y = groundHeight(side * 22, z);
        box(deco, cream, side * 22, y + 0.62, z, 3.4, 0.15, 4.8);
        for (const dz of [-1.9, 1.9])
          for (const dx of [-1.3, 1.3])
            box(deco, wood, side * 22 + dx, y + 0.3, z + dz, 0.15, 0.6, 0.15);
        for (let i = 0; i < 4; i++) box(deco, wood, side * 22, y + 0.86, z - 1.5 + i, 3, 0.35, 0.7);
      }
      for (let z = -18; z < 24; z += 14) {
        const x = side * 18.7,
          y = groundHeight(x, z);
        box(deco, iron, x, y + 1.9, z, 0.12, 3.8, 0.12);
        box(deco, cream, x, y + 3.7, z, 0.65, 0.8, 0.6);
        box(deco, green, x, y + 4.2, z, 0.85, 0.13, 0.8);
      }
    }
    for (let x = -19; x <= 19; x += 2) {
      box(deco, stone, x, 0.18, 27.5, 1.8, 0.35, 0.6);
      box(deco, stone, x, 2.65, -37.4, 1.8, 0.35, 0.6);
    }
    this.scene.add(batch(deco));
    const trunkGeo = new THREE.CylinderGeometry(0.18, 0.31, 3.1, 7),
      leafGeo = new THREE.IcosahedronGeometry(1, 1),
      appleGeo = new THREE.SphereGeometry(0.12, 6, 5);
    const trunks = [],
      leaves = [],
      apples = [];
    for (const side of [-1, 1])
      for (let row = 0; row < 3; row++)
        for (let z = -40; z < 39; z += 6) {
          const x = side * (23 + row * 6) + (random() - 0.5),
            zz = z + (random() - 0.5),
            h = groundHeight(x, zz);
          trunks.push([x, h + 1.5, zz, 0.85 + random() * 0.2]);
          for (let k = 0; k < 3; k++)
            leaves.push([
              x + (k - 1) * 0.75,
              h + 3.2 + random() * 0.6,
              zz + (random() - 0.5) * 0.7,
              1.2 + random() * 0.5,
            ]);
          for (let k = 0; k < 6; k++)
            apples.push([
              x + (random() - 0.5) * 2.4,
              h + 2.5 + random() * 1.5,
              zz + (random() - 0.5) * 1.5,
              1,
            ]);
        }
    const instance = (geometry, mat, arr, stretch = [1, 1, 1]) => {
      const m = new THREE.InstancedMesh(geometry, mat, arr.length),
        d = new THREE.Object3D();
      arr.forEach(([x, y, z, s], i) => {
        d.position.set(x, y, z);
        d.scale.set(s * stretch[0], s * stretch[1], s * stretch[2]);
        d.updateMatrix();
        m.setMatrixAt(i, d.matrix);
      });
      m.castShadow = true;
      m.receiveShadow = true;
      this.scene.add(m);
      return m;
    };
    instance(trunkGeo, wood, trunks);
    instance(leafGeo, material(palette.leaf), leaves, [1, 1.1, 0.9]);
    instance(appleGeo, material(0xc7703e), apples);
    const grass = [];
    for (let i = 0; i < 900; i++) {
      const x = (random() < 0.5 ? -1 : 1) * (20.5 + random() * 23),
        z = -44 + random() * 88;
      grass.push([x, groundHeight(x, z) + 0.18, z, 0.6 + random()]);
    }
    instance(new THREE.ConeGeometry(0.14, 0.45, 3), material(0x7b8c4a), grass);

    const house = createGreenhouse();
    house.position.set(0, 2.5, -43);
    this.scene.add(house);
    const houseBlock = new THREE.Box3(
      new THREE.Vector3(-11, 2.5, -49),
      new THREE.Vector3(11, 15.5, -37.5),
    );
    const proxy = new THREE.Mesh(
      new THREE.BoxGeometry(22, 13, 11.5),
      new THREE.MeshBasicMaterial({ visible: false, side: THREE.DoubleSide }),
    );
    proxy.position.copy(houseBlock.getCenter(new THREE.Vector3()));
    proxy.updateMatrixWorld();
    this.blockers.push(proxy);
    this.sign("THE IRON ORCHARD", -14, 0, 22, 0.12);
    this.sign("CUTTINGS / 01", -16, 0, 7, 0.2);
    this.sign("SUPPORT ROW / 02", 15, 0, -5, -0.15);
    this.sign("SEEDHOUSE / 03", -16, groundHeight(0, -22), -22, 0.12);
    this.makeTracks();
  }
  sign(text, x, y, z, rotation) {
    const canvas = document.createElement("canvas");
    canvas.width = 1024;
    canvas.height = 128;
    const c = canvas.getContext("2d");
    c.fillStyle = "#e8ddb5";
    c.fillRect(0, 0, 1024, 128);
    c.strokeStyle = "#667252";
    c.lineWidth = 12;
    c.strokeRect(8, 8, 1008, 112);
    c.fillStyle = "#344c3c";
    c.font = "bold 55px sans-serif";
    c.textAlign = "center";
    c.textBaseline = "middle";
    c.fillText(text, 512, 67);
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    const group = new THREE.Group();
    group.position.set(x, y, z);
    group.rotation.y = rotation;
    const board = new THREE.Mesh(new THREE.BoxGeometry(5, 0.75, 0.14), material(palette.cream));
    board.position.y = 2;
    group.add(board);
    const front = new THREE.Mesh(
      new THREE.PlaneGeometry(4.9, 0.65),
      new THREE.MeshBasicMaterial({ map: texture }),
    );
    front.position.set(0, 2, 0.08);
    group.add(front);
    for (const xx of [-1.8, 1.8]) box(group, material(0x776449), xx, 1, 0, 0.1, 2, 0.1);
    this.scene.add(group);
  }
  makeTracks() {
    const mats = new THREE.MeshBasicMaterial({
      color: 0xa59471,
      transparent: true,
      opacity: 0.35,
      depthWrite: false,
    });
    for (const [cx, cz, r] of [
      [-4, 8, 5.8],
      [6, -4, 5.4],
      [0, -26, 10.5],
    ]) {
      const points = [];
      for (let i = 0; i <= 80; i++) {
        const a = (i / 80) * Math.PI * 2,
          x = cx + Math.cos(a) * r,
          z = cz + Math.sin(a) * r;
        points.push(new THREE.Vector3(x, groundHeight(x, z) + 0.018, z));
      }
      const curve = new THREE.CatmullRomCurve3(points);
      this.scene.add(new THREE.Mesh(new THREE.TubeGeometry(curve, 80, 0.038, 3, false), mats));
    }
  }
  resize() {
    this.renderer.setSize(innerWidth, innerHeight, false);
    this.camera.aspect = innerWidth / innerHeight;
    this.camera.updateProjectionMatrix();
  }
  setView({ aiming, sensitivity, impactShake } = {}) {
    if (aiming !== undefined) this.view.aiming = !!aiming;
    if (Number.isFinite(sensitivity)) this.view.sensitivity = clamp(sensitivity, 0.2, 3);
    if (Number.isFinite(impactShake)) this.view.impactShake = clamp(impactShake, 0, 1);
  }
  orbit(dx, dy) {
    this.yaw += dx * 0.003 * this.view.sensitivity;
    this.pitch = clamp(this.pitch + dy * 0.002 * this.view.sensitivity, -1.22, 1.22);
    if (this.lastPlayer) this.frameCamera(this.lastPlayer, 0);
  }
  resetCamera() {
    this.yaw = 0;
    this.pitch = 0.24;
    this.focusBlend = 0;
    this.cameraReady = false;
    this.lastPlayer = null;
  }
  aimRay() {
    this.camera.updateMatrixWorld();
    this.raycaster.setFromCamera({ x: 0, y: 0 }, this.camera);
    const { origin, direction } = this.raycaster.ray;
    return {
      origin: { x: origin.x, y: origin.y, z: origin.z },
      direction: { x: direction.x, y: direction.y, z: direction.z },
    };
  }
  frameCamera(p, dt) {
    this.lastPlayer = p;
    const direction = new THREE.Vector3(
      Math.sin(this.yaw) * Math.cos(this.pitch),
      -Math.sin(this.pitch),
      -Math.cos(this.yaw) * Math.cos(this.pitch),
    );
    const right = new THREE.Vector3(Math.cos(this.yaw), 0, Math.sin(this.yaw));
    const focus = new THREE.Vector3(p.x, p.y + 0.55, p.z);
    if (!this.cameraReady) {
      this.follow.copy(focus);
      this.cameraReady = true;
    }
    this.follow.lerp(focus, 1 - Math.exp(-dt * 22));
    this.focusBlend += ((this.view.aiming ? 1 : 0) - this.focusBlend) * (1 - Math.exp(-dt * 12));
    const distance = (6.4 + p.radius * 1.2 - this.focusBlend * 2.4) * this.zoom;
    const pivot = this.follow.clone().addScaledVector(right, 1.05);
    const desired = pivot.clone().addScaledVector(direction, -distance);
    const delta = desired.clone().sub(this.follow);
    this.raycaster.set(this.follow, delta.clone().normalize());
    this.raycaster.far = delta.length();
    const hit = this.raycaster.intersectObjects(this.blockers, false)[0];
    if (hit)
      desired.copy(this.follow).addScaledVector(delta.normalize(), Math.max(1, hit.distance - 0.5));
    desired.y = Math.max(desired.y, groundHeight(desired.x, desired.z) + 0.65);
    this.camera.position.copy(desired);
    this.target.copy(pivot).addScaledVector(direction, 30);
    if (this.shake > 0 && this.view.impactShake > 0) {
      const shake = this.shake * this.view.impactShake;
      this.camera.position.x += Math.sin(performance.now() * 0.079) * shake * 0.045;
      this.camera.position.y += Math.cos(performance.now() * 0.06) * shake * 0.03;
    }
    this.shake = Math.max(0, this.shake - dt * 5);
    this.camera.fov = 65 - this.focusBlend * 12;
    this.camera.updateProjectionMatrix();
    this.camera.lookAt(this.target);
    this.camera.updateMatrixWorld();
    this.raycaster.far = Infinity;
  }
  screenPoint(x, y, z) {
    this.tmp.set(x, y, z).project(this.camera);
    return {
      x: (this.tmp.x * 0.5 + 0.5) * innerWidth,
      y: (-0.5 * this.tmp.y + 0.5) * innerHeight,
      visible:
        this.tmp.z < 1 && this.tmp.z > -1 && Math.abs(this.tmp.x) <= 1 && Math.abs(this.tmp.y) <= 1,
      behind: this.tmp.z > 1,
    };
  }
  update(game, dt) {
    updateHero(this.hero, game.player, dt, game.time);
    for (const e of game.enemies) {
      if (e.state === "dead") continue;
      if (!this.enemies.has(e.id)) {
        const m = this.enemyPool.get(e.kind)?.pop() || createEnemy(e.kind);
        this.scene.add(m);
        this.enemies.set(e.id, m);
      }
      const model = this.enemies.get(e.id);
      updateEnemy(model, e, game.time);
    }
    const ids = new Set(game.enemies.filter((e) => e.state !== "dead").map((e) => e.id));
    for (const [id, m] of this.enemies)
      if (!ids.has(id)) {
        this.poolEnemy(m);
        this.enemies.delete(id);
      }
    for (const p of game.pickups) {
      if (p.collected) {
        if (this.pickups.has(p.id)) {
          this.poolPickup(this.pickups.get(p.id));
          this.pickups.delete(p.id);
        }
        continue;
      }
      if (!this.pickups.has(p.id)) {
        const m = this.pickupPool.get(p.kind)?.pop() || createPickup(p.kind);
        m.userData.pickupKind = p.kind;
        this.scene.add(m);
        this.pickups.set(p.id, m);
      }
      const m = this.pickups.get(p.id);
      m.position.set(
        p.x,
        (p.y ?? groundHeight(p.x, p.z)) + 0.35 + Math.sin(game.time * 2 + p.x) * 0.12,
        p.z,
      );
      m.rotation.y = game.time * 0.7 + p.x;
    }
    const pids = new Set(game.pickups.filter((p) => !p.collected).map((p) => p.id));
    for (const [id, m] of this.pickups)
      if (!pids.has(id)) {
        this.poolPickup(m);
        this.pickups.delete(id);
      }
    const buddy = game.companion;
    this.companion.visible = !!buddy?.active && buddy.enabled !== false;
    if (this.companion.visible) {
      this.companion.position.set(buddy.x, buddy.y, buddy.z);
      this.companion.rotation.y = -(buddy.yaw || 0);
      if (this.companion.userData.shears) {
        const s = this.companion.userData.shears;
        if (Array.isArray(s))
          s.forEach((g, i) => (g.rotation.y = (i ? 1 : -1) * (0.18 + (buddy.flash || 0) * 0.5)));
      }
    }
    this.updateConductors(game.conductors || []);
    this.updateAttackVisual(
      this.conductorLink,
      game.conductorLinks?.length
        ? {
            valid: true,
            segments: game.conductorLinks,
            corridors: game.conductorLinks,
          }
        : null,
      0.6,
      0x74ffe3,
    );
    this.updateAttackVisual(this.preview, game.mode === "playing" ? game.targeting : null);
    this.updateHazards(game.hazards || []);
    this.updateEffects(dt);
    this.frameCamera(game.player, dt);
    this.renderer.render(this.scene, this.camera);
  }
  makeAttackVisual() {
    const group = new THREE.Group();
    const mat = new THREE.MeshBasicMaterial({
      color: 0xafffff,
      transparent: true,
      depthWrite: false,
    });
    const backingMaterial = new THREE.MeshBasicMaterial({
      color: 0x10252c,
      transparent: true,
      opacity: 0.95,
      depthWrite: false,
      side: THREE.DoubleSide,
    });
    const halos = Array.from({ length: 32 }, () => {
      const mesh = new THREE.Mesh(this.effectGeo, backingMaterial);
      mesh.visible = false;
      mesh.renderOrder = 1;
      group.add(mesh);
      return mesh;
    });
    const pieces = Array.from({ length: 32 }, () => {
      const mesh = new THREE.Mesh(this.effectGeo, mat);
      mesh.visible = false;
      mesh.renderOrder = 2;
      group.add(mesh);
      return mesh;
    });
    const ringGeometry = new THREE.BufferGeometry();
    ringGeometry.setAttribute(
      "position",
      new THREE.BufferAttribute(new Float32Array(64 * 6 * 3), 3).setUsage(THREE.DynamicDrawUsage),
    );
    const ring = new THREE.Mesh(ringGeometry, mat);
    ring.material.side = THREE.DoubleSide;
    const ringBacking = new THREE.Mesh(ringGeometry.clone(), backingMaterial);
    ringBacking.renderOrder = 1;
    ring.renderOrder = 2;
    group.add(ringBacking, ring);
    const marker = new THREE.Mesh(new THREE.IcosahedronGeometry(0.11, 0), mat);
    group.add(marker);
    const corridors = Array.from({ length: 2 }, () => {
      const corridor = new THREE.Group();
      const geometry = () => {
        const result = new THREE.BufferGeometry();
        result.setAttribute(
          "position",
          new THREE.BufferAttribute(new Float32Array(42 * 6 * 3), 3).setUsage(
            THREE.DynamicDrawUsage,
          ),
        );
        return result;
      };
      const fillMaterial = mat.clone();
      const body = new THREE.Mesh(geometry(), fillMaterial);
      const footprint = new THREE.Mesh(geometry(), mat);
      const footprintBacking = new THREE.Mesh(geometry(), backingMaterial);
      footprintBacking.renderOrder = 1;
      footprint.renderOrder = 2;
      const outline = new THREE.LineSegments(
        geometry(),
        new THREE.LineBasicMaterial({ transparent: true, depthWrite: false }),
      );
      corridor.add(body, footprintBacking, footprint, outline);
      corridor.visible = false;
      group.add(corridor);
      return { group: corridor, body, footprint, footprintBacking, outline };
    });
    group.visible = false;
    this.scene.add(group);
    return {
      group,
      mat,
      backingMaterial,
      pieces,
      halos,
      ring,
      ringBacking,
      marker,
      corridors,
    };
  }
  updateAttackVisual(record, attack, opacity = 0.85, color) {
    record.group.visible = !!attack;
    if (!attack) return;
    record.mat.color.setHex(
      color ?? (attack.valid ? (attack.blocked ? 0xffc471 : 0xb9ffff) : 0xff705b),
    );
    record.mat.opacity = opacity;
    record.backingMaterial.opacity = Math.min(1, opacity + 0.15);
    this.updateCorridors(record, attack.corridors || [], opacity);
    record.pieces.forEach((mesh, i) => {
      const segment = attack.segments?.[i];
      mesh.visible = !!segment;
      record.halos[i].visible = !!segment;
      if (!segment) return;
      const { from, to } = segment;
      const delta = this.tmp.set(to.x - from.x, to.y - from.y, to.z - from.z);
      const length = delta.length();
      mesh.position.set((from.x + to.x) / 2, (from.y + to.y) / 2, (from.z + to.z) / 2);
      mesh.quaternion.setFromUnitVectors(UP, delta.multiplyScalar(1 / Math.max(length, 1e-8)));
      mesh.scale.set(0.025, length, 0.025);
      record.halos[i].position.copy(mesh.position);
      record.halos[i].quaternion.copy(mesh.quaternion);
      record.halos[i].scale.set(0.05, length, 0.05);
    });
    const point = attack.point;
    record.marker.visible = !!point;
    if (point)
      record.marker.position.set(point.x, point.y + (attack.kind === "bolt" ? 0 : 0.1), point.z);
    record.ring.visible = !!point && attack.radius > 0;
    record.ringBacking.visible = record.ring.visible;
    if (record.ring.visible) {
      for (const [mesh, inset, width, lift] of [
        [record.ringBacking, 0, 0.18, 0.085],
        [record.ring, 0.05, 0.07, 0.09],
      ]) {
        const positions = mesh.geometry.attributes.position;
        let index = 0;
        for (let i = 0; i < 64; i++) {
          const a = (i * Math.PI) / 32,
            b = ((i + 1) * Math.PI) / 32;
          const outer = Math.max(0, attack.radius - inset),
            inner = Math.max(0, outer - width);
          for (const [angle, radius] of [
            [a, inner],
            [a, outer],
            [b, outer],
            [a, inner],
            [b, outer],
            [b, inner],
          ]) {
            const x = point.x + Math.sin(angle) * radius,
              z = point.z + Math.cos(angle) * radius;
            positions.setXYZ(index++, x, groundHeight(x, z) + lift, z);
          }
        }
        positions.needsUpdate = true;
        mesh.geometry.computeBoundingSphere();
      }
    }
  }
  updateCorridors(record, corridors, opacity) {
    record.corridors.forEach((visual, index) => {
      const corridor = corridors[index];
      visual.group.visible = !!corridor;
      if (!corridor) return;
      const { from, to, radius, yMin, yMax } = corridor;
      const angle = Math.atan2(to.z - from.z, to.x - from.x);
      const perimeter = [];
      for (let cap = 0; cap < 2; cap++) {
        const point = cap ? to : from;
        for (let step = 0; step <= 20; step++) {
          const a = angle + (cap ? -Math.PI / 2 : Math.PI / 2) + (step * Math.PI) / 20;
          perimeter.push({
            x: point.x + Math.cos(a) * radius,
            z: point.z + Math.sin(a) * radius,
            centerX: point.x,
            centerZ: point.z,
            cos: Math.cos(a),
            sin: Math.sin(a),
          });
        }
      }
      const body = visual.body.geometry.attributes.position;
      const outline = visual.outline.geometry.attributes.position;
      let vertex = 0;
      for (let i = 0; i < perimeter.length; i++) {
        const a = perimeter[i],
          b = perimeter[(i + 1) % perimeter.length];
        for (const [point, y] of [
          [a, yMin],
          [b, yMin],
          [b, yMax],
          [a, yMin],
          [b, yMax],
          [a, yMax],
        ])
          body.setXYZ(vertex++, point.x, y, point.z);
        for (const [mesh, inset, width, lift] of [
          [visual.footprintBacking, 0, 0.18, 0.105],
          [visual.footprint, 0.05, 0.07, 0.11],
        ]) {
          const positions = mesh.geometry.attributes.position;
          let at = i * 6;
          for (const [point, inner] of [
            [a, false],
            [b, false],
            [b, true],
            [a, false],
            [b, true],
            [a, true],
          ]) {
            const r = Math.max(0, radius - inset - (inner ? width : 0));
            const x = point.centerX + point.cos * r,
              z = point.centerZ + point.sin * r;
            positions.setXYZ(at++, x, groundHeight(x, z) + lift, z);
          }
        }
        let at = i * 6;
        for (const [point, y] of [
          [a, yMin],
          [b, yMin],
          [a, yMax],
          [b, yMax],
          [a, yMin],
          [a, yMax],
        ])
          outline.setXYZ(at++, point.x, y, point.z);
      }
      for (const mesh of [visual.body, visual.footprint, visual.footprintBacking, visual.outline]) {
        mesh.geometry.attributes.position.needsUpdate = true;
        mesh.geometry.computeBoundingSphere();
      }
      visual.body.material.color.copy(record.mat.color);
      visual.body.material.opacity = opacity * 0.1;
      visual.outline.material.color.setHex(0x10252c);
      visual.outline.material.opacity = Math.min(1, opacity + 0.15);
    });
  }
  updateConductors(conductors) {
    const ids = new Set(conductors.map((c) => c.id));
    for (const [id, model] of this.conductors) {
      if (ids.has(id)) continue;
      model.removeFromParent();
      this.conductorPool.push(model);
      this.conductors.delete(id);
    }
    for (const c of conductors) {
      if (!this.conductors.has(c.id)) {
        const model = this.conductorPool.pop() || createConductor();
        this.conductors.set(c.id, model);
        this.scene.add(model);
      }
      const model = this.conductors.get(c.id);
      model.position.set(c.x, c.y, c.z);
      model.userData.electrode.scale.setScalar(0.22 * (1 + Math.max(0, c.flash || 0) * 0.7));
    }
  }
  makeHazard(h) {
    const group = new THREE.Group(),
      fill = new THREE.MeshBasicMaterial({
        color: 0xc98232,
        transparent: true,
        opacity: 0.15,
        depthWrite: false,
        side: THREE.DoubleSide,
      });
    const outline = new THREE.LineBasicMaterial({
      color: 0x845b32,
      transparent: true,
      opacity: 0.85,
      depthWrite: false,
    });
    const geo = new THREE.BufferGeometry();
    if (h.previewSegments?.length) {
      const vertices = [],
        edges = [];
      const point = (x, z) => [x, groundHeight(x, z) + 0.052, z];
      for (const s of h.previewSegments) {
        const dx = s.x2 - s.x1,
          dz = s.z2 - s.z1,
          len = Math.hypot(dx, dz) || 1,
          nx = (-dz / len) * s.radius,
          nz = (dx / len) * s.radius;
        const corners = [
          point(s.x1 + nx, s.z1 + nz),
          point(s.x2 + nx, s.z2 + nz),
          point(s.x2 - nx, s.z2 - nz),
          point(s.x1 - nx, s.z1 - nz),
        ];
        for (const idx of [0, 1, 2, 0, 2, 3]) vertices.push(...corners[idx]);
        edges.push(...corners[0], ...corners[1], ...corners[2], ...corners[3]);
        for (const [x, z] of [
          [s.x1, s.z1],
          [s.x2, s.z2],
        ]) {
          for (let i = 0; i < 12; i++) {
            const a = (i * Math.PI) / 6,
              b = ((i + 1) * Math.PI) / 6;
            vertices.push(
              ...point(x, z),
              ...point(x + Math.cos(a) * s.radius, z + Math.sin(a) * s.radius),
              ...point(x + Math.cos(b) * s.radius, z + Math.sin(b) * s.radius),
            );
          }
        }
      }
      geo.setAttribute("position", new THREE.Float32BufferAttribute(vertices, 3));
      fill.depthWrite = true;
      fill.depthFunc = THREE.LessDepth;
      group.add(new THREE.Mesh(geo, fill));
      group.add(
        new THREE.LineSegments(
          new THREE.BufferGeometry().setAttribute(
            "position",
            new THREE.Float32BufferAttribute(edges, 3),
          ),
          outline,
        ),
      );
    }
    if (h.telegraph?.length > 2) {
      const contour = h.telegraph.map((p) => new THREE.Vector2(p.x, p.z));
      const triangles = THREE.ShapeUtils.triangulateShape(contour, []).flat(),
        vertices = [];
      for (const p of h.telegraph) vertices.push(p.x, groundHeight(p.x, p.z) + 0.045, p.z);
      geo.setAttribute("position", new THREE.Float32BufferAttribute(vertices, 3));
      geo.setIndex(triangles);
      geo.computeVertexNormals();
      group.add(new THREE.Mesh(geo, fill));
      const points = h.telegraph.map(
        (p) => new THREE.Vector3(p.x, groundHeight(p.x, p.z) + 0.06, p.z),
      );
      points.push(points[0].clone());
      group.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(points), outline));
    }
    const pieces = [];
    for (let i = 0; i < 6; i++) {
      const mat = new THREE.MeshBasicMaterial({
        color: 0xf36c40,
        transparent: true,
        opacity: 0.37,
        depthWrite: false,
      });
      const body = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), mat);
      body.rotation.x = -Math.PI / 2;
      group.add(body);
      const ends = [0, 1].map(() => {
        const m = new THREE.Mesh(new THREE.CircleGeometry(1, 14), mat);
        m.rotation.x = -Math.PI / 2;
        group.add(m);
        return m;
      });
      pieces.push({ body, ends, mat });
    }
    let chunk = null;
    if (h.kind === "offcut") {
      chunk = new THREE.Mesh(
        new THREE.IcosahedronGeometry(h.bodyRadius || 0.65, 0),
        new THREE.MeshStandardMaterial({ color: 0x9b7047, roughness: 0.9 }),
      );
      chunk.castShadow = true;
      group.add(chunk);
    }
    this.scene.add(group);
    const heightGeometry = new THREE.BufferGeometry();
    heightGeometry.setAttribute(
      "position",
      new THREE.BufferAttribute(new Float32Array(6 * 6 * 3), 3).setUsage(THREE.DynamicDrawUsage),
    );
    const heightMaterial = new THREE.LineBasicMaterial({
      color: 0xff447c,
      transparent: true,
      opacity: 0.8,
      depthWrite: false,
    });
    const height = new THREE.LineSegments(heightGeometry, heightMaterial);
    group.add(height);
    return { group, pieces, fill, outline, chunk, height };
  }
  updateHazards(hazards) {
    const alive = new Set();
    for (const h of hazards) {
      const id = h.id;
      alive.add(id);
      if (!this.hazards.has(id)) this.hazards.set(id, this.makeHazard(h));
      const record = this.hazards.get(id),
        active = h.state === "active";
      record.fill.color.setHex(h.jumpable === false ? 0xf03d69 : 0xe49d21);
      record.outline.color.setHex(h.jumpable === false ? 0x6e102c : 0x503814);
      record.fill.opacity = active ? 0.1 : 0.2 + h.phase * 0.12;
      record.outline.opacity = active ? 0.65 : 0.95;
      record.height.visible =
        h.jumpable === false && Number.isFinite(h.yMin) && Number.isFinite(h.yMax);
      if (record.height.visible) {
        const positions = record.height.geometry.attributes.position;
        let index = 0;
        for (const segment of (h.segments?.length ? h.segments : h.previewSegments || []).slice(
          0,
          6,
        )) {
          for (const [x, y, z] of [
            [segment.x1, h.yMin, segment.z1],
            [segment.x1, h.yMax, segment.z1],
            [segment.x1, h.yMax, segment.z1],
            [segment.x2, h.yMax, segment.z2],
            [segment.x2, h.yMax, segment.z2],
            [segment.x2, h.yMin, segment.z2],
          ])
            positions.setXYZ(index++, x, y, z);
        }
        record.height.geometry.setDrawRange(0, index);
        positions.needsUpdate = true;
        record.height.geometry.computeBoundingSphere();
      }
      if (record.chunk) {
        record.chunk.visible = active;
        record.chunk.position.set(
          h.x,
          Number.isFinite(h.yMin) && Number.isFinite(h.yMax)
            ? (h.yMin + h.yMax) / 2
            : groundHeight(h.x, h.z) + (h.bodyRadius || 0.65),
          h.z,
        );
        record.chunk.rotation.set(h.z * 1.6, h.x * 0.8, h.phase * 5);
      }
      record.pieces.forEach((p, i) => {
        const s = h.segments?.[i];
        p.body.visible = !!s && active;
        p.ends.forEach((e) => (e.visible = !!s && active));
        if (!s) return;
        const dx = s.x2 - s.x1,
          dz = s.z2 - s.z1,
          length = Math.hypot(dx, dz),
          midX = (s.x1 + s.x2) / 2,
          midZ = (s.z1 + s.z2) / 2;
        p.body.position.set(midX, groundHeight(midX, midZ) + 0.07, midZ);
        p.body.rotation.set(-Math.PI / 2, 0, Math.atan2(-dx, -dz));
        p.body.scale.set(s.radius * 2, Math.max(0.015, length), 1);
        p.ends.forEach((e, j) => {
          const x = j ? s.x2 : s.x1,
            z = j ? s.z2 : s.z1;
          e.position.set(x, groundHeight(x, z) + 0.075, z);
          e.scale.setScalar(s.radius);
        });
      });
    }
    for (const [id, record] of this.hazards)
      if (!alive.has(id)) {
        record.group.traverse((o) => {
          if (o.geometry) o.geometry.dispose();
          if (o.material) o.material.dispose();
        });
        this.scene.remove(record.group);
        this.hazards.delete(id);
      }
  }
  event(e) {
    if (e.type === "attack" && e.attack) {
      if (this.effects.length >= 16) {
        const old = this.effects.shift();
        old.visual.group.visible = false;
        this.effectPool.push(old.visual);
      }
      const visual = this.effectPool.pop() || this.makeAttackVisual();
      const color = e.echo
        ? 0xd6aaff
        : e.source === "companion"
          ? 0xffe8a0
          : e.source === "conductor"
            ? 0x74ffe3
            : 0xc8ffff;
      this.updateAttackVisual(visual, e.attack, 1, color);
      for (const piece of visual.pieces) piece.scale.x = piece.scale.z = e.echo ? 0.035 : 0.055;
      for (const halo of visual.halos) halo.scale.x = halo.scale.z = e.echo ? 0.06 : 0.085;
      this.effects.push({
        visual,
        life: e.attack.kind === "strike" ? 0.4 : 0.18,
        max: e.attack.kind === "strike" ? 0.4 : 0.18,
      });
    }
    if (
      ["hit", "hurt", "ram", "collect", "companion", "land", "bounce", "spawn"].includes(e.type)
    ) {
      const color =
        e.type === "collect"
          ? 0xa8f1ca
          : e.type === "hurt"
            ? 0xf77c52
            : e.type === "bounce"
              ? 0xaaffff
              : 0xffd87e;
      for (let i = 0; i < (e.type === "collect" ? 9 : 14); i++)
        if (this.particles.length < 220 && Number.isFinite(e.x) && Number.isFinite(e.z))
          this.particles.push({
            x: e.x,
            y: e.y ?? 1,
            z: e.z,
            vx: (Math.random() - 0.5) * 5,
            vy: 1.8 + Math.random() * 3,
            vz: (Math.random() - 0.5) * 5,
            life: 0.35 + Math.random() * 0.45,
            color,
          });
      if (["ram", "hurt", "land", "bounce"].includes(e.type)) this.shake = 0.6;
    }
  }
  updateEffects(dt) {
    this.effects = this.effects.filter((e) => {
      e.life -= dt;
      if (e.life <= 0) {
        e.visual.group.visible = false;
        this.effectPool.push(e.visual);
        return false;
      }
      e.visual.mat.opacity = e.life / e.max;
      e.visual.backingMaterial.opacity = e.life / e.max;
      for (const corridor of e.visual.corridors) {
        corridor.body.material.opacity = (e.life / e.max) * 0.1;
        corridor.outline.material.opacity = e.life / e.max;
      }
      return true;
    });
    this.particles = this.particles.filter((p) => {
      p.life -= dt;
      p.vy -= dt * 7;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.z += p.vz * dt;
      return p.life > 0;
    });
    this.particles.forEach((p, i) => {
      this.dummy.position.set(p.x, p.y, p.z);
      this.dummy.rotation.set(p.life * 3, p.x, p.z);
      this.dummy.scale.setScalar(Math.min(1, p.life * 4));
      this.dummy.updateMatrix();
      this.particleMesh.setMatrixAt(i, this.dummy.matrix);
      this.particleMesh.setColorAt(i, new THREE.Color(p.color));
    });
    this.particleMesh.count = this.particles.length;
    this.particleMesh.instanceMatrix.needsUpdate = true;
    if (this.particleMesh.instanceColor) this.particleMesh.instanceColor.needsUpdate = true;
  }
  clear() {
    for (const m of this.pickups.values()) this.poolPickup(m);
    this.pickups.clear();
    for (const e of this.effects) {
      e.visual.group.visible = false;
      this.effectPool.push(e.visual);
    }
    for (const m of this.enemies.values()) this.poolEnemy(m);
    this.enemies.clear();
    this.updateConductors([]);
    this.updateAttackVisual(this.conductorLink, null);
    this.updateAttackVisual(this.preview, null);
    this.particleMesh.count = 0;
    this.effects.length = 0;
    this.updateHazards([]);
    this.particles.length = 0;
    this.shake = 0;
    this.resetCamera();
  }
  poolEnemy(mesh) {
    mesh.removeFromParent();
    const kind = mesh.userData.kind;
    if (!this.enemyPool.has(kind)) this.enemyPool.set(kind, []);
    this.enemyPool.get(kind).push(mesh);
  }
  poolPickup(mesh) {
    this.scene.remove(mesh);
    const kind = mesh.userData.pickupKind || "scrap";
    if (!this.pickupPool.has(kind)) this.pickupPool.set(kind, []);
    this.pickupPool.get(kind).push(mesh);
  }
}
