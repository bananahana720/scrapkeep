extends SubViewportContainer

const Palette := preload("res://src/core/palette.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")

# The class card's portrait and live ability preview: the pilot's real hero shell
# (hero_assets.gd's glb, painted by its own paint()) in a tiny world of its own. The
# framing follows the visual track's key art (storyboards 10 to 12): the sphere large
# in the upper part, caught mid-action, over a quiet dark floor the card's words sit on.
# At rest the card holds one frame of the pilot's signature move, gently bobbing, the
# pilot turned three-quarters to you. While the card is open the camera pulls back and
# the whole move loops, the camera trailing the sphere at mid range: Sable hooks a wall pylon, swings on the taut line and launches
# like a cannonball; Rivet sprints through a crowd with the laser firing, then blasts;
# Kest lobs sticky charges, blinks out in smoke, draws the line and rides its own blast
# up, then glides down on its vanes. The motion is scripted here, not the game's ball
# and abilities, which need the whole run around them; the model, colours and shapes
# are the game's (ring, chevron, burst).

const LOOP := 3.6
# The loop phase each card holds at rest: the key art's moment.
const REST := {"pylon_engineer": 0.54, "runner_gunner": 0.3, "demolitions_caster": 0.64}
const BOB := 0.08
const REST_SPIN := 2.5
# How far the resting pilot turns from its heading toward the camera.
const FACE_CAMERA := 0.55
const NEAR_OFFSET := Vector3(-0.3, 0.5, 5.0)
const NEAR_LOOK := Vector3(0.0, -0.75, 0.0)
const NEAR_FOV := 42.0
const FOLLOW_OFFSET := Vector3(-0.4, 1.0, 5.9)
const FOLLOW_LOOK := Vector3(0.0, -0.2, 0.0)
const FOLLOW_FOV := 44.0
const FOLLOW_RATE := 5.0
const FLOOR := 6.0
const WALL_X := -2.8
const ANCHOR := Vector3(-2.45, 3.4, 0.0)
const TETHER := 2.7

var def: Resource
# 0 at rest, 1 fully open; the card eases it.
var open := 0.0
var clock := 0.0
var ball: Node3D
# An equipped paint's cosmetic id; colours only the shell's paint slot, never the class accent.
var paint_id := "":
	set(value):
		paint_id = value
		if _core != null:
			_paint_shell()

var _viewport: SubViewport
var _camera: Camera3D
var _core: Node3D
var _pod: Node3D
var _props := {}
var _last := Vector3.ZERO
var _heading := 0.0
var _rest_at := Vector3.ZERO
var _follow := Vector3.ZERO
var _time := 0.0
var _painter


func _init(class_def: Resource = null, size_hint := Vector2(380.0, 260.0)) -> void:
	def = class_def
	stretch = true
	custom_minimum_size = size_hint
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = Vector2i(size_hint)
	add_child(_viewport)
	_build_stage()
	if def != null and HeroAssets.SHELLS.has(def.id):
		_build_shell()
		_build_props()
		clock = _rest_phase() * LOOP
		_pose(_rest_phase() - 0.01)
		_pose(_rest_phase())
		_rest_at = ball.position
		_follow = _rest_at
		_frame(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _painter != null:
		_painter.free()


func playing() -> bool:
	return open > 0.5


func _rest_phase() -> float:
	return REST.get(def.id, 0.5) if def != null else 0.5


func _build_stage() -> void:
	var tint: Color = def.color if def != null else Palette.SAND
	_camera = Camera3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.SAND
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_camera.environment = env
	_viewport.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(32.0), 0.0)
	sun.light_energy = 1.4
	_viewport.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.5, 4.5, -3.0)
	rim.light_color = tint
	rim.light_energy = 2.4
	rim.omni_range = 11.0
	_viewport.add_child(rim)
	var ground := CylinderMesh.new()
	ground.top_radius = FLOOR
	ground.bottom_radius = FLOOR
	ground.height = 0.1
	_mesh(ground, _mat(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.2), 0.0, 1.0, false), Vector3(0.0, -0.05, 0.0))
	_mesh(_torus(FLOOR - 0.06, FLOOR + 0.02), _mat(tint, 1.0), Vector3.ZERO)


