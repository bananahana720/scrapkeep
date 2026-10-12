extends SceneTree

const Game := preload("res://src/game.gd")
const Hero := preload("res://src/presentation/hero_assets.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const T := preload("res://tests/support/t.gd")
var t := T.new("pilot_clip_runtime_lookup_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	await process_frame
	var hero = game.presentation.hero_assets
	for class_id in Hero.PILOTS:
		game.player.fit_class(ClassDef.by_id(class_id))
		hero._process(0.0)
		var rec: Dictionary = hero.shell_of(game.player)
		var motion = rec.mecha
		var pod: Node3D = rec.pod
		var core: Node3D = rec.core
		t.eq(class_id + " resolves the fitted Core", motion._node("Core"), core)
		for clip in ["cast_special", "cast_line"]:
			var control: String = motion.cast_control(class_id, clip)
			var found: Node3D = motion._node("Control." + control)
			t.check(class_id + " finds " + control, found != null)
			print("RUNTIME_CONTROL class=%s clip=%s request=Control.%s found=%s" % [class_id, clip, control, found.get_path() if found != null else "ABSENT"])
		print("RUNTIME_SKIPS class=%s searched=%s + %s lines=%s" % [class_id, pod.get_path(), core.get_path(), motion.skip_lines])
		t.check(class_id + " never skips Core", not "SKIP control Core" in motion.skip_lines)
	t.eq("stated check count", t.checks + 1, 25)
	game.queue_free()
	quit(t.verdict())
