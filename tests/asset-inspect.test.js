import test, { describe } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { inspectGlb } from "../scripts/asset-inspect.mjs";

const execFileAsync = promisify(execFile);
const CONCURRENCY = Math.max(2, Math.min(os.availableParallelism(), 8));

const cli = fileURLToPath(new URL("../scripts/asset-inspect.mjs", import.meta.url));
function fixture({
  triangles = 1,
  indexed = true,
  stride = 12,
  vertexCount,
  indexComponent = 5125,
  indexValues,
  edit = () => {},
} = {}) {
  const vertices = vertexCount ?? (indexed ? 3 : triangles * 3);
  const positions = Buffer.alloc(vertices * stride);
  for (let i = 0; i < vertices; i++) {
    positions.writeFloatLE(i % 3 === 1 ? 1 : 0, i * stride);
    positions.writeFloatLE(i % 3 === 2 ? 1 : 0, i * stride + 4);
  }
  const [indexBytes, writeIndex] = {
    5121: [1, "writeUInt8"],
    5123: [2, "writeUInt16LE"],
    5125: [4, "writeUInt32LE"],
  }[indexComponent];
  const indices = Buffer.alloc(indexed ? triangles * 3 * indexBytes : 0);
  for (let i = 0; i < triangles * 3 && indexed; i++)
    indices[writeIndex](indexValues?.[i] ?? i % 3, i * indexBytes);
  const bin = Buffer.concat([positions, indices]);
  const doc = {
    asset: { version: "2.0" },
    buffers: [{ byteLength: bin.length }],
    bufferViews: [
      {
        buffer: 0,
        byteLength: positions.length,
        ...(stride === 12 ? {} : { byteStride: stride }),
      },
    ],
    accessors: [{ bufferView: 0, componentType: 5126, count: vertices, type: "VEC3" }],
    meshes: [
      {
        primitives: [{ attributes: { POSITION: 0 }, ...(indexed ? { indices: 1 } : {}) }],
      },
    ],
    nodes: [{ mesh: 0 }],
    scenes: [{ nodes: [0] }],
    scene: 0,
  };
  if (indexed) {
    doc.bufferViews.push({
      buffer: 0,
      byteOffset: positions.length,
      byteLength: indices.length,
    });
    doc.accessors.push({
      bufferView: 1,
      componentType: indexComponent,
      count: triangles * 3,
      type: "SCALAR",
    });
  }
  edit(doc, bin);
  return pack(doc, bin);
}
function pack(doc, bin) {
  const raw = Buffer.from(JSON.stringify(doc)),
    json = Buffer.alloc(Math.ceil(raw.length / 4) * 4, 0x20);
  raw.copy(json);
  const body = Buffer.alloc(Math.ceil(bin.length / 4) * 4);
  bin.copy(body);
  const header = Buffer.alloc(20);
  header.writeUInt32LE(0x46546c67);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(28 + json.length + body.length, 8);
  header.writeUInt32LE(json.length, 12);
  header.writeUInt32LE(0x4e4f534a, 16);
  const bh = Buffer.alloc(8);
  bh.writeUInt32LE(body.length);
  bh.writeUInt32LE(0x004e4942, 4);
  return Buffer.concat([header, json, bh, body]);
}
function workspace(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "asset-inspect-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}
async function execute(args, options = {}) {
  try {
    const { stdout, stderr } = await execFileAsync(process.execPath, [cli, "--json", ...args], {
      encoding: "utf8",
      ...options,
    });
    return {
      code: 0,
      report: JSON.parse(stdout),
      stderr,
    };
  } catch (error) {
    assert.equal(error.signal, null);
    return {
      code: error.code,
      report: JSON.parse(error.stdout),
      stderr: error.stderr,
    };
  }
}
function save(dir, name, bytes) {
  const file = path.join(dir, name);
  fs.writeFileSync(file, bytes);
  return file;
}

test("indexed and non-indexed triangles, actual bounds and interleaved positions", () => {
  for (const indexed of [true, false])
    for (const stride of [12, 24]) {
      const r = inspectGlb(fixture({ triangles: 2, indexed, stride }));
      assert.equal(r.inventory.triangles, 2);
      assert.deepEqual(r.selection.static_world_bounds, {
        min: [0, 0, 0],
        max: [1, 1, 0],
      });
    }
});
test("unique geometry differs from reused nodes and unused alternate LOD", () => {
  const bytes = fixture({
    edit: (d) => {
      d.meshes.push({
        primitives: [
          { attributes: { POSITION: 0 }, indices: 1 },
          { attributes: { POSITION: 0 }, indices: 1 },
        ],
      });
      d.nodes = [
        { children: [1, 2] },
        { mesh: 0, translation: [2, 0, 0] },
        { mesh: 0 },
        { mesh: 1 },
      ];
      d.scenes = [{ nodes: [0, 3] }];
    },
  });
  const r = inspectGlb(bytes, { nodes: [0] });
  assert.equal(r.inventory.triangles, 3);
  assert.equal(r.selection.triangles, 2);
  assert.equal(r.selection.mesh_instances, 2);
  assert.equal(r.inventory.primitives, 3);
  assert.equal(inspectGlb(bytes, { nodes: [3] }).selection.triangles, 2);
  assert.deepEqual(r.selection.static_world_bounds.max, [3, 1, 0]);
});
test("subtree world bounds retain ancestor TRS and matrix transforms", () => {
  const bytes = fixture({
    edit: (d) => {
      d.nodes = [
        { translation: [10, 0, 0], children: [1] },
        { mesh: 0, scale: [2, 3, 1] },
      ];
    },
  });
  assert.deepEqual(inspectGlb(bytes, { nodes: [1] }).selection.static_world_bounds, {
    min: [10, 0, 0],
    max: [12, 3, 0],
  });
  const matrix = fixture({
    edit: (d) => {
      d.nodes[0].matrix = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 4, 5, 6, 1];
    },
  });
  assert.deepEqual(inspectGlb(matrix).selection.static_world_bounds.min, [4, 5, 6]);
});
test("animation, skin or morph keeps deformed bounds explicitly unknown", () => {
  for (const edit of [
    (d) => {
      d.animations = [{}];
    },
    (d) => {
      d.skins = [{}];
      d.nodes[0].skin = 0;
    },
    (d) => {
      d.meshes[0].primitives[0].targets = [{ POSITION: 0 }];
    },
  ]) {
    const r = inspectGlb(fixture({ edit }));
    assert.equal(r.selection.static_world_bounds, null);
    assert.equal(r.selection.bounds_status, "unknown_deformed_or_animated");
  }
});
test("ambiguous scenes require explicit choice", () => {
  const bytes = fixture({
    edit: (d) => {
      delete d.scene;
      d.scenes.push({ nodes: [0] });
    },
  });
  assert.throws(() => inspectGlb(bytes), /ambiguous/);
  assert.equal(inspectGlb(bytes, { scene: 1 }).selection.triangles, 1);
});
const malformed = [
  ["index out of range", (d, b) => b.writeUInt32LE(3, 36), /Index value/],
  [
    "fake index count",
    (d) => {
      d.accessors[1].count = 9000000;
    },
    /binary range/,
  ],
  [
    "missing vertex storage",
    (d) => {
      d.accessors[0].count = 999;
    },
    /binary range/,
  ],
  [
    "buffer too short",
    (d) => {
      d.buffers[0].byteLength = 1;
    },
    /buffer length/,
  ],
  [
    "bufferView too long",
    (d) => {
      d.bufferViews[0].byteLength = 999;
    },
    /bufferView range/,
  ],
  [
    "negative offset",
    (d) => {
      d.accessors[0].byteOffset = -4;
    },
    /binary range/,
  ],
  ["non-finite position", (d, b) => b.writeFloatLE(NaN, 0), /Non-finite/],
  [
    "attribute mismatch",
    (d) => {
      d.accessors.push({ ...d.accessors[0], count: 2 });
      d.meshes[0].primitives[0].attributes.NORMAL = 2;
    },
    /counts/,
  ],
  [
    "wrong index component",
    (d) => {
      d.accessors[1].componentType = 5126;
    },
    /unsigned scalar/,
  ],
  [
    "unsupported primitive",
    (d) => {
      d.meshes[0].primitives[0].mode = 5;
    },
    /primitive mode/,
  ],
  [
    "sparse geometry",
    (d) => {
      d.accessors[0].sparse = {};
    },
    /Sparse/,
  ],
  [
    "draco geometry",
    (d) => {
      d.meshes[0].primitives[0].extensions = { KHR_draco_mesh_compression: {} };
    },
    /Unsupported extension/,
  ],
  [
    "meshopt geometry",
    (d) => {
      d.bufferViews[0].extensions = { EXT_meshopt_compression: {} };
    },
    /Unsupported extension/,
  ],
  [
    "GPU instances",
    (d) => {
      d.nodes[0].extensions = { EXT_mesh_gpu_instancing: {} };
    },
    /Unsupported extension/,
  ],
  [
    "extension LOD",
    (d) => {
      d.nodes[0].extensions = { MSFT_lod: { ids: [1] } };
    },
    /Unsupported extension/,
  ],
  [
    "unknown required extension",
    (d) => {
      d.extensionsRequired = ["vendor_geometry"];
    },
    /Unsupported required/,
  ],
  [
    "external buffer",
    (d) => {
      d.buffers[0].uri = "https://invalid.example/a.bin";
    },
    /external URI/,
  ],
  [
    "external image",
    (d) => {
      d.images = [{ uri: "https://invalid.example/image.png" }];
    },
    /image URIs/,
  ],
  [
    "cycle",
    (d) => {
      d.nodes[0].children = [0];
    },
    /Cycle/,
  ],
  [
    "multiple parents",
    (d) => {
      d.nodes = [{ children: [2] }, { children: [2] }, { mesh: 0 }];
    },
    /multi-parent/,
  ],
  [
    "duplicate roots",
    (d) => {
      d.scenes[0].nodes = [0, 0];
    },
    /Duplicate scene/,
  ],
  [
    "invalid child",
    (d) => {
      d.nodes[0].children = [7];
    },
    /node reference/,
  ],
  [
    "invalid mesh",
    (d) => {
      d.nodes[0].mesh = 2;
    },
    /mesh reference/,
  ],
  [
    "invalid default scene",
    (d) => {
      d.scene = 3;
    },
    /default scene/,
  ],
  [
    "empty assembly",
    (d) => {
      d.nodes[0] = {};
    },
    /no mesh/,
  ],
];
for (const [name, edit, message] of malformed)
  test(`rejects ${name}`, () => assert.throws(() => inspectGlb(fixture({ edit })), message));
