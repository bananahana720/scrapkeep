extends Node3D

const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Finishes := preload("res://src/presentation/highdraft_finishes.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const SHADER_DIR := "res://assets/materials/highdraft/"
const CATCH_SECONDS := 0.4
const CATCH_DEPTH := 0.15
const CAPTURE_DEPTH := 0.05
const CAPTURE_AT := 0.2
# Drawn bowl is at most twice the physical sink, so the ball rests in the net it draws.
const VISUAL_CATCH_GAIN := 2.0
const RIPPLE_SECONDS := 0.5
const CAPTURE_RIPPLE_SECONDS := 0.3
const CAPTURE_RIPPLE_SCALE := 0.5
const PULSE_SECONDS := 0.2
const CATCH_RADIUS := 6.0
const CHUNK := 32.0
const CLOUD_WRAP := 650.0
# Seconds between cloud drift steps at full rate; the low preset's share of the rate is a DRESSING row.
const CLOUD_STEP := 0.1
# Idle and occupied counts per column come from the thermal_ride JUICE row.
static var MOTE_COUNTS: Array = EventKinds.juice("thermal_ride")["motes"]
static var STREAK_COUNTS: Array = EventKinds.juice("thermal_ride")["streaks"]

# Injectable only for the missing-resource proof. No preload that can break boot.
static var shader_dir := SHADER_DIR
var thermals: Array[Dictionary] = []
var chunks := {}
var active_catches: Array[Dictionary] = []
var clouds: MultiMeshInstance3D
var cloud_origins: Array[Transform3D] = []
var cloud_placements: Array[Transform3D] = []
var cloud_velocities: Array[Vector3] = []
var clock := 0.0
var frozen := false
# The saved setting, read when the fx installs; Game.set_reduced_motion also updates a live one. It is
# the world effects' one store (WorldFxKit.reduced_motion).
static var preferred: bool:
	get:
		return Kit.reduced_motion
	set(on):
		Kit.reduced_motion = on
var reduced_motion := preferred
var low := false
var _map
var _last_ball := Vector3.INF
var _cloud_wait := 0.0
var _warned_net := false
var _net_dust: Array[GPUParticles3D] = []
var _net_dust_next := 0


static func install(scenery: Node3D, presence: Node, map) -> Node3D:
	var rise := _shader("thermal_rise.gdshader")
	var sag := _shader("net_catch.gdshader")
	if rise == null or sag == null:
		push_warning("highdraft_fx: shaders unavailable; existing Highdraft scenery retained")
		return null
	var fx := new()
	fx.name = "WindEffects"
	fx._map = map
	scenery.add_child(fx)
	for i in int(FxLibrary.spec("net_dust")["pool"]):
		var dust := FxLibrary.build("net_dust")
		dust.name = "NetDust%d" % i
		fx.add_child(dust)
		fx._net_dust.append(dust)
	for row in presence.thermals:
		fx._thermal(row, rise)
	var deck := scenery.get_node_or_null("NetDeck")
	if deck != null:
		for chunk: MultiMeshInstance3D in deck.find_children("Tiles_*", "MultiMeshInstance3D", false, false):
			fx._net_chunk(chunk, sag)
	fx.clouds = scenery.get_node_or_null("Sky/CloudDeck") as MultiMeshInstance3D
	fx._clouds()
	Kit.follow_quality(fx)
	return fx


static func _shader(file: String) -> Shader:
	var path := shader_dir + file
	return load(path) as Shader if ResourceLoader.exists(path) else null


func _thermal(row: Dictionary, shader: Shader) -> void:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("column_height", row.height)
	material.set_shader_parameter("column_radius", row.radius)
	material.set_shader_parameter("lift_tint", EventKinds.world_row("thermal_ride").color)
	material.set_shader_parameter("edge_tint", Kit.dressing_colour("hd_thermal_edge"))
	material.set_shader_parameter("idle_opacity", Kit.dressing_alpha("hd_thermal_idle"))
	material.set_shader_parameter("occupied_opacity", Kit.dressing_alpha("hd_thermal_occupied"))
	var mote := BoxMesh.new()
	mote.size = Vector3.ONE * 0.22
	var streak := _lift_chevron()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6_310_006 + thermals.size()
	var views: Array[MultiMeshInstance3D] = []
	for kind in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mote if kind == 0 else streak
		mm.instance_count = MOTE_COUNTS[1] if kind == 0 else STREAK_COUNTS[1]
		for i in mm.instance_count:
			mm.set_instance_transform(i, Transform3D.IDENTITY)
			mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), sqrt(rng.randf()), rng.randf()))
		var view := MultiMeshInstance3D.new()
		view.name = "Motes_%d" % thermals.size() if kind == 0 else "Streaks_%d" % thermals.size()
		view.multimesh = mm
		view.material_override = material
		view.position = row.base
		view.custom_aabb = AABB(Vector3(-row.radius, -1.0, -row.radius), Vector3(row.radius * 2.0, row.height + 2.0, row.radius * 2.0))
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(view)
		GraphicsPreset.register_scenery(view)
		views.append(view)
	thermals.append({"presence": row, "material": material, "views": views, "occupied": false})


