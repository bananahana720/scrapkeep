# smoke: solo (its sixty simulated seconds run at wall pace, so a loaded batch pushes it toward the 120 s limit)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Activities := preload("res://src/world/activities.gd")
const ActivityView := preload("res://src/world/activity_view.gd")
const Palette := preload("res://src/core/palette.gd")
const BetCrate := preload("res://src/world/bet_crate.gd")
const AmbushAltar := preload("res://src/world/ambush_altar.gd")

# The three standing activities on the slice's Cable Reach (LEGIBILITY section 9, wave R3), on a
# live slice game:
# - at the stage's first frame three activity nodes stand at the sites' ground, each lit in the
#   row's amber, and no device stands;
# - the bounty: a plated brute stands at its site, off the director's cap; killing it leaves one
#   pickup where it fell; a ball 60 m away for 300 frames finds it back within 10 m;
# - the ambush: rolling into the ring brings exactly its three; two dead pays nothing, all three
#   leave one part at the altar, and touching it adds exactly one part;
# - the cache: a slow ram leaves the wall and answers with the roll's refused cue, once for two bumps
#   inside the cue's gap and again once the gap is spent; a ram at a held roll's speed breaks it with no
#   cue and one part waits on
#   the pedestal; a slam of at least cruise's strength breaks it too and a weaker one does not;
# - calm mode builds the cache alone;
# - no activity changes the ball's planar speed beyond what the same line costs with none;
# - with all three finished no timed event starts in 60 simulated seconds;
# - a retry restores three unfinished activities, and the default alpha table builds its authored activity sites.
# Every wait is counted in physics frames; none reads the wall clock.

const SEED := 11
const SIM_RATE := 120
const SIM_SECONDS := 60
const LEASH_FRAMES := 300
const SPEED_SLACK := 0.1
const RAM_BELOW := 0.7
const RAM_AT := 1.3
# A held stick's speed into a face on a 10-22 m run-up (12.6-13.8 m/s at cruise 14): under cruise,
# and it breaks the wall (Activities.RAM_MIN_PER_CRUISE).
const RAM_HELD := 0.92
const SIDE_CONTENT_PENDING := preload("res://src/core/pending_content.gd").SIDE_CONTENT_PENDING
const LINE_FRAMES := 24
const PICKUP_FRAMES := 40
const PICKUP_SPEED := 14.0
const RAM_FRAMES := 150

var _game
var _t := preload("res://tests/support/t.gd").new("activities_test")
var _source := Intent.Scripted.new()
var _done: Array = []
var _event_facts := 0
var _refused := 0


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot(table: String) -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = table
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = SEED
	_game.player.source = _source
	_done.clear()
	_event_facts = 0
	_game.events.activity_done.connect(func(id: String, _at: Vector3): _done.append(id))
	_game.events.verb_failed.connect(func(verb: String, _reason: String, _at: Vector3):
		if verb == "roll":
			_refused += 1)
	_game.events.event_announced.connect(func(_id: String, _seconds: float, _at: Vector3): _event_facts += 1)
	_game.events.event_started.connect(func(_id: String): _event_facts += 1)
	_game.events.event_ended.connect(func(_id: String, _outcome: String): _event_facts += 1)
	_game.events.event_progress.connect(func(_id: String, _fraction: float): _event_facts += 1)
	_game.events.milestone_won.connect(func(_id: String): _event_facts += 1)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)


func _site(id: String):
	return _game.world.activities.site(id)


func _ground(at: Vector3, lift := 1.05) -> Vector3:
	return _game.ctx.terrain.drop_point(at.x, at.z, lift)


func _hold(count: int) -> void:
	for i in count:
		_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame


func _put(at: Vector3, velocity := Vector3.ZERO) -> void:
	_game.player.reset_to(at, velocity)
	_game.player.set_velocity_now(velocity)


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# A ball rolled along a line from `start`: its planar speed on the first frame and after `frames`.
func _line(start: Vector3, velocity: Vector3, frames: int) -> Dictionary:
	_put(start, velocity)
	await physics_frame
	var before: float = _game.player.planar_velocity().length()
	await _frames(frames)
	return {"before": before, "after": _game.player.planar_velocity().length()}


func _kill(enemy) -> void:
	if is_instance_valid(enemy):
		enemy.take_damage(100000.0)


func _run() -> void:
	await _boot("slice")
	await physics_frame
	_lit()
	await _word()
	await _bounty()
	await _ambush()
	await _cache()
	await _all_done_quiet()
	await _retry()
	await _lifetime()
	await _calm()
	_game.free()
	await _frames(2)
	await _default_table()
	quit(_t.verdict())


