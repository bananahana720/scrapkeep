extends "res://tests/zz_e105_core.gd"
# smoke: timeout=360s

func _part() -> void:
	PART = "ramp"
	for k in [1.0, 1.5, 2.0]:
		for z in [176, 178, 180, 182, 184, 186, 188, 189, 190, 191]:
			await _roll("ramp W>E z%d" % z, Vector2(-162.0, z), Vector2(1, 0), k, -140.0, 3.0)
			await _roll("ramp E>W z%d" % z, Vector2(-139.0, z), Vector2(-1, 0), k, 162.0, 3.0)
		await _roll("ramp diag SW-ward", Vector2(-160, 176), Vector2(1, 0.5), k, Vector2(-140, 186).dot(Vector2(1, 0.5).normalized()), 3.0)
		await _roll("ramp diag SE-ward", Vector2(-140, 176), Vector2(-1, 0.5), k, Vector2(-160, 186).dot(Vector2(-1, 0.5).normalized()), 3.0)
		await _roll("crest N-ward into lip x-151", Vector2(-151, 192), Vector2(0, -1), k, -170.0, 3.0)
		await _roll("crest N-ward into lip x-149", Vector2(-149, 191), Vector2(0, -1), k, -170.0, 3.0)
