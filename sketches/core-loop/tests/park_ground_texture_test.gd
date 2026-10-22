extends SceneTree

# Gate for the park ground texture: every Terrain3D render node the park build makes carries the
# `ground` slot's two textures (floor, strata) and the auto-shader setup, not the default
# checkerboard. Headless Terrain3D draws nothing, so this asserts the resources, not pixels.

const Terrain := preload("res://src/world/terrain.gd")
const MaterialSlots := preload("res://src/presentation/material_slots.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

class Table:
	const DEFS := [{"map": "park_sinkhole", "stage": 1, "world": 1}, {"map": "park_flume", "stage": 2, "world": 1}]

class World:
	extends Node3D

var t := T.new("park_ground_texture_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var w := World.new()
	root.add_child(w)
	var camera := Camera3D.new()
	w.add_child(camera)
	camera.current = true
	var terrain := Terrain.new(Table)
	terrain.build(w)
	var row: Dictionary = MaterialSlots.row("ground")
	var want := [Palette.look_texture(row.textures.floor_map).resource_path, Palette.look_texture(row.textures.strata_map).resource_path]
	await process_frame
	var nodes: Array = w.get_children().filter(func(n): return n.name.begins_with("ParkRender"))
	t.eq("park build makes two render nodes", nodes.size(), 2)
	for stage in [1, 2]:
		terrain.use(stage)
		for node in nodes:
			_check_node(node, want, row, "stage %d %s" % [stage, node.name])
	if nodes.size() == 2:
		t.check("render nodes share one asset list", nodes[0].assets == nodes[1].assets)
	quit(t.verdict())

func _check_node(node: Node, want: Array, row: Dictionary, label: String) -> void:
	var assets: Object = node.assets
	t.check(label + " has assets", assets != null)
	if assets == null:
		return
	t.check(label + " texture list non-empty", assets.get_texture_count() > 0)
	t.eq(label + " texture count", assets.get_texture_count(), 2)
	for i in mini(2, assets.get_texture_count()):
		var tex: Object = assets.get_texture(i)
		t.eq(label + " texture %d path" % i, tex.albedo_texture.resource_path if tex.albedo_texture else "", want[i])
		t.near(label + " texture %d tile" % i, 1.0 / tex.uv_scale, float(row.triplanar_scale), 0.001)
	var material: Object = node.material
	t.check(label + " auto-shader on", material.auto_shader)
