extends RefCounted

# Which of the sitting's loops fired in this run, and how often (scripts/gate/sitting-played-receipt.mjs
# reads it from the run log's "loops" block). A loop's owner module calls note() at the moment the
# loop does its thing; the run log resets it at run start and copies it into every line.
# It lives in run meta, as the flourish rows do, so the owners need no reference to the run log.
# Heat is not here: the run log reads it from the redline's own counts.

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
