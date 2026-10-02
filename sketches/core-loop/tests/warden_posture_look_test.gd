extends SceneTree

const Game := preload("res://src/game.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

# A posture Warden's body shows the fight (LEGIBILITY section 4), on the slice table and
# driven through combat.strike():
#   B3-2  the seam cracks light at guard 25, 50 and 75 and seal as it drains, on the look and
#         on the model's copied strokes; staggered, the jaws stand 25 degrees or more further
#         apart and the core wears the live colour, steady; both return after; the health
#         ring is not drawn and the badge stays; no material on the Warden is ever amber, and
#         the live colour is on it only while it is open.
# Every wait is counted in physics frames; the look and the model are stepped by hand.

const SliceDefs := preload("res://src/core/slice_defs.gd")
const PLATING: float = SliceDefs.DEFS[0]["warden_plating"]
const CURVE: float = SliceDefs.DEFS[0]["posture"]["curve"]
const OPEN_APART_DEG := 25.0
const JAWS_PER_PAIR := 9

var _t := T.new("warden_posture_look_test")
var _game
var _combat
var _player
var _warden
var _look
var _hook
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


func _ground(out: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_warden.global_position.x + out, _warden.global_position.z, 1.5)


# The ram force whose gain is `share` of a full hit at heft 1, under the row's curve.
func _force_for(share: float) -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < PLATING * pow(share, 1.0 / CURVE):
		force += 0.02
	return force


func _ram(share: float) -> void:
	_combat.strike(_warden, "ram", _force_for(share))
	await physics_frame


func _fill() -> void:
	var guard := 0
	while is_instance_valid(_warden) and not _warden.staggered() and guard < 20:
		await _ram(1.0)
		guard += 1


# Steps the look and the model once, as the frame would.
func _step(delta := 1.0) -> void:
	_look.update(delta)
	_hook._update_warden(_hook.warden_of(_warden))


# The game's process order: the hero model copies the body material before the look
# rewrites it, so a flash's amber reaches the model first.
func _step_game_order(delta := 1.0) -> void:
	_hook._update_warden(_hook.warden_of(_warden))
	_look.update(delta)


func _look_levels() -> int:
	var count := 0
	for level in _look._seams.size():
		if (_look._seams[level][0] as MeshInstance3D).visible:
			count += 1
	return count


# The seam levels lit on the model's copied strokes: a level counts when all its strokes
# on both jaws are lit, and -1 when a level is half lit.
func _model_levels() -> int:
	var seams: Array = _hook.warden_of(_warden).seams
	var count := 0
	for level in 3:
		var lit := 0
		var total := 0
		for i in seams.size():
			if (i % JAWS_PER_PAIR) / 3 == level:
				total += 1
				if seams[i].node.visible:
					lit += 1
		if lit == total:
			count += 1
		elif lit != 0:
			return -1
	return count


func _model_jaws() -> Array:
	var base: Node3D = _hook.warden_of(_warden).base
	return [base.get_node("JawL"), base.get_node("JawR")]


func _apart(a: Node3D, b: Node3D) -> float:
	return rad_to_deg(a.global_basis.y.angle_to(b.global_basis.y))


func _look_apart() -> float:
	return _apart(_look._jaw_plates[0], _look._jaw_plates[2])


func _model_apart() -> float:
	var jaws := _model_jaws()
	return _apart(jaws[0], jaws[1])


func _materials_of(node: Node) -> Array:
	var found: Array = []
	for item in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if mesh.material_override != null:
			found.append(mesh.material_override)
		for surface in mesh.get_surface_override_material_count():
			if mesh.get_surface_override_material(surface) != null:
				found.append(mesh.get_surface_override_material(surface))
		if mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				if mesh.mesh.surface_get_material(surface) != null:
					found.append(mesh.mesh.surface_get_material(surface))
	return found


func _count_emission(color: Color) -> int:
	var count := 0
	for mat in _materials_of(_warden):
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).emission_enabled and (mat as BaseMaterial3D).emission == color:
			count += 1
	return count


func _no_amber(state: String) -> void:
	_t.eq("no amber anywhere on a posture Warden: " + state, _count_emission(Palette.AMBER), 0)


func _live_off(state: String) -> void:
	var live := EventKinds.state_color("open")
	_t.eq("the live colour is not on it: " + state, _count_emission(live), 0)


func _start() -> bool:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _seconds(0.4)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_warden = _game.flow.warden
	if not is_instance_valid(_warden):
		return false
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	_look = _warden._look
	_hook = _game.presentation.hero_assets
	return true


