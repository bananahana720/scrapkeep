extends Node3D

const Palette := preload("res://src/core/palette.gd")

# Survey posts (BACKLOG W1-103): something small to do on the ride between sites, behind `--posts=on` (off by
# default). A row is five survey posts beside the floor line, one a beat of the scrap trail (the trail's own
# spacing), alternating left and right, so a ball that weaves takes all five. A post the ball touches at speed is
# knocked flat; all five inside SET_S throw a line of scrap ahead of the ball. Nothing stops the ball, nothing has
# a collider (a knock is a touch at speed, as overtime.gd's bell is), no marker points at a row and a missed row
# costs nothing. (Not Sable's stakes, src/combat/stakes.gd, nor the relay's stake: these are posts.)
#
# Where rows stand is a pure function of the stage's floor line, its sites and the run's seed (rows()): a slot every
# EVERY_M of line, kept on two runs in three, slid along the line to the first stretch that is rolled ground, runs
# straight and is clear of every site. So a run's rows differ from the last run's and a replay keeps them.

const POSTS := 5
const SIDE_M := 2.4
const FIRST_M := 130.0
const EVERY_M := 260.0
const SLIDES := [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0]
# A row keeps this far from every site (and FIGHT_PAD_M outside every fight's own extent), and its ground rises or falls no more than this a metre of run.
const CLEAR_M := 70.0
const FIGHT_PAD_M := 10.0
const SLOPE := 0.45
const MARGIN_M := 10.0
# The line may turn this much across a row, in radians.
const TURN := 0.35
const KEEP_OF := 3
const TOUCH_M := 1.7
const TOUCH_UP_M := 3.0
const MIN_SPEED := 6.0
const SET_S := 8.0
const SET_SCRAP := 10
const THROW_M := 30.0
const HEIGHT_M := 3.2
const FALL_S := 0.25

var ctx
# The rows standing this stage: {"posts": [Node3D], "down": [bool], "hit": int, "clock": float, "paid": bool}.
var standing: Array = []
var sets_paid := 0

var _rng := RandomNumberGenerator.new()


func setup(context) -> void:
	ctx = context
	name = "SurveyPosts"
	ctx.events.stage_entered.connect(func(stage: int, _retry: bool): _build(stage))
	ctx.events.stage_content_cleared.connect(func(_reason: String): _clear())
	set_physics_process(false)


# Where a run's rows stand on a line: [{"posts": [Vector3 on the ground], "heading": Vector2}], in line order.
# `points` is the line in plan, `spacing` the distance between posts, `gaps` the stretches of the line a built ramp
# covers ([from, to] in metres along it), `clear_of` what a row keeps away from (keep_clear()'s rows), and `ground` a Callable (x, z) -> height.
static func rows(points: PackedVector2Array, spacing: float, gaps: Array, clear_of: Array, ground: Callable, seed_value: int) -> Array:
	var out := []
	if points.size() < 2 or spacing <= 0.0:
		return out
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	var run := spacing * (POSTS - 1)
	var slot := 0
	var centre := FIRST_M
	while centre + run + MARGIN_M + float(SLIDES.max()) < total:
		if posmod(hash([seed_value, "survey_posts", slot]), KEEP_OF) != 0:
			for slide in SLIDES:
				var row := _row(points, centre + slide, spacing, gaps, clear_of, ground)
				if not row.is_empty():
					out.append(row)
					break
		slot += 1
		centre += EVERY_M
	return out


