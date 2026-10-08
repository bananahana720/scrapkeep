# smoke: solo timeout=360s (four full skipper runs of one pilot in child processes at once, stage 1 to the win)
# The six-pilot slice for runner_gunner; the runs and the win rule live in bot_six_pilots_test.gd.
extends "res://tests/bot_six_pilots_test.gd"


func _pilot() -> String:
	return "runner_gunner"