func _build_shell() -> void:
	_painter = HeroAssets.new()
	var shell: Node = load(HeroAssets.SHELLS[def.id]).instantiate()
	ball = Node3D.new()
	ball.name = "Shell"
	_viewport.add_child(ball)
	for part in ["Core", "Pod"]:
		var node := shell.find_child(part, true, false) as Node3D
		node.get_parent().remove_child(node)
		node.owner = null
		ball.add_child(node)
	_core = ball.get_node("Core")
	_pod = ball.get_node("Pod")
	shell.free()
	_paint_shell()


func _paint_shell() -> void:
	var tints := {"class": def.color}
	if paint_id != "":
		var tint = _painter.paint_tint(def.id, paint_id)
		if tint != null:
			tints["paint"] = tint
	_painter.paint(_core, tints)
	_painter.paint(_pod, tints)


func _build_props() -> void:
	match def.id:
		"pylon_engineer":
			var wall := BoxMesh.new()
			wall.size = Vector3(1.2, 6.0, 4.0)
			_mesh(wall, _mat(Palette.SANDSTONE, 0.0, 1.0, false), Vector3(WALL_X - 0.6, 3.0, 0.0))
			var post := CylinderMesh.new()
			post.top_radius = 0.14
			post.bottom_radius = 0.24
			post.height = 0.9
			_prop("post", post, Palette.VERDIGRIS.lightened(0.25), 0.0, false)
			_prop("cap", _torus(0.26, 0.4), def.color, 1.8)
			_prop("tether", _stick(0.05), Palette.SAND.darkened(0.3), 0.0, false)
			_prop("discharge", _torus(0.9, 1.0), def.color, 1.8)
			for i in 3:
				_prop("trail%d" % i, _torus(0.5, 0.62), def.color, 1.4)
				_prop("dust%d" % i, _sphere(0.5), Palette.SAND, 0.0)
		"runner_gunner":
			for i in 3:
				var box := BoxMesh.new()
				box.size = Vector3(0.9, 1.2, 0.9)
				_prop("dummy%d" % i, box, Palette.RUST, 0.0, false)
				_prop("bolt%d" % i, _stick(0.07), def.color, 2.6)
				_prop("dust%d" % i, _sphere(0.5), Palette.SANDSTONE, 0.0)
			for i in 4:
				_prop("chevron%d" % i, _chevron(), def.color, 1.6)
			_prop("blast", _torus(0.9, 1.05), def.color, 1.8)
		"demolitions_caster":
			for i in 3:
				_prop("charge%d" % i, _sphere(0.24), def.color, 2.0)
				_prop("boom%d" % i, _burst(), def.color, 2.2)
			for i in 5:
				_prop("smoke%d" % i, _sphere(0.6), Palette.SAND.darkened(0.25), 0.0)
			var lane := BoxMesh.new()
			lane.size = Vector3(1.0, 0.04, 0.9)
			_prop("lane", lane, def.color, 1.2)


func _process(delta: float) -> void:
	if ball == null:
		return
	_time += delta
	if playing():
		clock += delta
	else:
		clock = _rest_phase() * LOOP
	_pose(fmod(clock, LOOP) / LOOP)
	if not playing():
		ball.position.y += BOB * sin(_time * 2.2)
		_core.rotate(Vector3.UP.cross(Vector3(sin(_heading), 0.0, cos(_heading))).normalized(), -REST_SPIN * delta)
		var toward := _camera.global_position - ball.position
		_pod.rotation.y = lerp_angle(_heading, atan2(-toward.x, -toward.z), FACE_CAMERA)
	_follow = _follow.lerp(ball.position, 1.0 - exp(-FOLLOW_RATE * delta))
	_frame(smoothstep(0.0, 1.0, open))


func _frame(k: float) -> void:
	var at := (_rest_at + NEAR_OFFSET).lerp(_follow + FOLLOW_OFFSET, k)
	_camera.fov = lerpf(NEAR_FOV, FOLLOW_FOV, k)
	_camera.transform = Transform3D(Basis.looking_at((_rest_at + NEAR_LOOK).lerp(_follow + FOLLOW_LOOK, k) - at), at)


