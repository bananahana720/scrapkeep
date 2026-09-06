import * as THREE from "three";
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry.js";

const palette = {
  cream: 0xffedcd,
  ink: 0x153437,
  orange: 0xf29b5b,
  orangeDark: 0xb7643d,
  mint: 0x9fd4b6,
  blue: 0x82b6c0,
  sage: 0x638c71,
  copper: 0xc78c58,
  pink: 0xe7a693,
};
const classes = {
  scavenger: { color: palette.orange, dark: palette.orangeDark, name: "Pip" },
  engineer: { color: palette.mint, dark: palette.copper, name: "Rivet" },
  warden: { color: palette.blue, dark: palette.sage, name: "Moss" },
};
let geometries;
const materials = new Map();

function geometry(shape) {
  geometries ??= {
    round: new THREE.SphereGeometry(1, 20, 14),
    box: new RoundedBoxGeometry(1, 1, 1, 3, 0.15),
    cone: new THREE.ConeGeometry(1, 1, 4),
    ring: new THREE.TorusGeometry(1, 0.22, 8, 20),
    halfRing: new THREE.TorusGeometry(1, 0.24, 8, 16, Math.PI),
  };
  return geometries[shape];
}

function part(group, shape, color, position, scale, rotation = [0, 0, 0]) {
  if (!materials.has(color)) {
    materials.set(
      color,
      new THREE.MeshStandardMaterial({
        color,
        roughness: color === palette.ink ? 0.3 : 0.62,
        metalness: color === palette.copper ? 0.3 : 0.05,
      }),
    );
  }
  const mesh = new THREE.Mesh(geometry(shape), materials.get(color));
  mesh.position.set(...position);
  mesh.scale.set(...scale);
  mesh.rotation.set(...rotation);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  group.add(mesh);
  return mesh;
}

