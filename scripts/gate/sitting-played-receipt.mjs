#!/usr/bin/env node
import { readFileSync, realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { parseReceiptArgs, runReceiptCliSync } from "./receipt-cli.mjs";

export const LOOPS = ["heat", "overtime", "called_shot", "marked_hull", "moss_scale", "carry_core"];
export const MIN_CHECKS = 20;

const jsonLines = (text, tag) =>
  text
    .split("\n")
    .filter((l) => l.startsWith(`${tag} {`))
    .map((line) => {
      try {
        return JSON.parse(line.slice(tag.length + 1));
      } catch {
        return null;
      }
    });
const jsonAfter = (text, tag) => jsonLines(text, tag)[0] ?? null;
export const MIN_CONTROLS = 2;

export function buildReceipt(text, head) {
  const lines = text.split("\n");
  const failed = lines.filter((l) => l.endsWith("-> FAIL"));
  const passed = lines.filter((l) => l.endsWith("-> PASS"));
  const run = jsonAfter(text, "RECEIPT");
  const controls = jsonLines(text, "CONTROL");
  const fired = run?.fired ?? {};
  const missing = LOOPS.filter((l) => fired[l] !== true);
  const offs = controls.map((c) => c?.off);
  const caughtOne = (control) =>
    Boolean(
      run &&
      control &&
      LOOPS.includes(control.off) &&
      fired[control.off] === true &&
      control.fired?.[control.off] === false &&
      LOOPS.filter((l) => l !== control.off).every((l) => control.fired?.[l] === fired[l]),
    );
  const caught =
    controls.length >= MIN_CONTROLS &&
    new Set(offs).size === controls.length &&
    controls.every(caughtOne);
  const checks = passed.length + failed.length;
  const pass =
    Boolean(run) && failed.length === 0 && checks >= MIN_CHECKS && missing.length === 0 && caught;
  let measured;
  if (!run) measured = "no RECEIPT line: the played run did not finish";
  else if (failed.length) measured = `${failed.length} check(s) failed: ${failed[0].slice(0, 120)}`;
  else if (checks < MIN_CHECKS) measured = `only ${checks} check lines, the test stopped early`;
  else if (missing.length)
    measured = `${LOOPS.length - missing.length} of ${LOOPS.length} loops fired; not fired: ${missing.join(", ")} (${run.seconds} s)`;
  else
    measured = `${LOOPS.length} of ${LOOPS.length} loops fired in a played run to Brindle (${run.seconds} s); with ${offs.join(" off, and with ")} off each read as not fired`;
  return { head, pass, measured, plant_caught: caught };
}

function main(argv) {
  const usage =
    "usage: sitting-played-receipt.mjs --log <test output> --head <commit> [--out <file>]";
  return runReceiptCliSync(() => {
    const args = parseReceiptArgs(argv, {
      valueFlags: { "--log": { key: "log" }, "--head": { key: "head" } },
      usageError: usage,
    });
    if (!args.log || !args.head) throw new Error(usage);
    return { receipt: buildReceipt(readFileSync(args.log, "utf8"), args.head), out: args.out };
  });
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url))
  process.exit(main(process.argv.slice(2)));
