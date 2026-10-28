extends RefCounted

const Palette := preload("res://src/core/palette.gd")
# Captured at the real default fight entry. Re-pinned when the bowl began to build off the tree (local
# positions, no add and subtract of its world position): the masts moved by at most 3 um, nothing else.
const COLLIDER_HASH := "1b6c977ba899b6d62171c54f852504e396f4b60ae37a1193e07fa806d71b3d52"
const ENTRY_POSITION := Vector3(-46, 64.44074, -12)

class Errors extends Logger:
	var warnings: Array[String] = []
	var errors := 0

	func _log_error(_function: String, _file: String, _line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors += 1
		elif code.begins_with("arena_bowl_dress:") or rationale.begins_with("arena_bowl_dress:"):
			warnings.append(code if not code.is_empty() else rationale)


static func collider_hash(arena: Node3D) -> String:
	var records := []
	for shape: CollisionShape3D in arena.get_node("Bowl").get_children():
		var data := {"transform": var_to_str(shape.transform), "disabled": shape.disabled, "type": shape.shape.get_class()}
		if shape.shape is ConcavePolygonShape3D:
			data.geometry = shape.shape.get_faces().to_byte_array().hex_encode().sha256_text()
			data.backface = shape.shape.backface_collision
		elif shape.shape is ConvexPolygonShape3D:
			data.geometry = shape.shape.points.to_byte_array().hex_encode().sha256_text()
		elif shape.shape is CylinderShape3D:
			data.radius = shape.shape.radius
			data.height = shape.shape.height
		elif shape.shape is BoxShape3D:
			data.size = var_to_str(shape.shape.size)
		records.append(data)
	return JSON.stringify(records).sha256_text()


static func check_colliders(t, arena: Node3D) -> void:
	var body := arena.get_node("Bowl") as StaticBody3D
	t.check("bowl collision layers and transform stay fixed", body.collision_layer == 1 and body.collision_mask == 0
		and body.transform == Transform3D.IDENTITY and arena.position.is_equal_approx(ENTRY_POSITION))
	t.eq("all 15 colliders remain", body.get_child_count(), 15)
	t.eq("base collider geometry, transforms and enabled state stay exact", collider_hash(arena), COLLIDER_HASH)


static func check_greybox(t, arena: Node3D) -> void:
	for role in ["Floor", "Bank", "RimWall", "Ramp", "Kicker"]:
		var views := arena.get_children().filter(func(n): return n is MeshInstance3D and n.get_meta("bowl_surface", "") == role)
		t.check("greybox role exists: " + role, not views.is_empty())
		for view in views:
			var material: Material = view.material_override
			t.check("greybox remains visible: " + role, view.visible and material is StandardMaterial3D)
			if material is StandardMaterial3D:
				t.check("original checker stays: " + role, not material.vertex_color_use_as_albedo
					and material.albedo_texture != null and material.albedo_texture.get_width() == 64)
	var floor_view := arena.get_node("Floor") as MeshInstance3D
	var floor_material := floor_view.material_override as StandardMaterial3D
	if floor_material != null and floor_material.albedo_texture != null:
		t.check("original charcoal floor tint stays", floor_material.albedo_texture.get_image().get_pixel(0, 0).is_equal_approx(Palette.CHARCOAL))
