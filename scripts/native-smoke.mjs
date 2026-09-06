import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { access, mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const recordedBinary =
  "/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64";
const pinnedVersion = "4.7.2.stable.official.ed1daf0bf";
const projectDirectory = "native";
const positiveScript = "res://tests/smoke_boot.gd";
const negativeScript = "res://tests/fixtures/untyped_negative.gd";
const marker = /^SCRAPKEEP_SMOKE (\S+) typed$/m;
const negativeMarker = "SCRAPKEEP_SMOKE_NEGATIVE";
const networkingClasses =
  /HTTPRequest|ENet|WebSocket|MultiplayerAPI|PacketPeer|StreamPeer|HTTPClient|UDPServer|TCPServer/;
const reportFile = path.join(root, "artifacts/local/native-smoke/report.json");
const proofsDirectory = path.join(projectDirectory, "proofs");
const proofRunner = "proof_runner.gd";
const faultArgument = "--inject-fault";
const failLine = /^\S+ \S+ FAIL /m;
const proofLine = /^\S+ (\S+ (PASS|FAIL) |SUMMARY )/;
const limits =
  "Proves a headless boot of the pinned editor binary on one Linux host only, plus each headless proof under native/proofs against its own ADR rule. Not qualification evidence for any target, export, renderer, input device or feel (adr/TADR-001-engine-language-platforms.md lines 35 and 39).";

function run(command, args) {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
    timeout: 60_000,
  });
  if (result.error) throw result.error;
  return {
    command: [command, ...args].join(" "),
    exitCode: result.status,
    signal: result.signal,
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? "",
  };
}

function excerpt(text) {
  return text.trim().split("\n").slice(0, 12).join("\n").slice(0, 1500);
}

function outcome(id, execution, failures, detail) {
  return {
    id,
    status: failures.length === 0 ? "pass" : "fail",
    command: execution.command,
    exitCode: execution.exitCode,
    signal: execution.signal,
    stdoutExcerpt: excerpt(execution.stdout),
    stderrExcerpt: excerpt(execution.stderr),
    detail: failures.length === 0 ? detail : failures.join("; "),
  };
}

function bootArguments(script) {
  return ["--headless", "--path", projectDirectory, "--script", script];
}

function positiveFailures(execution, engineVersion) {
  const failures = [];
  if (execution.exitCode !== 0)
    failures.push("expected exit 0, got " + execution.exitCode);
  const found = marker.exec(execution.stdout);
  if (!found)
    failures.push("marker line SCRAPKEEP_SMOKE <version> typed absent");
  else if (found[1] !== engineVersion)
    failures.push(
      "script reported " + found[1] + " but --version printed " + engineVersion,
    );
  return failures;
}

function positiveBoot(binary, engineVersion) {
  const execution = run(binary, bootArguments(positiveScript));
  return outcome(
    "positive-boot",
    execution,
    positiveFailures(execution, engineVersion),
    "typed SceneTree script booted headless, printed the marker and exited 0",
  );
}

function negativeBoot(binary) {
  const execution = run(binary, bootArguments(negativeScript));
  const failures = [];
  if (execution.exitCode === 0) failures.push("untyped fixture exited 0");
  if (execution.stdout.includes(negativeMarker))
    failures.push("untyped fixture reached _init");
  if (!/Warning treated as error/.test(execution.stderr + execution.stdout))
    failures.push("no warning-as-error message printed");
  return outcome(
    "negative-untyped",
    execution,
    failures,
    "untyped declaration refused under native/project.godot warning settings",
  );
}

async function walk(directory) {
  const files = [];
  for (const item of await readdir(directory, { withFileTypes: true })) {
    const file = path.join(directory, item.name);
    if (item.isDirectory()) {
      if (item.name !== ".godot") files.push(...(await walk(file)));
    } else if (item.isFile() && !file.endsWith(".import")) files.push(file);
  }
  return files.sort();
}

async function networkingGrep(files) {
  const scanned = files.filter(
    (file) => file.endsWith(".gd") || file.endsWith("project.godot"),
  );
  const hits = [];
  for (const file of scanned) {
    const lines = (await readFile(file, "utf8")).split("\n");
    lines.forEach((line, index) => {
      if (networkingClasses.test(line))
        hits.push(path.relative(root, file) + ":" + (index + 1));
    });
  }
  return {
    id: "networking-grep",
    status: hits.length === 0 ? "pass" : "fail",
    command:
      "grep -E " +
      JSON.stringify(networkingClasses.source) +
      " " +
      scanned.map((file) => path.relative(root, file)).join(" "),
    exitCode: null,
    signal: null,
    stdoutExcerpt: hits.join("\n"),
    stderrExcerpt: "",
    detail:
      hits.length === 0
        ? "no networking class named in " + scanned.length + " scanned files"
        : "networking class named at " + hits.join(", "),
  };
}

