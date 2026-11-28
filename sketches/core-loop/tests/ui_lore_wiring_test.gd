extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const Codex := preload("res://src/core/codex.gd")
const Push := preload("res://tests/support/push.gd")

# Lore wiring rule: zone-entry exchanges follow row order, wait for advance, end on
# the interact key (never Escape or jump), dismiss at cruise speed, play once per zone per run; exchanges are silent in Warden fights and the Warden intro row plays once at engagement (wave 10 ST2). Notes show
# only saved codex discoveries, with locked empty-text rows in lore-table order.
# This exercises the real game's bus, input dispatch and rendered Notes labels.

const SETTLE_FRAMES := 12

var _game
var _bubble
var _phase := "boot"
var _frames := 0
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _next(phase: String) -> void:
	_phase = phase
	_frames = 0


func _lines(zone: String, kind: String) -> Array:
	return LoreRows.ROWS.filter(func(row): return row["zone"] == zone and row["kind"] == kind)


func _said(row: Dictionary) -> bool:
	return _bubble.visible and _bubble.text == "%s: %s" % [row["speaker"], row["text"]]


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event, true)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	root.push_input(event, true)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_frames += 1
	if _phase != "boot" and _frames < SETTLE_FRAMES:
		return false
	var spillway := _lines("1-1", "exchange")
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_bubble = _game.get_node("Workshop").bubble
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_next("entry")
		"entry":
			# A test's run has no opening, so the cold open's card starts with the stage and the
			# hello waits for it (bubble_gives_way_test). The card is not this test's subject.
			if _game.presentation.reading():
				_game.presentation.flourish.stop_all()
				_next("entry")
				return false
			_report("Spillway entry", _said(spillway[0]) and _bubble.showing(), _bubble.text)
			_bubble._process(30.0)
			_report("waits for advance", _said(spillway[0]), "simulated 30 seconds without input")
			_press("cl_jump")
			_press("ui_accept")
			_report("jump does not advance", _said(spillway[0]), _bubble.text)
			_press("cl_interact")
			_report("advance second line", _said(spillway[1]), _bubble.text)
			Push.key(root, KEY_ESCAPE)
			_report("Escape leaves the exchange alone", _said(spillway[1]), _bubble.text)
			_next("pause")
		"pause":
			_report("Escape pauses", _game.pause_toggled() or paused, "pause_toggled %s; paused %s" % [_game.pause_toggled(), paused])
			Push.key(root, KEY_ESCAPE)
			_game.player.state.velocity = Vector3(0.0, 0.0, _game.ctx.tuning.f("cruise") + 2.0)
			_bubble._process(0.016)
			_report("moving at cruise dismisses", not _bubble.visible and _bubble.text == "", "visible %s; text '%s'" % [_bubble.visible, _bubble.text])
			_game.player.state.velocity = Vector3.ZERO
			_press("cl_interact")
			_next("skipped")
		"skipped":
			_report("dismissed has no next line", not _bubble.visible and _bubble.text == "", _bubble.text)
			_game.flow.enter_stage(1, Vector3.ZERO, true)
			_next("retry")
		"retry":
			_report("same zone stays silent", not _bubble.visible and _bubble.text == "", "retry within the same run")
			_check_notes()
			_game.flow.enter_stage(2, Vector3.ZERO, false)
			_next("reach")
		"reach":
			var reach := _lines("1-2", "exchange")
			_report("Reach entry", _said(reach[0]), _bubble.text)
			_press("cl_interact")
			_report("action advances", _said(reach[1]), _bubble.text)
			_press("cl_interact")
			_report("third row in order", _said(reach[2]), _bubble.text)
			_press("cl_interact")
			_report("last line ends exchange", not _bubble.visible and _bubble.text == "", "all three lines completed")
			_game.flow.enter_stage(2, Vector3.ZERO, true)
			_next("completed")
		"completed":
			_report("completed zone stays silent", not _bubble.visible, "Reach retry within the same run")
			_game.flow.new_run()
			_next("new_run")
		"new_run":
			if _game.presentation.reading():
				_game.presentation.flourish.stop_all()
				_next("new_run")
				return false
			_report("new run restores exchange", _said(spillway[0]), _bubble.text)
			_report("note survives new run", _game.notes.note_entries()[0]["known"], "saved codex id remains known")
			var warden_intro: Dictionary = _lines("1-1", "intro")[0]
			_game.flow._read_sighting(_game.flow._warden_at)
			_report("a Warden sighted during the entry exchange waits it out", _said(spillway[0]), _bubble.text)
			_bubble.dismiss_exchange()
			_report("Warden sighting shows the Warden intro before the fight", _bubble.visible and _bubble.text == String(warden_intro["text"]), _bubble.text)
			_game.flow._engage()
			_report("Warden engagement clears the intro: no intro inside a fight", not _bubble.visible and _bubble.text == "", _bubble.text)
			_game.flow.enter_stage(2, Vector3.ZERO, false)
			_next("fight")
		"fight":
			var reach_intro: Dictionary = _lines("1-2", "intro")[0]
			_bubble.dismiss_exchange()
			_game.flow._read_sighting(_game.flow._warden_at)
			_report("stage-2 sighting shows that zone's Warden intro", _bubble.text == String(reach_intro["text"]), _bubble.text)
			_game.flow._engage()
			_report("stage-2 engagement clears it", not _bubble.visible and _bubble.text == "", _bubble.text)
			_report("no exchange during Warden fight", not _said(_lines("1-2", "exchange")[0]) and not _said(spillway[0]), "advance and entry signal cannot resume an exchange")
			_game.flow.enter_stage(2, Vector3.ZERO, true)
			_next("retry_after_fight")
		"retry_after_fight":
			_bubble.dismiss_exchange()
			_game.flow._read_sighting(_game.flow._warden_at)
			_report("a Warden intro already shown stays silent on a retry", not _bubble.visible, _bubble.text)
			print("ui_lore_wiring_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _check_notes() -> void:
	var lore_notes := LoreRows.ROWS.filter(func(row): return row["kind"] == "field_note")
	var found: Dictionary = lore_notes[0]
	_game.codex.declare({"id": found["id"], "category": "world", "name": "Field note", "text": found["text"]})
	_game.codex.mark_discovered(found["id"])
	var saved := Codex.new()
	saved.setup(_game.events, _game.run, null, _game.storage_dir)
	_report("note saved in profile codex", _game.codex.last_error == "" and saved.known(found["id"]), "fresh codex reads the discovered lore id")
	saved.free()
	var notes = _game.notes
	var entries: Array = notes.note_entries()
	_report("found note uses codex", entries[0]["known"] and entries[0]["text"] == found["text"], entries[0]["text"])
	_report("unfound text is empty", not entries[1]["known"] and entries[1]["text"] == "", str(entries[1]))
	var ordered: bool = entries.size() == lore_notes.size()
	for i in mini(entries.size(), lore_notes.size()):
		ordered = ordered and entries[i]["id"] == lore_notes[i]["id"]
	_report("notes keep row order", ordered, "%d declared note rows" % entries.size())
	_game.hold_notes(true)
	notes.show_page(notes.pages().find("notes"))
	var lines = notes._codex_page.get_child(0).get_child(0)
	_report("Notes page renders found text", notes.current_page() == "notes" and notes.tab_label() == "Notes"
			and lines.get_child_count() == entries.size() and lines.get_child(0).text.contains(found["text"]), lines.get_child(0).text)
	_report("locked line renders no lore", lines.get_child(1).text == "2. Locked"
			and not lines.get_child(1).text.contains(lore_notes[1]["text"]), lines.get_child(1).text)
	_game.hold_notes(false)
