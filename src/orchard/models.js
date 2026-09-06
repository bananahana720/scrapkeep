import * as THREE from "three";
import { mergeGeometries } from "three/addons/utils/BufferGeometryUtils.js";

const material = (color, metalness = 0.25, roughness = 0.65) =>
  new THREE.MeshStandardMaterial({
    color,
    metalness,
    roughness,
    flatShading: true,
  });
const M = {
  sage: material("#849875"),
  cream: material("#ece1bb"),
  ochre: material("#bc853a"),
  steel: material("#3a4945", 0.72),
  rubber: material("#242d29", 0.05),
  copper: material("#bc7250", 0.65),
  fur: material("#b47b49", 0),
  pale: material("#fff0d2", 0),
  pink: material("#e9a09a", 0),
  eye: material("#182423", 0.1, 0.25),
  leaf: material("#527841", 0),
  apple: material("#d99245", 0),
  soil: material("#5b4936", 0),
  glow: new THREE.MeshStandardMaterial({
    color: "#ffe7a1",
    emissive: "#ffc157",
    emissiveIntensity: 0.8,
  }),
  glass: new THREE.MeshPhysicalMaterial({
    color: "#b8e5d7",
    transparent: true,
    opacity: 0.19,
    roughness: 0.12,
    metalness: 0.05,
    depthWrite: false,
    side: THREE.DoubleSide,
  }),
};
const G = {
  box: new THREE.BoxGeometry(1, 1, 1),
  sphere: new THREE.SphereGeometry(1, 16, 10),
  ico: new THREE.IcosahedronGeometry(1, 1),
  cylinder: new THREE.CylinderGeometry(1, 1, 1, 12),
  ring: new THREE.TorusGeometry(1, 0.12, 6, 20),
};
const up = new THREE.Vector3(0, 1, 0);
const direction = new THREE.Vector3();
const rollingAxis = new THREE.Vector3();
const rollingRotation = new THREE.Quaternion();

