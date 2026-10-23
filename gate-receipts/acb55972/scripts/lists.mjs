import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import path from "node:path";
const [wt, out] = process.argv.slice(2);
const { isBot } = await import(path.join(wt, "scripts/sketch-smoke.mjs"));
const dir = path.join(wt, "sketches/core-loop/tests");
const bots = [], rest = [];
for (const f of readdirSync(dir).filter((f) => f.endsWith(".gd")).sort()) (isBot(readFileSync(path.join(dir, f), "utf8")) ? bots : rest).push(f.replace(/\.gd$/, ""));
writeFileSync(`${out}-nonbot.txt`, rest.join("\n") + "\n"); writeFileSync(`${out}-bots.txt`, bots.join("\n") + "\n");
console.log(`nonbot ${rest.length} bots ${bots.length}`);
