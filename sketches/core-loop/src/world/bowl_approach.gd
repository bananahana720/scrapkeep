extends Node3D

const ModelKit := preload("res://src/world/model_kit.gd")
const Palette := preload("res://src/core/palette.gd")
const SurveyPosts := preload("res://src/world/survey_posts.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")

# The approach to the boss's bowl (BACKLOG W1-104, pieces 1 to 3 of its concept page), behind `--approach=on` (off
# by default). A map that names an approach row gets, on the last LAST_M of its floor line and outside every fight's ground: tag racks (a rack beside
# the line and three tagged crates across it; a crate the ball touches at speed bursts and throws scrap ahead, all
# three throw more), a weighbridge across the line (rolling over its plate at speed flips the board to the ball's
# heft and throws scrap, once an attempt at the stage), and the furnace's stacks, glow and smoke standing where the row's `smoke`
# says, which is where the stage's launch aims. Nothing has a collider, nothing stops the ball, no marker points at
# any of it and missing it costs nothing.
#
# Where the pieces stand is a pure function of the floor line, its ramps, what it keeps clear of and the ground
# (plan()), so every run of a map has the same approach.

const GANTRY := "res://assets/models/world_one/poi_weighbridge_gantry.glb"
const RACK := "res://assets/models/world_one/poi_tag_rack.glb"
const CRATE := "res://assets/models/world_one/poi_tagged_crate.glb"
const STACKS := "res://assets/models/world_one/poi_furnace_stacks.glb"

# The stretch of the line's end the approach may stand on. A floor line ends at the Warden's engage ring, and the
# ground the Warden's fight can shut (the yard lock's ring, a fight site) reaches back about 250 m of the flume's
# line from there, so the approach is what leads up to that ground.
const LAST_M := 560.0
const STEP_M := 5.0
# A piece keeps this far from every grapple anchor post of the map's own fields.
const ANCHOR_CLEAR_M := 4.0
# Tag racks: how many, how far apart their centres are along the line, and a cluster's lay-out.
const RACKS := 3
const RACK_EVERY_M := 50.0
const CRATES := 3
const CRATE_STEP_M := 8.0
const CRATE_SIDE_M := 3.0
const RACK_SIDE_M := 7.0
const CRATE_M := 1.2
const CRATE_SCRAP := 1
const CLUSTER_SCRAP := 4
const THROW_M := 24.0
const BURST_S := 0.2
# The weighbridge: the plate's half width and half depth, the gantry's size, and its pay.
const PLATE_HALF_M := 4.0
const PLATE_DEEP_M := 2.0
const GANTRY_WIDE_M := 12.0
const GANTRY_TALL_M := 7.0
const WEIGH_SCRAP := 3
const WEIGH_PER_HEFT := 2
const WEIGH_SCRAP_MAX := 12
# The furnace: three stacks this tall, and how fast the smoke climbs.
const STACK_M := 60.0
const SMOKE_PUFFS := 6
const SMOKE_RISE_M := 90.0
const SMOKE_S := 24.0
const FAR_SHARE := 0.8
# The farthest the furnace reaches from its foot: the top of its smoke, and across its stacks.
const FURNACE_REACH_M := 200.0

var ctx
# What stands this stage: racks [{"crates": [Node3D], "down": [bool], "hit": int, "paid": bool}], bridge {} or
# {"node", "at": Vector3, "heading": Vector2, "side": float, "weighed": bool, "board": Label3D}, furnace or null
# (furnace_home() is where it stands; the node itself is drawn nearer for a far eye, stand_in()).
var racks: Array = []
var bridge := {}
var furnace: Node3D
var crates_burst := 0
var clusters_paid := 0
var weighed := 0.0

var _rng := RandomNumberGenerator.new()
var _puffs: Array = []
var _smoke_clock := 0.0
var _furnace_home := Vector3.ZERO


func setup(context) -> void:
	ctx = context
	name = "BowlApproach"
	ctx.events.stage_entered.connect(func(stage: int, _retry: bool): _build(stage))
	ctx.events.stage_content_cleared.connect(func(_reason: String): _clear())
	set_physics_process(false)
	set_process(false)


