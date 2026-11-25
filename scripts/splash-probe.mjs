import { spawn, spawnSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const SPLASH = [36, 42, 40];

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

const DEFAULT_TIMES = "0.1,0.3,0.6,1";
const TOOL_TIMEOUT_MS = 10000;

export function parseArgs(argv) {
  const args = { display: null, godot: null, times: DEFAULT_TIMES, out: null };
  for (const arg of argv) {
    if (arg.startsWith("--display=")) args.display = arg.slice("--display=".length);
    else if (arg.startsWith("--godot=")) args.godot = arg.slice("--godot=".length);
    else if (arg.startsWith("--times=")) args.times = arg.slice("--times=".length);
    else if (arg.startsWith("--out=")) args.out = arg.slice("--out=".length);
    else throw new Error("unknown argument: " + arg);
  }
  if (!args.display) throw new Error("need --display=<X display>");
  if (!args.godot) throw new Error("need --godot=<binary>");
  args.times = args.times.split(",").map((entry) => {
    const n = entry.trim() === "" ? NaN : Number(entry);
    if (!Number.isFinite(n) || n < 0)
      throw new Error("--times entries must be numbers >= 0, got: " + JSON.stringify(entry));
    return n;
  });
  return args;
}

let child = null;

function stopChild() {
  if (child && child.exitCode === null && !child.killed) child.kill();
}

function fail(message) {
  stopChild();
  console.error("splash-probe FAIL: " + message);
  process.exit(2);
}

function run(tool, args, env, what) {
  const r = spawnSync(tool, args, { env, encoding: "utf8", timeout: TOOL_TIMEOUT_MS });
  const stderr = String(r.stderr ?? "").trim();
  if (r.error) {
    if (r.error.code === "ENOENT") fail(`ImageMagick \`${tool}\` is not installed (${what})`);
    if (r.error.code === "ETIMEDOUT")
      fail(`${tool} timed out after ${TOOL_TIMEOUT_MS} ms (${what}): ${stderr}`);
    fail(`${tool} failed (${what}): ${r.error.message} ${stderr}`);
  }
  if (r.status !== 0) fail(`${tool} exited ${r.status ?? r.signal} (${what}): ${stderr}`);
  return r.stdout;
}

async function main() {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  let args;
  try {
    const argv = process.argv.slice(2);
    args = parseArgs(argv);
  } catch (error) {
    fail(error.message);
  }
  const { display, godot, times } = args;
  const out = path.resolve(args.out ?? path.join(root, "artifacts/local/splash-probe"));
  mkdirSync(out, { recursive: true });
  const env = { ...process.env, DISPLAY: display };
  try {
    child = spawn(
      godot,
      ["--path", path.join(root, "sketches/core-loop"), "--rendering-driver", "opengl3"],
      { env, stdio: "ignore" },
    );
    child.on("error", (error) => fail(`cannot start Godot \`${godot}\`: ${error.message}`));
    const t0 = Date.now();
    const rows = [];
    let centre = null;
    for (const t of times) {
      const wait = t * 1000 - (Date.now() - t0);
      if (wait > 0) await new Promise((r) => setTimeout(r, wait));
      const file = path.join(out, `frame-${t}.png`);
      run("import", ["-window", "root", file], env, `cannot capture display ${display}`);
      if (!centre) {
        const size = run(
          "convert",
          [file, "-format", "%w %h", "info:"],
          env,
          `cannot read size of ${file}`,
        )
          .trim()
          .split(/\s+/)
          .map(Number);
        if (size.length !== 2 || !size.every((n) => Number.isInteger(n) && n > 0))
          fail(`unexpected root geometry from convert: ${size.join(" ")}`);
        centre = [Math.floor(size[0] / 2), Math.floor(size[1] / 2)];
      }
      const text = run(
        "convert",
        [file, "-format", `%[pixel:p{${centre[0]},${centre[1]}}]`, "info:"],
        env,
        `cannot read pixel of ${file}`,
      );
      const rgb = parsePixel(text);
      if (!rgb) fail(`cannot parse pixel from convert output: ${JSON.stringify(text)}`);
      rows.push({ want: t, at: (Date.now() - t0) / 1000, rgb });
      console.log(`t=${t}s at=${rows.at(-1).at.toFixed(2)}s pixel=${rgb.join(",")}`);
    }
    const s = summarize(rows);
    console.log(
      s.seen ? `splash colour seen at ${s.firstAt.toFixed(2)}s` : "splash colour never seen",
    );
    stopChild();
    process.exit(s.seen ? 0 : 1);
  } finally {
    stopChild();
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  await main();
