// A persistent JXA sampler. Send only process IDs and timing to the parent. Core Graphics uses
// a top-left origin on the primary screen; NSScreen uses a bottom-left origin, in the same points.
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";

const SAMPLER = `
ObjC.import("AppKit");
ObjC.import("CoreGraphics");
const stdout = $.NSFileHandle.fileHandleWithStandardOutput;
const clock = $.NSProcessInfo.processInfo;
const period = 0.05;
let next = clock.systemUptime;
while (true) {
  const screens = $.NSScreen.screens;
  if (!screens.count) throw Error("no active screens");
  const top = screens.firstObject.frame.size.height;
  const displays = [];
  for (let i = 0; i < screens.count; i++) {
    const f = screens.objectAtIndex(i).frame;
    displays.push([f.origin.x, top - f.origin.y - f.size.height, f.size.width, f.size.height]);
  }
  const cf = $.CGWindowListCopyWindowInfo(17, 0); // on screen, excluding desktop elements
  if (!cf) throw Error("no window list");
  const windows = ObjC.deepUnwrap(ObjC.castRefToObject(cf));
  const front = Number($.NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier);
  if (!Array.isArray(windows) || !windows.length || !(front > 0)) throw Error("window server unreadable");
  const visible = new Set();
  const godot = new Set();
  for (const w of windows) {
    const b = w.kCGWindowBounds;
    if (b.Width <= 0 || b.Height <= 0) continue;
    if (!displays.some(d => b.X < d[0] + d[2] && b.X + b.Width > d[0] && b.Y < d[1] + d[3] && b.Y + b.Height > d[1])) continue;
    visible.add(w.kCGWindowOwnerPID);
    if (/godot/i.test(w.kCGWindowOwnerName)) godot.add(w.kCGWindowOwnerPID);
  }
  const now = clock.systemUptime;
  const missed = Math.max(0, Math.floor((now - next) / period));
  const row = {at: Date.now(), front, visible: Array.from(visible), godot: Array.from(godot), missed};
  stdout.writeData($(JSON.stringify(row) + "\\n").dataUsingEncoding($.NSUTF8StringEncoding));
  next += (missed + 1) * period;
  // Service workspace notifications between snapshots so frontmostApplication stays current.
  $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(Math.max(0, next - clock.systemUptime)));
}
`;

function bounded(promise, ms) {
  let timer;
  return Promise.race([promise, new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error("window watcher timed out")), ms);
  })]).finally(() => clearTimeout(timer));
}

export function windowCounts(samples, pid) {
  if (!Number.isInteger(pid) || samples.length < 2) throw new Error("window watcher lacks a process or samples");
  let frontmostChanges = 0;
  let onScreen = 0;
  let targetOnScreen = 0;
  let missed = 0;
  let maxGapMs = 0;
  for (const [i, s] of samples.entries()) {
    if (i > 0) {
      if (s.front === pid && samples[i - 1].front !== pid) frontmostChanges++;
      maxGapMs = Math.max(maxGapMs, s.at - samples[i - 1].at);
      missed += s.missed;
    }
    if (s.visible.includes(pid)) targetOnScreen++;
    if (s.visible.includes(pid) || s.godot.length) onScreen++;
  }
  return { samples: samples.length, firstMs: samples[0].at, lastMs: samples.at(-1).at,
    periodMs: 50, maxGapMs, missed, onScreen, targetOnScreen, frontmostChanges };
}

function startSampler() {
  return spawn("/usr/bin/osascript", ["-l", "JavaScript", "-e", SAMPLER], { stdio: ["ignore", "pipe", "pipe"] });
}

export async function watchDrawnRun(run, start = startSampler) {
  const child = start();
  const controller = new AbortController();
  const stop = () => { controller.abort(); child.kill(); };
  const onInterrupt = signal => { process.exitCode = signal === "SIGINT" ? 130 : 143; stop(); };
  process.on("SIGINT", onInterrupt);
  process.on("SIGTERM", onInterrupt);
  process.on("exit", stop);
  let error = "";
  child.on("error", e => { error = e.message; });
  child.stderr.setEncoding("utf8").on("data", s => { error += s; });
  const lines = createInterface({ input: child.stdout });
  const rows = lines[Symbol.asyncIterator]();
  const samples = [];
  let exitMs;
  const read = async () => {
    const { value, done } = await rows.next();
    if (done) throw new Error("window watcher stopped: " + error.trim());
    samples.push(JSON.parse(value));
  };
  try {
    await bounded(read(), 5000);
    const observing = (async () => {
      do { await bounded(read(), 1500); } while (exitMs === undefined || samples.at(-1).at <= exitMs);
    })().then(() => null, e => { controller.abort(); return e; });
    const result = await run(controller.signal);
    exitMs = Date.now();
    const failure = await bounded(observing, 3000);
    if (failure) throw failure;
    return { ...result, watch: windowCounts(samples, result.pid) };
  } finally {
    process.off("SIGINT", onInterrupt);
    process.off("SIGTERM", onInterrupt);
    process.off("exit", stop);
    lines.close();
    stop();
  }
}
