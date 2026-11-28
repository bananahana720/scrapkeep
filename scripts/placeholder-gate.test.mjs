import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  assetPaths,
  cosmeticRows,
  cosmeticsWithoutArt,
  dictKeys,
  gdStrings,
  glbPath,
  iconIds,
  mapIds,
  markedText,
  missingIcons,
  openAttackRows,
  parkGreybox,
  isPlainSlope,
  recipeGlbs,
  isMesaEdge,
  parseArgs,
  pendingEntries,
  primStandIns,
  report,
  scan,
  sceneText,
  standInAbilities,
  unwiredAssets,
} from "./placeholder-gate.mjs";

test("gdStrings skips comments and keeps escapes, single quotes and line numbers", () => {
  const source = '# "not this"\nvar a := "one \\"two\\"" # "nor this"\nvar b := \'three\'\n';
  assert.deepEqual(gdStrings(source), [
    { text: 'one \\"two\\"', line: 2 },
    { text: "three", line: 3 },
  ]);
});

test("gdStrings reads a triple-quoted string across lines", () => {
  assert.deepEqual(gdStrings('var a := """x\ny"""\nvar b := "z"'), [
    { text: "x\ny", line: 1 },
    { text: "z", line: 3 },
  ]);
});

test("marker words in shown text are found, log lines and sentinels are not", () => {
  const source = [
    'var title := "Stage TODO"',
    'push_warning("keeping functional placeholders")',
    'const PLACEHOLDER := "tbd"',
    'var lore := "Placeholder lore for the dam"',
    "# TODO in a comment",
    'var fine := "Spillway: the top shelf"',
  ].join("\n");
  const found = markedText(source, "src/x.gd");
  assert.deepEqual(
    found.map((f) => f.where),
    ["src/x.gd:1", "src/x.gd:4"],
  );
});

test("a word that only contains a marker is not one", () => {
  assert.deepEqual(markedText('var a := "todos are mastodons"', "f"), []);
});

test("sceneText reads text properties of a scene", () => {
  const found = sceneText(
    '[node name="A" type="Label"]\ntext = "Coming soon"\ntext = "Play"\n',
    "main.tscn",
  );
  assert.deepEqual(found, [{ kind: "text", where: "main.tscn:2", what: '"Coming soon"' }]);
});

test("mapIds lists each map a defs file uses once", () => {
  assert.deepEqual(mapIds('{"map": "park_dam"}, {"map": "park_flume"}, {"map": "park_dam"}'), [
    "park_dam",
    "park_flume",
  ]);
});

test("glbPath sends contraptions to their skin folder", () => {
  assert.equal(glbPath("cannon", "contraption_rows"), "assets/models/park/contraptions/cannon.glb");
  assert.equal(glbPath("canal_lip", "park_rows"), "assets/models/park/canal_lip.glb");
});

test("parkGreybox groups greybox recipes and recipes with no GLB, and passes built ones", () => {
  const doc = {
    landmark: { id: "dam", recipe: "landmark_dam" },
    park_rows: [
      { id: "a", element: "bank", recipe: "greybox:bank" },
      { id: "b", element: "bank", recipe: "greybox:bank" },
      { id: "c", element: "half_pipe", recipe: "half_pipe_concrete" },
      { id: "d", element: "ground", recipe: "" },
    ],
    contraption_rows: [{ id: "e", recipe: "cannon" }],
  };
  const built = new Set(["half_pipe_concrete:park_rows", "cannon:contraption_rows"]);
  const found = parkGreybox("park_dam", doc, (recipe, group) => built.has(`${recipe}:${group}`));
  assert.deepEqual(
    found.map((f) => [f.what, f.count]),
    [
      ["2 greybox bank: a, b", 2],
      ["1 greybox landmark_dam (recipe landmark_dam has no GLB): dam", 1],
    ],
  );
});

test("parkGreybox passes an anchors kit row only when all three variants have landed", () => {
  assert.deepEqual(recipeGlbs("anchor_cairn"), [
    "anchor_cairn_a",
    "anchor_cairn_b",
    "anchor_cairn_c",
  ]);
  assert.deepEqual(recipeGlbs("flume_span"), ["flume_span"]);
  const doc = {
    park_rows: [
      { id: "posts", element: "anchor_field", recipe: "anchor_hoodoo" },
      { id: "cairns", element: "anchor_field", recipe: "anchor_cairn" },
    ],
  };
  const built = new Set([
    "anchor_hoodoo_a",
    "anchor_hoodoo_b",
    "anchor_hoodoo_c",
    "anchor_cairn_a",
    "anchor_cairn_b",
  ]);
  const found = parkGreybox("park_islands", doc, (recipe) => built.has(recipe));
  assert.deepEqual(
    found.map((f) => [f.what, f.count]),
    [["1 greybox anchor_field (recipe anchor_cairn has no GLB): cairns", 1]],
  );
});

