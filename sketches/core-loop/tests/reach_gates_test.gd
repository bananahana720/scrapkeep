extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const Parts := preload("res://src/build/parts.gd")

# The Reach's gates stand at three fixed slots and the workshop bay always docks behind them
# (unit Z3). The Warden's break is the real flow's: with the ball parked at 16 spots round the
# bowl (8 on a 20 m ring, 8 on a 44 m one) the kill handler opens the gates, and each time the
# offers stand on the map's slots facing +z, the bay has docked at the sheet's deck height and
# cradle, and it never warned that there was no clear dock. The real offer count is two, so
# the two outermost slots are used; a three-gate offer fills all three slots. A control run
# with the slots emptied (the old placement at the ball) must fail to dock on at least one
# spot; there only the dock is judged, since the old placement never stood on the slots.
# Last, with the ball parked past the row on the south bank, the gates stay where they are:
# the offer is published once and not again on every tick, and rolling back north through a
# gate takes it, because a gate that cannot move must open from both sides.

const RINGS := [20.0, 44.0]
const SPOTS_PER_RING := 8
const DECK_Y := 47.5
const DECK_TOLERANCE := 1.0
const CRADLE := Vector2(-28.0, 134.0)
const SLOT_TOLERANCE := 0.05
const PAST_ROW := Vector2(0.0, 162.0)
const PAST_TICKS := 60

var _t := T.new("reach_gates_test")
var _game
var _ticks := 0
var _mode := "slots"
var _spot := 0
var _step := 0
var _bad := {"slots": [], "control": []}
var _three_bad: Array = []
var _slots: Array = []
var _offered := 0
var _past_left := 0
var _chosen: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_game.events.reward_offered.connect(func(_offers: Array): _offered += 1)
		return false
	if _ticks == 4:
		_slots = _game.ctx.terrain.map().gate_slots.duplicate(true)
		_t.check("the Reach publishes three gate slots", _slots.size() == 3, "%d slots: %s" % [_slots.size(), _slots])
		return false
	if _ticks < 6:
		return false
	if _mode == "past":
		return _run_past()
	return _run_spot()


func _spot_at(index: int) -> Vector2:
	var ring: float = RINGS[index / SPOTS_PER_RING]
	var angle := TAU * float(index % SPOTS_PER_RING) / SPOTS_PER_RING
	return _game.ctx.terrain.map().beacon + Vector2.from_angle(angle) * ring


# One spot takes three ticks: enter the stage, park the ball, break the Warden. The checks
# read straight after the break, since the kill handler opens the gates and docks the bay
# before it returns.
func _run_spot() -> bool:
	var terrain = _game.ctx.terrain
	match _step:
		0:
			_game.flow.enter_stage(1, Vector3.ZERO, false)
			_step = 1
		1:
			var at := _spot_at(_spot)
			var ball: Vector3 = terrain.drop_point(at.x, at.y, 1.05)
			_game.player.reset_to(ball, Vector3(0.0, 0.0, 2.0))
			_game.player.body().global_position = ball
			_step = 2
		2:
			_game.flow.sealed = true
			_game.flow._on_enemy_killed("warden", _game.flow._warden_at, 0)
			_check_spot()
			_check_three()
			_spot += 1
			_step = 0
			if _spot == RINGS.size() * SPOTS_PER_RING:
				return _next_mode()
	return false


func _check_spot() -> void:
	var offers: Array = _game.ctx.build.gates.offers
	var bay = _game.world.bay
	var at := _spot_at(_spot)
	var problems := []
	if _mode == "slots" and _game.flow.state_name() != "gates":
		problems.append("flow %s" % _game.flow.state_name())
	# The rolled pair takes the two outermost slots; a hot-wired part waiting at the gates (the
	# Warden break's rare part, systems audit pass D) makes three and fills all three.
	var wanted: Array = _slots if offers.size() == 3 and _hotwire_waiting() else [_slots[0], _slots[2]]
	if _mode == "slots":
		if offers.size() != wanted.size():
			problems.append("%d offers" % offers.size())
		else:
			for i in offers.size():
				var o: Dictionary = offers[i]
				var want: Vector2 = wanted[i]["at"]
				if Vector2(o["at"].x, o["at"].z).distance_to(want) > SLOT_TOLERANCE or (o["facing"] as Vector3).distance_to(Vector3(0.0, 0.0, 1.0)) > 0.001:
					problems.append("gate %d at %s facing %s, slot %s" % [i, o["at"], o["facing"], want])
	if not bay.docked:
		problems.append("bay not docked")
	elif _mode == "slots" and (absf(bay.deck_y() - DECK_Y) > DECK_TOLERANCE or Vector2(bay.cradle_at.x, bay.cradle_at.z).distance_to(CRADLE) > 0.5):
		problems.append("deck y %.2f, cradle %s" % [bay.deck_y(), bay.cradle_at])
	if bay._warned:
		problems.append("no clear dock warning")
	if not problems.is_empty():
		_bad[_mode].append("spot %d at %s: %s" % [_spot, at, problems])