# Poses the scene at loop phase t, 0 to 1.
func _pose(t: float) -> void:
	for prop in _props.values():
		prop.visible = false
	ball.visible = true
	match def.id:
		"pylon_engineer":
			_sable(t)
		"runner_gunner":
			_rivet(t)
		"demolitions_caster":
			_kest(t)
	_roll()


func _sable(t: float) -> void:
	var start := Vector3(3.6, 1.0, 0.6)
	var land := Vector3(4.2, 1.0, 0.9)
	var plant := _span(t, 0.18, 0.24)
	if plant > 0.0:
		_show("post", ANCHOR - Vector3(0.1, 0.0, 0.0), Vector3(1.0, maxf(plant, 0.01), 1.0), 1.0, Vector3(0.0, 0.0, PI * 0.5))
		_show("cap", ANCHOR + Vector3(0.35 * plant, 0.0, 0.0), Vector3.ONE * (1.0 + 0.25 * sin(t * 40.0)), 1.0, Vector3(0.0, 0.0, PI * 0.5))
	var burst := _span(t, 0.2, 0.34)
	if burst > 0.0 and burst < 1.0:
		_show("discharge", ANCHOR + Vector3(0.1, 0.0, 0.0), Vector3.ONE * lerpf(0.5, 4.0, burst), 1.0 - burst, Vector3(0.0, 0.0, PI * 0.5))
		for i in 3:
			var drift := Vector3(0.5 + 0.4 * i, (float(i) - 1.0) * 0.8, (float(i) - 1.0) * 0.6) * burst * 1.6
			_show("dust%d" % i, ANCHOR + drift, Vector3.ONE * lerpf(0.4, 1.3, burst), 0.7 * (1.0 - burst))
	if t < 0.22:
		var f := _ease_out(_span(t, 0.0, 0.22))
		ball.position = start.lerp(_swing(0.45), f) + Vector3(0.0, 1.6 * sin(f * PI), 0.0)
	elif t < 0.56:
		ball.position = _swing(lerpf(0.45, 1.9, _ease_in(_span(t, 0.22, 0.56))))
		_line("tether", ball.position, ANCHOR + Vector3(0.35, 0.0, 0.0))
	elif t < 0.88:
		var f := _span(t, 0.56, 0.88)
		ball.position = _arc(_swing(1.9), land, 3.2, f)
		for i in 3:
			var at := _span(t, 0.6 + 0.06 * i, 0.88)
			if at > 0.0 and at < 1.0:
				var spot := _arc(_swing(1.9), land, 3.2, _span(0.6 + 0.06 * i, 0.56, 0.88))
				_show("trail%d" % i, spot, Vector3.ONE * lerpf(0.6, 1.4, at), 1.0 - at, Vector3(PI * 0.5, 0.0, 0.0))
	else:
		ball.position = land.lerp(start, _span(t, 0.88, 1.0))


# The pendulum under the wall anchor: theta 0 hangs straight down, positive swings out.
static func _swing(theta: float) -> Vector3:
	return ANCHOR + Vector3(sin(theta), -cos(theta), 0.25 * sin(theta)) * TETHER


