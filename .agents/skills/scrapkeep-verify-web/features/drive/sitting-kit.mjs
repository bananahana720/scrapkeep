#!/usr/bin/env node
// The Sitting Kit page: mark an area, write a note, veto a call, reload, export, clear.
// Usage: node .agents/skills/scrapkeep-verify-web/features/drive/sitting-kit.mjs [<evidence name>]
import { existsSync, readFileSync } from "node:fs";
import { drive, kit, kitVerdicts } from "./lib.mjs";

const saved = () => (existsSync(kitVerdicts) ? readFileSync(kitVerdicts, "utf8") : "");
const gate = (page) => page.locator("#gate").innerText();
// The row of area buttons sticks to the top and would sit over a control scrolled just under it,
// so each control is brought to the middle of the view before the click, as a reader would scroll.
const press = async (locator) => {
  await locator.evaluate((node) => node.scrollIntoView({ block: "center" }));
  await locator.click();
};

await drive("sitting-kit", async (page, proof) => {
  await page.goto(kit + "/");
  await page.locator("#pips button").first().waitFor();
  const build = await (await page.request.get(kit + "/api/build")).json();
  proof.check("the page names the build", { shown: await page.locator("#build").innerText(), commit: build.short }, (await page.locator("#build").innerText()).includes(build.short));
  proof.check("eleven area buttons, none marked", { pips: await page.locator("#pips button").count(), gate: await gate(page) }, (await page.locator("#pips button").count()) === 11 && (await gate(page)).includes("0 of 11"));
  await proof.shot("fresh");

  const third = page.locator("section.area").nth(2);
  await page.locator("#pips button").nth(2).click();
  await press(third.locator('.vbtn[data-v="notyet"]'));
  proof.check("area 3 marked Not yet", { area: await third.getAttribute("data-v"), pip: await page.locator("#pips button").nth(2).getAttribute("data-v"), gate: await gate(page) }, (await third.getAttribute("data-v")) === "notyet" && (await gate(page)).includes("1 of 11"));
  await third.locator("textarea").fill("stamina bar unreadable");
  await press(third.locator('input[type="checkbox"]').first());
  await press(page.locator("section.area").nth(0).locator('.vbtn[data-v="accept"]'));
  const veto = page.locator("section.area").nth(1).locator('button[data-choice="veto"]').first();
  await press(veto);
  proof.check("area 1 accepted, a call in area 2 vetoed", { gate: await gate(page), veto: await veto.getAttribute("aria-pressed") }, (await gate(page)).includes("2 of 11") && (await veto.getAttribute("aria-pressed")) === "true");
  await page.waitForFunction(() => document.getElementById("save").dataset.state === "pc", null, { timeout: 10000 });
  await proof.shot("marked");
  proof.check("the server wrote the marks to its file", { file: kitVerdicts, hasNote: saved().includes("stamina bar unreadable"), hasNotYet: saved().includes("notyet") }, saved().includes("stamina bar unreadable") && saved().includes("notyet"));

  await page.goto(kit + "/");
  await page.waitForFunction(() => document.getElementById("gate").innerText.includes(" of 11"), null, { timeout: 10000 });
  proof.check("marks survive a reload", { gate: await gate(page), note: await page.locator("section.area").nth(2).locator("textarea").inputValue(), veto: await page.locator("section.area").nth(1).locator('button[data-choice="veto"]').first().getAttribute("aria-pressed") },
    (await gate(page)).includes("2 of 11") && (await page.locator("section.area").nth(2).locator("textarea").inputValue()) === "stamina bar unreadable");

  await press(page.locator("#print"));
  const markdown = await page.locator("#out").innerText();
  proof.check("Show Markdown lists the verdict and the note", { length: markdown.length, hasNotYet: markdown.includes("Not yet"), hasNote: markdown.includes("stamina bar unreadable") }, markdown.includes("Not yet") && markdown.includes("stamina bar unreadable"));
  await page.locator("#out").scrollIntoViewIfNeeded();
  await proof.shot("markdown");

  await press(page.locator("#reset"));
  proof.check("Clear all marks asks first", { label: await page.locator("#reset").innerText() }, (await page.locator("#reset").innerText()).toLowerCase().includes("press again"));
  await press(page.locator("#reset"));
  await page.waitForLoadState("load");
  await page.waitForFunction(() => document.getElementById("gate").innerText.includes("0 of 11"), null, { timeout: 10000 });
  proof.check("cleared", { gate: await gate(page), note: await page.locator("section.area").nth(2).locator("textarea").inputValue(), fileHasNote: saved().includes("stamina bar unreadable") }, (await gate(page)).includes("0 of 11") && !saved().includes("stamina bar unreadable"));
  await proof.shot("cleared");
});
