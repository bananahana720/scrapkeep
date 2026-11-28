import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  COMMIT_SHA_RE,
  commitsMatch,
  formatJsonReceipt,
  runnerReceiptBaseName,
  runnerReceiptFileName,
  runnerReceiptPath,
  writeJsonReceipt,
} from "./receipt.mjs";
import { parseReceiptArgs } from "../gate/receipt-cli.mjs";

test("receipt: COMMIT_SHA_RE and commitsMatch validate 7..40 lowercase hex prefixes", () => {
  assert.equal(COMMIT_SHA_RE.test("abcdef0"), true);
  assert.equal(COMMIT_SHA_RE.test("a".repeat(40)), true);
  assert.equal(COMMIT_SHA_RE.test("abc123"), false);
  assert.equal(COMMIT_SHA_RE.test("ABCDEF0"), false);
  assert.equal(commitsMatch("abcdef0123456789", "abcdef0"), true);
  assert.equal(commitsMatch("abcdef0", "abcdef0123456789"), true);
  assert.equal(commitsMatch("abcdef0", "1234567"), false);
  assert.equal(commitsMatch("short", "short"), false);
});

test("receipt: runnerReceiptPath preserves label, id slice, nogit fallback, and stamp", () => {
  const startedAt = "2026-11-27T12:34:56.789Z";
  assert.equal(
    runnerReceiptBaseName("fast", "0123456789abcdef0123", startedAt),
    "fast-0123456789ab-2026-11-27T12-34-56-789Z",
  );
  assert.equal(
    runnerReceiptFileName("smoke", null, startedAt),
    "smoke-nogit-2026-11-27T12-34-56-789Z.json",
  );
  assert.equal(
    runnerReceiptPath("/repo", "nightly", "fedcba9876543210", startedAt),
    path.join(
      "/repo",
      "artifacts",
      "local",
      "receipts",
      "nightly-fedcba987654-2026-11-27T12-34-56-789Z.json",
    ),
  );
});

test("receipt: writeJsonReceipt creates parent directories and writes pretty trailing-newline JSON", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "receipt-test-"));
  try {
    const file = path.join(dir, "nested", "r.json");
    const data = { head: "abcdef0", pass: true };
    assert.equal(writeJsonReceipt(file, data), file);
    assert.equal(readFileSync(file, "utf8"), formatJsonReceipt(data));
    assert.deepEqual(JSON.parse(readFileSync(file, "utf8")), data);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("receipt-cli: parseReceiptArgs handles split/= forms, multi, bool, and head validation", () => {
  const parsed = parseReceiptArgs(
    ["--band", "a", "--band=b", "--head=abcdef0", "--out", "r.json", "--flag"],
    {
      valueFlags: { "--band": { key: "band", multi: true } },
      boolFlags: { "--flag": "flag" },
      defaults: { flag: false },
      head: "required",
    },
  );
  assert.deepEqual(parsed, {
    band: ["a", "b"],
    head: "abcdef0",
    out: "r.json",
    flag: true,
  });
  assert.throws(() => parseReceiptArgs(["--head", "bad"], { head: "required" }), /7 to 40/);
  assert.throws(() => parseReceiptArgs(["--unknown"], {}), /unknown argument: --unknown/);
  assert.throws(() => parseReceiptArgs(["--out"], {}), /--out requires a value/);
  assert.throws(
    () => parseReceiptArgs(["--out="], { rejectEmptyEquals: true }),
    /--out requires a value/,
  );
});
