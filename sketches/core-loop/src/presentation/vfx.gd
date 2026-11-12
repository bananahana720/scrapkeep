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
const Synergies := preload("res://src/build/synergies.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const KillMark := preload("res://src/presentation/kill_mark.gd")

# World-space effects. Each glyph takes its colour and silhouette from the fact's
# event_kinds row, so a slam ring, a kill burst and a scrap square read the same way
# here, in the HUD and in the field notes. Speed shows as a trail and speed lines in
# the speed tier's own colour. Effects stay small, brief and behind or around the
# ball, never across the line ahead, so they never hide the next threat.

const POOL := 48
# Glyph silhouettes that are pure light pops: reduce flashes keeps FlashGuard's decorative
# share of their alpha. Every other glyph (rings, bars, cause shapes) shows a reach or a cause
# and keeps the information share.
const POP_SHAPES := ["flash", "star", "burst"]
const SPARKLE_POOL := 6
# Trail seconds and width per speed tier: nothing at a walk, a comet when blazing.
const TRAIL_SECONDS := [0.0, 0.12, 0.22, 0.36]
const TRAIL_WIDTH := [0.0, 0.28, 0.48, 0.72]
const LINES_PER_TIER := [0, 0, 10, 20]
# v3 W11 bursts: pooled one-shot CPU particles, one shared mesh and material per kind;
# each burst sets only its emitter's colour, place and count. pool emitters x max count
# is the ceiling a dense fight can hold alive at once (DESIGN-NOTES v3 W11).
#   debris    a kill or a blast: chunks thrown up under gravity
#   dust      a ram, a rebound or a blast: soft puffs rolling out along the ground
#   fountain  a part or a core: a column that rises and falls around the drop
const BURSTS := {
	"debris": {"pool": 6, "max": 12, "life": 0.7, "speed": [4.0, 9.0], "spread": 55.0, "gravity": -26.0, "size": Vector3.ONE * 0.24},
	"dust": {"pool": 4, "max": 14, "life": 0.5, "speed": [2.0, 5.0], "spread": 85.0, "gravity": 1.5, "size": Vector3.ONE * 0.4, "soft": true},
	"fountain": {"pool": 3, "max": 24, "life": 0.9, "speed": [6.0, 10.0], "spread": 22.0, "gravity": -18.0, "size": Vector3.ONE * 0.18},
}
const BURST_LOOKS := {"debris": "chunk", "dust": "puff", "fountain": "bead"}
# The kill chain: a pip per kill in the run over the ball, from 2 up.
const PIPS := 8
const PIP_RADIUS := 0.9
const PIP_HEIGHT := 2.5
# The kill mark's width across its longest points, before the merged pop's scale: a crit's
# star reaches 1.6 m, so a single kill's mark stands clear of it.
const KILL_MARK_M := 3.0

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
# W12 P-FX: GPU effect pools by FxLibrary spec id, and the ball's rolling dust.
var _fx := {}
var _fx_next := {}
var _roll: GPUParticles3D
var _pips: Array = []
var _pip_mat: StandardMaterial3D
var _chain := 0
var _chain_rung := 0
var _pip_pop := 0.0
var edge: Control
# How grown the build is, 0 to 1 (player_fx.gd might): hit and kill glyphs grow with it, so
# a late run's hit reads bigger than the first fight's (Andrew, "Clearly mightier").
# The slam ring stays at the slam's real reach.
var might := 0.0
const MIGHT_GLYPH := 0.15
# How far a grown build's hit and kill glyphs run toward heat orange (player_fx.gd heat_k):
# growth shows as colour, not size (Andrew, "Presence, centre clear").
var heat := 0.0
const HEAT_GLYPH := Color(1.0, 0.5, 0.12)
# False skips the ball trail and speed lines; tools/perf_bench.gd --no-trails sets it.
var trails := true
# Every kill's mark, shards and debris pass through this gate (kill_pop).
var pops := PopGate.new()
# A kill's own mark (FX-01, Andrew's pick 12 Nov 2026: the ink burst, and a time card on elites).
var kill_mark: KillMark
var _fill_scale := 1.0
# What the governor steers toward, recounted every 1 / Density.SAMPLE_HZ seconds.
var _density_target := 0.0
var _density_wait := 0.0


# At most Density.KILL_POPS_PER_WINDOW kill pops in any KILL_POP_WINDOW seconds
# (FEEL-READABILITY.md §1.2, E1-DENSITY.md §3). A kill that finds no room, or arrives in a
# band that coalesces, joins the nearest pending cluster within reach, else opens one;
# a fourth cluster folds into the nearest. A cluster pops once, scaled by its kill count,
# when the window has room and it has waited the band's coalesce time. O(1) per kill.
class PopGate:
	extends RefCounted

	var ring := PackedFloat64Array([-1.0e9, -1.0e9, -1.0e9])
	var oldest := 0
	var pending: Array = []
	# The last EMITTED_KEEP pops: [clock, kills, scale], for the tests.
	const EMITTED_KEEP := 64
	var emitted: Array = []

	func add(clock: float, at: Vector3, reach: float) -> void:
		var nearest: Dictionary = {}
		var best := INF
		for cluster in pending:
			var d: float = (cluster["sum"] / cluster["n"]).distance_to(at)
			if d < best:
				best = d
				nearest = cluster
		if not nearest.is_empty() and (best <= reach or pending.size() >= Density.KILL_POPS_PER_WINDOW):
			nearest["sum"] += at
			nearest["n"] += 1
			return
		pending.append({"sum": at, "n": 1, "since": clock})

	# The clusters that pop now, oldest first.
	func ready(clock: float, wait: float) -> Array:
		var out: Array = []
		while not pending.is_empty() and clock - ring[oldest] >= Density.KILL_POP_WINDOW \
				and clock - float(pending[0]["since"]) >= wait:
			var cluster: Dictionary = pending.pop_front()
			ring[oldest] = clock
			oldest = (oldest + 1) % ring.size()
			cluster["at"] = cluster["sum"] / cluster["n"]
			cluster["scale"] = Density.pop_scale(cluster["n"])
			emitted.append([clock, cluster["n"], cluster["scale"]])
			if emitted.size() > EMITTED_KEEP:
				emitted.pop_front()
			out.append(cluster)
		return out

	func clear() -> void:
		pending.clear()
		emitted.clear()
		ring = PackedFloat64Array([-1.0e9, -1.0e9, -1.0e9])
		oldest = 0


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
		glyph("harpoon_smashed", at, 0.6, 2.0 + speed * 0.05, 0.4, Vector3.ZERO, "", player.class_color()))
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


