import { createHash } from "node:crypto";
import { readFile, realpath } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { isMain } from "./lib/cli.mjs";

const defaults = {
  "documentation-only": ["docs", "project", "scenario-review"],
  "native-proof": [
    "docs",
    "project",
    "scenario-review",
    "adr-harness",
    "linux-export",
    "windows-export",
    "linux-local",
    "linux-ci",
  ],
  gameplay: ["docs", "project", "automated-smoke", "human-playtest"],
};
const statuses = ["passed", "failed", "pending_evidence", "skipped", "inconclusive"];
const taskStates = [
  "queued",
  "ready",
  "in_progress",
  "review",
  "changes_requested",
  "blocked",
  "done",
  "parked",
  "cancelled",
];
const sha = { test: (value) => typeof value === "string" && /^[a-f0-9]{64}$/.test(value) };
const commit = { test: (value) => typeof value === "string" && /^[a-f0-9]{40}$/.test(value) };
const digest = (bytes) => createHash("sha256").update(bytes).digest("hex");
const text = (value) => typeof value === "string" && value.trim().length > 0;
const object = (value) => value !== null && typeof value === "object" && !Array.isArray(value);

export async function checkReceipt(receipt, { root, receiptHash }) {
  const issues = [];
  const fail = (field, message) => issues.push({ outcome: "failed", field, message });
  const pending = (field, message) => issues.push({ outcome: "pending_evidence", field, message });
  const require = (condition, field, message) => {
    if (!condition) fail(field, message);
    return condition;
  };
  const array = (value, field) =>
    require(Array.isArray(value), field, "expected an array") ? value : [];
  const record = (value, field) =>
    require(object(value), field, "expected an object") ? value : {};
  const string = (value, field) => require(text(value), field, "expected nonempty text");
  const revision = (value, field) =>
    require(Number.isInteger(value) && value > 0, field, "expected a positive revision");
  const unique = (items, field) => {
    const seen = new Set();
    for (const item of items) {
      string(item?.id, field + ".id");
      if (seen.has(item?.id)) fail(field, "duplicate ID " + item?.id);
      seen.add(item?.id);
    }
  };
  const r = record(receipt, "receipt");
  require(r.schemaVersion === 1, "schemaVersion", "only schema version 1 is supported");
  string(r.sprintId, "sprintId");
  require(commit.test(r.integratedCommit), "integratedCommit", "expected a full commit SHA");
  require(typeof r.scopeKind === "string" &&
    Object.hasOwn(defaults, r.scopeKind), "scopeKind", "unknown scope kind");
  require(r.decisionOwner ===
    "Coordinator", "decisionOwner", "only the coordinator records closure");
  require(r.previousReceipt === null ||
    sha.test(r.previousReceipt), "previousReceipt", "expected null or prior receipt SHA256");
  const authorization = record(r.authorization, "authorization");
  require(authorization.owner ===
    "Andrew", "authorization.owner", "scope authorization belongs to Andrew");
  string(authorization.reference, "authorization.reference");
  let rootPath;
  try {
    rootPath = await realpath(root);
    const head = execFileSync("git", ["-C", rootPath, "rev-parse", "HEAD"], {
      encoding: "utf8",
    }).trim();
    if (head !== r.integratedCommit)
      pending("integratedCommit", "checkout HEAD differs from tested commit");
    const dirty = execFileSync(
      "git",
      ["-C", rootPath, "status", "--porcelain", "--untracked-files=no"],
      { encoding: "utf8" },
    );
    if (dirty.trim()) pending("worktree", "tracked worktree is dirty");
  } catch {
    pending("root", "cannot verify repository identity and tracked cleanliness");
  }

  async function fileIdentity(value, field) {
    const file = record(value, field);
    string(file.path, field + ".path");
    require(sha.test(file.sha256), field + ".sha256", "expected SHA256");
    if (!rootPath || !text(file.path)) return;
    const target = path.resolve(rootPath, file.path);
    if (path.isAbsolute(file.path) || path.relative(rootPath, target).startsWith("..")) {
      fail(field + ".path", "evidence must stay inside the repository");
      return;
    }
    try {
      const actual = await realpath(target);
      if (path.relative(rootPath, actual).startsWith("..")) {
        fail(field + ".path", "evidence symlink escapes the repository");
        return;
      }
      if (digest(await readFile(actual)) !== file.sha256)
        pending(field, "evidence hash differs from recorded bytes");
    } catch {
      pending(field, "evidence file is missing or unreadable");
    }
  }

  async function evidence(value, field) {
    const e = record(value, field);
    await fileIdentity(e, field);
    require(commit.test(e.sourceCommit), field + ".sourceCommit", "expected a full commit SHA");
    if (e.sourceCommit !== r.integratedCommit)
      pending(field, "evidence belongs to a different commit");
    string(e.method, field + ".method");
    string(e.limits, field + ".limits");
    require(statuses.includes(e.status), field + ".status", "unknown evidence status");
    if (e.status === "failed") fail(field, "observed evidence failure");
    else if (e.status !== "passed") pending(field, "required evidence is not passed");
    return e;
  }

  const tasks = array(r.selectedTasks, "selectedTasks");
  require(tasks.length > 0, "selectedTasks", "select at least one delivery task");
  unique(tasks, "selectedTasks");
  for (const [index, value] of tasks.entries()) {
    const field = `selectedTasks[${index}]`;
    const task = record(value, field);
    revision(task.revision, field + ".revision");
    require(taskStates.includes(task.state), field + ".state", "unknown task state");
    if (task.state !== "done") pending(field, "selected delivery task is incomplete");
  }
  const completed = new Set(tasks.filter((task) => task?.state === "done").map((task) => task.id));
  const predecessors =
    r.completedPredecessors === undefined
      ? []
      : array(r.completedPredecessors, "completedPredecessors");
  unique(predecessors, "completedPredecessors");
  const predecessorIds = new Set(predecessors.map((task) => task?.id));
  for (const [index, value] of predecessors.entries()) {
    const field = `completedPredecessors[${index}]`;
    const firstIssue = issues.length;
    const predecessor = record(value, field);
    revision(predecessor.revision, field + ".revision");
    require(!tasks.some(
      (task) => task?.id === predecessor.id,
    ), field, "predecessor must be separate from selected delivery tasks");
    require(taskStates.includes(predecessor.state), field + ".state", "unknown predecessor state");
    if (predecessor.state !== "done") pending(field, "predecessor is not complete");
    if (
      require(commit.test(predecessor.acceptedCommit), field +
        ".acceptedCommit", "expected a full accepted commit SHA") &&
      rootPath
    ) {
      try {
        execFileSync(
          "git",
          ["-C", rootPath, "merge-base", "--is-ancestor", predecessor.acceptedCommit, "HEAD"],
          { stdio: "ignore" },
        );
      } catch {
        pending(
          field,
          "accepted predecessor commit is unavailable or not integrated into this checkout",
        );
      }
    }
    if (!predecessor.reconciliationEvidence)
      pending(field, "missing current predecessor reconciliation evidence");
    else await evidence(predecessor.reconciliationEvidence, field + ".reconciliationEvidence");
    if (issues.length === firstIssue && rootPath) completed.add(predecessor.id);
  }
  require(Number.isInteger(r.activeLeases) &&
    r.activeLeases >= 0, "activeLeases", "expected a nonnegative count");
  if (r.activeLeases !== 0) pending("activeLeases", "all write leases must be reconciled");

  const gates = array(r.gates, "gates");
  unique(gates, "gates");
  const mandatory = defaults[r.scopeKind] ?? [];
  for (const id of mandatory) {
    if (!gates.some((gate) => gate?.id === id)) pending("gates", "missing mandatory gate " + id);
  }
  for (const [index, value] of gates.entries()) {
    const field = `gates[${index}]`;
    const gate = record(value, field);
    require(typeof gate.required === "boolean", field + ".required", "expected a boolean");
    require(statuses.includes(gate.status), field + ".status", "unknown gate status");
    if (mandatory.includes(gate.id))
      require(gate.required === true, field + ".required", "mandatory gate cannot be optional");
    const required = gate.required === true || mandatory.includes(gate.id);
    const entries = array(gate.evidence, field + ".evidence");
    if (!required) {
      string(gate.reason, field + ".reason");
      continue;
    }
    if (gate.status === "failed") fail(field, "observed required gate failure");
    else if (gate.status !== "passed") pending(field, "required gate is not passed");
    if (entries.length === 0) pending(field, "required gate has no evidence");
    for (const [offset, entry] of entries.entries())
      await evidence(entry, `${field}.evidence[${offset}]`);
    if (
      gate.id === "scenario-review" &&
      !entries.some((e) => e?.independent === true && text(e?.reviewer))
    ) {
      pending(field, "independent scenario reviewer identity is required");
    }
    if (
      gate.id === "linux-local" &&
      r.scopeKind === "native-proof" &&
      !entries.some((e) => e?.visible === true && e?.success === true && e?.exitWorked === true)
    ) {
      pending(field, "visible local launch, success, and working exit evidence are required");
    }
    if (
      gate.id === "linux-ci" &&
      r.scopeKind === "native-proof" &&
      !entries.some((e) => text(e?.runId) && text(e?.toolchainIdentity))
    ) {
      pending(field, "CI run and toolchain identities are required");
    }
  }

  const gameplay = record(r.gameplay, "gameplay");
  if (r.scopeKind === "gameplay") {
    require(gameplay.applicable ===
      true, "gameplay.applicable", "gameplay scope requires human qualification");
    string(gameplay.objective, "gameplay.objective");
    const pillars = array(gameplay.pillars, "gameplay.pillars");
    require(pillars.length > 0, "gameplay.pillars", "declare applicable Bible Pillars tests");
    unique(pillars, "gameplay.pillars");
    for (const pillar of pillars) {
      string(pillar?.test, "gameplay.pillars.test");
      const human = gates.find((g) => g?.id === "human-playtest");
      if (
        !human?.evidence?.some(
          (e) =>
            e?.kind === "human" &&
            e?.observer === "Andrew" &&
            Array.isArray(e?.pillars) &&
            e.pillars.includes(pillar.id),
        )
      ) {
        pending("gameplay.pillars", "missing Andrew human evidence for " + pillar?.id);
      }
    }
  } else {
    require(gameplay.applicable ===
      false, "gameplay.applicable", "non-gameplay proof cannot claim a gameplay pass");
    string(gameplay.reason, "gameplay.reason");
  }
  if (r.scopeKind === "native-proof") {
    const toolchain = record(r.toolchain, "toolchain");
    string(toolchain.engineVersion, "toolchain.engineVersion");
    require(sha.test(toolchain.editorSha256), "toolchain.editorSha256", "expected editor SHA256");
    require(sha.test(
      toolchain.templatesSha256,
    ), "toolchain.templatesSha256", "expected template SHA256");
  }

  const amendments = array(r.amendments, "amendments");
  unique(amendments, "amendments");
  for (const [index, value] of amendments.entries()) {
    const field = `amendments[${index}]`;
    const amendment = record(value, field);
    require(typeof amendment.applicable === "boolean", field + ".applicable", "expected a boolean");
    require(["proposed", "accepted", "rejected", "deferred"].includes(amendment.state), field +
      ".state", "unknown amendment state");
    require(["implementation", "factual", "architecture", "product"].includes(
      amendment.kind,
    ), field + ".kind", "unknown amendment kind");
    const owner = ["architecture", "product"].includes(amendment.kind) ? "Andrew" : "Coordinator";
    require(amendment.decisionOwner === owner, field + ".decisionOwner", "decision belongs to " +
      owner);
    string(amendment.reason, field + ".reason");
    const affected = array(amendment.affectedCards, field + ".affectedCards");
    unique(affected, field + ".affectedCards");
    for (const card of affected) revision(card?.revision, field + ".affectedCards.revision");
    if (
      amendment.applicable === false &&
      affected.some((card) => tasks.some((task) => task?.id === card?.id))
    ) {
      fail(field + ".applicable", "amendment affects a selected delivery task");
    }
    if (amendment.applicable !== true) continue;
    if (["proposed", "deferred"].includes(amendment.state)) {
      pending(field, "applicable amendment remains unresolved");
      continue;
    }
    if (!amendment.decisionEvidence) pending(field, "missing decision evidence");
    else await evidence(amendment.decisionEvidence, field + ".decisionEvidence");
    if (amendment.state === "rejected") {
      require(amendment.readinessChecked === true, field +
        ".readinessChecked", "rejected request needs readiness recheck");
      continue;
    }
    if (!amendment.propagation) {
      pending(field, "accepted amendment has not been admitted");
      continue;
    }
    const propagation = record(amendment.propagation, field + ".propagation");
    if (propagation.sourceCommit !== r.integratedCommit)
      pending(field, "propagation does not identify the integrated commit");
    const sources = array(propagation.sources, field + ".propagation.sources");
    require(sources.length > 0, field +
      ".propagation.sources", "accepted amendment needs authoritative source propagation");
    for (const [offset, source] of sources.entries())
      await fileIdentity(source, `${field}.propagation.sources[${offset}]`);
    const cards = array(propagation.cards, field + ".propagation.cards");
    unique(cards, field + ".propagation.cards");
    for (const card of cards) revision(card?.revision, field + ".propagation.cards.revision");
    for (const card of affected) {
      if (
        !cards.some((admitted) => admitted?.id === card?.id && admitted.revision === card.revision)
      )
        pending(field, "affected card revision not propagated: " + card?.id);
      const selected = tasks.find((task) => task?.id === card?.id);
      if (selected && selected.revision !== card.revision)
        pending(field, "selected task uses a different card revision: " + card.id);
    }
    if (!propagation.reviewEvidence) pending(field, "missing independent propagation review");
    else {
      require(propagation.reviewEvidence.independent === true, field +
        ".propagation.reviewEvidence.independent", "review must be independent");
      string(propagation.reviewEvidence.reviewer, field + ".propagation.reviewEvidence.reviewer");
      await evidence(propagation.reviewEvidence, field + ".propagation.reviewEvidence");
    }
    require(propagation.readinessChecked === true, field +
      ".propagation.readinessChecked", "admission needs readiness recheck");
  }

  for (const name of ["retroActions", "groomingChanges"]) {
    for (const [index, value] of array(r[name], name).entries()) {
      const action = record(value, `${name}[${index}]`);
      string(action.cause, name + ".cause");
      string(action.disposition, name + ".disposition");
      string(action.reference, name + ".reference");
    }
  }
  const proposal = record(r.nextProposal, "nextProposal");
  require(proposal.status ===
    "awaiting_review", "nextProposal.status", "proposal must remain awaiting_review");
  require(proposal.approvalOwner ===
    "Andrew", "nextProposal.approvalOwner", "next scope needs Andrew's approval");
  string(proposal.objective, "nextProposal.objective");
  const cards = array(proposal.cards, "nextProposal.cards");
  require(cards.length <= 4, "nextProposal.cards", "at most four proposed cards");
  unique(cards, "nextProposal.cards");
  for (const [index, value] of cards.entries()) {
    const field = `nextProposal.cards[${index}]`;
    const card = record(value, field);
    revision(card.revision, field + ".revision");
    require(["S", "M"].includes(card.size), field + ".size", "proposed cards must be S or M");
    require(typeof card.inputReady === "boolean", field + ".inputReady", "expected a boolean");
    require(typeof card.initialDispatch === "boolean", field +
      ".initialDispatch", "expected a boolean");
    const dependencies = array(card.dependencies, field + ".dependencies");
    const questions = array(card.questions, field + ".questions");
    for (const item of [...dependencies, ...questions])
      string(item, field + ".dependencies/questions");
    for (const name of ["permittedActions", "acceptance"]) {
      const items = array(card[name], field + "." + name);
      require(items.length > 0, field + "." + name, "required card contract is empty");
      for (const item of items) string(item, field + "." + name);
    }
    for (const dependency of dependencies) {
      if (
        !completed.has(dependency) &&
        !cards.slice(0, index).some((item) => item?.id === dependency)
      ) {
        if (predecessorIds.has(dependency))
          pending(field, "predecessor dependency lacks valid completion evidence: " + dependency);
        else fail(field, "dependency is neither completed nor earlier in proposal: " + dependency);
      }
    }
    if (card.initialDispatch) {
      if (
        !card.inputReady ||
        questions.length ||
        dependencies.some((id) => !completed.has(id) && !predecessorIds.has(id))
      ) {
        fail(field, "initial dispatch contains a blocked card");
      }
      if (dependencies.some((id) => predecessorIds.has(id) && !completed.has(id)))
        pending(field, "initial dispatch awaits predecessor reconciliation");
    }
  }

  const outcome = issues.some((issue) => issue.outcome === "failed")
    ? "failed"
    : issues.length
      ? "pending_evidence"
      : "passed";
  return {
    schemaVersion: 1,
    receiptId: receiptHash,
    closureKey: digest(`${r.sprintId}\n${r.integratedCommit}`),
    sprintId: r.sprintId ?? null,
    integratedCommit: r.integratedCommit ?? null,
    outcome,
    issues,
    limits:
      "Checks receipt structure, local evidence bytes, commit identity, and recorded authority. Does not authenticate statements, discover omitted tasks/amendments, execute gates, or mutate canonical records.",
  };
}

