extends "res://tools/look_harness.gd"


func _boss_smoke(id: String) -> int:
	var rc: int = await super(id)
	print("BOSS_SMOKE_CRASH boss=%s rc=%d aborting on purpose" % [id, rc])
	OS.crash("boss smoke crash control")
	return rc