# Where the approach stands on a line: {"racks": [{"crates": [Vector3], "rack": Vector3, "heading": Vector2}],
# "bridge": {} or {"at": Vector3, "heading": Vector2}}, the bridge the last stretch of the line that suits one and
# the racks behind it, RACK_EVERY_M apart, each slid back to the first stretch that suits. `points` is the line in
# plan, `gaps` the stretches a built ramp covers, `clear_of` SurveyPosts.keep_clear()'s rows, `ground` a Callable
# (x, z) -> height.
static func plan(points: PackedVector2Array, gaps: Array, clear_of: Array, ground: Callable) -> Dictionary:
	var out := {"racks": [], "bridge": {}}
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	var floor_m := maxf(STEP_M, total - LAST_M)
	var d := total - STEP_M
	while d >= floor_m and out["bridge"].is_empty():
		if _suits(points, d - PLATE_DEEP_M, d + PLATE_DEEP_M, PLATE_HALF_M, gaps, clear_of, ground):
			var here := SurveyPosts.along(points, d)
			out["bridge"] = {"at": _on_ground(here["at"], ground), "heading": here["heading"], "along": d}
		d -= STEP_M
	var run := CRATE_STEP_M * (CRATES - 1)
	var next: float = (float(out["bridge"]["along"]) if not out["bridge"].is_empty() else total) - RACK_EVERY_M * 0.5
	while out["racks"].size() < RACKS and next - run >= floor_m:
		var from := next - run
		if _suits(points, from, next, RACK_SIDE_M, gaps, clear_of, ground):
			var first := SurveyPosts.along(points, from)
			var crates := []
			for i in CRATES:
				var here := SurveyPosts.along(points, from + CRATE_STEP_M * i)
				var side: Vector2 = here["heading"].orthogonal() * CRATE_SIDE_M * float(i - (CRATES >> 1))
				crates.append(_on_ground(here["at"] + side, ground))
			var mid := SurveyPosts.along(points, from + run * 0.5)
			var beside: Vector2 = mid["at"] + mid["heading"].orthogonal() * RACK_SIDE_M * (1.0 if out["racks"].size() % 2 == 0 else -1.0)
			out["racks"].append({"crates": crates, "rack": _on_ground(beside, ground), "heading": first["heading"], "along": from})
			next = from - RACK_EVERY_M + run
		else:
			next -= STEP_M
	return out


# What an approach keeps clear for whoever else stands things on the line (survey posts): SurveyPosts.keep_clear()'s
# kind of row for each piece of a plan().
static func taken(planned: Dictionary) -> Array:
	var out := []
	if not planned["bridge"].is_empty():
		var at: Vector3 = planned["bridge"]["at"]
		out.append({"at": Vector2(at.x, at.z), "r": GANTRY_WIDE_M})
	for rack in planned["racks"]:
		var mid: Vector3 = rack["crates"][CRATES >> 1]
		out.append({"at": Vector2(mid.x, mid.z), "r": CRATE_STEP_M * (CRATES >> 1) + RACK_SIDE_M})
	return out


static func _on_ground(at: Vector2, ground: Callable) -> Vector3:
	return Vector3(at.x, ground.call(at.x, at.y), at.y)


# True where the line from `from` to `to` metres runs straight on rolled ground no steeper than SurveyPosts.SLOPE, `half` metres
# to each side included, off every ramp and clear of everything in `clear_of`.
static func _suits(points: PackedVector2Array, from: float, to: float, half: float, gaps: Array, clear_of: Array, ground: Callable) -> bool:
	if from < 0.0 or gaps.any(func(g: Array) -> bool: return from <= g[1] and to >= g[0]):
		return false
	var first := SurveyPosts.along(points, from)
	if absf(first["heading"].angle_to(SurveyPosts.along(points, to)["heading"])) > SurveyPosts.TURN:
		return false
	var height: float = ground.call(first["at"].x, first["at"].y)
	var d := from
	while d <= to:
		var here: Dictionary = SurveyPosts.along(points, d)
		var y: float = ground.call(here["at"].x, here["at"].y)
		if absf(y - height) > SurveyPosts.SLOPE:
			return false
		for side in [-half, half]:
			var off: Vector2 = here["at"] + here["heading"].orthogonal() * side
			if absf(float(ground.call(off.x, off.y)) - y) > half * SurveyPosts.SLOPE:
				return false
			if clear_of.any(func(c: Dictionary) -> bool: return SurveyPosts.near(c, off)):
				return false
		if clear_of.any(func(c: Dictionary) -> bool: return SurveyPosts.near(c, here["at"])):
			return false
		height = y
		d += 1.0
	return true


