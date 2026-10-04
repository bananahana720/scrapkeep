extends SceneTree

const Game := preload("res://src/game.gd")
const EventDirector := preload("res://src/world/event_director.gd")

# The fall-line layout on the legacy double stages, in the real physics world: the beacon's
# mast top is in clear sight from the 14 m entry drop, the spawn is above the beacon,
# every scrap line (so every fabricator B stands on one) lies within 25 m of the
# spawn-to-beacon line, the vault and each event ring sit 40 m or more off it with a
# way back that never climbs, the beacon bowl banks at 20 degrees or more on at least
# half of its 30-45 m ring, and the sky never holds more than three pillars.

const DROP := 14.0
const MAST_TOP := 18.0
const NEAR_LINE := 25.0
const OFF_LINE := 40.0
const RETURN_DROP := 3.0
const RETURN_CLIMB := 1.5
const BANK_DEG := 20.0
const BANK_SHARE := 0.5
const MAX_PILLARS := 3

# The straight fall-line rule predates the Reach's authored routes. Keep it on the
# double's gorge; reach_gates_test covers the current Reach's fixed gate placement.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _failures := 0
var _stage := 0
var _wait := 0
var _phase := "static"
var _frames := 0


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


# The event view hides all but one event beam in its own _process, so the beams are only
# settled once a rendered frame has run after the stage was entered. Physics ticks can
# batch ahead of rendered frames under load, so the pillar count waits on frames too.
func _process(_delta: float) -> bool:
	_frames += 1
	return false


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	match _phase:
		"static":
			if _stage == 0:
				_stage = 1
				_game.ctx.terrain.use(_stage)
				_wait = 0
				return false
			_wait += 1
			if _wait < 3:
				return false
			_check_layout(_stage)
			_stage += 1
			_wait = 0
			if _stage <= _game.ctx.stages.COUNT:
				_game.ctx.terrain.use(_stage)
			else:
				_stage = 0
				_phase = "pillars"
				_game.flow.press_start()
				_game.flow.choose_class(0)
		"pillars":
			if _stage == 0 or (_wait >= 4 and _frames >= 2):
				if _stage > 0:
					_check_pillars(_stage)
				_stage += 1
				_wait = 0
				_frames = 0
				if _stage > _game.ctx.stages.COUNT:
					return _finish()
				_game.flow.enter_stage(_stage, Vector3(0.0, 0.0, 18.0), false)
				for offer in _game.world.events.offers:
					offer["phase"] = EventDirector.ARMED
				return false
			_wait += 1
	return false


func _probe_line(from: Vector3, to: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


static func _v2(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


# Walks the line from the projection of site toward the beacon until the ground is
# RETURN_DROP below the site, then checks the straight run back never climbs above
# the site by more than RETURN_CLIMB.
func _downhill_return(map, site: Vector2) -> Dictionary:
	var t = _game.ctx.terrain
	var h0: float = t.height(site.x, site.y)
	var a: Vector2 = map.spawn
	var b: Vector2 = map.beacon
	var along := clampf((site - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	var rejoin := Vector2.INF
	var s := along
	while s <= 1.0:
		var p := a.lerp(b, s)
		if t.height(p.x, p.y) < h0 - RETURN_DROP:
			rejoin = p
			break
		s += 2.0 / (b - a).length()
	if rejoin == Vector2.INF:
		return {"ok": false, "detail": "no point on the line sits %.0f m below it" % RETURN_DROP}
	var climb := -INF
	var steps := int(site.distance_to(rejoin))
	for i in steps + 1:
		var p := site.lerp(rejoin, float(i) / maxf(1.0, steps))
		climb = maxf(climb, t.height(p.x, p.y) - h0)
	return {"ok": climb <= RETURN_CLIMB, "detail": "rejoins at (%.0f, %.0f) %.1f m lower, highest point %.1f m over the site"
		% [rejoin.x, rejoin.y, h0 - t.height(rejoin.x, rejoin.y), climb]}


func _check_layout(stage: int) -> void:
	var t = _game.ctx.terrain
	var map = t.map()
	var spawn: Vector3 = t.spawn_point(stage)
	var beacon: Vector3 = t.beacon_point(stage)
	var hit := _probe_line(spawn + Vector3.UP * DROP, beacon + Vector3.UP * MAST_TOP)
	_report("stage %d sightline" % stage, hit.is_empty(),
		"%s: from the drop at (%.0f, %.1f, %.0f) to the mast top at (%.0f, %.1f, %.0f): %s"
			% [map.title, spawn.x, spawn.y + DROP, spawn.z, beacon.x, beacon.y + MAST_TOP, beacon.z,
				"clear" if hit.is_empty() else "blocked at %s" % str(hit["position"])])
	_report("stage %d descent" % stage, spawn.y - 2.0 > beacon.y,
		"spawn ground %.1f m, beacon %.1f m, %.0f m apart" % [spawn.y - 2.0, beacon.y, _v2(spawn).distance_to(_v2(beacon))])

	var worst := 0.0
	for line in map.scrap_lines:
		worst = maxf(worst, maxf(map.off_line(line[0]), map.off_line(line[1])))
	_report("stage %d on the line" % stage, worst <= NEAR_LINE and not map.scrap_lines.is_empty(),
		"%d scrap lines, and so every fabricator stood on one, lie at most %.1f m off the fall line"
			% [map.scrap_lines.size(), worst])

	var spots := {"vault": map.vault}
	for id in map.sites:
		spots[id] = map.sites[id]["ring"]
	for id in spots:
		var site: Vector2 = spots[id]
		var off: float = map.off_line(site)
		var back := _downhill_return(map, site)
		_report("stage %d %s off the line" % [stage, id], off >= OFF_LINE and back["ok"],
			"(%.0f, %.0f) sits %.1f m off the fall line; %s" % [site.x, site.y, off, back["detail"]])

	var banked := 0
	var samples := 0
	var tan_min := tan(deg_to_rad(BANK_DEG))
	for r in [32.0, 36.0, 40.0, 44.0]:
		for i in 36:
			var dir := Vector2.from_angle(i * TAU / 36.0)
			var inner: Vector2 = map.beacon + dir * (r - 2.0)
			var outer: Vector2 = map.beacon + dir * (r + 2.0)
			var slope: float = (t.height(outer.x, outer.y) - t.height(inner.x, inner.y)) / 4.0
			samples += 1
			if slope >= tan_min:
				banked += 1
	var share := float(banked) / float(samples)
	_report("stage %d beacon berm" % stage, share >= BANK_SHARE,
		"%.0f%% of %d samples on the 30-45 m ring bank upward at %d degrees or more" % [share * 100.0, samples, int(BANK_DEG)])


func _check_pillars(stage: int) -> void:
	var shown := 0
	for node in root.get_tree().get_nodes_in_group("sky_pillar"):
		if node.is_visible_in_tree():
			shown += 1
	var armed: int = _game.world.events.offers.size()
	_report("stage %d sky pillars" % stage, shown + 1 <= MAX_PILLARS and shown >= 1,
		"with %d event offer(s) armed and the vault %s, the sky shows %d world pillar(s) plus the beacon's"
			% [armed, "standing" if _game.world.vault != null else "absent", shown])


func _finish() -> bool:
	print("world_route_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