function mesh(
  parent,
  geometry,
  mat,
  x = 0,
  y = 0,
  z = 0,
  sx = 1,
  sy = sx,
  sz = sx,
) {
  const object = new THREE.Mesh(geometry, mat);
  object.position.set(x, y, z);
  object.scale.set(sx, sy, sz);
  object.castShadow = mat !== M.glass;
  object.receiveShadow = mat !== M.glass;
  parent.add(object);
  return object;
}
function box(parent, mat, x, y, z, sx, sy, sz) {
  return mesh(parent, G.box, mat, x, y, z, sx, sy, sz);
}
function ball(parent, mat, x, y, z, sx, sy = sx, sz = sx) {
  return mesh(parent, G.sphere, mat, x, y, z, sx, sy, sz);
}
function rod(parent, mat, ax, ay, az, bx, by, bz, radius) {
  const object = mesh(parent, G.cylinder, mat);
  setRod(object, ax, ay, az, bx, by, bz, radius);
  return object;
}
function setRod(object, ax, ay, az, bx, by, bz, radius) {
  direction.set(bx - ax, by - ay, bz - az);
  const length = direction.length();
  object.position.set((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2);
  object.scale.set(radius, length, radius);
  object.quaternion.setFromUnitVectors(
    up,
    direction.multiplyScalar(1 / Math.max(length, 1e-8)),
  );
}
function pivot(parent, x, y, z, radius = 0.35, horizontal = false) {
  const disc = mesh(parent, G.cylinder, M.sage, x, y, z, radius, 0.18, radius);
  const rim = mesh(
    parent,
    G.ring,
    M.cream,
    x,
    y,
    z + (horizontal ? 0 : 0.11),
    radius * 0.9,
  );
  const cap = mesh(
    parent,
    G.cylinder,
    M.copper,
    x,
    y + (horizontal ? 0.13 : 0),
    z + (horizontal ? 0 : 0.14),
    radius * 0.35,
    0.09,
    radius * 0.35,
  );
  if (horizontal) rim.rotation.x = Math.PI / 2;
  else {
    disc.rotation.x = Math.PI / 2;
    cap.rotation.x = Math.PI / 2;
  }
}
function consolidate(group) {
  group.updateMatrixWorld(true);
  const inverse = group.matrixWorld.clone().invert();
  const batches = new Map();
  const original = [];
  group.traverse((object) => {
    if (!object.isMesh) return;
    const geometry = object.geometry.index
      ? object.geometry.toNonIndexed()
      : object.geometry.clone();
    geometry.applyMatrix4(inverse.clone().multiply(object.matrixWorld));
    if (!batches.has(object.material)) batches.set(object.material, []);
    batches.get(object.material).push(geometry);
    original.push(object);
  });
  for (const object of original) object.removeFromParent();
  for (const [mat, geometries] of batches) {
    const geometry = mergeGeometries(geometries, false);
    if (!geometry) throw new Error("Incompatible model geometry");
    mesh(group, geometry, mat);
    for (const source of geometries) source.dispose();
  }
  return group;
}
function rigid(parent) {
  const group = new THREE.Group();
  parent.add(group);
  return group;
}

function bladeGeometry(side) {
  const shape = new THREE.Shape();
  shape.moveTo(0, 0);
  shape.lineTo(side * 0.48, -0.3);
  shape.quadraticCurveTo(side * 0.86, -1.6, side * 0.12, -2.7);
  shape.quadraticCurveTo(side * 0.35, -1.25, 0, -0.25);
  shape.closePath();
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth: 0.13,
    bevelEnabled: true,
    bevelSize: 0.055,
    bevelThickness: 0.045,
    bevelSegments: 1,
    curveSegments: 7,
  });
  geometry.rotateX(Math.PI / 2);
  return geometry;
}
const blades = [bladeGeometry(-1), bladeGeometry(1)];
function shears(parent, scale = 1) {
  const group = rigid(parent);
  group.scale.setScalar(scale);
  const housing = rigid(group);
  box(housing, M.sage, 0, -0.07, 0.14, 0.85, 0.25, 0.8);
  pivot(housing, 0, 0.05, 0, 0.48, true);
  rod(housing, M.cream, -0.37, 0, 0.65, 0.28, 0.14, 0.03, 0.11);
  consolidate(housing);
  const jaws = [-1, 1].map((side, index) => {
    const jaw = rigid(group);
    mesh(jaw, blades[index], M.steel, 0, index * 0.07, 0);
    rod(
      jaw,
      M.ochre,
      side * 0.27,
      -0.08,
      -0.34,
      side * 0.47,
      -0.08,
      -1.25,
      0.11,
    );
    pivot(jaw, side * 0.18, 0.13, -0.35, 0.07, true);
    consolidate(jaw);
    jaw.userData.side = side;
    return jaw;
  });
  group.userData.jaws = jaws;
  return group;
}
function poseShears(tool, open) {
  tool.userData.jaws[0].rotation.y = open;
  tool.userData.jaws[1].rotation.y = -open;
}

