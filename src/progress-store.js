import { createProfile, parseProfile, settleRun, masteryFor } from "./campaign.js";

export function createProgressStore(storage, key) {
  if (typeof key !== "string" || !key || key.length > 200) {
    throw new TypeError("A progress storage key is required.");
  }
  const prefix = `${key}.run.`;
  const receipts = new Map();
  const pending = new Map();
  let memory = null;

  function receipt(raw, expectedId) {
    try {
      const value = typeof raw === "string" ? JSON.parse(raw) : raw;
      if (!value || (expectedId !== undefined && value.id !== expectedId)) return null;
      const run = Object.fromEntries(
        ["id", "classId", "seed", "score", "survived", "outcome"].map((field) => [
          field,
          value[field],
        ]),
      );
      const result = settleRun(createProfile(), run);
      return result.mastery && result.profile.settled.includes(run.id) ? run : null;
    } catch {
      return null;
    }
  }

  function read(fallbackProfile) {
    let base = parseProfile(memory || fallbackProfile);
    let storageAvailable = true;
    try {
      const raw = storage.getItem(key);
      if (raw !== null) {
        try {
          const parsed = JSON.parse(raw);
          if (parsed?.version === 1 && parsed.classes && typeof parsed.classes === "object")
            base = parseProfile(parsed);
        } catch {}
      }
      const keys = [];
      for (let i = 0; i < storage.length; i++) {
        const name = storage.key(i);
        if (typeof name === "string" && name.startsWith(prefix)) keys.push(name);
      }
      for (const name of keys) {
        const id = name.slice(prefix.length);
        if (!/^[a-zA-Z0-9_-]{1,100}$/.test(id)) continue;
        const run = receipt(storage.getItem(name), id);
        if (run) receipts.set(run.id, run);
      }
    } catch {
      storageAvailable = false;
      base = parseProfile(memory || fallbackProfile);
    }
    for (const run of receipts.values()) base = settleRun(base, run).profile;
    memory = base;
    return {
      profile: parseProfile(memory),
      storageAvailable: storageAvailable && pending.size === 0,
    };
  }

  function record(value, fallbackProfile) {
    const current = read(fallbackProfile);
    const run = receipt(value);
    if (!run) return { ...current, awarded: 0, mastery: null, unlocks: [] };
    const result = settleRun(current.profile, run);
    if (!current.profile.settled.includes(run.id)) receipts.set(run.id, run);
    pending.set(run.id, receipts.get(run.id) || run);
    let storageAvailable = true;
    for (const [id, queued] of pending) {
      try {
        const name = `${prefix}${id}`;
        const existing = receipt(storage.getItem(name), id);
        if (!existing) storage.setItem(name, JSON.stringify(queued));
        pending.delete(id);
      } catch {
        storageAvailable = false;
      }
    }
    memory = result.profile;
    const refreshed = read(memory);
    return {
      ...result,
      profile: refreshed.profile,
      mastery: masteryFor(refreshed.profile, run.classId),
      storageAvailable: storageAvailable && refreshed.storageAvailable,
    };
  }

  return { read, record };
}