test("parkGreybox counts a mesa edge spanning the play rect as terrain and keeps narrower lips", () => {
  const rect = [-800, -800, 1600, 1600];
  const edge = {
    id: "fan_step_lip_1",
    element: "kicker",
    recipe: "greybox:kicker",
    stamp: "plateau",
    y: null,
    yaw_deg: 0,
    size: [12, 0.01, 1600],
  };
  const narrow = { ...edge, id: "fin_nose_kicker", size: [12, 0.01, 56] };
  const unstamped = { ...edge, id: "loose_lip", stamp: "" };
  assert.equal(isMesaEdge(edge, rect), true);
  assert.equal(isMesaEdge(narrow, rect), false);
  assert.equal(isMesaEdge(unstamped, rect), false);
  assert.equal(
    isMesaEdge({ ...edge, id: "run", element: "flow_line", recipe: "greybox:flow_line" }, rect),
    true,
  );
  assert.equal(
    isMesaEdge({ ...edge, id: "dressed", element: "flow_line", recipe: "isle_ride_x" }, rect),
    false,
  );
  const found = parkGreybox(
    "park_islands",
    { play_rect: rect, park_rows: [edge, narrow, unstamped] },
    () => false,
  );
  assert.deepEqual(
    found.map((f) => [f.what, f.count]),
    [["2 greybox kicker: fin_nose_kicker, loose_lip", 2]],
  );
});

test("parkGreybox counts a stamped plain slope as terrain and keeps ride pieces and unstamped slopes", () => {
  const doc = {
    park_rows: [
      { id: "bank_stamped", element: "bank", recipe: "greybox:bank", stamp: "raise", y: null },
      { id: "mesa_stamped", element: "sky_island", recipe: "greybox:sky_island", stamp: "raise" },
      { id: "bank_flat", element: "bank", recipe: "greybox:bank", stamp: "", y: null },
      { id: "bank_floating", element: "bank", recipe: "greybox:bank", stamp: "raise", y: 40 },
      { id: "tube_stamped", element: "tunnel", recipe: "greybox:tunnel", stamp: "cut", y: null },
    ],
  };
  const found = parkGreybox("park_x", doc, () => false);
  assert.deepEqual(
    found.map((f) => [f.what, f.count]),
    [
      ["2 greybox bank: bank_flat, bank_floating", 2],
      ["1 greybox tunnel: tube_stamped", 1],
    ],
  );
  assert.equal(isPlainSlope(doc.park_rows[0]), true);
  assert.equal(isPlainSlope(doc.park_rows[4]), false);
});

test("parkGreybox counts a landmark-dressed row only until the landmark's GLB lands, and never a scatter-dressed one", () => {
  const doc = {
    landmark: { id: "sinkhole", recipe: "landmark_sinkhole" },
    park_rows: [
      { id: "deck", element: "ledge", recipe: "landmark" },
      { id: "wash", element: "ledge", recipe: "scatter" },
    ],
  };
  const bare = parkGreybox("park_sinkhole", doc, () => false);
  assert.deepEqual(
    bare.map((f) => f.what),
    [
      "1 greybox landmark_sinkhole (recipe landmark_sinkhole has no GLB): sinkhole",
      "1 greybox ledge (dressed by landmark landmark_sinkhole, which has no GLB): deck",
    ],
  );
  assert.deepEqual(
    parkGreybox("park_sinkhole", doc, (recipe) => recipe === "landmark_sinkhole"),
    [],
  );
});

test("dictKeys reads the keys of one dictionary block and skips comments", () => {
  const source =
    'const IDS := {\n\t"cls_a": "x", # "not_a": "y"\n\t"cls_b": "z",\n}\nconst EXTRA := {"e": "f"}\n';
  assert.deepEqual(dictKeys(source, "IDS"), ["cls_a", "cls_b"]);
  assert.deepEqual(dictKeys(source, "EXTRA"), ["e"]);
  assert.deepEqual(dictKeys(source, "MISSING"), []);
});

