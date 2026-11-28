extends RefCounted


const LoopTally := preload("res://src/core/loop_tally.gd")
const KEY := "hull_mark"
const FLOOR_SHARE := 0.1


static func held(run) -> float:
	if run == null:
		return 0.0
	return float(run.trade_memory.get(KEY, 0.0))


static func ceiling(run, unmarked: float) -> float:
	var room := maxf(0.0, unmarked - maxf(1.0, ceilf(unmarked * FLOOR_SHARE)))
	if held(run) > room:
		if room > 0.0:
			run.trade_memory[KEY] = room
		else:
			run.trade_memory.erase(KEY)
	return unmarked - held(run)


static func stake(run, amount: float) -> void:
	if amount <= 0.0:
		return
	LoopTally.note(run, "marked_hull")
	run.trade_memory[KEY] = held(run) + amount
	run.set_max_hp(run.max_hp - amount)


static func lift(run) -> float:
	var amount := held(run)
	if amount <= 0.0:
		return 0.0
	run.trade_memory.erase(KEY)
	run.set_max_hp(run.max_hp + amount)
	return amount


static func doc_ok(doc: Dictionary) -> bool:
	if not doc.has(KEY):
		return true
	var value = doc[KEY]
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(value) and value >= 0.0
