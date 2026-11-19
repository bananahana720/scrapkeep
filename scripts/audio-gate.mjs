import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// The alpha's audio check for sketches/core-loop, the "Sound and music" half of the placeholder gate.
//   cue        a special-enemy or boss cue named in design-v3/sound/INTEGRATION.md that the game cannot
//              play yet: no sfx_bank.gd recipe or audio file for a sound, no music_ace theme, clip or
//              file for a track. A missing cue counts as a placeholder (Andrew, 17 Oct 00:45Z), so
//              placeholder-gate.mjs reports these too.
//   loudness   integrated loudness (ffmpeg ebur128) more than 0.5 LU from -16 LUFS (MIX-CHECK target)
//   peak       true peak above -1 dBTP
//   seam       a looping track whose wrap from its last sample to its loop point steps further than
//              the loop's own 99.9th-percentile sample step, the measure package_music.py used for
//              the warden loop: an audible click
//   stale      a packed Ogg that does not match what its manifest or STEMS.sha256 records: another
//              mix under the same file name (a pack whose manifest was rewritten but whose Oggs were
//              not), decoded length different from sample_count, loudness more than 0.3 LU from the
//              clip's recorded measured.lufs, or a sha256 that differs from STEMS.sha256. The Oggs are
//              gitignored, so the manifest and the hash list are what a checkout can compare them to.
//   unchecked  a track whose audio is not on disk, or no ffmpeg; never counted as a pass
// Game clips are measured as the engine plays them: stems summed, plus the manifest's level_db.
// Loudness skips clips and files under 10 s (stingers, fanfares, short beds): the target is EBU R 128
// integrated programme loudness (ITU-R BS.1770 gating), a whole-programme measure that means little
// over a few seconds. True peak (BS.1770 4x oversampled) and seams are checked on every clip.
// Run: node scripts/audio-gate.mjs [--project <dir>] [--music <dir>]... [--loops <regex>] [--json] [--cues-only]

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export const TARGET_LUFS = -16;
export const LUFS_TOL = 0.5;
export const MAX_TRUE_PEAK = -1;
export const MIN_LOUDNESS_SECONDS = 10;
export const SEAM_PERCENTILE = 0.999;
export const AUDIO_EXT = [".wav", ".ogg", ".mp3", ".flac"];
export const SFX_BANK = "src/presentation/sfx_bank.gd";
export const MUSIC_DIR = "assets/music_ace";
export const STEM_HASHES = "STEMS.sha256";
export const MANIFEST_LUFS_TOL = 0.3;

// INTEGRATION.md section 7 item 5: each special's presence loop, tell, break and spawn. The
// Splitter's break has a ground-ram and a clean variant.
export const SPECIALS = ["foreman", "dispatcher", "splitter", "linker"];
export function specialCues() {
  return SPECIALS.flatMap((name) =>
    (name === "splitter" ? ["presence", "tell", "break_split", "break_clean", "spawn"] : ["presence", "tell", "break", "spawn"]).map(
      (part) => ({ id: `${name}_${part}`, type: "sound", group: "special" }),
    ),
  );
}

// INTEGRATION.md sections 4 to 6 and section 7 items 6 and 7: the boss duel stingers, each boss's
// theme, Brindle's three phase tracks, the final phases and their Eurodance hype versions, and the
// champion, which follows the same hype rule. Track ids drop the take's seed suffix (-s2801).
export const BOSS_SOUNDS = ["boss_arena_in", "boss_phase", "stinger_boss_defeated", "hype_drop"];
export const BOSS_TRACKS = [
  "brindle",
  "waking",
  "mind",
  "brindle-p1-requisition",
  "brindle-p2-furnace",
  "brindle-p3-scuttle",
  "waking-final",
  "mind-final",
  "champion-hype",
  "euro-brindle-p3",
  "euro-waking-final",
  "euro-mind-final",
  "euro-champion",
];
export function cueList() {
  return [
    ...specialCues(),
    ...BOSS_SOUNDS.map((id) => ({ id, type: "sound", group: "boss" })),
    ...BOSS_TRACKS.map((id) => ({ id, type: "track", group: "boss" })),
  ];
}

