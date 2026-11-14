extends "res://tools/bot_run.gd"
# Scratch (untracked, never committed): PR #715 look-fix films on the real renderer, adapted from
# ~/scratch/w33facts/sight-d/sketches/core-loop/tools/sight.gd (modes d1v/d1a).
#   -- --mode=fan --part=a|b|c | gate | flume  --shots=<abs dir> [bot_run flags]
# A bot run warms up to stage 1 in play; then this takes over (the driver stops ticking).

const ShopTile := preload("res://src/ui/shop_tile.gd")
const Parts := preload("res://src/build/parts.gd")
const Palette := preload("res://src/core/palette.gd")

var _sg: Dictionary = {}
var _sg_state := "warm"
var _sg_dir := ""
var _sg_mode := ""
var _sg_started := false
var _offers_seen: Array = []
var _panels: Array = []
var _launched := false
var _stage_seen := 0


func _initialize() -> void:
	_sg = _parse(OS.get_cmdline_user_args())
	_sg_dir = String(_sg.get("shots", ""))
	_sg_mode = String(_sg.get("mode", "fan"))
	if DisplayServer.get_name() == "headless" or _sg_dir == "":
		printerr("sight715: needs a rendered display and --shots=<abs dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_sg_dir)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	super._initialize()


func _physics_process(delta: float) -> bool:
	if _sg_state == "warm":
		var over: bool = super._physics_process(delta)
		if not over and _game != null and _driver != null and _game.flow != null and _game.flow.in_play() and _game.run.stage_time > 2.0 and not _sg_started:
			_sg_started = true
			_sg_state = "go"
			_go.call_deferred()
		return over
	return false


func _wait_frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _save_png(path: String) -> void:
	root.get_texture().get_image().save_png(path)


func _take_control(calm := true) -> void:
	_game.run.set_max_hp(999999.0)
	_game.ctx.calm = calm
	_driver.source.hold = {}
	_driver.source.press = {}


func _place_ball(at: Vector3, face: Vector3, pitch := -0.18, frozen := true) -> void:
	_game.player.set_frozen(false)
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	if frozen:
		_game.player.set_frozen(true)
	_game.camera.snap(face - at, pitch)


func _film(dir: String, frames: int, step: int, per_frame: Callable = Callable()) -> int:
	DirAccess.make_dir_recursive_absolute(dir)
	var n := 0
	for i in frames:
		if per_frame.is_valid():
			if per_frame.call(i) == false:
				break
		await RenderingServer.frame_post_draw
		if i % step == 0:
			_save_png(dir.path_join("f%04d.png" % n))
			n += 1
	print("sight715: film ", dir, " frames saved ", n)
	return n


func _go() -> void:
	print("sight715: control taken mode=", _sg_mode, " stage=", _game.run.stage, " map=", String(_game.ctx.stages.of(_game.run.stage).get("map", "")),
		" next map=", String(_game.ctx.stages.of(_game.run.stage + 1).get("map", "")), " class=", _game.run.class_def.resource_path if _game.run.class_def != null else "-",
		" ball=", _game.player.ball_position())
	match _sg_mode:
		"fan":
			await _fan(String(_sg.get("part", "a")))
		"gate":
			await _gate()
		"flume":
			await _flume()
	print("sight715: done")
	quit(0)


# ------------------------------------------------------------------------- measure helpers

func _ball_screen() -> Dictionary:
	var cam := root.get_camera_3d()
	var b: Vector3 = _game.player.shown_position()
	var c := cam.unproject_position(b)
	var top := cam.unproject_position(b + cam.global_basis.y * 1.0)
	return {"x": c.x, "y": c.y, "top": top.y}


# Share of pixels in rect whose largest channel differs by more than t/255, for t in [4, 8, 16].
static func _diff_share(a: Image, b: Image, rect: Rect2i, mask: Image = null) -> Array:
	var counts := [0, 0, 0]
	var total := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			var d := maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) * 255.0
			total += 1
			if d > 4.0:
				counts[0] += 1
			if d > 8.0:
				counts[1] += 1
				if mask != null:
					mask.set_pixel(x, y, Color.WHITE)
			if d > 16.0:
				counts[2] += 1
	if total == 0:
		return [0.0, 0.0, 0.0]
	return [float(counts[0]) / total, float(counts[1]) / total, float(counts[2]) / total]


