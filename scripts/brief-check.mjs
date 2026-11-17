import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Mechanical checks for music composition briefs, computed instead of left to reviewers.
// A brief is a JSON spec (format: sketches/core-loop/design-v3/sound/briefs/README.md).
//   FILE_MISSING   a pick or stem file that is not on disk under its root
//   HASH_MISMATCH  sha256 differs from the spec's, or from STEMS.sha256 for anything under assets/music_ace
//   LENGTH_RAW     a non-guide use-span reads past the tempo-stretched pick (native_seconds * native_bpm / take_bpm):
//                  pick_from_s + (to_s - from_s) > stretched + tolerance_s; or the file's ffprobe length
//                  differs from native_seconds by more than 0.25 s. A guide span is exempt, loop lets a span run past.
//   PICK_FROM_MISSING  a non-guide, non-loop use-span with from_s != 0 and no pick_from_s (the length check would guess)
//   OFF_PHRASE     an edit or span start/end more than tolerance_s from the nearest phrase boundary
//   SECTIONS_SUM   sections do not chain from 0 to `seconds`, or the journey skips/repeats/reorders one
//   SPAN_HOLE      a part uncovered for more than one bar (a mute span covers; "guide only" in a note exempts;
//                  gap: true on a span of that part marks its holes as deliberate)
//   OTHER_STEM_LEAD  a 'use' source with part 'other' that is not wholly inside its own guide_matches_pick span
//                  ({from_bar,to_bar} or {from_s,to_s}, the take span where the guide plays the pick's lead bar for bar):
//                  the pick's 'other' stem carries its lead melody, so anywhere else the source would hold two leads
//   BAD_SPEC       a required field is missing or malformed
//   unchecked      a file whose root is unavailable (or no ffprobe): reported, never a pass
// Run: node scripts/brief-check.mjs [--dir <specs dir>] [--strict] [--json]
// Exit: 1 any finding, 2 unchecked under --strict, 0 clean.

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export const DEFAULT_DIR = "sketches/core-loop/design-v3/sound/briefs";
export const PACK_DIR = "sketches/core-loop/assets/music_ace";
export const STEM_HASHES = "STEMS.sha256";
// Linux pins the system binary; elsewhere (Homebrew on macOS) it is found on PATH.
export const FFPROBE = process.platform === "linux" ? "/usr/bin/ffprobe" : "ffprobe";
export const NATIVE_LENGTH_TOL = 0.25;
export const EPS = 1e-6;

export function defaultRoots() {
  return {
    repo: repoRoot,
    music_direction:
      process.env.BRIEF_CHECK_MUSIC_DIR || path.join(os.homedir(), "Music/Scrapkeep-sound-direction/sound-bible-2026-10-16"),
    pack: path.join(repoRoot, PACK_DIR),
  };
}

export function sha256File(file) {
  return createHash("sha256").update(readFileSync(file)).digest("hex");
}

export function parseStemHashes(text) {
  const entries = [];
  for (const line of text.split("\n")) {
    const m = /^([0-9a-f]{64})\s+(.+?)\s*$/.exec(line);
    if (m) entries.push({ sha256: m[1], file: m[2] });
  }
  return entries;
}

export function probeSeconds(file) {
  const r = spawnSync(FFPROBE, ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file], { encoding: "utf8" });
  if (r.error || r.status !== 0) return null;
  const v = Number.parseFloat(r.stdout);
  return Number.isFinite(v) ? v : null;
}

export function applyDefaults(spec) {
  return {
    phrase_bars: 4,
    grid_origin_s: 0,
    tolerance_s: 0.12,
    sources: [],
    sections: [],
    journey: [],
    edits: [],
    ...spec,
  };
}

export function loadSpecs(dir) {
  const specs = [];
  for (const name of readdirSync(dir).filter((n) => n.endsWith(".json")).sort()) {
    const full = path.join(dir, name);
    let raw;
    try {
      raw = JSON.parse(readFileSync(full, "utf8"));
    } catch (error) {
      specs.push({ id: name, _file: full, _parseError: error.message });
      continue;
    }
    specs.push({ ...applyDefaults(raw), id: raw.id ?? name, _file: full });
  }
  return specs;
}

