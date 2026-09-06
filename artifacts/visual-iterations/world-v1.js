import * as THREE from "three";
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry.js";
import { mergeGeometries } from "three/addons/utils/BufferGeometryUtils.js";
import { PATH, WALLS, WEAPONS, seededRandom } from "./game.js";
const C = {
  navy: 0x0b2026,
  petrol: 0x23464a,
  dark: 0x193439,
  ivory: 0xd6d0b7,
  light: 0xe7debf,
  orange: 0xf38c4b,
  mint: 0x9ce7ce,
  copper: 0xa95f3b,
  rock: 0x294147,
  sage: 0x778f73,
};
const materials = new Map();
function mat(color, emissive = 0) {
  const key = color + ":" + emissive;
  if (!materials.has(key))
    materials.set(
      key,
      new THREE.MeshStandardMaterial({
        color: new THREE.Color(color).multiplyScalar(emissive ? 0.32 : 1),
        roughness: 0.88,
        metalness: 0.08,
        emissive,
        emissiveIntensity: 0.35,
      }),
    );
  return materials.get(key);
}
const geos = {
  box: new RoundedBoxGeometry(1, 1, 1, 1, 0.075),
  cube: new THREE.BoxGeometry(1, 1, 1),
  cylinder: new THREE.CylinderGeometry(1, 1, 1, 8),
  cone: new THREE.ConeGeometry(1, 1, 7),
  sphere: new THREE.IcosahedronGeometry(1, 2),
  rock: new THREE.IcosahedronGeometry(1, 0),
  torus: new THREE.TorusGeometry(1, 0.085, 5, 32),
};
for (const [name, geometry] of Object.entries(geos)) {
  if (geometry.index) {
    geos[name] = geometry.toNonIndexed();
    geometry.dispose();
  }
}
function mesh(
  parent,
  shape,
  color,
  x,
  y,
  z,
  sx = 1,
  sy = 1,
  sz = 1,
  emissive = 0,
) {
  const o = new THREE.Mesh(geos[shape], mat(color, emissive));
  o.position.set(x, y, z);
  o.scale.set(sx, sy, sz);
  o.castShadow = true;
  o.receiveShadow = true;
  parent.add(o);
  return o;
}
function consolidate(group) {
  group.updateMatrixWorld(true);
  const bins = new Map();
  group.traverse((o) => {
    if (o.isMesh) {
      const geometry = o.geometry.clone().applyMatrix4(o.matrixWorld);
      let bin = bins.get(o.material);
      if (!bin) {
        bin = [];
        bins.set(o.material, bin);
      }
      bin.push(geometry);
    }
  });
  const merged = new THREE.Group();
  for (const [m, geometries] of bins) {
    const geo = mergeGeometries(geometries, false);
    const obj = new THREE.Mesh(geo, m);
    obj.castShadow = true;
    obj.receiveShadow = true;
    merged.add(obj);
    geometries.forEach((g) => g.dispose());
  }
  return merged;
}
function weaponModel(type, ground = false) {
  const g = new THREE.Group();
  mesh(g, "cylinder", C.dark, 0, 0.08, 0, 0.26, 0.16, 0.26);
  mesh(g, "box", C.orange, 0, 0.19, 0, 0.44, 0.19, 0.4);
  if (type === "bolt") {
    mesh(g, "box", C.light, 0, 0.35, 0, 0.36, 0.3, 0.36);
    mesh(g, "cylinder", C.dark, 0, 0.53, 0, 0.115, 0.4, 0.115);
    mesh(g, "cylinder", C.orange, 0, 0.7, 0, 0.16, 0.1, 0.16);
    mesh(g, "box", C.mint, 0.18, 0.4, 0, 0.055, 0.1, 0.18, C.mint);
  }
  if (type === "pipe") {
    mesh(g, "cylinder", C.orange, 0, 0.39, 0, 0.26, 0.4, 0.26);
    mesh(g, "torus", C.copper, 0, 0.48, 0, 0.24, 0.24, 0.24).rotation.x =
      Math.PI / 2;
    mesh(g, "cylinder", C.dark, 0, 0.61, 0, 0.19, 0.1, 0.19);
    mesh(g, "cylinder", C.light, 0, 0.51, 0, 0.29, 0.08, 0.29);
  }
  if (type === "coil") {
    mesh(g, "cylinder", C.dark, 0, 0.4, 0, 0.13, 0.42, 0.13);
    for (let i = 0; i < 3; i++)
      mesh(
        g,
        "cylinder",
        C.mint,
        0,
        0.27 + i * 0.14,
        0,
        0.24,
        0.055,
        0.24,
        C.mint,
      );
    mesh(g, "sphere", C.mint, 0, 0.69, 0, 0.13, 0.13, 0.13, C.mint);
  }
  if (type === "cactus") {
    mesh(g, "cylinder", C.copper, 0, 0.19, 0, 0.26, 0.25, 0.26);
    mesh(g, "cylinder", C.sage, 0, 0.49, 0, 0.14, 0.45, 0.14);
    mesh(g, "box", C.sage, 0.17, 0.4, 0, 0.28, 0.12, 0.14);
    mesh(g, "cylinder", C.sage, 0.26, 0.5, 0, 0.07, 0.24, 0.07);
    mesh(g, "cone", C.light, 0, 0.77, 0, 0.1, 0.15, 0.1);
  }
  const result = consolidate(g);
  if (ground) result.scale.setScalar(1.18);
  return result;
}
function enemyModel(type) {
  const g = new THREE.Group();
  const tank = type === "tank",
    boss = type === "boss";
  mesh(g, "sphere", C.dark, 0, 0.32, 0, 0.43, 0.24, 0.53);
  mesh(g, "box", tank ? C.copper : C.orange, 0, 0.5, 0, 0.55, 0.32, 0.55);
  mesh(g, "box", C.dark, 0, 0.49, 0.29, 0.45, 0.16, 0.12);
  for (const x of [-0.14, 0.14])
    mesh(g, "box", 0xffd4a0, x, 0.51, 0.36, 0.09, 0.065, 0.07, 0xff9354);
  for (let i = 0; i < 2; i++)
    for (const s of [-1, 1]) {
      const leg = mesh(
        g,
        "box",
        C.copper,
        s * 0.46,
        0.24,
        (i - 0.5) * 0.58,
        0.5,
        0.12,
        0.13,
      );
      leg.rotation.z = s * -0.4;
      mesh(
        g,
        "sphere",
        C.dark,
        s * 0.65,
        0.13,
        (i - 0.5) * 0.58,
        0.11,
        0.13,
        0.13,
      );
    }
  if (tank || boss) {
    mesh(g, "box", C.ivory, 0, 0.65, 0, 0.58, 0.13, 0.58);
    mesh(g, "box", C.orange, 0, 0.78, 0, 0.17, 0.19, 0.36);
  }
  const model = consolidate(g);
  if (tank) model.scale.setScalar(1.4);
  if (boss) model.scale.setScalar(2.55);
  if (type === "runner") model.scale.set(0.8, 0.7, 1.05);
  return model;
}
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
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.12;
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(C.navy);
    this.scene.fog = new THREE.Fog(C.navy, 65, 130);
    this.camera = new THREE.OrthographicCamera(-24, 24, 17, -17, 0.1, 180);
    this.camera.position.set(29, 34, 32);
    this.camera.lookAt(0, 0, 0);
    this.cameraBase = this.camera.position.clone();
    this.scene.add(new THREE.HemisphereLight(0xd9eee6, 0x1b2f34, 1.95));
    const sun = new THREE.DirectionalLight(0xffe5bf, 3);
    sun.position.set(-15, 28, 10);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
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
    sun.shadow.radius = 3;
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
    this.resize();
    window.addEventListener("resize", () => this.resize());
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
    const g = new THREE.Group(),
      rand = seededRandom(181);
    mesh(g, "box", C.dark, 0, -1.05, 0, 27.7, 2.1, 22);
    mesh(g, "box", C.ivory, 0, -0.13, 0, 28, 0.35, 22.2);
    mesh(g, "box", C.copper, 0, -0.38, 0, 28.08, 0.12, 22.22);
    for (let x = -13; x <= 13; x += 2)
      for (let z = -10; z <= 10; z += 2) {
        mesh(
          g,
          "cube",
          rand() > 0.5 ? C.ivory : 0xcac5af,
          x,
          0.062,
          z,
          1.97,
          0.05,
          1.97,
        );
      }
    for (let i = 1; i < PATH.length; i++) {
      const a = PATH[i - 1],
        b = PATH[i],
        horizontal = a[1] === b[1];
      const len = Math.hypot(b[0] - a[0], b[1] - a[1]);
      const x = (a[0] + b[0]) / 2,
        z = (a[1] + b[1]) / 2;
      mesh(
        g,
        "box",
        0x26454a,
        x,
        0.09,
        z,
        horizontal ? len + 2.15 : 2.15,
        0.075,
        horizontal ? 2.15 : len + 2.15,
      );
      for (const side of [-1, 1])
        mesh(
          g,
          "cube",
          C.orange,
          x + (horizontal ? 0 : side * 1.08),
          0.139,
          z + (horizontal ? side * 1.08 : 0),
          horizontal ? len + 0.1 : 0.065,
          0.04,
          horizontal ? 0.065 : len + 0.1,
        );
      const dx = (b[0] - a[0]) / len,
        dz = (b[1] - a[1]) / len;
      for (let j = 2; j < len - 1; j += 2.5) {
        const px = a[0] + dx * j,
          pz = a[1] + dz * j;
        const arrow = mesh(g, "cone", 0x788778, px, 0.15, pz, 0.14, 0.3, 0.08);
        arrow.rotation.x = Math.PI / 2;
        arrow.rotation.z = -Math.atan2(dx, dz);
      }
    }
    for (const w of WALLS) {
      mesh(g, "box", C.dark, w.x, 0.28, w.z, w.w + 0.16, 0.46, w.h + 0.1);
      mesh(g, "box", C.ivory, w.x, 0.62, w.z, w.w, 0.83, w.h);
      mesh(g, "box", C.light, w.x, 1.05, w.z, w.w + 0.12, 0.14, w.h + 0.12);
      for (let x = w.x - w.w / 2 + 0.6; x < w.x + w.w / 2; x += 2.1) {
        mesh(g, "box", 0xe1d8be, x, 0.83, w.z, 0.23, 0.62, w.h + 0.12);
        mesh(g, "box", C.orange, x, 1.15, w.z, 0.24, 0.065, 0.45);
      }
    }
    for (let x = -13; x <= 13; x += 1.55) {
      for (const z of [-10.85, 10.85]) {
        mesh(g, "box", C.ivory, x, 0.23, z, 1.35, 0.34, 0.38);
        mesh(
          g,
          "box",
          rand() > 0.5 ? C.rock : 0x6e7870,
          x,
          -1.05,
          z - 0.12,
          1.2,
          1.1 + rand() * 0.8,
          0.5,
        );
        if (Math.abs(x % 4) < 1)
          mesh(g, "cylinder", C.copper, x, -1, z * 1.02, 0.13, 1.7, 0.13);
      }
    }
    for (let z = -9.7; z < 10; z += 1.55)
      for (const x of [-13.65, 13.65]) {
        mesh(g, "box", C.ivory, x, 0.23, z, 0.4, 0.34, 1.35);
        mesh(g, "box", C.rock, x, -1.05, z, 0.5, 1.3, 1.25);
      }
    for (let x = -12.6; x < 13; x += 1.8) {
      for (const z of [-11, 11]) {
        const h = 0.7 + rand() * 0.9;
        mesh(
          g,
          "box",
          rand() > 0.4 ? 0x718075 : 0xa3a58c,
          x,
          -1.2,
          z,
          1.25,
          h,
          0.32,
        );
        mesh(g, "rock", C.rock, x + 0.4, -1.6, z + 0.22, 0.48, 0.62, 0.45);
      }
    }
    for (let z = -9; z <= 9; z += 2.4)
      for (const x of [-13.9, 13.9]) {
        mesh(g, "box", 0x809083, x, -1, z, 0.38, 1.3, 1.15);
        const pipe = mesh(
          g,
          "cylinder",
          C.copper,
          x * 1.005,
          -0.55,
          z,
          0.12,
          0.55,
          0.12,
        );
        pipe.rotation.z = Math.PI / 2;
      }
    const tree = (x, z, s = 1) => {
      mesh(g, "cylinder", C.copper, x, 0.45, z, 0.11, 0.8, 0.11);
      for (let j = 0; j < 3; j++)
        mesh(
          g,
          "cone",
          j % 2 ? 0x3e6662 : 0x315451,
          x,
          0.85 + j * 0.45 * s,
          z,
          (0.72 - j * 0.14) * s,
          0.95 * s,
          (0.72 - j * 0.14) * s,
        );
    };
    const cluster = (x, z) => {
      mesh(g, "cylinder", C.rock, x, 0.13, z, 1.15, 0.3, 1.15);
      tree(x, z, 1.2);
      tree(x + 0.7, z + 0.4, 0.7);
      for (let i = 0; i < 4; i++) {
        const rock = mesh(
          g,
          "rock",
          C.rock,
          x + (rand() - 0.5) * 2,
          0.28,
          z + (rand() - 0.5) * 2,
          0.3 + rand() * 0.4,
          0.35 + rand() * 0.25,
          0.4,
        );
        rock.rotation.set(rand(), rand(), rand());
      }
    };
    cluster(-11.3, -9.3);
    cluster(11.5, 9.3);
    cluster(-11.5, 9.1);
    cluster(11.5, -9.3);
    for (let i = 0; i < 28; i++) {
      const x = (rand() - 0.5) * 25,
        z = (rand() - 0.5) * 18.7;
      if (
        WALLS.some(
          (w) =>
            Math.abs(x - w.x) < w.w / 2 && Math.abs(z - w.z) < w.h / 2 + 0.45,
        )
      )
        continue;
      const nearPath = PATH.slice(1).some((b, j) => {
        const a = PATH[j];
        return a[1] === b[1]
          ? Math.abs(z - a[1]) < 1.2 &&
              x >= Math.min(a[0], b[0]) - 1 &&
              x <= Math.max(a[0], b[0]) + 1
          : Math.abs(x - a[0]) < 1.2 &&
              z >= Math.min(a[1], b[1]) - 1 &&
              z <= Math.max(a[1], b[1]) + 1;
      });
      if (nearPath) continue;
      mesh(g, "box", C.dark, x, 0.1, z, 0.4, 0.16, 0.4);
      mesh(g, "cone", C.orange, x, 0.29, z, 0.16, 0.4, 0.16);
      mesh(g, "cylinder", C.light, x, 0.28, z, 0.1, 0.065, 0.1);
    }
    const base = new THREE.Group();
    mesh(base, "cylinder", C.dark, 3, 0.23, 8, 1.7, 0.35, 1.7);
    mesh(base, "cylinder", C.ivory, 3, 0.5, 8, 1.45, 0.3, 1.45);
    mesh(base, "cylinder", C.orange, 3, 0.72, 8, 1.14, 0.17, 1.14);
    mesh(base, "cylinder", C.dark, 3, 0.87, 8, 1, 0.2, 1);
    for (let i = 0; i < 8; i++) {
      const a = (i * Math.PI) / 4;
      mesh(
        base,
        "box",
        C.mint,
        3 + Math.cos(a) * 1.05,
        0.88,
        8 + Math.sin(a) * 1.05,
        0.13,
        0.18,
        0.13,
        C.mint,
      );
    }
    g.add(base);
    // Entry arch frames the beginning of the enemy lane.
    for (const z of [-8.3, -5.7]) {
      mesh(g, "box", C.dark, -12, 0.65, z, 0.68, 1.2, 0.55);
      mesh(g, "box", C.orange, -12, 1.23, z, 0.78, 0.16, 0.65);
    }
    mesh(g, "box", C.orange, -12, 1.85, -7, 0.45, 0.35, 3.1);
    for (let i = 0; i < 5; i++) {
      const hazard = mesh(
        g,
        "box",
        C.dark,
        -11.76,
        1.85,
        -8.15 + i * 0.56,
        0.025,
        0.37,
        0.19,
      );
      hazard.rotation.x = -0.38;
    }
    for (const z of [2.8, 5.2]) {
      mesh(g, "box", C.dark, -11.4, 0.7, z, 0.58, 1.25, 0.42);
      mesh(g, "box", C.orange, -11.4, 1.35, z, 0.68, 0.18, 0.52);
    }
    mesh(g, "box", C.orange, -11.4, 1.85, 4, 0.4, 0.32, 2.9);
    for (let i = 0; i < 5; i++)
      mesh(
        g,
        "box",
        C.dark,
        -11.18,
        1.85,
        2.95 + i * 0.52,
        0.03,
        0.34,
        0.19,
      ).rotation.x = -0.4;
    this.scene.add(consolidate(g));
    this.crystal = new THREE.Group();
    this.crystal.position.set(3, 0.96, 8);
    for (let i = 0; i < 4; i++) {
      const crystal = mesh(
        this.crystal,
        "cylinder",
        i ? 0x70caae : C.mint,
        i ? Math.cos(i * 2) * 0.58 : 0,
        i ? 0.62 : 1.06,
        i ? Math.sin(i * 2) * 0.58 : 0,
        i ? 0.25 : 0.42,
        i ? 1.22 : 2.12,
        i ? 0.25 : 0.42,
        C.mint,
      );
      const tip = mesh(
        this.crystal,
        "cone",
        0xc0ffe5,
        crystal.position.x,
        crystal.position.y + (i ? 0.85 : 1.38),
        crystal.position.z,
        i ? 0.25 : 0.42,
        i ? 0.5 : 0.7,
        i ? 0.25 : 0.42,
        C.mint,
      );
      tip.rotation.y = crystal.rotation.y = Math.PI / 8;
    }
    this.scene.add(this.crystal);
    const ground = new THREE.Mesh(
      new THREE.PlaneGeometry(300, 300),
      mat(C.navy),
    );
    ground.rotation.x = -Math.PI / 2;
    ground.position.y = -2.35;
    ground.receiveShadow = true;
    this.scene.add(ground);
  }
  buildPlayer() {
    this.player = new THREE.Group();
    this.core = new THREE.Group();
    mesh(this.core, "sphere", C.petrol, 0, 0, 0, 1, 1, 1);
    for (let i = 0; i < 3; i++) {
      const ring = mesh(
        this.core,
        "torus",
        C.dark,
        0,
        0,
        0,
        1.003,
        1.003,
        1.003,
      );
      ring.rotation.set(
        i === 0 ? Math.PI / 2 : 0,
        i === 1 ? Math.PI / 2 : 0,
        0,
      );
    }
    for (let i = 0; i < 12; i++) {
      const a = i * 2.39996,
        y = 1 - (i + 0.5) / 6,
        r = Math.sqrt(1 - y * y);
      mesh(
        this.core,
        "box",
        i % 3 === 0 ? C.orange : C.ivory,
        Math.cos(a) * r,
        y,
        Math.sin(a) * r,
        0.12,
        0.12,
        0.12,
      );
    }
    this.player.add(this.core);
    this.face = new THREE.Group();
    for (const x of [-0.24, 0.24])
      mesh(this.face, "box", C.mint, x, 0.18, 0.94, 0.13, 0.12, 0.06, C.mint);
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
    this.width = w;
    this.height = h;
    this.updateCamera();
  }
  updateCamera() {
    const aspect = this.width / this.height;
    const half = Math.max(14.8, 22 / aspect);
    this.camera.left = -half * aspect - this.menuShift;
    this.camera.right = half * aspect - this.menuShift;
    this.camera.top = half + 0.9;
    this.camera.bottom = -half + 0.9;
    this.camera.updateProjectionMatrix();
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
    this.face.rotation.y = Math.PI / 4;
    this.playerHalo.position.set(p.x, 0.19, p.z);
    this.playerHalo.scale.setScalar(p.radius);
    this.playerHalo.material.opacity = p.dashCooldown === 0 ? 0.65 : 0.25;
    this.rangeRing.position.set(p.x, 0.175, p.z);
    this.rangeRing.scale.setScalar(game.buffs.range);
    this.rangeRing.visible = game.mode === "playing";
    this.crystal.position.y = 0.96 + Math.sin(t * 1.8) * 0.045;
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
      const band = (game.weapons.indexOf(w) % 3) * 0.19;
      const y = p.radius + 0.28 + band;
      const normal = new THREE.Vector3(m.nx, 0.38 + band, m.nz).normalize();
      o.position.set(m.x, y, m.z);
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
      this.dummy.position.z += 0.035;
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
      this.dummy.rotation.set(
        0,
        target ? Math.atan2(target.x - s.x, target.z - s.z) : 0,
        0,
      );
      this.dummy.scale.set(
        s.type === "pipe" ? 0.16 : 0.055,
        0.055,
        s.type === "pipe" ? 0.23 : 0.54,
      );
      this.dummy.updateMatrix();
      this.shotMesh.setMatrixAt(i, this.dummy.matrix);
      this.shotMesh.setColorAt(i, this.color.set(WEAPONS[s.type].color));
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
    this.renderer.render(this.scene, this.camera);
  }
}