# --- Demo-spec facts ----------------------------------------------------------------------

# The Warden breaks: a star flash over the beacon and a ring out to its edge.
func _on_unsealed(stage: int) -> void:
	var at := player.shown_position() as Vector3
	var radius := 12.0
	if ctx.terrain != null:
		at = ctx.terrain.beacon_point(stage)
	if ctx.flow != null and ctx.flow.has_method("stage_def"):
		radius = float(ctx.flow.stage_def().get("beacon_radius", radius))
	glyph("beacon_unsealed", at + Vector3.UP * 6.0, 1.0, 6.0, 0.6)
	glyph("beacon_unsealed", at + Vector3.UP * 0.3, 2.0, radius, 0.7, Vector3.UP, "ring")


# A new heft class ripples out from the ball along the ground.
func _on_heft_class(heft_class: int, _heft: float) -> void:
	if heft_class < _heft_class:
		# A class lost: the ring falls inward in the torn-scrap colour.
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


# The core locks in where it was won: a diamond flash and a tight ring.
func _on_core(_source: String, at: Vector3, _count: int) -> void:
	glyph("core_gained", at + Vector3.UP * 1.2, 0.5, 1.6, 0.5)
	glyph("core_gained", at + Vector3.UP * 0.2, 0.6, 3.0, 0.45, Vector3.UP, "ring")


