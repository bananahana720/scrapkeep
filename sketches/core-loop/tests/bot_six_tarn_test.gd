# smoke: bots timeout=1500s (four full skipper runs of one pilot in child processes at once, stage 1 to the win)
# 2026-10-12 (W13 coordinator): on 00a1bdf, pre-kit Kest won 4/4 at 637, 739, 742, 791 s wall
# (435 to 626 s game) with an 1100 s child cap; Cannon won 4/4 at 442 to 471 s wall.
# At the old 330 s child cap every child was killed (coordinator receipts, 2026-10-12).
# The six-pilot slice for tarn; the runs and the win rule live in bot_six_pilots_test.gd.
extends "res://tests/bot_six_pilots_test.gd"


func _pilot() -> String:
	return "tarn"
