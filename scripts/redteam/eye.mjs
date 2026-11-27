#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GODOT_VERSION, resolveGodotBinary } from "../godot-home.mjs";
import {
  FILMS,
  FILM_OF,
  READERS,
  filmArgs,
  judgeSheet,
  parseNdjson,
  readerBrief,
  readerPack,
} from "./lib.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const sketch = path.join(root, "sketches/core-loop");
const opts = {
  persona: null,
  film: null,
  seed: 1,
  pilot: "",
  world: 1,
  plant: "",
  deathAt: 0,
  out: null,
  from: null,
  xvfb: true,
  gpu: false,
  look: false,
};
for (const arg of process.argv.slice(2)) {
  const [k, v] = arg.replace(/^--/, "").split("=");
  if (k === "persona") opts.persona = v;
  else if (k === "film") opts.film = v;
  else if (k === "seed") opts.seed = Number(v);
  else if (k === "pilot") opts.pilot = v;
  else if (k === "world") opts.world = Number(v);
  else if (k === "plant") opts.plant = v;
  else if (k === "death-at") opts.deathAt = Number(v);
  else if (k === "out") opts.out = path.resolve(v);
  else if (k === "from") opts.from = path.resolve(v);
  else if (k === "no-xvfb") opts.xvfb = false;
  else if (k === "gpu") opts.gpu = opts.look = true;
  else if (k === "look") opts.look = true;
  else die("unknown option " + arg);
}
if (!READERS[opts.persona]) die("--persona must be one of " + Object.keys(READERS).join(", "));
const film = opts.film || FILM_OF[opts.persona] || "whole";
if (!FILMS[film]) die("--film must be one of " + Object.keys(FILMS).join(", "));
const stamp = new Date().toISOString().replace(/[:.]/g, "-");
const out =
  opts.out || path.join(root, "artifacts/local/redteam", `eye-${opts.persona}-${film}-${stamp}`);
const filmDir = opts.from || path.join(out, "film");

function die(message) {
  console.error("eye: " + message);
  process.exit(1);
}

if (!opts.from) {
  const godot = resolveGodotBinary({ requireExplicit: true });
  if (!godot || !existsSync(godot))
    die(`set GODOT_BIN to the Godot ${GODOT_VERSION} editor (the cloud SessionStart hook does)`);
  mkdirSync(filmDir, { recursive: true });
  const game = [
    godot,
    ...(opts.gpu ? [] : ["--rendering-driver", "opengl3"]),
    "--audio-driver",
    "Dummy",
    "--resolution",
    "1280x720",
    "--fixed-fps",
    "30",
    "--path",
    sketch,
    "--",
    ...filmArgs({
      film,
      seed: opts.seed,
      pilot: opts.pilot,
      out: filmDir,
      world: opts.world,
      plant: opts.plant,
      deathAt: opts.deathAt,
      live: opts.gpu,
      save: `eye-${film}-${opts.seed}-${Date.now().toString(36)}`,
    }),
  ];
  const argv =
    opts.xvfb && !opts.gpu ? ["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", ...game] : game;
  console.log(
    `eye: filming ${FILMS[film].says} (${opts.plant ? "CONTROL, plant " + opts.plant : "no plant"}); a software renderer takes about 4 seconds for each game second`,
  );
  const run = spawnSync(argv[0], argv.slice(1), { encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });
  writeFileSync(path.join(out, "game.log"), (run.stdout || "") + (run.stderr || ""));
  const said = (run.stdout || "").split("\n").filter((l) => l.startsWith("self-play: "));
  console.log(said.slice(-4).join("\n"));
  if (run.status !== 0) die(`the game quit ${run.status}; see ${path.join(out, "game.log")}`);
}

const rowsPath = path.join(filmDir, "film.ndjson");
if (!existsSync(rowsPath)) die("no film.ndjson in " + filmDir);
const pack = readerPack(parseNdjson(readFileSync(rowsPath, "utf8")));
if (!pack.frames.length) die("the film has no frames");
const reader = path.join(out, "reader");
const judge = path.join(out, "judge");
mkdirSync(reader, { recursive: true });
mkdirSync(judge, { recursive: true });
for (const f of pack.frames)
  copyFileSync(
    path.join(filmDir, f.file),
    path.join(reader, String(f.n).padStart(3, "0") + ".jpg"),
  );
writeFileSync(path.join(reader, "BRIEF.md"), readerBrief(opts.persona, pack, { look: opts.look }));
writeFileSync(path.join(judge, "SHEET.md"), judgeSheet(pack));
console.log(
  `eye: ${pack.frames.length} pictures, ${pack.sets.length} moments with a lead-in\n  reader: ${reader}\n  judge:  ${path.join(judge, "SHEET.md")}`,
);
