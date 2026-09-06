import test from "node:test";
import assert from "node:assert/strict";
import * as THREE from "three";
import { groundHeight } from "../src/orchard/simulation.js";
import { OrchardScene } from "../src/orchard/scene.js";

function sceneHarness() {
  const scene = Object.create(OrchardScene.prototype);
  scene.scene = new THREE.Scene();
  scene.hazards = new Map();
  return scene;
}
test("rendered diagonal capsule rectangle joins the actual damaging endpoints", () => {
  const scene = sceneHarness(),
    s = { x1: 0, z1: 0, x2: 2, z2: -3, radius: 0.4 };
  scene.updateHazards([
    { id: "diagonal", kind: "cut", state: "active", phase: 0.5, segments: [s] },
  ]);
  const mesh = scene.hazards.get("diagonal").pieces[0].body;
  mesh.updateMatrixWorld(true);
  const ends = [
    new THREE.Vector3(0, -0.5, 0),
    new THREE.Vector3(0, 0.5, 0),
  ].map((v) => v.applyMatrix4(mesh.matrixWorld));
  const actual = ends.map((p) => [p.x, p.z]).sort((a, b) => a[0] - b[0]);
  assert.ok(Math.abs(actual[0][0]) < 1e-8 && Math.abs(actual[0][1]) < 1e-8);
  assert.ok(
    Math.abs(actual[1][0] - 2) < 1e-8 && Math.abs(actual[1][1] + 3) < 1e-8,
  );
});
test("offcut windup previews no physical chunk; actual released chunk is visible", () => {
  const scene = sceneHarness(),
    s = { x1: 0, z1: -10, x2: 0, z2: 8, radius: 0.65 };
  scene.updateHazards([
    {
      id: "preview",
      kind: "offcut",
      state: "windup",
      phase: 0.4,
      x: 0,
      z: -10,
      bodyRadius: 0.65,
      segments: [],
      previewSegments: [s],
    },
  ]);
  assert.equal(scene.hazards.get("preview").chunk.visible, false);
  scene.updateHazards([
    {
      id: "flight",
      kind: "offcut",
      state: "active",
      phase: 0.05,
      x: 0,
      z: -9,
      bodyRadius: 0.65,
      segments: [{ ...s, z2: -9 }],
    },
  ]);
  assert.equal(scene.hazards.has("preview"), false);
  assert.equal(scene.hazards.get("flight").chunk.visible, true);
  assert.equal(scene.hazards.get("flight").chunk.position.z, -9);
  scene.updateHazards([]);
  assert.equal(scene.hazards.size, 0);
  assert.equal(scene.scene.children.length, 0);
});

