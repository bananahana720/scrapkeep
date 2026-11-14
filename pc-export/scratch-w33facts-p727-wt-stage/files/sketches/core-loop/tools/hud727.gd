extends "res://tools/bot_run.gd"
# Scratch copy for p727 (adds the cog chip, sand crops, a sand floor in the world, a VIEWPORT line).
# Scratch (untracked, never committed): PR #721 HUD meters picture and film on the real renderer,
# modelled on ~/scratch/w33facts/eng/wt/sketches/core-loop/tools/sight715.gd.
#   -- --mode=pic|film --shots=<abs dir> [--warm=20] [--hpf=0.65] [bot_run flags]
# A bot run warms up on stage 1 (park table: park_dam) in play; then this takes over. The bot keeps
# driving (a real fight) while the probe holds health at --hpf of max and moves the director clock.
# No content-scale override: the project's own stretch (canvas_items, 1600x900 base) at the window size.

const UiDraw := preload("res://src/ui/ui_draw.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Palette := preload("res://src/core/palette.gd")
const RunStatusS := preload("res://src/ui/run_status.gd")
const GaugeS := preload("res://src/ui/gauge.gd")
const AbilityBarS := preload("res://src/ui/ability_bar.gd")
const DirectorS := preload("res://src/world/director.gd")

var _sg: Dictionary = {}
var _sg_state := "warm"
var _sg_dir := ""
var _sg_mode := ""
var _sg_started := false
var _hpf := 0.65
var _drive := true
var _rises: Array = []


func _initialize() -> void:
	_sg = _parse(OS.get_cmdline_user_args())
	_sg_dir = String(_sg.get("shots", ""))
	_sg_mode = String(_sg.get("mode", "pic"))
	_hpf = float(_sg.get("hpf", "0.65"))
	if DisplayServer.get_name() == "headless" or _sg_dir == "":
		printerr("hud721: needs a rendered display and --shots=<abs dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_sg_dir)
	super._initialize()


func _physics_process(delta: float) -> bool:
	if _sg_state == "warm":
		var over: bool = super._physics_process(delta)
		if not over and _game != null and _driver != null and _game.flow != null and _game.flow.in_play() \
				and _game.run.stage_time > float(_sg.get("warm", "20")) and not _sg_started:
			_sg_started = true
			_sg_state = "go"
			_go.call_deferred()
		return over
	_hold_hp()
	if _drive:
		return super._physics_process(delta)
	return false


func _hold_hp() -> void:
	if _game == null or _game.run == null:
		return
	var run = _game.run
	run.hp = run.max_hp * _hpf


func _wait_frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _hud():
	return _game.hud


func _director():
	return _game.world.director


func _force_clock(seconds: float) -> void:
	_director().stage_time = seconds


func _state_line() -> String:
	var h = _hud()
	var d = _director()
	var run = _game.run
	return "stage=%d map=%s class=%s armor_mode=%s scrap_mode=%s hp=%.1f/%.1f (%.2f) mass=%.1f dir_time=%.1f tier=%d spike=%s eff=%d hud_threat=%d steps_lit=%d toast=%s '%s' flow=%s" % [
		run.stage, String(_game.ctx.stages.of(run.stage).get("map", "")), run.class_def.id if run.class_def != null else "-",
		str(run.armor_mode), _game.ctx.tuning.option("scrap_mode"), run.hp, run.max_hp, run.hp / maxf(1.0, run.max_hp), run.mass,
		d.stage_time, d.tier(), str(d.spike), d.effective_tier(), h._threat, h._status.steps_lit(),
		str(h._toast_row.visible), h._toast_label.text, _game.flow.state_name()]


func _enemies_on_screen() -> int:
	var cam := root.get_camera_3d()
	var n := 0
	for e in get_nodes_in_group("enemy"):
		if not (e is Node3D) or not e.is_inside_tree():
			continue
		var p: Vector3 = e.global_position
		if cam.is_position_behind(p):
			continue
		var to := p - cam.global_position
		if to.length() < 45.0 and to.normalized().dot(-cam.global_basis.z) > 0.6:
			n += 1
	return n


func _go() -> void:
	print("hud721: VIEWPORT window=", root.size, " visible_rect=", root.get_visible_rect().size, " texture=", root.get_texture().get_size(), " hud_laid_out=", _hud()._laid_out, " adapter=", RenderingServer.get_video_adapter_name())
	print("hud721: control taken mode=", _sg_mode, " ", _state_line())
	_game.ctx.calm = false
	_game.events.threat_rose.connect(func(tier: int): _rises.append([Engine.get_process_frames(), tier]))
	match _sg_mode:
		"pic":
			await _pic()
		"film":
			await _film()
	print("hud721: done ", _state_line())
	quit(0)


# ------------------------------------------------------------------------- geometry

func _screen_rect(c: Control, local: Rect2) -> Rect2:
	var t: Transform2D = c.get_screen_transform()
	var laid: Vector2 = _hud()._laid_out
	var k: Vector2 = Vector2(root.get_texture().get_size()) / laid
	var a: Vector2 = t * local.position * k
	var b: Vector2 = t * local.end * k
	return Rect2(a, b - a).abs()


# A pack of chasers and lobbers 12-20 m in front of the camera, facing the ball: a fight in frame.
func _stage_fight() -> void:
	var ball: Vector3 = _game.player.ball_position()
	var fwd: Vector3 = _game.ctx.heading()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	var spots := [[14.0, -4.0, "chaser"], [17.0, 5.0, "chaser"], [20.0, -9.0, "lobber"], [12.0, 9.0, "chaser"]]
	for s in spots:
		var p: Vector3 = ball + fwd * float(s[0]) + side * float(s[1])
		var at: Vector3 = _game.ctx.terrain.drop_point(p.x, p.z, 2.4)
		var e = _game.ctx.spawner.spawn_enemy(String(s[2]), at, "")
		print("hud721: spawned ", s[2], " at ", at, " -> ", e)
	if _game.run.mass < 60.0:
		_game.run.mass = 70.0
	print("hud721: staged fight, mass ", _game.run.mass)


func _font_box(c: Control, x: float, ymid: float, word: String, size: int) -> Rect2:
	var font := UiFonts.bold()
	var asc := font.get_ascent(size)
	var desc := font.get_descent(size)
	var base := ymid + (asc - desc) * 0.5
	return _screen_rect(c, Rect2(Vector2(x, base - asc), Vector2(UiDraw.width(word, size), asc + desc)))


func _geometry() -> Dictionary:
	var h = _hud()
	var st: Control = h._status
	var hg: Control = h._health
	var ag: Control = h._armor
	var ab: Control = h.ability_bar
	var g := {}
	g["scale"] = float(root.get_texture().get_size().x) / _hud()._laid_out.x
	g["hud_canvas"] = _hud()._laid_out
	g["image_size"] = Vector2(root.get_texture().get_size())
	g["viewport"] = root.get_visible_rect().size
	g["plate"] = _screen_rect(st, Rect2(Vector2(-RunStatusS.PLATE_PAD, -RunStatusS.PLATE_PAD), st.size + Vector2.ONE * RunStatusS.PLATE_PAD * 2.0))
	var foot: float = st.size.y - 1.0
	g["threat_word"] = _font_box(st, RunStatusS.word_left(), foot - RunStatusS.STEP.y * 0.5, RunStatusS.THREAT_WORD, RunStatusS.WORD_FONT)
	g["threat_steps"] = _screen_rect(st, Rect2(Vector2(RunStatusS.BAR_X, foot - RunStatusS.STEP.y), Vector2(RunStatusS.steps() * (RunStatusS.STEP.x + RunStatusS.STEP_GAP), RunStatusS.STEP.y)))
	for pair in [["health", hg], ["armour", ag]]:
		var gc: Control = pair[1]
		var x: float = GaugeS.ICON + GaugeS.GAP
		if gc.label != "":
			x += UiDraw.width(gc.label, GaugeS.FONT, true) + GaugeS.GAP
		var mid: float = gc.bar_mid()
		g[pair[0] + "_bar"] = _screen_rect(gc, Rect2(Vector2(x, mid - GaugeS.BAR_H * 0.5), Vector2(gc.bar_width, GaugeS.BAR_H)))
		g[pair[0] + "_icon"] = _screen_rect(gc, Rect2(Vector2(0.0, mid - GaugeS.ICON * 0.5), Vector2(GaugeS.ICON, GaugeS.ICON)))
		g[pair[0] + "_word"] = _font_box(gc, x, GaugeS.ICON + GaugeS.CAPTION_LINE * 0.5, gc.caption, GaugeS.CAPTION_FONT)
		g[pair[0] + "_gauge"] = _screen_rect(gc, Rect2(Vector2.ZERO, gc.size))
		g[pair[0] + "_visible"] = gc.visible
		g[pair[0] + "_caption"] = gc.caption
		g[pair[0] + "_color"] = gc.color.to_html(false)
	var bs: Vector2 = AbilityBarS.bar_size(maxi(ab.slots.size(), AbilityBarS.NUMBERED + 2))
	g["ability_bar"] = _screen_rect(ab, Rect2(Vector2.ZERO, bs))
	g["key_row"] = _screen_rect(ab, Rect2(Vector2(0.0, AbilityBarS.SLOT + AbilityBarS.KEY_GAP), Vector2(bs.x, AbilityBarS.KEY_H)))
	g["threat_color"] = EventKindsColor("threat_rose")
	var cogs: Control = h._cogs
	g["cogs_chip"] = _screen_rect(cogs, Rect2(Vector2.ZERO, cogs.size))
	g["cogs_icon"] = _screen_rect(cogs, Rect2(Vector2(0.0, cogs.size.y * 0.5 - 10.0), Vector2(20.0, 20.0)))
	g["cogs_visible"] = cogs.is_visible_in_tree()
	g["cogs_amount"] = cogs.amount
	return g


func EventKindsColor(k: String) -> String:
	return preload("res://src/core/event_kinds.gd").color(k).to_html(false)


# Rows/cols of pixels in `rect` whose colour is within `tol` of `col` (max channel): the bbox.
static func _ink_box(img: Image, rect: Rect2i, col: Color, tol: float) -> Rect2i:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var minx := 1 << 30
	var miny := 1 << 30
	var maxx := -1
	var maxy := -1
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var p := img.get_pixel(x, y)
			if maxf(absf(p.r - col.r), maxf(absf(p.g - col.g), absf(p.b - col.b))) <= tol:
				minx = mini(minx, x)
				miny = mini(miny, y)
				maxx = maxi(maxx, x)
				maxy = maxi(maxy, y)
	if maxx < 0:
		return Rect2i()
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)


static func _ri(r: Rect2, grow := 0.0) -> Rect2i:
	var g := r.grow(grow)
	return Rect2i(int(floor(g.position.x)), int(floor(g.position.y)), int(ceil(g.size.x)), int(ceil(g.size.y)))


func _crop8(img: Image, rect: Rect2i, path: String) -> void:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var c := img.get_region(r)
	c.resize(r.size.x * 8, r.size.y * 8, Image.INTERPOLATE_NEAREST)
	c.save_png(path)


# Mean luma of rect.
static func _luma(img: Image, rect: Rect2i) -> float:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var s := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			var p := img.get_pixel(x, y)
			s += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b
			n += 1
	return s / maxf(1.0, n)


func _backdrop(color: Color) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 0
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = Vector2(-10000, -10000)
	r.size = Vector2(40000, 40000)
	layer.add_child(r)
	root.add_child(layer)
	return layer


func _measure_words(img: Image, g: Dictionary, mf: FileAccess, tag: String) -> void:
	var tc := Color(String(g["threat_color"]))
	var items := [["THREAT", g["threat_word"], tc], ["HEALTH", g["health_word"], Color(String(g["health_color"]))], ["ARMOUR", g["armour_word"], Color(String(g["armour_color"]))]]
	for it in items:
		var box := _ink_box(img, _ri(it[1], 3.0 * float(g["scale"])), it[2], 0.10)
		mf.store_line("%s\t%s word fill bbox\t%s\theight_px=%d\twidth_px=%d\tfont_box=%s" % [tag, it[0], str(box), box.size.y, box.size.x, str(_ri(it[1]))])
		g[tag + "_" + it[0] + "_ink"] = box


# ------------------------------------------------------------------------- picture 1

func _pic() -> void:
	# Threat tier 1 by the director's own clock (its rise is announced as in play); then let the toast go.
	_force_clock(DirectorS.TIER_SECONDS + 0.5)
	await _wait_frames(6 * 90)
	print("hud721: after tier force ", _state_line())
	_drive = false
	_driver.source.hold = {}
	_driver.source.press = {}
	_stage_fight()
	await _wait_frames(90)
	var mf := FileAccess.open(_sg_dir.path_join("measure.tsv"), FileAccess.WRITE)
	mf.store_line("# hud721 pic, " + _state_line())
	var burst := _sg_dir.path_join("burst")
	DirAccess.make_dir_recursive_absolute(burst)
	var best := -1
	var best_i := -1
	var best_img: Image = null
	for i in 24:
		await _wait_frames(30)
		var img := root.get_texture().get_image()
		var n := _enemies_on_screen()
		var toast: bool = _hud()._toast_row.visible
		img.save_png(burst.path_join("b%02d.png" % i))
		mf.store_line("burst\tb%02d\tenemies_on_screen=%d\ttoast=%s\t%s" % [i, n, str(toast), _state_line()])
		if n > best and not toast:
			best = n
			best_i = i
			best_img = img
	if best_img == null:
		best_img = root.get_texture().get_image()
	print("hud721: picked burst ", best_i, " enemies ", best)
	_drive = false
	best_img.save_png(_sg_dir.path_join("picture1_full.png"))
	mf.store_line("picked\tb%02d\tenemies_on_screen=%d" % [best_i, best])
	# The frame now, frozen: geometry, then the same HUD on black and on sand.
	_game.player.set_frozen(true)
	await _wait_frames(4)
	var g := _geometry()
	mf.store_line("geometry\t" + JSON.stringify(_jsonable(g)))
	var now := root.get_texture().get_image()
	now.save_png(_sg_dir.path_join("frozen_frame.png"))
	_measure_words(now, g, mf, "frozen")
	var blk := _backdrop(Color.BLACK)
	await _wait_frames(3)
	var bimg := root.get_texture().get_image()
	bimg.save_png(_sg_dir.path_join("hud_on_black.png"))
	_measure_words(bimg, g, mf, "black")
	blk.queue_free()
	var sand := _backdrop(Palette.SAND)
	await _wait_frames(3)
	var simg := root.get_texture().get_image()
	var sc0: float = float(g["scale"])
	_crop8(simg, _ri(g["plate"], 6.0 * sc0), _sg_dir.path_join("hud_on_sand_panel_threat_plate_8x.png"))
	_crop8(simg, _ri(g["cogs_chip"], 6.0 * sc0), _sg_dir.path_join("hud_on_sand_panel_cogs_8x.png"))
	simg.save_png(_sg_dir.path_join("hud_on_sand_panel.png"))
	_measure_words(simg, g, mf, "sandpanel")
	sand.queue_free()
	await _wait_frames(2)
	# Crops of the picked frame.
	var sc: float = float(g["scale"])
	_crop8(best_img, _ri(g["plate"], 6.0 * sc), _sg_dir.path_join("picture1_threat_plate_8x.png"))
	var bottom: Rect2 = (g["armour_gauge"] as Rect2).merge(g["health_gauge"]).grow(6.0 * sc)
	_crop8(best_img, _ri(bottom), _sg_dir.path_join("picture1_health_armour_8x.png"))
	_crop8(bimg, _ri(g["plate"], 6.0 * sc), _sg_dir.path_join("hud_on_black_threat_plate_8x.png"))
	_crop8(bimg, _ri(bottom), _sg_dir.path_join("hud_on_black_health_armour_8x.png"))
	_crop8(simg, _ri(bottom), _sg_dir.path_join("hud_on_sand_panel_health_armour_8x.png"))
	_crop8(bimg, _ri(g["cogs_chip"], 6.0 * sc), _sg_dir.path_join("hud_on_black_cogs_8x.png"))
	# The ball standing on a flat floor of Palette.SAND in the world, HUD at 100%.
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600.0, 600.0)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Palette.SAND
	floor_mi.material_override = fm
	root.add_child(floor_mi)
	var bpos: Vector3 = _game.player.ball_position()
	floor_mi.global_position = bpos - Vector3.UP * 1.0
	_game.camera.snap(Vector3(0, 0, -1), -0.35)
	await _wait_frames(10)
	var wimg := root.get_texture().get_image()
	wimg.save_png(_sg_dir.path_join("sand_floor_full.png"))
	_crop8(wimg, _ri(bottom), _sg_dir.path_join("sand_floor_health_armour_8x.png"))
	_crop8(wimg, _ri(g["cogs_chip"], 6.0 * sc), _sg_dir.path_join("sand_floor_cogs_8x.png"))
	_crop8(wimg, _ri(g["plate"], 6.0 * sc), _sg_dir.path_join("sand_floor_threat_plate_8x.png"))
	mf.store_line("sand_floor\tplane at ball-1m %s, camera pitch -0.35; floor colour %s" % [str(floor_mi.global_position), Palette.SAND.to_html(false)])
	floor_mi.queue_free()
	await _wait_frames(2)
	# Pale ground in the world: sweep the camera, HUD hidden, for the brightest ground behind the bottom row.
	var row_rect := _ri(bottom)
	var hud = _hud()
	hud.visible = false
	var ball: Vector3 = _game.player.ball_position()
	var bestl := -1.0
	var bestv := []
	for yd in range(0, 360, 30):
		for p in [-0.15, -0.45, -0.8, -1.1]:
			var dir := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(yd))
			_game.camera.snap(dir, p)
			await _wait_frames(8)
			var im := root.get_texture().get_image()
			var l := _luma(im, row_rect)
			mf.store_line("pale_sweep\tyaw=%d\tpitch=%.2f\tluma_behind_bottom_row=%.3f" % [yd, p, l])
			if l > bestl:
				bestl = l
				bestv = [dir, p, yd]
	print("hud721: pale sweep best luma ", bestl, " at ", bestv)
	_game.camera.snap(bestv[0], bestv[1])
	await _wait_frames(10)
	var bare := root.get_texture().get_image()
	hud.visible = true
	await _wait_frames(4)
	var pale := root.get_texture().get_image()
	pale.save_png(_sg_dir.path_join("pale_ground_full.png"))
	bare.save_png(_sg_dir.path_join("pale_ground_bare.png"))
	_crop8(pale, _ri(bottom), _sg_dir.path_join("pale_ground_health_armour_8x.png"))
	mf.store_line("pale_ground\tyaw=%d\tpitch=%.2f\tluma_behind_bottom_row=%.3f\tball=%s" % [bestv[2], bestv[1], bestl, str(ball)])
	_measure_words(pale, g, mf, "paleground")
	mf.store_line("rises\t" + str(_rises))
	mf.store_line("# end " + _state_line())
	mf.close()


