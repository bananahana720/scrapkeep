extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")
const Rows := preload("res://src/presentation/rows.gd")
const CodexStyle := preload("res://src/presentation/codex_style.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const Augments := preload("res://src/movement/augments.gd")
const EdgeFlash := preload("res://src/presentation/edge_flash.gd")
const Interactables := preload("res://src/world/interactables.gd")
const Palette := preload("res://src/core/palette.gd")
const Density := preload("res://src/presentation/density.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Synergies := preload("res://src/build/synergies.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")
const KillMark := preload("res://src/presentation/kill_mark.gd")
const HeroFx := preload("res://src/presentation/hero_fx.gd")
const PopGate := preload("res://src/presentation/pop_gate.gd")
const DensityGovernor := preload("res://src/presentation/density_governor.gd")


const POOL := 48
const GLYPH_PRIORITY := -2
const TRAIL_PRIORITY := -4
const GLYPH_SHADER := preload("res://assets/shaders/fx_glyph.gdshader")
const INK_SHAPES := ["burst", "star", "cross", "arc"]
const POP_SHAPES := ["flash", "star", "burst"]
const SPARKLE_POOL := 6
const SPARKLE_MAX := 20
const SPARKLE_CEILING := SPARKLE_POOL * SPARKLE_MAX
const TRAIL_SECONDS := [0.0, 0.12, 0.22, 0.36]
const TRAIL_WIDTH := [0.0, 0.28, 0.48, 0.72]
const TRAIL_NEAR := Vector2(0.4, 0.8)
const LINES_PER_TIER := [0, 0, 10, 20]
const BURSTS := {
	"debris": {"pool": 6, "max": 12, "life": 0.7, "speed": [4.0, 9.0], "spread": 55.0, "gravity": -26.0, "size": Vector3.ONE * 0.24},
	"dust": {"pool": 4, "max": 14, "life": 0.5, "speed": [2.0, 5.0], "spread": 85.0, "gravity": 1.5, "size": Vector3.ONE * 0.4, "soft": true},
	"fountain": {"pool": 3, "max": 24, "life": 0.9, "speed": [6.0, 10.0], "spread": 22.0, "gravity": -18.0, "size": Vector3.ONE * 0.18},
}
const BURST_LOOKS := {"debris": "chunk", "dust": "puff", "fountain": "bead"}
const PIPS := 8
const PIP_RADIUS := 0.9
const PIP_HEIGHT := 2.5
const KILL_MARK_M := 3.0
const SHOCKWAVE_MIN_SPEED := 14.0
const SHOCKWAVE_FULL_SPEED := 36.0
const FUSION_SIGNATURES := {
	"arc+frost": {"style": 0, "primary": Palette.ICE, "accent": Palette.ARC, "shapes": ["diamond", "ring"],
		"burst": "dust", "burst_count": 10, "fx": ["spark_core", "spark_halo"], "life": 0.42},
	"arc+kinetic": {"style": 1, "primary": Palette.COBALT, "accent": Palette.BRASS, "shapes": ["burst", "bolt"],
		"burst": "debris", "burst_count": 10, "fx": ["crit_core", "crit_halo"], "life": 0.38},
	"frost+kinetic": {"style": 2, "primary": Palette.ANCIENT, "accent": Palette.COPPER, "shapes": ["star", "square"],
		"burst": "debris", "burst_count": 10, "fx": ["spark_core"], "life": 0.48},
	"frost+heat": {"style": 3, "primary": Palette.SODIUM, "accent": Palette.ICE, "shapes": ["star", "wave"],
		"burst": "dust", "burst_count": 12, "fx": ["crit_core", "crit_halo"], "life": 0.42},
	"arc+heat": {"style": 4, "primary": Palette.DAWN_VIOLET, "accent": Palette.APRICOT, "shapes": ["wave", "bolt"],
		"burst": "fountain", "burst_count": 14, "fx": ["spark_core", "spark_halo"], "life": 0.46},
	"heat+kinetic": {"style": 5, "primary": Palette.AMBER, "accent": Palette.COPPER, "shapes": ["burst", "ring"],
		"burst": "debris", "burst_count": 12, "fx": ["crit_core", "crit_halo"], "life": 0.44},
}

var ctx
var player
var camera
var root: Node3D
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
var _rings := {}
var _heft_class := 1
var _found_wired := false
var _fusion_wired := false
var _bursts := {}
var _burst_next := {}
var _fx := FxLibrary.Pools.new()
var _roll: GPUParticles3D
var _pips: Array = []
var _pip_mat: Material
var _chain := 0
var _chain_rung := 0
var _pip_pop := 0.0
var edge: Control
var might := 0.0
const MIGHT_GLYPH := 0.15
var heat := 0.0
const HEAT_GLYPH := Color(1.0, 0.5, 0.12)
var trails := true
var pops := PopGate.new()
var kill_mark: KillMark
var hero_fx: HeroFx
var _density := DensityGovernor.new()


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Vfx"
	player = ctx.player
	camera = ctx.camera
	_rng.seed = 7
	root = Node3D.new()
	root.name = "PresentationFx"
	ctx.root.add_child(root)
	_build_glyphs()
	hero_fx = HeroFx.new()
	root.add_child(hero_fx)
	hero_fx.setup()
	for i in SPARKLE_POOL:
		_sparkles.append(_make_sparkle())
	_build_bursts()
	_build_fx()
	_build_pips()
	var layer := CanvasLayer.new()
	layer.name = "EdgeFlashLayer"
	layer.layer = 4
	add_child(layer)
	edge = EdgeFlash.new()
	layer.add_child(edge)
	_build_trail()
	var events = ctx.events
	events.landed.connect(_on_landed)
	events.slammed.connect(_on_slammed)
	events.mounted.connect(_on_mounted)
	events.dismounted.connect(_on_dismounted)
	events.grapple_fired.connect(func(anchor: Vector3): glyph("grapple_fired", anchor, 0.25, 0.7, 0.25, Vector3.ZERO, "", player.class_color()))
	events.harpoon_bit.connect(func(_enemy: Node3D, at: Vector3):
		glyph("harpoon_bit", at, 0.3, 1.0, 0.3, Vector3.ZERO, "", player.class_color())
		play_fx("harpoon_bit", at, player.class_color(), "", player.shown_position() - at))
	events.harpoon_smashed.connect(func(_enemy: Node3D, at: Vector3, speed: float):
		glyph("harpoon_smashed", at, 0.6, 2.0 + speed * 0.05, 0.4, Vector3.ZERO, "", player.class_color())
		if speed >= SHOCKWAVE_MIN_SPEED:
			impact_shockwave(at, speed, Vector3.UP, player.class_color(), "dunk_shockwave"))
	events.shot_fired.connect(_on_shot)
	events.enemy_struck.connect(_on_struck)
	events.scrap_collected.connect(_on_scrap)
	events.part_gained.connect(func(_id: String, _source: String): glyph("part_gained", player.shown_position() + Vector3.UP * 2.2, 0.4, 1.1, 0.5))
	events.milestone_won.connect(func(_id: String): glyph("milestone_won", player.shown_position() + Vector3.UP * 2.5, 0.5, 1.6, 0.7))
	events.launched.connect(func(v: Vector3):
		_launch_boost = 1.2
		glyph("launched", player.shown_position(), 1.0, 4.0, 0.35, v))
	events.stage_entered.connect(func(_stage: int, _retry: bool): clear())
	if events.has_signal("stage_content_cleared"):
		events.stage_content_cleared.connect(func(_reason: String): clear())
	events.run_started.connect(func(_class_id: String): clear_rings())
	wire_optional()


func wire_optional() -> void:
	var events = ctx.events
	SignalWire.listen(events, "beacon_unsealed", _on_unsealed)
	SignalWire.listen(events, "heft_class_changed", _on_heft_class)
	SignalWire.listen(events, "world_fact", _on_world_fact_fx)
	SignalWire.listen(events, "stage_entered", func(_stage: int, _retry: bool): stop_embers())
	SignalWire.listen(events, "stage_content_cleared", func(_reason: String): stop_embers())
	SignalWire.listen(events, "heft_class_dropped", _on_heft_class)
	SignalWire.listen(events, "scrap_lost", _on_scrap_lost)
	SignalWire.listen(events, "strike_deflected", _on_deflected)
	SignalWire.listen(events, "core_gained", _on_core)
	SignalWire.listen(events, "synergy_discovered", _on_synergy)
	SignalWire.listen(events, "cause_armed", _on_cause_armed)
	SignalWire.listen(events, "cause_fired", _on_cause_fired)
	SignalWire.listen(events, "element_resolved", _on_element)
	SignalWire.listen(events, "interact_armed", _on_interact_armed)
	SignalWire.listen(events, "interact_fired", _on_interact_fired)
	SignalWire.listen(events, "ambush_ended", _on_ambush_ended)
	SignalWire.listen(events, "bet_resolved", _on_bet_resolved)
	if events.has_signal("interaction_found") and not _found_wired:
		_found_wired = true
		var argc := SignalWire.arg_count(events, "interaction_found")
		events.connect("interaction_found", _on_found.unbind(argc) if argc > 0 else _on_found)
	var build_node = ctx.get("build") if ctx != null else null
	var field = build_node.get("field") if build_node != null else null
	if field != null and not _fusion_wired:
		_fusion_wired = true
		SignalWire.listen(field, "fused", _on_fusion_result)
		SignalWire.listen(field, "extended_fused", _on_fusion_result)


func _on_interact_armed(family: String, _id: String, at: Vector3) -> void:
	var row := Interactables.row(family)
	glyph("interact_armed", at + Vector3.UP * 2.0, 0.4, 1.2, 0.3, Vector3.ZERO, String(row["shape"]), row["color"])


func _on_interact_fired(family: String, _id: String, at: Vector3) -> void:
	var row := Interactables.row(family)
	glyph("interact_fired", at + Vector3.UP * 2.0, 0.6, 2.4, 0.45, Vector3.ZERO, String(row["shape"]), row["color"])


func _on_ambush_ended(_id: String, won: bool, at: Vector3) -> void:
	glyph("ambush_ended", at + Vector3.UP * 3.0, 0.6, 2.2 if won else 1.2, 0.5, Vector3.ZERO, "star" if won else "cross", Interactables.color("fight"))


func _on_bet_resolved(_id: String, won: bool, _stake: int, at: Vector3) -> void:
	glyph("bet_resolved", at + Vector3.UP * 5.0, 0.6, 2.6 if won else 1.0, 0.5, Vector3.ZERO, "star" if won else "cross", Palette.ARC if won else Palette.RUST)


func _on_unsealed(stage: int) -> void:
	var at := player.shown_position() as Vector3
	var radius := 12.0
	if ctx.terrain != null:
		at = ctx.terrain.beacon_point(stage)
	if ctx.flow != null and ctx.flow.has_method("stage_def"):
		radius = float(ctx.flow.stage_def().get("beacon_radius", radius))
	glyph("beacon_unsealed", at + Vector3.UP * 6.0, 1.0, 6.0, 0.6)
	glyph("beacon_unsealed", at + Vector3.UP * 0.3, 2.0, radius, 0.7, Vector3.UP, "ring")


func _on_heft_class(heft_class: int, _heft: float) -> void:
	if heft_class < _heft_class:
		_heft_class = heft_class
		var down: Vector3 = player.state.contact_normal if player.state.grounded else Vector3.UP
		glyph("scrap_lost", player.shown_position() - down * 0.9, 5.0, 1.0, 0.4, down, "ring")
		return
	if heft_class == _heft_class:
		return
	_heft_class = heft_class
	var normal: Vector3 = player.state.contact_normal if player.state.grounded else Vector3.UP
	var at: Vector3 = player.shown_position() - normal * 0.9
	glyph("heft_class_changed", at, 1.2, 7.0, 0.5, normal, "ring")
	glyph("heft_class_changed", at + normal * 0.05, 0.8, 4.5, 0.4, normal, "ring")


func _on_scrap_lost(_amount: int, at: Vector3, _total: int, _cause: String) -> void:
	glyph("scrap_lost", at + Vector3.UP * 0.8, 0.5, 1.4, 0.35)


func _on_deflected(enemy: Node3D, _kind: String, _punch: float, _plating: float) -> void:
	if is_instance_valid(enemy) and enemy.is_inside_tree():
		var row := EventKinds.state_row("glancing")
		glyph("strike_deflected", enemy.global_position + Vector3.UP * 0.6, 0.35, 0.7, 0.15, Vector3.ZERO,
			String(row["shape"]), EventKinds.state_color("glancing"))


func _on_core(_source: String, at: Vector3, _count: int) -> void:
	glyph("core_gained", at + Vector3.UP * 1.2, 0.5, 1.6, 0.5)
	glyph("core_gained", at + Vector3.UP * 0.2, 0.6, 3.0, 0.45, Vector3.UP, "ring")


func _on_synergy(id: String, category: String, _first_time: bool) -> void:
	add_ring(id, CodexStyle.category_color(category))


const ARMED_SECONDS := 0.6


func _on_cause_armed(id: String) -> void:
	var shapes: Array = EventKinds.cause_glyphs(Synergies.ROWS[id]["tags"]) if Synergies.ROWS.has(id) else []
	if shapes.is_empty() or EventKinds.cause_row(id).is_empty():
		return
	var tint := EventKinds.cause_color(id)
	var side := Vector3.RIGHT
	if camera != null and camera.cam != null:
		side = camera.cam.global_basis.x
	var top: Vector3 = player.shown_position() + Vector3.UP * 2.4
	glyph("cause_armed", top - side * 0.8, 0.7, 0.8, ARMED_SECONDS, Vector3.ZERO, shapes[0], tint, "P4")
	glyph("cause_armed", top + side * 0.8, 0.7, 0.8, ARMED_SECONDS, Vector3.ZERO, shapes[1], tint, "P4")
	glyph("cause_armed", top, 0.2, 1.2, ARMED_SECONDS, side, "bar", tint, "P4")


func _on_cause_fired(id: String, target: Node3D, at: Vector3) -> void:
	var shape := String(EventKinds.cause_row(id).get("shape", ""))
	if shape == "":
		return
	var where := at
	if target != null and is_instance_valid(target):
		where = target.global_position + Vector3.UP * 0.8
	glyph("cause_fired", where, 0.8, 3.2, 0.45, Vector3.ZERO, shape, EventKinds.cause_color(id), "P4")


func _on_found() -> void:
	glyph("interaction_found", player.shown_position() + Vector3.UP * 2.0, 0.3, 0.9, 0.4)


func _on_element(_element: String, _material: String, behaviour: String, at: Vector3) -> void:
	if behaviour == "steam_cloud":
		glyph("element_resolved", at + Vector3.UP * 0.6, 0.8, 2.8, 0.42, Vector3.UP, "wave", Palette.LEDGER_CREAM)
		burst("dust", at + Vector3.UP * 0.4, Palette.LEDGER_CREAM, 10)
		return
	if behaviour == "flash_melt":
		glyph("element_resolved", at + Vector3.UP * 0.6, 0.7, 3.2, 0.36, Vector3.ZERO, "star", Palette.SODIUM)
		impact_shockwave(at + Vector3.UP * 0.2, 24.0, Vector3.UP, Palette.SODIUM, "shatter_shockwave")
		return
	var sound := Rows.element_sound(behaviour)
	var shape: String = {"ice_form": "diamond", "zap_hum": "burst", "shatter": "star"}.get(sound, "burst")
	glyph("element_resolved", at + Vector3.UP * 0.5, 0.4, 1.5, 0.3, Vector3.ZERO, shape)
	if sound == "shatter":
		impact_shockwave(at + Vector3.UP * 0.2, 22.0, Vector3.UP, Palette.ICE, "shatter_shockwave")


static func fusion_key(raw: String) -> String:
	var pair := raw.split("+")
	if pair.size() != 2:
		return raw
	return "%s+%s" % [pair[0], pair[1]] if pair[0] < pair[1] else "%s+%s" % [pair[1], pair[0]]


static func fusion_signature(key: String) -> Dictionary:
	return FUSION_SIGNATURES.get(fusion_key(key), {})


func _on_fusion_result(result: Dictionary) -> void:
	var key := String(result.get("key", ""))
	if key == "":
		return
	var at: Vector3 = result.get("at", Vector3.ZERO)
	var radius := float(result.get("radius", 4.5))
	play_fusion(key, at, radius)


func play_fusion(key: String, at: Vector3, radius := 4.5) -> Dictionary:
	var canonical := fusion_key(key)
	var sig := fusion_signature(canonical)
	if sig.is_empty() or root == null or not root.is_inside_tree():
		return {}
	var primary: Color = sig["primary"]
	var accent: Color = sig["accent"]
	var shapes: Array = sig["shapes"]
	var life := float(sig["life"])
	var scale_m := clampf(radius * 0.72, 2.4, 5.2) * (1.0 + MIGHT_GLYPH * might)
	var governed := Density.live().apply("P4", 1.0, 1.0, 1.0)
	if kill_mark != null:
		kill_mark.fusion_burst(at + Vector3.UP * 0.9, scale_m, primary, accent, int(sig["style"]), governed)
	glyph("fusion_glyph", at + Vector3.UP * 0.7, 0.8, maxf(2.4, radius * 0.7), life, Vector3.ZERO, String(shapes[0]), primary, "P4")
	glyph("fusion_glyph", at + Vector3.UP * 0.22, 0.9, maxf(2.8, radius), life * 0.92, Vector3.UP, String(shapes[1]), accent, "P4")
	burst(String(sig["burst"]), at + Vector3.UP * 0.5, accent if String(sig["burst"]) != "debris" else Palette.CHARCOAL, int(sig["burst_count"]))
	for fx_id in sig["fx"]:
		if _fx.has(String(fx_id)):
			_fire_fx(String(fx_id), "enemy_struck", 16, at + Vector3.UP * 0.6, primary)
	spawned["fusion_" + canonical] = int(spawned.get("fusion_" + canonical, 0)) + 1
	return sig


func impact_shockwave(at: Vector3, speed: float, normal := Vector3.UP, tint := Color.TRANSPARENT, kind := "dunk_shockwave") -> Dictionary:
	if root == null or not root.is_inside_tree():
		return {}
	var intensity := clampf((speed - SHOCKWAVE_MIN_SPEED) / (SHOCKWAVE_FULL_SPEED - SHOCKWAVE_MIN_SPEED), 0.25, 1.0)
	var primary: Color = tint if tint.a > 0.0 else (player.class_color() if player != null and player.has_method("class_color") else Palette.AMBER)
	var accent := Palette.LEDGER_CREAM
	var axis := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	var radius := lerpf(2.8, 5.4, intensity) * (1.0 + MIGHT_GLYPH * might)
	var governed := Density.live().apply(Density.class_of_kind("slammed"), 1.0, 1.0, 1.0)
	if kill_mark != null:
		kill_mark.shockwave(at + axis * 0.25, radius, primary, accent, governed)
	glyph("shockwave_glyph", at + axis * 0.14, 0.9, radius * 1.15, lerpf(0.24, 0.36, intensity), axis, "ring", primary)
	glyph("shockwave_glyph", at + axis * 0.65, 0.5, radius * 0.65, lerpf(0.18, 0.28, intensity), Vector3.ZERO, "star", accent)
	burst("dust", at + axis * 0.2, Palette.SANDSTONE, int(round(lerpf(6.0, 12.0, intensity))))
	if intensity >= 0.55:
		burst("debris", at + axis * 0.35, Palette.CHARCOAL, int(round(lerpf(6.0, 10.0, intensity))))
	spawned[kind] = int(spawned.get(kind, 0)) + 1
	return {"kind": kind, "intensity": intensity, "radius": radius, "color": primary, "accent": accent}


const MAX_RINGS := 4
const RING_ALPHA := 0.8
const RING_REST := 0.3
const RING_READ := 2.5
const RING_SETTLE := 1.0


func add_ring(id: String, tint: Color) -> void:
	if _rings.has(id) or _rings.size() >= MAX_RINGS:
		return
	var ring := ring_view(_rings.size(), tint)
	player.juice_node().add_child(ring)
	_rings[id] = {"node": ring, "tilt": 0.5 + 0.35 * _rings.size(), "speed": 1.4 + 0.5 * _rings.size(), "born": _clock}


static func ring_alpha(age: float) -> float:
	return lerpf(RING_ALPHA, RING_ALPHA * RING_REST, smoothstep(RING_READ, RING_READ + RING_SETTLE, age))


static func ring_view(index: int, tint: Color) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.32 + 0.12 * index
	torus.outer_radius = torus.inner_radius + 0.05
	torus.rings = 48
	torus.ring_segments = 4
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(tint.r, tint.g, tint.b, RING_ALPHA)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.name = "SynergyRing"
	return ring


func ring_count() -> int:
	return _rings.size()


func clear_rings() -> void:
	for entry in _rings.values():
		if is_instance_valid(entry["node"]):
			entry["node"].queue_free()
	_rings.clear()


func clear() -> void:
	for g in _glyphs:
		g["t"] = 1.0
		g["node"].visible = false
	for kind in _bursts:
		for p in _bursts[kind]:
			p.emitting = false
	_chain = 0
	_chain_rung = 0
	_pip_pop = 0.0
	if kill_mark != null:
		kill_mark.clear()
	if hero_fx != null:
		hero_fx.clear()
	_trail_points.clear()
	_streaks.clear()
	pops.clear()
	Density.live().reset()
	_density.reset()
	if ctx != null and ctx.run != null and ctx.run.has_method("heft_class"):
		_heft_class = int(ctx.run.heft_class())


func _build_glyphs() -> void:
	_build_meshes()
	for i in POOL:
		var glyph := MeshInstance3D.new()
		var mat := ShaderMaterial.new()
		mat.shader = GLYPH_SHADER
		mat.render_priority = GLYPH_PRIORITY
		mat.set_shader_parameter("ink_colour", Palette.CHARCOAL)
		mat.set_shader_parameter("tint", Color.WHITE)
		mat.set_shader_parameter("alpha", 0.0)
		mat.set_shader_parameter("heat", 0.0)
		mat.set_shader_parameter("mode", 0)
		glyph.material_override = mat
		glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glyph.visible = false
		root.add_child(glyph)
		_glyphs.append({"node": glyph, "mat": mat, "t": 1.0, "life": 1.0, "from": 1.0, "to": 1.0, "color": Color.WHITE})
	kill_mark = KillMark.new()
	root.add_child(kill_mark)


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
	var core := SphereMesh.new()
	core.radius = 0.4
	core.height = 0.8
	core.radial_segments = 4
	core.rings = 2
	_meshes["core"] = core
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
	_meshes["disc"] = dot
	var bolt := BoxMesh.new()
	bolt.size = Vector3(0.14, 0.9, 0.14)
	_meshes["bolt"] = bolt
	_meshes["none"] = dot
	_meshes["arc"] = _arc_mesh()


static func _arc_mesh() -> ArrayMesh:
	const WIDTH := 0.08
	var points := [Vector3.ZERO, Vector3(0.12, 0.05, -0.33), Vector3(-0.1, -0.04, -0.66), Vector3(0.0, 0.0, -1.0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for across in [Vector3.RIGHT * WIDTH * 0.5, Vector3.UP * WIDTH * 0.5]:
		for i in 3:
			var a: Vector3 = points[i]
			var b: Vector3 = points[i + 1]
			var v0 := float(i) / 3.0
			var v1 := float(i + 1) / 3.0
			var verts := [a - across, b - across, b + across, a - across, b + across, a + across]
			var uvs := [Vector2(0.0, v0), Vector2(0.0, v1), Vector2(1.0, v1), Vector2(0.0, v0), Vector2(1.0, v1), Vector2(1.0, v0)]
			for k in 6:
				st.set_uv(uvs[k])
				st.add_vertex(verts[k])
	return st.commit()


static func _star_mesh(spokes: int, thickness: float, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in spokes:
		var angle := PI * i / spokes
		var along := Vector3(cos(angle), sin(angle), 0.0) * length
		var across := Vector3(-sin(angle), cos(angle), 0.0) * (thickness * 1.35)
		var a := -along - across
		var b := along - across
		var c := along + across
		var d := -along + across
		var verts := [a, b, c, a, c, d]
		var uvs := [Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0)]
		for k in 6:
			st.set_uv(uvs[k])
			st.add_vertex(verts[k])
	return st.commit()


func glyph(kind: String, at: Vector3, size_from: float, size_to: float, life: float, facing := Vector3.ZERO, shape := "",
		color_override := Color(0, 0, 0, 0), priority_class := "") -> Dictionary:
	if root == null or not root.is_inside_tree():
		return {}
	var governed := Density.live().apply(priority_class if priority_class != "" else Density.class_of_kind(kind), 0.9, 1.0, life)
	size_from *= governed.y
	size_to *= governed.y
	life = governed.z
	var silhouette: String = shape if shape != "" else Rows.shape(kind)
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
	slot["color"] = color_override if color_override.a > 0.0 else Rows.color(kind)
	slot["t"] = 0.0
	slot["life"] = maxf(0.05, life)
	slot["from"] = size_from
	slot["to"] = size_to
	slot["spin"] = 3.0 if silhouette in ["star", "burst", "diamond", "square", "core"] else 0.0
	var pop: bool = silhouette in POP_SHAPES or not _meshes.has(silhouette)
	slot["alpha"] = FlashGuard.alpha(governed.x) if pop else FlashGuard.info(governed.x)
	slot["ink_mode"] = 0 if silhouette in INK_SHAPES else 1
	slot["pop"] = pop
	node.visible = true
	spawned[kind] = spawned.get(kind, 0) + 1
	_draw_glyph(slot)
	return slot


func end_glyph(slot: Dictionary, at: Vector3) -> void:
	if slot.is_empty() or slot["t"] >= 1.0 or not slot["node"].global_position.is_equal_approx(at):
		return
	slot["t"] = 1.0
	slot["node"].visible = false


func _facing_basis(silhouette: String, facing: Vector3) -> Basis:
	if facing.length_squared() < 0.0001:
		if silhouette in ["ring", "wave"]:
			return Basis.IDENTITY
		if camera != null and camera.cam != null:
			return camera.cam.global_basis
		return Basis.IDENTITY
	var dir := facing.normalized()
	if silhouette in ["ring", "wave"]:
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
	var alpha: float = (1.0 - t) * float(slot.get("alpha", 0.9))
	var mat = slot["mat"]
	if mat is ShaderMaterial:
		var hot: float = FlashGuard.whiten(0.88) * maxf(0.0, 1.0 - t / 0.65) if slot.get("pop", false) else 0.0
		mat.set_shader_parameter("tint", Color(color.r, color.g, color.b, 1.0))
		mat.set_shader_parameter("alpha", alpha)
		mat.set_shader_parameter("heat", hot)
		mat.set_shader_parameter("mode", int(slot.get("ink_mode", 0)))
	elif mat is StandardMaterial3D:
		mat.albedo_color = Color(color.r, color.g, color.b, alpha)


func _on_landed(impact: float) -> void:
	if impact < 10.0:
		return
	var at: Vector3 = player.shown_position() - player.state.contact_normal * 0.95
	glyph("landed", at, 0.6, 1.2 + impact * 0.06, 0.25, player.state.contact_normal)


func _on_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05:
		return
	glyph("slammed", at + Vector3.UP * 0.15, 1.0, player.slam_radius() if player.has_method("slam_radius") else Augments.SLAM_RADIUS, 0.35, player.state.contact_normal)
	play_fx("slammed", at + Vector3.UP * 0.15)
	if strength >= 0.65:
		impact_shockwave(at + Vector3.UP * 0.2, 16.0 + strength * 18.0, player.state.contact_normal, Palette.AMBER, "slam_shockwave")


func _on_mounted(at: Vector3, _banked: float) -> void:
	var normal: Vector3 = player.kit.mount_normal
	var face: Vector3 = player.kit.mount_face if player.kit.mount_face != Vector3.ZERO else at
	glyph("mounted", face + normal * 0.1, 0.8, Augments.MOUNT_REPEL_RADIUS, 0.3, normal, "ring")


func _on_dismounted(velocity: Vector3) -> void:
	if velocity.length() > 1.0:
		glyph("dismounted", player.shown_position(), 0.8, 1.6, 0.22, velocity)


func _on_shot(_weapon: String, from: Vector3, to: Vector3) -> void:
	var dir := to - from
	glyph("shot_fired", from + dir.normalized() * 0.4, 0.5, 0.9, 0.06, dir, "", player.class_color())
	glyph("shot_fired", to, 0.5, 1.1, 0.09, Vector3.ZERO, "flash", player.class_color())


func _hot(kind: String) -> Color:
	if heat <= 0.0:
		return Color(0, 0, 0, 0)
	var c: Color = Rows.color(kind).lerp(HEAT_GLYPH, heat)
	var k := 1.0 + 0.6 * heat
	return Color(c.r * k, c.g * k, c.b * k, c.a)


func _on_struck(enemy: Node3D, _kind: String, force: float) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var grow := 1.0 + MIGHT_GLYPH * might
	glyph("enemy_struck", enemy.global_position + Vector3.UP * 0.6, 0.4 * grow, clampf(0.8 + force * 0.03, 0.8, 1.6) * grow, 0.14 + 0.08 * might,
		Vector3.ZERO, "", _hot("enemy_struck"))


func _make_sparkle() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	p.amount = clampi(6 + amount * 2, 6, SPARKLE_MAX)
	p.restart()
	p.emitting = true
	spawned["scrap_collected"] = spawned.get("scrap_collected", 0) + 1


func _build_trail() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = TRAIL_PRIORITY
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
	for entry in _rings.values():
		var node: Node3D = entry["node"]
		if is_instance_valid(node):
			node.basis = Basis(Vector3.UP, _clock * entry["speed"]) * Basis(Vector3.RIGHT, entry["tilt"])
			var mat := (node as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null:
				mat.albedo_color.a = ring_alpha(_clock - float(entry["born"]))
	_draw_pips(delta)
	_govern(delta)
	_emit_pops()
	var tier: int = player.speed_tier()
	if _launch_boost > 0.0:
		tier = SpeedTier.BLAZING
	if trails:
		_draw_trail(tier)
		_draw_lines(tier, delta)
	_roll_dust()


static func trail_near(point_m: float, ball_m: float) -> float:
	return smoothstep(ball_m * TRAIL_NEAR.x, ball_m * TRAIL_NEAR.y, point_m)


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
		var fade := (1.0 - float(i) / count) * 0.55 * trail_near(eye.distance_to(p), eye.distance_to(at))
		mesh.surface_set_color(Color(color.r, color.g, color.b, fade))
		mesh.surface_add_vertex(p + side)
		mesh.surface_set_color(Color(color.r, color.g, color.b, fade))
		mesh.surface_add_vertex(p - side)
	mesh.surface_end()


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


func _build_bursts() -> void:
	for kind in BURSTS:
		var spec: Dictionary = BURSTS[kind]
		var look: String = BURST_LOOKS[kind]
		var mesh := FxLibrary.look_mesh(look, spec["size"])
		if mesh is PrimitiveMesh:
			mesh.material = FxLibrary.look_material(look)
		else:
			mesh.surface_set_material(0, FxLibrary.look_material(look))
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(1.0, 0.0 if not spec.get("soft", false) else 0.3))
		var pool: Array = []
		for i in int(spec["pool"]):
			var p := CPUParticles3D.new()
			p.emitting = false
			p.one_shot = true
			p.amount = int(spec["max"])
			p.lifetime = spec["life"]
			p.explosiveness = 1.0
			p.direction = Vector3.UP
			p.spread = spec["spread"]
			p.initial_velocity_min = spec["speed"][0]
			p.initial_velocity_max = spec["speed"][1]
			p.gravity = Vector3(0.0, spec["gravity"], 0.0)
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.2
			p.scale_amount_curve = curve
			p.particle_flag_align_y = spec.get("align", false)
			if look == "puff":
				p.damping_min = 2.0
				p.damping_max = 4.0
			if look != "chunk":
				p.angle_min = 0.0
				p.angle_max = 360.0
			else:
				p.angular_velocity_min = -540.0
				p.angular_velocity_max = 540.0
			p.set_meta("fx_look", look)
			if look == "puff" or look == "bead":
				p.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
			p.mesh = mesh
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.name = "Burst_%s_%d" % [kind, i]
			root.add_child(p)
			pool.append(p)
		_bursts[kind] = pool
		_burst_next[kind] = 0


func burst(kind: String, at: Vector3, color: Color, count: int) -> void:
	if not _bursts.has(kind) or count <= 0 or root == null or not root.is_inside_tree():
		return
	var pool: Array = _bursts[kind]
	var p: CPUParticles3D = pool[_burst_next[kind]]
	_burst_next[kind] = (_burst_next[kind] + 1) % pool.size()
	var amount := mini(count, int(BURSTS[kind]["max"]))
	if p.amount != amount:
		p.amount = amount
	p.global_position = at
	p.color = color
	FxLibrary.set_heat(p)
	p.restart()
	p.emitting = true
	spawned["burst_" + kind] = spawned.get("burst_" + kind, 0) + 1


func _build_fx() -> void:
	_fx = FxLibrary.pools(root, "vfx")
	_roll = _fx.list("roll_dust")[0]
	_roll.set_instance_shader_parameter(FxLibrary.TINT, FxLibrary.colour("roll_dust", "rolling"))


func play_fx(kind: String, at: Vector3, tint := Color.TRANSPARENT, variant := "", toward := Vector3.ZERO) -> void:
	if root == null or not root.is_inside_tree():
		return
	var effects := FxLibrary.effects(kind, variant)
	for id in effects:
		if not _fx.has(id) or FxLibrary.SPECS[id]["attach"] == "ball":
			continue
		_fire_fx(id, kind, int(effects[id]), at, tint, toward)


func _fire_fx(id: String, kind: String, count: int, at: Vector3, tint := Color.TRANSPARENT, toward := Vector3.ZERO) -> void:
	if _fx.fire(id, kind, count, at, tint, toward) != null:
		spawned["fx_" + id] = spawned.get("fx_" + id, 0) + 1


func _on_world_fact_fx(kind: String, at: Vector3) -> void:
	if not FxLibrary.effects(kind).is_empty() and kind != "breach_opened":
		play_fx(kind, at)
	if kind in ["wall_crumbled", "piece_shattered"]:
		impact_shockwave(at, 26.0, Vector3.UP, Palette.COPPER, "shatter_shockwave")


func stop_embers() -> void:
	_fx.stop(["cache_ember", "cache_wisp"])


func _roll_dust() -> void:
	if _roll == null:
		return
	var row := EventJuice.juice("rolling")
	var speed: float = player.planar_velocity().length()
	var floor_speed: float = row["min_speed"]
	var on: bool = player.state.grounded and speed >= floor_speed
	if on:
		_roll.global_position = player.shown_position() - player.state.contact_normal * 0.95
		var rate: float = float(row["fx"]["roll_dust"]) * clampf(speed / (floor_speed * 2.0), 0.4, 1.0)
		_roll.amount_ratio = clampf(rate * _roll.lifetime / float(_roll.amount), 0.0, 1.0)
	if _roll.emitting != on:
		_roll.emitting = on
		if on:
			spawned["fx_roll_dust"] = spawned.get("fx_roll_dust", 0) + 1


func kill_pop(at: Vector3) -> void:
	var governor := Density.live()
	pops.add(_clock, at, governor.coalesce_metres())
	_emit_pops()


func _emit_pops() -> void:
	if pops.pending.is_empty():
		return
	for cluster in pops.ready(_clock, Density.live().coalesce_seconds()):
		kill_look(cluster["at"], cluster["scale"])


func kill_look(at: Vector3, scale: float, pilot := Color.TRANSPARENT) -> void:
	var row := EventJuice.juice("enemy_killed")
	scale *= 1.0 + MIGHT_GLYPH * might
	if root == null or not root.is_inside_tree():
		return
	var tint := (pilot if pilot.a > 0.0 else kill_tint()).lerp(HEAT_GLYPH, heat)
	var cap := float(maxi(1, int(row.get("chain_cap", 7))))
	var punch := clampf(float(_chain_rung) / cap, 0.0, 1.0)
	kill_mark.fire(at + Vector3.UP * 0.8, KILL_MARK_M * scale, tint,
		Density.live().apply(Density.class_of_kind("enemy_killed"), 1.0, 1.0, 1.0), punch)
	var fx := FxLibrary.effects("enemy_killed")
	for id in fx:
		_fire_fx(id, "enemy_killed", int(ceil(float(fx[id]) * scale)), at + Vector3.UP * 0.6, tint)
	burst("debris", at + Vector3.UP * 0.5, Palette.CHARCOAL, int(ceil(float(row["debris"]) * scale)))
	spawned["enemy_killed"] = spawned.get("enemy_killed", 0) + 1


func shift_over_kill(at: Vector3, scale := 1.0, pilot := Color.TRANSPARENT) -> void:
	var row := EventJuice.juice("enemy_killed")
	scale *= 1.0 + MIGHT_GLYPH * might
	if root == null or not root.is_inside_tree():
		return
	var tint := (pilot if pilot.a > 0.0 else kill_tint()).lerp(HEAT_GLYPH, heat)
	kill_mark.shift_over(at + Vector3.UP * 0.85, KILL_MARK_M * scale, tint,
		Density.live().apply(Density.class_of_kind("enemy_killed"), 1.0, 1.0, 1.0))
	var fx := FxLibrary.effects("enemy_killed")
	for id in fx:
		_fire_fx(id, "enemy_killed", int(ceil(float(fx[id]) * scale)), at + Vector3.UP * 0.6, tint)
	burst("debris", at + Vector3.UP * 0.5, Palette.CHARCOAL, int(ceil(float(row["debris"]) * scale)))
	spawned["shift_over"] = int(spawned.get("shift_over", 0)) + 1
	spawned["enemy_killed"] = spawned.get("enemy_killed", 0) + 1


func kill_tint() -> Color:
	return player.class_color() if player != null and player.has_method("class_color") else EventKinds.color("enemy_killed")


func _govern(delta: float) -> void:
	_density.step(delta, _count_density)


func _count_density() -> float:
	var cam: Camera3D = camera.cam if camera != null and camera.get("cam") is Camera3D else null
	var alive := 0
	for g in _glyphs:
		if g["t"] < 1.0:
			alive += 1
	var tree := get_tree()
	return Density.raw(Density.count_in_view(cam, tree.get_nodes_in_group(Threat.GROUP)), alive,
		Density.count_in_view(cam, tree.get_nodes_in_group("enemy")))


static func burst_ceiling() -> int:
	var total := 0
	for kind in BURSTS:
		total += int(BURSTS[kind]["pool"]) * int(BURSTS[kind]["max"])
	return total


func _build_pips() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.22, 0.22)
	var mat := ShaderMaterial.new()
	mat.shader = GLYPH_SHADER
	mat.render_priority = GLYPH_PRIORITY
	mat.set_shader_parameter("ink_colour", Palette.CHARCOAL)
	mat.set_shader_parameter("tint", EventKinds.color("enemy_killed"))
	mat.set_shader_parameter("alpha", 0.96)
	mat.set_shader_parameter("heat", 0.0)
	mat.set_shader_parameter("mode", 1)
	_pip_mat = mat
	mesh.material = _pip_mat
	for i in PIPS:
		var pip := MeshInstance3D.new()
		pip.mesh = mesh
		pip.name = "ChainPip%d" % i
		pip.top_level = true
		pip.visible = false
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pip)
		_pips.append(pip)


func set_chain(length: int, rung: int) -> void:
	var shown := mini(length, PIPS) if length >= 2 else 0
	if shown > chain_pips():
		_pip_pop = 1.0
	_chain = shown
	_chain_rung = rung


func chain_pips() -> int:
	return _chain


func _draw_pips(delta: float) -> void:
	_pip_pop = maxf(0.0, _pip_pop - delta * 5.0)
	var top := float(EventJuice.juice("enemy_killed").get("chain_cap", 7))
	var charge := clampf(_chain_rung / top, 0.0, 1.0)
	var pip_tint := EventKinds.color("enemy_killed").lerp(EventKinds.color("part_gained"), minf(charge * 1.6, 1.0)).lerp(Palette.LEDGER_CREAM, maxf(0.0, charge - 0.7) * 2.0)
	if _pip_mat is ShaderMaterial:
		(_pip_mat as ShaderMaterial).set_shader_parameter("tint", pip_tint)
	elif _pip_mat is StandardMaterial3D:
		(_pip_mat as StandardMaterial3D).albedo_color = pip_tint
	var centre: Vector3 = player.shown_position() + Vector3.UP * PIP_HEIGHT
	var spin_rate := 2.2 + 1.4 * charge
	var orbit_r := PIP_RADIUS + 0.14 * _pip_pop + 0.08 * charge
	var beat := 0.08 * charge * sin(_clock * (6.0 + 4.0 * charge)) if _chain_rung >= 3 else 0.0
	for i in PIPS:
		var pip: MeshInstance3D = _pips[i]
		pip.visible = i < _chain
		if not pip.visible:
			continue
		var angle := _clock * spin_rate + TAU * float(i) / maxf(1.0, _chain)
		var size := 1.0 + (0.8 * _pip_pop if i == _chain - 1 else 0.0) + 0.25 * charge + beat
		pip.global_transform = Transform3D(Basis(Vector3.UP, angle * 2.0).scaled(Vector3.ONE * size),
			centre + Vector3(cos(angle), 0.0, sin(angle)) * orbit_r)


func edge_flash(direction: Vector2, color: Color, strength: float, seconds: float) -> void:
	if edge != null:
		edge.flash(direction, color, strength, seconds)
	spawned["edge_flash"] = spawned.get("edge_flash", 0) + 1
