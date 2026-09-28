extends SubViewportContainer

const Palette := preload("res://src/core/palette.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")

# The class card's portrait and live ability preview: the pilot's real hero shell
# (hero_assets.gd's glb, painted by its own paint()) in a tiny world of its own. At rest
# the shell turns on a class-coloured plinth. While the card is open the camera pulls
# back and the shell plays its signature move on a loop: Sable plants a pylon, swings
# on the hook and launches like a cannonball; Rivet sprints through a crowd and blasts
# it; Kest lobs sticky charges, blinks out in smoke and fires the line. The motion is
# scripted here, not the game's ball and abilities, which need the whole run around
# them; the shapes and colours are the ones the game uses (ring, chevron, burst).

const LOOP := 3.6
const SPIN := 0.55
const NEAR := {"at": Vector3(0.0, 1.9, 4.2), "look": Vector3(0.0, 0.9, 0.0), "fov": 40.0}
const FAR := {"at": Vector3(-0.4, 3.3, 8.8), "look": Vector3(-0.4, 1.6, 0.0), "fov": 40.0}
# The plinth is a pedestal at rest and grows into the demo's floor as the card opens.
const PLINTH := 5.4
const PEDESTAL := 1.5

var def: Resource
# 0 at rest, 1 fully open; the card eases it.
var open := 0.0
var clock := 0.0
var ball: Node3D

var _viewport: SubViewport
var _camera: Camera3D
var _core: Node3D
var _pod: Node3D
var _props := {}
var _last := Vector3.ZERO
var _painter
var _plinth: Node3D


func _init(class_def: Resource = null, size_hint := Vector2(380.0, 190.0)) -> void:
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
	_pose(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _painter != null:
		_painter.free()


func playing() -> bool:
	return open > 0.5


func _build_stage() -> void:
	var tint: Color = def.color if def != null else Palette.SAND
	_camera = Camera3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.SAND
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_camera.environment = env
	_viewport.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(28.0), 0.0)
	sun.light_energy = 1.3
	_viewport.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.5, 3.0, -3.0)
	rim.light_color = tint
	rim.light_energy = 2.2
	rim.omni_range = 9.0
	_viewport.add_child(rim)
	_plinth = Node3D.new()
	_viewport.add_child(_plinth)
	var plinth := CylinderMesh.new()
	plinth.top_radius = 1.0
	plinth.bottom_radius = 1.0
	plinth.height = 0.1
	_mesh(plinth, _mat(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.2), 0.0, 1.0, false), Vector3(0.0, -0.05, 0.0), _plinth)
	var edge := TorusMesh.new()
	edge.inner_radius = 0.97
	edge.outer_radius = 1.02
	_mesh(edge, _mat(tint, 1.2), Vector3.ZERO, _plinth)
	_plinth.scale = Vector3(PEDESTAL, 1.0, PEDESTAL)


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
		_painter.paint(node, {"class": def.color})
		ball.add_child(node)
	_core = ball.get_node("Core")
	_pod = ball.get_node("Pod")
	shell.free()


func _build_props() -> void:
	match def.id:
		"pylon_engineer":
			var post := CylinderMesh.new()
			post.top_radius = 0.1
			post.bottom_radius = 0.18
			post.height = 2.6
			_prop("post", post, Palette.SAND.lightened(0.2), 0.0, false)
			_prop("cap", _torus(0.28, 0.42), def.color, 1.6)
			_prop("tether", _stick(0.05), def.color, 2.0)
			_prop("discharge", _torus(0.9, 1.0), def.color, 1.8)
			for i in 3:
				_prop("trail%d" % i, _torus(0.5, 0.62), def.color, 1.4)
		"runner_gunner":
			for i in 3:
				var box := BoxMesh.new()
				box.size = Vector3(0.9, 1.2, 0.9)
				_prop("dummy%d" % i, box, Palette.RUST, 0.0, false)
				_prop("bolt%d" % i, _stick(0.07), def.color, 2.4)
			for i in 4:
				_prop("chevron%d" % i, _chevron(), def.color, 1.6)
			_prop("blast", _torus(0.9, 1.05), def.color, 1.8)
		"demolitions_caster":
			for i in 3:
				var sphere := SphereMesh.new()
				sphere.radius = 0.24
				sphere.height = 0.48
				_prop("charge%d" % i, sphere, def.color, 2.0)
				_prop("boom%d" % i, _burst(), def.color, 2.2)
			for i in 5:
				var puff := SphereMesh.new()
				puff.radius = 0.6
				puff.height = 1.2
				_prop("smoke%d" % i, puff, Palette.SAND.darkened(0.25), 0.0)
			var lane := BoxMesh.new()
			lane.size = Vector3(1.0, 0.04, 0.9)
			_prop("lane", lane, def.color, 1.2)


