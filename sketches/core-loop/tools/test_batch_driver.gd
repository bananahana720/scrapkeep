extends RefCounted

const ChallengeDials := preload("res://src/core/challenge_dials.gd")
const Game := preload("res://src/game.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const Density := preload("res://src/presentation/density.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const SettingsPages := preload("res://src/ui/settings_pages.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const EnemyClips := preload("res://src/presentation/enemy_clips.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Palette := preload("res://src/core/palette.gd")
const WarningBound := preload("res://src/combat/warning_bound.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const WorldFxWord := preload("res://src/presentation/world_fx/world_fx_word.gd")
const Synth := preload("res://src/presentation/synth.gd")
const Footings := preload("res://src/world/park/footings.gd")
const RescueSite := preload("res://src/world/rescue_site.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const HighdraftScenery := preload("res://src/presentation/highdraft_scenery.gd")
const ArenaMindDress := preload("res://src/presentation/arena_mind_dress.gd")
const ArenaWakingDress := preload("res://src/presentation/arena_waking_dress.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const DigFx := preload("res://src/presentation/dig_fx.gd")
const StageMap := preload("res://src/world/stage_map.gd")
const QuietGun := preload("res://src/presentation/quiet_gun.gd")
const SHIM_EXTENDS := 'extends "res://tools/test_batch_shim.gd"'

var tree: SceneTree
var paths: Array
var index := -1
var started := 0
var worst := 0
var current := ""
var quit_call := RegEx.create_from_string("(?<![\\w.])quit\\(")
var frame_func := RegEx.create_from_string("(?m)^func _(physics_)?process\\(")


var physics_ticks := Engine.physics_ticks_per_second
var max_steps := Engine.max_physics_steps_per_frame
var max_fps := Engine.max_fps
var dig_stone_dir := DigScenery.stone_dir
var dig_mech_dir := DigScenery.mech_dir
var dig_cart_dir := DigScenery.cart_dir
var dig_lamp_shader := DigFx.lamp_shader_path
var stage_surface_shader := StageMap.surface_shader_path


func _init(owner: SceneTree, list: Array) -> void:
	tree = owner
	paths = list


func finish(code: int) -> void:
	_close.call_deferred(code)


# A solo run frees the test's nodes as the process exits, and what they print then (an await
# resumed on a freed node, say) is that test's output. The batch frees them the same way,
# without removing them first, before it closes the test's output.
func _close(code: int) -> void:
	_reset()
	print("BATCH END %s exit=%d ms=%d" % [current, code, Time.get_ticks_msec() - started])
	worst = maxi(worst, code)
	next.call_deferred()


func next() -> void:
	index += 1
	if index >= paths.size():
		tree.set_script(null)
		print("BATCH DONE %d tests" % paths.size())
		tree.quit(worst)
		return
	current = paths[index]
	var source := FileAccess.get_file_as_string("res://" + current)
	var script := GDScript.new()
	var text := source.replace("extends SceneTree", SHIM_EXTENDS)  # the first line, checked by sketch-fast
	text = frame_func.sub(quit_call.sub(text, "_batch_quit(", true), "func _batch_$1process(", true)
	script.source_code = text
	print("BATCH START %s" % current)
	started = Time.get_ticks_msec()
	if script.reload() != OK:
		finish(70)
		return
	tree.set_script(script)
	if tree.has_method("_initialize"):
		tree.call("_initialize")


func _reset() -> void:
	for child in tree.root.get_children():
		child.free()
	# The process-wide settings a test may change, back to how the process started.
	tree.paused = false
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = physics_ticks
	Engine.max_physics_steps_per_frame = max_steps
	Engine.max_fps = max_fps
	ChallengeDials.reset()
	Game.set_motion_statics(false)
	FlashGuard.on = false
	if GraphicsPreset.current != "high":
		GraphicsPreset.apply("high")
	SimClock.ticks = false
	Density.live().reset()
	Density.publish_fill_scale(1.0)
	Glyphs.device = "kbm"
	SettingsPages.last_page = 0
	StageLocks.active = true
	Parts.maker_nudge_on = true
	Parts.answer_nudge_on = true
	Synergies.table = null
	EnemyMotion.headless_idle = false
	EnemyClips.headless = false
	Enemy.rim_color = Palette.ARC
	WarningBound.test_pad_scale = 1.0
	WarningBound.test_skip_hazard_merge = false
	WorldFx.current = null
	WorldFxWord.quiet(false)
	Synth.score_transpose = 0
	Footings.plant_ignore_lines = false
	RescueSite.model_path = RescueSite.MODEL
	MusicRows.stem_dir = ""
	HighdraftFx.shader_dir = HighdraftFx.SHADER_DIR
	HighdraftScenery.dir = HighdraftScenery.DIR
	ArenaMindDress.dir = ArenaMindDress.DIR
	ArenaWakingDress.stone_dir = ArenaWakingDress.STONE_DIR
	ArenaWakingDress.mech_dir = ArenaWakingDress.MECH_DIR
	DigScenery.stone_dir = dig_stone_dir
	DigScenery.mech_dir = dig_mech_dir
	DigScenery.cart_dir = dig_cart_dir
	DigFx.lamp_shader_path = dig_lamp_shader
	StageMap.surface_shader_path = stage_surface_shader
	QuietGun.housing_path = QuietGun.HOUSING