# The plan for a stage's map, {} where the map names no approach or has no floor line. The same for every caller,
# so survey posts can keep off it. The pieces keep off what survey posts keep off, and off every grapple anchor post
# the map's own fields plant.
static func plan_for(map, ground: Callable) -> Dictionary:
	if not "approach" in map or map.approach.is_empty() or map.scrap_trail.is_empty():
		return {}
	var trail: Dictionary = map.scrap_trail
	var clear_of: Array = SurveyPosts.keep_clear(map)
	var fields: Dictionary = ParkRecipes.field_posts(map.park["park_rows"], ParkRecipes.clear_zones(map.park))
	for i in fields:
		for post in fields[i]:
			clear_of.append({"at": post, "r": ANCHOR_CLEAR_M})
	return plan(trail["points"], trail.get("gaps", []), clear_of, ground)


# Where the furnace is drawn for an eye whose far plane is `far`: its own place while all of it (`radius` metres
# about `home`) stands inside FAR_SHARE of the far plane, else scaled about the eye so every part stays on the ray it
# had and inside the far plane (landmark_impostor.gd's method; the chase camera's far plane is 700 m and the furnace
# stands farther than that from most of the line).
static func stand_in(home: Vector3, radius: float, eye: Vector3, far: float) -> Transform3D:
	var reach := far * FAR_SHARE
	var span := home.distance_to(eye) + radius
	var k := 1.0 if span <= reach else reach / span
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), eye + (home - eye) * k)


static func on(context) -> bool:
	var tuning = context.get("tuning")
	return tuning != null and tuning.option("approach") == "on" and not context.calm


func furnace_home() -> Vector3:
	return _furnace_home


func _build(stage: int) -> void:
	_clear()
	if not on(ctx):
		return
	var map = ctx.terrain.map_for(stage)
	var planned := plan_for(map, func(x: float, z: float) -> float: return ctx.terrain.height(x, z))
	if planned.is_empty():
		return
	_rng.seed = hash([ctx.rng.seed, ctx.run.run_seed, stage, "bowl_approach"])
	for row in planned["racks"]:
		var yaw: float = atan2(row["heading"].x, row["heading"].y)
		var rack := _rack()
		add_child(rack)
		rack.global_position = row["rack"]
		rack.rotation.y = yaw
		var nodes := [rack]
		var crates := []
		for at in row["crates"]:
			var crate := _crate()
			add_child(crate)
			crate.global_position = at
			crate.rotation.y = yaw + _rng.randf_range(-0.4, 0.4)
			crates.append(crate)
			nodes.append(crate)
		var down := []
		down.resize(CRATES)
		down.fill(false)
		racks.append({"crates": crates, "nodes": nodes, "down": down, "hit": 0, "paid": false})
	if not planned["bridge"].is_empty():
		var heading: Vector2 = planned["bridge"]["heading"]
		var node := _gantry()
		add_child(node)
		node.global_position = planned["bridge"]["at"]
		node.rotation.y = atan2(heading.x, heading.y)
		bridge = {"node": node, "at": planned["bridge"]["at"], "heading": heading, "side": 0.0, "weighed": false,
			"board": node.get_meta("board")}
	var smoke: Vector2 = map.approach["smoke"]
	furnace = _furnace()
	add_child(furnace)
	# Its foot is level with the map's ground nearest it: the furnace may stand off the map.
	var edge := ParkTerrain.HALF - 10.0
	_furnace_home = Vector3(smoke.x, ctx.terrain.height(clampf(smoke.x, -edge, edge), clampf(smoke.y, -edge, edge)), smoke.y)
	furnace.global_position = _furnace_home
	set_physics_process(true)
	set_process(true)


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	racks.clear()
	bridge = {}
	furnace = null
	_puffs.clear()
	set_physics_process(false)
	set_process(false)