# The word flies beside its column, never across it: centred, the amber column covered the
# middle letters of an amber word, and a sentence ran the width of the screen.
func _word() -> void:
	var view := ActivityView.new()
	root.add_child(view)
	view.build("ambush_altar", 8.0)
	view.near(Vector3.ZERO)
	# A billboard's box covers every facing; flat, the box is the laid-out letters.
	view.word.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	await _frames(2)
	# Corner-on the column reaches 0.99 m; the outline's reach is taken off the word's side as well,
	# whether or not the box counts it.
	var corner := ActivityView.COLUMN_WIDTH * 0.5 * sqrt(2.0) + ActivityView.WORD_OUTLINE * view.word.pixel_size
	var one: AABB = view.word.get_aabb()
	_t.check("an activity's word starts clear of its column, seen corner-on", view.word.visible and one.position.x > corner,
		"word from %.2f m, column to %.2f m" % [one.position.x, corner])
	view.word.text = "Head gate: wheel turning. Stay ahead of the water."
	await _frames(2)
	var long: AABB = view.word.get_aabb()
	var reach := (ActivityView.WORD_GAP + ActivityView.WORD_WIDTH) * view.word.pixel_size
	_t.check("a sentence folds into a block beside the column", long.position.x > corner and long.end.x <= reach + 0.2 and long.size.y > one.size.y * 1.8,
		"from %.2f to %.2f m (reach %.2f), %.2f m tall against %.2f" % [long.position.x, long.end.x, reach, long.size.y, one.size.y])
	view.free()


func _lit() -> void:
	var world = _game.world
	var map = _game.ctx.terrain.map()
	_t.eq("four activity nodes stand at the first frame", world.activities.sites.size(), 4)
	_t.eq("one device stands, the relic cache behind the valve (GP1)", world.interact.devices.size(), 1)
	for spec in map.activity_sites:
		var id := String(spec["id"])
		var s = _site(id)
		if s == null:
			_t.check("%s stands" % id, false, "no node for it")
			continue
		var want: Vector3 = _game.ctx.terrain.drop_point(spec["at"].x, spec["at"].y, 0.0)
		if id == "cracked_cache":
			var lane: Vector3 = s.global_basis.z * Activities.CACHE_LANE_OFFSET
			want = _game.ctx.terrain.drop_point(spec["at"].x + lane.x, spec["at"].y + lane.z, 0.0)
		_t.check("%s stands on the site's ground" % id, s.global_position.distance_to(want) < 0.01, "at %s, want %s" % [s.global_position, want])
		var color: Color = EventKinds.activity_color(id)
		_t.check("%s is lit" % id, s.view.lit(), "column %s, glyph %s, ring %s" % [s.view.column.visible, s.view.glyph.visible, s.view.ring.visible])
		_t.check("%s's column is the row's amber" % id, _rgb(s.view.column.material_override.albedo_color) == _rgb(color),
			"column %s, row %s" % [s.view.column.material_override.albedo_color, color])
		var veil: StandardMaterial3D = s.view.column.material_override
		_t.check("%s's column thins to nothing at the lens" % id, veil.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
			and veil.distance_fade_min_distance > 0.0 and veil.distance_fade_max_distance > veil.distance_fade_min_distance,
			"fade mode %d, %.1f to %.1f m" % [veil.distance_fade_mode, veil.distance_fade_min_distance, veil.distance_fade_max_distance])
		_t.check("%s's glyph is the row's amber" % id, _rgb(_first_mesh(s.view.glyph).material_override.albedo_color) == _rgb(color), "glyph colour")
		_t.check("%s's ring is the row's amber" % id, _rgb(_first_mesh(s.view.ring).material_override.albedo_color) == _rgb(color), "ring colour")
		_t.check("%s's word waits until the ball is near" % id, not s.view.word.visible, "word visible at the spawn")
	var cap = _site("ambush_altar").cap
	_t.check("the altar cap is brass", cap != null and _rgb(cap.material_override.albedo_color) == _rgb(Palette.BRASS),
		"cap %s" % [cap.material_override.albedo_color if cap != null else null])
	_check_site_models()
	# Views of one row share their meshes and materials (the stage entry frame built them per view); a
	# stage modifier's sight scale stretches only its own column.
	var view_a := ActivityView.new()
	var view_b := ActivityView.new()
	view_a.build("cracked_cache", 6.0)
	view_b.build("cracked_cache", 6.0)
	_t.check("two views of one row share the column's mesh and material", view_a.column.mesh == view_b.column.mesh
		and view_a.column.material_override == view_b.column.material_override)
	_t.check("and the ring's dash mesh", _first_mesh(view_a.ring).mesh == _first_mesh(view_b.ring).mesh)
	view_a.set_sight(1.5)
	_t.check("a sight scale stretches only its own column", view_a.column.mesh != view_b.column.mesh
		and is_equal_approx((view_b.column.mesh as BoxMesh).size.y, ActivityView.COLUMN_HEIGHT)
		and is_equal_approx((view_a.column.mesh as BoxMesh).size.y, ActivityView.COLUMN_HEIGHT * 1.5))
	view_a.free()
	view_b.free()
	var altar := AmbushAltar.new()
	altar._build_greybox()
	_t.check("altar fallback has no hazard surface or ground ring", _no_hazard_surface(altar) and altar._ring == null)
	_t.check("altar fallback bone band uses its dressed material", _has_bone_band(altar))
	altar.free()
	altar = AmbushAltar.new()
	altar.build()
	_t.check("altar model has no hazard surface or floor ring", _no_hazard_surface(altar) and altar._ring == null
		and altar.find_child("AltarRing", true, false) == null)
	_t.check("altar model bone band uses its dressed material", _has_bone_band(altar))
	altar.free()
	var bet := BetCrate.new()
	bet._build_greybox()
	_t.check("bet crate fallback has no hazard surface", _no_hazard_surface(bet))
	bet.free()
	bet = BetCrate.new()
	bet.build()
	_t.check("bet crate model has no hazard surface", _no_hazard_surface(bet))
	bet.free()


