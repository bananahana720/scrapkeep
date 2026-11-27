extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")
const Worlds := preload("res://src/core/worlds.gd")
const AppShell := preload("res://src/core/app_shell.gd")


const SCREENS := [
	{"name": "settings-display", "group": "title", "reach": "_reach_settings", "tab": 0, "ready": "_ready_settings", "what": "Settings from the title, Display tab"},
	{"name": "settings-controls", "group": "title", "reach": "_reach_settings", "tab": 1, "ready": "_ready_settings", "what": "Settings from the title, Controls tab"},
	{"name": "settings-look", "group": "title", "reach": "_reach_settings", "tab": 2, "ready": "_ready_settings", "what": "Settings from the title, Look tab"},
	{"name": "settings-feel", "group": "title", "reach": "_reach_settings", "tab": 3, "ready": "_ready_settings", "what": "Settings from the title, Feel tab"},
	{"name": "achievements", "group": "title", "reach": "_reach_achievements", "ready": "_ready_achievements", "what": "The achievements page"},
	{"name": "camp", "group": "title", "reach": "_reach_camp", "ready": "_ready_camp", "what": "The camp walk with its key strip"},
	{"name": "camp-jukebox", "group": "title", "reach": "_reach_jukebox", "ready": "_ready_jukebox", "what": "Moss's jukebox page"},
	{"name": "camp-radio", "group": "title", "reach": "_reach_radio", "ready": "_ready_radio", "what": "The radio's mixtapes page"},
	{"name": "camp-customize", "group": "title", "reach": "_reach_customize", "ready": "_ready_customize", "what": "The customize page at the lockers"},
	{"name": "companion", "group": "title", "reach": "_reach_companion", "ready": "_ready_companion", "what": "The companion panel on the title"},
	{"name": "hud-toast-card", "group": "run", "reach": "_reach_hud", "ready": "_ready_hud", "what": "The fight HUD with a toast and the kit card up"},
	{"name": "build-readout", "group": "run", "reach": "_reach_readout", "ready": "_ready_readout", "what": "The Build popup listing three fitted parts"},
	{"name": "pause-settings", "group": "run", "reach": "_reach_pause_settings", "ready": "_ready_pause_settings", "what": "Settings opened from the pause menu"},
	{"name": "shop", "group": "run", "reach": "_reach_shop", "ready": "_ready_shop", "what": "Moss's counter with a tile selected"},
	{"name": "death", "group": "run", "reach": "_reach_death", "ready": "_ready_death", "what": "The death screen"},
	{"name": "summary-loss", "group": "run", "reach": "_reach_summary_loss", "ready": "_ready_summary", "what": "The run summary after a loss"},
	{"name": "summary-win", "group": "run", "reach": "_reach_summary_win", "ready": "_ready_summary", "what": "The run summary after a win"},
]
const SELFTEST_ROW := {"name": "selftest-never", "group": "title", "reach": "_reach_nothing", "ready": "_ready_never", "what": "Planted failure"}

const WAIT_FRAMES := 240
const SETTLE_FRAMES := 40
const MIN_BYTES := 50000
const WATCHDOG := 500.0

