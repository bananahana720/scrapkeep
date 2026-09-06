import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const output = path.join(root, "artifacts", "local", "verify");
const npm = process.env.npm_execpath;
if (!npm) throw new Error("Run this check with npm run verify.");
await mkdir(output, { recursive: true });
const stages = [
  ["project", "run", "check:project"],
  ["tests", "test"],
  ["models", "run", "test:orchard:models"],
  ["expedition", "run", "test:expedition"],
  ["build", "run", "build"],
  ["built-http", "run", "check:build"],
];
const report = {
  startedAt: new Date().toISOString(),
  node: process.version,
  result: "running",
  plannedStages: stages.map((s) => s[0]),
  stages: [],
  hashes: {},
};
const save = () =>
  writeFile(
    path.join(output, "report.json"),
    JSON.stringify(report, null, 2) + "\n",
  );
await save();
async function sourceFiles(directory) {
  const files = [];
  for (const item of await readdir(path.join(root, directory), {
    withFileTypes: true,
  })) {
    const file = path.join(directory, item.name);
    if (item.isDirectory()) files.push(...(await sourceFiles(file)));
    else if (item.isFile()) files.push(file);
  }
  return files;
}
try {
  const files = [
    "package.json",
    "package-lock.json",
    "vite.config.js",
    "index.html",
    "orchard.html",
    ...(await sourceFiles("src")),
    ...(await sourceFiles("server")),
    ...(await sourceFiles("scripts")),
    ...(await sourceFiles("tests")),
  ];
  for (const file of files)
    report.hashes[file] = createHash("sha256")
      .update(await readFile(path.join(root, file)))
      .digest("hex");
  for (const [name, ...args] of stages) {
    process.stdout.write("\nChecking " + name + "\n");
    const started = Date.now();
    const child = spawnSync(process.execPath, [npm, ...args], {
      cwd: root,
      encoding: "utf8",
      timeout: 120000,
      maxBuffer: 8 * 1024 * 1024,
    });
    const log = (child.stdout || "") + (child.stderr || "");
    await writeFile(path.join(output, name + ".log"), log);
    const stage = {
      name,
      exitCode: child.status,
      signal: child.signal,
      elapsedMs: Date.now() - started,
      log: name + ".log",
    };
    if (child.error) stage.error = child.error.message;
    report.stages.push(stage);
    await save();
    if (child.status !== 0 || child.error) {
      process.stderr.write(log);
      throw new Error(
        name + " failed; inspect " + path.join(output, name + ".log"),
      );
    }
    process.stdout.write("PASS " + name + "\n");
  }
  report.result = "pass";
} catch (error) {
  report.result = "fail";
  report.error = error.message;
  process.stderr.write(error.message + "\n");
  process.exitCode = 1;
} finally {
  report.finishedAt = new Date().toISOString();
  await save();
  process.stdout.write(
    "Verification report: " + path.join(output, "report.json") + "\n",
  );
}