# The discovery leaves a ring on the ball for the rest of the run, one per synergy, so your
# build shows on the ball. The moment itself is the pulse on the struck body.
func _on_synergy(id: String, category: String, _first_time: bool) -> void:
	add_ring(id, CodexStyle.category_color(category))


const ARMED_SECONDS := 0.6


# A synergy goes live: its two cause glyphs link above the ball, no name and no banner.
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


# The effect resolves: a pulse in the row's own shape on the struck body, or where it
# landed when nobody was in reach.
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
	var sound := Rows.element_sound(behaviour)
	var shape: String = {"ice_form": "diamond", "zap_hum": "burst", "shatter": "star"}.get(sound, "burst")
	glyph("element_resolved", at + Vector3.UP * 0.5, 0.4, 1.5, 0.3, Vector3.ZERO, shape)


const MAX_RINGS := 4


func add_ring(id: String, tint: Color) -> void:
	if _rings.has(id) or _rings.size() >= MAX_RINGS:
		return
	var ring := ring_view(_rings.size(), tint)
	player.juice_node().add_child(ring)
	_rings[id] = {"node": ring, "tilt": 0.5 + 0.35 * _rings.size(), "speed": 1.4 + 0.5 * _rings.size()}


# The index-th synergy ring as add_ring draws it (BakeWarm builds one at stage entry).
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
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.8)
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
	if kill_mark != null:
		kill_mark.clear()
	_trail_points.clear()
	_streaks.clear()
	pops.clear()
	Density.live().reset()
	_density_target = 0.0
	_density_wait = 0.0
	_publish_fill_scale(1.0)
	if ctx.run.has_method("heft_class"):
		_heft_class = int(ctx.run.heft_class())


# --- Glyphs ---------------------------------------------------------------------------

# The glyph pool and the kill mark, under root.
func _build_glyphs() -> void:
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
# priority_class is the fact's FEEL-READABILITY §1.1 class; unset, the kind's own
# (Density.class_of_kind). The governor thins P5 glyphs and never P0 to P3.
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
	node.visible = true
	spawned[kind] = spawned.get(kind, 0) + 1
	_draw_glyph(slot)
	return slot


# Ends a glyph glyph() returned early, unless its pooled slot has since moved on to another glyph.
func end_glyph(slot: Dictionary, at: Vector3) -> void:
	if slot.is_empty() or slot["t"] >= 1.0 or not slot["node"].global_position.is_equal_approx(at):
		return
	slot["t"] = 1.0
	slot["node"].visible = false


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
	mat.albedo_color = Color(color.r, color.g, color.b, (1.0 - t) * slot.get("alpha", 0.9))


# --- Facts -------------------------------------------------------------------------------

func _on_landed(impact: float) -> void:
	if impact < 10.0:
		return
	var at: Vector3 = player.shown_position() - player.state.contact_normal * 0.95
	glyph("landed", at, 0.6, 1.2 + impact * 0.06, 0.25, player.state.contact_normal)


# The slam ring grows to the slam's real reach, so the effect shows exactly who it hit.
func _on_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05:
		return
	glyph("slammed", at + Vector3.UP * 0.15, 1.0, player.slam_radius() if player.has_method("slam_radius") else Augments.SLAM_RADIUS, 0.35, player.state.contact_normal)
	play_fx("slammed", at + Vector3.UP * 0.15)


# The plant ring shows the mount's repel reach.
func _on_mounted(at: Vector3, _banked: float) -> void:
	var normal: Vector3 = player.kit.mount_normal
	var face: Vector3 = player.kit.mount_face if player.kit.mount_face != Vector3.ZERO else at
	glyph("mounted", face + normal * 0.1, 0.8, Augments.MOUNT_REPEL_RADIUS, 0.3, normal, "ring")


func _on_dismounted(velocity: Vector3) -> void:
	if velocity.length() > 1.0:
		glyph("dismounted", player.shown_position(), 0.8, 1.6, 0.22, velocity)


