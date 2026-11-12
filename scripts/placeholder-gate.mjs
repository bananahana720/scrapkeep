import { existsSync, readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { cueFindings } from "./audio-gate.mjs";

// npm run sketch:placeholders (port note): the alpha's "no placeholders" release check for
// sketches/core-loop. It reads the tree statically, with no Godot, and fails on anything the
// game still shows as a stand-in:
//   park       a park row whose recipe is `greybox:<element>`, or names a GLB that has not landed
//              (park_recipes.gd stands it in as its greybox), on the six park maps park_defs.gd uses;
//              a stamped plain slope (PLAIN_SLOPES) is terrain, not a placeholder (see below); an anchors
//              kit recipe (ANCHOR_KITS) needs all three of its variant GLBs
//   icon       an icon id with no assets/icons/<id>.svg, so Icons.texture draws the glyph placeholder
//   pending    an entry in a src/ list named *PENDING* (cosmetics PENDING_ART, codex DETECTOR_PENDING,
//              SIDE_CONTENT_PENDING, achievements PENDING_PILOTS)
//   cosmetic   a non-paint cosmetic row whose asset resolves to no file (Cosmetics.asset_paths)
//   registry   a registry asset delivered but not wired ("integration pending", "wire it in")
//   attack     an ATTACK_ROWS row with fields still open (event_kinds.gd PLACEHOLDER "tbd")
//   ability    a pilot still on the shared stand-in line_reel or ult_default (SKILL-BAR 3 and 4)
//   text       a player-facing string with TODO, TBD, FIXME, XXX, lorem, placeholder or coming soon
//   audio      a special-enemy or boss cue from INTEGRATION.md the game cannot play (audio-gate.mjs,
//              which also measures loudness and loop seams)
// What it cannot see: a runtime fallback (a capsule, a missing material) that only a running
// build shows; tests/dress_coverage_test.gd and release_gate_placeholder_test.gd own those. Nor a
// mesh the game builds from a Godot primitive: tests/prim_census_test.gd runs a bot through world 1
// and fails on one not in tools/prim_census_pin.tsv; this prints how many stand-ins that pin still owes.
// Run: node scripts/placeholder-gate.mjs [--project <dir>] [--json] [--limit <n per group>]

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export const PARK_MAPS_FILE = "src/core/park_defs.gd";
export const GREYBOX = "greybox:";
// Andrew's ruling 2026-10-17 06:16Z ("Ride lips only"): tunnel mouths, half-pipe edges, kickers and caverns
// get real pieces; a plain bank, drop, ground shelf or mesa whose height stamp already shapes the ground
// counts once its world's ground and scatter are on. Such a row draws no grey box (park_recipes.gd
// stamp_replaces: a stamp and no absolute y), so the check lists it as terrain and does not fail on it.
// The scatter half is runtime: park_map.gd keeps scatter out of every non-ground footprint until the wave
// coordinator lets it onto these rows.
export const PLAIN_SLOPES = ["bank", "drop", "ground", "sky_island"];
export const LANDMARK_DRESSED = "landmark";
// park_recipes.gd: the park's ground scatter dresses the row, so it is no stand-in.
export const SCATTER_DRESSED = "scatter";
// Andrew's "Edges are ground" (2026-10-17 22:29Z): a stamped greybox kicker spanning the whole play rect across its
// facing (the Highdraft's mesa step lips) is a mesa edge, ground like a plain slope (park_map.gd mesa_edge). Extended
// to every element by World NEEDS #149 6325353865, coordinator ruling (a) 2026-10-21, Andrew's veto list: any stamped
// greybox row with no absolute y whose cross size spans the rect (a 1,600 m ride band) is ground too.
export const TEXT_MARKER = /\b(todo|tbd|fixme|xxx|lorem|placeholders?|coming soon|not yet implemented)\b/i;
// Calls whose text goes to the log, not the screen.
export const LOG_CALL = /\b(print|prints|printerr|print_rich|push_warning|push_error|assert|_warn|_warn_once|_fail)\s*\(/;
export const STAND_IN_ABILITIES = { line_id: "line_reel", ultimate_id: "ult_default" };
export const UNWIRED_LOADER = /integration pending|wire it in/i;

// String literals in GDScript source with their 1-based line, comments skipped. Handles '' and
// "" with escapes, triple quotes, and the &"" / ^"" StringName and NodePath prefixes.
export function gdStrings(source) {
  const out = [];
  let line = 1;
  let i = 0;
  while (i < source.length) {
    const c = source[i];
    if (c === "\n") {
      line++;
      i++;
    } else if (c === "#") {
      while (i < source.length && source[i] !== "\n") i++;
    } else if (c === '"' || c === "'") {
      const triple = source.startsWith(c.repeat(3), i);
      const close = triple ? c.repeat(3) : c;
      const start = line;
      let j = i + close.length;
      let text = "";
      while (j < source.length && !source.startsWith(close, j)) {
        if (source[j] === "\\") {
          text += source.slice(j, j + 2);
          j += 2;
          continue;
        }
        if (source[j] === "\n") {
          if (!triple) break;
          line++;
        }
        text += source[j++];
      }
      out.push({ text, line: start });
      i = j + close.length;
    } else i++;
  }
  return out;
}

// A constant whose whole value is a marker word is a sentinel the code compares against, such as
// event_kinds.gd PLACEHOLDER := "tbd"; the check that owns its uses reports them.
export const SENTINEL = /^\s*const\s+\w+\s*(:\s*\w+\s*)?:?=\s*"(\w+)"\s*$/;

// Literals with a marker word, minus those on a line that only logs and sentinel constants.
export function markedText(source, file) {
  const lines = source.split("\n");
  const sentinel = (line) => {
    const m = SENTINEL.exec(line);
    return m !== null && TEXT_MARKER.test(m[2]) && m[2].length <= 12;
  };
  return gdStrings(source)
    .filter(({ text, line }) => TEXT_MARKER.test(text) && !LOG_CALL.test(lines[line - 1] ?? "") && !sentinel(lines[line - 1] ?? ""))
    .map(({ text, line }) => ({ kind: "text", where: `${file}:${line}`, what: JSON.stringify(text) }));
}

// The text = "..." properties of a .tscn scene.
export function sceneText(source, file) {
  const found = [];
  source.split("\n").forEach((line, index) => {
    const m = /^\s*(text|tooltip_text|placeholder_text)\s*=\s*"(.*)"\s*$/.exec(line);
    if (m && TEXT_MARKER.test(m[2]))
      found.push({ kind: "text", where: `${file}:${index + 1}`, what: JSON.stringify(m[2]) });
  });
  return found;
}

// The map ids a defs file's rows use: every "map": "<id>".
export function mapIds(source) {
  return [...new Set([...source.matchAll(/"map":\s*"([a-z0-9_]+)"/g)].map((m) => m[1]))];
}

// Every object under a park file that carries a recipe.
export function recipeRows(doc, group = "") {
  const rows = [];
  if (Array.isArray(doc)) doc.forEach((item) => rows.push(...recipeRows(item, group)));
  else if (doc && typeof doc === "object") {
    if (typeof doc.recipe === "string") rows.push({ group, row: doc });
    for (const [key, value] of Object.entries(doc))
      if (value && typeof value === "object") rows.push(...recipeRows(value, key.endsWith("_rows") ? key : group));
  }
  return rows;
}

// park_recipes.gd GLB_DIR for park rows and the landmark, contraptions.gd SKIN_DIR for contraptions.
export function glbPath(recipe, group) {
  return group === "contraption_rows" ? `assets/models/park/contraptions/${recipe}.glb` : `assets/models/park/${recipe}.glb`;
}

// park_recipes.gd ANCHOR_KITS: an anchors kit recipe has no <recipe>.glb; it is built when all its variants have landed.
export const ANCHOR_KITS = ["anchor_hoodoo", "anchor_basalt", "anchor_timber", "anchor_saguaro", "anchor_cairn"];
export const ANCHOR_VARIANTS = ["a", "b", "c"];

// The GLB ids a recipe needs before it stops standing in: an anchors kit's variants, else the recipe itself.
export function recipeGlbs(recipe) {
  return ANCHOR_KITS.includes(recipe) ? ANCHOR_VARIANTS.map((v) => `${recipe}_${v}`) : [recipe];
}

export function isPlainSlope(row) {
  return (
    typeof row.recipe === "string" &&
    row.recipe === GREYBOX + row.element &&
    PLAIN_SLOPES.includes(row.element) &&
    (row.stamp ?? "") !== "" &&
    row.y == null
  );
}

export function isMesaEdge(row, playRect) {
  if (!String(row.recipe ?? "").startsWith(GREYBOX) || (row.stamp ?? "") === "" || row.y != null) return false;
  if (!Array.isArray(playRect) || !Array.isArray(row.size)) return false;
  const a = ((row.yaw_deg ?? 0) * Math.PI) / 180;
  return row.size[2] >= Math.abs(Math.cos(a)) * playRect[2] + Math.abs(Math.sin(a)) * playRect[3];
}

// One finding per map and stand-in element, with its count and first ids.
export function parkGreybox(map, doc, glbExists) {
  const groups = new Map();
  for (const { group, row } of recipeRows(doc)) {
    const recipe = row.recipe;
    if (isPlainSlope(row) || isMesaEdge(row, doc.play_rect)) continue;
    let element = null;
    let why = "";
    if (recipe === SCATTER_DRESSED) continue;
    if (recipe.startsWith(GREYBOX)) element = recipe.slice(GREYBOX.length);
    else if (recipe === LANDMARK_DRESSED) {
      // park_recipes.gd: the landmark's own model dresses the row, so it stands in until that GLB lands.
      const mark = doc.landmark?.recipe ?? "";
      if (mark === "" || !glbExists(mark, "")) {
        element = row.element ?? recipe;
        why = ` (dressed by landmark ${mark || "?"}, which has no GLB)`;
      }
    } else if (recipe !== "" && !recipeGlbs(recipe).every((id) => glbExists(id, group))) {
      element = row.element ?? recipe;
      why = ` (recipe ${recipe} has no GLB)`;
    }
    if (element === null) continue;
    const key = element + why;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(row.id ?? "?");
  }
  return [...groups.entries()]
    .sort((a, b) => b[1].length - a[1].length || a[0].localeCompare(b[0]))
    .map(([key, ids]) => ({
      kind: "park",
      where: map,
      what: `${ids.length} greybox ${key}: ${ids.slice(0, 3).join(", ")}${ids.length > 3 ? ", ..." : ""}`,
      count: ids.length,
    }));
}

// The keys of a `const NAME := { ... }` dictionary block.
export function dictKeys(source, name) {
  const start = source.search(new RegExp(`^const ${name}\\s*:?=\\s*\\{`, "m"));
  if (start < 0) return [];
  const end = source.indexOf("\n}", start);
  const block = source.slice(start, end < 0 ? undefined : end).replace(/#[^\n]*/g, "");
  return [...block.matchAll(/"([a-z0-9_]+)"\s*:/g)].map((m) => m[1]);
}

// Every icon id the game asks for: the contract's IDS and EXTRA, the literal Icons.texture ids,
// and the "icon" of each ability row (ability_state.gd). Other files' "icon" fields are categories
// that callers prefix (cat_<category>), so they are not ids.
export function iconIds(iconsSource, otherSources = [], abilitySource = "") {
  const ids = new Set([...dictKeys(iconsSource, "IDS"), ...dictKeys(iconsSource, "EXTRA")]);
  for (const source of otherSources)
    for (const m of source.matchAll(/Icons\.texture\("([a-z0-9_]+)"\)/g)) ids.add(m[1]);
  for (const m of abilitySource.matchAll(/"icon":\s*"([a-z0-9_]+)"/g)) ids.add(m[1]);
  return [...ids].sort();
}

export function missingIcons(ids, svgExists) {
  return ids
    .filter((id) => !svgExists(id))
    .map((id) => ({ kind: "icon", where: "assets/icons", what: `${id}.svg missing; Icons.texture draws its glyph placeholder` }));
}

// The quoted entries of every `const *PENDING* := [ ... ]` in a file.
export function pendingEntries(source, file) {
  const found = [];
  for (const m of source.matchAll(/^const (\w*PENDING\w*)\s*(?::\s*[\w[\]]+\s*)?:?=\s*\[([^\]]*)\]/gm))
    for (const entry of m[2].matchAll(/"([^"]+)"/g))
      found.push({ kind: "pending", where: `${file} ${m[1]}`, what: entry[1] });
  return found;
}

// Cosmetic rows from cosmetics.gd ROWS: {id, slot, name, asset}.
export function cosmeticRows(source) {
  const rows = [];
  for (const m of source.matchAll(/^\s*"([a-z0-9_]+)":\s*\{"slot":\s*"([a-z_]+)"([^\n]*)/gm)) {
    const name = /"name":\s*"([^"]*)"/.exec(m[3]);
    const asset = /"asset":\s*"([^"]*)"/.exec(m[3]);
    rows.push({ id: m[1], slot: m[2], name: name ? name[1] : "", asset: asset ? asset[1] : "" });
  }
  return rows;
}

