extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const Triggers := preload("res://src/build/triggers.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Augments := preload("res://src/movement/augments.gd")
const SimClock := preload("res://src/core/sim_clock.gd")


const TICKS_PER_SECOND := 90.0
const LINE_EVERY := 5.0
const LINE_SIZE := 3
const LINE_AHEAD := 16.0
const HEAVY_EVERY := 15.0
const MAX_ENEMIES := 24
const STALL_SPEED := 1.0
const STALL_SECONDS := 10.0
const TICK_BUDGET_MS := 16.7
const SPEED_CEILING := 60.0
const OUTLIER := 3.0
const INJECT_AT := 0.75
const REDUCTION_CAP := 0.3

var _settings := {}
var _seeds: Array[int] = []
var _seconds := 90.0
var _out := ""
var _index := -1
var _game
var _driver
var _build
var _results: Array[Dictionary] = []
var _anomalies: Array[Dictionary] = []

var _ticks := 0
var _drafted := false
var _parts: Array = []
var _line_clock := 0.0
var _heavy_clock := 0.0
var _stall := 0.0
var _peak_speed := 0.0
var _tick_ms: Array[float] = []
var _natural := {}
var _injected := {}
var _mine: Array[Dictionary] = []
var _flags := {}
var _last_usec := 0


func _initialize() -> void:
	SimClock.ticks = true
	_settings = _parse(OS.get_cmdline_user_args())
	_out = _settings.get("out", "user://item-fuzz")
	_seconds = float(_settings.get("seconds", "90"))
	_seeds = _seed_list(String(_settings.get("seeds", "1-200")))
	_out = ProjectSettings.globalize_path(_out)
	if not _out.is_absolute_path():
		_out = OS.get_environment("PWD").path_join(_out)
	if _settings.has("child") and _seeds.size() != 1:
		printerr("item_fuzz: a child must run exactly one seed")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	for name in ["fuzz.ndjson", "anomalies.md"]:
		var f := FileAccess.open(_out.path_join(name), FileAccess.WRITE)
		if f != null:
			f.close()
	if _settings.has("child"):
		_next()
	else:
		_run_children()


func _run_children() -> void:
	var out := _out
	var inconclusive := 0
	for i in _seeds.size():
		var child_out := out.path_join("children/%d-seed-%d" % [i + 1, _seeds[i]])
		DirAccess.make_dir_recursive_absolute(child_out)
		var previous := {}
		for kind in ["DATA", "CONFIG", "CACHE"]:
			var key: String = "XDG_%s_HOME" % kind
			previous[key] = {"present": OS.has_environment(key), "value": OS.get_environment(key)}
			OS.set_environment(key, child_out.path_join("state/" + kind.to_lower()))
		var args := PackedStringArray(["--signal=KILL", "%ss" % _settings.get("child-timeout", "600"),
			OS.get_executable_path(), "--headless", "--fixed-fps", "90", "--path",
			ProjectSettings.globalize_path("res://"), "--script", "res://tools/item_fuzz.gd", "--",
			"--child=1", "--seeds=%d" % _seeds[i], "--seconds=%s" % _seconds, "--out=" + child_out])
		var output := []
		var code := OS.execute("timeout", args, output, true)
		for key in previous:
			if previous[key]["present"]:
				OS.set_environment(key, previous[key]["value"])
			else:
				OS.unset_environment(key)
		var log := "".join(output)
		var file := FileAccess.open(child_out.path_join("child.log"), FileAccess.WRITE)
		if file != null:
			file.store_string(log)
		var records: Array = []
		var lines := FileAccess.open(child_out.path_join("fuzz.ndjson"), FileAccess.READ)
		while lines != null and not lines.eof_reached():
			var line := lines.get_line().strip_edges()
			var parsed = JSON.parse_string(line) if line != "" else null
			if parsed is Dictionary:
				records.append(parsed)
		if code != 0 or records.size() != 1 or int(records[0].get("seed", -1)) != _seeds[i] or log.contains("SCRIPT ERROR"):
			inconclusive += 1
			printerr("item_fuzz: seed %d INCONCLUSIVE (child exit %d, %d records); see %s" % [_seeds[i], code, records.size(), child_out])
			continue
		var record: Dictionary = records[0]
		for key in ["seed", "size", "generated", "ticks", "kills"]:
			record[key] = int(record[key])
		for a in record["anomalies"]:
			a["seed"] = int(a["seed"])
			a["tick"] = int(a["tick"])
		_results.append(record)
		_anomalies.append_array(record["anomalies"])
		var ndjson := FileAccess.open(out.path_join("fuzz.ndjson"), FileAccess.READ_WRITE)
		if ndjson != null:
			ndjson.seek_end()
			ndjson.store_line(JSON.stringify(record))
			ndjson.close()
		for line in log.split("\n", false):
			if line.begins_with("item_fuzz: seed "):
				print(line)
	_finish(3 if inconclusive > 0 else 0)


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if arg.begins_with("--") and "=" in arg:
			out[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	return out


static func _seed_list(text: String) -> Array[int]:
	var out: Array[int] = []
	for part in text.split(",", false):
		if "-" in part:
			var ends := part.split("-")
			for n in range(int(ends[0]), int(ends[1]) + 1):
				out.append(n)
		else:
			out.append(int(part))
	return out


func _next() -> void:
	_index += 1
	if _index >= _seeds.size():
		_finish()
		return
	Engine.time_scale = 1.0
	seed(_seeds[_index])
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_driver = null
	_build = null
	_ticks = 0
	_drafted = false
	_parts = []
	_line_clock = 0.0
	_heavy_clock = HEAVY_EVERY * 0.5
	_stall = 0.0
	_peak_speed = 0.0
	_tick_ms = []
	_natural = {}
	_injected = {}
	_mine = []
	_flags = {}
	_last_usec = 0


func _physics_process(delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_tick_ms.append((now - _last_usec) / 1000.0)
	_last_usec = now
	if _driver == null:
		_driver = BotDriver.new(_game, ["skipper", "completionist", "random"][_seeds[_index] % 3], _seeds[_index])
		_driver.start()
		_build = _game.ctx.build
		return false
	var ended: bool = _driver.tick(delta)
	if _game.flow.in_stage() and not _drafted:
		_draft()
	if _drafted:
		_ticks += 1
		_scripted_line(delta)
		_check_tick(delta)
		if _ticks == int(_seconds * INJECT_AT * TICKS_PER_SECOND):
			_inject_missing()
	if ended or float(_ticks) / TICKS_PER_SECOND >= _seconds:
		_close(ended)
	return false


func _draft() -> void:
	_drafted = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["fuzz", _seeds[_index]])
	var run = _game.run
	var class_id: String = run.class_id()
	var want := rng.randi_range(6, 14)
	while _parts.size() < want:
		var roll := rng.randi_range(0, 9)
		var picks: Array = []
		if roll < 6:
			picks = Parts.roll_gate(rng, PartOffers.gate_rarities(rng.randi_range(0, 2)), class_id, _parts, 2, rng.randi_range(1, 3))
			if not picks.is_empty():
				picks = [picks[rng.randi_range(0, picks.size() - 1)]]
		elif roll < 8:
			picks = Parts.roll(rng, PartOffers.SOURCE_RARITIES["fabricator"], class_id, _parts, 1)
		elif roll < 9:
			picks = Parts.roll(rng, PartOffers.SOURCE_RARITIES["vault"], class_id, _parts, 1)
		else:
			picks = [PartOffers.milestone_for("event_%d" % rng.randi(), _parts)]
		for part_id in picks:
			_parts.append(part_id)
			run.add_part(part_id, "fuzz")


func _scripted_line(delta: float) -> void:
	if not _game.flow.in_stage() or _game.ctx.spawner == null:
		return
	if _game.get_tree().get_nodes_in_group("enemy").size() >= MAX_ENEMIES:
		return
	_line_clock -= delta
	_heavy_clock -= delta
	var ball: Vector3 = _game.player.ball_position()
	var heading: Vector3 = _game.player.planar_velocity()
	heading = heading.normalized() if heading.length() > 2.0 else -_game.camera.yaw_basis().z
	if _line_clock <= 0.0:
		_line_clock = LINE_EVERY
		for i in LINE_SIZE:
			var spot: Vector3 = ball + heading * (LINE_AHEAD + 1.6 * i)
			_game.ctx.spawner.spawn_enemy("chaser", _game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))
	if _heavy_clock <= 0.0:
		_heavy_clock = HEAVY_EVERY
		var spot: Vector3 = ball + heading * (LINE_AHEAD + 8.0)
		_game.ctx.spawner.spawn_enemy("miniboss", _game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))


