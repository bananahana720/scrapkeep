import { spawn, spawnSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// node scripts/splash-probe.mjs --display=:97 --godot=<bin> [--times=0.1,0.3,0.6,1] [--out=dir]:
// launches the core-loop project on an existing X display (start Xvfb first), grabs root
// captures at the given seconds and reads the corner pixel of each, so the boot splash colour
// (project.godot boot_splash/bg_color, #242a28) is seen on screen before the first game frame.
// Needs ImageMagick (import, convert). Exit 0 when the colour appears, 1 when it never does.
// It kills only the Godot process it started.

export const SPLASH = [36, 42, 40];

// "srgb(36,42,40)" or "gray(0)" from ImageMagick -> [r,g,b], or null when unreadable.
export function parsePixel(text) {
  const m = /^(srgba?|gray)\(([^)]*)\)/.exec(String(text).trim());
  if (!m) return null;
  const v = m[2].split(",").map((s) => Math.round(parseFloat(s)));
  if (m[1] === "gray") return [v[0], v[0], v[0]];
  return v.length >= 3 && v.every(Number.isFinite) ? v.slice(0, 3) : null;
}

export function isSplash(rgb, want = SPLASH) {
  return Array.isArray(rgb) && rgb.length === 3 && rgb.every((c, i) => c === want[i]);
}

export function summarize(rows) {
  const first = rows.find((r) => isSplash(r.rgb));
  return { seen: Boolean(first), firstAt: first ? first.at : null };
}

function arg(name, fallback) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}

async function main() {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const display = arg("display", process.env.DISPLAY);
  const godot = arg("godot", process.env.GODOT_BIN);
  const times = arg("times", "0.1,0.3,0.6,1").split(",").map(Number);
  const out = path.resolve(arg("out", path.join(root, "artifacts/local/splash-probe")));
  if (!display || !godot) {
    console.error("splash-probe: need --display and --godot (or DISPLAY and GODOT_BIN)");
    process.exit(2);
  }
  mkdirSync(out, { recursive: true });
  const env = { ...process.env, DISPLAY: display };
  const child = spawn(godot, ["--path", path.join(root, "sketches/core-loop"), "--rendering-driver", "opengl3"], { env, stdio: "ignore" });
  const t0 = Date.now();
  const rows = [];
  for (const t of times) {
    const wait = t * 1000 - (Date.now() - t0);
    if (wait > 0) await new Promise((r) => setTimeout(r, wait));
    const file = path.join(out, `frame-${t}.png`);
    spawnSync("import", ["-window", "root", file], { env });
    const px = spawnSync("convert", [file, "-format", "%[pixel:p{5,5}]", "info:"], { encoding: "utf8" });
    const rgb = parsePixel(px.stdout);
    rows.push({ want: t, at: (Date.now() - t0) / 1000, rgb });
    console.log(`t=${t}s at=${rows.at(-1).at.toFixed(2)}s pixel=${rgb ? rgb.join(",") : "unreadable"}`);
  }
  child.kill();
  const s = summarize(rows);
  console.log(s.seen ? `splash colour seen at ${s.firstAt.toFixed(2)}s` : "splash colour never seen");
  process.exit(s.seen ? 0 : 1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
