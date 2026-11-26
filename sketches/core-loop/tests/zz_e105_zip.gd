extends "res://tests/zz_e105_core.gd"
# smoke: timeout=360s

func _zip(name: String, at: Vector2, dir: Vector2, k: float) -> void:
	await _roll(name + " approach", at, dir, k, 186.0, 1.0)
	var clear := 0.0
	var t := 0.0
	var zipped := false
	while t < 9.0:
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
		var ball: Vector3 = _game.player.ball_position()
		if ball.z > 260.0 and ball.z < 430.0:
			clear = maxf(clear, ball.y - _h(ball.x, ball.z))
		if ball.z > 430.0:
			break
	_out("zip %s k=%.1f clear=%.1f end=%s" % [name, k, clear, str(_game.player.ball_position().snapped(Vector3.ONE * 0.1))])


func _part() -> void:
	PART = "zip"
	for k in [1.0, 1.5, 2.0]:
		for x in [-153.0, -151.0, -149.0]:
			await _boot_fresh()
			await _zip("x%d" % x, Vector2(x, 166.0), Vector2(0, 1), k)


func _boot_fresh() -> void:
	_game.queue_free()
	for i in 3:
		await process_frame
	await _boot()
