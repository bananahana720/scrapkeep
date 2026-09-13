import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(process.argv[2] ?? '.');
const here = dirname(fileURLToPath(import.meta.url));
const read = (p) => readFileSync(resolve(root, p), 'utf8');

const checks = [
  ['README names five done cards', () => /Five of the fourteen are done/.test(read('docs/project/README.md'))],
  ['README links HF-03a, HF-04a, HF-05 and the archive', () => {
    const s = read('docs/project/README.md');
    return ['HF-03a-module-map.md', 'HF-04a-runtime-lifecycle.md', 'HF-05-content-admission.md', 'tracking/EVENTS-0001-0057.md'].every((x) => s.includes(x));
  }],
  ['README defers live counts to TRACKING', () => /TRACKING\.md\)\s+owns the live card counts/.test(read('docs/project/README.md'))],
  ['BACKLOG edition line dated 12 September 2026', () => /^Edition 3 · Updated 12 September 2026/m.test(read('BACKLOG.md'))],
  ['BACKLOG sprint prose cites EV-0078', () => {
    const s = read('BACKLOG.md');
    const i = s.indexOf('## Proposed first sprint\n');
    return i > 0 && s.slice(i, i + 800).includes('EV-0078');
  }],
  ['BACKLOG heading text unchanged', () => read('BACKLOG.md').includes('\n## Proposed first sprint\n')],
  ['ORCHESTRATOR header no longer presents Sprint 0 as current', () => !/Operational Sprint 0 is authorized by/.test(read('ORCHESTRATOR.md').split('\n')[2])],
  ['ORCHESTRATOR closing paragraph no longer says awaiting_review', () => !read('ORCHESTRATOR.md').trimEnd().split('\n').at(-1).includes('awaiting_review')],
  ['ORCHESTRATOR header and closing defer to TRACKING authorization row', () => (read('ORCHESTRATOR.md').match(/TRACKING\.md#program-authorization/g) ?? []).length >= 2],
  ['ORCHESTRATOR headings unchanged', () => {
    const want = ['Read first and preserve authority', 'Roles and concurrency', 'Admission and assignment', 'Ownership, checkpoints and interruption', 'Handoff and review', 'Serial integration and completion', 'Questions and scope changes', 'Sprint closure', 'Specification contradictions', 'Checkpoint and handback'];
    const got = read('ORCHESTRATOR.md').split('\n').filter((l) => l.startsWith('## ')).map((l) => l.slice(3));
    return JSON.stringify(want) === JSON.stringify(got);
  }],
  ['adr/README no longer says pages not produced and links sections README', () => {
    const s = read('adr/README.md');
    return !s.includes('They have not been produced') && s.includes('../docs/tech/sections/README.md');
  }],
  ['RUNTIME-BLUEPRINT opens with historical banner naming TADR-002', () => {
    const l = read('docs/RUNTIME-BLUEPRINT.md').split('\n')[2];
    return l.startsWith('Historical') && l.includes('TADR-002-runtime-model.md');
  }],
  ['PLANNING-PREP-SWARM opens with historical banner naming both supersessions', () => {
    const l = read('docs/PLANNING-PREP-SWARM.md').split('\n')[2];
    return l.startsWith('Historical') && l.includes('HOUSEKEEPING.md#environment-constraint') && l.includes('project/PLANNING.md');
  }],
  ['HOUSEKEEPING line 40 points at root BACKLOG', () => read('docs/project/HOUSEKEEPING.md').split('\n')[39].includes('](../../BACKLOG.md)')],
  ['ASSETS line 15 points T04 at SOURCE-DISPOSITIONS', () => read('docs/project/ASSETS.md').split('\n')[14].includes('SOURCE-DISPOSITIONS.md#historical-identifiers')],
  ['no permitted file links the frozen docs/project/BACKLOG.md', () => ['docs/project/HOUSEKEEPING.md', 'docs/project/ASSETS.md'].every((p) => !/\]\(BACKLOG\.md/.test(read(p)))],
];

const results = checks.map(([name, fn]) => {
  let ok = false;
  let error;
  try { ok = Boolean(fn()); } catch (e) { error = String(e); }
  return { name, ok, ...(error ? { error } : {}) };
});
const failures = results.filter((r) => !r.ok).length;
writeFileSync(resolve(here, 'paper-check-receipt.json'), JSON.stringify({ root, checkedAt: new Date().toISOString(), failures, results }, null, 2) + '\n');
for (const r of results) console.log(`${r.ok ? 'PASS' : 'FAIL'} ${r.name}${r.error ? ` (${r.error})` : ''}`);
console.log(`${results.length - failures}/${results.length} passed`);
process.exit(failures ? 1 : 0);
