#!/usr/bin/env node
// The original yard (/): the start screen, How to play, a hero pick and the start of an expedition.
// Usage: node .agents/skills/scrapkeep-verify-web/features/drive/yard.mjs [<evidence name>]
import { drive, vite } from "./lib.mjs";

await drive("yard", async (page, proof) => {
  await page.goto(vite + "/?quality=low");
  await page.locator("#start").waitFor();
  proof.check("the start screen is up", { title: await page.title(), start: await page.locator("#start").innerText() }, (await page.title()).includes("Scrapkeep") && (await page.locator("#start").isVisible()));
  await proof.shot("start-screen");
  await page.locator("#help").click();
  await page.waitForTimeout(500);
  await proof.shot("how-to-play");
  await page.keyboard.press("Escape");
  await page.getByText("Rivet", { exact: false }).first().click();
  await proof.shot("hero-picked");
  await page.locator("#start").click();
  await page.waitForFunction(() => { const s = document.getElementById("start"); return !s || s.offsetParent === null; }, null, { timeout: 30000 });
  await page.keyboard.down("w");
  await page.waitForTimeout(3000);
  await page.keyboard.up("w");
  const canvas = await page.locator("#world").boundingBox();
  proof.check("the expedition started: the start button is gone and the world is drawn", { canvas }, canvas !== null && canvas.width > 300);
  await proof.shot("in-expedition");
});
