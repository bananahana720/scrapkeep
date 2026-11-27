import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import {
  acquireSlotLock,
  applyDevOverlay,
  assertNotPrimaryCheckout,
  assertUnderSandboxRoot,
  LOCK_FILENAME,
  patchGameGd,
  patchIntentGd,
  patchWorkshopGd,
  releaseSlotLock,
  REPO_ROOT,
  resolveGitRef,
  validateSlotName,
} from "./worktree-sandbox.mjs";

describe("worktree-sandbox structural safety", () => {
  it("refuses to mutate the primary checkout or any checkout owning .agents/hooks.json", () => {
    assert.throws(
      () => assertNotPrimaryCheckout(REPO_ROOT, REPO_ROOT),
      (err) => err.code === "PRIMARY_CHECKOUT_PROTECTED",
    );

    const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-hooks-guard-"));
    try {
      mkdirSync(path.join(tmp, ".agents"), { recursive: true });
      writeFileSync(path.join(tmp, ".agents", "hooks.json"), "{}\n", "utf8");
      assert.throws(
        () => assertNotPrimaryCheckout(tmp, REPO_ROOT),
        (err) => err.code === "PRIMARY_CHECKOUT_PROTECTED",
      );
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("refuses sandbox paths escaping artifacts/local/dev-ref/", () => {
    for (const bad of [
      "/tmp/escape",
      path.join(REPO_ROOT, "artifacts", "local"),
      path.join(REPO_ROOT, "artifacts", "local", "dev-ref"),
      path.join(REPO_ROOT, "artifacts", "local", "dev-ref", "..", "other"),
    ]) {
      assert.throws(
        () => assertUnderSandboxRoot(bad, REPO_ROOT),
        (err) => err.code === "SANDBOX_PATH_ESCAPE",
      );
    }
    const okPath = path.join(REPO_ROOT, "artifacts", "local", "dev-ref", "deadbeef0123-s0");
    assert.equal(assertUnderSandboxRoot(okPath, REPO_ROOT), okPath);
  });

  it("rejects unsafe slot names", () => {
    for (const bad of ["", ".", "..", "../escape", "slot/sub", "slot space"]) {
      assert.throws(() => validateSlotName(bad), /Invalid sandbox slot/);
    }
    assert.equal(validateSlotName("s0"), "s0");
    assert.equal(validateSlotName("qa_worker-1"), "qa_worker-1");
  });
});

describe("worktree-sandbox idempotent locking and crash reconciliation", () => {
  it("acquires a slot exclusively, blocks concurrent live owners, and reconciles stale dead-PID locks", () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-slot-lock-"));
    try {
      const slotDir = path.join(tmp, "abc123456789-s0");
      const first = acquireSlotLock(slotDir, { sha: "abc" }, { pid: 1001, isAlive: () => true });
      assert.equal(first.acquired, true);
      assert.equal(first.staleCleaned, false);
      assert.ok(existsSync(path.join(slotDir, LOCK_FILENAME)));

      const blocked = acquireSlotLock(slotDir, { sha: "abc" }, { pid: 2002, isAlive: () => true });
      assert.equal(blocked.acquired, false);
      assert.equal(blocked.busyPid, 1001);

      const recovered = acquireSlotLock(
        slotDir,
        { sha: "abc" },
        { pid: 2002, isAlive: () => false },
      );
      assert.equal(recovered.acquired, true);
      assert.equal(recovered.staleCleaned, true);

      recovered.transferTo(3003, { session: "qa" });
      const lockDoc = JSON.parse(readFileSync(path.join(slotDir, LOCK_FILENAME), "utf8"));
      assert.equal(lockDoc.pid, 3003);
      assert.equal(lockDoc.session, "qa");

      assert.equal(releaseSlotLock(slotDir, { expectedPid: 3003 }), true);
      assert.ok(!existsSync(path.join(slotDir, LOCK_FILENAME)));
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe("worktree-sandbox idempotent console seam overlay", () => {
  it("patches pre-dev game.gd, intent.gd, and workshop.gd cleanly and converges on rerun", () => {
    const preDevGame = [
      "var keyboard",
      "var codex",
      "func _ready() -> void:",
      "\tauto_pause.setup(self)",
      "\tif test_mode:",
      "\t\tmenu_modules()",
      "func _apply_pause() -> void:",
      "\tget_tree().paused = _pause_toggled or _notes_held",
      "func capture_mouse(capture: bool) -> void:",
      "\tInput.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE",
      "func menu_held() -> bool:",
      '\treturn get_meta("menu_held", false)',
    ].join("\n");

    const g1 = patchGameGd(preDevGame);
    assert.equal(g1.changed, true);
    assert.match(g1.text, /var _dev_held := false/);
    assert.match(g1.text, /dev_console\.gd"\)\.hook\(self\)/);
    assert.match(g1.text, /func freeze_for_dev\(on: bool\)/);
    assert.match(g1.text, /capture and not _dev_held/);
    assert.match(g1.text, /return _dev_held or get_meta/);

    const g2 = patchGameGd(g1.text);
    assert.equal(g2.changed, false);
    assert.equal(g2.text, g1.text);

    const preDevIntent = [
      "class Keyboard:",
      "\textends Source",
      "\tvar enabled := true",
      "\tvar walk := false",
      "\tfunc poll(out) -> void:",
      "\t\tout.clear()",
      "\t\tif not enabled:",
      "\t\t\treturn",
    ].join("\n");

    const i1 = patchIntentGd(preDevIntent);
    assert.equal(i1.changed, true);
    assert.match(i1.text, /\tvar held := false/);
    assert.match(i1.text, /if not enabled or held:/);
    assert.equal(patchIntentGd(i1.text).changed, false);

    const preDevWorkshop = [
      "func card_holds_only() -> bool:",
      "\treturn _start_pointer_held",
      "",
      "func _apply_hold() -> void:",
      "\tpass",
    ].join("\n");

    const w1 = patchWorkshopGd(preDevWorkshop);
    assert.equal(w1.changed, true);
    assert.match(w1.text, /func pausing\(\) -> bool:\n\treturn _paused/);
    assert.equal(patchWorkshopGd(w1.text).changed, false);
  });

  it("overlays src/dev and patches seams idempotently inside a sandbox directory", () => {
    const base = path.join(REPO_ROOT, "artifacts", "local", "dev-ref");
    mkdirSync(base, { recursive: true });
    const fakeSandbox = mkdtempSync(path.join(base, "unit-overlay-"));
    try {
      const srcDir = path.join(fakeSandbox, "sketches", "core-loop", "src");
      mkdirSync(path.join(srcDir, "movement"), { recursive: true });
      mkdirSync(path.join(srcDir, "ui"), { recursive: true });
      writeFileSync(
        path.join(srcDir, "game.gd"),
        [
          "var keyboard",
          "func _ready() -> void:",
          "\tauto_pause.setup(self)",
          "func _apply_pause() -> void:",
          "\tget_tree().paused = _pause_toggled or _notes_held",
          "func capture_mouse(capture: bool) -> void:",
          "\tInput.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE",
          "func menu_held() -> bool:",
          '\treturn get_meta("menu_held", false)',
        ].join("\n"),
        "utf8",
      );
      writeFileSync(
        path.join(srcDir, "movement", "intent.gd"),
        "class Keyboard:\n\tvar enabled := true\n\tfunc poll(out) -> void:\n\t\tif not enabled:\n\t\t\treturn\n",
        "utf8",
      );
      writeFileSync(
        path.join(srcDir, "ui", "workshop.gd"),
        "var _paused := false\nfunc _apply_hold() -> void:\n\tpass\n",
        "utf8",
      );

      const first = applyDevOverlay(fakeSandbox, { sourceRoot: REPO_ROOT, sha: "deadbeef" });
      assert.equal(first.applied, true);
      assert.ok(first.filesCopied > 5);
      assert.equal(first.seamsPatched.length, 3);
      assert.ok(existsSync(path.join(srcDir, "dev", "dev_console.gd")));
      assert.ok(existsSync(path.join(srcDir, "dev", "dev_inspect.gd")));

      const second = applyDevOverlay(fakeSandbox, { sourceRoot: REPO_ROOT, sha: "deadbeef" });
      assert.equal(second.applied, false);
      assert.equal(second.cached, true);
    } finally {
      rmSync(fakeSandbox, { recursive: true, force: true });
    }
  });

  it("resolves HEAD commit SHA cleanly and rejects nonexistent refs", () => {
    const resolved = resolveGitRef("HEAD", REPO_ROOT);
    assert.match(resolved.sha, /^[0-9a-f]{40}$/);
    assert.equal(resolved.sha12, resolved.sha.slice(0, 12));
    assert.throws(
      () => resolveGitRef("refs/heads/does-not-exist-xyz", REPO_ROOT),
      /Could not resolve/,
    );
  });
});