// "euro-brindle-p3-s2801.wav" -> "euro_brindle_p3", so files, theme folders and clip ids compare.
export function cueKey(name) {
  return name
    .replace(/\.[a-z0-9]+$/i, "")
    .replace(/[-_]s\d{3,5}(-\d+bpm)?$/i, "")
    .replace(/[-_]\d+bpm$/i, "")
    .toLowerCase()
    .replace(/-/g, "_");
}

// The cue ids sfx_bank.gd can bake: every quoted id in the file (TRIM_DB keys, match labels).
export function bankIds(source) {
  return new Set([...source.matchAll(/"([a-z][a-z0-9_]*)"/g)].map((m) => m[1]));
}

// What the game can play: sound ids from the bank and audio files, track ids from music_ace theme
// folders, their clips and sources, and audio files.
export function wiredSet({ bank = "", manifests = [], files = [] }) {
  const sounds = bankIds(bank);
  const tracks = new Set();
  for (const m of manifests) {
    if (m.theme) tracks.add(cueKey(m.theme));
    for (const key of [...Object.keys(m.clips ?? {}), ...Object.keys(m.sources ?? {})])
      if (m.theme) tracks.add(cueKey(`${m.theme}_${key}`));
  }
  for (const f of files) {
    sounds.add(cueKey(path.basename(f)));
    tracks.add(cueKey(path.basename(f)));
  }
  return { sounds, tracks };
}

// One finding per cue the game cannot play. delivered lists audio files outside the game tree
// (--music folders), so the report says whether a cue is unrendered or rendered but not imported.
export function missingCues(cues, wired, delivered = []) {
  const byKey = new Map(delivered.map((f) => [cueKey(path.basename(f)), f]));
  return cues
    .filter((cue) => !(cue.type === "sound" ? wired.sounds : wired.tracks).has(cueKey(cue.id)))
    .map((cue) => {
      const file = byKey.get(cueKey(cue.id));
      const where = cue.group === "special" ? "special enemies" : "bosses";
      const what = `${cue.type} ${cue.id} ${file ? `rendered (${path.basename(file)}) but not in the game` : "has no audio in the game or the render folders"}`;
      return { kind: "cue", where, what };
    });
}

export function walk(dir, ext) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(full, ext);
    return ext.some((e) => entry.name.toLowerCase().endsWith(e)) ? [full] : [];
  });
}

export function readManifests(project) {
  const dir = path.join(project, MUSIC_DIR);
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && existsSync(path.join(dir, d.name, "manifest.json")))
    .map((d) => ({ dir: path.join(dir, d.name), ...JSON.parse(readFileSync(path.join(dir, d.name, "manifest.json"), "utf8")) }));
}

export function cueFindings(project, delivered = []) {
  const bankPath = path.join(project, SFX_BANK);
  if (!existsSync(bankPath)) return [];
  const wired = wiredSet({
    bank: readFileSync(bankPath, "utf8"),
    manifests: readManifests(project),
    files: walk(path.join(project, "assets"), AUDIO_EXT),
  });
  return missingCues(cueList(), wired, delivered);
}

// ffmpeg ebur128 summary: integrated loudness and true peak.
export function parseEbur128(stderr) {
  const i = [...stderr.matchAll(/^\s*I:\s+(-?[\d.]+|-inf)\s+LUFS/gm)].pop();
  const p = [...stderr.matchAll(/^\s*Peak:\s+(-?[\d.]+|-inf)\s+dBFS/gm)].pop();
  const num = (m) => (m ? (m[1] === "-inf" ? -Infinity : Number(m[1])) : null);
  return { lufs: num(i), truePeak: num(p) };
}

export function hasFfmpeg() {
  return spawnSync("ffmpeg", ["-version"], { stdio: "ignore" }).status === 0;
}