export const stretchedSeconds = (spec) => (spec.pick.native_seconds * spec.pick.native_bpm) / spec.take_bpm;
export const phraseSeconds = (spec) => (spec.phrase_bars * spec.beats_per_bar * 60) / spec.take_bpm;
export const barSeconds = (spec) => (spec.beats_per_bar * 60) / spec.take_bpm;

// Distance from t to the nearest boundary of the grid origin + n * phrase (n any integer).
export function phraseError(t, spec) {
  const p = phraseSeconds(spec);
  const k = (t - spec.grid_origin_s) / p;
  return Math.abs(k - Math.round(k)) * p;
}

// The take-timeline span [from, to] a guide_matches_pick names, or null when it is absent or malformed.
// Bars count from 0 at grid_origin_s: {from_bar: 0, to_bar: 2} is the first two bars.
export function guideMatchSpan(spec, g) {
  if (!g || typeof g !== "object") return null;
  if (num(g.from_s) && num(g.to_s)) return [g.from_s, g.to_s];
  if (num(g.from_bar) && num(g.to_bar)) return [spec.grid_origin_s + g.from_bar * barSeconds(spec), spec.grid_origin_s + g.to_bar * barSeconds(spec)];
  return null;
}

export function packAvailable(packDir) {
  const list = path.join(packDir, STEM_HASHES);
  if (!existsSync(list)) return false;
  const first = parseStemHashes(readFileSync(list, "utf8"))[0];
  return Boolean(first) && existsSync(path.join(packDir, first.file));
}

const num = (v) => typeof v === "number" && Number.isFinite(v);

function validate(spec) {
  const missing = [];
  for (const f of ["seconds", "take_bpm", "beats_per_bar"]) if (!num(spec[f])) missing.push(f);
  const p = spec.pick;
  if (!p || typeof p.file !== "string" || !["repo", "music_direction", "pack"].includes(p.root)) missing.push("pick.file/root");
  else for (const f of ["native_bpm", "native_seconds"]) if (!num(p[f])) missing.push(`pick.${f}`);
  for (const [i, s] of spec.sources.entries()) {
    if (!["drums", "bass", "other", "guide"].includes(s.part) || !["use", "mute"].includes(s.action) || !num(s.from_s) || !num(s.to_s) || (s.pick_from_s !== undefined && !num(s.pick_from_s)))
      missing.push(`sources[${i}]`);
    else if (s.guide_matches_pick !== undefined && !guideMatchSpan(spec, s.guide_matches_pick)) missing.push(`sources[${i}].guide_matches_pick`);
  }
  return missing;
}

