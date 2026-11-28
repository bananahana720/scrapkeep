import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";

export const COMMIT_SHA_RE = /^[0-9a-f]{7,40}$/;

export function commitsMatch(a, b) {
  return (
    typeof a === "string" &&
    typeof b === "string" &&
    COMMIT_SHA_RE.test(a) &&
    COMMIT_SHA_RE.test(b) &&
    (a.startsWith(b) || b.startsWith(a))
  );
}

export function formatJsonReceipt(data) {
  return JSON.stringify(data, null, 2) + "\n";
}

export function writeJsonReceipt(file, data) {
  mkdirSync(path.dirname(path.resolve(file)), { recursive: true });
  writeFileSync(file, formatJsonReceipt(data));
  return file;
}

export function runnerReceiptBaseName(label, id, startedAt) {
  const stamp = startedAt.replace(/[:.]/g, "-");
  return `${label}-${id ? id.slice(0, 12) : "nogit"}-${stamp}`;
}

export function runnerReceiptFileName(label, id, startedAt) {
  return `${runnerReceiptBaseName(label, id, startedAt)}.json`;
}

export function runnerReceiptPath(root, label, id, startedAt) {
  return path.join(
    root,
    "artifacts",
    "local",
    "receipts",
    runnerReceiptFileName(label, id, startedAt),
  );
}
