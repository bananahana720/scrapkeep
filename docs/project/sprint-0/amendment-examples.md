# Synthetic specification amendment examples

These four worked packets are fictional exercises for [S0-11](../../../BACKLOG.md#s0-11). None is a live request, accepted decision, reported defect, or admission receipt. `EXAMPLE-*` identities and every described observation, ruling, candidate, and event are synthetic. Do not import them into TRACKING as real decisions.

The accepted clauses cited below were read at `1eb4a220fb48de80efded0a6459c98020fb7ed26`. Candidate clauses appear inline as fixtures, so each exercise is reproducible by comparing the quoted fixture with its linked source. No runtime was executed for these examples. They demonstrate [the amendment packet](amendment-request.md) under the [contradiction rule](../../../ORCHESTRATOR.md#specification-contradictions).

All packets have request revision 1, illustrative timestamp `2026-09-06T00:00:00Z`, fictional requester `example-worker`, and a fictional isolated attempt with no real lease. Referenced card revisions describe the exercise's input contract, not a dispatch or change to those cards. Unaffected work means only existing, independently authorized leases.

## Implementation defect returns for repair

### Context and evidence

`EXAMPLE-DEFECT` concerns a candidate for [S0-07 revision 1](../../../BACKLOG.md#s0-07). Its dependent [S0-08 revision 1](../../../BACKLOG.md#s0-08) cannot rely on the broken result. Both real cards are already completed. This exercise assumes a separately authorized reopen that retains the original completion evidence. Stop the candidate's durability claim. Unrelated leased documentation may continue.

Clause A is [TADR-004, Decision](../../../adr/TADR-004-persistence.md#decision), which requires a failed critical write to hold the transition and forbids reporting successful saving while durability is unknown.

Clause B is the inline candidate fixture `write_result = failure; acknowledgement = saved; transition = resumed`. The synthetic review observes that the fixture acknowledges success after a failed write. The expected state is a recoverable save error with the transition held. This is a source-and-fixture comparison, not a finding in the actual persistence proof.

### Proposal and compatibility

The worker proposes weakening TADR-004 to permit a successful acknowledgement before the write completes. The coordinator classifies the mismatch as an implementation defect because the accepted requirement is unambiguous.

Repairing the candidate to hold the transition satisfies the source. Weakening the source would lose the durability guarantee. Suppressing the error message while still resuming would leave the same defect. The selected synthetic disposition is candidate repair under the unchanged contract.

No authoritative clause or card revision changes. Save semantics stay intact. Browser data, native proof ownership, and content identities remain unchanged. Retain the failed attempt as evidence and rerun the card's failed-write checks after repair.

### Decision, admission, and closure

The fictional coordinator rejects `EXAMPLE-DEFECT` as a source amendment and returns the candidate through `changes_requested`. The decision rationale is the direct conflict with TADR-004. Source/card propagation is not applicable because the contract is unchanged.

Repair remains pending. Its future handoff must name the repaired candidate, independent reviewer/verdict, integrated commit, and required verification receipts. S0-08 remains blocked until the prerequisite is accepted and readiness is checked. A rejected request does not itself unblock either card.

The closure exercise fails to reach `passed` while the selected repair task is incomplete. No real event, candidate commit, review, or integration is claimed.

## Factual correction preserves the accepted engine

### Context and evidence

`EXAMPLE-FACT` concerns [S0-12 revision 1](../../../BACKLOG.md#s0-12) and its dependent [S0-13 revision 1](../../../BACKLOG.md#s0-13). Stop the affected toolchain wording and export handoff. Independently leased amendment documentation may continue.

Clause A is [TADR-001, Decision](../../../adr/TADR-001-engine-language-platforms.md#decision), which pins Godot 4.7.2 standard edition with matching export templates.

Clause B is an invented current toolchain sentence for `docs/tech/native-toolchain.md`, `The proof uses Godot 4.7.1.` The exercise's inline observation fixture says `editor_version=4.7.2; template_version=4.7.2`. A comparison finds a one-version documentation typo. These strings are synthetic evidence, not actual command output or a claim about the current file.

### Proposal and compatibility

The proposed replacement is `The proof uses Godot 4.7.2 with matching export templates.` The exercise also assumes S0-12 revision 1 copied the same typo into its input description. Its proposed revision 2 corrects only that version. S0-13's proposed revision 2 references the corrected S0-12 input. Acceptance behavior and verification commands stay unchanged.

Correcting both descriptions preserves the accepted engine. Downgrading the installed engine to match the typo would change the accepted direction and is outside coordinator authority. Leaving the typo would preserve contradictory dispatch inputs. No ADR change is needed because the ADR already states the correct version.

This correction changes no gameplay, data format, browser proof, or production platform promise. Existing evidence retains its original identity. The coordinator must verify real editor/template identities before using this pattern for a real request.

### Decision, admission, and closure

The fictional coordinator accepts this evidence-backed factual correction. In the first exercise state, the request is `accepted` and admission is pending. S0-12 and S0-13 remain blocked because neither the source edit nor card revisions have been admitted.

In the second exercise state, a fictional admission receipt contains the following proof obligations. These are expected receipt contents, not evidence that admission occurred.

| Receipt field | Required synthetic result |
| --- | --- |
| Source and card propagation | Toolchain sentence and S0-12/S0-13 revisions enter in the same integrated commit. |
| Independent review | Fresh reviewer checks the exact candidate against TADR-001 and confirms a factual correction with no architecture change. |
| Verification | `npm run check:docs` on the integrated commit, plus observed editor and template identities tied to that commit's toolchain record. |
| Readiness | Coordinator checks dependencies, authorization, other amendments, and current leases before recording readiness. |
| Event and closure | Separate decision and propagation events cite the request revision, reviewed candidate, integrated commit, receipts, and affected card revisions. |

Only a complete real receipt could remove this amendment's blocker. Other selected work and required gates must still pass for sprint closure. Placeholder identities or missing verification keep closure pending.

## Architecture change requires Andrew

### Context and evidence

`EXAMPLE-ARCHITECTURE` concerns [HF-07b revision 1](../../../BACKLOG.md#hf-07b), with downstream [HF-08 revision 2](../../../BACKLOG.md#hf-08). These foundation cards remain outside the authorized operational Sprint 0 work. This example grants neither card execution authority.

Clause A is [TADR-004, Decision](../../../adr/TADR-004-persistence.md#decision), which selects a versioned JSON aggregate and one persistence owner. Clause B is an invented candidate sentence, `Store the profile and current run in an embedded database instead of the JSON aggregate.` The exercise compares the sentences and observes a storage-architecture change. There is no measured database result or actual failing save protocol.

### Proposal and compatibility

The proposed amendment replaces TADR-004's JSON storage decision with an embedded database while retaining atomic lifecycle guarantees. It would also require revised HF-07b schema/transaction deliverables and HF-08 recovery checks. Exact replacement contracts and their card revisions are pending; this is not an implementation-ready proposal.

Keeping the JSON aggregate retains the accepted design and needs qualification. A mandatory journal would introduce a different persistence protocol and also requires an amendment. A database might change failure recovery and maintenance costs, but this exercise contains no measurements supporting that claim.

Compatibility analysis must cover existing JSON generations, schema/content migration, rollback, save ownership, and recovery checks on both target OS families. The proposal cannot weaken spent-revival or terminal authority. Browser data stays preserved under its separate policy. A production dependency and implementation scope would need separate authorization.

### Decision, admission, and closure

The request remains `proposed` for Andrew. The coordinator may classify and collect evidence but cannot accept an architecture change as a factual correction. No answer from Andrew is invented. Admission is pending with no propagation receipt.

If Andrew later accepts a fully specified request, the coordinator must admit TADR-004 and all affected card revisions together. Fresh review, affected verification, and readiness follow before dispatch. An acceptance message alone supplies none of that propagation evidence.

While applicable to selected work, this unresolved request prevents `passed` closure. In this example the foundation cards are unselected, so the request does not block unrelated operational Sprint 0 closure. The closure receipt must state that applicability decision and its reason.

## Deferred contradiction keeps affected work blocked

### Context and evidence

`EXAMPLE-DEFERRED` concerns [S0-13 revision 1](../../../BACKLOG.md#s0-13). Stop its claimed platform-execution result. Unrelated authorized documentation may continue. Keep ownership of the stopped attempt's lease until the coordinator reconciles it.

Clause A is [ORCHESTRATOR, Sprint closure](../../../ORCHESTRATOR.md#sprint-closure), which states that Windows export alone establishes no Windows execution. Clause B is an invented candidate receipt, `Windows execution passed because the Windows export exists.` The inline observation is `Windows export present; Windows launch evidence absent`.

The comparison shows that the candidate's evidence cannot support its execution claim. It does not prove a Windows runtime failure. [TADR-001, Later qualification](../../../adr/TADR-001-engine-language-platforms.md#later-qualification-and-reconsideration) preserves platform qualification needs.

### Proposal and compatibility

The worker proposes counting export as Windows execution. The coordinator leaves the accepted evidence rule unchanged and defers the requested change pending the owner's disposition or actual execution evidence. The source remains authoritative throughout the deferral.

Obtaining a scoped Windows execution receipt could satisfy an applicable execution requirement. Correcting the candidate to claim export only would remove the false claim, but cannot pass a gate requiring execution. Treating the absent receipt as a runtime failure would also misstate the evidence. No alternative permits an unsupported execution claim.

No source or card revision is accepted. Required platform gates and historical evidence keep their meaning. This scenario introduces no build, deployment, hardware qualification, or new testing authorization.

### Decision, admission, and closure

The fictional coordinator records `deferred` with the missing evidence, affected S0-13 action, and a resolution condition. Admission stays pending. No source/card propagation, independent admission review, or integrated receipt exists.

For the exercise, assume the selected gate requires Windows execution. Closure is `pending_evidence` while that receipt is missing, even if the export succeeds. Andrew could instead authorize a revised scope, but the coordinator must record that decision and propagate its required source/card changes before recollecting final evidence. Deferral cannot waive the gate.

This assumption does not add a Windows execution requirement to the real operational Sprint 0. The [actual authorization](AUTHORIZATION.md) distinguishes exports from Windows execution. The reviewer must compare any real request with its actual selected gates.
