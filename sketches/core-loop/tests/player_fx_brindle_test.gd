extends SceneTree

# PF-26: a hit word keeps off Brindle's whole drawn ship, not only the 9 x 5 x 14 m placeholder box under
# his hull piece. The loaded model, the cockpit and the crane posts are children of the ship node, so the
# hull piece's own meshes stop at 5 m. The oracle here is independent of the fix: the screen rect of the
# loaded model's own meshes, walked by the test. The camera is set the frame the word is asked for, so the
# chase camera cannot move it. Evidence limit: rects from projected bounds, no pixels.
const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const Requisition := preload("res://src/boss/requisition.gd")

# Close enough that the 5 m above the placeholder box is taller on screen than a word.
const CAM_M := 26.0

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
	var fx = _game.presentation.player_fx
	var ship: Node3D = _game.boss.ship
	var cam: Camera3D = _game.camera.cam
	t.check("Brindle's model loaded over the primitives", ship.model != null)
	# The superstructure: the part of the drawn model above the hull piece's 5 m placeholder box.
	var merged := [AABB(), false]
	PlayerFx._merge_meshes(ship.model if ship.model != null else ship, merged)
	var body: AABB = merged[0]
	# The word's near end sits over the cockpit at the stern, past the caps' mark columns, and the ball amidships makes it
	# grow toward the stern; the camera looks along the ship's side. Only that one spot is free on the
	# placeholder box and the caps, so a stamp there lands on the superstructure.
	var spot: Vector3 = ship.to_global(Vector3(0.0, 8.5, 7.2))
	_game.player.set_frozen(true)
	Harness.put_ball(_game, ship.to_global(Vector3(0.0, 8.5, 0.0)))
	await process_frame
	cam.global_position = ship.to_global(Vector3(CAM_M, 8.5, 3.0))
	cam.look_at(ship.to_global(Vector3(0.0, 7.4, 3.0)), Vector3.UP)
	var drawn := PlayerFx.foe_rect(ship.model if ship.model != null else ship, cam)
	var hull_piece := _mesh_rect(ship.hull, cam)
	t.check("the drawn ship is taller on screen than the hull piece's placeholder box", drawn.has_area() and hull_piece.has_area()
		and drawn.position.y < hull_piece.position.y - 20.0, "drawn %s hull piece %s" % [drawn, hull_piece])
	# Every spot over the ship's side, from the stern end to the bow end and from the deck to the model's top:
	# a word may stand clear of the ship or be held, and may never lie on it.
	var tried := 0
	var stamped := 0
	var on_ship := 0
	var first_hit := ""
	for z in [-8.0, -6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0, 8.0, 10.0]:
		for y in [5.5, 6.5, 7.5, 8.5, 9.5]:
			fx._last_word = -1.0e9
			fx._word_seen.clear()
			for w in fx._words:
				w["t"] = 1.0
			tried += 1
			var at: Vector3 = ship.to_global(Vector3(0.0, y, z))
			if not fx.word("slam", at):
				continue
			stamped += 1
			var w: Dictionary = fx._words_by_id("slam")
			var rect := PlayerFx._word_rect(cam, w["at"], float(w["away"]) > 0.0, float(w["width_px"]), float(w["size"]), 0.01)
			if rect.intersects(drawn):
				on_ship += 1
				first_hit = "local z %.1f y %.1f word %s" % [z, y, rect]
	t.check("no word stamped over the ship's side lies on the whole drawn ship", drawn.has_area() and tried == 50 and on_ship == 0,
		"%d tried, %d stamped, %d on the ship (first %s), drawn ship %s" % [tried, stamped, on_ship, first_hit, drawn])
	quit(t.verdict())


# What the hull piece alone reports: the meshes under it, the placeholder box included.
func _mesh_rect(node: Node3D, camera: Camera3D) -> Rect2:
	var merged := [AABB(), false]
	PlayerFx._merge_meshes(node, merged)
	var span := [Vector2(INF, INF), Vector2(-INF, -INF)]
	if merged[1]:
		PlayerFx._project_box(merged[0], camera, span)
	return Rect2(span[0], span[1] - span[0]) if span[0].x <= span[1].x else Rect2()