# W1-22: the park's altar and cracked pocket draw their models, not primitives, over the colliders
# they always had, and the pocket's shell fits its colliders (its inner back face on the back wall's).
func _check_site_models() -> void:
	var altar: Node3D = _site("ambush_altar")
	_t.check("the altar wears its model", altar.find_child("AltarPost", false, false) != null
		and altar.find_child("AltarBand", false, false) != null and altar.cap.name == "AltarCap" and _primitives(altar, altar.view) == 0,
		"primitives %d" % _primitives(altar, altar.view))
	var cache: Node3D = _site("cracked_cache")
	var shell: MeshInstance3D = cache.find_child("CacheShell", false, false)
	_t.check("the cache wears its model", shell != null and cache.wall.find_child("CacheWall", false, false) != null
		and cache.find_child("CachePedestal", false, false) != null and cache.find_child("CacheRoof", true, false) == null
		and _primitives(cache, cache.view) == 0, "primitives %d" % _primitives(cache, cache.view))
	var boxes := []
	for shape: CollisionShape3D in cache.find_children("*", "CollisionShape3D", true, false):
		boxes.append([(shape.shape as BoxShape3D).size, (cache.global_transform.affine_inverse() * shape.global_transform).origin])
	var tall := Activities.WALL_HEIGHT + Activities.WALL_SINK
	var mid := tall * 0.5 - Activities.WALL_SINK
	var expected := [
		[Vector3(12, tall, 1), Vector3(0, mid, 0)],
		[Vector3(1, tall, Activities.WALL_DEPTH), Vector3(-6.5, mid, -Activities.WALL_DEPTH * 0.5)],
		[Vector3(1, tall, Activities.WALL_DEPTH), Vector3(6.5, mid, -Activities.WALL_DEPTH * 0.5)],
		[Vector3(14, tall, 1), Vector3(0, mid, -Activities.WALL_DEPTH - 0.5)],
	]
	var same := boxes.size() == expected.size()
	for i in mini(boxes.size(), expected.size()):
		same = same and boxes[i][0].is_equal_approx(expected[i][0]) and boxes[i][1].is_equal_approx(expected[i][1])
	_t.check("the cache keeps its four wall colliders as built", same, "%s" % [boxes])
	if shell != null:
		var box: AABB = shell.transform * shell.mesh.get_aabb()
		_t.check("the cache's shell fits its colliders", absf(box.position.y + Activities.WALL_SINK) < 0.05
			and absf(box.end.y - Activities.WALL_HEIGHT) < 0.05 and absf(box.position.x + 7.0) < 0.15
			and box.position.z > -Activities.WALL_DEPTH - 1.0 and box.position.z < -Activities.WALL_DEPTH - 0.5 and box.end.z > 0.0 and box.end.z < 0.6,
			"shell %s" % [box])


# Primitive meshes the site draws, less its beacon view.
func _primitives(node: Node, skip: Node) -> int:
	var n := 0
	for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if view.mesh is PrimitiveMesh and not skip.is_ancestor_of(view):
			n += 1
	return n


func _no_hazard_surface(node: Node) -> bool:
	for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if view.material_override is BaseMaterial3D:
			if view.material_override.get_meta("greybox_checker", false):
				return false
			if _rgb(view.material_override.albedo_color) == _rgb(Palette.HAZARD):
				return false
	return true


