#!/usr/bin/env node
// The Iron Orchard (/orchard.html): the entry card and the first seconds inside.
// Usage: node .agents/skills/scrapkeep-verify-web/features/drive/orchard.mjs [<evidence name>]
import { drive, vite } from "./lib.mjs";

await drive("orchard", async (page, proof) => {
  await page.goto(vite + "/orchard.html");
  await page.locator("#start").waitFor();
  proof.check("the entry card is up", { title: await page.title(), start: await page.locator("#start").innerText() }, (await page.title()).includes("Iron Orchard"));
  await proof.shot("entry");
  await page.locator("#start").click();
  await page.waitForFunction(() => { const s = document.getElementById("start"); return !s || s.offsetParent === null; }, null, { timeout: 30000 });
  await page.keyboard.down("w");
  await page.waitForTimeout(3000);
  await page.keyboard.up("w");
  const canvas = await page.locator("#orchard-world").boundingBox();
  proof.check("inside the orchard: the entry button is gone and the world is drawn", { canvas }, canvas !== null && canvas.width > 300);
  await proof.shot("inside");
});
