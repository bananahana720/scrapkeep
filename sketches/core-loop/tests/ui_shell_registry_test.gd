extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const GameMap := preload("res://src/core/game_map.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")

# The game's shape (src/core/game_map.gd). The registry is checked as data: every entry
# has a status, a parent that exists, a teaser of at most 8 words, keys that do not
# collide with the title's or the dead and summary screens', dev fields that name real
# paths, and nothing in src/ outside the registry names a placeholder entry. Then it is
# walked as the player would: every entry by its key from the title, every placeholder
# opens its page and Esc returns, every live leaf routes to class select, and the home
# and its placeholders answer the mouse (a click in, a click on Back out).

const RESERVED := [KEY_SPACE, KEY_ENTER, KEY_H, KEY_L, KEY_G, KEY_M, KEY_MINUS, KEY_EQUAL, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_O, KEY_R, KEY_N, KEY_C, KEY_T]

var _game
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _process(_delta: float) -> bool:
	if _game.flow == null or _game.get_meta("shell_test_started", false):
		return false
	_game.set_meta("shell_test_started", true)
	_run()
	return false


func _run() -> void:
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	await _frames(30)
	_check_data()
	_check_no_hardcoding()
	# Clicks first: the mouse walk needs the title's layout before any run screen has
	# grown the content column.
	await _walk_by_click()
	await _walk_by_key()
	print("ui_shell_registry_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check_data() -> void:
	var ids := {}
	var bad := PackedStringArray()
	for e in GameMap.all():
		ids[e["id"]] = true
	for e in GameMap.all():
		var id: String = e["id"]
		if e["status"] != GameMap.LIVE and e["status"] != GameMap.PLACEHOLDER:
			bad.append("%s status" % id)
		if e["parent"] != GameMap.HOME and not ids.has(e["parent"]):
			bad.append("%s parent" % id)
		if WordBudget.words_in(e["teaser"]) > GameMap.TEASER_WORDS or e["teaser"] == "":
			bad.append("%s teaser" % id)
		if String(e["note"]) == "":
			bad.append("%s note" % id)
		if (e["avenues"] as Array).size() > 3:
			bad.append("%s avenues" % id)
		var node_of_page: bool = e["parent"] != GameMap.HOME and not GameMap.is_live(e["parent"])
		if e["status"] == GameMap.LIVE and not GameMap.has_children(id) and not node_of_page and e["route"] != "start":
			bad.append("%s live leaf without a route" % id)
		if e["status"] == GameMap.PLACEHOLDER and e["route"] != "":
			bad.append("%s placeholder with a route" % id)
		for path in e["touches"]:
			if not FileAccess.file_exists("res://" + path):
				bad.append("%s touches %s (missing)" % [id, path])
	_report("registry data", bad.is_empty() and ids.size() == GameMap.all().size(),
		"%d entries; problems: %s" % [GameMap.all().size(), ", ".join(bad) if not bad.is_empty() else "none"])
	var clashes := PackedStringArray()
	var levels := {}
	for e in GameMap.all():
		levels[e["parent"]] = true
	for parent in levels:
		var seen := {}
		for e in GameMap.children(parent):
			var k: String = e["key"]
			if k == "":
				continue
			var code := OS.find_keycode_from_string(k)
			if seen.has(code) or code in RESERVED or code == KEY_NONE:
				clashes.append("%s (%s)" % [e["id"], k])
			seen[code] = true
	_report("registry keys", clashes.is_empty(), "no collisions with each other or the title, dead and summary keys; clashes: %s"
		% (", ".join(clashes) if not clashes.is_empty() else "none"))
	var wanted := ["play", "mode_run", "mode_endless", "mode_daily", "mode_mutated", "mode_challenge", "worlds", "world_1", "world_2",
		"world_3", "world_final", "pilots", "pilot_sable", "pilot_rivet", "pilot_kest", "pilot_fourth", "kit_tree", "codex", "unlocks",
		"bay_extras", "settings", "credits"]
	var missing := wanted.filter(func(id): return not ids.has(id))
	_report("registry coverage", missing.is_empty(), "every scaffolded entry is present; missing: %s" % [missing])
	var live := ["play", "mode_run", "worlds", "world_1", "pilots", "pilot_sable", "pilot_rivet", "pilot_kest", "tier_2", "tier_4"]
	var wrong := wanted.filter(func(id): return GameMap.is_live(id) != (id in live))
	_report("registry statuses", wrong.is_empty(), "live and placeholder split as scoped; wrong: %s" % [wrong])
	var unknowns := ["world_2", "world_3", "world_final", "pilot_fourth", "tier_8", "tier_16"]
	var unnamed := unknowns.filter(func(id): return GameMap.entry(id)["title"] != "???")
	_report("registry secrets", unnamed.is_empty(), "the unnamed worlds, the fourth pilot and the deep tiers read ???; named: %s" % [unnamed])


func _check_no_hardcoding() -> void:
	var offenders := PackedStringArray()
	var needles := PackedStringArray()
	# The in-run Tab codex keeps its own "codex" and "Codex"; the home entry only shares the name.
	for e in GameMap.all():
		if e["status"] == GameMap.PLACEHOLDER and e["id"] != "codex":
			needles.append('"%s"' % e["id"])
			if e["title"] != GameMap.UNKNOWN:
				needles.append('"%s"' % e["title"])
	_scan("res://src", needles, offenders)
	_report("no hard-coded entries", offenders.is_empty(), "no file under src/ but the registry names a placeholder entry; found: %s"
		% (", ".join(offenders) if not offenders.is_empty() else "none"))


func _scan(dir: String, needles: PackedStringArray, offenders: PackedStringArray) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + sub, needles, offenders)
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd") or file == "game_map.gd":
			continue
		var text := FileAccess.get_file_as_string(dir + "/" + file)
		for needle in needles:
			if text.contains(needle):
				offenders.append("%s/%s %s" % [dir, file, needle])


