import test from "node:test";
import assert from "node:assert/strict";
import * as THREE from "three";
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