func _check_tick(delta: float) -> void:
	var player = _game.player
	var run = _game.run
	var pos: Vector3 = player.ball_position()
	var vel: Vector3 = player.state.velocity
	if not (pos.is_finite() and vel.is_finite() and is_finite(run.hp) and is_finite(run.max_hp)):
		_flag("non_finite_ball", "ball %s velocity %s hp %s" % [pos, vel, run.hp], "finite", "The ball's numbers went non-finite.")
	for node in _game.get_tree().get_nodes_in_group("enemy"):
		if node is Node3D and is_instance_valid(node) and not (node as Node3D).global_position.is_finite():
			_flag("non_finite_enemy", "enemy at %s" % (node as Node3D).global_position, "finite", "An enemy flew off to infinity.")
	if _game.ctx.spawner != null and _game.ctx.spawner.has_method("live_projectiles"):
		var live: int = _game.ctx.spawner.live_projectiles()
		if live > Bolts.MAX_LIVE:
			_flag("bolts", "%d live bolts" % live, "%d" % Bolts.MAX_LIVE, "More bolts in the air than the cap allows.")
	var abilities = player.abilities
	for slot in ItemEffects.SLOTS:
		var s = abilities.slot(slot)
		if s.max_charges > ItemEffects.MAX_CHARGES or s.charges > s.max_charges:
			_flag("charges_" + slot, "%s %d of %d" % [slot, s.charges, s.max_charges], "%d" % ItemEffects.MAX_CHARGES, "A slot stocked past its ceiling.")
		if s.cooldown > 0.0 and abilities.cooldown_of(slot) < AbilityState.COOLDOWN_FLOOR - 0.0001:
			_flag("floor_" + slot, "%s cooldown %.2f s" % [slot, abilities.cooldown_of(slot)], "0.4 s", "A cooldown slipped under the floor.")
	if _build.effects.damage_reduction > REDUCTION_CAP + 0.0001:
		_flag("reduction", "%.2f" % _build.effects.damage_reduction, "%.2f" % REDUCTION_CAP, "Damage reduction passed its hyperbolic cap.")
	var stats: Dictionary = _build.trigger_stats()
	if stats["leaked"] or stats["max_same_kind"] > 1:
		_flag("guard", "leaked %s, same kind %d in a pass" % [stats["leaked"], stats["max_same_kind"]], "1", "A trigger fired twice in one commitment.")
	for kind in stats["fired"]:
		if not _injected.has(kind):
			_natural[kind] = true
	var state: String = _game.flow.state_name()
	var speed: float = player.planar_velocity().length()
	if state in ["stage", "beacon"]:
		_peak_speed = maxf(_peak_speed, speed)
		if speed > SPEED_CEILING:
			_flag("speed", "%.1f m/s" % speed, "%.0f m/s" % SPEED_CEILING, "Something stacked the ball past any ceiling a part names.")
		_stall = _stall + delta if speed < STALL_SPEED and run.alive() else 0.0
		if _stall > STALL_SECONDS:
			_flag("stall", "%.0f s under %.0f m/s" % [_stall, STALL_SPEED], "%.0f s" % STALL_SECONDS, "The ball sat still with the bot at the wheel.")
	else:
		_stall = 0.0


