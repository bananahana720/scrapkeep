extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")


const BEAM_HEIGHT := 70.0
const GATE_RADIUS := 6.0
const FOG_COLOR := Color("c8a878")
const PILLAR_ALPHA := 0.45
const PILLAR_FADE := Vector2(4.0, 20.0)
const ARRIVAL_RADIUS := 3.0
const RELAY_MAST := "res://assets/models/world_one/relay_mast.glb"
const VAULT_PROMPT_REACH := 60.0

var director
var terrain
var player

var _vault_pillar: MeshInstance3D
var _vault_anchor: Node3D
var vault_prompt
var _arrival_rings: Array[MeshInstance3D] = []

var _offer_nodes: Array[Dictionary] = []
var _dust_wall: MeshInstance3D
var _base_fog := 0.0009
var _base_fog_color := Color.WHITE


func setup(terrain_ref, player_ref = null) -> void:
	terrain = terrain_ref
	player = player_ref
	_vault_pillar = _pillar(Palette.AMBER)
	_vault_pillar.visible = false
	add_child(_vault_pillar)
	_vault_anchor = Node3D.new()
	add_child(_vault_anchor)
	vault_prompt = WorldPrompt.new()
	vault_prompt.add_theme_color_override("font_color", Palette.AMBER)
	vault_prompt.attach(_vault_anchor, Vector3.ZERO, VAULT_PROMPT_REACH)
	_vault_anchor.add_child(vault_prompt)
	record_fog()
	_dust_wall = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(420.0, 60.0)
	_dust_wall.mesh = quad
	_dust_wall.material_override = Palette.unshaded(Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, 0.45))
	_dust_wall.visible = false
	add_child(_dust_wall)


func record_fog() -> void:
	if terrain != null and terrain.environment != null:
		_base_fog = terrain.environment.fog_density
		_base_fog_color = terrain.environment.fog_light_color


func rebuild(director_ref) -> void:
	director = director_ref
	for entry in _offer_nodes:
		entry["root"].queue_free()
	_offer_nodes.clear()
	for offer in director.offers:
		_offer_nodes.append(_build_offer(offer))
	_apply_fog(0.0)


func clear() -> void:
	director = null
	for entry in _offer_nodes:
		entry["root"].queue_free()
	_offer_nodes.clear()
	show_arrivals([])
	set_vault(Vector3.ZERO, false)
	_dust_wall.visible = false
	_apply_fog(0.0)


func _build_offer(offer: Dictionary) -> Dictionary:
	var model = offer["model"]
	var root := Node3D.new()
	add_child(root)
	var hazard := EventKinds.color("event_started")
	var ground := _ground(model.ring)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = model.ring_radius - 0.8
	torus.outer_radius = model.ring_radius
	ring.mesh = torus
	var ring_mat := Palette.solid(hazard, 1.6)
	ring.material_override = ring_mat
	ring.position = ground + Vector3.UP * 0.3
	root.add_child(ring)

	var beam := _pillar(hazard)
	beam.position = ground + Vector3.UP * BEAM_HEIGHT * 0.5
	root.add_child(beam)

	var sign := _label(offer["id"].replace("_", " ").capitalize() + "\nroll in: milestone part + bonus core", hazard)
	sign.position = ground + Vector3.UP * 9.0
	root.add_child(sign)

	var status := _label("", Palette.SAND)
	status.visible = false
	root.add_child(status)

	var entry := {"offer": offer, "root": root, "ring": ring, "ring_mat": ring_mat, "beam": beam,
		"sign": sign, "status": status, "parts": []}
	match offer["id"]:
		"surge_run":
			_build_surge(entry, model)
		"hold_the_relay":
			_build_relay(entry, model)
		"scrap_stampede":
			_build_hauler(entry)
	return entry


func _build_surge(entry: Dictionary, model) -> void:
	var gates: Array = []
	for i in model.gates.size():
		var g := gate_ring(_ground(model.gates[i]), model.route.tangent(model.gate_distances[i]))
		g.visible = false
		entry["root"].add_child(g)
		gates.append(g)
	entry["gates"] = gates
	var front := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(34.0, 5.0, 3.0)
	front.mesh = box
	front.material_override = Palette.water(Palette.VERDIGRIS.lerp(Palette.ARC, 0.5))
	front.visible = false
	entry["root"].add_child(front)
	entry["front"] = front