static func _lift_chevron() -> ArrayMesh:
	var vertices := PackedVector3Array()
	# Crossed ribbons keep the upward arrow legible from every chase heading.
	var outline := [Vector2(-0.5, -0.35), Vector2(0, 0.35),
		Vector2(0.5, -0.35), Vector2(0.5, -0.15), Vector2(0, 0.55), Vector2(-0.5, -0.15)]
	for angle in [0.0, PI * 0.5]:
		for index in [0, 1, 5, 1, 4, 5, 1, 2, 3, 1, 3, 4]:
			var point: Vector2 = outline[index]
			vertices.append(Vector3(cos(angle) * point.x, point.y, sin(angle) * point.x))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _net_chunk(view: MultiMeshInstance3D, shader: Shader) -> void:
	var source := view.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
	# Malformed material: keep this chunk's original finish and weave.
	if source == null:
		if not _warned_net:
			_warned_net = true
			push_warning("highdraft_fx: net material unavailable; affected chunks retain their original weave")
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("atlas", source.albedo_texture)
	material.set_shader_parameter("tint", source.albedo_color)
	material.set_shader_parameter("finish_roughness", source.roughness)
	material.set_shader_parameter("finish_metallic", source.metallic)
	material.set_shader_parameter("cord_tint", Finishes.LOOK["bone"])
	material.set_shader_parameter("fade_end", 0.5)
	material.set_shader_parameter("catch_point", Vector4(0.0, 0.0, 0.0, CATCH_RADIUS))
	material.set_shader_parameter("visual_catch_gain", VISUAL_CATCH_GAIN)
	material.set_shader_parameter("ring_glow", Kit.dressing_colour("hd_net_ring"))
	view.material_override = material
	view.custom_aabb = view.custom_aabb.grow(CATCH_DEPTH * VISUAL_CATCH_GAIN)
	var at: Vector3 = (view.get_meta("placements") as Array[Transform3D])[0].origin
	chunks[Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK))] = material


func _clouds() -> void:
	if clouds == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 6_310_036
	var placements: Array[Transform3D] = clouds.get_meta("placements")
	for i in clouds.multimesh.instance_count:
		cloud_origins.append(placements[i])
		cloud_placements.append(placements[i])
		cloud_velocities.append(Vector3(rng.randf_range(0.08, 0.14), 0.0, rng.randf_range(0.025, 0.055)))
	# Drift can reach the whole wrap square, while the banks remain below the catch plane.
	clouds.custom_aabb = AABB(Vector3(-900.0, -34.0, -900.0), Vector3(1800.0, 16.0, 1800.0))


func _sync_dressing() -> void:
	low = Kit.low_preset()
	for row in thermals:
		_density(row)


func _density(row: Dictionary) -> void:
	var state := 1 if row.occupied else 0
	for kind in 2:
		var view: MultiMeshInstance3D = row.views[kind]
		var id := "hd_thermal_motes" if kind == 0 else "hd_thermal_streaks"
		var amount: int = MOTE_COUNTS[state] if kind == 0 else STREAK_COUNTS[state]
		view.multimesh.visible_instance_count = Kit.dressing_count(id, amount, low)
		view.visible = Kit.dressing_shown(id)


# Called by Presence after it reads the actual column occupancy. No physics writes or RNG.
func step(delta: float, ball: Vector3) -> void:
	if frozen:
		return
	clock += delta
	for row in thermals:
		var occupied: bool = row.presence.state == "occupied"
		if occupied != row.occupied:
			row.occupied = occupied
			row.material.set_shader_parameter("occupied", 1.0 if occupied else 0.0)
			_density(row)
		row.material.set_shader_parameter("fx_time", clock)
	_step_catches(delta)
	if ball != Vector3.INF and _map.has_method("net_deck_height"):
		var contact: float = _map.net_deck_height() + Tuning.RADIUS
		if _last_ball != Vector3.INF and ball.y <= contact + 0.15 and ball.y >= contact - 0.2 \
				and (_last_ball.y > contact + 0.15 or _last_ball.y < contact - 0.2):
			catch_at(ball)
	_last_ball = ball
	_cloud_wait += delta
	if clouds != null and _cloud_wait >= CLOUD_STEP / Kit.dressing_share("hd_cloud_drift", low):
		_cloud_wait = 0.0
		for i in cloud_origins.size():
			var xf: Transform3D = cloud_origins[i]
			xf.origin += cloud_velocities[i] * clock
			xf.origin.x = wrapf(xf.origin.x, -CLOUD_WRAP, CLOUD_WRAP)
			xf.origin.z = wrapf(xf.origin.z, -CLOUD_WRAP, CLOUD_WRAP)
			cloud_placements[i] = xf
			clouds.multimesh.set_instance_transform(i, xf)


