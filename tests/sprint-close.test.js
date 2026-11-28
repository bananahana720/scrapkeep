import { after, describe, test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile, rm, mkdir, symlink } from "node:fs/promises";
import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { git as runGit } from "../scripts/lib/git.mjs";

const execFileAsync = promisify(execFile);
const CONCURRENCY = Math.max(2, Math.min(os.availableParallelism(), 8));
const script = fileURLToPath(new URL("../scripts/sprint-close.mjs", import.meta.url));
const hash = (data) => createHash("sha256").update(data).digest("hex");
const git = (root, ...args) => runGit(args, { cwd: root });
const EVIDENCE_BYTES = "synthetic test evidence only\n";
const EVIDENCE_SHA = hash(EVIDENCE_BYTES);

let sharedBaseRepoPromise = null;
let sharedPredRepoPromise = null;
let receiptDirPromise = null;
let receiptCounter = 0;

async function createRepo({ withPredecessor = false } = {}) {
  const root = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-close-"));
  git(root, "init", "--quiet");
  await writeFile(path.join(root, "source.txt"), "accepted source\n");
  git(root, "add", "source.txt");
  git(
    root,
    "-c",
    "user.name=Fixture",
    "-c",
    "user.email=fixture@example.invalid",
    "commit",
    "--quiet",
    "-m",
    "fixture",
  );
  const firstCommit = git(root, "rev-parse", "HEAD");
  let integratedCommit = firstCommit;
  if (withPredecessor) {
    git(
      root,
      "-c",
      "user.name=Fixture",
      "-c",
      "user.email=fixture@example.invalid",
      "commit",
      "--quiet",
      "--allow-empty",
      "-m",
      "current sprint",
    );
    integratedCommit = git(root, "rev-parse", "HEAD");
  }
  await mkdir(path.join(root, "evidence"));
  await writeFile(path.join(root, "evidence/result.txt"), EVIDENCE_BYTES);
  return { root, firstCommit, integratedCommit };
}

function getSharedBaseRepo() {
  return (sharedBaseRepoPromise ??= createRepo());
}

function getSharedPredRepo() {
  return (sharedPredRepoPromise ??= createRepo({ withPredecessor: true }));
}

function getReceiptDir() {
  return (receiptDirPromise ??= mkdtemp(path.join(os.tmpdir(), "scrapkeep-close-receipts-")));
}

after(async () => {
  const dirs = [];
  if (sharedBaseRepoPromise) dirs.push((await sharedBaseRepoPromise).root);
  if (sharedPredRepoPromise) dirs.push((await sharedPredRepoPromise).root);
  if (receiptDirPromise) dirs.push(await receiptDirPromise);
  await Promise.all(dirs.map((d) => rm(d, { recursive: true, force: true })));
});

function buildReceiptData(integratedCommit, scopeKind = "documentation-only") {
  const evidence = {
    path: "evidence/result.txt",
    sha256: EVIDENCE_SHA,
    sourceCommit: integratedCommit,
    status: "passed",
    method: "synthetic fixture comparison",
    limits: "No runtime or human qualification",
  };
  const ids =
    scopeKind === "native-proof"
      ? [
          "docs",
          "project",
          "scenario-review",
          "adr-harness",
          "linux-export",
          "windows-export",
          "linux-local",
          "linux-ci",
        ]
      : scopeKind === "gameplay"
        ? ["docs", "project", "automated-smoke", "human-playtest"]
        : ["docs", "project", "scenario-review"];
  const r = {
    schemaVersion: 1,
    sprintId: "EXAMPLE",
    integratedCommit,
    scopeKind,
    decisionOwner: "Coordinator",
    previousReceipt: null,
    authorization: { owner: "Andrew", reference: "synthetic authorization" },
    selectedTasks: [{ id: "EXAMPLE-01", revision: 1, state: "done" }],
    activeLeases: 0,
    gates: ids.map((id) => ({ id, required: true, status: "passed", evidence: [{ ...evidence }] })),
    gameplay: { applicable: false, reason: "No playable slice" },
    amendments: [],
    retroActions: [],
    groomingChanges: [],
    nextProposal: {
      status: "awaiting_review",
      approvalOwner: "Andrew",
      objective: "Review the next fixture",
      cards: [
        {
          id: "NEXT-01",
          revision: 1,
          size: "S",
          dependencies: [],
          questions: [],
          permittedActions: ["document"],
          acceptance: ["review passed"],
          inputReady: true,
          initialDispatch: true,
        },
      ],
    },
  };
  const scenario = r.gates.find((gate) => gate.id === "scenario-review");
  if (scenario)
    Object.assign(scenario.evidence[0], { independent: true, reviewer: "fixture reviewer" });
  if (scopeKind === "native-proof") {
    r.toolchain = {
      engineVersion: "synthetic engine",
      editorSha256: hash("editor"),
      templatesSha256: hash("templates"),
    };
    Object.assign(r.gates.find((g) => g.id === "linux-local").evidence[0], {
      visible: true,
      success: true,
      exitWorked: true,
    });
    Object.assign(r.gates.find((g) => g.id === "linux-ci").evidence[0], {
      runId: "fixture-run",
      toolchainIdentity: "fixture-toolchain",
    });
  }
  if (scopeKind === "gameplay") {
    r.gameplay = {
      applicable: true,
      objective: "synthetic playable objective",
      pillars: [{ id: "mastery", test: "synthetic mastery test" }],
    };
    Object.assign(r.gates.find((g) => g.id === "human-playtest").evidence[0], {
      kind: "human",
      observer: "Andrew",
      pillars: ["mastery"],
    });
  }
  return { r, evidence };
}

