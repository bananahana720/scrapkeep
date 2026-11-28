extends Node3D

const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")
const Finishes := preload("res://src/presentation/highdraft_finishes.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const StageBeats := preload("res://src/core/stage_beats.gd")
const Comfort := preload("res://src/core/comfort.gd")
const SHADER_DIR := "res://assets/materials/highdraft/"
const CATCH_SECONDS := 0.4
const CATCH_DEPTH := 0.15
const CAPTURE_DEPTH := 0.05
const CAPTURE_AT := 0.2
const VISUAL_CATCH_GAIN := 2.0
const RIPPLE_SECONDS := 0.5
const CAPTURE_RIPPLE_SECONDS := 0.3
const CAPTURE_RIPPLE_SCALE := 0.5
const PULSE_SECONDS := 0.2
const CATCH_RADIUS := 6.0
const CHUNK := 32.0
const CLOUD_WRAP := 650.0
const CLOUD_STEP := 0.1
static var MOTE_COUNTS: Array = EventJuice.juice("thermal_ride")["motes"]
static var STREAK_COUNTS: Array = EventJuice.juice("thermal_ride")["streaks"]

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
var reduced_motion := Comfort.reduced_motion
var low := false
var _map
var _last_ball := Vector3.INF
var _cloud_wait := 0.0
var _warned_net := false
var _net_dust: Array[GPUParticles3D] = []
var _net_dust_next := 0
const RING_SPIN := 0.3
const BUCKET_SPEED := 3.2
const GYPSUM_PERIOD := 26.0
const STRIKE_BEATS := 8
const STRIKE_FALLBACK_S := 4.0
const STRIKE_REACH := 160.0
const BOLT_SECONDS := 0.32
const BOLT_HEIGHT := 140.0
const BOLT_SEGMENTS := 9
const BOLT_WIDTH := 1.1
const BOLT_COLOUR := Color("e4ecff")
const CARD_LAYER := 34
var rings: Array[Dictionary] = []
var buckets: Array[Dictionary] = []
var rods: Array[Dictionary] = []
var gypsum: MultiMeshInstance3D
var gypsum_rest: Array[Transform3D] = []
var bolts: Array[Dictionary] = []
var beat_offset := Callable()
var _last_offset := INF
var _beats := 0
var _strike_wait := 0.0
var _strike_next := 0
var _bolt_material: Material
var _card_layer: CanvasLayer
var _card_title: Label
var _card_line: Label
var _card_left := 0.0
var _tint: ColorRect
var _tint_from := Color(0, 0, 0, 0)
var _tint_to := Color(0, 0, 0, 0)
var _tint_left := 0.0
var _tint_seconds := 0.0
var _events


func bind_events(events) -> void:
	if _events == events or events == null:
		return
	_events = events
	if events.has_signal("boss_arena_entered") and not events.boss_arena_entered.is_connected(_dismiss_cards):
		events.boss_arena_entered.connect(_dismiss_cards)
	if events.has_signal("stage_content_cleared") and not events.stage_content_cleared.is_connected(_on_content_cleared):
		events.stage_content_cleared.connect(_on_content_cleared)
	if events.has_signal("flow_changed") and not events.flow_changed.is_connected(_on_flow_changed):
		events.flow_changed.connect(_on_flow_changed)


func _on_content_cleared(_reason: String) -> void:
	_dismiss_cards()


func _on_flow_changed(flow_state: String) -> void:
	if flow_state not in ["stage", "beacon", "gates"]:
		_dismiss_cards()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_dismiss_cards()


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
	fx._valley(presence)
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
	var mote := preload("res://src/presentation/world23_chunk_craft.gd").get_thermal_mote_mesh()
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
	_step_valley(delta)
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


func on_landed(_impact: float, player: Node3D) -> void:
	if frozen or not is_visible_in_tree() or not is_instance_valid(player):
		return
	var body: RigidBody3D = player.body()
	var physics := PhysicsServer3D.body_get_direct_state(body.get_rid())
	if physics != null:
		catch_at(physics.transform.origin)


func _sink(age: float) -> float:
	if age < CAPTURE_AT:
		return lerpf(CATCH_DEPTH, CAPTURE_DEPTH, smoothstep(0.0, 1.0, age / CAPTURE_AT))
	var phase := clampf((age - CAPTURE_AT) / (CATCH_SECONDS - CAPTURE_AT), 0.0, 1.0)
	return CAPTURE_DEPTH * pow(1.0 - phase, 2.0) * (0.75 + 0.25 * cos(phase * TAU * 1.5))


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


func _valley(presence: Node) -> void:
	if presence.get("rings") == null:
		return
	rings = presence.rings
	buckets = presence.buckets
	rods = presence.rods
	gypsum = presence.gypsum
	if gypsum != null:
		gypsum_rest = gypsum.get_meta("placements")
	_bolt_material = preload("res://src/presentation/world23_chunk_craft.gd").build_lightning_bolt_material()


static func along(path: Array[Vector3], t: float) -> Vector3:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var want := clampf(t, 0.0, 1.0) * total
	for i in path.size() - 1:
		var leg := path[i].distance_to(path[i + 1])
		if want <= leg:
			return path[i].lerp(path[i + 1], want / maxf(leg, 0.001))
		want -= leg
	return path[-1]


func _step_valley(delta: float) -> void:
	if not reduced_motion:
		for ring in rings:
			var rest: Transform3D = ring["rest"]
			var turned := Transform3D(rest.basis.rotated(Vector3.UP, clock * RING_SPIN * float(ring["spin"])),
				rest.origin + Vector3.UP * sin(clock * 0.7 + float(ring["index"])) * 0.6)
			(ring["view"] as MultiMeshInstance3D).multimesh.set_instance_transform(int(ring["index"]), turned)
	for line in buckets:
		var path: Array[Vector3] = line["path"]
		var span := 0.0
		for i in path.size() - 1:
			span += path[i].distance_to(path[i + 1])
		for k in int(line["count"]):
			var t := fposmod(float(line["phase"]) + (k + 0.5) / float(line["count"]) + (0.0 if reduced_motion else clock * BUCKET_SPEED / maxf(span, 1.0)), 1.0)
			(line["view"] as MultiMeshInstance3D).multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, along(path, t)))
	if gypsum != null and not reduced_motion:
		var rise := float(gypsum.get_meta("rise", 0.0))
		for i in gypsum_rest.size():
			var xf := gypsum_rest[i]
			xf.origin.y += rise * 0.5 * (1.0 + sin(TAU * clock / GYPSUM_PERIOD + i * 0.4))
			gypsum.multimesh.set_instance_transform(i, xf)
	_step_strikes(delta)
	_step_bolts(delta)
	_step_cards(delta)