func _physics_process(_delta: float) -> void:
	if ctx.player == null:
		return
	var ball: Vector3 = ctx.player.ball_position()
	# Speed along the ground: a ball falling straight down beside a crate bursts nothing.
	var velocity: Vector3 = ctx.player.planar_velocity()
	var fast := velocity.length() >= SurveyPosts.MIN_SPEED
	for row in racks:
		if row["paid"] or not fast:
			continue
		for i in CRATES:
			if row["down"][i]:
				continue
			var to: Vector3 = ball - row["crates"][i].global_position
			if Vector2(to.x, to.z).length() <= SurveyPosts.TOUCH_M and absf(to.y) <= SurveyPosts.TOUCH_UP_M:
				_burst(row, i, ball, velocity)
		if row["hit"] == CRATES:
			row["paid"] = true
			clusters_paid += 1
			_throw(ball, velocity.normalized(), CLUSTER_SCRAP)
	if not bridge.is_empty() and not bridge["weighed"]:
		_weigh(ball, velocity, fast)


# The ball crossing the plate's middle line at speed, either way, is weighed once.
func _weigh(ball: Vector3, velocity: Vector3, fast: bool) -> void:
	var to: Vector3 = ball - bridge["at"]
	var heading: Vector2 = bridge["heading"]
	var along := Vector2(to.x, to.z).dot(heading)
	var across := absf(Vector2(to.x, to.z).dot(heading.orthogonal()))
	var before: float = bridge["side"]
	bridge["side"] = signf(along) if across <= PLATE_HALF_M and absf(to.y) <= SurveyPosts.TOUCH_UP_M and absf(along) <= PLATE_DEEP_M * 4.0 else 0.0
	if not fast or before == 0.0 or bridge["side"] == 0.0 or before == bridge["side"]:
		return
	bridge["weighed"] = true
	weighed = ctx.player.heft()
	var board = bridge["board"]
	if board != null:
		board.text = str(roundi(weighed))
		board.modulate = Palette.AMBER
	_throw(ball, velocity.normalized(), pay(weighed))


# What the weighbridge throws for a ball of this heft: more for a heavier build, capped.
static func pay(heft: float) -> int:
	return mini(WEIGH_SCRAP_MAX, WEIGH_SCRAP + int(maxf(0.0, heft - 1.0) * WEIGH_PER_HEFT))


# Scrap ahead of the ball, a piece every few metres, each seated on the ground it lands on.
func _throw(from: Vector3, heading: Vector3, pieces: int) -> void:
	for i in pieces:
		var spot := from + heading * THROW_M * (i + 0.5) / pieces
		ctx.build.scrap.drop(ctx.terrain.drop_point(spot.x, spot.z, 0.0), 1, _rng)


