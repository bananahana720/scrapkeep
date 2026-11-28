extends SceneTree

const BossPlate := preload("res://src/ui/boss_plate.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const Game := preload("res://src/game.gd")
const WardenBody := preload("res://src/combat/warden.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const T := preload("res://tests/support/t.gd")

# The posture Warden's health ring on the ground (LEGIBILITY section 4), on the slice table
# with a real fight driven through combat.strike() and a real harpoon smash: lit arcs equal
# chunks_left() after each shatter; the crack sits on the next arc to go exactly when
# chunk_cracked(); lit arcs take the open colour exactly while staggered(); every arc colour
# equals the plate's own reader for that state; the ring is freed with its Warden.

# 2026-10-13 RED-COMBAT: WT-BANDS 907bfef tunes the slice's ram gain
# (src/core/slice_defs.gd:50-51). Fill against the live 110 plating, not the
# obsolete 45-plating fixture; chunk counts below remain exact.

var _t := T.new("warden_ring_test")
# F6 2026-10-04: the plating Warden case is gone; every Warden fights on posture and wears a ring.

var _game
var _combat
var _player
var _warden
var _plate
var _smashed := 0
var _source := Intent.Scripted.new()


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * Engine.physics_ticks_per_second))


func _matched_force() -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < float(_warden.plating):
		force += 0.05
	return force


func _fast_force() -> float:
	var force := _matched_force()
	var cruise: float = _player.tuning.f("cruise")
	while SpeedTier.of(force, cruise) < 2:
		force += 0.5
	return force


func _fill() -> void:
	var guard := 0
	while is_instance_valid(_warden) and not _warden.staggered() and guard < 20:
		_combat.strike(_warden, "ram", _matched_force())
		await physics_frame
		guard += 1
	await physics_frame


func _smash() -> void:
	_smashed = 0
	var at: Vector3 = _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT
	_player.reset_to(at + Vector3(-6.0, 6.0, 0.0))
	_player.grapple_to(at, Vector3.UP, _warden)
	_source.hold = {"harpoon_held": true}
	await _seconds(0.02)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	for tick in roundi(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if _smashed > 0:
			break
	_source.hold = {}


func _start(table: String) -> bool:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _speed: float): _smashed += 1)
	await _seconds(0.4)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_warden = _game.flow.warden
	if not is_instance_valid(_warden):
		return false
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	return table != ""


# The ring against the warden's facts and the plate's readers, after the ring has run a frame.
func _state(label: String, want_left: int, want_crack: int) -> void:
	await process_frame
	await process_frame
	var ring = _warden.get_node_or_null("WardenRing")
	if not _t.check("%s: the ring is there" % label, ring != null):
		return
	var left: int = _warden.chunks_left()
	var open: bool = _warden.staggered()
	var pips: Array = _plate.pips()
	_t.eq("%s: lit arcs equal chunks_left" % label, ring.lit_count(), left)
	_t.eq("%s: chunks_left is the expected count" % label, left, want_left)
	_t.eq("%s: the crack sits on the expected arc" % label, ring.cracked_arc(), want_crack)
	_t.eq("%s: the crack is drawn exactly when cracked" % label, ring.crack_visible(), _warden.chunk_cracked())
	var colours_ok := true
	var shown_ok := true
	for i in BossPosture.CHUNKS:
		var want: Color
		if pips[i]["filled"]:
			want = _plate.bar_color() if open else BossPlate.pip_color(true)
		else:
			want = BossPlate.pip_color(false)
		if ring.arc_color(i) != want:
			colours_ok = false
		if ring.shown_arc_color(i) != want:
			shown_ok = false
		_t.eq("%s: arc %d lit as the plate's pip %d" % [label, i, i], ring.lit(i), pips[i]["filled"])
	_t.check("%s: every arc colour is the plate's reader for its state" % label, colours_ok)
	_t.check("%s: every arc's material holds that colour" % label, shown_ok)
	_t.check("%s: lit arcs take the open colour exactly while staggered" % label, open == (left > 0 and ring.shown_arc_color(0) == _plate.bar_color() and _plate.bar_color() != BossPlate.pip_color(true)))
	_t.check("%s: the crack mark is the plate's crack colour" % label, ring.shown_crack_color() == _plate.crack_color() and ring.shown_backing_color() == BossPlate.crack_backing())
	_t.check("%s: the crack uses no white" % label, not _whitish(ring.shown_crack_color()) and not _whitish(ring.shown_backing_color()))
	_t.check("%s: the crack's colours are the plate's readers" % label, ring.shown_crack_color() == BossPlate.crack_color_for(open) and ring.shown_backing_color() == BossPlate.crack_backing())


func _whitish(c: Color) -> bool:
	return c.r > 0.9 and c.g > 0.9 and c.b > 0.9


