extends Control

const SessionOwner: GDScript = preload("res://proofs/tadr-002/session_owner.gd")
const EncounterState: GDScript = preload("res://proofs/tadr-002/encounter_state.gd")
const Catalogue: GDScript = preload("res://proofs/tadr-003/definitions/catalogue.gd")
const Definition: GDScript = preload("res://proofs/tadr-003/definitions/slot_tree_definition.gd")
const SaveOwner: GDScript = preload("res://proofs/tadr-004/save_owner.gd")
const SOURCE: Definition = preload("res://proofs/tadr-003/fixtures/placeholder_tree.tres")
const CONTENT_REVISION: String = "s0-12-synthetic-1"
const TRANSACTION: String = "s0-12-stage-1"
const EXPECTED_TICKS: int = 3

class SmokeResult extends RefCounted:
	var mode: String = "stage"
	var data_dir: String = ""
	var checks: PackedStringArray = PackedStringArray()
	var failures: PackedStringArray = PackedStringArray()

	func check(condition: bool, name: String) -> bool:
		checks.append(name)
		if not condition:
			failures.append(name)
		print("SCRAPKEEP_INTEGRATION CHECK %s %s" % ["PASS" if condition else "FAIL", name])
		return condition

var result: SmokeResult = SmokeResult.new()
var auto_exit: bool = false
var inject_fault: bool = false
var session: SessionOwner
var exit_code: int = 1
@onready var status_label: Label = $Panel/Rows/Status
@onready var details_label: Label = $Panel/Rows/Details
@onready var exit_button: Button = $Panel/Rows/Exit

func _ready() -> void:
	exit_button.pressed.connect(_exit)
	get_tree().auto_accept_quit = false
	if not _arguments():
		_finish()
		return
	await _run()
	_finish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_exit()

