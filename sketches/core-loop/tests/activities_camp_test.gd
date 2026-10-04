extends SceneTree

# Rule: each zone's enemy camp waits for ring entry, spawns one homogeneous pack,
# finishes only when all members die, and pays its authored named part plus 180 scrap
# once per stage entry. A retry rebuilds it unfinished. This checks live headless
# Game flow, enemies, pickups and signposting; it does not qualify human play feel.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")

var _game
var _failures := 0
var _done: Array = []
var _gained: Array = []
var _scrap: Array = []


func _initialize() -> void:
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _tick(at: Vector3, count := 1) -> void:
	for i in count:
		_game.player.reset_to(at, Vector3.ZERO)
		_game.player.body().global_position = at
		_game.world.activities._physics_process(1.0 / 60.0)
		await physics_frame


func _ground(at: Vector3) -> Vector3:
	return _game.ctx.terrain.drop_point(at.x, at.z, 1.05)


func _run() -> void:
	_clear_storage("user://test-%d" % OS.get_process_id())
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	# Isolate the optional camp from timed director reinforcements. The camp still
	# uses the real combat spawner and enemy death methods.
	_game.world.set_physics_process(false)
	_game.world.activities.set_physics_process(false)
	_game.events.activity_done.connect(func(id: String, _at: Vector3): _done.append(id))
	_game.events.part_gained.connect(func(id: String, source: String):
		if source == "activity_camp":
			_gained.append(id))
	_game.events.scrap_collected.connect(func(amount: int, _at: Vector3, _total: int): _scrap.append(amount))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	for stage in [1, 2]:
		if stage == 2:
			_game.flow.enter_stage(2, Vector3.ZERO, false)
		await physics_frame
		await _camp(stage, "chaser" if stage == 1 else "lobber", "hot_rivets" if stage == 1 else "long_spool")
	_game.free()
	print("activities_camp_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# Game.test_mode owns a process-specific user folder; clear that folder before boot.
func _clear_storage(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for folder in dir.get_directories():
		_clear_storage(path.path_join(folder))
		dir.remove(folder)


func _camp(stage: int, kind: String, named: String) -> void:
	var activities = _game.world.activities
	var map = _game.ctx.terrain.map()
	var camps: Array = map.activity_sites.filter(func(spec): return spec.id == "enemy_camp")
	_report("zone %d site" % stage, camps.size() == 1, "%d camp sites" % camps.size())
	var s = activities.site("enemy_camp")
	_report("entry unfinished", s != null and not s.started and not s.done and s.pack.is_empty() and s.view.lit(), "camp stands before ring entry")
	if s == null:
		return
	_report("authored reward", Parts.rows().has(named) and Parts.rarity_of(named) in ["common", "rare"], named)
	_report("zone reward resolved", s.rule.pay.named == named, str(s.rule.pay))
	var row := EventKinds.activity_row("enemy_camp")
	_report("camp signpost row", row.get("word") == "Camp" and row.get("shape") == "cross" and row.get("motion") == "steady"
		and row.get("sound") == "found_chime" and row.get("color") == "amber", str(row))
	_game.hud._engaged = false
	var targets: Array = _game.hud.edge_markers.targets().filter(func(target): return target.get("activity", "") == "enemy_camp")
	_report("camp marker", targets.size() == 1 and targets[0].at == s.global_position
		and EdgeMarkers.marker_color(targets[0]) == EventKinds.activity_color(s.id), "%d camp targets" % targets.size())
	_report("camp word", s.view.word.text == "Camp", s.view.word.text)
	if stage == 1:
		var at: Vector2 = camps[0].at
		var slope := 0.0
		for dx in [-8.0, 0.0, 8.0]:
			for dz in [-8.0, 0.0, 8.0]:
				slope = maxf(slope, absf(map.sample(at.x + dx + 0.25, at.y + dz)[0] - map.sample(at.x + dx - 0.25, at.y + dz)[0]) / 0.5)
				slope = maxf(slope, absf(map.sample(at.x + dx, at.y + dz + 0.25)[0] - map.sample(at.x + dx, at.y + dz - 0.25)[0]) / 0.5)
		_report("Spillway flat ground", slope < 0.2, "largest ring-ground slope %.3f" % slope)
	var outside := _ground(s.global_position + Vector3(14.0, 0.0, 0.0))
	await _tick(outside, 3)
	_report("outside ring", s.pack.is_empty() and not s.started and not s.done, "no pack before entry")
	await _tick(s.global_position + Vector3.UP * 12.0, 2)
	_report("above ring", s.pack.is_empty() and not s.started, "flying above the ring does not start it")
	_game.flow.retry_stage()
	await physics_frame
	s = activities.site("enemy_camp")
	_report("retry unfinished", s != null and not s.started and not s.done and s.pack.is_empty() and s.view.lit(), "retry restores camp")
	if s == null:
		return
	outside = _ground(s.global_position + Vector3(14.0, 0.0, 0.0))
	await _tick(outside, 2)
	var enemies_before := get_nodes_in_group("enemy").size()
	var inside := _ground(s.global_position + Vector3(4.0, 0.0, 0.0))
	await _tick(inside)
	var kinds: Array = s.pack.map(func(enemy): return String(enemy.kind))
	_report("one named-kind pack", s.started and kinds == [kind, kind, kind]
		and get_nodes_in_group("enemy").size() == enemies_before + 3, str(kinds))
	if s.pack.size() != 3:
		return
	var pack: Array = s.pack.duplicate()
	await _tick(outside, 2)
	await _tick(inside, 2)
	_report("ring reentry", s.pack == pack and get_nodes_in_group("enemy").size() == enemies_before + 3, "same pack, no second spawn")
	var done_before := _done.count("enemy_camp")
	pack[0].take_damage(100000.0)
	pack[1].take_damage(100000.0)
	await _tick(outside, 2)
	_report("partial pack", not s.done and s.pickup == null and _done.count("enemy_camp") == done_before, "two dead pays nothing")
	pack[2].take_damage(100000.0)
	await _tick(outside, 2)
	_report("pack dead", s.done and not s.view.lit() and _done.count("enemy_camp") == done_before + 1, "camp finishes once")
	_report("named pickup", s.pickup != null and s.pickup_part == named, "want %s, got %s" % [named, s.pickup_part])
	if s.pickup == null:
		return
	var parts_before: int = _game.run.parts.size()
	var gained_before := _gained.size()
	_scrap.clear()
	await _tick(outside, 2)
	_report("pickup waits", _game.run.parts.size() == parts_before and _scrap.is_empty(), "part and scrap wait for collection")
	await _tick(_ground(s.pickup.global_position), 2)
	_report("named part paid", _game.run.parts.size() == parts_before + 1 and _gained.slice(gained_before) == [named]
		and _game.run.parts.back() == named, "camp gains %s" % [_gained.slice(gained_before)])
	_report("usual scrap", _scrap == [180], "scrap facts %s" % [_scrap])
	activities._finish(s, s.global_position)
	await _tick(outside, 2)
	await _tick(_ground(s.global_position), 3)
	_report("paid once", s.done and s.pickup_taken and s.pickup == null and s.pack == pack
		and activities.site("enemy_camp") == s and _gained.size() == gained_before + 1
		and _scrap == [180] and _done.count("enemy_camp") == done_before + 1, "no rebuild, respawn or second payment in stage")
	_game.flow.retry_stage()
	await physics_frame
	var rebuilt = activities.site("enemy_camp")
	_report("paid retry reset", rebuilt != null and rebuilt != s and not rebuilt.done and not rebuilt.started
		and not rebuilt.pickup_taken and rebuilt.pickup == null and rebuilt.pack.is_empty(), "paid camp rebuilds only on next entry")
