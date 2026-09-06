extends RefCounted

const EncounterState: GDScript = preload("res://proofs/tadr-002/encounter_state.gd")

var tick: int = 0
var prepared: String = ""
var casts_committed: int = 0


func snapshot() -> EncounterState:
	var copy: EncounterState = EncounterState.new()
	copy.tick = tick
	copy.prepared = prepared
	copy.casts_committed = casts_committed
	return copy
