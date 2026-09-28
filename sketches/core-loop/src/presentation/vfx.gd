extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")
const Rows := preload("res://src/presentation/rows.gd")
const CodexStyle := preload("res://src/presentation/codex_style.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Augments := preload("res://src/movement/augments.gd")
const EdgeFlash := preload("res://src/presentation/edge_flash.gd")
const Interactables := preload("res://src/world/interactables.gd")
const Palette := preload("res://src/core/palette.gd")
const Density := preload("res://src/presentation/density.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

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
# v3 W11 bursts: pooled one-shot CPU particles, one shared mesh and material per kind;
# each burst sets only its emitter's colour, place and count. pool emitters x max count
# is the ceiling a dense fight can hold alive at once (DESIGN-NOTES v3 W11).
#   spark     a hit: thin shards flying out in the hit's colour
#   pop       a kill: a quick round puff
#   debris    a kill or a blast: chunks thrown up under gravity
#   dust      a ram, a rebound or a blast: soft puffs rolling out along the ground
#   fountain  a part or a core: a column that rises and falls around the drop
const BURSTS := {
	"spark": {"pool": 10, "max": 16, "life": 0.28, "speed": [5.0, 11.0], "spread": 180.0, "gravity": -9.0,
		"size": Vector3(0.05, 0.05, 0.24), "align": true},
	"pop": {"pool": 6, "max": 14, "life": 0.32, "speed": [3.0, 7.0], "spread": 180.0, "gravity": -3.0, "size": Vector3.ONE * 0.16},
	"debris": {"pool": 6, "max": 12, "life": 0.7, "speed": [4.0, 9.0], "spread": 55.0, "gravity": -26.0, "size": Vector3.ONE * 0.24},
	"dust": {"pool": 4, "max": 14, "life": 0.5, "speed": [2.0, 5.0], "spread": 85.0, "gravity": 1.5, "size": Vector3.ONE * 0.4, "soft": true},
	"fountain": {"pool": 3, "max": 24, "life": 0.9, "speed": [6.0, 10.0], "spread": 22.0, "gravity": -18.0, "size": Vector3.ONE * 0.18},
}
# The kill chain: a pip per kill in the run over the ball, from 2 up.
const PIPS := 8
const PIP_RADIUS := 0.9
const PIP_HEIGHT := 2.5
# v3 F1a: the P5 kinds this module's glyph() draws (FEEL-READABILITY.md §1.1's P5 row:
# hit sparks, kill pops, slam rings' afterglow, synergy shockwaves). Every other kind
# glyph() draws is a one-off reward or discovery reveal (P4), owned by a later unit and
# left ungoverned here. A dictionary stands in for a set.
const P5_KINDS := {"enemy_struck": true, "shot_fired": true, "slammed": true, "synergy_discovered": true}
# The trail's own first TRAIL_FULL_SECONDS stay at full alpha regardless of density: the
# ball's direction is a read, never candy (§1.2).
const TRAIL_FULL_SECONDS := 0.12

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
var _rings := {}
var _heft_class := 1
var _found_wired := false
var _bursts := {}
var _burst_next := {}
var _pips: Array = []
var _pip_mat: StandardMaterial3D
var _chain := 0
var _chain_rung := 0
var _pip_pop := 0.0
var edge: Control
# v3 F1a: density (FEEL-READABILITY.md §1.2) is one shared scalar (density.gd's static
# Governor, contributed to every frame by this module and bolts.gd), not a private one,
# so the two modules never disagree on what "dense" means (finding 2/9).
var _density := 0.0
# One coalesced "pop" burst in flight: {"at", "time", "count", "color", "particles",
# "size_scale"}, or empty. Every caller of burst("pop", ...) -- currently only juice.gd's
# own per-kill bursts -- routes through this, so a kill chain shares one starburst
# instead of stacking one per kill (finding 1/8).
var _pending_pop := {}
# Recent burst() timestamps by kind, trimmed to the last 5 s, for tests and the notes
# (kill_pops_per_250ms, §1.2).
var _burst_log := {}
# The shared union mark (threat_grammar.gd §1.3.1, finding 4): this module samples density
# every frame with tree access already, so it also refreshes and draws the one union layer
# every telegraph/hazard Painter otherwise has no shared place to draw.
var _union_painter


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
	_union_painter = Threat.Painter.new()
	root.add_child(_union_painter)
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
	_build_bursts()
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
	events.grapple_fired.connect(func(anchor: Vector3): glyph("grapple_fired", anchor, 0.25, 0.7, 0.25))
	events.shot_fired.connect(_on_shot)
	events.enemy_struck.connect(_on_struck)
	events.enemy_killed.connect(_on_killed)
	events.scrap_collected.connect(_on_scrap)
	events.part_gained.connect(func(_id: String, _source: String): glyph("part_gained", player.ball_position() + Vector3.UP * 2.2, 0.4, 1.1, 0.5))
	events.milestone_won.connect(func(_id: String): glyph("milestone_won", player.ball_position() + Vector3.UP * 2.5, 0.5, 1.6, 0.7))
	events.launched.connect(func(v: Vector3):
		_launch_boost = 1.2
		glyph("launched", player.ball_position(), 1.0, 4.0, 0.35, v))
	events.stage_entered.connect(func(_stage: int, _retry: bool): clear())
	if events.has_signal("stage_content_cleared"):
		events.stage_content_cleared.connect(func(_reason: String): clear())
	events.run_started.connect(func(_class_id: String): clear_rings())
	wire_optional()


func wire_optional() -> void:
	var events = ctx.events
	_listen(events, "beacon_unsealed", _on_unsealed)
	_listen(events, "heft_class_changed", _on_heft_class)
	_listen(events, "heft_class_dropped", _on_heft_class)
	_listen(events, "scrap_lost", _on_scrap_lost)
	_listen(events, "strike_deflected", _on_deflected)
	_listen(events, "core_gained", _on_core)
	_listen(events, "synergy_discovered", _on_synergy)
	_listen(events, "element_resolved", _on_element)
	_listen(events, "interact_armed", _on_interact_armed)
	_listen(events, "interact_fired", _on_interact_fired)
	_listen(events, "ambush_ended", _on_ambush_ended)
	_listen(events, "bet_resolved", _on_bet_resolved)
	_listen(events, "lap_bell_rung", _on_lap_bell)
	_listen(events, "lap_ring_passed", _on_lap_ring)
	_listen(events, "lap_completed", _on_lap_notch)
	_listen(events, "warden_stripped", _on_warden_stripped)
	if events.has_signal("interaction_found") and not _found_wired:
		_found_wired = true
		var argc := 0
		for info in events.get_signal_list():
			if info["name"] == "interaction_found":
				argc = (info["args"] as Array).size()
		events.connect("interaction_found", _on_found.unbind(argc) if argc > 0 else _on_found)


# An interactable's consent and act, in its family's shape and colour; a result as a
# star for a win and a cross for a loss.
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


static func _listen(events: Object, signal_name: String, callable: Callable) -> void:
	if events.has_signal(signal_name) and not events.is_connected(signal_name, callable):
		events.connect(signal_name, callable)


# --- Demo-spec facts ----------------------------------------------------------------------

# The Warden breaks: a star flash over the beacon and a ring out to its edge.
func _on_unsealed(stage: int) -> void:
	var at := player.ball_position() as Vector3
	var radius := 12.0
	if ctx.terrain != null:
		at = ctx.terrain.beacon_point(stage)
	if ctx.flow != null and ctx.flow.has_method("stage_def"):
		radius = float(ctx.flow.stage_def().get("beacon_radius", radius))
	glyph("beacon_unsealed", at + Vector3.UP * 6.0, 1.0, 6.0, 0.6)
	glyph("beacon_unsealed", at + Vector3.UP * 0.3, 2.0, radius, 0.7, Vector3.UP, "ring")


# v3 fun lab, laps mode. The bell: a ring out across the Warden's reach, like the break's.
func _on_lap_bell(at: Vector3) -> void:
	glyph("lap_bell_rung", at + Vector3.UP * 0.3, 2.0, 30.0, 0.8, Vector3.UP, "ring")


# A checkpoint: a burst where the ball went through the ring.
func _on_lap_ring(_index: int, _count: int, at: Vector3) -> void:
	glyph("lap_ring_passed", at + Vector3.UP * 5.0, 1.0, 5.0, 0.3)


# The notch: a flash on the beacon's mast, up where its collars stand.
func _on_lap_notch(_lap: int, _required: int, _seconds: float) -> void:
	if ctx.terrain != null and ctx.flow != null:
		glyph("lap_completed", ctx.terrain.beacon_point(ctx.flow.stage()) + Vector3.UP * 12.0, 2.0, 7.0, 0.5, Vector3.ZERO, "star")


# Plating off a Warden: a copper burst on its body.
func _on_warden_stripped(_plating: float, at: Vector3) -> void:
	glyph("warden_stripped", at + Vector3.UP * 2.0, 1.5, 6.0, 0.5)


# A new heft class ripples out from the ball along the ground.
func _on_heft_class(heft_class: int, _heft: float) -> void:
	if heft_class < _heft_class:
		# A class lost: the ring falls inward in the torn-scrap colour.
		_heft_class = heft_class
		var down: Vector3 = player.state.contact_normal if player.state.grounded else Vector3.UP
		glyph("scrap_lost", player.ball_position() - down * 0.9, 5.0, 1.0, 0.4, down, "ring")
		return
	if heft_class == _heft_class:
		return
	_heft_class = heft_class
	var normal: Vector3 = player.state.contact_normal if player.state.grounded else Vector3.UP
	var at: Vector3 = player.ball_position() - normal * 0.9
	glyph("heft_class_changed", at, 1.2, 7.0, 0.5, normal, "ring")
	glyph("heft_class_changed", at + normal * 0.05, 0.8, 4.5, 0.4, normal, "ring")


func _on_scrap_lost(_amount: int, at: Vector3, _total: int, _cause: String) -> void:
	glyph("scrap_lost", at + Vector3.UP * 0.8, 0.5, 1.4, 0.35)


func _on_deflected(enemy: Node3D, _kind: String, _punch: float, _plating: float) -> void:
	if is_instance_valid(enemy) and enemy.is_inside_tree():
		glyph("strike_deflected", enemy.global_position + Vector3.UP * 0.6, 0.35, 0.7, 0.15)


# The core locks in where it was won: a diamond flash and a tight ring.
func _on_core(_source: String, at: Vector3, _count: int) -> void:
	glyph("core_gained", at + Vector3.UP * 1.2, 0.5, 1.6, 0.5)
	glyph("core_gained", at + Vector3.UP * 0.2, 0.6, 3.0, 0.45, Vector3.UP, "ring")


# The discovery: a burst in the category's colour, and a ring that stays on the ball
# for the rest of the run, one per synergy, so your build shows on the ball.
func _on_synergy(id: String, category: String, _first_time: bool) -> void:
	var tint := CodexStyle.category_color(category)
	glyph("synergy_discovered", player.ball_position() + Vector3.UP * 2.4, 0.6, 1.8, 0.7, Vector3.ZERO, "burst", tint)
	glyph("synergy_discovered", player.ball_position(), 1.0, 5.0, 0.5, Vector3.UP, "ring", tint)
	add_ring(id, tint)


func _on_found() -> void:
	glyph("interaction_found", player.ball_position() + Vector3.UP * 2.0, 0.3, 0.9, 0.4)


func _on_element(_element: String, _material: String, behaviour: String, at: Vector3) -> void:
	var sound := Rows.element_sound(behaviour)
	var shape: String = {"ice_form": "diamond", "zap_hum": "burst", "shatter": "star"}.get(sound, "burst")
	glyph("element_resolved", at + Vector3.UP * 0.5, 0.4, 1.5, 0.3, Vector3.ZERO, shape)


const MAX_RINGS := 4


func add_ring(id: String, tint: Color) -> void:
	if _rings.has(id) or _rings.size() >= MAX_RINGS:
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.32 + 0.12 * _rings.size()
	torus.outer_radius = torus.inner_radius + 0.05
	torus.rings = 48
	torus.ring_segments = 4
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.name = "SynergyRing"
	player.juice_node().add_child(ring)
	_rings[id] = {"node": ring, "tilt": 0.5 + 0.35 * _rings.size(), "speed": 1.4 + 0.5 * _rings.size()}


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
	_trail_points.clear()
	_streaks.clear()
	_pending_pop = {}
	if ctx.run.has_method("heft_class"):
		_heft_class = int(ctx.run.heft_class())


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
func glyph(kind: String, at: Vector3, size_from: float, size_to: float, life: float, facing := Vector3.ZERO, shape := "", color_override := Color(0, 0, 0, 0)) -> void:
	if root == null or not root.is_inside_tree():
		return
	# v3 F1a: P5 kinds (hit sparks, slam afterglow, synergy shockwaves) read the density
	# governor's size/lifetime/alpha caps; every other kind here is a P4 reward reveal,
	# out of this unit's write set, and stays exactly as it drew before.
	var governed: bool = P5_KINDS.has(kind)
	if governed and _governed_glyph_count() >= Density.cap("p5_glyphs"):
		# §8: refuse the spawn instead of evicting a P2/P3 shape sharing the pool
		# (finding 3/10 -- p5_glyphs reserves 8 of the 48 slots for those).
		spawned["p5_glyph_refused"] = spawned.get("p5_glyph_refused", 0) + 1
		return
	if kind == "enemy_struck" and _kind_alive_count(kind) >= Density.cap("hit_sparks"):
		spawned["hit_spark_refused"] = spawned.get("hit_spark_refused", 0) + 1
		return
	if governed:
		var size_scale := Density.size_factor(_density)
		size_from *= size_scale
		size_to *= size_scale
		life *= Density.lifetime_factor(_density)
	var silhouette: String = shape if shape != "" else Rows.shape(kind)
	var slot: Dictionary = _find_slot(governed)
	var node: MeshInstance3D = slot["node"]
	node.mesh = _meshes.get(silhouette, _meshes["flash"])
	node.global_position = at
	slot["basis"] = _facing_basis(silhouette, facing)
	var tint: Color = color_override if color_override.a > 0.0 else Rows.color(kind)
	if governed:
		tint = Color(tint.r, tint.g, tint.b, tint.a * Density.alpha_factor(_density))
	slot["color"] = tint
	slot["t"] = 0.0
	slot["life"] = maxf(0.05, life)
	slot["from"] = size_from
	slot["to"] = size_to
	slot["spin"] = 3.0 if silhouette in ["star", "burst", "diamond", "square", "core"] else 0.0
	slot["governed"] = governed
	slot["kind"] = kind
	node.visible = true
	spawned[kind] = spawned.get(kind, 0) + 1
	_draw_glyph(slot)


# §8: p5_glyphs reserves POOL - cap("p5_glyphs") slots (8 of 48) for P2/P3 shapes sharing
# the pool, so a flood of P5 glyphs (hit sparks, kill flashes) can never evict one: a
# governed request only ever evicts another governed slot's oldest. An ungoverned request
# may still take any slot, exactly as before this unit (finding 3/10).
func _find_slot(governed: bool) -> Dictionary:
	for g in _glyphs:
		if g["t"] >= 1.0:
			return g
	var best: Dictionary = {}
	for g in _glyphs:
		if governed and not g.get("governed", false):
			continue
		if best.is_empty() or g["t"] > best["t"]:
			best = g
	return best if not best.is_empty() else _glyphs[0]


func _governed_glyph_count() -> int:
	var count := 0
	for g in _glyphs:
		if g["t"] < 1.0 and g.get("governed", false):
			count += 1
	return count


func _kind_alive_count(k: String) -> int:
	var count := 0
	for g in _glyphs:
		if g["t"] < 1.0 and g.get("kind", "") == k:
			count += 1
	return count


# --- v3 F1a test/notes instrumentation --------------------------------------------------

func governed_glyph_count() -> int:
	return _governed_glyph_count()


func kind_alive_count(k: String) -> int:
	return _kind_alive_count(k)


func burst_count_within(kind: String, ms: float) -> int:
	var log: Array = _burst_log.get(kind, [])
	var cutoff := _clock - ms / 1000.0
	var count := 0
	for t in log:
		if t >= cutoff:
			count += 1
	return count


func _log_burst(kind: String) -> void:
	var log: Array = _burst_log.get(kind, [])
	log.append(_clock)
	var cutoff := _clock - 5.0
	while log.size() > 0 and log[0] < cutoff:
		log.pop_front()
	_burst_log[kind] = log


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


# The kill flash stays as it was. juice.gd (out of this unit's write set) already bursts
# one "pop" per kill on the enemy_killed signal (juice.gd:423-424); this listener used to
# burst a second, independent starburst on top of that, double-counting every kill and
# breaking the "one bigger shape, not many" budget (finding 1/8). It no longer does:
# burst()'s own pop-coalescing (below) is what turns juice's per-kill calls into one
# scaled starburst at high density.
func _on_killed(_kind: String, at: Vector3, _value: int) -> void:
	glyph("enemy_killed", at + Vector3.UP * 0.8, 0.6, 1.8, 0.3)


# --- v3 F1a: the density governor itself -------------------------------------------------

func density() -> float:
	return _density


func _effects_alive() -> int:
	var count := 0
	for g in _glyphs:
		if g["t"] < 1.0:
			count += 1
	for kind in _bursts:
		for p in _bursts[kind]:
			if p.emitting:
				count += 1
	return count


func _update_density(delta: float) -> void:
	# The same camera fetch bolts.gd uses (finding 2/9), not `camera.cam`, so both modules
	# agree on what "in view" means for threats and enemies.
	var camera3d: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() and get_viewport() != null else null
	var threats := 0
	var enemies := 0
	var threat_nodes: Array = []
	if is_inside_tree():
		threat_nodes = get_tree().get_nodes_in_group(Threat.GROUP)
		threats = Density.count_in_view(camera3d, threat_nodes)
		enemies = Density.count_in_view(camera3d, get_tree().get_nodes_in_group("enemy"))
	_density = Density.contribute(delta, threats, _effects_alive(), enemies)
	var in_view_fn := Callable()
	if camera3d != null:
		in_view_fn = func(p: Vector3): return Density.in_view(camera3d, p)
	Threat.refresh_union(threat_nodes, in_view_fn)
	if _union_painter != null:
		_union_painter.paint(Threat.union_marks_now(), Threat.STATIC_LAYERS)


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
	_update_density(delta)
	_maybe_flush_pending_pop()
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
	_draw_pips(delta)
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
	var alpha_factor := Density.alpha_factor(_density)
	for i in count:
		var p: Vector3 = _trail_points[i][0]
		var along: Vector3 = _trail_points[maxi(i - 1, 0)][0] - _trail_points[mini(i + 1, count - 1)][0]
		if along.length_squared() < 0.000001:
			along = Vector3.FORWARD
		var side := along.cross(eye - p).normalized() * width * (1.0 - float(i) / count)
		var fade := (1.0 - float(i) / count) * 0.55
		# The trail's own first TRAIL_FULL_SECONDS ignore the governor: direction is a
		# read, never candy (§1.2).
		var age: float = _clock - float(_trail_points[i][1])
		if age >= TRAIL_FULL_SECONDS:
			fade *= alpha_factor
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
	# Speed lines are P5 (§1.1): density caps their alpha the same way as trail and burst.
	var head_alpha := 0.5 * Density.alpha_factor(_density)
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
		mesh.surface_set_color(Color(color.r, color.g, color.b, head_alpha))
		mesh.surface_add_vertex(head)
		mesh.surface_set_color(Color(color.r, color.g, color.b, 0.0))
		mesh.surface_add_vertex(tail)
	mesh.surface_end()


# --- v3 W11 bursts, the chain and the edge flash ----------------------------------------

func _build_bursts() -> void:
	for kind in BURSTS:
		var spec: Dictionary = BURSTS[kind]
		var mesh: PrimitiveMesh
		if spec.get("soft", false):
			var ball := SphereMesh.new()
			ball.radius = spec["size"].x * 0.5
			ball.height = spec["size"].x
			ball.radial_segments = 6
			ball.rings = 3
			mesh = ball
		else:
			var box := BoxMesh.new()
			box.size = spec["size"]
			mesh = box
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		if spec.get("soft", false):
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
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
			p.mesh = mesh
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.name = "Burst_%s_%d" % [kind, i]
			root.add_child(p)
			pool.append(p)
		_bursts[kind] = pool
		_burst_next[kind] = 0


# One pooled burst: the oldest emitter of its kind restarts here in this colour. Every
# burst kind except "fountain" is P5 (§1.1: hit sparks, kill pops, slam/blast debris and
# dust), so density caps its alpha, size and lifetime (§1.2); size_scale layers the
# coalesced-kill scale (up to 2.5x, §1.2) on top of that cap. "pop" additionally
# coalesces here (finding 1/8): juice.gd's own per-kill vfx.burst("pop", ...) calls are
# the only source of pop bursts, so merging them here, not in a second listener, is what
# turns a kill chain into one scaled starburst instead of one per kill. "fountain" is a
# P4 reward reveal (a part or a core gained), out of this unit's write set in spirit even
# though it shares this pool: the continuous per-frame caps never touch it (finding 11);
# only the "pin_trails_and_fountains" shed step shortens its lifetime, in its turn (§8).
func burst(kind: String, at: Vector3, color: Color, count: int, size_scale := 1.0) -> void:
	if not _bursts.has(kind) or count <= 0 or root == null or not root.is_inside_tree():
		return
	if kind == "pop":
		_queue_pop(at, color, count, size_scale)
		return
	_emit_burst(kind, at, color, count, size_scale)


const FOUNTAIN_SHED_LIFETIME_SCALE := 0.6


func _emit_burst(kind: String, at: Vector3, color: Color, count: int, size_scale := 1.0) -> void:
	var pool: Array = _bursts[kind]
	var p: CPUParticles3D = pool[_burst_next[kind]]
	_burst_next[kind] = (_burst_next[kind] + 1) % pool.size()
	var amount := mini(count, int(BURSTS[kind]["max"]))
	if p.amount != amount:
		p.amount = amount
	if kind == "fountain":
		var shedding := "pin_trails_and_fountains" in Density.active_shed(_density)
		p.scale_amount_min = 0.6 * size_scale
		p.scale_amount_max = 1.2 * size_scale
		p.lifetime = float(BURSTS[kind]["life"]) * (FOUNTAIN_SHED_LIFETIME_SCALE if shedding else 1.0)
		p.color = color
	else:
		var scale := Density.size_factor(_density) * size_scale
		p.scale_amount_min = 0.6 * scale
		p.scale_amount_max = 1.2 * scale
		p.lifetime = float(BURSTS[kind]["life"]) * Density.lifetime_factor(_density)
		p.color = Color(color.r, color.g, color.b, color.a * Density.alpha_factor(_density))
	p.global_position = at
	p.restart()
	p.emitting = true
	spawned["burst_" + kind] = spawned.get("burst_" + kind, 0) + 1
	_log_burst(kind)


# Below density 0.4 every call gets its own starburst immediately, as before this unit.
# Past that, calls within the band's window (time and distance) share one burst, scaled
# by the extra-call count and capped, so a kill chain reads as one bigger shape rather
# than a stack of small ones (§1.5).
func _queue_pop(at: Vector3, color: Color, count: int, size_scale: float) -> void:
	var win := Density.coalesce_window(_density)
	var window_s: float = float(win["ms"]) / 1000.0
	if window_s <= 0.0:
		_flush_pending_pop()
		_emit_burst("pop", at, color, count, size_scale)
		return
	var window_m: float = float(win["metres"])
	if not _pending_pop.is_empty() and _clock - float(_pending_pop["time"]) <= window_s \
			and at.distance_to(_pending_pop["at"]) <= window_m:
		_pending_pop["count"] = int(_pending_pop["count"]) + 1
		_pending_pop["at"] = at
		_pending_pop["time"] = _clock
		_pending_pop["color"] = color
		_pending_pop["particles"] = maxi(int(_pending_pop["particles"]), count)
		return
	_flush_pending_pop()
	_pending_pop = {"at": at, "time": _clock, "count": 1, "color": color, "particles": count, "size_scale": size_scale}


func _flush_pending_pop() -> void:
	if _pending_pop.is_empty():
		return
	var win := Density.coalesce_window(_density)
	var extra: int = maxi(0, int(_pending_pop["count"]) - 1)
	var scale: float = clampf(1.0 + float(win["scale_per_extra"]) * extra, 1.0, float(win["scale_cap"]))
	_emit_burst("pop", _pending_pop["at"], _pending_pop["color"], int(_pending_pop["particles"]),
		scale * float(_pending_pop["size_scale"]))
	_pending_pop = {}


func _maybe_flush_pending_pop() -> void:
	if _pending_pop.is_empty():
		return
	var window_s: float = float(Density.coalesce_window(_density)["ms"]) / 1000.0
	if _clock - float(_pending_pop["time"]) > maxf(window_s, 0.001):
		_flush_pending_pop()


# The most particles the bursts can hold alive at once, for the notes.
static func burst_ceiling() -> int:
	var total := 0
	for kind in BURSTS:
		total += int(BURSTS[kind]["pool"]) * int(BURSTS[kind]["max"])
	return total


func _build_pips() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.22, 0.22)
	_pip_mat = StandardMaterial3D.new()
	_pip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pip_mat.albedo_color = EventKinds.color("enemy_killed")
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


# The kill chain over the ball: a pip per kill in the run from the second one, climbing
# from the kill colour to the reward amber and to white at the top rung. 0 hides it.
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
	var top := float(EventKinds.juice("enemy_killed").get("chain_cap", 7))
	var heat := clampf(_chain_rung / top, 0.0, 1.0)
	_pip_mat.albedo_color = EventKinds.color("enemy_killed").lerp(EventKinds.color("part_gained"), minf(heat * 1.6, 1.0)).lerp(Color.WHITE, maxf(0.0, heat - 0.7) * 2.0)
	var centre: Vector3 = player.shown_position() + Vector3.UP * PIP_HEIGHT
	for i in PIPS:
		var pip: MeshInstance3D = _pips[i]
		pip.visible = i < _chain
		if not pip.visible:
			continue
		var angle := _clock * 2.2 + TAU * float(i) / maxf(1.0, _chain)
		var size := 1.0 + (0.8 * _pip_pop if i == _chain - 1 else 0.0) + 0.25 * heat
		pip.global_transform = Transform3D(Basis(Vector3.UP, angle * 2.0).scaled(Vector3.ONE * size),
			centre + Vector3(cos(angle), 0.0, sin(angle)) * PIP_RADIUS)


# The screen edge toward direction (x right, y down; zero for every edge) flashes.
func edge_flash(direction: Vector2, color: Color, strength: float, seconds: float) -> void:
	if edge != null:
		edge.flash(direction, color, strength, seconds)
	spawned["edge_flash"] = spawned.get("edge_flash", 0) + 1
