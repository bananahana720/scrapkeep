extends "res://tests/zz_e105_core.gd"
# smoke: timeout=360s

func _part() -> void:
	PART = "shelf_we"
	for k in [1.0, 1.5, 2.0]:
		for z in [446, 450, 454, 458, 462, 466, 470, 474, 480, 490, 500, 510, 520, 530, 540, 546, 549]:
			await _roll("W>E z%d" % z, Vector2(149.0, z), Vector2(1, 0), k, 172.0, 4.0)
