#!/usr/bin/env node

import { readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { isMain } from "./lib/cli.mjs";
import { REPO_ROOT } from "./lib/git.mjs";

export const REGISTRY_DIR = "assets/registry.d";
export const LOADER = ["loader"];
export const GENERATORS = [["recipe"], ["provenance", "recipe"], ["provenance", "helper"]];

const FIRST_TOKEN = /^[^\s(,;]+/;
const NAME = /^[A-Za-z_]\w*$/;
const DECLARATION = {
  ".gd": (name) =>
    new RegExp(`^\\s*(?:static\\s+|@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*func\\s+${name}\\s*\\(`, "m"),
  ".py": (name) => new RegExp(`^\\s*(?:async\\s+)?def\\s+${name}\\s*\\(`, "m"),
};

export function codeRef(text) {
  if (typeof text !== "string") return null;
  const token = FIRST_TOKEN.exec(text.trim())?.[0] ?? "";
  if (!token.includes("/") && !/\.[A-Za-z0-9]+(?::[^/]*)?$/.test(token)) return null;
  const bare = token.replace(/^res:\/\//, "");
  const colon = bare.indexOf(":");
  return colon < 0
    ? { token, file: bare, name: null }
    : { token, file: bare.slice(0, colon), name: bare.slice(colon + 1) };
}

export function registryRows(project) {
  const dir = path.join(project, REGISTRY_DIR);
  const names = readdirSync(dir)
    .filter((name) => name.endsWith(".json"))
    .sort();
  if (names.length === 0) throw new Error(`${REGISTRY_DIR} holds no .json file`);
  const rows = [];
  for (const name of names) {
    const doc = JSON.parse(readFileSync(path.join(dir, name), "utf8"));
    if (!Array.isArray(doc?.assets))
      throw new Error(`${REGISTRY_DIR}/${name}: expected an object with an assets array`);
    for (const row of doc.assets) {
      if (row === null || typeof row !== "object" || Array.isArray(row))
        throw new Error(`${REGISTRY_DIR}/${name}: an asset row is not an object`);
      rows.push({ fragment: name, row });
    }
  }
  if (rows.length === 0) throw new Error(`${REGISTRY_DIR} holds no asset row`);
  return rows;
}

function problem(project, ref, read) {
  const abs = path.resolve(project, ref.file);
  const rel = path.relative(project, abs);
  if (rel === "" || rel.startsWith("..") || path.isAbsolute(rel)) return "lies outside the project";
  let isFile = false;
  try {
    isFile = statSync(abs).isFile();
  } catch {
    return "names a file that does not exist";
  }
  if (!isFile) return "names a folder, not a file";
  if (ref.name === null) return null;
  if (!NAME.test(ref.name)) return `names ":${ref.name}", which is not a function name`;
  const declaration = DECLARATION[path.extname(ref.file)];
  if (!declaration) return `names a function in a ${path.extname(ref.file) || "plain"} file`;
  return declaration(ref.name).test(read(abs))
    ? null
    : `names ${ref.name}, which the file does not define`;
}

const field = (row, keys) => keys.reduce((value, key) => value?.[key], row);

export function brokenRefs(project) {
  const sources = new Map();
  const read = (abs) => {
    if (!sources.has(abs)) sources.set(abs, readFileSync(abs, "utf8"));
    return sources.get(abs);
  };
  const counts = { rows: 0, loaders: 0, generators: 0 };
  const findings = [];
  for (const { fragment, row } of registryRows(project)) {
    counts.rows++;
    for (const keys of [LOADER, ...GENERATORS]) {
      const ref = codeRef(field(row, keys));
      if (ref === null) continue;
      counts[keys === LOADER ? "loaders" : "generators"]++;
      const why = problem(project, ref, read);
      if (why)
        findings.push(`${fragment} ${row.id ?? row.path}: ${keys.join(".")} ${ref.token} ${why}`);
    }
  }
  if (counts.loaders === 0) throw new Error(`no row in ${REGISTRY_DIR} names a loader by path`);
  if (counts.generators === 0)
    throw new Error(`no row in ${REGISTRY_DIR} names a generator by path`);
  return { counts, findings };
}

export function main(argv, { log = console.log, error = console.error } = {}) {
  let project = path.join(REPO_ROOT, "sketches/core-loop");
  if (argv.length === 2 && argv[0] === "--project") project = path.resolve(argv[1]);
  else if (argv.length > 0) {
    error("usage: node scripts/registry-refs.mjs [--project <core-loop folder>]");
    return 2;
  }
  try {
    const { counts, findings } = brokenRefs(project);
    for (const line of findings) log(line);
    log(
      `registry refs: ${findings.length === 0 ? "PASS" : `FAIL (${findings.length})`}, ${counts.rows} rows, ${counts.loaders} path loaders, ${counts.generators} path generators`,
    );
    return findings.length === 0 ? 0 : 1;
  } catch (err) {
    error(`registry refs: the registry could not be read, so nothing is checked: ${err.message}`);
    return 2;
  }
}

if (isMain(import.meta.url)) process.exitCode = main(process.argv.slice(2));