# One measured sample: the frame with the fan (on), then the indicator hidden (off), then hidden again (off2,
# the noise floor: what changes between two control frames with nothing toggled).
func _measure(tag: String, mf) -> void:
	var ind: Node3D = _game.player.indicator
	await RenderingServer.frame_post_draw
	var on := root.get_texture().get_image()
	var bs := _ball_screen()
	var layers := str(ind.shapes.keys())
	ind.visible = false
	await RenderingServer.frame_post_draw
	var off := root.get_texture().get_image()
	await RenderingServer.frame_post_draw
	var off2 := root.get_texture().get_image()
	ind.visible = true
	if ind.shapes.size() > 1:
		# per-layer split: an eraser that runs before the indicator draws removes one layer each frame
		var er := Eraser.new()
		er.ind = ind
		er.process_priority = -1000
		root.add_child(er)
		for layer in ind.shapes.keys():
			er.layer = layer
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var only := root.get_texture().get_image()
			var bt := clampi(int(_ball_screen()["top"]), 0, 1080)
			var s1 := _diff_share(only, off, Rect2i(480, 0, 960, bt))
			only.save_png(_sg_dir.path_join("m_%s_without_%s.png" % [tag, layer]))
			mf.store_line("%s_without_%s\tregionA share t4/t8/t16 vs off\t%.4f\t%.4f\t%.4f" % [tag, layer, s1[0], s1[1], s1[2]])
			print("sight715: SPLIT ", tag, " without ", layer, " ", s1)
		er.queue_free()
		await RenderingServer.frame_post_draw
	on.save_png(_sg_dir.path_join("m_%s_on.png" % tag))
	off.save_png(_sg_dir.path_join("m_%s_off.png" % tag))
	var ball_top := clampi(int(bs["top"]), 0, 1080)
	var region_a := Rect2i(480, 0, 960, ball_top)
	var region_b := Rect2i(480, 270, 960, 540)
	var mask := Image.create(1920, 1080, false, Image.FORMAT_RGB8)
	mask.fill(Color.BLACK)
	var sa := _diff_share(on, off, region_a, mask)
	var sa_noise := _diff_share(off, off2, region_a)
	var sb := _diff_share(on, off, region_b)
	var sb_noise := _diff_share(off, off2, region_b)
	var full := _diff_share(on, off, Rect2i(0, 0, 1920, 1080))
	mask.save_png(_sg_dir.path_join("m_%s_mask_regionA_t8.png" % tag))
	var fill := -1.0
	if ind.shapes.has("slingshot"):
		fill = float(ind.shapes["slingshot"].get("fill", -1.0))
	var row := "%s\t%s\t%.0f,%.0f\t%.0f\t%s\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.3f\t%.2f\t%.2f" % [tag, layers, bs["x"], bs["y"], bs["top"], str(region_a),
		sa[0], sa[1], sa[2], sa_noise[1], sb[0], sb[1], sb[2], sb_noise[1], full[1], _game.camera.pitch, _game.camera.yaw, fill]
	mf.store_line(row)
	mf.flush()
	print("sight715: MEASURE ", row)


# ------------------------------------------------------------------------- 1: aim fan

