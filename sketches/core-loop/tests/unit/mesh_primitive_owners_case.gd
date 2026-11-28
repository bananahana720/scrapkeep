extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")

const NAME := "[A-Za-z0-9_]*(?:bevel|chamfer|torus|faceted_orb|append_box)[A-Za-z0-9_]*"
const DECLARATION := "(?m)^\\s*(?:static\\s+|@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*(?:func\\s+(" + NAME + ")\\s*\\(|(?:const|var)\\s+(" + NAME + ")\\s*(?::\\s*Callable\\s*)?:?=\\s*func\\b)"
const DECLARED := {
	"src/build/tier_mark.gd": ["_torus"],
	"src/combat/dispatcher.gd": ["_append_box"],
	"src/core/beacon.gd": ["_torus_mesh"],
	"src/presentation/craft/camp_craft_meshes.gd": ["add_bevel_box"],
	"src/presentation/craft/enemy_boss_craft.gd": ["_bevel_box", "_bevel_cyl", "_bevel_ring"],
	"src/presentation/craft/hero_kitbash_sculptor.gd": ["add_beveled_annulus", "add_chamfered_plate", "add_chamfered_prism"],
	"src/presentation/craft/vista_megastructures.gd": ["_append_box"],
	"src/presentation/craft_prop_meshes.gd": ["_bevel_box_masked", "_bevel_cyl_masked", "_bevel_ring", "_bevel_ring_masked", "bevel_box", "bevel_cyl", "bevel_prop_box", "bevel_prop_post"],
	"src/presentation/crafted_ball_gear.gd": ["add_beveled_box", "add_faceted_orb", "add_torus"],
	"src/presentation/destructible_kit.gd": ["chamfered"],
	"src/presentation/harpoon_physics_rig.gd": ["_add_beveled_extrusion"],
	"src/presentation/pilot_gear_kit.gd": ["_add_chamfered_box", "_add_chamfered_prism"],
	"src/presentation/recipe_props.gd": ["bevel_box"],
	"src/presentation/spillway_scenery.gd": ["_unit_bevel_block"],
	"src/presentation/world23_chunk_craft.gd": ["_add_closed_torus", "_add_faceted_orb"],
	"src/ui/class_preview.gd": ["_torus"],
}


func run(t) -> void:
	var found := {}
	var hits := SourceScan.captures(t, ["res://src", "res://tools"], DECLARATION)
	for path in hits:
		var names := []
		for row in hits[path]:
			names.append(row[1] if row[1] != "" else row[2])
		names.sort()
		found[String(path).trim_prefix("res://")] = names
	t.eq("only the listed files declare a bevel, chamfer, torus, faceted orb or box mesh primitive", found, DECLARED)
