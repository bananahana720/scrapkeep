import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { Worker, isMainThread, parentPort, workerData } from "node:worker_threads";
import { isMain } from "./lib/cli.mjs";
import { REPO_ROOT } from "./lib/git.mjs";
import { walkSync } from "./lib/walk.mjs";

const root = REPO_ROOT;

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

export const SPECIALS = ["foreman", "dispatcher", "splitter", "linker"];
export function specialCues() {
  return SPECIALS.flatMap((name) =>
    (name === "splitter"
      ? ["presence", "tell", "break_split", "break_clean", "spawn"]
      : ["presence", "tell", "break", "spawn"]
    ).map((part) => ({ id: `${name}_${part}`, type: "sound", group: "special" })),
  );
}

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

export function cueKey(name) {
  return name
    .replace(/\.[a-z0-9]+$/i, "")
    .replace(/[-_]s\d{3,5}(-\d+bpm)?$/i, "")
    .replace(/[-_]\d+bpm$/i, "")
    .toLowerCase()
    .replace(/-/g, "_");
}

export function bankIds(source) {
  return new Set([...source.matchAll(/"([a-z][a-z0-9_]*)"/g)].map((m) => m[1]));
}

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
  return walkSync(dir, {
    filter: (entry) => ext.some((e) => entry.name.toLowerCase().endsWith(e)),
  }).map((entry) => entry.full);
}

export function readManifests(project) {
  const dir = path.join(project, MUSIC_DIR);
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && existsSync(path.join(dir, d.name, "manifest.json")))
    .map((d) => ({
      dir: path.join(dir, d.name),
      ...JSON.parse(readFileSync(path.join(dir, d.name, "manifest.json"), "utf8")),
    }));
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

export function parseEbur128(stderr) {
  const i = [...stderr.matchAll(/^\s*I:\s+(-?[\d.]+|-inf)\s+LUFS/gm)].pop();
  const p = [...stderr.matchAll(/^\s*Peak:\s+(-?[\d.]+|-inf)\s+dBFS/gm)].pop();
  const num = (m) => (m ? (m[1] === "-inf" ? -Infinity : Number(m[1])) : null);
  return { lufs: num(i), truePeak: num(p) };
}

export function hasFfmpeg() {
  return spawnSync("ffmpeg", ["-version"], { stdio: "ignore" }).status === 0;
}

export function decode(file, rate = null) {
  const args = [
    "-v",
    "error",
    "-i",
    file,
    "-f",
    "f32le",
    "-ac",
    "2",
    ...(rate ? ["-ar", String(rate)] : []),
    "pipe:1",
  ];
  const out = spawnSync("ffmpeg", args, { maxBuffer: 1 << 30 });
  if (out.status !== 0) throw new Error(`ffmpeg could not decode ${file}: ${out.stderr}`);
  const buf = out.stdout;
  return new Float32Array(buf.buffer, buf.byteOffset, buf.length / 4);
}

export function probeRate(file) {
  const out = spawnSync("ffprobe", [
    "-v",
    "error",
    "-select_streams",
    "a:0",
    "-show_entries",
    "stream=sample_rate",
    "-of",
    "csv=p=0",
    file,
  ]);
  return Number(String(out.stdout).trim()) || 48000;
}

export function meter(samples, rate) {
  const buf = Buffer.from(samples.buffer, samples.byteOffset, samples.byteLength);
  const out = spawnSync(
    "ffmpeg",
    [
      "-hide_banner",
      "-nostats",
      "-f",
      "f32le",
      "-ar",
      String(rate),
      "-ac",
      "2",
      "-i",
      "pipe:0",
      "-af",
      "ebur128=peak=true",
      "-f",
      "null",
      "-",
    ],
    { input: buf, maxBuffer: 1 << 26 },
  );
  return parseEbur128(String(out.stderr));
}

export function seamStep(samples, exit, loopAt) {
  const frames = samples.length / 2;
  const end = Math.min(exit, frames);
  const count = Math.max(0, Math.ceil(end - (loopAt + 1))) * 2;
  const steps = new Float64Array(count);
  let k = 0;
  for (let f = loopAt + 1; f < end; f++)
    for (let c = 0; c < 2; c++)
      steps[k++] = Math.abs(samples[f * 2 + c] - samples[(f - 1) * 2 + c]);
  steps.sort();
  const p = count ? steps[Math.min(count - 1, Math.floor(count * SEAM_PERCENTILE))] : 0;
  let wrap = 0;
  for (let c = 0; c < 2; c++)
    wrap = Math.max(wrap, Math.abs(samples[loopAt * 2 + c] - samples[(end - 1) * 2 + c]));
  return { wrap, p999: p, ok: wrap <= p };
}