export function createHero() {
  const hero = new THREE.Group();
  hero.name = "Scrapkeep hamster";
  const shell = rigid(hero);
  const cageGeometry = new THREE.TorusGeometry(0.9, 0.045, 6, 28);
  for (let i = 0; i < 3; i++) {
    const rib = mesh(shell, cageGeometry, i === 1 ? M.copper : M.steel);
    rib.rotation.set(i === 0 ? Math.PI / 2 : 0, i === 2 ? Math.PI / 2 : 0, 0);
  }
  for (let i = 0; i < 24; i++) {
    const y = 1 - (2 * (i + 0.5)) / 24;
    const angle = i * 2.399963;
    const radial = Math.sqrt(1 - y * y);
    const x = radial * Math.cos(angle),
      z = radial * Math.sin(angle);
    const patch = box(
      shell,
      [M.sage, M.cream, M.ochre, M.copper][i % 4],
      x * 0.89,
      y * 0.89,
      z * 0.89,
      0.31 + (i % 3) * 0.055,
      0.16,
      0.3,
    );
    patch.quaternion.setFromUnitVectors(up, direction.set(x, y, z));
    if (i % 3 === 0) ball(shell, M.copper, x * 1.01, y * 1.01, z * 1.01, 0.055);
  }
  consolidate(shell);
  cageGeometry.dispose();
  const ports = rigid(hero);
  const viewportGeometry = new THREE.TorusGeometry(0.58, 0.045, 6, 28);
  for (const side of [-1, 1]) {
    mesh(ports, viewportGeometry, M.cream, 0, 0.03, side * 0.72);
    for (const x of [-0.47, 0.47]) {
      ball(ports, M.copper, x, -0.3, side * 0.72, 0.052);
      rod(
        ports,
        M.steel,
        x,
        -0.3,
        side * 0.72,
        x * 1.5,
        -0.36,
        side * 0.36,
        0.045,
      );
    }
  }
  consolidate(ports);
  viewportGeometry.dispose();
  const cockpit = rigid(hero);
  cockpit.position.set(0, -0.42, 0);
  cockpit.scale.setScalar(0.95);
  const cabin = rigid(cockpit);
  ball(cabin, M.steel, 0, -0.13, 0, 0.67, 0.25, 0.63);
  const hatch = mesh(cabin, G.ring, M.cream, 0, 0.08, 0, 0.66);
  hatch.rotation.x = Math.PI / 2;
  box(cabin, M.ochre, 0, 0.05, 0.36, 0.62, 0.49, 0.14);
  ball(cabin, M.fur, 0, 0.34, -0.02, 0.31, 0.35, 0.26);
  ball(cabin, M.pale, 0, 0.27, -0.2, 0.22, 0.22, 0.1);
  ball(cabin, M.fur, 0, 0.66, -0.08, 0.34, 0.29, 0.28);
  for (const side of [-1, 1]) {
    ball(cabin, M.fur, side * 0.27, 0.87, -0.05, 0.14, 0.17, 0.095);
    ball(cabin, M.pink, side * 0.27, 0.88, -0.135, 0.085, 0.105, 0.025);
    ball(cabin, M.pale, side * 0.15, 0.56, -0.29, 0.18, 0.15, 0.1);
    ball(cabin, M.eye, side * 0.15, 0.72, -0.32, 0.057, 0.066, 0.03);
    ball(cabin, M.pale, side * 0.14 - 0.012, 0.737, -0.348, 0.017);
    ball(cabin, M.fur, side * 0.3, 0.35, -0.23, 0.11, 0.13, 0.11);
    rod(
      cabin,
      M.steel,
      side * 0.3,
      0.24,
      -0.35,
      side * 0.28,
      0.41,
      -0.37,
      0.035,
    );
  }
  ball(cabin, M.pink, 0, 0.62, -0.4, 0.061, 0.042, 0.04);
  box(cabin, M.pale, 0, 0.505, -0.375, 0.085, 0.09, 0.033);
  rod(cabin, M.cream, -0.61, 0.08, 0.15, -0.44, 0.89, 0.27, 0.028);
  rod(cabin, M.cream, 0.61, 0.08, 0.15, 0.44, 0.89, 0.27, 0.028);
  consolidate(cabin);
  ball(cockpit, M.glass, 0, 0.5, -0.01, 0.68, 0.7, 0.65).renderOrder = 2;
  const shear = shears(hero, 0.38);
  shear.position.set(0.78, -0.05, -0.2);
  poseShears(shear, 0.28);
  const brace = rigid(hero);
  for (const side of [-1, 1]) {
    rod(brace, M.cream, side * 0.5, 0.2, 0.78, side * 0.92, -0.45, 0.35, 0.1);
    pivot(brace, side * 0.5, 0.2, 0.8, 0.16);
    box(brace, M.ochre, side * 0.84, -0.47, 0.34, 0.38, 0.16, 0.44);
  }
  consolidate(brace);
  shear.visible = false;
  brace.visible = false;
  hero.userData = { shell, cockpit, ports, shear, brace };
  return hero;
}
export function updateHero(group, player, dt, time) {
  const data = group.userData;
  group.position.set(player.x, player.y, player.z);
  group.scale.setScalar(player.radius);
  const speed = Math.hypot(player.vx, player.vz);
  if (speed > 0.0001 && dt > 0) {
    rollingAxis.set(player.vz / speed, 0, -player.vx / speed);
    rollingRotation.setFromAxisAngle(rollingAxis, (speed * dt) / player.radius);
    data.shell.quaternion.premultiply(rollingRotation);
  }
  data.cockpit.rotation.y = -player.yaw;
  data.ports.rotation.y = -player.yaw;
  data.cockpit.rotation.z = Math.sin(time * 4) * Math.min(speed * 0.003, 0.035);
  data.shear.rotation.y = -player.yaw;
  data.shear.visible = player.shear > 0;
  data.brace.visible = player.brace > 0;
}

