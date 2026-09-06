extends Node

const EncounterCoordinator: GDScript = preload("res://proofs/tadr-002/encounter_coordinator.gd")
const InputAdapter: GDScript = preload("res://proofs/tadr-002/input_adapter.gd")

var run_id: String = "run-0001"
var profile: Dictionary[String, int] = {"runs_started": 1}
var input: InputAdapter = InputAdapter.new()
var coordinator: EncounterCoordinator = EncounterCoordinator.new()
var focus_trigger: String = "none"


func _init() -> void:
	coordinator.input = input
	add_child(coordinator)


func pause() -> void:
	get_tree().paused = true


func resume() -> void:
	get_tree().paused = false


func on_focus_lost() -> void:
	input.clear_held()
	coordinator.submit(EncounterCoordinator.CMD_CANCEL_PREPARED)
	pause()


func lose_focus() -> void:
	focus_trigger = "none"
	propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	if focus_trigger == "none":
		focus_trigger = "direct-call"
		on_focus_lost()
	print("S0-04 focus trigger %s" % [focus_trigger])


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focus_trigger = "notification"
		on_focus_lost()