// A non-paint row whose asset names no path, or a path with no file. Rows PENDING_ART already
// names are left to the pending check so each owed row is listed once.
export function cosmeticsWithoutArt(rows, assetPaths, fileExists, pending = []) {
  return rows
    .filter((row) => row.slot !== "paint" && !pending.includes(row.id))
    .flatMap((row) => {
      const target = assetPaths[row.asset];
      if (!row.asset) return [{ kind: "cosmetic", where: row.id, what: `${row.slot} "${row.name}" names no asset` }];
      if (!target) return [{ kind: "cosmetic", where: row.id, what: `${row.slot} "${row.name}": asset ${row.asset} is in neither the registry nor cua_manifest.json` }];
      if (!fileExists(target)) return [{ kind: "cosmetic", where: row.id, what: `${row.slot} "${row.name}": ${target} is missing` }];
      return [];
    });
}

// Cosmetics.asset_paths: registry ids and paths, then the cosmetics manifest groups.
export function assetPaths(registry, manifest) {
  const paths = {};
  for (const entry of registry.assets ?? []) if (entry.id && entry.path) paths[entry.id] = entry.path;
  for (const group of ["trails", "decals", "paints"])
    for (const entry of manifest[group] ?? []) paths[entry.id] = "res://assets/cosmetics/" + entry.path;
  return paths;
}

