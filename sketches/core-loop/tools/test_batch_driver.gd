extends RefCounted

const ChallengeDials := preload("res://src/core/challenge_dials.gd")
const Game := preload("res://src/game.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const Density := preload("res://src/presentation/density.gd")
const PickQuiet := preload("res://src/ui/pick_quiet.gd")
const Parts := preload("res://src/build/parts.gd")
const WarningBound := preload("res://src/combat/warning_bound.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const ArenaWakingDress := preload("res://src/presentation/arena_waking_dress.gd")
const DigFx := preload("res://src/presentation/dig_fx.gd")
const ArenaBowlDress := preload("res://src/presentation/arena_bowl_dress.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const WakingDress := preload("res://src/boss/waking_dress.gd")
const MindDress := preload("res://src/boss/mind_dress.gd")
const MindHand := preload("res://src/combat/mind_hand.gd")
const SpillwayScenery := preload("res://src/presentation/spillway_scenery.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const MechaMotion := preload("res://src/presentation/mecha_motion.gd")
const WorldFxGrain := preload("res://src/presentation/world_fx/world_fx_grain.gd")
const WorldFxSound := preload("res://src/presentation/world_fx/world_fx_sound.gd")
const WorldFxAnchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const ThreadGuard := preload("res://src/core/thread_guard.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const SettingsPages := preload("res://src/ui/settings_pages.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const Synergies := preload("res://src/build/synergies.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const EnemyClips := preload("res://src/presentation/enemy_clips.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Palette := preload("res://src/core/palette.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const WorldFxWord := preload("res://src/presentation/world_fx/world_fx_word.gd")
const Synth := preload("res://src/presentation/synth.gd")
const Footings := preload("res://src/world/park/footings.gd")
const RescueSite := preload("res://src/world/rescue_site.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const HighdraftScenery := preload("res://src/presentation/highdraft_scenery.gd")
const ArenaMindDress := preload("res://src/presentation/arena_mind_dress.gd")
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
var root_size := Vector2i.ZERO
var content_scale_size := Vector2i.ZERO
var content_scale_aspect := Window.CONTENT_SCALE_ASPECT_KEEP


func _init(owner: SceneTree, list: Array) -> void:
	tree = owner
	paths = list
	root_size = tree.root.size
	content_scale_size = tree.root.content_scale_size
	content_scale_aspect = tree.root.content_scale_aspect


func finish(code: int) -> void:
	_close.call_deferred(code)


# A solo run frees the test's nodes as the process exits, and what they print then (an await
# resumed on a freed node, say) is that test's output. The batch frees them the same way,
# without removing them first, before it closes the test's output. Starting the next test on
# physics_frame keeps every test's first callback in _physics_process, matching solo.
func _close(code: int) -> void:
	_reset()
	print("BATCH END %s exit=%d ms=%d" % [current, code, Time.get_ticks_msec() - started])
	worst = maxi(worst, code)
	tree.set_script(null)
	if tree.get_processed_tweens().is_empty():
		tree.physics_frame.connect(next, CONNECT_ONE_SHOT)
	else:
		# Killed tweens leave get_processed_tweens() when Godot steps process_tweens on the next frame.
		tree.process_frame.connect(func() -> void: tree.physics_frame.connect(next, CONNECT_ONE_SHOT), CONNECT_ONE_SHOT | CONNECT_DEFERRED)


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
	for tw in tree.get_processed_tweens():
		tw.kill()
	for child in tree.root.get_children():
		child.free()
	for tw in tree.get_processed_tweens():
		tw.kill()
	# The process-wide settings a test may change, back to how the process started.
	tree.paused = false
	if tree.root.size != root_size:
		tree.root.size = root_size
	if tree.root.content_scale_size != content_scale_size:
		tree.root.content_scale_size = content_scale_size
	if tree.root.content_scale_aspect != content_scale_aspect:
		tree.root.content_scale_aspect = content_scale_aspect
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = physics_ticks
	Engine.max_physics_steps_per_frame = max_steps
	Engine.max_fps = max_fps
	ChallengeDials.reset()
	Game.set_motion_statics(false)
	FlashGuard.on = false
	GraphicsPreset.reset_for_tests()
	Density.reset_for_tests()
	PickQuiet.reset_for_tests()
	Parts.reset_for_tests()
	WarningBound.reset_for_tests()
	DigScenery.reset_for_tests()
	ArenaWakingDress.reset_for_tests()
	DigFx.reset_for_tests()
	ArenaBowlDress.reset_for_tests()
	Requisition.reset_for_tests()
	WakingDress.reset_for_tests()
	MindDress.reset_for_tests()
	MindHand.reset_for_tests()
	SpillwayScenery.reset_for_tests()
	PackPressure.reset_for_tests()
	Cosmetics.reset_for_tests()
	MechaMotion.reset_for_tests()
	WorldFxGrain.reset_for_tests()
	WorldFxSound.reset_for_tests()
	WorldFxAnchor.reset_for_tests()
	ClassPreview.reset_for_tests()
	ThreadGuard.reset_for_tests()
	PlayerFx.reset_for_tests()
	ParkProps.reset_for_tests()
	Threat.reset_for_tests()
	Projectile.reset_for_tests()
	Palette.reset_for_tests()
	_clear_dir("user://test-%d" % OS.get_process_id())
	SimClock.ticks = false
	Glyphs.device = "kbm"
	SettingsPages.last_page = 0
	StageLocks.active = true
	Synergies.table = null
	EnemyMotion.headless_idle = false
	EnemyClips.headless = false
	Enemy.rim_color = Palette.ARC
	WorldFx.current = null
	WorldFxWord.quiet(false)
	Synth.score_transpose = 0
	Footings.plant_ignore_lines = false
	RescueSite.model_path = RescueSite.MODEL
	MusicRows.stem_dir = ""
	HighdraftFx.shader_dir = HighdraftFx.SHADER_DIR
	HighdraftScenery.dir = HighdraftScenery.DIR
	ArenaMindDress.dir = ArenaMindDress.DIR
	QuietGun.housing_path = QuietGun.HOUSING


static func _clear_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for folder in dir.get_directories():
		_clear_dir(path.path_join(folder))
		dir.remove(folder)
