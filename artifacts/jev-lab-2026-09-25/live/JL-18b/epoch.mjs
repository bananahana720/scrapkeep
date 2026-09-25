// JL-18b DoD 6: the q2 epoch record, from JL-18's retained controls result and
// this run's blind report reduced through blindResult().
import { copyFileSync, readFileSync } from "node:fs";
import path from "node:path";
import { isDeepStrictEqual } from "node:util";

import {
  instrumentIdentity,
  loadQuestionSet,
} from "../../../../../tools/jev-player/decide.mjs";
import {
  blindResult,
  epochRecord,
  epochStatus,
  EPOCHS_ROOT,
  writeEpochRecord,
} from "../../../../../tools/jev-player/preflight.mjs";

const here = import.meta.dirname;
const retained = path.resolve(here, "../../../../jev-lab-2026-09-25/live/JL-18");
const read = (file) => JSON.parse(readFileSync(file, "utf8"));

const questions = loadQuestionSet("q2-neutral");
const instrument = instrumentIdentity(questions);
const controls = read(
  path.join(retained, "controls-2026-09-25T19-20-45.238Z.json"),
);
const earlier = read(path.join(retained, "epoch-record.json"));
const report = read(path.join(here, "corpus-score-q2-blind.json"));

const checks = {
  controls_instrument_is_q2: isDeepStrictEqual(controls.instrument, instrument),
  earlier_record_instrument_is_q2: isDeepStrictEqual(
    earlier.instrument,
    instrument,
  ),
  same_controls_version_and_sha:
    controls.controls_sha === earlier.controls.sha &&
    controls.controls_version === earlier.controls.version,
  same_per_control_results: isDeepStrictEqual(
    controls.controls.map((one) => [one.id, one.passed, one.reason]),
    earlier.controls.results.map((one) => [one.id, one.passed, one.reason]),
  ),
};
if (!Object.values(checks).every(Boolean)) {
  throw new Error(`retained controls disagree: ${JSON.stringify(checks)}`);
}

const record = epochRecord({
  questions,
  controls,
  blind: blindResult(report, instrument),
  now: new Date(),
});
const file = await writeEpochRecord(record, EPOCHS_ROOT);
copyFileSync(file, path.join(here, "epoch-record.json"));
const status = await epochStatus(instrument, EPOCHS_ROOT);
process.stdout.write(
  `${JSON.stringify({ checks, file: path.basename(file), resolved_models: record.resolved_models, blind: record.blind, valid_flag: record.valid, status }, null, 2)}\n`,
);
