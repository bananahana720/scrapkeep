extends SceneTree

const T := preload("res://tests/support/t.gd")
var _t := T.new("pol_dk_cache_readability_test")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://assets/models/world_one/cracked_cache.glb") as PackedScene).instantiate()
	for name_ in ["CacheChest", "CacheLid"]:
		var view := scene.find_child(name_, true, false) as MeshInstance3D
		var lifted := 0
		var total := 0
		if view != null:
			for surface in view.mesh.get_surface_count():
				var colors: PackedColorArray = view.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				for color in colors:
					total += 1
					if color.g > color.r and color.g > 0.15 and color.b > 0.10:
						lifted += 1
		var fraction := float(lifted) / maxf(total, 1)
		_t.check("DK %s primary teal panel faces are lifted" % name_, lifted >= 8, "fraction %.3f" % fraction)
	scene.free()
	quit(_t.verdict())