func _jsonable(g: Dictionary) -> Dictionary:
	var out := {}
	for k in g.keys():
		var v = g[k]
		if v is Rect2 or v is Rect2i:
			out[k] = [v.position.x, v.position.y, v.size.x, v.size.y]
		elif v is Vector2:
			out[k] = [v.x, v.y]
		else:
			out[k] = v
	return out


# ------------------------------------------------------------------------- film 2

func _film() -> void:
	_force_clock(DirectorS.TIER_SECONDS + 0.5)
	await _wait_frames(6 * 90)
	_drive = false
	_driver.source.hold = {}
	_driver.source.press = {}
	_stage_fight()
	await _wait_frames(90)
	print("hud721: film start ", _state_line())
	var frames_dir := _sg_dir.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var log_f := FileAccess.open(_sg_dir.path_join("trace.tsv"), FileAccess.WRITE)
	log_f.store_line("saved_frame\ttick_i\tdir_time\ttier\teff_tier\thud_threat\tsteps_lit\ttoast_visible\ttoast_text\tenemies_on_screen\thp_frac\trising\trise_left")
	# Tier 2 arrives 3 s into the film.
	_force_clock(DirectorS.TIER_SECONDS * 2.0 - 3.0)
	var g := _geometry()
	log_f.store_line("# geometry " + JSON.stringify(_jsonable(g)))
	var n := 0
	var h = _hud()
	for i in 900:
		await RenderingServer.frame_post_draw
		if i % 3 == 0:
			root.get_texture().get_image().save_png(frames_dir.path_join("f%04d.png" % n))
			var d = _director()
			var st = h._status
			var rl: float = float(st.get("_rise_left")) if st.get("_rise_left") != null else -1.0
			log_f.store_line("%d\t%d\t%.2f\t%d\t%d\t%d\t%d\t%s\t%s\t%d\t%.2f\t%s\t%.3f" % [n, i, d.stage_time, d.tier(), d.effective_tier(), h._threat, h._status.steps_lit(),
				str(h._toast_row.visible), h._toast_label.text, _enemies_on_screen(), _game.run.hp / maxf(1.0, _game.run.max_hp), str(st.rising()) if st.has_method("rising") else "n/a", rl])
			n += 1
	log_f.store_line("# rises " + str(_rises))
	log_f.close()
	print("hud721: film frames ", n, " rises ", _rises)
