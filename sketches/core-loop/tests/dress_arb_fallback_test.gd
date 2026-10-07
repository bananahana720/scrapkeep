extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Dress := preload("res://src/presentation/arena_bowl_dress.gd")
const Proof := preload("res://tests/support/arena_bowl_proof.gd")
const T := preload("res://tests/support/t.gd")
const MISSING := "res://assets/models/__arb_missing_folder__"

var t := T.new("dress_arb_fallback_test")
var game
var errors := Proof.Errors.new()


func _initialize() -> void:
	OS.add_logger(errors)
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	Harness.start_run(game)
	for folders in [[MISSING, Dress.SPILLWAY_DIR], [Dress.ASSET_DIR, MISSING], [MISSING, MISSING]]:
		Dress.asset_dir = folders[0]
		Dress.spillway_dir = folders[1]
		var before := errors.warnings.size()
		game.boss.enter_arena(Vector3(18, 0, 0))
		await physics_frame
		var arena: Node3D = game.boss.arena
		t.check("missing folder drops the whole dressing", arena.get_node_or_null("ArenaBowlDress") == null)
		Proof.check_greybox(t, arena)
		Proof.check_colliders(t, arena)
		t.eq("one warning per failed arena build", errors.warnings.size() - before, 1)
	Dress.asset_dir = Dress.ASSET_DIR
	Dress.spillway_dir = Dress.SPILLWAY_DIR
	# A surface with no material must be rejected rather than dereferenced.
	var malformed := Node3D.new()
	for part in Dress.FOUNDRY_PARTS:
		var view := MeshInstance3D.new()
		view.name = part
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().surface_get_arrays(0))
		view.mesh = mesh
		malformed.add_child(view)
		view.owner = malformed
	var packed := PackedScene.new()
	t.eq("packs malformed fixture", packed.pack(malformed), OK)
	malformed.free()
	t.eq("writes malformed fixture", ResourceSaver.save(packed, "user://arb-malformed.tscn"), OK)
	t.check("null-material surfaces fail safely", Dress.new()._parts("user://arb-malformed.tscn", Dress.FOUNDRY_PARTS).is_empty())
	game.boss.enter_arena(Vector3(18, 0, 0))
	await physics_frame
	t.check("restored assets dress the next fight", game.boss.arena.get_node_or_null("ArenaBowlDress") != null)
	t.eq("no loader errors or crashes", errors.errors, 0)
	game.free()
	OS.remove_logger(errors)
	quit(t.verdict())
