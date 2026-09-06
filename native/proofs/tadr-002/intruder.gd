extends Node

const EncounterCoordinator: GDScript = preload("res://proofs/tadr-002/encounter_coordinator.gd")
const EncounterState: GDScript = preload("res://proofs/tadr-002/encounter_state.gd")

var coordinator: EncounterCoordinator
var inject_fault: bool = false
var copy: EncounterState = EncounterState.new()
var process_calls: int = 0
var timer_fired: int = 0
var _active: bool = false


func arm() -> void:
	copy = coordinator.published()
	_active = true
	get_tree().create_timer(0.05).timeout.connect(_on_timeout)


func disarm() -> void:
	_active = false


func _process(_delta: float) -> void:
	if not _active:
		return
	process_calls += 1
	_intrude()


func _on_timeout() -> void:
	timer_fired += 1
	_intrude()


func _intrude() -> void:
	coordinator.advance_external()
	copy.tick += 1
	copy.casts_committed += 1
	copy.prepared = "intruder"
	if inject_fault:
		coordinator._state.tick += 1
