extends "res://tests/boss_lead_line_test.gd"
# smoke: timeout=300s
# fast-lane sources: res://src/game.gd res://src/combat/miniboss.gd res://src/movement/tuning.gd res://src/combat/pack_pressure.gd


func _run() -> void:
	_game.ctx.calm = true
	var stage := await _stage()
	for variant in _enemy_variants("miniboss"):
		_variant(variant)
	await _slam_reach_checks()
	_enemy_scenarios("miniboss")
	stage.queue_free()
	_finish("boss_lead_line_miniboss_test", 43)
