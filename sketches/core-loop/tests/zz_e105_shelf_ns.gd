extends "res://tests/zz_e105_core.gd"
# smoke: timeout=360s

func _part() -> void:
	PART = "shelf_ns"
	for k in [1.0, 1.5, 2.0]:
		for x in [150, 153, 156, 158, 160, 162, 164, 167, 170]:
			await _roll("N>S x%d" % x, Vector2(x, 432.0), Vector2(0, 1), k, 556.0, 6.0)
		for x in [150, 153, 156, 158, 160, 162, 164, 167, 170]:
			await _roll("S>N x%d" % x, Vector2(x, 560.0), Vector2(0, -1), k, -440.0, 6.0)