function offlineBoot(binary, engineVersion) {
  let probe;
  try {
    probe = run("unshare", ["-rn", "true"]);
  } catch (error) {
    probe = { command: "unshare -rn true", exitCode: null, error };
  }
  if (probe.exitCode !== 0)
    return {
      id: "offline-boot",
      status: "skip",
      command: probe.command,
      exitCode: probe.exitCode,
      signal: null,
      stdoutExcerpt: "",
      stderrExcerpt: probe.error ? probe.error.message : excerpt(probe.stderr),
      detail:
        "unshare -rn unavailable on this host; the offline rerun was not performed",
    };
  const execution = run("unshare", [
    "-rn",
    binary,
    ...bootArguments(positiveScript),
  ]);
  return outcome(
    "offline-boot",
    execution,
    positiveFailures(execution, engineVersion),
    "positive boot repeated inside a user namespace with no network interfaces",
  );
}

async function discoverProofs() {
  const directory = path.join(root, proofsDirectory);
  try {
    await access(directory);
  } catch {
    return [];
  }
  const proofs = [];
  for (const item of await readdir(directory, { withFileTypes: true })) {
    if (!item.isDirectory()) continue;
    const script = path.join(directory, item.name, proofRunner);
    try {
      await access(script);
      proofs.push({
        name: item.name,
        script: "res://proofs/" + item.name + "/" + proofRunner,
      });
    } catch {
      continue;
    }
  }
  return proofs.sort((a, b) => a.name.localeCompare(b.name));
}

function proofOutcome(id, execution, failures, detail) {
  return {
    ...outcome(id, execution, failures, detail),
    assertionLines: execution.stdout
      .split("\n")
      .filter((line) => proofLine.test(line)),
  };
}

function proofRun(binary, proof) {
  const execution = run(binary, bootArguments(proof.script));
  const failures = [];
  if (execution.exitCode !== 0)
    failures.push("expected exit 0, got " + execution.exitCode);
  const fail = failLine.exec(execution.stdout);
  if (fail) failures.push("FAIL line present: " + fail[0].trim());
  return proofOutcome(
    "proof-" + proof.name,
    execution,
    failures,
    "proof exited 0 with no FAIL line",
  );
}

function proofFaultRun(binary, proof) {
  const execution = run(binary, [
    ...bootArguments(proof.script),
    "--",
    faultArgument,
  ]);
  const failures = [];
  if (execution.exitCode !== 1)
    failures.push(
      "expected exit 1 under " + faultArgument + ", got " + execution.exitCode,
    );
  if (!failLine.test(execution.stdout))
    failures.push("no FAIL line under " + faultArgument);
  return proofOutcome(
    "proof-" + proof.name + "-inject-fault",
    execution,
    failures,
    "injected fault was caught: exit 1 with a FAIL line",
  );
}

async function hashFiles(files) {
  const hashes = {};
  for (const file of files)
    hashes[path.relative(root, file).split(path.sep).join("/")] = createHash(
      "sha256",
    )
      .update(await readFile(file))
      .digest("hex");
  return hashes;
}

async function resolveBinary() {
  const source = process.env.GODOT_BIN ? "GODOT_BIN" : "recorded";
  const binary = process.env.GODOT_BIN || recordedBinary;
  await access(binary);
  return { binary, source };
}

function engineVersionOf(binary) {
  const execution = run(binary, ["--version"]);
  const lines = execution.stdout.trim().split("\n").filter(Boolean);
  const version = lines.at(-1) ?? "";
  if (execution.exitCode !== 0 || !version)
    throw new Error("could not read the engine version from " + binary);
  return version;
}

function announce(check) {
  console.log(
    check.status.toUpperCase() +
      " " +
      check.id +
      " exit " +
      (check.exitCode ?? "n/a") +
      ": " +
      check.detail,
  );
}

async function main() {
  const { binary, source } = await resolveBinary();
  const engineVersion = engineVersionOf(binary);
  const files = await walk(path.join(root, projectDirectory));
  const checks = [
    positiveBoot(binary, engineVersion),
    negativeBoot(binary),
    await networkingGrep(files),
    offlineBoot(binary, engineVersion),
  ];
  for (const proof of await discoverProofs())
    checks.push(proofRun(binary, proof), proofFaultRun(binary, proof));
  for (const check of checks) announce(check);
  const report = {
    schema: "scrapkeep-native-smoke/1",
    generatedAt: new Date().toISOString(),
    host: {
      platform: os.platform(),
      release: os.release(),
      arch: os.arch(),
      hostname: os.hostname(),
      node: process.version,
    },
    engine: {
      binary,
      source,
      versionString: engineVersion,
      pinnedVersion,
      matchesPin: engineVersion === pinnedVersion,
    },
    checks,
    files: await hashFiles(files),
    limits,
    verdict: checks.every((check) => check.status !== "fail") ? "pass" : "fail",
  };
  if (!report.engine.matchesPin)
    console.log(
      "NOTE engine " + engineVersion + " differs from the pin " + pinnedVersion,
    );
  await mkdir(path.dirname(reportFile), { recursive: true });
  await writeFile(reportFile, JSON.stringify(report, null, 2) + "\n");
  console.log(
    "native:smoke " +
      report.verdict +
      ". Report: " +
      reportFile +
      "\n" +
      limits,
  );
  process.exitCode = report.verdict === "pass" ? 0 : 1;
}

main().catch((error) => {
  console.error("native:smoke internal error: " + error.message);
  process.exitCode = 2;
});
