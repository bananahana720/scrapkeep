// Shared by the web drives: one browser, one evidence folder, one row a step.
import { chromium } from "playwright";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const repo = execFileSync("git", ["-C", path.dirname(fileURLToPath(import.meta.url)), "rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
export const vite = `http://127.0.0.1:${process.env.VERIFY_WEB_VITE_PORT || 5199}`;
export const kit = `http://127.0.0.1:${process.env.VERIFY_WEB_KIT_PORT || 8799}`;
export const kitVerdicts = path.join(repo, "artifacts/local/verify-web/run/verdicts.json");

// Runs `steps(page, proof)` in a fresh browser and writes rows.json, the pictures and identity.txt
// under artifacts/local/verify-web/<name>/. Exit 0 when every check held and the page threw nothing.
export async function drive(name, steps, { viewport = { width: 1440, height: 900 } } = {}) {
  const folder = process.argv[2] || name;
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(folder)) throw new Error(`bad evidence name '${folder}' (letters, digits, . _ - only)`);
  const out = path.join(repo, "artifacts/local/verify-web", folder);
  mkdirSync(out, { recursive: true });
  const executablePath = process.env.CHROMIUM_PATH || ["/opt/pw-browsers/chromium", "/usr/bin/chromium"].find((file) => existsSync(file));
  const browser = await chromium.launch({ executablePath, headless: true, args: ["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
  const page = await browser.newPage({ viewport });
  const rows = [];
  const errors = [];
  let shots = 0;
  page.on("pageerror", (error) => errors.push(error.message));
  const proof = {
    out,
    // One checked claim: what was done, what was seen, and whether it is what the feature file says.
    check(step, seen, ok) {
      rows.push({ n: rows.length + 1, step, seen, ok: Boolean(ok) });
      console.log(`${ok ? "ok  " : "FAIL"} ${rows.length} ${step}: ${JSON.stringify(seen)}`);
    },
    async shot(label) {
      shots += 1;
      const file = `${String(shots).padStart(2, "0")}-${label}.png`;
      await page.screenshot({ path: path.join(out, file) });
      return file;
    },
  };
  let crashed = null;
  try {
    await steps(page, proof);
  } catch (error) {
    crashed = String(error.message || error).split("\n")[0];
    await proof.shot("FAILED").catch(() => {});
  } finally {
    await browser.close();
  }
  const failed = rows.filter((row) => !row.ok);
  const head = execFileSync("git", ["-C", repo, "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
  writeFileSync(path.join(out, "rows.json"), JSON.stringify({ name, commit: head, rows, pageErrors: errors, crashed }, null, 2) + "\n");
  writeFileSync(path.join(out, "identity.txt"), `commit ${head}\nfinished ${new Date().toISOString()}\nchecks ${rows.length} failed ${failed.length} page errors ${errors.length} crashed ${crashed ?? "no"}\n`);
  console.log(`${name}: ${rows.length - failed.length} of ${rows.length} checks held, ${errors.length} page error(s)${crashed ? ", stopped: " + crashed : ""}; evidence in ${out}`);
  process.exit(failed.length === 0 && errors.length === 0 && crashed === null && rows.length > 0 ? 0 : 1);
}
