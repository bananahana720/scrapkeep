import { spawnSync } from "node:child_process";
import { copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { existsSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GODOT_VERSION, resolveGodotBinary, scratchGodotEnv } from "../godot-home.mjs";
import {
  WIN_PROOFS,
  playProofTries,
  proofLibraries,
  releaseGateFailures,
  winProofBotArgs,
  winProofFailures,
  winProofLine,
  winProofTimeoutMs,
} from "../sketch-export.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const project = path.join(root, "sketches/core-loop");
const binary = resolveGodotBinary({ requireExplicit: true });
const errorLine = /^(SCRIPT ERROR|ERROR)\b/m;
const winProof = process.argv.includes("--win-proof");

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    maxBuffer: 256 * 1024 * 1024,
    ...options,
  });
  return { status: result.status, text: (result.stdout ?? "") + (result.stderr ?? "") };
}

function fail(message) {
  console.error("cloud export: " + message);
  process.exit(1);
}

function step(label, result, extra = []) {
  const problems = [...extra];
  if (result.status !== 0) problems.push("exit " + result.status);
  if (errorLine.test(result.text)) problems.push("SCRIPT ERROR or ERROR line in the output");
  if (problems.length > 0)
    fail(label + ": " + problems.join("; ") + "\n" + result.text.slice(-2000));
  console.log("PASS " + label);
}

if (!binary || !existsSync(binary))
  fail(`set GODOT_BIN to the Godot ${GODOT_VERSION} editor (the cloud SessionStart hook does)`);

step("editor import", run(binary, ["--headless", "--path", project, "--editor", "--import"]));
const gate = run(
  binary,
  ["--headless", "--path", project, "--script", "res://tests/release_gate_placeholder_test.gd"],
  {
    env: { ...process.env, SCRAPKEEP_RELEASE_GATE: "1" },
  },
);
const gateFailures = releaseGateFailures(gate.text, gate.status);
if (gateFailures.length > 0) fail("release gate\n" + gateFailures.join("\n"));
console.log("PASS release gate");

const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\..*/, "");
const outDir = path.join(root, "artifacts/local/cloud-export", stamp);
await mkdir(outDir, { recursive: true });
const exe = path.join(outDir, "core-loop.x86_64");
step(
  "export Linux x64",
  run(binary, ["--headless", "--path", project, "--export-release", "Linux x64", exe]),
  existsSync(exe) ? [] : ["no executable"],
);
step("boot 300 frames", run(exe, ["--headless", "--quit-after", "300"], { cwd: outDir }));
step(
  "park table boot 600 frames",
  run(exe, ["--headless", "--table=park", "--quit-after", "600"], { cwd: outDir }),
);

const lines = [];
if (winProof) {
  const proofDir = outDir + "-win-proof";
  await mkdir(proofDir, { recursive: true });
  const pack = path.join(proofDir, "proof.pck");
  step(
    "export Linux x64 proof pack",
    run(binary, ["--headless", "--path", project, "--export-pack", "Linux x64 proof", pack]),
  );
  const addons = path.join(project, "addons");
  const addonFiles = existsSync(addons)
    ? readdirSync(addons, { recursive: true }).map((rel) =>
        path.join("addons", String(rel)).split(path.sep).join("/"),
      )
    : [];
  for (const rel of proofLibraries(addonFiles)) {
    await mkdir(path.join(proofDir, path.dirname(rel)), { recursive: true });
    await copyFile(path.join(project, rel), path.join(proofDir, rel));
  }
  for (const proof of WIN_PROOFS) {
    const root = path.join(proofDir, proof.dir);
    const result = await playProofTries(proof, (attempt) =>
      playOnce((proof.tries ?? 1) > 1 ? path.join(root, "try-" + attempt) : root, proof),
    );
    if (!result.ok) fail(proof.label + "\n" + result.failure);
    console.log("PASS " + result.line);
    lines.push(result.line);
  }

  async function playOnce(base, proof) {
    const state = path.join(base, "state");
    const out = path.join(base, "run");
    const bot = run(
      binary,
      [
        "--headless",
        "--fixed-fps",
        "90",
        "--main-pack",
        pack,
        "--script",
        "res://tools/bot_run.gd",
        "--",
        ...winProofBotArgs(proof, out),
      ],
      {
        cwd: proofDir,
        timeout: winProofTimeoutMs(proof),
        env: scratchGodotEnv(state, { baseEnv: process.env, create: true }),
      },
    );
    const rowsPath = path.join(out, "bots.ndjson");
    const rowsText = existsSync(rowsPath) ? await readFile(rowsPath, "utf8") : "";
    const failures = winProofFailures(bot.text, bot.status, rowsText);
    if (failures.length > 0)
      return {
        ok: false,
        failure: failures.join("\n") + "\n" + bot.text.slice(-2000),
        summary: failures[0],
      };
    return { ok: true, line: winProofLine(JSON.parse(rowsText.trim()), pack, proof) };
  }
}

const head = run("git", ["-C", root, "rev-parse", "HEAD"]).text.trim();
await writeFile(
  path.join(outDir, "BUILD.txt"),
  [
    "commit: " + head,
    "built: " + stamp + " in a cloud container (scripts/cloud/export-headless.mjs)",
    "godot: 4.7.2.stable",
    "stems: none (ACE stems live on Andrew's machine)",
    "boss smoke: not run (needs a Vulkan GPU)",
    winProof ? lines.join("\n") : "win proof: not run",
    "",
  ].join("\n"),
);
console.log("executable: " + exe);
