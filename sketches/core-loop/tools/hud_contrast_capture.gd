extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")

const SIZE := Vector2i(1280, 720)
const STAGES := [1, 2]
const VIEWS := {"ground": -0.30, "sky": 0.45}
const WORD_LINE := 4.5
const MARK_LINE := 3.0
const DIFFER := 3
const MATCH := 10
const MIN_GLYPH := 8
const PAD := 8
const AROUND := 3
const OUTLINE_SHARE := 0.5
const LANDED := 1.6
const SETTLE := 12

var out := ""
var plant := ""
var game
var records: Array = []
var _hidden: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--plant="):
			plant = a.trim_prefix("--plant=")
	if DisplayServer.get_name() == "headless" or out == "":
		printerr("needs a display and --out")
		quit(2)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot() -> Image:
	for i in SETTLE:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _run() -> void:
	seed(40440)
	game = Game.new()
	game.test_mode = true
	game.table = Game.LAUNCH_TABLE
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	DirAccess.make_dir_recursive_absolute(out)
	for stage in STAGES:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await _frames(60)
		if not await _rest():
			printerr("the ball never rested in stage %d" % stage)
			quit(4)
			return
		for view in VIEWS:
			await _view(stage, view)
	var scored := 0
	var failed := 0
	var worst_word := INF
	var worst_mark := INF
	var event_worst := INF
	var plant_close := INF
	var plant_control := INF
	for rec in records:
		if rec["name"] == "PlantClose" and rec["scored"]:
			plant_close = minf(plant_close, rec["contrast"])
		elif rec["name"] == "PlantControl" and rec["scored"]:
			plant_control = minf(plant_control, rec["contrast"])
		if rec["scored"]:
			scored += 1
			if not rec["pass"]:
				failed += 1
			if rec["kind"] == "word":
				worst_word = minf(worst_word, rec["contrast"])
			else:
				worst_mark = minf(worst_mark, rec["contrast"])
			if rec["event_line"]:
				event_worst = minf(event_worst, rec["contrast"])
	var pass_all := scored > 0 and failed == 0
	var code := 0 if pass_all else 1
	if plant == "close":
		pass_all = plant_close >= WORD_LINE
		code = 3 if plant_control < WORD_LINE or plant_control == INF else (0 if pass_all else 1)
	var head: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], head)
	var f := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"tool": "hud_contrast_capture.gd", "head": String(head[0]).strip_edges() if head.size() > 0 else "",
		"plant": plant, "adapter": RenderingServer.get_video_adapter_name(), "size": [SIZE.x, SIZE.y],
		"word_line": WORD_LINE, "mark_line": MARK_LINE, "scored": scored, "failed": failed,
		"worst_word": snappedf(worst_word, 0.01) if worst_word < INF else null,
		"worst_mark": snappedf(worst_mark, 0.01) if worst_mark < INF else null,
		"worst_event_line": snappedf(event_worst, 0.01) if event_worst < INF else null,
		"plant_close_worst": snappedf(plant_close, 0.01) if plant_close < INF else null,
		"plant_control_worst": snappedf(plant_control, 0.01) if plant_control < INF else null,
		"verdict": "pass" if pass_all else "fail", "elements": records}, "\t"))
	f.close()
	print("hud_contrast_capture: plant=%s scored %d, failed %d, worst word %s, worst mark %s, event line %s -> %s" % [plant, scored, failed, worst_word, worst_mark, event_worst, "pass" if pass_all else "fail"])
	quit(code)


func _rest() -> bool:
	var landed := 0
	for i in 2400:
		await physics_frame
		var p: Vector3 = game.player.ball_position()
		landed = landed + 1 if p.y - Telegraph.ground_under(game.ctx.spawner.ground, p) < LANDED else 0
		if landed >= 30:
			game.player.body().freeze = true
			await _frames(120)
			return true
	return false


