import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const RAW_EXTENSIONS = ["bin", "dat", "csv", "txt", "tsv", "raw", "ndjson"];
const literal = new RegExp(`"([^"\\n]*\\.(?:${RAW_EXTENSIONS.join("|")}))"`, "g");

export function globToRegExp(glob) {
  const body = glob
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replace(/\*/g, ".*")
    .replace(/\?/g, ".");
  return new RegExp("^" + body + "$", "i");
}

export function filterList(value) {
  return value
    .replace(/^"(.*)"$/, "$1")
    .split(",")
    .map((item) => item.trim().replace(/^res:\/\//, ""))
    .filter(Boolean);
}

export function covered(file, patterns) {
  return patterns.some((pattern) => globToRegExp(pattern).test(file));
}

export function rawLiterals(source) {
  const found = [];
  for (const match of source.matchAll(literal)) {
    const text = match[1];
    found.push({ text, res: text.startsWith("res://") ? text.slice(6) : null });
  }
  return found;
}

export function resolveLiterals(literals, projectFiles) {
  const files = new Set();
  const unresolved = [];
  for (const { text, res } of literals) {
    let hits = [];
    if (res !== null) {
      const pattern = globToRegExp(res.replace(/%[sd]/g, "*"));
      hits = projectFiles.filter((file) => pattern.test(file));
      if (hits.length === 0) unresolved.push(text);
    } else if (text.startsWith("/")) {
      hits = projectFiles.filter((file) => file.endsWith(text));
    }
    for (const hit of hits) files.add(hit);
  }
  return { files: [...files].sort(), unresolved };
}

export function uncoveredFiles({ files, include, exclude = [] }) {
  return files.filter((file) => !covered(file, exclude) && !covered(file, include));
}

function walk(dir, base, out) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const rel = base ? base + "/" + entry.name : entry.name;
    if (entry.isDirectory()) {
      if (entry.name !== ".godot") walk(path.join(dir, entry.name), rel, out);
    } else out.push(rel);
  }
  return out;
}

export function checkPreset({ sketch, presetText, presetName = "Linux x64" }) {
  const block = new RegExp(
    `\\[preset\\.\\d+\\]\\s*\\nname="${presetName}"[\\s\\S]*?(?=\\n\\[preset\\.\\d+\\.options\\])`,
  ).exec(presetText);
  if (!block) return { problems: [`preset "${presetName}" not found`], files: [] };
  const field = (name) => new RegExp(`^${name}=(.*)$`, "m").exec(block[0])?.[1] ?? '""';
  const include = filterList(field("include_filter"));
  const exclude = filterList(field("exclude_filter"));
  const projectFiles = walk(sketch, "", []);
  const literals = [];
  for (const rel of projectFiles.filter((file) => file.startsWith("src/") && file.endsWith(".gd")))
    literals.push(...rawLiterals(readFileSync(path.join(sketch, rel), "utf8")));
  const { files, unresolved } = resolveLiterals(literals, projectFiles);
  const problems = uncoveredFiles({ files, include, exclude }).map(
    (file) => `${file} is opened by the game but no include_filter pattern covers it`,
  );
  for (const text of unresolved) problems.push(`${text} names no file in the project`);
  if (files.length === 0) problems.push("no raw data file found: the scan matched nothing");
  return { problems, files };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const sketch = path.join(root, "sketches/core-loop");
  const presets = process.argv.includes("--preset")
    ? [process.argv[process.argv.indexOf("--preset") + 1]]
    : ["Linux x64", "Linux x64 proof"];
  const text = readFileSync(path.join(sketch, "export_presets.cfg"), "utf8");
  let bad = 0;
  for (const presetName of presets) {
    const { problems, files } = checkPreset({ sketch, presetText: text, presetName });
    console.log(
      `export include check "${presetName}": ${files.length} raw files read by the game, ${problems.length} problems`,
    );
    for (const problem of problems) console.log("  " + problem);
    bad += problems.length;
  }
  process.exit(bad > 0 ? 1 : 0);
}
