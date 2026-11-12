extends RefCounted

const Bindings := preload("res://src/core/bindings.gd")
const KeyGlyphs := preload("res://src/ui/key_glyphs.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

# The prompt rules of design-v3/LEGIBILITY.md section 5 over a scripted view of the ball: a
# prompt shows only on a tick its verb is ready, two at most and the higher ball state first,
# it retires after three successes (five for the smash), returns after a failed press, after 90 s
# unused and at the first availability of each run, each return lasting 3 s of ready ticks, and
# HOOK and SMASH ride it until the first bite and the first smash on the profile. The haul prompt
# wears the reel on a world line and the smash glyph on a body, E and the slingshot come through
# the same table. LET GO (the RMB keycap, a fling arrow and the words) rides a line standing on the
# world for the first three world latches of a profile only, counts toward the two-prompt limit and
# sorts below the Ctrl winch prompt. These are rule checks over a scripted view; the link from the player's
# verb_ready to the view is checked in harpoon_canon_test.

const DT := 1.0 / 60.0


class StubFlow:
	extends RefCounted

	var playing := true

	func in_play() -> bool:
		return playing


class StubGame:
	extends RefCounted

	var events
	var flow := StubFlow.new()


func run(t) -> void:
	var dir := "user://c1-prompts-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	var game := StubGame.new()
	game.events = GameEvents.new()
	var profile := UiProfile.new(dir)
	var glyphs := KeyGlyphs.new()
	glyphs.setup(game, profile)

	_only_when_ready(t, glyphs)
	_two_at_most(t, glyphs)
	_retire_and_return(t, glyphs, profile)
	_smash_retires_at_five(t, glyphs, profile)
	_words(t, glyphs, profile, game)
	_haul_waits(t, glyphs)
	_returns_count_ready_ticks(t, glyphs, profile)
	_icons_and_ball_verbs(t, glyphs)
	_let_go(t, glyphs, profile, game)
	_boost_waits_for_fast(t, glyphs, profile)

	glyphs.free()
	game.events.free()
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


static func _view(ready: Array, line := "", airborne := false, winching := false) -> Dictionary:
	var flags := {}
	for verb in KeyGlyphs.PROMPT_VERBS:
		flags[verb] = verb in ready
	return {"ready": flags, "line": line, "charging": false, "mounted": false, "airborne": airborne, "winching": winching,
		"points": {"harpoon": Vector3.ONE, "haul": Vector3.ONE, "boost": Vector3.ONE}}


# W1-77: the boost prompt stays off until the ball first reaches the fast tier in a run, then
# shows as ever (and stays even if the ball slows again); a new run holds it again. Other
# prompts are not held meanwhile.
static func _boost_waits_for_fast(t, glyphs, profile) -> void:
	_fresh(glyphs, profile)
	var slow := _view(["boost"])
	slow["tier"] = SpeedTier.CRUISE
	var slow_with_hook := _view(["boost", "harpoon"])
	slow_with_hook["tier"] = SpeedTier.CRUISE
	glyphs.step(DT, slow_with_hook)
	t.eq("the boost prompt waits while the ball is below the fast tier", glyphs.shown_verbs(), ["harpoon"])
	var fast := _view(["boost"])
	fast["tier"] = SpeedTier.FAST
	glyphs.step(DT, fast)
	t.eq("the boost prompt shows once the ball is fast", glyphs.shown_verbs(), ["boost"])
	glyphs.step(DT, slow)
	t.eq("the boost prompt stays after the ball slows", glyphs.shown_verbs(), ["boost"])
	glyphs.new_run()
	glyphs.step(DT, slow)
	t.eq("a new run holds the boost prompt again", glyphs.shown_verbs(), [])
	glyphs.step(DT, _view(["boost"]))
	t.eq("a view with no tier is not held", glyphs.shown_verbs(), ["boost"])


static func _fresh(glyphs, profile) -> void:
	profile.glyph_uses = {}
	DirAccess.remove_absolute(profile.path)
	glyphs.new_run()


static func _only_when_ready(t, glyphs) -> void:
	glyphs.new_run()
	glyphs.step(DT, _view([]))
	t.eq("nothing ready, nothing drawn", glyphs.shown_verbs(), [])
	glyphs.step(DT, _view(["boost"]))
	t.eq("a ready verb is drawn", glyphs.shown_verbs(), ["boost"])
	glyphs.step(DT, _view([]))
	t.eq("the prompt goes the tick the press would fail", glyphs.shown_verbs(), [])
	glyphs.step(DT, _view(["harpoon"]))
	t.eq("a ready harpoon is drawn", glyphs.shown_verbs(), ["harpoon"])
	glyphs.step(DT, _view(["boost"]))
	t.eq("only the ready verb is drawn", glyphs.shown_verbs(), ["boost"])


static func _two_at_most(t, glyphs) -> void:
	glyphs.new_run()
	glyphs.step(2.0, _view(["haul", "harpoon", "boost"], "body"))
	t.eq("three ready: two drawn, the line on the body first", glyphs.shown_verbs(), ["haul", "harpoon"])
	t.eq("the first of them is in the highest state", glyphs.shown[0]["state"], "line_body")
	glyphs.new_run()
	glyphs.step(2.0, _view(["haul", "harpoon", "boost"], "world"))
	t.eq("three ready on a world line: the line still wins", glyphs.shown_verbs(), ["haul", "harpoon"])
	t.eq("it is in the world-line state", glyphs.shown[0]["state"], "line_world")
	glyphs.new_run()
	glyphs.step(DT, _view(["harpoon", "boost"], "", true))
	t.eq("two ready in the air: both drawn", glyphs.shown_verbs(), ["harpoon", "boost"])


static func _retire_and_return(t, glyphs, profile) -> void:
	_fresh(glyphs, profile)
	for i in 3:
		profile.add_use("boost")
	glyphs.step(DT, _view(["boost"]))
	t.eq("the first availability of a run shows a retired prompt", glyphs.shown_verbs(), ["boost"])
	glyphs.step(3.0, _view(["boost"]))
	glyphs.step(DT, _view(["boost"]))
	t.eq("three successes retire it, after its first return has run 3 s of ready ticks", glyphs.shown_verbs(), [])
	glyphs.returned("boost")
	glyphs.step(DT, _view(["boost"]))
	t.eq("a failed press brings it back", glyphs.shown_verbs(), ["boost"])
	for i in 170:
		glyphs.step(DT, _view(["boost"]))
	t.eq("it is still there 2.8 s after the failure", glyphs.shown_verbs(), ["boost"])
	for i in 20:
		glyphs.step(DT, _view(["boost"]))
	t.eq("it is gone 3.2 s after the failure", glyphs.shown_verbs(), [])
	glyphs.record_use("boost")
	for i in 88:
		glyphs.step(1.0, _view([]))
	glyphs.step(DT, _view(["boost"]))
	t.eq("it stays retired just short of 90 s unused", glyphs.shown_verbs(), [])
	glyphs.step(2.0, _view(["boost"]))
	t.eq("90 s unused brings it back", glyphs.shown_verbs(), ["boost"])
	glyphs.step(1.0, _view(["boost"]))
	glyphs.step(DT, _view(["boost"]))
	t.eq("the 90 s return retires again after 3 s of ready ticks", glyphs.shown_verbs(), [])
	glyphs.record_use("boost")
	glyphs.step(DT, _view(["boost"]))
	t.eq("a success clears the return", glyphs.shown_verbs(), [])
	glyphs.new_run()
	glyphs.step(DT, _view(["boost"]))
	t.eq("a new run brings it back", glyphs.shown_verbs(), ["boost"])
	glyphs.step(3.0, _view(["boost"]))
	glyphs.step(DT, _view(["boost"]))
	t.eq("and it retires again after 3 s of ready ticks", glyphs.shown_verbs(), [])


static func _smash_retires_at_five(t, glyphs, profile) -> void:
	_fresh(glyphs, profile)
	glyphs.step(3.0, _view(["haul"], "body"))
	glyphs.step(DT, _view([]))
	for i in 4:
		profile.add_use("smash")
	glyphs.step(2.0, _view(["haul"], "body"))
	t.eq("four smashes do not retire the smash prompt", glyphs.shown_verbs(), ["haul"])
	glyphs.step(DT, _view([]))
	profile.add_use("smash")
	glyphs.step(2.0, _view(["haul"], "body"))
	t.eq("five smashes do", glyphs.shown_verbs(), [])
	_fresh(glyphs, profile)
	glyphs.step(3.0, _view(["haul"], "world"))
	glyphs.step(DT, _view([]))
	for i in 3:
		profile.add_use("haul")
	glyphs.step(2.0, _view(["haul"], "world"))
	t.eq("three winches retire the world-line prompt", glyphs.shown_verbs(), [])


static func _words(t, glyphs, profile, game) -> void:
	_fresh(glyphs, profile)
	glyphs.step(DT, _view(["harpoon"]))
	t.eq("HOOK rides the harpoon prompt before the first bite", Array(glyphs.drawn_words()), ["HOOK"])
	t.eq("HOOK is the LINE_ROWS word", EventKinds.LINE_ROWS["locked"]["word"], "HOOK")
	game.events.line_state_changed.emit("latched_world", null, Vector3.ZERO, "")
	t.eq("a bite counts a success on the profile", profile.uses("harpoon"), 1)
	glyphs.step(DT, _view(["harpoon"]))
	t.check("HOOK still reads on the prompt after the first bite, as what the key does", "HOOK" in glyphs.drawn_words(), "words %s" % [glyphs.drawn_words()])
	for i in 5:
		game.events.line_state_changed.emit("latched_body", null, Vector3.ZERO, "")
	glyphs.step(DT, _view(["harpoon"]))
	t.check("and the retired prompt draws no word", not "HOOK" in glyphs.drawn_words(), "words %s" % [glyphs.drawn_words()])

	_fresh(glyphs, profile)
	glyphs.step(2.0, _view(["haul"], "body"))
	t.check("SMASH rides the haul prompt on a body before the first smash", "SMASH" in glyphs.drawn_words(), "words %s" % [glyphs.drawn_words()])
	t.eq("SMASH is the LINE_ROWS word", EventKinds.LINE_ROWS["latched_body"]["word"], "SMASH")
	game.events.line_state_changed.emit("smash_committed", null, Vector3.ZERO, "")
	t.eq("a committed smash counts a smash on the profile", profile.uses("smash"), 1)
	glyphs.step(2.0, _view(["haul"], "body"))
	t.check("SMASH still reads on a body after the first smash, as what the key does", "SMASH" in glyphs.drawn_words(), "words %s" % [glyphs.drawn_words()])
	glyphs.step(2.0, _view(["haul"], "world"))
	t.check("the world-line haul prompt never carries SMASH", not "SMASH" in glyphs.drawn_words(), "words %s" % [glyphs.drawn_words()])

	# E and Space say what the key does where the ball is, before and after the prompt first retires (PF-03).
	_fresh(glyphs, profile)
	t.eq("E says MOUNT off the pylon", glyphs.word_for("interact", "", Bindings.ball_state("", false, false, false)), "MOUNT")
	t.eq("Space says JUMP on the ground", glyphs.word_for("jump", "", Bindings.ball_state("", false, false, false)), "JUMP")
	t.eq("DOUBLE JUMP in the air", glyphs.word_for("jump", "", Bindings.ball_state("", false, false, true)), "DOUBLE JUMP")
	t.eq("and SLINGSHOT on the pylon", glyphs.word_for("jump", "", Bindings.ball_state("", false, true, false)), "SLINGSHOT")
	t.eq("SLINGSHOT still while it charges there", glyphs.word_for("jump", "", glyphs._word_state("jump", {"charging": true, "mounted": true, "airborne": false, "line": ""})), "SLINGSHOT")
	for i in KeyGlyphs.RETIRE_AFTER["interact"]:
		profile.add_use("interact")
	t.eq("E still reads MOUNT after its prompt first retires", glyphs.word_for("interact", "", Bindings.ball_state("", false, false, false)), "MOUNT")
	t.eq("and Space keeps its own count", glyphs.word_for("jump", "", Bindings.ball_state("", false, false, false)), "JUMP")


static func _haul_waits(t, glyphs) -> void:
	glyphs.new_run()
	glyphs.step(1.0, _view(["haul"], "body"))
	t.eq("the haul prompt waits for the line to stand 1.5 s", glyphs.shown_verbs(), [])
	glyphs.step(0.6, _view(["haul"], "body"))
	t.eq("it shows once the line has stood 1.5 s", glyphs.shown_verbs(), ["haul"])
	glyphs.new_run()
	glyphs.step(1.0, _view(["haul"], "world"))
	glyphs.step(DT, _view(["haul"], "world", false, true))
	glyphs.step(1.0, _view(["haul"], "world"))
	t.eq("a Ctrl press restarts the wait", glyphs.shown_verbs(), [])


# A return counts down only on ticks the verb is ready; the first-availability and 90 s returns
# last at most 3 s of ready ticks, so a ready-almost-always verb does not sit on screen.
static func _returns_count_ready_ticks(t, glyphs, profile) -> void:
	_fresh(glyphs, profile)
	for i in 3:
		profile.add_use("boost")
	glyphs.step(3.0, _view(["boost"]))
	glyphs.returned("boost")
	for i in 600:
		glyphs.step(DT, _view([]))
	glyphs.step(DT, _view(["boost"]))
	t.eq("a failed press is still owed after 10 s of the verb not being ready", glyphs.shown_verbs(), ["boost"])
	for i in 170:
		glyphs.step(DT, _view(["boost"]))
	t.eq("it is still shown 2.8 s of ready ticks after the failure", glyphs.shown_verbs(), ["boost"])
	for i in 20:
		glyphs.step(DT, _view(["boost"]))
	t.eq("it is gone after 3 s of ready ticks", glyphs.shown_verbs(), [])
	_fresh(glyphs, profile)
	for i in 3:
		profile.add_use("boost")
	for i in 100:
		glyphs.step(DT, _view([]))
	for i in 170:
		glyphs.step(DT, _view(["boost"]))
	t.eq("the first return is spent on ready ticks only: shown 2.8 s in", glyphs.shown_verbs(), ["boost"])
	for i in 20:
		glyphs.step(DT, _view(["boost"]))
	t.eq("the first return retires at 3 s of ready ticks, not 3 s of the clock", glyphs.shown_verbs(), [])
	t.eq("a ready prompt of a verb used and retired stays gone for good", glyphs.retired("boost"), true)


static func _icons_and_ball_verbs(t, glyphs) -> void:
	t.eq("the haul prompt wears the reel on a world line", glyphs.icon_of("haul", "world"), Icons.REEL)
	t.eq("the haul prompt wears the smash glyph on a body", glyphs.icon_of("haul", "body"), "ab_sable_smash")
	t.eq("the mount prompt keeps its turret icon", glyphs.icon_of("interact", ""), "ab_sable_mount")
	t.eq("the slingshot prompt keeps its launch icon", glyphs.icon_of("jump", ""), "ab_sable_vault")
	t.check("the reel glyph draws, apart from the smash glyph", Icons.glyph_of(Icons.REEL) == "reel" and Icons.glyph_of(Icons.REEL) != Icons.glyph_of("ab_sable_smash"),
		"reel is %s, smash is %s" % [Icons.glyph_of(Icons.REEL), Icons.glyph_of("ab_sable_smash")])
	glyphs.new_run()
	glyphs.step(DT, _view(["interact", "harpoon", "boost"]))
	t.eq("E at the face and the harpoon fit in two; the mount prompt is not crowded out by the boost", glyphs.shown_verbs(), ["interact", "harpoon"])
	glyphs.new_run()
	glyphs.step(DT, _view(["jump"]))
	t.eq("a ready slingshot is drawn", glyphs.shown_verbs(), ["jump"])


static func _let_go(t, glyphs, profile, game) -> void:
	_fresh(glyphs, profile)
	var shown_on := []
	for latch in 4:
		game.events.line_state_changed.emit("latched_world", null, Vector3.ZERO, "")
		glyphs.step(DT, _view([], "world"))
		shown_on.append("letgo" in glyphs.shown_prompts())
		glyphs.step(DT, _view([]))
	t.eq("LET GO shows on the first three world latches and not the fourth", shown_on, [true, true, true, false])
	_fresh(glyphs, profile)
	game.events.line_state_changed.emit("latched_world", null, Vector3.ZERO, "")
	glyphs.step(DT, _view([], "world"))
	t.eq("LET GO is the RMB prompt with its words", [glyphs.shown_glyphs(), Array(glyphs.drawn_words())], [["key_rmb"], ["LET GO"]])
	glyphs.step(DT, _view([]))
	t.eq("it goes the tick the line lets go", glyphs.shown_prompts(), [])
	t.eq("LET GO is a prompt and no verb: the verbs list leaves it out", glyphs.shown_verbs(), [])
	game.events.line_state_changed.emit("latched_body", null, Vector3.ZERO, "")
	glyphs.step(DT, _view([], "body"))
	t.check("a line on a body never shows it", not "letgo" in glyphs.shown_prompts(), "shown %s" % [glyphs.shown_prompts()])
	_fresh(glyphs, profile)
	game.events.line_state_changed.emit("latched_world", null, Vector3.ZERO, "")
	glyphs.step(2.0, _view(["haul", "harpoon", "boost"], "world"))
	t.eq("with the winch prompt up, LET GO takes the second of two prompts, below it", glyphs.shown_prompts(), ["haul", "letgo"])
	t.eq("the verbs list holds the winch alone", glyphs.shown_verbs(), ["haul"])
	t.eq("the bar is told both glyphs", glyphs.shown_glyphs(), ["key_ctrl", "key_rmb"])
