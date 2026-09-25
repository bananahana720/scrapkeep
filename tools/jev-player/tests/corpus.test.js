// Offline checks on the authored corpus. Option wording may be corrected; the
// labels, states and everything else are pinned to their pre-JL-03 digest.
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = JSON.parse(
  readFileSync(path.join(here, "..", "corpus.json"), "utf8"),
);
const all = [...corpus.cases, ...corpus.adversarial];
const ROLLING = "already rolling over it";

test("everything but option wording matches the pre-JL-03 corpus", () => {
  const strip = (c) => ({
    ...c,
    options: c.options.map((o) => ({ ...o, why: null })),
  });
  const stripped = {
    ...corpus,
    cases: corpus.cases.map(strip),
    adversarial: corpus.adversarial.map(strip),
  };
  const digest = createHash("sha256")
    .update(JSON.stringify(stripped))
    .digest("hex");
  assert.equal(
    digest,
    "e0e1cd1462976b823653cf55fdaa7b33e1c7e1c90c3ee17ce61bd492b9cf2f5e",
  );
});

test("a cache the option places away from the player is not also under it", () => {
  const away = /\d+ m\b|\bahead\b|\babove\b/;
  const offenders = [];
  for (const c of all) {
    for (const o of c.options) {
      if (
        o.id === "take_cache" &&
        away.test(o.why) &&
        o.why.includes(ROLLING)
      ) {
        offenders.push(c.id);
      }
    }
  }
  assert.deepEqual(offenders, []);
  const chaser = all.find((c) => c.id === "low-hp-chaser");
  const cache = chaser.options.find((o) => o.id === "take_cache");
  assert.ok(!cache.why.includes(ROLLING));
});
