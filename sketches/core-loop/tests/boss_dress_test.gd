extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const MindDress := preload("res://src/boss/mind_dress.gd")
const Palette := preload("res://src/core/palette.gd")

# Brindle's dress (card BOSS-DRESS). Two pins:
#
# 1. The posture ring sits round the ship the player sees. It is the hull's posture chunks
#    on the ground (warden_ring.gd), so it must centre on the Requisition, not wherever the
#    hull's physics body was left, and its inner edge must clear the hull's footprint so the
#    hull never hides an arc.
# 2. Hazard stripes sit on the bow's ram lip only. The arenas sheet limits Brindle's stripes
#    to the magnet underside, the throats and the bow; a full-face bow stripe read as striped
#    hull sides at rest (wave 10 judges, w10-arenas.md:33). The BowRam's signal surface is a
#    low band, never the whole plate.
#
# Evidence limit: the ring is read through its node and accessors, the stripe through the
# imported mesh's bounds, not through pixels.

const MODEL := "res://assets/models/bosses/boss_brindle.glb"
const SIGNAL := "M4_signal_surface"
# The ram lip: at most this tall, and wholly in the lower half of the bow plate.
const LIP_MAX := 1.0

var _game
var _boss
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var hit := _find(child, wanted)
		if hit != null:
			return hit
	return null


func _stripe() -> void:
	var scene: PackedScene = load(MODEL)
	if scene == null:
		_report("the bow stripe is a ram lip", false, "no model at %s" % MODEL)
		return
	var model := scene.instantiate()
	var bow := _find(model, "BowRam") as MeshInstance3D
	if bow == null or bow.mesh == null:
		_report("the bow stripe is a ram lip", false, "no BowRam mesh")
		model.free()
		return
	var plate := bow.mesh.get_aabb()
	var lip := AABB()
	var found := false
	for i in bow.mesh.get_surface_count():
		var material := bow.mesh.surface_get_material(i)
		if material == null or material.resource_name != SIGNAL:
			continue
		var points: PackedVector3Array = bow.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
		for p in points:
			if not found:
				lip = AABB(p, Vector3.ZERO)
				found = true
			else:
				lip = lip.expand(p)
	var plate_mid := plate.position.y + plate.size.y * 0.5
	_report("the bow stripe is a ram lip", found and lip.size.y <= LIP_MAX and lip.end.y <= plate_mid,
		"signal band %.2f m tall, top %.2f, plate %.2f to %.2f (mid %.2f)" % [lip.size.y, lip.end.y, plate.position.y, plate.end.y, plate_mid])
	model.free()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.spawner = _game.combat
	_boss = _game.boss
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	for _i in 30:
		await process_frame
	var ship: Node3D = _boss.ship
	var hull = ship.hull
	var ring = hull.get_node_or_null("WardenRing")
	if ring == null:
		_report("the ring sits round the ship", false, "no WardenRing on the hull")
	else:
		var off := _flat(ring.global_position).distance_to(_flat(ship.global_position))
		_report("the ring sits round the ship", ring.visible and off < 0.5,
			"ring at %s, ship at %s, %.2f m apart (hull node at %s)" % [ring.global_position, ship.global_position, off, hull.global_position])
		var footprint := Vector2(Requisition.HULL.x, Requisition.HULL.z).length() * 0.5
		var inner: float = ring._radius() - ring.BAND * 0.5 - ring.BACKING * 0.5
		_report("the ring clears the hull", inner > footprint,
			"ring inner edge %.2f m, hull half diagonal %.2f m" % [inner, footprint])
	_stripe()
	_mind_cards()
	print("boss_dress_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


# W49-MAPS: the Mind's dress shows the Foreman's call-in and the HIRED stamp as cards that never
# pause the tree or catch the mouse, and freeing the dress leaves neither behind.
func _mind_cards() -> void:
	var dress = MindDress.new()
	root.add_child(dress)
	dress.show_call_in()
	var call: CanvasLayer = dress.get_node_or_null(MindDress.CALL_IN_NODE)
	_report("the call-in card is a corner layer that lets clicks through", call != null and not paused
		and (call.get_child(0) as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "layer %s" % [call])
	dress.dismiss_call_in()
	_report("the call-in card dismisses", call.is_queued_for_deletion() and dress._call_in_left == 0.0, "")
	dress.show_hired()
	var hired: CanvasLayer = dress.get_node_or_null(MindDress.HIRED_NODE)
	var stamp: Label = hired.find_child("Stamp", true, false) if hired != null else null
	_report("the HIRED stamp is inked, never Kindness purple", stamp != null and stamp.text == "HIRED" and not paused
		and stamp.get_theme_color("font_color") != Palette.KINDNESS, "stamp %s" % [stamp])
	root.remove_child(dress)
	dress.free()
	_report("freeing the dress frees both cards", not is_instance_valid(hired) and root.find_child(MindDress.HIRED_NODE, true, false) == null, "")
