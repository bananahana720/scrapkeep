import path from "node:path";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";

import { RUNS_ROOT } from "./record.mjs";
import { METRICS } from "./metrics/index.mjs";
import { EXIT, STATUS, evaluate } from "./metrics/status.mjs";
import {
  compareToPin,
  describeEpoch,
  latestReading,
  loadModel,
  loadPins,
} from "./model.mjs";

const repositoryRoot = path.resolve(import.meta.dirname, "../..");
const ARTIFACTS_ROOT = path.join(repositoryRoot, "artifacts");
const LAYERS = [...new Set(METRICS.map((metric) => metric.layer))];
const RESET = "\x1b[0m";

const USAGE = `Usage:
  node scripts/lab/stats-cli.mjs [--layer <layer>] [--runs dir] [--artifacts dir]
  scrapkeep stats [--layer <layer>]
Layers: ${LAYERS.join(", ")}.`;

class UsageError extends Error {}

const number = (value) => String(Number(value.toFixed(4)));

function signed(value) {
  const text = number(value);
  return value > 0 && text !== "0" ? `+${text}` : text;
}

function changeText(comparison) {
  if (comparison.kind === "epoch")
    return `pin ${comparison.pin.name} is in another epoch, not compared`;
  if (comparison.kind === "change")
    return `change ${signed(comparison.change)} from pin ${comparison.pin.name}`;
  return "no pin";
}

function metricLine(metric, model, pins, tty) {
  const reading = latestReading(model, metric.id);
  const measure = reading?.measure ?? { value: null, n: 0 };
  const status = evaluate(metric, measure);
  const value = Number.isFinite(measure.value) ? number(measure.value) : "none";
  const parts = [`${status.glyph} ${metric.id} ${value} n=${measure.n}`];
  if (reading === null) parts.push("no reading");
  else {
    parts.push(changeText(compareToPin(reading, pins)));
    parts.push(`${reading.series} seq ${reading.record.seq}`);
  }
  parts.push(metric.says);
  const text = parts.join(" · ");
  return tty ? `  ${status.ansi}${text}${RESET}` : `  ${text}`;
}

function header(model) {
  const lines = [];
  if (model.records.length === 0) lines.push(`no runs under ${model.root}`);
  else lines.push(`${model.records.length} runs under ${model.root}`);
  for (const [position, epoch] of model.epochs.entries()) {
    const span =
      epoch.first_seq === epoch.last_seq
        ? `seq ${epoch.first_seq}`
        : `seq ${epoch.first_seq} to ${epoch.last_seq}`;
    lines.push(
      `epoch ${position + 1} of ${model.epochs.length}: ${describeEpoch(epoch)}, ${span}, ${epoch.runs} runs`,
    );
  }
  for (const boundary of model.boundaries)
    lines.push(`trend break at seq ${boundary.seq} (${boundary.id})`);
  for (const problem of model.problems) lines.push(`problem: ${problem}`);
  return lines;
}

export async function main(
  argv,
  { out = process.stdout, err = process.stderr } = {},
) {
  try {
    let values;
    try {
      ({ values } = parseArgs({
        args: argv,
        options: {
          layer: { type: "string" },
          runs: { type: "string" },
          artifacts: { type: "string" },
        },
        allowPositionals: false,
        strict: true,
      }));
    } catch (error) {
      throw new UsageError(error.message);
    }
    if (values.layer !== undefined && !LAYERS.includes(values.layer))
      throw new UsageError(`unknown layer ${values.layer}`);
    const model = await loadModel({
      root: path.resolve(values.runs ?? RUNS_ROOT),
    });
    const pins = await loadPins(
      path.resolve(values.artifacts ?? ARTIFACTS_ROOT),
    );
    const tty = out.isTTY === true;
    const lines = header(model);
    const layers = values.layer === undefined ? LAYERS : [values.layer];
    for (const layer of layers) {
      lines.push("", layer);
      for (const metric of METRICS.filter((one) => one.layer === layer))
        lines.push(metricLine(metric, model, pins, tty));
    }
    const legend = Object.values(STATUS)
      .map((status) => `${status.glyph} ${status.word}`)
      .join("  ");
    lines.push("", `key: ${legend}`);
    out.write(`${lines.join("\n")}\n`);
    return EXIT.pass;
  } catch (error) {
    if (!(error instanceof UsageError)) throw error;
    err.write(`${error.message}\n${USAGE}\n`);
    return EXIT.usage;
  }
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  try {
    process.exitCode = await main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`${error.stack ?? error}\n`);
    process.exitCode = EXIT.invalid;
  }
}
