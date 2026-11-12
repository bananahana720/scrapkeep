extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")

# The plating lesson (ui/first_steps.gd "plate", W1-68) on a fresh profile, with a plated brute
# at plating 30 in front of the ball:
#   - a bolt that glances off its slate rim beats the rim (enemy.flare_glance) and stretches three
#     speed lines from the ball, pointing away from the target, with no word on screen;
#   - the lines are longer for a hit that fell further short, and go after PLATE_SHOW seconds;
#   - a deflection off a target with no tint (a Warden's guard) teaches nothing;
#   - the first ram that beats the plating retires it for good, and a later glance shows nothing.

const AHEAD := 9.0

class Untinted:
	extends Node3D


var _game
var _combat
var _failures := 0
var _step := 0
var _prompts: Array[String] = []
var _dummy: Node3D


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_step += 1
	if _step == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.events.prompt_shown.connect(func(verb: String): _prompts.append(verb))
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_game.run.set_max_hp(99999.0)
		return false
	if _step == 3:
		_combat = _game.ctx.spawner
		_combat.heft_override = 1.0
		var cam: Camera3D = _game.camera.cam
		var forward := -cam.global_basis.z
		forward.y = 0.0
		var at: Vector3 = _game.player.ball_position() + forward.normalized() * AHEAD
		_dummy = _combat.spawn_enemy("plated_brute", _game.ctx.terrain.drop_point(at.x, at.z, 1.6))
		_dummy.plating = 30.0
		_dummy.hp = 1000.0
		_dummy.max_hp = 1000.0
		return false
	if _step < 6:
		return false
	if _step == 6:
		_check()
		return false
	# The rim's beat runs on the enemy's own physics ticks: let a second of them pass.
	if _step < 6 + Engine.physics_ticks_per_second:
		return false
	_check_after()
	print("first_steps_plate_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true


func _streak(lessons) -> Dictionary:
	for placed in lessons._placements():
		if placed.has("dir"):
			return placed
	return {}


func _check() -> void:
	var lessons = _game.hud.first_steps
	var profile = _game.hud.profile
	var cam: Camera3D = _game.camera.cam
	_report("fresh profile, slate target", profile.uses("plate") == 0 and _dummy.tint_state == "slate"
		and cam.get_viewport().get_visible_rect().has_point(cam.unproject_position(_dummy.global_position)),
		"plate uses %d, tint %s at punch %.1f on plating 30, target in view" % [profile.uses("plate"), _dummy.tint_state, _combat.punch_now()])

	lessons.step(0.016)
	var words_before := Array(lessons.drawn_words())
	_report("nothing before a glance", not "plate" in lessons.shown_ids(), "shown %s" % [lessons.shown_ids()])

	var ghost := Untinted.new()
	_game.add_child(ghost)
	_game.events.strike_deflected.emit(ghost, "ram", 5.0, 30.0)
	lessons.step(0.016)
	_report("a guard with no tint teaches nothing", not "plate" in lessons.shown_ids(), "shown %s" % [lessons.shown_ids()])
	ghost.queue_free()

	_combat.strike(_dummy, "arc", 14.0)
	var flaring: bool = _dummy._glance_left > 0.0
	lessons.step(0.016)
	var words_now := Array(lessons.drawn_words())
	_report("a glance shows the lesson, with no word", "plate" in lessons.shown_ids() and "plate" in _prompts and words_now == words_before,
		"shown %s, prompts %s, words %s (the drive row's alone: %s)" % [lessons.shown_ids(), _prompts, words_now, words_before])
	_report("the slate rim beats", flaring, "glance left %.2f s after the bolt" % _dummy._glance_left)
	for i in int(ceil(lessons.STREAK_GROW / 0.05)) + 1:
		lessons.step(0.05)
	var streak := _streak(lessons)
	var ball_world: Vector3 = _game.player.shown_position()
	var ground: Vector3 = ball_world - _dummy.global_position
	ground.y = 0.0
	var away: Vector2 = (cam.unproject_position(ball_world + ground.normalized()) - cam.unproject_position(ball_world)).normalized()
	_report("speed lines stretch from the ball, along the run-up away from the target", not streak.is_empty()
		and streak["dir"].dot(away) > 0.99 and float(streak["length"]) > lessons.STREAK_SHORT,
		"streak %s, away %s" % [streak, away])
	var long_len := float(streak.get("length", 0.0))

	_combat.strike(_dummy, "arc", 28.0)
	for i in int(ceil(lessons.STREAK_GROW / 0.05)) + 1:
		lessons.step(0.05)
	var near_len := float(_streak(lessons).get("length", 0.0))
	_report("a nearer miss draws shorter lines", near_len > 0.0 and near_len < long_len,
		"14 on plating 30: %.0f px; 28 on plating 30: %.0f px" % [long_len, near_len])

	for i in int(ceil(lessons.PLATE_SHOW / 0.1)) + 1:
		lessons.step(0.1)
	_report("it goes after PLATE_SHOW", not "plate" in lessons.shown_ids() and _streak(lessons).is_empty(),
		"shown %s after %.1f s" % [lessons.shown_ids(), lessons.PLATE_SHOW])


func _check_after() -> void:
	var lessons = _game.hud.first_steps
	var profile = _game.hud.profile
	_report("the rim holds slate again", _dummy._glance_left == 0.0 and _dummy.tint_state == "slate"
		and is_equal_approx(_dummy._tint_materials[0].emission_energy_multiplier, _dummy.PLATE_GLOW_SLATE),
		"glance left %.2f, tint %s, rim energy %.2f" % [_dummy._glance_left, _dummy.tint_state, _dummy._tint_materials[0].emission_energy_multiplier])

	_combat.strike(_dummy, "ram", 14.0)
	_report("beating the plating retires it", lessons.retired("plate") and profile.uses("plate") == 1,
		"ram punch 32.2 on plating 30: plate uses %d" % profile.uses("plate"))
	_combat.strike(_dummy, "arc", 14.0)
	lessons.step(0.016)
	_report("a later glance shows nothing", not "plate" in lessons.shown_ids() and _dummy._glance_left == 0.0,
		"shown %s, glance left %.2f" % [lessons.shown_ids(), _dummy._glance_left])

	var reread := UiProfile.new(_game.storage_dir)
	_report("persisted", reread.uses("plate") == 1, "a profile read back holds plate %d" % reread.uses("plate"))
