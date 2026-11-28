extends SceneTree

const Anchor := preload("res://src/combat/anchor_crew.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const T := preload("res://tests/support/t.gd")

func _initialize() -> void:
	var t := T.new("fub_anchor_reel_test")
	var path := "res://assets/models/world_three/enemy_anchor_crew.glb"
	var original := load(path) as PackedScene
	var scene := original.instantiate()
	scene.find_child("DeckReel", true, false).free()
	var packed := PackedScene.new()
	packed.pack(scene)
	scene.free()
	packed.take_over_path(path)
	t.check("missing DeckReel retains crew greybox", Anchor._parts().is_empty())
	t.check("repeat missing DeckReel retains greybox", Anchor._parts().is_empty())
	var anchor := Anchor.new()
	anchor._crew = MeshInstance3D.new()
	anchor.add_child(anchor._crew)
	anchor._material = PaletteMaterials.solid(Color.WHITE)
	anchor._build_tool()
	anchor._pose()
	t.check("missing DeckReel keeps visible crew", anchor._crew != null)
	t.check("missing DeckReel leaves no animated rig", anchor._windup_rig == null)
	anchor.free()
	quit(t.verdict())
