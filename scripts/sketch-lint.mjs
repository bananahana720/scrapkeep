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
const BASELINED_RULES = ["L1", "L2", "L3", "L4", "L16"];
const MAX_QUARANTINE = 0;
const QUARANTINE_HEADER = "test\towner\treason\tadded\tdeadline";
const TEST_FOLDERS = new Set(["unit", "support", "doubles", "fixtures", "trees", "workshop"]);
const launchesGame = /SMOKE_FLAGS|--flags|tuning\.gd/;
const SOURCE_EXTENSIONS = new Set([".gd", ".mjs", ".js", ".sh", ".py"]);

const finding = (rule, file, line, message) => ({ rule, path: file, line, message });

export function formatFinding(item) {
  return `${item.rule} ${item.path}:${item.line} ${item.message}`;
}

const codeLinesCache = new Map();

function codeLines(text) {
  let cached = codeLinesCache.get(text);
  if (cached) return cached;
  cached = text
    .split("\n")
    .map((raw, index) => ({ raw, number: index + 1, code: raw.trim() }))
    .filter((line) => !line.code.startsWith("#") && !line.code.startsWith("//"));
  if (codeLinesCache.size > 4096) codeLinesCache.clear();
  codeLinesCache.set(text, cached);
  return cached;
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
    if (!file.text.includes("--")) continue;
    for (const line of codeLines(file.text)) {
      if (!line.raw.includes("--")) continue;
      for (const match of line.raw.matchAll(parsedFlag)) parsed.add(match[1]);
    }
  }
  const ownedCache = new Map();
  const owned = (name) => {
    if (parsed.has(name)) return true;
    let found = ownedCache.get(name);
    if (found === undefined) {
      const needle = `"${name}"`;
      found = files.some((other) => other.text.includes(needle));
      ownedCache.set(name, found);
    }
    return found;
  };
  const findings = [];
  for (const file of files) {
    const hasDash = file.text.includes("--");
    const hasParen = file.text.includes("(");
    if (!hasDash && !hasParen) continue;
    for (const line of codeLines(file.text)) {
      if (hasDash && line.raw.includes("--")) {
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
      }
      if (hasParen && line.raw.includes("(")) {
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
    findings.push(
      finding(
        "L5",
        file,
        1,
        `${entries.length} entries; QUARANTINE.tsv is retired (max ${MAX_QUARANTINE}), use KNOWN-FAILING.tsv`,
      ),
    );
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

const faultWriteCache = new Map();

function faultWrite(name) {
  let re = faultWriteCache.get(name);
  if (!re) {
    re = new RegExp(
      `(?<!\\w)${name}\\b${faultSubscript}\\s*(?:[-+*/%]?=(?!=)|\\.\\s*(?:${collectionWrite})\\s*\\()|\\bset(?:_deferred|_indexed)?\\(\\s*&?["']${name}["']`,
    );
    faultWriteCache.set(name, re);
  }
  return re;
}

export function lintL12(file, rel, text, switches = FAULT_SWITCHES) {
  const out = [];
  const names = Object.keys(switches);
  const activeNames = names.filter((name) => text.includes(name));
  if (activeNames.length > 0) {
    let resetting = false;
    for (const line of codeLines(text)) {
      if (line.raw.length > 0 && !/^\s/.test(line.raw) && topLevel.test(line.raw))
        resetting = faultReset.test(line.raw);
      for (const name of activeNames) {
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

const displayNameRead = /\bDisplayServer\s*\.\s*get_name\s*\(/;

export function lintL13(file, rel, text) {
  if (rel === "src/core/app_shell.gd" || !text.includes("DisplayServer")) return [];
  return codeLines(text)
    .filter((line) => displayNameRead.test(line.raw))
    .map((line) =>
      finding(
        "L13",
        file,
        line.number,
        "raw DisplayServer.get_name() read; call AppShell.headless() (src/core/app_shell.gd) instead",
      ),
    );
}

export const L14_STATIC_VAR_BASELINE = new Set([
  "src/boss/arena.gd:_ahead_bowl",
  "src/boss/arena.gd:_looks_warm",
  "src/boss/boss.gd:_pickup_materials",
  "src/boss/boss.gd:_pickup_mesh",
  "src/boss/requisition.gd:_ahead",
  "src/boss/requisition.gd:_ahead_reads",
  "src/boss/requisition.gd:_dressing",
  "src/build/accretion.gd:_layout",
  "src/build/accretion.gd:_part_meshes",
  "src/build/panel_shell.gd:_meshes",
  "src/build/panel_shell.gd:_sockets",
  "src/build/parts.gd:_all_rows",
  "src/build/parts.gd:_answering_by_class",
  "src/build/parts.gd:_defs",
  "src/build/parts.gd:_maker_of",
  "src/build/parts.gd:_rows",
  "src/combat/anchor_crew.gd:_shared",
  "src/combat/anchor_crew.gd:_warned_asset",
  "src/combat/ballast_heavy.gd:_shared",
  "src/combat/bola_thrower.gd:_shared",
  "src/combat/bola_thrower.gd:_warned_asset",
  "src/combat/bolts.gd:_outline_shader",
  "src/combat/boom_tender.gd:_shared",
  "src/combat/burrower.gd:_shared",
  "src/combat/catch_trap.gd:_shared",
  "src/combat/chaser.gd:_shared",
  "src/combat/chaser.gd:_warned_asset",
  "src/combat/combat.gd:_arc_mark_mesh",
  "src/combat/combat.gd:_exposure_material",
  "src/combat/combat.gd:_exposure_mesh",
  "src/combat/combat.gd:_ink_mesh",
  "src/combat/deflector.gd:_shared",
  "src/combat/deflector.gd:_warned_asset",
  "src/combat/dispatcher.gd:_asset_warned",
  "src/combat/dispatcher.gd:_body_shape",
  "src/combat/dispatcher.gd:_column_shapes",
  "src/combat/dispatcher.gd:_deck_shape",
  "src/combat/dispatcher.gd:_mast_charcoal",
  "src/combat/dispatcher.gd:_mast_meshes",
  "src/combat/dispatcher.gd:_mast_rust",
  "src/combat/dispatcher.gd:_model_checked",
  "src/combat/dispatcher.gd:_packed_model",
  "src/combat/dispatcher.gd:_pod_mat",
  "src/combat/dispatcher.gd:_pod_mesh",
  "src/combat/dispatcher.gd:_shared",
  "src/combat/dispatcher.gd:_sockets",
  "src/combat/dispatcher.gd:_special_cues",
  "src/combat/dispatcher.gd:_special_cues_checked",
  "src/combat/dispatcher.gd:_warmed",
  "src/combat/drill_crew.gd:_shared",
  "src/combat/drill_crew.gd:_warned_asset",
  "src/combat/enemy.gd:_attack_serial",
  "src/combat/enemy.gd:_frame_mask",
  "src/combat/enemy.gd:_plate_shaders",
  "src/combat/enemy.gd:_ring_out_kept",
  "src/combat/enemy.gd:_variables_by_script",
  "src/combat/enemy_casting.gd:_warned",
  "src/combat/foreman.gd:_asset_warned",
  "src/combat/foreman.gd:_shared",
  "src/combat/foreman.gd:_sockets",
  "src/combat/foreman.gd:_sync_ring_material",
  "src/combat/foreman.gd:_sync_ring_mesh",
  "src/combat/gap_net.gd:_shared",
  "src/combat/gyro_jammer.gd:_shared",
  "src/combat/hooker.gd:_shared",
  "src/combat/hooker.gd:_warned_asset",
  "src/combat/jolt_layer.gd:_shared",
  "src/combat/kite_drone.gd:_shared",
  "src/combat/kite_drone.gd:_warned_asset",
  "src/combat/lamp_swarm.gd:_painted",
  "src/combat/lamp_swarm.gd:_shared",
  "src/combat/lamp_swarm.gd:_warned_asset",
  "src/combat/line_cutter.gd:_shared",
  "src/combat/lobber.gd:_shared",
  "src/combat/lobber.gd:_warned_asset",
  "src/combat/mag_trapper.gd:_shared",
  "src/combat/mag_trapper.gd:_warned_asset",
  "src/combat/mind_hand.gd:_rim_masks",
  "src/combat/mind_hand.gd:_warned_models",
  "src/combat/miniboss.gd:_asset_warned",
  "src/combat/miniboss.gd:_hazard_stripe",
  "src/combat/miniboss.gd:_shared",
  "src/combat/monster_heft.gd:_doc",
  "src/combat/netcaster.gd:_net_shader",
  "src/combat/netcaster.gd:_shared",
  "src/combat/netcaster.gd:_warned_asset",
  "src/combat/pit_jaw.gd:_shared",
  "src/combat/plated_brute.gd:_mask",
  "src/combat/plated_brute.gd:_shared",
  "src/combat/plated_brute.gd:_warned_asset",
  "src/combat/projectile.gd:_rim_quad",
  "src/combat/projectile.gd:_shell_material",
  "src/combat/projectile.gd:_shell_mesh",
  "src/combat/prop_crew.gd:_shared",
  "src/combat/ramp_flipper.gd:_shared",
  "src/combat/ramp_flipper.gd:_warned_asset",
  "src/combat/reactor_relic.gd:_shared",
  "src/combat/reactor_relic.gd:_warned_asset",
  "src/combat/rivet_kit.gd:_cap_unit",
  "src/combat/rivet_kit.gd:_convex_cache",
  "src/combat/rivet_kit.gd:_convex_lock",
  "src/combat/rivet_kit.gd:_convex_searching",
  "src/combat/rivet_kit.gd:_strip_unit",
  "src/combat/rivet_kit.gd:convex_searches",
  "src/combat/rivet_kit.gd:convex_searches_on_main",
  "src/combat/rogue.gd:_model_warned",
  "src/combat/roster.gd:ROWS",
  "src/combat/roster.gd:SPECIALS",
  "src/combat/roster_dig.gd:_shared_capsule",
  "src/combat/splitter.gd:_parts",
  "src/combat/swarm_remnant.gd:_asset_warned",
  "src/combat/swarm_remnant.gd:_hazard_stripe",
  "src/combat/swarm_remnant.gd:_shared",
  "src/combat/swatter.gd:_shared",
  "src/combat/swatter.gd:_warned_asset",
  "src/combat/threat_grammar.gd:_stripes",
  "src/combat/vault.gd:_asset_warned",
  "src/combat/vault.gd:_shared",
  "src/combat/warden.gd:_drivers_requested",
  "src/combat/warden.gd:warned_variants",
  "src/combat/warden_look.gd:_seam_shader",
  "src/combat/warden_reactor.gd:_line_reference",
  "src/combat/warden_reactor.gd:_sheet_shader",
  "src/combat/winch_drone.gd:_shared",
  "src/combat/winch_drone.gd:_warned_asset",
  "src/core/ability_state.gd:KEYS",
  "src/core/beacon.gd:_packed_models",
  "src/core/beacon.gd:_roster_dig",
  "src/core/beacon.gd:_shared_lantern_bulb",
  "src/core/beacon.gd:_shared_mast_bulb",
  "src/core/beacon.gd:_shared_mast_cyl",
  "src/core/beacon.gd:_shared_mast_mat",
  "src/core/beacon.gd:_shared_torus",
  "src/core/beacon.gd:_slot_materials",
  "src/core/build_stamp.gd:_stamp",
  "src/core/content_registry.gd:_pass",
  "src/core/content_registry.gd:_pass_depth",
  "src/core/palette.gd:_checkers",
  "src/core/palette.gd:_grain_normal",
  "src/core/palette.gd:_grain_rough",
  "src/core/palette.gd:_grime",
  "src/core/palette.gd:_look_textures",
  "src/core/palette.gd:_oxide",
  "src/core/palette.gd:_painted_textures",
  "src/core/palette.gd:_slot_materials",
  "src/core/palette.gd:_wear",
  "src/core/radio_takes.gd:_doc",
  "src/core/shift_variants.gd:_forced",
  "src/core/thread_guard.gd:_lock",
  "src/core/trees/cannon.gd:NODES_WORLD_ONE",
  "src/core/trees/kest.gd:NODES_WORLD_ONE",
  "src/core/trees/rivet.gd:NODES_WORLD_ONE",
  "src/core/trees/sable.gd:NODES_WORLD_ONE",
  "src/core/trees/tally.gd:NODES_WORLD_ONE",
  "src/core/trees/tarn.gd:NODES_WORLD_ONE",
  "src/presentation/ace_sequencer.gd:_kept",
  "src/presentation/ace_sequencer.gd:_kept_lock",
  "src/presentation/ace_sequencer.gd:_kept_order",
  "src/presentation/ambient_life.gd:_painted",
  "src/presentation/arena_bowl_dress.gd:_ahead",
  "src/presentation/arena_bowl_dress.gd:_reading",
  "src/presentation/arena_bowl_dress.gd:_requested",
  "src/presentation/arena_mind_dress.gd:_kit_ahead",
  "src/presentation/arena_mind_dress.gd:_panorama_out",
  "src/presentation/arena_mind_dress.gd:_panorama_task",
  "src/presentation/audio.gd:_cannon_streams",
  "src/presentation/bake_look.gd:_lift",
  "src/presentation/bake_look.gd:_ramp",
  "src/presentation/bake_look.gd:_twins",
  "src/presentation/bake_warm.gd:_firsts_done",
  "src/presentation/bake_warm.gd:_glows",
  "src/presentation/bake_warm.gd:_held",
  "src/presentation/bake_warm.gd:_kept",
  "src/presentation/bake_warm.gd:_loading",
  "src/presentation/bake_warm.gd:_stood",
  "src/presentation/bake_warm.gd:_warm",
  "src/presentation/ball_looks.gd:CUTAWAY_SHADER",
  "src/presentation/ball_looks.gd:_canopy_material",
  "src/presentation/ball_looks.gd:_enamels",
  "src/presentation/ball_looks.gd:_inside",
  "src/presentation/ball_looks.gd:_platings",
  "src/presentation/ball_looks.gd:_shaders",
  "src/presentation/codex_style.gd:_icons",
  "src/presentation/companion_body.gd:_painted_materials",
  "src/presentation/companion_body.gd:_warned_empty_mesh",
  "src/presentation/craft/craft_lookdev.gd:_cache",
  "src/presentation/craft/craft_lookdev.gd:_unmasked_cache",
  "src/presentation/crafted_ball_gear.gd:_mesh_cache",
  "src/presentation/crew_lamp_field.gd:_lens",
  "src/presentation/deck_fx.gd:_cache",
  "src/presentation/deck_fx.gd:_notch_sos",
  "src/presentation/deck_fx.gd:_snare_bp_sos",
  "src/presentation/deck_fx.gd:_viking_click_hp_sos",
  "src/presentation/density.gd:_live",
  "src/presentation/density.gd:last_published",
  "src/presentation/enemy_clips.gd:_libraries",
  "src/presentation/enemy_motion.gd:_enemy_script",
  "src/presentation/enemy_motion.gd:_live_tags",
  "src/presentation/enemy_motion.gd:_tag_material",
  "src/presentation/enemy_motion.gd:_tag_mesh",
  "src/presentation/enemy_motion.gd:motion_scale",
  "src/presentation/flourish_player.gd:reduced_motion",
  "src/presentation/foley_audio.gd:_streams",
  "src/presentation/fx_library.gd:_meshes",
  "src/presentation/fx_library.gd:_shaders",
  "src/presentation/graphics_preset.gd:_target_server_active",
  "src/presentation/harpoon_physics_rig.gd:_body_mesh",
  "src/presentation/harpoon_physics_rig.gd:_cable_ink_mat",
  "src/presentation/harpoon_physics_rig.gd:_core_mesh",
  "src/presentation/harpoon_physics_rig.gd:_ink_mat",
  "src/presentation/harpoon_physics_rig.gd:_jaw_mesh",
  "src/presentation/harpoon_physics_rig.gd:_metal_mat",
  "src/presentation/harpoon_physics_rig.gd:_spool_mat",
  "src/presentation/harpoon_physics_rig.gd:_spool_mesh",
  "src/presentation/highdraft_finishes.gd:_pieces",
  "src/presentation/highdraft_finishes.gd:_warned_aerial",
  "src/presentation/highdraft_fx.gd:MOTE_COUNTS",
  "src/presentation/highdraft_fx.gd:STREAK_COUNTS",
  "src/presentation/highdraft_fx.gd:preferred",
  "src/presentation/ink_outline.gd:_shaders",
  "src/presentation/jolt_layer_audio.gd:_streams",
  "src/presentation/landmark_proxy.gd:_materials",
  "src/presentation/music_engine.gd:_park_tasks",
  "src/presentation/music_engine.gd:_park_warm",
  "src/presentation/music_engine.gd:_park_warm_lock",
  "src/presentation/music_engine.gd:_rest_lock",
  "src/presentation/music_engine.gd:_stinger_tasks",
  "src/presentation/park_props.gd:_cache_owner",
  "src/presentation/park_props.gd:_far_sources",
  "src/presentation/park_props.gd:_material",
  "src/presentation/park_props.gd:_meshes",
  "src/presentation/park_props.gd:_requested",
  "src/presentation/park_props.gd:_stand_ins_lock",
  "src/presentation/phase_music.gd:_on_disk",
  "src/presentation/pilot_antics.gd:reduced_motion",
  "src/presentation/recipe_props.gd:_pieces",
  "src/presentation/set_dressing.gd:_broken_rock",
  "src/presentation/set_dressing.gd:_route_warned",
  "src/presentation/sfx_bank.gd:_cache_lock",
  "src/presentation/sfx_bank.gd:_file_present",
  "src/presentation/sfx_bank.gd:_lock",
  "src/presentation/sfx_bank.gd:_rendered",
  "src/presentation/sfx_bank.gd:_samples",
  "src/presentation/sfx_bank.gd:_shift",
  "src/presentation/sfx_bank.gd:_streams",
  "src/presentation/sfx_bank.gd:_theme",
  "src/presentation/sfx_bank.gd:_voice_clips",
  "src/presentation/sfx_bank.gd:_voice_tts",
  "src/presentation/sfx_bank.gd:bake_cancel",
  "src/presentation/sfx_bank.gd:unknown_callers",
  "src/presentation/site_markers.gd:_materials",
  "src/presentation/site_markers.gd:_meshes",
  "src/presentation/spillway_scenery.gd:_prop_materials",
  "src/presentation/spillway_scenery.gd:_prop_shaders",
  "src/presentation/spillway_scenery.gd:_prop_warnings",
  "src/presentation/spillway_scenery.gd:flow_scale",
  "src/presentation/synth.gd:_lock",
  "src/presentation/synth.gd:_notes",
  "src/presentation/synth.gd:score_step",
  "src/presentation/title_intro_player.gd:_finishes",
  "src/presentation/tune_moments.gd:_available",
  "src/presentation/weapon_rig_fx.gd:_mesh_cache",
  "src/presentation/work_machines.gd:_painted",
  "src/presentation/work_machines.gd:_rows",
  "src/presentation/work_machines.gd:_scenes",
  "src/presentation/world_fx/world_fx.gd:preferred",
  "src/presentation/world_fx/world_fx_cable.gd:_shader",
  "src/presentation/world_fx/world_fx_kit.gd:_materials",
  "src/presentation/world_fx/world_fx_kit.gd:reduced_motion",
  "src/presentation/world_fx/world_fx_sound.gd:_streams",
  "src/presentation/world_fx/world_fx_word.gd:_hushed",
  "src/presentation/world_fx/world_fx_word.gd:_live",
  "src/ui/ability_bar.gd:reduced_motion",
  "src/ui/aim_reticle.gd:reduced_motion",
  "src/ui/boss_plate.gd:reduced_motion",
  "src/ui/caller_tile.gd:reduced_motion",
  "src/ui/class_card.gd:reduced_motion",
  "src/ui/class_preview.gd:reduced_motion",
  "src/ui/ending_sequence.gd:_highdraft_skies",
  "src/ui/field_notes.gd:CONTROLS",
  "src/ui/icons.gd:_cache",
  "src/ui/icons.gd:_from_file",
  "src/ui/moss_bubble.gd:reduced_motion",
  "src/ui/radio_dial.gd:_fits",
  "src/ui/reward_view.gd:reduced_motion",
  "src/ui/ui_tokens.gd:reduced_motion",
  "src/ui/wordmark.gd:_texture",
  "src/world/activities.gd:_find_wet",
  "src/world/activities.gd:_interior_block",
  "src/world/activities.gd:_parts",
  "src/world/activities.gd:_shared_graphs",
  "src/world/activities.gd:_wall",
  "src/world/activity_view.gd:_shared",
  "src/world/ambush_altar.gd:_loaded",
  "src/world/ambush_altar.gd:_shared",
  "src/world/bet_crate.gd:_loaded",
  "src/world/bet_crate.gd:_shared",
  "src/world/cracked_cache.gd:_loaded",
  "src/world/cracked_cache.gd:_shared",
  "src/world/director.gd:_parks",
  "src/world/events/natural.gd:_marks_job",
  "src/world/events/natural.gd:_plans",
  "src/world/model_kit.gd:_flat",
  "src/world/model_kit.gd:_kits",
  "src/world/park/park_recipes.gd:_anchor_fit",
  "src/world/park/park_recipes.gd:_anchor_fit_lock",
  "src/world/park/park_recipes.gd:_anchor_fit_read",
  "src/world/park/park_recipes.gd:_anchor_hull_lock",
  "src/world/park/park_recipes.gd:_anchor_hulls",
  "src/world/park/park_recipes.gd:_anchor_meshes",
  "src/world/park/park_recipes.gd:_beam_roots",
  "src/world/park/park_recipes.gd:_budgets",
  "src/world/park/park_recipes.gd:_ends",
  "src/world/park/park_recipes.gd:_origins",
  "src/world/park/park_recipes.gd:_origins_lock",
  "src/world/park/park_recipes.gd:_origins_read",
  "src/world/park/park_recipes.gd:_tiles",
  "src/world/park/park_schema.gd:_registry_ids",
  "src/world/park/park_schema.gd:_registry_lock",
  "src/world/park/park_schema.gd:_registry_read",
  "src/world/park/park_terrain.gd:_patch_noise",
  "src/world/park/regions.gd:_maps",
  "src/world/radio_cache.gd:_parts",
  "src/world/rescue_site.gd:_shared",
  "src/world/rescue_site.gd:_warned",
]);

const staticVarDecl = /^static\s+var\s+([A-Za-z_]\w*)\b/;
const gdFuncDecl = /^(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(/;
const resetFuncName = /^_?reset/i;

export function parseBatchDriverRefs(text) {
  return new Set([...text.matchAll(/res:\/\/(src\/[^"']+\.gd)/g)].map((match) => match[1]));
}

export function parseBatchDriverVars(text) {
  const aliases = new Map();
  for (const match of text.matchAll(
    /\bconst\s+([A-Za-z_]\w*)\s*:?=\s*preload\(\s*"res:\/\/(src\/[^"']+\.gd)"\s*\)/g,
  )) {
    aliases.set(match[1], match[2]);
  }
  const direct = new Set();
  for (const [alias, rel] of aliases) {
    for (const match of text.matchAll(new RegExp(`\\b${alias}\\.([A-Za-z_]\\w*)\\b`, "g"))) {
      direct.add(`${rel}:${match[1]}`);
    }
  }
  return direct;
}

function resetMethodText(text) {
  let inReset = false;
  const kept = [];
  for (const raw of text.split("\n")) {
    const code = raw.replace(/#.*$/, "");
    const fn = code.match(gdFuncDecl);
    if (fn) {
      inReset = resetFuncName.test(fn[1]);
      continue;
    }
    if (/^\S/.test(code) && code.trim()) inReset = false;
    if (inReset) kept.push(code);
  }
  return kept.join("\n");
}

export function lintL14(
  file,
  rel,
  text,
  driverRefs,
  baseline = L14_STATIC_VAR_BASELINE,
  driverVars = new Set(),
) {
  if (!text.includes("static") || !/\bstatic\s+var\b/.test(text)) return [];
  const registered = driverRefs.has(rel);
  const resetBody = registered ? resetMethodText(text) : "";
  const out = [];
  for (const line of codeLines(text)) {
    const match = line.code.match(staticVarDecl);
    if (!match) continue;
    const varName = match[1];
    const key = `${rel}:${varName}`;
    if (baseline.has(key)) continue;
    const clearedInReset =
      registered &&
      (driverVars.has(key) ||
        new RegExp(`\\b${varName}\\b\\s*(?:=|\\.clear\\(|\\.erase\\()`).test(resetBody));
    if (clearedInReset) continue;
    out.push(
      finding(
        "L14",
        file,
        line.number,
        `mutable static var ${varName} is not reset per-variable: register ${rel} in sketches/core-loop/tools/test_batch_driver.gd _reset() and clear ${varName} in the script's reset method`,
      ),
    );
  }
  return out;
}

export const L15_HZ_BASELINE = {
  "tests/active_torch_test.gd": 2,
  "tests/activities_camp_test.gd": 1,
  "tests/audio_momentum_test.gd": 1,
  "tests/body_run_warning_test.gd": 5,
  "tests/bot_hands_flag_test.gd": 1,
  "tests/bot_relay_stake_test.gd": 4,
  "tests/camera_aim_rest_test.gd": 1,
  "tests/camera_glance_test.gd": 1,
  "tests/camera_tight_test.gd": 1,
  "tests/camp_ring_test.gd": 1,
  "tests/cannon_ultimate_test.gd": 1,
  "tests/cast_motion_test.gd": 1,
  "tests/combat_codex_test.gd": 1,
  "tests/companion_drivers_test.gd": 1,
  "tests/dam_gates_test.gd": 1,
  "tests/damage_numbers_test.gd": 1,
  "tests/destructibles_hooks_test.gd": 2,
  "tests/destructibles_test.gd": 1,
  "tests/device_caps_test.gd": 1,
  "tests/dig_combat_test.gd": 1,
  "tests/dig_fx_test.gd": 1,
  "tests/discovery_skill_bar_test.gd": 1,
  "tests/dress_arb_yard_test.gd": 3,
  "tests/durability_test.gd": 6,
  "tests/elite_affix_test.gd": 1,
  "tests/enemies_bughunt_test.gd": 2,
  "tests/enemy_axis_errors_test.gd": 1,
  "tests/enemy_clips_test.gd": 7,
  "tests/enemy_counters_test.gd": 1,
  "tests/enemy_gait_test.gd": 2,
  "tests/enemy_linker_test.gd": 1,
  "tests/enemy_pit_jaw_test.gd": 1,
  "tests/enemy_tenacity_test.gd": 1,
  "tests/entrance_closeup_test.gd": 1,
  "tests/field_tips_test.gd": 3,
  "tests/find_in_fight_test.gd": 1,
  "tests/grapple_muts_test.gd": 1,
  "tests/highdraft_fx_test.gd": 5,
  "tests/int_arena_standdown_test.gd": 2,
  "tests/jolt_layer_test.gd": 1,
  "tests/kest_kit_test.gd": 2,
  "tests/kest_set_piece_test.gd": 1,
  "tests/line_skill_hook_test.gd": 1,
  "tests/look_frames_test.gd": 2,
  "tests/music_params_trace_game_test.gd": 2,
  "tests/park_recipes_tunnels_test.gd": 1,
  "tests/pilot_antics_test.gd": 1,
  "tests/pocket_kinds_test.gd": 1,
  "tests/reach_secret_test.gd": 1,
  "tests/regen_rolling_test.gd": 1,
  "tests/rivet_kit_test.gd": 1,
  "tests/sable_kit_test.gd": 1,
  "tests/shot_bits_live_test.gd": 1,
  "tests/sim_elements_chains_test.gd": 1,
  "tests/skill_bar_select_test.gd": 1,
  "tests/spillway_roster_test.gd": 1,
  "tests/stand_crew_test.gd": 4,
  "tests/step5_enemy_boss_craft_test.gd": 6,
  "tests/tally_set_piece_test.gd": 1,
  "tests/tarn_claw_drag_test.gd": 1,
  "tests/telegraph_timing_swarm_test.gd": 1,
  "tests/ui_objective_board_test.gd": 1,
  "tests/ultimate_set_piece_test.gd": 1,
  "tests/w45_exploration_test.gd": 3,
  "tests/w45_neon_hardening_test.gd": 1,
  "tests/w45_plate_seat_test.gd": 1,
  "tests/w45_tarn_relics_test.gd": 1,
  "tests/w47_h1_heroes_test.gd": 1,
  "tests/w47_h2_heroes_test.gd": 1,
  "tests/w50_isaac_relics_test.gd": 1,
  "tests/wall_grip_test.gd": 4,
  "tests/weapon_cadence_test.gd": 1,
  "tests/weapon_driver_test.gd": 1,
  "tests/works_surge_test.gd": 1,
  "tests/world_one_mass_s_test.gd": 2,
  "tests/world_one_stree_test.gd": 1,
};

const physicsTestSignal = /\b(?:physics_frame|_physics_process)\b/;
const hardcoded60Hz = /\b1\.0\s*\/\s*60(?:\.0)?\b|\*\s*60\.0\b/g;

export function lintL15(file, rel, text, baseline = L15_HZ_BASELINE) {
  if (!text.includes("60") || !physicsTestSignal.test(text)) return [];
  const lines = codeLines(text);
  if (!lines.some((line) => physicsTestSignal.test(line.raw))) return [];
  const sites = lines.flatMap((line) =>
    (line.raw.replace(/#.*$/, "").match(hardcoded60Hz) ?? []).map(() => line),
  );
  const listed = baseline[rel] ?? 0;
  if (sites.length <= listed) return [];
  const message =
    listed === 0
      ? "hardcoded 60 Hz physics frame literal in a 90 Hz physics test; derive ticks from Engine.physics_ticks_per_second instead"
      : `${sites.length} hardcoded 60 Hz physics frame literals, L15_HZ_BASELINE allows ${listed}; derive ticks from Engine.physics_ticks_per_second instead`;
  return sites.map((line) => finding("L15", file, line.number, message));
}

const srcRelPattern = /(?:^|\/)(src\/.+\.gd)$/;
const classNameDecl = /^class_name\s+([A-Za-z_]\w*)\b/;

function scriptRel(filePath) {
  const match = srcRelPattern.exec(filePath);
  return match ? match[1] : filePath;
}

function scanGdLine(raw, tripleQuote) {
  const strings = [];
  let code = "";
  let i = 0;
  while (i < raw.length) {
    if (tripleQuote) {
      const end = raw.indexOf(tripleQuote, i);
      if (end === -1) return { strings, code, tripleQuote };
      i = end + 3;
      tripleQuote = null;
      continue;
    }
    const ch = raw[i];
    if (ch === "#") break;
    if ((ch === '"' || ch === "'") && raw[i + 1] === ch && raw[i + 2] === ch) {
      tripleQuote = ch + ch + ch;
      i += 3;
      continue;
    }
    if (ch === '"' || ch === "'") {
      let j = i + 1;
      while (j < raw.length) {
        if (raw[j] === "\\") {
          j += 2;
          continue;
        }
        if (raw[j] === ch) break;
        j++;
      }
      strings.push(raw.slice(i + 1, j));
      i = j + 1;
      code += " ";
      continue;
    }
    code += ch;
    i++;
  }
  return { strings, code, tripleQuote };
}

export function buildScriptGraph(files) {
  const relToPath = new Map();
  const classOwners = new Map();
  for (const file of files) {
    relToPath.set(scriptRel(file.path), file.path);
    if (!file.text.includes("class_name")) continue;
    for (const line of codeLines(file.text)) {
      const match = classNameDecl.exec(line.raw);
      if (match) {
        classOwners.set(match[1], file.path);
        break;
      }
    }
  }
  const classNames = [...classOwners.keys()];
  const classTestRe =
    classNames.length > 0 ? new RegExp(`\\b(?:${classNames.join("|")})\\b`) : null;
  const classMatchRe =
    classNames.length > 0 ? new RegExp(`\\b(?:${classNames.join("|")})\\b`, "g") : null;
  const graph = new Map();
  for (const file of files) {
    const deps = new Set();
    const hasRes = file.text.includes("res://src/");
    const hasClass = classTestRe !== null && classTestRe.test(file.text);
    if (hasRes || hasClass) {
      const hasTriple = file.text.includes('"""') || file.text.includes("'''");
      let tripleQuote = null;
      for (const line of codeLines(file.text)) {
        if (!hasTriple) {
          const lineHasRes = hasRes && line.raw.includes("res://src/");
          const lineHasClass = hasClass && classTestRe.test(line.raw);
          if (!lineHasRes && !lineHasClass) continue;
        }
        const scanned = scanGdLine(line.raw, tripleQuote);
        tripleQuote = scanned.tripleQuote;
        if (hasRes) {
          for (const literal of scanned.strings) {
            if (!literal.startsWith("res://src/") || !literal.endsWith(".gd")) continue;
            const target = relToPath.get(literal.slice(6));
            if (target && target !== file.path) deps.add(target);
          }
        }
        if (hasClass && scanned.code) {
          for (const match of scanned.code.matchAll(classMatchRe)) {
            const target = classOwners.get(match[0]);
            if (target && target !== file.path) deps.add(target);
          }
        }
      }
    }
    graph.set(file.path, [...deps].sort());
  }
  return graph;
}

export function stronglyConnectedComponents(graph) {
  const adj = graph instanceof Map ? graph : new Map(Object.entries(graph));
  const nodes = [...adj.keys()].sort();
  const index = new Map();
  const lowlink = new Map();
  const onStack = new Set();
  const stack = [];
  const components = [];
  let nextIndex = 0;
  for (const start of nodes) {
    if (index.has(start)) continue;
    index.set(start, nextIndex);
    lowlink.set(start, nextIndex);
    nextIndex++;
    stack.push(start);
    onStack.add(start);
    const frames = [{ node: start, edges: [...(adj.get(start) ?? [])], next: 0 }];
    while (frames.length > 0) {
      const top = frames[frames.length - 1];
      const v = top.node;
      if (top.next < top.edges.length) {
        const w = top.edges[top.next++];
        if (!index.has(w)) {
          index.set(w, nextIndex);
          lowlink.set(w, nextIndex);
          nextIndex++;
          stack.push(w);
          onStack.add(w);
          frames.push({ node: w, edges: [...(adj.get(w) ?? [])], next: 0 });
        } else if (onStack.has(w)) {
          const wIndex = index.get(w);
          if (wIndex < lowlink.get(v)) lowlink.set(v, wIndex);
        }
      } else {
        frames.pop();
        if (lowlink.get(v) === index.get(v)) {
          const component = [];
          while (true) {
            const w = stack.pop();
            onStack.delete(w);
            component.push(w);
            if (w === v) break;
          }
          component.sort();
          components.push(component);
        }
        if (frames.length > 0) {
          const parent = frames[frames.length - 1].node;
          const vLow = lowlink.get(v);
          if (vLow < lowlink.get(parent)) lowlink.set(parent, vLow);
        }
      }
    }
  }
  components.sort((a, b) => b.length - a.length || a[0].localeCompare(b[0]));
  return components;
}

export function lintL16(files) {
  const graph = buildScriptGraph(files);
  const components = stronglyConnectedComponents(graph).filter(
    (component) => component.length >= 2,
  );
  const findings = [];
  for (const component of components) {
    const members = new Set(component);
    for (const file of component) {
      const inLoop = (graph.get(file) ?? []).filter((dep) => members.has(dep));
      const shown = inLoop.slice(0, 3).map(scriptRel);
      const extra = inLoop.length > 3 ? ` (+${inLoop.length - 3} more)` : "";
      findings.push(
        finding(
          "L16",
          file,
          1,
          `in a ${component.length}-file script dependency cycle (depends on ${shown.join(", ")}${extra}); break an edge to leave the cycle`,
        ),
      );
    }
  }
  return findings.sort((a, b) => a.path.localeCompare(b.path));
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
  for (const file of testFiles) {
    findings.push(...lintL1(file.path, file.text));
    if (sketch === "core-loop")
      findings.push(...lintL15(file.path, file.path.slice(relative.length + 1), file.text));
  }
  const lit = new Set();
  const batchDriverPath = path.join(directory, "tools", "test_batch_driver.gd");
  const driverText =
    sketch === "core-loop" && existsSync(batchDriverPath)
      ? readFileSync(batchDriverPath, "utf8")
      : "";
  const driverRefs = driverText ? parseBatchDriverRefs(driverText) : new Set();
  const driverVars = driverText ? parseBatchDriverVars(driverText) : new Set();
  const srcFiles = sources(path.join(directory, "src"), new Set([".gd"]));
  for (const file of srcFiles) {
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
    findings.push(...lintL13(file.path, rel, file.text));
    findings.push(
      ...lintL14(file.path, rel, file.text, driverRefs, L14_STATIC_VAR_BASELINE, driverVars),
    );
  }
  findings.push(...lintL16(srcFiles));
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