func _view(stage: int, view: String) -> void:
	var heading: Vector3 = -game.camera.cam.global_transform.basis.z
	game.camera.pitch = VIEWS[view]
	game.camera.snap(heading, VIEWS[view])
	game.events.event_announced.emit("lightning", 20.0, Vector3.INF)
	await _frames(90)
	var wait := 0
	while game.hud.launch_card.showing() and wait < 900:
		wait += 1
		await physics_frame
	await _frames(60)
	paused = true
	var with_hud := await _shot()
	_layers(false)
	var ground := await _shot()
	var ground2 := await _shot()
	var extra: Array = []
	if plant == "close":
		extra.append(_plant_word(ground, "SCRAP TOLD HERE", true, 0.55))
		extra.append(_plant_word(ground, "SCRAP TOLD HERE", false, 0.70))
	_layers(true)
	if plant == "close":
		await _shot()
		with_hud = await _shot()
	var tag := "stage%d-%s" % [stage, view]
	with_hud.save_png(out.path_join(tag + "-hud.png"))
	ground.save_png(out.path_join(tag + "-ground.png"))
	var noise := 0
	for y in range(0, ground.get_height(), 4):
		for x in range(0, ground.get_width(), 4):
			var a := ground.get_pixel(x, y)
			var b := ground2.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) * 255.0 >= DIFFER:
				noise += 1
	for node in _elements(extra):
		var rec := _measure_node(node, with_hud, ground, stage, view)
		rec["png"] = out.path_join(tag + "-hud.png")
		rec["ground_noise_samples"] = noise
		records.append(rec)
	paused = false
	for n in extra:
		(n as Node).get_parent().queue_free()
	print("%s: %d elements so far, ground noise samples %d" % [tag, records.size(), noise])


func _layers(on: bool) -> void:
	if not on:
		_hidden.clear()
		for n in root.find_children("*", "CanvasLayer", true, false):
			if n.visible:
				_hidden.append(n)
				n.visible = false
	else:
		for n in _hidden:
			if is_instance_valid(n):
				n.visible = true


func _plant_word(ground: Image, text: String, close: bool, down: float) -> Label:
	var layer := CanvasLayer.new()
	layer.layer = 90
	root.add_child(layer)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 40)
	label.position = Vector2(SIZE.x * 0.55, SIZE.y * down)
	label.name = "PlantClose" if close else "PlantControl"
	layer.add_child(label)
	var at := Rect2i(Vector2i(label.position), Vector2i(360, 50))
	var sum := Vector3.ZERO
	var n := 0
	for y in range(at.position.y, at.end.y, 2):
		for x in range(at.position.x, at.end.x, 2):
			var c := ground.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			n += 1
	var mean := sum / maxf(1.0, n)
	var tone := Color(mean.x, mean.y, mean.z)
	if close:
		tone = Color(mean.x + 0.05, mean.y + 0.05, mean.z + 0.05)
	else:
		tone = Color.WHITE if ratio(1.0, luminance(tone)) > ratio(0.0, luminance(tone)) else Color.BLACK
	label.add_theme_color_override("font_color", tone)
	return label


func _elements(extra: Array) -> Array:
	var nodes: Array = []
	for n in game.hud.find_children("*", "Label", true, false):
		nodes.append(n)
	for n in game.hud.find_children("*", "TextureRect", true, false):
		nodes.append(n)
	nodes.append_array(extra)
	return nodes


