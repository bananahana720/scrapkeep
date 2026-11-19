// Deep-modules sweep: flags new shallow wrappers, private reach-ins, wide signatures,
// leaked string keys and growing giant files in the GDScript a promotion brought in.
// It reports candidates for a reader; it fails nothing. Checklist: project-guide/handoff/DEEP-SWEEP.md.
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SRC = "sketches/core-loop/src/";
// Tools are read for private reach-ins only: a capture or trial script that drives the game through its
// underscore members breaks on the next refactor and proves less than it claims.
const TOOLS = "sketches/core-loop/tools/";
const WIDE_PARAMS = 6;
const WIDE_BOOLS = 3;
const GIANT_LINES = 1500;
const GIANT_GROWTH = 100;
const LEAK_FILES = 3;
// Schema modules that own their keys: a key they spell is named, not leaked (event kinds are the bus contract).
const KEY_OWNERS = [`${SRC}core/event_kinds.gd`];

const git = (...args) => execFileSync("git", args, { cwd: root, encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });

const strip = (line) => line.replace(/#.*$/, "").trimEnd();

// Functions in a GDScript file: name, params, first line, body lines (comments and blanks dropped).
export function parseFuncs(text) {
  const lines = text.split("\n");
  const funcs = [];
  for (let i = 0; i < lines.length; i++) {
    const head = lines[i].match(/^(\s*)(?:static\s+)?func\s+(\w+)\s*\(/);
    if (!head) continue;
    const indent = head[1].length;
    let sig = lines[i];
    let j = i;
    while (!/\)\s*(->\s*[\w\[\], .]+)?\s*:\s*(#.*)?$/.test(strip(sig)) && j + 1 < lines.length) sig += " " + lines[++j].trim();
    const inside = sig.slice(sig.indexOf("(") + 1, sig.lastIndexOf(")"));
    const params = splitTop(inside).map((p) => p.trim()).filter(Boolean).map((p) => {
      const name = p.match(/^(\w+)/)?.[1] ?? p;
      return { name, bool: /:\s*bool\b/.test(p) || /:?=\s*(true|false)\s*$/.test(p) };
    });
    const body = [];
    let k = j + 1;
    for (; k < lines.length; k++) {
      const raw = lines[k];
      if (raw.trim() === "" || raw.trim().startsWith("#")) continue;
      if (raw.match(/^(\s*)/)[1].length <= indent) break;
      body.push(strip(raw).trim());
    }
    funcs.push({ name: head[2], params, line: i + 1, body });
    i = j;
  }
  return funcs;
}

function splitTop(text) {
  const out = [];
  let depth = 0;
  let cur = "";
  let quote = null;
  for (const ch of text) {
    if (quote) { cur += ch; if (ch === quote) quote = null; continue; }
    if (ch === '"' || ch === "'") { quote = ch; cur += ch; continue; }
    if ("([{".includes(ch)) depth++;
    if (")]}".includes(ch)) depth--;
    if (ch === "," && depth === 0) { out.push(cur); cur = ""; continue; }
    cur += ch;
  }
  if (cur.trim()) out.push(cur);
  return out;
}

// D1: a function whose whole body forwards its own parameters, in order, to one other call.
export function passThroughs(funcs) {
  return funcs.filter((f) => {
    if (f.body.length !== 1 || f.name.startsWith("_")) return false;
    const call = f.body[0].match(/^(?:return\s+)?([\w.]+)\((.*)\)$/);
    if (!call || !call[1].includes(".")) return false;
    const args = splitTop(call[2]).map((a) => a.trim()).filter(Boolean);
    return args.length === f.params.length && args.every((a, n) => a === f.params[n].name);
  }).map((f) => ({ line: f.line, message: `${f.name}() only forwards to ${f.body[0].replace(/^return\s+/, "")}` }));
}

// D3: wide signatures.
export function wideSignatures(funcs) {
  return funcs.filter((f) => f.params.length >= WIDE_PARAMS || f.params.filter((p) => p.bool).length >= WIDE_BOOLS)
    .map((f) => ({ line: f.line, message: `${f.name}() takes ${f.params.length} params (${f.params.filter((p) => p.bool).length} bool)` }));
}

// The owner may be a chain (game.flow.warden._age), and self.other._member is still a reach into other.
// super._member is a class calling its own parent, and self._member a file reading its own field, neither a reach.
// A chain may start at the file's own private field, with or without self (_game.flow._set_state): the reach is into flow.
const reachIn = /(?<![\w.])(?!super\._)(?:self\.)?(?!self\b)((?:_?[a-z]\w*\.)*_?[a-z]\w*)\.(_[a-z]\w*)\b|\.(?:get|set|call)\(\s*"(_[a-z]\w*)"/;

// D2: code that touches another object's underscore members. Lines are [number, text] pairs.
export function reachIns(lines) {
  const out = [];
  for (const [number, raw] of lines) {
    const code = strip(raw);
    const hit = code.match(reachIn);
    if (hit) out.push({ line: number, message: `reaches into ${hit[1] ? `${hit[1]}.${hit[2]}` : hit[3]}` });
  }
  return out;
}

// Snake-case string keys (likely dictionary keys or state names) on the given lines.
export function stringKeys(lines) {
  const keys = new Set();
  for (const [, raw] of lines) {
    for (const m of strip(raw).matchAll(/"([a-z][a-z0-9]*(?:_[a-z0-9]+)+)"/g)) keys.add(m[1]);
  }
  return keys;
}

// Added lines per file from a unified diff with zero context.
export function addedLines(diff) {
  const files = new Map();
  let file = null;
  let number = 0;
  for (const line of diff.split("\n")) {
    if (line.startsWith("+++ ")) { file = line.slice(4).replace(/^b\//, ""); if (!files.has(file)) files.set(file, []); continue; }
    const hunk = line.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/);
    if (hunk) { number = Number(hunk[1]); continue; }
    if (file && line.startsWith("+")) files.get(file).push([number++, line.slice(1)]);
  }
  return files;
}

function defaultBase(head) {
  const parents = git("rev-list", "--parents", "-n", "1", head).trim().split(" ");
  if (parents.length < 3) throw new Error(`${head} is not a merge; pass --base <last promoted main>`);
  return parents[1];
}

export function sweep({ base, head, read, diff, listSrc, linesAt }) {
  const added = addedLines(diff);
  const findings = [];
  const add = (rule, file, item) => findings.push({ rule, path: file, ...item });
  const leaks = new Map();
  const allSrc = listSrc();
  for (const [file, lines] of added) {
    if (!file.endsWith(".gd") || lines.length === 0) continue;
    if (file.startsWith(TOOLS)) { reachIns(lines).forEach((item) => add("D2", file, item)); continue; }
    if (!file.startsWith(SRC)) continue;
    const text = read(file);
    const changed = new Set(lines.map(([n]) => n));
    const funcs = parseFuncs(text).filter((f) => changed.has(f.line));
    passThroughs(funcs).forEach((item) => add("D1", file, item));
    reachIns(lines).forEach((item) => add("D2", file, item));
    wideSignatures(funcs).forEach((item) => add("D3", file, item));
    for (const key of stringKeys(lines)) {
      if (!leaks.has(key)) leaks.set(key, new Set());
      leaks.get(key).add(file);
    }
    const now = text.split("\n").length;
    const before = linesAt(base, file);
    if (now >= GIANT_LINES && now - before >= GIANT_GROWTH) add("D5", file, { line: 1, message: `${before} -> ${now} lines; look for a module to split out` });
  }
  const owned = KEY_OWNERS.map((f) => read(f));
  for (const [key, origins] of leaks) {
    if (owned.some((text) => text.includes(`"${key}"`))) continue;
    const users = allSrc.filter((f) => read(f).includes(`"${key}"`));
    if (users.length >= LEAK_FILES) add("D4", [...origins][0], { line: 0, message: `"${key}" is spelled in ${users.length} src files: ${users.map((u) => u.slice(SRC.length)).slice(0, 6).join(", ")}${users.length > 6 ? ", ..." : ""}` });
  }
  return findings;
}

export function report({ base, head, findings }) {
  const names = { D1: "Pass-through wrappers", D2: "Private reach-ins", D3: "Wide signatures", D4: "String keys spelled in 3+ files", D5: "Giant files still growing" };
  const out = [`# Deep-modules sweep ${base.slice(0, 8)}..${head.slice(0, 8)}`, "", `${findings.length} candidates. Each is a lead for a reader, not a defect; triage with project-guide/handoff/DEEP-SWEEP.md.`, ""];
  for (const rule of Object.keys(names)) {
    const rows = findings.filter((f) => f.rule === rule);
    out.push(`## ${rule} ${names[rule]} (${rows.length})`, "");
    rows.forEach((f) => out.push(`- ${f.path}${f.line ? `:${f.line}` : ""} ${f.message}`));
    if (rows.length) out.push("");
  }
  return out.join("\n").trimEnd() + "\n";
}

function main(argv) {
  const opt = (name) => { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : undefined; };
  const head = git("rev-parse", opt("--head") ?? "HEAD").trim();
  const base = git("rev-parse", opt("--base") ?? defaultBase(head)).trim();
  const cache = new Map();
  const read = (file) => {
    if (!cache.has(file)) { try { cache.set(file, git("show", `${head}:${file}`)); } catch { cache.set(file, ""); } }
    return cache.get(file);
  };
  const linesAt = (ref, file) => { try { return execFileSync("git", ["show", `${ref}:${file}`], { cwd: root, encoding: "utf8", maxBuffer: 256 * 1024 * 1024, stdio: ["ignore", "pipe", "ignore"] }).split("\n").length; } catch { return 0; } };
  const listSrc = () => git("ls-tree", "-r", "--name-only", head, SRC).split("\n").filter((f) => f.endsWith(".gd"));
  const diff = git("diff", "--unified=0", "--no-color", base, head, "--", SRC, TOOLS);
  const text = report({ base, head, findings: sweep({ base, head, read, diff, listSrc, linesAt }) });
  const out = opt("--out");
  if (out) writeFileSync(out, text); else process.stdout.write(text);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main(process.argv.slice(2));
