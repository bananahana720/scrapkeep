import assert from "node:assert/strict";
import test from "node:test";
import { bootFailures, missingStems } from "./sketch-export.mjs";

const manifest = {
  stems: ["drums", "bass"],
  clips: {
    calm: { files: { drums: "calm.drums.ogg", bass: "calm.bass.ogg" } },
    open: { files: { drums: "open.drums.ogg", bass: "open.bass.ogg" } },
  },
};

test("a manifest whose stems all exist reports none missing", () => {
  assert.deepEqual(missingStems(manifest, "/d", () => true), []);
});

test("a stem file the manifest names but the folder lacks is reported", () => {
  const present = new Set(["/d/calm.drums.ogg", "/d/calm.bass.ogg", "/d/open.drums.ogg"]);
  assert.deepEqual(missingStems(manifest, "/d", (file) => present.has(file)), ["open.bass.ogg"]);
});

test("a clip with no file named for a stem is reported", () => {
  const broken = { stems: ["drums"], clips: { calm: { files: {} } } };
  assert.equal(missingStems(broken, "/d", () => true).length, 1);
});

test("boot output passes only with a ready ACE_CHECK and no error line", () => {
  assert.deepEqual(bootFailures("ACE_CHECK ready=true clips=9 streams=27 missing=\n"), []);
  assert.equal(bootFailures("SCRIPT ERROR: x\nACE_CHECK ready=true clips=9 streams=27").length, 1);
  assert.equal(bootFailures("ACE_CHECK ready=false clips=0 streams=0 missing=/x").length, 1);
  assert.equal(bootFailures("nothing").length, 1);
});