export function gain(samples, db) {
  if (!db) return samples;
  const g = 10 ** (db / 20);
  return samples.map((s) => s * g);
}

export function judge(name, samples, rate, { loop = false, exit = null, loopAt = 0 } = {}) {
  const found = [];
  const seconds = samples.length / 2 / rate;
  const row = { name, seconds: Math.round(seconds * 10) / 10 };
  const { lufs, truePeak } = meter(samples, rate);
  row.truePeak = truePeak;
  if (truePeak === null || truePeak > MAX_TRUE_PEAK)
    found.push({
      kind: "peak",
      where: name,
      what: `true peak ${truePeak} dBTP, limit ${MAX_TRUE_PEAK}`,
    });
  if (seconds >= MIN_LOUDNESS_SECONDS) {
    row.lufs = lufs;
    if (lufs === null || Math.abs(lufs - TARGET_LUFS) > LUFS_TOL)
      found.push({
        kind: "loudness",
        where: name,
        what: `${lufs} LUFS, target ${TARGET_LUFS} +/- ${LUFS_TOL}`,
      });
  }
  if (loop) {
    const s = seamStep(samples, exit ?? samples.length / 2, loopAt);
    Object.assign(row, { seamWrap: round4(s.wrap), seamP999: round4(s.p999) });
    if (!s.ok)
      found.push({
        kind: "seam",
        where: name,
        what: `loop wrap steps ${round4(s.wrap)}, the loop's own 99.9th-percentile step is ${round4(s.p999)}`,
      });
  }
  return { row, found };
}

const round4 = (x) => Math.round(x * 10000) / 10000;

export function gameTracks(manifests) {
  const tracks = [];
  for (const m of manifests)
    for (const [id, clip] of Object.entries(m.clips ?? {})) {
      const files = Object.values(clip.files ?? {}).map((f) => path.join(m.dir, f));
      tracks.push({
        name: `${m.theme}/${id}`,
        files,
        rate: clip.rate ?? m.rate,
        level: m.level_db ?? 0,
        loop: !!clip.loop,
        exit: clip.sample_count ?? clip.exit,
        loopAt: clip.loop_offset ?? 0,
        frames: clip.sample_count ?? null,
        measuredLufs: clip.measured?.lufs ?? null,
      });
    }
  return tracks;
}

export function staleAgainstManifest(t, frames, lufs) {
  const found = [];
  if (t.frames !== null && frames !== t.frames)
    found.push({
      kind: "stale",
      where: t.name,
      what: `decoded ${frames} frames, the manifest's sample_count is ${t.frames}; the Oggs are not the ones this manifest was cut from`,
    });
  if (
    t.measuredLufs !== null &&
    lufs !== null &&
    lufs !== undefined &&
    Math.abs(lufs - t.measuredLufs) > MANIFEST_LUFS_TOL
  )
    found.push({
      kind: "stale",
      where: t.name,
      what: `${lufs} LUFS, the manifest recorded ${t.measuredLufs} (tolerance ${MANIFEST_LUFS_TOL}); the Oggs are not the ones this manifest was cut from`,
    });
  return found;
}

export function sha256(file) {
  return createHash("sha256").update(readFileSync(file)).digest("hex");
}

