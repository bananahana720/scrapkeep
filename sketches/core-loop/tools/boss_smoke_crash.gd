extends "res://tools/look_harness.gd"

# Positive control for the sketch-export boss smoke, never shipped as a default: the export boots this
# script only for the boss SCRAPKEEP_BOSS_SMOKE_CRASH names. It runs the real look_harness boss entry,
# so the BOSS_SMOKE PASS line still prints, then aborts the engine; the export must fail on the exit alone.


func _boss_smoke(id: String) -> int:
	var rc: int = await super(id)
	print("BOSS_SMOKE_CRASH boss=%s rc=%d aborting on purpose" % [id, rc])
	OS.crash("boss smoke crash control")
	return rc
