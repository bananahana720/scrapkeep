extends SceneTree

# PF-26: a hit word keeps off Brindle's whole drawn ship, not only the 9 x 5 x 14 m placeholder box under
# his hull piece, and it still speaks where clear screen is. The oracle is independent of the fix: the
# screen rects of the loaded model's own meshes (every visible one, but the magnets and caps, which are strike
# pieces of their own), walked and projected here, not the boxes the ship reports. Three set-ups: a camera off
# the ship's side, the ship turned 45 degrees (a world box around a turned hull grows to 16.5 x 16.5 m), and
# the camera beside the hull. Each asks for a word at spots on the ship (a crane mast, the cockpit, the deck,
# amidships) and at spots beside it on clear screen. The camera is set the frame the word is asked for, so the
# chase camera cannot move it. Evidence limit: rects from projected boxes, no pixels.
const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const BossModel := preload("res://src/boss/boss_model.gd")

# Close enough that the 5 m above the placeholder box is taller on screen than a word.
const CAM_M := 26.0
# The chase camera eases its field of view with how fast the ball went, over game time, so the same frame count
# shows the ship a few percent larger on a slower run. Every try sets the same field of view.
const FOV := 74.0

var t := T.new("player_fx_brindle_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.spawner = _game.combat
	_game.ctx.calm = true
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	for _i in 30:
		await process_frame
	# Brindle's arrival row puts a caption and a close-up panel on screen for a game-time span, and how much of it
	# has played by a frame count depends on the machine's load. The tries below ask for clear screen, so no row
	# is showing: stop it, as a screen change does. (Waiting for it to end instead runs on into the fight's first
	# attacks, whose warnings are also game-time driven.)
	_game.presentation.flourish.stop_all()
	for _i in 2:
		await process_frame
	# The boss walks the ship along its route every frame (requisition.move_to), by game time, so how far it has
	# gone when the tries start depends on the machine's load, and so do the hull's screen rects. Hold it still.
	_game.boss.process_mode = Node.PROCESS_MODE_DISABLED
	var fx = _game.presentation.player_fx
	var ship: Node3D = _game.boss.ship
	var cam: Camera3D = _game.camera.cam
	t.check("Brindle's model loaded over the primitives", ship.model != null)
	# The intro arcs the model over the rim on a tween bound to it (flourish_cues._rise), by game time, so under load
	# the tries met the hull up to 2 m along that arc. Stop the model processing, which pauses the tween, and stand
	# it where the arc lands.
	ship.model.process_mode = Node.PROCESS_MODE_DISABLED
	ship.model.position = Vector3.ZERO
	# The idle roll loops on game time, so the hull's screen rects (and the room beside them) shift by a few dozen
	# pixels with how far the clip has run when the tries start. Hold it at its first frame.
	var idle := BossModel.player_of(ship.model)
	if idle != null:
		# Under load the fight has reached its next clip by now, whose first frame poses the hull elsewhere, so put
		# the idle roll back with no blend before holding it.
		idle.play("idle_roll", 0.0)
		idle.seek(0.0, true)
		idle.speed_scale = 0.0
	_game.player.set_frozen(true)
	var meshes: Array[MeshInstance3D] = []
	for m in ship.model.find_children("*", "MeshInstance3D", true, false):
		if m.layers != 0 and m.is_visible_in_tree() and m.get_aabb().size != Vector3.ZERO and not String(m.name).begins_with("Magnet") and not String(m.name).begins_with("Cap") \
				and not (m.get_parent() is Node3D and String(m.get_parent().name).begins_with("Cap")):
			meshes.append(m)
	t.check("the oracle holds the model's body meshes", meshes.size() >= 20, "%d meshes" % meshes.size())
	var base_xf: Transform3D = ship.global_transform
	var tried_clear := 0
	var stamped_clear := 0
	var tried_ship := 0
	var on_ship := 0
	var first_hit := ""
	for setup in 3:
		var label: String = ["side", "turned 45", "beside the hull"][setup]
		# The screen spots sit at a third and a half of the height. At 0.7 a word beside the ball reached the hull's
		# lower rects once the model stood at rest, so those were not clear screen: the old pass came from the intro arc
		# holding the model about 2 m up when the tries began.
		for spot in [Vector3(-4.5, 6.5, -2.0), Vector3(4.5, 6.5, 2.0), Vector3(0.0, 6.5, 4.8), Vector3(0.0, 3.0, 0.0), Vector3(0.0, 6.0, -5.0), Vector3(0.0, 8.5, 0.0), Vector3(-7.0, 8.0, -4.5), Vector3(3.0, 8.0, 4.5), Vector3(-6.0, 7.5, 2.0),
				Vector2(0.14, 0.5), Vector2(0.86, 0.5), Vector2(0.14, 0.3), Vector2(0.86, 0.3)]:
			ship.global_transform = base_xf
			if setup == 1:
				ship.global_transform = Transform3D(base_xf.basis.rotated(Vector3.UP, deg_to_rad(45.0)), base_xf.origin)
			var cam_at := Vector3(CAM_M, 8.0, 3.0) if setup != 2 else Vector3(7.5, 5.0, 3.0)
			var look := Vector3(0.0, 4.0, 0.0)
			var on_screen := spot is Vector2
			var ball_at: Vector3 = ship.to_global(spot) if not on_screen else Vector3.ZERO
			if not on_screen:
				Harness.put_ball(_game, ball_at)
			else:
				Harness.put_ball(_game, ship.to_global(Vector3(0.0, 6.0, 0.0)))
			await process_frame
			cam.global_position = ship.to_global(cam_at)
			cam.look_at(ship.to_global(look), Vector3.UP)
			cam.fov = FOV
			if on_screen:
				ball_at = cam.project_position(cam.get_viewport().get_visible_rect().size * spot, 40.0)
				Harness.put_ball(_game, ball_at)
				cam.global_position = ship.to_global(cam_at)
				cam.look_at(ship.to_global(look), Vector3.UP)
			cam.fov = FOV
			fx._last_word = -1.0e9
			fx._word_seen.clear()
			# The fight rects are cached per frame, and this frame's were taken through the chase camera before the
			# test moved it. Under load that camera has eased further, so the stale rects covered the asked spots.
			fx._fight_frame = -1
			for w in fx._words:
				w["t"] = 1.0
			var said: bool = fx.word("slam", ball_at)
			var rect := Rect2()
			if said:
				var w: Dictionary = fx._words_by_id("slam")
				rect = PlayerFx._word_rect(cam, w["at"], float(w["away"]) > 0.0, float(w["width_px"]), float(w["size"]), 0.01)
			var hit := false
			if said:
				for m in meshes:
					var r := PlayerFx._view_rect(PlayerFx._box_points(m.global_transform, m.get_aabb(), cam), cam)
					if r.has_area() and r.intersects(rect):
						hit = true
						first_hit = "%s spot %s mesh %s word %s" % [label, spot, m.name, rect]
						break
			if hit:
				on_ship += 1
			if on_screen and setup != 2:
				tried_clear += 1
				stamped_clear += 1 if said else 0
			elif not on_screen:
				tried_ship += 1
	# The reported boxes cover the drawn body: every on-screen corner of every oracle mesh lies inside one of
	# the rects the hull piece reports, from the side camera and with the ship turned 45 degrees.
	var uncovered := ""
	for yaw in [0.0, 45.0]:
		ship.global_transform = Transform3D(base_xf.basis.rotated(Vector3.UP, deg_to_rad(yaw)), base_xf.origin)
		cam.global_position = ship.to_global(Vector3(CAM_M, 8.0, 3.0))
		cam.look_at(ship.to_global(Vector3(0.0, 4.0, 0.0)), Vector3.UP)
		var reported := PlayerFx.foe_rects(ship.hull, cam)
		for m in meshes:
			var mb := m.get_aabb()
			for c in 8:
				var corner: Vector3 = m.global_transform * (mb.position + mb.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1))
				if cam.is_position_behind(corner):
					continue
				var px := cam.unproject_position(corner)
				if not cam.get_viewport().get_visible_rect().has_point(px):
					continue
				if not reported.any(func(r: Rect2): return r.grow(2.0).has_point(px)) and uncovered == "":
					uncovered = "yaw %d mesh %s corner %s" % [yaw, m.name, px]
	t.check("the boxes the hull piece reports cover every corner of every body mesh on screen", uncovered == "" and not PlayerFx.foe_rects(ship.hull, cam).is_empty(), uncovered)
	ship.global_transform = base_xf
	t.check("no word lies on the ship by the mesh oracle, in any of the three set-ups", tried_ship == 27 and on_ship == 0, "%d ship tries, %d words on the ship, first %s" % [tried_ship, on_ship, first_hit])
	t.check("words still speak on clear screen beside the ship (at least 6 of 8 tries stamp)", tried_clear == 8 and stamped_clear >= 6, "%d of %d stamped" % [stamped_clear, tried_clear])
	quit(t.verdict())