test("iconIds joins the contract, literal texture calls and ability icons only", () => {
  const icons = 'const IDS := {"cls_a": "x"}\nconst EXTRA := {"ab_b": "y"}\n';
  const other = 'Icons.texture("res_c")\nvar row := {"icon": "damage"}';
  const ids = iconIds(icons, [other], '"line": {"icon": "ab_d"}');
  assert.deepEqual(ids, ["ab_b", "ab_d", "cls_a", "res_c"]);
  assert.deepEqual(
    missingIcons(ids, (id) => id !== "ab_d").map((f) => f.what),
    ["ab_d.svg missing; Icons.texture draws its glyph placeholder"],
  );
});

test("pendingEntries lists every entry of a PENDING list, typed or not, and nothing of an empty one", () => {
  const source =
    'const PENDING_ART := ["a", "b"]\nconst SIDE_CONTENT_PENDING: Array = []\nconst DETECTOR_PENDING := ["c"]\nconst OTHER := ["d"]\n';
  assert.deepEqual(
    pendingEntries(source, "f.gd").map((f) => `${f.where} ${f.what}`),
    ["f.gd PENDING_ART a", "f.gd PENDING_ART b", "f.gd DETECTOR_PENDING c"],
  );
});

test("cosmetics with no art: missing asset, unknown asset, missing file; paint and pending rows skipped", () => {
  const source = [
    '\t"paint_a": {"slot": "paint", "pilot": "", "name": "Salt", "tint": Color("fff")},',
    '\t"trail_ok": {"slot": "trail", "pilot": "", "name": "Ok", "asset": "trail_ok"},',
    '\t"trail_gone": {"slot": "trail", "pilot": "", "name": "Gone", "asset": "trail_gone"},',
    '\t"trail_unknown": {"slot": "trail", "pilot": "", "name": "Unknown", "asset": "nope"},',
    '\t"outfit_none": {"slot": "outfit", "pilot": "x", "name": "None"},',
    '\t"shell_owed": {"slot": "shell", "pilot": "x", "name": "Owed", "asset": "owed"},',
  ].join("\n");
  const rows = cosmeticRows(source);
  assert.equal(rows.length, 6);
  const paths = assetPaths(
    {
      assets: [
        { id: "trail_ok", path: "res://a/ok.glb" },
        { id: "trail_gone", path: "res://a/gone.glb" },
      ],
    },
    { trails: [] },
  );
  const found = cosmeticsWithoutArt(rows, paths, (p) => p === "res://a/ok.glb", ["shell_owed"]);
  assert.deepEqual(
    found.map((f) => f.where),
    ["trail_gone", "trail_unknown", "outfit_none"],
  );
});

test("assetPaths adds the cosmetics manifest under assets/cosmetics", () => {
  assert.deepEqual(assetPaths({ assets: [] }, { decals: [{ id: "d", path: "decals/d.tres" }] }), {
    d: "res://assets/cosmetics/decals/d.tres",
  });
});

test("unwiredAssets names unshipped assets whose loader says they wait for wiring", () => {
  const registry = {
    assets: [
      { id: "a", ships: false, loader: "none (delivered model; runtime integration pending)" },
      {
        id: "b",
        ships: false,
        loader: "none (forge promote x/v001; wire it in and set ships true)",
      },
      { id: "c", ships: false, loader: "none (route proof, wave 12)" },
      { id: "d", ships: true, loader: "hero_assets.gd" },
    ],
  };
  assert.deepEqual(
    unwiredAssets(registry).map((f) => f.where),
    ["a", "b"],
  );
});

test("openAttackRows lists rows with open fields across lines", () => {
  const source = [
    '\t"E01": {"label": "Lunge", "group": "enemy",',
    '\t\t"pose": "p", "floor": "B", "open": []},',
    '\t"E19": {"label": "Burst", "group": "enemy",',
    '\t\t"pose": "p", "floor": PLACEHOLDER, "open": ["pose", "floor"]},',
  ].join("\n");
  assert.deepEqual(
    openAttackRows(source).map((f) => `${f.where}: ${f.what}`),
    ["ATTACK_ROWS E19: Burst: pose, floor open"],
  );
});

test("standInAbilities finds a pilot on the shared line or ultimate", () => {
  const source =
    '"line_id": "bank_shot", "ultimate_id": "cable_run",\n"line_id": "line_reel", "ultimate_id": "ult_default",\n';
  assert.deepEqual(
    standInAbilities(source).map((f) => f.what),
    ["line_id is the shared stand-in line_reel", "ultimate_id is the shared stand-in ult_default"],
  );
});

