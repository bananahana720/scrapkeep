extends SceneTree

const Game := preload("res://src/game.gd")
const Rogue := preload("res://src/combat/rogue.gd")

# The three rogue GLBs (assets/models/rogues, PR #388) as the live game assembles them: each
# spawn renders its sculpted body in the shared enemy budget with no primitive or stamp left,
# keeps its row's collider, and its work drives its bones. The hatch plates swing out from
# their outer hinges in the vented window and close when it stalks; the crane's hook and the
# tender's harpoon run out along a committed lane; the skip's bucket tips for the dump. A
# scene that breaks the contract is refused, so the primitive body takes its place.

var failures := 0
var game


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _run() -> void:
	game.ctx.calm = true
	for kind in Rogue.ROWS:
		var rogue = game.ctx.spawner.spawn_enemy(kind, Vector3(0, 40, 0))
		rogue.set_physics_process(false)
		_assembly(rogue, kind)
		if rogue._rig != null:
			_poses(rogue, kind)
		rogue._clear_telegraph()
		rogue.free()
	var empty := Node3D.new()
	_check(not Rogue._model_ok(empty, Rogue.MODELS.rogue_crane), "a scene without the contract is refused")
	empty.free()
	print("enemy_rogue_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	game.free()
	quit(0 if failures == 0 else 1)


func _assembly(rogue, kind: String) -> void:
	var tris := 0
	var vertices := 0
	var draws := 0
	var primitive := false
	for child in rogue.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		primitive = primitive or mi.mesh is PrimitiveMesh
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var indices = arrays[Mesh.ARRAY_INDEX]
			tris += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			draws += 1
	print("%s live: %d T / %d V / %d D" % [kind, tris, vertices, draws])
	_check(rogue._rig != null, kind + " loads its GLB")
	_check(tris > 0 and tris <= 8800 and vertices <= 4900 and draws == 3, kind + " fits the shared enemy budget")
	_check(not primitive and rogue.find_children("*", "Label3D", true, false).is_empty(),
		kind + " shows no primitive part or stamp")
	_check(rogue._core != null and rogue._core.name == String(Rogue.MODELS[kind].prefix) + "Core", kind + " core is the GLB hatch core")
	var shapes: Array = rogue.find_children("*", "CollisionShape3D", true, false)
	var capsule := shapes[0].shape as CapsuleShape3D if shapes.size() == 1 else null
	var row: Dictionary = Rogue.ROWS[kind]
	_check(capsule != null and is_equal_approx(capsule.radius, row.radius)
		and is_equal_approx(capsule.height, maxf(float(row.half_height) * 2.0, float(row.radius) * 2.0 + 0.01)), kind + " keeps its row's collider")


func _turn(rogue, part: String) -> float:
	var rig: Skeleton3D = rogue._rig
	return rig.get_bone_pose_rotation(rogue._bones[part]).get_euler().y


func _offset(rogue, part: String) -> Vector3:
	var rig: Skeleton3D = rogue._rig
	var index: int = rogue._bones[part]
	return rig.get_bone_pose_position(index) - rig.get_bone_rest(index).origin


func _poses(rogue, kind: String) -> void:
	rogue.state = Rogue.State.WEAK
	rogue._pose_model(0.016, 1.0)
	_check(_turn(rogue, "PlateLeft") < -0.9 and _turn(rogue, "PlateRight") > 0.9, kind + " vented: plates swing open")
	rogue.state = Rogue.State.STALK
	rogue._pose_model(0.016, 1.0)
	_check(absf(_turn(rogue, "PlateLeft")) < 0.01 and absf(_turn(rogue, "PlateRight")) < 0.01, kind + " stalking: plates shut")
	rogue._begin_attack(Vector3(0, 0, -10))
	var length: float = rogue.telegraph().length
	rogue.state = Rogue.State.STRIKE
	rogue._out = 1.0
	rogue._pose_model(0.016, 1.0)
	match kind:
		"rogue_crane":
			_check(is_equal_approx(-_offset(rogue, "Hook").z, length - 6.9), "crane sweep: the hook runs to the lane's end")
		"rogue_tender":
			_check(is_equal_approx(-_offset(rogue, "Harpoon").z, length - 6.0), "tender harpoon: the harpoon flies to the lane's end")
		"rogue_skip":
			rogue.attack = "dump"
			rogue._pose_model(0.016, 1.0)
			var tip: float = (rogue._rig as Skeleton3D).get_bone_pose_rotation(rogue._bones["Bucket"]).get_euler().x
			_check(is_equal_approx(tip, -0.7), "skip dump: the bucket tips forward")