async function main(argv) {
  let root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  if (argv.length !== 1 && !(argv.length === 3 && argv[1] === "--root"))
    throw new Error("Usage: node scripts/sprint-close.mjs <receipt.json> [--root <checkout>]");
  if (argv[2]) root = path.resolve(argv[2]);
  const bytes = await readFile(path.resolve(argv[0]));
  const receiptHash = digest(bytes);
  let receipt;
  try {
    receipt = JSON.parse(bytes.toString("utf8"));
  } catch {
    console.log(
      JSON.stringify(
        {
          schemaVersion: 1,
          receiptId: receiptHash,
          outcome: "failed",
          issues: [{ field: "receipt", message: "invalid JSON" }],
        },
        null,
        2,
      ),
    );
    process.exitCode = 1;
    return;
  }
  const result = await checkReceipt(receipt, { root, receiptHash });
  console.log(JSON.stringify(result, null, 2));
  process.exitCode = result.outcome === "passed" ? 0 : 1;
}

if (isMain(import.meta.url)) {
  try {
    await main(process.argv.slice(2));
  } catch (error) {
    console.log(
      JSON.stringify(
        {
          schemaVersion: 1,
          outcome: "failed",
          issues: [{ field: "checker", message: error.message }],
        },
        null,
        2,
      ),
    );
    process.exitCode = 1;
  }
}
