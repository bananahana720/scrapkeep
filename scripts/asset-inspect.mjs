import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import { profiles } from "./asset-profiles.mjs";

const fail = (message) => {
  throw new Error(message);
};
const check = (condition, message) => {
  if (!condition) fail(message);
};
const integer = (n, min = 0) => Number.isSafeInteger(n) && n >= min;
const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");
const list = (value, label) => {
  check(value === undefined || Array.isArray(value), `${label} must be an array`);
  return value ?? [];
};
const ref = (values, id, label) => {
  check(integer(id) && id < values.length, `Invalid ${label} reference ${id}`);
  return values[id];
};
const identity = () => [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
const multiply = (a, b) =>
  Array.from({ length: 16 }, (_, i) => {
    const r = i % 4,
      c = Math.floor(i / 4);
    return (
      a[r] * b[c * 4] + a[r + 4] * b[c * 4 + 1] + a[r + 8] * b[c * 4 + 2] + a[r + 12] * b[c * 4 + 3]
    );
  });
function transform(node) {
  const vector = (v, length, name) => {
    check(
      Array.isArray(v) && v.length === length && v.every(Number.isFinite),
      `Invalid node ${name}`,
    );
    return v;
  };
  if (node.matrix !== undefined) {
    check(
      node.translation === undefined && node.rotation === undefined && node.scale === undefined,
      "Node matrix and TRS cannot coexist",
    );
    const m = vector(node.matrix, 16, "matrix");
    check(m[3] === 0 && m[7] === 0 && m[11] === 0 && m[15] === 1, "Node matrix must be affine");
    return m;
  }
  const [x, y, z, w] = vector(node.rotation ?? [0, 0, 0, 1], 4, "rotation");
  check(Math.abs(x * x + y * y + z * z + w * w - 1) < 1e-4, "Node quaternion must be normalized");
  const s = vector(node.scale ?? [1, 1, 1], 3, "scale"),
    t = vector(node.translation ?? [0, 0, 0], 3, "translation");
  return [
    (1 - 2 * y * y - 2 * z * z) * s[0],
    (2 * x * y + 2 * z * w) * s[0],
    (2 * x * z - 2 * y * w) * s[0],
    0,
    (2 * x * y - 2 * z * w) * s[1],
    (1 - 2 * x * x - 2 * z * z) * s[1],
    (2 * y * z + 2 * x * w) * s[1],
    0,
    (2 * x * z + 2 * y * w) * s[2],
    (2 * y * z - 2 * x * w) * s[2],
    (1 - 2 * x * x - 2 * y * y) * s[2],
    0,
    ...t,
    1,
  ];
}
const bounds = () => ({
  min: [Infinity, Infinity, Infinity],
  max: [-Infinity, -Infinity, -Infinity],
});
function extend(box, p) {
  check(p.every(Number.isFinite), "Non-finite position or transformed bounds");
  for (let i = 0; i < 3; i++) {
    box.min[i] = Math.min(box.min[i], p[i]);
    box.max[i] = Math.max(box.max[i], p[i]);
  }
}
const point = (m, p) =>
  [0, 1, 2].map((i) => m[i] * p[0] + m[i + 4] * p[1] + m[i + 8] * p[2] + m[i + 12]);
const irrelevant = new Set([
  "KHR_materials_unlit",
  "KHR_materials_clearcoat",
  "KHR_materials_transmission",
  "KHR_materials_ior",
  "KHR_materials_specular",
  "KHR_materials_sheen",
  "KHR_materials_volume",
  "KHR_materials_emissive_strength",
  "KHR_materials_iridescence",
  "KHR_materials_anisotropy",
  "KHR_texture_transform",
  "KHR_lights_punctual",
]);
const textureOnly = new Set(["EXT_texture_webp"]);
function extensions(value, location = "document", lenient = false) {
  if (!value || typeof value !== "object") return;
  if (value.extensions)
    for (const name of Object.keys(value.extensions))
      check(
        irrelevant.has(name) || (lenient && textureOnly.has(name)),
        `Unsupported extension ${name} at ${location}; export uncompressed core glTF geometry`,
      );
  for (const [key, item] of Object.entries(value))
    if (key !== "extras" && key !== "extensions") extensions(item, `${location}.${key}`, lenient);
}

function longestClip(animations, parsed) {
  let longest = 0;
  for (const clip of animations)
    for (const s of list(clip.samplers, "animation samplers")) {
      const input = ref(parsed, s.input, "sampler input accessor");
      check(
        input.type === "SCALAR" && input.componentType === 5126,
        "Animation sampler input must be float SCALAR",
      );
      for (let i = 0; i < input.count; i++) longest = Math.max(longest, input.read(i, 0));
    }
  return longest;
}
function imageSides(images, views, bin) {
  let side = 0;
  for (const image of images) {
    if (image.bufferView === undefined) {
      const m = /^data:[^;,]*;base64,(.*)$/s.exec(image.uri ?? "");
      if (m) side = Math.max(side, pixelSide(Buffer.from(m[1], "base64")));
      continue;
    }
    const v = views[image.bufferView],
      b = bin.subarray(v.byteOffset ?? 0, (v.byteOffset ?? 0) + v.byteLength);
    side = Math.max(side, pixelSide(b));
  }
  return side;
}
export function webpSide(b) {
  if (
    b.length < 30 ||
    b.toString("latin1", 0, 4) !== "RIFF" ||
    b.toString("latin1", 8, 12) !== "WEBP"
  )
    return 0;
  const kind = b.toString("latin1", 12, 16);
  if (kind === "VP8X") return Math.max(b.readUIntLE(24, 3) + 1, b.readUIntLE(27, 3) + 1);
  if (kind === "VP8L") {
    const bits = b.readUInt32LE(21);
    return Math.max((bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1);
  }
  if (kind === "VP8 ") return Math.max(b.readUInt16LE(26) & 0x3fff, b.readUInt16LE(28) & 0x3fff);
  return 0;
}
export function pixelSide(b) {
  const webp = webpSide(b);
  if (webp) return webp;
  if (b.length >= 24 && b.readUInt32BE(0) === 0x89504e47)
    return Math.max(b.readUInt32BE(16), b.readUInt32BE(20));
  if (b.length > 4 && b[0] === 0xff && b[1] === 0xd8)
    for (let i = 2; i + 9 < b.length;) {
      if (b[i] !== 0xff) return 0;
      const marker = b[i + 1];
      if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker))
        return Math.max(b.readUInt16BE(i + 5), b.readUInt16BE(i + 7));
      i += 2 + b.readUInt16BE(i + 2);
    }
  return 0;
}
export function inspectGlb(bytes, selection = {}) {
  check(bytes.length >= 20, "Truncated GLB header");
  check(
    bytes.readUInt32LE(0) === 0x46546c67 && bytes.readUInt32LE(4) === 2,
    "Expected GLB version 2",
  );
  check(bytes.readUInt32LE(8) === bytes.length, "GLB declared length differs from actual bytes");
  const chunks = [];
  for (let offset = 12; offset < bytes.length;) {
    check(offset + 8 <= bytes.length, "Truncated chunk header");
    const length = bytes.readUInt32LE(offset),
      type = bytes.readUInt32LE(offset + 4);
    offset += 8;
    check(
      length % 4 === 0 && offset + length <= bytes.length,
      "Invalid GLB chunk length/alignment",
    );
    chunks.push({ type, data: bytes.subarray(offset, offset + length) });
    offset += length;
  }
  check(
    chunks.length >= 1 &&
      chunks.length <= 2 &&
      chunks[0].type === 0x4e4f534a &&
      (chunks.length === 1 || chunks[1].type === 0x004e4942),
    "Expected JSON then optional BIN chunks only",
  );
  let doc;
  try {
    doc = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(chunks[0].data));
  } catch {
    fail("Invalid GLB JSON");
  }
  check(
    doc?.asset?.version === "2.0" && (!doc.asset.minVersion || doc.asset.minVersion === "2.0"),
    "Expected glTF asset version 2.0",
  );
  const lenient = selection.textureLenient === true;
  for (const name of list(doc.extensionsRequired, "extensionsRequired"))
    check(
      irrelevant.has(name) || (lenient && textureOnly.has(name)),
      `Unsupported required extension ${name}`,
    );
  for (const name of list(doc.extensionsUsed, "extensionsUsed"))
    check(
      irrelevant.has(name) || (lenient && textureOnly.has(name)),
      `Unsupported extension ${name}`,
    );
  extensions(doc, "document", lenient);
  const buffers = list(doc.buffers, "buffers"),
    bin = chunks[1]?.data ?? Buffer.alloc(0);
  check(buffers.length <= 1, "Only one embedded GLB buffer is supported");
  for (const buffer of buffers)
    check(
      buffer.uri === undefined &&
        integer(buffer.byteLength, 1) &&
        bin.length >= buffer.byteLength &&
        bin.length - buffer.byteLength <= 3,
      "Invalid embedded buffer length or external URI; use a self-contained GLB",
    );
  check(buffers.length || !bin.length, "BIN chunk without buffer declaration");
  const views = list(doc.bufferViews, "bufferViews"),
    accessors = list(doc.accessors, "accessors");
  for (const v of views) {
    check(
      v.buffer === 0 &&
        buffers.length &&
        integer(v.byteOffset ?? 0) &&
        integer(v.byteLength, 1) &&
        (v.byteOffset ?? 0) + v.byteLength <= buffers[0].byteLength,
      "Invalid bufferView range",
    );
    if (v.byteStride !== undefined)
      check(
        integer(v.byteStride, 4) && v.byteStride <= 252 && v.byteStride % 4 === 0,
        "Invalid bufferView stride",
      );
  }
  const component = {
    5120: [1, "readInt8"],
    5121: [1, "readUInt8"],
    5122: [2, "readInt16LE"],
    5123: [2, "readUInt16LE"],
    5125: [4, "readUInt32LE"],
    5126: [4, "readFloatLE"],
  };
  const widths = {
    SCALAR: 1,
    VEC2: 2,
    VEC3: 3,
    VEC4: 4,
    MAT2: 4,
    MAT3: 9,
    MAT4: 16,
  };
  const parsed = accessors.map((a, id) => {
    check(!a.sparse, `Sparse accessor ${id} is unsupported; export dense accessors`);
    const c = component[a.componentType],
      width = widths[a.type];
    check(c && width && integer(a.count, 1), `Invalid accessor ${id} type/count`);
    check(!a.type.startsWith("MAT") || c[0] === 4, `Packed matrix accessor ${id} is unsupported`);
    const v = ref(views, a.bufferView, "bufferView"),
      offset = a.byteOffset ?? 0,
      stride = v.byteStride ?? c[0] * width;
    check(
      integer(offset) &&
        offset % c[0] === 0 &&
        ((v.byteOffset ?? 0) + offset) % c[0] === 0 &&
        stride >= c[0] * width &&
        offset + (a.count - 1) * stride + c[0] * width <= v.byteLength,
      `Invalid accessor ${id} binary range/alignment`,
    );
    check(
      a.normalized === undefined || typeof a.normalized === "boolean",
      `Invalid accessor ${id} normalized flag`,
    );
    return {
      ...a,
      width,
      stride,
      offset: (v.byteOffset ?? 0) + offset,
      read: (i, j = 0) => bin[c[1]]((v.byteOffset ?? 0) + offset + i * stride + j * c[0]),
    };
  });
  const materials = list(doc.materials, "materials"),
    textures = list(doc.textures, "textures"),
    images = list(doc.images, "images"),
    skins = list(doc.skins, "skins"),
    animations = list(doc.animations, "animations");
  for (const image of images) {
    if (lenient && image.uri !== undefined) continue;
    check(
      image.uri === undefined,
      "External/data image URIs unsupported; embed images in bufferViews",
    );
    ref(views, image.bufferView, "image bufferView");
  }
  const meshes = list(doc.meshes, "meshes").map((mesh, id) => {
    const primitives = list(mesh.primitives, "primitives");
    check(primitives.length > 0, `Mesh ${id} has no primitives`);
    const box = bounds();
    let triangles = 0,
      vertices = 0,
      welded = 0;
    const geometry = primitives.map((p) => {
      check((p.mode ?? 4) === 4, "Unsupported primitive mode; export TRIANGLES");
      check(
        p.attributes && typeof p.attributes === "object" && !Array.isArray(p.attributes),
        "Missing primitive attributes",
      );
      const pos = ref(parsed, p.attributes.POSITION, "POSITION accessor");
      check(
        pos.type === "VEC3" && pos.componentType === 5126 && !pos.normalized,
        "POSITION must be float VEC3",
      );
      check(pos.offset % 4 === 0 && pos.stride % 4 === 0, "POSITION must be four-byte aligned");
      for (const a of Object.values(p.attributes))
        check(
          ref(parsed, a, "attribute accessor").count === pos.count,
          "Attribute counts must match POSITION",
        );
      for (const target of list(p.targets, "morph targets"))
        for (const a of Object.values(target))
          check(
            ref(parsed, a, "morph accessor").count === pos.count,
            "Morph counts must match POSITION",
          );
      if (p.material !== undefined) ref(materials, p.material, "material");
      let count = pos.count;
      if (p.indices !== undefined) {
        const index = ref(parsed, p.indices, "index accessor");
        check(
          index.type === "SCALAR" &&
            [5121, 5123, 5125].includes(index.componentType) &&
            !index.normalized,
          "Indices must be unsigned scalar",
        );
        check(
          views[index.bufferView].byteStride === undefined,
          "Index bufferView cannot have a stride",
        );
        count = index.count;
        const restartIndex = { 5121: 255, 5123: 65535, 5125: 4294967295 }[index.componentType];
        for (let i = 0; i < count; i++) {
          const value = index.read(i);
          check(value !== restartIndex, "Reserved primitive-restart index value");
          check(value < pos.count, "Index value outside POSITION range");
        }
      }
      check(count % 3 === 0, "TRIANGLES element count must be divisible by three");
      for (let i = 0; i < pos.count; i++)
        extend(box, [pos.read(i, 0), pos.read(i, 1), pos.read(i, 2)]);
      triangles += count / 3;
      vertices += pos.count;
      const accessorsOf = Object.values(p.attributes).map((a) => parsed[a]);
      const seen = new Set();
      for (let i = 0; i < pos.count; i++)
        seen.add(
          accessorsOf
            .map((a) => Array.from({ length: a.width }, (_, j) => a.read(i, j)).join(","))
            .join("|"),
        );
      welded += seen.size;
      return { pos, morph: !!p.targets?.length };
    });
    return {
      id,
      name: mesh.name ?? null,
      triangles,
      vertices,
      welded_vertices: welded,
      primitives: primitives.length,
      local_static_bounds: box,
      geometry,
    };
  });
  const nodes = list(doc.nodes, "nodes"),
    scenes = list(doc.scenes, "scenes"),
    parents = Array(nodes.length).fill(null),
    matrices = nodes.map(transform);
  for (let i = 0; i < nodes.length; i++) {
    const n = nodes[i];
    if (n.mesh !== undefined) ref(meshes, n.mesh, "mesh");
    if (n.skin !== undefined) ref(skins, n.skin, "skin");
    for (const child of list(n.children, "node children")) {
      ref(nodes, child, "node");
      check(parents[child] === null, "Duplicate child or multi-parent node");
      parents[child] = i;
    }
  }
  const visited = new Set(),
    active = new Set();
  function visit(id) {
    check(!active.has(id), "Cycle in node graph");
    if (visited.has(id)) return;
    active.add(id);
    for (const child of nodes[id].children ?? []) visit(child);
    active.delete(id);
    visited.add(id);
  }
  for (let i = 0; i < nodes.length; i++) visit(i);
  for (const scene of scenes) {
    const seen = new Set();
    for (const id of list(scene.nodes, "scene nodes")) {
      ref(nodes, id, "scene node");
      check(
        !seen.has(id) && parents[id] === null,
        "Duplicate scene root or scene root has a parent",
      );
      seen.add(id);
    }
  }
  if (doc.scene !== undefined) ref(scenes, doc.scene, "default scene");
  let roots,
    sceneId = null;
  if (selection.nodes !== undefined) {
    check(Array.isArray(selection.nodes) && selection.nodes.length > 0, "Node selection is empty");
    roots = selection.nodes;
  } else {
    sceneId = selection.scene ?? doc.scene ?? (scenes.length === 1 ? 0 : null);
    check(sceneId !== null, "Scene selection is ambiguous or missing; use --scene or --nodes");
    roots = ref(scenes, sceneId, "selected scene").nodes ?? [];
  }
  check(roots.length > 0, "Selected assembly is empty");
  const selected = new Set(),
    worldBounds = bounds();
  let triangles = 0,
    primitiveCount = 0,
    draws = 0,
    collisionNodes = 0,
    instances = 0,
    unknownBounds = animations.length > 0;
  const worldCache = new Map();
  function world(id) {
    if (!worldCache.has(id))
      worldCache.set(
        id,
        parents[id] === null ? matrices[id] : multiply(world(parents[id]), matrices[id]),
      );
    return worldCache.get(id);
  }
  function collect(id) {
    const n = ref(nodes, id, "selected node");
    check(!selected.has(id), "Overlapping selected subtrees or duplicate roots");
    selected.add(id);
    if (n.mesh !== undefined) {
      const mesh = meshes[n.mesh];
      triangles += mesh.triangles;
      primitiveCount += mesh.primitives;
      if (typeof n.name === "string" && n.name.endsWith("-col")) collisionNodes++;
      else draws += mesh.primitives;
      instances++;
      unknownBounds ||= n.skin !== undefined || mesh.geometry.some((p) => p.morph);
      for (const { pos } of mesh.geometry)
        for (let i = 0; i < pos.count; i++)
          extend(worldBounds, point(world(id), [pos.read(i, 0), pos.read(i, 1), pos.read(i, 2)]));
    }
    for (const child of n.children ?? []) collect(child);
  }
  roots.forEach(collect);
  check(
    instances > 0 || (selection.allowClipOnly && animations.length > 0),
    "Selected assembly contains no mesh instances",
  );
  return {
    inventory: {
      meshes: meshes.length,
      triangles: meshes.reduce((n, m) => n + m.triangles, 0),
      vertices: meshes.reduce((n, m) => n + m.vertices, 0),
      welded_vertices: meshes.reduce((n, m) => n + m.welded_vertices, 0),
      primitives: meshes.reduce((n, m) => n + m.primitives, 0),
      materials: materials.length,
      textures: textures.length,
      images: images.length,
      skins: skins.length,
      animations: animations.length,
      bones: new Set(skins.flatMap((k) => list(k.joints, "skin joints"))).size,
      clips: animations.length,
      longest_clip_s: longestClip(animations, parsed),
      texture_max_side: imageSides(images, views, bin),
    },
    meshes: meshes.map(({ geometry, ...m }) => m),
    selection: {
      scene: sceneId,
      roots: [...roots],
      mesh_instances: instances,
      triangles,
      primitives: primitiveCount,
      draws,
      collision_nodes: collisionNodes,
      static_world_bounds: unknownBounds ? null : worldBounds,
      bounds_status: unknownBounds ? "unknown_deformed_or_animated" : "static",
    },
  };
}