func _rivet(t: float) -> void:
	var start := Vector3(-5.0, 1.0, 0.3)
	var stop := Vector3(4.2, 1.0, 0.3)
	var dummies := [Vector3(-1.2, 0.6, 0.3), Vector3(0.6, 0.6, -0.2), Vector3(2.2, 0.6, 0.6)]
	ball.position = start.lerp(stop, _ease_in(_span(t, 0.1, 0.5)))
	if t < 0.5:
		for i in 3:
			var f := fmod(t * 9.0 + i / 3.0, 1.0)
			var muzzle := ball.position + Vector3(1.1, 0.25, 0.0)
			_line("bolt%d" % i, muzzle + Vector3(6.0 * f, 0.0, 0.0), muzzle + Vector3(6.0 * f + 1.3, 0.0, 0.0))
	for i in 3:
		var home: Vector3 = dummies[i]
		# When the eased sprint reaches this dummy.
		var since := t - lerpf(0.1, 0.5, sqrt(_span(home.x, start.x, stop.x)))
		if since < 0.0:
			_show("dummy%d" % i, home)
		elif since < 0.3:
			var f := since / 0.3
			var side := 1.0 if i % 2 == 0 else -1.0
			_show("dummy%d" % i, home + Vector3(2.4 * f, 3.2 * 4.0 * f * (1.0 - f), side * 2.0 * f), Vector3.ONE,
				1.0, Vector3(f * 7.0, f * 5.0, f * 3.0 * side))
		elif t > 0.86:
			_show("dummy%d" % i, home, Vector3.ONE * maxf(_span(t, 0.86, 0.96), 0.01))
	if t >= 0.1 and t < 0.55:
		for i in 4:
			_show("chevron%d" % i, ball.position - Vector3(1.1 + 0.8 * i, 0.9, 0.0), Vector3.ONE * (1.0 - 0.15 * i), 1.0 - 0.22 * i)
		for i in 3:
			var kick := fmod(t * 6.0 + i / 3.0, 1.0)
			_show("dust%d" % i, ball.position + Vector3(-1.0 - 1.6 * kick, -0.6 + 0.9 * kick, (float(i) - 1.0) * 0.7),
				Vector3.ONE * lerpf(0.4, 1.2, kick), 0.6 * (1.0 - kick))
	var blast := _span(t, 0.52, 0.72)
	if blast > 0.0 and blast < 1.0:
		_show("blast", stop + Vector3(0.0, -0.8, 0.0), Vector3.ONE * lerpf(0.8, 4.5, blast), 1.0 - blast)
	if t > 0.9:
		ball.position = stop.lerp(start, _span(t, 0.9, 1.0))


func _kest(t: float) -> void:
	var start := Vector3(-3.4, 1.0, 1.0)
	var blinked := Vector3(0.1, 1.0, 1.0)
	var apex := Vector3(1.2, 5.6, 0.6)
	var land := Vector3(-2.6, 1.0, 1.2)
	var spots := [Vector3(0.4, 0.24, -0.2), Vector3(1.8, 0.24, -0.2), Vector3(3.2, 0.24, -0.2)]
	for i in 3:
		var thrown := _span(t, 0.03 + 0.07 * i, 0.1 + 0.07 * i)
		var fired := _span(t, 0.56 + 0.05 * i, 0.68 + 0.05 * i)
		if thrown > 0.0 and fired <= 0.0:
			var ready := 0.25 * sin(t * 50.0) if thrown >= 1.0 else 0.0
			_show("charge%d" % i, _arc(start, spots[i], 2.2, thrown), Vector3.ONE * (1.0 + ready))
		if fired > 0.0 and fired < 1.0:
			_show("boom%d" % i, spots[i] + Vector3(0.0, 0.5, 0.0), Vector3.ONE * lerpf(0.4, 2.6, fired), 1.0 - fired,
				Vector3(0.0, fired * 2.0, 0.0))
	var puff := _span(t, 0.28, 0.46)
	if puff > 0.0 and puff < 1.0:
		for i in 5:
			var drift := Vector3(cos(i * 1.3), 0.3 + 0.2 * i, sin(i * 1.3)) * 0.8 * puff
			_show("smoke%d" % i, start + drift, Vector3.ONE * lerpf(0.5, 1.6, puff), 0.8 * (1.0 - puff))
	var lane := _span(t, 0.42, 0.54)
	if lane > 0.0 and t < 0.74:
		var from: Vector3 = spots[0] - Vector3(0.8, 0.2, 0.0)
		var length: float = (spots[2].x - spots[0].x + 1.6) * lane
		_show("lane", from + Vector3(length * 0.5, 0.0, 0.0), Vector3(maxf(length, 0.01), 1.0, 1.0), 0.55)
	var glide := 0.0
	if t < 0.3:
		ball.position = start
	elif t < 0.38:
		ball.position = start
		ball.visible = t < 0.31
	elif t < 0.57:
		ball.position = blinked
	elif t < 0.7:
		ball.position = blinked.lerp(apex, _ease_out(_span(t, 0.57, 0.7)))
	elif t < 0.93:
		glide = 1.0
		var f := _span(t, 0.7, 0.93)
		ball.position = apex.lerp(land, f) + Vector3(0.0, 0.5 * sin(f * PI * 3.0) * (1.0 - f), 0.0)
	else:
		ball.position = land.lerp(start, _span(t, 0.93, 1.0))
	for vane in ["VaneL", "VaneR"]:
		var node := _pod.get_node_or_null(vane) as Node3D
		if node != null:
			node.rotation.z = (1.0 if vane == "VaneL" else -1.0) * glide * PI * 0.5


