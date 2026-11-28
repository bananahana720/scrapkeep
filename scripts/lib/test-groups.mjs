import { readFileSync } from "node:fs";

export function groupId(value) {
  const text = typeof value === "number" ? String(value) : value;
  if (typeof text !== "string" || !/^\d+$/.test(text)) return null;
  const id = Number(text);
  return Number.isSafeInteger(id) && id > 1 ? id : null;
}

function linesIn(file) {
  let text;
  try {
    text = readFileSync(file, "utf8");
  } catch {
    return [];
  }
  return text.split("\n").slice(0, -1);
}

export function testGroups(t, { from = null, kill = process.kill.bind(process) } = {}) {
  const live = new Set();
  const gone = new Set();
  const note = (message) => {
    try {
      t.diagnostic(message);
    } catch {}
  };
  const add = (value) => {
    const id = groupId(value);
    if (id !== null && !gone.has(id)) live.add(id);
    return id;
  };
  const known = () => {
    if (from !== null) for (const line of linesIn(from)) add(line);
    return [...live];
  };
  const signal = (id, sig) => {
    try {
      kill(-id, sig);
      return true;
    } catch (error) {
      if (error?.code !== "ESRCH" && error?.code !== "EPERM")
        note(`could not signal group ${id}: ${error?.message ?? error}`);
      return false;
    }
  };
  const groups = {
    add,
    gone(value) {
      const id = groupId(value);
      if (id === null) return;
      live.delete(id);
      gone.add(id);
    },
    sweep() {
      for (const id of known()) if (!signal(id, 0)) groups.gone(id);
    },
    reap() {
      for (const id of known()) {
        signal(id, "SIGKILL");
        groups.gone(id);
      }
    },
  };
  t.after(() => groups.reap());
  return groups;
}