const help = `Usage: npm run asset:inspect -- [options] file.glb ...
  --profile generic-30k | --max-tris N   Explicit selected-assembly budget
  --nodes 0,2                          Numeric subtree roots (one file)
  --scene N                            Scene index (one file)
  --manifest assembly.json             Local version-1 assembly manifest
  --json                               JSON stdout instead of summary
  --output report.json                 Save JSON without overwriting inputs
  --help                               Show usage
Exit: 0 inventory or budget pass; 2 over budget; 1 invalid/unsupported/usage.
Inventory is not approval. Engine import and performance are not measured.`;
function options(args) {
  const o = { files: [] };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (["--json", "--help"].includes(a)) o[a.slice(2)] = true;
    else if (
      ["--profile", "--max-tris", "--nodes", "--scene", "--manifest", "--output"].includes(a)
    ) {
      check(o[a.slice(2)] === undefined, `Duplicate option ${a}`);
      check(args[i + 1] !== undefined && !args[i + 1].startsWith("--"), `Missing value for ${a}`);
      o[a.slice(2)] = args[++i];
    } else {
      check(!a.startsWith("-"), `Unknown option ${a}`);
      o.files.push(a);
    }
  }
  const numeric = (s, label) => {
    check(/^\d+$/.test(s), `${label} must be a nonnegative integer`);
    const n = Number(s);
    check(integer(n), `${label} out of range`);
    return n;
  };
  if (o["max-tris"] !== undefined) o.max = numeric(o["max-tris"], "max-tris");
  if (o.profile !== undefined) {
    check(Object.hasOwn(profiles, o.profile), "Unknown budget profile");
    check(o.max === undefined, "Choose profile or max-tris, not both");
    o.max = profiles[o.profile].max_triangles;
  }
  if (o.scene !== undefined) o.scene = numeric(o.scene, "scene");
  if (o.nodes !== undefined) o.nodes = o.nodes.split(",").map((n) => numeric(n, "node"));
  check(!(o.nodes && o.scene !== undefined), "Choose nodes or scene, not both");
  return o;
}
function capture(file) {
  const absolute = path.resolve(file),
    real = fs.realpathSync(absolute),
    stat = fs.statSync(real);
  check(stat.isFile(), `Input is not a file: ${file}`);
  const bytes = fs.readFileSync(real);
  return {
    path: absolute,
    real,
    dev: stat.dev,
    ino: stat.ino,
    bytes,
    sha256: hash(bytes),
  };
}
function safeOutput(output, inputs) {
  const absolute = path.resolve(output);
  let real = absolute,
    stat;
  try {
    real = fs.realpathSync(absolute);
    stat = fs.statSync(absolute);
  } catch (e) {
    if (e.code !== "ENOENT") throw e;
    check(!fs.lstatSync(absolute, { throwIfNoEntry: false }), "Output is a dangling symlink");
    real = path.join(fs.realpathSync(path.dirname(absolute)), path.basename(absolute));
  }
  check(
    !inputs.some(
      (i) =>
        i.path === absolute ||
        i.real === real ||
        (stat && i.dev === stat.dev && i.ino === stat.ino),
    ),
    "Output aliases an input; refusing to overwrite",
  );
  return absolute;
}
function manifestEntries(doc) {
  check(
    doc &&
      doc.version === 1 &&
      typeof doc.name === "string" &&
      doc.name.trim() &&
      Array.isArray(doc.parts) &&
      doc.parts.length,
    "Manifest needs version:1, name and nonempty parts",
  );
  check(
    Object.keys(doc).every((k) => ["version", "name", "parts"].includes(k)),
    "Unknown manifest field",
  );
  return doc.parts.map((p) => {
    check(
      p && Object.keys(p).every((k) => ["file", "nodes", "lod"].includes(k)),
      "Unknown manifest part field",
    );
    check(
      typeof p.file === "string" &&
        p.file.length &&
        !path.isAbsolute(p.file) &&
        !/^\w+:/.test(p.file),
      "Manifest file must be a local relative path",
    );
    check(
      Array.isArray(p.nodes) && p.nodes.length && p.nodes.every((n) => integer(n)),
      "Manifest part needs numeric node roots",
    );
    check(
      p.lod === undefined || (typeof p.lod === "string" && p.lod.trim()),
      "LOD label must be a nonempty string",
    );
    return p;
  });
}
export function run(args) {
  let o, output;
  const report = {
    schema_version: 1,
    status: "invalid",
    engine_import: "not_run",
    visual_acceptance: "not_measured",
    performance: "not_measured",
    texture_memory_bytes: null,
    gpu_memory_bytes: null,
    scope: "Static triangle geometry inspection; not full glTF conformance or engine qualification",
    files: [],
    errors: [],
  };
  try {
    o = options(args);
    if (o.help) {
      console.log(help);
      return 0;
    }
    check(
      !(o.manifest && (o.files.length || o.nodes || o.scene !== undefined)),
      "Manifest cannot be combined with positional files or node/scene options",
    );
    check(o.manifest || o.files.length, "Supply GLB files or a manifest");
    check(
      !(o.files.length > 1 && (o.nodes || o.scene !== undefined)),
      "Node/scene selection requires one file",
    );
    const inputs = [],
      entries = [];
    if (o.manifest) {
      const source = capture(o.manifest);
      inputs.push(source);
      let doc;
      try {
        doc = JSON.parse(source.bytes.toString("utf8"));
      } catch {
        fail("Invalid manifest JSON");
      }
      report.manifest = {
        path: source.path,
        sha256: source.sha256,
        name: doc.name,
      };
      for (const part of manifestEntries(doc))
        entries.push({
          file: path.resolve(path.dirname(source.path), part.file),
          nodes: part.nodes,
          lod: part.lod ?? null,
        });
    } else for (const file of o.files) entries.push({ file, nodes: o.nodes, scene: o.scene });
    for (const entry of entries) {
      check(path.extname(entry.file).toLowerCase() === ".glb", "Only .glb inputs are supported");
      entry.source = capture(entry.file);
      inputs.push(entry.source);
    }
    if (o.output) output = safeOutput(o.output, inputs);
    for (const entry of entries) {
      const source = entry.source;
      try {
        report.files.push({
          path: source.path,
          sha256: source.sha256,
          bytes: source.bytes.length,
          lod: entry.lod ?? null,
          ...inspectGlb(source.bytes, entry),
        });
      } catch (e) {
        report.errors.push(`${source.path}: ${e.message}`);
      }
    }
    report.budget =
      o.max === undefined ? null : { profile: o.profile ?? null, max_triangles: o.max };
    if (!report.errors.length) {
      const triangles = report.files.reduce((n, f) => n + f.selection.triangles, 0);
      report.assembly = {
        name: report.manifest?.name ?? null,
        triangles,
        mesh_instances: report.files.reduce((n, f) => n + f.selection.mesh_instances, 0),
        static_world_bounds:
          o.manifest || report.files.length > 1
            ? null
            : report.files[0].selection.static_world_bounds,
        bounds_status:
          o.manifest || report.files.length > 1
            ? "unknown_no_shared_placement"
            : report.files[0].selection.bounds_status,
      };
      report.status =
        o.max === undefined ? "inventory" : triangles <= o.max ? "pass" : "over_budget";
    }
  } catch (e) {
    report.errors.push(e.message);
  }
  const json = JSON.stringify(report, null, 2) + "\n";
  if (output) {
    try {
      fs.writeFileSync(output, json);
    } catch (e) {
      report.status = "invalid";
      report.errors.push(`Cannot write report: ${e.message}`);
    }
  }
  if (o?.json || args.includes("--json")) console.log(JSON.stringify(report, null, 2));
  else {
    console.log(`Asset inspection: ${report.status}`);
    for (const f of report.files)
      console.log(
        `${f.path}: inventory ${f.inventory.triangles} triangles; selected ${f.selection.triangles} triangles in ${f.selection.mesh_instances} instances`,
      );
    if (report.assembly)
      console.log(
        `Assembly: ${report.assembly.triangles} triangles; budget ${report.budget?.max_triangles ?? "none (inventory only)"}`,
      );
    for (const error of report.errors) console.error(error);
    console.log(
      "Engine import: not_run; GPU/texture memory, visual acceptance and performance: not measured.",
    );
  }
  return report.status === "invalid" ? 1 : report.status === "over_budget" ? 2 : 0;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  process.exitCode = run(process.argv.slice(2));
