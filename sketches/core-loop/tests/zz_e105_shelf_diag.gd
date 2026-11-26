extends "res://tests/zz_e105_core.gd"
# smoke: timeout=360s

func _part() -> void:
	PART = "shelf_diag"
	for k in [1.0, 1.5, 2.0]:
		await _roll("diag NW>SE", Vector2(144, 470), Vector2(1, 1), k, Vector2(176, 502).dot(Vector2(1, 1).normalized()), 4.0)
		await _roll("diag NE>SW", Vector2(176, 470), Vector2(-1, 1), k, Vector2(144, 502).dot(Vector2(-1, 1).normalized()), 4.0)
		await _roll("diag SW>NE", Vector2(144, 530), Vector2(1, -1), k, Vector2(176, 498).dot(Vector2(1, -1).normalized()), 4.0)
		await _roll("diag SE>NW", Vector2(176, 530), Vector2(-1, -1), k, Vector2(144, 498).dot(Vector2(-1, -1).normalized()), 4.0)
		await _roll("shallow N>S from west", Vector2(146, 436), Vector2(0.35, 1), k, 520.0, 5.0)
		await _roll("shallow N>S from east", Vector2(174, 436), Vector2(-0.35, 1), k, 520.0, 5.0)
		await _roll("shallow S>N from west", Vector2(146, 556), Vector2(0.35, -1), k, -470.0, 5.0)
		await _roll("top-ramp corner N>S x155", Vector2(155, 440), Vector2(0, 1), k, 520.0, 5.0)
		await _roll("top-ramp corner N>S x165", Vector2(165, 440), Vector2(0, 1), k, 520.0, 5.0)
		await _roll("on top W off", Vector2(160, 500), Vector2(-1, 0), k, -140.0, 3.0)
		await _roll("on top E off", Vector2(160, 500), Vector2(1, 0), k, 180.0, 3.0)
		await _roll("on top S off end", Vector2(160, 520), Vector2(0, 1), k, 562.0, 4.0)
		await _roll("on top N to ramp", Vector2(160, 520), Vector2(0, -1), k, -438.0, 5.0)