func _build_relay(entry: Dictionary, model) -> void:
	var foot := _ground(model.relay)
	var coil_mat := Palette.solid(Palette.ARC, 0.3)
	entry["coil_mat"] = coil_mat
	if ResourceLoader.exists(RELAY_MAST):
		var dressed := (load(RELAY_MAST) as PackedScene).instantiate() as Node3D
		var glow := dressed.find_child("CoilGlow", true, false) as MeshInstance3D
		if glow != null:
			glow.material_override = coil_mat
			dressed.position = foot
			entry["root"].add_child(dressed)
			return
		dressed.free()
	var mast := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 1.2
	cyl.height = 16.0
	mast.mesh = cyl
	mast.material_override = Palette.solid(Palette.COPPER)
	mast.position = foot + Vector3.UP * 8.0
	entry["root"].add_child(mast)
	var coil := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.2
	sphere.height = 4.4
	coil.mesh = sphere
	coil.material_override = coil_mat
	coil.position = foot + Vector3.UP * 17.0
	entry["root"].add_child(coil)


func _build_hauler(entry: Dictionary) -> void:
	var hauler := Node3D.new()
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.2, 2.4, 5.4)
	body.mesh = box
	body.material_override = Palette.striped(Palette.COPPER, Palette.RUST)
	hauler.add_child(body)
	var lamp := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.7
	bulb.height = 1.4
	lamp.mesh = bulb
	lamp.material_override = Palette.solid(Palette.AMBER, 3.0)
	lamp.position = Vector3(0.0, 1.8, 0.0)
	hauler.add_child(lamp)
	hauler.visible = false
	entry["root"].add_child(hauler)
	entry["hauler"] = hauler


