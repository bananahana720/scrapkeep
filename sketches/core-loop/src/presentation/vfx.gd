extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Augments := preload("res://src/movement/augments.gd")

# World-space effects. Each glyph takes its colour and silhouette from the fact's
# event_kinds row, so a slam ring, a kill burst and a scrap square read the same way
# here, in the HUD and in the field notes. Speed shows as a trail and speed lines in
# the speed tier's own colour. Effects stay small, brief and behind or around the
# ball, never across the line ahead, so they never hide the next threat.

const POOL := 48
const SPARKLE_POOL := 6
# Trail seconds and width per speed tier: nothing at a walk, a comet when blazing.
const TRAIL_SECONDS := [0.0, 0.12, 0.22, 0.36]
const TRAIL_WIDTH := [0.0, 0.28, 0.48, 0.72]
const LINES_PER_TIER := [0, 0, 10, 20]

var ctx
var player
var camera
var root: Node3D
# kind -> count of glyphs spawned, for the tests and the notes.
var spawned := {}

var _glyphs: Array = []
var _meshes := {}
var _sparkles: Array = []
var _sparkle_next := 0
var _trail: MeshInstance3D
var _trail_points: Array = []
var _lines: MeshInstance3D
var _streaks: Array = []
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _launch_boost := 0.0


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Vfx"
	player = ctx.player
	camera = ctx.camera
	_rng.seed = 7
	root = Node3D.new()
	root.name = "PresentationFx"
	ctx.root.add_child(root)
	_build_meshes()
	for i in POOL:
		var glyph := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.no_depth_test = false
		glyph.material_override = mat
		glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glyph.visible = false
		root.add_child(glyph)
		_glyphs.append({"node": glyph, "mat": mat, "t": 1.0, "life": 1.0, "from": 1.0, "to": 1.0, "color": Color.WHITE})
	for i in SPARKLE_POOL:
		_sparkles.append(_make_sparkle())
	_build_trail()
	var events = ctx.events
	events.landed.connect(_on_landed)
	events.slammed.connect(_on_slammed)
	events.mounted.connect(_on_mounted)
	events.dismounted.connect(_on_dismounted)
	events.grapple_fired.connect(func(anchor: Vector3): glyph("grapple_fired", anchor, 0.25, 0.7, 0.25))
	events.shot_fired.connect(_on_shot)
	events.enemy_struck.connect(_on_struck)
	events.enemy_killed.connect(func(_kind: String, at: Vector3, _value: int): glyph("enemy_killed", at + Vector3.UP * 0.8, 0.6, 1.8, 0.3))
	events.scrap_collected.connect(_on_scrap)
	events.part_gained.connect(func(_id: String, _source: String): glyph("part_gained", player.ball_position() + Vector3.UP * 2.2, 0.4, 1.1, 0.5))
	events.milestone_won.connect(func(_id: String): glyph("milestone_won", player.ball_position() + Vector3.UP * 2.5, 0.5, 1.6, 0.7))
	events.launched.connect(func(v: Vector3):
		_launch_boost = 1.2
		glyph("launched", player.ball_position(), 1.0, 4.0, 0.35, v))
	events.stage_entered.connect(func(_stage: int, _retry: bool): clear())


func clear() -> void:
	for g in _glyphs:
		g["t"] = 1.0
		g["node"].visible = false
	_trail_points.clear()
	_streaks.clear()


# --- Glyphs ---------------------------------------------------------------------------

func _build_meshes() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	ring.rings = 48
	ring.ring_segments = 6
	_meshes["ring"] = ring
	_meshes["wave"] = ring
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.5
	_meshes["square"] = cube
	_meshes["diamond"] = cube
	var bar := BoxMesh.new()
	bar.size = Vector3(0.12, 0.12, 1.0)
	_meshes["bar"] = bar
	_meshes["burst"] = _star_mesh(6, 0.08, 1.0)
	_meshes["star"] = _star_mesh(4, 0.12, 1.0)
	_meshes["cross"] = _star_mesh(2, 0.1, 1.0)
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.8, 1.0, 0.1)
	_meshes["arrow"] = arrow
	_meshes["chevron"] = arrow
	var dot := SphereMesh.new()
	dot.radius = 0.3
	dot.height = 0.6
	dot.radial_segments = 12
	dot.rings = 6
	_meshes["flash"] = dot
	_meshes["none"] = dot