export function createHeroModel(classId) {
  const id = Object.hasOwn(classes, classId) ? classId : "scavenger";
  const hero = classes[id];
  const group = new THREE.Group();
  group.name = hero.name;
  group.userData.classId = id;
  const add = (shape, color, p, s, r) => part(group, shape, color, p, s, r);
  add("round", hero.color, [0, 0.58, 0], [0.39, 0.43, 0.31]);
  add("round", palette.cream, [0, 0.61, 0.25], [0.25, 0.29, 0.095]);
  for (const side of [-1, 1]) {
    add("round", hero.dark, [side * 0.22, 0.12, 0.075], [0.19, 0.12, 0.25]);
    add(
      "round",
      hero.color,
      [side * 0.4, 0.58, 0.02],
      [0.14, 0.24, 0.16],
      [0, 0, side * 0.22],
    );
  }
  add("box", hero.dark, [0, 0.91, 0], [0.62, 0.16, 0.51]);
  add(
    id === "engineer" ? "box" : "round",
    hero.color,
    [0, 1.34, 0],
    id === "engineer" ? [1.12, 0.86, 0.87] : [0.59, 0.48, 0.46],
  );
  add(
    id === "engineer" ? "box" : "round",
    palette.cream,
    [0, 1.32, 0.34],
    id === "engineer" ? [0.97, 0.65, 0.24] : [0.5, 0.37, 0.21],
  );
  for (const side of [-1, 1]) {
    add("round", palette.ink, [side * 0.205, 1.36, 0.54], [0.055, 0.073, 0.04]);
    add(
      "round",
      palette.cream,
      [side * 0.205 - 0.014, 1.387, 0.574],
      [0.016, 0.018, 0.012],
    );
    if (id !== "engineer")
      add(
        "round",
        palette.pink,
        [side * 0.32, 1.22, 0.505],
        [0.062, 0.029, 0.016],
      );
  }
  add("round", palette.ink, [0, 1.205, 0.551], [0.032, 0.023, 0.015]);

  if (id === "scavenger") {
    for (const side of [-1, 1]) {
      add(
        "cone",
        hero.color,
        [side * 0.39, 1.79, -0.015],
        [0.25, 0.49, 0.2],
        [0, Math.PI / 4, -side * 0.23],
      );
      add(
        "cone",
        palette.cream,
        [side * 0.39, 1.8, 0.11],
        [0.125, 0.27, 0.075],
        [0, Math.PI / 4, -side * 0.23],
      );
    }
    add(
      "round",
      hero.dark,
      [-0.32, 0.59, -0.41],
      [0.26, 0.24, 0.43],
      [-0.45, 0.35, 0],
    );
    add("round", palette.cream, [-0.41, 0.78, -0.65], [0.19, 0.16, 0.18]);
    add("box", hero.dark, [0.19, 0.79, -0.35], [0.58, 0.62, 0.3]);
    add(
      "halfRing",
      palette.copper,
      [0.26, 1.12, -0.53],
      [0.31, 0.31, 0.31],
      [0, 0, Math.PI],
    );
    for (const side of [-1, 1])
      add(
        "box",
        palette.cream,
        [0.26 + side * 0.31, 1.21, -0.53],
        [0.16, 0.22, 0.17],
      );
  } else if (id === "engineer") {
    for (const side of [-1, 1]) {
      add("ring", palette.copper, [side * 0.23, 1.37, 0.56], [0.22, 0.22, 0.2]);
      add("box", palette.copper, [side * 0.58, 1.36, 0.04], [0.16, 0.3, 0.27]);
    }
    add("box", palette.copper, [0, 1.4, 0.56], [0.09, 0.055, 0.065]);
    add(
      "box",
      palette.copper,
      [0.18, 1.85, 0],
      [0.055, 0.24, 0.055],
      [0, 0, -0.2],
    );
    add("round", palette.orange, [0.2, 1.97, 0], [0.095, 0.095, 0.095]);
    add(
      "box",
      palette.copper,
      [0.58, 0.65, 0.13],
      [0.12, 0.63, 0.12],
      [0, 0, -0.25],
    );
    add(
      "halfRing",
      palette.copper,
      [0.66, 1, 0.13],
      [0.2, 0.2, 0.26],
      [0, 0, Math.PI],
    );
    add("round", palette.ink, [0, 0.59, 0.35], [0.09, 0.09, 0.025]);
    add("round", palette.orange, [0, 0.59, 0.375], [0.048, 0.048, 0.02]);
  } else {
    for (const side of [-1, 1]) {
      add(
        "box",
        palette.copper,
        [side * 0.38, 1.79, -0.055],
        [0.085, 0.51, 0.09],
        [0, 0, -side * 0.4],
      );
      add(
        "round",
        palette.sage,
        [side * 0.55, 1.9, -0.045],
        [0.105, 0.235, 0.075],
        [0, 0, -side * 0.8],
      );
      add(
        "round",
        palette.mint,
        [side * 0.29, 1.97, -0.055],
        [0.09, 0.2, 0.06],
        [0, 0, side * 0.4],
      );
    }
    add("round", palette.sage, [0, 0.71, -0.26], [0.46, 0.45, 0.2]);
    add("round", palette.copper, [-0.51, 0.62, 0.24], [0.28, 0.35, 0.09]);
    add("round", palette.blue, [-0.51, 0.63, 0.31], [0.235, 0.29, 0.05]);
    add(
      "round",
      palette.mint,
      [-0.51, 0.65, 0.36],
      [0.065, 0.15, 0.026],
      [0, 0, -0.35],
    );
  }
  return group;
}