func _process(delta: float) -> void:
	if ball == null:
		return
	if playing():
		clock += delta
	else:
		clock = 0.0
		ball.rotation.y += SPIN * delta
	var k := smoothstep(0.0, 1.0, open)
	_camera.position = (NEAR["at"] as Vector3).lerp(FAR["at"], k)
	_camera.fov = lerpf(NEAR["fov"], FAR["fov"], k)
	_camera.look_at((NEAR["look"] as Vector3).lerp(FAR["look"], k))
	var reach := lerpf(PEDESTAL, PLINTH, k)
	_plinth.scale = Vector3(reach, 1.0, reach)
	_pose(fmod(clock, LOOP) / LOOP if playing() else -1.0)


# Poses the scene at loop phase t (0 to 1), or at rest for t < 0.
func _pose(t: float) -> void:
	if ball == null:
		return
	for prop in _props.values():
		prop.visible = false
	if t < 0.0:
		ball.visible = true
		ball.position = Vector3(0.0, 1.0, 0.0)
		_last = ball.position
		return
	ball.rotation.y = 0.0
	match def.id:
		"pylon_engineer":
			_sable(t)
		"runner_gunner":
			_rivet(t)
		"demolitions_caster":
			_kest(t)
	_roll()


func _sable(t: float) -> void:
	var pylon := Vector3(2.0, 0.0, -0.4)
	var top := pylon + Vector3(0.0, 2.6, 0.0)
	var swing_r := 1.6
	var rise := _span(t, 0.2, 0.3)
	if t >= 0.2:
		_show("post", pylon + Vector3(0.0, 1.3 * rise, 0.0), Vector3(1.0, maxf(rise, 0.01), 1.0))
		_show("cap", pylon + Vector3(0.0, 2.6 * rise, 0.0), Vector3.ONE * (1.0 + 0.3 * sin(t * 40.0)))
	var burst := _span(t, 0.28, 0.42)
	if burst > 0.0 and burst < 1.0:
		_show("discharge", pylon + Vector3(0.0, 0.1, 0.0), Vector3.ONE * lerpf(0.6, 5.0, burst), 1.0 - burst)
	var swing_end := pylon + Vector3(0.0, 1.0, swing_r)
	if t < 0.3:
		var a := _ease_out(_span(t, 0.0, 0.3))
		ball.position = Vector3(-4.5, 1.0, 0.6).lerp(pylon + Vector3(-swing_r, 1.0, 0.0), a)
	elif t < 0.56:
		var angle := lerpf(PI, PI * 2.5, _span(t, 0.3, 0.56))
		ball.position = pylon + Vector3(cos(angle) * swing_r, 1.0 + 0.4 * sin(angle * 2.0), sin(angle) * swing_r)
		_line("tether", ball.position, top)
	elif t < 0.9:
		var f := _span(t, 0.56, 0.9)
		var land := Vector3(-4.2, 1.0, 1.2)
		ball.position = swing_end.lerp(land, f) + Vector3(0.0, 4.2 * 4.0 * f * (1.0 - f), 0.0)
		for i in 3:
			var at := _span(t, 0.6 + 0.07 * i, 0.9)
			if at > 0.0 and at < 1.0:
				var p := _span(0.6 + 0.07 * i, 0.56, 0.9)
				var spot := swing_end.lerp(land, p) + Vector3(0.0, 4.2 * 4.0 * p * (1.0 - p), 0.0)
				_show("trail%d" % i, spot, Vector3.ONE * lerpf(0.6, 1.4, at), 1.0 - at, Vector3(PI * 0.5, 0.0, 0.0))
	else:
		var f := _span(t, 0.9, 1.0)
		ball.position = Vector3(-4.2, 1.0 + 0.5 * sin(f * PI), 1.2)


func _rivet(t: float) -> void:
	var start := Vector3(-5.0, 1.0, 0.3)
	var stop := Vector3(4.2, 1.0, 0.3)
	var dummies := [Vector3(-1.2, 0.6, 0.3), Vector3(0.6, 0.6, -0.2), Vector3(2.2, 0.6, 0.6)]
	ball.position = start.lerp(stop, _ease_in(_span(t, 0.12, 0.5)))
	for i in 3:
		var f := _span(t, 0.03 * i, 0.03 * i + 0.08)
		if f > 0.0 and f < 1.0:
			var from := start + Vector3(1.0, 0.1, 0.0)
			var to: Vector3 = dummies[0] + Vector3(0.0, 0.3, 0.0)
			_line("bolt%d" % i, from.lerp(to, f), from.lerp(to, minf(1.0, f + 0.25)))
	for i in 3:
		var home: Vector3 = dummies[i]
		# When the eased sprint reaches this dummy.
		var since := t - lerpf(0.12, 0.5, sqrt(_span(home.x, start.x, stop.x)))
		if since < 0.0:
			_show("dummy%d" % i, home)
		elif since < 0.3:
			var f := since / 0.3
			var side := 1.0 if i % 2 == 0 else -1.0
			_show("dummy%d" % i, home + Vector3(2.4 * f, 3.2 * 4.0 * f * (1.0 - f), side * 2.0 * f), Vector3.ONE,
				1.0, Vector3(f * 7.0, f * 5.0, f * 3.0 * side))
		elif t > 0.86:
			_show("dummy%d" % i, home, Vector3.ONE * maxf(_span(t, 0.86, 0.96), 0.01))
	if t >= 0.12 and t < 0.55:
		for i in 4:
			var back := ball.position - Vector3(1.1 + 0.8 * i, 0.9, 0.0)
			_show("chevron%d" % i, back, Vector3.ONE * (1.0 - 0.15 * i), 1.0 - 0.22 * i)
	var blast := _span(t, 0.52, 0.72)
	if blast > 0.0 and blast < 1.0:
		_show("blast", stop + Vector3(0.0, -0.8, 0.0), Vector3.ONE * lerpf(0.8, 4.5, blast), 1.0 - blast)
	if t > 0.9:
		ball.position = stop.lerp(start, _span(t, 0.9, 1.0))