test("overlapping subtrees and invalid explicit roots fail", () => {
  const bytes = fixture({
    edit: (d) => {
      d.nodes = [{ children: [1] }, { mesh: 0 }];
    },
  });
  for (const nodes of [[0, 1], [1, 1], [9], []]) assert.throws(() => inspectGlb(bytes, { nodes }));
});
test("invalid GLB lengths, alignment, chunk order and header fail", () => {
  const valid = fixture();
  for (const mutate of [
    (b) => b.writeUInt32LE(0, 0),
    (b) => b.writeUInt32LE(1, 4),
    (b) => b.writeUInt32LE(b.length + 4, 8),
    (b) => b.writeUInt32LE(3, 12),
    (b) => b.writeUInt32LE(0x004e4942, 16),
  ]) {
    const b = Buffer.from(valid);
    mutate(b);
    assert.throws(() => inspectGlb(b));
  }
  assert.throws(() => inspectGlb(valid.subarray(0, 10)), /Truncated/);
});
test("optional material metadata does not block core geometry", () => {
  assert.equal(
    inspectGlb(
      fixture({
        edit: (d) => {
          d.extensionsUsed = ["KHR_materials_specular"];
          d.materials = [{ extensions: { KHR_materials_specular: { specularFactor: 0.5 } } }];
        },
      }),
    ).inventory.triangles,
    1,
  );
});
describe("asset-inspect CLI", { concurrency: CONCURRENCY }, () => {
  test("CLI inventory is not approval; exact ceiling passes and above fails", async (t) => {
    const dir = workspace(t);
    const f30000 = save(dir, "30000.glb", fixture({ triangles: 30000 }));
    const f30001 = save(dir, "30001.glb", fixture({ triangles: 30001 }));
    const [pass30k, over30k, inv] = await Promise.all([
      execute([f30000, "--profile", "generic-30k"]),
      execute([f30001, "--profile", "generic-30k"]),
      execute([f30000]),
    ]);
    for (const [r, count, status, code] of [
      [pass30k, 30000, "pass", 0],
      [over30k, 30001, "over_budget", 2],
    ]) {
      assert.equal(r.code, code);
      assert.equal(r.report.status, status);
      assert.equal(r.report.assembly.triangles, count);
    }
    assert.equal(inv.report.status, "inventory");
    assert.equal(inv.report.budget, null);
    assert.equal(inv.report.engine_import, "not_run");
    assert.equal(inv.report.gpu_memory_bytes, null);
  });
  test("three million triangles have real binary index storage and fail 30k", async (t) => {
    const dir = workspace(t),
      bytes = fixture({ triangles: 3000000 });
    assert.ok(bytes.length > 36000000);
    const file = save(dir, "large.glb", bytes),
      r = await execute([file, "--max-tris", "30000"]);
    assert.equal(r.code, 2);
    assert.equal(r.report.files[0].inventory.triangles, 3000000);
  });
  test("manifest totals intentional instances; combined placement remains unknown", async (t) => {
    const dir = workspace(t);
    save(dir, "part.glb", fixture());
    const manifest = save(
      dir,
      "assembly.json",
      JSON.stringify({
        version: 1,
        name: "pair",
        parts: [
          { file: "part.glb", nodes: [0], lod: "high" },
          { file: "part.glb", nodes: [0], lod: "high" },
        ],
      }),
    );
    const r = await execute(["--manifest", manifest, "--max-tris", "2"]);
    assert.equal(r.code, 0);
    assert.equal(r.report.assembly.triangles, 2);
    assert.equal(r.report.assembly.static_world_bounds, null);
    assert.equal(r.report.assembly.bounds_status, "unknown_no_shared_placement");
    assert.equal(r.report.files[0].lod, "high");
  });
  test("manifest fields and unsafe paths are rejected", async (t) => {
    const dir = workspace(t);
    const parts = [
      { file: "https://example.com/a.glb", nodes: [0] },
      { file: "/absolute.glb", nodes: [0] },
      { file: "part.glb", nodes: ["0"] },
      { file: "part.glb", nodes: [0], unexpected: true },
    ];
    const results = await Promise.all(
      parts.map((part, i) => {
        const manifest = save(
          dir,
          `bad-${i}.json`,
          JSON.stringify({ version: 1, name: "bad", parts: [part] }),
        );
        return execute(["--manifest", manifest]);
      }),
    );
    for (const r of results) assert.equal(r.code, 1);
  });
  test("output cannot overwrite direct, symlink, hardlink or manifest inputs", async (t) => {
    const dir = workspace(t),
      bytes = fixture(),
      file = save(dir, "part.glb", bytes),
      sym = path.join(dir, "symlink.json"),
      hard = path.join(dir, "hardlink.json");
    fs.symlinkSync(file, sym);
    fs.linkSync(file, hard);
    const manifest = save(
        dir,
        "assembly.json",
        JSON.stringify({
          version: 1,
          name: "part",
          parts: [{ file: "part.glb", nodes: [0] }],
        }),
      ),
      original = fs.readFileSync(manifest);
    const output = path.join(dir, "receipt.json");
    const [directRes, symRes, hardRes, manifestRes, okRes] = await Promise.all([
      execute([file, "--output", file]),
      execute([file, "--output", sym]),
      execute([file, "--output", hard]),
      execute(["--manifest", manifest, "--output", manifest]),
      execute([file, "--output", output]),
    ]);
    for (const r of [directRes, symRes, hardRes]) {
      assert.equal(r.code, 1);
      assert.match(r.report.errors.join(" "), /aliases/);
    }
    assert.equal(manifestRes.code, 1);
    assert.deepEqual(fs.readFileSync(manifest), original);
    assert.equal(okRes.code, 0);
    assert.equal(JSON.parse(fs.readFileSync(output)).status, "inventory");
    assert.deepEqual(fs.readFileSync(file), bytes);
  });
  test("failed inspection writes explicitly invalid receipt safely", async (t) => {
    const dir = workspace(t),
      file = save(
        dir,
        "bad.glb",
        fixture({
          edit: (d) => {
            d.meshes[0].primitives[0].mode = 1;
          },
        }),
      ),
      output = path.join(dir, "failed.json");
    assert.equal((await execute([file, "--output", output, "--profile", "generic-30k"])).code, 1);
    assert.equal(JSON.parse(fs.readFileSync(output)).status, "invalid");
  });
  test("batch totals selected instances and does not claim shared bounds", async (t) => {
    const dir = workspace(t),
      a = save(dir, "a.glb", fixture()),
      b = save(dir, "b.glb", fixture({ triangles: 2 }));
    const r = await execute([a, b, "--max-tris", "2"]);
    assert.equal(r.code, 2);
    assert.equal(r.report.assembly.triangles, 3);
    assert.equal(r.report.assembly.static_world_bounds, null);
  });
  test("CLI usage rejects conflicting or malformed options with bounded diagnostics", async () => {
    const results = await Promise.all(
      [
        [],
        ["--max-tris", "-1"],
        ["--profile", "missing"],
        ["--nodes", "a"],
        ["--nodes", "0", "--scene", "0"],
        ["--wat"],
      ].map((args) => execute(args)),
    );
    for (const r of results) {
      assert.equal(r.code, 1);
      assert.ok(r.report.errors.length);
      assert.doesNotMatch(r.stderr, /at file:/);
    }
  });

  test("an option cannot consume the next option as its missing value", async (t) => {
    const dir = workspace(t);
    const file = save(dir, "valid.glb", fixture());
    const results = await Promise.all(
      ["--output", "--manifest", "--nodes", "--scene", "--profile", "--max-tris"].map((option) =>
        execFileAsync(process.execPath, [cli, file, option, "--json"], {
          cwd: dir,
          encoding: "utf8",
        }).then(
          (res) => ({ status: 0, stdout: res.stdout }),
          (err) => ({ status: err.code, stdout: err.stdout }),
        ),
      ),
    );
    for (const result of results) {
      assert.equal(result.status, 1);
      const report = JSON.parse(result.stdout);
      assert.equal(report.status, "invalid");
      assert.match(report.errors.join(" "), /Missing value/);
      assert.equal(fs.existsSync(path.join(dir, "--json")), false);
    }
  });
});