// Interleaved stereo float samples at the file's own rate (or rate when given).
export function decode(file, rate = null) {
  const args = ["-v", "error", "-i", file, "-f", "f32le", "-ac", "2", ...(rate ? ["-ar", String(rate)] : []), "pipe:1"];
  const out = spawnSync("ffmpeg", args, { maxBuffer: 1 << 30 });
  if (out.status !== 0) throw new Error(`ffmpeg could not decode ${file}: ${out.stderr}`);
  const buf = out.stdout;
  return new Float32Array(buf.buffer, buf.byteOffset, buf.length / 4);
}

export function probeRate(file) {
  const out = spawnSync("ffprobe", ["-v", "error", "-select_streams", "a:0", "-show_entries", "stream=sample_rate", "-of", "csv=p=0", file]);
  return Number(String(out.stdout).trim()) || 48000;
}

export function meter(samples, rate) {
  const buf = Buffer.from(samples.buffer, samples.byteOffset, samples.byteLength);
  const out = spawnSync(
    "ffmpeg",
    ["-hide_banner", "-nostats", "-f", "f32le", "-ar", String(rate), "-ac", "2", "-i", "pipe:0", "-af", "ebur128=peak=true", "-f", "null", "-"],
    { input: buf, maxBuffer: 1 << 26 },
  );
  return parseEbur128(String(out.stderr));
}

// The wrap from frame exit - 1 to frame loopAt against the loop's own sample steps.
export function seamStep(samples, exit, loopAt) {
  const frames = samples.length / 2;
  const end = Math.min(exit, frames);
  const steps = [];
  for (let f = loopAt + 1; f < end; f++)
    for (let c = 0; c < 2; c++) steps.push(Math.abs(samples[f * 2 + c] - samples[(f - 1) * 2 + c]));
  steps.sort((a, b) => a - b);
  const p = steps.length ? steps[Math.min(steps.length - 1, Math.floor(steps.length * SEAM_PERCENTILE))] : 0;
  let wrap = 0;
  for (let c = 0; c < 2; c++) wrap = Math.max(wrap, Math.abs(samples[loopAt * 2 + c] - samples[(end - 1) * 2 + c]));
  return { wrap, p999: p, ok: wrap <= p };
}

export function gain(samples, db) {
  if (!db) return samples;
  const g = 10 ** (db / 20);
  return samples.map((s) => s * g);
}

// A track's verdicts: true peak always, loudness when it is long enough, the seam when it loops.
export function judge(name, samples, rate, { loop = false, exit = null, loopAt = 0 } = {}) {
  const found = [];
  const seconds = samples.length / 2 / rate;
  const row = { name, seconds: Math.round(seconds * 10) / 10 };
  const { lufs, truePeak } = meter(samples, rate);
  row.truePeak = truePeak;
  if (truePeak === null || truePeak > MAX_TRUE_PEAK)
    found.push({ kind: "peak", where: name, what: `true peak ${truePeak} dBTP, limit ${MAX_TRUE_PEAK}` });
  if (seconds >= MIN_LOUDNESS_SECONDS) {
    row.lufs = lufs;
    if (lufs === null || Math.abs(lufs - TARGET_LUFS) > LUFS_TOL)
      found.push({ kind: "loudness", where: name, what: `${lufs} LUFS, target ${TARGET_LUFS} +/- ${LUFS_TOL}` });
  }
  if (loop) {
    const s = seamStep(samples, exit ?? samples.length / 2, loopAt);
    Object.assign(row, { seamWrap: round4(s.wrap), seamP999: round4(s.p999) });
    if (!s.ok) found.push({ kind: "seam", where: name, what: `loop wrap steps ${round4(s.wrap)}, the loop's own 99.9th-percentile step is ${round4(s.p999)}` });
  }
  return { row, found };
}

const round4 = (x) => Math.round(x * 10000) / 10000;

