import { copyFileSync, existsSync, mkdirSync, readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HASHES = "STEMS.sha256";
const MUSIC = path.join("sketches", "core-loop", "assets", "music_ace");

const sha256 = (file) => createHash("sha256").update(readFileSync(file)).digest("hex");

export function parseHashes(text) {
  const out = new Map();
  for (const line of text.split("\n")) {
    const m = /^([0-9a-f]{64})\s+(\S.*)$/.exec(line.trim());
    if (m) out.set(m[2], m[1]);
  }
  return out;
}

export function sync(to, sources) {
  const hashFile = path.join(to, HASHES);
  if (!existsSync(hashFile))
    throw new Error(
      `${hashFile}: no hash list in the target (run scripts/music/mx stem-hashes in a checkout that holds the Oggs)`,
    );
  const listed = parseHashes(readFileSync(hashFile, "utf8"));
  const result = { copied: [], present: [], mismatched: [], missing: [] };
  for (const [rel, hash] of listed) {
    const dest = path.join(to, rel);
    if (existsSync(dest)) {
      if (sha256(dest) === hash) result.present.push(rel);
      else
        result.mismatched.push({
          file: rel,
          why: "the file here has a different sha256 and was left alone",
        });
      continue;
    }
    let found = null;
    let differs = null;
    for (const dir of sources) {
      const src = path.join(dir, rel);
      if (!existsSync(src)) continue;
      if (sha256(src) === hash) {
        found = src;
        break;
      }
      differs = src;
    }
    if (found) {
      mkdirSync(path.dirname(dest), { recursive: true });
      copyFileSync(found, dest);
      if (sha256(dest) !== hash)
        result.mismatched.push({ file: rel, why: `copy from ${found} does not hash as listed` });
      else result.copied.push(rel);
    } else if (differs)
      result.mismatched.push({
        file: rel,
        why: `${differs} has a different sha256 than listed; not copied`,
      });
    else result.missing.push(rel);
  }
  return result;
}

export function defaultSources(repo, home = os.homedir()) {
  const common = execFileSync("git", ["-C", repo, "rev-parse", "--git-common-dir"], {
    encoding: "utf8",
  }).trim();
  const main = path.resolve(repo, common, "..");
  const scratch = path.join(home, "scratch");
  return [
    path.join(main, MUSIC),
    path.join(scratch, "w46", "music_ace-v2"),
    path.join(scratch, "w33", "music_ace-full"),
    path.join(scratch, "w19", "music_ace-full"),
    path.join(scratch, "w18", "music_ace-full"),
    path.join(scratch, "w17", "music_ace-full"),
    path.join(scratch, "repage", "music_ace"),
  ];
}

function main(argv) {
  const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const take = (name) => argv.flatMap((a, i) => (a === name ? [argv[i + 1]] : []));
  const to = take("--to")[0] ?? path.join(repo, MUSIC);
  const from = take("--from");
  const sources = (from.length ? from : defaultSources(repo)).filter(
    (d) => path.resolve(d) !== path.resolve(to),
  );
  const r = sync(to, sources);
  for (const m of r.mismatched) console.log(`mismatched  ${m.file}: ${m.why}`);
  for (const f of r.missing) console.log(`missing     ${f}: no source holds it`);
  console.log(
    `stems-sync: ${r.copied.length} copied, ${r.present.length} present, ${r.mismatched.length} mismatched, ${r.missing.length} missing (target ${to})`,
  );
  return r.mismatched.length || r.missing.length ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  process.exit(main(process.argv.slice(2)));
