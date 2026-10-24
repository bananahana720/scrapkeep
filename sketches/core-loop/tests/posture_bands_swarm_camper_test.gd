# smoke: bots timeout=900s (8 camper bot runs on stage 3 in child processes, as many at once as memory and cores allow, each cut at RUN_CAP_S)
# 2026-10-23: split from posture_bands_swarm_test so each sweep fits the bot tier's 1800 s ceiling. A camper child
# plays to the tick cap (the camper never breaks the hive): 495 s wall for one; the sweep (8 at once on a 4-core cloud sandbox) took 660 s through the smoke runner.
extends "res://tests/posture_bands_swarm_test.gd"

# The swarm band's third leg (wardens/swarm.md section 7): the camper, who only shoots from range, never breaks
# the stage 3 hive. Its children are posture_bands_swarm_test's; this parent runs only the camper arm.


func _arm_seeds() -> Dictionary:
	return {"camper": CAMPER_SEEDS}


func _suite() -> String:
	return "posture_bands_swarm_camper_test"


func _judge(t, sweep: Dictionary) -> void:
	var fights: Array = sweep["fights"]["camper"]
	print("swarm camper stage %d: %s" % [STAGE, fights])
	t.eq("the camper never breaks it", fights.filter(func(s): return s < RUN_CAP_S).size(), 0)
