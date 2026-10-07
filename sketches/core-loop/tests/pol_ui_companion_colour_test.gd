extends SceneTree

const Game := preload("res://src/game.gd")
const Sequence := preload("res://src/ui/ending_sequence.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("pol_ui_companion_colour_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	_check_paint(game.presentation.title_stage.companion, "title")
	var seq := Sequence.new()
	game.screens.add_child(seq)
	seq.start(game)
	seq.set_process(false)
	_check_paint(seq.companion, "ending stand-in")
	seq.free()
	var body = game.presentation.get_node("CompanionBody")
	body._rebuild(["primer_coil", "ram_prow"], "primer_coil__ram_prow")
	_check_paint(body, "live body")
	game.free()
	quit(_t.verdict())

func _check_paint(holder: Node, label: String) -> void:
	var painted := 0
	for mesh in holder.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var mat: Material = mesh.get_active_material(surface)
			if mat.resource_name != "paint":
				continue
			painted += 1
			_t.check(label + " SPIL-9 paint consumes vertex colours", mat is BaseMaterial3D and mat.vertex_color_use_as_albedo)
			var colors: PackedColorArray = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			_t.check(label + " SPIL-9 carries coloured enamel", Array(colors).any(func(c): return c.r < 0.7 or c.g < 0.7 or c.b < 0.7))
	_t.check(label + " real painted companion surface checked", painted > 0)
