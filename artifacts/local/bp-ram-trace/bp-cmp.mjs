import fs from 'fs'; import readline from 'readline';
const drop = ['bodies','areas','nodes','posts_node','posts_physics','posts_standing'];
const clean = l => { const o = JSON.parse(l); for (const k of drop) delete o[k]; return o; };
const its = [1,2,3,4,5,6].map(r => readline.createInterface({input: fs.createReadStream(`${r}/trace-40322.ndjson`)})[Symbol.asyncIterator]());
const first = Array(6).fill(null); let t8598 = null, last = null, n = 0;
while (true) {
  const lines = await Promise.all(its.map(i => i.next()));
  if (lines[0].done) break;
  const objs = lines.map(x => clean(x.value)); const s0 = JSON.stringify(objs[0]); n++;
  for (let r = 1; r < 6; r++) if (first[r] === null && JSON.stringify(objs[r]) !== s0) first[r] = {tick: objs[0].tick, a: objs[0], b: objs[r]};
  if (objs[0].tick === 8598) t8598 = objs.map(o => o.struck);
  last = objs[0];
}
for (let r = 1; r < 6; r++) console.log(`run ${r+1} vs 1:`, first[r] ? `first differs at tick ${first[r].tick}; struck run1 ${JSON.stringify(first[r].a.struck)} run${r+1} ${JSON.stringify(first[r].b.struck)}` : 'identical game rows');
console.log('rows', n, 'tick 8598 struck per run', JSON.stringify(t8598));
console.log('last row', last.tick, last.flow, 'hp', last.hp);