func _has_bone_band(node: Node) -> bool:
	for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if view.name == "AltarBand" or view.mesh is BoxMesh and (view.mesh as BoxMesh).size == Vector3(1.42, 0.12, 1.42):
			return view.material_override is StandardMaterial3D \
				and view.material_override.resource_name == "altar_bone_band" \
				and _rgb(view.material_override.albedo_color) == _rgb(Palette.SAND)
	return false


func _rgb(c: Color) -> Array:
	return [snappedf(c.r, 0.001), snappedf(c.g, 0.001), snappedf(c.b, 0.001)]


func _first_mesh(node: Node) -> MeshInstance3D:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		return child
	return null


# ---- The bounty ----

func _bounty() -> void:
	var s = _site("hauler_bounty")
	var brute = s.brute
	_t.check("a plated brute stands at the bounty's site from the first frames", brute != null and is_instance_valid(brute) and String(brute.kind) == "plated_brute"
		and _planar(brute.global_position, s.global_position) < 3.0, "brute %s" % [brute])
	_t.eq("the director is given the enemy group's size less the bounty's brute",
		_game.world.director_alive(), _game.get_tree().get_nodes_in_group("enemy").size() - 1)
	_t.check("its crate wears the row's amber, apart from its plates", brute.get_node("BountyCrate").material_override.albedo_color == EventKinds.activity_color("hauler_bounty")
		and brute.find_child("BrutePlates", true, false) != null, "crate colour")
	# Walked off and woken, with the ball 60 m away, it goes home inside 300 frames.
	var near: Vector3 = _ground(s.global_position + Vector3(20.0, 0.0, 0.0))
	var acts = _game.world.activities
	_t.eq("a hauler the ball has not met is not at hand, however near", [brute.bounty_met, acts.at_hand(near) == null], [false, true])
	_put(near)
	await _hold(6)
	_t.eq("woken, it is met and its site is at hand", [brute.bounty_met, acts.at_hand(near) == s], [true, true])
	var away: Vector3 = _ground(s.global_position + Vector3(0.0, 0.0, 60.0))
	var out: Vector3 = _ground(s.global_position + Vector3(35.0, 0.0, 0.0), 2.4)
	brute.global_position = out
	_put(away)
	await _hold(LEASH_FRAMES)
	_t.check("with the ball 60 m off for 300 frames the brute is back within 10 m of its site", _planar(brute.global_position, s.global_position) <= 10.0,
		"brute %.1f m from its site, started 35 m out" % _planar(brute.global_position, s.global_position))
	# It falls asleep again at home; met, its site stays at hand (a ball shooting it from beyond
	# its leash wakes it with every bolt, and the plate flickered with it).
	brute.bounty_woken = false
	_t.eq("asleep again at home, its site is still at hand", [brute.bounty_met, acts.at_hand(away) == s], [true, true])
	_t.eq("no activity has finished yet", _done.size(), 0)
	_put(_ground(s.global_position + Vector3(0.0, 0.0, 50.0)))
	await _hold(2)
	var fell: Vector3 = brute.global_position
	_kill(brute)
	await _frames(3)
	_t.eq("the bounty finishes once", _done.count("hauler_bounty"), 1)
	_t.check("one pickup lies where it fell", s.pickup != null and is_instance_valid(s.pickup) and _planar(s.pickup.global_position, fell) < 1.0,
		"pickup %s, brute fell at %s" % [s.pickup, fell])
	_t.eq("the bounty's column is gone", s.view.lit(), false)
	var parts: int = _game.run.parts.size()
	await _hold(3)
	_t.eq("nothing is added until the ball touches the pickup", _game.run.parts.size(), parts)
	var at: Vector3 = s.pickup.global_position
	var line_start := _ground(at + Vector3(0.0, 0.0, 6.0))
	var heading := Vector3(0.0, 0.0, -1.0) * PICKUP_SPEED
	# 2026-10-04 (gate read N1): a gem's part may complete an evolution pair, which grants a
	# second part through add_part, so the gem's own part is counted by id (as growth_pays_test).
	var own_before: int = _game.run.parts.count(s.pickup_part)
	var through: Dictionary = await _line(line_start, heading, PICKUP_FRAMES)
	_t.eq("touching the pickup adds exactly one part", _game.run.parts.count(s.pickup_part), own_before + 1)
	var own_after: int = _game.run.parts.size()
	var control: Dictionary = await _line(line_start, heading, PICKUP_FRAMES)
	_t.eq("a second pass adds nothing", _game.run.parts.size(), own_after)
	_t.check("the pickup does not take the ball's speed", through["after"] >= through["before"] - (control["before"] - control["after"]) - SPEED_SLACK,
		"through %.2f to %.2f, control %.2f to %.2f" % [through["before"], through["after"], control["before"], control["after"]])
	_t.eq("the bounty still finished once", _done.count("hauler_bounty"), 1)


