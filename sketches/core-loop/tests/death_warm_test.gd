extends SceneTree

# A kind's death debris boxes draw with BakeLook.unbaked twins of its body's materials, and on the
# 4080 the first use of a twin compiled its look's shader in the death frame (about 11 ms each for
# the first chaser and lobber at dam f3870, #587 comment 6509692838). BakeWarm.death_warm, run on a
# spawn warm once its kit is dressed, makes and uses those twins ahead; a later death of the kind
# draws its boxes with twins of the looks the warm made (a body paint the kit owns per enemy gets a
# twin of its own, the same look, so its shader is the one already compiled). A look here is every
# switch and texture slot of the material, the settings Godot builds a material's shader from.
# Kinds with debris boxes: lobber (6 pieces, 4 meshes) and chaser.

const T := preload("res://tests/support/t.gd")
const BakeWarm := preload("res://src/presentation/bake_warm.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

const KITS := [preload("res://src/combat/lobber.gd"), preload("res://src/combat/chaser.gd")]

var _t := T.new("death_warm_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	for kit in KITS:
		var kind := BakeWarm.kind_of(kit)
		var warm := BakeWarm.spawn_view(kit, world, null, null)
		await process_frame
		var made := BakeWarm.death_warm(warm)
		var warmed := {}
		for view in warm.get_children():
			if view is MeshInstance3D and view.mesh is BoxMesh:
				warmed[_look(view.material_override)] = true
		warm.free()
		# A live one of the kind, dressed the same way, dies later.
		var live := BakeWarm.spawn_view(kit, world, null, null)
		await process_frame
		var enemy: Node3D = live.get_child(0)
		var debris := EnemyMotion.scatter(enemy, kind, Vector3.FORWARD)
		var boxes := 0
		var found := 0
		for piece in debris.get_children() if debris != null else []:
			if piece is MeshInstance3D and piece.mesh is BoxMesh:
				boxes += 1
				if warmed.has(_look(piece.material_override)):
					found += 1
		_t.check("%s: the warm made its body's debris twins" % kind, made > 0 and warmed.size() > 0, "%d made, %d looks" % [made, warmed.size()])
		_t.check("%s: its later death's boxes draw with warmed looks" % kind, boxes > 0 and found == boxes, "%d of %d boxes" % [found, boxes])
		live.free()
	quit(_t.verdict())


# The material's switches (bools and enums, not its render priority) and which texture slots it fills.
func _look(mat: Material) -> String:
	var parts := PackedStringArray()
	for property in mat.get_property_list():
		if not int(property.usage) & PROPERTY_USAGE_STORAGE or property.name == "render_priority" or String(property.name).begins_with("resource_"):
			continue
		var value = mat.get(property.name)
		if value is bool or value is int:
			parts.append("%s=%s" % [property.name, value])
		elif property.type == TYPE_OBJECT and String(property.hint_string).contains("Texture"):
			parts.append("%s=%s" % [property.name, value != null])
	return ",".join(parts)