func _to_title() -> void:
	_game.flow.show_title()


# The path from the home screen to an entry, as ids.
func _path(id: String) -> Array:
	var out := []
	var at := id
	while at != GameMap.HOME:
		out.push_front(at)
		at = GameMap.entry(at)["parent"]
	return out


func _walk_by_key() -> void:
	var problems := PackedStringArray()
	var opened := 0
	var routed := 0
	for e in GameMap.all():
		var id: String = e["id"]
		if String(e["key"]) == "":
			continue
		_to_title()
		await _frames(2)
		var shell = _game.screens.shell_view()
		var pressed_m: bool = _game._screen_key(KEY_O)
		var here := true
		for step in _path(id):
			var k := OS.find_keycode_from_string(GameMap.entry(step)["key"])
			here = here and _game._screen_key(k)
		var action := GameMap.action(id)
		match action:
			"page":
				var ok: bool = pressed_m and here and shell.view() == "page" and shell.page.entry_id == id and shell.page.visible
				if not ok:
					problems.append("%s did not open its page" % id)
				# Esc (the key) leaves the page for the level it came from.
				var parent: String = e["parent"]
				_game._screen_key(KEY_ESCAPE)
				var back_ok: bool = shell.visible and (shell.stack.is_empty() if parent == GameMap.HOME else shell.stack.back() == parent)
				if not back_ok:
					problems.append("%s Esc did not return to %s" % [id, parent if parent != "" else "home"])
				opened += 1
			"list":
				if not (here and shell.view() == "list" and shell.stack.back() == id):
					problems.append("%s did not open its list" % id)
			"start":
				if not (here and _game.flow.state_name() == "class_select"):
					problems.append("%s did not route to class select (%s)" % [id, _game.flow.state_name()])
				routed += 1
			_:
				problems.append("%s has no action" % id)
	_report("walk by key", problems.is_empty(), "%d placeholders opened their page and Esc returned; %d live leaves routed to class select; problems: %s"
		% [opened, routed, ", ".join(problems) if not problems.is_empty() else "none"])
	_to_title()
	await _frames(2)


func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	for pressed in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		button.position = at
		button.global_position = at
		root.push_input(button, true)


func _walk_by_click() -> void:
	var problems := PackedStringArray()
	var clicked := 0
	_to_title()
	await _frames(30)
	var menu: Button = _game.screens.button_for("menu")
	if menu == null:
		problems.append("the title has no menu button")
	else:
		_click(menu)
		await _frames(3)
	var shell = _game.screens.shell_view()
	if not shell.visible:
		problems.append("a click on Menu did not open the home")
	for e in GameMap.children(GameMap.HOME):
		var id: String = e["id"]
		var button: Button = shell.button_for(id)
		if button == null:
			problems.append("%s has no button on the home" % id)
			continue
		_click(button)
		await _frames(3)
		var action := GameMap.action(id)
		var expect := "page" if action == "page" else "list"
		if shell.view() != expect or shell.stack.back() != id:
			problems.append("%s click gave %s" % [id, shell.view()])
			continue
		var out: Button = shell.page.back if shell.view() == "page" else _game.screens.shell_view()._back
		_click(out)
		await _frames(3)
		if not (shell.visible and shell.stack.is_empty()):
			problems.append("%s Back click did not return home" % id)
		clicked += 1
	# A live leaf answers the mouse too: Play, then Run.
	var play: Button = shell.button_for("play")
	if play != null:
		_click(play)
		await _frames(3)
		var run: Button = shell.button_for("mode_run")
		if run != null:
			_click(run)
			await _frames(3)
		if run == null or _game.flow.state_name() != "class_select":
			problems.append("a click on Play, then Run did not reach class select")
	_report("walk by click", problems.is_empty(), "%d home entries opened on a click and came back on a Back click; problems: %s"
		% [clicked, ", ".join(problems) if not problems.is_empty() else "none"])
