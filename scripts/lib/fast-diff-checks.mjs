import path from "node:path";

export function checkLabels(source) {
  const labels = new Set();
  for (const raw of source.split("\n")) {
    const line = raw.replace(/^\s*#.*$/, "");
    for (const m of line.matchAll(
      /(?<![\w])(?:\w+\.)?_?(?:check|eq|near|report)\w*\(\s*"((?:[^"\\]|\\.)*)"/g,
    ))
      labels.add(m[1]);
  }
  return labels;
}

export function removedChecks(baseSource, headSource) {
  const head = checkLabels(headSource);
  return [...checkLabels(baseSource)].filter((label) => !head.has(label)).sort();
}

export function checksRemoved(nameStatusLines, show, baseRef, headRef) {
  const isTest = (file) => /^sketches\/core-loop\/tests\/(?:[^/]+\/)?[^/]+\.gd$/.test(file);
  return nameStatusLines
    .filter(Boolean)
    .map((line) => {
      const [status, from, to = from] = line.split("\t");
      if (status.startsWith("A") || !isTest(from)) return null;
      const before = show(baseRef, from);
      const after = status.startsWith("D") ? "" : (show(headRef, to) ?? "");
      return before === null
        ? null
        : { test: path.posix.basename(to), labels: removedChecks(before, after) };
    })
    .filter((row) => row && row.labels.length > 0);
}

export const ROOT_FILES_ALLOWED = new Set([".mcp.json", "GEMINI.md"]);
export const SKILL_LINK = /^\.claude\/skills\/[a-z0-9-]+$/;

export function hygieneFindings(rawLines, baseTopLevel) {
  const findings = [];
  for (const line of rawLines) {
    const match = /^:(\d+) (\d+) \S+ \S+ A\t(.+)$/.exec(line);
    if (!match) continue;
    const [, , mode, file] = match;
    if (mode === "120000" && SKILL_LINK.test(file)) continue;
    else if (mode === "120000") findings.push(`symlink added: ${file}`);
    else if (ROOT_FILES_ALLOWED.has(file)) continue;
    else if (!file.includes("/")) findings.push(`root file added: ${file}`);
    else if (!baseTopLevel.has(file.split("/")[0])) findings.push(`new top-level folder: ${file}`);
  }
  return findings;
}

export function bridgeFindings(projectGodot) {
  return /McpBridge/.test(projectGodot)
    ? ["project.godot carries the Godot MCP's McpBridge autoload: call stop_project, then commit"]
    : [];
}

export function mergedBranch(subject) {
  return (
    /\bfrom [\w.-]+\/([\w./-]+)$/.exec(subject)?.[1] ??
    /(?:remote-tracking branch '|branch ')(?:origin\/)?([\w./-]+)'/.exec(subject)?.[1] ??
    null
  );
}

export function carriedPrs(merges, { prHeads = new Map(), branchHeads = new Map() }, isAncestor) {
  const prsAt = (sha) => [...prHeads].filter(([, head]) => head === sha).map(([pr]) => pr);
  return merges.map(({ merge, carried, subject }) => {
    const exact = prsAt(carried);
    if (exact.length > 0) return { merge, carried, prs: exact, stale: false };
    const named = /#(\d+)/.exec(subject)?.[1];
    const branch = mergedBranch(subject);
    const head =
      named && prHeads.has(named)
        ? prHeads.get(named)
        : branch && branchHeads.has(branch)
          ? branchHeads.get(branch)
          : null;
    if (!head) return { merge, carried, prs: [], branch, stale: false, subject };
    const prs = named && prHeads.has(named) ? [named] : prsAt(head);
    return { merge, carried, prs, branch, stale: head !== carried && !isAncestor(head), head };
  });
}

export function placeholderIncrease(baseRows, headRows) {
  const key = (row) => `${row.kind} ${row.where}`;
  const total = (rows) => {
    const map = new Map();
    for (const row of rows) map.set(key(row), (map.get(key(row)) ?? 0) + (row.count ?? 1));
    return map;
  };
  const base = total(baseRows);
  const grew = [];
  for (const [group, count] of total(headRows))
    if (count > (base.get(group) ?? 0)) grew.push(`${group}: ${base.get(group) ?? 0} -> ${count}`);
  return grew;
}
