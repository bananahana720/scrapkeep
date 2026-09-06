import test from "node:test";
import assert from "node:assert/strict";
import { createProgressStore } from "../src/progress-store.js";
import { createProfile, serializeProfile } from "../src/campaign.js";

function storage() {
  const values = new Map();
  return {
    get length() {
      return values.size;
    },
    key(index) {
      return [...values.keys()][index] ?? null;
    },
    getItem(key) {
      return values.get(key) ?? null;
    },
    setItem(key, value) {
      values.set(key, String(value));
    },
  };
}
const run = (id, overrides = {}) => ({
  id,
  classId: "scavenger",
  seed: 745,
  score: 3000,
  survived: 5,
  outcome: "gameover",
  ...overrides,
});

test("stale tabs retain both run receipts despite interleaved aggregate overwrites", () => {
  const shared = storage();
  const a = createProgressStore(shared, "progress");
  const b = createProgressStore(shared, "progress");
  const staleA = a.read().profile,
    staleB = b.read().profile;
  const first = a.record(run("first"), staleA);
  shared.setItem("progress", serializeProfile(staleB));
  const second = b.record(run("second"), staleB);
  shared.setItem("progress", serializeProfile(first.profile));
  assert.equal(second.profile.classes.scavenger.xp, 100);
  const reopened = createProgressStore(shared, "progress").read();
  assert.equal(reopened.profile.classes.scavenger.xp, 100);
  assert.equal(reopened.profile.classes.scavenger.runs, 2);
  assert.deepEqual(
    new Set(reopened.profile.settled),
    new Set(["first", "second"]),
  );
  assert.equal(reopened.storageAvailable, true);
  assert.ok(shared.getItem("progress.run.first"));
  assert.ok(shared.getItem("progress.run.second"));
});

test("record never overwrites the aggregate and replay never awards duplicate XP", () => {
  const shared = storage();
  const legacy = createProfile();
  legacy.classes.scavenger.xp = 20;
  const raw = serializeProfile(legacy);
  shared.setItem("progress", raw);
  const a = createProgressStore(shared, "progress");
  assert.equal(a.record(run("one")).awarded, 50);
  assert.equal(shared.getItem("progress"), raw);
  const b = createProgressStore(shared, "progress");
  const duplicate = b.record(run("one"));
  assert.equal(duplicate.awarded, 0);
  assert.equal(duplicate.profile.classes.scavenger.xp, 70);
  assert.equal(b.read().profile.classes.scavenger.runs, 1);
});

test("malformed and mismatched receipts cannot add XP or select arbitrary storage keys", () => {
  const shared = storage();
  shared.setItem("progress.run.bad", "{broken");
  shared.setItem("progress.run.wrong", JSON.stringify(run("other")));
  shared.setItem("progress.run.../unsafe", JSON.stringify(run("../unsafe")));
  shared.setItem(
    "progress.run.constructor",
    JSON.stringify(run("constructor", { classId: "constructor" })),
  );
  shared.setItem("another.run.good", JSON.stringify(run("good")));
  const store = createProgressStore(shared, "progress");
  assert.equal(store.read().profile.classes.scavenger.xp, 0);
  assert.equal(store.record(run("../unsafe")).awarded, 0);
  assert.equal(
    shared.getItem("progress.run.../unsafe"),
    JSON.stringify(run("../unsafe")),
  );
  assert.equal(store.record(run("valid")).awarded, 50);
});

test("denied storage retains fallback and subsequent progress in memory", () => {
  const denied = {
    getItem() {
      throw new Error("Denied");
    },
    setItem() {
      throw new Error("Denied");
    },
  };
  const fallback = createProfile();
  fallback.classes.scavenger.xp = 25;
  const store = createProgressStore(denied, "progress");
  const first = store.record(run("offline"), fallback);
  assert.equal(first.storageAvailable, false);
  assert.equal(first.profile.classes.scavenger.xp, 75);
  assert.equal(store.record(run("offline")).awarded, 0);
  const second = store.record(run("offline-two"));
  assert.equal(second.profile.classes.scavenger.xp, 125);
  assert.equal(store.read().profile.classes.scavenger.runs, 2);
});

test("write denial preserves receipts locally and a retry can persist them", () => {
  const shared = storage();
  const set = shared.setItem;
  let denied = true;
  shared.setItem = (key, value) => {
    if (denied) throw new Error("Quota");
    set(key, value);
  };
  const store = createProgressStore(shared, "progress");
  const result = store.record(run("retry"));
  assert.equal(result.storageAvailable, false);
  assert.equal(result.profile.classes.scavenger.xp, 50);
  denied = false;
  const retry = store.record(run("retry"));
  assert.equal(retry.awarded, 0);
  assert.equal(retry.storageAvailable, true);
  assert.equal(
    createProgressStore(shared, "progress").read().profile.classes.scavenger.xp,
    50,
  );
});

test("a later successful record flushes every earlier unsaved receipt", () => {
  const shared = storage();
  const set = shared.setItem;
  let denied = true;
  shared.setItem = (key, value) => {
    if (denied) throw new Error("Quota");
    set(key, value);
  };
  const store = createProgressStore(shared, "progress");
  store.record(run("queued-one"));
  store.record(run("queued-two"));
  assert.equal(store.read().storageAvailable, false);
  denied = false;
  assert.equal(store.record(run("online")).storageAvailable, true);
  const reloaded = createProgressStore(shared, "progress").read();
  assert.equal(reloaded.profile.classes.scavenger.xp, 150);
  assert.equal(reloaded.profile.classes.scavenger.runs, 3);
});
