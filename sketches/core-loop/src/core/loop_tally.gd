extends RefCounted


const META := "loop_tally"


static func reset(run) -> void:
	run.set_meta(META, {})


static func note(run, loop_id: String) -> void:
	if run == null:
		return
	var tally: Dictionary = run.get_meta(META, {})
	tally[loop_id] = int(tally.get(loop_id, 0)) + 1
	run.set_meta(META, tally)


static func counts(run) -> Dictionary:
	return (run.get_meta(META, {}) as Dictionary).duplicate()
