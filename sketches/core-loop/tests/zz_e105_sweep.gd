extends "res://tests/zz_e105_core.gd"
# smoke: timeout=360s

func _part() -> void:
	PART = "sweep"
	for k in [0.75, 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.15, 1.2, 1.25, 1.3]:
		await _roll("sweep W>E z480 from140", Vector2(140.0, 480.0), Vector2(1, 0), k, 172.0, 5.0)
		await _roll("sweep W>E z500 from151.5", Vector2(151.5, 500.0), Vector2(1, 0), k, 172.0, 5.0)
		await _roll("sweep E>W z500 from185", Vector2(185.0, 500.0), Vector2(-1, 0), k, -152.0, 5.0)
		await _roll("sweep S>N x160 from562", Vector2(160.0, 562.0), Vector2(0, -1), k, -520.0, 5.0)
