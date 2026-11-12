// Word lint: ruling cx (LEGIBILITY.md section 13) over the strings a player reads.
//
// Covered here, each finding tagged with its section 13 code:
//   W1  puffery as filler (epic, powerful, unleash, master, legendary). "ultimate" is an ability's name, never flagged.
//   W2  generic game filler (Welcome, Get ready, Good luck, Are you sure).
//   W4  "class" reaching the player; a bound key typed as a letter in a sentence (keys can be rebound,
//       so a keycap is drawn); a key in brackets such as "[.]".
//   W6  em or en dash, middle dot, ellipsis, exclamation mark, curly quotes; and, outside the in-world
//       voice sources (crew logs, captions, intro cards: voice: true below, which TONE-BIBLE approves in
//       that form), a colon after a label or mid-sentence (a time or a ratio is not) and capitals of
//       more than CAPS_WORDS words in a row.
//   W7  a retired name: every string in the Lint column of design-v3/NAMES.md.
//   S8  a Back button named or keyed any other way than "Back" with the Esc keycap; "Esc to close" text.
// Not attempted, left to the reviewer and a blind read of a still: S1, S2, S3, S4, S5, S6, S7, W3, W5, W8, W9.
// Review aids, not lint: Title Case (it cannot tell a record, a secret or a card name from a title-cased
// sentence), the retired names whose NAMES.md Lint cell says "reviewer", and every string SOURCES does
// not list (strings built in code from pieces, text drawn by presentation scripts outside the list).
//
// Data shape. SOURCES names every place player text comes from, as (path or glob, how to read it):
//   rows  the string values of the named fields ("name": "...") and every string value inside the named
//         consts (const TIPS := {...}; const GAP := "..."), never a dictionary key.
//   ui    string literals on a line that shows text (.text =, a toast, a label, a ChoiceButton, a
//         draw_string, a lines.append), never a key, an id, a node or resource path, a signal or a debug print.
// A finding is { rule, path, line, string, fix }; the baseline holds a count per rule and file.

import { existsSync, readdirSync, readFileSync } from "node:fs";
import path from "node:path";

export const WORD_RULES = ["W1", "W2", "W4", "W6", "W7", "S8"];