# The row whose first post stands `from` metres along the line, or {} where the stretch does not suit one.
static func _row(points: PackedVector2Array, from: float, spacing: float, gaps: Array, clear_of: Array, ground: Callable) -> Dictionary:
	var run := spacing * (POSTS - 1)
	if from < MARGIN_M or gaps.any(func(g: Array) -> bool: return from - MARGIN_M <= g[1] and from + run + MARGIN_M >= g[0]):
		return {}
	var first := _along(points, from)
	var last := _along(points, from + run)
	if absf(first["heading"].angle_to(last["heading"])) > TURN:
		return {}
	var before: Dictionary = _along(points, from - MARGIN_M)
	var height: float = ground.call(before["at"].x, before["at"].y)
	var d := from - MARGIN_M + 1.0
	while d <= from + run + MARGIN_M:
		var here: Dictionary = _along(points, d)
		var y: float = ground.call(here["at"].x, here["at"].y)
		if absf(y - height) > SLOPE or clear_of.any(func(c: Dictionary) -> bool: return near(c, here["at"])):
			return {}
		height = y
		d += 1.0
	var posts := []
	for i in POSTS:
		var here: Dictionary = _along(points, from + spacing * i)
		var side: Vector2 = here["heading"].orthogonal() * (SIDE_M if i % 2 == 0 else -SIDE_M)
		var at: Vector2 = here["at"] + side
		var y: float = ground.call(at.x, at.y)
		var on_line: float = ground.call(here["at"].x, here["at"].y)
		if absf(y - on_line) > SIDE_M * SLOPE * 2.0:
			return {}
		posts.append(Vector3(at.x, y, at.y))
	return {"posts": posts, "heading": first["heading"]}


# The plan position and unit heading `d` metres along a line.
static func _along(points: PackedVector2Array, d: float) -> Dictionary:
	var left := maxf(0.0, d)
	for i in range(1, points.size()):
		var leg := points[i] - points[i - 1]
		var length := leg.length()
		if left <= length or i == points.size() - 1:
			var heading := leg / length if length > 0.001 else Vector2.DOWN
			return {"at": points[i - 1] + heading * minf(left, length), "heading": heading}
		left -= length
	return {"at": points[0], "heading": Vector2.DOWN}


func _on() -> bool:
	var tuning = ctx.get("tuning")
	return tuning != null and tuning.option("posts") == "on" and not ctx.calm


func _build(stage: int) -> void:
	_clear()
	if not _on():
		return
	var trail: Dictionary = ctx.terrain.scrap_trail(stage)
	if trail.is_empty():
		return
	var map = ctx.terrain.map_for(stage)
	_rng.seed = hash([ctx.rng.seed, ctx.run.run_seed, stage, "survey_posts"])
	var ground := func(x: float, z: float) -> float: return ctx.terrain.height(x, z)
	for row in rows(trail["points"], float(trail["spacing_m"]), trail.get("gaps", []), keep_clear(map), ground, _rng.seed):
		var nodes := []
		var yaw: float = atan2(row["heading"].x, row["heading"].y)
		for at in row["posts"]:
			var post := _post()
			add_child(post)
			post.global_position = at
			post.rotation.y = yaw
			nodes.append(post)
		var down := []
		down.resize(POSTS)
		down.fill(false)
		standing.append({"posts": nodes, "down": down, "hit": 0, "clock": 0.0, "paid": false, "heading": row["heading"]})
	set_physics_process(not standing.is_empty())


# What a map's rows keep away from, as rows() takes it: the Warden's beacon and every activity, rescue and survival
# site by CLEAR_M ({"at", "r"}), and every fight site (a crew home, an event's ground, a fighting activity's ring, the
# yard lock: ParkMap.fight_sites()) by its own ground and FIGHT_PAD_M ({"at", "r"} for a ring, {"at", "half",
# "yaw_deg", "r"} for a box, r being the pad).
static func keep_clear(map) -> Array:
	var out: Array = [{"at": map.beacon, "r": CLEAR_M}]
	for table in ["activity_sites", "rescue_sites", "survival_sites"]:
		if table in map:
			for site in map.get(table):
				var at = site["at"]
				out.append({"at": at if at is Vector2 else Vector2(float(at[0]), float(at[-1])), "r": CLEAR_M})
	if map.has_method("fight_sites"):
		for fight in map.fight_sites():
			if fight.has("half"):
				out.append({"at": fight["at"], "half": fight["half"], "yaw_deg": float(fight.get("yaw_deg", 0.0)), "r": FIGHT_PAD_M})
			else:
				out.append({"at": fight["at"], "r": float((fight["ring"] as Vector2).y) + FIGHT_PAD_M})
	return out


