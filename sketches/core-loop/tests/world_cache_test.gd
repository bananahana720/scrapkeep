extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const TierMark := preload("res://src/build/tier_mark.gd")

# The cracked wall behind stage 1's vault plinth and the cache in its pocket
# (LOOP-REDESIGN section 9), in the running game as Kest in calm. Rolled into at
# 10 m/s the wall holds; at 24 m/s it crumbles the tick before contact and the ball keeps
# its speed. While sealed its gauge reads the approach speed and E cannot reach the
# chest. Inside, E opens the chest, three parts rise, and rolling onto one takes it as a
# cache part.

const KEST := 2
const SLOW := 10.0
const FAST := 24.0

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _steps: Array = []
var _index := 0
var _ticks := 0
var _entered := false
var _cache
var _crumbled: Array = []
var _gained: Array = []
var _gauge_seen := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if _steps.is_empty():
		_begin()
		return false
	if _index >= _steps.size():
		print("world_cache_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	if _cache != null and _cache.state == CrackedCache.SEALED:
		_gauge_seen = maxf(_gauge_seen, _cache.gauge())
	var step: Array = _steps[_index]
	if not _entered:
		_entered = true
		_ticks = 0
		(step[0] as Callable).call()
		return false
	_ticks += 1
	if _ticks < int(step[1]):
		return false
	(step[2] as Callable).call()
	_index += 1
	_entered = false
	return false


func _begin() -> void:
	_game.player.source = _source
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(KEST)
	_game.events.world_fact.connect(func(kind: String, _at: Vector3):
		if kind == "wall_crumbled":
			_crumbled.append(_game.player.planar_velocity().length()))
	_game.events.part_gained.connect(func(part: String, source: String): _gained.append([part, source]))
	_steps = [
		[_noop, 30, _find_cache],
		[_run_at_wall.bind(SLOW), 90, _check_holds],
		[_press_at_wall, 4, _check_sealed_press],
		[_run_at_wall.bind(FAST), 60, _check_breaks],
		[_inside_pocket, 6, _press_e],
		[_noop, 4, _check_open],
		[_onto_pedestal, 4, _check_taken],
		[_enter_reach, 30, _check_reach_cache],
		[_enter_deep, 30, _check_deep_cache],
	]


func _noop() -> void:
	pass


func _enter_deep() -> void:
	_game.ctx.calm = true
	_game.flow.enter_stage(4, Vector3.ZERO, false)


func _enter_reach() -> void:
	_game.ctx.calm = true
	_game.flow.enter_stage(2, Vector3.ZERO, false)


func _check_reach_cache() -> void:
	var cache: Node3D = _game.world.activities.site("cracked_cache") as Node3D
	_report("Reach cache is present", cache != null, "activities %s" % _game.world.activities.sites.map(func(site): return site.id))
	if cache != null:
		var gap := _nearest_external_wall(cache, 2)
		_report("Reach cache clears nearby map wall colliders", gap < 0.0 or gap >= CrackedCache.LANE_OFFSET - 0.01,
			"nearest external wall %s" % ("none within 30 m" if gap < 0.0 else "%.2f m away" % gap))


func _check_deep_cache() -> void:
	var map = _game.ctx.terrain.map()
	var deep_cache
	for device in _game.world.interact.devices:
		if device is CrackedCache and device.id == "relic_cache":
			deep_cache = device
	_report("Dig deep relic cache is placed", deep_cache != null, "devices %s" % [_game.world.interact.devices.map(func(d): return d.id)])
	if deep_cache != null:
		# GATEFIX (2026-10-08): a relic cache sits on its authored spot (relics_per_world_test pins
		# it within 0.01 m), so the lane offset is not a shadow proxy here; the wall-gap check below is.
		var gap := _nearest_external_wall(deep_cache, 4)
		_report("Dig deep cache clears nearby map wall colliders", gap < 0.0 or gap >= CrackedCache.LANE_OFFSET - 0.01,
			"nearest external wall %s" % ("none within 30 m" if gap < 0.0 else "%.2f m away" % gap))


func _find_cache() -> void:
	for device in _game.world.interact.devices:
		if device is CrackedCache:
			_cache = device
	_report("cache placed", _cache != null, "stage 1 carries a cracked cache: %s" % (_cache.id if _cache != null else "none"))
	if _cache != null:
		# A per-cache light freed on a stage change segfaulted Godot 4.7.2 Forward+ at the
		# next boss entry (GPU only); the rim is an emissive lip instead.
		_report("cache adds no dynamic light", _cache.find_children("*", "Light3D", true, false).is_empty(),
			"%d lights under the cache" % _cache.find_children("*", "Light3D", true, false).size())
		var shell := _cache.find_child("CacheShell", false, false) as GeometryInstance3D
		_report("the rim glow is its own strip, not an overlay on the shell", _cache.find_child("CacheRimGlow", false, false) != null and (shell == null or shell.material_overlay == null),
			"shell overlay %s" % [shell.material_overlay if shell != null else "no shell"])
		_report("sealed cache keeps its warm rim glow", _cache._rim_glow != null and is_equal_approx(_cache._rim_glow.emission_energy_multiplier, CrackedCache.RIM_GLOW.sealed),
			"rim glow %.2f" % (_cache._rim_glow.emission_energy_multiplier if _cache._rim_glow != null else 0.0))
		var authored_at: Vector2 = _cache.spec["at"]
		var authored: Vector3 = _game.ctx.terrain.drop_point(authored_at.x, authored_at.y, 0.0)
		_report("cache clears its wall shadow", _cache.global_position.distance_to(authored) >= CrackedCache.LANE_OFFSET - 0.01,
			"root offset %.2f m from authored wall point" % _cache.global_position.distance_to(authored))
		var gap := _nearest_external_wall(_cache, 1)
		_report("Reach cache clears nearby map wall colliders", gap < 0.0 or gap >= CrackedCache.LANE_OFFSET - 0.01,
			"nearest external wall %s" % ("none within 30 m" if gap < 0.0 else "%.2f m away" % gap))


func _nearest_external_wall(cache: Node3D, stage: int) -> float:
	var nearest := INF
	var stage_root: Node3D = _game.ctx.terrain.geometry_root(stage)
	for body in stage_root.find_children("*", "StaticBody3D", true, false):
		if cache.is_ancestor_of(body):
			continue
		for shape_node in body.find_children("*", "CollisionShape3D", true, false):
			if not shape_node.shape is BoxShape3D:
				continue
			var size: Vector3 = shape_node.shape.size
			if size.y < 6.0 or minf(size.x, size.z) > 2.5:
				continue
			var local: Vector3 = shape_node.to_local(cache.global_position)
			var half := size * 0.5
			var closest: Vector3 = local.clamp(-half, half)
			var gap: float = shape_node.to_global(closest).distance_to(cache.global_position)
			if gap <= 30.0:
				nearest = minf(nearest, gap)
	return -1.0 if is_inf(nearest) else nearest


func _local_ground(local: Vector3) -> Vector3:
	var at: Vector3 = _cache.to_global(local)
	return _game.ctx.terrain.drop_point(at.x, at.z, 1.05)


func _place(at: Vector3, velocity := Vector3.ZERO) -> void:
	_game.player.reset_to(at, velocity)
	_game.player.body().global_position = at
	_source.hold = {}
	_source.press = {}


# Five metres out from the wall's face, rolling straight at it.
func _run_at_wall(speed: float) -> void:
	_gauge_seen = 0.0
	var into: Vector3 = -_cache.global_basis.z
	_place(_local_ground(Vector3(0.0, 0.0, CrackedCache.HALF_D + 6.0)), into * speed)
	_game.camera.snap(into)


func _check_holds() -> void:
	var local: Vector3 = _cache.to_local(_game.player.ball_position())
	_report("a slow ball meets a wall", not _cache.broken() and _crumbled.is_empty() and local.z > CrackedCache.HALF_D,
		"rolled at the wall at %.0f m/s: broken %s, ball still outside it (%.1f m from the pocket's middle), gauge peaked %.2f"
			% [SLOW, _cache.broken(), local.z, _gauge_seen])


func _press_at_wall() -> void:
	_place(_local_ground(Vector3(0.0, 0.0, CrackedCache.HALF_D + 2.5)))
	_game.camera.snap(-_cache.global_basis.z)
	_source.press["mount_pressed"] = true


func _check_sealed_press() -> void:
	_report("sealed, E cannot reach it", _cache.state == CrackedCache.SEALED and _cache.prompt.keycap == "",
		"E at the sealed wall: state %d, keycap \"%s\"" % [_cache.state, _cache.prompt.keycap])


func _check_breaks() -> void:
	var at_break: float = _crumbled[0] if not _crumbled.is_empty() else 0.0
	_report("a fast ball breaks it", _cache.broken() and _crumbled.size() == 1 and at_break >= FAST * 0.9 and _gauge_seen >= 1.0,
		"rolled at the wall at %.0f m/s: crumbled %d time(s) with the ball at %.1f m/s, gauge reached %.2f"
			% [FAST, _crumbled.size(), at_break, _gauge_seen])
	_report("fired cache gets its warm fill", _cache._rim_glow != null and is_equal_approx(_cache._rim_glow.emission_energy_multiplier, CrackedCache.RIM_GLOW.fired)
		and _cache.find_children("*", "Light3D", true, false).is_empty(),
		"rim glow %.2f" % (_cache._rim_glow.emission_energy_multiplier if _cache._rim_glow != null else 0.0))


# Inside the pocket, five metres from the chest, facing it.
func _inside_pocket() -> void:
	_place(_local_ground(Vector3(0.0, 0.0, 1.2)))
	_game.camera.snap(-_cache.global_basis.z)


func _press_e() -> void:
	_source.press["mount_pressed"] = true


func _check_open() -> void:
	var shown := 0
	for p in _cache._pedestals:
		if p["node"].visible:
			shown += 1
	_report("E opens the chest", _cache.state == CrackedCache.PICKING and _cache.offers.size() == CrackedCache.PICKS and shown == CrackedCache.PICKS,
		"E inside the pocket: state %d, %d parts offered %s, %d pedestals up" % [_cache.state, _cache.offers.size(), _cache.offers, shown])
	_check_gem_colours()


# Every pedestal gem takes its colour from the item ladder (a relic is not painted as arc by
# default, a rare is not brass): the shown gems match their part's rarity rung.
func _check_gem_colours() -> void:
	var ok := true
	var seen := []
	for i in _cache.offers.size():
		# A cache may offer a relic (RL2), which is a part on the relic rung.
		var offer: String = _cache.offers[i]
		var d: Resource = Parts.def(offer)
		var rarity: String = d.rarity if d != null else "common"
		var holder: Node3D = _cache._pedestals[i]["gem"]
		var mark: Node3D = holder.get_child(holder.get_child_count() - 1)
		var gem: Color = (mark.get_child(0) as MeshInstance3D).material_override.albedo_color
		seen.append(rarity)
		ok = ok and gem == ItemGen.RARITY[rarity]["color"] and String(mark.name) == "Tier_" + TierMark.shape_of(rarity)
	var ladder := true
	for rarity in ItemGen.RARITIES:
		ladder = ladder and CrackedCache.gem_color(rarity) == ItemGen.RARITY[rarity]["color"]
	_report("gems wear the ladder colour and shape", ok and ladder and CrackedCache.gem_color("relic") == ItemGen.RARITY["relic"]["color"],
		"offered rarities %s, every rung read from ItemGen.RARITY, each gem its TierMark shape" % [seen])


func _onto_pedestal() -> void:
	var p: Dictionary = _cache._pedestals[1]
	_place(_local_ground(p["at"]))


func _check_taken() -> void:
	var want: String = _cache.offers[1] if _cache.offers.size() > 1 else ""
	_report("roll onto one to take it", _gained == [[want, "cache"]] and _cache.state == CrackedCache.TAKEN and _cache.spent,
		"rolled onto the middle pedestal: gained %s, state %d, spent %s" % [_gained, _cache.state, _cache.spent])
