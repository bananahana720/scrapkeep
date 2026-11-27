extends SceneTree

const Site := preload("res://src/world/rescue_site.gd")
const T := preload("res://tests/support/t.gd")

func _initialize() -> void:
	var t := T.new("fub_cage_fallback_test")
	Site.model_path = "res://assets/models/__fub_missing_cage.glb"
	for i in 2:
		var cage := Site.Cage.new()
		cage.spec = {"quest": "rivet"}
		cage.build()
		t.check("missing cage keeps greybox bars " + str(i), cage._bars != null and cage._bars.get_child_count() == 11)
		t.check("missing cage uses boxes " + str(i), cage._bars.get_child(0).mesh is ArrayMesh and cage._bars.get_child(0).mesh.get_surface_count() > 0)
		t.check("missing cage adds no collision " + str(i), cage.find_children("*", "CollisionObject3D", true, false).is_empty())
		cage.free()
	t.check("missing cage warning recorded", Site._warned.has(Site.model_path))
	quit(t.verdict())
