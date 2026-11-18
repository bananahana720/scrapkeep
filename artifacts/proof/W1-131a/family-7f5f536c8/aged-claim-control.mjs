import assert from "node:assert/strict";
import path from "node:path";
import {mkdirSync,mkdtempSync,readdirSync,utimesSync} from "node:fs";
import {acquireSlot,STALE_CLAIM_MS} from "../../../scripts/sketch-smoke.mjs";

// A private one-slot fixture. No engine or real machine slot is started or acquired.
const dir=mkdtempSync("artifacts/local/w131-focus/aged-claim-");
const quietDirectory=path.join(dir,"empty-quiet-fixture");
mkdirSync(quietDirectory);
const defaults={directory:dir,quietDirectory,slots:1,pollMs:5,log:()=>{}};
const first=await acquireSlot({...defaults,beforePublish(){
  const entry=readdirSync(dir).find(s=>s.startsWith("claim-"));
  const past=new Date(Date.now()-STALE_CLAIM_MS-5000);
  utimesSync(path.join(dir,entry,entry),past,past);
}});
let firstHeld=true;
const second=await acquireSlot(defaults);
console.log(JSON.stringify({source:"stage/alpha-w44 3cafd8fa3, unmodified scripts/sketch-smoke.mjs",simulatedWaitSeconds:95,firstHeldWhenSecondReturned:firstHeld,sameSlot:first.slot===second.slot}));
assert.ok(firstHeld && first.slot===second.slot);
second.release();
firstHeld=false;
first.release();