func _fan(part: String) -> void:
	_take_control()
	var at := Vector3(-30.0, 72.0, 638.55)
	var player = _game.player
	var body: RigidBody3D = player.body()
	var mf := FileAccess.open(_sg_dir.path_join("measure.tsv"), FileAccess.WRITE)
	mf.store_line("tag\tindicator_layers\tball_px\tball_top_px\tregionA(x,y,w,h)\tA_share_t4\tA_share_t8\tA_share_t16\tA_noise_t8\tB_share_t4\tB_share_t8\tB_share_t16\tB_noise_t8\tfull_frame_t8\tcam_pitch\tcam_yaw\tsling_fill")
	var log_f := FileAccess.open(_sg_dir.path_join("trace.tsv"), FileAccess.WRITE)
	log_f.store_line("saved_frame\ttick_i\tsegment\tball\tcam_pos\tcam_yaw\tcam_pitch\tlayers\tmounted\tsling_fill\tsling_charging")
	var hover := func():
		if not player.kit.mounted:
			body.gravity_scale = 0.0
			body.linear_velocity = Vector3.ZERO
			body.global_position = at
	var wall := Vector3(0, 0, 1)
	var yaws: Array = [0.0]
	if part == "b":
		yaws = [45.0, 90.0]
	_place_ball(at, at + wall * 100.0, 0.0, false)
	body.gravity_scale = 0.0
	for i in 90:
		hover.call()
		await RenderingServer.frame_post_draw
	if part == "c":
		_driver.source.press = {"mount_pressed": true}
		for i in 30:
			await RenderingServer.frame_post_draw
		print("sight715: mount pressed; mounted=", player.kit.mounted, " ", player.kit.mount_point if player.kit.mounted else "")
		_driver.source.press = {"jump_pressed": true}
		_driver.source.hold = {"jump_held": true}
		for i in 90:
			player.kit.slingshot.held = minf(player.kit.slingshot.held, player.kit.slingshot.charge_max + 0.05)
			await RenderingServer.frame_post_draw
		print("sight715: slingshot charging=", player.kit.slingshot.charging, " fraction=", player.kit.slingshot.fraction(), " mounted=", player.kit.mounted)
	var hold_sling := func():
		if part == "c" and player.kit.slingshot.charging:
			player.kit.slingshot.held = minf(player.kit.slingshot.held, player.kit.slingshot.charge_max + 0.05)
	var saved := [0]
	var seg := [""]
	var trace := func(i: int):
		if i % 3 == 0:
			var cam := root.get_camera_3d()
			log_f.store_line("%d\t%d\t%s\t%s\t%s\t%.3f\t%.3f\t%s\t%s\t%.2f\t%s" % [saved[0], i, seg[0], str(player.ball_position().snapped(Vector3.ONE * 0.01)),
				str(cam.global_position.snapped(Vector3.ONE * 0.01)), _game.camera.yaw, _game.camera.pitch, str(player.indicator.shapes.keys()),
				str(player.kit.mounted), player.kit.slingshot.fraction(), str(player.kit.slingshot.charging)])
			saved[0] += 1
	var frames_dir := _sg_dir.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var n := 0
	for yi in yaws.size():
		var yd: float = yaws[yi]
		var heading := wall.rotated(Vector3.UP, deg_to_rad(yd))
		_game.camera.snap(heading, 0.0)
		for i in 30:
			hover.call()
			hold_sling.call()
			await RenderingServer.frame_post_draw
		# measure at level (three samples 0.33 s apart, so a breathing glow is caught high and low)
		for k in 3:
			hover.call()
			hold_sling.call()
			await _measure("%s_yaw%d_level_%d" % [part, int(yd), k], mf)
			for j in 30:
				hover.call()
				hold_sling.call()
				await RenderingServer.frame_post_draw
		# film: 3 s level, 0.4 s mouse pitch up to the limit, 3 s at the limit
		for i in 640:
			hover.call()
			hold_sling.call()
			if i < 270:
				seg[0] = "yaw%d level" % int(yd)
			elif i < 310:
				seg[0] = "yaw%d pitching up (mouse dy=-7 px/tick)" % int(yd)
				_game.camera.look(Vector2(0, -7.0))
			else:
				seg[0] = "yaw%d pitch at limit" % int(yd)
				_game.camera.look(Vector2(0, -1.0))
			trace.call(i)
			await RenderingServer.frame_post_draw
			if i % 3 == 0:
				_save_png(frames_dir.path_join("f%04d.png" % n))
				n += 1
		for k in 3:
			hover.call()
			hold_sling.call()
			_game.camera.look(Vector2(0, -1.0))
			await _measure("%s_yaw%d_up_%d" % [part, int(yd), k], mf)
			for j in 30:
				hover.call()
				hold_sling.call()
				await RenderingServer.frame_post_draw
	log_f.close()
	mf.close()
	print("sight715: fan frames saved ", n)


# ------------------------------------------------------------------------- 2: gate sign

func _gate_node(part_id: String) -> Node3D:
	var gates = _game.build.gates
	for i in gates.offers.size():
		if gates.offers[i]["part_id"] == part_id:
			return gates._gates[i]
	return null


