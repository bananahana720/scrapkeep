# smoke: solo (verdict reads wall time: real-time hit-stop freeze under 100 ms)
extends SceneTree

const Game := preload("res://src/game.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")
const HitStopBudget := preload("res://src/core/hit_stop_budget.gd")
const Juice := preload("res://src/presentation/juice.gd")
const Palette := preload("res://src/core/palette.gd")

# Juice through the real game: the camera hooks fire for dash, slam and launch; a
# landing squashes the ball; the hits of one frame send one stop, never above the
# spine's 60 ms cap, measured on the real Engine.time_scale the spine drives. The
# damage bands, spacing and budget have their own test, presentation_hitstop_test.

var _game
var _juice
var _failures := 0
var _step := 0
var _wait_until := 0
var _enemy: Node3D
var _stop_started := -1
var _stop_seen_ms := 0.0
var _sent_before := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


# Sample the real-time freeze on both physics ticks and render frames: a loaded frame can run
# several physics ticks before the next _process(), so sampling only in _process() can miss the
# entire 5-tick dip and read 0 ms (w32 gate).
func _sample_freeze() -> void:
	if Engine.time_scale < 1.0:
		if _stop_started < 0:
			_stop_started = Time.get_ticks_usec()
	elif _stop_started >= 0:
		_stop_seen_ms = maxf(_stop_seen_ms, (Time.get_ticks_usec() - _stop_started) / 1000.0)
		_stop_started = -1