function face(parent, x, y, z, scale = 1, eyeMaterial = M.glow) {
  box(parent, M.rubber, x, y, z, 0.8 * scale, 0.36 * scale, 0.22 * scale);
  for (const side of [-1, 1])
    ball(
      parent,
      eyeMaterial,
      x + side * 0.21 * scale,
      y,
      z - 0.12 * scale,
      0.066 * scale,
    );
}
function cart(parent) {
  box(parent, M.sage, 0, 0.51, 0, 1.7, 0.59, 1.75);
  box(parent, M.cream, 0, 0.74, 0, 1.83, 0.12, 1.83);
  box(parent, M.ochre, 0, 0.46, -0.96, 1.5, 0.2, 0.22);
  for (const x of [-0.92, 0.92])
    for (const z of [-0.54, 0.58]) {
      const tire = mesh(
        parent,
        G.cylinder,
        M.rubber,
        x,
        0.37,
        z,
        0.38,
        0.26,
        0.38,
      );
      tire.rotation.z = Math.PI / 2;
      const hub = mesh(
        parent,
        G.cylinder,
        M.ochre,
        x * 1.13,
        0.37,
        z,
        0.18,
        0.04,
        0.18,
      );
      hub.rotation.z = Math.PI / 2;
    }
  face(parent, 0, 0.92, -0.75);
  box(parent, M.ochre, 0, 0.96, 0.63, 1.08, 0.4, 0.5);
  for (let i = 0; i < 5; i++) {
    rod(
      parent,
      M.soil,
      -0.4 + i * 0.18,
      1.03,
      0.7,
      -0.56 + i * 0.24,
      1.65 + (i % 2) * 0.25,
      0.7,
      0.035,
    );
    ball(
      parent,
      M.leaf,
      -0.56 + i * 0.24,
      1.5 + (i % 2) * 0.25,
      0.7,
      0.14,
      0.24,
      0.075,
    );
  }
}
function createSnipcart() {
  const group = new THREE.Group();
  const base = rigid(group);
  cart(base);
  consolidate(base);
  const neck = rigid(group);
  neck.position.set(0, 0.78, -0.23);
  box(neck, M.sage, 0, 0.34, 0.06, 0.62, 0.75, 0.54);
  rod(neck, M.cream, -0.4, 0.06, 0.22, -0.4, 0.68, -0.56, 0.095);
  rod(neck, M.steel, 0.28, 0.08, 0.2, 0.28, 0.61, -0.51, 0.08);
  pivot(neck, 0, 0.51, -0.15, 0.35);
  consolidate(neck);
  const tool = shears(neck, 0.88);
  tool.position.set(0, 0.66, -0.5);
  group.userData = { kind: "snipcart", neck, tool };
  return group;
}
function createSpreadleg() {
  const group = new THREE.Group();
  const body = rigid(group);
  const core = rigid(body);
  box(core, M.sage, 0, -0.05, 0, 0.96, 0.8, 0.7);
  pivot(core, 0, 0.31, -0.06, 0.5);
  for (const side of [-1, 1])
    rod(
      core,
      M.cream,
      side * 0.39,
      -0.25,
      -0.27,
      side * 0.43,
      0.67,
      -0.07,
      0.1,
    );
  face(core, 0, -0.07, -0.48, 0.77);
  box(core, M.cream, 0, -0.46, -0.41, 0.6, 0.27, 0.1);
  consolidate(core);
  const legs = [-1, 1].map((side) => {
    const upper = rigid(body);
    upper.position.x = side * 0.37;
    const upperParts = rigid(upper);
    box(upperParts, M.sage, 0, -0.75, 0, 0.42, 1.4, 0.38);
    rod(
      upperParts,
      M.cream,
      -side * 0.15,
      -0.15,
      -0.25,
      side * 0.18,
      -1.25,
      -0.25,
      0.07,
    );
    pivot(upperParts, 0, 0, -0.12, 0.26);
    pivot(upperParts, 0, -1.5, -0.11, 0.32);
    consolidate(upperParts);
    const lower = rigid(upper);
    lower.position.y = -1.5;
    const lowerParts = rigid(lower);
    box(lowerParts, M.sage, 0, -0.67, 0, 0.44, 1.25, 0.43);
    rod(
      lowerParts,
      M.cream,
      side * 0.2,
      -0.13,
      -0.3,
      -side * 0.17,
      -1.18,
      -0.3,
      0.08,
    );
    pivot(lowerParts, 0, -1.3, -0.2, 0.22);
    consolidate(lowerParts);
    const foot = rigid(lower);
    foot.position.y = -1.4;
    box(foot, M.ochre, 0, -0.04, -0.17, 0.91, 0.25, 0.94);
    box(foot, M.rubber, 0, -0.18, -0.17, 0.94, 0.12, 0.97);
    consolidate(foot);
    return { side, upper, lower, foot };
  });
  group.userData = { kind: "spreadleg", body, legs };
  return group;
}
function createPruner() {
  const group = new THREE.Group();
  const foundation = rigid(group);
  box(foundation, M.sage, 0, 0.5, 0.8, 3.5, 0.7, 3.1);
  for (const side of [-1, 1]) {
    rod(
      foundation,
      M.cream,
      side * 0.9,
      0.6,
      0.8,
      side * 2.45,
      0.3,
      -0.3,
      0.23,
    );
    box(foundation, M.rubber, side * 2.3, 0.19, -0.3, 1.2, 0.38, 1.35);
    box(foundation, M.ochre, side * 2.3, 0.39, -0.3, 1.15, 0.2, 1.2);
  }
  pivot(foundation, 0, 1, 0.55, 1.04, true);
  face(foundation, 0, 0.79, -0.84, 1.1);
  const spool = mesh(
    foundation,
    G.cylinder,
    M.copper,
    1.65,
    1.2,
    1.45,
    0.47,
    0.85,
    0.47,
  );
  spool.rotation.z = Math.PI / 2;
  for (const x of [1.2, 2.1]) {
    const flange = mesh(
      foundation,
      G.cylinder,
      M.ochre,
      x,
      1.2,
      1.45,
      0.64,
      0.13,
      0.64,
    );
    flange.rotation.z = Math.PI / 2;
  }
  consolidate(foundation);
  const arm = rigid(group);
  arm.position.set(0, 1.0, 0.55);
  arm.rotation.order = "YXZ";
  const beam = rigid(arm);
  for (const side of [-1, 1]) {
    rod(beam, M.sage, side * 0.4, 0, 0.4, side * 0.4, 2.7, 0.1, 0.35);
    rod(beam, M.sage, side * 0.4, 2.7, 0.1, side * 0.4, 0.75, -2.2, 0.3);
    rod(beam, M.cream, side * 0.73, 2.35, 0.1, side * 0.73, 1.0, -1.65, 0.17);
    box(beam, M.rubber, side * 0.43, 0.7, -2.15, 0.5, 0.35, 0.9);
    rod(beam, M.copper, side * 0.2, 0.36, 0.1, side * 0.2, 1.95, 0, 0.1);
  }
  pivot(beam, 0, 2.7, 0.15, 0.8);
  pivot(beam, 0, 0.72, -2.05, 0.58);
  consolidate(beam);
  const tool = shears(arm, 1.8);
  tool.position.set(0, 0.75, -2.2);
  const cable = rod(group, M.rubber, 1.65, 1.65, 1.45, 0, 1.85, -1.65, 0.075);
  const latch = rigid(group);
  box(latch, M.ochre, 1.67, 0.88, 0.29, 0.56, 0.62, 0.32);
  rod(latch, M.cream, 1.47, 0.97, 0.08, 1.87, 0.8, 0.08, 0.07);
  consolidate(latch);
  group.userData = { kind: "pruner", arm, tool, cable, latch };
  return group;
}
const enemyFactories = {
  snipcart: createSnipcart,
  spreadleg: createSpreadleg,
  pruner: createPruner,
};
export function createEnemy(kind) {
  const factory = enemyFactories[kind];
  if (!factory) throw new Error(`Unknown orchard enemy ${kind}`);
  const group = factory();
  group.name = kind;
  group.userData.signalMaterial = M.glow.clone();
  const beacon = ball(
    group,
    group.userData.signalMaterial,
    0,
    kind === "pruner" ? 4.2 : kind === "spreadleg" ? 3.9 : 2,
    0,
    0.11,
  );
  group.userData.beacon = beacon;
  return group;
}
function stroke(state, phase) {
  if (state === "active") return phase;
  if (state === "recovery") return 1 - phase;
  return 0;
}
export function updateEnemy(group, enemy, time) {
  const data = group.userData;
  const phase = Math.max(0, Math.min(1, enemy.phase));
  const attack = stroke(enemy.state, phase);
  const preparing = enemy.state === "windup";
  group.position.set(enemy.x, enemy.y, enemy.z);
  group.rotation.y = -enemy.yaw;
  const dead = enemy.state === "dead";
  data.signalMaterial.emissive.setHex(
    dead
      ? 0x000000
      : enemy.hitFlash > 0
        ? 0xffffff
        : enemy.state === "recovery"
          ? 0x78ffc4
          : preparing
            ? 0xffa24a
            : 0xffc157,
  );
  data.signalMaterial.emissiveIntensity = dead
    ? 0
    : preparing
      ? 0.9 + Math.sin(time * 15) * 0.45
      : 0.65 + Math.max(0, enemy.hitFlash) * 3;
  if (data.kind === "snipcart") {
    data.neck.rotation.x = dead
      ? -0.6
      : enemy.state === "recovery"
        ? -0.35 * Math.sin(phase * Math.PI)
        : 0;
    data.neck.position.y =
      0.78 - (preparing ? phase * 0.08 : enemy.state === "active" ? 0.08 : 0);
    poseShears(
      data.tool,
      dead
        ? 0.03
        : preparing
          ? 0.12 + phase * 0.46
          : enemy.state === "active"
            ? 0.58 * (1 - attack)
            : 0.12,
    );
  } else if (data.kind === "spreadleg") {
    const angle = dead ? 1.15 : 0.2 + attack * 0.83;
    data.body.position.y =
      0.28 + 1.5 * Math.cos(angle) + 1.4 * Math.cos(angle * 0.3);
    for (const leg of data.legs) {
      leg.upper.rotation.z = leg.side * angle;
      leg.lower.rotation.z = -leg.side * angle * 0.7;
      leg.foot.rotation.z = -leg.side * angle * 0.3;
    }
    data.beacon.position.y = data.body.position.y + 0.92;
  } else {
    const tossing = enemy.attackStyle === "toss" && !dead;
    const sweep = tossing
      ? 0
      : dead
        ? 0.7
        : preparing
          ? -phase * 0.67
          : enemy.state === "active"
            ? -0.67 + attack * 1.34
            : enemy.state === "recovery"
              ? (1 - phase) * 0.67
              : 0;
    data.arm.rotation.y = sweep;
    if (tossing) {
      const flick = Math.min(1, phase * 3);
      const recoil = Math.max(0, (phase - 1 / 3) * 1.5);
      data.arm.rotation.x = preparing
        ? phase * 0.32
        : enemy.state === "active"
          ? 0.32 * (1 - flick) + 0.1 * Math.sin(recoil * Math.PI)
          : enemy.state === "recovery"
            ? 0.1 * Math.sin(phase * Math.PI)
            : 0;
      poseShears(
        data.tool,
        preparing
          ? 0.12 - phase * 0.07
          : enemy.state === "active"
            ? 0.05 + flick * 0.25
            : enemy.state === "recovery"
              ? 0.3 - phase * 0.18
              : 0.12,
      );
    } else {
      data.arm.rotation.x = dead
        ? -0.48
        : enemy.state === "recovery"
          ? -Math.sin(phase * Math.PI) * 0.2
          : 0;
      poseShears(
        data.tool,
        dead
          ? 0.05
          : preparing
            ? 0.12 + phase * 0.23
            : enemy.state === "active"
              ? 0.35 * (1 - attack)
              : 0.12,
      );
    }
    const cosX = Math.cos(data.arm.rotation.x),
      sinX = Math.sin(data.arm.rotation.x);
    const cy = 0.85 * cosX + 2.2 * sinX;
    const cz = 0.85 * sinX - 2.2 * cosX;
    setRod(
      data.cable,
      1.65,
      1.65,
      1.45,
      Math.sin(sweep) * cz,
      1 + cy,
      0.55 + Math.cos(sweep) * cz,
      0.075,
    );
    data.latch.visible = enemy.hp > enemy.maxHp * 0.4;
  }
}

