extends SceneTree

# The world-native arrivals and the Dig's falling rock (design-v3/WORLD-ROSTERS.md), each on
# a stub world so every rule is read directly:
# - rubble_fall.gd: waits for the shared 0.2 s warning gap, commits one INSTANT disc, hits a
#   ball only while it is on the floor (a bank, a wall or the air is safe), never touches its
#   velocity, and crushes every enemy inside;
# - cave_ins.gd: a burrower breaking the floor starts one cave-in over its hole; none within
#   GAP_S of the last; a park with no burrower home has none;
# - fleet.gd lift_cage (park_pit.json's row): the cage climbs the shaft through the warning,
#   tops out at land and wakes its home; a slam inside sends it down and breaks the home;
# - fleet.gd zipline_drop (park_islands.json's row): the cable spans anchor to landing; a ball
#   in the air on the line cuts it and the crew never arrives; uncut, land wakes the home and
#   knocks nearby enemies straight out from the landing;
# - the four Dig and Highdraft parks carry the native kinds and no fleet_landing, and still
#   pass the park schema.

const T := preload("res://tests/support/t.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const GameDirector := preload("res://src/world/director.gd")
const RubbleFall := preload("res://src/world/events/rubble_fall.gd")
const WarningGap := preload("res://src/world/events/warning_gap.gd")
const CaveIns := preload("res://src/world/events/cave_ins.gd")
const Fleet := preload("res://src/world/events/fleet.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

const SEED := 4417
const BAR := 240.0 / 172.0
const FAR := Vector3(5000.0, 1.0, 5000.0)

var t := T.new("dig_highdraft_events_test")


class Map extends RefCounted:
	var park := {}


class Terrain extends RefCounted:
	var park := {}

	func height(x: float, z: float) -> float:
		return 12.0 + 0.02 * x - 0.01 * z

	func map() -> Map:
		var holder := Map.new()
		holder.park = park
		return holder


class BallState extends RefCounted:
	var grounded := true
	var contact_normal := Vector3.UP
	var velocity := Vector3(9.0, 0.0, 0.0)


class Ball extends Node3D:
	var state := BallState.new()
	var at := Vector3.ZERO

	func ball_position() -> Vector3:
		return at


class Ctx extends RefCounted:
	var player
	var run = null
	var events = null


class StageWorld extends RefCounted:
	var terrain := Terrain.new()
	var director
	var ctx := Ctx.new()


class Dummy extends Node3D:
	var kind := "dummy"
	var hp := 100.0
	var hidden := true
	var bursts := 0
	var knocked := Vector3.ZERO

	func take_damage(amount: float) -> float:
		hp -= amount
		return amount

	func is_dead() -> bool:
		return hp <= 0.0

	func knock(direction: Vector3, force: float) -> void:
		knocked = direction.normalized() * force


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	await _rubble()
	await _cave_ins()
	await _lift_cage()
	await _zipline()
	_parks()
	quit(t.verdict())


func _ground(at: Vector3) -> Vector3:
	var terrain := Terrain.new()
	return Vector3(at.x, terrain.height(at.x, at.z), at.z)


func _dummy(at: Vector3, kind := "dummy") -> Dummy:
	var d := Dummy.new()
	d.kind = kind
	d.add_to_group("enemy")
	root.add_child(d)
	d.global_position = at
	return d


# --- rubble_fall.gd ----------------------------------------------------------------------

func _fall(ball: Ball, hits: Array, damage := 50.0) -> Node3D:
	var fall = RubbleFall.new()
	fall.configure("test", _ground(Vector3.ZERO), 5.0, 1.0, Terrain.new(), ball, func(): hits.append(true), damage)
	root.add_child(fall)
	return fall


func _rubble() -> void:
	root.remove_meta(WarningGap.LAST_META)
	var ball := Ball.new()
	root.add_child(ball)
	ball.at = _ground(Vector3(1.0, 0.0, 1.0)) + Vector3.UP
	var velocity_before := ball.state.velocity
	var hits := []
	var inside := _dummy(_ground(Vector3(2.0, 0.0, 0.0)) + Vector3.UP)
	var outside := _dummy(_ground(Vector3(9.0, 0.0, 0.0)) + Vector3.UP)
	var fall = _fall(ball, hits)
	await _frames(2)
	t.check("a fall with the gap open commits at once", fall.committed() and fall.waited == 0, "waited %d" % fall.waited)
	t.eq("the roof disc is INSTANT", fall.hazard.type, Threat.Type.INSTANT)
	t.near("the disc radius", fall.hazard.r_out, 5.0)
	t.check("the warning is at least the hazard floor", fall.hazard.warn_seconds >= 1.0)
	var landed := []
	fall.landed.connect(func(crushed: Array, hit_ball: bool): landed.append([crushed, hit_ball]))
	await _frames(int(1.3 * Engine.physics_ticks_per_second))
	t.eq("the fall lands once", landed.size(), 1)
	t.eq("a ball on the floor inside is hit", hits.size(), 1)
	t.check("the enemy inside is crushed", inside.hp < 100.0, "hp %.1f" % inside.hp)
	t.near("the enemy outside is spared", outside.hp, 100.0)
	t.check("the fall never touched the ball's velocity", ball.state.velocity == velocity_before)
	t.check("the fall cleans itself up", not is_instance_valid(fall))

	# Off the floor: a bank (normal tilted past 25 degrees) and the air are both safe.
	for case in [["a ball on a bank", true, Vector3(0.6, 0.8, 0.0).normalized()], ["a ball in the air", false, Vector3.UP]]:
		hits.clear()
		ball.state.grounded = case[1]
		ball.state.contact_normal = case[2]
		root.remove_meta(WarningGap.LAST_META)
		fall = _fall(ball, hits, 0.0)
		await _frames(int(1.4 * Engine.physics_ticks_per_second))
		t.eq("%s is under nothing" % case[0], hits.size(), 0)
	ball.state.grounded = true
	ball.state.contact_normal = Vector3.UP

	# The gap: a warning stamped this frame holds the fall for MIN_GAP, then it commits.
	WarningGap.stamp(self, ball)
	fall = _fall(ball, hits, 0.0)
	var frames := 0
	while not fall.committed() and frames < 120:
		await physics_frame
		frames += 1
	t.check("a fall waits for the 0.2 s gap", fall.committed() and frames >= WarningGap.gap_frames() - 1 and frames <= WarningGap.gap_frames() + 1,
		"committed after %d frames, gap %d" % [frames, WarningGap.gap_frames()])
	t.eq("its commit stamps the shared clock", int(root.get_meta(WarningGap.LAST_META)), Engine.get_physics_frames() - 1 if frames > 0 else Engine.get_physics_frames())
	fall.free()
	for node in [inside, outside, ball]:
		node.free()


# --- cave_ins.gd -------------------------------------------------------------------------

func _cave_ins() -> void:
	root.remove_meta(WarningGap.LAST_META)
	var world := StageWorld.new()
	var ball := Ball.new()
	root.add_child(ball)
	ball.at = FAR
	world.ctx.player = ball
	world.terrain.park = {"home_rows": [{"id": "h", "enemy": "burrower", "site": "s"}]}
	var caves = CaveIns.new()
	root.add_child(caves)
	caves.setup(world)
	t.check("a park with a burrower home has cave-ins", caves.active)
	var burrower := _dummy(_ground(Vector3(30.0, 0.0, 10.0)) + Vector3.UP, "burrower")
	await _frames(3)
	t.eq("a hidden burrower brings no cave-in", caves.falls_started, 0)
	burrower.hidden = false
	burrower.bursts = 1
	await _frames(2)
	t.eq("a burrower breaking the floor starts one cave-in", caves.falls_started, 1)
	t.check("the cave-in is over its hole", caves.last_at.distance_to(burrower.global_position) < 0.01)
	burrower.hidden = true
	await _frames(2)
	burrower.hidden = false
	burrower.bursts = 2
	await _frames(2)
	t.eq("a second surfacing inside the gap starts none", caves.falls_started, 1)
	await _frames(int((CaveIns.GAP_S + 0.2) * Engine.physics_ticks_per_second))
	burrower.hidden = true
	await _frames(2)
	burrower.hidden = false
	burrower.bursts = 3
	await _frames(2)
	t.eq("past the gap the next surfacing caves in", caves.falls_started, 2)
	caves.release()
	caves.free()

	var dry := StageWorld.new()
	dry.terrain.park = {"home_rows": [{"id": "h", "enemy": "kite_drone", "site": "s"}]}
	var none = CaveIns.new()
	root.add_child(none)
	none.setup(dry)
	t.check("a park with no burrower home has none", not none.active)
	none.free()
	burrower.free()
	ball.free()


# --- the arrivals --------------------------------------------------------------------------

func _park_row(map_id: String, kind: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id))
	var row: Dictionary = data.event_rows.filter(func(r): return r.kind == kind)[0]
	var site: Dictionary = data.park_rows.filter(func(s): return s.id == row.site)[0]
	var home: Dictionary = data.home_rows.filter(func(h): return h.id == row.effect.home)[0]
	return {"data": data, "row": row, "site": site, "home": home}


# A stage with one event row whose home sits on the director, driven like the fleet test.
func _stage(entry: Dictionary, ball: Ball) -> Dictionary:
	var row: Dictionary = entry.row.duplicate(true)
	var home: Dictionary = entry.home.duplicate(true)
	home.broken = false
	var game := GameDirector.new(SEED)
	game.homes.append(home)
	var world := StageWorld.new()
	world.ctx.player = ball
	var data: Dictionary = entry.data
	world.terrain.park = {"map": "", "park_rows": [entry.site], "event_rows": [row], "weather_rows": [],
		"routes": data.routes, "spawn": data.spawn, "landmark": data.landmark, "activity_rows": [], "home_rows": []}
	world.director = game
	var handler = Fleet.new()
	root.add_child(handler)
	handler.setup(world)
	var map := Map.new()
	map.park = world.terrain.park
	var events := EventDirector.new(SEED, {}, map, 14.0, Callable(world.terrain, "height"))
	events.register_family("fleet", Callable(handler, "handle"))
	return {"row": row, "home": home, "game": game, "handler": handler, "events": events}


func _advance(stage: Dictionary, until: String) -> Array:
	var facts := []
	for step in int(30.0 * Engine.physics_ticks_per_second):
		var ctx := {"clock_tier": 4, "grounded": true, "bar_s": BAR, "bar_origin_s": 0.0, "pilot_lines": []}
		var delta := 1.0 / Engine.physics_ticks_per_second
		var tick: Array = stage.events.advance(delta, FAR, Vector3.ZERO, ctx)
		facts.append_array(tick)
		await physics_frame
		if tick.any(func(f): return f.kind == until and f.id == stage.row.id):
			return facts
	return facts


func _lift_cage() -> void:
	var ball := Ball.new()
	root.add_child(ball)
	ball.at = FAR
	var entry := _park_row("park_pit", "lift_cage")
	var stage := _stage(entry, ball)
	var handler = stage.handler
	var id: String = stage.row.id
	var facts := await _advance(stage, "announced")
	t.check("the lift cage announces", handler.active.has(id))
	if not handler.active.has(id):
		ball.free()
		return
	t.eq("its form is the cage climbing", facts.filter(func(f): return f.kind == "world").map(func(f): return f.fact), ["cage_rising"])
	var cage: Node3D = handler.active[id].cage
	var low := cage.position.y
	t.check("the cage starts deep in the shaft", low <= -(Fleet.CAGE_HEIGHT_M + Fleet.SHAFT_DEPTH_M) + 0.01, "y %.2f" % low)
	t.check("the home sleeps through the warning", not stage.game.home_live(stage.home.id))
	facts = await _advance(stage, "started")
	var climbed := cage.position.y
	t.check("land tops the cage out", absf(climbed) < 0.01, "y %.2f" % climbed)
	t.check("land wakes the cage's home", stage.game.home_live(stage.home.id))
	t.check("land publishes cage_landed", facts.any(func(f): return f.kind == "world" and f.fact == "cage_landed"))
	# A slam outside the cage does nothing; one inside sends it down with its crew.
	var at := Vector2(float(entry.site.at[0]), float(entry.site.at[1]))
	var ground: float = Terrain.new().height(at.x, at.y)
	handler.on_slammed(Vector3(at.x + 40.0, ground, at.y))
	t.eq("a slam outside the cage leaves it", handler.cages_dropped, 0)
	handler.on_slammed(Vector3(at.x + 2.0, ground + 0.5, at.y - 1.0))
	t.eq("a slam inside the cage sends it down", handler.cages_dropped, 1)
	t.check("its home is broken", not stage.game.home_live(stage.home.id))
	await _frames(int((Fleet.CAGE_DROP_S + 0.2) * Engine.physics_ticks_per_second))
	t.check("the cage drops back down the shaft", cage.position.y < -Fleet.CAGE_HEIGHT_M, "y %.2f" % cage.position.y)
	stage.events.end_all()
	t.check("end clears the cage", not handler.active.has(id))
	handler.release()
	handler.free()
	ball.free()


func _zipline() -> void:
	var ball := Ball.new()
	root.add_child(ball)
	ball.at = FAR
	ball.state.grounded = true
	var entry := _park_row("park_islands", "zipline_drop")
	# Uncut: land wakes the home and knocks the crowd out from the landing.
	var stage := _stage(entry, ball)
	var handler = stage.handler
	var id: String = stage.row.id
	var facts := await _advance(stage, "announced")
	t.check("the zipline announces", handler.active.has(id))
	if not handler.active.has(id):
		ball.free()
		return
	t.eq("its form is the trolley inbound", facts.filter(func(f): return f.kind == "world").map(func(f): return f.fact), ["zipline_inbound"])
	var ends: Array = handler.zip_ends(stage.row)
	t.check("the anchor is high over the landing", ends[0].y - ends[1].y >= 20.0, "%s to %s" % [ends[0], ends[1]])
	var near := _dummy(ends[1] + Vector3(4.0, 0.0, 3.0))
	var far := _dummy(ends[1] + Vector3(80.0, 0.0, 0.0))
	await _frames(30)
	var trolley: Node3D = handler.active[id].line.get_node("Trolley")
	var mark_y: float = handler.active[id].mark.position.y
	var ride: Vector3 = trolley.position + Vector3.UP * mark_y
	t.check("the trolley rides the cable", Geometry3D.get_closest_point_to_segment(ride, ends[0], ends[1]).distance_to(ride) < 0.05)
	t.check("a grounded ball under the line cuts nothing", handler.lines_cut == 0)
	facts = await _advance(stage, "started")
	t.check("land wakes the zipline's home", stage.game.home_live(stage.home.id))
	t.check("land publishes zipline_landed", facts.any(func(f): return f.kind == "world" and f.fact == "zipline_landed"))
	t.check("the impact knocks a near enemy straight out", near.knocked.length() > 0.0
		and Vector2(near.knocked.x, near.knocked.z).normalized().dot(Vector2(4.0, 3.0).normalized()) > 0.99, str(near.knocked))
	t.eq("a far enemy is left alone", far.knocked, Vector3.ZERO)
	stage.events.end_all()
	handler.release()
	handler.free()

	# Cut: a ball in the air on the line before land, and the crew never comes.
	stage = _stage(entry, ball)
	handler = stage.handler
	await _advance(stage, "announced")
	ball.state.grounded = false
	ball.at = ends[0].lerp(ends[1], 0.5)
	await _frames(2)
	t.eq("a ball flying through the line cuts it", handler.lines_cut, 1)
	ball.at = FAR
	ball.state.grounded = true
	await _advance(stage, "started")
	t.check("a cut line wakes no home", not stage.game.home_live(stage.home.id))
	stage.events.end_all()
	handler.release()
	handler.free()
	for node in [near, far, ball]:
		node.free()


# --- the parks -----------------------------------------------------------------------------

func _parks() -> void:
	var native := {"park_pit": "lift_cage", "park_sinkhole": "lift_cage", "park_islands": "zipline_drop", "park_crown": "zipline_drop"}
	for map_id in native:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id))
		var kinds: Array = data.event_rows.map(func(r): return r.kind)
		t.check("%s arrives by %s" % [map_id, native[map_id]], kinds.has(native[map_id]) and not kinds.has("fleet_landing"), str(kinds))
		var map = ParkMap.new("res://src/world/park/%s.json" % map_id)
		t.check("%s passes the park schema" % map_id, map.ok, str(map.errors.slice(0, 5)))
