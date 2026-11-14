extends "res://tools/self_play.gd"
# Scratch (untracked): ultrawide-fill stills and films from the launched game, played by self_play.gd with keys and eyes.
#   godot --path sketches/core-loop --fixed-fps 90 ... -- --self-play --self-play-script=res://tools/uwcap.gd
#     --self-play-keys=1 --self-play-eyes=1 --self-play-until=win --self-play-hold=9999 --self-play-pilot=pylon_engineer
#     --uw-out=<abs dir> [--uw-film=1] [--uw-hold=1]
# It takes a still at each of the twelve moments with the window size, the root viewport's visible rect and the image size
# printed beside it, and a dump of every visible Control's rect. --uw-film=1 also writes a JPG every third tick for two
# windows: the title to the first pack, and the exit of stage 2 to ten seconds into Brindle's arena. --uw-hold=1 keeps the
# hull full (a reader's aid, so the bot reaches Brindle). The death is scripted (a scripted-kill hit), like self_play's plant.

var root: Window:
	get:
		return get_tree().root
var _out := ""
var _film_want := false
var _hold_hull := true
var _t := 0.0
var _pending: Array = []
var _hooked := false
var _phase := "pre"
var _pre_at := -1.0
var _done := {}
var _tsv: FileAccess
var _cs_wait := 0.0
var _kit_t := 0.0
var _brief_t := 0.0
var _uf_dir := ""
var _film_n := 0
var _film_tag := ""
var _dying := false
var _kill_tries := 0
var _sum_wait := 0.0
var _extra_done := false
var _first_pack := false
var _arena_at := -1.0
var _stage1_notes_at := -1.0


func _uw_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--uw-out="):
			_out = arg.trim_prefix("--uw-out=")
		elif arg == "--uw-film=1":
			_film_want = true
		elif arg == "--uw-hold=0":
			_hold_hull = false


func _now() -> float:
	return _clock


func _physics_process(delta: float) -> void:
	if game.flow == null:
		return
	if _out == "":
		_uw_args()
		DirAccess.make_dir_recursive_absolute(_out.path_join("stills"))
		_tsv = FileAccess.open(_out.path_join("stills.tsv"), FileAccess.WRITE)
		_tsv.store_line("name\tt\tstage\tflow\twindow\tvisible_rect\timage\ttexture\tscale_aspect\tscale_mode")
	_t += delta
	if not _hooked and game.events != null:
		_hooked = true
		_hook()
	_run_pending()
	if _uf_dir != "" and Engine.get_physics_frames() % 3 == 0:
		_frame()
	if _phase == "pre":
		_pre()
		return
	if _dying:
		if _quit_code >= 0:
			print("uwcap: quitting with code %d" % _quit_code)
			get_tree().quit(_quit_code)
			return
		_release()
		_dying_step(delta)
		return
	if _hold_hull and game.run != null and game.run.alive():
		game.run.hp = game.run.max_hp
	var state: String = game.flow.state_name()
	# The pilot select stands for a still before the number key is pressed.
	if _driver != null and _menus and state == "class_select" and not game.screens.prologue_showing() and not _done.has("class_select"):
		_release()
		_cs_wait += delta
		if _cs_wait >= 1.5:
			_still("class_select")
		return
	super._physics_process(delta)
	if _quit_code >= 0:
		return
	_watch_moments(delta, state)


func _hook() -> void:
	var ev = game.events
	ev.warden_engaged.connect(func(s: int):
		if s == 1 and not _done.has("warden_fight"):
			_later(3.0, func(): _still("warden_fight")))
	ev.pack_arrived.connect(func(_f: String, _a: Vector3, _k: Array):
		if not _first_pack and game.run.stage == 1:
			_first_pack = true
			print("uwcap: first pack at t=%.2f" % _t)
			_later(4.0, func(): _film_end("film1_launch_to_first_pack")))
	ev.stage_cleared.connect(func(s: int):
		if s == 2 and _film_want and _uf_dir == "":
			_film_begin("film2_brindle"))
	ev.boss_arena_entered.connect(func():
		_arena_at = _t
		print("uwcap: boss arena entered at t=%.2f" % _t)
		_later(1.0, func(): _still("brindle_entrance_a"))
		_later(2.5, func(): _still("brindle_entrance_b"))
		_later(4.5, func(): _still("brindle_entrance_c"))
		_later(10.0, func(): _film_end("film2_brindle"))
		_later(10.5, func(): _begin_death()))


func _later(secs: float, fn: Callable) -> void:
	_pending.append({"at": _t + secs, "fn": fn})


func _run_pending() -> void:
	for p in _pending.duplicate():
		if _t >= float(p["at"]):
			_pending.erase(p)
			(p["fn"] as Callable).call()


func _tap(key: Key) -> void:
	_send(key, true)
	_later(0.12, func(): _send(key, false))


func _pre() -> void:
	if not game.ctx.terrain.is_ready(1):
		return
	var content = game.screens._content
	if _pre_at < 0.0:
		if content.modulate.a < 0.99 or game.flow.state_name() != "title":
			return
		_pre_at = _t
		if _film_want:
			_film_begin("film1_launch_to_first_pack")
		_later(2.5, func(): _still("title_intro"))
		_later(3.5, func(): _tap(KEY_SHIFT))
		_later(6.5, func(): _still("title"))
		_later(7.5, func(): _tap(KEY_H))
		_later(9.0, func(): _still("how_to_play"))
		_later(9.6, func(): _tap(KEY_H))
		_later(11.0, func(): _phase = "go")


