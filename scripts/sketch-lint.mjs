import {
  existsSync,
  readdirSync,
  readFileSync,
  realpathSync,
  statSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { WORD_RULES, lintWords } from "./sketch-lint-words.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const BASELINE_FILE = path.join(root, "scripts", "sketch-lint.baseline.json");
const BASELINED_RULES = ["L1", "L2", "L3", "L4"];
const MAX_QUARANTINE = 3;
const QUARANTINE_HEADER = "test\towner\treason\tadded\tdeadline";
const TEST_FOLDERS = new Set(["unit", "support", "doubles", "fixtures", "trees", "workshop"]);
const launchesGame = /SMOKE_FLAGS|--flags|tuning\.gd/;
const SOURCE_EXTENSIONS = new Set([".gd", ".mjs", ".js", ".sh", ".py"]);

const finding = (rule, file, line, message) => ({ rule, path: file, line, message });

export function formatFinding(item) {
  return `${item.rule} ${item.path}:${item.line} ${item.message}`;
}

function codeLines(text) {
  return text
    .split("\n")
    .map((raw, index) => ({ raw, number: index + 1, code: raw.trim() }))
    .filter((line) => !line.code.startsWith("#") && !line.code.startsWith("//"));
}

const wallClock =
  /Time\.get_ticks_(?:msec|usec)|Time\.get_unix_time_from_system|Time\.get_datetime_\w+|OS\.delay_(?:msec|usec)|\bcreate_timer\b/;

export function lintL1(file, text) {
  return codeLines(text)
    .filter((line) => wallClock.test(line.raw))
    .map((line) =>
      finding(
        "L1",
        file,
        line.number,
        `wall-clock read (${line.raw.match(wallClock)[0]}); step frames or use the sim clock`,
      ),
    );
}

const writeOpen = /FileAccess\.open\([^)]*\b(?:WRITE|READ_WRITE|WRITE_READ)\b/;
const storeCall =
  /\.store_(?:string|line|buffer|var|8|16|32|64|float|double|half|real|csv_line|pascal_string)\(/;

export function lintL2(file, text) {
  return codeLines(text)
    .filter((line) => writeOpen.test(line.raw) || storeCall.test(line.raw))
    .map((line) =>
      finding("L2", file, line.number, "raw file write; saves go through SafeStore.write_atomic"),
    );
}

const toolsLoad = /res:\/\/tools\//;

const selfPlayLine = /^const SELF_PLAY := "res:\/\/tools\/self_play\.gd"$/;
export function lintL7(file, text) {
  const guarded =
    /(^|\/)src\/game\.gd$/.test(file) && text.includes("ResourceLoader.exists(script_path)");
  return codeLines(text)
    .filter((line) => toolsLoad.test(line.raw) && !(guarded && selfPlayLine.test(line.code)))
    .map((line) =>
      finding(
        "L7",
        file,
        line.number,
        "game code names a res://tools/ path, which the release pack leaves out; move the shared code under src/",
      ),
    );
}

export function parseTuning(text) {
  const table = text.match(/const FLAGS\s*:?=\s*\{([\s\S]*?)\n\}/);
  const flags = table
    ? [...table[1].matchAll(/^\s*"([a-z][a-z0-9-]*)"\s*:/gm)].map((match) => match[1])
    : [];
  const keys = [...text.matchAll(/\{"key":\s*"([^"]+)"/g)].map((match) => match[1]);
  if (flags.length === 0 || keys.length === 0) {
    throw new Error(
      `sketch-lint: parsed ${flags.length} FLAGS names and ${keys.length} row keys from tuning.gd; the lint cannot check flags without both`,
    );
  }
  return { flags: new Set(flags), keys: new Set(keys) };
}

const flagLiteral = /--([a-z][a-z0-9-]*)=/g;
const parsedFlag =
  /(?:begins_with|trim_prefix|startsWith|startswith|replace)\(\s*["']--([a-z][a-z0-9-]*)=/g;
const tuningCall = /\.(?:option|set_option|f|set_value)\(\s*"([^"]+)"/g;

export function lintL3(files, tuning) {
  const parsed = new Set();
  for (const file of files) {
    for (const line of codeLines(file.text)) {
      for (const match of line.raw.matchAll(parsedFlag)) parsed.add(match[1]);
    }
  }
  const findings = [];
  for (const file of files) {
    const owned = (name) =>
      parsed.has(name) || files.some((other) => other.text.includes(`"${name}"`));
    for (const line of codeLines(file.text)) {
      for (const match of line.raw.matchAll(flagLiteral)) {
        if (!tuning.flags.has(match[1]) && !owned(match[1])) {
          findings.push(
            finding(
              "L3",
              file.path,
              line.number,
              `launch flag --${match[1]}= is not a FLAGS name in tuning.gd`,
            ),
          );
        }
      }
      for (const match of line.raw.matchAll(tuningCall)) {
        if (!tuning.keys.has(match[1])) {
          findings.push(
            finding(
              "L3",
              file.path,
              line.number,
              `tuning key "${match[1]}" is not a row key in tuning.gd`,
            ),
          );
        }
      }
    }
  }
  return findings;
}

export function lintL4(entries, testsPath = "sketches/core-loop/tests") {
  const findings = [];
  for (const entry of entries) {
    const parts = entry.rel.split("/");
    const name = parts[parts.length - 1];
    if (parts.length === 1) {
      const known = entry.dir
        ? TEST_FOLDERS.has(name)
        : /^\w+\.gd(?:\.uid)?$/.test(name) || name === "QUARANTINE.tsv";
      if (!known)
        findings.push(
          finding(
            "L4",
            `${testsPath}/${entry.rel}`,
            1,
            "stray entry under tests/; allowed: NAME.gd, NAME.gd.uid, QUARANTINE.tsv, unit, support, doubles, fixtures, trees, workshop",
          ),
        );
    } else if (
      parts[0] === "unit" &&
      parts.length === 2 &&
      !entry.dir &&
      !/^\w+_case\.gd(?:\.uid)?$/.test(name)
    ) {
      findings.push(
        finding("L4", `${testsPath}/${entry.rel}`, 1, "file under tests/unit/ is not NAME_case.gd"),
      );
    }
  }
  return findings;
}

export function lintL5(text, tests, file = "sketches/core-loop/tests/QUARANTINE.tsv") {
  const lines = text
    .split("\n")
    .map((line) => line.replace(/\r$/, ""))
    .filter((line) => line.trim() !== "");
  if (lines[0] !== QUARANTINE_HEADER)
    return [
      finding("L5", file, 1, `header must be: ${QUARANTINE_HEADER.replaceAll("\t", " TAB ")}`),
    ];
  const entries = lines.slice(1);
  const findings = [];
  if (entries.length > MAX_QUARANTINE)
    findings.push(finding("L5", file, 1, `${entries.length} entries; at most ${MAX_QUARANTINE}`));
  const seen = new Set();
  entries.forEach((entry, index) => {
    const number = index + 2;
    const cells = entry.split("\t");
    if (cells.length !== 5 || cells.some((cell) => cell.trim() === "")) {
      findings.push(
        finding("L5", file, number, "entry needs test, owner, reason, added and deadline"),
      );
      return;
    }
    const [test, , , added] = cells;
    if (!tests.has(test))
      findings.push(finding("L5", file, number, `${test} is not an existing top-level test`));
    if (seen.has(test)) findings.push(finding("L5", file, number, `${test} is listed twice`));
    seen.add(test);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(added))
      findings.push(finding("L5", file, number, `added date "${added}" is not YYYY-MM-DD`));
  });
  return findings;
}

export const LIGHT_OWNERS = {
  "src/presentation/hero_assets.gd": {
    sites: 2,
    owner: "MossBay barge, made once per session by world.gd (workshop warm fills)",
  },
  "src/presentation/graphics_preset.gd": {
    sites: 1,
    owner: "sibling of the world sun, session-lived",
  },
  "src/presentation/world_look.gd": {
    sites: 3,
    owner:
      "the Dig's LampPool under its stage geometry root, kept across stage changes; Night Shift's NightLights under the stage roots' parent, session-lived and darkened when the day returns",
  },
  "src/presentation/title_stage.gd": {
    sites: 3,
    owner: "presentation's title stage, session-lived",
  },
  "src/ui/class_preview.gd": {
    sites: 2,
    owner: "class select screen, directional, closes before any stage",
  },
  "src/ui/build_read.gd": {
    sites: 1,
    owner: "pause menu's build read, its own-world SubViewport under the session-lived pause menu",
  },
  "src/ui/ending_sequence.gd": {
    sites: 1,
    owner: "ending screen, directional, after the last stage",
  },
  "src/world/flood.gd": {
    sites: 1,
    owner: "world.gd Flood, session-lived and reconfigured per stage",
  },
  "src/world/map_gorge.gd": {
    sites: 1,
    owner: "landmark under its stage geometry root, kept across stage changes",
  },
  "src/world/map_reach.gd": {
    sites: 1,
    owner: "landmark under its stage geometry root, kept across stage changes",
  },
  "src/world/terrain.gd": { sites: 1, owner: "the world sun, session-lived" },
  "src/world/camp_hub.gd": {
    sites: 1,
    owner: "the camp hub's root under the game node, session-lived and hidden outside the walk",
  },
  "src/presentation/arena_waking_dress.gd": {
    sites: 4,
    owner:
      "WakingLightPool under ctx.root, session-lived; lent to the arena and floors, darkened and returned before exit or drop",
  },
};

const lightNew = /\b(?:Omni|Spot|Directional)Light3D\.new\(/;

export function lintL6(file, rel, text, owners = LIGHT_OWNERS) {
  const sites = codeLines(text).filter((line) => lightNew.test(line.raw));
  if (sites.length === 0) return [];
  const listed = owners[rel];
  if (listed === undefined) {
    return sites.map((line) =>
      finding(
        "L6",
        file,
        line.number,
        "runtime Light3D in a file LIGHT_OWNERS does not list; a light freed with a stage-freed node crashes Forward+, so glow on the node's own mesh or list an owner that outlives the stage",
      ),
    );
  }
  if (sites.length !== listed.sites) {
    return sites.map((line) =>
      finding(
        "L6",
        file,
        line.number,
        `${sites.length} runtime Light3D sites, LIGHT_OWNERS lists ${listed.sites}; classify the new light's owner`,
      ),
    );
  }
  return [];
}

export function lintL6Owners(counts, relative, owners = LIGHT_OWNERS) {
  return Object.keys(owners)
    .filter((rel) => !counts.has(rel))
    .map((rel) =>
      finding(
        "L6",
        `${relative}/${rel}`,
        1,
        "LIGHT_OWNERS lists a file with no runtime Light3D: remove the entry",
      ),
    );
}

export const SIM_READS = {
  "src/presentation/audio.gd": {
    sites: 1,
    why: "the landing-sound guard repeats the director's own clearance check, so it asks about the same ball the director does",
  },
  "src/presentation/hero_assets.gd": {
    sites: 1,
    why: "the Warden's lens asks its Sight, which answers with the last seen place while the ball is cloaked and has no drawn place",
  },
  "src/presentation/reward_ceremony.gd": {
    sites: 1,
    why: "calm() decides whether a ceremony may stop the world: a rule read against threats and enemies at the tick",
  },
  "src/ui/workshop.gd": {
    sites: 1,
    why: "pulling up to Moss opens the counter: a rule about where the ball is, not a picture of it",
  },
};

const tickGuard = /has_method\(\s*["']ball_position["']\s*\)/g;
const tickRead = /\bball_position\b|\b(?:active_)?body\(\)\s*\.\s*global_(?:position|transform)\b/g;

export function lintL8(file, rel, text, allowed = SIM_READS) {
  if (!/^src\/(?:presentation|ui)\//.test(rel)) return [];
  const reads = codeLines(text).flatMap((line) =>
    (line.raw.replace(tickGuard, "").match(tickRead) ?? []).map(() => line),
  );
  const listed = allowed[rel]?.sites ?? 0;
  if (reads.length === listed) return [];
  if (reads.length === 0)
    return [
      finding(
        "L8",
        file,
        1,
        "SIM_READS lists a file with no tick read of the ball left: remove the entry",
      ),
    ];
  const message =
    listed === 0
      ? "drawing code reads the ball's place at the physics tick (ball_position(), or the body's global_position); read shown_position(), where the ball is drawn this frame"
      : `${reads.length} tick reads of the ball, SIM_READS lists ${listed}; a new read takes shown_position()`;
  return reads.map((line) => finding("L8", file, line.number, message));
}

const ownPlace =
  /(?<![\w.])(?:\w+\s*\.\s*)*_?player\s*\.\s*(?:global_position|global_transform|position)\b/;
const placeGuard = /has_method\(\s*["'](?:ball_position|shown_position)["']\s*\)/;

export function lintL9(file, text) {
  return codeLines(text)
    .filter((line) => ownPlace.test(line.raw) && !placeGuard.test(line.raw))
    .map((line) =>
      finding(
        "L9",
        file,
        line.number,
        "the player node never leaves the origin: ask ball_position() for a rule or shown_position() for a picture, not the node's own place",
      ),
    );
}

export const HAND_MOVED = {
  "src/combat/kest_kit.gd": {
    sites: 1,
    why: "an ultimate's flight leg ends exactly on its mark and the next leg leaves from there with the kit, the chain and the speed intact, which a reset would clear",
  },
};

const handMove =
  /\b(?:(?:active_|_ball_)?body\(\)|_rigid)\s*\.\s*(?:(?:global_)?(?:position|transform)\b(?:\s*\.\s*\w+)*\s*[-+*\/]?=(?!=)|(?:set_(?:global_)?(?:position|transform)|global_translate|translate)\s*\()/g;

export function lintL10(file, rel, text, allowed = HAND_MOVED) {
  const writes = codeLines(text).flatMap((line) =>
    (line.raw.match(handMove) ?? []).map(() => line),
  );
  const listed = allowed[rel]?.sites ?? 0;
  if (writes.length === listed) return [];
  if (writes.length === 0)
    return [
      finding(
        "L10",
        file,
        1,
        "HAND_MOVED lists a file that no longer moves the ball's body by hand: remove the entry",
      ),
    ];
  const message =
    listed === 0
      ? "the ball's body is moved by hand: PlayerBall.reset_to(point, velocity) places it in one call and it reads at the new spot at once"
      : `${writes.length} writes to the ball's body, HAND_MOVED lists ${listed}; a placement takes reset_to(point, velocity)`;
  return writes.map((line) => finding("L10", file, line.number, message));
}

export const ID_COMPARE_OWNERS = new Set([
  "src/core/class_def.gd",
  "src/core/park_defs.gd",
  "src/core/alpha_defs.gd",
  "src/core/stage_defs.gd",
  "src/core/slice_defs.gd",
]);

export const CANONICAL_IDS = [
  "park_dam",
  "park_flume",
  "park_pit",
  "park_sinkhole",
  "park_islands",
  "park_crown",
  "spillway",
  "reach",
  "dig",
  "dig_deep",
  "highdraft",
  "highdraft_crown",
  "pylon_engineer",
  "runner_gunner",
  "demolitions_caster",
  "tarn",
  "tally",
  "remembered_cannon",
  "line_splicer",
];

export const ID_COMPARE_LEGACY = {
  "src/boss/mind.gd": { sites: 1, why: "pre-MG-16 pilot branch" },
  "src/combat/combat.gd": { sites: 8, why: "pre-MG-16 pilot branches" },
  "src/combat/kest_kit.gd": { sites: 1, why: "pre-MG-16 pilot branch" },
  "src/combat/rivet_kit.gd": { sites: 1, why: "pre-MG-16 pilot branch" },
  "src/combat/tarn_claw.gd": { sites: 1, why: "pre-MG-16 pilot branch" },
  "src/core/pilot_story.gd": { sites: 7, why: "pre-MG-16 pilot story branches" },
  "src/game.gd": { sites: 1, why: "pre-MG-16 pilot check" },
  "src/movement/player_ball.gd": { sites: 4, why: "pre-MG-16 pilot/map branches" },
  "src/presentation/audio.gd": { sites: 1, why: "pre-MG-16 park prefix check" },
  "src/presentation/dig_scenery.gd": { sites: 3, why: "pre-MG-16 dig map checks" },
  "src/presentation/grapple_rig.gd": { sites: 2, why: "pre-MG-16 pilot match arms" },
  "src/presentation/hero_assets.gd": { sites: 1, why: "pre-MG-16 pilot check" },
  "src/presentation/park_props.gd": { sites: 1, why: "pre-MG-16 park prefix check" },
  "src/presentation/pilot_antics.gd": { sites: 6, why: "pre-MG-16 pilot match arms" },
  "src/presentation/player_fx.gd": { sites: 1, why: "pre-MG-16 pilot check" },
  "src/presentation/quiet_gun.gd": { sites: 1, why: "pre-MG-16 pilot check" },
  "src/presentation/sfx_bank.gd": { sites: 3, why: "pre-MG-16 map check and pilot match arms" },
  "src/presentation/world_look.gd": { sites: 1, why: "pre-MG-16 park prefix check" },
  "src/ui/class_preview.gd": { sites: 10, why: "pre-MG-16 pilot match arms" },
  "src/ui/ending_sequence.gd": {
    sites: 7,
    why: "pre-MG-16 pilot ending branches and park prefix checks",
  },
  "src/world/director.gd": { sites: 2, why: "pre-MG-16 park prefix checks" },
  "src/world/terrain.gd": { sites: 2, why: "pre-MG-16 park prefix checks" },
};

export const ID_FAMILY_PREFIXES = ["park_"];

const idAlternation = CANONICAL_IDS.join("|");
const idLiteral = `(?:&|StringName\\(\\s*)?["'](?:${idAlternation})["']`;
const rawIdCompare = new RegExp(
  `(?:==|!=)\\s*${idLiteral}|${idLiteral}\\s*\\)?\\s*(?:==|!=)|\\bin\\s*\\[[^\\]]*${idLiteral}`,
);
const rawIdPrefix = new RegExp(
  `\\.begins_with\\(\\s*&?["'](?:${[...CANONICAL_IDS, ...ID_FAMILY_PREFIXES].join("|")})["']\\s*\\)`,
);
const rawIdPattern = new RegExp(idLiteral);
const matchOpen = /^match\s.+:\s*(?:#.*)?$/;

function armPatterns(code) {
  let quote = null;
  let depth = 0;
  for (let i = 0; i < code.length; i++) {
    const ch = code[i];
    if (quote) {
      if (ch === "\\") i++;
      else if (ch === quote) quote = null;
    } else if (ch === '"' || ch === "'") quote = ch;
    else if (ch === "#") return null;
    else if ("([{".includes(ch)) depth++;
    else if (")]}".includes(ch)) depth--;
    else if (ch === ":" && depth === 0) return code.slice(0, i);
  }
  return null;
}

export function idMatchArms(text) {
  const arms = new Set();
  const open = [];
  for (const line of codeLines(text)) {
    if (line.code === "") continue;
    const indent = line.raw.length - line.raw.trimStart().length;
    while (open.length > 0 && indent <= open.at(-1).indent) open.pop();
    const block = open.at(-1);
    if (block) {
      block.arm ??= indent;
      const patterns = indent === block.arm ? armPatterns(line.code) : null;
      if (patterns !== null && rawIdPattern.test(patterns)) arms.add(line.number);
    }
    if (matchOpen.test(line.code)) open.push({ indent, arm: null });
  }
  return arms;
}

export function lintL11(file, rel, text, allowed = ID_COMPARE_LEGACY, owners = ID_COMPARE_OWNERS) {
  if (owners.has(rel) || rel.startsWith("src/dev/")) return [];
  const arms = idMatchArms(text);
  const sites = codeLines(text).filter(
    (line) => rawIdCompare.test(line.raw) || rawIdPrefix.test(line.raw) || arms.has(line.number),
  );
  const listed = allowed[rel]?.sites ?? 0;
  if (sites.length === listed) return [];
  if (sites.length === 0) {
    return [
      finding(
        "L11",
        file,
        1,
        "ID_COMPARE_LEGACY lists a file with no raw map/pilot ID comparison left: remove the entry",
      ),
    ];
  }
  const message =
    listed === 0
      ? "raw map or pilot ID branch (string or StringName compare, match arm, or begins_with) outside owning table (MG-16); query the owning def/capability instead of branching on ID strings"
      : `${sites.length} raw map/pilot ID branches, ID_COMPARE_LEGACY lists ${listed}; move branching to owning table fields (MG-16)`;
  return sites.map((line) => finding("L11", file, line.number, message));
}

export function applyBaseline(findings, baseline, exists) {
  const kept = [];
  const offending = new Map();
  const words = new Map();
  for (const item of findings) {
    if (WORD_RULES.includes(item.rule)) {
      const key = `${item.rule} ${item.path}`;
      if (!words.has(key)) words.set(key, []);
      words.get(key).push(item);
      continue;
    }
    const listed = baseline[item.rule] ?? [];
    if (BASELINED_RULES.includes(item.rule) && listed.includes(item.path)) {
      offending.set(`${item.rule} ${item.path}`, true);
    } else {
      kept.push(item);
    }
  }
  for (const rule of BASELINED_RULES) {
    for (const file of baseline[rule] ?? []) {
      if (offending.has(`${rule} ${file}`)) continue;
      kept.push(
        finding(
          "BASELINE",
          file,
          1,
          `${rule} no longer offends${exists(file) ? "" : " (file is gone)"}: remove from baseline`,
        ),
      );
    }
  }
  for (const rule of WORD_RULES) {
    const listed = baseline[rule] ?? {};
    for (const [key, items] of words) {
      if (!key.startsWith(`${rule} `)) continue;
      const allowed = listed[items[0].path] ?? 0;
      if (items.length > allowed) {
        kept.push(
          ...items.map((item) => ({
            ...item,
            message: `${item.message}${allowed > 0 ? ` (${items.length} in this file, baseline ${allowed})` : ""}`,
          })),
        );
      }
    }
    for (const [file, allowed] of Object.entries(listed)) {
      const now = words.get(`${rule} ${file}`)?.length ?? 0;
      if (now === 0)
        kept.push(
          finding(
            "BASELINE",
            file,
            1,
            `${rule} no longer offends${exists(file) ? "" : " (file is gone)"}: remove from baseline`,
          ),
        );
      else if (now < allowed)
        kept.push(
          finding(
            "BASELINE",
            file,
            1,
            `${rule} fell to ${now} from ${allowed}: lower the baseline to ${now}`,
          ),
        );
    }
  }
  return kept;
}

export function baselineFrom(findings) {
  const baseline = {};
  for (const rule of BASELINED_RULES) {
    baseline[rule] = [
      ...new Set(findings.filter((item) => item.rule === rule).map((item) => item.path)),
    ].sort();
  }
  for (const rule of WORD_RULES) {
    const counts = {};
    for (const item of findings.filter((entry) => entry.rule === rule))
      counts[item.path] = (counts[item.path] ?? 0) + 1;
    baseline[rule] = Object.fromEntries(
      Object.entries(counts).sort(([a], [b]) => a.localeCompare(b)),
    );
  }
  return baseline;
}

export function parseLintArgs(argv) {
  const options = { sketch: null, writeBaseline: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--sketch" && argv[i + 1]) options.sketch = argv[++i];
    else if (argv[i] === "--write-baseline") options.writeBaseline = true;
  }
  return options;
}

export const FAULT_SWITCHES = {
  _reel_plant: {
    home: "src/boss/boss.gd",
    why: "brindle_reel_test stops or unbraces the reel to prove each guard holds the fight",
  },
  lead_plant: {
    home: "src/combat/pack_pressure.gd",
    why: "boss_lead_line_test leads every ball or none to prove the lead rule is what spares a turning ball",
  },
  test_pad_scale: {
    home: "src/combat/warning_bound.gd",
    why: "warning_bound_containment_test shrinks a ground pad to watch the containment check fail",
  },
  test_skip_hazard_merge: {
    home: "src/combat/warning_bound.gd",
    why: "warning_bound_park_ground_test skips the merge to prove it is what holds hazards on real ground",
  },
  _test_pending: {
    home: "src/core/cosmetics.gd",
    why: "the customize tests name extra pending art to reach the pending paths while the list is empty",
  },
  test_no_warn: {
    home: "src/world/contraptions.gd",
    why: "works_surge_test fires a surge with no warning to fail the warning predicate",
  },
  plant_ignore_lines: {
    home: "src/world/park/footings.gd",
    why: "park_flume_piers_test casts a sole on a ridden line to prove the footing check sees it",
  },
  keep_one_placement: {
    home: "src/combat/terrain_faces.gd",
    why: "rivet_warm_hitch_test restores the old one-build keying to prove the warm-up hitch fix",
  },
};

const collectionWrite =
  "append|append_array|push_back|push_front|insert|erase|clear|assign|resize|merge|fill|pop_back|pop_front|pop_at|remove_at|sort|reverse|shuffle";
const faultReset = /^(?:static\s+)?func\s+reset_for_tests\s*\(/;
const topLevel = /^(?:static\s+)?(?:func|var|const|class|signal|enum)\b|^@/;

const faultSubscript = "(?:\\s*\\[(?:[^\\[\\]]|\\[[^\\[\\]]*\\])*\\])*";

function faultWrite(name) {
  return new RegExp(
    `(?<!\\w)${name}\\b${faultSubscript}\\s*(?:[-+*/%]?=(?!=)|\\.\\s*(?:${collectionWrite})\\s*\\()|\\bset(?:_deferred|_indexed)?\\(\\s*&?["']${name}["']`,
  );
}

export function lintL12(file, rel, text, switches = FAULT_SWITCHES) {
  const out = [];
  let resetting = false;
  const names = Object.keys(switches);
  for (const line of codeLines(text)) {
    if (line.raw.length > 0 && !/^\s/.test(line.raw) && topLevel.test(line.raw))
      resetting = faultReset.test(line.raw);
    for (const name of names) {
      if (!faultWrite(name).test(line.raw)) continue;
      if (resetting && switches[name].home === rel) continue;
      out.push(
        finding(
          "L12",
          file,
          line.number,
          `game code writes the fault switch ${name}; only a test or a tool may set it, and ${switches[name].home} clears it in reset_for_tests()`,
        ),
      );
    }
  }
  for (const name of names) {
    if (switches[name].home !== rel) continue;
    const declared = new RegExp(`^(?:static\\s+)?var\\s+${name}\\b`, "m");
    if (!declared.test(text))
      out.push(
        finding(
          "L12",
          file,
          1,
          `FAULT_SWITCHES lists ${name}, which this file no longer declares: remove the entry`,
        ),
      );
  }
  return out;
}

function walk(directory, base = directory) {
  const entries = [];
  if (!existsSync(directory)) return entries;
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    entries.push({
      rel: path.relative(base, full).split(path.sep).join("/"),
      dir: entry.isDirectory(),
      full,
    });
    if (entry.isDirectory()) entries.push(...walk(full, base));
  }
  return entries;
}

function sources(directory, extensions) {
  return walk(directory)
    .filter((entry) => !entry.dir && extensions.has(path.extname(entry.rel)))
    .map((entry) => ({
      path: path.relative(root, entry.full).split(path.sep).join("/"),
      text: readFileSync(entry.full, "utf8"),
    }));
}

export function lintSketch(sketch) {
  const directory = path.join(root, "sketches", sketch);
  const relative = `sketches/${sketch}`;
  const tuning = parseTuning(
    readFileSync(path.join(directory, "src", "movement", "tuning.gd"), "utf8"),
  );
  const findings = [];
  const testFiles = sources(path.join(directory, "tests"), new Set([".gd"]));
  for (const file of testFiles) findings.push(...lintL1(file.path, file.text));
  const lit = new Set();
  for (const file of sources(path.join(directory, "src"), new Set([".gd"]))) {
    if (file.path !== `${relative}/src/core/safe_store.gd`)
      findings.push(...lintL2(file.path, file.text));
    findings.push(...lintL7(file.path, file.text));
    if (sketch !== "core-loop") continue;
    const rel = file.path.slice(relative.length + 1);
    if (codeLines(file.text).some((line) => lightNew.test(line.raw))) lit.add(rel);
    findings.push(...lintL6(file.path, rel, file.text));
    findings.push(...lintL8(file.path, rel, file.text));
    findings.push(...lintL9(file.path, file.text));
    findings.push(...lintL10(file.path, rel, file.text));
    findings.push(...lintL11(file.path, rel, file.text));
    findings.push(...lintL12(file.path, rel, file.text));
  }
  if (sketch === "core-loop") findings.push(...lintL6Owners(lit, relative));
  if (sketch === "core-loop") {
    const words = lintWords({
      sketchDir: directory,
      prefix: relative,
      names: readFileSync(path.join(directory, "design-v3", "NAMES.md"), "utf8"),
      bindings: readFileSync(path.join(directory, "src", "core", "bindings.gd"), "utf8"),
    });
    findings.push(...words.findings);
    findings.words = { read: words.read, total: words.total };
  }
  const lintSelf = new Set(["scripts/sketch-lint.mjs", "scripts/sketch-lint.test.mjs"]);
  const flagFiles = [
    ...testFiles,
    ...sources(path.join(directory, "tools"), SOURCE_EXTENSIONS),
    ...sources(path.join(root, "scripts"), SOURCE_EXTENSIONS).filter(
      (file) => !lintSelf.has(file.path) && launchesGame.test(file.text),
    ),
  ];
  findings.push(...lintL3(flagFiles, tuning));
  const tests = walk(path.join(directory, "tests"));
  findings.push(...lintL4(tests, `${relative}/tests`));
  const quarantine = path.join(directory, "tests", "QUARANTINE.tsv");
  if (existsSync(quarantine)) {
    const names = new Set(
      tests
        .filter((entry) => !entry.dir && /^[^/]+\.gd$/.test(entry.rel))
        .map((entry) => entry.rel.replace(/\.gd$/, "")),
    );
    findings.push(
      ...lintL5(readFileSync(quarantine, "utf8"), names, `${relative}/tests/QUARANTINE.tsv`),
    );
  }
  return findings;
}

function main() {
  const options = parseLintArgs(process.argv.slice(2));
  if (
    !options.sketch ||
    !existsSync(path.join(root, "sketches", options.sketch, "project.godot"))
  ) {
    console.error("sketch-lint: pass --sketch NAME for a folder under sketches/");
    process.exit(2);
  }
  const started = Date.now();
  const raw = lintSketch(options.sketch);
  if (options.writeBaseline) {
    const baseline = baselineFrom(raw);
    writeFileSync(BASELINE_FILE, JSON.stringify(baseline, null, 2) + "\n");
    for (const rule of BASELINED_RULES)
      console.log(`${rule} ${baseline[rule].length} baseline paths`);
    for (const rule of WORD_RULES)
      console.log(
        `${rule} ${Object.values(baseline[rule]).reduce((a, b) => a + b, 0)} baseline offences in ${Object.keys(baseline[rule]).length} files`,
      );
    return;
  }
  const baseline = existsSync(BASELINE_FILE) ? JSON.parse(readFileSync(BASELINE_FILE, "utf8")) : {};
  const findings = applyBaseline(
    raw,
    baseline,
    (file) => existsSync(path.join(root, file)) && statSync(path.join(root, file)).isFile(),
  );
  for (const item of findings) console.log(formatFinding(item));
  if (options.sketch === "core-loop") {
    for (const [rel, entry] of Object.entries(LIGHT_OWNERS).filter(([, entry]) => entry.open)) {
      console.log(`L6 open: sketches/core-loop/${rel} ${entry.sites} sites, ${entry.owner}`);
    }
  }
  if (raw.words) {
    for (const entry of raw.words.read)
      console.log(`words read ${String(entry.count).padStart(4)} ${entry.source}`);
    const byRule = WORD_RULES.map(
      (rule) => `${rule}=${raw.filter((item) => item.rule === rule).length}`,
    ).join(" ");
    console.log(
      `words: ${raw.words.total} player strings read; offences before baseline ${byRule}`,
    );
  }
  const wordBaseline = WORD_RULES.map(
    (rule) => `${rule}=${Object.values(baseline[rule] ?? {}).reduce((a, b) => a + b, 0)}`,
  ).join(" ");
  const baselined = `${BASELINED_RULES.map((rule) => `${rule}=${(baseline[rule] ?? []).length}`).join(" ")} ${wordBaseline}`;
  console.log(
    `sketch-lint ${findings.length === 0 ? "pass" : "fail"}: ${findings.length} findings, baseline entries ${baselined}, ${Date.now() - started}ms`,
  );
  process.exit(findings.length === 0 ? 0 : 1);
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) main();
