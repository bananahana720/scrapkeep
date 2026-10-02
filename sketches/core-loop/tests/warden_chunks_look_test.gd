extends SceneTree

const Game := preload("res://src/game.gd")
const BossPlate := preload("res://src/ui/boss_plate.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# WM: real harpoon contacts on a live slice Warden remove its four armour segments.
# All waits are physics frames. The fourth copy must survive the Warden's own deletion.
# The default table, retries, stages and a fresh run are exercised through real flow.

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
	_game = Game.new()
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
	var halves_agree := true
	for i in 4:
		var shown := 0
		for band in rec.segments[i]:
			if is_instance_valid(band) and band.visible:
				shown += 1
		halves_agree = halves_agree and (shown == 0 or shown == 2)
		if shown == 2:
			visible.append(i)
	var want: Array = []
	for i in range(4 - left, 4):
		want.append(i)
	_t.check("both halves of a band show or hide together: " + state, halves_agree)
	_t.eq("visible armour bands follow chunks, top band lost first: " + state, visible, want)
	# A lost band leaves its dark wound where it was; a band still on has none.
	if not rec.wounds.is_empty():
		var wounded: Array = []
		for i in 4:
			if rec.wounds[i][0].visible and rec.wounds[i][1].visible:
				wounded.append(i)
		var gone: Array = []
		for i in range(0, 4 - left):
			gone.append(i)
		_t.eq("a lost band leaves a wound strip: " + state, wounded, gone)


# The default table's Warden draws no health band: the base model's look stays as it was.
func _plain(rec: Dictionary, state: String) -> void:
	var drawn := 0
	for i in 4:
		for band in rec.segments[i]:
			if band.visible:
				drawn += 1
	_t.eq("plating draws no health band: " + state, drawn, 0)
	var crown_ok := true
	for side in ["L", "R"]:
		var crown := rec.base.get_node("Jaw%s/Crown%s" % [side, side]) as MeshInstance3D
		crown_ok = crown_ok and crown.visible
		for surface in crown.get_surface_override_material_count():
			crown_ok = crown_ok and crown.get_surface_override_material(surface) != rec.materials.get("warden_plate")
	_t.check("plating keeps its crown pieces: " + state, crown_ok)
	_t.eq("plating leaves no wound strip", rec.wounds.size(), 0)


func _core(rec: Dictionary, open: bool, state: String) -> void:
	var surface := rec.core.get_node("HeartSurface") as MeshInstance3D
	var mat := surface.get_surface_override_material(0) as StandardMaterial3D
	_t.check("core colour follows stagger: " + state, mat.emission == EventKinds.state_color("open") if open else mat.emission != EventKinds.state_color("open"))
	_t.eq("caged core revealed only while open: " + state, rec.core.visible, open)
	_t.check("core has its own tint material", mat == rec.materials.warden_heart and mat.emission_enabled)
	# WR: the core is depth tested, so a jaw or plate in front of it hides it.
	_t.check("core is drawn with the depth test on: " + state, not mat.no_depth_test and mat.render_priority == 0)
	var no_amber := true
	var live_only_open := true
	var rim_open_only := true
	for i in 4:
		for band in rec.segments[i]:
			for surface_index in band.get_surface_override_material_count():
				var armour: StandardMaterial3D = band.get_surface_override_material(surface_index)
				no_amber = no_amber and armour.emission != Palette.AMBER
				var is_rim: bool = armour == rec.materials.warden_rim
				live_only_open = live_only_open and (open or armour.emission != EventKinds.state_color("open"))
				if is_rim:
					# Every band still on wears the live rim while open, and loses it when it closes.
					rim_open_only = rim_open_only and ((armour.emission == EventKinds.state_color("open") and armour.emission_enabled) == open)
	_t.check("armour never emits amber", no_amber)
	_t.check("closed armour has no live colour", live_only_open)
	_t.check("band rims are live only while open: " + state, rim_open_only)


func _marks(rec: Dictionary, next: int, cracked: bool, open: bool) -> void:
	var visible: Array = []
	var plate := BossPlate.new()
	plate.bind(_warden)
	var want := plate.crack_color()
	_t.check("the plate's crack colour is the HUD rule's: " + str(open), want == (EventKinds.state_color("chunk_shatter") if open else EventKinds.role_color("neutral")))
	plate.unbind()
	plate.free()
	var tinted := true
	var per_band_ok := true
	for i in 4:
		var shown := 0
		for mark in rec.chunk_marks[i]:
			if mark.visible:
				shown += 1
			for stroke in mark.get_children():
				if String(stroke.name).begins_with("Groove"):
					continue
				tinted = tinted and stroke.material_override.emission == want and stroke.material_override.albedo_color == want
		if shown > 0:
			visible.append(i)
		per_band_ok = per_band_ok and (shown == 0 or shown == rec.chunk_marks[i].size())
	_t.check("crack tint follows the HUD rule", tinted)
	_t.eq("only the next armour band has a crack", visible, [next] if cracked else [])
	_t.check("a cracked band shows its crack on every anchor, both halves", per_band_ok and rec.chunk_marks[0].size() == 6)


# WR: the body and the HUD plate say one thing. The plate has no reader for its filled-pip
# colour (boss_plate.gd's _draw holds it in a local), so the closed plate's own bar_color() and
# crack_color(), which are that same neutral role, stand for it. The crack colour is read from
# crack_color() in both states and the core from bar_color() while open.
func _agree(rec: Dictionary, state: String) -> void:
	var plate := BossPlate.new()
	plate.bind(_warden)
	var open: bool = _warden.staggered()
	var plate_mat: StandardMaterial3D = rec.materials.warden_plate
	if not open:
		_t.check("band colour is the plate's neutral pip colour: " + state, plate_mat.albedo_color == plate.bar_color() and plate_mat.albedo_color == plate.crack_color())
	var wearing := true
	for i in 4:
		for band in rec.segments[i]:
			wearing = wearing and band.get_surface_override_material(band.get_surface_override_material_count() - 1) != null
			for surface_index in band.get_surface_override_material_count():
				var worn: Material = band.get_surface_override_material(surface_index)
				wearing = wearing and (worn == rec.materials.warden_plate or worn == rec.materials.warden_rim)
	_t.check("every band wears the plate or rim material: " + state, wearing)
	var crack_mat: StandardMaterial3D = rec.materials.warden_crack
	_t.check("crack colour is the plate's crack colour: " + state, crack_mat.emission == plate.crack_color() and crack_mat.albedo_color == plate.crack_color())
	var heart: StandardMaterial3D = rec.materials.warden_heart
	if open:
		_t.check("open core is the plate's open colour: " + state, heart.emission == plate.bar_color() and not heart.no_depth_test)
		var rim: StandardMaterial3D = rec.materials.warden_rim
		_t.check("band rims are the plate's open colour: " + state, rim.emission == plate.bar_color())
	else:
		_t.check("closed core is not the plate's open colour: " + state, heart.emission != EventKinds.state_color("open") and not rec.core.visible)
	plate.unbind()
	plate.free()


# Each shattered band throws two copies, one per jaw half; both fly, fall and free by themselves.
func _flight(rec: Dictionary, index: int) -> void:
	if not _t.eq("two flying copies per shatter, one per half", rec.flights.size(), 2 * (index + 1)):
		return
	var nodes: Array = []
	var lasts: Array = []
	for half in 2:
		var flight: Dictionary = rec.flights[2 * index + half]
		var node: MeshInstance3D = flight.node
		nodes.append(node)
		lasts.append(flight)
		_t.check("flying copy is a mesh with no collision or physics", node is MeshInstance3D and node.get_child_count() == 0 and node.find_children("*", "CollisionObject3D", true, false).is_empty())
	var centres := [lasts[0].centre, lasts[1].centre]
	await _seconds(0.1)
	for half in 2:
		var node: MeshInstance3D = nodes[half]
		if _t.check("break-off exists during its outward flight", is_instance_valid(node)):
			var now: Vector3 = node.global_transform * node.mesh.get_aabb().get_center()
			_t.check("fragment travels out along its own normal and falls", (now - centres[half]).dot(lasts[half].normal) > 0.8 and now.y < centres[half].y, "outward %.3f m, drop %.3f m, flight %.4f s" % [(now - centres[half]).dot(lasts[half].normal), centres[half].y - now.y, lasts[half].seconds])
	await _seconds(0.1)
	for half in 2:
		_t.check("flight cannot hide the core after 0.2 seconds", not is_instance_valid(nodes[half]) or not nodes[half].visible, "flight %.4f s, time scale %.3f" % [lasts[half].seconds, Engine.time_scale])
	await _seconds(0.4)
	for half in 2:
		_t.check("flying copy freed within 0.6 simulated seconds", not is_instance_valid(nodes[half]), "flight %.4f s, time scale %.3f" % [lasts[half].seconds, Engine.time_scale])
	_t.check("freed copy leaves no physics callback", not physics_frame.is_connected(_hook._step_warden_fragments))


# Two bands broken inside one flight: each copy flies and frees by itself.
func _two_at_once() -> void:
	var rec: Dictionary = _hook.warden_of(_warden)
	_hook._throw_warden_segment(rec, 0)
	_hook._throw_warden_segment(rec, 1)
	var first: MeshInstance3D = rec.flights[0].node
	var second: MeshInstance3D = rec.flights[3].node
	var start: Vector3 = second.global_position
	await _seconds(0.1)
	var moved := second.global_position.distance_to(start) if is_instance_valid(second) else -1.0
	_t.check("two copies in flight both move", moved > 0.5, "the last copy moved %.3f m in 0.1 s" % moved)
	await _seconds(0.5)
	_t.check("two copies in flight both free within 0.6 seconds", not is_instance_valid(first) and not is_instance_valid(second),
		"first alive %s, last alive %s" % [is_instance_valid(first), is_instance_valid(second)])
	_t.eq("no flying debris is left", _hook.find_children("WardenFragment*", "MeshInstance3D", false, false).size(), 0)
	_t.check("no physics callback is left", not physics_frame.is_connected(_hook._step_warden_fragments))
	rec.flights.clear()


# WR: the shoulder crowns are no longer segments. They stay on in every state and wear the
# body's own materials, never the plate colour.
func _crowns(rec: Dictionary, state: String) -> void:
	var ok := true
	for side in ["L", "R"]:
		var crown := rec.base.get_node("Jaw%s/Crown%s" % [side, side]) as MeshInstance3D
		ok = ok and crown.visible
		for surface in crown.get_surface_override_material_count():
			var worn: Material = crown.get_surface_override_material(surface)
			ok = ok and worn != rec.materials.warden_plate and worn != rec.materials.warden_rim
	_t.check("crowns stay on in the body's own material: " + state, ok)


func _fresh(state: String) -> void:
	var rec: Dictionary = _hook.warden_of(_warden)
	_crowns(rec, state)
	_segments(rec, 4, state)
	_marks(rec, 0, false, false)
	_core(rec, false, state)
	_agree(rec, state)
	_t.eq("fresh Warden has no flying debris", _hook.find_children("WardenFragment*", "MeshInstance3D", false, false).size(), 0)


func _crack_and_wait(rec: Dictionary) -> void:
	await _fill()
	_core(rec, true, "open")
	_agree(rec, "open")
	_combat.strike(_warden, "ram", 1.0)
	await _frames(2)
	_t.check("lesser contact cracked the health chunk", _warden.chunk_cracked())
	_marks(rec, 0, true, true)
	_agree(rec, "cracked and open")
	await _seconds(BossPosture.STAGGER_SECONDS + 0.3)
	_t.check("crack survives closure", _warden.chunk_cracked() and not _warden.staggered())
	_marks(rec, 0, true, false)
	_core(rec, false, "cracked and closed")
	_agree(rec, "cracked and closed")


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
			_crowns(rec, "shatter %d" % (i + 1))
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


func _plating() -> void:
	await _start("")
	for stage in range(1, 4):
		if stage > 1:
			_game.flow.enter_stage(stage, Vector3.ZERO, false)
			await _seconds(0.4)
			_bind()
		var rec: Dictionary = _hook.warden_of(_warden)
		_t.eq("default table fights by plating", _warden.fight(), "plating")
		_plain(rec, "plating spawn %d" % stage)
		_t.check("new core and inner damage stay hidden on plating", not rec.core.visible and not rec.base.get_node("JawL/InnerL").visible and not rec.base.get_node("JawR/InnerR").visible)
		_t.eq("plating has no health crack marks", rec.chunk_marks.size(), 0)
		_combat.strike(_warden, "ram", 200.0)
		_hook._update_warden(rec)
		_plain(rec, "plating damaged %d" % stage)
		_t.eq("plating damage throws no segment", rec.flights.size(), 0)
		_warden.died.connect(func(_at: Vector3, _scrap: int): _plain(rec, "plating death %d" % stage))
		_warden.take_damage(999999.0)
		await _frames(2)
		_t.check("plating Warden died through ordinary health damage", not is_instance_valid(_warden))
	_game.free()


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
	_game.flow.enter_stage(2, Vector3.ZERO, false)
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
	await _plating()
	quit(_t.verdict())
