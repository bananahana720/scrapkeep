import { realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export function isMain(metaUrl, argv1 = process.argv[1]) {
  if (!argv1) return false;
  const self = fileURLToPath(metaUrl);
  try {
    return realpathSync(self) === realpathSync(argv1);
  } catch {
    return path.resolve(self) === path.resolve(argv1);
  }
}

export function flagValue(argv, at, needs) {
  if (!argv[at] || argv[at].startsWith("-")) throw new Error(`${argv[at - 1]} requires ${needs}`);
  return argv[at];
}

export function parseCliArgs(
  argv,
  { flags = {}, values = {}, multi = {}, allowPositionals = false, defaults = {} } = {},
) {
  const opts = { ...defaults };
  for (const key of Object.values(flags)) {
    if (!(key in opts)) opts[key] = false;
  }
  for (const key of Object.values(values)) {
    if (!(key in opts)) opts[key] = null;
  }
  for (const key of Object.values(multi)) {
    if (!(key in opts)) opts[key] = [];
    else opts[key] = [...opts[key]];
  }
  const positionals = [];
  let restPositional = false;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (restPositional) {
      positionals.push(arg);
      continue;
    }
    if (arg === "--" && allowPositionals) {
      restPositional = true;
      continue;
    }
    if (Object.hasOwn(flags, arg)) {
      opts[flags[arg]] = true;
      continue;
    }
    const eq = arg.startsWith("--") ? arg.indexOf("=") : -1;
    const flagName = eq > 0 ? arg.slice(0, eq) : arg;
    const inlineValue = eq > 0 ? arg.slice(eq + 1) : null;

    if (Object.hasOwn(values, flagName)) {
      const value = inlineValue !== null ? inlineValue : argv[++i];
      if (value === undefined || value === "") throw new Error(`${flagName} requires a value`);
      opts[values[flagName]] = value;
      continue;
    }
    if (Object.hasOwn(multi, flagName)) {
      const value = inlineValue !== null ? inlineValue : argv[++i];
      if (value === undefined || value === "") throw new Error(`${flagName} requires a value`);
      opts[multi[flagName]].push(value);
      continue;
    }
    if (!arg.startsWith("-") && allowPositionals) {
      positionals.push(arg);
      continue;
    }
    throw new Error(`unknown argument: ${arg}`);
  }

  if (allowPositionals) opts.positionals = positionals;
  return opts;
}
