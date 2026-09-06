import assert from "node:assert/strict";
import * as THREE from "three";
import {
  createHero,
  updateHero,
  createEnemy,
  updateEnemy,
  createPickup,
  createCompanion,
  createConductor,
  createGreenhouse,
} from "../src/orchard/models.js";
const counts = (group) => {
  let meshes = 0,
    triangles = 0;
  group.traverse((object) => {
    if (!object.isMesh) return;
    meshes++;
    triangles +=
      (object.geometry.index?.count ??
        object.geometry.attributes.position.count) / 3;
    for (const key of ["position", "normal"])
      for (const value of object.geometry.attributes[key].array)
        assert(Number.isFinite(value), key);
  });
  return { meshes, triangles };
};
const finite = (group) => {
  group.updateMatrixWorld(true);
  group.traverse((object) => {
    for (const value of object.matrixWorld.elements)
      assert(Number.isFinite(value), object.name);
  });
};
const results = {};
const hero = createHero();
const player = {
  x: 0,
  y: 1,
  z: 0,
  radius: 1,
  vx: 3,
  vz: -4,
  yaw: 0,
  shear: 0,
  brace: 0,
};
updateHero(hero, player, 1 / 60, 1);
assert.equal(hero.position.y, player.y);
assert.equal(hero.userData.cockpit.rotation.x, 0);
assert(hero.userData.shell.quaternion.angleTo(new THREE.Quaternion()) > 0);
for (const radius of [1, 1.4, 1.65]) {
  Object.assign(player, { radius, y: radius, shear: 1, brace: 1 });
  updateHero(hero, player, 1 / 60, 10);
  finite(hero);
  assert.equal(hero.scale.x, radius);
  assert(hero.userData.shear.visible && hero.userData.brace.visible);
}
Object.assign(player, { y: 7.5, grounded: false, landingImpact: 10 });
updateHero(hero, player, 1 / 60, 11);
assert.equal(hero.position.y, 7.5);
assert.equal(
  hero.scale.y,
  player.radius,
  "landing deformation never changes the model root or camera anchor",
);
assert(hero.userData.deformation.scale.y < 1);
assert(hero.userData.lightning.visible);
results.hero = counts(hero);
// Check the actual cockpit vertices in unscaled hero space: the entire pilot
// and glass cabin must fit inside the rolling cage at every growth stage.
hero.updateMatrixWorld(true);
let cabinRadius = 0;
const point = new THREE.Vector3();
hero.userData.cockpit.traverse((object) => {
  if (!object.isMesh) return;
  const vertices = object.geometry.attributes.position;
  for (let i = 0; i < vertices.count; i++) {
    point.fromBufferAttribute(vertices, i).applyMatrix4(object.matrixWorld);
    hero.worldToLocal(point);
    cabinRadius = Math.max(cabinRadius, point.length());
  }
});
assert(
  cabinRadius < 0.9,
  `pilot cabin protrudes from scrap cage: ${cabinRadius}`,
);
results.cabinRadius = cabinRadius;
for (const kind of ["snipcart", "spreadleg", "pruner"]) {
  const enemy = createEnemy(kind);
  const state = {
    x: 3,
    y: 2.5,
    z: -20,
    yaw: 1.2,
    phase: 0,
    hp: 90,
    maxHp: 100,
    state: "idle",
    hitFlash: 0,
  };
  for (const pose of [
    "idle",
    "approach",
    "windup",
    "active",
    "recovery",
    "dead",
  ])
    for (let step = 0; step <= 20; step++) {
      Object.assign(state, { state: pose, phase: step / 20 });
      updateEnemy(enemy, state, step / 10);
      finite(enemy);
      assert.equal(enemy.rotation.y, -state.yaw);
      if (pose === "active" && kind === "snipcart")
        assert(
          Math.abs(
            enemy.userData.tool.userData.jaws[0].rotation.y -
              0.58 * (1 - state.phase),
          ) < 1e-10,
        );
      if (pose === "active" && kind === "pruner")
        assert(
          Math.abs(
            enemy.userData.arm.rotation.y - (-0.67 + 1.34 * state.phase),
          ) < 1e-10,
        );
    }
  const other = createEnemy(kind);
  assert.notEqual(enemy.userData.signalMaterial, other.userData.signalMaterial);
  if (kind === "spreadleg") {
    assert.equal(enemy.userData.legs.length, 2);
    Object.assign(state, { state: "active", phase: 0 });
    updateEnemy(enemy, state, 0);
    const height = enemy.userData.body.position.y;
    Object.assign(state, { phase: 1 });
    updateEnemy(enemy, state, 0);
    assert(enemy.userData.body.position.y < height);
    for (const leg of enemy.userData.legs) {
      assert.equal(leg.lower.position.y, -1.5);
      assert.equal(leg.foot.position.y, -1.4);
      enemy.updateMatrixWorld(true);
      const local = leg.foot.getWorldPosition(new THREE.Vector3());
      enemy.worldToLocal(local);
      const expected =
        leg.side * (0.37 + 1.5 * Math.sin(1.03) + 1.4 * Math.sin(0.309));
      assert(
        Math.abs(local.x - expected) < 1e-8,
        "shoe center matches simulation stroke",
      );
      assert(
        Math.abs(local.y - 0.28) < 1e-8,
        "fixed shoe height under articulated lowering",
      );
    }
  }
  if (kind === "pruner") {
    Object.assign(state, { state: "recovery", phase: 0.5 });
    updateEnemy(enemy, state, 0);
    enemy.updateMatrixWorld(true);
    const connected = new THREE.Vector3(0, 0.85, -2.2).applyMatrix4(
      enemy.userData.arm.matrixWorld,
    );
    const cableEnd = new THREE.Vector3(0, 0.5, 0).applyMatrix4(
      enemy.userData.cable.matrixWorld,
    );
    assert(
      connected.distanceTo(cableEnd) < 1e-5,
      "binding cable connects to moving cradle",
    );
  }
  results[kind] = counts(enemy);
}
for (const kind of ["scrap", "shear", "brace", "heart"]) {
  const pickup = createPickup(kind);
  finite(pickup);
  results[kind] = counts(pickup);
}
const companion = createCompanion();
finite(companion);
results.companion = counts(companion);
assert.equal(companion.userData.shears.length, 2);
const conductor = createConductor();
finite(conductor);
results.conductor = counts(conductor);
assert.equal(conductor.userData.electrode.position.y, 1.35);
const greenhouse = createGreenhouse();
finite(greenhouse);
results.greenhouse = counts(greenhouse);
console.log(JSON.stringify(results, null, 2));
console.log(
  "PASS all factories, 126 poses per enemy, finite geometry/matrices, hero roll/growth, two fixed-length legs, connected cable, independent signal materials",
);
