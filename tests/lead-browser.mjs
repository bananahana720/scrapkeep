import { chromium } from "playwright";
import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { createLeadServer } from "../server/index.js";

const artifactDirectory = path.resolve(
  process.env.ARTIFACT_DIR || "artifacts/local",
);
await mkdir(artifactDirectory, { recursive: true });
const temporary = await mkdtemp(
  path.join(os.tmpdir(), "scrapkeep-browser-leads-"),
);
let app, browser;
try {
  app = await createLeadServer({
    dataDirectory: temporary,
    distDirectory: path.resolve("dist"),
  });
  await new Promise((resolve) => app.server.listen(0, "127.0.0.1", resolve));
  const url = `http://127.0.0.1:${app.server.address().port}`;
  browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || "/usr/bin/chromium",
    headless: true,
    args: [
      "--no-sandbox",
      "--use-angle=swiftshader",
      "--enable-unsafe-swiftshader",
    ],
  });
  const checks = [],
    errors = [];
  const check = (name, value) => {
    assert.ok(value, name);
    checks.push(name);
  };
  const page = await browser.newPage({
    viewport: { width: 1280, height: 800 },
  });
  page.on("pageerror", (error) => errors.push(error.message));
  await page.goto(url + "/?quality=low");
  await page.locator("#start").waitFor();
  await page.evaluate(() => document.fonts.ready);
  await page.evaluate(
    () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve)),
      ),
  );
  check(
    "Production excludes QA globals and controls",
    await page.evaluate(
      () => !window.__scrapkeep && !document.querySelector("#qa-panel"),
    ),
  );

  await page.locator("#open-collection").click();
  await page.locator("#lead-submit").waitFor();
  check(
    "Email and SMS start unchecked",
    !(await page.locator("#consent-email").isChecked()) &&
      !(await page.locator("#consent-sms").isChecked()),
  );
  await page.locator("#lead-submit").click();
  await page
    .getByText(
      "Enter a contact detail and tick its permission box to choose your updates.",
      { exact: true },
    )
    .waitFor();
  check("Contact without opt-in is rejected by UI", true);
  await page.locator('[data-hero="engineer"]').click();
  await page.locator("#lead-email").fill("automated-browser@example.com");
  await page.locator("#consent-email").check();
  await page.locator("#lead-phone").fill("+1 (555) 010-0002");
  await page.locator("#consent-sms").check();
  await page.locator("#lead-submit").click();
  await page
    .getByText(
      "Saved. Your interest in Rivet is on this server. No messages have been sent.",
      { exact: true },
    )
    .waitFor();
  let stored = JSON.parse(
    await readFile(path.join(temporary, "leads.json"), "utf8"),
  );
  check(
    "Real browser POST stores both opted-in channels and hero interest",
    stored.leads.length === 1 &&
      stored.leads[0].contacts.email.length === 1 &&
      stored.leads[0].contacts.sms.length === 1 &&
      stored.leads[0].interests.includes("engineer"),
  );
  check(
    "Successful submission clears contact fields",
    (await page.locator("#lead-email").inputValue()) === "" &&
      (await page.locator("#lead-phone").inputValue()) === "",
  );
  await page.screenshot({
    path: path.join(artifactDirectory, "figurine-collection.png"),
  });
  await page.locator("#lead-email").fill("automated-browser@example.com");
  await page.locator("#consent-email").check();
  await page.locator("#lead-submit").click();
  await page
    .getByText(
      "Saved. Your interest in Rivet is on this server. No messages have been sent.",
      { exact: true },
    )
    .waitFor();
  stored = JSON.parse(
    await readFile(path.join(temporary, "leads.json"), "utf8"),
  );
  check(
    "Browser retry does not duplicate the lead or discard SMS consent",
    stored.leads.length === 1 && stored.leads[0].contacts.sms.length === 1,
  );
  await page.route("**/api/leads", (route) => route.abort());
  await page.locator("#lead-email").fill("failed-save@example.com");
  await page.locator("#consent-email").check();
  await page.locator("#lead-submit").click();
  await page
    .getByText(
      "The signup service is unavailable. Your details have not been confirmed saved. Please try again.",
      { exact: true },
    )
    .waitFor();
  check(
    "Network failure shows error and preserves retry input",
    (await page.locator("#lead-email").inputValue()) ===
      "failed-save@example.com" &&
      (await page.locator("#lead-submit").isEnabled()),
  );
  await page.unroute("**/api/leads");
  await page.locator(".dialog-close").click();
  await page.goto(url + "/?quality=low#challenge=1.42.warden.5000");
  await page
    .getByText("A FRIEND LEFT YOU A CHALLENGE", { exact: true })
    .waitFor();
  check(
    "Shared challenge selects its required hero",
    (await page
      .locator('[data-class="warden"]')
      .getAttribute("aria-pressed")) === "true",
  );
  await page.locator("#start").click();
  await page.getByText("TARGET 5,000", { exact: true }).waitFor();
  check("Friend score is visible while playing", true);
  await page.locator("#pause").click();
  await page.locator("#menu-button").click();
  await page.locator("#daily-start").click();
  check(
    "Daily expedition clears a prior friend challenge",
    !new URL(page.url()).hash,
  );
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(url + "/?quality=low");
  await page.locator("#start").waitFor();
  await page.evaluate(() => document.fonts.ready);
  await page.evaluate(
    () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve)),
      ),
  );
  await page.screenshot({
    path: path.join(artifactDirectory, "expedition-mobile-menu.png"),
  });
  const mobileBounds = await page.evaluate(() => ({
    width: innerWidth,
    menu: document.querySelector("#menu").scrollWidth,
    children: [...document.querySelectorAll("#menu *")]
      .filter((e) => e.getBoundingClientRect().right > innerWidth + 1)
      .slice(0, 10)
      .map((e) => ({
        cls: e.className,
        right: e.getBoundingClientRect().right,
      })),
  }));
  check(
    "Phone title screen has no horizontal overflow: " +
      JSON.stringify(mobileBounds),
    mobileBounds.menu <= mobileBounds.width,
  );
  await page.locator("#open-collection").click();
  await page.locator("#lead-submit").waitFor();
  await page.locator("#lead-phone").scrollIntoViewIfNeeded();
  const rect = await page.locator("#lead-phone").boundingBox();
  check(
    "Phone signup fields fit viewport and remain reachable",
    rect.width > 250 && rect.x >= 0 && rect.x + rect.width <= 390,
  );
  await page.screenshot({
    path: path.join(artifactDirectory, "figurine-mobile.png"),
  });
  await page.locator(".dialog-close").click();
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.locator('[data-class="engineer"]').click();
  await page.evaluate(
    () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve)),
      ),
  );
  await page.screenshot({
    path: path.join(artifactDirectory, "expedition-menu.png"),
  });
  check("No browser runtime errors", errors.length === 0);
  await writeFile(
    path.join(artifactDirectory, "lead-browser-tests.json"),
    JSON.stringify(
      {
        result: "pass",
        checks,
        errors,
        storage: "Temporary synthetic test records, no external messages.",
      },
      null,
      2,
    ),
  );
  console.log(`${checks.length} production browser checks passed`);
} finally {
  try {
    await browser?.close();
  } finally {
    try {
      await app?.close();
    } finally {
      await rm(temporary, { recursive: true, force: true });
    }
  }
}
