# smoke: solo (two dial 1 fights in the Waking arena; 25 s on a 4-core cloud box on 2026-10-23 with the other half running beside it)
extends "res://tests/boss_weak_crew_test.gd"

# The crew record half of boss_weak_crew_test.gd: the seal record outliving the crew and the Warden, and the
# per-phase counts the band sweep reads. Same helpers and evidence limit as that file.


func _run() -> void:
	_t = T.new("boss_weak_crew_record_test")
	await _record_survives()
	await _stats()
	_finish()
