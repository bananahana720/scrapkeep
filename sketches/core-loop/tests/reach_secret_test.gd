extends SceneTree

# Rule: Cable Reach's authored valve cache stays closed until its own cruise-speed
# ram (or slam), uses the shared cache pickup/payment once, and rebuilds on retry.
# Headless real Game flow and contraption ticks; no human discoverability verdict.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Activities := preload("res://src/world/activities.gd")
const Parts := preload("res://src/build/parts.gd")

var _game
var _failures := 0
var _gained: Array = []
var _done: Array = []
var _prompts: Array = []
var _facts: Array = []
# Cogs the first-discovery burst paid (f4fb4c5, 2026-10-04: one cog per scrap unit). The
# burst announces them on cogs_collected; the cache pays silently, so its payment is the
# wallet change less these.
var _burst_cogs := 0


func _initialize() -> void:
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _clear_storage(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for folder in dir.get_directories():
		_clear_storage(path.path_join(folder))
		dir.remove(folder)


func _tick(c, at: Vector3, velocity: Vector3, frames := 1) -> void:
	for i in frames:
		_game.player.reset_to(at, velocity)
		_game.player.body().global_position = at
		for fact in c.step(1.0 / 60.0, at, velocity, _game.player.kit, false):
			_game.world._contraption_fact(fact)
		await physics_frame


func _secret(c) -> Dictionary:
	for v in c.valves:
		if v["spec"]["id"] == "reach_cache_valve":
			return v
	return {}


func _run() -> void:
	_clear_storage("user://test-%d" % OS.get_process_id())
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.world.set_physics_process(false)
	_game.world.activities.set_physics_process(false)
	_game.events.part_gained.connect(func(id: String, source: String):
		if source == "activity_cache":
			_gained.append(id))
	_game.events.activity_done.connect(func(id: String, _at: Vector3): _done.append(id))
	_game.events.prompt_shown.connect(func(verb: String): _prompts.append(verb))
	_game.events.world_fact.connect(func(kind: String, _at: Vector3): _facts.append(kind))
	_game.events.cogs_collected.connect(func(amount: int, _total: int): _burst_cogs += amount)
	_game.flow.press_start()
	# Non-mounting pilot: Sable's wall-mount prompt fires prompt_shown("interact") whenever a
	# _process frame lands while the ball is placed against the valve door or cache pocket walls.
	_game.flow.choose_class(1)
	var parked = _game.world.contraptions.get(2)
	_report("parked Reach has no active cache colliders", parked != null and not _secret(parked).has("cache_site"),
		"cache is built only on Reach entry")
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await physics_frame
	var c = _game.world.contraptions.get(2)
	_report("Reach feeds Contraptions.setup", c != null and c.map == _game.ctx.terrain.map(), "live owner for alpha zone 1-2")
	if c != null:
		await _cache(c)
	_game.free()
	print("reach_secret_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _cache_cogs() -> int:
	return _game.run.cogs - _burst_cogs


func _cache(c) -> void:
	var v := _secret(c)
	_report("authored valve exists", not v.is_empty() and v.has("cache_site"), "map valve builds the hidden cache")
	if v.is_empty() or not v.has("cache_site"):
		return
	var s = v["cache_site"]
	var at: Vector3 = v["at"]
	var cruise: float = _game.ctx.tuning.f("cruise")
	var velocity := Vector3(0.0, 0.0, cruise)
	var codex_id: String = v["spec"]["codex"]["id"]
	_report("closed on entry", not v["open"] and v["sink"] == 0.0 and v["door"].position == v["door_home"]
		and not s.done and s.pickup == null, "door blocks the empty pedestal")
	_report("real door collider", v["door"] is StaticBody3D and v["door"].get_child(0) is CollisionShape3D
		and not v["door"].get_child(0).disabled, "existing valve builder supplies collision")
	var door_view := v["door"].get_node_or_null("ValveDoor") as MeshInstance3D
	var door_box: Vector3 = (v["door"].get_child(0).shape as BoxShape3D).size
	_report("door draws the valve door model", door_view != null and not door_view.mesh is PrimitiveMesh
		and door_view.scale.is_equal_approx(door_box / Vector3(12.0, 6.0, 1.0))
		and v["door"].find_children("*", "MeshInstance3D", true, false).size() == 1, "one riveted gate scaled to the collider, no plain box")
	_report("shared cache rule", s.rule == Activities.RULES["cracked_cache"] and s.wall == null and not s.view.visible,
		"same pay/source/rarities, valve replaces cracked face, no prompt")
	await _tick(c, at, velocity * 0.99)
	await _tick(c, at + Vector3.RIGHT * 6.0, velocity)
	await _tick(c, at + Vector3.UP * 6.0, velocity)
	await _tick(c, s.pedestal + Vector3.UP, velocity)
	_report("only own trigger opens", not v["open"] and not s.done and s.pickup == null and _gained.is_empty(),
		"slow ram, remote ram, airborne ram and pedestal visit pay nothing")
	var cogs_before: int = _game.run.cogs
	_burst_cogs = 0
	var parts_before: int = _game.run.parts.size()
	await _tick(c, at, velocity)
	var rolled: String = s.pickup_part
	_report("cruise ram opens", v["open"] and s.done and s.pickup != null and _facts.has("valve_smashed")
		and _facts.has("route_opened"), "wheel ram opens door and reveals cache pickup")
	_report("real part waits", Parts.rows().has(rolled) and _game.ctx.stages.part_in_play(rolled)
		and _game.run.parts.size() == parts_before and _cache_cogs() == cogs_before, "rolled %s, unpaid until collection" % rolled)
	_report("codex line", _game.codex.known(codex_id) and _game.codex.name_of(codex_id) == "Pressure keeps the change"
		and _game.codex.entries("world").any(func(entry): return entry.id == codex_id and not entry.text.is_empty()), codex_id)
	await _tick(c, s.pedestal + Vector3.UP, velocity)
	_report("door must finish sinking", s.pickup != null and _gained.is_empty(), "cannot collect through opening door")
	await _tick(c, at + Vector3.RIGHT * 12.0, Vector3.ZERO, 40)
	_report("door clears route", v["sink"] == 1.0 and v["door"].position.y < (v["door_home"] as Vector3).y - 6.0,
		"door sank below pocket floor")
	await _tick(c, s.pedestal + Vector3.UP, velocity, 2)
	_report("cache pays once", s.pickup_taken and s.pickup == null and _gained == [rolled]
		and _game.run.parts.size() == parts_before + 1 and _cache_cogs() == cogs_before + Activities.PAY_SCRAP,
		"one part, %d cogs (burst paid %d apart)" % [Activities.PAY_SCRAP, _burst_cogs])
	# 2026-10-04 (gate read): the burst itself is pinned, so a duplicate burst cannot hide behind
	# the subtraction in _cache_cogs. One codex fact, one burst of BURST_PER_STAGE * stage.
	var burst_want: int = _game.flow.BURST_PER_STAGE * _game.run.stage
	_report("the discovery burst paid once", _burst_cogs == burst_want, "burst %d, want %d" % [_burst_cogs, burst_want])
	await _tick(c, at, velocity, 2)
	await _tick(c, s.pedestal + Vector3.UP, velocity, 2)
	_report("repeat trigger cannot repay", _gained == [rolled] and _done.count("cracked_cache") == 1
		and _cache_cogs() == cogs_before + Activities.PAY_SCRAP and _burst_cogs == burst_want,
		"one completion and one payment, burst still %d" % _burst_cogs)
	_report("no interaction prompt", not _prompts.has("interact"), str(_prompts))
	_game.flow.retry_stage()
	_burst_cogs = 0
	await physics_frame
	v = _secret(c)
	s = v["cache_site"]
	_report("retry restores secret", not v["open"] and v["sink"] == 0.0 and v["door"].position == v["door_home"]
		and not s.done and not s.pickup_taken and s.pickup == null and _game.run.parts.size() == parts_before
		and _game.run.cogs == cogs_before, "flow retry restores entrance and closed cache")
	await _tick(c, at, velocity)
	_report("retry repeats seeded pickup", s.pickup_part == rolled and s.pickup != null, s.pickup_part)
	await _tick(c, at + Vector3.RIGHT * 12.0, Vector3.ZERO, 40)
	await _tick(c, s.pedestal + Vector3.UP, velocity, 2)
	_report("retry can pay once again", _gained == [rolled, rolled] and _cache_cogs() == cogs_before + Activities.PAY_SCRAP,
		"rewound attempt earns one fresh payment")