# ---- The ambush ----

func _ambush() -> void:
	var s = _site("ambush_altar")
	var ring := float(_game.world.activities.RULES["ambush_altar"]["ring"])
	await _away_from_the_line(s, ring)
	var outside: Vector3 = _ground(s.global_position + Vector3(ring + 6.0, 0.0, 0.0))
	_put(outside)
	await _hold(8)
	_t.eq("outside the ring nothing arrives", s.pack.size(), 0)
	_t.eq("and the altar stands unfinished", s.done, false)
	var angle := deg_to_rad(60.0)
	var dir := Vector3(cos(angle), 0.0, sin(angle))
	var line_start := _ground(s.global_position + dir * (ring + 2.0))
	var through: Dictionary = {}
	_put(line_start, -dir * 10.0)
	await physics_frame
	var before: float = _game.player.planar_velocity().length()
	var started_at := -1
	var inside_at := -1
	for i in LINE_FRAMES:
		await physics_frame
		var ball: Vector3 = _game.player.ball_position()
		if inside_at < 0 and _planar(ball, s.global_position) <= ring:
			inside_at = i
		if started_at < 0 and s.started:
			started_at = i
	through = {"before": before, "after": _game.player.planar_velocity().length()}
	_t.check("rolling into the ring starts it", s.started and started_at >= 0, "started at frame %d" % started_at)
	_t.check("the pack starts within 10 frames of the ball entering the ring", inside_at >= 0 and started_at >= 0 and started_at - inside_at <= 10,
		"ball inside at frame %d, pack at frame %d" % [inside_at, started_at])
	var kinds: Array = s.pack.map(func(e): return String(e.kind))
	_t.check("exactly the three named kinds arrive", s.pack.size() == 3 and kinds == ["chaser", "chaser", "lobber"], "kinds %s" % [kinds])
	_t.eq("only the bounty has finished so far", _done.size(), 1)
	_put(_ground(s.global_position + Vector3(5.0, 0.0, 0.0)))
	await _hold(2)
	_kill(s.pack[0])
	_kill(s.pack[1])
	await _hold(4)
	_t.check("two of three dead pays nothing", s.pickup == null and not s.done and _done.count("ambush_altar") == 0,
		"pickup %s, done %s, announced %d times" % [s.pickup, s.done, _done.count("ambush_altar")])
	_kill(s.pack[2])
	await _hold(4)
	_t.eq("the ambush finishes once", _done.count("ambush_altar"), 1)
	_t.check("the altar's cap goes dark with its column", not s.cap.visible and not s.view.lit(), "cap visible %s, lit %s" % [s.cap.visible, s.view.lit()])
	_t.check("one pickup lies within 2 m of the altar", s.pickup != null and _planar(s.pickup.global_position, s.global_position) <= 2.0,
		"pickup %s" % [s.pickup])
	var parts: int = _game.run.parts.size()
	await _hold(4)
	_t.eq("nothing is added until the ball touches it", _game.run.parts.size(), parts)
	var at: Vector3 = s.pickup.global_position
	var start := _ground(at + dir * 6.0)
	var own_before: int = _game.run.parts.count(s.pickup_part)
	var pass_a: Dictionary = await _line(start, -dir * PICKUP_SPEED, PICKUP_FRAMES)
	_t.eq("touching it adds exactly one part", _game.run.parts.count(s.pickup_part), own_before + 1)
	var control: Dictionary = await _line(line_start, -dir * 10.0, LINE_FRAMES)
	_t.eq("the ambush finished once", _done.count("ambush_altar"), 1)
	_t.check("the ring start does not take the ball's speed", through["after"] >= through["before"] - (control["before"] - control["after"]) - SPEED_SLACK,
		"through %.2f to %.2f, control %.2f to %.2f" % [through["before"], through["after"], control["before"], control["after"]])
	_t.check("the ring no longer stands", s.view.lit() == false and pass_a["before"] > 0.0, "lit %s" % s.view.lit())