test("report passes on no findings and sums park counts on a failure", () => {
  assert.equal(report([]), "placeholder gate: PASS (no placeholders found)");
  const text = report(
    [
      { kind: "park", where: "m", what: "3 greybox bank", count: 3 },
      { kind: "icon", where: "i", what: "x.svg missing" },
      { kind: "icon", where: "i", what: "y.svg missing" },
    ],
    1,
  );
  assert.match(text, /^Greybox park rows: 3$/m);
  assert.match(text, /^Icons drawn as placeholder glyphs: 2$/m);
  assert.match(text, /\.\.\. 1 more/);
  assert.match(text, /FAIL \(5 placeholder\(s\) in 3 finding\(s\)\)$/);
});

test("parseArgs reads the project, json and limit, and refuses the unknown", () => {
  const args = parseArgs(["--project=/p", "--json", "--limit", "4"]);
  assert.equal(args.project, path.resolve("/p"));
  assert.equal(args.json, true);
  assert.equal(args.limit, 4);
  assert.throws(() => parseArgs(["--nope"]), /unknown argument/);
});

function project(files) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "placeholder-gate-"));
  for (const [rel, text] of Object.entries(files)) {
    mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    writeFileSync(path.join(dir, rel), text);
  }
  return dir;
}

test("scan passes a finished project and fails each kind of placeholder", () => {
  const clean = {
    "src/core/park_defs.gd": '{"map": "park_a"}',
    "src/world/park/park_a.json": JSON.stringify({
      landmark: { id: "l", recipe: "land" },
      park_rows: [],
    }),
    "assets/models/park/land.glb": "",
    "src/core/icons.gd": 'const IDS := {"cls_a": "x"}\nconst EXTRA := {}\n',
    "assets/icons/cls_a.svg": "<svg/>",
    "src/core/cosmetics.gd":
      'const PENDING_ART := []\n\t"paint_a": {"slot": "paint", "name": "A"},\n',
    "assets/registry.json": JSON.stringify({ assets: [] }),
    "src/core/event_kinds.gd": '"E01": {"label": "L", "open": []},',
    "src/core/class_def.gd": '"line_id": "bank_shot",',
    "main.tscn": 'text = "Play"\n',
  };
  const good = project(clean);
  try {
    assert.deepEqual(scan(good), []);
  } finally {
    rmSync(good, { recursive: true, force: true });
  }
  const bad = project({
    ...clean,
    "src/world/park/park_a.json": JSON.stringify({
      landmark: { id: "l", recipe: "land" },
      park_rows: [{ id: "r", recipe: "greybox:bank" }],
    }),
    "src/core/icons.gd": 'const IDS := {"cls_a": "x", "cls_b": "y"}\nconst EXTRA := {}\n',
    "src/core/cosmetics.gd":
      'const PENDING_ART := ["trail_x"]\n\t"trail_y": {"slot": "trail", "name": "Y", "asset": "y"},\n',
    "assets/registry.json": JSON.stringify({
      assets: [
        { id: "z", path: "res://z", ships: false, loader: "none (runtime integration pending)" },
      ],
    }),
    "src/core/event_kinds.gd": '"E01": {"label": "L", "open": ["pose"]},',
    "src/core/class_def.gd": '"ultimate_id": "ult_default",',
    "main.tscn": 'text = "TODO title"\n',
  });
  try {
    const kinds = scan(bad)
      .map((f) => f.kind)
      .sort();
    assert.deepEqual(kinds, [
      "ability",
      "attack",
      "cosmetic",
      "icon",
      "park",
      "pending",
      "registry",
      "text",
    ]);
  } finally {
    rmSync(bad, { recursive: true, force: true });
  }
});

test("primStandIns counts the census pin's stand-in rows by BACKLOG row and skips code rows", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "prim-pin-"));
  try {
    assert.deepEqual(primStandIns(dir), {});
    mkdirSync(path.join(dir, "tools"));
    writeFileSync(
      path.join(dir, "tools/prim_census_pin.tsv"),
      [
        "# owner\tmesh\tshape\tkind\trow\twhy",
        "beacon.gd\t*\tBeacon/*\tcode\t-\tthe beacon",
        "radio_cache.gd\t*\t*\tstand-in\tW1-23\tradio",
        "none\tBoxMesh\tFind_*\tstand-in\tW1-22\tfinds",
        "x\ty\tz\tstand-in\tW1-22\tcache",
        "scrap_field.gd\t*\tScrap/*\tstand-in-live\tW1-21\tcogs",
      ].join("\n"),
    );
    assert.deepEqual(primStandIns(dir), { "W1-23": 1, "W1-22": 2, "W1-21": 1 });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