var _out := ""
var _asked: Array = []
var _profile_mode := "fresh"
var _seed := 0
var _selftest := false
var _game
var _shots: Array = []
var _missed: Array = []
var _args := {}
var _row := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			_args[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	_selftest = _args.get("selftest", "0") == "1"
	_out = _args.get("out", "")
	_profile_mode = _args.get("profile", "fresh")
	_seed = int(_args.get("seed", "0"))
	var known := table().map(func(r): return String(r["name"]))
	var want := String(_args.get("screens", "all"))
	_asked = known.duplicate() if want == "all" else Array(want.split(",", false))
	var unknown := _asked.filter(func(n): return not known.has(n))
	if _out == "" or not _profile_mode in ["fresh", "played"] or not unknown.is_empty() or _asked.is_empty():
		printerr("ui_screens_capture: needs -- --out=<absolute dir>, --profile=fresh|played and screens from: %s%s" % [", ".join(known), (" (unknown: %s)" % ", ".join(unknown)) if not unknown.is_empty() else ""])
		quit(2)
		return
	if AppShell.headless():
		printerr("ui_screens_capture: needs a rendered display (gamescope headless backend), not --headless")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	seed(_seed)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func table() -> Array:
	var rows: Array = SCREENS.duplicate()
	if _selftest:
		rows.append(SELFTEST_ROW)
	return rows


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(30)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_seed_profile()
	var index := 0
	for row in table():
		if not _asked.has(row["name"]):
			continue
		_row = row
		if row["group"] == "title":
			await _to_title()
		else:
			await _fresh_run()
		await call(row["reach"])
		var reached := await _wait_ready(row["ready"])
		if reached:
			await _frames(SETTLE_FRAMES)
			var shot := await _save(index, row["name"])
			if shot.get("flat", false) or int(shot.get("bytes", 0)) < MIN_BYTES:
				_missed.append("%s (frame saved but %s)" % [row["name"], "flat colour" if shot.get("flat", false) else "under %d bytes" % MIN_BYTES])
			else:
				print("ui_screens_capture: %s %s %d bytes" % [row["name"], shot["file"], shot["bytes"]])
		else:
			_missed.append("%s (never settled: %s)" % [row["name"], row["ready"]])
		index += 1
	_finish()


var _clock := 0.0
var _done := false


func _process(delta: float) -> bool:
	_clock += delta
	if _clock > WATCHDOG and not _done and _game != null:
		var done := _shots.map(func(s): return s["screen"])
		for name in _asked:
			if not done.has(name) and _missed.filter(func(m): return String(m).begins_with(name)).is_empty():
				_missed.append("%s (run timed out)" % name)
		_finish()
	return false


func _finish() -> void:
	_done = true
	var info := {"profile": _profile_mode, "seed": _seed, "adapter": RenderingServer.get_video_adapter_name(), "shots": _shots, "missed": _missed}
	var file := FileAccess.open(_out.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "  "))
		file.close()
	paused = false
	if _missed.is_empty():
		print("ui_screens_capture: %d stills in %s (profile %s)" % [_shots.size(), _out, _profile_mode])
		quit(0)
	else:
		printerr("ui_screens_capture: NOT REACHED: %s" % "; ".join(_missed))
		quit(1)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait_ready(method: String) -> bool:
	for i in WAIT_FRAMES:
		if bool(call(method)):
			return true
		await process_frame
	return false