func _measure_node(node: Control, shot: Image, ground: Image, stage: int, view: String) -> Dictionary:
	var is_word := node is Label
	var rec := {"stage": stage, "view": view, "name": str(node.name), "kind": "word" if is_word else "mark", "scored": false,
		"event_line": node == game.hud._toast_label, "pass": false, "contrast": 0.0, "ground_contrast": 0.0}
	if is_word:
		rec["text"] = (node as Label).text
	if not node.is_visible_in_tree() or (is_word and (node as Label).text == ""):
		rec["why"] = "not shown"
		return rec
	var xf := node.get_global_transform_with_canvas()
	var corners := [xf * Vector2.ZERO, xf * Vector2(node.size.x, 0.0), xf * node.size, xf * Vector2(0.0, node.size.y)]
	var lo: Vector2 = corners[0]
	var hi: Vector2 = corners[0]
	for c: Vector2 in corners:
		lo = lo.min(c)
		hi = hi.max(c)
	var rect := Rect2i(Vector2i(lo) - Vector2i(PAD, PAD), Vector2i(hi - lo) + Vector2i(PAD * 2, PAD * 2)).intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	if rect.size.x < 4 or rect.size.y < 4:
		rec["why"] = "off screen"
		return rec
	var font := Color.WHITE
	if is_word:
		font = node.get_theme_color("font_color")
		font *= node.self_modulate
		var chain: CanvasItem = node
		while chain != null:
			font *= chain.modulate
			chain = chain.get_parent() as CanvasItem
	var m := measure(shot, ground, rect, font if is_word else Color(0, 0, 0, -1))
	rec.merge(m, true)
	rec["pass"] = rec["scored"] and rec["contrast"] >= (WORD_LINE if is_word else MARK_LINE)
	rec["line"] = WORD_LINE if is_word else MARK_LINE
	rec["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	return rec


static func measure(shot: Image, ground: Image, rect: Rect2i, font: Color) -> Dictionary:
	var is_mark := font.a < 0.0
	var w := rect.size.x
	var h := rect.size.y
	var glyph := PackedByteArray()
	glyph.resize(w * h)
	var shown := PackedByteArray()
	shown.resize(w * h)
	var count := 0
	for j in h:
		for i in w:
			var s := shot.get_pixel(rect.position.x + i, rect.position.y + j)
			var g := ground.get_pixel(rect.position.x + i, rect.position.y + j)
			if _apart(s, g) < float(DIFFER):
				continue
			shown[j * w + i] = 1
			if is_mark:
				glyph[j * w + i] = 1
				count += 1
			else:
				var e := Color(font.r * font.a + g.r * (1.0 - font.a), font.g * font.a + g.g * (1.0 - font.a), font.b * font.a + g.b * (1.0 - font.a))
				if _apart(s, e) <= float(MATCH):
					glyph[j * w + i] = 1
					count += 1
	var rec := {"scored": false, "contrast": 0.0, "ground_contrast": 0.0, "glyph_px": count, "around_px": 0}
	if count < MIN_GLYPH:
		return rec
	var near := _dilate(glyph, w, h, AROUND)
	var core_lum := []
	var ground_lum := []
	var ring_lum := []
	var drawn_lum := []
	for j in h:
		for i in w:
			var k := j * w + i
			var s := shot.get_pixel(rect.position.x + i, rect.position.y + j)
			if glyph[k] == 1:
				core_lum.append(luminance(s))
				ground_lum.append(luminance(ground.get_pixel(rect.position.x + i, rect.position.y + j)))
			elif near[k] == 1:
				ring_lum.append(luminance(s))
				if shown[k] == 1:
					drawn_lum.append(luminance(s))
	if ring_lum.is_empty():
		return rec
	var share := float(drawn_lum.size()) / float(ring_lum.size())
	var around_lum: Array = drawn_lum if share >= OUTLINE_SHARE else ring_lum
	rec["around_px"] = around_lum.size()
	rec["surround"] = "outline" if share >= OUTLINE_SHARE else "ring"
	rec["outline_share"] = snappedf(share, 0.01)
	rec["scored"] = true
	var core := _median(core_lum)
	var around := _median(around_lum)
	if around_lum == drawn_lum:
		around = _quantile(drawn_lum, 0.25 if core > around else 0.75)
	rec["contrast"] = snappedf(ratio(core, around), 0.01)
	rec["ring_contrast"] = snappedf(ratio(core, _median(ring_lum)), 0.01)
	rec["ground_contrast"] = snappedf(ratio(core, _median(ground_lum)), 0.01)
	return rec


static func _apart(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) * 255.0


static func _dilate(mask: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	var out_mask := PackedByteArray()
	out_mask.resize(w * h)
	for j in h:
		for i in w:
			if mask[j * w + i] == 1:
				for dj in range(maxi(0, j - r), mini(h, j + r + 1)):
					for di in range(maxi(0, i - r), mini(w, i + r + 1)):
						out_mask[dj * w + di] = 1
	return out_mask


static func _quantile(values: Array, q: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(q * float(sorted.size())), 0, sorted.size() - 1)]


static func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


static func luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func ratio(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