export function createPickup(kind) {
  const group = new THREE.Group();
  group.name = `${kind} pickup`;
  if (kind === "shear") {
    const tool = shears(group, 0.2);
    poseShears(tool, 0.36);
    tool.rotation.z = 0.3;
  } else if (kind === "brace") {
    rod(group, M.cream, -0.28, -0.17, 0, 0.26, 0.2, 0, 0.09);
    pivot(group, -0.28, -0.17, 0, 0.17);
    pivot(group, 0.26, 0.2, 0, 0.17);
    consolidate(group);
  } else if (kind === "heart") {
    ball(group, M.pink, -0.12, 0.1, 0, 0.2);
    ball(group, M.pink, 0.12, 0.1, 0, 0.2);
    const tip = box(group, M.pink, 0, -0.065, 0, 0.3, 0.3, 0.27);
    tip.rotation.z = Math.PI / 4;
    consolidate(group);
  } else {
    box(group, M.ochre, 0, 0, 0, 0.38, 0.34, 0.29).rotation.z = 0.3;
    mesh(group, G.ring, M.cream, 0.17, 0.12, 0, 0.2);
    box(group, M.sage, -0.12, 0.11, -0.07, 0.3, 0.13, 0.41);
    consolidate(group);
  }
  return group;
}
export function createCompanion() {
  const group = new THREE.Group();
  group.name = "Shear buddy";
  const chassis = rigid(group);
  box(chassis, M.sage, 0, 0.35, 0, 0.7, 0.47, 0.67);
  for (const side of [-1, 1]) {
    box(chassis, M.rubber, side * 0.43, 0.18, 0, 0.24, 0.28, 0.8);
    rod(
      chassis,
      M.cream,
      side * 0.26,
      0.39,
      0.22,
      side * 0.45,
      0.2,
      -0.2,
      0.055,
    );
  }
  face(chassis, 0, 0.39, -0.38, 0.52);
  rod(chassis, M.copper, 0.2, 0.55, 0.22, 0.22, 0.94, 0.24, 0.028);
  ball(chassis, M.glow, 0.22, 0.95, 0.24, 0.065);
  consolidate(chassis);
  const tool = shears(group, 0.29);
  tool.position.set(0, 0.7, -0.2);
  poseShears(tool, 0.28);
  group.userData.shears = tool.userData.jaws;
  return group;
}

