#!/usr/bin/env node

import { lstatSync, readFileSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { isMain } from "./lib/cli.mjs";
import { git, gitOptional, nulSeparated } from "./lib/git.mjs";

const defaultRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export const SUPPORTED_EXTENSIONS = new Set([".gd", ".gdshader", ".js", ".mjs", ".ts"]);

const GD_MULTI_OPS = [
  "<<=",
  ">>=",
  "**=",
  "->",
  ":=",
  "==",
  "!=",
  "<=",
  ">=",
  "&&",
  "||",
  "**",
  "<<",
  ">>",
  "+=",
  "-=",
  "*=",
  "/=",
  "%=",
  "&=",
  "|=",
  "^=",
];

const JS_MULTI_OPS = [
  ">>>=",
  "===",
  "!==",
  ">>>",
  "<<=",
  ">>=",
  "**=",
  "&&=",
  "||=",
  "??=",
  "...",
  "?.",
  "=>",
  "++",
  "--",
  "**",
  "<<",
  ">>",
  "<=",
  ">=",
  "==",
  "!=",
  "&&",
  "||",
  "??",
  "+=",
  "-=",
  "*=",
  "/=",
  "%=",
  "&=",
  "|=",
  "^=",
];

const REGEX_PRECEDING_KEYWORDS = new Set([
  "return",
  "throw",
  "case",
  "default",
  "delete",
  "void",
  "typeof",
  "await",
  "yield",
  "in",
  "instanceof",
  "of",
  "new",
  "else",
  "do",
  "export",
]);

const CONDITION_KEYWORDS = new Set(["if", "while", "for", "with"]);

const GD_NUM_RE =
  /(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|(?:[0-9][0-9_]*(?:\.[0-9_]*)?|\.[0-9][0-9_]*)(?:[eE][+-]?[0-9_]+)?)/y;
const GD_ID_RE = /[A-Za-z_][A-Za-z0-9_]*/y;
const JS_NUM_RE =
  /(?:0[xX][0-9a-fA-F_]+n?|0[bB][01_]+n?|0[oO][0-7_]+n?|(?:[0-9][0-9_]*(?:\.[0-9_]*)?|\.[0-9][0-9_]*)(?:[eE][+-]?[0-9_]+)?n?)/y;
const JS_ID_RE = /[A-Za-z_$][A-Za-z0-9_$]*/y;

function normalizePragma(kind, rest) {
  return `${kind}:${rest.trim().replace(/\s+/g, " ")}`;
}

export function lexGd(source) {
  const text = String(source ?? "").replace(/\r\n?/g, "\n");
  const tokens = [];
  const indentStack = [0];
  let i = 0;
  let line = 1;
  let parenDepth = 0;
  let atLineStart = true;
  let pendingIndent = null;
  let lineHasCode = false;

  const flushIndent = (lineNum) => {
    if (pendingIndent === null) return;
    const top = indentStack[indentStack.length - 1];
    if (pendingIndent > top) {
      indentStack.push(pendingIndent);
      tokens.push({ kind: "INDENT", value: "INDENT", line: lineNum });
    } else if (pendingIndent < top) {
      while (indentStack.length > 1 && indentStack[indentStack.length - 1] > pendingIndent) {
        indentStack.pop();
        tokens.push({ kind: "DEDENT", value: "DEDENT", line: lineNum });
      }
    }
    pendingIndent = null;
  };

  while (i < text.length) {
    if (atLineStart && parenDepth === 0) {
      let indent = 0;
      while (i < text.length && (text[i] === " " || text[i] === "\t")) {
        indent += text[i] === "\t" ? 4 : 1;
        i++;
      }
      atLineStart = false;
      pendingIndent = indent;
      if (i >= text.length) break;
    }

    const ch = text[i];

    if (ch === " " || ch === "\t") {
      i++;
      continue;
    }

    if (ch === "\\" && text[i + 1] === "\n") {
      i += 2;
      line++;
      continue;
    }

    if (ch === "\n") {
      if (parenDepth === 0) {
        if (lineHasCode) {
          tokens.push({ kind: "NEWLINE", value: "\n", line });
          lineHasCode = false;
        }
        atLineStart = true;
        pendingIndent = null;
      }
      line++;
      i++;
      continue;
    }

    if (ch === "#") {
      let end = text.indexOf("\n", i + 1);
      if (end < 0) end = text.length;
      const body = text.slice(i + 1, end);
      const pragmaMatch = /^\s*(smoke|lint):(.*)$/.exec(body);
      if (pragmaMatch && (pragmaMatch[1] === "lint" || line <= 5)) {
        tokens.push({
          kind: "PRAGMA",
          value: normalizePragma(pragmaMatch[1], pragmaMatch[2]),
          line,
        });
      }
      i = end;
      continue;
    }

    const hasStringPrefix =
      (ch === "r" || ch === "&" || ch === "^") &&
      (text[i + 1] === '"' || text[i + 1] === "'") &&
      (i === 0 || !/[A-Za-z0-9_]/.test(text[i - 1]));

    if (hasStringPrefix || ch === '"' || ch === "'") {
      const start = i;
      const startLine = line;
      if (hasStringPrefix) i++;
      const quoteChar = text[i];
      const triple = text.startsWith(quoteChar.repeat(3), i);
      const quote = triple ? quoteChar.repeat(3) : quoteChar;
      i += quote.length;
      while (i < text.length && !text.startsWith(quote, i)) {
        if (text[i] === "\\" && i + 1 < text.length) {
          if (text[i + 1] === "\n") line++;
          i += 2;
          continue;
        }
        if (text[i] === "\n") {
          line++;
          if (!triple) break;
        }
        i++;
      }
      if (text.startsWith(quote, i)) i += quote.length;
      flushIndent(startLine);
      lineHasCode = true;
      tokens.push({ kind: "STRING", value: text.slice(start, i), line: startLine });
      continue;
    }

    if ((ch >= "0" && ch <= "9") || (ch === "." && text[i + 1] >= "0" && text[i + 1] <= "9")) {
      GD_NUM_RE.lastIndex = i;
      const numMatch = GD_NUM_RE.exec(text);
      if (numMatch) {
        flushIndent(line);
        lineHasCode = true;
        tokens.push({ kind: "NUMBER", value: numMatch[0], line });
        i = GD_NUM_RE.lastIndex;
        continue;
      }
    }

    if ((ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z") || ch === "_") {
      GD_ID_RE.lastIndex = i;
      const idMatch = GD_ID_RE.exec(text);
      flushIndent(line);
      lineHasCode = true;
      tokens.push({ kind: "IDENT", value: idMatch[0], line });
      i = GD_ID_RE.lastIndex;
      continue;
    }

    let op = ch;
    for (const candidate of GD_MULTI_OPS) {
      if (text.startsWith(candidate, i)) {
        op = candidate;
        break;
      }
    }
    if (op === "(" || op === "[" || op === "{") parenDepth++;
    else if ((op === ")" || op === "]" || op === "}") && parenDepth > 0) parenDepth--;
    flushIndent(line);
    lineHasCode = true;
    tokens.push({ kind: "OP", value: op, line });
    i += op.length;
  }

  if (lineHasCode) {
    tokens.push({ kind: "NEWLINE", value: "\n", line });
  }
  while (indentStack.length > 1) {
    indentStack.pop();
    tokens.push({ kind: "DEDENT", value: "DEDENT", line });
  }

  return tokens;
}

export function lexJsLike(source, { allowRegex = true } = {}) {
  const text = String(source ?? "").replace(/\r\n?/g, "\n");
  const tokens = [];
  const parenMeta = [];
  const templateStack = [];
  let i = 0;
  let line = 1;

  const prevCodeToken = () => {
    for (let idx = tokens.length - 1; idx >= 0; idx--) {
      if (tokens[idx].kind !== "PRAGMA") return tokens[idx];
    }
    return null;
  };

  const canStartRegex = () => {
    const prev = prevCodeToken();
    if (!prev) return true;
    if (prev.kind === "OP") {
      if (prev.value === ")") return Boolean(prev.isConditionClose);
      if (prev.value === "]" || prev.value === "++" || prev.value === "--") return false;
      if (prev.value === "}") return false;
      return true;
    }
    if (prev.kind === "IDENT") {
      return REGEX_PRECEDING_KEYWORDS.has(prev.value);
    }
    return false;
  };

  const scanTemplate = (isHead) => {
    const start = i;
    const startLine = line;
    i++;
    while (i < text.length) {
      const c = text[i];
      if (c === "\\" && i + 1 < text.length) {
        if (text[i + 1] === "\n") line++;
        i += 2;
        continue;
      }
      if (c === "`") {
        i++;
        tokens.push({
          kind: isHead ? "STRING" : "TEMPLATE_TAIL",
          value: text.slice(start, i),
          line: startLine,
        });
        return;
      }
      if (c === "$" && text[i + 1] === "{") {
        tokens.push({
          kind: isHead ? "TEMPLATE_HEAD" : "TEMPLATE_MID",
          value: text.slice(start, i + 2),
          line: startLine,
        });
        tokens.push({ kind: "OP", value: "${", line });
        i += 2;
        templateStack.push({ braceDepth: 0 });
        return;
      }
      if (c === "\n") line++;
      i++;
    }
    tokens.push({
      kind: isHead ? "STRING" : "TEMPLATE_TAIL",
      value: text.slice(start, i),
      line: startLine,
    });
  };

  if (text.startsWith("#!")) {
    let end = text.indexOf("\n");
    if (end < 0) end = text.length;
    tokens.push({ kind: "PRAGMA", value: `shebang:${text.slice(2, end).trim()}`, line: 1 });
    i = end;
  }

  while (i < text.length) {
    const ch = text[i];

    if (ch === "\n") {
      line++;
      i++;
      continue;
    }
    if (ch === " " || ch === "\t" || ch === "\v" || ch === "\f") {
      i++;
      continue;
    }

    if (ch === "/" && text[i + 1] === "/") {
      let end = text.indexOf("\n", i + 2);
      if (end < 0) end = text.length;
      const body = text.slice(i + 2, end);
      const pragmaMatch = /^\s*lint:(.*)$/.exec(body);
      if (pragmaMatch) {
        tokens.push({
          kind: "PRAGMA",
          value: normalizePragma("lint", pragmaMatch[1]),
          line,
        });
      }
      i = end;
      continue;
    }

    if (ch === "/" && text[i + 1] === "*") {
      i += 2;
      while (i < text.length && !(text[i] === "*" && text[i + 1] === "/")) {
        if (text[i] === "\n") line++;
        i++;
      }
      if (i + 1 < text.length) i += 2;
      continue;
    }

    if (ch === "`") {
      scanTemplate(true);
      continue;
    }

    if (ch === "}") {
      if (templateStack.length > 0 && templateStack[templateStack.length - 1].braceDepth === 0) {
        templateStack.pop();
        tokens.push({ kind: "OP", value: "}", line });
        scanTemplate(false);
        continue;
      }
      if (templateStack.length > 0) {
        templateStack[templateStack.length - 1].braceDepth--;
      }
      tokens.push({ kind: "OP", value: "}", line });
      i++;
      continue;
    }

    if (ch === "{") {
      if (templateStack.length > 0) {
        templateStack[templateStack.length - 1].braceDepth++;
      }
      tokens.push({ kind: "OP", value: "{", line });
      i++;
      continue;
    }

    if (ch === '"' || ch === "'") {
      const start = i;
      const startLine = line;
      i++;
      while (i < text.length && text[i] !== ch) {
        if (text[i] === "\\" && i + 1 < text.length) {
          if (text[i + 1] === "\n") line++;
          i += 2;
          continue;
        }
        if (text[i] === "\n") {
          line++;
          break;
        }
        i++;
      }
      if (text[i] === ch) i++;
      tokens.push({ kind: "STRING", value: text.slice(start, i), line: startLine });
      continue;
    }

    if (ch === "/" && allowRegex && canStartRegex()) {
      const start = i;
      const startLine = line;
      i++;
      let inClass = false;
      while (i < text.length) {
        const c = text[i];
        if (c === "\\" && i + 1 < text.length && text[i + 1] !== "\n") {
          i += 2;
          continue;
        }
        if (c === "\n") break;
        if (c === "[") inClass = true;
        else if (c === "]") inClass = false;
        else if (c === "/" && !inClass) {
          i++;
          break;
        }
        i++;
      }
      while (i < text.length && /[a-zA-Z]/.test(text[i])) i++;
      tokens.push({ kind: "REGEX", value: text.slice(start, i), line: startLine });
      continue;
    }

    if ((ch >= "0" && ch <= "9") || (ch === "." && text[i + 1] >= "0" && text[i + 1] <= "9")) {
      JS_NUM_RE.lastIndex = i;
      const numMatch = JS_NUM_RE.exec(text);
      if (numMatch) {
        tokens.push({ kind: "NUMBER", value: numMatch[0], line });
        i = JS_NUM_RE.lastIndex;
        continue;
      }
    }

    if ((ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z") || ch === "_" || ch === "$") {
      JS_ID_RE.lastIndex = i;
      const idMatch = JS_ID_RE.exec(text);
      tokens.push({ kind: "IDENT", value: idMatch[0], line });
      i = JS_ID_RE.lastIndex;
      continue;
    }

    let op = ch;
    for (const candidate of JS_MULTI_OPS) {
      if (text.startsWith(candidate, i)) {
        op = candidate;
        break;
      }
    }
    if (op === "(") {
      const prev = prevCodeToken();
      parenMeta.push({
        isCondition: Boolean(prev && prev.kind === "IDENT" && CONDITION_KEYWORDS.has(prev.value)),
      });
      tokens.push({ kind: "OP", value: op, line });
    } else if (op === ")") {
      const meta = parenMeta.pop();
      tokens.push({
        kind: "OP",
        value: op,
        line,
        isConditionClose: Boolean(meta?.isCondition),
      });
    } else {
      tokens.push({ kind: "OP", value: op, line });
    }
    i += op.length;
  }

  return tokens;
}

export function lexByExtension(filePath, source) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === ".gd") return lexGd(source);
  if (ext === ".gdshader") return lexJsLike(source, { allowRegex: false });
  if (ext === ".js" || ext === ".mjs" || ext === ".ts") {
    return lexJsLike(source, { allowRegex: true });
  }
  throw new Error(`unsupported extension for token-diff: ${filePath}`);
}

export function diffTokenStreams(baseTokens, headTokens) {
  const limit = Math.max(baseTokens.length, headTokens.length);
  for (let idx = 0; idx < limit; idx++) {
    const a = baseTokens[idx];
    const b = headTokens[idx];
    if (!a) {
      return {
        changed: true,
        baseLine: baseTokens.at(-1)?.line ?? 0,
        headLine: b.line,
        baseToken: null,
        headToken: b,
      };
    }
    if (!b) {
      return {
        changed: true,
        baseLine: a.line,
        headLine: headTokens.at(-1)?.line ?? 0,
        baseToken: a,
        headToken: null,
      };
    }
    if (a.kind !== b.kind || a.value !== b.value) {
      return {
        changed: true,
        baseLine: a.line,
        headLine: b.line,
        baseToken: a,
        headToken: b,
      };
    }
  }
  return { changed: false };
}

function resolveDefaultBase(root) {
  if (gitOptional(["rev-parse", "--verify", "--quiet", "origin/main"], { cwd: root }) !== null)
    return "origin/main";
  if (gitOptional(["rev-parse", "--verify", "--quiet", "HEAD"], { cwd: root }) !== null)
    return "HEAD";
  throw new Error("cannot resolve default base (neither origin/main nor HEAD exists)");
}

function gitShowOptional(root, spec) {
  try {
    return git(["show", spec], { cwd: root, trim: false });
  } catch (error) {
    if (error.status === undefined) throw error;
    return null;
  }
}

export function runTokenDiff({ root = defaultRoot, base = null, staged = false } = {}) {
  const targetBase = base ?? resolveDefaultBase(root);
  if (
    gitOptional(["rev-parse", "--verify", "--quiet", `${targetBase}^{commit}`], { cwd: root }) ===
    null
  ) {
    throw new Error(`invalid base revision: ${targetBase}`);
  }

  const changedSet = new Set();
  const diffArgs = staged
    ? ["diff", "--cached", "--name-only", "-z", targetBase]
    : ["diff", "--name-only", "-z", targetBase];
  for (const file of nulSeparated(git(diffArgs, { cwd: root, trim: false }))) {
    if (SUPPORTED_EXTENSIONS.has(path.extname(file).toLowerCase())) changedSet.add(file);
  }

  if (!staged) {
    const untracked = git(["ls-files", "--others", "--exclude-standard", "-z"], {
      cwd: root,
      trim: false,
    });
    for (const file of nulSeparated(untracked)) {
      if (SUPPORTED_EXTENSIONS.has(path.extname(file).toLowerCase())) changedSet.add(file);
    }
  }

  const diffs = [];
  for (const file of [...changedSet].sort()) {
    const baseSrc = gitShowOptional(root, `${targetBase}:${file}`) ?? "";
    let headSrc = "";
    if (staged) {
      headSrc = gitShowOptional(root, `:${file}`) ?? "";
    } else {
      const abs = path.join(root, file);
      try {
        const st = lstatSync(abs);
        if (st.isFile()) headSrc = readFileSync(abs, "utf8");
      } catch (error) {
        if (error.code !== "ENOENT") throw error;
      }
    }
    const baseTokens = lexByExtension(file, baseSrc);
    const headTokens = lexByExtension(file, headSrc);
    const compared = diffTokenStreams(baseTokens, headTokens);
    if (compared.changed) {
      diffs.push({ file, ...compared });
    }
  }

  return { base: targetBase, staged, diffs };
}

export function parseTokenDiffArgs(argv) {
  const opts = { base: null, staged: false, root: defaultRoot };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--staged") {
      opts.staged = true;
    } else if (arg === "--base") {
      if (i + 1 >= argv.length || !argv[i + 1] || argv[i + 1].startsWith("-")) {
        throw new Error("--base requires a ref");
      }
      opts.base = argv[++i];
    } else if (arg === "--root") {
      if (i + 1 >= argv.length || !argv[i + 1] || argv[i + 1].startsWith("-")) {
        throw new Error("--root requires a directory");
      }
      opts.root = path.resolve(argv[++i]);
    } else if (arg.startsWith("-")) {
      throw new Error(`unknown argument: ${arg}`);
    } else if (opts.base === null) {
      opts.base = arg;
    } else {
      throw new Error(`unexpected argument: ${arg}`);
    }
  }
  return opts;
}

function formatToken(tok) {
  return tok ? `${tok.kind}(${JSON.stringify(tok.value)})` : "<EOF>";
}

if (isMain(import.meta.url)) {
  try {
    const opts = parseTokenDiffArgs(process.argv.slice(2));
    const result = runTokenDiff(opts);
    if (result.diffs.length === 0) {
      console.log(
        `token-diff: identical (${result.base} vs ${opts.staged ? "staged" : "working"})`,
      );
      process.exitCode = 0;
    } else {
      for (const diff of result.diffs) {
        console.log(
          `${diff.file}:${diff.baseLine}:${diff.headLine} ${formatToken(diff.baseToken)} -> ${formatToken(diff.headToken)}`,
        );
      }
      process.exitCode = 1;
    }
  } catch (error) {
    console.error(`token-diff: ${error.message}`);
    process.exitCode = 2;
  }
}
