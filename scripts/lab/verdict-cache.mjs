// The jev arm's verdict cache (plan section 2, "Arms"). One file per key,
// <directory>/<key>.json, where the key is protocol.mjs's verdictKey(): the
// sha256 of {protocol, questions_sha, model, confidence_floor, gate_version,
// state, options}. A verdict is therefore reused only for the same wording,
// model alias, floor, gate and snapshot. Files are written tmp-then-rename, so
// concurrent batches sharing a directory never read half an entry, and a
// second write of the same key leaves the same answer.
import { mkdir, readFile } from "node:fs/promises";
import path from "node:path";

import { writeAtomic } from "../../tools/jev-player/protocol/protocol.mjs";

export const VERDICT_CACHE_ROOT = path.resolve(
  import.meta.dirname,
  "../../artifacts/local/jev-cache",
);

const KEY = /^[0-9a-f]{64}$/;

export function openVerdictCache(directory = VERDICT_CACHE_ROOT) {
  const fileOf = (key) => {
    if (!KEY.test(key)) {
      throw new Error(`verdict cache key "${key}" is not a sha256`);
    }
    return path.join(directory, `${key}.json`);
  };
  return {
    directory,
    async get(key) {
      const file = fileOf(key);
      let text;
      try {
        text = await readFile(file, "utf8");
      } catch (error) {
        if (error.code === "ENOENT") return null;
        throw error;
      }
      const entry = JSON.parse(text);
      if (entry?.key !== key) {
        throw new Error(`${file} is filed under another key`);
      }
      return entry;
    },
    async put(key, entry) {
      const file = fileOf(key);
      await mkdir(directory, { recursive: true });
      await writeAtomic(file, { key, ...entry });
    },
  };
}

// The key names the model alias, but the entry stores the model that answered.
// In a live batch the preflight's resolved model is the anchor: a hit from any
// other model (or none recorded) reads as a miss, so the arm asks again, and
// anchor.mismatches counts it for the run record. A replay is not wrapped; the
// harness checks its verdicts against each other instead.
export function anchoredCache(cache, anchor) {
  return {
    directory: cache.directory,
    put: (key, entry) => cache.put(key, entry),
    async get(key) {
      const entry = await cache.get(key);
      if (entry === null || (entry.verdict?.model ?? null) === anchor.model) {
        return entry;
      }
      anchor.mismatches += 1;
      return null;
    },
  };
}
