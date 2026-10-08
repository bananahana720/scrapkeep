extends SceneTree

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("shell_accent_test")
	var assets := HeroAssets.new()
	var tint := Color("347fc4")
	for pilot in ["tally", "remembered_cannon"]:
		var shell := load(HeroAssets.SHELLS[pilot]).instantiate() as Node3D
		assets.paint(shell, {"class": tint})
		var accents := 0
		for mesh: MeshInstance3D in shell.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				if HeroAssets.slot_of(mesh.mesh, surface) != "class_accent":
					continue
				accents += 1
				var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
				t.check("%s accent reads pilot tint" % pilot, material != null and material.albedo_color.is_equal_approx(tint))
		t.check("%s exports a class_accent surface" % pilot, accents > 0)
		shell.free()
	assets.free()
	quit(t.verdict())
