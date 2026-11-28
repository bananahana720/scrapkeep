extends SceneTree

const Warden := preload("res://src/combat/warden.gd")
const Reactor := preload("res://src/combat/warden_reactor.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const T := preload("res://tests/support/t.gd")

# W1-67, the Wardens escalate (gameplay critique finding 5). The pulse cycle shrinks by the stage's
# ratchet (challenge dial warden.pulse_ratchet_by_stage) for each chunk lost, the tell never shrinks,
# the rest never drops under REST_FLOOR, and a drained bar never relaxes the fight. On the dam, once a
# quarter is lost, each charge opens one half of the sheet, shown faint through the charge, and only
# that half carries the ride.
#
# Evidence limit: the Warden's chunk count and the sheet's mount are stand-ins stepped by hand; the
# fight's length on the park is the posture bands' and the band read's to judge.

class Held extends "res://src/combat/warden.gd":
	var left := 4
	func phase_chunks_left() -> int:
		return left


class Floor extends RefCounted:
	func height(_x: float, _z: float) -> float:
		return 0.0


class Mount extends Node3D:
	var spec := {"park_landmark": true}
	var family := "reactor"
	var mounting := "dam_face"
	var home := Vector3.ZERO
	var terrain := Floor.new()
	var stage := 1
	var fleet = null
	var world_root: Node = null
	var lost := 0
	var _charging := false
	var _pulse_clock := 0.0
	var _charge_time := 0.0
	var _posture = Reactor.DamPosture.new({})
	func chunks_lost() -> int:
		return lost
	func cycle_now() -> float:
		return 6.0
	func family_point_at() -> Vector3:
		return home + Vector3.UP * 5.0
	func flat_to_ball() -> Vector3:
		return Vector3.FORWARD


var _t := T.new("warden_ratchet_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ChallengeDials.reset()
	_ratchet()
	await _lanes()
	ChallengeDials.reset()
	quit(_t.verdict())


func _ratchet() -> void:
	var w := Held.new()
	for stage in [2]:
		w.stage = stage
		w._lost_peak = 0
		w._cycle_lost = 0
		var base: float = Warden.pulse_cycle(stage)
		var last := INF
		for lost in BossPosture.CHUNKS:
			w.left = BossPosture.CHUNKS - lost
			var running: float = w.cycle_now()
			_t.near("stage %d, %d lost mid-cycle: the running cycle keeps its length" % [stage, lost], running, last if lost > 0 else base, 0.0001)
			w._cycle_lost = w.chunks_lost()
			var cycle: float = w.cycle_now()
			_t.near("stage %d, %d chunks lost: cycle is base x 0.9^%d" % [stage, lost, lost], cycle, base * pow(0.9, lost), 0.0001)
			_t.check("stage %d, %d lost: tighter than before" % [stage, lost], cycle < last, "%.3f after %.3f" % [cycle, last])
			_t.check("stage %d, %d lost: rest at least REST_FLOOR" % [stage, lost], cycle - Warden.pulse_telegraph(stage) >= Warden.REST_FLOOR - 0.0001)
			last = cycle
		_t.near("stage %d: the tell is unchanged" % stage, Warden.pulse_telegraph(stage), Warden.PULSE_TELEGRAPH)
	w.stage = 2
	w._lost_peak = 0
	w.left = 2
	w._cycle_lost = w.chunks_lost()
	var tight: float = w.cycle_now()
	w.left = 4
	w._cycle_lost = w.chunks_lost()
	_t.near("a drained bar keeps the tighter cycle", w.cycle_now(), tight)
	for flat in [1, 3]:
		w.stage = flat
		w._lost_peak = 0
		w.left = 1
		w._cycle_lost = w.chunks_lost()
		_t.near("stage %d (the dam, and past world 1) stays flat" % flat, w.cycle_now(), Warden.pulse_cycle(flat))
	ChallengeDials.set_overrides({"warden.pulse_ratchet_by_stage": [0.1, 0.1, 1.0, 1.0, 1.0, 1.0]})
	w.stage = 1
	w._lost_peak = 0
	w.left = 1
	w._cycle_lost = w.chunks_lost()
	_t.near("a steep ratchet floors at tell + REST_FLOOR", w.cycle_now(), Warden.pulse_telegraph(1) + Warden.REST_FLOOR)
	ChallengeDials.reset()
	w.free()


func _lanes() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var m := Mount.new()
	m.world_root = root
	var d := Reactor.new()
	d.sheet_dir = Vector3.FORWARD
	var right := Vector3.FORWARD.cross(Vector3.UP)
	var mid := Vector3.FORWARD * (Reactor.SHEET_RUN * 0.5)
	d.on_charge(m, 2.0)
	_t.eq("no chunk lost: the whole sheet, no faint lane", d.lane, 0)
	_t.eq("no chunk lost: nothing drawn at the charge", _drawn(root).size(), 0)
	d.on_pulse(m, false)
	_t.check("the whole sheet carries both sides", d.in_sheet(m, mid + right * 8.0) and d.in_sheet(m, mid - right * 8.0))
	for lost in [1, 2, 3]:
		m.lost = lost
		m._charging = true
		d.on_charge(m, 2.0)
		_t.check("%d lost: one half opens" % lost, d.lane in [1, -1], str(d.lane))
		var drawn := _drawn(root)
		_t.eq("%d lost: the charge draws the lane faint" % lost, drawn.size(), 1)
		var shown: MeshInstance3D = drawn[0]
		_t.near("%d lost: the faint lane is half the sheet and a margin past the core" % lost, shown.mesh.get_aabb().size.x, Reactor.SHEET_WIDTH * 0.5 + Reactor.LANE_PAST_CORE)
		_t.check("%d lost: the faint lane sits on its side" % lost, signf(shown.global_position.dot(right)) == float(d.lane))
		d.on_pulse(m, false)
		await process_frame
		var open: Vector3 = mid + right * d.lane_offset()
		var shut: Vector3 = mid - right * d.lane_offset()
		_t.check("%d lost: the open half carries the ride" % lost, d.in_sheet(m, open))
		_t.check("%d lost: the other half is dry" % lost, not d.in_sheet(m, shut))
		_t.check("%d lost: the core's line keeps its water" % lost, d.in_sheet(m, mid) and d.in_sheet(m, mid - right * float(d.lane) * (Reactor.LANE_PAST_CORE - 0.1)))
		_t.check("%d lost: the marked foot is in the open half" % lost, signf(d._sheet_foot(m).dot(right)) == float(d.lane))
	_t.check("a stagger-cancelled charge's lane goes with it", _cancelled(d, m, root))
	_t.near("the dam's rest never cuts the sheet's run", d.rest_floor(m), Reactor.SHEET_SECONDS)
	m.mounting = "flume"
	_t.near("the flume keeps the plain rest floor", d.rest_floor(m), 0.0)
	m.mounting = "dam_face"
	d.on_exit(m)
	m.free()
	root.queue_free()
	await process_frame


func _drawn(root: Node) -> Array:
	return root.get_children().filter(func(n): return not n.is_queued_for_deletion())


func _cancelled(d, m, root) -> bool:
	d.sheet_left = 0.0
	d.on_charge(m, 2.0)
	m._charging = false
	d.step(m, 1.0 / 90.0)
	return not is_instance_valid(d._sheet_view)

# smoke: solo timeout=60s