export function unwiredAssets(registry) {
  return (registry.assets ?? [])
    .filter((entry) => !entry.ships && UNWIRED_LOADER.test(entry.loader ?? ""))
    .map((entry) => ({ kind: "registry", where: entry.id ?? entry.path, what: `not wired: ${entry.loader}` }));
}

// ATTACK_ROWS rows whose open list is not empty.
export function openAttackRows(source) {
  const found = [];
  for (const m of source.matchAll(/"([A-Z]+\d+)":\s*\{"label":\s*"([^"]*)"[\s\S]*?"open":\s*\[([^\]]*)\]/g)) {
    const open = [...m[3].matchAll(/"([a-z_]+)"/g)].map((f) => f[1]);
    if (open.length > 0)
      found.push({ kind: "attack", where: `ATTACK_ROWS ${m[1]}`, what: `${m[2]}: ${open.join(", ")} open` });
  }
  return found;
}

// class_def.gd rows still carrying a shared stand-in ability.
export function standInAbilities(source) {
  const found = [];
  source.split("\n").forEach((line, index) => {
    for (const [field, id] of Object.entries(STAND_IN_ABILITIES))
      if (new RegExp(`"${field}":\\s*"${id}"`).test(line))
        found.push({ kind: "ability", where: `src/core/class_def.gd:${index + 1}`, what: `${field} is the shared stand-in ${id}` });
  });
  return found;
}

