extends "res://tests/zz_e105_core.gd"
# smoke: timeout=360s

func _part() -> void:
	PART = "geo"
	_steps(140, 180, 436, 560)
	_steps(150, 170, 440, 556)
	_steps(-166, -136, 170, 192)
	_steps(-158, -142, 176, 190)
	for x in [148, 152, 156, 160, 164, 168, 172]:
		_profile("shelf N-S x%d" % x, Vector2(x, 436), Vector2(x, 560), 62)
	for z in [446, 452, 458, 462, 466, 470, 480, 500, 540, 548]:
		_profile("shelf W-E z%d" % z, Vector2(140, z), Vector2(180, z), 20)
	for x in [-156, -154, -152, -150, -148, -146]:
		_profile("ramp N-S x%d" % x, Vector2(x, 170), Vector2(x, 204), 17)
	for z in [176, 180, 184, 186, 188, 190, 192, 196]:
		_profile("ramp W-E z%d" % z, Vector2(-166, z), Vector2(-136, z), 15)
