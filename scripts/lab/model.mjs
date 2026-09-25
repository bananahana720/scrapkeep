import { readFile, readdir } from "node:fs/promises";
import path from "node:path";

import { RUNS_ROOT, SCHEMA, rebuildIndex } from "./record.mjs";

const pinDay = /^jev-lab-\d{4}-\d{2}-\d{2}$/;

export class MixedEpochError extends Error {}

// Plan § 1 "Instrument epoch": each distinct question sha, and each model,
// is its own instrument. The model Jev actually answered as outranks the one
// the instrument block intended.
export function epochOf(record) {
  const provenance = record?.provenance ?? {};
  return {
    questions_sha: provenance.instrument?.questions_sha ?? null,
    model: provenance.jev?.model ?? provenance.instrument?.model ?? null,
  };
}

export function epochKey({ questions_sha, model }) {
  return JSON.stringify([questions_sha, model]);
}

export function describeEpoch({ questions_sha, model }) {
  if (questions_sha === null && model === null) return "no instrument";
  const sha = questions_sha === null ? "none" : questions_sha.slice(0, 12);
  return `questions ${sha}, model ${model ?? "none"}`;
}

export const seriesOf = (record) => `${record.type}/${record.label}`;

function measureOf(record, id) {
  return record.kpis?.[id] ?? record.kris?.[id] ?? null;
}

// A killed append can leave a truncated last line; record.mjs drops that one
// line, and so does this reader. A bad line anywhere else throws.
function parseIndex(text) {
  const lines = text.split("\n").filter((line) => line.trim() !== "");
  const entries = [];
  for (const [position, line] of lines.entries()) {
    try {
      entries.push(JSON.parse(line));
    } catch (error) {
      if (position === lines.length - 1) break;
      throw error;
    }
  }
  return entries;
}