function walk(dir, ext, base = dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(full, ext, base);
    return ext.some((e) => entry.name.endsWith(e)) ? [path.relative(base, full)] : [];
  });
}

export function scan(project) {
  const read = (rel) => readFileSync(path.join(project, rel), "utf8");
  const has = (rel) => existsSync(path.join(project, rel));
  const res = (p) => p.replace(/^res:\/\//, "");
  const findings = [];

  const parkDefs = has(PARK_MAPS_FILE) ? read(PARK_MAPS_FILE) : "";
  for (const map of mapIds(parkDefs)) {
    const file = `src/world/park/${map}.json`;
    if (!has(file)) {
      findings.push({ kind: "park", where: map, what: `no park file; the stage stands on its old map` });
      continue;
    }
    findings.push(...parkGreybox(map, JSON.parse(read(file)), (recipe, group) => has(glbPath(recipe, group))));
  }

  const sources = walk(path.join(project, "src"), [".gd"]).map((rel) => ({ rel: "src/" + rel, text: read("src/" + rel) }));
  const icons = has("src/ui/icons.gd") ? read("src/ui/icons.gd") : "";
  const abilities = has("src/core/ability_state.gd") ? read("src/core/ability_state.gd") : "";
  const ids = iconIds(icons, sources.map((s) => s.text), abilities);
  findings.push(...missingIcons(ids, (id) => has(`assets/icons/${id}.svg`)));

  const pending = sources.flatMap((s) => pendingEntries(s.text, s.rel));
  findings.push(...pending);

  const registry = has("assets/registry.json") ? JSON.parse(read("assets/registry.json")) : { assets: [] };
  const manifest = has("assets/cosmetics/cua_manifest.json") ? JSON.parse(read("assets/cosmetics/cua_manifest.json")) : {};
  if (has("src/core/cosmetics.gd"))
    findings.push(
      ...cosmeticsWithoutArt(
        cosmeticRows(read("src/core/cosmetics.gd")),
        assetPaths(registry, manifest),
        (p) => has(res(p)),
        pending.map((p) => p.what),
      ),
    );
  findings.push(...unwiredAssets(registry));

  if (has("src/core/event_kinds.gd")) findings.push(...openAttackRows(read("src/core/event_kinds.gd")));
  if (has("src/core/class_def.gd")) findings.push(...standInAbilities(read("src/core/class_def.gd")));

  for (const s of sources) findings.push(...markedText(s.text, s.rel));
  for (const rel of ["main.tscn", ...walk(path.join(project, "src"), [".tscn"]).map((r) => "src/" + r)])
    if (has(rel)) findings.push(...sceneText(read(rel), rel));
  findings.push(...cueFindings(project).map((f) => ({ ...f, kind: "audio" })));
  return findings;
}

export const KIND_TITLES = {
  park: "Greybox park rows",
  icon: "Icons drawn as placeholder glyphs",
  pending: "Content lists still owing art or content",
  cosmetic: "Cosmetics with no art",
  registry: "Art delivered but not wired",
  attack: "Attack rows with open fields",
  ability: "Pilots on stand-in abilities",
  text: "Placeholder words in player-facing text",
  audio: "Special-enemy and boss cues the game cannot play",
};

export function report(findings, limit = Infinity) {
  if (findings.length === 0) return "placeholder gate: PASS (no placeholders found)";
  const lines = [];
  for (const [kind, title] of Object.entries(KIND_TITLES)) {
    const group = findings.filter((f) => f.kind === kind);
    if (group.length === 0) continue;
    const total = group.reduce((sum, f) => sum + (f.count ?? 1), 0);
    lines.push(`${title}: ${total}`);
    for (const f of group.slice(0, limit)) lines.push(`  ${f.where}  ${f.what}`);
    if (group.length > limit) lines.push(`  ... ${group.length - limit} more`);
  }
  const total = findings.reduce((sum, f) => sum + (f.count ?? 1), 0);
  lines.push(`placeholder gate: FAIL (${total} placeholder(s) in ${findings.length} finding(s))`);
  return lines.join("\n");
}

export function parseArgs(argv) {
  const args = { project: path.join(root, "sketches/core-loop"), json: false, limit: Infinity };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--json") args.json = true;
    else if (arg === "--project" && i + 1 < argv.length) args.project = path.resolve(argv[++i]);
    else if (arg.startsWith("--project=")) args.project = path.resolve(arg.slice("--project=".length));
    else if (arg === "--limit" && i + 1 < argv.length) args.limit = Number(argv[++i]);
    else if (arg.startsWith("--limit=")) args.limit = Number(arg.slice("--limit=".length));
    else throw new Error("unknown argument: " + arg);
  }
  if (!Number.isFinite(args.limit) && args.limit !== Infinity) throw new Error("--limit needs a number");
  return args;
}

