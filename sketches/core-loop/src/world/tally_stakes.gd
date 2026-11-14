extends Node3D

const Palette := preload("res://src/core/palette.gd")

# Tally stakes (BACKLOG W1-103): something small to do on the ride between sites, behind `--stakes=on` (off by
# default). A row is five survey stakes beside the floor line, one a beat of the scrap trail (the trail's own
# spacing), alternating left and right, so a ball that weaves takes all five. A stake the ball touches at speed is
# knocked flat; all five inside SET_S throw a line of scrap ahead of the ball. Nothing stops the ball, nothing has
# a collider (a knock is a touch at speed, as overtime.gd's bell is), no marker points at a row and a missed row
# costs nothing.
#
# Where rows stand is a pure function of the stage's floor line, its sites and the run's seed (rows()): a slot every
# EVERY_M of line, kept on two runs in three, slid along the line to the first stretch that is rolled ground, runs
# straight and is clear of every site. So a run's rows differ from the last run's and a replay keeps them.

const STAKES := 5
const SIDE_M := 2.4
const FIRST_M := 130.0
const EVERY_M := 260.0
const SLIDES := [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0]
# A row keeps this far from every site, and its ground rises or falls no more than this a metre of run.
const CLEAR_M := 70.0
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
# The rows standing this stage: {"stakes": [Node3D], "down": [bool], "hit": int, "clock": float, "paid": bool}.
var standing: Array = []
var sets_paid := 0

var _rng := RandomNumberGenerator.new()


func setup(context) -> void:
	ctx = context
	name = "TallyStakes"
	ctx.events.stage_entered.connect(func(stage: int, _retry: bool): _build(stage))
	ctx.events.stage_content_cleared.connect(func(_reason: String): _clear())


# Where a run's rows stand on a line: [{"stakes": [Vector3 on the ground], "heading": Vector2}], in line order.
# `points` is the line in plan, `spacing` the distance between stakes, `gaps` the stretches of the line a built ramp
# covers ([from, to] in metres along it), `clear_of` the plan positions a row keeps CLEAR_M from, and `ground` a
# Callable (x, z) -> height.
static func rows(points: PackedVector2Array, spacing: float, gaps: Array, clear_of: Array, ground: Callable, seed_value: int) -> Array:
	var out := []
	if points.size() < 2 or spacing <= 0.0:
		return out
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	var run := spacing * (STAKES - 1)
	var slot := 0
	var centre := FIRST_M
	while centre + run + MARGIN_M + float(SLIDES.max()) < total:
		if posmod(hash([seed_value, "tally_stakes", slot]), KEEP_OF) != 0:
			for slide in SLIDES:
				var row := _row(points, centre + slide, spacing, gaps, clear_of, ground)
				if not row.is_empty():
					out.append(row)
					break
		slot += 1
		centre += EVERY_M
	return out


# The row whose first stake stands `from` metres along the line, or {} where the stretch does not suit one.
static func _row(points: PackedVector2Array, from: float, spacing: float, gaps: Array, clear_of: Array, ground: Callable) -> Dictionary:
	var run := spacing * (STAKES - 1)
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
		if absf(y - height) > SLOPE or clear_of.any(func(at: Vector2) -> bool: return at.distance_to(here["at"]) < CLEAR_M):
			return {}
		height = y
		d += 1.0
	var stakes := []
	for i in STAKES:
		var here: Dictionary = _along(points, from + spacing * i)
		var side: Vector2 = here["heading"].orthogonal() * (SIDE_M if i % 2 == 0 else -SIDE_M)
		var at: Vector2 = here["at"] + side
		var y: float = ground.call(at.x, at.y)
		var on_line: float = ground.call(here["at"].x, here["at"].y)
		if absf(y - on_line) > SIDE_M * SLOPE * 2.0:
			return {}
		stakes.append(Vector3(at.x, y, at.y))
	return {"stakes": stakes, "heading": first["heading"]}


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
	return tuning != null and tuning.option("stakes") == "on" and not ctx.calm


