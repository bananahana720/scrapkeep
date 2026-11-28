#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync } from "node:fs";
import path from "node:path";
import { isMain } from "./lib/cli.mjs";

function git(cwd, args) {
  const r = spawnSync("git", args, { cwd, encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });
  if (r.status > 1) throw new Error(`git ${args.join(" ")}: ${r.stderr}`);
  return r.stdout;
}

function needles(top, rel) {
  const out = [{ text: path.posix.basename(rel), word: false }];
  const abs = path.join(top, rel);
  if (rel.endsWith(".py")) out.push({ text: path.posix.basename(rel, ".py"), word: true });
  if (rel.endsWith(".gd") && existsSync(abs)) {
    const m = readFileSync(abs, "utf8").match(/^class_name\s+(\w+)/m);
    if (m) out.push({ text: m[1], word: true });
  }
  return out;
}

export function findMentions(files, cwd = process.cwd()) {
  const top = git(cwd, ["rev-parse", "--show-toplevel"]).trim();
  const base = realpathSync(cwd);
  const rels = files.map((f) =>
    path.relative(top, path.resolve(base, f)).split(path.sep).join("/"),
  );
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
  let mentioned = false;
  for (const [rel, hits] of findMentions(files)) {
    console.log(`${rel}: ${hits.length} mention${hits.length === 1 ? "" : "s"}`);
    for (const h of hits) console.log(`  ${h}`);
    if (hits.length) mentioned = true;
  }
  process.exit(mentioned ? 1 : 0);
}