func _arguments() -> bool:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	auto_exit = arguments.has("--auto-exit")
	var selected_mode: bool = false
	var index: int = 0
	while index < arguments.size():
		match arguments[index]:
			"--stage", "--resume":
				if not result.check(not selected_mode, "one process mode"):
					return false
				selected_mode = true
				result.mode = arguments[index].trim_prefix("--")
			"--data-dir":
				index += 1
				if not result.check(index < arguments.size() and result.data_dir.is_empty(), "data directory argument"):
					return false
				result.data_dir = arguments[index]
			"--auto-exit":
				auto_exit = true
			"--inject-fault":
				inject_fault = true
			_:
				result.check(false, "unknown argument %s" % arguments[index])
				return false
		index += 1
	if result.data_dir.is_empty():
		if not result.check(result.mode == "stage", "resume requires --data-dir"):
			return false
		var temporary_root: String = OS.get_environment("TEMP")
		if temporary_root.is_empty():
			temporary_root = "/tmp"
		result.data_dir = temporary_root.path_join("scrapkeep-s0-12-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	return result.check(result.data_dir.is_absolute_path() and not result.data_dir.begins_with("res://") and not result.data_dir.begins_with("user://"), "absolute isolated data path")

func _run() -> void:
	var catalogue: Catalogue = Catalogue.new()
	var definitions: Array[Definition] = [SOURCE]
	if not result.check(catalogue.stage(definitions) == OK, "typed content admitted"):
		return
	var admitted: Definition = catalogue.resolve(SOURCE.id)
	var mutable_copy: Definition = admitted.duplicate(true) as Definition
	mutable_copy.nodes[0] = "synthetic-mutation"
	result.check(admitted.nodes[0] == "n0" and SOURCE.nodes[0] == "n0", "deep-copy definition isolation")
	var bad_copy: Definition = admitted.duplicate(true) as Definition
	bad_copy.edges.remove_at(0)
	var rejected: Array[Definition] = [bad_copy]
	result.check(catalogue.stage(rejected) == ERR_INVALID_DATA and catalogue.resolve(SOURCE.id) == admitted, "invalid content rejected with active catalogue retained")
	session = SessionOwner.new()
	session.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(session)
	result.check(not session.coordinator.advance_external(), "external tick rejected")
	while session.coordinator.physics_calls < EXPECTED_TICKS:
		await get_tree().physics_frame
	session.pause()
	var snapshot: EncounterState = session.coordinator.published()
	result.check(snapshot.tick == EXPECTED_TICKS and snapshot.tick == session.coordinator.physics_calls, "one coordinator owns physics ticks")
	snapshot.tick = 999
	result.check(session.coordinator.published().tick == EXPECTED_TICKS, "published state isolation")
	await get_tree().physics_frame
	await get_tree().physics_frame
	result.check(session.coordinator.published().tick == EXPECTED_TICKS, "pause stops authoritative ticks")
	if not result.failures.is_empty():
		return
	if result.mode == "stage":
		_stage()
	else:
		_resume()

func _stage() -> void:
	if DirAccess.dir_exists_absolute(result.data_dir):
		if not result.check(DirAccess.get_files_at(result.data_dir).is_empty() and DirAccess.get_directories_at(result.data_dir).is_empty(), "stage directory is empty"):
			return
	if not result.check(DirAccess.make_dir_recursive_absolute(result.data_dir) == OK, "stage directory ready"):
		return
	var aggregate: Dictionary = {
		"schema_version": SaveOwner.SCHEMA_VERSION,
		"content_revision": CONTENT_REVISION,
		"generation": 1,
		"transaction_id": TRANSACTION,
		"profile": {
			"runs_started": session.profile["runs_started"],
			"synthetic_score": 42,
			"owned_ticks": session.coordinator.published().tick,
			"tree_id": String(SOURCE.id),
			"writer_process": OS.get_process_id(),
		},
		"run": {
			"checkpoint": {"next_entrance": "proof.entrance.next"},
			"lifecycle": {"revival_spent": true, "terminal": false},
		},
	}
	if inject_fault:
		aggregate["schema_version"] = SaveOwner.SCHEMA_VERSION + 1
	var owner: SaveOwner = SaveOwner.new(result.data_dir)
	var staged: String = owner.stage(aggregate)
	if not result.check(not staged.is_empty(), "synthetic aggregate staged"):
		return
	if not result.check(owner.validate(staged) == OK, "synthetic aggregate validated"):
		return
	if not result.check(owner.commit(staged) == OK, "synthetic aggregate committed"):
		return
	owner.acknowledge(TRANSACTION)
	result.check(owner.is_acknowledged(TRANSACTION), "commit acknowledged")

func _resume() -> void:
	var owner: SaveOwner = SaveOwner.new(result.data_dir)
	var recovered: Dictionary = owner.recover()
	var playable_committed: bool = recovered["status"] == SaveOwner.STATUS_COMMITTED and recovered["playable"] == true
	if not result.check(playable_committed, "committed playable aggregate recovered"):
		return
	var aggregate: Dictionary = recovered["aggregate"]
	var profile: Dictionary = aggregate["profile"]
	var run: Dictionary = aggregate["run"]
	var checkpoint: Dictionary = run["checkpoint"]
	var lifecycle: Dictionary = run["lifecycle"]
	var envelope_identity_restored: bool = aggregate["content_revision"] == CONTENT_REVISION and aggregate["generation"] == 1 and aggregate["transaction_id"] == TRANSACTION
	result.check(envelope_identity_restored, "envelope identity restored")
	var resume_runs_in_a_fresh_process: bool = profile.get("writer_process", OS.get_process_id()) != OS.get_process_id()
	result.check(resume_runs_in_a_fresh_process, "resume runs in a fresh process")
	var expected_score: int = 43 if inject_fault else 42
	var synthetic_profile_restored_exactly: bool = profile.get("synthetic_score") == expected_score and profile.get("owned_ticks") == EXPECTED_TICKS and profile.get("tree_id") == String(SOURCE.id) and profile.get("runs_started") == 1
	result.check(synthetic_profile_restored_exactly, "synthetic profile restored exactly")
	var checkpoint_and_lifecycle_restored_exactly: bool = checkpoint["next_entrance"] == "proof.entrance.next" and lifecycle["revival_spent"] == true and lifecycle["terminal"] == false
	result.check(checkpoint_and_lifecycle_restored_exactly, "checkpoint and lifecycle restored exactly")
	if result.failures.is_empty():
		var restored_runs: float = profile["runs_started"]
		session.profile["runs_started"] = int(restored_runs)
		result.check(session.profile["runs_started"] == 1, "restored profile belongs to session")

func _finish() -> void:
	exit_code = 0 if result.failures.is_empty() else 1
	status_label.text = "%s %s" % [result.mode.capitalize(), "passed" if exit_code == 0 else "failed"]
	var scope_note: String = "Synthetic state saved. Fresh-process resume has not run in this window." if result.mode == "stage" else "Synthetic state recovered and checked in this fresh process."
	details_label.text = "%s\n\n%d checks. %d failures.\n%s\n\nData directory\n%s\n\nOperational proof only. No gameplay, hardware or durability qualification." % [scope_note, result.checks.size(), result.failures.size(), "\n".join(result.failures), result.data_dir]
	if exit_code != 0:
		details_label.text = "The smoke check failed.\n\n%s\n\nData directory\n%s\n\nNo successful save or resume is claimed." % ["\n".join(result.failures), result.data_dir]
	print("SCRAPKEEP_INTEGRATION %s %s" % [result.mode.to_upper(), "PASS" if exit_code == 0 else "FAIL"])
	print("SCRAPKEEP_INTEGRATION SUMMARY " + JSON.stringify({"mode": result.mode, "exit_code": exit_code, "checks": result.checks, "failures": result.failures, "data_dir": result.data_dir}))
	exit_button.grab_focus()
	if auto_exit:
		_exit()

func _exit() -> void:
	get_tree().quit(exit_code)