func _inject_missing() -> void:
	var ball: Vector3 = _game.player.ball_position()
	var near: Array = _build.enemies_near(ball, 40.0, 1)
	var target: Node3D = near[0] if not near.is_empty() else null
	for kind in 12:
		if _natural.has(kind):
			continue
		_injected[kind] = true
		_build._post(kind, "fuzz", 1.0, target.global_position if target != null else ball, target, 12.0)


func _flag(kind: String, reading: String, cap: String, description: String) -> void:
	if _flags.has(kind):
		return
	_flags[kind] = true
	_mine.append({"seed": _seeds[_index], "class": _game.run.class_id(), "build": _parts.duplicate(), "tick": _ticks,
		"kind": kind, "reading": reading, "cap": cap, "description": description})


func _close(ended: bool) -> void:
	var procs: Dictionary = _build.item_procs() if _build != null else {}
	var sorted := _tick_ms.duplicate()
	sorted.sort()
	var p99: float = sorted[int(sorted.size() * 0.99)] if not sorted.is_empty() else 0.0
	if p99 > TICK_BUDGET_MS:
		_flag("frame_time", "p99 %.1f ms" % p99, "%.1f ms" % TICK_BUDGET_MS, "Ticks ran over the frame budget.")
	var natural: Array = _natural.keys().map(func(k): return Triggers.name_of(k))
	var injected: Array = _injected.keys().map(func(k): return Triggers.name_of(k))
	var record := {
		"seed": _seeds[_index], "class": _game.run.class_id(), "policy": _driver.policy if _driver != null else "",
		"build": _parts, "size": _parts.size(), "generated": _parts.filter(func(p): return ItemGen.is_generated(p)).size(),
		"ticks": _ticks, "ended": _driver.outcome if ended and _driver != null else "", "kills": _game.run.kills,
		"peak_speed": snappedf(_peak_speed, 0.1), "tick_p99_ms": snappedf(p99, 0.01),
		"natural": natural, "injected": injected, "procs": procs, "anomalies": _mine,
	}
	_results.append(record)
	_anomalies.append_array(_mine)
	_game.codex.append_line(_out.path_join("fuzz.ndjson"), JSON.stringify(record))
	print("item_fuzz: seed %d (%s, %d parts) %d ticks, %d kills, peak %.1f m/s, natural %d/12, %d anomalies"
		% [record["seed"], record["class"], record["size"], _ticks, record["kills"], _peak_speed, natural.size(), _mine.size()])
	_game.free()
	_game = null
	_next()


