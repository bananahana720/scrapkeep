extends SceneTree
# smoke: timeout=360s

# The flume's weir deck keeps a ball's speed (wave 36 snag sweep, flume-merged.json: six ride lanes over
# Park_weir_deck lost 13.6 m/s down to 2.0 to 6.6 m/s). The deck (park_flume.json weir_deck, recipe weir_apron,
# tools/blender/park/flume_works.py) was a drop wedge with vertical faces: a 0.5 m back end and sides falling from
# 0.5 m to 0, which a radius 1 ball meets as a step at its top edge. Its rim is now a 1:6 bevel drawn and collided alike.
#
# Four lines at cruise cross the whole deck, one entering over each side (both long sides, the high back end the drop
# is ridden from, the flush front), and each rim's lowest speed from the ball's touch to 4 m past it must stay at least
# KEEP of the speed 3 m before it. The deck's place, extent and the cruise speed are read from the running game.
# Controls on flat open ground beside the deck: the same lane with nothing on it passes, and a planted box of the
# deck's height with vertical faces fails, so a pass on the deck is the deck's and not a blind measure.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

const KEEP := 0.85
# Run-up before the first rim and run-out after the last, and where "before" is read.
const RUN_M := 10.0
const BEFORE_M := 3.0
const PAST_M := 4.0
# Where the lines cross: the long sides at 30% of the length from the high end (a 0.4 m step on the old wedge), the
# ends at 30% of the width either side of the centre line.
const SIDE_AT := 0.3
const END_AT := 0.3
# The open-ground controls stand this far past the deck's +x side, where the ground is one flat tile.
const CONTROL_OFF_M := 35.0
const CONTROL_LEN_M := 10.0
const FLAT_M := 0.1

var t := T.new("park_weir_deck_roll_test")
var game
var source := Intent.Scripted.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = source
	game.flow.press_start()
	game.flow.choose_class(0)
	game.flow.enter_stage(2, Vector3.ZERO, false)
	var terrain = game.ctx.terrain
	var waited := 0
	while waited < 3000 and not (terrain.rows_ready(2) and terrain.is_ready(2) and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	for i in 30:
		await physics_frame
	t.eq("real Game plays the flume on the park table", terrain.map().title, "park_flume")
	var found: Array = game.find_children("Park_weir_deck", "Node3D", true, false)
	t.check("the flume places the weir deck", found.size() == 1, "%d found" % found.size())
	if found.size() != 1:
		game.free()
		quit(t.verdict())
		return
	var deck: Node3D = found[0]
	var box := _extent(deck.get_node("Collider"), deck)
	var frame: Transform3D = deck.global_transform
	var cruise: float = game.player.tuning.f("cruise")
	print("  deck at %s yaw %.1f, collider %s, cruise %.1f" % [frame.origin, rad_to_deg(frame.basis.get_euler().y), box, cruise])
	t.check("the deck is a low piece the ball rolls over", box.size.y > 0.05 and box.size.y < Tuning.RADIUS, "height %.2f" % box.size.y)
	var lo := box.position
	var hi := box.end
	var zs := lo.z + box.size.z * SIDE_AT
	var xe := box.size.x * 0.5 * END_AT * 2.0
	var lines := {
		"over the -x side": [Vector3(lo.x, 0, zs), Vector3.RIGHT, box.size.x],
		"over the +x side": [Vector3(hi.x, 0, zs), Vector3.LEFT, box.size.x],
		"over the high end": [Vector3(xe, 0, lo.z), Vector3.BACK, box.size.z],
		"over the flush front": [Vector3(-xe, 0, hi.z), Vector3.FORWARD, box.size.z],
	}
	for name: String in lines:
		var line: Array = lines[name]
		var roll := await _roll(frame, line[0], line[1], line[2], cruise)
		_rims(name, roll)
	# Controls beside the deck: flat open ground, then a planted vertical-faced box of the deck's height on it.
	var c0 := Vector3(hi.x + CONTROL_OFF_M, 0, -CONTROL_LEN_M * 0.5)
	var flat := _flatness(frame, c0, Vector3.BACK, CONTROL_LEN_M + RUN_M * 2.0)
	t.check("control: the open ground beside the deck is flat", flat < FLAT_M, "height span %.2f m" % flat)
	var open := await _roll(frame, c0, Vector3.BACK, CONTROL_LEN_M, cruise)
	_rims("open ground (control)", open)
	var step := StaticBody3D.new()
	step.name = "PlantedStep"
	step.collision_layer = 0
	step.collision_mask = 0
	step.set_collision_layer_value(ParkRecipes.WORLD_LAYER, true)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(CONTROL_LEN_M, box.size.y, CONTROL_LEN_M)
	shape.shape = bs
	step.add_child(shape)
	deck.get_parent().add_child(step)
	var c_mid := frame * (c0 + Vector3.BACK * CONTROL_LEN_M * 0.5)
	step.global_transform = Transform3D(frame.basis, Vector3(c_mid.x, _ground(c_mid) + box.size.y * 0.5, c_mid.z))
	for i in 2:
		await physics_frame
	var planted := await _roll(frame, c0, Vector3.BACK, CONTROL_LEN_M, cruise)
	print("  planted step (control): entry %.2f exit %.2f of the speed before" % [planted["entry"], planted["exit"]])
	t.check("control: a planted %.2f m vertical step costs more than %.0f%% (the measure sees a rim)" % [box.size.y, (1.0 - KEEP) * 100.0],
		planted["entry"] < KEEP, "entry kept %.2f" % planted["entry"])
	step.free()
	game.free()
	quit(t.verdict())


func _rims(name: String, roll: Dictionary) -> void:
	print("  %s: before %.1f m/s, entry rim kept %.2f, exit rim kept %.2f, crossed %s" % [name, roll["before"], roll["entry"], roll["exit"], roll["crossed"]])
	t.check("%s: the ball crosses" % name, roll["crossed"], "ended at %.1f m of %.1f" % [roll["reached"], roll["length"]])
	t.check("%s: the entry rim keeps %.0f%% of the speed" % [name, KEEP * 100.0], roll["entry"] >= KEEP, "kept %.2f" % roll["entry"])
	t.check("%s: the exit rim keeps %.0f%% of the speed" % [name, KEEP * 100.0], roll["exit"] >= KEEP, "kept %.2f" % roll["exit"])


# The collider's box in the deck's own frame.
func _extent(body: CollisionObject3D, deck: Node3D) -> AABB:
	var out := AABB()
	var any := false
	for owner_id in body.get_shape_owners():
		var xf: Transform3D = deck.global_transform.affine_inverse() * body.global_transform * body.shape_owner_get_transform(owner_id)
		for i in body.shape_owner_get_shape_count(owner_id):
			var b: AABB = xf * body.shape_owner_get_shape(owner_id, i).get_debug_mesh().get_aabb()
			out = b if not any else out.merge(b)
			any = true
	return out


func _ground(at: Vector3) -> float:
	var space := game.player.body().get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 40.0, at.z), Vector3(at.x, at.y - 200.0, at.z))
	q.exclude = [game.player.body().get_rid()]
	var hit := space.intersect_ray(q)
	return at.y if hit.is_empty() else float(hit.position.y)