// Game clips from the music_ace manifests: stems summed as the engine mixes them.
export function gameTracks(manifests) {
  const tracks = [];
  for (const m of manifests)
    for (const [id, clip] of Object.entries(m.clips ?? {})) {
      const files = Object.values(clip.files ?? {}).map((f) => path.join(m.dir, f));
      tracks.push({ name: `${m.theme}/${id}`, files, rate: clip.rate ?? m.rate, level: m.level_db ?? 0, loop: !!clip.loop, exit: clip.sample_count ?? clip.exit, loopAt: clip.loop_offset ?? 0, frames: clip.sample_count ?? null, measuredLufs: clip.measured?.lufs ?? null });
    }
  return tracks;
}

// A clip whose decoded length or loudness differs from what its manifest recorded when it was cut.
export function staleAgainstManifest(t, frames, lufs) {
  const found = [];
  if (t.frames !== null && frames !== t.frames)
    found.push({ kind: "stale", where: t.name, what: `decoded ${frames} frames, the manifest's sample_count is ${t.frames}; the Oggs are not the ones this manifest was cut from` });
  if (t.measuredLufs !== null && lufs !== null && lufs !== undefined && Math.abs(lufs - t.measuredLufs) > MANIFEST_LUFS_TOL)
    found.push({ kind: "stale", where: t.name, what: `${lufs} LUFS, the manifest recorded ${t.measuredLufs} (tolerance ${MANIFEST_LUFS_TOL}); the Oggs are not the ones this manifest was cut from` });
  return found;
}

export function sha256(file) {
  return createHash("sha256").update(readFileSync(file)).digest("hex");
}

// The stem files the manifests name, as "pack/file.ogg".
export function namedStems(manifests) {
  return manifests.flatMap((m) =>
    Object.values(m.clips ?? {}).flatMap((clip) => Object.values(clip.files ?? {}).map((f) => `${path.basename(m.dir)}/${f}`)),
  );
}

export function readStemHashes(file) {
  if (!existsSync(file)) return null;
  const hashes = new Map();
  for (const line of readFileSync(file, "utf8").split("\n")) {
    const m = /^([0-9a-f]{64})  (\S+)$/.exec(line);
    if (m) hashes.set(m[2], m[1]);
  }
  return hashes;
}

// Every packed Ogg on disk under stemsDir must match STEMS.sha256, and every one the manifests name
// must be listed there. Missing files are not reported here (missingStems and "unchecked" own that).
// Returns one { file, why } per rejected file, so the caller can name each.
export function stemHashMismatches(hashFile, stemsDir, named) {
  const hashes = readStemHashes(hashFile);
  if (hashes === null) return null;
  const rejected = [];
  for (const rel of [...new Set(named)].sort()) {
    const file = path.join(stemsDir, rel);
    if (!existsSync(file)) continue;
    if (!hashes.has(rel)) rejected.push({ file: rel, why: `not listed in ${STEM_HASHES}; run scripts/music/mx stem-hashes after packing` });
    else if (sha256(file) !== hashes.get(rel)) rejected.push({ file: rel, why: `sha256 differs from ${STEM_HASHES} (a stale or re-encoded Ogg)` });
  }
  return rejected;
}

export function writeStemHashes(hashFile, stemsDir, named) {
  const lines = [];
  for (const rel of [...new Set(named)].sort()) {
    const file = path.join(stemsDir, rel);
    if (!existsSync(file)) throw new Error(`cannot hash ${rel}: not in ${stemsDir}`);
    lines.push(`${sha256(file)}  ${rel}`);
  }
  writeFileSync(hashFile, lines.join("\n") + "\n");
  return lines.length;
}

export function measureGame(manifests) {
  const rows = [];
  const found = [];
  const missing = [];
  for (const t of gameTracks(manifests)) {
    if (t.files.length === 0 || !t.files.every((f) => existsSync(f))) {
      missing.push(t.name);
      continue;
    }
    const stems = t.files.map((f) => decode(f, t.rate));
    const mix = new Float32Array(Math.max(...stems.map((s) => s.length)));
    for (const s of stems) for (let i = 0; i < s.length; i++) mix[i] += s[i];
    const r = judge(t.name, gain(mix, t.level), t.rate, t);
    rows.push(r.row);
    found.push(...r.found, ...staleAgainstManifest(t, mix.length / 2, r.row.lufs));
  }
  if (missing.length)
    found.push({ kind: "unchecked", where: MUSIC_DIR, what: `${missing.length} clip(s) have no local stems (the Oggs are not committed): ${missing.slice(0, 4).join(", ")}${missing.length > 4 ? ", ..." : ""}` });
  return { rows, found };
}