// Paths are inside the sketch. Seeded from the three unslop audits' file lists (wave 36).
export const SOURCES = [
  // tuning_panel and panel_drawer open only with --dev.
  { path: "src/ui/*.gd", read: "ui", exclude: ["src/ui/tuning_panel.gd", "src/ui/panel_drawer.gd"] },
  { path: "src/core/trees/*.gd", read: "rows", fields: ["name", "effect"], consts: ["SET_PIECE_LINES", "UNFITTED_ROWS"] },
  { path: "src/build/items.gd", read: "rows", fields: ["name", "verb", "text"] },
  { path: "src/build/parts.gd", read: "rows", fields: ["name", "verb", "pitch", "text", "label", "words"] },
  { path: "src/build/synergies.gd", read: "rows", fields: ["name", "words", "text", "found"] },
  { path: "src/build/relics.gd", read: "rows", fields: ["name", "text"] },
  { path: "src/build/attachments.gd", read: "rows", fields: ["name", "text"] },
  { path: "src/build/maker_sets.gd", read: "rows", fields: ["name", "text", "bonus_name"] },
  { path: "src/build/panels.gd", read: "rows", fields: ["name", "words"] },
  { path: "src/build/lanes.gd", read: "rows", fields: ["name", "text", "hint"] },
  { path: "src/combat/actives/active_defs.gd", read: "rows", fields: ["name", "verb", "text"] },
  { path: "src/combat/codex_entries.gd", read: "rows", fields: ["name", "text", "hint", "clue"] },
  { path: "src/boss/codex_entries.gd", read: "rows", fields: ["name", "text", "hint"] },
  { path: "src/world/codex_world.gd", read: "rows", fields: ["name", "text", "hint", "clue"] },
  { path: "src/core/secrets.gd", read: "rows", fields: ["name", "text", "hint", "clue"] },
  { path: "src/core/secrets.gd", read: "rows", fields: ["log"], voice: true },
  { path: "src/core/achievements.gd", read: "rows", fields: ["name", "text"] },
  { path: "src/core/shift_board.gd", read: "rows", fields: ["name", "text", "stamp"] },
  { path: "src/core/class_def.gd", read: "rows", fields: ["display_name", "role", "pitch", "label"] },
  { path: "src/core/companion.gd", read: "rows", fields: ["name", "effect"] },
  { path: "src/core/cosmetics.gd", read: "rows", fields: ["name"] },
  { path: "src/core/start_picks.gd", read: "rows", fields: [], consts: ["COGS_EFFECT", "CORE_EFFECT"] },
  { path: "src/core/meta_options.gd", read: "rows", fields: ["name", "text"] },
  { path: "src/core/event_kinds.gd", read: "rows", fields: ["hud", "objective"] },
  { path: "src/core/lore_rows.gd", read: "rows", fields: ["text"], consts: ["SPEAKERS"], voice: true },
  { path: "src/core/prologue_rows.gd", read: "rows", fields: ["text"], voice: true },
  { path: "src/core/tune_rows.gd", read: "rows", fields: ["name", "where"] },
  { path: "src/core/tune_rows.gd", read: "rows", fields: ["sleeve"], voice: true },
  { path: "src/core/worlds.gd", read: "rows", fields: ["name", "title", "victory", "epitaph", "sign"] },
  { path: "src/core/objectives.gd", read: "rows", fields: ["words"], consts: ["ACTIVITY_WORDS", "DONE_WORDS", "LOST_WORDS"] },
  { path: "src/core/death_tips.gd", read: "rows", fields: [], consts: ["HEAD", "GAP", "DRAWN", "ROWS"] },
  { path: "src/core/death_cause.gd", read: "rows", fields: [], consts: ["WORDS", "BOSSES"] },
  { path: "src/core/alpha_defs.gd", read: "rows", fields: ["name", "warden_hint"] },
  { path: "src/core/park_defs.gd", read: "rows", fields: ["name", "warden_hint"] },
  { path: "src/presentation/flourish_rows.gd", read: "rows", fields: ["text"], voice: true },
  { path: "src/presentation/title_intros.gd", read: "rows", fields: [], consts: ["ROWS"], voice: true },
  { path: "src/core/run_moments.gd", read: "rows", fields: [], consts: ["CAPTIONS"], voice: true },
  { path: "src/presentation/machine_fx.gd", read: "rows", fields: ["break_word", "fall_word", "eject_word"] },
  { path: "src/world/events/stage_modifier.gd", read: "rows", fields: ["line", "word"] },
  { path: "src/world/activities.gd", read: "rows", fields: ["word", "won", "open", "lost"], voice: true },
  { path: "src/world/trade_pockets.gd", read: "rows", fields: ["name", "line"] },
];

// The coverage floor: today's total (wave 36 base 0ae9b791) is 2,934 strings; the floor sits at about 90% of
// it, so a reader that silently loses a source or a field fails. Raise it when a source is added.
export const COVERAGE_FLOOR = 2650;

const finding = (rule, file, line, string, fix) => ({ rule, path: file, line, string, fix, message: `"${clip(string)}": ${fix}` });
const clip = (text) => (text.length > 70 ? `${text.slice(0, 67)}...` : text).replaceAll("\n", " ");