func _outliers() -> void:
	var buckets := {}
	for r in _results:
		var key := int(r["size"]) / 3
		var list: Array = buckets.get(key, [])
		list.append(r)
		buckets[key] = list
	for key in buckets:
		var list: Array = buckets[key]
		if list.size() < 5:
			continue
		for stat in ["peak_speed", "kills"]:
			var values: Array = list.map(func(r): return float(r[stat]))
			values.sort()
			var median: float = values[values.size() / 2]
			if median <= 0.0:
				continue
			for r in list:
				if float(r[stat]) > OUTLIER * median:
					_anomalies.append({"seed": r["seed"], "class": r["class"], "build": r["build"], "tick": r["ticks"],
						"kind": "outlier_" + stat, "reading": "%s" % r[stat], "cap": "3x median %.1f" % median,
						"description": "This build's %s ran far past its peers'." % ("speed" if stat == "peak_speed" else "kill count")})


func _finish(code := 0) -> void:
	_outliers()
	var file := FileAccess.open(_out.path_join("anomalies.md"), FileAccess.WRITE)
	if file != null:
		for a in _anomalies:
			file.store_line("- seed %d, %s, tick %d: %s, %s (cap %s). %s Build: %s. KEEP / KILL"
				% [a["seed"], a["class"], a["tick"], a["kind"], a["reading"], a["cap"], a["description"], ", ".join(PackedStringArray(a["build"]))])
		file.close()
	var natural_all := {}
	for r in _results:
		for k in r["natural"]:
			natural_all[k] = true
	print("item_fuzz: %d seeds, %d anomalies, %d of 12 trigger kinds fired naturally somewhere, written to %s"
		% [_results.size(), _anomalies.size(), natural_all.size(), ProjectSettings.globalize_path(_out)])
	quit(code)