func _step_strikes(delta: float) -> void:
	if rods.is_empty() or reduced_motion:
		return
	var offset := float(beat_offset.call()) if beat_offset.is_valid() else INF
	if is_inf(offset):
		_strike_wait += delta
		if _strike_wait >= STRIKE_FALLBACK_S:
			_strike_wait = 0.0
			_strike_ambient()
		_last_offset = INF
		return
	if not is_inf(_last_offset) and _last_offset < 0.0 and offset >= 0.0:
		_beats += 1
		if _beats % STRIKE_BEATS == 0:
			_strike_ambient()
	_last_offset = offset


func _strike_ambient() -> void:
	strike_rod(_strike_next % rods.size())
	_strike_next = (_strike_next * 7 + 3) % maxi(1, rods.size() * 5)


func on_world_fact(kind: String, at: Vector3) -> void:
	if kind != "lightning_landed" and kind != "lightning_mark_landed" or rods.is_empty() or not is_inside_tree():
		return
	var local := to_local(at)
	var best := -1
	var best_d := STRIKE_REACH
	for i in rods.size():
		var d := Vector2(local.x - (rods[i]["tip"] as Vector3).x, local.z - (rods[i]["tip"] as Vector3).z).length()
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		strike_rod(best)


func strike_rod(i: int) -> void:
	if i < 0 or i >= rods.size() or _bolt_material == null:
		return
	var tip: Vector3 = rods[i]["tip"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(i, int(clock * 10.0)))
	var points: Array[Vector3] = []
	for k in BOLT_SEGMENTS + 1:
		var t := float(k) / BOLT_SEGMENTS
		var wander := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * 9.0 * sin(PI * t)
		points.append(tip + Vector3.UP * BOLT_HEIGHT * (1.0 - t) + wander)
	var vertices := PackedVector3Array()
	for k in BOLT_SEGMENTS:
		var a := points[k]
		var b := points[k + 1]
		var width := BOLT_WIDTH * (1.0 - 0.6 * float(k) / BOLT_SEGMENTS)
		for side in [Vector3.RIGHT, Vector3.BACK]:
			var off: Vector3 = side * width * 0.5
			for p in [a - off, b - off, b + off, a - off, b + off, a + off]:
				vertices.append(p)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var view := MeshInstance3D.new()
	view.name = "Bolt_%d" % i
	view.mesh = mesh
	var material := _bolt_material.duplicate() as ShaderMaterial
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	bolts.append({"view": view, "material": material, "age": 0.0})


