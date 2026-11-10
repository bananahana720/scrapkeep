extends SceneTree

# A kind's death debris boxes draw with BakeLook.unbaked twins of its body's materials, and on the
# 4080 the first use of a twin compiled its look's shader in the death frame (about 11 ms each for
# the first chaser and lobber at dam f3870, #587 comment 6509692838). BakeWarm.death_warm, run on a
# spawn warm once its kit is dressed, makes and uses those twins ahead; a later death of the kind
# draws its boxes with twins of the looks the warm made (a body paint the kit owns per enemy gets a
# twin of its own, the same look, so its shader is the one already compiled), at rest or killed mid
# hit-flash, when the paint glows. A look here is every
# switch and texture slot of the material, the settings Godot builds a material's shader from.
# Every kind the warm stands: the ones world 1's stages can send (Director.kinds_sent).

const T := preload("res://tests/support/t.gd")
const BakeWarm := preload("res://src/presentation/bake_warm.gd")
const Director := preload("res://src/world/director.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

var _t := T.new("death_warm_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var sent := _sent()
	var kits := BakeWarm.WORLD_KITS[1].filter(func(kit): return BakeWarm.kind_of(kit) in sent)
	_t.check("every warmed kind is under test", kits.size() == sent.size(), "%d of %d" % [kits.size(), sent.size()])
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
		var found := _found(enemy, kind, warmed)
		_t.check("%s: the warm made its body's debris twins" % kind, made > 0 and warmed.size() > 0, "%d made, %d looks" % [made, warmed.size()])
		_t.check("%s: a death at rest draws its boxes with warmed looks" % kind, found.y > 0 and found.x == found.y, "%d of %d boxes" % [found.x, found.y])
		live.free()
		# Another one killed mid hit-flash: its owned body paint glows, and its twin is copied glowing.
		var lit := BakeWarm.spawn_view(kit, world, null, null)
		await process_frame
		var hit: Node3D = lit.get_child(0)
		hit.flash()
		hit._update_flash(0.016)
		found = _found(hit, kind, warmed)
		_t.check("%s: a death mid hit-flash draws its boxes with warmed looks" % kind, found.y > 0 and found.x == found.y, "%d of %d boxes" % [found.x, found.y])
		lit.free()
	quit(_t.verdict())


# Every kind world 1's stages can send on the launch table (Director.kinds_sent): the list the warm
# stands.
func _sent() -> Array:
	var out := []
	for row: Dictionary in ParkDefs.DEFS:
		if int(row["world"]) == 1:
			for kind in Director.kinds_sent(row, ParkDefs):
				if not out.has(kind):
					out.append(kind)
	return out


# Of the debris boxes a death of `enemy` throws: how many draw something already drawn (x) and how
# many there are (y). A box is drawn already when it is a twin look the warm put on a box, or when
# it is one of the body's own box parts thrown with the material the standing body drew it with (a
# kit built of boxes, the dispatcher).
func _found(enemy: Node3D, kind: String, warmed: Dictionary) -> Vector2i:
	var own := {}
	for part: MeshInstance3D in enemy.find_children("*", "MeshInstance3D", true, false):
		own[[part.mesh, part.material_override]] = true
	var debris := EnemyMotion.scatter(enemy, kind, Vector3.FORWARD)
	var out := Vector2i.ZERO
	for piece in debris.get_children() if debris != null else []:
		if piece is MeshInstance3D and piece.mesh is BoxMesh:
			out.y += 1
			if own.has([piece.mesh, piece.material_override]) or (piece.material_override != null and warmed.has(_look(piece.material_override))):
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