# The ball enters the ring at 0, 60 and 120 degrees; none of the three arrivals stands within 3 m of
# the ball's straight line through the ring. Each trial is wiped afterwards so the real run is unchanged.
func _away_from_the_line(s, ring: float) -> void:
	for deg in [0.0, 60.0, 120.0]:
		var a := deg_to_rad(deg)
		var dir := Vector3(cos(a), 0.0, sin(a))
		_put(_ground(s.global_position + dir * (ring - 0.3)))
		await _hold(2)
		var ball: Vector3 = _game.player.ball_position()
		var axis := Vector2(s.global_position.x - ball.x, s.global_position.z - ball.z).normalized()
		var worst := 99.0
		for e in s.pack:
			var rel := Vector2(e.global_position.x - ball.x, e.global_position.z - ball.z)
			worst = minf(worst, absf(rel.x * axis.y - rel.y * axis.x))
		_t.check("entering at %d degrees, no arrival stands within 3 m of the ball's line through the ring" % int(deg), s.pack.size() == 3 and worst > 3.0,
			"%d arrived, nearest %.1f m from the line" % [s.pack.size(), worst])
		_put(_ground(s.global_position + Vector3(ring + 20.0, 0.0, 0.0)))
		await _hold(2)
		for e in s.pack:
			if is_instance_valid(e):
				e.free()
		s.pack.clear()
		s.started = false


# ---- The cache ----

func _cache() -> void:
	var s = _site("cracked_cache")
	var spec: Dictionary = _game.ctx.terrain.map().activity_sites.filter(func(row): return row["id"] == "cracked_cache")[0]
	var authored: Vector3 = _game.ctx.terrain.drop_point(spec["at"].x, spec["at"].y, 0.0)
	_t.check("cache is shifted 6 m into the lane", s.global_position.distance_to(authored) >= Activities.CACHE_LANE_OFFSET - 0.01,
		"offset %.2f m" % s.global_position.distance_to(authored))
	var wall_gap := _nearest_external_wall(s)
	_t.check("Reach cache is 6 m from external wall colliders", wall_gap < 0.0 or wall_gap >= Activities.CACHE_LANE_OFFSET - 0.01,
		"nearest external wall %s" % ("none within 30 m" if wall_gap < 0.0 else "%.2f m away" % wall_gap))
	var cruise: float = _game.ctx.tuning.f("cruise")
	var back: Vector3 = s.global_basis.z
	var heading: Vector3 = -back
	var start := _ground(s.global_position + back * 14.0)
	var refused_before := _refused
	var slow: Dictionary = await _ram(s, start, heading * cruise * RAM_BELOW, RAM_FRAMES)
	_t.check("a ram under the bar leaves the wall standing", not s.done and s.wall.visible and _done.count("cracked_cache") == 0,
		"ram at %.1f m/s of cruise %.1f: done %s, wall visible %s" % [cruise * RAM_BELOW, cruise, s.done, s.wall.visible])
	# The second bump starts 6 m out, so it reaches the face well inside its 60 frames, and both rams
	# together are shorter than the cue's gap.
	await _ram(s, _ground(s.global_position + back * 6.0), heading * cruise * RAM_BELOW, 60)
	var gap_frames := int(float(Activities.RULES["cracked_cache"]["refused"]["gap_s"]) * Engine.physics_ticks_per_second)
	_t.check("two bumps under the bar inside the cue's gap play the roll's refused cue once", _refused - refused_before == 1 and RAM_FRAMES + 60 < gap_frames,
		"%d cues over %d frames, gap %d frames" % [_refused - refused_before, RAM_FRAMES + 60, gap_frames])
	# The same bump with the face's gap spent: a second cue, so the gap and not a short bump held the last.
	s.refused_frame = -1
	await _ram(s, _ground(s.global_position + back * 6.0), heading * cruise * RAM_BELOW, 60)
	_t.check("the same bump once the gap is spent plays the cue again", _refused - refused_before == 2, "%d cues" % (_refused - refused_before))
	s.refused_frame = -1
	var fast: Dictionary = await _ram(s, start, heading * cruise * RAM_HELD, RAM_FRAMES)
	_t.check("a ram at a held roll's speed breaks the wall", s.done and not s.wall.visible, "ram at %.1f m/s: done %s" % [cruise * RAM_HELD, s.done])
	_t.check("the breaking ram, with the gap spent, plays no refused cue", _refused - refused_before == 2, "%d cues" % (_refused - refused_before))
	_t.check("fired cache has its warm fill", s.fired_glow != null and s.fired_glow.emission_enabled and s.fired_glow.emission_energy_multiplier > 0.0,
		"glow energy %.2f" % (s.fired_glow.emission_energy_multiplier if s.fired_glow != null else 0.0))
	# A per-site light freed on a stage change segfaulted Godot 4.7.2 Forward+ at the next boss entry.
	_t.check("fired cache adds no dynamic light", s.find_children("*", "Light3D", true, false).is_empty())
	_t.eq("the cache finishes once", _done.count("cracked_cache"), 1)
	_t.check("one pickup stands on the pedestal", s.pickup != null and _planar(s.pickup.global_position, s.pedestal) < 0.5,
		"pickup %s, pedestal %s" % [s.pickup, s.pedestal])
	var control: Dictionary = await _ram(s, start, heading * cruise * RAM_HELD, RAM_FRAMES)
	_t.check("the wall does not take the ball's speed", fast["after"] >= fast["before"] - (control["before"] - control["after"]) - SPEED_SLACK,
		"ram %.2f to %.2f, same line with the wall gone %.2f to %.2f; slow ram stopped at %.2f" % [fast["before"], fast["after"], control["before"], control["after"], slow["after"]])
	_put(_ground(s.pedestal + back * 3.0))
	await _hold(3)
	var own_before: int = _game.run.parts.count(s.pickup_part)
	var onto: Dictionary = await _line(_ground(s.pedestal + back * 4.0), heading * 8.0, 40)
	_t.eq("touching the pedestal's pickup adds exactly one part", _game.run.parts.count(s.pickup_part), own_before + 1)
	var own_after: int = _game.run.parts.size()
	var onto_control: Dictionary = await _line(_ground(s.pedestal + back * 4.0), heading * 8.0, 40)
	_t.eq("a second pass adds nothing", _game.run.parts.size(), own_after)
	_t.check("the pickup cost no speed beyond the line", onto["after"] >= onto["before"] - (onto_control["before"] - onto_control["after"]) - SPEED_SLACK,
		"through %.2f to %.2f, control %.2f to %.2f" % [onto["before"], onto["after"], onto_control["before"], onto_control["after"]])
	_t.eq("the cache finished once", _done.count("cracked_cache"), 1)


