// One line per run from a core-loop runs.ndjson, so what happened in a sitting can be
// read without asking the player. Records are cumulative (each line carries the whole
// run so far), so the last line of a run_id is the run. Keys a record lacks print as "-".
//
//   node scripts/run-summary.mjs [--last N] [--file path]
//
// With no --file it reads the game's own log. Godot puts user:// for a project with no
// custom user dir at $XDG_DATA_HOME/godot/app_userdata/<config/name>/ (default
// ~/.local/share/godot/...); with config/use_custom_user_dir=true it is
// $XDG_DATA_HOME/<config/custom_user_dir_name>/ instead. Both come from the sketch's project.godot.
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sketch = path.join(root, "sketches", "core-loop");
const DASH = "-";

function projectSetting(key, fallback) {
  const file = path.join(sketch, "project.godot");
  if (!existsSync(file)) {
    return fallback;
  } else {
    const found = readFileSync(file, "utf8").match(new RegExp(`^${key}=(.+)$`, "m"));
    if (found === null) {
      return fallback;
    } else {
      return found[1].trim().replace(/^"|"$/g, "");
    }
  }
}

export function defaultLog(env = process.env, home = homedir()) {
  const data = env.XDG_DATA_HOME || path.join(home, ".local", "share");
  if (projectSetting("config/use_custom_user_dir", "false") === "true") {
    return path.join(data, projectSetting("config/custom_user_dir_name", "core-loop"), "runs.ndjson");
  }
  const name = projectSetting("config/name", "core-loop");
  return path.join(data, "godot", "app_userdata", name, "runs.ndjson");
}

export function readRuns(text) {
  const byId = new Map();
  for (const line of text.split("\n")) {
    if (line.trim() === "") {
      continue;
    }
    let record = null;
    try {
      record = JSON.parse(line);
    } catch {
      record = null;
    }
    if (record !== null && typeof record === "object") {
      byId.set(record.run_id ?? `line-${byId.size}`, record);
    }
  }
  return [...byId.values()];
}

function whenOf(record) {
  const stamp = Number.parseInt(String(record.run_id ?? "").split("-")[0], 10);
  if (!Number.isFinite(stamp) || stamp < 1e9) {
    return DASH;
  } else {
    return new Date(stamp * 1000).toISOString().slice(0, 16).replace("T", " ") + "Z";
  }
}

function seconds(ticks, rate) {
  if (typeof ticks !== "number") {
    return DASH;
  } else {
    return `${(ticks / rate).toFixed(1)}s`;
  }
}

// A pack row is a faction string in old records and {faction, kinds} since wave 13.
function packLabel(item) {
  if (item && typeof item === "object") {
    const kinds = Array.isArray(item.kinds) ? item.kinds.join("+") : "";
    return kinds ? `${item.faction ?? DASH}[${kinds}]` : `${item.faction ?? DASH}`;
  } else {
    return item;
  }
}

function tally(items) {
  const counts = new Map();
  for (const raw of items) {
    const item = packLabel(raw);
    counts.set(item, (counts.get(item) ?? 0) + 1);
  }
  if (counts.size === 0) {
    return DASH;
  } else {
    return [...counts].map(([name, count]) => `${name}x${count}`).join(",");
  }
}

export function summarize(record, rate = 60) {
  const stages = Array.isArray(record.stages) ? record.stages : [];
  const last = stages.length > 0 ? stages[stages.length - 1] : null;
  const postureRows = stages.map((row) => row.posture).filter((row) => row && typeof row === "object");
  const sum = (key) => postureRows.reduce((total, row) => total + (Number(row[key]) || 0), 0);
  const causes = new Map();
  for (const row of stages) {
    for (const [id, count] of Object.entries(row.causes ?? {})) {
      causes.set(id, (causes.get(id) ?? 0) + Number(count));
    }
  }
  const causeText = causes.size === 0 ? DASH : [...causes].map(([id, count]) => `${id}x${count}`).join(",");
  const packs = stages.flatMap((row) => (Array.isArray(row.packs) ? row.packs : []));
  const posture = postureRows.length === 0 ? `staggers ${DASH} chunks ${DASH}` : `staggers ${sum("staggers")} chunks ${sum("chunks_lost")}`;
  return [
    whenOf(record),
    record.class ?? DASH,
    record.table ?? DASH,
    record.outcome ?? DASH,
    last === null ? `stage ${DASH}` : `stage ${last.stage}`,
    `engage ${seconds(last?.ticks_to_warden_engaged, rate)} break ${seconds(last?.ticks_to_warden_break, rate)}`,
    posture,
    `bites ${record.bites ?? DASH} smashes ${record.smashes ?? DASH}`,
    `packs ${Array.isArray(record.stages) && "packs" in (last ?? {}) ? tally(packs) : DASH}`,
    `causes ${record.stages && last && "causes" in last ? causeText : DASH}`,
  ].join(" | ");
}

export function parseArgs(argv) {
  const options = { last: null, file: null };
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === "--last") {
      options.last = Number.parseInt(argv[index + 1], 10);
      index += 1;
    } else if (argv[index] === "--file") {
      options.file = argv[index + 1];
      index += 1;
    }
  }
  return options;
}

function main(argv) {
  const options = parseArgs(argv);
  const file = options.file ?? defaultLog();
  if (!existsSync(file)) {
    console.error(`No run log at ${file}`);
    process.exit(2);
  }
  const rate = Number.parseInt(projectSetting("common/physics_ticks_per_second", "60"), 10);
  let runs = readRuns(readFileSync(file, "utf8"));
  if (Number.isFinite(options.last) && options.last > 0) {
    runs = runs.slice(-options.last);
  }
  console.log(`# ${file}`);
  for (const record of runs) {
    console.log(summarize(record, rate));
  }
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2));
}
