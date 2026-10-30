extends SceneTree

# A kind's death debris boxes draw with BakeLook.unbaked twins of its body's materials, and on the
# 4080 the first use of a twin compiled its look's shader in the death frame (about 11 ms each for
# the first chaser and lobber at dam f3870, #587 comment 6509692838). BakeWarm.death_warm, run on a
# spawn warm once its kit is dressed, makes and uses those twins ahead; a later death of the kind
# draws its boxes with twins of the looks the warm made (a body paint the kit owns per enemy gets a
# twin of its own, the same look, so its shader is the one already compiled), at rest or killed mid
# hit-flash, when the paint glows. A look here is every
# switch and texture slot of the material, the settings Godot builds a material's shader from.
# Every kind the warm builds (BakeWarm.SPAWN_WARM).

const T := preload("res://tests/support/t.gd")
const BakeWarm := preload("res://src/presentation/bake_warm.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

var _t := T.new("death_warm_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var kits := BakeWarm.WORLD_KITS[1].filter(func(kit): return BakeWarm.kind_of(kit) in BakeWarm.SPAWN_WARM)
	_t.check("every warmed kind is under test", kits.size() == BakeWarm.SPAWN_WARM.size(), "%d of %d" % [kits.size(), BakeWarm.SPAWN_WARM.size()])
	for kit in kits:
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
		var found := _found(EnemyMotion.scatter(enemy, kind, Vector3.FORWARD), warmed)
		_t.check("%s: the warm made its body's debris twins" % kind, made > 0 and warmed.size() > 0, "%d made, %d looks" % [made, warmed.size()])
		_t.check("%s: a death at rest draws its boxes with warmed looks" % kind, found.y > 0 and found.x == found.y, "%d of %d boxes" % [found.x, found.y])
		live.free()
		# Another one killed mid hit-flash: its owned body paint glows, and its twin is copied glowing.
		var lit := BakeWarm.spawn_view(kit, world, null, null)
		await process_frame
		var hit: Node3D = lit.get_child(0)
		hit.flash()
		hit._update_flash(0.016)
		found = _found(EnemyMotion.scatter(hit, kind, Vector3.FORWARD), warmed)
		_t.check("%s: a death mid hit-flash draws its boxes with warmed looks" % kind, found.y > 0 and found.x == found.y, "%d of %d boxes" % [found.x, found.y])
		lit.free()
	quit(_t.verdict())


# Of a death's debris boxes: how many draw a warmed look (x) and how many there are (y).
func _found(debris: Node3D, warmed: Dictionary) -> Vector2i:
	var out := Vector2i.ZERO
	for piece in debris.get_children() if debris != null else []:
		if piece is MeshInstance3D and piece.mesh is BoxMesh:
			out.y += 1
			if warmed.has(_look(piece.material_override)):
				out.x += 1
	return out


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
