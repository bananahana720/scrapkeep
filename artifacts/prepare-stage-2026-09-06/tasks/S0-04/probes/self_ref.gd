extends RefCounted

const SelfRef: GDScript = preload("self_ref.gd")

var tick: int = 0


func snapshot() -> SelfRef:
	var copy: SelfRef = SelfRef.new()
	copy.tick = tick
	return copy
