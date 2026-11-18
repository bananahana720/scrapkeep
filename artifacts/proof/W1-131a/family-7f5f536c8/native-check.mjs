import assert from "node:assert/strict";
import childProcess from "node:child_process";
import { once } from "node:events";
import { syncBuiltinESMExports } from "node:module";
import { setTimeout as sleep } from "node:timers/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const spawn = childProcess.spawn;
const trees = [];
async function tree() {
  // The windowless grandchild starts a separate process group. The kernel parent
  // chain is the only connection to the PID returned by the capture launcher.
  const source = 'const {spawn}=require("node:child_process");const p=spawn("/bin/sleep",["20"],{detached:true,stdio:"ignore"});console.log(p.pid);p.on("exit",()=>process.exit(0))';
  const parent = spawn(process.execPath, ["-e",source], {detached:true,stdio:["ignore","pipe","pipe"]});
  const [buf] = await once(parent.stdout, "data");
  const id = Number(String(buf).trim());
  assert.ok(id>1);
  trees.push([parent,id]);
  return {pid:parent.pid,child:id};
}
const foreground = "Number($.NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier)";
let foregroundFixture;
childProcess.spawn = (bin, argv, options) => {
  if (bin === "/usr/bin/osascript" && foregroundFixture) {
    assert.ok(argv[3].includes(foreground));
    argv = [...argv];
    argv[3] = argv[3].replace("while (true) {","let plantSample = 0; while (true) {").replace(foreground,foregroundFixture);
  }
  return spawn(bin,argv,options);
};
syncBuiltinESMExports();
try {
  const { watchDrawnRun }=await import(pathToFileURL(path.resolve("scripts/gate/window-watch.mjs")));
  const capture=await tree();
  const unrelated=await tree();
  const run=async () => {await sleep(650);return {pid:capture.pid};};
  const live=(await watchDrawnRun(run)).watch;
  assert.equal(live.onScreen,0);
  assert.equal(live.frontmostChanges,0);
  console.log("Unmodified live Mac watcher, windowless CLI parent",JSON.stringify(live));
  foregroundFixture='(++plantSample >= 4 ? '+capture.child+' : '+unrelated.child+')';
  const plant=(await watchDrawnRun(run)).watch;
  assert.equal(plant.onScreen,0);
  assert.equal(plant.targetOnScreen,0);
  assert.equal(plant.frontmostChanges,1);
  assert.equal(plant.missed,0);
  console.log("Foreground PID transitions from unrelated sleep to detached capture child; native ancestry and WindowServer unchanged",JSON.stringify(plant));
  foregroundFixture='2147483647'; // No such Darwin PID. An unreadable family must invalidate the trace.
  await assert.rejects(watchDrawnRun(run),/cannot read foreground process ancestry/);
  console.log("Unreadable Darwin ancestry rejected before a zero-count receipt could be returned");
} finally {
  for (const [parent,id] of trees) {try{process.kill(id,"SIGTERM");}catch{} parent.kill();}
}
