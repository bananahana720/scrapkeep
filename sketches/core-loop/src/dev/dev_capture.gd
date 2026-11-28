extends Node

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const DevLook := preload("res://src/dev/dev_look.gd")
const DevLens := preload("res://src/dev/dev_lens.gd")
const DevFight := preload("res://src/dev/dev_fight.gd")
const DevOverlay := preload("res://src/dev/dev_overlay.gd")
const FrameRead := preload("res://src/presentation/frame_read.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const SafeStore := preload("res://src/core/safe_store.gd")

signal said(line: String, tone: String)

const SHOT_DIR := "user://dev_shots"
const SHEET_SCALE := 0.34
const SHEET_AXES := ["presets", "cams", "quality"]
const SHEET_SETTLE := {"presets": 4, "cams": 6, "quality": 10}
const SHEET_GUTTER := 4
const SHEET_HEADER := 28
const SHEET_CAPTION := 28
const SHEET_DEAD_EDGE := 4
const SAME_LUMA := 0.002

var game
var console
var look: DevLook
var lens: DevLens
var fight: DevFight
var overlay: DevOverlay
var shot_dir := SHOT_DIR
var _drawer: Control
var _ink: Color
var _shots := 0
var _busy := false


func setup(game_ref, console_ref, drawer: Control, ink: Color) -> void:
	game = game_ref
	console = console_ref
	look = console.look
	lens = console.lens
	fight = console.fight
	overlay = console.overlay
	_drawer = drawer
	_ink = ink
	name = "DevCapture"


func shot(id := "", close_menu := false) -> String:
	var result: Dictionary = await shot_detailed(id, close_menu)
	return String(result.text)


func shot_detailed(id := "", close_menu := false) -> Dictionary:
	if _busy:
		return _answer(false, "!a still or sheet is already running")
	_busy = true
	if close_menu:
		console.unpause()
	DirAccess.make_dir_recursive_absolute(shot_dir)
	_shots += 1
	var stem := id if id.is_valid_filename() and id != "" else "shot-%03d-%d" % [_shots, Engine.get_frames_drawn()]
	var path := shot_dir.path_join(stem + ".png")
	var was := _drawer.visible
	_drawer.visible = false
	overlay.set_capture_hide(false, overlay.active_layers().perf != "on")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return {"ok": false, "text": "!the console closed before the still", "data": {}}
	var image := _grab()
	_drawer.visible = was and console.open
	overlay.set_capture_hide(false, false)
	_busy = false
	if image == null:
		return _answer(false, "!no viewport image in headless mode")
	var read := FrameRead.metrics(image)
	var err := image.save_png(path)
	if err != OK:
		return _answer(false, "!could not save %s (%d)" % [path, err])
	var data := {"path": ProjectSettings.globalize_path(path), "width": image.get_width(), "height": image.get_height(),
		"metrics": read, "dead_frame": FrameRead.is_dead(read), "cam": lens.mode, "look": look.preset_name,
		"quality": GraphicsPreset.current, "stage": _stage_name()}
	SafeStore.write_atomic(shot_dir.path_join(stem + ".json"), JSON.stringify(data, "\t"))
	var dead := FrameRead.note(read)
	return _answer(true, "still -> %s%s" % [data.path, ("  dead frame: " + dead) if dead != "" else ""], data)


func qa_pack_detailed(id := "", close_menu := false) -> Dictionary:
	if _busy:
		return _answer(false, "!a still or sheet is already running")
	_busy = true
	if close_menu:
		console.unpause()
	DirAccess.make_dir_recursive_absolute(shot_dir)
	_shots += 1
	var stem := id if id.is_valid_filename() and id != "" else "qa-pack-%03d-%d" % [_shots, Engine.get_frames_drawn()]
	var was := _drawer.visible
	_drawer.visible = false
	overlay.set_capture_hide(false, overlay.active_layers().perf != "on")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return {"ok": false, "text": "!the console closed before qa_pack", "data": {}}
	var image := _grab()
	_drawer.visible = was and console.open
	overlay.set_capture_hide(false, false)
	_busy = false
	if image == null:
		return _answer(false, "!no viewport image in headless mode")
	var read := FrameRead.metrics(image)
	var pack := DevLook.build_qa_pack_images(image)
	var suffixes := {
		"rgb_1080p": "_1080p_rgb.png",
		"downscale_720p": "_720p.png",
		"greyscale_rec709": "_greyscale.png",
		"cvd_deuteranopia_machado": "_deuteranopia.png",
	}
	var oracles := {}
	for key in suffixes:
		var out_img: Image = pack[key]
		var out_path := shot_dir.path_join(stem + String(suffixes[key]))
		var err := out_img.save_png(out_path)
		if err != OK:
			return _answer(false, "!could not save %s (%d)" % [out_path, err])
		oracles[key] = {
			"path": ProjectSettings.globalize_path(out_path),
			"width": out_img.get_width(),
			"height": out_img.get_height(),
			"metrics": FrameRead.metrics(out_img),
		}
	var data := {
		"path": oracles.rgb_1080p.path,
		"stem": stem,
		"source_width": image.get_width(),
		"source_height": image.get_height(),
		"metrics": read,
		"dead_frame": FrameRead.is_dead(read),
		"oracles": oracles,
		"cam": lens.mode,
		"look": look.preset_name,
		"quality": GraphicsPreset.current,
		"stage": _stage_name(),
	}
	SafeStore.write_atomic(shot_dir.path_join(stem + "_qa_pack.json"), JSON.stringify(data, "\t"))
	var dead := FrameRead.note(read)
	return _answer(true, "qa_pack -> %s%s" % [data.path, ("  dead frame: " + dead) if dead != "" else ""], data)


func contact_sheet(close_menu := false) -> String:
	var result: Dictionary = await sheet_detailed("presets", "", close_menu)
	return String(result.text)


func sheet_detailed(axis := "presets", id := "", close_menu := false) -> Dictionary:
	if _busy:
		return _answer(false, "!a still or sheet is already running")
	axis = axis.to_lower()
	if not axis in SHEET_AXES:
		return _answer(false, "!sheet takes %s" % ", ".join(SHEET_AXES))
	_busy = true
	var held_look := look.snapshot()
	var held_lens := lens.snapshot()
	var held_quality := GraphicsPreset.current
	if close_menu:
		console.unpause()
	var was_frozen := fight.frozen()
	var scale := fight.time_scale()
	fight.set_time(0.0)
	var was := _drawer.visible
	_drawer.visible = false
	overlay.set_capture_hide(true, true)
	var header := "%s | cam %s | frame %d | %s" % [axis, lens.mode, Engine.get_frames_drawn(), _stage_name()]
	var ids := sheet_ids(axis)
	var tiles: Array[Image] = []
	var reads: Array = []
	var failed := ""
	for step in ids:
		_sheet_step(axis, step)
		for i in int(SHEET_SETTLE[axis]):
			await RenderingServer.frame_post_draw
		if not is_inside_tree():
			return {"ok": false, "text": "!the console closed before the sheet", "data": {}}
		var image := _grab()
		if image == null:
			failed = "!no viewport image in headless mode"
			break
		reads.append(FrameRead.metrics(image))
		image.resize(maxi(1, int(image.get_width() * SHEET_SCALE)), maxi(1, int(image.get_height() * SHEET_SCALE)), Image.INTERPOLATE_LANCZOS)
		tiles.append(image)
	look.clear()
	look.load_snapshot(held_look)
	lens.restore(held_lens)
	if GraphicsPreset.current != held_quality:
		GraphicsPreset.apply(held_quality)
	fight.set_time(0.0 if was_frozen else scale)
	if failed != "":
		overlay.set_capture_hide(false, false)
		_drawer.visible = was and console.open
		_busy = false
		return _answer(false, failed)
	var rows: Array = []
	for i in ids.size():
		var tag := ""
		if axis == "quality" and ids[i] == "target":
			var high := ids.find("high")
			if high >= 0 and absf(float(reads[i].mean_luma) - float(reads[high].mean_luma)) / 255.0 <= SAME_LUMA:
				tag = "= high"
		var label := ("%02d %s %s" % [i + 1, ids[i], tag]).strip_edges()
		rows.append({"index": i + 1, "id": ids[i], "label": label, "tag": tag, "metrics": reads[i], "dead": FrameRead.is_dead(reads[i]),
			"note": FrameRead.note(reads[i])})
	var sheet := await _compose(tiles, rows, header)
	if not is_inside_tree():
		return {"ok": false, "text": "!the console closed before the sheet", "data": {}}
	overlay.set_capture_hide(false, false)
	_drawer.visible = was and console.open
	_busy = false
	DirAccess.make_dir_recursive_absolute(shot_dir)
	_shots += 1
	var stem := id if id.is_valid_filename() and id != "" else "sheet-%s-%03d-%d" % [axis, _shots, Engine.get_frames_drawn()]
	var path := shot_dir.path_join(stem + ".png")
	var err := sheet.save_png(path)
	if err != OK:
		return _answer(false, "!could not save the sheet (%d)" % err)
	var grid := sheet_grid(ids.size())
	var dead := rows.filter(func(r): return r.dead).size()
	var data := {"path": ProjectSettings.globalize_path(path), "axis": axis, "header": header, "width": sheet.get_width(),
		"height": sheet.get_height(), "columns": grid.x, "rows": grid.y, "tiles": rows, "dead_count": dead,
		"dead_frame": dead > 0, "cam": lens.mode, "look": look.preset_name,
		"quality": GraphicsPreset.current, "stage": _stage_name()}
	SafeStore.write_atomic(shot_dir.path_join(stem + ".json"), JSON.stringify(data, "\t"))
	return _answer(true, "sheet of %d %s (%s)%s -> %s" % [ids.size(), axis, ", ".join(ids),
		("  %d dead" % dead) if dead > 0 else "", data.path], data)


static func sheet_ids(axis: String) -> Array:
	match axis:
		"cams":
			var cams: Array = ["game"]
			for mode in DevLens.MODES:
				if mode != "game":
					cams.append(mode)
			return cams
		"quality":
			return GraphicsPreset.PRESETS.keys()
	return DevLook.PRESETS.keys()


static func sheet_grid(n: int) -> Vector2i:
	if n <= 0:
		return Vector2i(1, 1)
	if n <= 3:
		return Vector2i(n, 1)
	var best := Vector2i(3, ceili(n / 3.0))
	for cols in [4, 5]:
		var rows := ceili(float(n) / cols)
		if cols * rows - n <= best.x * best.y - n:
			best = Vector2i(cols, rows)
	return best


func _sheet_step(axis: String, step: String) -> void:
	match axis:
		"presets":
			look.apply_preset(step)
		"cams":
			lens.use(step)
			lens.spin = 0.0
		"quality":
			GraphicsPreset.apply(step)


func _grab() -> Image:
	var texture := get_viewport().get_texture()
	var image := texture.get_image() if texture != null else null
	if image == null or image.is_empty():
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _compose(tiles: Array[Image], rows: Array, header: String) -> Image:
	var grid := sheet_grid(tiles.size())
	var w := tiles[0].get_width()
	var h := tiles[0].get_height()
	var g := SHEET_GUTTER
	var size := Vector2i(grid.x * w + (grid.x + 1) * g, SHEET_HEADER + grid.y * (h + SHEET_CAPTION) + (grid.y + 1) * g)
	var print_vp := SubViewport.new()
	print_vp.name = "SheetLabels"
	print_vp.size = size
	print_vp.disable_3d = true
	print_vp.transparent_bg = false
	print_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var board := ColorRect.new()
	board.color = Palette.CHARCOAL
	board.size = Vector2(size)
	print_vp.add_child(board)
	board.add_child(_sheet_label(header, Vector2(g * 2, 0), Vector2(size.x - g * 4, SHEET_HEADER), _ink))
	for i in tiles.size():
		var at := _tile_at(i, grid, w, h)
		var colour := Palette.HAZARD if rows[i].dead else _ink
		var text: String = rows[i].label + (("  " + rows[i].note) if rows[i].dead else "")
		board.add_child(_sheet_label(text, Vector2(at.x + UiTokens.GAP_XS, at.y + h), Vector2(w - UiTokens.GAP_XS, SHEET_CAPTION), colour))
	add_child(print_vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var sheet: Image = null
	if is_inside_tree():
		sheet = print_vp.get_texture().get_image()
	print_vp.queue_free()
	if sheet == null or sheet.is_empty() or sheet.get_size() != size:
		sheet = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		sheet.fill(Palette.CHARCOAL)
	if sheet.get_format() != Image.FORMAT_RGBA8:
		sheet.convert(Image.FORMAT_RGBA8)
	for i in tiles.size():
		var at := _tile_at(i, grid, w, h)
		sheet.blit_rect(tiles[i], Rect2i(0, 0, w, h), at)
		if rows[i].dead:
			var e := SHEET_DEAD_EDGE
			for edge in [Rect2i(at.x, at.y, w, e), Rect2i(at.x, at.y + h - e, w, e), Rect2i(at.x, at.y, e, h), Rect2i(at.x + w - e, at.y, e, h)]:
				sheet.fill_rect(edge, Palette.HAZARD)
	return sheet


func _tile_at(i: int, grid: Vector2i, w: int, h: int) -> Vector2i:
	var g := SHEET_GUTTER
	return Vector2i(g + (i % grid.x) * (w + g), SHEET_HEADER + g + (i / grid.x) * (h + SHEET_CAPTION + g))


func _sheet_label(text: String, at: Vector2, span: Vector2, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiFonts.mono())
	label.add_theme_font_size_override("font_size", UiTokens.CAPTION)
	label.add_theme_color_override("font_color", colour)
	label.position = at
	label.size = span
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	return label


func _stage_name() -> String:
	var run = game.get("run") if game != null else null
	var state: String = game.flow.state_name() if game != null and game.flow != null else ""
	if run != null and state != "title":
		return "w%d s%d %s" % [int(run.world), int(run.stage), state]
	return state


func _answer(ok: bool, text: String, data := {}) -> Dictionary:
	said.emit(text, "ok" if ok else "warn")
	return {"ok": ok, "text": text, "data": data}
