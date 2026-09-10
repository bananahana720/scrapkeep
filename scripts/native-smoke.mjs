import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";
import {
  access,
  cp,
  mkdir,
  mkdtemp,
  readdir,
  readFile,
  stat,
  symlink,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const recordedBinary =
  "/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64";
const pinnedVersion = "4.7.2.stable.official.ed1daf0bf";
const sourceDirectory = "native";
let projectDirectory = sourceDirectory;
let runtimeEnvironment = process.env;
const positiveScript = "res://tests/smoke_boot.gd";
const negativeScript = "res://tests/fixtures/untyped_negative.gd";
const marker = /^SCRAPKEEP_SMOKE (\S+) typed$/m;
const negativeMarker = "SCRAPKEEP_SMOKE_NEGATIVE";
// Every transport, peer and replication class the offline-solo decision
// excludes (adr/TADR-005-networking-scope.md, Decision: no networking
// subsystem, no replication, no server deployment). The list carries the peer,
// WebRTC, replication, DTLS and UPnP families an earlier revision scanned
// past, so the guard matches the scope a reader assumes it enforces.
export const forbiddenNetworkingClasses =
  /HTTPRequest|ENet|WebSocket|MultiplayerAPI|PacketPeer|StreamPeer|HTTPClient|UDPServer|TCPServer|MultiplayerPeer|WebRTC|SceneMultiplayer|DTLSServer|UPNP/;
const reportFile = path.join(root, "artifacts/local/native-smoke/report.json");
const proofsDirectory = path.join(sourceDirectory, "proofs");
const proofRunner = "proof_runner.gd";
const faultArgument = "--inject-fault";
const failLine = /^\S+ \S+ FAIL /m;
const proofLine = /^\S+ (\S+ (PASS|FAIL) |SUMMARY )/;
const limits =
  "Proves a headless boot of the pinned editor binary on one Linux host only, plus each headless proof under native/proofs against its own ADR rule. Not qualification evidence for any target, export, renderer, input device or feel (adr/TADR-001-engine-language-platforms.md lines 35 and 39).";

export function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
    env: runtimeEnvironment,
    timeout: 60_000,
    killSignal: "SIGKILL",
    maxBuffer: 8 * 1024 * 1024,
    ...options,
  });
  return {
    command: [command, ...args],
    error: result.error
      ? { code: result.error.code, message: result.error.message }
      : null,
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
  failures = [
    ...executionFailures(execution, {
      expectedCode: null,
      allowScriptErrors: true,
    }),
    ...failures,
  ];
  return {
    id,
    status: failures.length === 0 ? "pass" : "fail",
    command: execution.command,
    exitCode: execution.exitCode,
    signal: execution.signal,
    error: execution.error,
    stdoutExcerpt: excerpt(execution.stdout),
    stderrExcerpt: excerpt(execution.stderr),
    detail: failures.length === 0 ? detail : failures.join("; "),
  };
}

function bootArguments(script) {
  return ["--headless", "--path", projectDirectory, "--script", script];
}

