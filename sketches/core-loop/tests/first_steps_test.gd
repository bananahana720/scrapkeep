extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")

# The FIRST-TIMER lessons (ui/first_steps.gd) on a fresh profile:
#   - the drive keys show at the ball on the drop with the word DRIVE, and say so on the bus;
#   - DRIVE_LEARNED seconds of steering takes them down and counts one use; three uses retire them;
#   - a staggered Warden shows Space Ctrl SLAM on the ground and Ctrl SLAM alone in the air;
#   - a slam at the open core counts, one far from it does not, three retire the lesson, and the
#     count persists.

# A Warden stand-in: the lesson reads only staggered() and where it stands.
class OpenCore:
	extends Node3D

	func staggered() -> bool:
		return true


var _game
var _failures := 0
var _wait := 0
var _started := false
var _prompts: Array[String] = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _words(lessons) -> Array:
	return Array(lessons.drawn_words())


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.events.prompt_shown.connect(func(verb: String): _prompts.append(verb))
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	_wait += 1
	if _wait < 3:
		return false
	var lessons = _game.hud.first_steps
	var profile = _game.hud.profile
	lessons.step(0.016)
	_report("drive shows on the drop", "roll" in lessons.shown_ids() and "DRIVE" in _words(lessons) and "roll" in _prompts,
		"shown %s, words %s, prompts %s" % [lessons.shown_ids(), _words(lessons), _prompts])
	var ball_x: float = _game.camera.cam.unproject_position(_game.player.shown_position()).x
	var placed: Array = lessons._placements()
	var row_end: float = placed[0]["at"].x + lessons.row_width(placed[0]["parts"]) if not placed.is_empty() else INF
	_report("the drive row ends left of the ball", row_end < ball_x,
		"row ends at x %.0f, ball at x %.0f (the ball verbs' prompts sit to its right)" % [row_end, ball_x])

	_game.player.intent.move = Vector2(0.0, 1.0)
	for i in int(ceil(lessons.DRIVE_LEARNED / 0.1)) + 1:
		lessons.step(0.1)
	_report("steering takes it down", not "roll" in lessons.shown_ids() and profile.uses("roll") == 1,
		"shown %s, roll uses %d" % [lessons.shown_ids(), profile.uses("roll")])
	for i in 2:
		lessons.new_run()
		for j in int(ceil(lessons.DRIVE_LEARNED / 0.1)) + 1:
			lessons.step(0.1)
	lessons.new_run()
	lessons.step(0.016)
	_report("three runs retire it", lessons.retired("roll") and not "roll" in lessons.shown_ids(),
		"roll uses %d, shown %s" % [profile.uses("roll"), lessons.shown_ids()])

	var real_warden = _game.flow.warden
	var core := OpenCore.new()
	_game.add_child(core)
	var cam: Camera3D = _game.camera.cam
	core.global_position = cam.global_position - cam.global_transform.basis.z * 12.0 - lessons.CORE_LIFT
	_game.flow.warden = core
	_game.player.state.grounded = true
	lessons.step(0.016)
	var grounded := _words(lessons)
	_game.player.state.grounded = false
	lessons.step(0.016)
	var airborne := _words(lessons)
	_report("the open core teaches the slam", "slam" in lessons.shown_ids() and grounded == ["Space", "Ctrl", "SLAM"]
		and airborne == ["Ctrl", "SLAM"] and "slam" in _prompts,
		"ground %s, air %s, prompts %s" % [grounded, airborne, _prompts])
	_game.events.slammed.emit(core.global_position + Vector3(lessons.SLAM_REACH + 1.0, 0.0, 0.0), 1.0, 1.0)
	var far_uses: int = profile.uses("slam")
	for i in 3:
		_game.events.slammed.emit(core.global_position, 1.0, 1.0)
	lessons.step(0.016)
	_report("three slams on the core retire it", far_uses == 0 and lessons.retired("slam") and not "slam" in lessons.shown_ids(),
		"a slam %.0f m off counted %d; slam uses %d, shown %s" % [lessons.SLAM_REACH + 1.0, far_uses, profile.uses("slam"), lessons.shown_ids()])
	_game.flow.warden = real_warden
	core.queue_free()
	_game.events.slammed.emit(Vector3.ZERO, 1.0, 1.0)

	var reread := UiProfile.new(_game.storage_dir)
	_report("persisted", reread.uses("roll") == 3 and reread.uses("slam") == 3,
		"a profile read back holds roll %d, slam %d (a slam with no open core adds none)" % [reread.uses("roll"), reread.uses("slam")])
	print("first_steps_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