// GDScript string literals with their line, comments skipped. kind is "string", or "name" for &"x" and
// "path" for ^"x". masked is the source with every comment and string body blanked, line breaks kept.
export function tokenize(text) {
  const tokens = [];
  const masked = text.split("");
  let i = 0;
  let line = 1;
  while (i < text.length) {
    const c = text[i];
    if (c === "\n") { line++; i++; continue; }
    if (c === "#") {
      while (i < text.length && text[i] !== "\n") masked[i++] = " ";
      continue;
    }
    if (c !== '"' && c !== "'") { i++; continue; }
    const quote = text.startsWith(c.repeat(3), i) ? c.repeat(3) : c;
    const start = i;
    const startLine = line;
    let value = "";
    i += quote.length;
    while (i < text.length && !text.startsWith(quote, i)) {
      if (text[i] === "\\" && i + 1 < text.length) {
        const e = text[i + 1];
        if (e === "u" && /^[0-9a-fA-F]{4}$/.test(text.slice(i + 2, i + 6))) { value += String.fromCharCode(parseInt(text.slice(i + 2, i + 6), 16)); i += 6; continue; }
        value += e === "n" ? "\n" : e === "t" ? "\t" : e;
        i += 2;
        continue;
      }
      if (text[i] === "\n") {
        line++;
        if (quote.length === 1) break;
      } else {
        masked[i] = "_";
      }
      value += text[i];
      i++;
    }
    i += quote.length;
    const prefix = text[start - 1];
    tokens.push({ value, line: startLine, start, end: Math.min(i, text.length), kind: prefix === "&" ? "name" : prefix === "^" ? "path" : "string" });
  }
  return { tokens, masked: masked.join("") };
}

const isKey = (masked, token) => /^\s*:(?!=)/.test(masked.slice(token.end, token.end + 40));
// An id may carry a colon between its parts (a card key such as "hud:note"); it has no space and no capital.
const idLike = /^[a-z0-9_.\-:]*$/;
const pathLike = /:\/\/|^[%^$]?[A-Za-z0-9_]+(?:\/[A-Za-z0-9_.%]+)+$|^%[A-Z][A-Za-z0-9]*$|\.(?:gd|tscn|tres|png|ogg|wav|json|res)$|^[A-Z][a-z0-9]+(?:[A-Z][a-z0-9]+)+$|^[A-Z_][A-Z0-9]*_[A-Z0-9_]+$/;
const hasLetters = /[A-Za-z]{2}/;

// A string is player text when it carries a word and is not an id, a path or a format scrap.
export function isPlayerText(value) {
  return hasLetters.test(value) && !idLike.test(value) && !pathLike.test(value);
}

// rows: values of the named fields anywhere in the file, and every value inside the named consts.
export function readRows(text, { fields = [], consts = [] } = {}) {
  const { tokens, masked } = tokenize(text);
  const wanted = new Set(fields);
  const out = [];
  const taken = new Set();
  tokens.forEach((token, index) => {
    if (token.kind !== "string" || !wanted.has(token.value) || !isKey(masked, token)) return;
    const next = tokens[index + 1];
    if (!next || next.kind !== "string") return;
    if (!/^\s*:\s*$/.test(masked.slice(token.end, next.start))) return;
    if (hasLetters.test(next.value)) { out.push({ line: next.line, value: next.value }); taken.add(next.start); }
  });
  const lines = masked.split("\n");
  for (const name of consts) {
    const startLine = lines.findIndex((row) => new RegExp(`^const ${name}\\b`).test(row));
    if (startLine < 0) continue;
    let endLine = lines.length;
    for (let i = startLine + 1; i < lines.length; i++) {
      if (/^(?:const|var|func|static|class|enum|signal|@)\b/.test(lines[i])) { endLine = i; break; }
    }
    for (const token of tokens) {
      if (token.line <= startLine || token.line > endLine || token.kind !== "string" || taken.has(token.start)) continue;
      if (isKey(masked, token) || !isPlayerText(token.value)) continue;
      out.push({ line: token.line, value: token.value });
      taken.add(token.start);
    }
  }
  return out.sort((a, b) => a.line - b.line);
}

