extends "res://tests/zz_e105_core.gd"
# smoke: timeout=360s

func _part() -> void:
	PART = "fan"
	for k in [0.8, 1.0, 1.2]:
		for x in [140.0, 143.0, 146.0, 149.0]:
			for deg in [0.0, 10.0, 20.0, 30.0, 40.0]:
				var a := deg_to_rad(deg)
				var d := Vector2(sin(a), cos(a))
				await _roll("fanNW x%d deg%d" % [x, deg], Vector2(x, 436.0), d, k, Vector2(160, 525).dot(d), 4.5)
