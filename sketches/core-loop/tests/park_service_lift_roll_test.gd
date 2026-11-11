extends "res://tests/park_hollow_lift_roll_test.gd"
# smoke: timeout=900s

# The dam's service_lift and a ball at cruise at the PHASES even places of its cycle and the fire place, read exactly as
# park_hollow_lift_roll_test.gd reads the flume's hollow_lift (its header has the method, the readings and the guard), in a
# process of its own.


func _test_name() -> String:
	return "park_service_lift_roll_test"


func _lift() -> Array:
	return ["service_lift", 1, "park_dam", false]
