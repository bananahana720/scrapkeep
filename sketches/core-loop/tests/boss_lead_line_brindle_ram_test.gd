extends "res://tests/boss_lead_line_brindle_test.gd"
# smoke: timeout=300s
# fast-lane sources: res://src/game.gd res://src/boss/boss_rules.gd res://src/movement/tuning.gd res://src/combat/pack_pressure.gd res://src/movement/intent.gd res://tests/doubles/boss_harness.gd res://src/boss/hazard.gd res://src/boss/requisition.gd res://src/boss/arena.gd


func _run() -> void:
	_game.ctx.calm = true
	var fight := await _brindle()
	var boss = fight["boss"]
	var centre: Vector3 = fight["centre"]
	_brindle_scenarios(boss, centre, fight["nose"])
	_bank_stun_check(boss, centre)
	_rest_at_bank_check(boss, centre)
	boss.set_physics_process(true)
	_finish("boss_lead_line_brindle_ram_test", 8)