func _run() -> void:
	if not await _start():
		print("warden_posture_look_test: FAIL (no Warden on the slice table)")
		quit(1)
		return
	_t.check("the hero model is on it", not _hook.warden_of(_warden).is_empty())
	_player.reset_to(_ground(58.0))
	await _seconds(0.3)
	await _levels()
	await _open_and_close()
	await _ring_and_badge()
	_game.free()
	quit(_t.verdict())


func _levels() -> void:
	_step()
	_t.eq("lit crack levels at posture 0 is 0", _look_levels(), 0)
	_t.eq("model strokes at posture 0 are 0", _model_levels(), 0)
	_no_amber("rest")
	_live_off("rest")
	await _ram(1.0)
	_step()
	_t.check("posture is 30", absf(_warden.posture() - 30.0) < 0.5, "posture %.1f" % _warden.posture())
	_t.eq("lit crack levels at posture 30 is 1", _look_levels(), 1)
	_t.eq("model strokes at posture 30 are 1", _model_levels(), 1)
	await _ram(5.0 / 6.0)
	_step()
	_t.check("posture is 55", absf(_warden.posture() - 55.0) < 3.0, "posture %.1f" % _warden.posture())
	_t.eq("lit crack levels at posture 55 is 2", _look_levels(), 2)
	_t.eq("model strokes at posture 55 are 2", _model_levels(), 2)
	await _ram(5.0 / 6.0)
	_step()
	_t.check("posture is 80", absf(_warden.posture() - 80.0) < 4.0, "posture %.1f" % _warden.posture())
	_t.eq("lit crack levels at posture 80 is 3", _look_levels(), 3)
	_t.eq("model strokes at posture 80 are 3", _model_levels(), 3)
	_no_amber("cracked")
	_live_off("cracked")
	var neutral := EventKinds.role_color("neutral")
	_t.check("the cracks are the neutral role colour", _look._seam_material.emission == neutral and _hook.warden_of(_warden).seams[0].node.material_override.emission == neutral)
	_warden.flash()
	_warden._update_flash(0.01)
	_step_game_order(0.01)
	_no_amber("hit flash")
	await _seconds(8.5)
	_step()
	_t.check("the guard drained to 20 or under", _warden.posture() < 25.0, "posture %.1f" % _warden.posture())
	_t.eq("lit crack levels after the drain are 0", _look_levels(), 0)
	_t.eq("model strokes after the drain are 0", _model_levels(), 0)


func _open_and_close() -> void:
	_step()
	var rest_look := _look_apart()
	var rest_model := _model_apart()
	var rest_core: Color = _look.core_material().emission
	await _fill()
	_t.check("it is staggered", _warden.staggered())
	_step()
	var live := EventKinds.state_color("open")
	_t.check("the look's jaws stand 25 degrees or more further apart", _look_apart() - rest_look >= OPEN_APART_DEG, "%.1f over rest" % (_look_apart() - rest_look))
	_t.check("the model's jaws stand 25 degrees or more further apart", _model_apart() - rest_model >= OPEN_APART_DEG, "%.1f over rest" % (_model_apart() - rest_model))
	_t.check("the look's core is the live colour", _look.core_material().emission == live and _look.core_material().albedo_color == live)
	var light: StandardMaterial3D = _hook.warden_of(_warden).materials.ancient_light
	_t.check("the model's core is the live colour", light.emission == live)
	var steady: float = _look.core_material().emission_energy_multiplier
	_step(0.1)
	_t.check("the open core is steady", is_equal_approx(_look.core_material().emission_energy_multiplier, steady))
	_t.eq("all three crack levels show while it is open", _look_levels(), 3)
	_no_amber("open")
	await _seconds(4.5)
	_step()
	_t.check("the stagger ended", not _warden.staggered())
	_t.check("the look's jaws closed", absf(_look_apart() - rest_look) < 0.5, "%.1f over rest" % (_look_apart() - rest_look))
	_t.check("the model's jaws closed", absf(_model_apart() - rest_model) < 0.5, "%.1f over rest" % (_model_apart() - rest_model))
	_t.check("the look's core is back", _look.core_material().emission == rest_core and _look.core_material().emission != live)
	var rest_light: Color = _hook.warden_of(_warden).light_rest["ancient_light"]
	_t.check("the model's core is back to its rest emission", light.emission == rest_light and light.emission != live)
	_t.eq("the cracks are sealed after the stagger", _look_levels(), 0)
	_no_amber("closed")
	_live_off("closed")


func _ring_and_badge() -> void:
	var shown := 0
	for segment in _look._segments:
		if (segment as MeshInstance3D).visible:
			shown += 1
	_t.eq("the ring's segments are hidden", shown, 0)
	_t.check("the badge stays visible", _look._badge.visible)
	_t.check("its plates stay at rest", _warden.tint_state == "")
	_warden.set_tint("amber")
	_t.eq("combat's tint never reaches it", _warden.tint_state, "")