func _nearest_external_wall(cache: Node3D) -> float:
	var nearest := INF
	var stage_root: Node3D = _game.ctx.terrain.geometry_root(1)
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


# The ball rolled at the wall until the first frame it has crossed the wall's plane or `frames` pass;
# its speed on the first frame and at the frame it is one body length past the face.
func _ram(s, start: Vector3, velocity: Vector3, frames: int) -> Dictionary:
	_put(start, velocity)
	await physics_frame
	var before: float = _game.player.planar_velocity().length()
	var after := before
	for i in frames:
		if s.to_local(_game.player.ball_position()).z > 6.0:
			_game.player.set_velocity_now(velocity)
		await physics_frame
		var local: Vector3 = s.to_local(_game.player.ball_position())
		after = _game.player.planar_velocity().length()
		if local.z < -1.0:
			break
	return {"before": before, "after": after}


# ---- All three done, a quiet minute ----

func _all_done_quiet() -> void:
	var finished: Array = ["ambush_altar", "cracked_cache", "hauler_bounty"].filter(func(id): return _done.has(id))
	_t.eq("all three are finished", finished.size(), 3)
	_game.ctx.calm = false
	var starts := 0
	var counter := func(_id: String): starts += 1
	_game.events.event_started.connect(counter)
	var normal := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = SIM_RATE
	_event_facts = 0
	_put(_ground(_site("hauler_bounty").global_position + Vector3(0.0, 0.0, 90.0)))
	for tick in SIM_RATE * SIM_SECONDS:
		if tick % 30 == 0:
			_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
	Engine.physics_ticks_per_second = normal
	_t.eq("event_started fires 0 times in 60 simulated seconds", starts, 0)
	_t.eq("no event row is published in those 60 seconds", _event_facts, 0)


# ---- A retry and the default table ----

func _retry() -> void:
	_game.flow.retry_stage()
	await _frames(3)
	await _slams()
	_game.flow.retry_stage()
	await _frames(3)
	var sites: Array = _game.world.activities.sites
	_t.eq("a retry builds four activities", sites.size(), 4)
	_t.check("each is unfinished and lit", sites.all(func(s): return not s.done and s.view.lit()), "done flags %s" % [sites.map(func(s): return s.done)])
	var s = _site("hauler_bounty")
	_t.check("the bounty's brute stands again", s != null and s.brute != null and is_instance_valid(s.brute) and not s.brute.is_dead(), "brute %s" % [s.brute if s != null else null])
	_t.eq("one device stands, the relic cache (GP1)", _game.world.interact.devices.size(), 1)
	_t.check("the cache's wall stands again", _site("cracked_cache").wall.visible and not _site("cracked_cache").done, "wall")


