import fs from 'fs'; import readline from 'readline';
const rl = readline.createInterface({input: fs.createReadStream(process.argv[2])});
const R = [];
for await (const l of rl) { const o = JSON.parse(l); if (o.stage === 1) R.push({t: o.tick, s: o.stage_time, p: o.position, v: o.velocity, flow: o.flow}); }
let i = 1;
while (i < R.length) {
  if (R[i-1].p[2] < 476 && R[i].p[2] >= 476 && Math.abs(R[i].p[0]) < 40) {
    const a = R[i]; let peak = a.p[1], j = i, land = null;
    for (j = i; j < Math.min(R.length, i + 900); j++) {
      peak = Math.max(peak, R[j].p[1]);
      if (j > i + 5 && R[j-1].v[1] < -2 && R[j].v[1] > R[j-1].v[1] + 2) { land = R[j]; break; }
    }
    console.log(`cross z476 at t ${a.t} (${a.s.toFixed(1)} s) x ${a.p[0].toFixed(1)} y ${a.p[1].toFixed(1)} v ${a.v.map(n=>n.toFixed(1))} flow ${a.flow} | peak y ${peak.toFixed(1)} | landing ${land ? `t ${land.t} at x ${land.p[0].toFixed(1)} y ${land.p[1].toFixed(1)} z ${land.p[2].toFixed(1)} flow ${land.flow}` : 'none within 10 s'}`);
    i = j + 1;
  } else i++;
}
