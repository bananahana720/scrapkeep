extends RefCounted


const Augments := preload("res://src/movement/augments.gd")

const HOLD_S := 0.6
const CRADLE_S := 40.0
const DECK_S := 50.0
const BRAKE_ABOVE := 3.0
const PLATE_GAP_S := 0.4
const TRADE_REACH := 12.0
const TRADE_S := 120.0
const ROUTE_REACHED := 15.0
const BELL_S := 90.0
const PIECE_S := 150.0
const CARRY_RINGS := 3
const LINE_HOME_TICKS := 4

var hands := {"called_shot": true, "bay": true, "trade": true, "overtime": true, "carry": true}

var _driver
var _game
var _stage_bay := -1
var _bay_done := {}
var _bay_clock := 0.0
var _plate_clock := 0.0
var _plate_step := 0
var _shot_state := ""
var _trade_stage := -1
var _trade_clock := 0.0
var _trade_told := false
var _bell_clock := 0.0
var _route: Array[Vector3] = []
var _trade_said := -1
var _press_gap := 0.0
var _route_for := ""
var _device_told := {}
var _piece_clock := 0.0
var _piece_stage := -1
var _rings_told := 0
var _pot_said := -1
var _cash_told := false
var _line_home := 0


func _init(driver, game) -> void:
	_driver = driver
	_game = game


func step(delta: float) -> void:
	_called_shot(delta)


func _called_shot(delta: float) -> void:
	var build = _game.ctx.build
	var shot = build.called_shot if build != null else null
	if shot == null or not shot.enabled():
		return
	if shot.state != _shot_state:
		_shot_state = shot.state
		_say("called shot is %s (%s)" % [shot.state if shot.state != "" else "idle", shot.called])
	if shot.state != "window":
		_line_home = 0
		return
	if not hands["called_shot"]:
		_driver.source.hold.erase("brake_held")
		return
	if hands["carry"] and _game.run.can_stow_core():
		_driver.source.hold.erase("brake_held")
		return
	var warden = _game.flow.warden
	if not is_instance_valid(warden):
		return
	var ball: Vector3 = _game.player.ball_position()
	_driver._look(ball, warden.global_position, false, delta)
	var to: Vector3 = warden.global_position - _game.ctx.aim_origin()
	var look: Vector3 = _game.ctx.aim_forward()
	var aimed: bool = Vector2(to.x, to.z).length() > 0.01 and Vector2(look.x, look.z).length() > 0.01 \
			and Vector2(to.x, to.z).normalized().dot(Vector2(look.x, look.z).normalized()) >= shot.AIM_DOT
	_driver.hold_off_warden_line(0.3)
	var kit = _game.player.kit
	_line_home = _line_home + 1 if not kit.hooked and kit.line_state == Augments.LINE_IDLE else 0
	if aimed and (_line_home >= LINE_HOME_TICKS or shot.held_s > 0.0) and shot.held_s < HOLD_S:
		_driver.source.hold["brake_held"] = true
	elif shot.held_s <= 0.0:
		_driver.source.hold.erase("brake_held")


func stage(delta: float) -> bool:
	if _driver._note.get("warden_engaged_s") != null:
		return false
	if _bell(delta):
		return true
	if _trade(delta):
		return true
	return _piece(delta)


func _piece(delta: float) -> bool:
	if _piece_stage != _game.run.stage:
		_piece_stage = _game.run.stage
		_piece_clock = 0.0
	if not hands["carry"] or not _game.run.companion.is_empty() or _piece_clock > PIECE_S:
		return false
	if _piece_clock == 0.0:
		for key in ["cracked_cache", "hauler_bounty"]:
			_driver.skip_activity(key)
		_say("piece: heading for the camp")
	_piece_clock += delta
	return _driver._activity_goal(delta)


func _bell(delta: float) -> bool:
	var locks = _game.world.locks if _game.world != null else null
	var overtime = locks.overtime if locks != null else null
	if overtime != null and overtime.rings != _rings_told:
		_rings_told = overtime.rings
		_say("overtime bell: %d rings, %s" % [overtime.rings, overtime.state])
	if overtime != null and overtime.cashed and not _cash_told:
		_cash_told = true
		_say("overtime pot cashed: cores %d" % _game.run.bonus_cores)
	var rings_wanted: int = CARRY_RINGS if hands["carry"] else 1
	if not hands["overtime"] or overtime == null or overtime.state != "offered" or overtime.rings >= rings_wanted:
		if hands["carry"] and overtime != null and overtime.state == "offered" and overtime.rings >= CARRY_RINGS:
			return _pot(overtime, delta)
		_bell_clock = 0.0
		return false
	_bell_clock += delta
	if _bell_clock > BELL_S:
		return false
	if _bell_clock <= delta * 1.5:
		_say("overtime bell: heading there")
	_driver._goal = "overtime bell"
	_driver._act(overtime.prop_at("bell"), null, delta)
	return true


func _pot(overtime, delta: float) -> bool:
	_bell_clock += delta
	if _bell_clock > BELL_S:
		return false
	_driver._goal = "overtime pot"
	if int(_bell_clock) % 10 == 0 and int(_bell_clock) != _pot_said:
		_pot_said = int(_bell_clock)
		_say("overtime pot: %.0f m away, speed %.1f, %s" % [_game.player.ball_position().distance_to(overtime.prop_at("pot")), _game.player.planar_velocity().length(), overtime.state])
	_driver._act(overtime.prop_at("pot"), null, delta)
	return true