# True when plan point `p` is inside what a keep_clear() row keeps clear.
static func near(row: Dictionary, p: Vector2) -> bool:
	var local: Vector2 = p - row["at"]
	if not row.has("half"):
		return local.length() < float(row["r"])
	local = local.rotated(deg_to_rad(float(row["yaw_deg"])))
	var half: Vector2 = row["half"]
	return Vector2(maxf(0.0, absf(local.x) - half.x), maxf(0.0, absf(local.y) - half.y)).length() < float(row["r"])


func _clear() -> void:
	for row in standing:
		for post in row["posts"]:
			if is_instance_valid(post):
				post.queue_free()
	standing.clear()
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if standing.is_empty() or ctx.player == null:
		return
	var ball: Vector3 = ctx.player.ball_position()
	# Speed along the ground: a ball falling straight down beside a post knocks nothing.
	var velocity: Vector3 = ctx.player.planar_velocity()
	for row in standing:
		if row["paid"]:
			continue
		if row["hit"] > 0:
			row["clock"] += delta
		if velocity.length() < MIN_SPEED:
			continue
		for i in POSTS:
			if row["down"][i]:
				continue
			var post: Node3D = row["posts"][i]
			var to := ball - post.global_position
			if Vector2(to.x, to.z).length() <= TOUCH_M and absf(to.y) <= TOUCH_UP_M:
				_knock(row, i, velocity)
		if row["hit"] == POSTS:
			row["paid"] = true
			if row["clock"] <= SET_S:
				sets_paid += 1
				_throw(ball, velocity.normalized())


# The set's scrap, a piece every few metres ahead of the ball, each seated on the ground it lands on.
func _throw(from: Vector3, heading: Vector3) -> void:
	for i in SET_SCRAP:
		var spot := from + heading * THROW_M * (i + 0.5) / SET_SCRAP
		ctx.build.scrap.drop(ctx.terrain.drop_point(spot.x, spot.z, 0.0), 1, _rng)


# The post falls the way the ball was going and stays down.
func _knock(row: Dictionary, index: int, velocity: Vector3) -> void:
	row["down"][index] = true
	row["hit"] += 1
	var post: Node3D = row["posts"][index]
	var axis := Vector3.UP.cross(velocity.normalized()).normalized()
	var fallen := Basis(axis, PI * 0.47) * post.global_transform.basis
	var tween := post.create_tween()
	tween.tween_property(post, "global_transform:basis", fallen, FALL_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# One post: a thick striped survey pole with an amber pennant that faces up and down the line, built about its
# foot. Sized to read from the chase camera at speed.
func _post() -> Node3D:
	var post := Node3D.new()
	var pole := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.15
	shaft.bottom_radius = 0.2
	shaft.height = HEIGHT_M
	shaft.radial_segments = 8
	pole.mesh = shaft
	pole.material_override = Palette.striped(Palette.AMBER, Palette.CHARCOAL)
	pole.position = Vector3.UP * HEIGHT_M * 0.5
	post.add_child(pole)
	var pennant := MeshInstance3D.new()
	var cloth := PrismMesh.new()
	cloth.size = Vector3(0.9, 1.4, 0.05)
	pennant.mesh = cloth
	pennant.material_override = Palette.solid(Palette.AMBER, 1.2, false)
	pennant.rotation = Vector3(0.0, 0.0, -PI * 0.5)
	pennant.position = Vector3(0.85, HEIGHT_M - 0.55, 0.0)
	post.add_child(pennant)
	return post
