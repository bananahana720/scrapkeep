extends SceneTree

const Game := preload("res://src/game.gd")
const DeathTips := preload("res://src/core/death_tips.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Roster := preload("res://src/combat/roster.gd")
const Intent := preload("res://src/movement/intent.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const Screens := preload("res://src/ui/screens.gd")
const T := preload("res://tests/support/t.gd")

# The death and summary loop (9 Nov pre-sitting pass, world 1 design findings).
#   (a) the "next shift" line (core/death_tips.gd): the rule order (a build that met the fight
#       short, the attack's row, the source's row, the threat type, a drawn-first body, nothing),
#       every row's form, and world 1's damage sources all answered.
#   (b) the game's path, a run store on so a death opens the summary: a Warden fight the build
#       arrived short for shows the gap on the note with the arrival's numbers, even when the
#       ball grew before it died; a build that arrived grown and was stripped by the fight
#       (scrap is armour) shows the Warden's own row; a short build entering the boss arena reads
#       the gap against the hull; a new run clears it.
#   (e) the death's picture: the comic page's last still is taken on the frame the run ends, so
#       the end screen stays down until that still is read back and comes up the frame after;
#       the moments hear of a death before the flow does, which is what makes the wait work.
#   (c) the latch cue: Space held through a death shuts the summary; the cue stays down for
#       LATCH_CUE_AFTER, then names Space; a press the latch turns away shows it at once; it goes
#       with the release and the screen takes keys.
#   (d) the pause menu asks before New run and Quit: N arms the row and restarts nothing, N
#       again inside ARM_GUARD is ignored, N after it restarts; the ask lapses after ARM_SECONDS
#       and when the focus leaves; Quit asks on Enter and quits on the second; the X hold quits
#       with no ask, and a tap of X answers a Quit row that is asking.

const DIR := "user://death_summary_loop_test/"
const PATH := DIR + "run.json"
const WORLD_ONE := [["chaser", ""], ["lobber", ""], ["miniboss", "E03"], ["miniboss", "E04"],
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
	await _still_first()
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
	var short := {"who": "the Warden", "punch": 37.0, "plating": 110.0}
	_t.eq("a short build in a Warden fight reads the gap, whatever landed", DeathTips.line("chaser", "", short),
		"Punch 37 met the Warden's plating 110. Roll up more scrap for more punch.")
	_t.eq("the gap names the boss it met", DeathTips.line("brindle_slag", "", {"who": "Admiral Brindle", "punch": 60.0, "plating": 110.0}),
		"Punch 60 met Admiral Brindle's plating 110. Roll up more scrap for more punch.")
	_t.eq("the brute reads its own row, slam or hurl", DeathTips.line("plated_brute"), DeathTips.ROWS["plated_brute"])
	_t.eq("a build at the ratio reads the killing hit", DeathTips.line("warden", "", {"punch": 77.0, "plating": 110.0}), DeathTips.ROWS["warden"])
	_t.check("no plating is no gap", not DeathTips.short_build({"punch": 0.0, "plating": 0.0}) and not DeathTips.short_build({}))
	_t.eq("the note as one line", DeathTips.shown(DeathTips.ROWS["E01"]), "Next shift: Ram a chaser while it crouches to lunge. The lunge never comes.")
	_t.eq("nothing to say shows nothing", DeathTips.shown(""), "")
	var lines: Array = DeathTips.ROWS.values() + DeathTips.BY_THREAT.values() + [DeathTips.DRAWN, DeathTips.GAP % [999, "Admiral Brindle", 999]]
	var bad := PackedStringArray()
	for said in lines:
		if said.length() > DeathTips.MAX_CHARS or not said.ends_with(".") or said.contains("!") or said.contains("\n"):
			bad.append(said)
	_t.check("every line fits one row, ends on a stop and never shouts", bad.is_empty(), " | ".join(bad))
	var keyless := PackedStringArray()
	for key in DeathTips.ROWS:
		if not EventKinds.has_attack(key) and not (key in ["warden", "warden_counter", "silt_boil", "plated_brute"]):
			keyless.append(key)
	_t.check("every row keys an attack row or a named source", keyless.is_empty(), ", ".join(keyless))
	var silent := PackedStringArray()
	for pair in WORLD_ONE:
		if DeathTips.line(pair[0], pair[1]) == "":
			silent.append("%s %s" % [pair[0], pair[1]])
	_t.check("every world 1 damage source has a line", silent.is_empty(), ", ".join(silent))
	# NAMES.md: name the machine. The cause line and the tip both say the roster's own name for the
	# machine, and neither says "miniboss".
	var unnamed := PackedStringArray()
	for id in ["E03", "E04"]:
		var machine := Roster.name_of(String(EventKinds.attack_row(id)["owner"])).to_lower()
		for said in [String(EventKinds.attack_row(id)["label"]), String(DeathTips.ROWS[id])]:
			if not said.to_lower().contains(machine) or said.to_lower().contains("miniboss"):
				unnamed.append("%s: %s" % [id, said])
	_t.check("the leap slam and the charge name their machine", unnamed.is_empty() and not Roster.name_of("miniboss").to_lower().contains("miniboss"), " | ".join(unnamed))


func _start_run() -> void:
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(5)


# Dies to the Warden having met the fight at `heft`, and at `dying` heft when the hit lands (the
# same when not given); returns the plating that stood.
func _die_to_warden(heft: float, dying := -1.0) -> float:
	if _game.flow.state_name() == "summary":
		_game.flow.new_run()
	else:
		await _start_run()
	await _frames(5)
	_game.combat.heft_override = heft
	_game.flow._engage()
	var plating: float = _game.flow.warden_plating()
	if dying >= 0.0:
		_game.combat.heft_override = dying
	_game.run.damage(9999.0, "warden")
	await _frames(3)
	return plating


func _tag_on_summary() -> void:
	var plating: float = await _die_to_warden(0.05)
	var screens = _game.screens
	_t.eq("the run is over", _game.flow.state_name(), "summary")
	_t.check("a short build reads the gap", _game.flow.death_tip.begins_with("Punch ") and _game.flow.death_tip.contains("met the Warden's plating %d." % int(plating)),
		_game.flow.death_tip)
	_t.eq("the note says it", screens.tip_text(), "Next shift: " + _game.flow.death_tip)
	var body: PackedStringArray = screens.body_text().split("\n")
	_t.check("the screen reads pilot, cause, and the note before the choices", body.size() > 2 and body[1] == "Scrapped by the Warden."
			and body.find(screens.tip_text()) > 1 and body.find(screens.tip_text()) < body.find(""), " | ".join(body))
	await _frames(3)
	var words: Array = []
	for group in screens._stats.get_children():
		for cell in group.get_child(group.get_child_count() - 1).get_children():
			words.append((cell.get_child(1) as Label).text)
	_t.check("each of the summary's stats has its word under its icon, and the word says what it counts",
		words == ["TIME", "STAGES", "CLOCKED OUT", "SCRAP", "PARTS BOLTED ON"], str(words))
	var saved: Dictionary = _game.run.summary()
	saved["save_used"] = 1
	var saved_words: Array = screens.summary_chips(saved, _game.ctx.stages.COUNT).map(func(chip): return String(chip[2]))
	_t.check("the earned save shows only on a run that used it", not words.has("SAVE USED") and saved_words.back() == "save used" and saved_words.size() == words.size() + 1,
		str(saved_words))
	var comic: Control = screens.comic_page()
	var floor_y: float = screens._screen().y - 8.0
	_t.check("the summary's column is on the screen, title to buttons", screens._title.get_global_rect().position.y >= 0.0
			and screens._actions.get_global_rect().end.y <= floor_y and not screens._choices.visible,
		"title from %.0f, buttons to %.0f of %.0f" % [screens._title.get_global_rect().position.y, screens._actions.get_global_rect().end.y, floor_y])
	_t.check("a body past three lines takes its extra lines from the comic page, down to a floor", is_equal_approx(screens.comic_height(900.0, 3, 33.0), 450.0)
			and is_equal_approx(screens.comic_height(900.0, 5, 33.0), 384.0) and is_equal_approx(screens.comic_height(900.0, 1, 33.0), 450.0)
			and is_equal_approx(screens.comic_height(900.0, 40, 33.0), screens.COMIC_MIN_HEIGHT), "comic_height")
	# The real path: a long shift board line lands on the summary after the page (a first win
	# with every stamp at once), and the page gives up the height so the buttons stay on screen.
	var short_page: float = comic.custom_minimum_size.y
	var body_before: String = screens._body.text
	screens._body.text = "Sable\nScrapped by the Warden.\nThe Fleet filed it as weather.\nShift board: CLOCKED IN Clocked In. LOGGED First Warden. HIRED Rivet, Tarn. FOUND the Lost Tape, in the wall."
	screens._fit_comic()
	await _frames(3)
	var long_lines: int = screens._body.get_line_count()
	_t.check("a long body shrinks the page it shares the column with, and the buttons stay on the screen", long_lines >= 5
			and comic.custom_minimum_size.y < short_page and screens._actions.get_global_rect().end.y <= floor_y and screens._title.get_global_rect().position.y >= 0.0,
		"%d lines, page %.0f from %.0f, buttons to %.0f of %.0f" % [long_lines, comic.custom_minimum_size.y, short_page, screens._actions.get_global_rect().end.y, floor_y])
	screens._body.text = body_before
	screens._fit_comic()
	await _frames(2)
	var chase: Control = screens._chase
	_t.check("the comic page stands between the chase plate and the note", comic != null and comic != screens._tip and comic != chase
			and chase != null and chase.get_index() == 0 and comic.get_index() == 1 and screens._tip.get_index() == 2
			and chase.global_position.x + chase.size.x <= comic.global_position.x and screens._tip.global_position.x >= comic.global_position.x + comic.size.x,
		"chase %s, comic %s, note at %.0f" % [chase, comic, screens._tip.global_position.x])
	var room: Vector2 = screens._screen()
	var last: Control = screens.button_for("camp")
	_t.check("the column still ends on the screen", screens._title.global_position.y >= 0.0 and last.global_position.y + last.size.y <= room.y,
		"title top %.0f, actions end %.0f of %.0f" % [screens._title.global_position.y, last.global_position.y + last.size.y, room.y])
	_t.check("the row fits the narrowest screen", screens._comic_row.get_combined_minimum_size().x <= Screens.NARROW_W - 2.0 * Screens.SIDE,
		"%.0f px" % screens._comic_row.get_combined_minimum_size().x)
	await _die_to_warden(400.0)
	_t.eq("a grown build in the same fight reads the Warden's row", _game.flow.death_tip, DeathTips.ROWS["warden"])
	await _die_to_warden(400.0, 0.05)
	_t.eq("a grown build the fight stripped still reads the Warden's row", _game.flow.death_tip, DeathTips.ROWS["warden"])
	await _die_to_warden(0.05, 400.0)
	_t.check("a build that met the fight short reads the gap, whatever it weighed at the end", _game.flow.death_tip.begins_with("Punch "), _game.flow.death_tip)
	await _stripped_by_the_fight()
	await _die_to_the_boss()
	_game.flow.new_run()
	await _frames(3)
	_t.check("a new run clears the tip and the tag", _game.flow.death_tip == "" and screens.tip_text() == "",
		"tip '%s', tag '%s'" % [_game.flow.death_tip, screens.tip_text()])
	_game.combat.heft_override = -1.0


# The real armour path, no override: a ball heavy with scrap meets the Warden, one hit strips the
# scrap and takes the hull, and the tip still reads the build that arrived.
func _stripped_by_the_fight() -> void:
	_game.flow.new_run()
	await _frames(5)
	_game.combat.heft_override = -1.0
	_game.run.mass = 20000.0
	_game.flow._engage()
	var met: float = _game.flow._arrival["punch"]
	_game.run.damage(99999.0, "warden")
	await _frames(3)
	_t.check("armour stripped by the killing hit does not read as a short build", _game.run.mass < 1.0 and _game.flow.death_tip == DeathTips.ROWS["warden"],
		"met at punch %.0f, mass at death %.0f, tip '%s'" % [met, _game.run.mass, _game.flow.death_tip])


# A short build enters the boss arena and dies there: the gap names the boss and its hull plating.
func _die_to_the_boss() -> void:
	_game.flow.new_run()
	await _frames(5)
	_game.combat.heft_override = 0.05
	_game.flow.enter_boss(Vector3.ZERO)
	await _frames(3)
	var hull: float = _game.flow._arrival.get("plating", 0.0)
	_game.combat.heft_override = 400.0
	_game.run.damage(99999.0, "brindle_slag")
	await _frames(3)
	_t.check("a short build at the boss reads the gap against the hull", hull > 0.0
			and _game.flow.death_tip.contains("met Admiral Brindle's plating %d." % int(hull)), "hull %.0f, tip '%s'" % [hull, _game.flow.death_tip])
	_game.combat.heft_override = -1.0


# A headless run takes no stills, so the pending one is planted and the end screen is asked to
# come up again, as the death's own flow change asks it.
func _still_first() -> void:
	var screens = _game.screens
	var heard: Array = []
	for row in _game.events.player_died.get_connections():
		var who = row["callable"].get_object()
		if who == _game.run_moments or who == _game.flow:
			heard.append("moments" if who == _game.run_moments else "flow")
	_t.eq("the moments hear of a death before the flow ends the run on it", heard, ["moments", "flow"])
	_game.flow.new_run()
	await _frames(5)
	_game.run.damage(99999.0, "chaser")
	await _frames(2)
	_t.check("with no still to wait for the end screen comes up with the death", _game.flow.state_name() == "summary" and screens.visible
			and not _game.run_moments.still_pending(), "state %s, up %s" % [_game.flow.state_name(), screens.visible])
	_game.run_moments._grabs_pending = 1
	screens._on_flow_changed("summary")
	var held: bool = not screens.visible
	await _frames(3)
	_t.check("the end screen stays down while the run's last still is being taken", held and not screens.visible and _game.run_moments.still_pending(),
		"down at once %s, down three frames on %s" % [held, not screens.visible])
	_game.run_moments._grabs_pending = 0
	await _frames(2)
	_t.check("and comes up once the still is read back", screens.visible and screens.tip_text() != "" and screens._actions.get_child_count() > 0,
		"up %s, tip '%s', actions %d" % [screens.visible, screens.tip_text(), screens._actions.get_child_count()])
	_game.flow.new_run()
	await _frames(5)


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
	_t.check("N arms New run and restarts nothing", menu.armed() == "restart" and menu.is_open() and _game.run.run_id == run_id
			and menu.row("restart").text == menu.ARM_WORDS["restart"] and menu.focused_id() == "restart",
		"armed '%s', row '%s', focus '%s'" % [menu.armed(), menu.row("restart").text, menu.focused_id()])
	_key(KEY_N)
	_t.check("N again inside the guard is not the second press", menu.armed() == "restart" and _game.run.run_id == run_id, "armed '%s'" % menu.armed())
	menu.step_arm(menu.ARM_SECONDS)
	_t.check("the ask lapses and the row reads as before", menu.armed() == "" and menu.row("restart").text == "New run",
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
	menu.press("quit")
	_key(KEY_X)
	_key(KEY_X, false)
	_t.check("a tap of X inside the guard is not the second press", _quits == 2 and menu.armed() == "quit", "quits %d, armed '%s'" % [_quits, menu.armed()])
	menu.step_arm(menu.ARM_GUARD)
	_key(KEY_X)
	menu.step_quit(menu.QUIT_HOLD + 0.01)
	_key(KEY_X, false)
	_t.check("a tap of X on the asking Quit row quits, once", _quits == 3 and menu.armed() == "", "quits %d, armed '%s'" % [_quits, menu.armed()])
	_key(KEY_N)
	menu.step_arm(menu.ARM_GUARD)
	_key(KEY_N)
	await _frames(5)
	_t.check("N, then N after the guard, restarts the run", _game.run.run_id != run_id and not menu.is_open() and _game.flow.in_play() and not paused,
		"run changed %s, open %s, paused %s" % [_game.run.run_id != run_id, menu.is_open(), paused])
