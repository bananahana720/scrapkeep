#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  realpathSync,
  statSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const MUSIC_ACE_DIR = path.join(REPO_ROOT, "sketches", "core-loop", "assets", "music_ace");
const DEFAULT_OUT_DIR = path.join(REPO_ROOT, "artifacts", "local", "lyria-work");
const DEFAULT_SSH_HOST = "ahana";
const DEFAULT_REMOTE_ROOT = "/home/andrew/Projects/scrapkeep-alpha-cut";
const REMOTE_PYTHON = "/home/andrew/.local/share/ACE-Step-1.5/.venv/bin/python";
const REMOTE_DEMUCS = "/home/andrew/.local/share/demucs-venv/bin/demucs";
const ANALYZE_MODEL = "gemini-4-neon";
const MUSIC_MODEL = "lyria-3.5";
const MAX_INLINE_BYTES = 10 * 1024 * 1024;
const TARGET_LUFS = -16.0;
const LUFS_TOL = 0.5;
const MANIFEST_LUFS_TOL = 0.3;
const MAX_TRUE_PEAK = -1.0;

export const ALPHA_PACK_IDS = [
  "roam_highdraft",
  "roam_dig",
  "euro_waking_final",
  "euro_mind_final",
];

export const PACK_SPECS = {
  roam_highdraft: {
    id: "roam_highdraft",
    bpm: 172,
    key: "G",
    keyOffset: 5,
    mode: "G minor with raised fourth (Lydian-minor wind colour)",
    world:
      "World 3 - The Highdraft (cableways, launch rails, hanging islands, golden hour to dusk)",
    schema: "roam",
    clips: {
      calm: { bars: 16, loop: true },
      travel: { bars: 16, loop: true },
      cadence: { bars: 2, loop: false },
    },
    direction:
      "Fast 172 BPM liquid drum and bass roaming score in G minor (with raised fourth wind colour); rapid two-step breakbeat snare on beats 2 and 4 with fast 16th-note shuffling hats at true 172 BPM (never slow hip-hop or smooth jazz), rolling warm sub and detuned sawtooth bass (G8), shimmering electric piano jazz chords, soaring bright synth-sax and crisp brass lead accents (G1, G5, G10); opens with an airy driving 172 BPM calm groove, lifts into a fuller soaring high-energy travel section with ride cymbals and layered counter-melodies, and finishes with a crisp 2-bar cadence onto G; strictly instrumental, zero vocals, zero East Asian instruments, zero talking growls or dubstep wubs (R1/R2).",
  },
  roam_dig: {
    id: "roam_dig",
    bpm: 172,
    key: "E",
    keyOffset: 2,
    mode: "E minor / E Phrygian",
    world: "World 2 - The Dig (open-pit mine, buried iron plates, sinkhole, noon to afternoon)",
    schema: "roam",
    clips: {
      calm: { bars: 16, loop: true },
      travel: { bars: 16, loop: true },
      cadence: { bars: 2, loop: false },
    },
    direction:
      "Fast 172 BPM funk-infused liquid drum and bass roaming score in E minor / E Phrygian; rapid crisp 172 BPM breakbeat drums with fast two-step kick-snare drive and rapid hats (never slow hip-hop or mid-tempo funk), gritty slap and deep sub subterranean bassline (G8), tight rhythmic clavinet and electric piano comping (G5), punchy brass stabs and expressive synth-sax call-and-response leads; opens with a taut 172 BPM mining-pit groove for calm bars, builds into a full-band driving second half for travel bars, and resolves with a clean 2-bar cadential tag onto E; strictly instrumental, zero vocals, zero East Asian instruments, zero talking growls or heavy LFO dubstep wubs (R1/R2).",
  },
  euro_waking_final: {
    id: "euro_waking_final",
    bpm: 142,
    key: "D",
    keyOffset: 0,
    mode: "D minor / D Dorian",
    world:
      "World 2 Boss Final Phase - The Waking (ancient buried excavator, final posture hype phase)",
    schema: "euro",
    clips: {
      main: { bars: 16, loop: true },
    },
    direction:
      "142 BPM high-octane instrumental Eurodance / Euro-club final-phase boss anthem in D minor (G3, G4, G11); relentless four-on-the-floor club kick and crisp offbeat hi-hats, pumping octave funk-synth bassline with clean sidechain bounce (G8), euphoric brassy supersaw rave chords and rhythmic jazz-funk stabs, triumphant soaring synth-brass and expressive sax melody riffs trading over a rock-steady 142 BPM pulse; joyful melodramatic finale adrenaline; strictly instrumental, zero vocals, zero talking growls or dubstep wobble (R1/R2), zero East Asian instruments.",
  },
  euro_mind_final: {
    id: "euro_mind_final",
    bpm: 142,
    key: "E",
    keyOffset: 2,
    mode: "E minor / E Dorian (bright climactic lift)",
    world:
      "World 3 Boss Final Phase - The Mind / Foreman (control system finale, final posture hype phase)",
    schema: "euro",
    clips: {
      main: { bars: 16, loop: true },
    },
    direction:
      "142 BPM transcendent instrumental Eurodance / Euro-club grand finale in E minor (G3, G4, G10, G11); precision four-on-the-floor drums and shimmering 16th-note hats, pumping melodic octave funk bass (G8), layered counter-melodies combining crystalline arpeggiated synths with warm electric piano, brass stabs, and soaring expressive synth-sax call-and-response; rock-steady 142 BPM pulse ready for a seamless 16-bar loop; strictly instrumental, zero vocals, zero talking growls or dubstep wubs (R1/R2), zero East Asian instruments.",
  },
};

export function usageText() {
  return [
    "Usage: node scripts/music/lyria-tune.mjs [options]",
    "",
    "Options:",
    "  --pack <id>           Pack id to tune (repeatable)",
    "  --all-alpha           Tune all 4 World 2/3 alpha packs",
    "  --dry-run             Preview planned stages without calling APIs or mutating files",
    "  --analyze-only        Run Stage 1 stem-context analysis only",
    "  --reuse-raw           Reuse existing stage1_analysis.json and lyria_raw audio in out-dir",
    "  --ref-dir <dir>       Local directory holding reference .ogg stems",
    "  --out-dir <dir>       Work directory (default: artifacts/local/lyria-work)",
    "  --ssh-host <host>     Remote GPU/mastering host (default: ahana)",
    "  --remote-root <dir>   Remote repo root on ssh-host",
    "  --api-key <key>       Explicit Gemini API key (otherwise strips GEMINI_API_KEY for keyring)",
    "  --max-attempts <n>    Max Lyria generation attempts per pack (default: 3)",
    "  -h, --help            Show this help",
  ].join("\n");
}

