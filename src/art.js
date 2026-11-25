import * as THREE from "three";
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry.js";
import { mergeGeometries } from "three/addons/utils/BufferGeometryUtils.js";
import { PATH, WALLS, FLANK_POINT, seededRandom } from "./game.js";

export const C = {
  navy: 0x071a23,
  petrol: 0x21484a,
  dark: 0x153437,
  ivory: 0xcec3a0,
  light: 0xe5d4af,
  orange: 0xed8746,
  amber: 0xe6a55e,
  mint: 0xa0f6d0,
  copper: 0xb36b40,
  rock: 0x264648,
  sage: 0x698e79,
};
const materials = new Map();
export function mat(color, emissive = 0) {
  const key = `${color}:${emissive}`;
  if (!materials.has(key))
    materials.set(
      key,
      new THREE.MeshStandardMaterial({
        color,
        roughness: emissive ? 0.4 : 0.8,
        metalness: emissive ? 0.05 : 0.13,
        emissive,
        emissiveIntensity: emissive ? 1.15 : 0,
      }),
    );
  return materials.get(key);
}
export const geos = {
  box: new RoundedBoxGeometry(1, 1, 1, 1, 0.065),
  cube: new THREE.BoxGeometry(1, 1, 1),
  cylinder: new THREE.CylinderGeometry(1, 1, 1, 8),
  cone: new THREE.ConeGeometry(1, 1, 6),
  sphere: new THREE.IcosahedronGeometry(1, 2),
  rock: new THREE.IcosahedronGeometry(1, 0),
  torus: new THREE.TorusGeometry(1, 0.13, 6, 24),
  elbow: new THREE.TorusGeometry(1, 0.28, 7, 10, Math.PI / 2),
};
for (const [name, g] of Object.entries(geos)) {
  if (g.index) {
    geos[name] = g.toNonIndexed();
    g.dispose();
  }
}
geos.sphere.computeVertexNormals();
export function mesh(parent, shape, color, x, y, z, sx = 1, sy = 1, sz = 1, emissive = 0) {
  const o = new THREE.Mesh(geos[shape], mat(color, emissive));
  o.position.set(x, y, z);
  o.scale.set(sx, sy, sz);
  o.castShadow = true;
  o.receiveShadow = true;
  parent.add(o);
  return o;
}
const opaqueBatch = new THREE.MeshStandardMaterial({
  vertexColors: true,
  roughness: 0.81,
  metalness: 0.13,
});
const luminousBatch = new THREE.MeshStandardMaterial({
  vertexColors: true,
  color: 0xffffff,
  roughness: 0.5,
  metalness: 0.06,
  emissive: 0xffffff,
  emissiveIntensity: 1.05,
});
luminousBatch.onBeforeCompile = (shader) => {
  shader.fragmentShader = shader.fragmentShader.replace(
    "#include <emissivemap_fragment>",
    "#include <emissivemap_fragment>\n#ifdef USE_COLOR\ntotalEmissiveRadiance *= vColor;\n#endif",
  );
};
luminousBatch.customProgramCacheKey = () => "scrapkeep-emissive-vertices";
export function consolidate(group) {
  group.updateMatrixWorld(true);
  const bins = [[], []];
  group.traverse((o) => {
    if (!o.isMesh) return;
    let geometry = o.geometry.clone().applyMatrix4(o.matrixWorld);
    if (geometry.index) {
      const flat = geometry.toNonIndexed();
      geometry.dispose();
      geometry = flat;
    }
    const glowing = o.material.emissive && o.material.emissive.getHex() > 0;
    const source = glowing ? o.material.emissive : o.material.color;
    if (!geometry.getAttribute("color")) {
      const colors = new Float32Array(geometry.getAttribute("position").count * 3);
      for (let i = 0; i < colors.length; i += 3) {
        colors[i] = source.r;
        colors[i + 1] = source.g;
        colors[i + 2] = source.b;
      }
      geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3));
    }
    if (!geometry.getAttribute("uv"))
      geometry.setAttribute(
        "uv",
        new THREE.BufferAttribute(new Float32Array(geometry.getAttribute("position").count * 2), 2),
      );
    bins[glowing ? 1 : 0].push(geometry);
  });
  const result = new THREE.Group();
  bins.forEach((parts, i) => {
    if (!parts.length) return;
    const merged = new THREE.Mesh(mergeGeometries(parts, false), i ? luminousBatch : opaqueBatch);
    merged.castShadow = true;
    merged.receiveShadow = true;
    result.add(merged);
    parts.forEach((g) => g.dispose());
  });
  return result;
}
function tube(g, color, a, b, r = 0.07) {
  const from = new THREE.Vector3(...a),
    to = new THREE.Vector3(...b),
    delta = to.sub(from),
    o = mesh(
      g,
      "cylinder",
      color,
      ...from.addScaledVector(delta, 0.5).toArray(),
      r,
      delta.length(),
      r,
    );
  o.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), delta.normalize());
  return o;
}
function collar(g, color, x, y, z, r = 0.3, h = 0.08) {
  return mesh(g, "cylinder", color, x, y, z, r, h, r);
}
function bolts(g, y, r, count = 4) {
  for (let i = 0; i < count; i++) {
    const a = (i / count) * Math.PI * 2 + Math.PI / 4;
    collar(g, C.copper, Math.cos(a) * r, y, Math.sin(a) * r, 0.04, 0.06);
  }
}
export function weaponModel(type, ground = false) {
  const g = new THREE.Group();
  collar(g, C.dark, 0, 0.08, 0, 0.35, 0.16);
  collar(g, C.copper, 0, 0.18, 0, 0.33, 0.1);
  collar(g, C.ivory, 0, 0.25, 0, 0.29, 0.1);
  bolts(g, 0.31, 0.23);
  mesh(g, "box", C.orange, 0, 0.42, 0, 0.48, 0.3, 0.42);
  for (const side of [-1, 1]) {
    mesh(g, "box", C.dark, side * 0.26, 0.42, 0, 0.08, 0.2, 0.22);
    mesh(g, "box", C.copper, side * 0.3, 0.43, 0, 0.045, 0.11, 0.1);
  }
  if (type === "bolt") {
    mesh(g, "box", C.amber, 0, 0.62, 0, 0.42, 0.2, 0.4);
    collar(g, C.dark, 0, 0.76, 0, 0.135, 0.3);
    collar(g, C.ivory, 0, 0.89, 0, 0.28, 0.13);
    collar(g, C.copper, 0, 0.964, 0, 0.205, 0.035);
    collar(g, C.dark, 0, 0.985, 0, 0.125, 0.016);
    for (let i = 0; i < 3; i++)
      collar(g, 0x050e12, Math.cos(i * 2.094) * 0.07, 1, Math.sin(i * 2.094) * 0.07, 0.027, 0.01);
    mesh(g, "box", C.ivory, 0, 0.62, -0.24, 0.3, 0.22, 0.1);
    mesh(g, "box", C.dark, 0, 0.63, -0.295, 0.22, 0.12, 0.016);
    mesh(g, "box", C.mint, 0.06, 0.66, -0.308, 0.075, 0.04, 0.009, C.mint);
    mesh(g, "box", C.orange, 0.3, 0.55, 0.14, 0.12, 0.24, 0.16);
  } else if (type === "pipe") {
    collar(g, C.orange, 0, 0.64, 0, 0.29, 0.43);
    collar(g, C.copper, 0, 0.69, 0, 0.32, 0.085);
    collar(g, C.ivory, 0, 0.86, 0, 0.36, 0.15);
    collar(g, C.copper, 0, 0.944, 0, 0.265, 0.025);
    collar(g, C.dark, 0, 0.96, 0, 0.205, 0.012);
    collar(g, 0x060f13, 0, 0.974, 0, 0.135, 0.008);
    const elbow = mesh(g, "elbow", C.copper, -0.3, 0.49, 0, 0.24, 0.24, 0.24);
    elbow.rotation.z = Math.PI;
    tube(g, C.copper, [-0.3, 0.25, 0], [-0.3, 0.49, 0], 0.066);
    collar(g, C.amber, 0, 0.45, 0, 0.31, 0.08);
    bolts(g, 0.95, 0.29, 6);
  } else if (type === "coil") {
    collar(g, C.dark, 0, 0.57, 0, 0.105, 0.6);
    for (let j = 0; j < 4; j++) {
      collar(g, C.copper, 0, 0.44 + j * 0.135, 0, 0.225, 0.035);
      collar(g, C.mint, 0, 0.469 + j * 0.135, 0, 0.215, 0.038, C.mint);
    }
    collar(g, C.dark, 0, 1.035, 0, 0.16, 0.085);
    mesh(g, "box", C.ivory, 0, 1.12, 0, 0.28, 0.15, 0.23);
    mesh(g, "box", C.mint, 0, 1.19, 0, 0.19, 0.04, 0.13, C.mint);
    tube(g, C.copper, [0.23, 0.4, 0.15], [0.23, 0.83, 0.15], 0.03);
  } else {
    collar(g, C.copper, 0, 0.42, 0, 0.27, 0.27);
    collar(g, C.ivory, 0, 0.53, 0, 0.3, 0.09);
    mesh(g, "box", C.sage, 0, 0.78, 0, 0.19, 0.46, 0.2);
    mesh(g, "sphere", C.sage, 0, 1.005, 0, 0.1, 0.1, 0.1);
    for (const side of [-1, 1]) {
      mesh(g, "box", C.sage, side * 0.16, 0.75, 0, 0.23, 0.12, 0.13);
      mesh(g, "box", C.sage, side * 0.25, 0.85, 0, 0.105, 0.29, 0.13);
      mesh(g, "cone", C.light, side * 0.25, 1.045, 0, 0.065, 0.15, 0.065);
    }
    for (const y of [0.66, 0.8, 0.94])
      for (const x of [-0.08, 0.08])
        mesh(g, "cone", C.light, x, y, 0.13, 0.025, 0.08, 0.025).rotation.x = Math.PI / 2;
  }
  if (ground) {
    const base = new THREE.Group();
    mesh(base, "box", C.dark, 0, -0.2, 0, 0.79, 0.25, 0.76);
    mesh(base, "box", C.ivory, 0, -0.085, 0, 0.87, 0.16, 0.83);
    for (const side of [-1, 1]) mesh(base, "box", C.orange, side * 0.38, -0.2, 0, 0.095, 0.18, 0.4);
    if (type === "bolt") {
      g.rotation.z = -0.82;
      g.position.set(-0.12, 0.12, 0);
    }
    if (type === "coil") {
      for (const x of [-0.29, 0.29])
        for (const z of [-0.29, 0.29]) mesh(base, "box", C.petrol, x, 0.65, z, 0.115, 1.04, 0.115);
      mesh(base, "box", C.ivory, 0, 1.2, 0, 0.73, 0.13, 0.73);
      mesh(base, "box", C.mint, 0, 0.76, 0.29, 0.41, 0.5, 0.045, C.mint);
    }
    base.add(g);
    return consolidate(base);
  }

  return consolidate(g);
}
export function enemyModel(type) {
  const g = new THREE.Group(),
    tank = type === "tank",
    boss = type === "boss";
  mesh(g, "sphere", C.dark, 0, 0.38, 0, 0.42, 0.25, 0.57);
  mesh(g, "sphere", tank ? C.copper : 0xc94922, 0, 0.57, -0.025, 0.39, 0.31, 0.49);
  mesh(g, "box", 0xe46529, 0, 0.82, -0.06, 0.28, 0.19, 0.46);
  mesh(g, "box", C.dark, 0, 0.77, -0.05, 0.05, 0.17, 0.49);
  mesh(g, "box", C.dark, 0, 0.51, 0.4, 0.44, 0.15, 0.17);
  for (const x of [-0.155, 0.155]) {
    collar(g, C.copper, x, 0.55, 0.47, 0.097, 0.09).rotation.x = Math.PI / 2;
    mesh(g, "sphere", C.mint, x, 0.57, 0.515, 0.055, 0.05, 0.04, C.mint);
  }
  for (let i = 0; i < 3; i++)
    for (const side of [-1, 1]) {
      const z = (i - 1) * 0.38,
        x = side * (i === 1 ? 0.63 : 0.55),
        spread = (i - 1) * 0.11;
      tube(g, C.dark, [side * 0.28, 0.4, z], [x, 0.56, z + spread], 0.075);
      mesh(g, "sphere", C.orange, x, 0.56, z + spread, 0.11, 0.105, 0.105);
      tube(g, C.dark, [x, 0.56, z + spread], [side * 0.78, 0.14, z + spread + 0.07], 0.065);
      mesh(g, "box", C.dark, side * 0.79, 0.105, z + spread + 0.11, 0.17, 0.1, 0.2);
    }
  for (const side of [-1, 1]) {
    mesh(g, "box", C.ivory, side * 0.255, 0.665, 0.1, 0.115, 0.075, 0.16).rotation.z = side * -0.35;
    collar(g, C.copper, side * 0.2, 0.715, -0.29, 0.06, 0.06);
  }
  if (tank || boss) {
    mesh(g, "box", C.ivory, 0, 0.85, 0, 0.48, 0.13, 0.5);
    collar(g, C.dark, 0, 0.96, 0, 0.18, 0.18);
    mesh(g, "box", C.orange, 0, 1.05, 0.12, 0.18, 0.15, 0.48);
  }
  return consolidate(g);
}
function roadOffsets(width) {
  return PATH.map((p, i) => {
    const prev = PATH[Math.max(0, i - 1)],
      next = PATH[Math.min(PATH.length - 1, i + 1)];
    let ax = p[0] - prev[0],
      az = p[1] - prev[1],
      bx = next[0] - p[0],
      bz = next[1] - p[1];
    let al = Math.hypot(ax, az),
      bl = Math.hypot(bx, bz);
    if (!al) {
      ax = bx;
      az = bz;
      al = bl;
    }
    if (!bl) {
      bx = ax;
      bz = az;
      bl = al;
    }
    ax /= al;
    az /= al;
    bx /= bl;
    bz /= bl;
    const k = width / (1 + ax * bx + az * bz);
    return {
      left: [p[0] + (-az - bz) * k, p[1] + (ax + bx) * k],
      right: [p[0] - (-az - bz) * k, p[1] - (ax + bx) * k],
    };
  });
}
function ribbon(g, points, width, color, y) {
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1],
      b = points[i],
      len = Math.hypot(b[0] - a[0], b[1] - a[1]);
    const part = mesh(
      g,
      "box",
      color,
      (a[0] + b[0]) / 2,
      y,
      (a[1] + b[1]) / 2,
      width,
      0.085,
      len + width,
    );
    part.rotation.y = Math.atan2(b[0] - a[0], b[1] - a[1]);
  }
}
function road(g) {
  const edges = roadOffsets(1.13),
    outline = [...edges.map((p) => p.left), ...edges.map((p) => p.right).reverse()];
  const shape = new THREE.Shape();
  outline.forEach((p, i) => (i ? shape.lineTo(p[0], -p[1]) : shape.moveTo(p[0], -p[1])));
  shape.closePath();
  const geo = new THREE.ExtrudeGeometry(shape, {
    depth: 0.055,
    bevelEnabled: false,
    steps: 1,
  });
  geo.rotateX(-Math.PI / 2);
  const lane = new THREE.Mesh(geo, mat(0x16383e));
  lane.position.y = 0.16;
  lane.receiveShadow = true;
  g.add(lane);
  for (const side of ["left", "right"]) {
    ribbon(
      g,
      edges.map((p) => p[side]),
      0.13,
      C.ivory,
      0.2,
    );
    ribbon(
      g,
      edges.map((p) => p[side]),
      0.052,
      C.orange,
      0.265,
    );
  }
  const curbEdges = roadOffsets(1.42);
  for (const side of ["left", "right"])
    for (let i = 1; i < PATH.length - 1; i++) {
      if (![3, 6, 8, 9, 11, 12, 13, 15, 17].includes(i)) continue;
      if ((i % 2 === 0) !== (side === "left")) continue;
      const a = curbEdges[i - 1][side],
        b = curbEdges[i][side],
        length = Math.hypot(b[0] - a[0], b[1] - a[1]);
      if (length < 3) continue;
      const dx = (b[0] - a[0]) / length,
        dz = (b[1] - a[1]) / length,
        count = Math.ceil(length / 1.1);
      for (let j = 0; j < count; j++) {
        const d = ((j + 0.5) * length) / count,
          x = a[0] + dx * d,
          z = a[1] + dz * d;
        const o = mesh(
          g,
          "box",
          j % 3 ? C.ivory : C.light,
          x,
          0.41,
          z,
          0.31,
          0.48,
          length / count - 0.022,
        );
        o.rotation.y = Math.atan2(dx, dz);
        if (j % 4 === 0) {
          const cap = mesh(g, "box", C.light, x, 0.63, z, 0.4, 0.14, 0.44);
          cap.rotation.y = o.rotation.y;
        }
      }
    }
  for (let i = 1; i < PATH.length; i++) {
    const a = PATH[i - 1],
      b = PATH[i],
      len = Math.hypot(b[0] - a[0], b[1] - a[1]),
      dx = (b[0] - a[0]) / len,
      dz = (b[1] - a[1]) / len;
    for (let d = 1.8; d < len - 0.7; d += 2.8) {
      const x = a[0] + dx * d,
        z = a[1] + dz * d;
      const joint = mesh(
        g,
        "cube",
        0x0f2d32,
        x,
        0.22,
        z,
        dx ? 0.016 : 1.93,
        0.009,
        dx ? 1.93 : 0.016,
      );
      if (d > 3 && i % 2 === 1) {
        const arrow = mesh(g, "cone", 0x748879, x, 0.234, z, 0.09, 0.2, 0.03);
        arrow.rotation.x = Math.PI / 2;
        arrow.rotation.z = -Math.atan2(dx, dz);
      }
    }
  }
}
function masonry(g, w, rand) {
  mesh(g, "box", C.ivory, w.x, 0.45, w.z, w.w + 0.07, 0.72, w.h + 0.08);
  const columns = Math.ceil(w.w / 1.04),
    rows = Math.ceil(w.h / 1.02);
  for (let i = 0; i < columns; i++)
    for (let j = 0; j < rows; j++) {
      const x = w.x - w.w / 2 + ((i + 0.5) * w.w) / columns,
        z = w.z - w.h / 2 + ((j + 0.5) * w.h) / rows;
      mesh(
        g,
        "box",
        [C.ivory, C.light, 0xc2b894, 0xd9cba7][Math.floor(rand() * 4)],
        x,
        0.71,
        z,
        w.w / columns - 0.022,
        0.83 + (rand() - 0.5) * 0.045,
        w.h / rows - 0.022,
      );
    }
  for (let x = w.x - w.w / 2 + 0.2; x < w.x + w.w / 2; x += 1.3) {
    mesh(g, "box", C.light, x, 0.23, w.z + w.h / 2, 0.31, 0.35, 0.18);
    if (rand() > 0.4) mesh(g, "box", C.ivory, x, 1.2, w.z - 0.12, 0.42, 0.32, 0.38);
  }
}
function coneCluster(g, x, z, s, rand) {
  for (let i = 0; i < 5; i++) {
    const rock = mesh(
      g,
      "rock",
      i % 2 ? C.rock : C.dark,
      x + (rand() - 0.5) * 2 * s,
      0.29,
      z + (rand() - 0.5) * 2 * s,
      (0.32 + rand() * 0.4) * s,
      (0.24 + rand() * 0.5) * s,
      (0.35 + rand() * 0.35) * s,
    );
    rock.rotation.set(rand(), rand() * 5, rand());
  }
  for (let i = 0; i < 3; i++) {
    const px = x + (i - 1) * 0.61 * s,
      pz = z + (i % 2) * 0.62 * s,
      scale = (i === 1 ? 1.3 : 0.85) * s;
    mesh(g, "cylinder", C.copper, px, 0.46, pz, 0.095, 0.78, 0.095);
    for (let tier = 0; tier < 4; tier++)
      mesh(
        g,
        "cone",
        tier % 2 ? 0x375959 : 0x284b4d,
        px,
        0.76 + tier * 0.43 * scale,
        pz,
        (0.69 - tier * 0.13) * scale,
        0.99 * scale,
        (0.69 - tier * 0.13) * scale,
      );
  }
}
function equipment(g, x, z, angle, kind = 0) {
  const station = new THREE.Group();
  mesh(station, "box", C.dark, 0, 0.23, 0, 1.0, 0.42, 0.93);
  mesh(station, "box", C.ivory, 0, 0.49, 0, 1.1, 0.13, 1.03);
  if (kind === 0) {
    mesh(station, "box", C.petrol, 0, 0.9, 0, 0.7, 0.71, 0.64);
    mesh(station, "box", C.ivory, 0, 1.29, 0, 0.77, 0.16, 0.72);
    mesh(station, "box", C.dark, 0, 0.94, 0.334, 0.51, 0.46, 0.03);
    mesh(station, "box", C.mint, 0, 0.97, 0.356, 0.27, 0.27, 0.035, C.mint);
    for (const s of [-1, 1])
      mesh(station, "box", C.copper, s * 0.33, 0.87, 0.33, 0.095, 0.54, 0.08);
  } else {
    collar(station, C.orange, 0, 0.71, 0, 0.37, 0.37);
    collar(station, C.dark, 0, 0.95, 0, 0.3, 0.17);
    collar(station, C.ivory, 0, 1.085, 0, 0.42, 0.12);
    for (let i = 0; i < 3; i++) collar(station, C.mint, 0, 1.19 + i * 0.13, 0, 0.26, 0.035, C.mint);
    collar(station, C.dark, 0, 1.5, 0, 0.2, 0.12);
  }
  station.position.set(
    x,
    WALLS.some((w) => Math.abs(x - w.x) < w.w / 2 && Math.abs(z - w.z) < w.h / 2) ? 1.15 : 0,
    z,
  );
  station.rotation.y = angle;
  g.add(station);
}
export function buildYard(scene) {
  const g = new THREE.Group(),
    rand = seededRandom(181);
  mesh(g, "box", 0x65776b, 0, -1.6, 0, 27.75, 3.1, 22);
  mesh(g, "box", C.ivory, 0, -0.17, 0, 28, 0.55, 22.2);
  mesh(g, "box", C.copper, 0, -0.48, 0, 28.06, 0.1, 22.22);
  const paving = [0xd0c39f, 0xc7bd9b, 0xd9ccaa, 0xc1b99a, 0xd3c9a9, 0xcbbf9c];
  for (let row = 0; row < 18; row++) {
    const z = -11 + ((row + 0.5) * 22) / 18;
    let x = -14;
    while (x < 13.99) {
      const width = Math.min(14 - x, 0.95 + rand() * 1.5);
      mesh(
        g,
        "box",
        paving[Math.floor(rand() * paving.length)],
        x + width / 2,
        0.11,
        z,
        width - 0.009,
        0.1,
        22 / 18 - 0.009,
      );
      x += width;
    }
  }
  road(g);
  WALLS.forEach((w) => masonry(g, w, rand));
  for (const z of [-10.86, 10.86])
    for (let x = -13.1; x < 13.7; x += 1.12) {
      mesh(g, "box", rand() > 0.3 ? C.ivory : C.light, x, 0.27, z, 1.08, 0.28, 0.34);
      for (let row = 0; row < 3; row++) {
        const center = x + (row % 2) * 0.2,
          h = 0.66 + rand() * 0.2;
        mesh(
          g,
          "box",
          rand() > 0.2 ? C.ivory : C.rock,
          center,
          -0.72 - row * 0.75,
          z + (rand() - 0.5) * 0.17,
          0.75 + rand() * 0.45,
          h,
          0.5 + rand() * 0.24,
        );
      }
      if (rand() < 0.42) {
        mesh(g, "rock", C.rock, x, -2.82, z + 0.12, 0.4 + rand() * 0.5, 0.4 + rand() * 0.45, 0.53);
        const pipe = mesh(g, "cylinder", C.copper, x, -1.53, z * 1.028, 0.1, 2.1, 0.1);
        for (const y of [-0.7, -1.4, -2.25]) collar(g, C.amber, x, y, z * 1.028, 0.15, 0.065);
        const elbow = mesh(g, "elbow", C.copper, x + 0.2, -0.5, z * 1.028, 0.2, 0.2, 0.2);
        elbow.rotation.y = z > 0 ? Math.PI / 2 : -Math.PI / 2;
      }
    }
  for (const x of [-13.67, 13.67])
    for (let z = -9.7; z < 10.5; z += 1.17) {
      mesh(g, "box", C.ivory, x, 0.27, z, 0.35, 0.3, 1.12);
      for (let row = 0; row < 3; row++)
        mesh(
          g,
          "box",
          rand() > 0.2 ? 0xc5ba98 : C.rock,
          x + (rand() - 0.5) * 0.12,
          -0.72 - row * 0.74,
          z + (row % 2) * 0.22,
          0.55,
          0.64 + rand() * 0.13,
          0.8 + rand() * 0.35,
        );
      if (rand() < 0.48) {
        mesh(g, "box", C.light, x * 1.01, -1.1, z, 0.6, 1.85, 0.39);
        tube(g, C.copper, [x * 1.025, -0.53, z], [x * 1.025, -2.65, z], 0.1);
      }
    }
  for (const [x, z] of [
    [-11.5, -9.2],
    [11.4, 9.2],
    [-11.6, 9.1],
    [11.6, -9.2],
  ])
    coneCluster(g, x, z, 0.91, rand);
  const hardware = [
    [-7.7, -3.45, 0, 0],
    [7.5, -3.55, 0.9, 1],
    [-7.1, 2.7, -0.5, 0],
    [6.8, 3.85, 1.7, 1],
  ];
  hardware.forEach(([x, z, a, k]) => equipment(g, x, z, a, k));
  for (const w of WALLS) {
    for (let i = 0; i < 3; i++) {
      const x = w.x + (rand() - 0.5) * (w.w - 0.2),
        z = w.z + (rand() - 0.5) * (w.h - 0.2);
      if (w.h > 1) {
        mesh(g, "box", C.dark, x, 1.28, z, 0.27, 0.15, 0.3);
        mesh(g, "box", C.ivory, x, 1.43, z, 0.31, 0.15, 0.33);
      }
    }
  }
  for (let i = 0; i < 18; i++) {
    const x = (rand() - 0.5) * 25,
      z = (rand() - 0.5) * 19;
    if (WALLS.some((w) => Math.abs(x - w.x) < w.w / 2 + 0.25 && Math.abs(z - w.z) < w.h / 2 + 0.25))
      continue;
    mesh(g, "box", C.ivory, x, 0.2, z, 0.36, 0.13, 0.36);
    mesh(g, "cone", C.orange, x, 0.4, z, 0.15, 0.38, 0.15);
    collar(g, C.light, x, 0.42, z, 0.083, 0.065);
  }
  for (const [x, z] of [
    [-12, -7],
    [FLANK_POINT[0] - 1.25, FLANK_POINT[1]],
  ]) {
    for (const s of [-1, 1]) {
      mesh(g, "box", C.dark, x, 0.64, z + s * 1.3, 0.56, 1.02, 0.42);
      mesh(g, "box", C.ivory, x, 1.17, z + s * 1.3, 0.65, 0.15, 0.49);
      mesh(g, "box", C.orange, x, 1.48, z + s * 1.3, 0.25, 0.5, 0.28);
    }
    mesh(g, "box", C.copper, x, 1.72, z, 0.22, 0.21, 2.85);
    for (let i = 0; i < 5; i++)
      mesh(g, "box", C.orange, x, 1.72, z - 1.1 + i * 0.55, 0.25, 0.24, 0.24).rotation.x = -0.4;
  }
  for (const [y, r, h, col] of [
    [0.27, 2.25, 0.4, C.dark],
    [0.51, 2.05, 0.27, C.ivory],
    [0.73, 1.8, 0.21, C.light],
    [0.88, 1.54, 0.15, C.orange],
    [1.03, 1.38, 0.19, C.dark],
  ]) {
    collar(g, col, 3, y, 8, r, h);
  }
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * Math.PI * 2;
    mesh(
      g,
      "box",
      C.copper,
      3 + Math.cos(a) * 1.42,
      1.03,
      8 + Math.sin(a) * 1.42,
      0.22,
      0.31,
      0.18,
    ).rotation.y = -a;
    mesh(
      g,
      "box",
      C.mint,
      3 + Math.cos(a) * 1.25,
      1.16,
      8 + Math.sin(a) * 1.25,
      0.16,
      0.09,
      0.12,
      C.mint,
    );
  }
  scene.add(consolidate(g));
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(300, 300), mat(C.navy));
  ground.rotation.x = -Math.PI / 2;
  ground.position.y = -3.4;
  ground.receiveShadow = true;
  scene.add(ground);
  return createCrystal();
}
function crystalGeometry(radius, height, seed) {
  const rnd = seededRandom(seed),
    verts = [],
    colors = [],
    faces = 6;
  const baseColor = new THREE.Color(0x57cfa6),
    topColor = new THREE.Color(0xbdffe2);
  const heights = Array.from({ length: faces }, () => height * (0.8 + rnd() * 0.11));
  const add = (p) => {
    verts.push(...p);
    const color = baseColor.clone().lerp(topColor, Math.min(1, p[1] / height));
    colors.push(color.r, color.g, color.b);
  };
  for (let i = 0; i < faces; i++) {
    const a = (i / faces) * Math.PI * 2,
      b = ((i + 1) / faces) * Math.PI * 2,
      pa = [Math.cos(a) * radius, 0, Math.sin(a) * radius],
      pb = [Math.cos(b) * radius, 0, Math.sin(b) * radius],
      qa = [pa[0], heights[i], pa[2]],
      qb = [pb[0], heights[(i + 1) % faces], pb[2]],
      tip = [radius * 0.1, height, 0];
    [pa, pb, qa, pb, qb, qa, qa, qb, tip].forEach(add);
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute("position", new THREE.Float32BufferAttribute(verts, 3));
  geometry.setAttribute("color", new THREE.Float32BufferAttribute(colors, 3));
  geometry.computeVertexNormals();
  return geometry;
}
function createCrystal() {
  const g = new THREE.Group();
  g.position.set(3, 1.15, 8);
  const crystalMaterial = new THREE.MeshStandardMaterial({
    vertexColors: true,
    color: 0x81c8b6,
    emissive: 0x55e9ad,
    emissiveIntensity: 0.68,
    roughness: 0.2,
    metalness: 0.08,
  });
  for (let i = 0; i < 6; i++) {
    const angle = i * 2.39996,
      crystal = new THREE.Mesh(
        crystalGeometry(i ? 0.27 : 0.48, i ? 1.55 + (i % 3) * 0.35 : 3.65, 713 + i),
        crystalMaterial,
      );
    crystal.position.set(i ? Math.cos(angle) * 0.7 : 0, 0, i ? Math.sin(angle) * 0.7 : 0);
    crystal.rotation.set(i ? Math.sin(angle) * 0.2 : 0, angle, i ? Math.cos(angle) * -0.2 : 0);
    crystal.castShadow = true;
    g.add(crystal);
  }
  return g;
}
export function makeBallCore() {
  const g = new THREE.Group(),
    body = new THREE.Mesh(geos.sphere, mat(C.petrol));
  body.castShadow = true;
  body.receiveShadow = true;
  g.add(body);
  for (let i = 0; i < 27; i++) {
    const a = i * 2.39996,
      y = 1 - (i + 0.5) / 13.5,
      r = Math.sqrt(1 - y * y),
      normal = new THREE.Vector3(Math.cos(a) * r, y, Math.sin(a) * r);
    const plate = mesh(
      g,
      "box",
      i % 5 === 0 ? 0x315153 : 0x193c40,
      normal.x,
      normal.y,
      normal.z,
      0.32,
      0.27,
      0.065,
    );
    plate.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), normal);
  }
  return consolidate(g);
}