# The angles (degrees, 0 to 360) and radii of a mesh's vertices about the ring's origin.
func _polar(mesh: Mesh) -> Dictionary:
	var out := {"a0": 1000.0, "a1": -1000.0, "r0": 1000.0, "r1": -1000.0}
	if mesh == null or mesh.get_surface_count() == 0:
		return out
	for v in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var a := fposmod(rad_to_deg(atan2(v.z, v.x)), 360.0)
		var r := Vector2(v.x, v.z).length()
		out["a0"] = minf(out["a0"], a)
		out["a1"] = maxf(out["a1"], a)
		out["r0"] = minf(out["r0"], r)
		out["r1"] = maxf(out["r1"], r)
	return out


# The ring's geometry, read from its meshes: four gaps of 20 degrees centred on the camera's
# axes, a dark backing wider than the band under every arc and every outline, and an inner edge
# that clears the Warden's own core telegraph by at least 0.6 m.
func _geometry(ring: Node3D) -> void:
	var arcs: Array = []
	for i in BossPosture.CHUNKS:
		arcs.append(_polar(ring.get_node("Arc%d" % i).mesh))
	var gaps_ok := true
	var centred_ok := true
	for i in BossPosture.CHUNKS:
		var next: int = (i + 1) % BossPosture.CHUNKS
		var gap: float = arcs[next]["a0"] - arcs[i]["a1"] + (360.0 if next == 0 else 0.0)
		if absf(gap - 20.0) > 0.6:
			gaps_ok = false
		var mid_gap: float = fposmod(arcs[i]["a1"] + gap * 0.5, 90.0)
		if mid_gap > 0.5 and mid_gap < 89.5:
			centred_ok = false
	_t.check("four gaps of 20 degrees between the arcs", gaps_ok)
	_t.check("each gap is centred on a camera axis", centred_ok)
	var backed := true
	for i in BossPosture.CHUNKS:
		var back: Dictionary = _polar(ring.get_node_or_null("Backing%d" % i).mesh if ring.has_node("Backing%d" % i) else null)
		var band: Dictionary = arcs[i]
		var edge: Dictionary = _polar(ring.get_node("Edge%d" % i).mesh)
		var wider: bool = back["r0"] < band["r0"] - 0.05 and back["r1"] > band["r1"] + 0.05
		wider = wider and back["r0"] < edge["r0"] - 0.05 and back["r1"] > edge["r1"] + 0.05
		wider = wider and back["a0"] < band["a0"] and back["a1"] > band["a1"]
		if not wider:
			backed = false
		_t.check("arc %d has a backing wider than its band and outline" % i, wider)
	_t.check("every arc has a backing wider than the band", backed)
	var clear: float = WardenBody.CORE_RADIUS + 0.6
	var inner := 1000.0
	for i in BossPosture.CHUNKS:
		inner = minf(inner, arcs[i]["r0"])
		if ring.has_node("Backing%d" % i):
			inner = minf(inner, _polar(ring.get_node("Backing%d" % i).mesh)["r0"])
	_t.check("the inner edge clears the core telegraph radius by 0.6 m (inner %.2f, telegraph %.2f)" % [inner, WardenBody.CORE_RADIUS], inner >= clear - 0.01)


func _run() -> void:
	if not await _start("slice"):
		print("warden_ring_test: FAIL (no Warden on the slice table)")
		quit(1)
		return
	_plate = BossPlate.new()
	_plate.set_process(false)
	root.add_child(_plate)
	_plate.bind(_warden)
	_player.reset_to(_game.ctx.terrain.drop_point(_warden.global_position.x + 58.0, _warden.global_position.z, 1.5))
	await _seconds(0.3)
	await _state("fresh", 4, -1)
	_geometry(_warden.get_node("WardenRing"))
	await _fill()
	_t.check("the fight opened", _warden.staggered())
	await _state("open", 4, -1)
	_combat.strike(_warden, "stomp", _matched_force())
	await _frames(2)
	await _state("cracked and open", 4, 3)
	await _seconds(BossPosture.STAGGER_SECONDS + 0.5)
	_t.check("the stagger ran out", not _warden.staggered())
	await _state("cracked and closed", 4, 3)
	await _fill()
	await physics_frame
	_combat.strike(_warden, "ram", _fast_force())
	await _frames(2)
	_t.eq("a shatter leaves three chunks", _warden.chunks_left(), 3)
	await _state("after one shatter", 3, -1)
	await _seconds(0.5)
	await _fill()
	await _smash()
	await _seconds(1.0)
	_t.eq("a harpoon smash leaves two chunks", _warden.chunks_left(), 2)
	await _state("after two shatters", 2, -1)
	var ring = _warden.get_node_or_null("WardenRing")
	var warden: Node3D = _warden
	_plate.unbind()
	warden.free()
	await process_frame
	_t.check("the ring is freed with its Warden", not is_instance_valid(ring))
	_plate.free()
	_game.free()
	quit(_t.verdict())