export function createGreenhouse() {
  const group = new THREE.Group();
  group.name = "Orchard nursery greenhouse";
  const structure = rigid(group);
  box(structure, M.sage, 0, 1.1, 0, 22, 2.1, 12);
  box(structure, M.cream, 0, 2.25, 0, 22.6, 0.3, 12.6);
  for (const x of [-10, -5, 0, 5, 10]) {
    box(structure, M.steel, x, 0.38, 0, 1.45, 0.75, 12.8);
    for (const z of [-5.9, 5.9]) {
      rod(structure, M.cream, x, 2.4, z, x, 8.1, z, 0.13);
      rod(structure, M.cream, x, 8.1, z, x, 11.4, 0, 0.13);
    }
  }
  for (const y of [3.2, 5.8, 8.1])
    for (const z of [-5.9, 5.9])
      rod(structure, M.cream, -10.5, y, z, 10.5, y, z, 0.12);
  rod(structure, M.cream, -10.5, 11.4, 0, 10.5, 11.4, 0, 0.16);
  for (const x of [-10.4, 10.4]) {
    rod(structure, M.cream, x, 8.1, -5.9, x, 8.1, 5.9, 0.12);
    rod(structure, M.cream, x, 2.4, 0, x, 11.4, 0, 0.12);
  }
  box(structure, M.steel, 0, 4.6, 6, 3.1, 4.5, 0.16);
  box(structure, M.sage, 0, 4.5, 6.12, 2.6, 4.1, 0.15);
  box(structure, M.cream, 0, 6.9, 6.25, 4.1, 0.63, 0.25);
  ball(structure, M.ochre, 0.85, 4.3, 6.27, 0.11);
  face(structure, 0, 5.3, 6.27, 1.45);
  for (const side of [-1, 1]) {
    box(structure, M.ochre, side * 6.5, 2.8, 6.6, 5.5, 0.85, 1.4);
    box(structure, M.soil, side * 6.5, 3.25, 6.6, 5.1, 0.1, 1.1);
    for (let i = 0; i < 6; i++) {
      const x = side * 6.5 - 2.15 + i * 0.86;
      rod(structure, M.soil, x, 3.3, 6.6, x, 4.5 + (i % 2) * 0.4, 6.6, 0.05);
      mesh(
        structure,
        G.ico,
        M.leaf,
        x,
        4.25 + (i % 2) * 0.4,
        6.6,
        0.4,
        0.65,
        0.4,
      );
      ball(structure, M.apple, x + 0.21, 4.28, 6.88, 0.14);
    }
    for (let i = 0; i < 4; i++) {
      const x = side * 5.5 + (i % 2) * 1.6;
      const z = -2 + Math.floor(i / 2) * 3.2;
      box(structure, M.copper, x, 3.1, z, 0.9, 1.3, 0.9);
      rod(structure, M.soil, x, 3.6, z, x, 6.3, z, 0.1);
      mesh(structure, G.ico, M.leaf, x, 5.8, z, 1.2, 1.6, 1.1);
      ball(structure, M.apple, x + 0.7, 5.8, z + 0.6, 0.23);
    }
  }
  rod(structure, M.copper, -7, 11, 0, -7, 13, 0, 0.06);
  box(structure, M.cream, -6.2, 12.6, 0, 1.6, 0.8, 0.08);
  ball(structure, M.leaf, -6.2, 12.6, -0.08, 0.25, 0.29, 0.05);
  consolidate(structure);
  const glazing = rigid(group);
  for (const z of [-5.9, 5.9]) box(glazing, M.glass, 0, 5.3, z, 21, 5.6, 0.04);
  for (const side of [-1, 1]) {
    const panel = box(glazing, M.glass, 0, 9.75, side * 2.95, 21, 0.04, 6.76);
    panel.rotation.x = side * 0.51;
  }
  consolidate(glazing);
  return group;
}