static func gate_ring(ground: Vector3, along: Vector2) -> MeshInstance3D:
	var g := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = GATE_RADIUS - 0.5
	torus.outer_radius = GATE_RADIUS
	g.mesh = torus
	g.material_override = Palette.solid(Palette.SAND, 0.6)
	g.position = ground + Vector3.UP * (GATE_RADIUS - 1.0)
	g.basis = Basis.looking_at(Vector3(along.x, 0.0, along.y), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	return g


static func _pillar(color: Color) -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.9
	cyl.height = BEAM_HEIGHT
	beam.mesh = cyl
	beam.material_override = Palette.unshaded(Color(color.r, color.g, color.b, PILLAR_ALPHA))
	beam.add_to_group("sky_pillar")
	return beam


func show_arrivals(arrivals: Array) -> void:
	while _arrival_rings.size() < arrivals.size():
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = ARRIVAL_RADIUS - 0.5
		torus.outer_radius = ARRIVAL_RADIUS
		ring.mesh = torus
		ring.material_override = Palette.solid(EventKinds.color("enemy_spawned"), 2.0)
		add_child(ring)
		_arrival_rings.append(ring)
	for i in _arrival_rings.size():
		var ring: MeshInstance3D = _arrival_rings[i]
		ring.visible = i < arrivals.size()
		if ring.visible:
			var at: Vector2 = arrivals[i]["at"]
			var left: float = arrivals[i]["left"]
			ring.position = _ground(at) + Vector3.UP * 0.3
			ring.scale = Vector3.ONE * lerpf(0.4, 1.0, clampf(left, 0.0, 1.0))


func set_vault(at: Vector3, standing: bool, plating := -1.0) -> void:
	_vault_pillar.visible = standing
	_vault_pillar.position = at + Vector3.UP * BEAM_HEIGHT * 0.5
	_vault_anchor.position = at + Vector3.UP * 3.0
	vault_prompt.text = vault_text(plating) if standing else ""


static func vault_text(plating: float) -> String:
	var guard := " (plating %d)" % int(plating) if plating >= 0.0 else ""
	return "Vault: rare part + bonus core" + guard


func _process(_delta: float) -> void:
	if director == null:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	var beam_shown := false
	for entry in _offer_nodes:
		_update_offer(entry, pulse)
		var phase: int = entry["offer"]["phase"]
		var open := phase == EventDirector.ANNOUNCED or phase == EventDirector.ARMED
		entry["beam"].visible = open and not beam_shown
		beam_shown = beam_shown or open
		_fade(entry["beam"])
	_fade(_vault_pillar)
	_update_squall()


func _fade(beam: MeshInstance3D) -> void:
	if not beam.visible or player == null:
		return
	var d := _flat_to(beam, player.ball_position())
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		d = minf(d, _flat_to(beam, cam.global_position))
	var mat: StandardMaterial3D = beam.material_override
	mat.albedo_color.a = PILLAR_ALPHA * smoothstep(PILLAR_FADE.x, PILLAR_FADE.y, d)


static func _flat_to(beam: Node3D, point: Vector3) -> float:
	return Vector2(point.x - beam.global_position.x, point.z - beam.global_position.z).length()


func _update_offer(entry: Dictionary, pulse: float) -> void:
	var offer: Dictionary = entry["offer"]
	var model = offer["model"]
	var phase: int = offer["phase"]
	var shown := phase == EventDirector.ANNOUNCED or phase == EventDirector.ARMED or phase == EventDirector.LIVE
	entry["root"].visible = shown
	if not shown:
		return
	var armed := phase == EventDirector.ARMED
	entry["ring_mat"].emission_energy_multiplier = FlashGuard.spike(0.4, 0.4 + (pulse * 2.4 if armed else 0.0))
	entry["sign"].visible = phase != EventDirector.LIVE
	var status: Label3D = entry["status"]
	status.visible = phase == EventDirector.LIVE
	if phase == EventDirector.LIVE:
		status.text = model.status()
	match offer["id"]:
		"surge_run":
			_update_surge(entry, model, phase == EventDirector.LIVE, pulse)
		"hold_the_relay":
			entry["coil_mat"].emission_energy_multiplier = FlashGuard.spike(0.3 + model.progress() * 2.4, 0.3 + model.progress() * 4.0 * (0.6 + 0.4 * pulse))
			status.position = _ground(model.relay) + Vector3.UP * 22.0
		"scrap_stampede":
			var hauler: Node3D = entry["hauler"]
			hauler.visible = phase == EventDirector.LIVE
			if hauler.visible:
				var at: Vector3 = model.hauler_position()
				var t: Vector2 = model.route.tangent(model.hauler)
				hauler.position = at
				hauler.basis = Basis.looking_at(Vector3(t.x, 0.0, t.y), Vector3.UP)
				status.position = at + Vector3.UP * 5.0


func _update_surge(entry: Dictionary, model, live: bool, pulse: float) -> void:
	var gates: Array = entry["gates"]
	for i in gates.size():
		var g: MeshInstance3D = gates[i]
		g.visible = live and i >= model.next_gate
		if g.visible:
			var next: bool = i == model.next_gate
			var mat: StandardMaterial3D = g.material_override
			mat.albedo_color = EventKinds.color("event_started") if next else Palette.SAND
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = FlashGuard.spike(1.2, 1.2 + pulse * 2.0) if next else 0.4
	var front: MeshInstance3D = entry["front"]
	front.visible = live and model.front > 0.0
	if front.visible:
		var p: Vector2 = model.front_point()
		var t: Vector2 = model.front_tangent()
		front.position = _ground(p) + Vector3.UP * 2.0
		front.basis = Basis.looking_at(Vector3(t.x, 0.0, t.y), Vector3.UP)
	if live and model.next_gate < model.gates.size():
		entry["status"].position = _ground(model.gates[model.next_gate]) + Vector3.UP * (GATE_RADIUS * 2.0 + 1.5)


func _update_squall() -> void:
	var squall = director.squall
	if squall == null:
		_dust_wall.visible = false
		return
	var warn: float = director.squall_warning()
	var intensity: float = squall.intensity()
	_dust_wall.visible = warn > 0.0
	if _dust_wall.visible:
		var cam := get_viewport().get_camera_3d()
		var centre := cam.global_position if cam != null else Vector3.ZERO
		var upwind := Vector3(-squall.wind.x, 0.0, -squall.wind.y)
		_dust_wall.position = Vector3(centre.x, 20.0, centre.z) + upwind * lerpf(190.0, 40.0, warn)
		_dust_wall.basis = Basis.looking_at(-upwind, Vector3.UP)
	_apply_fog(intensity)


func _apply_fog(intensity: float) -> void:
	var env: Environment = terrain.environment if terrain != null else null
	if env == null:
		return
	var squall = director.squall if director != null else null
	env.fog_density = squall.fog_density(_base_fog) if squall != null else _base_fog
	env.fog_light_color = _base_fog_color.lerp(FOG_COLOR, intensity)


func _ground(at: Vector2) -> Vector3:
	return terrain.drop_point(at.x, at.y, 0.0)


static func _label(text: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Palette.CHARCOAL
	label.outline_size = 12
	label.font_size = 56
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
