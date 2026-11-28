import {
  COMMIT_SHA_RE,
  commitsMatch,
  formatJsonReceipt,
  writeJsonReceipt,
} from "../lib/receipt.mjs";
import { REPO_ROOT as root, cleanHead } from "../lib/git.mjs";

export { COMMIT_SHA_RE, cleanHead, commitsMatch, formatJsonReceipt, root, writeJsonReceipt };

export function parseReceiptArgs(
  argv,
  {
    valueFlags = {},
    boolFlags = {},
    defaults = {},
    head = false,
    headError = (value) => `--head requires 7 to 40 lowercase hex characters; got "${value}"`,
    usageError = null,
    rejectEmptyEquals = false,
    ignoreUnknown = false,
  } = {},
) {
  const allValueFlags = {
    "--out": { key: "out" },
    ...(head ? { "--head": { key: "head" } } : {}),
    ...valueFlags,
  };
  const args = { ...defaults };
  for (const spec of Object.values(allValueFlags)) {
    if (spec.multi && !Array.isArray(args[spec.key])) args[spec.key] = [];
  }

  const readValue = (index, flag, spec) => {
    const value = argv[index + 1];
    if (value === undefined || value === "" || value.startsWith("--")) {
      throw new Error(spec.emptyError ?? `${flag} requires a value`);
    }
    return value;
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (Object.hasOwn(boolFlags, arg)) {
      args[boolFlags[arg]] = true;
      continue;
    }
    if (Object.hasOwn(allValueFlags, arg)) {
      const spec = allValueFlags[arg];
      const raw = readValue(i++, arg, spec);
      const parsed = spec.parse ? spec.parse(raw) : raw;
      if (spec.multi) args[spec.key].push(parsed);
      else args[spec.key] = parsed;
      continue;
    }
    const eq = arg.indexOf("=");
    if (eq > 0) {
      const flag = arg.slice(0, eq);
      if (Object.hasOwn(allValueFlags, flag)) {
        const spec = allValueFlags[flag];
        const raw = arg.slice(eq + 1);
        if (raw === "" && (rejectEmptyEquals || spec.rejectEmptyEquals || spec.emptyError)) {
          throw new Error(spec.emptyError ?? `${flag} requires a value`);
        }
        const parsed = spec.parse ? spec.parse(raw) : raw;
        if (spec.multi) args[spec.key].push(parsed);
        else args[spec.key] = parsed;
        continue;
      }
    }
    if (ignoreUnknown) {
      if (eq < 0 && i + 1 < argv.length && !argv[i + 1].startsWith("--")) i++;
      continue;
    }
    throw new Error(usageError ?? `unknown argument: ${arg}`);
  }

  if (head === "required" && !args.head) {
    throw new Error(usageError ?? "--head is required");
  }
  if (head && args.head && !COMMIT_SHA_RE.test(args.head)) {
    throw new Error(headError(args.head));
  }
  return args;
}

export function emitJsonReceipt(receipt, out = null) {
  if (out) {
    writeJsonReceipt(out, receipt);
  } else {
    process.stdout.write(formatJsonReceipt(receipt));
  }
}

export function runReceiptCliSync(run) {
  let outcome;
  try {
    outcome = run();
  } catch (error) {
    console.error(String(error?.message ?? error));
    return 2;
  }
  const { receipt, out = null } = outcome;
  emitJsonReceipt(receipt, out);
  return receipt.pass ? 0 : 1;
}

export async function runReceiptCli(run) {
  let outcome;
  try {
    outcome = await run();
  } catch (error) {
    console.error(String(error?.message ?? error));
    return 2;
  }
  const { receipt, out = null } = outcome;
  emitJsonReceipt(receipt, out);
  return receipt.pass ? 0 : 1;
}
