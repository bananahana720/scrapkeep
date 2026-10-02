extends RefCounted

const KeyGlyphs := preload("res://src/ui/key_glyphs.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The prompt rules of design-v3/LEGIBILITY.md section 5 over a scripted view of the ball: a
# prompt shows only on a tick its verb is ready, two at most and the higher ball state first,
# it retires after three successes (five for the smash), returns for 3 s after a failed
# press, after 90 s unused and at the first availability of each run, and HOOK and SMASH ride
# it until the first bite and the first smash on the profile.

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
	t.eq("the first availability of a run shows a retired prompt once", glyphs.shown_verbs(), ["boost"])
	glyphs.step(DT, _view([]))
	glyphs.step(DT, _view(["boost"]))
	t.eq("three successes retire it", glyphs.shown_verbs(), [])
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
	glyphs.record_use("boost")
	glyphs.step(DT, _view(["boost"]))
	t.eq("a success clears the return", glyphs.shown_verbs(), [])
	glyphs.new_run()
	glyphs.step(DT, _view(["boost"]))
	t.eq("a new run brings it back once", glyphs.shown_verbs(), ["boost"])
	glyphs.step(DT, _view([]))
	glyphs.step(DT, _view(["boost"]))
	t.eq("and only once", glyphs.shown_verbs(), [])


static func _smash_retires_at_five(t, glyphs, profile) -> void:
	_fresh(glyphs, profile)
	glyphs.step(2.0, _view(["haul"], "body"))
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
	glyphs.step(2.0, _view(["haul"], "world"))
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
	t.check("HOOK is gone after the first bite", not "HOOK" in glyphs.drawn_words(), "words %s" % [glyphs.drawn_words()])
	for i in 5:
		game.events.line_state_changed.emit("latched_body", null, Vector3.ZERO, "")
	glyphs.step(DT, _view(["harpoon"]))
	t.check("and never comes back", not "HOOK" in glyphs.drawn_words(), "words %s" % [glyphs.drawn_words()])

	_fresh(glyphs, profile)
	glyphs.step(2.0, _view(["haul"], "body"))
	t.check("SMASH rides the haul prompt on a body before the first smash", "SMASH" in glyphs.drawn_words(), "words %s" % [glyphs.drawn_words()])
	t.eq("SMASH is the LINE_ROWS word", EventKinds.LINE_ROWS["latched_body"]["word"], "SMASH")
	game.events.line_state_changed.emit("smash_committed", null, Vector3.ZERO, "")
	t.eq("a committed smash counts a smash on the profile", profile.uses("smash"), 1)
	glyphs.step(2.0, _view(["haul"], "body"))
	t.check("SMASH is gone after the first smash", not "SMASH" in glyphs.drawn_words(), "words %s" % [glyphs.drawn_words()])
	glyphs.step(2.0, _view(["haul"], "world"))
	t.check("the world-line haul prompt never carries SMASH", not "SMASH" in glyphs.drawn_words(), "words %s" % [glyphs.drawn_words()])


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
