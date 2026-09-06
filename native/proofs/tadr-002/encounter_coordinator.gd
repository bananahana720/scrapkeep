extends Node

const EncounterState: GDScript = preload("res://proofs/tadr-002/encounter_state.gd")
const InputAdapter: GDScript = preload("res://proofs/tadr-002/input_adapter.gd")

const CMD_PREPARE_CAST: String = "prepare_cast"
const CMD_CANCEL_PREPARED: String = "cancel_prepared"

var input: InputAdapter
var physics_calls: int = 0
var rejected_out_of_phase: int = 0
var accepted_in_phase: int = 0
var _state: EncounterState = EncounterState.new()
var _queue: Array[String] = []
var _in_phase: bool = false


func submit(command: String) -> void:
	_queue.append(command)


func pending() -> Array[String]:
	return _queue.duplicate()


func published() -> EncounterState:
	return _state.snapshot()


func advance_external() -> bool:
	if not (Engine.is_in_physics_frame() and _in_phase):
		rejected_out_of_phase += 1
		return false
	accepted_in_phase += 1
	_step()
	return true


func _physics_process(_delta: float) -> void:
	_in_phase = true
	physics_calls += 1
	_step()
	_in_phase = false


func _step() -> void:
	for command: String in _queue:
		_apply(command)
	_queue.clear()
	var frame: InputAdapter.InputFrame = input.frame()
	if frame.released["cast"] and _state.prepared != "":
		_state.casts_committed += 1
		_state.prepared = ""
	_state.tick += 1


func _apply(command: String) -> void:
	match command:
		CMD_PREPARE_CAST:
			_state.prepared = "cast"
		CMD_CANCEL_PREPARED:
			_state.prepared = ""