// Check one spec. Returns { findings: [{code, id, field, message}], unchecked: [{id, field, message}] }.
export function checkSpec(rawSpec, options = {}) {
  const roots = { ...defaultRoots(), ...(options.roots ?? {}) };
  const findings = [];
  const unchecked = [];
  const id = rawSpec.id;
  const find = (code, field, message) => findings.push({ code, id, field, message });
  if (rawSpec._parseError) {
    find("BAD_SPEC", "(file)", `not valid JSON: ${rawSpec._parseError}`);
    return { findings, unchecked };
  }
  const spec = applyDefaults(rawSpec);
  const missing = validate(spec);
  if (missing.length) {
    find("BAD_SPEC", missing.join(","), `missing or malformed: ${missing.join(", ")}`);
    return { findings, unchecked };
  }
  const tol = spec.tolerance_s;
  const pick = spec.pick;
  const stretched = stretchedSeconds(spec);

  // Files: existence, hash, native length.
  const packOk = packAvailable(roots.pack);
  const stems = packOk ? parseStemHashes(readFileSync(path.join(roots.pack, STEM_HASHES), "utf8")) : [];
  const fileChecks = [{ field: "pick.file", file: pick.file, root: pick.root, sha256: pick.sha256, isPick: true }];
  spec.sources.forEach((s, i) => {
    if (s.file) fileChecks.push({ field: `sources[${i}].file`, file: s.file, root: s.root ?? pick.root, sha256: s.sha256 });
  });
  for (const fc of fileChecks) {
    const rootDir = roots[fc.root];
    const available = fc.root === "pack" ? packOk : Boolean(rootDir) && existsSync(rootDir);
    if (!available) {
      unchecked.push({ id, field: fc.field, message: `root '${fc.root}' is not available here; ${fc.file} not verified` });
      continue;
    }
    const full = path.resolve(rootDir, fc.file);
    if (!existsSync(full)) {
      find("FILE_MISSING", fc.field, `${fc.file} not found under ${fc.root}`);
      continue;
    }
    const actual = sha256File(full);
    if (fc.sha256 && actual !== fc.sha256) find("HASH_MISMATCH", fc.field, `sha256 ${actual} differs from the spec's ${fc.sha256}`);
    const packRel = path.relative(roots.pack, full);
    const entry = packOk && !packRel.startsWith("..") ? stems.find((e) => e.file === packRel.split(path.sep).join("/")) : undefined;
    if (entry && actual !== entry.sha256) find("HASH_MISMATCH", fc.field, `sha256 ${actual} differs from ${STEM_HASHES} (${entry.sha256})`);
    if (fc.isPick) {
      const len = probeSeconds(full);
      if (len === null) unchecked.push({ id, field: fc.field, message: "ffprobe could not read the file length" });
      else if (Math.abs(len - pick.native_seconds) > NATIVE_LENGTH_TOL)
        find("LENGTH_RAW", "pick.native_seconds", `ffprobe length ${len.toFixed(3)} s differs from native_seconds ${pick.native_seconds}`);
    }
  }

  // Length after tempo stretch. The span reads pick material from pick_from_s (default from_s) for to_s - from_s seconds.
  spec.sources.forEach((s, i) => {
    if (s.action !== "use" || s.part === "guide" || s.loop) return;
    if (!num(s.pick_from_s) && Math.abs(s.from_s) > EPS) {
      find("PICK_FROM_MISSING", `sources[${i}].pick_from_s`, `use span starts at ${s.from_s} s in the take; say where in the pick it starts (pick_from_s)`);
    }
    const pickFrom = num(s.pick_from_s) ? s.pick_from_s : s.from_s;
    const reach = pickFrom + (s.to_s - s.from_s);
    if (reach > stretched + tol)
      find("LENGTH_RAW", `sources[${i}].to_s`, `reads the pick to ${reach.toFixed(3)} s (from ${pickFrom} s for ${(s.to_s - s.from_s).toFixed(3)} s), past the stretched pick ${stretched.toFixed(3)} s (${pick.native_seconds} s at ${pick.native_bpm} bpm played at ${spec.take_bpm})`);
  });

  // The pick's 'other' stem carries its own lead melody: allowed only where the guide matches it bar for bar.
  spec.sources.forEach((s, i) => {
    if (s.action !== "use" || s.part !== "other") return;
    const span = guideMatchSpan(spec, s.guide_matches_pick);
    if (!span) find("OTHER_STEM_LEAD", `sources[${i}].guide_matches_pick`, `'other' is used from ${s.from_s} to ${s.to_s} s with no guide_matches_pick; the pick's other stem carries its lead, so the source would hold two leads`);
    else if (s.from_s < span[0] - tol || s.to_s > span[1] + tol)
      find("OTHER_STEM_LEAD", `sources[${i}].guide_matches_pick`, `'other' runs ${s.from_s} to ${s.to_s} s, outside the span ${span[0]} to ${span[1]} s where the guide matches the pick's lead`);
  });

  // Phrase grid.
  const phrase = phraseSeconds(spec);
  const offGrid = (field, t) => {
    const err = phraseError(t, spec);
    if (err > tol + EPS) find("OFF_PHRASE", field, `${t} s is ${err.toFixed(3)} s from the nearest ${phrase.toFixed(3)} s phrase boundary (tolerance ${tol})`);
  };
  spec.edits.forEach((t, i) => offGrid(`edits[${i}]`, t));
  spec.sources.forEach((s, i) => {
    offGrid(`sources[${i}].from_s`, s.from_s);
    offGrid(`sources[${i}].to_s`, s.to_s);
  });

  // Sections and journey.
  let cursor = 0;
  spec.sections.forEach((sec, i) => {
    if (Math.abs(sec.start_s - cursor) > EPS) find("SECTIONS_SUM", `sections[${i}].start_s`, `starts at ${sec.start_s} but the previous section ended at ${cursor}`);
    cursor = sec.end_s;
  });
  if (!spec.sections.length) find("SECTIONS_SUM", "sections", "no sections");
  else if (Math.abs(cursor - spec.seconds) > EPS) find("SECTIONS_SUM", "sections", `last section ends at ${cursor}, planned length is ${spec.seconds}`);
  const names = spec.sections.map((s) => s.name);
  const jnames = spec.journey.map((j) => j.section);
  if (names.length !== jnames.length || names.some((n, i) => n !== jnames[i]))
    find("SECTIONS_SUM", "journey", `journey [${jnames.join(", ")}] does not cover sections [${names.join(", ")}] once each in order`);

  // Holes: a use or mute span covers its part; "guide only" exempts the whole spec.
  const guideOnly = spec.sources.some((s) => /guide only/i.test(s.note ?? ""));
  if (!guideOnly) {
    const bar = barSeconds(spec);
    const parts = new Set(["drums", "bass", "other", ...spec.sources.map((s) => s.part)]);
    for (const part of parts) {
      if (spec.sources.some((s) => s.part === part && s.gap)) continue;
      const spans = spec.sources.filter((s) => s.part === part).map((s) => [s.from_s, s.to_s]).sort((a, b) => a[0] - b[0]);
      let at = 0;
      for (const [from, to] of spans) {
        if (from - at > bar + EPS) find("SPAN_HOLE", `part:${part}`, `${part} uncovered from ${at} to ${from} (${(from - at).toFixed(3)} s, one bar is ${bar.toFixed(3)} s)`);
        at = Math.max(at, to);
      }
      if (spec.seconds - at > bar + EPS) find("SPAN_HOLE", `part:${part}`, `${part} uncovered from ${at} to ${spec.seconds} (${(spec.seconds - at).toFixed(3)} s, one bar is ${bar.toFixed(3)} s)`);
    }
  }
  return { findings, unchecked };
}

