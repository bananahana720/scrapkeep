# Slice B4: TADR-004 persistence proof (scrapkeep-explorer). Model claude-fable-5-1 per host; effort unavailable. Gap confirmed; designable now; executable only after Godot install authorization. Evidence level 2. Nothing ran.
Receipt gap: docs-godot.txt Query 3 header names rename and JSON parse/stringify (line 205) but snippets contain neither DirAccess.rename nor any JSON method: both UNVERIFIED; proof depends on them.

## Observations
- HF-07/08/09 bounded by "No engine behavior or executable test" (BACKLOG.md:359,388,419). TRACKING.md:13 awaiting_review; HF-07/08/09 queued (:110-112); Q-E05, Q-E09 open (:172,:176). Godot absent; no CI; docs/tech absent.

## 1. Minimal proof
Envelope (placeholder): {schema_version:1, content_revision:"placeholder-content-0", generation:1, transaction_id:"txn-0001", profile:{placeholder:true}, run:{checkpoint:{next_entrance:"placeholder-entrance"}, lifecycle:{revival_spent:false, terminal:false}}} (TADR-004:28,30). No discovery field, no browser IDs.
SaveOwner (class_name SaveOwner extends RefCounted), one owner, one root:
- stage(aggregate)->String: writes <root>/save.json.tmp-<txn> via FileAccess.open(WRITE), flush(), close() (docs-godot.txt:206-272).
- validate(temp)->Error: re-reads the TEMP BYTES (not the dict), parses, checks schema_version <= SCHEMA_VERSION (else ERR_UNAVAILABLE), keys/types, generation > committed.generation (else ERR_ALREADY_EXISTS); same transaction_id as committed => OK with converged=true and no write (TADR-004:28 duplicate delivery).
- commit(temp)->Error: DirAccess.rename(temp, save.json) [unverified].
- acknowledge(txn): only legal after commit()==OK; earlier call pushes error, no ack.
- recover()->Dictionary: parse save.json; list save.json.tmp-*; never delete/rename them; return {status, aggregate, stale:[...]}.
- resolve_lifecycle(a,b): facts from higher generation; revival_spent/terminal monotonic true; terminal never playable.
Order stage->validate->commit->acknowledge preserves TADR-004:28; validating re-read temp bytes proves the on-disk candidate is what gets renamed.
Cases (stdout `CASE <id> PASS|FAIL <reason>`; exit 0 all pass / 1 assertion / 2 environment; quit() integer exit-code param UNVERIFIED, receipt shows quit() bare docs-godot.txt:39-49):
- (a) commit path: temp exists after stage; validate OK; after commit save.json exists, temp gone, bytes equal staged; acknowledge before commit rejected; after, recorded.
- (b) round trip: JSON.stringify -> JSON.parse_string -> deep compare (both unverified); re-stringified text compare. Godot 4 parses JSON numbers as float (background, unverified) => generation returns 1.0; typed comparison must state policy (cast to int at envelope boundary) or the case exposes drift immediately.
- (c) newer schema: c1 committed schema 1, stage candidate schema 99 => validate error; save.json hash unchanged; rejected temp preserved (TADR-004:40). c2 run dir with only save.json schema 99 => recover() status "unsupported_newer", playable false, hash unchanged (TADR-004:34).
- (d) interruption fixture from fixtures/interruption/: save.json (gen 3, acked) + save.json.tmp-txn-0004. d1 truncated temp => recover returns gen 3, stale:[tmp], temp unchanged. d2 (recommended; likeliest paper drift): temp complete valid JSON gen 4 revival_spent:true never renamed => committed gen 3 still source, temp preserved, but status "ambiguous_lifecycle", playable false (TADR-004:40 forbids silently choosing an older living generation when a newer spent-revival result may exist). "Prefer committed" holds for source-of-truth; d2 pins that it does not equal automatic resumption.
- (e) lifecycle fixture: save.json gen 5 revival_spent:true entrance X; older.json gen 4 revival_spent:false. resolve_lifecycle(gen5,gen4).revival_spent == true; staging older.json fails validate ERR_ALREADY_EXISTS, hash unchanged. Terminal variant gen 6 terminal:true => playable false (TADR-004:30).
- (f) optional: re-stage committed txn => converged true, no generation change, no write.
Proves: logical protocol (order, monotonic generation, lifecycle authority, visible rejection, stale preservation) on one OS/process/file with placeholders.
Does NOT prove (TADR-004:38 quoted: "Temporary files, a rename, a checksum or a backup alone do not prove power-loss durability..."): power-loss ordering; whether FileAccess.flush() reaches the device (docs-godot.txt:242-250 is a documentation claim, not an fsync guarantee); directory-entry durability after rename (no dir-sync API in receipt; unverified/likely absent); rename-over-existing on Windows/macOS; single-writer exclusion (no lock primitive in receipt); real projection fields; content-revision meaning; every open product rule.
Browser precedent (prior art, not reuse): src/campaign.js:115 `data.version !== 1` => newer version silently replaced by fresh default (line 112), inverse of TADR-004:34; no migration hook (grep migrat: none). src/progress-store.js:45 `parsed?.version === 1 &&` else keeps last usable profile (comment :51); same literal compare. tests/progress-store.test.js:92-111 denied storage via throwing getItem/setItem; :72-90 malformed/mismatched receipts; :113-133 denied write then retry: pattern worth porting is fault injection through the storage seam (GDScript equivalent unverified). server/store.js: lock wx (:12), pid + sync (:22-23), temp wx (:106), write (:107), handle.sync (:108), close (:109), rename (:111), dir sync (:113-117), temp cleanup (:121-123). Lacks vs TADR-004: generation/txn identity; separate acknowledge (state=next at :112 precedes dir sync); startup recovery of orphan leads-*.tmp; validation of written bytes before rename; migrations (version !== 1 throws :26-27, at least visible). Node exposes sync() primitives the Godot receipt does not show.