async function fixture(t, scopeKind = "documentation-only", { isolated = false } = {}) {
  const repo = isolated ? await createRepo() : await getSharedBaseRepo();
  if (isolated) t.after(() => rm(repo.root, { recursive: true, force: true }));
  const { r, evidence } = buildReceiptData(repo.integratedCommit, scopeKind);
  return { root: repo.root, r, evidence };
}

async function runCli(file, root) {
  try {
    const { stdout, stderr } = await execFileAsync(
      process.execPath,
      [script, file, "--root", root],
      {
        encoding: "utf8",
        timeout: 10000,
      },
    );
    return { status: 0, stdout, stderr };
  } catch (error) {
    assert.equal(error.signal, null, error.message);
    return { status: error.code, stdout: error.stdout ?? "", stderr: error.stderr ?? "" };
  }
}

async function run(root, r) {
  const dir = await getReceiptDir();
  const file = path.join(dir, `receipt-${++receiptCounter}.json`);
  await writeFile(file, typeof r === "string" ? r : JSON.stringify(r, null, 2));
  const child = await runCli(file, root);
  const result = JSON.parse(child.stdout);
  assert.equal(child.status, result.outcome === "passed" ? 0 : 1, child.stderr);
  return { result, stdout: child.stdout, file };
}

describe("sprint-close", { concurrency: CONCURRENCY }, () => {
  for (const scope of ["documentation-only", "native-proof", "gameplay"]) {
    test(scope + " complete fixture passes with a stable receipt identity", async (t) => {
      const { root, r } = await fixture(t, scope);
      const first = await run(root, r);
      const before = await readFile(first.file);
      const sourceBefore = await readFile(path.join(root, "source.txt"));
      const again = await runCli(first.file, root);
      assert.equal(first.result.outcome, "passed", first.stdout);
      assert.equal(again.status, 0, again.stdout);
      assert.equal(again.stdout, first.stdout);
      assert.deepEqual(await readFile(first.file), before);
      assert.deepEqual(await readFile(path.join(root, "source.txt")), sourceBefore);
      assert.equal(git(root, "status", "--porcelain", "--untracked-files=no"), "");
    });
  }

  const mutations = [
    [
      "missing independent reviewer",
      (r) => delete r.gates.find((g) => g.id === "scenario-review").evidence[0].independent,
      "pending_evidence",
      /independent scenario/,
    ],
    ["missing mandatory gate", (r) => r.gates.pop(), "pending_evidence", /missing mandatory gate/],
    [
      "optional mandatory gate",
      (r) => (r.gates[0].required = false),
      "failed",
      /cannot be optional/,
    ],
    ["missing evidence", (r) => (r.gates[0].evidence = []), "pending_evidence", /no evidence/],
    [
      "missing evidence file",
      (r) => (r.gates[0].evidence[0].path = "absent"),
      "pending_evidence",
      /missing or unreadable/,
    ],
    [
      "stale evidence commit",
      (r) => (r.gates[0].evidence[0].sourceCommit = "a".repeat(40)),
      "pending_evidence",
      /different commit/,
    ],
    [
      "stale evidence bytes",
      (r) => (r.gates[0].evidence[0].sha256 = "a".repeat(64)),
      "pending_evidence",
      /hash differs/,
    ],
    ["failed gate", (r) => (r.gates[0].status = "failed"), "failed", /gate failure/],
    [
      "failed evidence",
      (r) => (r.gates[0].evidence[0].status = "failed"),
      "failed",
      /evidence failure/,
    ],
    ["skipped gate", (r) => (r.gates[0].status = "skipped"), "pending_evidence", /not passed/],
    [
      "inconclusive gate",
      (r) => (r.gates[0].status = "inconclusive"),
      "pending_evidence",
      /not passed/,
    ],
    ["active lease", (r) => (r.activeLeases = 1), "pending_evidence", /leases/],
    [
      "incomplete task",
      (r) => (r.selectedTasks[0].state = "review"),
      "pending_evidence",
      /incomplete/,
    ],
    ["wrong closure authority", (r) => (r.decisionOwner = "Worker"), "failed", /coordinator/],
    ["wrong authorization", (r) => (r.authorization.owner = "Coordinator"), "failed", /Andrew/],
    ["unknown schema", (r) => (r.schemaVersion = 2), "failed", /schema version/],
    ["missing array", (r) => delete r.amendments, "failed", /array/],
    ["missing method", (r) => delete r.gates[0].evidence[0].method, "failed", /nonempty/],
    ["missing limits", (r) => delete r.gates[0].evidence[0].limits, "failed", /nonempty/],
    ["malformed status", (r) => (r.gates[0].status = "green"), "failed", /unknown gate status/],
    [
      "duplicate task",
      (r) => r.selectedTasks.push({ ...r.selectedTasks[0] }),
      "failed",
      /duplicate ID/,
    ],
    ["duplicate gate", (r) => r.gates.push({ ...r.gates[0] }), "failed", /duplicate ID/],
    [
      "too many proposed cards",
      (r) =>
        (r.nextProposal.cards = Array.from({ length: 5 }, (_, i) => ({
          ...r.nextProposal.cards[0],
          id: "NEXT-" + i,
        }))),
      "failed",
      /at most four/,
    ],
    ["large proposed card", (r) => (r.nextProposal.cards[0].size = "L"), "failed", /S or M/],
    [
      "blocked initial dispatch",
      (r) => (r.nextProposal.cards[0].inputReady = false),
      "failed",
      /blocked card/,
    ],
    [
      "unanswered initial question",
      (r) => (r.nextProposal.cards[0].questions = ["Q-01"]),
      "failed",
      /blocked card/,
    ],
    [
      "unresolved dependency",
      (r) => (r.nextProposal.cards[0].dependencies = ["MISSING"]),
      "failed",
      /dependency/,
    ],
    [
      "unauthorized next sprint",
      (r) => (r.nextProposal.status = "active"),
      "failed",
      /awaiting_review/,
    ],
    ["non-gameplay claim", (r) => (r.gameplay.applicable = true), "failed", /cannot claim/],
    [
      "path escape",
      (r) => (r.gates[0].evidence[0].path = "../outside.txt"),
      "failed",
      /inside the repository/,
    ],
  ];
  for (const [name, mutate, outcome, message] of mutations) {
    test(name + " cannot close the sprint", async (t) => {
      const { root, r } = await fixture(t);
      mutate(r);
      const { result, stdout } = await run(root, r);
      assert.equal(result.outcome, outcome, stdout);
      assert.ok(
        result.issues.some((issue) => message.test(issue.message)),
        stdout,
      );
    });
  }

  for (const state of ["proposed", "deferred", "accepted"]) {
    test(state + " applicable amendment blocks without admission", async (t) => {
      const { root, r, evidence } = await fixture(t);
      r.amendments.push({
        id: "AM-01",
        applicable: true,
        state,
        kind: "factual",
        decisionOwner: "Coordinator",
        reason: "fixture contradiction",
        affectedCards: [{ id: "EXAMPLE-01", revision: 1 }],
        decisionEvidence: evidence,
      });
      const { result } = await run(root, r);
      assert.equal(result.outcome, "pending_evidence");
    });
  }

  test("accepted amendment needs all source/card propagation and independent review", async (t) => {
    const { root, r, evidence } = await fixture(t);
    r.amendments = [
      {
        id: "AM-01",
        applicable: true,
        state: "accepted",
        kind: "architecture",
        decisionOwner: "Andrew",
        reason: "synthetic amendment",
        affectedCards: [{ id: "EXAMPLE-01", revision: 1 }],
        decisionEvidence: evidence,
        propagation: {
          sourceCommit: r.integratedCommit,
          sources: [{ path: "source.txt", sha256: hash("accepted source\n") }],
          cards: [{ id: "EXAMPLE-01", revision: 1 }],
          readinessChecked: true,
          reviewEvidence: { ...evidence, independent: true, reviewer: "fixture reviewer" },
        },
      },
    ];
    assert.equal((await run(root, r)).result.outcome, "passed");
    r.amendments[0].propagation.cards = [];
    assert.equal((await run(root, r)).result.outcome, "pending_evidence");
    r.amendments[0].decisionOwner = "Coordinator";
    assert.equal((await run(root, r)).result.outcome, "failed");
  });

  test("amendment cannot hide affected selected work as inapplicable", async (t) => {
    const { root, r } = await fixture(t);
    r.amendments = [
      {
        id: "AM-01",
        applicable: false,
        state: "deferred",
        kind: "factual",
        decisionOwner: "Coordinator",
        reason: "hidden",
        affectedCards: [{ id: "EXAMPLE-01", revision: 1 }],
      },
    ];
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
    const { root, r } = await fixture(t, "documentation-only", { isolated: true });
    r.integratedCommit = "b".repeat(40);
    assert.equal((await run(root, r)).result.outcome, "pending_evidence");
    r.integratedCommit = git(root, "rev-parse", "HEAD");
    await writeFile(path.join(root, "source.txt"), "changed\n");
    const { result } = await run(root, r);
    assert.ok(result.issues.some((i) => /dirty/.test(i.message)));
    assert.equal(result.outcome, "pending_evidence");
  });

  test("symlink escape fails closed", async (t) => {
    const { root, r } = await fixture(t, "documentation-only", { isolated: true });
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

  async function predecessorFixture() {
    const repo = await getSharedPredRepo();
    const { r, evidence } = buildReceiptData(repo.integratedCommit);
    r.completedPredecessors = [
      {
        id: "OLD-01",
        revision: 2,
        state: "done",
        acceptedCommit: repo.firstCommit,
        reconciliationEvidence: { ...evidence },
      },
    ];
    r.nextProposal.cards[0].dependencies = ["OLD-01"];
    return { root: repo.root, r, evidence };
  }

  test("a reconciled prior-sprint prerequisite enables initial dispatch without joining selectedTasks", async (t) => {
    const { root, r } = await predecessorFixture(t);
    const selected = structuredClone(r.selectedTasks);
    assert.notEqual(r.completedPredecessors[0].acceptedCommit, r.integratedCommit);
    const first = await run(root, r);
    assert.equal(first.result.outcome, "passed", first.stdout);
    assert.deepEqual(JSON.parse(await readFile(first.file, "utf8")).selectedTasks, selected);
    assert.equal((await run(root, r)).stdout, first.stdout);
  });

  const invalidPredecessors = [
    [
      "stale reconciliation commit",
      (p) => (p.reconciliationEvidence.sourceCommit = p.acceptedCommit),
      "pending_evidence",
      /different commit/,
    ],
    [
      "stale reconciliation bytes",
      (p) => (p.reconciliationEvidence.sha256 = "a".repeat(64)),
      "pending_evidence",
      /hash differs/,
    ],
    [
      "missing reconciliation",
      (p) => delete p.reconciliationEvidence,
      "pending_evidence",
      /missing current predecessor/,
    ],
    [
      "missing reconciliation file",
      (p) => (p.reconciliationEvidence.path = "absent"),
      "pending_evidence",
      /missing or unreadable/,
    ],
    ["missing predecessor state", (p) => delete p.state, "failed", /unknown predecessor state/],
    ["incomplete prior work", (p) => (p.state = "review"), "pending_evidence", /not complete/],
    [
      "skipped reconciliation",
      (p) => (p.reconciliationEvidence.status = "skipped"),
      "pending_evidence",
      /not passed/,
    ],
    [
      "failed reconciliation",
      (p) => (p.reconciliationEvidence.status = "failed"),
      "failed",
      /evidence failure/,
    ],
    [
      "unknown accepted commit",
      (p) => (p.acceptedCommit = "a".repeat(40)),
      "pending_evidence",
      /unavailable or not integrated/,
    ],
    [
      "malformed accepted identity",
      (p) => (p.acceptedCommit = "unknown"),
      "failed",
      /accepted commit SHA/,
    ],
    ["missing card revision", (p) => delete p.revision, "failed", /positive revision/],
  ];
  for (const [name, mutate, outcome, message] of invalidPredecessors) {
    test(name + " cannot admit an earlier-sprint dependency", async (t) => {
      const { root, r } = await predecessorFixture(t);
      mutate(r.completedPredecessors[0]);
      const { result, stdout } = await run(root, r);
      assert.equal(result.outcome, outcome, stdout);
      assert.ok(
        result.issues.some((issue) => message.test(issue.message)),
        stdout,
      );
    });
  }

  test("an unknown predecessor cannot be invented by a proposal dependency", async (t) => {
    const { root, r } = await predecessorFixture(t);
    r.nextProposal.cards[0].dependencies = ["UNKNOWN-01"];
    const { result, stdout } = await run(root, r);
    assert.equal(result.outcome, "failed", stdout);
    assert.ok(
      result.issues.some((issue) => /dependency is neither completed/.test(issue.message)),
      stdout,
    );
  });

  test("predecessor inventory rejects duplicates and overlap with selected deliveries", async (t) => {
    const { root, r } = await predecessorFixture(t);
    r.completedPredecessors.push({ ...r.completedPredecessors[0] });
    assert.equal((await run(root, r)).result.outcome, "failed");
    r.completedPredecessors.pop();
    r.completedPredecessors[0].id = r.selectedTasks[0].id;
    assert.equal((await run(root, r)).result.outcome, "failed");
  });
});
