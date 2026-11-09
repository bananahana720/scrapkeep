extends SceneTree

const Game := preload("res://src/game.gd")
const DeathTips := preload("res://src/core/death_tips.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Intent := preload("res://src/movement/intent.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const Screens := preload("res://src/ui/screens.gd")
const T := preload("res://tests/support/t.gd")

# The death and summary loop (9 Nov pre-sitting pass, world 1 design findings).
#   (a) the "next shift" line (core/death_tips.gd): the rule order (a short Warden build, the
#       attack's row, the source's row, the threat type, a drawn-first body, nothing), every row's
#       form, and world 1's damage sources all answered.
#   (b) the game's path, a run store on so a death opens the summary: a Warden fight the build is
#       short for shows the gap on the tag with the fight's numbers; a grown build in the same
#       fight shows the Warden's own row; a new run clears it.
#   (c) the latch cue: Space held through a death shuts the summary; the cue stays down for
#       LATCH_CUE_AFTER, then names Space; a press the latch turns away shows it at once; it goes
#       with the release and the screen takes keys.
#   (d) the pause menu asks before Restart run and Quit: N arms the row and restarts nothing, N
#       again inside ARM_GUARD is ignored, N after it restarts; the ask lapses after ARM_SECONDS
#       and when the focus leaves; Quit asks on Enter and quits on the second; the X hold quits
#       with no ask.

const DIR := "user://death_summary_loop_test/"
const PATH := DIR + "run.json"
const WORLD_ONE := [["chaser", ""], ["lobber", ""], ["miniboss", "E03"], ["miniboss", "E04"], ["plated_brute", "E09"],
	["plated_brute", ""], ["dispatcher", ""], ["boom_tender", ""], ["rogue_crane", "E34"], ["rogue_crane", "E35"],
	["warden", ""], ["warden_counter", ""], ["silt_boil", ""], ["brindle_charge", ""], ["brindle_slag", ""]]

var _t := T.new("death_summary_loop_test")
var _game
var _quits := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_run.call_deferred()


func _run() -> void:
	_rules()
	_game = Game.new()
	_game.test_mode = true
	_game.run_store_path = PATH
	root.add_child(_game)
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = Intent.Scripted.new()
	await _frames(2)
	await _tag_on_summary()
	await _latch_cue()
	await _pause_asks()
	_game.free()
	DirAccess.remove_absolute(PATH)
	quit(_t.verdict())


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _rules() -> void:
	_t.eq("a chaser's lunge reads its row", DeathTips.line("chaser"), DeathTips.ROWS["E01"])
	_t.eq("a rogue's landed attack picks its row", DeathTips.line("rogue_crane", "E35"), DeathTips.ROWS["E35"])
	_t.eq("Brindle's charge reads its row", DeathTips.line("brindle_charge"), DeathTips.ROWS["B03"])
	_t.eq("a source with no attack row reads its own", DeathTips.line("silt_boil"), DeathTips.ROWS["silt_boil"])
	_t.eq("a later world's attack falls to its threat type", DeathTips.line("burrower"), DeathTips.BY_THREAT["threat_instant"])
	_t.eq("a body whose row is not every hit is still drawn first", DeathTips.line("line_cutter"), DeathTips.DRAWN)
	_t.eq("a hazard with no row says nothing", DeathTips.line("cinder_floor"), "")
	_t.eq("no source, no line", DeathTips.line(""), "")
	var short := {"punch": 37.0, "plating": 110.0}
	_t.eq("a short build in a Warden fight reads the gap, whatever landed", DeathTips.line("chaser", "", short),
		"Punch 37 against plating 110. Roll more scrap before the Warden: heft is punch.")
	_t.eq("a build at the ratio reads the killing hit", DeathTips.line("warden", "", {"punch": 77.0, "plating": 110.0}), DeathTips.ROWS["warden"])
	_t.check("no plating is no gap", not DeathTips.short_build({"punch": 0.0, "plating": 0.0}) and not DeathTips.short_build({}))
	_t.eq("the note as one line", DeathTips.shown(DeathTips.ROWS["E01"]), "Next shift: Ram a chaser while it crouches to lunge. The lunge never comes.")
	_t.eq("nothing to say shows nothing", DeathTips.shown(""), "")
	var lines: Array = DeathTips.ROWS.values() + DeathTips.BY_THREAT.values() + [DeathTips.DRAWN, DeathTips.GAP % [999, 999]]
	var bad := PackedStringArray()
	for said in lines:
		if said.length() > DeathTips.MAX_CHARS or not said.ends_with(".") or said.contains("!") or said.contains("\n"):
			bad.append(said)
	_t.check("every line fits one row, ends on a stop and never shouts", bad.is_empty(), " | ".join(bad))
	var keyless := PackedStringArray()
	for key in DeathTips.ROWS:
		if not EventKinds.has_attack(key) and not (key in ["warden", "warden_counter", "silt_boil"]):
			keyless.append(key)
	_t.check("every row keys an attack row or a named source", keyless.is_empty(), ", ".join(keyless))
	var silent := PackedStringArray()
	for pair in WORLD_ONE:
		if DeathTips.line(pair[0], pair[1]) == "":
			silent.append("%s %s" % [pair[0], pair[1]])
	_t.check("every world 1 damage source has a line", silent.is_empty(), ", ".join(silent))


func _start_run() -> void:
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(5)


# Dies to the Warden with the fight engaged at this heft; returns the plating that stood.
func _die_to_warden(heft: float) -> float:
	if _game.flow.state_name() == "summary":
		_game.flow.new_run()
	else:
		await _start_run()
	await _frames(5)
	_game.combat.heft_override = heft
	_game.flow._engage()
	var plating: float = _game.flow.warden_plating()
	_game.run.damage(9999.0, "warden")
	await _frames(3)
	return plating


func _tag_on_summary() -> void:
	var plating: float = await _die_to_warden(0.05)
	var screens = _game.screens
	_t.eq("the run is over", _game.flow.state_name(), "summary")
	_t.check("a short build reads the gap", _game.flow.death_tip.begins_with("Punch ") and _game.flow.death_tip.contains("against plating %d." % int(plating)),
		_game.flow.death_tip)
	_t.eq("the note says it", screens.tip_text(), "Next shift: " + _game.flow.death_tip)
	var body: PackedStringArray = screens.body_text().split("\n")
	_t.check("the screen reads pilot, cause, and the note before the choices", body.size() > 2 and body[1] == "Scrapped by the Warden."
			and body.find(screens.tip_text()) > 1 and body.find(screens.tip_text()) < body.find(""), " | ".join(body))
	await _frames(3)
	var comic: Control = screens.comic_page()
	_t.check("the comic page is still the row's first, the note beside it", comic != null and comic != screens._tip and comic.get_index() == 0
			and screens._tip.get_index() == 1 and screens._tip.global_position.x >= comic.global_position.x + comic.size.x,
		"comic %s, note at %.0f" % [comic, screens._tip.global_position.x])
	var room: Vector2 = screens._screen()
	var last: Control = screens.button_for("camp")
	_t.check("the column still ends on the screen", screens._title.global_position.y >= 0.0 and last.global_position.y + last.size.y <= room.y,
		"title top %.0f, actions end %.0f of %.0f" % [screens._title.global_position.y, last.global_position.y + last.size.y, room.y])
	_t.check("the row fits the narrowest screen", screens._comic_row.get_combined_minimum_size().x <= Screens.NARROW_W - 2.0 * Screens.SIDE,
		"%.0f px" % screens._comic_row.get_combined_minimum_size().x)
	await _die_to_warden(400.0)
	_t.eq("a grown build in the same fight reads the Warden's row", _game.flow.death_tip, DeathTips.ROWS["warden"])
	_game.flow.new_run()
	await _frames(3)
	_t.check("a new run clears the tip and the tag", _game.flow.death_tip == "" and screens.tip_text() == "",
		"tip '%s', tag '%s'" % [_game.flow.death_tip, screens.tip_text()])
	_game.combat.heft_override = -1.0


func _hold(code: int, down: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = down
	Input.parse_input_event(key)
	Input.flush_buffered_events()


func _latch_cue() -> void:
	var screens = _game.screens
	var old_run: String = _game.run.run_id
	_hold(KEY_SPACE, true)
	_game.run.damage(9999.0, "test")
	await _frames(2)
	_t.check("Space held through the death shuts the summary", _game.flow.state_name() == "summary" and _game.summary_latched,
		"flow %s latched %s" % [_game.flow.state_name(), _game.summary_latched])
	_t.eq("the game names the held input", _game.held_glyph(), "key_space")
	_t.eq("no cue in the first beat", screens.latch_cue_text(), "")
	screens._step_latch_cue(Screens.LATCH_CUE_AFTER)
	_t.eq("then the cue names Space", screens.latch_cue_text(), "Let go of Space to continue")
	var row := Rect2(screens._actions.global_position, screens._actions.size)
	_t.check("the cue lies over the dimmed actions row", row.encloses(Rect2(screens._latch_cue.position, screens._latch_cue.size))
			and is_equal_approx(screens._actions.modulate.a, Screens.LATCH_DIM), "cue at %s in %s, row alpha %.2f" % [screens._latch_cue.position, row, screens._actions.modulate.a])
	_hold(KEY_SPACE, false)
	await _frames(2)
	_t.check("the release drops the latch and the cue, and the row is back", not _game.summary_latched and screens.latch_cue_text() == ""
			and screens._actions.modulate.a == 1.0, "latched %s, cue '%s', row alpha %.2f" % [_game.summary_latched, screens.latch_cue_text(), screens._actions.modulate.a])
	_game._screen_key(KEY_N)
	await _frames(5)
	_t.check("a fresh N then starts a run", _game.run.run_id != old_run and _game.flow.in_play(), "flow %s" % _game.flow.state_name())
	old_run = _game.run.run_id
	_hold(KEY_SPACE, true)
	_game.run.damage(9999.0, "test")
	await _frames(2)
	_game._screen_key(KEY_N)
	screens._step_latch_cue(0.0)
	_t.check("a press the latch turns away shows the cue at once and starts nothing", screens.latch_cue_text() == "Let go of Space to continue"
			and _game.run.run_id == old_run, "cue '%s'" % screens.latch_cue_text())
	_hold(KEY_SPACE, false)
	await _frames(2)
	_t.eq("an input with no cap has plain words", " ".join(Screens.latch_cue_parts(_game.HELD_UNNAMED).map(func(part): return part["say"])), "Let go to continue")
	_t.eq("a pad button draws its cap", Screens.latch_cue_parts("pad_a")[1], {"cap": "pad_a", "say": Keycap.label("pad_a")})


func _key(code: int, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	root.push_input(event)


func _pause_asks() -> void:
	_game._screen_key(KEY_N)
	await _frames(5)
	var menu = _game.get_node_or_null("PauseMenu")
	while menu == null:
		await process_frame
		menu = _game.get_node_or_null("PauseMenu")
	menu.quit_chosen.connect(func(): _quits += 1)
	var run_id: String = _game.run.run_id
	menu.open()
	_key(KEY_N)
	_t.check("N arms Restart run and restarts nothing", menu.armed() == "restart" and menu.is_open() and _game.run.run_id == run_id
			and menu.row("restart").text == menu.ARM_WORDS["restart"] and menu.focused_id() == "restart",
		"armed '%s', row '%s', focus '%s'" % [menu.armed(), menu.row("restart").text, menu.focused_id()])
	_key(KEY_N)
	_t.check("N again inside the guard is not the second press", menu.armed() == "restart" and _game.run.run_id == run_id, "armed '%s'" % menu.armed())
	menu.step_arm(menu.ARM_SECONDS)
	_t.check("the ask lapses and the row reads as before", menu.armed() == "" and menu.row("restart").text == "Restart run",
		"armed '%s', row '%s'" % [menu.armed(), menu.row("restart").text])
	_key(KEY_N)
	_key(KEY_S)
	menu.step_arm(0.0)
	_t.check("moving the focus off the row drops the ask", menu.armed() == "" and menu.focused_id() == "notes", "armed '%s', focus '%s'" % [menu.armed(), menu.focused_id()])
	_key(KEY_N)
	_key(KEY_O)
	_t.check("another row's key drops the ask", menu.armed() == "" and menu.settings_open(), "armed '%s'" % menu.armed())
	_key(KEY_ESCAPE)
	menu.press("quit")
	_t.check("Quit asks first", menu.armed() == "quit" and _quits == 0 and menu.row("quit").text == menu.ARM_WORDS["quit"],
		"armed '%s', quits %d" % [menu.armed(), _quits])
	menu.step_arm(menu.ARM_GUARD)
	_key(KEY_ENTER)
	_t.check("Enter on the asking row quits", _quits == 1 and menu.armed() == "", "quits %d" % _quits)
	_key(KEY_X)
	menu.step_quit(menu.QUIT_HOLD + 0.01)
	_key(KEY_X, false)
	_t.check("the X hold quits with no ask", _quits == 2 and menu.armed() == "", "quits %d, armed '%s'" % [_quits, menu.armed()])
	_key(KEY_N)
	menu.step_arm(menu.ARM_GUARD)
	_key(KEY_N)
	await _frames(5)
	_t.check("N, then N after the guard, restarts the run", _game.run.run_id != run_id and not menu.is_open() and _game.flow.in_play() and not paused,
		"run changed %s, open %s, paused %s" % [_game.run.run_id != run_id, menu.is_open(), paused])
