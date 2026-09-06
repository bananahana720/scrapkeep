import { chromium } from "playwright";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
const artifactDirectory = path.resolve(
  process.env.ARTIFACT_DIR || "artifacts/local",
);
const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_PATH || "/usr/bin/chromium",
  headless: true,
  args: [
    "--no-sandbox",
    "--use-angle=swiftshader",
    "--enable-unsafe-swiftshader",
  ],
});
try {
  const page = await browser.newPage({
      viewport: { width: 1440, height: 900 },
    }),
    errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto(
    (process.env.GAME_URL || "http://localhost:5173") + "/?qa&quality=low",
  );
  await page.locator("#qa-run").click();
  await page.waitForFunction(
    () => document.getElementById("qa-panel")?.dataset.result,
    null,
    { timeout: 120000 },
  );
  const records = await page.locator("#qa-panel").getAttribute("data-records");
  const result = await page.locator("#qa-panel").getAttribute("data-result");
  await mkdir(artifactDirectory, { recursive: true });
  await writeFile(
    path.join(artifactDirectory, "browser-tests.json"),
    JSON.stringify({ result, records: JSON.parse(records), errors }, null, 2),
  );
  await page.screenshot({
    path: path.join(artifactDirectory, "browser-regression.png"),
  });
  console.log(await page.locator("#qa-results").innerText());
  if (result !== "pass" || errors.length) process.exitCode = 1;
} finally {
  await browser.close();
}