// How many stamped plain slopes each park map counts as terrain, for the report's note.
export function terrainRows(project) {
  const read = (rel) => readFileSync(path.join(project, rel), "utf8");
  const parkDefs = existsSync(path.join(project, PARK_MAPS_FILE)) ? read(PARK_MAPS_FILE) : "";
  let total = 0;
  for (const map of mapIds(parkDefs)) {
    const file = `src/world/park/${map}.json`;
    if (!existsSync(path.join(project, file))) continue;
    const doc = JSON.parse(read(file));
    total += recipeRows(doc).filter(({ row }) => isPlainSlope(row) || isMesaEdge(row, doc.play_rect)).length;
  }
  return total;
}

export const PRIM_PIN_FILE = "tools/prim_census_pin.tsv";

// The code-built stand-ins tools/prim_census_pin.tsv still owes, by BACKLOG row: {row: pin lines}.
// The census test, not this file, judges what the game draws; this only reads the pin for the note.
export function primStandIns(project) {
  const file = path.join(project, PRIM_PIN_FILE);
  if (!existsSync(file)) return {};
  const out = {};
  for (const line of readFileSync(file, "utf8").split("\n")) {
    const cells = line.split("\t");
    if (line.startsWith("#") || cells.length !== 6 || !cells[3].startsWith("stand-in")) continue;
    out[cells[4]] = (out[cells[4]] ?? 0) + 1;
  }
  return out;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const findings = scan(args.project);
  console.log(args.json ? JSON.stringify(findings, null, 2) : report(findings, args.limit));
  if (!args.json) {
    const terrain = terrainRows(args.project);
    if (terrain > 0) console.log(`note: ${terrain} stamped plain slope(s) and mesa edge(s) counted as terrain, not placeholders (PLAIN_SLOPES, isMesaEdge)`);
    const owed = Object.entries(primStandIns(args.project));
    if (owed.length > 0)
      console.log(`note: ${owed.reduce((sum, [, n]) => sum + n, 0)} code-built stand-in pin row(s) still owed (${owed.map(([row, n]) => `${row} ${n}`).join(", ")}); tests/prim_census_test.gd judges them, and fails each under SCRAPKEEP_RELEASE_GATE=1`);
  }
  process.exitCode = findings.length === 0 ? 0 : 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
