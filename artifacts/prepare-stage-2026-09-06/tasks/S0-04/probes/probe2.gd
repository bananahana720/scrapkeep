extends SceneTree

const SelfRef: GDScript = preload("self_ref.gd")


func _init() -> void:
	var record: SelfRef = SelfRef.new()
	record.tick = 7
	var copy: SelfRef = record.snapshot()
	copy.tick += 1
	print("PROBE2 self-preload works: original=%d copy=%d" % [record.tick, copy.tick])
	quit(0)