## 2. Harness
Layout (DRAFT; HF-01 owns production paths BACKLOG.md:39): proofs/godot/tadr-004-save/{project.godot, save_owner.gd, run_proof.gd, fixtures/interruption/, fixtures/lifecycle/, fixtures/newer-version/}. Fixtures committed, copied to a per-run dir, never mutated in place.
Command (DRAFT, combination unverified): `godot --headless --path proofs/godot/tadr-004-save --script res://run_proof.gd` (docs-godot.txt:9,63,39-55; --path appears only with export in receipt :29). No framework (ci-facts.txt:29).
Run dir: absolute path under artifacts/local/proofs/tadr-004/<run-id>/ (DirAccess.open accepts absolute, docs-godot.txt:289); gitignored (.gitignore:7). Don't use the game's real user://; proof project name isolates it (docs-godot.txt:313-315).
Evidence: stdout.log; result.json (case, verdict, reason, sha256 of save.json before/after for c/e, dir listing after d, engine version string [API unverified]); run-dir copy. Method: "headless fixture run, Linux only, Godot <version>".
fsync/flush assertability from GDScript: UNVERIFIED; receipt exposes flush() and close() only; no fsync/fdatasync/dir sync/O_SYNC/lock. Harness asserts ordering and file state, not device durability. Windows/macOS untested by construction (Arch host, ci-facts.txt:9); no CI.

