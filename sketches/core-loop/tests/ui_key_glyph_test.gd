extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")

# The prompts are a game-level wiring check (the rules themselves are tests/unit/prompt_rules_case.gd):
#   - a fresh profile shows the harpoon prompt on a tick the harpoon is ready, with the word HOOK;
#   - three bites later it is gone, while a verb never used still shows;
#   - a committed smash counts a smash and a boost counts a boost, a drop off the pylon counts nothing;
#   - a new profile read from the same file keeps the count, so a restart remembers.

var _game
var _failures := 0
var _wait := 0
var _started := false


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
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	_wait += 1
	if _wait < 3:
		return false
	# Ensure HUD play-piece visibility catches up to flow.in_play() when choose_class()
	# causes consecutive physics ticks before the next frame's _process().
	_game.hud._process(0.016)
	var glyphs = _game.hud.key_glyphs
	var ready := {"harpoon": true, "haul": false, "boost": true, "interact": false, "jump": false}
	# Re-pinned 2026-10-10 (wave 13 unit B2): the prompts' words count only for a prompt the screen
	# draws (key_glyphs.drawn_words, so the HUD word budget matches the picture), so the anchors sit
	# 5 m ahead of the camera, in view. Was Vector3.ONE, which the drop's camera does not see.
	var cam: Camera3D = _game.camera.cam
	var ahead: Vector3 = cam.global_position - cam.global_transform.basis.z * 5.0
	var view := {"ready": ready, "line": "", "charging": false, "mounted": false, "airborne": false, "winching": false,
		"points": {"harpoon": ahead, "haul": ahead, "boost": ahead, "interact": ahead, "jump": ahead}}
	glyphs.new_run()
	glyphs.step(0.016, view)
	var fresh: Array = glyphs.shown_verbs()
	var words: Array = Array(glyphs.drawn_words())
	for i in 3:
		_game.events.line_state_changed.emit("latched_world", null, Vector3.ZERO, "")
	glyphs.step(0.016, {"ready": {"harpoon": false, "haul": false, "boost": false, "interact": false, "jump": false}, "line": "", "charging": false, "mounted": false,
		"airborne": false, "winching": false, "points": view["points"]})
	glyphs.step(0.016, view)
	var after: Array = glyphs.shown_verbs()
	_report("harpoon retires", fresh == ["harpoon", "boost"] and "HOOK" in words and after == ["boost"] and glyphs.retired("harpoon"),
		"fresh profile shows %s with %s; after 3 bites it shows %s" % [fresh, words, after])

	# W1-77: the boost prompt waits for the ball's first fast roll, or BOOST_WAIT_MAX seconds of rolling.
	var slow: Dictionary = view.duplicate()
	slow["fast"] = false
	glyphs.new_run()
	glyphs.step(0.016, slow)
	var held: bool = not "boost" in glyphs.shown_verbs()
	var waited := 0.016
	while waited < glyphs.BOOST_WAIT_MAX - 0.5:
		glyphs.step(0.5, slow)
		waited += 0.5
	var still: bool = not "boost" in glyphs.shown_verbs()
	glyphs.step(1.0, slow)
	var timed_out: bool = "boost" in glyphs.shown_verbs()
	glyphs.new_run()
	glyphs.step(0.016, slow)
	var fast: Dictionary = view.duplicate()
	fast["fast"] = true
	glyphs.step(0.016, fast)
	glyphs.step(0.016, slow)
	var after_fast: bool = "boost" in glyphs.shown_verbs()
	_report("boost waits for the first fast roll", held and still and timed_out and after_fast,
		"held at the drop %s, still held near the wait %s, shown past the wait %s, shown once fast %s" % [held, still, timed_out, after_fast])
	glyphs.new_run()

	_game.events.line_state_changed.emit("smash_committed", null, Vector3.ZERO, "")
	_game.events.boosted.emit(Vector3.ZERO)
	_game.events.mounted.emit(Vector3.ZERO, 5.0)
	_game.events.dismounted.emit(Vector3(0.0, 4.0, 9.0))
	_game.events.dismounted.emit(Vector3.ZERO)
	var profile = _game.hud.profile
	_report("successes are counted per verb", profile.uses("smash") == 1 and profile.uses("boost") == 1 and profile.uses("interact") == 1 and profile.uses("jump") == 1,
		"smash %d, boost %d, interact %d, slingshot (jump) %d" % [profile.uses("smash"), profile.uses("boost"), profile.uses("interact"), profile.uses("jump")])

	var reread := UiProfile.new(_game.storage_dir)
	_report("persisted", reread.uses("harpoon") == 3 and reread.uses("smash") == 1 and reread.path.begins_with(_game.storage_dir),
		"a profile read back from %s holds harpoon %d, smash %d" % [reread.path, reread.uses("harpoon"), reread.uses("smash")])
	print("ui_key_glyph_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
