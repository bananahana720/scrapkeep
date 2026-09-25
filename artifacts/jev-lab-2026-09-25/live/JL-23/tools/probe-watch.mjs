// Drives watch's real order hook (play.mjs requestOrder, which spawns
// scripts/lab/test-order.mjs as a child) against a labelled scratch sketch.
// usage: node probe-watch.mjs <scratch sketch dir> <saved file>
import { readdirSync } from "node:fs";
import path from "node:path";

import { requestOrder } from "../../../../../scripts/play.mjs";

const [dir, saved] = process.argv.slice(2);
const names = ["boot", ...readdirSync(path.join(dir, "tests")).filter((n) => n.endsWith(".gd")).sort()];
const started = Date.now();
const result = await requestOrder({ directory: dir }, names, saved);
console.log(JSON.stringify({ names, ...result, wall_ms: Date.now() - started }, null, 2));
