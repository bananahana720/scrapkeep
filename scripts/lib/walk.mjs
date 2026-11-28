import { existsSync, readdirSync, statSync } from "node:fs";
import { access, readdir, stat } from "node:fs/promises";
import path from "node:path";

async function existsAsync(file) {
  try {
    await access(file);
    return true;
  } catch {
    return false;
  }
}

function sortEntries(entries, sort) {
  if (!sort) return entries;
  return [...entries].sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
}

function dirKey(st) {
  return st ? `${st.dev}:${st.ino}` : null;
}

export function walkSync(
  directory,
  {
    includeDirs = false,
    filesOnly = false,
    sort = false,
    followSymlinks = false,
    prune = null,
    filter = null,
  } = {},
) {
  const out = [];
  if (!existsSync(directory)) return out;
  const ancestors = new Set();
  const rootKey = followSymlinks ? dirKey(statSync(directory, { throwIfNoEntry: false })) : null;
  if (rootKey) ancestors.add(rootKey);
  const visit = (dir, prefix) => {
    const entries = sortEntries(readdirSync(dir, { withFileTypes: true }), sort);
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
      let isDir = entry.isDirectory();
      let isFile = entry.isFile();
      let linkKey = null;
      if (followSymlinks && entry.isSymbolicLink()) {
        const st = statSync(full, { throwIfNoEntry: false });
        if (st) {
          isDir = st.isDirectory();
          isFile = st.isFile();
          if (isDir) linkKey = dirKey(st);
        }
      }
      const item = { name: entry.name, rel, full, dir: isDir, file: isFile };
      if (isDir) {
        if (prune && prune(item)) continue;
        if (linkKey && ancestors.has(linkKey)) continue;
        if (includeDirs && (!filter || filter(item))) out.push(item);
        if (linkKey) ancestors.add(linkKey);
        visit(full, rel);
        if (linkKey) ancestors.delete(linkKey);
      } else {
        if (filesOnly && !isFile) continue;
        if (!filter || filter(item)) out.push(item);
      }
    }
  };
  visit(directory, "");
  return out;
}

export async function walkAsync(
  directory,
  {
    includeDirs = false,
    filesOnly = false,
    sort = false,
    followSymlinks = false,
    prune = null,
    filter = null,
  } = {},
) {
  const out = [];
  if (!(await existsAsync(directory))) return out;
  const ancestors = new Set();
  const rootKey = followSymlinks ? dirKey(await stat(directory).catch(() => null)) : null;
  if (rootKey) ancestors.add(rootKey);
  const visit = async (dir, prefix) => {
    const entries = sortEntries(await readdir(dir, { withFileTypes: true }), sort);
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
      let isDir = entry.isDirectory();
      let isFile = entry.isFile();
      let linkKey = null;
      if (followSymlinks && entry.isSymbolicLink()) {
        const st = await stat(full).catch(() => null);
        if (st) {
          isDir = st.isDirectory();
          isFile = st.isFile();
          if (isDir) linkKey = dirKey(st);
        }
      }
      const item = { name: entry.name, rel, full, dir: isDir, file: isFile };
      if (isDir) {
        if (prune && prune(item)) continue;
        if (linkKey && ancestors.has(linkKey)) continue;
        if (includeDirs && (!filter || filter(item))) out.push(item);
        if (linkKey) ancestors.add(linkKey);
        await visit(full, rel);
        if (linkKey) ancestors.delete(linkKey);
      } else {
        if (filesOnly && !isFile) continue;
        if (!filter || filter(item)) out.push(item);
      }
    }
  };
  await visit(directory, "");
  return out;
}