func _on_shot(_weapon: String, from: Vector3, to: Vector3) -> void:
	var dir := to - from
	# Muzzle: a short bar along the shot, right at the barrel.
	glyph("shot_fired", from + dir.normalized() * 0.4, 0.5, 0.9, 0.06, dir, "", player.class_color())
	# Impact: a small flash where it landed.
	glyph("shot_fired", to, 0.5, 1.1, 0.09, Vector3.ZERO, "flash", player.class_color())


# A glyph's colour run toward heat and brightened; transparent (the row's own colour) when cold.
func _hot(kind: String) -> Color:
	if heat <= 0.0:
		return Color(0, 0, 0, 0)
	# Hotter and brighter: a grown hit's core carries more light at the same size.
	var c: Color = Rows.color(kind).lerp(HEAT_GLYPH, heat)
	var k := 1.0 + 0.6 * heat
	return Color(c.r * k, c.g * k, c.b * k, c.a)


func _on_struck(enemy: Node3D, _kind: String, force: float) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var grow := 1.0 + MIGHT_GLYPH * might
	glyph("enemy_struck", enemy.global_position + Vector3.UP * 0.6, 0.4 * grow, clampf(0.8 + force * 0.03, 0.8, 1.6) * grow, 0.14 + 0.08 * might,
		Vector3.ZERO, "", _hot("enemy_struck"))


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
	for entry in _rings.values():
		var node: Node3D = entry["node"]
		if is_instance_valid(node):
			node.basis = Basis(Vector3.UP, _clock * entry["speed"]) * Basis(Vector3.RIGHT, entry["tilt"])
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


# --- v3 W11 bursts, the chain and the edge flash ----------------------------------------

func _build_bursts() -> void:
	for kind in BURSTS:
		var spec: Dictionary = BURSTS[kind]
		# The same looks as the GPU effects (FxLibrary._LOOKS): kill pops and dust are cel puffs,
		# debris is chipped lit shards, and a drop's fountain is keylined beads.
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


# One pooled burst: the oldest emitter of its kind restarts here in this colour.
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
	for id in FxLibrary.SPECS:
		if FxLibrary.SPECS[id].get("owner", "vfx") != "vfx":
			continue
		var pool: Array = []
		for i in int(FxLibrary.SPECS[id]["pool"]):
			var p := FxLibrary.build(id)
			p.name = "%s_%d" % [p.name, i]
			root.add_child(p)
			pool.append(p)
		_fx[id] = pool
		_fx_next[id] = 0
	_roll = _fx["roll_dust"][0]
	_roll.set_instance_shader_parameter("tint", FxLibrary.colour("roll_dust", "rolling"))


# The GPU effects an event's JUICE row names, at one place: the oldest emitter of each
# restarts there, its particle count from the row, its tint from the spec's colour
# source unless the caller passes one (a crit's colour). `variant` picks the row's
# "crit" set; `toward` aims a forward spec (the latch's pulse runs at the ball).
func play_fx(kind: String, at: Vector3, tint := Color.TRANSPARENT, variant := "", toward := Vector3.ZERO) -> void:
	if root == null or not root.is_inside_tree():
		return
	var effects := FxLibrary.effects(kind, variant)
	for id in effects:
		if not _fx.has(id) or FxLibrary.SPECS[id]["attach"] == "ball":
			continue
		_fire_fx(id, kind, int(effects[id]), at, tint, toward)


# The oldest emitter of one "vfx" spec restarts at `at`.
func _fire_fx(id: String, kind: String, count: int, at: Vector3, tint := Color.TRANSPARENT, toward := Vector3.ZERO) -> void:
	var pool: Array = _fx[id]
	var p: GPUParticles3D = pool[_fx_next[id]]
	_fx_next[id] = (_fx_next[id] + 1) % pool.size()
	FxLibrary.fire(p, id, kind, count, at, tint, toward)
	spawned["fx_" + id] = spawned.get("fx_" + id, 0) + 1