func _gate() -> void:
	_take_control()
	_game.events.reward_offered.connect(func(offers: Array): _offers_seen.append(offers.map(func(o): return o["part_id"])))
	var bp: Vector3 = _game.ctx.terrain.beacon_point(_game.run.stage)
	var drop: Vector3 = _game.ctx.terrain.drop_point(bp.x, bp.z, 1.05)
	_place_ball(drop, drop + Vector3(0, 0, -50), -0.2, true)
	await _wait_frames(30)
	_game.flow._unseal()
	await _wait_frames(30)
	var gates = _game.build.gates
	print("sight715: flow state ", _game.flow.state_name(), " natural offers ", _offers_seen)
	var ids: Array = gates.offers.map(func(o): return o["part_id"])
	var forced := false
	if not ids.has("impact_driver"):
		forced = true
		var keep: Array = ids.filter(func(id): return id != "impact_driver")
		var new_ids := ["impact_driver"] + keep.slice(0, maxi(1, keep.size() - 1))
		_game.ctx.events.reward_offered.emit(gates.open(new_ids, _game.player.ball_position(), _game.ctx.heading(), _game.run.parts))
	print("sight715: offers now ", gates.offers.map(func(o): return [o["part_id"], o["trigger_icon"], o["icon"], o["element_icon"]]), " forced=", forced)
	var gate := _gate_node("impact_driver")
	if gate == null:
		print("sight715: no impact_driver gate")
		return
	var glyphs: Array = []
	for c in gate.get_children():
		if c is Sprite3D:
			glyphs.append(c)
	var trg: Sprite3D = null
	for g in glyphs:
		print("sight715: glyph ", g.name, " local ", g.position, " tex ", g.texture.resource_path if g.texture != null else "-", " size ", g.texture.get_size() if g.texture != null else Vector2.ZERO)
		if g.texture != null and "trg_on_rebound" in g.texture.resource_path:
			trg = g
	if trg == null and glyphs.size() > 0:
		trg = glyphs[-1]
	var offer: Dictionary = {}
	for o in gates.offers:
		if o["part_id"] == "impact_driver":
			offer = o
	var facing: Vector3 = offer["facing"]
	var gat: Vector3 = offer["at"]
	var st := FileAccess.open(_sg_dir.path_join("stills.tsv"), FileAccess.WRITE)
	st.store_line("file\ttarget_m\tcam_to_trg_glyph_m\tcam_pitch\tglyph_screen_px\tglyph_height_px\tforced_offer\tnote")
	for d in [8.0, 30.0]:
		var best := {}
		var backs: Array = [2.0, 4.0, 6.0, 8.0, 10.0] if d < 10.0 else [18.0, 21.0, 24.0, 27.0, 30.0]
		var side := facing.cross(Vector3.UP).normalized()
		for lat in [6.5, -6.5, 9.0, -9.0, 0.0]:
			for back in backs:
				for p in [0.55, 0.4, 0.25, 0.1, 0.0]:
					var g: Vector3 = gat - facing * back + side * lat
					var bpos: Vector3 = _game.ctx.terrain.drop_point(g.x, g.z, 1.05)
					_place_ball(bpos, bpos + facing * 50.0, p, true)
					await _wait_frames(12)
					var cam := root.get_camera_3d()
					if not is_instance_valid(trg) or not gates.is_open():
						print("sight715: gate went away (chosen or moved) at lat ", lat, " back ", back)
						return
					var gp := trg.global_position
					if cam.is_position_behind(gp):
						continue
					var sp := cam.unproject_position(gp)
					var dist := cam.global_position.distance_to(gp)
					var bshown: Vector3 = _game.player.shown_position()
					var bc := cam.unproject_position(bshown)
					var br := absf(cam.unproject_position(bshown + cam.global_basis.x * 1.0).x - bc.x)
					var clear := sp.distance_to(bc) > br + 60.0
					if sp.x > 80 and sp.x < 1840 and sp.y > 120 and sp.y < 1000 and clear:
						if best.is_empty() or absf(dist - d) < absf(float(best["dist"]) - d):
							best = {"pitch": p, "dist": dist, "sp": sp, "back": back, "lat": lat, "bpos": bpos}
				if not best.is_empty() and absf(float(best["dist"]) - d) < 1.0:
					break
			if not best.is_empty() and absf(float(best["dist"]) - d) < 1.0:
				break
		if best.is_empty():
			print("sight715: no framing for ", d)
			continue
		print("sight715: framing for ", d, " ", best)
		var bpos2: Vector3 = best["bpos"]
		_place_ball(bpos2, bpos2 + facing * 50.0, best["pitch"], true)
		await _wait_frames(40)
		var cam2 := root.get_camera_3d()
		var gp2 := trg.global_position
		var sp2 := cam2.unproject_position(gp2)
		var dist2 := cam2.global_position.distance_to(gp2)
		var half := trg.texture.get_size().y * trg.pixel_size * 0.5
		var hpx := absf(cam2.unproject_position(gp2 + cam2.global_basis.y * half).y - cam2.unproject_position(gp2 - cam2.global_basis.y * half).y)
		var file := "gate_%dm.png" % int(d)
		var img := root.get_texture().get_image()
		img.save_png(_sg_dir.path_join(file))
		var cx := clampi(int(sp2.x) - 120, 0, 1920 - 240)
		var cy := clampi(int(sp2.y) - 68, 0, 1080 - 135)
		var crop := img.get_region(Rect2i(cx, cy, 240, 135))
		crop.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		crop.save_png(_sg_dir.path_join(file.replace(".png", "_crop8x.png")))
		st.store_line("%s\t%.0f\t%.1f\t%.2f\t%.0f,%.0f\t%.1f\t%s\tchase camera, ball frozen %.1f m before the gate and %.1f m to the side; trigger glyph %s" % [file, d, dist2, best["pitch"], sp2.x, sp2.y, hpx, str(forced), best["back"], best["lat"], trg.name])
		print("sight715: SHOT ", file, " dist ", dist2, " glyph px ", hpx, " at ", sp2)
	# the shop tile for the same part, drawn by the game's own ShopTile at its counter size (112x124) and at 3x
	var d_def: Resource = Parts.def("impact_driver")
	var rec := {"kind": "shelf", "index": 0, "part_id": "impact_driver", "price": 60, "state": "ok",
		"icon": "cat_" + (d_def.icon_category if d_def != null and d_def.icon_category != "" else "utility"),
		"rarity": d_def.rarity if d_def != null else "common",
		"element_icon": "el_" + d_def.element if d_def != null and d_def.element != "" else "",
		"trigger_icon": "trg_" + d_def.trigger if d_def != null and d_def.trigger != "" else ""}
	var layer := CanvasLayer.new()
	layer.layer = 120
	root.add_child(layer)
	var back_rect := ColorRect.new()
	back_rect.color = Color(Palette.CHARCOAL, 0.92)
	back_rect.position = Vector2(60, 60)
	back_rect.size = Vector2(620, 520)
	layer.add_child(back_rect)
	var t1 := ShopTile.new(rec, Vector2(112.0, 124.0))
	t1.position = Vector2(100, 100)
	layer.add_child(t1)
	var t3 := ShopTile.new(rec, Vector2(112.0, 124.0))
	t3.position = Vector2(280, 100)
	t3.scale = Vector2(3, 3)
	layer.add_child(t3)
	await _wait_frames(10)
	var simg := root.get_texture().get_image()
	simg.save_png(_sg_dir.path_join("shop_tile.png"))
	simg.get_region(Rect2i(60, 60, 620, 520)).save_png(_sg_dir.path_join("shop_tile_crop.png"))
	st.store_line("shop_tile.png\t-\t-\t-\t-\t-\t-\tShopTile.new(rec) for impact_driver: left at counter size 112x124, right the same tile at scale 3; rec %s" % str(rec))
	st.close()
	print("sight715: shop tile rec ", rec)