function positiveFailures(execution, engineVersion) {
  const failures = executionFailures(execution, { expectedCode: null });
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
  if (execution.exitCode !== 1)
    failures.push("expected exit 1, got " + execution.exitCode);
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

// The scan list comes from the repository, not from a hard-coded subset or an
// extension filter: git already knows every tracked file under the directory,
// and --others --exclude-standard adds a file that is new or not yet committed
// (ignored build output such as native/.godot stays out), so a file added
// later cannot silently escape the check.
function derivationCommand(directory) {
  return "git ls-files -z --cached --others --exclude-standard -- " + directory;
}

export function repositoryFiles(directory = sourceDirectory) {
  const listing = run("git", [
    "ls-files",
    "-z",
    "--cached",
    "--others",
    "--exclude-standard",
    "--",
    directory,
  ]);
  if (listing.error || listing.exitCode !== 0)
    throw new Error(
      "could not derive the file list for " +
        directory +
        " from git: " +
        (listing.error ? listing.error.message : "exit " + listing.exitCode),
    );
  return listing.stdout
    .split("\0")
    .filter(Boolean)
    .map((file) => path.resolve(root, file))
    .sort();
}

function repositoryPath(file) {
  return path.relative(root, file).split(path.sep).join("/");
}

export async function networkingGrep(files, derivation = null) {
  const scanned = [...files].sort();
  const hits = [];
  for (const file of scanned) {
    const lines = (await readFile(file, "utf8")).split("\n");
    lines.forEach((line, index) => {
      const named = line.match(forbiddenNetworkingClasses);
      if (named)
        hits.push(repositoryPath(file) + ":" + (index + 1) + ":" + named[0]);
    });
  }
  const command =
    "grep -E " +
    JSON.stringify(forbiddenNetworkingClasses.source) +
    " " +
    scanned.map(repositoryPath).join(" ");
  return {
    id: "networking-grep",
    status: scanned.length > 0 && hits.length === 0 ? "pass" : "fail",
    command: scanned.length > 0 ? command : (derivation ?? command),
    exitCode: null,
    signal: null,
    stdoutExcerpt: hits.join("\n"),
    stderrExcerpt: "",
    derivation,
    scannedFiles: scanned.map(repositoryPath),
    detail:
      scanned.length === 0
        ? "no file was derived for the native networking scan; an unread tree cannot pass"
        : hits.length === 0
          ? "no networking class named in " + scanned.length + " scanned files"
          : "networking class named at " + hits.join(", "),
  };
}

export async function networkingScan(directory = sourceDirectory) {
  return networkingGrep(
    repositoryFiles(directory),
    derivationCommand(directory),
  );
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
  const failures = executionFailures(execution, { expectedCode: null });
  if (execution.exitCode !== 0)
    failures.push("expected exit 0, got " + execution.exitCode);
  const fail = failLine.exec(execution.stdout);
  if (fail) failures.push("FAIL line present: " + fail[0].trim());
  if (!/^\S+ \S+ PASS /m.test(execution.stdout))
    failures.push("proof assertion marker absent");
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
  const failures = executionFailures(execution, { expectedCode: null });
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

const pinnedBinaryHash =
  "8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e";
const templateArchiveHash =
  "ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079";
const pinnedTemplateHashes = {
  "linux_release.x86_64":
    "d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63",
  "windows_release_x86_64.exe":
    "d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562",
  "version.txt":
    "38885c88f75abbc797a1db7559719800279a00cfb9fa8b2e2868a7f6f84bad2e",
};

export function templateCheck(name, artifact) {
  const expectedSha256 = pinnedTemplateHashes[name];
  const matchesPin =
    artifact?.size > 0 &&
    expectedSha256 !== undefined &&
    artifact.sha256 === expectedSha256;
  return {
    id: "template-" + name,
    status: matchesPin ? "pass" : "fail",
    expectedSha256,
    actualSha256: artifact?.sha256 ?? null,
    detail: matchesPin
      ? "consumed template SHA256 matches the recorded pin"
      : "consumed template missing or SHA256 differs from the recorded pin",
  };
}

export function godotEnvironment(runDirectory, inherited = process.env) {
  return {
    ...inherited,
    XDG_DATA_HOME: path.join(runDirectory, "user-data"),
    XDG_CACHE_HOME: path.join(runDirectory, "cache"),
    XDG_CONFIG_HOME: path.join(runDirectory, "config"),
  };
}

const exportLimits =
  "Operational synthetic proof only. Linux editor and export execute headlessly; Windows export is file evidence only. Offline checks marked skip supply no offline execution evidence. No visible window, Exit input, renderer selection, hardware support, power-loss durability, performance or gameplay qualification is implied. Proof scripts remain in these internal exports; Q-E13 and TH-26 govern later removal. No binaries are distributed.";

export function executionFailures(
  execution,
  {
    expectedCode = 0,
    requiredMarker,
    allowScriptErrors = false,
    rejectErrors = false,
  } = {},
) {
  const failures = [];
  if (execution.error)
    failures.push(
      "subprocess error: " +
        execution.error.code +
        " " +
        execution.error.message,
    );
  if (execution.signal) failures.push("terminated by " + execution.signal);
  if (execution.exitCode === null)
    failures.push("process did not exit normally");
  if (expectedCode !== null && execution.exitCode !== expectedCode)
    failures.push(
      "expected exit " + expectedCode + ", got " + execution.exitCode,
    );
  const output = execution.stdout + "\n" + execution.stderr;
  if (!allowScriptErrors && /SCRIPT ERROR:|Parse Error:/.test(output))
    failures.push("engine script error");
  if (rejectErrors && /^ERROR:/m.test(output))
    failures.push("engine export/import error");
  if (requiredMarker && !requiredMarker.test(execution.stdout))
    failures.push("required marker absent: " + requiredMarker.source);
  return failures;
}

export function exportFailures(execution, artifact) {
  const failures = executionFailures(execution, { rejectErrors: true });
  if (
    !artifact ||
    artifact.size <= 0 ||
    !/^[a-f0-9]{64}$/.test(artifact.sha256)
  )
    failures.push("export file missing, empty or unhashed");
  return failures;
}

async function digest(file, algorithm = "sha256") {
  const hash = createHash(algorithm);
  for await (const chunk of createReadStream(file)) hash.update(chunk);
  return hash.digest("hex");
}

async function artifactOf(file) {
  try {
    const info = await stat(file);
    if (!info.isFile()) return null;
    return { path: file, size: info.size, sha256: await digest(file) };
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

function integratedRun(
  id,
  binary,
  args,
  mode,
  dataDirectory,
  fault = false,
  offline = false,
) {
  const userArgs = [
    "--",
    "--" + mode,
    "--data-dir",
    dataDirectory,
    "--auto-exit",
    ...(fault ? [faultArgument] : []),
  ];
  const execution = offline
    ? run("unshare", ["-rn", binary, ...args, ...userArgs])
    : run(binary, [...args, ...userArgs]);
  const requiredMarker = new RegExp(
    "^SCRAPKEEP_INTEGRATION " +
      mode.toUpperCase() +
      " " +
      (fault ? "FAIL" : "PASS") +
      "$",
    "m",
  );
  const failures = executionFailures(execution, {
    expectedCode: fault ? 1 : 0,
    requiredMarker,
  });
  const summaryLine = execution.stdout
    .split("\n")
    .find((line) => line.startsWith("SCRAPKEEP_INTEGRATION SUMMARY "));
  let summary = null;
  try {
    summary = JSON.parse(
      summaryLine?.slice("SCRAPKEEP_INTEGRATION SUMMARY ".length),
    );
    if (
      summary.mode !== mode ||
      summary.exit_code !== (fault ? 1 : 0) ||
      !Array.isArray(summary.failures) ||
      summary.failures.length > 0 !== fault
    )
      failures.push("integration summary disagrees with expected result");
  } catch {
    failures.push("integration summary missing or invalid");
  }
  if (!fault && /^SCRAPKEEP_INTEGRATION CHECK FAIL /m.test(execution.stdout))
    failures.push("failed integration assertion");
  return {
    ...outcome(
      id,
      execution,
      failures,
      "main scene " + mode + (fault ? " detected injected fault" : " passed"),
    ),
    summary,
  };
}

async function integratedPair(
  id,
  binary,
  args,
  dataRoot,
  checks,
  offline = false,
) {
  const data = path.join(dataRoot, id);
  checks.push(
    integratedRun(id + "-stage", binary, args, "stage", data, false, offline),
  );
  const saved = await artifactOf(path.join(data, "save.json"));
  checks.push(
    integratedRun(id + "-resume", binary, args, "resume", data, false, offline),
  );
  checks.push(
    integratedRun(
      id + "-resume-fault",
      binary,
      args,
      "resume",
      data,
      true,
      offline,
    ),
  );
  const after = await artifactOf(path.join(data, "save.json"));
  checks.push({
    id: id + "-save-preservation",
    status: saved && after && saved.sha256 === after.sha256 ? "pass" : "fail",
    detail: "resume and resume fault preserve the staged save bytes",
    beforeSha256: saved?.sha256,
    afterSha256: after?.sha256,
  });
  const faultData = data + "-stage-fault";
  checks.push(
    integratedRun(
      id + "-stage-fault",
      binary,
      args,
      "stage",
      faultData,
      true,
      offline,
    ),
  );
  checks.push({
    id: id + "-fault-no-commit",
    status: (await artifactOf(path.join(faultData, "save.json")))
      ? "fail"
      : "pass",
    detail: "stage validation fault leaves no committed save",
  });
}

async function exportSmoke(binary, runDirectory, checks, artifacts, toolchain) {
  const imported = run(binary, [
    "--headless",
    "--path",
    projectDirectory,
    "--editor",
    "--import",
  ]);
  const importCheck = outcome(
    "editor-import",
    imported,
    executionFailures(imported, { rejectErrors: true }),
    "fresh staged source imported without script errors",
  );
  checks.push(importCheck);
  if (importCheck.status !== "pass") return;
  await integratedPair(
    "editor",
    binary,
    ["--headless", "--path", projectDirectory],
    runDirectory,
    checks,
  );
  const dataHome =
    process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local/share");
  const templates = path.join(dataHome, "godot/export_templates/4.7.2.stable");
  toolchain.templates = [];
  for (const name of Object.keys(pinnedTemplateHashes)) {
    const artifact = await artifactOf(path.join(templates, name));
    toolchain.templates.push(
      artifact || { path: path.join(templates, name), missing: true },
    );
    checks.push(templateCheck(name, artifact));
  }
  if (process.env.GODOT_TEMPLATES_ARCHIVE) {
    toolchain.templatesArchive = {
      path: process.env.GODOT_TEMPLATES_ARCHIVE,
      sha512: await digest(process.env.GODOT_TEMPLATES_ARCHIVE, "sha512"),
      expectedSha512: templateArchiveHash,
    };
    checks.push({
      id: "templates-archive-pin",
      status:
        toolchain.templatesArchive.sha512 === templateArchiveHash
          ? "pass"
          : "fail",
      detail: "template archive SHA512 matches recorded release",
    });
  }
  if (checks.some((check) => check.status === "fail")) return;
  for (const preset of [
    { name: "Linux x64", platform: "linux", filename: "scrapkeep.x86_64" },
    { name: "Windows x64", platform: "windows", filename: "scrapkeep.exe" },
  ]) {
    const output = path.join(
      root,
      "artifacts/local/native-export",
      preset.platform,
      path.basename(runDirectory),
      preset.filename,
    );
    await mkdir(path.dirname(output), { recursive: true });
    const execution = run(binary, [
      "--headless",
      "--path",
      projectDirectory,
      "--export-release",
      preset.name,
      output,
    ]);
    const artifact = await artifactOf(output);
    const check = outcome(
      "export-" + preset.platform,
      execution,
      exportFailures(execution, artifact),
      preset.name + " exported to a fresh absolute path",
    );
    checks.push(check);
    if (artifact)
      artifacts.push({
        ...artifact,
        preset: preset.name,
        executed: preset.platform === "linux" && check.status === "pass",
      });
    if (preset.platform === "linux" && check.status === "pass") {
      await integratedPair(
        "linux-export",
        output,
        ["--headless"],
        runDirectory,
        checks,
      );
      const offline = run("unshare", ["-rn", "true"]);
      if (executionFailures(offline).length === 0)
        await integratedPair(
          "offline-linux-export",
          output,
          ["--headless"],
          runDirectory,
          checks,
          true,
        );
      else
        checks.push({
          id: "offline-linux-export",
          status: "skip",
          command: offline.command,
          detail: "unshare unavailable; no offline exported execution evidence",
          stderrExcerpt: excerpt(offline.stderr),
          error: offline.error,
        });
    }
  }
}

async function main() {
  const args = process.argv.slice(2);
  if (args.some((arg) => arg !== "--export") || args.length > 1)
    throw new Error("Usage: node scripts/native-smoke.mjs [--export]");
  const exporting = args.includes("--export");
  const sourceCommit = run("git", ["rev-parse", "HEAD"]).stdout.trim();
  const sourceStatus = run("git", ["status", "--porcelain"]).stdout.trim();
  const sourceFiles = await walk(path.join(root, sourceDirectory));
  const sourceHashes = await hashFiles(sourceFiles);
  await mkdir(path.dirname(reportFile), { recursive: true });
  const runDirectory = await mkdtemp(
    path.join(path.dirname(reportFile), "run-"),
  );
  projectDirectory = path.join(runDirectory, "native");
  runtimeEnvironment = godotEnvironment(runDirectory);
  if (exporting) {
    const templateSource = path.join(
      process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local/share"),
      "godot/export_templates/4.7.2.stable",
    );
    const templateLink = path.join(
      runtimeEnvironment.XDG_DATA_HOME,
      "godot/export_templates/4.7.2.stable",
    );
    await mkdir(path.dirname(templateLink), { recursive: true });
    await symlink(templateSource, templateLink);
  }
  await cp(path.join(root, sourceDirectory), projectDirectory, {
    recursive: true,
    filter: (file) =>
      !file.split(path.sep).includes(".godot") && !file.endsWith(".import"),
  });
  const { binary, source } = await resolveBinary();
  const engineVersion = engineVersionOf(binary);
  const checks = [
    positiveBoot(binary, engineVersion),
    negativeBoot(binary),
    await networkingScan(),
    offlineBoot(binary, engineVersion),
  ];
  for (const proof of await discoverProofs())
    checks.push(proofRun(binary, proof), proofFaultRun(binary, proof));
  const engineHash = await digest(binary);
  checks.push({
    id: "engine-pin",
    status:
      engineVersion === pinnedVersion && engineHash === pinnedBinaryHash
        ? "pass"
        : "fail",
    detail: "version and binary SHA256 must match the recorded pin",
  });
  const artifacts = [];
  const toolchain = { editorSha256: engineHash };
  if (exporting)
    await exportSmoke(binary, runDirectory, checks, artifacts, toolchain);
  const afterHashes = await hashFiles(
    await walk(path.join(root, sourceDirectory)),
  );
  checks.push({
    id: "source-preservation",
    status:
      JSON.stringify(sourceHashes) === JSON.stringify(afterHashes)
        ? "pass"
        : "fail",
    detail: "native source hashes unchanged through import and execution",
  });
  for (const check of checks) announce(check);
  const report = {
    schema: "scrapkeep-native-smoke/2",
    sourceCommit,
    sourceDirty: sourceStatus !== "",
    sourceStatus,
    mode: exporting ? "export" : "proofs",
    runDirectory,
    runtimePaths: {
      data: runtimeEnvironment.XDG_DATA_HOME,
      cache: runtimeEnvironment.XDG_CACHE_HOME,
      config: runtimeEnvironment.XDG_CONFIG_HOME,
    },
    artifacts,
    toolchain,
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
    files: sourceHashes,
    limits: exporting ? exportLimits : limits,
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
      (exporting ? exportLimits : limits),
  );
  process.exitCode = report.verdict === "pass" ? 0 : 1;
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  main().catch(async (error) => {
    console.error("native:smoke internal error: " + error.message);
    await mkdir(path.dirname(reportFile), { recursive: true });
    await writeFile(
      reportFile,
      JSON.stringify(
        {
          schema: "scrapkeep-native-smoke/2",
          sourceCommit: run("git", ["rev-parse", "HEAD"]).stdout.trim(),
          verdict: "fail",
          checks: [{ id: "harness", status: "fail", detail: error.message }],
          artifacts: [],
        },
        null,
        2,
      ) + "\n",
    );
    process.exitCode = 2;
  });
}
