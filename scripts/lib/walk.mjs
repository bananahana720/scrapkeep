import { existsSync, readdirSync } from "node:fs";
import { access, readdir } from "node:fs/promises";
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
  return [...entries].sort((a, b) => a.name.localeCompare(b.name));
}

export function walkSync(
  directory,
  { includeDirs = false, filesOnly = false, sort = false, prune = null, filter = null } = {},
) {
  const out = [];
  if (!existsSync(directory)) return out;
  const visit = (dir, prefix) => {
    const entries = sortEntries(readdirSync(dir, { withFileTypes: true }), sort);
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
      const isDir = entry.isDirectory();
      const isFile = entry.isFile();
      const item = { name: entry.name, rel, full, dir: isDir, file: isFile };
      if (isDir) {
        if (prune && prune(item)) continue;
        if (includeDirs && (!filter || filter(item))) out.push(item);
        visit(full, rel);
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
  { includeDirs = false, filesOnly = false, sort = false, prune = null, filter = null } = {},
) {
  const out = [];
  if (!(await existsAsync(directory))) return out;
  const visit = async (dir, prefix) => {
    const entries = sortEntries(await readdir(dir, { withFileTypes: true }), sort);
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
      const isDir = entry.isDirectory();
      const isFile = entry.isFile();
      const item = { name: entry.name, rel, full, dir: isDir, file: isFile };
      if (isDir) {
        if (prune && prune(item)) continue;
        if (includeDirs && (!filter || filter(item))) out.push(item);
        await visit(full, rel);
      } else {
        if (filesOnly && !isFile) continue;
        if (!filter || filter(item)) out.push(item);
      }
    }
  };
  await visit(directory, "");
  return out;
}