export function parseArgs(argv, defaults = {}) {
  const opts = {
    packs: [],
    allAlpha: false,
    dryRun: false,
    analyzeOnly: false,
    reuseRaw: false,
    refDir: null,
    outDir: defaults.outDir ?? DEFAULT_OUT_DIR,
    sshHost: defaults.sshHost ?? DEFAULT_SSH_HOST,
    remoteRoot: defaults.remoteRoot ?? DEFAULT_REMOTE_ROOT,
    apiKey: null,
    maxAttempts: 3,
    help: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const readVal = (flag) => {
      if (arg === flag) {
        if (i + 1 >= argv.length || argv[i + 1].startsWith("--")) {
          throw new Error(`${flag} requires a value`);
        }
        return argv[++i];
      }
      if (arg.startsWith(`${flag}=`)) return arg.slice(flag.length + 1);
      return null;
    };
    let val;
    if (arg === "-h" || arg === "--help") opts.help = true;
    else if (arg === "--all-alpha") opts.allAlpha = true;
    else if (arg === "--dry-run") opts.dryRun = true;
    else if (arg === "--analyze-only") opts.analyzeOnly = true;
    else if (arg === "--reuse-raw") opts.reuseRaw = true;
    else if ((val = readVal("--pack")) !== null) opts.packs.push(val);
    else if ((val = readVal("--ref-dir")) !== null) opts.refDir = path.resolve(val);
    else if ((val = readVal("--out-dir")) !== null) opts.outDir = path.resolve(val);
    else if ((val = readVal("--ssh-host")) !== null) opts.sshHost = val;
    else if ((val = readVal("--remote-root")) !== null) opts.remoteRoot = val;
    else if ((val = readVal("--api-key")) !== null) opts.apiKey = val;
    else if ((val = readVal("--max-attempts")) !== null) {
      const n = Number(val);
      if (!Number.isInteger(n) || n < 1 || n > 6) {
        throw new Error(`--max-attempts must be an integer between 1 and 6, got ${val}`);
      }
      opts.maxAttempts = n;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (opts.allAlpha) {
    for (const id of ALPHA_PACK_IDS) {
      if (!opts.packs.includes(id)) opts.packs.push(id);
    }
  }
  if (!opts.help && opts.packs.length === 0) {
    throw new Error("specify --pack <id> or --all-alpha");
  }
  return opts;
}

export function resolvePackSpec(packId, musicAceDir = MUSIC_ACE_DIR) {
  if (PACK_SPECS[packId]) return PACK_SPECS[packId];
  const manifestPath = path.join(musicAceDir, packId, "manifest.json");
  if (!existsSync(manifestPath)) {
    throw new Error(`unknown pack "${packId}": no spec and no manifest at ${manifestPath}`);
  }
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  const firstClip = Object.values(manifest.clips ?? {})[0];
  const clips = {};
  for (const [cid, clip] of Object.entries(manifest.clips ?? {})) {
    clips[cid] = { bars: clip.bars, loop: Boolean(clip.loop) };
  }
  return {
    id: packId,
    bpm: Number(firstClip?.bpm ?? 142),
    key: String(manifest.key ?? "D"),
    keyOffset: Number(manifest.key_offset ?? 0),
    mode: `${manifest.key ?? "D"} minor`,
    world: `Scrapkeep track ${packId}`,
    schema: manifest.flat ? "euro" : "roam",
    clips,
    direction: `${Number(firstClip?.bpm ?? 142)} BPM instrumental Scrapkeep track in ${manifest.key ?? "D"}, clean 3-stem separation, zero vocals, zero R1/R2 wubs.`,
  };
}

export function buildGeminiEnv(baseEnv = process.env, apiKey = null, home = os.homedir()) {
  const env = { ...baseEnv };
  const extraPaths = [
    "/opt/homebrew/opt/openjdk/bin",
    "/opt/homebrew/bin",
    path.join(home, ".local", "bin"),
  ];
  const currentPath = env.PATH ? env.PATH.split(":") : [];
  const merged = [...extraPaths, ...currentPath].filter(Boolean);
  env.PATH = [...new Set(merged)].join(":");
  if (apiKey) {
    env.GEMINI_API_KEY = apiKey;
  } else {
    delete env.GEMINI_API_KEY;
  }
  return env;
}

export function buildStage1Prompt(packSpec, manifest, stemFiles) {
  const clipSummary = Object.entries(packSpec.clips)
    .map(([cid, cfg]) => `${cid}: ${cfg.bars} bars (${cfg.loop ? "loop" : "one-shot"})`)
    .join(", ");
  const stemNames = stemFiles.map((f) => path.basename(f)).join(", ");
  const structureHint =
    packSpec.schema === "roam"
      ? "Build a 110-130 second continuous instrumental track at an exact rock-steady BPM with time-tagged sections: [0:00 - 0:10] clean 4-bar intro establishing the pocket, [0:10 - 0:40] steady moderate-energy 'calm' groove (at least 16 full bars, clean drums/bass/keys/sax space), [0:40 - 1:15] elevated energetic 'travel' section (at least 16 full bars, fuller brass/sax counter-melodies and driving groove), [1:15 - 1:45] climactic reprise and clean 2-bar cadential turnaround resolving firmly onto the tonic."
      : "Build a 90-120 second continuous instrumental track at an exact rock-steady BPM with time-tagged sections: [0:00 - 0:12] tight 4-bar club pickup into the four-on-the-floor groove, [0:12 - 0:50] full-intensity euphoric 16+ bar main Euro-club loop with pumping octave bass, brassy stabs, and soaring synth-sax/brass counter-melodies, [0:50 - 1:30] elevated layered multi-melody climax maintaining the exact same steady tempo and groove for clean 16-bar looping.";
  return [
    `You are Scrapkeep's Lead Audio Director analyzing the existing reference Ogg stems for pack "${packSpec.id}".`,
    `Attached reference stems (${stemFiles.length} files): ${stemNames}.`,
    `Target World & Role: ${packSpec.world}.`,
    `Target BPM: ${packSpec.bpm} BPM (strictly steady, zero tempo drift).`,
    `Target Key & Colour: ${packSpec.key} (${packSpec.mode}, key_offset ${packSpec.keyOffset} from D).`,
    `Required AceSequencer Clip Schema: ${clipSummary}.`,
    `Current manifest cuts="${manifest?.cuts ?? "unknown"}", timing_verified=${Boolean(manifest?.timing_verified)}.`,
    `Creative Direction: ${packSpec.direction}`,
    "Mandatory Scrapkeep MUSIC-GEMS & TONE-BIBLE Constraints:",
    "- Honour G1-G11: jazz harmony, expressive synth-sax & brass call-and-response, strong complementary basslines (G8), Euro-club funk bounce on euro packs (G3/G4), layered overlapping counter-melodies (G10), escalate by adding layers rather than swapping genres (G11).",
    "- STRICTLY INSTRUMENTAL ONLY: zero vocals, zero singing, zero vocal chops, zero spoken words, zero choir lyrics.",
    "- ZERO R1/R2 artifacts: zero talking growls ('yoi'/'wub'), zero heavy LFO brostep/dubstep wobble bass.",
    "- ZERO East Asian instrumentation or pentatonic oriental motifs.",
    "- NEVER mention any artist name, song title, brand trademark, or copyrighted sample name in lyria_prompt (write original purely descriptive musical terms).",
    "- Clean spectral separation across drums, bass, and harmonic/lead layers so htdemucs splits into crisp 3 stems (drums, bass, other) with minimal mix mud.",
    "Inspect the attached reference stems carefully for: groove pocket, BPM stability, actual tonal centre vs target key, bassline weight, sax/brass/synth lead phrasing, mix mud, and any G1-G11 or R1/R2 issues.",
    `Then write a rich, concrete, time-tagged [0:00 - ...] prompt for Lyria 3.5 (${MUSIC_MODEL}) that keeps what works, fixes every flaw you heard (especially key accuracy, exact tempo lock, and clarity), and follows this structural arc: ${structureHint}`,
    packSpec.bpm >= 160
      ? "TEMPO ANCHOR FOR LYRIA 3.5: Front-load 'Fast 172 BPM liquid drum and bass instrumental, rapid two-step breakbeat snare and 16th-note hi-hats' at the very start of lyria_prompt. Avoid words like 'smooth jazz', 'breezy', 'relaxed', or 'chill' that drag tempo down to 90-120 BPM."
      : "TEMPO ANCHOR FOR LYRIA 3.5: Front-load 'Fast 142 BPM high-energy instrumental Eurodance, four-on-the-floor club kick, pumping offbeat octave synth bass' at the very start of lyria_prompt.",
    "Return ONLY valid JSON matching this exact schema (no markdown fences, no commentary):",
    JSON.stringify({
      pack: packSpec.id,
      groove_notes: "string",
      bpm_stability: "string",
      tonal_centre: "string",
      bassline_notes: "string",
      lead_phrasing: "string",
      mix_mud_notes: "string",
      gems_compliance: "string",
      lyria_prompt:
        "string with [0:00 - ...] time-tagged sections, exact BPM, exact key, instrumentation, and strict instrumental constraints",
    }),
  ].join("\n");
}

export function buildEarGatePrompt(packSpec) {
  return [
    `Listen closely to this newly generated ${MUSIC_MODEL} audio track intended for Scrapkeep pack "${packSpec.id}".`,
    `Target: ${packSpec.bpm} BPM, key of ${packSpec.key} (${packSpec.mode}), ${packSpec.world}.`,
    `Intended Scrapkeep House-Band Style: ${packSpec.direction}`,
    "Evaluate strictly against Scrapkeep's audio gate and MUSIC-GEMS.md (G1-G11: Scrapkeep's house band blends fast liquid DnB or Eurodance rhythms with jazz harmony, electric piano, synth-sax, and brass leads):",
    "1. has_vocals: true if ANY human singing, lyrics, spoken voice, rap, or recognizable vocal chops appear anywhere; false only if strictly instrumental.",
    "2. steady_pulse: true if the tempo and beat grid remain steady and lockable across the main body without major tempo drift or chaotic rubato.",
    "3. estimated_bpm: your best numeric BPM estimate of the main drum groove (note: fast 172 BPM DnB breakbeats should read ~165-178 BPM, not slow 90-125 BPM smooth jazz).",
    "4. fits_key_and_mood: true if the harmonic centre, instrumentation, and energy fit the target world, key/mode, and intended Scrapkeep house-band style above (jazz harmony + sax/brass over fast DnB or Eurodance IS desired; reject only if genre/mood/tempo feel clearly wrong or East Asian instruments appear).",
    "5. has_r1_r2_wubs: true if talking growls ('yoi'/'wub') or heavy LFO dubstep/brostep wobble bass dominate.",
    "6. pass: true ONLY when has_vocals is false, steady_pulse is true, fits_key_and_mood is true, has_r1_r2_wubs is false, and the drum groove matches the target tempo.",
    "Return ONLY valid JSON (no markdown fences, no prose):",
    JSON.stringify({
      has_vocals: false,
      steady_pulse: true,
      estimated_bpm: packSpec.bpm,
      fits_key_and_mood: true,
      has_r1_r2_wubs: false,
      pass: true,
      reasons: ["string"],
      retry_adjustment: "string (empty if pass is true, concrete fix instructions if false)",
    }),
  ].join("\n");
}

export function extractJsonObject(rawText) {
  const text = String(rawText ?? "").trim();
  if (!text) throw new Error("empty model response; expected JSON");
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced ? fenced[1].trim() : text;
  try {
    return JSON.parse(candidate);
  } catch {
    const start = candidate.indexOf("{");
    if (start < 0) throw new Error(`no JSON object found in response: ${text.slice(0, 160)}`);
    let depth = 0;
    let inString = false;
    let escaped = false;
    for (let i = start; i < candidate.length; i++) {
      const ch = candidate[i];
      if (inString) {
        if (escaped) escaped = false;
        else if (ch === "\\") escaped = true;
        else if (ch === '"') inString = false;
        continue;
      }
      if (ch === '"') inString = true;
      else if (ch === "{") depth++;
      else if (ch === "}") {
        depth--;
        if (depth === 0) return JSON.parse(candidate.slice(start, i + 1));
      }
    }
    throw new Error(`unterminated JSON object in response: ${text.slice(0, 160)}`);
  }
}

export function evaluateEarGate(verdict, packSpec) {
  const failures = [];
  if (!verdict || typeof verdict !== "object") {
    return {
      ok: false,
      failures: ["ear-gate response is not a JSON object"],
      adjustment: "Regenerate strictly instrumental track on a steady grid.",
    };
  }
  if (verdict.has_vocals !== false)
    failures.push("vocals detected (must be strictly instrumental)");
  if (verdict.steady_pulse !== true) failures.push("pulse/tempo is unsteady");
  if (verdict.fits_key_and_mood !== true) failures.push("key or mood mismatch");
  if (verdict.has_r1_r2_wubs !== false)
    failures.push("R1/R2 talking growls or heavy wubs detected");
  if (verdict.pass === false) failures.push("model marked pass=false");
  const est = Number(verdict.estimated_bpm);
  if (Number.isFinite(est) && est > 0) {
    const directRatio = Math.abs(est - packSpec.bpm) / packSpec.bpm;
    const halfRatio = Math.abs(est * 2 - packSpec.bpm) / packSpec.bpm;
    const doubleRatio = Math.abs(est / 2 - packSpec.bpm) / packSpec.bpm;
    const withinTempo =
      directRatio <= 0.15 || (packSpec.bpm >= 160 && halfRatio <= 0.1) || doubleRatio <= 0.1;
    if (!withinTempo) {
      failures.push(`estimated BPM ${est} too far from target ${packSpec.bpm}`);
    }
  }
  const adjustment =
    typeof verdict.retry_adjustment === "string" && verdict.retry_adjustment.trim()
      ? verdict.retry_adjustment.trim()
      : failures.join("; ");
  return { ok: failures.length === 0, failures, adjustment };
}

export function applyRetryFeedback(basePrompt, feedback, attempt) {
  const note = sanitizeLyriaPrompt(feedback);
  const prefix = [
    `CRITICAL DIRECTION (attempt ${attempt}):`,
    note ||
      "Keep tempo strictly locked, strictly instrumental with zero vocals and zero dubstep wubs.",
    "Strictly instrumental, no singing, no vocal chops, rock-steady quantized drums.",
  ].join(" ");
  return `${prefix}\n\n${sanitizeLyriaPrompt(basePrompt)}`;
}

export function sanitizeLyriaPrompt(prompt) {
  return String(prompt ?? "")
    .replace(/\bRhodes\b/gi, "warm electric piano")
    .replace(/\bPyramids(?:-style)?\b/gi, "layered counter-melody")
    .replace(/\bReese\b/gi, "detuned sawtooth")
    .replace(/\bAmen\b/gi, "crisp")
    .replace(/\s+/g, " ")
    .trim();
}

export function buildFallbackLyriaPrompt(packSpec) {
  if (packSpec.schema === "roam") {
    return sanitizeLyriaPrompt(
      `Original instrumental fast ${packSpec.bpm} BPM liquid drum and bass soundtrack in ${packSpec.mode}. Crisp rapid breakbeat drums, steady deep sub and melodic bassline, electric piano jazz chords, bright expressive brass and synth-sax melodies. Purely instrumental with no voices or singing. [0:00 - 0:12] Fast ${packSpec.bpm} BPM breakbeat drum intro with warm bass entry and electric piano chords in ${packSpec.key} minor. [0:12 - 0:45] Steady driving ${packSpec.bpm} BPM groove with clear bass pocket, spacious electric piano comping, and melodic synth-sax lead phrases. [0:45 - 1:20] Energetic lifted section adding shimmering ride cymbals, fuller synth-brass stabs, and soaring counter-melodies at locked ${packSpec.bpm} BPM. [1:20 - 1:45] Climactic full-band finish with a crisp two-bar turnaround resolving cleanly onto ${packSpec.key}.`,
    );
  }
  return sanitizeLyriaPrompt(
    `Original instrumental fast ${packSpec.bpm} BPM high-energy Eurodance club boss soundtrack in ${packSpec.mode}. Relentless four-on-the-floor kick drum, crisp offbeat hi-hats, pumping octave funk synth bass, bright supersaw synth chords, punchy brass stabs, and soaring expressive lead melodies. Purely instrumental with no voices or singing. [0:00 - 0:12] Tight four-bar ${packSpec.bpm} BPM four-on-the-floor build into the full club pulse in ${packSpec.key} minor. [0:12 - 0:55] Euphoric high-energy ${packSpec.bpm} BPM main loop with pumping octave bass, brassy chords, and soaring synth-brass and sax lead riffs. [0:55 - 1:35] Elevated climactic final chorus layering bright arpeggios and counter-melodies at rock-steady ${packSpec.bpm} BPM.`,
  );
}

export function validateManifestInvariants(manifest, packSpec) {
  const errors = [];
  const raw = JSON.stringify(manifest);
  if (/\/home\/|\/Users\//.test(raw)) {
    errors.push("manifest contains personal home path");
  }
  if (manifest.cuts !== "lyria-3.5-stem-context") {
    errors.push(`cuts must be "lyria-3.5-stem-context", got ${JSON.stringify(manifest.cuts)}`);
  }
  if (manifest.timing_verified !== true) {
    errors.push("timing_verified must be true");
  }
  if (manifest.rate !== 44100) errors.push(`rate must be 44100, got ${manifest.rate}`);
  if (manifest.key !== packSpec.key)
    errors.push(`key must be ${packSpec.key}, got ${manifest.key}`);
  if (manifest.key_offset !== packSpec.keyOffset) {
    errors.push(`key_offset must be ${packSpec.keyOffset}, got ${manifest.key_offset}`);
  }
  const expectedClips = Object.keys(packSpec.clips).sort();
  const actualClips = Object.keys(manifest.clips ?? {}).sort();
  if (JSON.stringify(expectedClips) !== JSON.stringify(actualClips)) {
    errors.push(
      `clip keys mismatch: expected ${expectedClips.join(",")}, got ${actualClips.join(",")}`,
    );
  }
  for (const [cid, cfg] of Object.entries(packSpec.clips)) {
    const clip = manifest.clips?.[cid];
    if (!clip) continue;
    if (clip.bars !== cfg.bars) errors.push(`${cid}.bars must be ${cfg.bars}, got ${clip.bars}`);
    if (Boolean(clip.loop) !== cfg.loop) errors.push(`${cid}.loop must be ${cfg.loop}`);
    if (Number(clip.bpm) !== packSpec.bpm) {
      errors.push(`${cid}.bpm must be ${packSpec.bpm}, got ${clip.bpm}`);
    }
    const tp = clip.measured?.true_peak;
    if (typeof tp !== "number" || tp > MAX_TRUE_PEAK) {
      errors.push(`${cid} true_peak ${tp} exceeds ${MAX_TRUE_PEAK} dBTP`);
    }
    const seconds = (clip.sample_count ?? 0) / (manifest.rate ?? 44100);
    if (seconds >= 10) {
      const lufs = clip.measured?.lufs;
      if (typeof lufs !== "number" || Math.abs(lufs - TARGET_LUFS) > LUFS_TOL) {
        errors.push(`${cid} lufs ${lufs} outside ${TARGET_LUFS} +/- ${LUFS_TOL}`);
      }
      if (typeof lufs === "number" && Math.abs(lufs - TARGET_LUFS) > MANIFEST_LUFS_TOL) {
        errors.push(`${cid} lufs ${lufs} outside ${TARGET_LUFS} +/- ${MANIFEST_LUFS_TOL}`);
      }
    }
  }
  return errors;
}

export function updateStemHashesText(existingText, updatesMap) {
  const entries = new Map();
  for (const line of String(existingText ?? "").split("\n")) {
    const m = /^([0-9a-f]{64})  (\S+)$/.exec(line.trim());
    if (m) entries.set(m[2], m[1]);
  }
  for (const [rel, hash] of Object.entries(updatesMap)) {
    entries.set(rel, hash);
  }
  return (
    [...entries.keys()]
      .sort()
      .map((rel) => `${entries.get(rel)}  ${rel}`)
      .join("\n") + "\n"
  );
}

export function buildRemoteProcessorScript() {
  return `import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.ndimage import minimum_filter1d, uniform_filter1d

cfg = json.loads(Path(sys.argv[1]).read_text())
repo = Path(cfg["remote_root"])
sketch = repo / "sketches" / "core-loop"
sys.path.insert(0, str(sketch / "tools" / "ace"))
sys.path.insert(0, str(sketch / "design-v3" / "sound"))

import cut_loops
from package_music import LOOP_JOIN, POST_ROLL, PRE_ROLL, RATE, STEMS, cut_clip, encode, sha
from repage import MAX_PAGE_S, PAGE_USEC, longest_page

pack = cfg["pack"]
bpm = int(cfg["bpm"])
key = cfg["key"]
key_offset = int(cfg["key_offset"])
schema = cfg["schema"]
work = Path(cfg["remote_work"])
raw_input = Path(cfg["raw_input"])
staged_pack = repo / "artifacts" / "local" / "music_ace_staged" / pack
out_oggs = work / "oggs"
out_oggs.mkdir(parents=True, exist_ok=True)
(work / "stretched").mkdir(parents=True, exist_ok=True)
(work / "stems").mkdir(parents=True, exist_ok=True)

raw_44k = work / "raw_44k.wav"
subprocess.run(
    ["ffmpeg", "-v", "error", "-y", "-i", str(raw_input), "-ar", str(RATE), "-ac", "2", "-c:a", "pcm_s16le", str(raw_44k)],
    check=True,
)


def measure_bpm(wav_path, target_bpm):
    audio, sr = sf.read(wav_path, always_2d=True)
    mono = audio.mean(axis=1)
    n = len(mono)
    body = mono[int(n * 0.15):int(n * 0.85)] if n > sr * 25 else mono
    hop = 256
    frames = len(body) // hop
    rms = np.sqrt((body[:frames * hop].reshape(frames, hop) ** 2).mean(axis=1))
    flux = np.maximum(np.diff(np.log1p(rms * 100.0), prepend=0.0), 0.0)
    flux = flux - flux.mean()
    rate = sr / hop
    ac = np.correlate(flux, flux, mode="full")[len(flux) - 1:]
    lo = target_bpm * 0.88
    hi = target_bpm * 1.12
    coarse_best = None
    for t in np.arange(lo, hi + 0.01, 0.1):
        lag = rate * 60.0 / t
        score = sum(float(np.interp(k * lag, np.arange(len(ac)), ac)) for k in (1, 2, 4, 8))
        if coarse_best is None or score > coarse_best[0]:
            coarse_best = (score, float(t))
    coarse = coarse_best[1]
    fine_best = coarse_best
    for t in np.arange(coarse - 0.25, coarse + 0.25, 0.01):
        lag = rate * 60.0 / t
        score = sum(float(np.interp(k * lag, np.arange(len(ac)), ac)) for k in (1, 2, 4, 8))
        if score > fine_best[0]:
            fine_best = (score, float(t))
    return round(fine_best[1], 3)


bpm_before = measure_bpm(raw_44k, bpm)
stretched_wav = work / "stretched" / f"{pack}.wav"
stretch_tmp = work / "stretched" / f"{pack}.rb.wav"
stretch_mode = "as_is"
if 0.0008 < abs(bpm_before / bpm - 1.0) <= 0.14:
    ratio = bpm / bpm_before
    subprocess.run(
        ["rubberband", "-q", "--fine", "-T", f"{ratio:.6f}", str(raw_44k), str(stretch_tmp)],
        check=True,
    )
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", str(stretch_tmp), "-ar", str(RATE), "-ac", "2", "-c:a", "pcm_s16le", str(stretched_wav)],
        check=True,
    )
    bpm_after = measure_bpm(stretched_wav, bpm)
    if abs(bpm_after - bpm) > abs(bpm_before - bpm) + 1.5:
        shutil.copyfile(raw_44k, stretched_wav)
        bpm_after = bpm_before
        stretch_mode = "fallback_unstretched"
    else:
        stretch_mode = f"rubberband:{ratio:.6f}"
else:
    shutil.copyfile(raw_44k, stretched_wav)
    bpm_after = bpm_before

demucs_bin = cfg["remote_demucs"]
demucs_run = subprocess.run(
    [demucs_bin, "-n", "htdemucs", "-d", "cuda", "-o", str(work / "stems"), str(stretched_wav)],
    capture_output=True,
    text=True,
)
if demucs_run.returncode != 0:
    subprocess.run(
        [demucs_bin, "-n", "htdemucs", "-d", "cpu", "-o", str(work / "stems"), str(stretched_wav)],
        check=True,
    )

stem_dir = work / "stems" / "htdemucs" / pack
raw_stems = {}
for s in ("drums", "bass", "other", "vocals"):
    y, sr = sf.read(stem_dir / f"{s}.wav", always_2d=True)
    if sr != RATE:
        raise SystemExit(f"{s}.wav expected {RATE} Hz, got {sr}")
    raw_stems[s] = y.astype(np.float64)

length = min(len(v) for v in raw_stems.values())
audio = {
    "drums": raw_stems["drums"][:length],
    "bass": raw_stems["bass"][:length],
    "other": raw_stems["other"][:length] + raw_stems["vocals"][:length],
}

beat = round(RATE * 60 / bpm)
bar = beat * 4


def onset_env_hop(mono, hop=128):
    n = len(mono) // hop
    rms = np.sqrt((mono[:n * hop].reshape(n, hop) ** 2).mean(axis=1))
    return np.maximum(np.diff(rms, prepend=rms[0]), 0.0)


def find_downbeat(drums, bass):
    hop = 128
    de = onset_env_hop(drums.mean(axis=1), hop)
    best_off, best_score = 0, -1.0
    for off in range(0, beat, hop):
        idx = np.arange(off // hop, len(de), beat / hop).astype(int)
        idx = idx[idx < len(de)]
        score = float(de[idx].sum()) if len(idx) else 0.0
        if score > best_score:
            best_off, best_score = off, score
    be = onset_env_hop(bass.mean(axis=1), hop)
    pick_j, pick_score = 0, -1.0
    for j in range(4):
        start = best_off + j * beat
        idx = np.arange(start / hop, len(be), bar / hop).astype(int)
        idx = idx[idx < len(be)]
        score = float(be[idx].sum()) if len(idx) else 0.0
        if score > pick_score:
            pick_j, pick_score = j, score
    return int(best_off + pick_j * beat)


downbeat = find_downbeat(audio["drums"], audio["bass"])
whole_bars = (length - downbeat - POST_ROLL) // bar
mix_full = audio["drums"] + audio["bass"] + audio["other"]


def bar_rms(bar_idx):
    a = downbeat + (bar_idx - 1) * bar
    b = a + bar
    seg = mix_full[a:b]
    return float(np.sqrt(np.mean(seg ** 2) + 1e-12))


def window_rms(first_bar, num_bars):
    vals = [bar_rms(b) for b in range(first_bar, first_bar + num_bars)]
    return float(np.mean(vals)), float(np.min(vals))


active_bars = [b for b in range(1, whole_bars + 1) if bar_rms(b) > 0.025]
if not active_bars:
    active_bars = list(range(1, whole_bars + 1))
first_active = active_bars[0]
last_active = active_bars[-1]

plan = {}
if schema == "roam":
    if whole_bars < 34:
        raise SystemExit(f"{pack}: track too short ({whole_bars} bars) for roam schema")
    calm_start = max(first_active + 2, 5)
    if calm_start + 33 > last_active:
        calm_start = max(1, first_active)
    calm_cands = []
    max_calm_start = max(calm_start, min(calm_start + 12, last_active - 33))
    for sb in range(calm_start, max_calm_start + 1):
        mean_r, min_r = window_rms(sb, 16)
        if min_r > 0.02:
            calm_cands.append((mean_r, sb))
    if calm_cands:
        calm_cands.sort(key=lambda x: x[0])
        calm_bar = calm_cands[min(len(calm_cands) // 3, len(calm_cands) - 1)][1]
    else:
        calm_bar = calm_start
    travel_min = calm_bar + 16
    travel_max = max(travel_min, last_active - 18)
    travel_best = None
    for sb in range(travel_min, travel_max + 1):
        mean_r, min_r = window_rms(sb, 16)
        score = mean_r + 0.5 * min_r
        if travel_best is None or score > travel_best[0]:
            travel_best = (score, sb)
    travel_bar = travel_best[1] if travel_best else travel_min
    cadence_bar = max(travel_bar + 16, last_active - 1)
    if cadence_bar + 1 > whole_bars:
        cadence_bar = whole_bars - 1
    while cadence_bar > travel_bar + 16 and bar_rms(cadence_bar) < 0.03:
        cadence_bar -= 1
    plan["calm"] = (calm_bar, 16, 1)
    plan["travel"] = (travel_bar, 16, 1)
    plan["cadence"] = (cadence_bar, 2, None)
else:
    if whole_bars < 18:
        raise SystemExit(f"{pack}: track too short ({whole_bars} bars) for euro 16-bar loop")
    start_lo = max(first_active + 2, 5)
    start_hi = max(start_lo, last_active - 17)
    main_best = None
    for sb in range(start_lo, start_hi + 1):
        mean_r, min_r = window_rms(sb, 16)
        score = mean_r + 0.6 * min_r
        if main_best is None or score > main_best[0]:
            main_best = (score, sb)
    main_bar = main_best[1] if main_best else start_lo
    plan["main"] = (main_bar, 16, 1)


def measure_ebur128(samples_f32):
    out = subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-nostats",
            "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-i", "pipe:0",
            "-af", "ebur128=peak=true", "-f", "null", "-",
        ],
        input=samples_f32.astype("<f4").tobytes(),
        capture_output=True,
        check=True,
    ).stderr.decode()
    i_hits = re.findall(r"^\\s*I:\\s+(-?[\\d.]+|-inf)\\s+LUFS", out, re.M)
    p_hits = re.findall(r"^\\s*Peak:\\s+(-?[\\d.]+|-inf)\\s+dBFS", out, re.M)
    lufs = float(i_hits[-1]) if i_hits and i_hits[-1] != "-inf" else -70.0
    tp = float(p_hits[-1]) if p_hits and p_hits[-1] != "-inf" else -70.0
    return lufs, tp


def limit_stems(pcm_map, ceiling_db=-2.0):
    mix = np.abs(sum(pcm_map.values())).max(axis=1)
    ceiling = 10.0 ** (ceiling_db / 20.0)
    want = np.minimum(1.0, ceiling / np.maximum(mix, 1e-9))
    if want.min() >= 1.0:
        return pcm_map
    held = minimum_filter1d(want, size=int(RATE * 0.012), mode="nearest")
    g = uniform_filter1d(held, size=int(RATE * 0.008), mode="nearest")[:, None]
    return {s: v * g for s, v in pcm_map.items()}


def decode_ogg_f32(ogg_path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(ogg_path), "-f", "f32le", "-ac", "2", "-ar", str(RATE), "pipe:1"],
        capture_output=True,
        check=True,
    ).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2)


def seam_step(samples, exit_frame, loop_at):
    frames = len(samples)
    end = min(exit_frame, frames)
    seg = samples[loop_at:end]
    diffs = np.abs(np.diff(seg, axis=0)).reshape(-1)
    diffs.sort()
    p999 = float(diffs[min(len(diffs) - 1, int(len(diffs) * 0.999))]) if len(diffs) else 0.0
    wrap = float(np.max(np.abs(samples[loop_at] - samples[end - 1])))
    return wrap, p999, wrap <= p999


def apply_micro_seam_blend(pcm_map, loop_at, fade_len=64):
    out = {}
    t = np.linspace(0.0, 1.0, fade_len)[:, None]
    for s, v in pcm_map.items():
        c = v.copy()
        head_val = c[loop_at:loop_at + 1]
        c[-fade_len:] = c[-fade_len:] * (1.0 - t) + head_val * t
        out[s] = c
    return out


clips_report = {}
ogg_hashes = {}
max_page_seen = 0.0

for cid, (first_bar, bars, loop_bar) in plan.items():
    frames = bars * bar
    chosen = None
    max_shift = 4 if loop_bar is not None else 1
    for shift in range(max_shift):
        sb = first_bar + shift
        if sb + bars - 1 > whole_bars:
            break
        start = downbeat + (sb - 1) * bar
        state = dict(source_start=start, frames=frames)
        raw_clips = {s: cut_clip(audio[s], state, 0, loop_bar, bar) for s in STEMS}
        pcm = {s: raw_clips[s][0] for s in STEMS}
        loop_offset = raw_clips["drums"][1] or 0
        exit_frame = PRE_ROLL + frames
        duration_s = len(pcm["drums"]) / RATE
        ceiling_db = -2.2
        gain_db = 0.0
        for _ in range(6):
            cand = limit_stems({s: v * (10.0 ** (gain_db / 20.0)) for s, v in pcm.items()}, ceiling_db)
            i_pre, _p_pre = measure_ebur128(sum(cand.values()))
            want = -16.0 - i_pre
            if duration_s < 10.0:
                gain_db = float(np.clip(gain_db + want, -12.0, 8.0))
                break
            if abs(want) < 0.05:
                break
            gain_db += want

        micro_blend = False
        final_metrics = None
        for _iter in range(6):
            scaled = limit_stems({s: v * (10.0 ** (gain_db / 20.0)) for s, v in pcm.items()}, ceiling_db)
            if micro_blend and loop_bar is not None:
                scaled = apply_micro_seam_blend(scaled, loop_offset, 96)
            files = {}
            decoded_sum = None
            for s in STEMS:
                name = f"{cid}.{s}.ogg"
                target_ogg = out_oggs / name
                encode(scaled[s], target_ogg)
                pg_s, _pg_n = longest_page(target_ogg)
                if pg_s > MAX_PAGE_S:
                    raise SystemExit(f"{pack}/{name}: page {pg_s:.3f}s exceeds {MAX_PAGE_S}s")
                max_page_seen = max(max_page_seen, pg_s)
                files[s] = name
                dec = decode_ogg_f32(target_ogg)
                decoded_sum = dec.copy() if decoded_sum is None else decoded_sum + dec
            lufs_post, tp_post = measure_ebur128(decoded_sum)
            seam_ok = True
            wrap_val = 0.0
            p999_val = 0.0
            if loop_bar is not None:
                wrap_val, p999_val, seam_ok = seam_step(decoded_sum, exit_frame, loop_offset)
            tp_ok = tp_post <= -1.2
            lufs_ok = True if duration_s < 10.0 else abs(lufs_post - (-16.0)) <= 0.15
            if tp_ok and lufs_ok and seam_ok:
                final_metrics = (
                    sb,
                    start,
                    len(decoded_sum),
                    loop_offset,
                    exit_frame,
                    gain_db,
                    lufs_post,
                    tp_post,
                    wrap_val,
                    p999_val,
                    files,
                )
                break
            if not tp_ok:
                ceiling_db -= max(0.4, tp_post - (-1.6))
            if not lufs_ok:
                gain_db += (-16.0 - lufs_post)
            if not seam_ok:
                micro_blend = True
        if final_metrics is not None:
            chosen = final_metrics
            break
    if chosen is None:
        raise SystemExit(f"{pack}/{cid}: failed to converge LUFS/TP/seam after retries")
    sb, start, count, loop_offset, exit_frame, gain_db, lufs_post, tp_post, wrap_val, p999_val, files = chosen
    clips_report[cid] = dict(
        source_bars=f"{sb}-{sb + bars - 1}",
        source_start=int(start),
        take_start=int(start),
        bpm=float(bpm) if schema == "roam" else int(bpm),
        beat=int(beat),
        bar=int(bar),
        beats_per_bar=4,
        bars=int(bars),
        entry=int(PRE_ROLL),
        exit=int(exit_frame),
        loop=loop_bar is not None,
        loop_offset=int(loop_offset),
        loop_to_bar=loop_bar,
        sample_count=int(count),
        key=key,
        key_offset=key_offset,
        files=files,
        gain_db=round(float(gain_db), 2),
        measured=dict(
            lufs=round(float(lufs_post), 2),
            true_peak=round(float(tp_post), 2),
            note="summed decoded Ogg stems",
        ),
        seam=dict(wrap=round(float(wrap_val), 4), p999=round(float(p999_val), 4)) if loop_bar is not None else None,
    )
    staged_pack.mkdir(parents=True, exist_ok=True)
    for s, name in files.items():
        src_ogg = out_oggs / name
        dst_ogg = staged_pack / name
        shutil.copyfile(src_ogg, dst_ogg)
        ogg_hashes[f"{pack}/{name}"] = sha(dst_ogg)

stem_hashes = {s: sha(stem_dir / f"{s}.wav") for s in ("drums", "bass", "other", "vocals")}
report = dict(
    pack=pack,
    bpm_target=bpm,
    bpm_before=bpm_before,
    bpm_after=bpm_after,
    stretch_mode=stretch_mode,
    downbeat=int(downbeat),
    whole_bars=int(whole_bars),
    raw_sha256=sha(raw_input),
    stretched_sha256=sha(stretched_wav),
    stem_hashes=stem_hashes,
    max_page_s=round(float(max_page_seen), 4),
    clips=clips_report,
    ogg_hashes=ogg_hashes,
)
(work / "stage3_report.json").write_text(json.dumps(report, indent=2) + "\\n")
print(json.dumps(report))
`;
}

function runCommand(cmd, args, options = {}) {
  const res = spawnSync(cmd, args, {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    ...options,
  });
  if (res.error) throw res.error;
  if (res.status !== 0) {
    const detail = [res.stderr, res.stdout].filter(Boolean).join("\n").trim();
    throw new Error(`${cmd} ${args.join(" ")} failed (exit ${res.status}): ${detail}`);
  }
  return res.stdout;
}

function listOggFiles(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((name) => name.toLowerCase().endsWith(".ogg"))
    .sort()
    .map((name) => path.join(dir, name));
}

function prepareEarGateAudio(audioPath, workDir, env) {
  const size = statSync(audioPath).size;
  if (size <= MAX_INLINE_BYTES) return audioPath;
  const compact = path.join(workDir, "lyria_eargate.mp3");
  runCommand(
    "ffmpeg",
    ["-v", "error", "-y", "-i", audioPath, "-ac", "2", "-b:a", "128k", compact],
    { env },
  );
  return compact;
}

export function buildUpdatedManifest(existingManifest, packSpec, stage1, stage3) {
  const next = JSON.parse(JSON.stringify(existingManifest));
  next.rate = 44100;
  next.key = packSpec.key;
  next.key_offset = packSpec.keyOffset;
  next.level_db = 0.0;
  next.cuts = "lyria-3.5-stem-context";
  next.timing_verified = true;

  const portableStems = {};
  for (const stem of ["drums", "bass", "other", "vocals"]) {
    portableStems[stem] = {
      path: `lyria-work:${packSpec.id}/stems/${stem}.wav`,
      sha256: stage3.stem_hashes[stem],
    };
  }

  if (packSpec.schema === "roam") {
    next.pick = "lyria-3.5-stem-context";
    next.sources = {};
    for (const cid of ["calm", "travel", "cadence"]) {
      next.sources[cid] = {
        take: `${packSpec.id}-lyria-3.5`,
        render: `lyria-work:${packSpec.id}/lyria_raw.wav`,
        render_sha256: stage3.raw_sha256,
        stretched: `lyria-work:${packSpec.id}/stretched.wav`,
        stretched_sha256: stage3.stretched_sha256,
        model: MUSIC_MODEL,
        analyzer: ANALYZE_MODEL,
        tempo_read: stage3.bpm_before,
        bpm_after: stage3.bpm_after,
        stretch_mode: stage3.stretch_mode,
        timing: "grid-locked downbeat from drums and bass stems, ear-gated and seam-verified",
        split: {
          tool: "htdemucs, vocals folded into other",
          stems: portableStems,
        },
      };
    }
    for (const cid of ["calm", "travel", "cadence"]) {
      const c = stage3.clips[cid];
      next.clips[cid] = {
        parent: "roam",
        take: `${packSpec.id}-lyria-3.5`,
        source_state: `${packSpec.id}-lyria-3.5 bars ${c.source_bars}`,
        source_bars: c.source_bars,
        source_start: c.source_start,
        take_start: c.take_start,
        bpm: c.bpm,
        beat: c.beat,
        bar: c.bar,
        beats_per_bar: c.beats_per_bar,
        bars: c.bars,
        entry: c.entry,
        exit: c.exit,
        loop: c.loop,
        loop_offset: c.loop_offset,
        loop_to_bar: c.loop_to_bar,
        sample_count: c.sample_count,
        key: c.key,
        key_offset: c.key_offset,
        files: c.files,
        gain_db: c.gain_db,
        measured: c.measured,
      };
      if (c.seam) next.clips[cid].seam = c.seam;
    }
  } else {
    const c = stage3.clips.main;
    next.sources = {
      main: {
        take: `${packSpec.id}-lyria-3.5`,
        source: `lyria-work:${packSpec.id}/lyria_raw.wav`,
        source_sha256: stage3.raw_sha256,
        stretched: `lyria-work:${packSpec.id}/stretched.wav`,
        stretched_sha256: stage3.stretched_sha256,
        model: MUSIC_MODEL,
        analyzer: ANALYZE_MODEL,
        bpm_before: stage3.bpm_before,
        bpm_after: stage3.bpm_after,
        stretch_mode: stage3.stretch_mode,
        stems: portableStems,
        note: "htdemucs; vocals folded into other",
      },
    };
    next.clips = {
      main: {
        parent: "single",
        take: `${packSpec.id}-lyria-3.5`,
        source_bars: c.source_bars,
        source_start: c.source_start,
        take_start: c.take_start,
        bpm: c.bpm,
        beat: c.beat,
        bar: c.bar,
        beats_per_bar: c.beats_per_bar,
        bars: c.bars,
        entry: c.entry,
        exit: c.exit,
        loop: c.loop,
        loop_offset: c.loop_offset,
        loop_to_bar: c.loop_to_bar,
        sample_count: c.sample_count,
        key: c.key,
        key_offset: c.key_offset,
        files: c.files,
        gain_db: c.gain_db,
        measured: c.measured,
        seam: c.seam,
      },
    };
    next.gain_db = c.gain_db;
    next.measured = c.measured;
  }

  next.lyria_context = {
    model: MUSIC_MODEL,
    analyzer: ANALYZE_MODEL,
    tonal_centre_audit: stage1?.tonal_centre ?? "",
    gems_compliance: stage1?.gems_compliance ?? "",
  };
  return next;
}

function regenerateRemoteStemHashes(opts, env) {
  const remoteStageManifests = `${opts.remoteRoot}/artifacts/local/lyria-work/_manifests`;
  runCommand("ssh", [opts.sshHost, `mkdir -p ${JSON.stringify(remoteStageManifests)}`], { env });
  for (const packId of opts.packs) {
    const localManifest = path.join(MUSIC_ACE_DIR, packId, "manifest.json");
    runCommand(
      "scp",
      ["-q", localManifest, `${opts.sshHost}:${remoteStageManifests}/${packId}.manifest.json`],
      { env },
    );
  }
  const cmd = [
    "set -euo pipefail",
    `cd ${JSON.stringify(opts.remoteRoot)}`,
    "TMP=$(mktemp -d)",
    'trap "rm -rf \\"$TMP\\"" EXIT',
    'mkdir -p "$TMP/sketches/core-loop/assets"',
    'cp -a sketches/core-loop/assets/music_ace "$TMP/sketches/core-loop/assets/music_ace"',
    'cp -a artifacts/local/music_ace_staged/. "$TMP/sketches/core-loop/assets/music_ace/"',
    ...opts.packs.map(
      (p) =>
        `cp ${JSON.stringify(`${remoteStageManifests}/${p}.manifest.json`)} "$TMP/sketches/core-loop/assets/music_ace/${p}/manifest.json"`,
    ),
    'node scripts/audio-gate.mjs --write-stem-hashes --project "$TMP/sketches/core-loop" >/dev/null',
    'cp "$TMP/sketches/core-loop/assets/music_ace/STEMS.sha256" artifacts/local/music_ace_staged/STEMS.sha256',
    'cat "$TMP/sketches/core-loop/assets/music_ace/STEMS.sha256"',
  ].join("\n");
  const freshHashes = runCommand("ssh", [opts.sshHost, cmd], { env });
  writeFileSync(path.join(MUSIC_ACE_DIR, "STEMS.sha256"), freshHashes);
  return freshHashes.trim().split("\n").length;
}

export function runPipeline(opts, deps = {}) {
  const exec = deps.runCommand ?? runCommand;
  const env = buildGeminiEnv(process.env, opts.apiKey);
  const results = [];

  for (const packId of opts.packs) {
    const spec = resolvePackSpec(packId);
    const manifestPath = path.join(MUSIC_ACE_DIR, packId, "manifest.json");
    const existingManifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    const packWork = path.join(opts.outDir, packId);
    const refDir = opts.refDir
      ? existsSync(path.join(opts.refDir, packId))
        ? path.join(opts.refDir, packId)
        : opts.refDir
      : path.join(packWork, "ref");

    if (opts.dryRun) {
      const refStems = listOggFiles(refDir);
      const previewStems =
        refStems.length > 0
          ? refStems
          : Object.values(existingManifest.clips ?? {}).flatMap((c) =>
              Object.values(c.files ?? {}).map((f) => path.join(refDir, f)),
            );
      const stage1Prompt = buildStage1Prompt(spec, existingManifest, previewStems);
      const earPrompt = buildEarGatePrompt(spec);
      results.push({
        pack: packId,
        dryRun: true,
        bpm: spec.bpm,
        key: spec.key,
        schema: spec.schema,
        refDir,
        workDir: packWork,
        stage1StemCount: previewStems.length,
        stage1PromptChars: stage1Prompt.length,
        earGatePromptChars: earPrompt.length,
        remoteWork: `${opts.remoteRoot}/artifacts/local/lyria-work/${packId}`,
      });
      continue;
    }

    mkdirSync(packWork, { recursive: true });
    let stage1;
    let acceptedAudio = null;
    let acceptedGate = null;
    const attempts = [];
    const savedStage1 = path.join(packWork, "stage1_analysis.json");
    const savedRawWav = path.join(packWork, "lyria_raw.wav");
    const savedRawMp3 = path.join(packWork, "lyria_raw.mp3");
    const savedGate = path.join(packWork, "stage2_eargate.json");
    const reusableRaw = existsSync(savedRawWav)
      ? savedRawWav
      : existsSync(savedRawMp3)
        ? savedRawMp3
        : null;

    if (opts.reuseRaw && existsSync(savedStage1) && reusableRaw) {
      process.stderr.write(`[${packId}] Reusing cached Stage 1 & Stage 2 audio: ${reusableRaw}\n`);
      stage1 = JSON.parse(readFileSync(savedStage1, "utf8"));
      acceptedAudio = reusableRaw;
      if (existsSync(savedGate)) {
        const prev = JSON.parse(readFileSync(savedGate, "utf8"));
        acceptedGate = prev.attempts?.at(-1)?.verdict ?? null;
        attempts.push(...(prev.attempts ?? []));
      }
    } else {
      if (!opts.refDir) {
        mkdirSync(refDir, { recursive: true });
        const remoteRef = `${opts.remoteRoot}/artifacts/local/music_ace_staged/${packId}/*.ogg`;
        exec("scp", ["-q", `${opts.sshHost}:${remoteRef}`, `${refDir}/`], { env });
      }
      const refStems = listOggFiles(refDir);
      if (refStems.length === 0) {
        throw new Error(`${packId}: no reference .ogg stems found in ${refDir}`);
      }

      const stage1Prompt = buildStage1Prompt(spec, existingManifest, refStems);
      process.stderr.write(
        `[${packId}] Stage 1: analyzing ${refStems.length} reference stems with ${ANALYZE_MODEL}\n`,
      );
      const stage1Args = ["analyze", "-m", ANALYZE_MODEL];
      for (const stem of refStems) stage1Args.push("-i", stem);
      stage1Args.push(
        "--system",
        "Return ONLY valid JSON matching the requested schema. No markdown fences or extra prose.",
        stage1Prompt,
      );
      const stage1Raw = exec("gemini-api", stage1Args, { env });
      stage1 = extractJsonObject(stage1Raw);
      if (!stage1.lyria_prompt || typeof stage1.lyria_prompt !== "string") {
        throw new Error(`${packId}: Stage 1 analysis missing lyria_prompt`);
      }
      writeFileSync(savedStage1, JSON.stringify(stage1, null, 2) + "\n");

      if (opts.analyzeOnly) {
        results.push({
          pack: packId,
          analyzeOnly: true,
          refStemCount: refStems.length,
          tonalCentre: stage1.tonal_centre,
          lyriaPrompt: stage1.lyria_prompt,
        });
        continue;
      }

      let currentPrompt = sanitizeLyriaPrompt(stage1.lyria_prompt);

      for (let attempt = 1; attempt <= opts.maxAttempts; attempt++) {
        process.stderr.write(
          `[${packId}] Stage 2 (attempt ${attempt}/${opts.maxAttempts}): generating with ${MUSIC_MODEL}\n`,
        );
        const targetOut = path.join(packWork, `lyria_attempt_${attempt}.wav`);
        const promptFile = path.join(packWork, `lyria_prompt_${attempt}.txt`);
        writeFileSync(promptFile, currentPrompt + "\n");
        let musicStdout;
        try {
          musicStdout = exec(
            "gemini-api",
            [
              "music",
              "-m",
              MUSIC_MODEL,
              "-f",
              promptFile,
              "--body",
              JSON.stringify({ response_format: { mime_type: "audio/wav" } }),
              "--out",
              targetOut,
            ],
            { env },
          );
        } catch (err) {
          const msg = err instanceof Error ? err.message : String(err);
          if (/recitation|copyright/i.test(msg) && attempt < opts.maxAttempts) {
            process.stderr.write(
              `[${packId}] Stage 2 attempt ${attempt}: blocked by recitation filter, retrying with clean original prompt\n`,
            );
            attempts.push({
              attempt,
              path: null,
              verdict: null,
              evaluation: { ok: false, failures: ["recitation filter"], adjustment: "rephrase" },
            });
            currentPrompt = buildFallbackLyriaPrompt(spec);
            continue;
          }
          throw err;
        }
        const writtenPath = musicStdout.trim().split("\n").pop().trim();
        if (!writtenPath || !existsSync(writtenPath)) {
          throw new Error(
            `${packId}: lyria-3.5 did not produce an audio file (stdout: ${musicStdout})`,
          );
        }
        const gateInput = prepareEarGateAudio(writtenPath, packWork, env);
        const gateRaw = exec(
          "gemini-api",
          [
            "analyze",
            "-m",
            ANALYZE_MODEL,
            "-i",
            gateInput,
            "--system",
            "Return ONLY valid JSON matching the requested schema. No markdown fences or extra prose.",
            buildEarGatePrompt(spec),
          ],
          { env },
        );
        const verdict = extractJsonObject(gateRaw);
        const evalRes = evaluateEarGate(verdict, spec);
        process.stderr.write(
          `[${packId}] Stage 2 ear-gate attempt ${attempt}: ok=${evalRes.ok} est_bpm=${verdict.estimated_bpm} vocals=${verdict.has_vocals} wubs=${verdict.has_r1_r2_wubs}\n`,
        );
        attempts.push({ attempt, path: writtenPath, verdict, evaluation: evalRes });
        writeFileSync(savedGate, JSON.stringify({ attempts }, null, 2) + "\n");
        if (evalRes.ok) {
          acceptedAudio = writtenPath;
          acceptedGate = verdict;
          break;
        }
        currentPrompt = applyRetryFeedback(stage1.lyria_prompt, evalRes.adjustment, attempt + 1);
      }
    }

    if (!acceptedAudio) {
      const last = attempts.at(-1);
      throw new Error(
        `${packId}: rejected by ear-gate after ${opts.maxAttempts} attempt(s): ${last?.evaluation?.failures?.join("; ")}`,
      );
    }

    const canonicalRaw = path.join(packWork, `lyria_raw${path.extname(acceptedAudio) || ".wav"}`);
    if (path.resolve(acceptedAudio) !== path.resolve(canonicalRaw)) {
      copyFileSync(acceptedAudio, canonicalRaw);
    }

    const remoteWork = `${opts.remoteRoot}/artifacts/local/lyria-work/${packId}`;
    const remoteRaw = `${remoteWork}/${path.basename(canonicalRaw)}`;
    const remoteScript = `${remoteWork}/process_lyria.py`;
    const remoteCfg = `${remoteWork}/process_cfg.json`;
    const localScript = path.join(packWork, "process_lyria.py");
    const localCfg = path.join(packWork, "process_cfg.json");

    writeFileSync(localScript, buildRemoteProcessorScript());
    writeFileSync(
      localCfg,
      JSON.stringify(
        {
          pack: packId,
          bpm: spec.bpm,
          key: spec.key,
          key_offset: spec.keyOffset,
          schema: spec.schema,
          remote_root: opts.remoteRoot,
          remote_work: remoteWork,
          remote_demucs: REMOTE_DEMUCS,
          raw_input: remoteRaw,
        },
        null,
        2,
      ) + "\n",
    );

    exec("ssh", [opts.sshHost, `mkdir -p ${JSON.stringify(remoteWork)}`], { env });
    exec("scp", ["-q", canonicalRaw, `${opts.sshHost}:${remoteRaw}`], { env });
    exec("scp", ["-q", localScript, `${opts.sshHost}:${remoteScript}`], { env });
    exec("scp", ["-q", localCfg, `${opts.sshHost}:${remoteCfg}`], { env });

    process.stderr.write(
      `[${packId}] Stage 3: grid-lock, htdemucs split, -16 LUFS master, 20ms Ogg on ${opts.sshHost}\n`,
    );
    const stage3Out = exec(
      "ssh",
      [
        opts.sshHost,
        `${REMOTE_PYTHON} ${JSON.stringify(remoteScript)} ${JSON.stringify(remoteCfg)}`,
      ],
      { env },
    );
    const stage3 = JSON.parse(stage3Out.trim().split("\n").pop());
    writeFileSync(
      path.join(packWork, "stage3_report.json"),
      JSON.stringify(stage3, null, 2) + "\n",
    );

    const updatedManifest = buildUpdatedManifest(existingManifest, spec, stage1, stage3);
    const invariantErrors = validateManifestInvariants(updatedManifest, spec);
    if (invariantErrors.length > 0) {
      throw new Error(`${packId}: manifest invariant failure: ${invariantErrors.join("; ")}`);
    }
    writeFileSync(manifestPath, JSON.stringify(updatedManifest, null, 1) + "\n");

    const localOggDir = path.join(packWork, "oggs");
    mkdirSync(localOggDir, { recursive: true });
    exec("scp", ["-q", `${opts.sshHost}:${remoteWork}/oggs/*.ogg`, `${localOggDir}/`], { env });

    results.push({
      pack: packId,
      attempts: attempts.length,
      earGate: acceptedGate,
      bpmBefore: stage3.bpm_before,
      bpmAfter: stage3.bpm_after,
      stretchMode: stage3.stretch_mode,
      maxPageS: stage3.max_page_s,
      clips: Object.fromEntries(
        Object.entries(stage3.clips).map(([cid, c]) => [
          cid,
          { bars: c.source_bars, gain_db: c.gain_db, measured: c.measured, seam: c.seam },
        ]),
      ),
      oggHashes: stage3.ogg_hashes,
    });
  }

  let totalStemHashes = null;
  if (!opts.dryRun && !opts.analyzeOnly && results.length > 0) {
    totalStemHashes = regenerateRemoteStemHashes(opts, env);
  }
  return { results, totalStemHashes };
}

function isMain() {
  if (!process.argv[1]) return false;
  try {
    return realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1]);
  } catch {
    return fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
  }
}

if (isMain()) {
  try {
    const opts = parseArgs(process.argv.slice(2));
    if (opts.help) {
      console.log(usageText());
      process.exitCode = 0;
    } else {
      const summary = runPipeline(opts);
      console.log(JSON.stringify(summary, null, 2));
      process.exitCode = 0;
    }
  } catch (err) {
    console.error(`lyria-tune: ${err instanceof Error ? err.message : String(err)}`);
    process.exitCode = 1;
  }
}
