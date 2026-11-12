extends SceneTree

# PF-16 (w37 player's-eye film, pictures 093-098): Brindle's ram warned with a lane, but once
# the lane went live the whole lower screen turned flat orange and the mark over the ball
# went, while the hull was still on its way. Only the hull's nose hurts (boss.gd _run_charge),
# so a lane with a running front keeps its light pending fill inside its rails, and the dodge
# watch keeps the mark up until the front reaches the ball. The committed lane is unchanged.

const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const NearMiss := preload("res://src/combat/near_miss.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("ram_warning_test")


func _lane(front: float) -> Node:
	var h := Hazard.new()
	h.commit_lane("charge", Threat.Type.LANE, Vector3.ZERO, Vector3(0, 0, -1), 3.0, 40.0, 4.0, 5.0, 1.0, 2.0)
	h.lane_front = front
	h.state = Hazard.LIVE
	return h


func _initialize() -> void:
	var ball := Vector3(0.0, 0.0, -20.0)
	var plain := _lane(-1.0)
	var d: Dictionary = plain.descriptor()
	_t.check("planted: a live lane with no front draws its dense band", Threat.live_band(d) and Threat.drive(d).values()[0]["live"])
	_t.check("planted: and lands for the ball the moment it goes live", NearMiss._landed(plain, ball, d))
	var ram := _lane(3.0)
	var r: Dictionary = ram.descriptor()
	_t.check("the ram's live lane keeps the light pending fill", not Threat.live_band(r) and not Threat.drive(r).values()[0]["live"])
	_t.near("and that fill reaches the rails", Threat.fill_share(r), 1.0)
	_t.check("the hull 17 m short of the ball: not landed, the mark stays", not NearMiss._landed(ram, ball, r))
	ram.lane_front = 21.0
	_t.check("the hull's nose past the ball: landed", NearMiss._landed(ram, ball, ram.descriptor()))
	_t.check("the committed lane is the same shape with or without a front", ram.contains(ball) == plain.contains(ball) and ram.contains(Vector3(0, 0, -39.0)) and not ram.contains(Vector3(5.0, 0, -20.0)))
	plain.free()
	ram.free()
	quit(_t.verdict())
