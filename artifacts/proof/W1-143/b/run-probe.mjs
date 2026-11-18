// From a game checkout, run node /path/to/this/run-probe.mjs fins|places|gates|pause.
// FIN_VARIANT=shell_rivet_calibrated selects the trim. FIN_EXIT=bail cancels after peak.
import { spawnSync } from "node:child_process";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const probes = { fins: "cloud/fin-ride.gd", places: "place-stations.gd", gates: "gate-dress-ticks.gd", pause: "pause-sphere.gd" };
const which = process.argv[2];
if (!Object.hasOwn(probes, which) || !process.env.GODOT_BIN) {
  throw new Error("Set GODOT_BIN and select fins, places, gates or pause");
}
const { userDataEnv } = await import(pathToFileURL(resolve("scripts/godot-home.mjs")));
const home = mkdtempSync(join(tmpdir(), "w143-probe-"));
const script = fileURLToPath(new URL(probes[which], import.meta.url));
const flags = which === "gates"
  ? ["--out=" + home, "--table=park", "--policy=skipper", "--pilot=pylon_engineer", "--seeds=40317", "--until=2", "--prim-plant=1"]
  : ["--profile=sitting-earned"];
const run = spawnSync(process.env.GODOT_BIN,
  ["--headless", "--fixed-fps", "90", "--path", resolve("sketches/core-loop"), "--script", script, "--", ...flags],
  { env: { ...process.env, ...userDataEnv(home) }, stdio: "inherit", timeout: 840000 });
process.exit(run.status ?? 2);