# ------------------------------------------------------------------------- 3: flume entry

func _flume() -> void:
	_take_control(true)
	var events = _game.events
	events.reward_offered.connect(func(offers: Array): _offers_seen.append(offers))
	events.panel_gained.connect(func(id: String, _c: int, _at: Vector3, _j: bool): _panels.append([Engine.get_physics_frames(), id]))
	events.launched.connect(func(_v: Vector3): _launched = true)
	events.stage_entered.connect(func(s: int, _r: bool): _stage_seen = s)
	var bp: Vector3 = _game.ctx.terrain.beacon_point(_game.run.stage)
	var drop: Vector3 = _game.ctx.terrain.drop_point(bp.x, bp.z, 1.05)
	_place_ball(drop, drop + Vector3(0, 0, -50), -0.2, true)
	await _wait_frames(30)
	_game.flow._unseal()
	await _wait_frames(10)
	if _offers_seen.is_empty():
		print("sight715: no offers")
		return
	var offer: Dictionary = _offers_seen[-1][0]
	var facing: Vector3 = offer["facing"]
	var start: Vector3 = offer["at"] - facing * 16.0
	var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
	_game.player.set_frozen(false)
	_game.player.reset_to(at, facing * 21.0)
	_game.player.body().global_position = at
	_game.camera.snap(facing)
	_driver.source.hold = {"move": Vector2(0.0, 1.0)}
	print("sight715: approach from ", at, " to gate ", offer["part_id"], " at ", offer["at"], " stage map ", String(_game.ctx.stages.of(_game.run.stage).get("map", "")))
	var launch = _game.world.launch
	var log_f := FileAccess.open(_sg_dir.path_join("trace.tsv"), FileAccess.WRITE)
	log_f.store_line("saved_frame\ttick_i\tflow\tstage\tball\tplanar_speed\tgrounded\tlanding_rings_up\tpad_visible\trail_rings_up\tpanels_total\tamber_share\tmean_rgb\tevent")
	var saved := [0]
	var touch := [-1]
	var pad_gone := [-1]
	var launched_at := [-1]
	var frames_dir := _sg_dir.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var n := 0
	for i in 1800:
		var ev := ""
		if _launched and launched_at[0] < 0:
			launched_at[0] = i
			_driver.source.hold = {}
			_game.ctx.calm = false
			ev = "launched (calm off for the next stage)"
		if _stage_seen >= 2 and touch[0] < 0 and _game.player.state.grounded:
			touch[0] = i
			ev = "touchdown"
		if touch[0] >= 0 and pad_gone[0] < 0 and not launch._pad.visible:
			pad_gone[0] = i
			ev = "pad gone %.2f s after touchdown" % ((i - touch[0]) / 90.0)
		await RenderingServer.frame_post_draw
		if i % 3 == 0:
			var img := root.get_texture().get_image()
			img.save_png(frames_dir.path_join("f%04d.png" % n))
			var am := _amber(img)
			var rails := 0
			for r in launch._rings:
				rails += 1 if r.visible else 0
			log_f.store_line("%d\t%d\t%s\t%d\t%s\t%.1f\t%s\t%d\t%s\t%d\t%d\t%.4f\t%s\t%s" % [n, i, _game.flow.state_name(), _game.run.stage, str(_game.player.ball_position().snapped(Vector3.ONE * 0.1)),
				_game.player.planar_velocity().length(), str(_game.player.state.grounded), launch.landing_rings(), str(launch._pad.visible), rails, _panels.size(), am[0], am[1], ev])
			n += 1
		if touch[0] >= 0 and i - touch[0] >= 180 and (pad_gone[0] >= 0 or i - touch[0] > 360):
			break
	log_f.close()
	print("sight715: flume frames ", n, " launched tick ", launched_at[0], " touchdown tick ", touch[0], " pad gone tick ", pad_gone[0], " panels ", _panels)


# Share of pixels (on a 240x135 downsample) in the amber family (hue 20-50 deg, sat > 0.45, value > 0.45), and the mean colour.
static func _amber(img: Image) -> Array:
	var s := img.duplicate() as Image
	s.resize(240, 135, Image.INTERPOLATE_BILINEAR)
	var hit := 0
	var r := 0.0
	var g := 0.0
	var b := 0.0
	for y in 135:
		for x in 240:
			var c := s.get_pixel(x, y)
			r += c.r
			g += c.g
			b += c.b
			if c.h >= 20.0 / 360.0 and c.h <= 50.0 / 360.0 and c.s > 0.45 and c.v > 0.45:
				hit += 1
	var t := 240.0 * 135.0
	return [hit / t, "%.2f,%.2f,%.2f" % [r / t, g / t, b / t]]


class Eraser:
	extends Node
	var ind: Node3D
	var layer := ""

	func _process(_d: float) -> void:
		if ind != null and layer != "" and ind.shapes.has(layer):
			ind.shapes.erase(layer)