for (const [indexComponent, sentinel] of [
  [5121, 255],
  [5123, 65535],
]) {
  test(`rejects reserved ${indexComponent} index despite sufficient POSITION storage`, () => {
    const options = { indexComponent, vertexCount: sentinel + 1 };
    assert.throws(
      () => inspectGlb(fixture({ ...options, indexValues: [0, 1, sentinel] })),
      /Reserved primitive-restart index value/,
    );
    const valid = inspectGlb(fixture({ ...options, indexValues: [0, 1, sentinel - 1] }));
    assert.equal(valid.selection.triangles, 1);
    assert.equal(valid.inventory.vertices, sentinel + 1);
  });
}
test("rejects reserved U32 index explicitly before POSITION range validation", () => {
  assert.throws(
    () => inspectGlb(fixture({ indexValues: [0, 1, 4294967295] })),
    /Reserved primitive-restart index value/,
  );
  assert.equal(inspectGlb(fixture({ indexValues: [0, 1, 2] })).selection.triangles, 1);
});
test("a -col node counts under collision_nodes, not draws", () => {
  const r = inspectGlb(
    fixture({
      edit: (d) => {
        d.nodes = [
          { children: [1, 2] },
          { name: "piece", mesh: 0 },
          { name: "piece-col", mesh: 0 },
        ];
      },
    }),
  );
  assert.equal(r.selection.primitives, 2);
  assert.equal(r.selection.draws, 1);
  assert.equal(r.selection.collision_nodes, 1);
  assert.equal(r.selection.triangles, 2);
  const plain = inspectGlb(fixture());
  assert.equal(plain.selection.draws, 1);
  assert.equal(plain.selection.collision_nodes, 0);
});
test("a park recipe base GLB draws once and carries one -col node", () => {
  const glb = fileURLToPath(
    new URL("../sketches/core-loop/assets/models/park/half_pipe_concrete.glb", import.meta.url),
  );
  const r = inspectGlb(fs.readFileSync(glb));
  assert.equal(r.selection.primitives, 2);
  assert.equal(r.selection.draws, 1);
  assert.equal(r.selection.collision_nodes, 1);
});