func catch_at(ball: Vector3) -> void:
	if not _map.has_method("net_deck_height"):
		return
	var deck: float = _map.net_deck_height()
	if absf(ball.y - (deck + Tuning.RADIUS)) > 0.3 or absf(float(_map.sample(ball.x, ball.z)[0]) - deck) > 0.05:
		return
	var point := Vector2(ball.x, ball.z)
	var corner := Vector2i(floori(ball.x / CHUNK), floori(ball.z / CHUNK))
	for x in range(corner.x - 1, corner.x + 2):
		for z in range(corner.y - 1, corner.y + 2):
			var key := Vector2i(x, z)
			if not chunks.has(key):
				continue
			var nearest := Vector2(clampf(point.x, x * CHUNK, (x + 1) * CHUNK), clampf(point.y, z * CHUNK, (z + 1) * CHUNK))
			if nearest.distance_squared_to(point) > CATCH_RADIUS * CATCH_RADIUS:
				continue
			var material: ShaderMaterial = chunks[key]
			active_catches = active_catches.filter(func(row): return row.material != material)
			var row := {"material": material, "at": point, "age": 0.0, "front": 0.0, "capture_front": -1.0, "captured": false}
			active_catches.append(row)
			material.set_shader_parameter("catch_point", Vector4(point.x, point.y, CATCH_DEPTH, CATCH_RADIUS))
			_glow(row)
	if not _net_dust.is_empty() and Kit.dressing_share("hd_net_dust", low, reduced_motion) > 0.0:
		var puff := _net_dust[_net_dust_next]
		_net_dust_next = (_net_dust_next + 1) % _net_dust.size()
		FxLibrary.fire(puff, "net_dust", "net_caught", int(FxLibrary.effects("net_caught")["net_dust"]), Vector3(ball.x, deck + 0.1, ball.z))


# The existing landing signal arrives during force integration. Read the committed body
# transform there so a quick bounce between rendered frames cannot miss its catch.
func on_landed(_impact: float, player: Node3D) -> void:
	if frozen or not is_visible_in_tree() or not is_instance_valid(player):
		return
	var body: RigidBody3D = player.active_body()
	var physics := PhysicsServer3D.body_get_direct_state(body.get_rid())
	if physics != null:
		catch_at(physics.transform.origin)


func _sink(age: float) -> float:
	if age < CAPTURE_AT:
		return lerpf(CATCH_DEPTH, CAPTURE_DEPTH, smoothstep(0.0, 1.0, age / CAPTURE_AT))
	var phase := clampf((age - CAPTURE_AT) / (CATCH_SECONDS - CAPTURE_AT), 0.0, 1.0)
	# Spring toward rest with a smaller second settle. Never above the deck.
	return CAPTURE_DEPTH * pow(1.0 - phase, 2.0) * (0.75 + 0.25 * cos(phase * TAU * 1.5))


# Ring fronts are metres from the contact point; the shader brightens cords at that distance.
func _glow(row: Dictionary) -> void:
	var at: Vector2 = row.at
	var material: ShaderMaterial = row.material
	if Kit.dressing_share("hd_net_ring", low, reduced_motion) == 0.0:
		var level := clampf(1.0 - row.age / PULSE_SECONDS, 0.0, 1.0)
		material.set_shader_parameter("pulse", Vector4(at.x, at.y, CATCH_RADIUS, FlashGuard.spike(0.0, level)))
		return
	var first := clampf(row.age / RIPPLE_SECONDS, 0.0, 1.0)
	row.front = CATCH_RADIUS * first
	material.set_shader_parameter("ring_a", Vector4(at.x, at.y, row.front, FlashGuard.spike(0.0, 1.0 - first if first < 1.0 else 0.0)))
	if row.captured:
		var second := clampf((row.age - CAPTURE_AT) / CAPTURE_RIPPLE_SECONDS, 0.0, 1.0)
		row.capture_front = CATCH_RADIUS * CAPTURE_RIPPLE_SCALE * second
		material.set_shader_parameter("ring_b", Vector4(at.x, at.y, row.capture_front, FlashGuard.spike(0.0, 1.0 - second if second < 1.0 else 0.0)))


func _glow_end(row: Dictionary) -> void:
	var material: ShaderMaterial = row.material
	material.set_shader_parameter("ring_a", Vector4.ZERO)
	material.set_shader_parameter("ring_b", Vector4.ZERO)
	material.set_shader_parameter("pulse", Vector4.ZERO)


func _step_catches(delta: float) -> void:
	if active_catches.is_empty():
		return
	for row in active_catches:
		row.age += delta
		if row.age >= CAPTURE_AT:
			row.captured = true
		row.material.set_shader_parameter("catch_point", Vector4(row.at.x, row.at.y, _sink(row.age), CATCH_RADIUS))
		_glow(row)
	var live: Array[Dictionary] = []
	for row in active_catches:
		if row.age < maxf(RIPPLE_SECONDS, CAPTURE_AT + CAPTURE_RIPPLE_SECONDS):
			live.append(row)
		else:
			_glow_end(row)
	active_catches = live