func _watch_moments(delta: float, state: String) -> void:
	var ws: Node = game.get_node_or_null("Workshop")
	if ws != null and ws.pick != null and ws.pick.is_open():
		_kit_t += delta
		if _kit_t >= 1.5 and not _done.has("kit_pick"):
			_still("kit_pick")
	else:
		_kit_t = 0.0
	if ws != null and ws.briefing():
		_brief_t += delta
		if _brief_t >= 1.5 and not _done.has("briefing"):
			_still("briefing")
	else:
		_brief_t = 0.0
	if game.run.stage == 1 and state == "stage" and not get_tree().paused and game.run.stage_time >= 22.0 and not _done.has("dam_roaming"):
		_still("dam_roaming")
		_later(2.0, func(): _tap_notes())


func _begin_pause() -> void:
	_done["pause"] = false
	_tap(KEY_P)
	_later(1.0, func():
		_still("pause")
		_later(0.3, func(): _tap(KEY_P)))


func _tap_notes() -> void:
	_send(KEY_TAB, true)
	_later(0.7, func():
		_still("field_notes")
		_send(KEY_TAB, false)
		_later(0.8, func(): _begin_pause()))


func _begin_death() -> void:
	if _dying:
		return
	_dying = true
	_driver.source.hold = {}
	print("uwcap: scripted death at t=%.2f" % _t)
	_kill_tries = 0


func _dying_step(delta: float) -> void:
	var run = game.run
	if run.alive() and not _done.has("death"):
		_kill_tries += 1
		if _kill_tries % 10 == 1:
			run.damage(RunState.SCRIPTED_KILL, "chaser")
			if run.alive():
				run.hp = 0.0
		if not run.alive():
			_later(0.4, func(): _still("death"))
		return
	if game.flow.state_name() == "summary" and _done.has("death"):
		var vis: bool = game.screens.visible and game.screens._content.modulate.a >= 0.99
		if vis:
			_sum_wait += delta
		if _sum_wait >= 2.5 and not _done.has("summary"):
			_still("summary")
			_later(1.0, func(): _end_run(0))
	elif _t > 4000.0:
		_end_run(3)


func _still(name: String) -> void:
	if _done.get(name, false):
		return
	_done[name] = true
	var img := root.get_texture().get_image()
	var path := _out.path_join("stills").path_join("%s.png" % name)
	img.save_png(path)
	var vr: Rect2 = root.get_visible_rect()
	var row := "%s\t%.2f\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [name, _t, game.run.stage if game.run != null else 0, game.flow.state_name(),
		DisplayServer.window_get_size(), vr, img.get_size(), root.get_texture().get_size(), root.content_scale_aspect, root.content_scale_mode]
	_tsv.store_line(row)
	_tsv.flush()
	print("uwcap: still ", row.replace("\t", " | "))
	var rows: Array = []
	_walk(root, rows)
	var f := FileAccess.open(_out.path_join("stills").path_join("%s.controls.json" % name), FileAccess.WRITE)
	f.store_string(JSON.stringify({"name": name, "window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"visible_rect": [vr.position.x, vr.position.y, vr.size.x, vr.size.y], "image": [img.get_width(), img.get_height()], "controls": rows}))
	f.close()


func _alpha(c: CanvasItem) -> float:
	var a := 1.0
	var n: Node = c
	while n != null and n is CanvasItem:
		a *= (n as CanvasItem).modulate.a * (n as CanvasItem).self_modulate.a
		n = n.get_parent()
	return a


func _walk(n: Node, rows: Array) -> void:
	if n is Control:
		var c := n as Control
		if c.is_visible_in_tree() and c.size.x > 0.0 and c.size.y > 0.0 and _alpha(c) > 0.05:
			var r := c.get_global_rect()
			var text := ""
			if "text" in c:
				text = str(c.text).left(60)
			var kids := 0
			for k in c.get_children():
				if k is Control and (k as Control).visible:
					kids += 1
			var sp := ""
			if c.get_script() != null:
				sp = String(c.get_script().resource_path).get_file()
			rows.append({"class": c.get_class(), "script": sp, "path": str(c.get_path()).replace("/root/", ""), "rect": [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)],
				"text": text, "kids": kids, "alpha": snappedf(_alpha(c), 0.01)})
	for k in n.get_children():
		_walk(k, rows)


func _film_begin(tag: String) -> void:
	_film_tag = tag
	_uf_dir = _out.path_join(tag)
	_film_n = 0
	DirAccess.make_dir_recursive_absolute(_uf_dir)
	print("uwcap: film begin ", tag, " at t=", snappedf(_t, 0.01))


func _film_end(tag: String) -> void:
	if _uf_dir == "" or _film_tag != tag:
		return
	print("uwcap: film end ", tag, " frames=", _film_n, " at t=", snappedf(_t, 0.01))
	_uf_dir = ""


func _frame() -> void:
	var img := root.get_texture().get_image()
	img.save_jpg(_uf_dir.path_join("f%06d.jpg" % _film_n), 0.9)
	if _film_n == 0:
		print("uwcap: film first frame image=", img.get_size(), " visible_rect=", root.get_visible_rect(), " window=", DisplayServer.window_get_size())
	_film_n += 1