func _physics_process(_delta: float) -> bool:
	_sample_freeze()
	return false


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	var now := Time.get_ticks_msec()
	# Measure how long the spine really holds the freeze, in real time.
	_sample_freeze()
	if now < _wait_until:
		return false
	match _step:
		0:
			_juice = _game.presentation.juice
			# The pickup fountain wears the rung, but a common part (or an old uncommon id)
			# flashes sandstone, since mint flashes mean live; rare_plus wears the relic rung.
			for pair in [["focus_lens", Palette.SANDSTONE], ["reserve_tank", Palette.SANDSTONE],
					["sunforged_core", Palette.COBALT], ["warden_ward", Palette.AMBER]]:
				_check("fountain tint " + pair[0], Juice.part_tint(pair[0]) == pair[1], "%s -> %s" % [pair[0], Juice.part_tint(pair[0])])
			# An element still wins over the rung, as before the ladder: the fountain says what it does.
			var arc: Color = EventJuice.juice("part_gained")["element"].get("arc", Color.BLACK)
			_check("fountain tint arc_coil", Juice.part_tint("arc_coil") == arc, "common arc part -> %s" % Juice.part_tint("arc_coil"))
			# Without combat's resolver a hit lands for its force.
			_juice.plating_of = Callable()
			_juice.resolve_of = Callable()
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_enemy = Node3D.new()
			_game.add_child(_enemy)
			_enemy.global_position = _game.player.ball_position() + Vector3(0.0, 0.0, -4.0)
			_next(100)
		1:
			var before: float = _game.camera._punch
			_game.events.dashed.emit(Vector3.FORWARD)
			_check("dash punch", _logged("punch_fov", "dashed") and _game.camera._punch > before, "dashed -> punch_fov, camera fov punch %.1f deg" % _game.camera._punch)
			_game.events.landed.emit(20.0)
			_check("landing squash", _juice.squash_amount() > 0.2 and not _game.player.builtin_squash, "a 20 m/s landing squashes the ball by %.2f" % _juice.squash_amount())
			_game.events.slammed.emit(_game.player.ball_position(), 1.2, 1.0)
			_check("slam kick", _logged("kick", "slammed") and _logged("punch_fov", "slammed"), "slammed -> camera kick and a zoom-in punch")
			_check("slam no stop", _sent_for("slammed").is_empty(), "a slam on open ground asks for no hit-stop; only a break-through does")
			_game.events.launched.emit(Vector3(0.0, 20.0, 20.0))
			_check("launch punch", _logged("punch_fov", "launched") and _logged("kick", "launched"), "launched -> fov punch and kick")
			_next(400)
		2:
			_sent_before = _sent().size()
			for i in 5:
				_game.events.enemy_struck.emit(_enemy, "ram", 30.0)
			_game.events.enemy_struck.emit(_enemy, "ram", 10.0)
			_game.events.enemy_struck.emit(_enemy, "arc", 99.0)
			_game.events.enemy_struck.emit(_enemy, "stomp", 5.0)
			var logged_before: int = _juice.hit_stops.entries.size()
			_juice.flush()
			var sent := _sent().size() - _sent_before
			_check("no stack", sent == 1 and _juice.hit_stops.entries.size() - logged_before == 1,
				"eight hits in one frame ask once and send %d stop" % sent)
			_next(200)
		3:
			_juice.hit_stops.reset()
			_game.camera._shake = 0.0
			var gun_base: int = _juice.hit_stops.entries.size()
			var cues_before: int = _juice.audio.cue_log_total if _juice.audio != null else 0
			_juice.resolve_of = func(_e, _k, force): return {"dealt": force * 2.0, "punch": force, "full": true, "part": "", "plating": 0.0}
			for gun in ["runner", "arc", "turret"]:
				_game.events.enemy_struck.emit(_enemy, gun, 14.0)
			_game.events.enemy_struck.emit(_enemy, "runner", 40.0)
			_juice.flush()
			_juice.resolve_of = Callable()
			var pinged: bool = _juice.audio != null and _juice.audio.cues_since(cues_before).any(func(c: Array): return c[1] == "crit_ping")
			_check("guns do not stop", _juice.hit_stops.entries.size() == gun_base and _game.camera._shake == 0.0,
				"laser, arc and turret hits, crits among them, ask for %d stops and the camera shake is %.2f" % [_juice.hit_stops.entries.size() - gun_base, _game.camera._shake])
			_check("gun crit pings", pinged, "a crit on a gun kind still plays crit_ping")
			_juice.hit_stops.reset()
			_game.events.enemy_struck.emit(_enemy, "sticky", 16.0)
			_juice.flush()
			var bomb_shake: float = _game.camera._shake
			_check("bombs stop and shake", _sent_for("enemy_struck").size() >= 1 and bomb_shake > 0.0,
				"a sticky hit sends a stop and shakes the camera %.2f" % bomb_shake)
			_game.camera._shake = 0.0
			for blast in ["overdrive", "burst", "spill"]:
				_juice.hit_stops.reset()
				_game.camera._shake = 0.0
				var blast_base := _sent().size()
				_game.ctx.spawner.last_impact = {"key": blast, "enemy": _enemy.get_instance_id()}
				_game.events.enemy_struck.emit(_enemy, "runner" if blast == "overdrive" else "arc", 16.0)
				_juice.flush()
				_check("%s blast stops and shakes" % blast, _sent().size() > blast_base and _game.camera._shake > 0.0,
					"a %s hit published under a gun kind sends %d stops and shakes the camera %.2f" % [blast, _sent().size() - blast_base, _game.camera._shake])
			_juice.hit_stops.reset()
			_game.camera._shake = 0.0
			var other_base := _sent().size()
			_game.ctx.spawner.last_impact = {"key": "overdrive", "enemy": _enemy.get_instance_id() + 1}
			_game.events.enemy_struck.emit(_enemy, "runner", 16.0)
			_juice.flush()
			_check("another enemy's record is ignored", _sent().size() == other_base and _game.camera._shake == 0.0, "an impact record for a different enemy leaves a runner bolt with no stop and no shake")
			_game.ctx.spawner.last_impact = {}
			_game.camera._shake = 0.0
			_juice.hit_stops.reset()
			var rams_before := _sent().size()
			_game.events.enemy_struck.emit(_enemy, "ram", 20.0)
			_juice.flush()
			_check("rams stop and shake", _sent().size() > rams_before and _game.camera._shake > 0.0,
				"a ram sends a stop and shakes the camera %.2f" % _game.camera._shake)
			_juice.hit_stops.reset()
			var mixed_base := _sent().size()
			for i in 30:
				_game.events.enemy_struck.emit(_enemy, "sticky" if i % 2 == 0 else "ram", 40.0)
				_juice.flush()
			var mixed := 0.0
			for entry in _sent().slice(mixed_base):
				mixed += entry[1] * 1000.0
			_check("mixed burst keeps the budget", mixed <= HitStopBudget.STOP_BUDGET_MS + 0.5, "30 bomb and ram hits send %.0f ms of stop (budget %.0f)" % [mixed, HitStopBudget.STOP_BUDGET_MS])
			_game.camera._shake = 0.0
			_juice.hook_log.clear()
			_juice.squash(0.0, Vector3.FORWARD)
			_game.events.player_hit.emit(10.0, "chaser")
			_check("damage taken does not shake", _logged("edge_flash", "player_hit") and absf(_juice.squash_amount()) > 0.0 and _game.camera._shake == 0.0,
				"a hit taken flashes the edge, squashes the shell by %.2f and leaves the camera shake at %.2f" % [_juice.squash_amount(), _game.camera._shake])
			_next(200)
		4:
			var within := true
			var values: Array = []
			for entry in _sent():
				within = within and entry[1] > 0.0 and entry[1] <= Game.HIT_STOP_MAX
				values.append(entry[1])
			_check("stop length", within, "every sent stop is under the spine's %.0f ms cap: %s" % [Game.HIT_STOP_MAX * 1000.0, values])
			_check("real freeze", _stop_seen_ms > 0.0 and _stop_seen_ms < 60.0 + 40.0 and Engine.time_scale == 1.0,
				"longest observed Engine.time_scale dip %.0f ms (cap 60 ms plus frame granularity), time scale back to 1" % _stop_seen_ms)
			print("presentation_juice_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			_game.free()
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _next(wait_ms: int) -> void:
	_step += 1
	_wait_until = Time.get_ticks_msec() + wait_ms


func _logged(hook: String, fact: String) -> bool:
	for entry in _juice.hook_log:
		if entry[0] == hook and entry[1] == fact:
			return true
	return false


func _sent() -> Array:
	return _juice.hit_stops.entries.filter(func(entry: Array): return entry[1] > 0.0)


func _sent_for(fact: String) -> Array:
	return _sent().filter(func(entry: Array): return entry[2] == fact).map(func(entry: Array): return entry[1])


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
