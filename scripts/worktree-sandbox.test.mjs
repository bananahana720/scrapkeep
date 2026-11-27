import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import { godotIdentity } from "./import-stamp.mjs";
import {
  acquireSlotLock,
  applyDevOverlay,
  assertNotPrimaryCheckout,
  assertUnderSandboxRoot,
  ensureSandboxImport,
  IMPORT_STAMP_FILENAME,
  patchGameGd,
  patchIntentGd,
  patchWorkshopGd,
  releaseSlotLock,
  REPO_ROOT,
  resolveGitRef,
  slotLockPath,
  unimportedAssets,
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
  it("acquires a sibling lock outside slotDir, blocks concurrent live owners, and reconciles stale dead-PID locks", () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-slot-lock-"));
    try {
      const slotDir = path.join(tmp, "abc123456789-s0");
      const lockFile = slotLockPath(slotDir);
      assert.equal(lockFile, `${slotDir}.lock.json`);

      const first = acquireSlotLock(slotDir, { sha: "abc" }, { pid: 1001, isAlive: () => true });
      assert.equal(first.acquired, true);
      assert.equal(first.staleCleaned, false);
      assert.equal(first.lockPath, lockFile);
      assert.ok(existsSync(lockFile));
      assert.ok(!existsSync(slotDir), "cold slot lock must not pre-create slotDir");

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
      const lockDoc = JSON.parse(readFileSync(lockFile, "utf8"));
      assert.equal(lockDoc.pid, 3003);
      assert.equal(lockDoc.session, "qa");

      assert.equal(releaseSlotLock(slotDir, { expectedPid: 3003 }), true);
      assert.ok(!existsSync(lockFile));
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("keeps sibling lock intact across cold slot creation and destructive reconciliation without TOCTOU window", () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-cold-slot-race-"));
    try {
      const slotDir = path.join(tmp, "deadbeef0123-s0");
      const lockFile = slotLockPath(slotDir);
      const ownerA = acquireSlotLock(
        slotDir,
        { sha: "deadbeef0123" },
        { pid: 4100, isAlive: () => true },
      );
      assert.equal(ownerA.acquired, true);

      mkdirSync(slotDir, { recursive: true });
      writeFileSync(path.join(slotDir, "partial.tmp"), "corrupt", "utf8");
      rmSync(slotDir, { recursive: true, force: true });

      assert.ok(
        existsSync(lockFile),
        "sibling lock must survive slotDir removal during reconciliation",
      );
      const rivalB = acquireSlotLock(
        slotDir,
        { sha: "deadbeef0123" },
        { pid: 4200, isAlive: () => true },
      );
      assert.equal(rivalB.acquired, false);
      assert.equal(rivalB.busyPid, 4100);

      const fallbackSlotDir = path.join(tmp, "deadbeef0123-s1");
      const rivalFallback = acquireSlotLock(
        fallbackSlotDir,
        { sha: "deadbeef0123" },
        { pid: 4200, isAlive: () => true },
      );
      assert.equal(rivalFallback.acquired, true);

      ownerA.release();
      rivalFallback.release();
      assert.ok(!existsSync(lockFile));
      assert.ok(!existsSync(slotLockPath(fallbackSlotDir)));
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

      const altSource = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-alt-source-"));
      try {
        const altDev = path.join(altSource, "sketches", "core-loop", "src", "dev");
        mkdirSync(altDev, { recursive: true });
        writeFileSync(path.join(altDev, "dev_console.gd"), "extends CanvasLayer\n", "utf8");
        writeFileSync(
          path.join(altDev, "dev_inspect.gd"),
          "extends Node\nfunc greybox(): pass\nfunc sample_perf(): pass\n",
          "utf8",
        );
        const third = applyDevOverlay(fakeSandbox, { sourceRoot: altSource, sha: "deadbeef" });
        assert.equal(third.applied, true);
        const fourth = applyDevOverlay(fakeSandbox, { sourceRoot: altSource, sha: "deadbeef" });
        assert.equal(fourth.applied, false);
        assert.equal(fourth.cached, true);
      } finally {
        rmSync(altSource, { recursive: true, force: true });
      }
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

describe("worktree-sandbox import completeness", () => {
  const SKETCH = "sketches/core-loop";
  const SHA = "a".repeat(40);

  function writeAsset(sketchDir, rel, { sidecar = true, imported = true } = {}) {
    const full = path.join(sketchDir, rel);
    mkdirSync(path.dirname(full), { recursive: true });
    writeFileSync(full, "asset");
    const dest = `.godot/imported/${path.basename(rel)}-0123.scn`;
    if (sidecar) {
      writeFileSync(
        `${full}.import`,
        `[remap]\n\nimporter="scene"\npath="res://${dest}"\n\n[deps]\n\nsource_file="res://${rel}"\ndest_files=["res://${dest}"]\n`,
      );
    }
    if (imported) {
      mkdirSync(path.join(sketchDir, ".godot", "imported"), { recursive: true });
      writeFileSync(path.join(sketchDir, dest), "imported");
    }
  }

  function sandboxWith(build) {
    const worktreeDir = mkdtempSync(path.join(os.tmpdir(), "sandbox-import-"));
    const sketchDir = path.join(worktreeDir, SKETCH);
    mkdirSync(path.join(sketchDir, ".godot"), { recursive: true });
    writeFileSync(path.join(sketchDir, ".godot", "uid_cache.bin"), "uids");
    build(sketchDir);
    return {
      worktreeDir,
      sketchDir,
      stampFile: path.join(sketchDir, ".godot", IMPORT_STAMP_FILENAME),
    };
  }

  function stampAsImported(stampFile) {
    writeFileSync(
      stampFile,
      JSON.stringify({
        sha: SHA,
        overlay_hash: "",
        godot: godotIdentity(process.execPath),
        passes: 1,
      }),
    );
  }

  it("lists an asset with no sidecar or no imported file, and skips folders Godot does not import", () => {
    const box = sandboxWith((sketchDir) => {
      writeAsset(sketchDir, "assets/models/world_one/poi_siren_mast.glb");
      writeAsset(sketchDir, "assets/models/world_one/poi_bare.glb", {
        sidecar: false,
        imported: false,
      });
      writeAsset(sketchDir, "assets/textures/lost.png", { imported: false });
      writeAsset(sketchDir, "tools/blender/shells/draft.glb", { sidecar: false, imported: false });
      writeFileSync(path.join(sketchDir, "tools/blender/shells/.gdignore"), "");
      writeFileSync(path.join(sketchDir, ".godot", "imported", "stray.png"), "cache");
      writeAsset(sketchDir, ".hidden/icon.png", { sidecar: false, imported: false });
      writeAsset(sketchDir, "tools/nested/art/logo.png", { sidecar: false, imported: false });
      writeFileSync(path.join(sketchDir, "tools/nested/project.godot"), "");
      writeFileSync(path.join(sketchDir, "assets", "notes.txt"), "not an asset");
    });
    try {
      assert.deepEqual(unimportedAssets(box.worktreeDir, SKETCH), [
        { asset: "assets/models/world_one/poi_bare.glb", reason: "no .import sidecar" },
        {
          asset: "assets/textures/lost.png",
          reason: "imported file .godot/imported/lost.png-0123.scn is missing",
        },
      ]);
    } finally {
      rmSync(box.worktreeDir, { recursive: true, force: true });
    }
  });

  it("does not trust a matching stamp when a sidecar is missing: it imports, then caches", () => {
    const box = sandboxWith((sketchDir) => {
      writeAsset(sketchDir, "assets/models/world_one/poi_siren_mast.glb", {
        sidecar: false,
        imported: false,
      });
    });
    try {
      stampAsImported(box.stampFile);
      let passes = 0;
      const runPass = () => {
        passes += 1;
        writeAsset(box.sketchDir, "assets/models/world_one/poi_siren_mast.glb");
        return { status: 0, stdout: "", stderr: "" };
      };
      const args = {
        worktreeDir: box.worktreeDir,
        godotBin: process.execPath,
        sha: SHA,
        homeDir: path.join(box.worktreeDir, "home"),
        sketch: SKETCH,
        runPass,
      };
      const first = ensureSandboxImport(args);
      assert.deepEqual(
        [first.imported, first.cached, first.unimportedBefore, passes],
        [true, false, 1, 1],
      );
      assert.deepEqual(unimportedAssets(box.worktreeDir, SKETCH), []);
      const second = ensureSandboxImport(args);
      assert.deepEqual([second.imported, second.cached, passes], [false, true, 1]);
    } finally {
      rmSync(box.worktreeDir, { recursive: true, force: true });
    }
  });

  it("runs a second import when the first leaves an asset unimported", () => {
    const box = sandboxWith((sketchDir) => {
      writeAsset(sketchDir, "assets/models/a.glb", { sidecar: false, imported: false });
    });
    try {
      let passes = 0;
      const result = ensureSandboxImport({
        worktreeDir: box.worktreeDir,
        godotBin: process.execPath,
        sha: SHA,
        homeDir: path.join(box.worktreeDir, "home"),
        sketch: SKETCH,
        runPass: () => {
          passes += 1;
          if (passes === 2) writeAsset(box.sketchDir, "assets/models/a.glb");
          return { status: 0, stdout: "", stderr: "" };
        },
      });
      assert.deepEqual([result.imported, result.passes, passes], [true, 2, 2]);
      assert.equal(JSON.parse(readFileSync(box.stampFile, "utf8")).sha, SHA);
    } finally {
      rmSync(box.worktreeDir, { recursive: true, force: true });
    }
  });

  it("fails and writes no stamp when the import never produces the sidecar", () => {
    const box = sandboxWith((sketchDir) => {
      writeAsset(sketchDir, "assets/models/world_one/poi_siren_mast.glb", {
        sidecar: false,
        imported: false,
      });
    });
    try {
      assert.throws(
        () =>
          ensureSandboxImport({
            worktreeDir: box.worktreeDir,
            godotBin: process.execPath,
            sha: SHA,
            homeDir: path.join(box.worktreeDir, "home"),
            sketch: SKETCH,
            runPass: () => ({ status: 0, stdout: "", stderr: "" }),
          }),
        /1 asset not imported: assets\/models\/world_one\/poi_siren_mast\.glb \(no \.import sidecar\); no stamp written/,
      );
      assert.equal(existsSync(box.stampFile), false);
    } finally {
      rmSync(box.worktreeDir, { recursive: true, force: true });
    }
  });
});