const shows = /\.text\s*\+?=|\b(?:tooltip_text|placeholder_text|title|heading|caption|line|words)\s*\+?=\s*["(]|\btoast\(|\bUiDraw\.label\(|\bChoiceButton\.new\(|\bdraw_string\(|\b_(?:show|say|label|line|text|heading|title|caption|row|note|stamp|plate)\(|\bset_text\(|\badd_item\(|\b(?:lines|out|rows|words|parts|bits)\.append\(|\bLabel\b/;
const debug = /\b(?:print|printerr|print_debug|push_warning|push_error|assert|_warn_once|errors\.append|emit_signal|connect|has_method|call_deferred|get_node|find_child|set_meta|get_meta|is_action\w*|has_action)\s*\(/;
const accessBefore = /(?:\bget|\bhas|\berase|\bfind|\bbegins_with|\bends_with|\bcontains|\breplace|\bsplit|\bmatch|\bplay|\bglyph|\bdraw|\bicon|\bcolor|\bsound)\s*\(\s*$|\[\s*$|\bin\s*$|==\s*$|!=\s*$/;

// The fields a UI script's own small tables use for words it shows (pause rows, hint parts, captions).
export const UI_FIELDS = ["words", "text", "label", "title", "say", "caption", "hint", "line", "note", "heading"];
const keyCap = /^key_[a-z0-9_]+$/;

// ui: string literals on a code line that shows text, or on a line that passes a keycap id
// ("key_esc") with its words; plus the UI_FIELDS of the script's own tables and every value of its
// top-level consts. Keys, ids, paths, node names and debug prints are not read.
export function readUi(text) {
  const { tokens, masked } = tokenize(text);
  const lines = masked.split("\n");
  const capLines = new Set(tokens.filter((token) => keyCap.test(token.value)).map((token) => token.line));
  const seen = new Set();
  const out = [];
  const add = (line, value) => {
    if (seen.has(`${line}\u0000${value}`)) return;
    seen.add(`${line}\u0000${value}`);
    out.push({ line, value });
  };
  for (const token of tokens) {
    if (token.kind !== "string") continue;
    const row = lines[token.line - 1] ?? "";
    if (!(shows.test(row) || capLines.has(token.line)) || debug.test(row)) continue;
    if (isKey(masked, token) || !isPlayerText(token.value)) continue;
    const lineStart = masked.lastIndexOf("\n", token.start - 1) + 1;
    if (accessBefore.test(masked.slice(lineStart, token.start))) continue;
    add(token.line, token.value);
  }
  const consts = [...masked.matchAll(/^const ([A-Z][A-Z0-9_]*)\s*:?=\s*(?!preload|load)/gm)].map((match) => match[1]);
  for (const item of readRows(text, { fields: UI_FIELDS, consts })) add(item.line, item.value);
  return out.sort((a, b) => a.line - b.line);
}

// The NAMES.md table: Thing | Use | Retire from player text | Lint. Each backticked string in Lint is banned.
export function parseNames(text) {
  const bans = [];
  for (const row of text.split("\n")) {
    const cells = row.split("|").map((cell) => cell.trim());
    if (cells.length < 6 || cells[1] === "Thing" || /^-+$/.test(cells[1])) continue;
    for (const match of cells[4].matchAll(/`([^`]+)`/g)) bans.push({ ban: match[1], thing: cells[1], use: cells[2] });
  }
  return bans;
}

// The bound key letters from bindings.gd's KEY_ constants, so a rebound game is checked against its own keys.
export function parseBoundKeys(text) {
  const letters = new Set([...text.matchAll(/\bKEY_([A-Z])\b/g)].map((match) => match[1]));
  if (letters.size === 0) throw new Error("sketch-lint: parsed no KEY_ letters from bindings.gd; W4 cannot check typed keys");
  return letters;
}

const W1_WORDS = ["epic", "powerful", "unleash", "unleashes", "master", "legendary"];
// W2 is the filler form: the phrase opens a sentence. Inside a sentence ("You're welcome.") it is a word, and
// in a voice source ("Welcome home, Kest.", the Mind speaking) it is the tone bible's line, not filler.
const W2_FILLER = /(?:^|[.!?]\s+)(?:welcome|get ready|good luck|are you sure)\b/i;
const escape = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const wordRe = (word) => new RegExp(`(?<![\\w'-])${escape(word).replace(/\\? /g, "\\s+")}(?![\\w'-])`, "i");

// Format placeholders (%s, %d, %.1f, {name}) read as a plain word so a rule never fires on them.
// A number placeholder reads as 0, so "%d:%02d" is a time like "1:30".
const plain = (value) => value.replace(/%[-+ 0-9.]*[dfxX]/g, "0").replace(/%[-+ 0-9.]*[sc%]/g, "N").replace(/\{[a-z_]+\}/g, "N");

// The accepted marks run to three words in capitals: stamps ("SHIFT COMPLETE", "END OF SHIFT"), boss
// cards ("ADMIRAL BRINDLE"), titles ("THE WAKING STILLED"), plates ("NEXT SHIFT"). A fourth word makes it
// a sentence set in capitals.
export const CAPS_WORDS = 3;

export function checkW6(value, { voice = false } = {}) {
  const text = plain(value);
  const hits = [];
  if (/[\u2014\u2013]/.test(text)) hits.push("a dash; split into two sentences or use a comma");
  if (/\u00b7/.test(text)) hits.push("a middle-dot chain; one fact per line, or a mark");
  if (/\u2026|\.\.\./.test(text)) hits.push("an ellipsis; end the sentence");
  if (/!/.test(text)) hits.push("an exclamation mark; let the line or the stamp carry it");
  if (/[\u2018\u2019\u201c\u201d]/.test(text)) hits.push("curly quotes; use straight quotes");
  if (voice) return hits;
  if (/:/.test(text.replace(/\d:\d/g, "0"))) hits.push("a colon after a label or mid-sentence; say it as one sentence");
  const caps = text.match(/(?:\b[A-Z][A-Z'-]*[A-Z]\b[ ]+)+[A-Z][A-Z'-]*[A-Z]\b/g) ?? [];
  const long = caps.find((run) => run.split(/ +/).length > CAPS_WORDS);
  if (long) hits.push(`capitals past a short mark ("${long}"); ${CAPS_WORDS} words at most, or sentence case`);
  return hits;
}

const typedKey = (letters) => new RegExp(`(?:^|(?<=\\b(?:hold|press|tap|use|hit)\\s)|(?<=[\\s(]))([${[...letters].join("")}])(?=:|\\s+(?:to|fires|leaves|empties|becomes|opens|closes|turns)\\b|\\s*$|\\s*[,.)])`);

export function lintString(file, line, value, { bans, keys, voice = false }) {
  const out = [];
  const text = plain(value);
  for (const word of W1_WORDS) if (wordRe(word).test(text)) out.push(finding("W1", file, line, value, `"${word}" is puffery; name what it does`));
  if (!voice && W2_FILLER.test(text.trim())) out.push(finding("W2", file, line, value, "generic filler; cut it, or say what happens"));
  if (wordRe("class").test(text) || wordRe("classes").test(text)) out.push(finding("W4", file, line, value, '"class" reaches the player; say "pilot" or "tier"'));
  // A key is "typed in a sentence" only where the string has a lowercase word; a lone cap label ("Esc", "P / Esc") is not a sentence.
  const sentence = /\b[a-z]{2,}\b/.test(text);
  const key = sentence ? text.match(typedKey(keys)) : null;
  if (key && !(/^[AI]$/.test(key[1]) && !/:/.test(text.slice(key.index + key[0].length, key.index + key[0].length + 1)))) {
    out.push(finding("W4", file, line, value, `the key "${key[1]}" typed in a sentence; draw its keycap (keys can be rebound)`));
  }
  if (sentence && /\[[^\]\sA-Za-z]{1,2}\]|\[(?:Esc|Tab|Space|Enter)\]|\bEsc\b/.test(text)) out.push(finding("W4", file, line, value, "a key typed as text; draw its keycap"));
  for (const hit of checkW6(value, { voice })) out.push(finding("W6", file, line, value, hit));
  for (const { ban, use } of bans) if (wordRe(ban).test(text)) out.push(finding("W7", file, line, value, `"${ban}" is retired; say "${use.replace(/\s*\(.*$/, "").split(/[.,;]/)[0]}"`));
  return out;
}

const backButton = /\bChoiceButton\.new\(\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"/;
const backIds = new Set(["back", "close", "return"]);

// S8: a Back action named or keyed another way. Reads ChoiceButton lines and close-hint text in UI scripts.
export function lintS8(file, text) {
  const { masked } = tokenize(text);
  const raw = text.split("\n");
  const out = [];
  masked.split("\n").forEach((row, index) => {
    if (!/ChoiceButton\.new\(/.test(row)) return;
    const match = raw[index].match(backButton);
    if (!match) return;
    const [, id, key, label] = match;
    const isBack = backIds.has(id) || /^(?:Back|Return|Close)\b/.test(label);
    if (isBack && (label !== "Back" || key !== "key_esc")) {
      out.push(finding("S8", file, index + 1, label, `a Back action is "Back" with the Esc keycap (key_esc), not "${label}" on ${key}`));
    }
  });
  return out;
}

export function lintS8Text(file, line, value) {
  return /\bEsc to (?:close|leave)\b|^(?:Return|Close)$/i.test(value)
    ? [finding("S8", file, line, value, 'Back is one action: a "Back" button with the Esc keycap')]
    : [];
}

function globRe(glob) {
  return new RegExp(`^${glob.split("/").map((part) => part === "**" ? ".*" : part.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, "[^/]*")).join("/")}$`);
}

function files(directory, base = directory) {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(directory, entry.name);
    return entry.isDirectory() ? files(full, base) : [path.relative(base, full).split(path.sep).join("/")];
  });
}

// One file read the way its source says, every string linted. Returns { read, findings }.
export function lintFile(file, text, source, { bans, keys }) {
  const strings = source.read === "ui" ? readUi(text) : readRows(text, source);
  const findings = [];
  for (const item of strings) {
    findings.push(...lintString(file, item.line, item.value, { bans, keys, voice: source.voice === true }));
    if (source.read === "ui") findings.push(...lintS8Text(file, item.line, item.value));
  }
  if (source.read === "ui") findings.push(...lintS8(file, text));
  return { read: strings.length, findings };
}

// Reads every source and lints every string. Returns { findings, read } where read is a list of
// { source, count } in SOURCES order and findings carry repo-relative paths under prefix.
export function lintWords({ sketchDir, prefix, names, bindings, sources = SOURCES, floor = COVERAGE_FLOOR }) {
  const bans = parseNames(names);
  const keys = parseBoundKeys(bindings);
  const all = files(path.join(sketchDir, "src"), sketchDir);
  const findings = [];
  const read = [];
  let total = 0;
  for (const source of sources) {
    const matcher = globRe(source.path);
    const matched = all.filter((rel) => matcher.test(rel) && !(source.exclude ?? []).includes(rel)).sort();
    if (matched.length === 0) {
      findings.push(finding("COVERAGE", `${prefix}/${source.path}`, 1, source.path, "a source in SOURCES matches no file; fix the path or drop the row"));
    }
    let count = 0;
    for (const rel of matched) {
      const result = lintFile(`${prefix}/${rel}`, readFileSync(path.join(sketchDir, rel), "utf8"), source, { bans, keys });
      count += result.read;
      findings.push(...result.findings);
    }
    read.push({ source: `${source.path} ${source.read}${source.voice ? " voice" : ""}${source.fields?.length ? ` ${source.fields.join(",")}` : ""}`, count });
    total += count;
  }
  if (total < floor) findings.push(finding("COVERAGE", `${prefix}/src`, 1, String(total), `read ${total} player strings, under the floor of ${floor}; a reader or a source has gone quiet`));
  return { findings, read, total };
}