# Thin spokes radiating from the centre in the XY plane.
static func _star_mesh(spokes: int, thickness: float, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in spokes:
		var angle := PI * i / spokes
		var along := Vector3(cos(angle), sin(angle), 0.0) * length
		var across := Vector3(-sin(angle), cos(angle), 0.0) * thickness
		var a := -along - across
		var b := along - across
		var c := along + across
		var d := -along + across
		for v in [a, b, c, a, c, d]:
			st.add_vertex(v)
	return st.commit()


# Spawns the fact's glyph: its event_kinds shape and colour, growing from size_from to
# size_to over life seconds while it fades. facing orients rings and bars.
func glyph(kind: String, at: Vector3, size_from: float, size_to: float, life: float, facing := Vector3.ZERO, shape := "") -> void:
	if root == null or not root.is_inside_tree():
		return
	var row := EventKinds.row(kind)
	var silhouette: String = shape if shape != "" else String(row.get("shape", "none"))
	var slot: Dictionary = _glyphs[0]
	for g in _glyphs:
		if g["t"] >= 1.0:
			slot = g
			break
		if g["t"] > slot["t"]:
			slot = g
	var node: MeshInstance3D = slot["node"]
	node.mesh = _meshes.get(silhouette, _meshes["flash"])
	node.global_position = at
	slot["basis"] = _facing_basis(silhouette, facing)
	slot["color"] = EventKinds.color(kind)
	slot["t"] = 0.0
	slot["life"] = maxf(0.05, life)
	slot["from"] = size_from
	slot["to"] = size_to
	slot["spin"] = 3.0 if silhouette in ["star", "burst", "diamond", "square"] else 0.0
	node.visible = true
	spawned[kind] = spawned.get(kind, 0) + 1
	_draw_glyph(slot)


func _facing_basis(silhouette: String, facing: Vector3) -> Basis:
	if facing.length_squared() < 0.0001:
		# Flat glyphs lie on the ground; the rest face the camera.
		if silhouette in ["ring", "wave"]:
			return Basis.IDENTITY
		if camera != null and camera.cam != null:
			return camera.cam.global_basis
		return Basis.IDENTITY
	var dir := facing.normalized()
	if silhouette in ["ring", "wave"]:
		# A torus lies in its XZ plane, so point its Y along the facing.
		var right := Vector3.RIGHT if absf(dir.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		right = (right - dir * right.dot(dir)).normalized()
		return Basis(right, dir, right.cross(dir))
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	return Basis.looking_at(dir, up)


func _draw_glyph(slot: Dictionary) -> void:
	var t: float = slot["t"]
	var node: MeshInstance3D = slot["node"]
	var grow := ease(t, 0.35)
	var size: float = lerpf(slot["from"], slot["to"], grow)
	var base: Basis = slot.get("basis", Basis.IDENTITY)
	if slot.get("spin", 0.0) > 0.0:
		base = base * Basis(Vector3.BACK, slot["spin"] * t)
	node.basis = base.scaled(Vector3.ONE * size)
	var color: Color = slot["color"]
	var mat: StandardMaterial3D = slot["mat"]
	mat.albedo_color = Color(color.r, color.g, color.b, (1.0 - t) * 0.9)


# --- Facts -------------------------------------------------------------------------------

func _on_landed(impact: float) -> void:
	if impact < 10.0:
		return
	var at: Vector3 = player.ball_position() - player.state.contact_normal * 0.95
	glyph("landed", at, 0.6, 1.2 + impact * 0.06, 0.25, player.state.contact_normal)


# The slam ring grows to the slam's real reach, so the effect shows exactly who it hit.
func _on_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05:
		return
	glyph("slammed", at + Vector3.UP * 0.15, 1.0, Augments.SLAM_RADIUS, 0.35, player.state.contact_normal)


# The plant ring shows the mount's repel reach.
func _on_mounted(at: Vector3, _banked: float) -> void:
	var normal: Vector3 = player.kit.mount_normal
	var face: Vector3 = player.kit.mount_face if player.kit.mount_face != Vector3.ZERO else at
	glyph("mounted", face + normal * 0.1, 0.8, Augments.MOUNT_REPEL_RADIUS, 0.3, normal, "ring")


func _on_dismounted(velocity: Vector3) -> void:
	if velocity.length() > 1.0:
		glyph("dismounted", player.ball_position(), 0.8, 1.6, 0.22, velocity)


func _on_shot(_weapon: String, from: Vector3, to: Vector3) -> void:
	var dir := to - from
	# Muzzle: a short bar along the shot, right at the barrel.
	glyph("shot_fired", from + dir.normalized() * 0.4, 0.5, 0.9, 0.06, dir)
	# Impact: a small flash where it landed.
	glyph("shot_fired", to, 0.5, 1.1, 0.09, Vector3.ZERO, "flash")


func _on_struck(enemy: Node3D, _kind: String, force: float) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	glyph("enemy_struck", enemy.global_position + Vector3.UP * 0.6, 0.4, clampf(0.8 + force * 0.03, 0.8, 1.6), 0.14)


# --- Scrap sparkles ------------------------------------------------------------------------

func _make_sparkle() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.4
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0.0, -14.0, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = EventKinds.color("scrap_collected")
	mesh.material = mat
	p.mesh = mesh
	root.add_child(p)
	return p


func _on_scrap(amount: int, at: Vector3, _total: int) -> void:
	var p: CPUParticles3D = _sparkles[_sparkle_next]
	_sparkle_next = (_sparkle_next + 1) % _sparkles.size()
	p.global_position = at
	p.amount = clampi(6 + amount * 2, 6, 20)
	p.restart()
	p.emitting = true
	spawned["scrap_collected"] = spawned.get("scrap_collected", 0) + 1


# --- Trail and speed lines -----------------------------------------------------------------

func _build_trail() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The juice node belongs to presentation; the trail hangs off it but draws in world
	# space, so it is top level.
	var juice: Node3D = player.juice_node()
	_trail = MeshInstance3D.new()
	_trail.name = "Trail"
	_trail.mesh = ImmediateMesh.new()
	_trail.material_override = mat
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	juice.add_child(_trail)
	_lines = MeshInstance3D.new()
	_lines.name = "SpeedLines"
	_lines.mesh = ImmediateMesh.new()
	_lines.material_override = mat
	_lines.top_level = true
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	juice.add_child(_lines)


func _process(delta: float) -> void:
	if player == null:
		return
	_clock += delta
	_launch_boost = maxf(0.0, _launch_boost - delta)
	for g in _glyphs:
		if g["t"] >= 1.0:
			continue
		g["t"] = minf(1.0, g["t"] + delta / g["life"])
		if g["t"] >= 1.0:
			g["node"].visible = false
		else:
			_draw_glyph(g)
	var tier: int = player.speed_tier()
	if _launch_boost > 0.0:
		tier = SpeedTier.BLAZING
	_draw_trail(tier)
	_draw_lines(tier, delta)


func _draw_trail(tier: int) -> void:
	var mesh: ImmediateMesh = _trail.mesh
	mesh.clear_surfaces()
	var at: Vector3 = player.shown_position()
	_trail_points.push_front([at, _clock])
	var keep: float = TRAIL_SECONDS[clampi(tier, 0, 3)]
	while _trail_points.size() > 2 and _clock - _trail_points.back()[1] > keep:
		_trail_points.pop_back()
	if keep <= 0.0 or _trail_points.size() < 3 or camera == null or camera.cam == null:
		return
	var eye: Vector3 = camera.cam.global_position
	var width: float = TRAIL_WIDTH[tier]
	var color: Color = SpeedTier.COLORS[tier]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var count := _trail_points.size()
	for i in count:
		var p: Vector3 = _trail_points[i][0]
		var along: Vector3 = _trail_points[maxi(i - 1, 0)][0] - _trail_points[mini(i + 1, count - 1)][0]
		if along.length_squared() < 0.000001:
			along = Vector3.FORWARD
		var side := along.cross(eye - p).normalized() * width * (1.0 - float(i) / count)
		var fade := (1.0 - float(i) / count) * 0.55
		mesh.surface_set_color(Color(color.r, color.g, color.b, fade))
		mesh.surface_add_vertex(p + side)
		mesh.surface_set_color(Color(color.r, color.g, color.b, fade))
		mesh.surface_add_vertex(p - side)
	mesh.surface_end()


# Streaks in a sleeve around the ball, drawn from beside the ball backwards only, so
# they frame the ball and never cross the line ahead.
func _draw_lines(tier: int, delta: float) -> void:
	var mesh: ImmediateMesh = _lines.mesh
	mesh.clear_surfaces()
	var wanted: int = LINES_PER_TIER[clampi(tier, 0, 3)]
	var velocity: Vector3 = player.state.velocity
	var speed := velocity.length()
	if wanted == 0 or speed < 1.0:
		_streaks.clear()
		return
	var dir := velocity / speed
	var at: Vector3 = player.shown_position()
	var right := dir.cross(Vector3.UP)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(dir).normalized()
	while _streaks.size() < wanted:
		var angle := _rng.randf() * TAU
		_streaks.append({"angle": angle, "radius": _rng.randf_range(1.7, 3.4), "offset": _rng.randf_range(-1.0, 0.4), "length": _rng.randf_range(1.2, 3.2)})
	while _streaks.size() > wanted:
		_streaks.pop_back()
	var color: Color = SpeedTier.COLORS[tier]
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for streak in _streaks:
		# Each streak slides back past the ball and wraps to the front of the sleeve.
		streak["offset"] -= delta * (1.5 + speed * 0.08)
		if streak["offset"] < -3.0:
			streak["offset"] = _rng.randf_range(0.0, 0.4)
			streak["angle"] = _rng.randf() * TAU
		var ring: Vector3 = (right * cos(streak["angle"]) + up * sin(streak["angle"])) * streak["radius"]
		var head: Vector3 = at + ring + dir * streak["offset"]
		var tail: Vector3 = head - dir * streak["length"] * (0.6 + 0.2 * tier)
		mesh.surface_set_color(Color(color.r, color.g, color.b, 0.5))
		mesh.surface_add_vertex(head)
		mesh.surface_set_color(Color(color.r, color.g, color.b, 0.0))
		mesh.surface_add_vertex(tail)
	mesh.surface_end()