function cameraHarness() {
  const scene = sceneHarness();
  Object.assign(scene, {
    camera: new THREE.PerspectiveCamera(65, 16 / 9, 0.12, 180),
    raycaster: new THREE.Raycaster(),
    follow: new THREE.Vector3(),
    target: new THREE.Vector3(),
    yaw: 0,
    pitch: 0.24,
    zoom: 1,
    shake: 0,
    focusBlend: 0,
    blockers: [],
    view: { aiming: false, sensitivity: 1, impactShake: 0 },
  });
  return scene;
}
const player = { x: 0, y: 1, z: 0, radius: 1 };
test("mouse orbit refreshes the actual center ray and supports vertical aim", () => {
  const scene = cameraHarness();
  scene.frameCamera(player, 1 / 60);
  assert.ok(scene.aimRay().direction.y < 0);
  scene.orbit(0, -450);
  const upward = scene.aimRay();
  assert.ok(
    upward.direction.y > 0.2,
    "upward aim must not wait for the next render",
  );
  scene.orbit(300, 900);
  const downward = scene.aimRay();
  assert.ok(downward.direction.y < -0.5);
  assert.ok(downward.direction.x > 0.1);
  assert.ok(Math.abs(scene.pitch - 1.14) < 1e-8);
  assert.ok(
    Math.abs(new THREE.Vector3().copy(downward.direction).length() - 1) < 1e-8,
  );
});
test("focused framing preserves the center target while closing camera distance", () => {
  const scene = cameraHarness();
  scene.frameCamera(player, 1 / 60);
  const target = scene.target.clone(),
    start = scene.camera.position.clone();
  scene.setView({ aiming: true });
  scene.frameCamera(player, 0.5);
  assert.ok(scene.target.distanceTo(target) < 1e-8);
  const ray = scene.aimRay();
  assert.ok(
    new THREE.Ray(
      new THREE.Vector3().copy(ray.origin),
      new THREE.Vector3().copy(ray.direction),
    ).distanceToPoint(target) < 1e-8,
  );
  assert.ok(
    scene.camera.position.distanceTo(target) < start.distanceTo(target),
  );
  assert.ok(scene.camera.fov < 54);
});
function attackHarness() {
  const scene = sceneHarness();
  Object.assign(scene, {
    tmp: new THREE.Vector3(),
    effectGeo: new THREE.CylinderGeometry(1, 1, 1, 6),
    effects: [],
    effectPool: [],
    particles: [],
  });
  return scene;
}
const attack = {
  kind: "strike",
  valid: true,
  origin: { x: 1, y: 5, z: -10 },
  point: { x: 3, y: 1, z: -18 },
  radius: 4,
  segments: [{ from: { x: 1, y: 5, z: -10 }, to: { x: 3, y: 1, z: -18 } }],
};
test("preview and attack effects preserve authoritative 3D endpoints and terrain area", () => {
  const scene = attackHarness(),
    visual = scene.makeAttackVisual();
  scene.updateAttackVisual(visual, attack);
  const segment = visual.pieces[0];
  segment.updateMatrixWorld(true);
  const endpoints = [-0.5, 0.5].map((y) =>
    new THREE.Vector3(0, y, 0).applyMatrix4(segment.matrixWorld),
  );
  assert.ok(
    endpoints[0].distanceTo(new THREE.Vector3().copy(attack.origin)) < 1e-8,
  );
  assert.ok(
    endpoints[1].distanceTo(new THREE.Vector3().copy(attack.point)) < 1e-8,
  );
  const positions = visual.ring.geometry.attributes.position;
  for (let i = 0; i < positions.count; i++) {
    assert.ok(
      Math.abs(
        positions.getY(i) -
          groundHeight(positions.getX(i), positions.getZ(i)) -
          0.09,
      ) < 1e-6,
    );
    assert.ok(
      Math.hypot(positions.getX(i) - 3, positions.getZ(i) + 18) <= 4.000001,
    );
  }
  scene.event({ type: "attack", source: "player", attack });
  const committed = scene.effects[0].visual;
  assert.deepEqual(
    committed.pieces[0].position.toArray(),
    segment.position.toArray(),
  );
  assert.deepEqual(
    committed.marker.position.toArray(),
    visual.marker.position.toArray(),
  );
  scene.updateAttackVisual(visual, {
    ...attack,
    valid: false,
    radius: 0,
    blocked: true,
  });
  assert.equal(visual.ring.visible, false);
  assert.equal(visual.mat.color.getHex(), 0xff705b);
});
test("lightning effect allocation stays bounded during repeated chained echoes", () => {
  const scene = attackHarness();
  for (let i = 0; i < 200; i++)
    scene.event({ type: "attack", source: "conductor", echo: true, attack });
  assert.equal(scene.effects.length, 16);
  assert.equal(scene.scene.children.length, 16);
  assert.equal(scene.effects[0].visual.mat.color.getHex(), 0xd6aaff);
});
test("tall warning displays exact vertical danger bounds; jumpable warning stays on ground", () => {
  const scene = sceneHarness();
  const hazard = {
    id: "height",
    kind: "cut",
    state: "active",
    phase: 0.5,
    segments: [{ x1: 0, z1: 0, x2: 2, z2: -3, radius: 0.4 }],
    yMin: 1.4,
    yMax: 2.1,
    jumpable: false,
  };
  scene.updateHazards([hazard]);
  const record = scene.hazards.get("height");
  assert.equal(record.height.visible, true);
  const positions = record.height.geometry.attributes.position;
  assert.ok(Math.abs(positions.getY(0) - 1.4) < 1e-6);
  assert.ok(Math.abs(positions.getY(1) - 2.1) < 1e-6);
  const tallColor = record.fill.color.getHex();
  scene.updateHazards([{ ...hazard, jumpable: true }]);
  assert.equal(record.height.visible, false);
  assert.notEqual(record.fill.color.getHex(), tallColor);
});

test("restart returns dynamic models and effects to bounded pools and clears overlays", () => {
  const scene = attackHarness();
  Object.assign(scene, {
    pickups: new Map(),
    pickupPool: new Map(),
    enemies: new Map(),
    enemyPool: new Map(),
    conductors: new Map(),
    conductorPool: [],
    particleMesh: { count: 7 },
  });
  scene.preview = scene.makeAttackVisual();
  scene.conductorLink = scene.makeAttackVisual();
  const enemy = new THREE.Group();
  enemy.userData.kind = "snipcart";
  scene.scene.add(enemy);
  scene.enemies.set("worker", enemy);
  scene.updateConductors([{ id: 1, x: 1, y: 0, z: 2 }]);
  scene.event({ type: "attack", source: "player", attack });
  scene.updateAttackVisual(scene.preview, attack);
  scene.clear();
  assert.equal(scene.enemies.size, 0);
  assert.equal(scene.enemyPool.get("snipcart").length, 1);
  assert.equal(scene.conductors.size, 0);
  assert.equal(scene.conductorPool.length, 1);
  assert.equal(scene.effectPool.length, 1);
  assert.equal(scene.effects.length, 0);
  assert.equal(scene.particleMesh.count, 0);
  assert.equal(scene.preview.group.visible, false);
  scene.clear();
  assert.equal(
    scene.effectPool.length,
    1,
    "repeated clear must not add duplicate pool entries",
  );
});