func _trade(delta: float) -> bool:
	if not hands["trade"]:
		return false
	var activities = _game.world.activities if _game.world != null else null
	if activities == null:
		return false
	var stage_no: int = _game.run.stage
	if _trade_stage != stage_no:
		_trade_stage = stage_no
		_trade_clock = 0.0
		_trade_told = false
	for site in activities.sites:
		if not is_instance_valid(site) or site.rule.get("finishes", "") != "trade":
			continue
		if not _trade_told:
			_trade_told = true
			_say("trade %s at %.0f m: %s" % [site.id, _game.player.ball_position().distance_to(site.global_position), str(site.trade_devices.map(func(d): return d.offer.get("cost_kind", "") + ("/marks" if d.offer.get("marks", false) else "")))])
		if site.trade_devices.any(func(d): return d.spent):
			continue
		for device in site.trade_devices:
			if device.spent and not _device_told.has(str(device.id) + "spent"):
				_device_told[str(device.id) + "spent"] = true
				_say("trade device %s: taken" % device.id)
			if device.spent or not device.offer.get("marks", false) or not device.ready_now():
				continue
			_trade_clock += delta
			if not _device_told.has(device):
				_device_told[device] = true
				_say("trade device %s: heading there" % device.id)
			if _trade_clock > TRADE_S:
				if _trade_clock < TRADE_S + delta * 2.0:
					_say("trade device %s: out of time" % device.id)
				return false
			var ball: Vector3 = _game.player.ball_position()
			var at: Vector3 = device.reach_point()
			_driver._goal = "trade device"
			if int(_trade_clock) % 10 == 0 and int(_trade_clock) != _trade_said:
				_trade_said = int(_trade_clock)
				_say("trade: %.0f m away, %.0f m above, route %d points, speed %.1f" % [ball.distance_to(at), at.y - ball.y, _route.size(), _game.player.planar_velocity().length()])
			if _route_for != str(device.id):
				_route_for = str(device.id)
				_route = _driver._graph_path(ball, at)
			while not _route.is_empty() and Vector2(ball.x - _route[0].x, ball.z - _route[0].z).length() < ROUTE_REACHED:
				_route.pop_front()
			if ball.distance_to(at) > TRADE_REACH:
				_driver._act(at if _route.is_empty() else _route[0], null, delta)
			else:
				_creep(at, ball, delta)
				_driver.source.hold["mount_held"] = true
				var interact = _game.world.get("interact")
				_press_gap -= delta
				if interact != null and interact.target == device and interact.hold_fraction() <= 0.0 and _press_gap <= 0.0:
					_press_gap = 0.8
					_driver.source.press["mount_pressed"] = true
			return true
	return false


func gates(delta: float) -> bool:
	if not hands["bay"]:
		return false
	var bay = _game.world.bay if _game.world != null else null
	var workshop: Node = _game.get_node_or_null("Workshop")
	if bay == null or workshop == null:
		return false
	var stage: int = _game.run.stage
	if _bay_done.has(stage):
		return false
	if _stage_bay != stage:
		_stage_bay = stage
		_bay_clock = 0.0
		_plate_clock = 0.0
		_plate_step = 0
	if not bay.docked and not bay.inside:
		return false
	_bay_clock += delta
	var ball: Vector3 = _game.player.ball_position()
	if not bay.inside:
		if _plate_step >= 3:
			_bay_done[stage] = true
			return false
		if _bay_clock > CRADLE_S:
			_end_bay(stage, "cradle not reached")
			return false
		_driver._goal = "bay cradle"
		_driver._act(bay.cradle_at, null, delta)
		return true
	if _bay_clock > CRADLE_S + DECK_S:
		_end_bay(stage, "deck run out of time")
		return false
	if workshop.counter.is_open():
		_counter(workshop, delta)
		return true
	if _plate_step >= 3:
		_driver._goal = "bay pad"
		_driver._act(bay.pad_point(), null, delta)
		return true
	if _game.player.frozen():
		return true
	_driver._goal = "bay moss"
	_creep(bay.moss_point(), ball, delta)
	return true


func _say(line: String) -> void:
	print("self-play: hand %s (stage %d, %.0f s)" % [line, _game.run.stage, _game.run.stage_time])


func _end_bay(stage: int, why: String) -> void:
	_bay_done[stage] = true
	_say("stage %d bay: %s" % [stage, why])


func _creep(point: Vector3, ball: Vector3, delta: float) -> void:
	var to := Vector3(point.x - ball.x, 0.0, point.z - ball.z)
	var speed: float = _game.player.planar_velocity().length()
	_driver._look(ball, point, false, delta)
	var hold := {}
	if speed > BRAKE_ABOVE:
		hold["brake_held"] = true
	elif to.length() > 1.0:
		hold["move"] = _driver._world_to_stick(to.normalized())
	_driver.source.hold = hold


func _counter(workshop: Node, delta: float) -> void:
	_driver.source.hold = {}
	_plate_clock -= delta
	if _plate_clock > 0.0:
		return
	_plate_clock = PLATE_GAP_S
	var counter = workshop.counter
	match _plate_step:
		0:
			_say("counter open: cores %d (arrived %d), companion %s, stow plate %s" % [_game.run.bonus_cores, _game.run.arrived_core,
				"held" if not _game.run.companion.is_empty() else "none", str(counter.tile_for("stow").rec.get("state", "")) if counter.tile_for("stow") != null else "absent"])
			var tile = counter.tile_for("stow")
			if tile != null and String(tile.rec.get("state", "")) == "ok":
				counter.press(tile)
				_say("stow plate pressed")
			_plate_step = 1
		1:
			counter.set_face("sell")
			_plate_step = 2
		2:
			var tile = counter.tile_for("weigh")
			if tile != null and String(tile.rec.get("state", "")) == "ok":
				counter.press(tile)
				_say("weigh plate pressed")
			_plate_step = 3
		_:
			counter.leave_button().pressed.emit()