## 3. HF coverage
- HF-07 (:348-352; tabletop :356-357): proof covers envelope identity + stage/validate/commit/ack for one transition; not reward/offer fields (HF-06).
- HF-08 (:377-381; matrix :385): cases c2, d1, d2, e cover file-protocol rows.
- HF-09 (:408-412): case c covers newer-format rejection; no migration exercised (1->2 with original preserved is natural next case; needs a second schema HF-09 hasn't defined).
- Interruption matrix as executable fixtures from day one: YES for file-protocol stages (a matrix row at file level is literally a directory state); gameplay-stage rows depend on HF-04/HF-06 fields and would be fake. Recommend HF-08 DoD3 gains "each matrix row names its fixture directory or is marked paper-only."
- Sequencing: PAIR with HF-07 as sibling, not dependency. HF-07 drafts envelope; proof encodes it; HF-07 evidence cites proof result or blocked status.
- Drift, likeliest first: (1) whether "acknowledged as durable" follows rename or a flush the API may not expose, and whether validation reads temp bytes or the dict; (2) d2: paper says "prefer committed" without deciding that a valid unrenamed newer temp blocks resumption; (3) generation monotonicity stated as identity rather than commit-time rejection; (4) JSON int/float typing of generation; (5) transaction_id convergence stated but untested (f).

## 4. Gates
- Q-E05 (:2058-2068; open TRACKING.md:172): profile is {placeholder:true}; never reads localStorage/progress key/progress.run.* (src/progress-store.js:12,40); no import path. Boundary: any code reading a browser key or campaign.js profile shape is out of scope; adding discovery or class-XP field reopens the gate.
- Q-E09 (:2114-2124; open TRACKING.md:176): proof proves protocol for one explicit commit(); doesn't decide when commits occur; no discovery field. Boundary: no `discoveries` key or write-on-discovery trigger.
- Neither blocks the proof; both block the first non-placeholder profile field.

## 5. DRAFT cards
### S0-01 (B4): Author the TADR-004 save-owner proof and fixtures
Rev 0 DRAFT · Owner Persistence · Size S · Lane prepare. Sources: TADR-004 § Decision (22-34), § Consequences (36-42); docs-godot.txt; HF-07 draft envelope if available else placeholder; server/store.js:103-124 and tests/progress-store.test.js:72-133 prior art only. Dependencies: HF-01 or placeholder path. Blocking questions none; Blocking item: Godot install authorization (authoring can proceed; nothing can run). Files: proofs/godot/tadr-004-save/{project.godot,save_owner.gd,run_proof.gd,fixtures/*,README.md}; artifacts/local/tasks/S0-01/. DoD: (1) typed SaveOwner with the six methods; (2) cases a-e (f optional) with stated inputs/outputs/exit codes; (3) fixtures for c2, d1, d2, e; (4) README states command, run-dir rule, evidence layout, TADR-004:38 non-claim verbatim; (5) every API absent from docs-godot.txt marked unverified. Verification (DRAFT): source review against TADR-004:28,30,34,40; fixture JSON parses under Node (syntax only); no Godot execution claimed. Boundary: no game code, no future user://, no browser storage reads, no discovery field, no migration implementation, no CI; placeholders only.

### S0-02 (B4): Execute the TADR-004 proof and record evidence
Rev 0 DRAFT · Owner Verification · Size S · Lane prepare. Sources: S0-01 output; CONTRIBUTING.md:31; docs-godot.txt. Dependencies: S0-01 done; Godot installed. Blocking item: install authorization (ci-facts.txt:19-20 sources). Files: artifacts/local/proofs/tadr-004/<run-id>/; artifacts/local/tasks/S0-02/; suggested HF-08 matrix cross-references via handoff. DoD: (1) one headless run exit 0 all PASS; (2) engine version + OS recorded; (3) result.json names method "headless fixture run"; (4) explicit statement flush/fsync durability and non-Linux rename not asserted. Verification (DRAFT): rerun twice for idempotence; reviewer reads result.json vs case table. Boundary: Linux only; no CI, no templates; certifies nothing, closes no HF card.

## Decisions only Andrew can make
- Authorize local Godot 4.7.2 install.
- Whether a runnable proof card may join the sprint at all (changes its documentation-only character, BACKLOG.md:359/388/419).
- Whether proof files may land at a placeholder path before HF-01.
- Whether d2 (valid unrenamed newer temp with a lifecycle fact) surfaces to the player as a blocked-resume state (protocol is Persistence's; player-facing consequence is his).
