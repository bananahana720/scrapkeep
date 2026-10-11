# smoke: solo timeout=600s (four full skipper runs of one pilot in child processes at once, stage 1 to the win)
# 2026-10-11 (w13 B4 merge): 360 s to 600 s. Under the B4 adapter the Cannon wins 4 of 4 uncapped and only ran
# past the 330 s child cap with the machine at load average 20 to 50 (the wave's writers); the cap was the load, not the fight.
# The six-pilot slice for remembered_cannon; the runs and the win rule live in bot_six_pilots_test.gd.
extends "res://tests/bot_six_pilots_test.gd"


func _pilot() -> String:
	return "remembered_cannon"