export function namedStems(manifests) {
  return manifests.flatMap((m) =>
    Object.values(m.clips ?? {}).flatMap((clip) =>
      Object.values(clip.files ?? {}).map((f) => `${path.basename(m.dir)}/${f}`),
    ),
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

export function stemHashMismatches(hashFile, stemsDir, named) {
  const hashes = readStemHashes(hashFile);
  if (hashes === null) return null;
  const rejected = [];
  for (const rel of [...new Set(named)].sort()) {
    const file = path.join(stemsDir, rel);
    if (!existsSync(file)) continue;
    if (!hashes.has(rel))
      rejected.push({
        file: rel,
        why: `not listed in ${STEM_HASHES}; run scripts/music/mx stem-hashes after packing`,
      });
    else if (sha256(file) !== hashes.get(rel))
      rejected.push({
        file: rel,
        why: `sha256 differs from ${STEM_HASHES} (a stale or re-encoded Ogg)`,
      });
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

const WORKER_FLAG = "audioGateWorker";
const SELF_URL = new URL(import.meta.url);

export function defaultJobs() {
  return Math.max(1, Math.min(os.availableParallelism(), 16));
}

export function resolveJobs(jobs) {
  if (jobs === undefined || jobs === null) return defaultJobs();
  const n = Number(jobs);
  if (!Number.isInteger(n) || n < 1)
    throw new Error(`--jobs must be a positive integer, got ${jobs}`);
  return n;
}

function measureTrack(t) {
  const stems = t.files.map((f) => decode(f, t.rate));
  const mix = new Float32Array(Math.max(...stems.map((s) => s.length)));
  for (const s of stems) for (let i = 0; i < s.length; i++) mix[i] += s[i];
  const r = judge(t.name, gain(mix, t.level), t.rate, t);
  return {
    row: r.row,
    found: [...r.found, ...staleAgainstManifest(t, mix.length / 2, r.row.lufs)],
  };
}

function measureFile(f, loop) {
  const rate = probeRate(f);
  return judge(path.basename(f), decode(f, rate), rate, { loop });
}

function missingClipsFinding(missing) {
  return {
    kind: "unchecked",
    where: MUSIC_DIR,
    what: `${missing.length} clip(s) have no local stems (the Oggs are not committed): ${missing.slice(0, 4).join(", ")}${missing.length > 4 ? ", ..." : ""}`,
  };
}

function runWorkerItem(item) {
  if (item.kind === "track") return measureTrack(item.track);
  if (item.kind === "file") return measureFile(item.file, item.loop);
  throw new Error(`unknown audio-gate worker item kind: ${item.kind}`);
}

function send(port, msg) {
  // oxlint-disable-next-line unicorn/require-post-message-target-origin -- Node worker_threads MessagePort, not window.postMessage
  port.postMessage(msg);
}

async function runInWorkerPool(items, jobs, syncRunner) {
  const count = resolveJobs(jobs);
  if (items.length === 0) return [];
  const concurrency = Math.min(count, items.length);
  if (concurrency <= 1) return items.map(syncRunner);

  const results = new Array(items.length);
  const workers = [];
  let nextIndex = 0;
  let completed = 0;
  let settled = false;

  try {
    await new Promise((resolve, reject) => {
      const fail = (err) => {
        if (settled) return;
        settled = true;
        reject(err instanceof Error ? err : new Error(String(err)));
      };

      for (let i = 0; i < concurrency; i++) {
        const worker = new Worker(SELF_URL, {
          workerData: { [WORKER_FLAG]: true },
          execArgv: [],
        });
        let idle = false;
        workers.push(worker);

        const dispatch = () => {
          if (settled) return;
          if (nextIndex >= items.length) {
            idle = true;
            send(worker, { done: true });
            return;
          }
          const index = nextIndex++;
          send(worker, { index, item: items[index] });
        };

        worker.on("message", (msg) => {
          if (settled) return;
          if (!msg.ok) {
            fail(msg.error);
            return;
          }
          results[msg.index] = msg.result;
          completed += 1;
          if (completed === items.length) {
            settled = true;
            resolve();
            return;
          }
          dispatch();
        });

        worker.on("error", fail);
        worker.on("exit", (code) => {
          if (!settled && (!idle || code !== 0))
            fail(new Error(`audio-gate worker exited with code ${code}`));
        });

        dispatch();
      }
    });
    return results;
  } finally {
    await Promise.allSettled(workers.map((w) => w.terminate()));
  }
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
    const r = measureTrack(t);
    rows.push(r.row);
    found.push(...r.found);
  }
  if (missing.length) found.push(missingClipsFinding(missing));
  return { rows, found };
}

export async function measureGameAsync(manifests, { jobs } = {}) {
  const present = [];
  const missing = [];
  for (const t of gameTracks(manifests)) {
    if (t.files.length === 0 || !t.files.every((f) => existsSync(f))) {
      missing.push(t.name);
      continue;
    }
    present.push({ kind: "track", track: t });
  }
  const measured = await runInWorkerPool(present, jobs, runWorkerItem);
  const rows = [];
  const found = [];
  for (const r of measured) {
    rows.push(r.row);
    found.push(...r.found);
  }
  if (missing.length) found.push(missingClipsFinding(missing));
  return { rows, found };
}

export function measureFiles(files, loops) {
  const rows = [];
  const found = [];
  for (const f of files) {
    const r = measureFile(f, loops.test(path.basename(f)));
    rows.push(r.row);
    found.push(...r.found);
  }
  return { rows, found };
}

export async function measureFilesAsync(files, loops, { jobs } = {}) {
  const items = files.map((file) => ({
    kind: "file",
    file,
    loop: loops.test(path.basename(file)),
  }));
  const measured = await runInWorkerPool(items, jobs, runWorkerItem);
  const rows = [];
  const found = [];
  for (const r of measured) {
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
      lines.push(
        `  ${r.name}  ${r.seconds}  ${r.lufs ?? "-"}  ${r.truePeak ?? "-"}  ${r.seamWrap !== undefined ? `${r.seamWrap} / ${r.seamP999}` : "-"}`,
      );
  }
  for (const [kind, title] of Object.entries(KIND_TITLES)) {
    const group = findings.filter((f) => f.kind === kind);
    if (group.length === 0) continue;
    lines.push(`${title}: ${group.length}`);
    for (const f of group) lines.push(`  ${f.where}  ${f.what}`);
  }
  lines.push(
    findings.length === 0 ? "audio gate: PASS" : `audio gate: FAIL (${findings.length} finding(s))`,
  );
  return lines.join("\n");
}

export function parseArgs(argv) {
  const args = {
    project: path.join(root, "sketches/core-loop"),
    music: [],
    loops: /loop/i,
    jobs: defaultJobs(),
    json: false,
    cuesOnly: false,
    writeStemHashes: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const value = (flag) =>
      arg === flag && i + 1 < argv.length
        ? argv[++i]
        : arg.startsWith(flag + "=")
          ? arg.slice(flag.length + 1)
          : null;
    let v;
    if (arg === "--json") args.json = true;
    else if (arg === "--cues-only") args.cuesOnly = true;
    else if (arg === "--write-stem-hashes") args.writeStemHashes = true;
    else if ((v = value("--project")) !== null) args.project = path.resolve(v);
    else if ((v = value("--music")) !== null) args.music.push(path.resolve(v));
    else if ((v = value("--loops")) !== null) args.loops = new RegExp(v, "i");
    else if ((v = value("--jobs")) !== null) args.jobs = resolveJobs(v);
    else throw new Error("unknown argument: " + arg);
  }
  return args;
}

export function missingInputs(args, manifests) {
  const found = [];
  if (!existsSync(path.join(args.project, SFX_BANK)))
    found.push({
      kind: "unchecked",
      where: args.project,
      what: `no ${SFX_BANK}; cues not checked`,
    });
  if (!args.cuesOnly && !manifests.some((m) => Object.keys(m.clips ?? {}).length))
    found.push({
      kind: "unchecked",
      where: args.project,
      what: `no ${MUSIC_DIR} manifest with clips; game music not measured`,
    });
  for (const d of args.music)
    if (!existsSync(d)) found.push({ kind: "unchecked", where: d, what: "music folder not found" });
  return found;
}

export function hashFindings(project, manifests) {
  const dir = path.join(project, MUSIC_DIR);
  const named = namedStems(manifests);
  if (!named.some((rel) => existsSync(path.join(dir, rel)))) return [];
  const rejected = stemHashMismatches(path.join(dir, STEM_HASHES), dir, named);
  if (rejected === null)
    return [
      {
        kind: "unchecked",
        where: path.join(dir, STEM_HASHES),
        what: "no stem hash list; packed Oggs not compared to what was cut",
      },
    ];
  return rejected.map((r) => ({ kind: "stale", where: r.file, what: r.why }));
}

// before. ffmpeg writes pages one second long unless told otherwise, which made a section change deep
export const MAX_OGG_PAGE_S = 0.1;
export function oggLongestPage(data) {
  let rate = 0;
  let last = 0;
  let longest = 0;
  let pages = 0;
  for (let at = data.indexOf("OggS"); at >= 0 && at + 27 <= data.length;) {
    const granule = data.readBigInt64LE(at + 6);
    const segments = data[at + 26];
    const body = at + 27 + segments;
    let size = 0;
    for (let i = at + 27; i < body && i < data.length; i++) size += data[i];
    if (
      rate === 0 &&
      body + 16 <= data.length &&
      data.subarray(body, body + 7).toString("latin1") === "\x01vorbis"
    )
      rate = data.readUInt32LE(body + 12);
    if (granule >= 0n) {
      longest = Math.max(longest, Number(granule) - last);
      last = Number(granule);
      pages += 1;
    }
    at = data.indexOf("OggS", body + size);
  }
  return rate > 0 && pages > 0 ? longest / rate : null;
}

export function pageFindings(project, manifests) {
  const dir = path.join(project, MUSIC_DIR);
  const found = [];
  for (const rel of [...new Set(namedStems(manifests))].sort()) {
    const file = path.join(dir, rel);
    if (!rel.endsWith(".ogg") || !existsSync(file)) continue;
    const seconds = oggLongestPage(readFileSync(file));
    if (seconds !== null && seconds > MAX_OGG_PAGE_S)
      found.push({
        kind: "pages",
        where: rel,
        what: `longest Ogg page holds ${round4(seconds)} s of audio (over ${MAX_OGG_PAGE_S}); run tools/ace/repage.py apply, then scripts/music/mx stem-hashes`,
      });
  }
  return found;
}

export function run(args) {
  const delivered = args.music.flatMap((d) => walk(d, AUDIO_EXT));
  const findings = [
    ...missingInputs(args, readManifests(args.project)),
    ...cueFindings(args.project, delivered),
  ];
  const rows = [];
  if (!args.cuesOnly) findings.push(...hashFindings(args.project, readManifests(args.project)));
  if (!args.cuesOnly) findings.push(...pageFindings(args.project, readManifests(args.project)));
  if (!args.cuesOnly) {
    if (!hasFfmpeg())
      findings.push({
        kind: "unchecked",
        where: "ffmpeg",
        what: "ffmpeg not found; loudness, peaks and seams not measured",
      });
    else {
      for (const part of [
        measureGame(readManifests(args.project)),
        measureFiles(delivered, args.loops),
      ]) {
        rows.push(...part.rows);
        findings.push(...part.found);
      }
    }
  }
  return { findings, rows };
}

export async function runAsync(args) {
  const delivered = args.music.flatMap((d) => walk(d, AUDIO_EXT));
  const manifests = readManifests(args.project);
  const findings = [...missingInputs(args, manifests), ...cueFindings(args.project, delivered)];
  const rows = [];
  if (!args.cuesOnly) findings.push(...hashFindings(args.project, manifests));
  if (!args.cuesOnly) findings.push(...pageFindings(args.project, manifests));
  if (!args.cuesOnly) {
    if (!hasFfmpeg())
      findings.push({
        kind: "unchecked",
        where: "ffmpeg",
        what: "ffmpeg not found; loudness, peaks and seams not measured",
      });
    else {
      const gamePart = await measureGameAsync(manifests, { jobs: args.jobs });
      const filesPart = await measureFilesAsync(delivered, args.loops, { jobs: args.jobs });
      for (const part of [gamePart, filesPart]) {
        rows.push(...part.rows);
        findings.push(...part.found);
      }
    }
  }
  return { findings, rows };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.writeStemHashes) {
    const dir = path.join(args.project, MUSIC_DIR);
    const n = writeStemHashes(
      path.join(dir, STEM_HASHES),
      dir,
      namedStems(readManifests(args.project)),
    );
    console.log(`wrote ${n} hashes to ${path.join(dir, STEM_HASHES)}`);
    return;
  }
  const { findings, rows } = await runAsync(args);
  console.log(args.json ? JSON.stringify({ rows, findings }, null, 2) : report(findings, rows));
  process.exitCode = findings.length === 0 ? 0 : 1;
}

if (!isMainThread && workerData?.[WORKER_FLAG] === true && parentPort) {
  parentPort.on("message", (msg) => {
    if (msg?.done) {
      parentPort.close();
      return;
    }
    try {
      const result = runWorkerItem(msg.item);
      send(parentPort, { ok: true, index: msg.index, result });
    } catch (err) {
      send(parentPort, {
        ok: false,
        index: msg.index,
        error: err instanceof Error ? err.message : String(err),
      });
    }
  });
}

if (isMainThread && isMain(import.meta.url)) await main();