const portraits = {
  scavenger: `<path d="M163 175c40 15 65-1 49-26-6-10-19-14-31-18l-16 12" fill="#b7643d"/><path d="M197 136c23 7 31 33 8 41l-17-18z" fill="#ffedcd"/><rect x="72" y="119" width="110" height="66" rx="25" fill="#b7643d"/><path d="M71 107V86a23 23 0 0 1 46 0v21" fill="none" stroke="#c78c58" stroke-width="14"/><path d="M71 99v11m46-11v11" stroke="#ffedcd" stroke-width="16"/><path d="M77 82 74 26q0-7 7-2l41 39m38 0 28-40q5-5 7 2l4 61" fill="#f29b5b" stroke="#b7643d" stroke-width="5" stroke-linejoin="round"/><path d="m83 41 6 35 20-9m57 1 22-26 2 34" fill="#ffedcd"/><ellipse cx="134" cy="171" rx="42" ry="44" fill="#f29b5b"/><ellipse cx="134" cy="173" rx="25" ry="30" fill="#ffedcd"/><ellipse cx="86" cy="166" rx="15" ry="24" fill="#f29b5b" transform="rotate(16 86 166)"/><ellipse cx="181" cy="165" rx="15" ry="24" fill="#f29b5b" transform="rotate(-16 181 165)"/><ellipse cx="134" cy="104" rx="65" ry="54" fill="#f29b5b"/><path d="M75 106c8-31 37-3 59-1 24-2 48-30 60-1 9 36-25 53-60 53-33 0-65-17-59-51" fill="#ffedcd"/>`,
  engineer: `<rect x="88" y="135" width="91" height="71" rx="30" fill="#9fd4b6"/><rect x="108" y="151" width="47" height="43" rx="18" fill="#ffedcd"/><ellipse cx="80" cy="168" rx="14" ry="25" fill="#9fd4b6"/><ellipse cx="185" cy="166" rx="14" ry="25" fill="#9fd4b6"/><path d="m198 185-15-67m-1 0a17 17 0 0 1-4-33m4 33a17 17 0 0 0 17-26" fill="none" stroke="#c78c58" stroke-width="13" stroke-linecap="round"/><path d="m145 57 4-27" stroke="#c78c58" stroke-width="7"/><circle cx="150" cy="24" r="11" fill="#f29b5b"/><rect x="58" y="90" width="20" height="40" rx="8" fill="#c78c58"/><rect x="190" y="90" width="20" height="40" rx="8" fill="#c78c58"/><rect x="70" y="56" width="128" height="101" rx="29" fill="#9fd4b6"/><rect x="79" y="70" width="110" height="76" rx="24" fill="#ffedcd"/><circle cx="107" cy="108" r="24" fill="none" stroke="#c78c58" stroke-width="9"/><circle cx="161" cy="108" r="24" fill="none" stroke="#c78c58" stroke-width="9"/><path d="M130 106h8" stroke="#c78c58" stroke-width="7"/><circle cx="132" cy="173" r="12" fill="#153437"/><circle cx="132" cy="173" r="6" fill="#f29b5b"/>`,
  warden: `<path d="m95 82-15-46m88 47 18-47" fill="none" stroke="#c78c58" stroke-width="8" stroke-linecap="round"/><path d="M81 52C53 46 57 23 56 17c24 5 38 17 25 35m1-12C78 20 100 16 102 11c7 23-4 34-20 29m102 15c-2-21 17-30 30-33 0 21-13 36-30 33" fill="#638c71"/><path d="M185 41c-24-2-20-24-17-31 13 7 26 13 17 31" fill="#9fd4b6"/><ellipse cx="134" cy="166" rx="53" ry="42" fill="#638c71"/><ellipse cx="134" cy="175" rx="39" ry="40" fill="#82b6c0"/><ellipse cx="134" cy="172" rx="22" ry="28" fill="#ffedcd"/><ellipse cx="183" cy="166" rx="14" ry="25" fill="#82b6c0"/><ellipse cx="134" cy="105" rx="64" ry="53" fill="#82b6c0"/><ellipse cx="134" cy="115" rx="54" ry="39" fill="#ffedcd"/><path d="M54 149q28-17 57 0v31q-9 29-28 34-24-13-29-34z" fill="#c78c58"/><path d="M62 155q21-11 41 0v25q-6 20-20 26-17-12-21-26z" fill="#82b6c0"/><path d="M83 187c-17-17-5-28 5-30 7 13 10 23-5 30" fill="#9fd4b6"/>`,
};

export function heroPortrait(classId) {
  const id = Object.hasOwn(classes, classId) ? classId : "scavenger";
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 268 240" fill="none" aria-hidden="true" focusable="false"><ellipse cx="134" cy="219" rx="73" ry="10" fill="#153437" opacity=".1"/><ellipse cx="112" cy="205" rx="22" ry="13" fill="#7b6651"/><ellipse cx="157" cy="205" rx="22" ry="13" fill="#7b6651"/>${portraits[id]}<g fill="#153437"><ellipse cx="107" cy="108" rx="6" ry="8"/><ellipse cx="161" cy="108" rx="6" ry="8"/><ellipse cx="134" cy="130" rx="4" ry="3"/></g><g fill="#fff9e9"><circle cx="105" cy="105" r="2"/><circle cx="159" cy="105" r="2"/></g>${id === "engineer" ? "" : '<g fill="#e7a693" opacity=".8"><ellipse cx="92" cy="126" rx="7" ry="3"/><ellipse cx="176" cy="126" rx="7" ry="3"/></g>'}</svg>`;
}
