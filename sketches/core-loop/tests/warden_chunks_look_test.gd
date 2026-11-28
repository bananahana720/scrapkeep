extends SceneTree

const Game := preload("res://src/game.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# WM: real harpoon contacts on a live slice Warden remove its four armour segments.
# All waits are physics frames. The fourth copy must survive the Warden's own deletion.
# The default table, retries, stages and a fresh run are exercised through real flow.

# F6 2026-10-04: the legacy plating cases are gone; the double table still runs posture.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		if table.is_empty():
			return preload("res://tests/doubles/two_world_defs.gd").FirstWorld
		return super._chosen_table()

var _t := T.new("warden_chunks_look_test")
var _game
var _warden
var _hook
var _combat
var _source := Intent.Scripted.new()
var _smashed := 0


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * Engine.physics_ticks_per_second))


func _start(table: String) -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	_game.table = table
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _speed: float): _smashed += 1)
	await _seconds(0.4)
	_bind()


func _bind() -> void:
	_warden = _game.flow.warden
	_hook = _game.presentation.hero_assets
	_combat = _game.ctx.spawner
	_combat.heft_override = 1.0
	_game.run.set_max_hp(99999.0)
	_game.player.reset_to(_ground(58.0))
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()


func _ground(out: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_warden.global_position.x + out, _warden.global_position.z, 1.5)


func _fill() -> void:
	var force := 1.0
	while _combat.punch_of("ram", force) < _warden.plating:
		force += 0.05
	for hit in 20:
		if _warden.staggered():
			break
		_combat.strike(_warden, "ram", force)
		await physics_frame
	await _frames(2)
	_t.check("real fight opened", _warden.staggered())