# A slam in front of the face, sent through the ball's own landing so the bus carries the strength the
# game would: a landing slower than cruise leaves the wall, one at cruise or faster breaks it.
func _slams() -> void:
	var s = _site("cracked_cache")
	var cruise: float = _game.ctx.tuning.f("cruise")
	var at: Vector3 = s.global_position + s.global_basis.z * 3.0
	_put(_ground(s.global_position + s.global_basis.z * 40.0))
	await _hold(3)
	_game.player._on_slammed(at, cruise * RAM_BELOW, 1.0)
	await _frames(2)
	_t.check("a landing slower than cruise leaves the wall standing", not s.done and s.wall.visible, "landing %.1f m/s of cruise %.1f: done %s" % [cruise * RAM_BELOW, cruise, s.done])
	_game.player._on_slammed(at, cruise * RAM_AT, 1.0)
	await _frames(2)
	_t.check("a landing faster than cruise breaks it", s.done and not s.wall.visible, "landing %.1f m/s: done %s" % [cruise * RAM_AT, s.done])
	_t.check("and one part waits on the pedestal", s.pickup != null and _planar(s.pickup.global_position, s.pedestal) < 0.5, "pickup %s" % [s.pickup])


# A stage change and a death each leave no activity enemy standing and none of the old stage's sites.
func _lifetime() -> void:
	var old: Array = _game.world.activities.sites.duplicate()
	var brutes: Array = old.filter(func(x): return x.brute != null).map(func(x): return x.brute)
	_t.check("a brute stands before the stage changes", brutes.size() == 1 and is_instance_valid(brutes[0]), "brutes %s" % [brutes])
	_game.events.stage_content_cleared.emit("arena")
	await _frames(3)
	_t.eq("a stage change leaves no site standing", _game.world.activities.sites.size(), 0)
	_t.check("and no activity enemy alive", brutes.all(func(b): return not is_instance_valid(b) or b.is_dead()) and _game.world.activities.standing() == 0,
		"brute valid %s" % [brutes.map(func(b): return is_instance_valid(b) and not b.is_dead())])
	_game.flow.retry_stage()
	await _frames(3)
	old = _game.world.activities.sites.duplicate()
	brutes = old.filter(func(x): return x.brute != null).map(func(x): return x.brute)
	_game.events.player_died.emit()
	await _frames(3)
	_game.flow.retry_stage()
	await _frames(3)
	var now: Array = _game.world.activities.sites
	_t.check("after a death and a retry no site of the old stage stands", now.size() == 4 and now.all(func(x): return not old.has(x)), "sites %d, reused %s" % [now.size(), now.filter(func(x): return old.has(x)).size()])
	_t.check("and the old stage's enemy is gone", brutes.all(func(b): return not is_instance_valid(b) or b.is_dead()), "old brute alive")
	_t.eq("one activity enemy stands, the new bounty's", _game.world.activities.standing(), 1)


# Calm mode builds only what it can pay: the cache, not the ambush or the bounty.
func _calm() -> void:
	_game.ctx.calm = true
	_game.flow.retry_stage()
	await _frames(3)
	var ids: Array = _game.world.activities.sites.map(func(x): return x.id)
	_game.ctx.calm = false
	_t.check("calm mode builds the cache alone", ids == ["cracked_cache"], "sites %s" % [ids])


func _default_table() -> void:
	await _boot("")
	await _frames(3)
	var maps: Array = _game.ctx.terrain.maps
	var counts := []
	for i in maps.size():
		var row: Dictionary = _game.ctx.stages.DEFS[i]
		if SIDE_CONTENT_PENDING.has(String(row["map"])):
			# 2026-10-04 (wave 9): greybox zone, activity sites land in wave 10.
			print("[skip stage %d: %s] greybox map %s; activity sites pending wave 10" % [i + 1, row["name"], row["map"]])
			continue
		if not String(row["name"]).contains("placeholder"):
			counts.append(maps[i].activity_sites.size() if "activity_sites" in maps[i] else 0)
	_t.check("the default alpha's authored (non-placeholder) maps carry their activity sites", counts == [1, 4, 3, 4, 3, 3], "sites per authored stage %s" % [counts])
	var pending_named := true
	for row in _game.ctx.stages.DEFS:
		if SIDE_CONTENT_PENDING.has(String(row["map"])) and String(row["name"]).contains("placeholder"):
			pending_named = false
	# 2026-10-04 (wave 9): the pending list is about greybox content, not placeholders.
	_t.check("every pending map's row is greybox content, not a placeholder", pending_named, "pending %s" % [SIDE_CONTENT_PENDING])
	_t.eq("Spillway stands its one enemy camp site", _game.world.activities.sites.size(), 1)
	_t.eq("its four Spillway devices stand (three plus the rescue cage, META-3 2026-10-04)", _game.world.interact.devices.size(), 4)
	_game.free()
	await _frames(2)
