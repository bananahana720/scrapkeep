#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, statSync } from "node:fs";
import path from "node:path";
import { isMain } from "./lib/cli.mjs";

function git(cwd, args) {
  const r = spawnSync("git", args, { cwd, encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });
  if (r.error || r.status === null || r.status > 1) {
    throw new Error(`git ${args.join(" ")} failed: ${r.error?.message ?? r.stderr}`);
  }
  return r.stdout;
}

function needles(top, rel) {
  const out = [{ text: path.posix.basename(rel), word: false }];
  const abs = path.join(top, rel);
  if (rel.endsWith(".py")) out.push({ text: path.posix.basename(rel, ".py"), word: true });
  if (rel.endsWith(".gd")) {
    const m = readFileSync(abs, "utf8").match(/^class_name\s+(\w+)/m);
    if (m) out.push({ text: m[1], word: true });
    const uid = existsSync(`${abs}.uid`) && readFileSync(`${abs}.uid`, "utf8").match(/uid:\/\/\w+/);
    if (uid) out.push({ text: uid[0], word: false });
  }
  return out;
}

function outside(rel) {
  return rel === ".." || rel.startsWith("../") || path.isAbsolute(rel);
}

function why(top, rel, tracked) {
  const abs = path.join(top, rel);
  if (outside(rel)) return "lies outside the repository";
  if (!existsSync(abs)) return "does not exist";
  if (statSync(abs).isDirectory()) return "is a directory";
  return tracked.has(rel) ? null : "is not tracked by git";
}

export function badPaths(files, cwd = process.cwd()) {
  const { top, rels } = resolve(files, cwd);
  const inside = rels.filter((r) => !outside(r));
  const tracked = new Set(
    inside.length
      ? git(top, ["--literal-pathspecs", "ls-files", "-z", "--", ...inside]).split("\0")
      : [],
  );
  return files.flatMap((f, i) => {
    const reason = why(top, rels[i], tracked);
    return reason
      ? [`${f}: ${reason}; pass a path to a tracked file, relative to where you run the command`]
      : [];
  });
}

function resolve(files, cwd) {
  const top = realpathSync(git(cwd, ["rev-parse", "--show-toplevel"]).trim());
  const base = realpathSync(cwd);
  const rels = files.map((f) =>
    path.relative(top, path.resolve(base, f)).split(path.sep).join("/"),
  );
  return { top, rels };
}

export function findMentions(files, cwd = process.cwd()) {
  const bad = badPaths(files, cwd);
  if (bad.length) throw new Error(bad.join("\n"));
  const { top, rels } = resolve(files, cwd);
  const skip = new Set(rels.flatMap((r) => [r, `${r}.uid`]));
  const result = new Map();
  for (const rel of rels) {
    const hits = new Set();
    for (const n of needles(top, rel)) {
      const args = ["grep", "-n", "-I", "-F", ...(n.word ? ["-w"] : []), "-e", n.text];
      for (const line of git(top, args).split("\n")) {
        const m = line.match(/^([^:]+):(\d+):(.*)$/);
        if (m && !skip.has(m[1])) hits.add(`${m[1]}:${m[2]}: ${m[3].trim().slice(0, 160)}`);
      }
    }
    result.set(rel, [...hits].sort());
  }
  return result;
}

if (isMain(import.meta.url)) {
  const files = process.argv.slice(2);
  if (files.length === 0) {
    console.error("usage: node scripts/no-caller.mjs <file>...");
    process.exit(2);
  }
  let found;
  try {
    const bad = badPaths(files);
    if (bad.length) {
      for (const line of bad) console.error(line);
      process.exit(2);
    }
    found = findMentions(files);
  } catch (err) {
    console.error(`the search could not run, so nothing is known about callers: ${err.message}`);
    process.exit(2);
  }
  let mentioned = false;
  for (const [rel, hits] of found) {
    console.log(`${rel}: ${hits.length} mention${hits.length === 1 ? "" : "s"}`);
    for (const h of hits) console.log(`  ${h}`);
    if (hits.length) mentioned = true;
  }
  process.exit(mentioned ? 1 : 0);
}