func _smash() -> void:
	_smashed = 0
	var at: Vector3 = _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT
	_game.player.reset_to(at + Vector3(-6.0, 6.0, 0.0))
	_game.player.grapple_to(at, Vector3.UP, _warden)
	_source.hold = {"harpoon_held": true}
	await _seconds(0.02)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	for tick in roundi(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if _smashed > 0:
			break
	_source.hold = {}
	_t.eq("real harpoon contact landed", _smashed, 1)


func _segments(rec: Dictionary, left: int, state: String) -> void:
	var visible: Array = []
	for i in 4:
		if is_instance_valid(rec.segments[i]) and rec.segments[i].visible:
			visible.append(i)
	var want: Array = []
	for i in range(4 - left, 4):
		want.append(i)
	_t.eq("visible armour follows chunks: " + state, visible, want)


func _core(rec: Dictionary, open: bool, state: String) -> void:
	var surface := rec.core.get_node("HeartSurface") as MeshInstance3D
	var mat := surface.get_surface_override_material(0) as StandardMaterial3D
	_t.check("core colour follows stagger: " + state, mat.emission == EventKinds.state_color("open") if open else mat.emission != EventKinds.state_color("open"))
	_t.eq("caged core revealed only while open: " + state, rec.core.visible, open)
	_t.check("core shares the existing tint material", mat == rec.materials.ancient_light and mat.emission_enabled)
	var no_amber := true
	var live_only_open := true
	for segment in rec.segments:
		for surface_index in segment.get_surface_override_material_count():
			var armour: StandardMaterial3D = segment.get_surface_override_material(surface_index)
			no_amber = no_amber and armour.emission != Palette.AMBER
			live_only_open = live_only_open and (open or armour.emission != EventKinds.state_color("open"))
	_t.check("armour never emits amber", no_amber)
	_t.check("closed armour has no live colour", live_only_open)


func _marks(rec: Dictionary, next: int, cracked: bool, open: bool) -> void:
	var visible: Array = []
	var want := EventKinds.state_color("chunk_shatter") if open else EventKinds.role_color("neutral")
	var tinted := true
	for i in 4:
		var mark: Node3D = rec.chunk_marks[i]
		if mark.visible:
			visible.append(i)
		for stroke in mark.get_children():
			tinted = tinted and stroke.material_override.emission == want and stroke.material_override.albedo_color == want
	_t.check("crack tint follows the HUD rule", tinted)
	_t.eq("only the next armour segment has a crack", visible, [next] if cracked else [])


func _flight(rec: Dictionary, index: int) -> void:
	if not _t.eq("one flying copy per shatter", rec.flights.size(), index + 1):
		return
	var flight: Dictionary = rec.flights[index]
	var node: MeshInstance3D = flight.node
	_t.check("flying copy is a mesh with no collision or physics", node is MeshInstance3D and node.get_child_count() == 0 and node.find_children("*", "CollisionObject3D", true, false).is_empty())
	var centre: Vector3 = flight.centre
	await _seconds(0.1)
	if _t.check("break-off exists during its outward flight", is_instance_valid(node)):
		var now: Vector3 = node.global_transform * node.mesh.get_aabb().get_center()
		_t.check("fragment travels out along its own normal and falls", (now - centre).dot(flight.normal) > 0.8 and now.y < centre.y, "outward %.3f m, drop %.3f m, flight %.4f s" % [(now - centre).dot(flight.normal), centre.y - now.y, flight.seconds])
	await _seconds(0.1)
	_t.check("flight cannot hide the core after 0.2 seconds", not is_instance_valid(node) or not node.visible, "flight %.4f s, time scale %.3f" % [flight.seconds, Engine.time_scale])
	await _seconds(0.4)
	_t.check("flying copy freed within 0.6 simulated seconds", not is_instance_valid(node), "flight %.4f s, time scale %.3f" % [flight.seconds, Engine.time_scale])
	_t.check("freed copy leaves no physics callback", not physics_frame.is_connected(_hook._step_warden_fragments))


# Two segments broken inside one flight: each copy flies and frees by itself.
func _two_at_once() -> void:
	var rec: Dictionary = _hook.warden_of(_warden)
	_hook._throw_warden_segment(rec, 0)
	_hook._throw_warden_segment(rec, 1)
	var first: MeshInstance3D = rec.flights[0].node
	var second: MeshInstance3D = rec.flights[1].node
	var start: Vector3 = second.global_position
	await _seconds(0.1)
	var moved := second.global_position.distance_to(start) if is_instance_valid(second) else -1.0
	_t.check("two copies in flight both move", moved > 0.5, "the second copy moved %.3f m in 0.1 s" % moved)
	await _seconds(0.5)
	_t.check("two copies in flight both free within 0.6 seconds", not is_instance_valid(first) and not is_instance_valid(second),
		"first alive %s, second alive %s" % [is_instance_valid(first), is_instance_valid(second)])
	_t.eq("no flying debris is left", _hook.find_children("WardenFragment*", "MeshInstance3D", false, false).size(), 0)
	_t.check("no physics callback is left", not physics_frame.is_connected(_hook._step_warden_fragments))
	rec.flights.clear()


func _fresh(state: String) -> void:
	var rec: Dictionary = _hook.warden_of(_warden)
	_segments(rec, 4, state)
	_marks(rec, 0, false, false)
	_core(rec, false, state)
	_t.eq("fresh Warden has no flying debris", _hook.find_children("WardenFragment*", "MeshInstance3D", false, false).size(), 0)


func _crack_and_wait(rec: Dictionary) -> void:
	await _fill()
	_core(rec, true, "open")
	_combat.strike(_warden, "ram", 1.0)
	await _frames(2)
	_t.check("lesser contact cracked the health chunk", _warden.chunk_cracked())
	_marks(rec, 0, true, true)
	await _seconds(BossPosture.STAGGER_SECONDS + 0.3)
	_t.check("crack survives closure", _warden.chunk_cracked() and not _warden.staggered())
	_marks(rec, 0, true, false)
	_core(rec, false, "cracked and closed")


func _shatters() -> void:
	var rec: Dictionary = _hook.warden_of(_warden)
	for i in 4:
		await _fill()
		_core(rec, true, "before shatter %d" % (i + 1))
		await _smash()
		# The final Warden may already be gone; the record and detached copy remain measurable.
		if is_instance_valid(_warden):
			_t.eq("real contact removed exactly one chunk", _warden.chunks_left(), 3 - i)
			_segments(rec, _warden.chunks_left(), "shatter %d" % (i + 1))
			_marks(rec, i + 1, false, false)
			_core(rec, false, "after shatter %d" % (i + 1))
		else:
			_t.eq("last contact killed only the fourth chunk", i, 3)
			_t.eq("last state recorded zero chunks", rec.chunks_seen, 0)
		await _flight(rec, i)
		if i < 3:
			_game.player.reset_to(_ground(58.0))
			await _seconds(0.3)
	_t.check("four real shatters unsealed the stage", not is_instance_valid(_game.flow.warden))


func _run() -> void:
	await _start("slice")
	_t.eq("slice uses posture", _warden.fight(), "posture")
	_fresh("spawn")
	await _crack_and_wait(_hook.warden_of(_warden))
	await _fill()
	await _smash()
	_t.eq("damaged before retry", _warden.chunks_left(), 3)
	_game.flow.retry_stage()
	await _seconds(0.4)
	_bind()
	_fresh("retry")
	await _crack_and_wait(_hook.warden_of(_warden))
	_game.flow.enter_stage(1, Vector3.ZERO, false)
	await _seconds(0.4)
	_bind()
	_fresh("stage change")
	_game.free()
	await _frames(2)
	await _start("slice")
	_fresh("new run")
	await _two_at_once()
	await _shatters()
	_game.free()
	await _frames(2)
	quit(_t.verdict())