// Loose files: music under the --music folders, one track each. Files whose name matches loops
// are checked as loops that wrap from their last sample to their first.
export function measureFiles(files, loops) {
  const rows = [];
  const found = [];
  for (const f of files) {
    const rate = probeRate(f);
    const r = judge(path.basename(f), decode(f, rate), rate, { loop: loops.test(path.basename(f)) });
    rows.push(r.row);
    found.push(...r.found);
  }
  return { rows, found };
}

export const KIND_TITLES = {
  cue: "Special-enemy and boss cues the game cannot play",
  loudness: "Tracks off the loudness target",
  peak: "Tracks over the true-peak limit",
  seam: "Loops that click at the wrap",
  pages: "Packed Oggs stored in long pages (a start deep in the clip stalls its frame)",
  stale: "Packed audio that does not match its manifest or STEMS.sha256",
  unchecked: "Not checked",
};

export function report(findings, rows = []) {
  const lines = [];
  if (rows.length) {
    lines.push("track  seconds  LUFS  true peak  seam wrap / p99.9");
    for (const r of rows)
      lines.push(`  ${r.name}  ${r.seconds}  ${r.lufs ?? "-"}  ${r.truePeak ?? "-"}  ${r.seamWrap !== undefined ? `${r.seamWrap} / ${r.seamP999}` : "-"}`);
  }
  for (const [kind, title] of Object.entries(KIND_TITLES)) {
    const group = findings.filter((f) => f.kind === kind);
    if (group.length === 0) continue;
    lines.push(`${title}: ${group.length}`);
    for (const f of group) lines.push(`  ${f.where}  ${f.what}`);
  }
  lines.push(findings.length === 0 ? "audio gate: PASS" : `audio gate: FAIL (${findings.length} finding(s))`);
  return lines.join("\n");
}

export function parseArgs(argv) {
  const args = { project: path.join(root, "sketches/core-loop"), music: [], loops: /loop/i, json: false, cuesOnly: false, writeStemHashes: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const value = (flag) => (arg === flag && i + 1 < argv.length ? argv[++i] : arg.startsWith(flag + "=") ? arg.slice(flag.length + 1) : null);
    let v;
    if (arg === "--json") args.json = true;
    else if (arg === "--cues-only") args.cuesOnly = true;
    else if (arg === "--write-stem-hashes") args.writeStemHashes = true;
    else if ((v = value("--project")) !== null) args.project = path.resolve(v);
    else if ((v = value("--music")) !== null) args.music.push(path.resolve(v));
    else if ((v = value("--loops")) !== null) args.loops = new RegExp(v, "i");
    else throw new Error("unknown argument: " + arg);
  }
  return args;
}

// What the run cannot see, so a wrong path never reads as a pass.
export function missingInputs(args, manifests) {
  const found = [];
  if (!existsSync(path.join(args.project, SFX_BANK)))
    found.push({ kind: "unchecked", where: args.project, what: `no ${SFX_BANK}; cues not checked` });
  if (!args.cuesOnly && !manifests.some((m) => Object.keys(m.clips ?? {}).length))
    found.push({ kind: "unchecked", where: args.project, what: `no ${MUSIC_DIR} manifest with clips; game music not measured` });
  for (const d of args.music) if (!existsSync(d)) found.push({ kind: "unchecked", where: d, what: "music folder not found" });
  return found;
}