func _kest(t: float) -> void:
	var start := Vector3(-3.4, 1.0, 1.0)
	var hidden_at := Vector3(-1.0, 1.0, 2.8)
	var spots := [Vector3(0.4, 0.24, -0.2), Vector3(1.8, 0.24, -0.2), Vector3(3.2, 0.24, -0.2)]
	ball.position = start
	for i in 3:
		var thrown := _span(t, 0.04 + 0.08 * i, 0.12 + 0.08 * i)
		var fired := _span(t, 0.6 + 0.06 * i, 0.72 + 0.06 * i)
		if thrown > 0.0 and fired <= 0.0:
			var spot: Vector3 = spots[i]
			var arc := start.lerp(spot, thrown) + Vector3(0.0, 2.2 * 4.0 * thrown * (1.0 - thrown), 0.0)
			_show("charge%d" % i, arc, Vector3.ONE * (1.0 + (0.25 * sin(t * 50.0) if thrown >= 1.0 else 0.0)))
		if fired > 0.0 and fired < 1.0:
			_show("boom%d" % i, spots[i] + Vector3(0.0, 0.5, 0.0), Vector3.ONE * lerpf(0.4, 2.4, fired), 1.0 - fired,
				Vector3(0.0, fired * 2.0, 0.0))
	var puff := _span(t, 0.36, 0.56)
	if puff > 0.0 and puff < 1.0:
		for i in 5:
			var drift := Vector3(cos(i * 1.3), 0.3 + 0.2 * i, sin(i * 1.3)) * 0.8 * puff
			_show("smoke%d" % i, start + drift, Vector3.ONE * lerpf(0.5, 1.6, puff), 0.8 * (1.0 - puff))
	if t >= 0.38 and t < 0.44:
		ball.visible = false
	else:
		ball.visible = true
	if t >= 0.44:
		ball.position = hidden_at.lerp(start, _span(t, 0.92, 1.0))
	var lane := _span(t, 0.48, 0.6)
	if lane > 0.0 and t < 0.84:
		var from: Vector3 = spots[0] - Vector3(0.8, 0.2, 0.0)
		var length: float = (spots[2].x - spots[0].x + 1.6) * lane
		_show("lane", from + Vector3(length * 0.5, 0.0, 0.0), Vector3(maxf(length, 0.01), 1.0, 1.0), 0.55)


func _roll() -> void:
	var step := ball.position - _last
	_last = ball.position
	step.y = 0.0
	var dist := step.length()
	if dist < 0.0001 or dist > 3.0:
		return
	var axis := Vector3.UP.cross(step / dist)
	_core.transform.basis = Basis(axis, dist) * _core.transform.basis
	_pod.rotation.y = lerp_angle(_pod.rotation.y, atan2(step.x, step.z), 0.25)


func _show(id: String, at: Vector3, scale_by := Vector3.ONE, alpha := 1.0, spin := Vector3.ZERO) -> void:
	var prop: MeshInstance3D = _props[id]
	prop.visible = true
	prop.position = at
	prop.rotation = spin
	prop.scale = scale_by
	var mat := prop.material_override as StandardMaterial3D
	mat.albedo_color.a = alpha


# Stretches a unit stick from a to b.
func _line(id: String, a: Vector3, b: Vector3) -> void:
	var prop: MeshInstance3D = _props[id]
	var span := b - a
	if span.length() < 0.01:
		return
	prop.visible = true
	prop.position = (a + b) * 0.5
	prop.scale = Vector3.ONE
	var up := span.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	prop.basis = Basis(side, up * span.length(), side.cross(up))
	(prop.material_override as StandardMaterial3D).albedo_color.a = 1.0


func _prop(id: String, mesh: Mesh, color: Color, emit: float, fade := true) -> void:
	var prop := _mesh(mesh, _mat(color, emit, 1.0, fade), Vector3.ZERO)
	prop.visible = false
	_props[id] = prop


func _mesh(mesh: Mesh, mat: Material, at: Vector3, parent: Node = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _viewport).add_child(node)
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


static func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
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