func _flatness(frame: Transform3D, rim: Vector3, dir: Vector3, length: float) -> float:
	var lo := INF
	var hi := -INF
	for k in int(length) + 1:
		var y := _ground(frame * (rim - dir * RUN_M + dir * float(k)))
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo


# Rolls from RUN_M before `rim` (deck-local, on the rim the line enters over) along `dir` across `length` and RUN_M past.
# entry / exit: the lowest planar speed from the ball touching that rim to PAST_M beyond it, over the speed BEFORE_M
# short of the touch.
func _roll(frame: Transform3D, rim: Vector3, dir: Vector3, length: float, cruise: float) -> Dictionary:
	var player = game.player
	var wdir: Vector3 = (frame.basis * dir).normalized()
	var start: Vector3 = frame * (rim - dir * RUN_M)
	player.reset_to(Vector3(start.x, _ground(start) + Tuning.RADIUS + 0.3, start.z), wdir * cruise)
	source.hold = {}
	await physics_frame
	var touch_in := RUN_M - Tuning.RADIUS
	var touch_out := RUN_M + length - Tuning.RADIUS
	var marks := {"in_before": -1.0, "out_before": -1.0, "entry": INF, "exit": INF}
	var reached := 0.0
	var limit := int((length + RUN_M * 2.0) / cruise * 2.0 * Engine.physics_ticks_per_second) + 90
	for tick in limit:
		game.camera.yaw = atan2(-wdir.x, -wdir.z)
		source.hold = {"move": Vector2(0.0, 1.0)}
		player.grant_immunity(1.0)
		await physics_frame
		var ball: Vector3 = player.ball_position()
		var s: float = (ball - start).dot(wdir)
		reached = maxf(reached, s)
		var speed: float = player.planar_velocity().length()
		if marks["in_before"] < 0.0 and s >= touch_in - BEFORE_M:
			marks["in_before"] = speed
		if marks["out_before"] < 0.0 and s >= touch_out - BEFORE_M:
			marks["out_before"] = speed
		if s >= touch_in and s <= RUN_M + PAST_M:
			marks["entry"] = minf(marks["entry"], speed)
		if s >= touch_out and s <= RUN_M + length + PAST_M:
			marks["exit"] = minf(marks["exit"], speed)
		if s > RUN_M + length + PAST_M:
			break
	source.hold = {}
	var crossed := reached > RUN_M + length + PAST_M
	return {
		"before": marks["in_before"],
		"entry": marks["entry"] / marks["in_before"] if marks["in_before"] > 0.0 and marks["entry"] < INF else 0.0,
		"exit": marks["exit"] / marks["out_before"] if marks["out_before"] > 0.0 and marks["exit"] < INF else 0.0,
		"crossed": crossed, "reached": reached, "length": RUN_M + length + PAST_M,
	}
