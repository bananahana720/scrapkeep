import { readFileSync, writeFileSync } from "node:fs";
const lines = readFileSync(new URL("../../../../BIBLE.md", import.meta.url), "utf8").split("\n");
const anchor = (t) => t.toLowerCase().replace(/[^\w\s-]/g, "").trim().replace(/\s+/g, "-");
let section = null; const rows = [];
for (let i = 0; i < lines.length; i++) {
  const h2 = lines[i].match(/^## (\d)\. (.*)$/);
  if (h2) { section = Number(h2[1]) >= 3 && Number(h2[1]) <= 9 ? `${h2[1]}. ${h2[2]}` : null; continue; }
  if (/^## /.test(lines[i])) section = null;
  const h3 = lines[i].match(/^### (.*)$/);
  if (h3 && section) rows.push({ id: `N-${String(rows.length + 1).padStart(3, "0")}`, noun: h3[1], section, line: i + 1, anchor: anchor(h3[1]) });
}
const md = ["# HF-06a noun list", "", `Generated from BIBLE.md sections 3 to 9 by make-nouns.mjs; ${rows.length} rows. Each row is one \`###\` heading. Row IDs are stable inputs for the HF-06a matrix.`, "", "| Row | Noun | Bible section | Line | Anchor |", "| --- | --- | --- | --- | --- |", ...rows.map((r) => `| ${r.id} | ${r.noun} | ${r.section} | ${r.line} | [#${r.anchor}](../../../../BIBLE.md#${r.anchor}) |`), ""].join("\n");
writeFileSync(new URL("./nouns.md", import.meta.url), md);
console.log(`${rows.length} rows`);