# The crate flies apart the way the ball was going and is gone.
func _burst(row: Dictionary, index: int, ball: Vector3, velocity: Vector3) -> void:
	row["down"][index] = true
	row["hit"] += 1
	crates_burst += 1
	_throw(ball, velocity.normalized(), CRATE_SCRAP)
	var crate: Node3D = row["crates"][index]
	var tween := crate.create_tween()
	tween.set_parallel(true)
	tween.tween_property(crate, "global_position", crate.global_position + velocity.normalized() * 3.0 + Vector3.UP * 1.5, BURST_S)
	tween.tween_property(crate, "scale", Vector3.ONE * 0.05, BURST_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(crate.hide)


# The smoke climbs and thins, each puff in turn; drawn frames only.
func _process(delta: float) -> void:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera != null and furnace != null:
		furnace.global_transform = stand_in(_furnace_home, FURNACE_REACH_M, camera.global_position, camera.far)
	_smoke_clock = fmod(_smoke_clock + delta / SMOKE_S, 1.0)
	for i in _puffs.size():
		var t := fmod(_smoke_clock + float(i) / _puffs.size(), 1.0)
		var puff: MeshInstance3D = _puffs[i]
		puff.position = Vector3(t * t * 30.0, STACK_M + t * SMOKE_RISE_M, 0.0)
		puff.scale = Vector3.ONE * (10.0 + 26.0 * t)


func _box(size: Vector3, at: Vector3, color: Color, parent: Node3D, glow := 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = Palette.solid(color, glow, glow <= 0.0)
	mesh.position = at
	parent.add_child(mesh)
	return mesh


# A tagged crate about its foot: the model, or a rust box with a brass tag.
func _crate() -> Node3D:
	var crate := Node3D.new()
	if ModelKit.whole(CRATE, crate) != null:
		return crate
	_box(Vector3.ONE * CRATE_M, Vector3.UP * CRATE_M * 0.5, Palette.RUST, crate)
	_box(Vector3(0.35, 0.5, 0.06), Vector3(0.0, CRATE_M * 0.6, CRATE_M * 0.5 + 0.04), Palette.AMBER, crate, 1.2)
	return crate


# A tag rack about its foot, 3 m wide and tall: the model, or two shelves of tagged crates on a frame.
func _rack() -> Node3D:
	var rack := Node3D.new()
	if ModelKit.whole(RACK, rack) != null:
		return rack
	for x in [-1.4, 1.4]:
		_box(Vector3(0.2, 3.0, 2.0), Vector3(x, 1.5, 0.0), Palette.CHARCOAL, rack)
	for y in [0.2, 1.6]:
		_box(Vector3(3.0, 0.15, 2.0), Vector3(0.0, y, 0.0), Palette.CHARCOAL, rack)
		for x in [-0.8, 0.8]:
			_box(Vector3.ONE * CRATE_M, Vector3(x, y + 0.1 + CRATE_M * 0.5, 0.0), Palette.RUST, rack)
			_box(Vector3(0.06, 0.5, 0.35), Vector3(x, y + 0.7, 1.0), Palette.AMBER, rack, 1.2)
	return rack


# The weighbridge about the middle of its plate, the line running through it on +Z: the model (its board drawn by
# the game either way), or two legs, a beam and a plate.
func _gantry() -> Node3D:
	var gantry := Node3D.new()
	if ModelKit.whole(GANTRY, gantry) == null:
		for x in [-GANTRY_WIDE_M * 0.5, GANTRY_WIDE_M * 0.5]:
			_box(Vector3(1.0, GANTRY_TALL_M, 1.6), Vector3(x, GANTRY_TALL_M * 0.5, 0.0), Palette.RUST, gantry)
		_box(Vector3(GANTRY_WIDE_M + 1.0, 1.6, 1.6), Vector3(0.0, GANTRY_TALL_M - 0.8, 0.0), Palette.RUST, gantry)
		_box(Vector3(PLATE_HALF_M * 2.0, 0.12, PLATE_DEEP_M * 2.0), Vector3(0.0, 0.06, 0.0), Palette.AMBER, gantry)
	# The board reads from both ways along the line.
	var board := Label3D.new()
	board.name = "Board"
	board.text = "0"
	board.font_size = 256
	board.pixel_size = 0.012
	board.outline_size = 48
	board.modulate = Palette.CHARCOAL
	board.outline_modulate = Color.BLACK
	board.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	board.position = Vector3(0.0, GANTRY_TALL_M + 1.4, 0.0)
	gantry.add_child(board)
	gantry.set_meta("board", board)
	return gantry


# The furnace about its foot: three stacks (the model, or plain towers), a glow at their feet and smoke off the
# tallest. Big and simple: it is read from hundreds of metres.
func _furnace() -> Node3D:
	var works := Node3D.new()
	if ModelKit.whole(STACKS, works) == null:
		for i in 3:
			var tall: float = STACK_M * [1.0, 0.8, 0.65][i]
			_box(Vector3(9.0, tall, 9.0), Vector3(0.0, tall * 0.5, (i - 1) * 22.0), Palette.CHARCOAL, works)
			_box(Vector3(9.6, 3.0, 9.6), Vector3(0.0, tall - 4.0, (i - 1) * 22.0), Palette.AMBER, works, 1.6)
	_box(Vector3(30.0, 14.0, 70.0), Vector3(0.0, 7.0, 0.0), Palette.AMBER, works, 2.4)
	var cloud := SphereMesh.new()
	cloud.radius = 0.5
	cloud.height = 1.0
	cloud.radial_segments = 8
	cloud.rings = 4
	var soot := StandardMaterial3D.new()
	soot.albedo_color = Color(0.13, 0.11, 0.1, 0.8)
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in SMOKE_PUFFS:
		var puff := MeshInstance3D.new()
		puff.mesh = cloud
		puff.material_override = soot
		works.add_child(puff)
		_puffs.append(puff)
	return works