// STEMS.sha256 beside the manifests: a mismatch names the file; no list at all is "unchecked", never a pass.
export function hashFindings(project, manifests) {
  const dir = path.join(project, MUSIC_DIR);
  const named = namedStems(manifests);
  if (!named.some((rel) => existsSync(path.join(dir, rel)))) return [];
  const rejected = stemHashMismatches(path.join(dir, STEM_HASHES), dir, named);
  if (rejected === null) return [{ kind: "unchecked", where: path.join(dir, STEM_HASHES), what: "no stem hash list; packed Oggs not compared to what was cut" }];
  return rejected.map((r) => ({ kind: "stale", where: r.file, what: r.why }));
}

// An Ogg is stored in pages, and a start anywhere but a page's first sample decodes from the page
// before. ffmpeg writes pages one second long unless told otherwise, which made a section change deep
// in a clip decode up to a second of audio on its frame (tools/ace/repage.py has the measurement and
// the fix). Returns the seconds of audio in the file's longest page, or null when it is not Ogg Vorbis.
export const MAX_OGG_PAGE_S = 0.1;
export function oggLongestPage(data) {
  let rate = 0;
  let last = 0;
  let longest = 0;
  let pages = 0;
  for (let at = data.indexOf("OggS"); at >= 0 && at + 27 <= data.length; ) {
    const granule = data.readBigInt64LE(at + 6);
    const segments = data[at + 26];
    const body = at + 27 + segments;
    let size = 0;
    for (let i = at + 27; i < body && i < data.length; i++) size += data[i];
    if (rate === 0 && body + 16 <= data.length && data.subarray(body, body + 7).toString("latin1") === "\x01vorbis") rate = data.readUInt32LE(body + 12);
    if (granule >= 0n) {
      longest = Math.max(longest, Number(granule) - last);
      last = Number(granule);
      pages += 1;
    }
    at = data.indexOf("OggS", body + size);
  }
  return rate > 0 && pages > 0 ? longest / rate : null;
}

// Every packed Ogg the manifests name and the disk holds must be short-paged.
export function pageFindings(project, manifests) {
  const dir = path.join(project, MUSIC_DIR);
  const found = [];
  for (const rel of [...new Set(namedStems(manifests))].sort()) {
    const file = path.join(dir, rel);
    if (!rel.endsWith(".ogg") || !existsSync(file)) continue;
    const seconds = oggLongestPage(readFileSync(file));
    if (seconds !== null && seconds > MAX_OGG_PAGE_S)
      found.push({ kind: "pages", where: rel, what: `longest Ogg page holds ${round4(seconds)} s of audio (over ${MAX_OGG_PAGE_S}); run tools/ace/repage.py apply, then scripts/music/mx stem-hashes` });
  }
  return found;
}

export function run(args) {
  const delivered = args.music.flatMap((d) => walk(d, AUDIO_EXT));
  const findings = [...missingInputs(args, readManifests(args.project)), ...cueFindings(args.project, delivered)];
  const rows = [];
  if (!args.cuesOnly) findings.push(...hashFindings(args.project, readManifests(args.project)));
  if (!args.cuesOnly) findings.push(...pageFindings(args.project, readManifests(args.project)));
  if (!args.cuesOnly) {
    if (!hasFfmpeg()) findings.push({ kind: "unchecked", where: "ffmpeg", what: "ffmpeg not found; loudness, peaks and seams not measured" });
    else {
      for (const part of [measureGame(readManifests(args.project)), measureFiles(delivered, args.loops)]) {
        rows.push(...part.rows);
        findings.push(...part.found);
      }
    }
  }
  return { findings, rows };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.writeStemHashes) {
    const dir = path.join(args.project, MUSIC_DIR);
    const n = writeStemHashes(path.join(dir, STEM_HASHES), dir, namedStems(readManifests(args.project)));
    console.log(`wrote ${n} hashes to ${path.join(dir, STEM_HASHES)}`);
    return;
  }
  const { findings, rows } = run(args);
  console.log(args.json ? JSON.stringify({ rows, findings }, null, 2) : report(findings, rows));
  process.exitCode = findings.length === 0 ? 0 : 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