func _hotwire_waiting() -> bool:
	var pending: Dictionary = _game.ctx.build.hotwire_pending()
	return pending["state"] == "fit" and pending["part_id"] != "" and not pending["part_id"] in _game.run.parts


# A three-gate offer at the same spot: all three slots, in order, and the bay docks behind them.
func _check_three() -> void:
	if _mode != "slots":
		return
	var gates = _game.ctx.build.gates
	var bay = _game.world.bay
	var ids: Array = Parts.ids().slice(0, 3)
	var ball: Vector3 = _game.player.ball_position()
	gates.close()
	bay.undock()
	var offers: Array = gates.open(ids, ball, Vector3(0.0, 0.0, 1.0), [])
	_game.world._on_reward_offered(offers)
	var ok: bool = offers.size() == 3 and bay.docked and not bay._warned
	for i in mini(offers.size(), 3):
		var want: Vector2 = _slots[i]["at"]
		ok = ok and Vector2(offers[i]["at"].x, offers[i]["at"].z).distance_to(want) <= SLOT_TOLERANCE
	if not ok:
		_three_bad.append("spot %d: %d offers, docked %s" % [_spot, offers.size(), bay.docked])


func _next_mode() -> bool:
	if _mode == "slots":
		_t.check("gates stand at the slots and the bay docks, 16 of 16", _bad["slots"].is_empty(),
			"%d of %d spots failed: %s" % [_bad["slots"].size(), RINGS.size() * SPOTS_PER_RING, _bad["slots"]])
		_t.check("a three-gate offer fills the three slots, 16 of 16", _three_bad.is_empty(), "failed spots: %s" % [_three_bad])
		_mode = "control"
		_spot = 0
		_game.ctx.terrain.map().gate_slots = []
		return false
	_game.ctx.terrain.map().gate_slots = _slots
	_t.check("control: with the slots emptied the bay fails to dock somewhere", not _bad["control"].is_empty(),
		"%d of %d spots fail to dock without the slot path, first: %s" % [_bad["control"].size(), RINGS.size() * SPOTS_PER_RING,
			_bad["control"][0] if not _bad["control"].is_empty() else "none"])
	_mode = "past"
	_step = 0
	return false


# The ball parked past the gate row: the break opens the gates once, and they are not placed
# again while the ball stays there.
func _run_past() -> bool:
	var terrain = _game.ctx.terrain
	match _step:
		0:
			_game.flow.enter_stage(1, Vector3.ZERO, false)
			_step = 1
		1:
			var ball: Vector3 = terrain.drop_point(PAST_ROW.x, PAST_ROW.y, 1.05)
			_game.player.reset_to(ball, Vector3(0.0, 0.0, 2.0))
			_game.player.body().global_position = ball
			_step = 2
		2:
			_offered = 0
			_game.flow.sealed = true
			_game.flow._on_enemy_killed("warden", _game.flow._warden_at, 0)
			_past_left = PAST_TICKS
			_step = 3
		3:
			var at: Vector3 = terrain.drop_point(PAST_ROW.x, PAST_ROW.y, 1.05)
			_game.player.set_velocity_now(Vector3.ZERO)
			_game.player.body().global_position = at
			_past_left -= 1
			if _past_left == 0:
				var offers: Array = _game.ctx.build.gates.offers
				_t.check("past the row the offer is published once", _offered == 1 and offers.size() == (3 if _hotwire_waiting() else 2),
					"reward_offered fired %d times in %d ticks with the ball at %s; %d offers standing" % [_offered, PAST_TICKS, PAST_ROW, offers.size()])
				_game.ctx.build.gates.chosen.connect(func(id: String): _chosen.append(id))
				_step = 4
		4:
			_park(Vector2(_slots[0]["at"].x, _slots[0]["at"].y + 2.0))
			_step = 5
		5:
			var wanted: String = _game.ctx.build.gates.offers[0]["part_id"] if not _game.ctx.build.gates.offers.is_empty() else ""
			_park(Vector2(_slots[0]["at"].x, _slots[0]["at"].y - 2.0))
			_step = 6
			_past_left = 3
			_chosen.append("want:" + wanted)
		6:
			_past_left -= 1
			if _past_left == 0:
				var want: String = String(_chosen[0]).trim_prefix("want:")
				_t.check("a fixed gate opens from behind", _chosen.size() == 2 and _chosen[1] == want and want != "",
					"rolled north through the west gate from 2 m south of it; chosen %s" % [_chosen])
				_game.free()
				quit(_t.verdict())
				return true
	return false


func _park(at: Vector2) -> void:
	var ball: Vector3 = _game.ctx.terrain.drop_point(at.x, at.y, 1.05)
	_game.player.set_velocity_now(Vector3.ZERO)
	_game.player.body().global_position = ball