export function checkAll(specs, options = {}) {
  const findings = [];
  const unchecked = [];
  for (const spec of specs) {
    const r = checkSpec(spec, options);
    findings.push(...r.findings);
    unchecked.push(...r.unchecked);
  }
  return { findings, unchecked, specs: specs.length };
}

export function exitCode(result, strict) {
  if (result.findings.length) return 1;
  if (strict && result.unchecked.length) return 2;
  return 0;
}

function main() {
  const args = process.argv.slice(2);
  const strict = args.includes("--strict");
  const json = args.includes("--json");
  const di = args.indexOf("--dir");
  const dir = path.resolve(di >= 0 ? args[di + 1] : path.join(repoRoot, DEFAULT_DIR));
  if (!existsSync(dir)) {
    console.log(`brief-check: no specs directory at ${dir}; nothing to check.`);
    process.exit(0);
  }
  const specs = loadSpecs(dir);
  const result = checkAll(specs);
  if (json) console.log(JSON.stringify(result, null, 2));
  else {
    for (const f of result.findings) console.log(`${f.code}  ${f.id}  ${f.field}  ${f.message}`);
    for (const u of result.unchecked) console.log(`unchecked  ${u.id}  ${u.field}  ${u.message}`);
    console.log(`brief-check: ${result.specs} spec(s), ${result.findings.length} finding(s), ${result.unchecked.length} unchecked.`);
  }
  process.exit(exitCode(result, strict));
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