func _step_bolts(delta: float) -> void:
	if bolts.is_empty():
		return
	var live: Array[Dictionary] = []
	for bolt in bolts:
		bolt["age"] = float(bolt["age"]) + delta
		var view: MeshInstance3D = bolt["view"]
		if float(bolt["age"]) >= BOLT_SECONDS or not is_instance_valid(view):
			if is_instance_valid(view):
				view.queue_free()
			continue
		var level := FlashGuard.spike(0.0, 1.0 - float(bolt["age"]) / BOLT_SECONDS)
		var mat = bolt["material"]
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("fade_alpha", level)
		elif mat is StandardMaterial3D:
			(mat as StandardMaterial3D).albedo_color.a = level
		live.append(bolt)
	bolts = live


func on_stage_entered(kind: String, retry: bool) -> void:
	_dismiss_cards()
	if retry or kind.is_empty():
		return
	var card: Dictionary = LoreRows.world_three_cold_open(kind)
	if not card.is_empty():
		_show_card(String(card["title"]), "%s: %s" % [String(card["speaker"]), String(card["line"])], float(card["duration_s"]))
	var fade: Dictionary = StageBeats.LAUNCH_CROSSFADE
	if kind == String(fade["to_landmark"]):
		_start_tint(fade["from_tint"], fade["to_tint"], float(fade["seconds"]))


func _ensure_layer() -> void:
	if is_instance_valid(_card_layer):
		return
	_card_layer = CanvasLayer.new()
	_card_layer.name = "HighdraftStoryCard"
	_card_layer.layer = CARD_LAYER
	add_child(_card_layer)


func _show_card(title: String, line: String, seconds: float) -> void:
	_ensure_layer()
	var panel := PanelContainer.new()
	panel.name = "ColdOpen"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 28.0
	panel.offset_right = 520.0
	panel.offset_top = -268.0
	panel.offset_bottom = -172.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.16, 0.86)
	style.border_color = Kit.dressing_colour("hd_thermal_edge")
	style.border_width_left = 5
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_card_title = Label.new()
	_card_title.text = title
	_card_title.add_theme_font_size_override("font_size", 18)
	_card_title.add_theme_color_override("font_color", Color(0.90, 0.63, 0.27))
	box.add_child(_card_title)
	_card_line = Label.new()
	_card_line.text = line
	_card_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_line.add_theme_font_size_override("font_size", 15)
	_card_line.add_theme_color_override("font_color", Color(0.82, 0.77, 0.65))
	box.add_child(_card_line)
	_card_layer.add_child(panel)
	_card_left = seconds


func _start_tint(from: Color, to: Color, seconds: float) -> void:
	_ensure_layer()
	_tint = ColorRect.new()
	_tint.name = "GoldenDuskTint"
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = from
	_card_layer.add_child(_tint)
	_card_layer.move_child(_tint, 0)
	_tint_from = from
	_tint_to = to
	_tint_seconds = maxf(0.1, seconds)
	_tint_left = _tint_seconds


func _step_cards(delta: float) -> void:
	if _card_left > 0.0:
		_card_left -= delta
		var panel := _card_layer.get_node_or_null("ColdOpen") as Control if is_instance_valid(_card_layer) else null
		if panel != null:
			panel.modulate.a = clampf(_card_left / 0.4, 0.0, 1.0)
			if _card_left <= 0.0:
				panel.queue_free()
	if _tint_left > 0.0 and is_instance_valid(_tint):
		_tint_left -= delta
		var t := 1.0 - clampf(_tint_left / _tint_seconds, 0.0, 1.0)
		_tint.color = _tint_from.lerp(_tint_to, smoothstep(0.0, 1.0, t))
		if _tint_left <= 0.0:
			_tint.queue_free()
			_tint = null


func _dismiss_cards() -> void:
	_card_left = 0.0
	_tint_left = 0.0
	_tint = null
	if is_instance_valid(_card_layer):
		_card_layer.free()
	_card_layer = null


func _input(event: InputEvent) -> void:
	if _card_left <= 0.0 and _tint_left <= 0.0:
		return
	var accept := InputMap.has_action("ui_accept") and event.is_action_pressed("ui_accept")
	var cancel := InputMap.has_action("ui_cancel") and event.is_action_pressed("ui_cancel")
	var jump := InputMap.has_action("cl_jump") and event.is_action_pressed("cl_jump")
	if accept or cancel or jump:
		_dismiss_cards()


func _exit_tree() -> void:
	if _events != null and is_instance_valid(_events):
		if _events.has_signal("boss_arena_entered") and _events.boss_arena_entered.is_connected(_dismiss_cards):
			_events.boss_arena_entered.disconnect(_dismiss_cards)
		if _events.has_signal("stage_content_cleared") and _events.stage_content_cleared.is_connected(_on_content_cleared):
			_events.stage_content_cleared.disconnect(_on_content_cleared)
		if _events.has_signal("flow_changed") and _events.flow_changed.is_connected(_on_flow_changed):
			_events.flow_changed.disconnect(_on_flow_changed)
	_events = null
	_dismiss_cards()
