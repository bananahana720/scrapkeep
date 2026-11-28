import { existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { ALPHA_MAPS, PARK_MAPS, PILOT_IDS } from "./lib/game-defs.mjs";
import { REPO_ROOT, git, nulSeparated } from "./lib/git.mjs";
import { isMain } from "./lib/cli.mjs";
import { walkSync } from "./lib/walk.mjs";
import { WORD_RULES, lintWords } from "./sketch-lint-words.mjs";

const root = REPO_ROOT;
export const BASELINE_PATH = "scripts/sketch-lint.baseline.json";
const BASELINE_FILE = path.join(root, BASELINE_PATH);
export const BASELINE_RULES = {
  L1: { shape: "keys" },
  L2: { shape: "keys" },
  L3: { shape: "keys" },
  L4: { shape: "keys" },
  L11: { shape: "count" },
  L14: {
    shape: "keys",
    growth: "count",
    keyOf: (item) => item.key ?? item.path,
    fileOf: (key) => key.split(":")[0],
  },
  L15: { shape: "count" },
  L16: { shape: "keys" },
  ...Object.fromEntries(WORD_RULES.map((rule) => [rule, { shape: "count" }])),
  L18: { shape: "keys" },
  L19: { shape: "keys" },
  L20: {
    shape: "keys",
    keyOf: (item) => item.key,
    fileOf: (key) => key.split(" -> ")[0],
  },
  L21: {
    shape: "keys",
    keyOf: (item) => item.key ?? item.path,
    fileOf: (key) => key.split(":")[0],
  },
  L22: { shape: "keys" },
};
const UID_FOLDERS = ["addons", "src", "tests", "tools"];
const MAX_QUARANTINE = 0;
const QUARANTINE_HEADER = "test\towner\treason\tadded\tdeadline";
const TEST_FOLDERS = new Set(["unit", "support", "doubles", "fixtures", "trees", "workshop"]);
const launchesGame = /SMOKE_FLAGS|--flags|tuning\.gd/;
const SOURCE_EXTENSIONS = new Set([".gd", ".mjs", ".js", ".sh", ".py"]);
const HOME_SCRIPT_EXTENSIONS = new Set([".py", ".sh", ".gd"]);

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
  "src/presentation/reward_ceremony.gd": {
    sites: 1,
    why: "calm() decides whether a ceremony may stop the world: a rule read against threats and enemies at the tick",
  },
  "src/presentation/warden_dress.gd": {
    sites: 1,
    why: "the Warden's lens asks its Sight, which answers with the last seen place while the ball is cloaked and has no drawn place",
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

export const CANONICAL_IDS = [...PARK_MAPS, ...ALPHA_MAPS, ...PILOT_IDS, "line_splicer"];

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

export function lintL11(file, rel, text, allowed = null, owners = ID_COMPARE_OWNERS) {
  if (owners.has(rel) || rel.startsWith("src/dev/")) return [];
  const arms = idMatchArms(text);
  const sites = codeLines(text).filter(
    (line) => rawIdCompare.test(line.raw) || rawIdPrefix.test(line.raw) || arms.has(line.number),
  );
  const baseMessage =
    "raw map or pilot ID branch (string or StringName compare, match arm, or begins_with) outside owning table (MG-16); query the owning def/capability instead of branching on ID strings";
  if (allowed === null) return sites.map((line) => finding("L11", file, line.number, baseMessage));
  const entry = allowed[rel] ?? allowed[file];
  const listed = typeof entry === "number" ? entry : (entry?.sites ?? 0);
  if (sites.length === listed) return [];
  if (sites.length === 0) {
    return [
      finding(
        "L11",
        file,
        1,
        "L11 baseline lists a file with no raw map/pilot ID comparison left: remove the entry",
      ),
    ];
  }
  const message =
    listed === 0
      ? baseMessage
      : `${sites.length} raw map/pilot ID branches, L11 baseline allows ${listed}; move branching to owning table fields (MG-16)`;
  return sites.map((line) => finding("L11", file, line.number, message));
}

export function applyBaseline(findings, baseline, exists) {
  const kept = [];
  const keySets = new Map();
  const offendingKeys = new Set();
  const counted = new Map();
  for (const [rule, spec] of Object.entries(BASELINE_RULES)) {
    if (spec.shape === "keys") keySets.set(rule, new Set(baseline[rule] ?? []));
    else counted.set(rule, new Map());
  }
  for (const item of findings) {
    const spec = BASELINE_RULES[item.rule];
    if (!spec) {
      kept.push(item);
      continue;
    }
    if (spec.shape === "keys") {
      const key = spec.keyOf ? spec.keyOf(item) : item.path;
      if (keySets.get(item.rule).has(key)) {
        offendingKeys.add(`${item.rule}\0${key}`);
      } else {
        kept.push(item);
      }
    } else {
      const byFile = counted.get(item.rule);
      if (!byFile.has(item.path)) byFile.set(item.path, []);
      byFile.get(item.path).push(item);
    }
  }
  for (const [rule, spec] of Object.entries(BASELINE_RULES)) {
    if (spec.shape === "keys") {
      for (const key of baseline[rule] ?? []) {
        if (offendingKeys.has(`${rule}\0${key}`)) continue;
        const file = spec.fileOf ? spec.fileOf(key) : key;
        const label = key === file ? rule : `${rule} (${key})`;
        kept.push(
          finding(
            "BASELINE",
            file,
            1,
            `${label} no longer offends${exists(file) ? "" : " (file is gone)"}: remove from baseline`,
          ),
        );
      }
      continue;
    }
    const listed = baseline[rule] ?? {};
    const byFile = counted.get(rule);
    for (const [file, items] of byFile) {
      const allowed = listed[file] ?? 0;
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
      const now = byFile.get(file)?.length ?? 0;
      if (now === 0) {
        kept.push(
          finding(
            "BASELINE",
            file,
            1,
            `${rule} no longer offends${exists(file) ? "" : " (file is gone)"}: remove from baseline`,
          ),
        );
      } else if (now < allowed) {
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
  }
  return kept;
}

export function readBaselineAt(ref, { cwd = root } = {}) {
  git(["rev-parse", "--verify", "--quiet", `${ref}^{commit}`], { cwd });
  if (!git(["ls-tree", "--full-tree", "--name-only", ref, "--", BASELINE_PATH], { cwd })) return {};
  try {
    return JSON.parse(git(["show", `${ref}:${BASELINE_PATH}`], { cwd }));
  } catch (error) {
    throw new Error(
      `the base copy of ${BASELINE_PATH} at ${ref} could not be read, so the shrink-only check could not run; fetch ${ref} with its files and run again: ${error.message}`,
    );
  }
}

export function renamesSince(base, head = null, { cwd = root } = {}) {
  const fields = nulSeparated(
    git(
      [
        "diff",
        "--find-renames",
        "--name-status",
        "-z",
        "--diff-filter=R",
        base,
        ...(head ? [head] : []),
      ],
      { cwd, trim: false },
    ),
  );
  const renamed = new Map();
  for (let at = 0; at < fields.length; at += 3) renamed.set(fields[at + 2], fields[at + 1]);
  return renamed;
}

function movedBySplit(fresh, gone) {
  const now = fresh.split(" -> ");
  const was = gone.split(" -> ");
  const at = now.findIndex((file, index) => file !== was[index]);
  return (
    at !== -1 &&
    now.length === was.length &&
    now.every((file, index) => index === at || file === was[index]) &&
    path.posix.dirname(now[at]) === path.posix.dirname(was[at])
  );
}

function splitExcused(fresh, gone) {
  const owner = new Map();
  const fit = (one, seen) => {
    for (const [at, entry] of gone.entries()) {
      if (seen.has(at) || !movedBySplit(fresh[one], entry)) continue;
      seen.add(at);
      if (!owner.has(at) || fit(owner.get(at), seen)) {
        owner.set(at, one);
        return true;
      }
    }
    return false;
  };
  for (const one of fresh.keys()) fit(one, new Set());
  return new Set([...owner.values()].map((one) => fresh[one]));
}

export function baselineGrowth(before, after, renamed = new Map()) {
  const size = (list) =>
    Array.isArray(list) ? list.length : Object.values(list ?? {}).reduce((a, b) => a + b, 0);
  const grew = [];
  for (const [rule, now] of Object.entries(after)) {
    const twice = Array.isArray(now)
      ? [...new Set(now.filter((key, at) => now.indexOf(key) !== at))]
      : [];
    if (twice.length > 0)
      grew.push(
        finding(
          "BASELINE",
          BASELINE_PATH,
          1,
          `${rule} list holds ${twice.join(", ")} more than once: write the lists again with node scripts/sketch-lint.mjs --sketch core-loop --write-baseline`,
        ),
      );
    if (!Object.hasOwn(before, rule)) continue;
    const was = before[rule];
    const exact = Array.isArray(now) && BASELINE_RULES[rule]?.growth !== "count";
    if (!exact && size(now) <= size(was)) continue;
    const unmatched = [...(Array.isArray(was) ? was : [])];
    const take = (key) => {
      const at = unmatched.indexOf(key);
      if (at !== -1) unmatched.splice(at, 1);
      return at !== -1;
    };
    const named = (key) =>
      key
        .split(" -> ")
        .map((file) => renamed.get(file) ?? file)
        .join(" -> ");
    let added = Array.isArray(now)
      ? now.filter((key) => !(exact && take(named(key))) && !take(key))
      : Object.entries(now)
          .filter(([file, count]) => count > (was?.[file] ?? 0))
          .map(([file, count]) => `${file} (${was?.[file] ?? 0} to ${count})`);
    if (exact) {
      const fresh = [...new Set(added.map(named))].sort();
      const excused = splitExcused(fresh, [...unmatched].sort());
      added = added.filter((key) => !excused.has(named(key)));
    }
    if (added.length === 0) continue;
    const fix =
      rule === "L14"
        ? "register a reset in sketches/core-loop/tools/test_batch_driver.gd"
        : "fix the offence";
    const moved = added.filter((key) => key.split(" -> ").some((file) => renamed.has(file)));
    const renames =
      moved.length === 0
        ? ", and no file it names was renamed"
        : `; ${moved.length} of them ${moved.length === 1 ? "names a renamed file, and the base list lacks it" : "name a renamed file, and the base list lacks them"} under the old name too`;
    const change =
      size(now) > size(was)
        ? `grew from ${size(was)} to ${size(now)} entries`
        : `has ${added.length} ${added.length === 1 ? "entry" : "entries"} the base list lacks${renames}`;
    grew.push(
      finding(
        "BASELINE",
        BASELINE_PATH,
        1,
        `${rule} list ${change} (new: ${added.join(", ")}): ${fix} instead of listing it${exact ? "\n    An offence that moved with a split file passes only when it stays inside one directory" : ""}`,
      ),
    );
  }
  return grew;
}

export function baselineFrom(findings) {
  const baseline = {};
  for (const [rule, spec] of Object.entries(BASELINE_RULES)) {
    const mine = findings.filter((item) => item.rule === rule);
    if (spec.shape === "keys") {
      const keyOf = spec.keyOf ?? ((item) => item.path);
      baseline[rule] = [...new Set(mine.map(keyOf))].filter((key) => key !== undefined).sort();
    } else {
      const counts = {};
      for (const item of mine) counts[item.path] = (counts[item.path] ?? 0) + 1;
      baseline[rule] = Object.fromEntries(
        Object.entries(counts).sort(([a], [b]) => a.localeCompare(b)),
      );
    }
  }
  return baseline;
}

export function baselineText(baseline) {
  const rules = Object.entries(baseline);
  const lines = rules.map(([rule, list], index) => {
    const end = index === rules.length - 1 ? "" : ",";
    const head = `  ${JSON.stringify(rule)}: `;
    if (!Array.isArray(list)) {
      const rows = Object.entries(list).map(
        ([file, count]) => `    ${JSON.stringify(file)}: ${count}`,
      );
      return rows.length === 0 ? `${head}{}${end}` : `${head}{\n${rows.join(",\n")}\n  }${end}`;
    }
    const inline = `${head}[${list.map((key) => JSON.stringify(key)).join(", ")}]${end}`;
    if (inline.length <= 100) return inline;
    return `${head}[\n${list.map((key) => `    ${JSON.stringify(key)}`).join(",\n")}\n  ]${end}`;
  });
  return `{\n${lines.join("\n")}\n}\n`;
}

export function parseLintArgs(argv) {
  const options = { sketch: null, writeBaseline: false, base: null, layers: null };
  const value = (at, needs) => {
    if (!argv[at] || argv[at].startsWith("-")) throw new Error(`${argv[at - 1]} requires ${needs}`);
    return argv[at];
  };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--sketch") options.sketch = value(++i, "a name, as in --sketch core-loop");
    else if (argv[i] === "--layers") {
      const order = argv[i + 1];
      options.layers = order && !order.startsWith("-") ? parseLayerOrder(argv[++i]) : LAYERS;
    } else if (argv[i] === "--base") options.base = value(++i, "a ref, as in --base origin/main");
    else if (argv[i] === "--write-baseline") options.writeBaseline = true;
    else
      throw new Error(
        `unknown argument ${argv[i]}; use --sketch NAME, --base REF, --layers [ORDER] or --write-baseline`,
      );
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

export const L13_ALLOWED = {
  "tests/app_shell_test.gd": { sites: 2, why: "verifies AppShell.headless() and scan regex" },
  "tests/destructibles_look_test.gd": { sites: 1, why: "prints display driver name" },
  "tools/craft_sculptor_capture.gd": { sites: 1, why: "checks embedded display driver" },
  "tools/look_harness.gd": { sites: 1, why: "forwards --display-driver to child process" },
  "tools/offscreen_window.gd": { sites: 1, why: "checks Mac embedded display driver" },
  "tools/perf_bench.gd": { sites: 1, why: "records display driver metadata" },
  "tools/qa/snag_sweep.gd": { sites: 1, why: "records display driver metadata" },
  "tools/stress_capture.gd": { sites: 1, why: "records display driver metadata" },
  "tools/visual_capture.gd": { sites: 1, why: "records display driver metadata" },
};

export function lintL13(file, rel, text, allowed = L13_ALLOWED) {
  if (rel === "src/core/app_shell.gd") return [];
  const sites = text.includes("DisplayServer")
    ? codeLines(text).filter((line) => displayNameRead.test(line.raw))
    : [];
  const listed = allowed[rel];
  if (listed === undefined) {
    return sites.map((line) =>
      finding(
        "L13",
        file,
        line.number,
        "raw DisplayServer.get_name() read; call AppShell.headless() (src/core/app_shell.gd) instead",
      ),
    );
  }
  if (sites.length === listed.sites) return [];
  if (sites.length < listed.sites) {
    return [
      finding(
        "L13",
        file,
        1,
        `L13_ALLOWED lists ${listed.sites} DisplayServer.get_name() sites for ${rel}, found ${sites.length}: tighten or remove the entry`,
      ),
    ];
  }
  return sites.map((line) =>
    finding(
      "L13",
      file,
      line.number,
      `${sites.length} DisplayServer.get_name() reads, L13_ALLOWED lists ${listed.sites}; call AppShell.headless() (src/core/app_shell.gd) instead`,
    ),
  );
}

const staticVarDecl = /^static\s+var\s+([A-Za-z_]\w*)\b/;
const declPrefix = "^\\s*((?:static\\s+|@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*)";
const anyVarDecl = new RegExp(`${declPrefix}var\\s+([A-Za-z_]\\w*)\\b(.*)$`);
const anyFuncDecl = new RegExp(`${declPrefix}func\\s+([A-Za-z_]\\w*)\\s*\\(`);
const gdFuncDecl = /^(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(/;
const resetFuncName = /^_?reset/i;
const driverScript = "((?:src|tools|tests\\/support)\\/[^\"']+\\.gd)";

function parseBatchDriverRefs(text) {
  return new Set([...text.matchAll(new RegExp(`res:\\/\\/${driverScript}`, "g"))].map((m) => m[1]));
}

function parseBatchDriverVars(text) {
  const aliases = new Map();
  for (const match of text.matchAll(
    new RegExp(
      `\\bconst\\s+([A-Za-z_]\\w*)\\s*:?=\\s*preload\\(\\s*"res:\\/\\/${driverScript}"\\s*\\)`,
      "g",
    ),
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

function stripComment(raw) {
  return raw.match(/^((?:[^"'#]|"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')*)/)[1];
}

function logicalLines(text) {
  const out = [];
  let open = null;
  let tripleQuote = null;
  text.split("\n").forEach((raw, index) => {
    const inString = tripleQuote !== null;
    const scanned = scanGdLine(raw, tripleQuote);
    tripleQuote = scanned.tripleQuote;
    if (inString && !open) return;
    const code = inString ? scanned.code : stripComment(raw);
    const depth =
      (scanned.code.match(/[[({]/g) ?? []).length - (scanned.code.match(/[\])}]/g) ?? []).length;
    if (open) {
      open.code += ` ${code.trim()}`;
      open.depth += depth;
    } else if (code.trim()) open = { number: index + 1, code: code.trimEnd(), depth };
    else return;
    if (open.depth <= 0) {
      out.push(open);
      open = null;
    }
  });
  if (open) out.push(open);
  return out;
}

function gdFunctions(text) {
  const bodies = new Map();
  let body = null;
  for (const { code } of logicalLines(text)) {
    const fn = /^\S/.test(code) ? code.match(anyFuncDecl) : null;
    if (fn) {
      body = [];
      bodies.set(fn[2], body);
      continue;
    }
    if (/^\S/.test(code)) body = null;
    else if (body && code.trim()) body.push(code.trim());
  }
  return bodies;
}

function parseBatchDriverResets(text) {
  const paths = new Map();
  for (const match of text.matchAll(
    new RegExp(
      `\\bconst\\s+([A-Za-z_]\\w*)\\s*:?=\\s*(?:preload\\(\\s*)?"res:\\/\\/${driverScript}"`,
      "g",
    ),
  ))
    paths.set(match[1], match[2]);
  const aliases = new Map(
    [...text.matchAll(/\bconst\s+([A-Za-z_]\w*)\s*:?=\s*preload\(/g)]
      .filter((match) => paths.has(match[1]))
      .map((match) => [match[1], paths.get(match[1])]),
  );
  const resets = new Map();
  const reset = gdFunctions(text).get("_reset");
  if (!reset) return resets;
  const entry = (rel) => {
    if (!resets.has(rel)) resets.set(rel, { calls: new Set(), values: new Map() });
    return resets.get(rel);
  };
  for (const code of reset) {
    const loaded = code.match(/^var\s+([A-Za-z_]\w*)\s*:?=\s*load\(\s*([A-Za-z_]\w*)\s*\)/);
    if (loaded && paths.has(loaded[2])) aliases.set(loaded[1], paths.get(loaded[2]));
    for (const [alias, rel] of aliases) {
      const named = new RegExp(
        `(?<![\\w.])${alias}\\.([A-Za-z_]\\w*)\\s*(\\(|\\.clear\\(\\)|=(?!=))(.*)`,
      );
      const hit = code.match(named);
      if (!hit) continue;
      if (hit[2] === "(") entry(rel).calls.add(hit[1]);
      else
        resetValue(
          entry(rel).values,
          hit[1],
          hit[2] === "=" ? hit[3].replaceAll(`${alias}.`, "") : ".clear()",
        );
    }
  }
  return resets;
}

function gdValue(value) {
  return value.replace(/\s+/g, "").replace(/,([\])}])/g, "$1");
}

function resetValue(values, name, value) {
  values.set(name, [...(values.get(name) ?? []), gdValue(value)]);
}

export function parseBatchDriver(text) {
  return {
    refs: parseBatchDriverRefs(text),
    vars: parseBatchDriverVars(text),
    resets: parseBatchDriverResets(text),
  };
}

const zeroValues = new Set(["null", "0", "0.0", "false", '""', '&""', "[]", "{}", ".clear()"]);

function resetMatchesDeclared(declared, values) {
  if (declared === null)
    return values.some((value) => zeroValues.has(value) || /^\w+(?:\.ZERO|\(\))$/.test(value));
  return values.some(
    (value) =>
      value === declared ||
      (value === ".clear()" && /^(?:\[\]|\{\}|[A-Za-z_]\w*\.new\(\))$/.test(declared)),
  );
}

function strictResets(text, rel, driver) {
  const fromDriver = driver.resets.get(rel);
  const values = new Map(fromDriver?.values ?? []);
  if (!fromDriver) return values;
  const bodies = gdFunctions(text);
  const reached = new Set([...fromDriver.calls].filter((name) => bodies.has(name)));
  for (const name of reached)
    for (const code of bodies.get(name))
      for (const call of code.matchAll(/(?<![\w.])([A-Za-z_]\w*)\s*\(/g))
        if (bodies.has(call[1])) reached.add(call[1]);
  for (const name of reached)
    for (const code of bodies.get(name))
      for (const hit of code.matchAll(/(?<!\w)([A-Za-z_]\w*)\s*(?:(\.clear\(\))|=(?!=)\s*(.*))/g))
        resetValue(values, hit[1], hit[2] ?? hit[3]);
  return values;
}

const testSupportLoad =
  /(?:preload|load)\(\s*["']res:\/\/((?:tools|tests\/support)\/[^"']+\.gd)["']\s*\)|^extends\s+["']res:\/\/((?:tools|tests\/support)\/[^"']+\.gd)["']/g;

export function preloadedTestSupportFiles(testFiles, toolFiles, relative) {
  const prefix = `${relative}/`;
  const relOf = (file) =>
    file.path.startsWith(prefix) ? file.path.slice(prefix.length) : file.path;
  const byRel = new Map();
  for (const file of [...testFiles, ...toolFiles]) {
    if (!file.path.endsWith(".gd")) continue;
    const rel = relOf(file);
    if (rel.startsWith("tools/") || rel.startsWith("tests/support/")) {
      byRel.set(rel, { ...file, rel });
    }
  }
  const seen = new Set();
  const queue = [];
  const collect = (text) => {
    if (!text.includes("res://tools/") && !text.includes("res://tests/support/")) return;
    for (const line of codeLines(text)) {
      for (const match of line.code.matchAll(testSupportLoad)) {
        const rel = match[1] ?? match[2];
        if (byRel.has(rel) && !seen.has(rel)) {
          seen.add(rel);
          queue.push(rel);
        }
      }
    }
  };
  for (const file of testFiles) {
    if (!relOf(file).startsWith("tests/support/")) collect(file.text);
  }
  while (queue.length > 0) {
    collect(byRel.get(queue.shift()).text);
  }
  return [...seen].sort().map((rel) => byRel.get(rel));
}

export function lintPreloadedTestSupport(testFiles, toolFiles, relative, driver) {
  const reached = preloadedTestSupportFiles(testFiles, toolFiles, relative);
  const findings = [];
  if (driver.resets.size === 0)
    findings.push(
      finding(
        "L21",
        `${relative}/tools/test_batch_driver.gd`,
        1,
        "read no script reset in the batch driver's _reset(), so L21 checked nothing; restore its _reset() and the preloads it calls",
      ),
    );
  for (const folder of ["tools", "tests/support"]) {
    const prefix = `${folder}/`;
    if (!reached.some((file) => file.rel.startsWith(prefix))) {
      findings.push(
        finding(
          "L14",
          `${relative}/${folder}`,
          1,
          `no preloaded .gd script reached under ${relative}/${folder}; check the L14 test-support walker`,
        ),
      );
    }
  }
  for (const file of reached) {
    findings.push(...lintL14(file.path, file.rel, file.text, driver));
  }
  return findings;
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

function declaredValue(code) {
  const value = code.match(anyVarDecl)[3].match(/^\s*(?::(?!=)[^=]*)?:?=\s*(.*)$/)?.[1];
  return value === undefined ? null : gdValue(value).replace(/:$/, "");
}

export function lintL14(file, rel, text, driver, baseline = null) {
  if (!/\bstatic\b.*\bvar\b/.test(text)) return [];
  const registered = driver.refs.has(rel);
  const resetBody = registered ? resetMethodText(text) : "";
  const strict = strictResets(text, rel, driver);
  const out = [];
  const logical = new Map(logicalLines(text).map((line) => [line.number, line.code.trim()]));
  for (const { number, code } of codeLines(text)) {
    const match = code.match(anyVarDecl);
    if (!match || !/\bstatic\b/.test(match[1])) continue;
    const varName = match[2];
    const relKey = `${rel}:${varName}`;
    const key = `${file}:${varName}`;
    if (baseline && (baseline.has(key) || baseline.has(relKey))) continue;
    const declared = declaredValue(logical.get(number) ?? stripComment(code));
    const values = strict.get(varName) ?? [];
    if (values.length > 0 && resetMatchesDeclared(declared, values)) continue;
    const lenient =
      !staticVarDecl.test(code) ||
      (registered &&
        (driver.vars.has(relKey) ||
          new RegExp(`\\b${varName}\\b\\s*(?:=|\\.clear\\(|\\.erase\\()`).test(resetBody)));
    const why =
      values.length === 0
        ? `nothing sketches/core-loop/tools/test_batch_driver.gd _reset() runs resets ${varName}`
        : `${varName} is reset to ${values.join(" or ")}, not to its declared ${declared ?? "default"}`;
    out.push({
      ...finding(
        lenient ? "L21" : "L14",
        file,
        number,
        lenient
          ? `mutable static var ${varName} only looks reset: ${why}; call the reset from _reset() and give ${varName} its declared value there`
          : `mutable static var ${varName} is not reset per-variable: register ${rel} in sketches/core-loop/tools/test_batch_driver.gd _reset() and clear ${varName} in the script's reset method`,
      ),
      key,
    });
  }
  return out;
}

const physicsTestSignal = /\b(?:physics_frame|_physics_process)\b/;
const hardcoded60Hz = /\b1\.0\s*\/\s*60(?:\.0)?\b|\*\s*60\.0\b/g;

export function lintL15(file, rel, text, baseline = null) {
  if (!text.includes("60") || !physicsTestSignal.test(text)) return [];
  const lines = codeLines(text);
  if (!lines.some((line) => physicsTestSignal.test(line.raw))) return [];
  const sites = lines.flatMap((line) =>
    (line.raw.replace(/#.*$/, "").match(hardcoded60Hz) ?? []).map(() => line),
  );
  const baseMessage =
    "hardcoded 60 Hz physics frame literal in a 90 Hz physics test; derive ticks from Engine.physics_ticks_per_second instead";
  if (baseline === null) return sites.map((line) => finding("L15", file, line.number, baseMessage));
  const listed = baseline[rel] ?? baseline[file] ?? 0;
  if (sites.length <= listed) return [];
  const message =
    listed === 0
      ? baseMessage
      : `${sites.length} hardcoded 60 Hz physics frame literals, L15 baseline allows ${listed}; derive ticks from Engine.physics_ticks_per_second instead`;
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

const loadLines = new WeakMap();

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
  const lines = new Map();
  loadLines.set(graph, lines);
  for (const file of files) {
    const deps = new Map();
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
            if (target && target !== file.path && !deps.has(target)) deps.set(target, line.number);
          }
        }
        if (hasClass && scanned.code) {
          for (const match of scanned.code.matchAll(classMatchRe)) {
            const target = classOwners.get(match[0]);
            if (target && target !== file.path && !deps.has(target)) deps.set(target, line.number);
          }
        }
      }
    }
    graph.set(file.path, [...deps.keys()].sort());
    for (const [target, number] of deps) lines.set(`${file.path} -> ${target}`, number);
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

export function lintL16(files, graph = buildScriptGraph(files)) {
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

function srcDir(filePath) {
  const rel = scriptRel(filePath).slice("src/".length);
  const slash = rel.indexOf("/");
  return slash === -1 ? rel : rel.slice(0, slash);
}

export function parseLayerOrder(text) {
  const layers = text.split(",").map((layer) => layer.split("+"));
  const named = layers.flat();
  if (named.some((dir) => dir === ""))
    throw new Error(
      `--layers ${text}: name each layer's directories, bottom first, as in core,movement,boot+dev`,
    );
  const twice = named.filter((dir, index) => named.indexOf(dir) !== index);
  if (twice.length > 0) throw new Error(`--layers ${text}: ${twice[0]} is named twice`);
  return layers;
}

function layerIndex(layers) {
  return new Map(layers.flatMap((layer, index) => layer.map((dir) => [dir, index])));
}

function upwardPairs(graph, layerOf) {
  const pairs = [];
  for (const [from, deps] of graph) {
    const low = layerOf.get(srcDir(from));
    if (low === undefined) continue;
    for (const to of deps) if (layerOf.get(srcDir(to)) > low) pairs.push({ from, to });
  }
  return pairs;
}

function fewestUpward(matrix) {
  const order = matrix.map((_, index) => index);
  const cost = () => {
    let sum = 0;
    for (let low = 0; low < order.length; low++)
      for (let high = low + 1; high < order.length; high++) sum += matrix[order[low]][order[high]];
    return sum;
  };
  let best = { cost: cost(), order: [...order] };
  const swaps = order.map(() => 0);
  for (let at = 1; at < order.length;) {
    if (swaps[at] < at) {
      const other = at % 2 === 0 ? 0 : swaps[at];
      [order[other], order[at]] = [order[at], order[other]];
      const now = cost();
      if (now < best.cost) best = { cost: now, order: [...order] };
      swaps[at]++;
      at = 1;
    } else {
      swaps[at] = 0;
      at++;
    }
  }
  return best;
}

export function layerReport(files, layers) {
  const graph = buildScriptGraph(files);
  const dirs = [...new Set([...graph.keys()].map(srcDir))].sort();
  const named = layers.flat();
  const problems = [];
  if (graph.size === 0) problems.push("read no scripts under src/, so there is nothing to measure");
  for (const dir of dirs)
    if (!named.includes(dir)) problems.push(`src/${dir} is in no layer of the order`);
  for (const dir of named)
    if (!dirs.includes(dir)) problems.push(`the order names ${dir}, which holds no script`);
  if (problems.length > 0) return { ok: false, lines: problems };
  const layerOf = layerIndex(layers);
  const cell = new Map();
  let dependencies = 0;
  for (const [from, deps] of graph)
    for (const to of deps) {
      dependencies++;
      const key = `${srcDir(from)}\0${srcDir(to)}`;
      if (srcDir(from) !== srcDir(to)) cell.set(key, (cell.get(key) ?? 0) + 1);
    }
  const width = Math.max("from \\ to".length, ...named.map((dir) => dir.length)) + 1;
  const row = (head, cells) =>
    [head, ...cells]
      .map((text) => String(text).padEnd(width))
      .join("")
      .trimEnd();
  const name = (layer) => layer.join("+");
  const lines = [
    `layer order, bottom first: ${layers.map(name).join(" < ")}`,
    `${graph.size} scripts, ${dependencies} dependencies; each cell counts the pairs of files where a file in the row's directory depends on a file in the column's`,
    row("from \\ to", named),
    ...named.map((from) =>
      row(
        from,
        named.map((to) => cell.get(`${from}\0${to}`) ?? ""),
      ),
    ),
  ];
  const upward = upwardPairs(graph, layerOf);
  const byFile = new Map();
  for (const pair of upward) byFile.set(pair.from, (byFile.get(pair.from) ?? 0) + 1);
  lines.push(`upward pairs: ${upward.length} in ${byFile.size} files; the files with the most:`);
  for (const [file, count] of [...byFile]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, 10))
    lines.push(`${String(count).padStart(5)} ${scriptRel(file)}`);
  if (layers.length > 9) {
    lines.push(`${layers.length} layers are too many to try every order; name 9 or fewer`);
  } else {
    const matrix = layers.map((low) =>
      layers.map((high) =>
        low === high
          ? 0
          : low.reduce(
              (sum, a) => sum + high.reduce((inner, b) => inner + (cell.get(`${a}\0${b}`) ?? 0), 0),
              0,
            ),
      ),
    );
    const best = fewestUpward(matrix);
    lines.push(
      `fewest upward pairs over every order of these ${layers.length} layers: ${best.cost}, ${best.order.map((index) => name(layers[index])).join(" < ")}`,
    );
  }
  return { ok: true, lines };
}

export const LAYERS = parseLayerOrder(
  "core,movement,build,combat,boss,world,presentation,ui,boot+dev+experimental+game.gd",
);
const LAYER_RECORD = "adr/TADR-014-source-layer-order.md";

export function lintL20(files, graph = buildScriptGraph(files), layers = LAYERS) {
  if (files.length === 0)
    return [
      finding(
        "L20",
        "sketches/core-loop/src",
        1,
        "read no scripts under src/, so L20 checked nothing; run the lint from a full checkout",
      ),
    ];
  const layerOf = layerIndex(layers);
  const findings = [];
  const dirs = new Set([...graph.keys()].map(srcDir));
  const srcRoot = files[0].path.slice(0, -scriptRel(files[0].path).length) + "src";
  for (const dir of layers.flat())
    if (!dirs.has(dir))
      findings.push(
        finding(
          "L20",
          `${srcRoot}/${dir}`,
          1,
          `LAYERS names ${dir}, which holds no script; take it out of LAYERS in scripts/sketch-lint.mjs and ${LAYER_RECORD}, or restore its scripts`,
        ),
      );
  for (const file of graph.keys()) {
    const dir = srcDir(file);
    if (!layerOf.has(dir))
      findings.push(
        finding(
          "L20",
          file,
          1,
          `src/${dir} is in no layer; place it in LAYERS in scripts/sketch-lint.mjs and in ${LAYER_RECORD} before it can land`,
        ),
      );
  }
  const place = (dir) => `${dir} is layer ${layerOf.get(dir) + 1}`;
  const lines = loadLines.get(graph);
  for (const { from, to } of upwardPairs(graph, layerOf)) {
    const low = srcDir(from);
    const key = `${from} -> ${to}`;
    if (!lines?.has(key))
      throw new Error(`L20 has no line for the load ${key}; build the graph with buildScriptGraph`);
    findings.push({
      ...finding(
        "L20",
        from,
        lines.get(key),
        `loads ${scriptRel(to)}, a script in a higher layer: ${place(low)} and ${place(srcDir(to))} (${LAYER_RECORD}).\n    Hand the value or a callable in from the script above, move a pure data file down to ${low}, or move the fact to its owner in ${low}; never list the pair`,
      ),
      key,
    });
  }
  return findings.sort((a, b) => (a.key ?? a.path).localeCompare(b.key ?? b.path));
}

export function lintL17(file, text) {
  const findings = [];
  const lines = text.split("\n");
  for (let index = 0; index < lines.length; index++) {
    if (lines[index].includes("/home/andrew")) {
      findings.push(
        finding(
          "L17",
          file,
          index + 1,
          "hardcoded /home/andrew path; derive from HOME (os.path.expanduser, Path.home(), or $HOME)",
        ),
      );
    }
  }
  return findings;
}

export function lintL18(paths, folders = UID_FOLDERS) {
  const tracked = new Set(paths);
  const findings = [];
  if (!paths.some((file) => file.endsWith(".gd"))) {
    const list = folders.join(", ");
    return [
      finding(
        "L18",
        folders[0] ?? "sketches",
        1,
        `git ls-files returned no tracked .gd scripts under ${list}; check the repository root and git environment`,
      ),
    ];
  }
  for (const file of paths) {
    if (file.endsWith(".gd") && !tracked.has(`${file}.uid`))
      findings.push(
        finding(
          "L18",
          file,
          1,
          "script has no tracked NAME.gd.uid beside it; run a Godot import and commit the .uid file",
        ),
      );
    else if (file.endsWith(".gd.uid") && !tracked.has(file.slice(0, -".uid".length)))
      findings.push(
        finding("L18", file, 1, "uid file has no NAME.gd beside it; delete the orphan"),
      );
  }
  return findings;
}

const SOURCE_READER = "tests/support/source_scan.gd";
const scriptRootLiteral = /"res:\/\/(?:src|tools|tests)(?:\/[^"]*)?"/;
const scriptPathLiteral = /"res:\/\/(?:src|tools|tests)\/[^"]*\.gd"/;
const anyLiteral = /"[^"]*"/g;
const textRead = /\bFileAccess\s*\.\s*(?:get_file_as_string|open)\s*\(([^)]*)/g;
const folderList = /\bDirAccess\s*\.\s*(?:open|get_files_at|get_directories_at)\s*\(([^)]*)/g;
const scriptNameFilter = /\.ends_with\(\s*"\.gd"\s*\)|\.get_extension\(\)\s*==\s*"gd"/;
const oldBinding =
  /^(?:static\s+)?(?:const|var)\s+([A-Za-z_]\w*)\s*(?::\s*[\w[\]]+\s*)?:?=\s*(\[[^\]]*\]?|"[^"]*")/;
const oldLoop = /^for\s+([A-Za-z_]\w*)\s+in\s+([A-Za-z_]\w*|\[[^\]]*\]?)/;
const literalBinding =
  /^(?:static\s+)?(?:const|var)\s+([A-Za-z_]\w*)\s*(?::\s*[\w[\], ]+?\s*)?:?=\s*(?:[A-Z]\w*\(\s*)?(\[[^\]]*\]?|\{[^}]*\}?|"[^"]*")/;
const literalLoop = /^for\s+([A-Za-z_]\w*)(?:\s*:\s*[\w[\]]+)?\s+in\s+([A-Za-z_]\w*|\[[^\]]*\]?)/;
const lambdaOverList =
  /([A-Za-z_]\w*|\[[^\]]*\])\s*\.\s*(?:map|filter|any|all)\(\s*func\s*\(\s*([A-Za-z_]\w*)/;
const lambdaBinding = /^var\s+([A-Za-z_]\w*)\s*(?::[^=]*)?:?=\s*func\s*\(([^)]*)\)/;
const localBinding = /^var\s+([A-Za-z_]\w*)\s*(?::[^=]*)?:?=\s*(.+)$/;
const funcDecl = /^(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(([^)]*)\)/;
const preloadAlias =
  /^const\s+([A-Za-z_]\w*)\s*:?=\s*preload\(\s*"res:\/\/(tests\/[^"]+\.gd)"\s*\)/;
const extendsTest = /^extends\s+"res:\/\/(tests\/[^"]+\.gd)"/;

function joinList(raw, index, value) {
  const close = { "[": "]", "{": "}" }[value[0]];
  for (let next = index + 1; close && !value.includes(close) && next < raw.length; next++)
    value += raw[next];
  return value;
}

function paramNames(list) {
  return list
    .split(",")
    .map((param) => param.trim().match(/^[A-Za-z_]\w*/)?.[0])
    .filter(Boolean);
}

function words(code) {
  return code.match(/\b[A-Za-z_]\w*\b/g) ?? [];
}

function substitute(value, names) {
  return /^[[{]/.test(value)
    ? value.replace(/"[^"]*"|\b[A-Za-z_]\w*\b/g, (token) => names.get(token) ?? token)
    : value;
}

function readScopes(text, strict) {
  const raw = text.split("\n");
  const global = new Map();
  let local = new Map();
  let fn = null;
  let lambda = null;
  const scopes = new Map();
  const indent = (line) => line.match(/^\s*/)[0].length;
  for (let index = 0; index < raw.length; index++) {
    const topLevel = /^\S/.test(raw[index]);
    const code = raw[index].trim();
    if (lambda && code && indent(raw[index]) <= lambda.indent) lambda = null;
    if (topLevel) {
      local = new Map();
      const decl = code.match(funcDecl);
      fn = decl ? { name: decl[1], params: paramNames(decl[2]) } : null;
    }
    const names = () => new Map([...global, ...local]);
    const bound = code.match(strict ? literalBinding : oldBinding);
    if (bound) {
      const value = joinList(raw, index, bound[2]);
      (topLevel ? global : local).set(bound[1], strict ? substitute(value, names()) : value);
    }
    const loop = code.match(strict ? literalLoop : oldLoop);
    const mapped = loop || !strict || !code.includes("func") ? null : code.match(lambdaOverList);
    const [name, over] = loop ? [loop[1], loop[2]] : mapped ? [mapped[2], mapped[1]] : [];
    if (name) {
      const value = over.startsWith("[")
        ? substitute(joinList(raw, index, over), names())
        : names().get(over);
      if (value) local.set(name, value);
    }
    const lambdaDecl = strict ? code.match(lambdaBinding) : null;
    if (lambdaDecl)
      lambda = {
        name: lambdaDecl[1],
        params: paramNames(lambdaDecl[2]),
        indent: indent(raw[index]),
      };
    const derived = strict && !topLevel && fn && !lambdaDecl ? code.match(localBinding) : null;
    if (derived && words(derived[2]).some((word) => fn.params.includes(word)))
      fn.params.push(derived[1]);
    scopes.set(index + 1, { names: names(), fn, lambda });
  }
  return scopes;
}

const helperCall = (prefix, name, strict) =>
  new RegExp(
    String.raw`(?:^|[^\w.])${prefix}${name}${strict ? String.raw`(?:\.call)?` : ""}\s*\(([^)]*)`,
    "g",
  );

function scanReads(file, rel, text, strict) {
  const scan = { file, rel, text, strict, reads: new Set(), throughParam: new Map(), lists: [] };
  const reads = text.includes("FileAccess") || text.includes("DirAccess");
  if (!reads && !(strict && text.includes("res://tests/"))) return { ...scan, lines: [] };
  const lines = codeLines(text);
  let scopes = null;
  const scope = (line) => (scopes ??= readScopes(text, strict)).get(line.number);
  const resolve = (line, arg) =>
    arg.replace(/\b[A-Za-z_]\w*\b/g, (word) => scope(line).names.get(word) ?? word);
  const args = (line, pattern) =>
    [...line.code.matchAll(pattern)].map((match) => ({
      bare: match[1].trim(),
      arg: resolve(line, match[1]),
    }));
  Object.assign(scan, { lines, args });
  if (!reads) return scan;
  const picksScripts = lines.some((line) => scriptNameFilter.test(line.code));
  const builtFromListing = (arg) =>
    (arg.match(anyLiteral) ?? []).every(
      (literal) => scriptRootLiteral.test(literal) && !/\.\w+"$/.test(literal),
    );
  const first = (bare) => bare.split(",")[0];
  const mentions = (bare, params) =>
    strict
      ? words(first(bare)).some((word) => params.includes(word))
      : params.includes(first(bare).trim());
  for (const line of lines) {
    const { fn, lambda } = scope(line);
    for (const { bare } of args(line, textRead)) {
      if (/\bWRITE\b/.test(bare)) continue;
      for (const owner of strict ? [fn, lambda] : [fn])
        if (owner && mentions(bare, owner.params))
          scan.throughParam.set(owner.name, [...(scan.throughParam.get(owner.name) ?? []), line]);
    }
  }
  for (const line of lines) {
    for (const { arg } of args(line, textRead))
      if (
        !/\bWRITE\b/.test(arg) &&
        (scriptPathLiteral.test(arg) || (picksScripts && builtFromListing(arg)))
      )
        scan.reads.add(line);
  }
  scan.lists = picksScripts
    ? lines.filter((line) =>
        args(line, folderList).some(
          ({ arg }) => scriptRootLiteral.test(arg) && builtFromListing(arg),
        ),
      )
    : [];
  return scan;
}

function markHelperReads(caller, helper, prefix) {
  for (const [name, sites] of helper.throughParam) {
    const call = helperCall(prefix, name, helper.strict);
    for (const line of caller.lines)
      if (
        line.code.includes(name) &&
        caller.args(line, call).some(({ arg }) => scriptPathLiteral.test(arg))
      )
        for (const site of sites) helper.reads.add(site);
  }
}

export function lintL19(files, relative) {
  const reader = `${relative}/${SOURCE_READER}`;
  if (!files.some((file) => file.path === reader))
    return [
      finding(
        "L19",
        reader,
        1,
        "the shared source reader is not among the test scripts read, so L19 checked nothing; restore tests/support/source_scan.gd",
      ),
    ];
  const scansOf = (strict) => {
    const scans = new Map();
    for (const file of files) {
      const rel = file.path.slice(relative.length + 1);
      if (rel !== SOURCE_READER && rel.startsWith("tests/"))
        scans.set(rel, scanReads(file.path, rel, file.text, strict));
    }
    for (const scan of scans.values()) markHelperReads(scan, scan, strict ? "(?:self\\.)?" : "");
    if (strict) markCrossFileReads(scans);
    return scans;
  };
  const old = scansOf(false);
  const message =
    "reads script source by hand; read script source through tests/support/source_scan.gd";
  return [...scansOf(true).values()].flatMap((scan) => {
    const listed = old.get(scan.rel);
    const shown = listed.reads.size > 0 ? listed : scan;
    if (shown.reads.size === 0) return [];
    return [...new Set([...shown.lists, ...shown.reads])]
      .sort((a, b) => a.number - b.number)
      .map((line) => finding(shown === listed ? "L19" : "L22", scan.file, line.number, message));
  });
}

function markCrossFileReads(scans) {
  for (const scan of scans.values()) {
    if (!scan.text.includes("res://tests/")) continue;
    for (const line of scan.lines) {
      const alias = line.code.match(preloadAlias);
      const base = line.code.match(extendsTest);
      const helper = scans.get(alias?.[2] ?? base?.[1]);
      if (helper && helper !== scan && helper.throughParam.size > 0)
        markHelperReads(scan, helper, alias ? `${alias[1]}\\.` : "(?:self\\.)?");
    }
  }
}

export function lintTrackedUids(relative, repoRoot = root) {
  const folders = UID_FOLDERS.map((folder) => `${relative}/${folder}`);
  const paths = git(["ls-files", "--", ...folders], { cwd: repoRoot })
    .split("\n")
    .filter(Boolean);
  return lintL18(paths, folders);
}

function walk(directory) {
  return walkSync(directory, { includeDirs: true });
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
    findings.push(...lintL17(file.path, file.text));
    if (sketch === "core-loop") {
      const rel = file.path.slice(relative.length + 1);
      findings.push(...lintL15(file.path, rel, file.text));
      findings.push(...lintL13(file.path, rel, file.text));
    }
  }
  if (sketch === "core-loop") findings.push(...lintL19(testFiles, relative));
  for (const file of sources(path.join(directory, "tests"), new Set([".py", ".sh"]))) {
    findings.push(...lintL17(file.path, file.text));
  }
  const lit = new Set();
  const batchDriverPath = path.join(directory, "tools", "test_batch_driver.gd");
  const driverText =
    sketch === "core-loop" && existsSync(batchDriverPath)
      ? readFileSync(batchDriverPath, "utf8")
      : "";
  const driver = parseBatchDriver(driverText);
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
    findings.push(...lintL14(file.path, rel, file.text, driver));
  }
  const graph = buildScriptGraph(srcFiles);
  findings.push(...lintL16(srcFiles, graph));
  if (sketch === "core-loop") findings.push(...lintL20(srcFiles, graph));
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
  const toolFiles = sources(path.join(directory, "tools"), SOURCE_EXTENSIONS);
  for (const file of toolFiles) {
    if (HOME_SCRIPT_EXTENSIONS.has(path.extname(file.path))) {
      findings.push(...lintL17(file.path, file.text));
    }
    if (sketch === "core-loop" && file.path.endsWith(".gd")) {
      findings.push(...lintL13(file.path, file.path.slice(relative.length + 1), file.text));
    }
  }
  if (sketch === "core-loop") {
    findings.push(...lintPreloadedTestSupport(testFiles, toolFiles, relative, driver));
  }
  const flagFiles = [
    ...testFiles,
    ...toolFiles,
    ...sources(path.join(root, "scripts"), SOURCE_EXTENSIONS).filter(
      (file) => !lintSelf.has(file.path) && launchesGame.test(file.text),
    ),
  ];
  findings.push(...lintL3(flagFiles, tuning));
  const tests = walk(path.join(directory, "tests"));
  findings.push(...lintL4(tests, `${relative}/tests`));
  findings.push(...lintTrackedUids(relative));
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
  let options;
  try {
    options = parseLintArgs(process.argv.slice(2));
  } catch (error) {
    console.error(`sketch-lint: ${error.message}`);
    process.exit(2);
  }
  if (
    !options.sketch ||
    !existsSync(path.join(root, "sketches", options.sketch, "project.godot"))
  ) {
    console.error("sketch-lint: pass --sketch NAME for a folder under sketches/");
    process.exit(2);
  }
  if (options.layers) {
    const report = layerReport(
      sources(path.join(root, "sketches", options.sketch, "src"), new Set([".gd"])),
      options.layers,
    );
    for (const line of report.lines) console.log(line);
    process.exit(report.ok ? 0 : 1);
  }
  const started = Date.now();
  const raw = lintSketch(options.sketch);
  if (options.writeBaseline) {
    const baseline = baselineFrom(raw);
    writeFileSync(BASELINE_FILE, baselineText(baseline));
    for (const [rule, spec] of Object.entries(BASELINE_RULES)) {
      if (spec.shape === "keys") console.log(`${rule} ${baseline[rule].length} baseline entries`);
      else
        console.log(
          `${rule} ${Object.values(baseline[rule]).reduce((a, b) => a + b, 0)} baseline offences in ${Object.keys(baseline[rule]).length} files`,
        );
    }
    return;
  }
  const baseline = existsSync(BASELINE_FILE) ? JSON.parse(readFileSync(BASELINE_FILE, "utf8")) : {};
  const findings = applyBaseline(
    raw,
    baseline,
    (file) => existsSync(path.join(root, file)) && statSync(path.join(root, file)).isFile(),
  );
  if (options.base) {
    const base = git(["merge-base", options.base, "HEAD"]);
    findings.push(...baselineGrowth(readBaselineAt(base), baseline, renamesSince(base)));
  }
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
  const baselined = Object.entries(BASELINE_RULES)
    .map(([rule, spec]) => {
      if (spec.shape === "keys") return `${rule}=${(baseline[rule] ?? []).length}`;
      return `${rule}=${Object.values(baseline[rule] ?? {}).reduce((a, b) => a + b, 0)}`;
    })
    .join(" ");
  console.log(
    `sketch-lint ${findings.length === 0 ? "pass" : "fail"}: ${findings.length} findings, baseline entries ${baselined}, ${Date.now() - started}ms`,
  );
  process.exit(findings.length === 0 ? 0 : 1);
}

if (isMain(import.meta.url)) main();