func _save(index: int, name: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var file := "%02d-%s.png" % [index, name]
	var path := _out.path_join(file)
	image.save_png(path)
	var bytes := FileAccess.get_file_as_bytes(path).size()
	var seen := {}
	for y in range(0, image.get_height(), 24):
		for x in range(0, image.get_width(), 24):
			seen[image.get_pixel(x, y).to_html(false)] = true
	var shot := {"screen": name, "file": file, "bytes": bytes, "colours": seen.size(), "flat": seen.size() < 8, "size": [image.get_width(), image.get_height()]}
	_shots.append(shot)
	return shot


func _seed_profile() -> void:
	var profile = _game.ctx.profile
	var doc := Companion.new()
	if _profile_mode == "played":
		for def in _game.flow.classes:
			profile.unlock_pilot(def.id)
		for row in Worlds.ROWS:
			profile.unlock_world(str(row["id"]))
		for id in Cosmetics.ids():
			profile.unlock_cosmetic(id)
		var at := 1793491200.0
		for id in Achievements.ids():
			profile.earn(id, at)
			at += 86400.0
		for id in TuneRows.ids():
			profile.hear_tune(id)
		for stat in ["runs", "wins", "kills", "deaths", "stages_cleared", "time", "wardens_seen"]:
			profile.set_stat(stat, 12.0)
		for piece in Companion.PIECES:
			doc.acquire(piece["id"])
		var held: Array = Companion.PIECES.map(func(p): return String(p["id"]))
		if held.size() >= 2:
			doc.assemble([held[0], held[1]])
	else:
		doc.acquire(Companion.PIECES[0]["id"])
	profile.set_companion(doc.to_dict())
	_game.run.companion = doc.to_dict()


func _to_title() -> void:
	paused = false
	var menu = _game.get_node_or_null("PauseMenu")
	if menu != null and menu.is_open():
		menu.close()
	if _game.pause_toggled():
		_game.toggle_pause()
	_game.flow.show_title()
	await _frames(20)


func _fresh_run() -> void:
	await _to_title()
	_game.bot_driven = true
	_game.get_node("Workshop").armed = true
	_game.flow.press_start()
	await _frames(10)
	_game.flow.choose_class(_seed % _game.flow.classes.size())
	await _frames(90)


func _pick_open() -> bool:
	return _game.get_node("Workshop").pick.is_open()


func _reach_settings() -> void:
	_game.screens.toggle_settings()
	await _frames(5)
	_game.screens.settings_page().show_page(int(_row["tab"]))


func _ready_settings() -> bool:
	var page = _game.screens.settings_page()
	return _game.screens.settings_open() and page.current_page() == page.PAGES[int(_row["tab"])]


func _reach_achievements() -> void:
	_game.screens.toggle_achievements()


func _ready_achievements() -> bool:
	return _game.screens.achievements_open()


func _reach_camp() -> void:
	_game.screens.toggle_camp()


func _ready_camp() -> bool:
	return _game.screens.walk_live()


func _reach_jukebox() -> void:
	_game.screens.toggle_camp()
	await _frames(40)
	_game.screens.toggle_jukebox()


func _ready_jukebox() -> bool:
	return _game.screens.jukebox_open()


func _reach_radio() -> void:
	_game.screens.toggle_camp()
	await _frames(40)
	_game.screens.toggle_radio()


func _ready_radio() -> bool:
	return _game.screens.radio_open()


func _reach_customize() -> void:
	_game.screens.toggle_camp()
	await _frames(40)
	_game.screens.walk_customize()


func _ready_customize() -> bool:
	var page = _game.screens.get("_camp")
	return page != null and page.customize != null and page.customize.visible


func _reach_companion() -> void:
	_game.get_node("Workshop").open_companion()


func _ready_companion() -> bool:
	return _game.get_node("Workshop").companion_panel.is_open()


func _reach_hud() -> void:
	_game.hud.toast_kind("world_entered", {"world": 1})
	await _frames(6)


func _ready_hud() -> bool:
	return _pick_open() and _game.flow.in_play()


func _reach_readout() -> void:
	var ws = _game.get_node("Workshop")
	ws.choose(0)
	await _frames(30)
	for part in ["sunforged_core", "chain_arc", "cross_split"]:
		_game.run.add_part(part, "capture")
	var button = ws.pick.find_child("BuildReadout", true, false)
	if button != null:
		button.pressed.emit()


func _ready_readout() -> bool:
	var button = _game.get_node("Workshop").pick.find_child("BuildReadout", true, false)
	return button != null and button.popup_visible()


func _reach_pause_settings() -> void:
	var ws = _game.get_node("Workshop")
	while _pick_open():
		ws.choose(0)
		await _frames(20)
	ws.close_all()
	await _frames(20)
	var menu = _game.get_node("PauseMenu")
	menu.open()
	await _frames(20)
	menu.press("settings")


func _ready_pause_settings() -> bool:
	return _game.get_node("PauseMenu").settings_open()


func _reach_shop() -> void:
	var ws = _game.get_node("Workshop")
	ws.close_all()
	await _frames(10)
	_game.run.cogs = 300
	_game.build.shop.enter()
	ws.open_counter()
	await _frames(20)
	ws.counter.focus_first()


func _ready_shop() -> bool:
	var counter = _game.get_node("Workshop").counter
	return counter.is_open() and counter.tiles().size() > 0 and get_root().gui_get_focus_owner() != null


func _reach_death() -> void:
	_game.get_node("Workshop").close_all()
	_game.flow._on_player_died()


func _ready_death() -> bool:
	return _game.flow.state == _game.flow.DEAD


func _reach_summary_loss() -> void:
	_game.get_node("Workshop").close_all()
	_game.flow._end_run(false)


func _reach_summary_win() -> void:
	_game.get_node("Workshop").close_all()
	_game.flow._end_run(true)


func _ready_summary() -> bool:
	return _game.flow.state == _game.flow.SUMMARY and not _game.screens.ending_open()


func _reach_nothing() -> void:
	pass


func _ready_never() -> bool:
	return false
