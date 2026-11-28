# smoke: solo (boots the alpha table; stage 1, the Dig, a Highdraft stage)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")

# VX-WIRE (wave 12-C): the shipped high carries set dressing and air motes while low carries none,
# a world's depth fog survives an event view rebuild and clear, the Highdraft reads its exposure
# and saturation from its look row, the Spillway and Highdraft rows name the Poly Haven sky, and
# the capture switch leaves no Label or bubble visible.
var _t := T.new("vx_wire_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


# 2026-10-17 (one day per run): an open-sky stage's fog leans toward its time of day, so the colour
# to keep is the stage look's (WorldLook.environment), not the bare world row's.
func _fog_matches(label: String, row: Dictionary, stage: int) -> void:
	var env: Environment = _game.ctx.terrain.environment
	var view = _game.world.view
	var want: Color = WorldLook.environment(WorldLook.stage_look(stage, _game.ctx.stages.world_of(stage)), false).fog_light_color
	view.rebuild(_game.world.events)
	_t.near(label + " density survives a rebuild", env.fog_density, row.fog.density)
	_t.check(label + " colour survives a rebuild", env.fog_light_color.is_equal_approx(want), "%s, want %s" % [env.fog_light_color, want])
	view.clear()
	_t.near(label + " density survives a clear", env.fog_density, row.fog.density)


func _visible_ui() -> Array:
	var shown := []
	for node in _game.find_children("*", "CanvasItem", true, false):
		if node is Control and node.is_visible_in_tree():
			shown.append(String(node.get_path()))
	for node in _game.find_children("*", "Label3D", true, false):
		if node.is_visible_in_tree():
			shown.append(String(node.get_path()))
	return shown


func _run() -> void:
	seed(280928)
	Preset.apply("high")
	_game = Game.new()
	_game.name = "Game"
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	await process_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	await _frames(10)
	_game.flow.choose_class(1)
	_game.player.source = Intent.Scripted.new()
	await _frames(30)
	var env: Environment = _game.ctx.terrain.environment

	# 1. dressing and motes follow the preset switches.
	var dressing = _game.presentation.set_dressing
	_t.check("high boots set dressing and air motes", dressing != null and not dressing.find_children("DustMotes", "MultiMeshInstance3D", true, false).is_empty()
		and not dressing.find_children("*", "MultiMeshInstance3D", true, false).is_empty())
	Preset.apply("low")
	_t.check("low boots none", _game.presentation.set_dressing == null or not is_instance_valid(_game.presentation.set_dressing)
		or _game.find_children("DustMotes", "", true, false).is_empty())
	Preset.apply("high")
	await _frames(5)

	# 4. the sky rows.
	_t.eq("Spillway row names the HDRI sky", WorldLook.ROWS[1].sky, "hdri")
	_t.eq("Highdraft row names the HDRI sky", WorldLook.ROWS[3].sky, "hdri")
	_t.eq("Dig keeps its dome", WorldLook.ROWS[2].sky, "dome")
	_t.eq("Waking pit unchanged", WorldLook.ARENAS.waking.sky, "dome")
	_t.eq("Mind unchanged", WorldLook.ARENAS.mind.sky, "own")
	# 2026-10-17 (one day per run): the HDRI sky's material is the time-of-day sky shader over the panorama.
	var material := env.sky.sky_material as ShaderMaterial if env.sky != null else null
	var panorama: Texture2D = material.get_shader_parameter("panorama") if material != null else null
	_t.check("stage 1 draws the cached HDRI sky", env.sky == PaletteMaterials.hdri_sky() and panorama != null and panorama.resource_path.ends_with(".hdr"))
	_t.check("the HDRI sky is cached once", PaletteMaterials.hdri_sky() == PaletteMaterials.hdri_sky())

	# 2. fog: the Spillway's, then the Dig's.
	_fog_matches("Spillway", WorldLook.ROWS[1], 1)
	_game.flow.enter_stage(_game.ctx.stages.first_of(2), Vector3.ZERO, false)
	await _frames(30)
	_fog_matches("Dig", WorldLook.ROWS[2], _game.ctx.stages.first_of(2))
	_t.check("the Dig keeps its dome", env.background_mode == Environment.BG_COLOR)

	# 3. the Highdraft's own exposure and saturation come from its row.
	var source := FileAccess.get_file_as_string("res://src/presentation/highdraft_scenery.gd")
	_t.check("highdraft_scenery has no exposure or saturation literal", not source.contains('"tonemap_exposure": 1.05') and not source.contains('"adjustment_saturation": 1.15'))
	var high_stage := 0
	for row in _game.ctx.stages.DEFS:
		if _game.ctx.stages.world_of(row["stage"]) == 3:
			high_stage = row["stage"]
			break
	_t.check("the table has a Highdraft stage", high_stage > 0)
	if high_stage > 0:
		_game.flow.enter_stage(high_stage, Vector3.ZERO, false)
		await _frames(30)
		_t.near("Highdraft exposure is the row's", env.tonemap_exposure, WorldLook.ROWS[3].exposure)
		_t.near("Highdraft saturation is the row's", env.adjustment_saturation, WorldLook.ROWS[3].saturation)
		_t.check("Highdraft draws the HDRI sky", env.sky == PaletteMaterials.hdri_sky())

	# 5. the capture switch.
	var anchor := Node3D.new()
	_game.add_child(anchor)
	var prompt := WorldPrompt.new()
	prompt.text = "vault"
	anchor.add_child(prompt)
	prompt.visible = true
	var bubble: Control = null
	for node in _game.get_children():
		if node is CanvasLayer and node.get("bubble") != null:
			bubble = node.bubble
	_t.check("the game's workshop owns the Moss bubble", bubble != null)
	bubble.visible = true
	var label := Label3D.new()
	anchor.add_child(label)
	_t.check("a prompt, a bubble and a Label3D can show before the switch", prompt.is_visible_in_tree() and bubble.is_visible_in_tree() and label.is_visible_in_tree())
	_game.presentation.hide_ui()
	await _frames(10)
	var shown := _visible_ui()
	_t.check("after hide_ui no Label, bubble or Control is visible", shown.is_empty(), ", ".join(shown))
	_game.free()
	quit(_t.verdict())