func _build(stage: int) -> void:
	_clear()
	if not _on():
		return
	var trail: Dictionary = ctx.terrain.scrap_trail(stage)
	if trail.is_empty():
		return
	var map = ctx.terrain.map_for(stage)
	var clear_of: Array = [map.beacon]
	for site in map.activity_sites:
		clear_of.append(_plan(site["at"]))
	for table in ["rescue_sites", "survival_sites"]:
		if table in map:
			for site in map.get(table):
				clear_of.append(_plan(site["at"]))
	_rng.seed = hash([ctx.rng.seed, ctx.run.run_seed, stage, "tally_stakes"])
	var ground := func(x: float, z: float) -> float: return ctx.terrain.height(x, z)
	for row in rows(trail["points"], float(trail["spacing_m"]), trail.get("gaps", []), clear_of, ground, _rng.seed):
		var nodes := []
		var yaw: float = atan2(row["heading"].x, row["heading"].y)
		for at in row["stakes"]:
			var stake := _stake()
			add_child(stake)
			stake.global_position = at
			stake.rotation.y = yaw
			nodes.append(stake)
		var down := []
		down.resize(STAKES)
		down.fill(false)
		standing.append({"stakes": nodes, "down": down, "hit": 0, "clock": 0.0, "paid": false})


func _plan(at) -> Vector2:
	if at is Vector2:
		return at
	if at is Vector3:
		return Vector2(at.x, at.z)
	return Vector2(float(at[0]), float(at[-1]))


func _clear() -> void:
	for row in standing:
		for stake in row["stakes"]:
			if is_instance_valid(stake):
				stake.queue_free()
	standing.clear()


func _physics_process(delta: float) -> void:
	if standing.is_empty() or ctx.player == null:
		return
	var body: RigidBody3D = ctx.player.body()
	var ball: Vector3 = ctx.player.ball_position()
	var velocity: Vector3 = body.linear_velocity if body != null else Vector3.ZERO
	for row in standing:
		if row["paid"]:
			continue
		if row["hit"] > 0:
			row["clock"] += delta
		if velocity.length() < MIN_SPEED:
			continue
		for i in STAKES:
			if row["down"][i]:
				continue
			var stake: Node3D = row["stakes"][i]
			var to := ball - stake.global_position
			if Vector2(to.x, to.z).length() <= TOUCH_M and absf(to.y) <= TOUCH_UP_M:
				_knock(row, i, velocity)
		if row["hit"] == STAKES:
			row["paid"] = true
			if row["clock"] <= SET_S:
				sets_paid += 1
				ctx.build.scrap.drop_line(ball, velocity, THROW_M, SET_SCRAP, _rng)


# The stake falls the way the ball was going and stays down.
func _knock(row: Dictionary, index: int, velocity: Vector3) -> void:
	row["down"][index] = true
	row["hit"] += 1
	var stake: Node3D = row["stakes"][index]
	var flat := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var axis := Vector3.UP.cross(flat).normalized()
	if axis.length() < 0.5:
		return
	var fallen := Basis(axis, PI * 0.47) * stake.global_transform.basis
	var tween := stake.create_tween()
	tween.tween_property(stake, "global_transform:basis", fallen, FALL_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# One stake: a thick striped survey pole with an amber pennant that faces up and down the line, built about its
# foot. Sized to read from the chase camera at speed.
func _stake() -> Node3D:
	var stake := Node3D.new()
	var pole := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.15
	shaft.bottom_radius = 0.2
	shaft.height = HEIGHT_M
	shaft.radial_segments = 8
	pole.mesh = shaft
	pole.material_override = Palette.striped(Palette.AMBER, Palette.CHARCOAL)
	pole.position = Vector3.UP * HEIGHT_M * 0.5
	stake.add_child(pole)
	var pennant := MeshInstance3D.new()
	var cloth := PrismMesh.new()
	cloth.size = Vector3(0.9, 1.4, 0.05)
	pennant.mesh = cloth
	pennant.material_override = Palette.solid(Palette.AMBER, 1.2, false)
	pennant.rotation = Vector3(0.0, 0.0, -PI * 0.5)
	pennant.position = Vector3(0.85, HEIGHT_M - 0.55, 0.0)
	stake.add_child(pennant)
	return stake