func _on_world_fact_fx(kind: String, at: Vector3) -> void:
	if not FxLibrary.effects(kind).is_empty() and kind != "breach_opened":
		play_fx(kind, at)


# A spent cache keeps a low ember going where it stands, until the stage is left.
func stop_embers() -> void:
	for id in ["cache_ember", "cache_wisp"]:
		for p: GPUParticles3D in _fx[id]:
			p.emitting = false


# Rolling dust: the ball's contact point emits while it rolls on the ground at speed,
# thicker as it goes faster; the row's count is particles per second at twice min_speed.
func _roll_dust() -> void:
	if _roll == null:
		return
	var row := EventKinds.juice("rolling")
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


# A kill's mark, shards and debris, through the kill-pop gate: one call per kill.
func kill_pop(at: Vector3) -> void:
	var governor := Density.live()
	pops.add(_clock, at, governor.coalesce_metres())
	_emit_pops()


func _emit_pops() -> void:
	if pops.pending.is_empty():
		return
	for cluster in pops.ready(_clock, Density.live().coalesce_seconds()):
		kill_look(cluster["at"], cluster["scale"])


# One merged kill pop at `at`, `scale` from its kill count (FX-01): the kill mark, the body's
# shards in the pilot's colour and ink debris. `pilot` overrides the pilot's colour (a capture
# with no ball).
func kill_look(at: Vector3, scale: float, pilot := Color.TRANSPARENT) -> void:
	var row := EventKinds.juice("enemy_killed")
	scale *= 1.0 + MIGHT_GLYPH * might
	if root == null or not root.is_inside_tree():
		return
	var tint := (pilot if pilot.a > 0.0 else kill_tint()).lerp(HEAT_GLYPH, heat)
	kill_mark.reduced_motion = camera != null and camera.get("reduced_motion") == true
	kill_mark.fire(at + Vector3.UP * 0.8, KILL_MARK_M * scale, tint,
		Density.live().apply(Density.class_of_kind("enemy_killed"), 1.0, 1.0, 1.0))
	var fx := FxLibrary.effects("enemy_killed")
	for id in fx:
		_fire_fx(id, "enemy_killed", int(ceil(float(fx[id]) * scale)), at + Vector3.UP * 0.6, tint)
	burst("debris", at + Vector3.UP * 0.5, Palette.CHARCOAL, int(ceil(float(row["debris"]) * scale)))
	spawned["enemy_killed"] = spawned.get("enemy_killed", 0) + 1


# The pilot's colour: "you did this" (VISUAL-LANGUAGE section 2); the row's copper without a pilot.
func kill_tint() -> Color:
	return player.class_color() if player != null and player.has_method("class_color") else EventKinds.color("enemy_killed")


# One density per frame from what is in view (FEEL-READABILITY.md §1.2); the P6 fill
# scale reaches every governed fill as one global shader value. The group walks run
# Density.SAMPLE_HZ times a second; between samples the governor eases toward the last
# count, so a frame costs one update and at most one server call.
func _govern(delta: float) -> void:
	_density_wait -= delta
	if _density_wait <= 0.0:
		_density_wait = 1.0 / Density.SAMPLE_HZ
		_density_target = _count_density()
	_publish_fill_scale(Density.fill_scale(Density.live().update(delta, _density_target)))


func _count_density() -> float:
	var cam: Camera3D = camera.cam if camera != null and camera.get("cam") is Camera3D else null
	var alive := 0
	for g in _glyphs:
		if g["t"] < 1.0:
			alive += 1
	var tree := get_tree()
	return Density.raw(Density.count_in_view(cam, tree.get_nodes_in_group(Threat.GROUP)), alive,
		Density.count_in_view(cam, tree.get_nodes_in_group("enemy")))


func _publish_fill_scale(value: float) -> void:
	if value != _fill_scale:
		_fill_scale = value
		Density.publish_fill_scale(value)


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