async function indexEntries(root, problems) {
  try {
    return parseIndex(await readFile(path.join(root, "index.ndjson"), "utf8"));
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  try {
    return parseIndex(await rebuildIndex({ root, write: false }));
  } catch (error) {
    if (!(error instanceof SyntaxError)) throw error;
    problems.push(
      `${root} has no index.ndjson and a run.json it holds is unreadable`,
    );
    return [];
  }
}

async function readRecord(root, id, problems) {
  let text;
  try {
    text = await readFile(path.join(root, id, "run.json"), "utf8");
  } catch (error) {
    if (!["ENOENT", "ENOTDIR"].includes(error.code)) throw error;
    problems.push(`run ${id} is in the index but has no run.json`);
    return null;
  }
  let record;
  try {
    record = JSON.parse(text);
  } catch {
    problems.push(`run ${id} has an unreadable run.json`);
    return null;
  }
  if (record?.schema !== SCHEMA || record.id !== id) {
    problems.push(`run ${id} is not a ${SCHEMA} record for that id`);
    return null;
  }
  return record;
}

function modelConflict(record) {
  const intended = record.provenance?.instrument?.model;
  const answered = record.provenance?.jev?.model;
  if (intended && answered && intended !== answered)
    return `run ${record.id}'s instrument names model ${intended} but Jev answered as ${answered}`;
  return null;
}

// Consecutive runs in one series and epoch share a segment; any change of
// epoch starts a new one, so a trend line never joins two instruments.
function addPoint(trends, record, id, measure) {
  if (!trends.has(id)) trends.set(id, new Map());
  const bySeries = trends.get(id);
  const series = seriesOf(record);
  if (!bySeries.has(series)) bySeries.set(series, []);
  const segments = bySeries.get(series);
  const epoch = epochOf(record);
  const key = epochKey(epoch);
  if (segments.at(-1)?.epoch !== key)
    segments.push({ epoch: key, ...epoch, points: [] });
  segments.at(-1).points.push({
    seq: record.seq,
    id: record.id,
    series,
    epoch: key,
    value: measure.value,
    n: measure.n,
  });
}

export async function loadModel({ root = RUNS_ROOT } = {}) {
  const problems = [];
  const byId = new Map();
  for (const entry of await indexEntries(root, problems)) {
    if (typeof entry?.id !== "string") continue;
    const record = await readRecord(root, entry.id, problems);
    if (record !== null) byId.set(record.id, record);
  }
  const records = [...byId.values()].toSorted(
    (a, b) => a.seq - b.seq || a.id.localeCompare(b.id),
  );

  const latest = new Map();
  const trends = new Map();
  const epochs = [];
  const boundaries = [];
  let previous = null;
  for (const record of records) {
    latest.set(seriesOf(record), record);
    const conflict = modelConflict(record);
    if (conflict !== null) problems.push(conflict);
    const epoch = epochOf(record);
    const key = epochKey(epoch);
    let known = epochs.find((one) => one.key === key);
    if (known === undefined) {
      known = {
        key,
        ...epoch,
        first_seq: record.seq,
        last_seq: record.seq,
        runs: 0,
      };
      epochs.push(known);
    }
    known.last_seq = record.seq;
    known.runs += 1;
    if (previous !== null && previous !== key)
      boundaries.push({
        seq: record.seq,
        id: record.id,
        from: previous,
        to: key,
      });
    previous = key;
    for (const bucket of [record.kpis, record.kris])
      for (const [id, measure] of Object.entries(bucket ?? {}))
        addPoint(trends, record, id, measure);
  }
  return { root, records, latest, trends, epochs, boundaries, problems };
}

// Pools readings from one epoch as an n-weighted mean. Readings from two
// question sets or two models measure different instruments, so pooling them
// is refused rather than averaged.
export function aggregate(points) {
  const keys = [...new Set(points.map((point) => point.epoch))];
  if (keys.length > 1) {
    const epochs = keys.map((key) => JSON.parse(key));
    const shas = new Set(epochs.map(([sha]) => sha));
    const parts = [];
    if (shas.size > 1) parts.push("question shas");
    if (new Set(epochs.map(([, model]) => model)).size > 1)
      parts.push("models");
    throw new MixedEpochError(
      `refusing to aggregate across mixed ${parts.join(" and ")}: ${keys.join(", ")}`,
    );
  }
  let weighted = 0;
  let n = 0;
  for (const point of points) {
    if (!Number.isFinite(point.value) || !(point.n > 0)) continue;
    weighted += point.value * point.n;
    n += point.n;
  }
  return { value: n === 0 ? null : weighted / n, n, epoch: keys[0] ?? null };
}

// The newest reading of a metric among the latest record of every series.
export function latestReading(model, id) {
  let found = null;
  for (const record of model.latest.values()) {
    const measure = measureOf(record, id);
    if (measure === null) continue;
    if (found === null || record.seq > found.record.seq)
      found = {
        id,
        record,
        measure,
        series: seriesOf(record),
        epoch: epochOf(record),
      };
  }
  return found;
}

async function readJson(file) {
  try {
    return JSON.parse(await readFile(file, "utf8"));
  } catch (error) {
    if (error instanceof SyntaxError || error.code === "ENOENT") return null;
    throw error;
  }
}

async function listing(directory) {
  try {
    return await readdir(directory);
  } catch (error) {
    if (["ENOENT", "ENOTDIR"].includes(error.code)) return [];
    throw error;
  }
}

// Every pin under artifacts/jev-lab-*/pins/, newest first.
export async function loadPins(artifacts) {
  const pins = [];
  for (const day of (await listing(artifacts)).filter((one) =>
    pinDay.test(one),
  )) {
    const dayPins = path.join(artifacts, day, "pins");
    for (const name of await listing(dayPins)) {
      const directory = path.join(dayPins, name);
      const record = await readJson(path.join(directory, "run.json"));
      if (record?.schema !== SCHEMA) continue;
      const meta = await readJson(path.join(directory, "pin.json"));
      const pinnedAt = meta?.pinned_at ?? `${day.slice(8)}T00:00:00.000Z`;
      pins.push({ name, day, directory, record, pinned_at: pinnedAt });
    }
  }
  return pins.toSorted(
    (a, b) =>
      b.pinned_at.localeCompare(a.pinned_at) || a.name.localeCompare(b.name),
  );
}

// Change from the newest pin of the same run type that carries the metric.
export function compareToPin(reading, pins) {
  if (reading === null) return { kind: "none" };
  const pin = pins.find(
    (one) =>
      one.record.type === reading.record.type &&
      Number.isFinite(measureOf(one.record, reading.id)?.value),
  );
  if (pin === undefined) return { kind: "none" };
  if (epochKey(epochOf(pin.record)) !== epochKey(reading.epoch))
    return { kind: "epoch", pin };
  if (!Number.isFinite(reading.measure.value)) return { kind: "none" };
  const before = measureOf(pin.record, reading.id).value;
  return { kind: "change", pin, change: reading.measure.value - before };
}
