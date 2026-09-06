import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile, rm, mkdir, symlink } from "node:fs/promises";
import { createHash } from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

const script = fileURLToPath(new URL("../scripts/sprint-close.mjs", import.meta.url));
const hash = (data) => createHash("sha256").update(data).digest("hex");
const git = (root, ...args) => execFileSync("git", ["-C", root, ...args], { encoding: "utf8" }).trim();

async function fixture(t, scopeKind = "documentation-only") {
  const root = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-close-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  git(root, "init", "--quiet");
  await writeFile(path.join(root, "source.txt"), "accepted source\n");
  git(root, "add", "source.txt");
  git(root, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--quiet", "-m", "fixture");
  const integratedCommit = git(root, "rev-parse", "HEAD");
  await mkdir(path.join(root, "evidence"));
  const bytes = "synthetic test evidence only\n";
  await writeFile(path.join(root, "evidence/result.txt"), bytes);
  const evidence = { path: "evidence/result.txt", sha256: hash(bytes), sourceCommit: integratedCommit, status: "passed", method: "synthetic fixture comparison", limits: "No runtime or human qualification" };
  const ids = scopeKind === "native-proof"
    ? ["docs", "project", "scenario-review", "adr-harness", "linux-export", "windows-export", "linux-local", "linux-ci"]
    : scopeKind === "gameplay" ? ["docs", "project", "automated-smoke", "human-playtest"] : ["docs", "project", "scenario-review"];
  const r = {
    schemaVersion: 1, sprintId: "EXAMPLE", integratedCommit, scopeKind,
    decisionOwner: "Coordinator", previousReceipt: null,
    authorization: { owner: "Andrew", reference: "synthetic authorization" },
    selectedTasks: [{ id: "EXAMPLE-01", revision: 1, state: "done" }], activeLeases: 0,
    gates: ids.map((id) => ({ id, required: true, status: "passed", evidence: [{ ...evidence }] })),
    gameplay: { applicable: false, reason: "No playable slice" },
    amendments: [], retroActions: [], groomingChanges: [],
    nextProposal: { status: "awaiting_review", approvalOwner: "Andrew", objective: "Review the next fixture", cards: [{ id: "NEXT-01", revision: 1, size: "S", dependencies: [], questions: [], permittedActions: ["document"], acceptance: ["review passed"], inputReady: true, initialDispatch: true }] },
  };
  const scenario = r.gates.find((gate) => gate.id === "scenario-review");
  if (scenario) Object.assign(scenario.evidence[0], { independent: true, reviewer: "fixture reviewer" });
  if (scopeKind === "native-proof") {
    r.toolchain = { engineVersion: "synthetic engine", editorSha256: hash("editor"), templatesSha256: hash("templates") };
    Object.assign(r.gates.find((g) => g.id === "linux-local").evidence[0], { visible: true, success: true, exitWorked: true });
    Object.assign(r.gates.find((g) => g.id === "linux-ci").evidence[0], { runId: "fixture-run", toolchainIdentity: "fixture-toolchain" });
  }
  if (scopeKind === "gameplay") {
    r.gameplay = { applicable: true, objective: "synthetic playable objective", pillars: [{ id: "mastery", test: "synthetic mastery test" }] };
    Object.assign(r.gates.find((g) => g.id === "human-playtest").evidence[0], { kind: "human", observer: "Andrew", pillars: ["mastery"] });
  }
  return { root, r, evidence };
}

async function run(root, r) {
  const file = path.join(root, "receipt.json");
  await writeFile(file, typeof r === "string" ? r : JSON.stringify(r, null, 2));
  const child = spawnSync(process.execPath, [script, file, "--root", root], { encoding: "utf8", timeout: 10000 });
  assert.equal(child.error, undefined);
  const result = JSON.parse(child.stdout);
  assert.equal(child.status, result.outcome === "passed" ? 0 : 1, child.stderr);
  return { result, stdout: child.stdout, file };
}

for (const scope of ["documentation-only", "native-proof", "gameplay"]) {
  test(scope + " complete fixture passes with a stable receipt identity", async (t) => {
    const { root, r } = await fixture(t, scope);
    const first = await run(root, r);
    const before = await readFile(first.file);
    const sourceBefore = await readFile(path.join(root, "source.txt"));
    const again = spawnSync(process.execPath, [script, first.file, "--root", root], { encoding: "utf8" });
    assert.equal(first.result.outcome, "passed", first.stdout);
    assert.equal(again.status, 0, again.stdout);
    assert.equal(again.stdout, first.stdout);
    assert.deepEqual(await readFile(first.file), before);
    assert.deepEqual(await readFile(path.join(root, "source.txt")), sourceBefore);
    assert.equal(git(root, "status", "--porcelain", "--untracked-files=no"), "");
  });
}

const mutations = [
  ["missing independent reviewer", (r) => delete r.gates.find((g) => g.id === "scenario-review").evidence[0].independent, "pending_evidence", /independent scenario/],
  ["missing mandatory gate", (r) => r.gates.pop(), "pending_evidence", /missing mandatory gate/],
  ["optional mandatory gate", (r) => r.gates[0].required = false, "failed", /cannot be optional/],
  ["missing evidence", (r) => r.gates[0].evidence = [], "pending_evidence", /no evidence/],
  ["missing evidence file", (r) => r.gates[0].evidence[0].path = "absent", "pending_evidence", /missing or unreadable/],
  ["stale evidence commit", (r) => r.gates[0].evidence[0].sourceCommit = "a".repeat(40), "pending_evidence", /different commit/],
  ["stale evidence bytes", (r) => r.gates[0].evidence[0].sha256 = "a".repeat(64), "pending_evidence", /hash differs/],
  ["failed gate", (r) => r.gates[0].status = "failed", "failed", /gate failure/],
  ["failed evidence", (r) => r.gates[0].evidence[0].status = "failed", "failed", /evidence failure/],
  ["skipped gate", (r) => r.gates[0].status = "skipped", "pending_evidence", /not passed/],
  ["inconclusive gate", (r) => r.gates[0].status = "inconclusive", "pending_evidence", /not passed/],
  ["active lease", (r) => r.activeLeases = 1, "pending_evidence", /leases/],
  ["incomplete task", (r) => r.selectedTasks[0].state = "review", "pending_evidence", /incomplete/],
  ["wrong closure authority", (r) => r.decisionOwner = "Worker", "failed", /coordinator/],
  ["wrong authorization", (r) => r.authorization.owner = "Coordinator", "failed", /Andrew/],
  ["unknown schema", (r) => r.schemaVersion = 2, "failed", /schema version/],
  ["missing array", (r) => delete r.amendments, "failed", /array/],
  ["missing method", (r) => delete r.gates[0].evidence[0].method, "failed", /nonempty/],
  ["missing limits", (r) => delete r.gates[0].evidence[0].limits, "failed", /nonempty/],
  ["malformed status", (r) => r.gates[0].status = "green", "failed", /unknown gate status/],
  ["duplicate task", (r) => r.selectedTasks.push({ ...r.selectedTasks[0] }), "failed", /duplicate ID/],
  ["duplicate gate", (r) => r.gates.push({ ...r.gates[0] }), "failed", /duplicate ID/],
  ["too many proposed cards", (r) => r.nextProposal.cards = Array.from({ length: 5 }, (_, i) => ({ ...r.nextProposal.cards[0], id: "NEXT-" + i })), "failed", /at most four/],
  ["large proposed card", (r) => r.nextProposal.cards[0].size = "L", "failed", /S or M/],
  ["blocked initial dispatch", (r) => r.nextProposal.cards[0].inputReady = false, "failed", /blocked card/],
  ["unanswered initial question", (r) => r.nextProposal.cards[0].questions = ["Q-01"], "failed", /blocked card/],
  ["unresolved dependency", (r) => r.nextProposal.cards[0].dependencies = ["MISSING"], "failed", /dependency/],
  ["unauthorized next sprint", (r) => r.nextProposal.status = "active", "failed", /awaiting_review/],
  ["non-gameplay claim", (r) => r.gameplay.applicable = true, "failed", /cannot claim/],
  ["path escape", (r) => r.gates[0].evidence[0].path = "../outside.txt", "failed", /inside the repository/],
];
for (const [name, mutate, outcome, message] of mutations) {
  test(name + " cannot close the sprint", async (t) => {
    const { root, r } = await fixture(t);
    mutate(r);
    const { result, stdout } = await run(root, r);
    assert.equal(result.outcome, outcome, stdout);
    assert.ok(result.issues.some((issue) => message.test(issue.message)), stdout);
  });
}

for (const state of ["proposed", "deferred", "accepted"]) {
  test(state + " applicable amendment blocks without admission", async (t) => {
    const { root, r, evidence } = await fixture(t);
    r.amendments.push({ id: "AM-01", applicable: true, state, kind: "factual", decisionOwner: "Coordinator", reason: "fixture contradiction", affectedCards: [{ id: "EXAMPLE-01", revision: 1 }], decisionEvidence: evidence });
    const { result } = await run(root, r);
    assert.equal(result.outcome, "pending_evidence");
  });
}

test("accepted amendment needs all source/card propagation and independent review", async (t) => {
  const { root, r, evidence } = await fixture(t);
  r.amendments = [{ id: "AM-01", applicable: true, state: "accepted", kind: "architecture", decisionOwner: "Andrew", reason: "synthetic amendment", affectedCards: [{ id: "EXAMPLE-01", revision: 1 }], decisionEvidence: evidence, propagation: { sourceCommit: r.integratedCommit, sources: [{ path: "source.txt", sha256: hash("accepted source\n") }], cards: [{ id: "EXAMPLE-01", revision: 1 }], readinessChecked: true, reviewEvidence: { ...evidence, independent: true, reviewer: "fixture reviewer" } } }];
  assert.equal((await run(root, r)).result.outcome, "passed");
  r.amendments[0].propagation.cards = [];
  assert.equal((await run(root, r)).result.outcome, "pending_evidence");
  r.amendments[0].decisionOwner = "Coordinator";
  assert.equal((await run(root, r)).result.outcome, "failed");
});

test("amendment cannot hide affected selected work as inapplicable", async (t) => {
  const { root, r } = await fixture(t);
  r.amendments = [{ id: "AM-01", applicable: false, state: "deferred", kind: "factual", decisionOwner: "Coordinator", reason: "hidden", affectedCards: [{ id: "EXAMPLE-01", revision: 1 }] }];
  assert.equal((await run(root, r)).result.outcome, "failed");
});

test("gameplay needs human evidence for each declared Pillar", async (t) => {
  const { root, r } = await fixture(t, "gameplay");
  const human = r.gates.find((g) => g.id === "human-playtest");
  human.evidence[0].observer = "Agent";
  assert.equal((await run(root, r)).result.outcome, "pending_evidence");
  human.evidence[0].observer = "Andrew";
  r.gameplay.pillars.push({ id: "discovery", test: "discover a meaningful route" });
  assert.equal((await run(root, r)).result.outcome, "pending_evidence");
});

test("native proof requires exports, visible exit and CI identities", async (t) => {
  const { root, r } = await fixture(t, "native-proof");
  r.gates.find((g) => g.id === "linux-local").evidence[0].exitWorked = false;
  delete r.gates.find((g) => g.id === "linux-ci").evidence[0].runId;
  r.gates = r.gates.filter((g) => g.id !== "windows-export");
  const { result } = await run(root, r);
  assert.equal(result.outcome, "pending_evidence");
  assert.ok(result.issues.some((i) => /working exit/.test(i.message)));
  assert.ok(result.issues.some((i) => /CI run/.test(i.message)));
  assert.ok(result.issues.some((i) => /windows-export/.test(i.message)));
});

test("stale checkout and dirty tracked source prevent closure", async (t) => {
  const { root, r } = await fixture(t);
  r.integratedCommit = "b".repeat(40);
  assert.equal((await run(root, r)).result.outcome, "pending_evidence");
  r.integratedCommit = git(root, "rev-parse", "HEAD");
  await writeFile(path.join(root, "source.txt"), "changed\n");
  const { result } = await run(root, r);
  assert.ok(result.issues.some((i) => /dirty/.test(i.message)));
  assert.equal(result.outcome, "pending_evidence");
});

test("symlink escape fails closed", async (t) => {
  const { root, r } = await fixture(t);
  await symlink(os.tmpdir(), path.join(root, "outside"));
  r.gates[0].evidence[0].path = "outside";
  assert.equal((await run(root, r)).result.outcome, "failed");
});

for (const malformed of ["{", "null", "[]", "42", '{"schemaVersion":1,"gates":[null]}']) {
  test("malformed receipt " + malformed + " fails closed", async (t) => {
    const { root } = await fixture(t);
    assert.equal((await run(root, malformed)).result.outcome, "failed");
  });
}