func _roll() -> void:
	var step := ball.position - _last
	_last = ball.position
	step.y = 0.0
	var dist := step.length()
	if dist < 0.0001 or dist > 3.0:
		return
	var axis := Vector3.UP.cross(step / dist)
	_core.transform.basis = Basis(axis, dist) * _core.transform.basis
	# The pod faces -z (hero_assets.gd _steer_pod).
	_heading = atan2(-step.x, -step.z)
	_pod.rotation.y = lerp_angle(_pod.rotation.y, _heading, 0.25)


func _show(id: String, at: Vector3, scale_by := Vector3.ONE, alpha := 1.0, spin := Vector3.ZERO) -> void:
	var prop: MeshInstance3D = _props[id]
	prop.visible = true
	prop.position = at
	prop.rotation = spin
	prop.scale = scale_by
	(prop.material_override as StandardMaterial3D).albedo_color.a = alpha


# Stretches a unit stick from a to b.
func _line(id: String, a: Vector3, b: Vector3) -> void:
	var prop: MeshInstance3D = _props[id]
	var span := b - a
	if span.length() < 0.01:
		return
	prop.visible = true
	prop.position = (a + b) * 0.5
	var up := span.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	prop.basis = Basis(side, up * span.length(), side.cross(up))
	(prop.material_override as StandardMaterial3D).albedo_color.a = 1.0


func _prop(id: String, mesh: Mesh, color: Color, emit: float, fade := true) -> void:
	var prop := _mesh(mesh, _mat(color, emit, 1.0, fade), Vector3.ZERO)
	prop.visible = false
	_props[id] = prop


func _mesh(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_viewport.add_child(node)
	return node


func _mat(color: Color, emit: float, alpha := 1.0, fade := true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, alpha)
	mat.roughness = 0.7
	if fade:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emit
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


static func _arc(from: Vector3, to: Vector3, height: float, f: float) -> Vector3:
	return from.lerp(to, f) + Vector3(0.0, height * 4.0 * f * (1.0 - f), 0.0)


static func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


# A unit-tall rod, stretched by _line.
static func _stick(radius: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	return mesh


# A flat chevron on the ground, pointing +x: Rivet's shape.
static func _chevron() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(-0.35, 0.0, -0.6), Vector3(0.15, 0.0, 0.0), Vector3(-0.35, 0.0, 0.6),
		Vector3(0.0, 0.0, 0.6), Vector3(0.5, 0.0, 0.0), Vector3(0.0, 0.0, -0.6)]
	for tri in [[0, 1, 5], [5, 1, 4], [1, 2, 3], [1, 3, 4]]:
		for i in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(pts[i])
	return st.commit()


# Three crossed bars: Kest's starburst, the class row's `burst` shape.
static func _burst() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var angle := PI * i / 3.0
		var along := Vector3(cos(angle), sin(angle), 0.0)
		var across := Vector3(-sin(angle), cos(angle), 0.0) * 0.12
		var quad := [-along - across, along - across, along + across, -along + across]
		for tri in [[0, 1, 2], [0, 2, 3], [2, 1, 0], [3, 2, 0]]:
			for j in tri:
				st.set_normal(Vector3.BACK)
				st.add_vertex(quad[j])
	return st.commit()


static func _span(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func _ease_out(f: float) -> float:
	return 1.0 - (1.0 - f) * (1.0 - f)


static func _ease_in(f: float) -> float:
	return f * f
