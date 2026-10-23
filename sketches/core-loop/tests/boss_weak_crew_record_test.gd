# smoke: solo (three boots of the Waking arena, two on dial 1; 25 s on a 4-core cloud box on 2026-10-23 with the other half running beside it)
extends "res://tests/boss_weak_crew_test.gd"

# The crew record half of boss_weak_crew_test.gd: the seal record outliving the crew and the Warden, and the
# per-phase counts the band sweep reads. Same helpers and evidence limit as that file.
# The fast lane picks a test by the res:// paths in its text, and an extended test is not followed, so the
# sources the parent covers are named here too: res://src/boss/waking.gd res://src/boss/weak_points.gd
# res://src/combat/crew_fitter.gd res://src/game.gd res://src/presentation/sfx_bank.gd
# res://tools/bot_driver.gd res://tools/skill_band.gd


func _run() -> void:
	_t = T.new("boss_weak_crew_record_test")
	await _record_survives()
	await _stats()
	_finish()
