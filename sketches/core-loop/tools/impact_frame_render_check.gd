extends SceneTree

# Real-render proof that the impact frame yields on the GPU (lighting L7, #241). It needs a
# display, because canvas shaders do not run headless; under xvfb the Compatibility renderer
# runs them:
#   xvfb-run -a -s "-screen 0 1280x720x24" $GODOT_BIN --path sketches/core-loop \
#     --resolution 1280x720 --script res://tools/impact_frame_render_check.gd
# A full-strength, full-heat frame is fired over a solid background with one warning rect
# inside the edge band, and the viewport is grabbed. The pixels inside the rect plus the
# margin must equal the background, while pixels in the band outside it must not. The
# control fires the same frame with no rects: the same pixels must then change.
const PlayerFx := preload("res://src/presentation/player_fx.gd")

const WARNING := Rect2(40.0, 300.0, 200.0, 200.0)
const BACKGROUND := Color(0.6, 0.6, 0.6)

var _frame: PlayerFx.ImpactFrame
var _rects: Array[Rect2] = []


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("impact_frame_render_check: needs a display (run under xvfb-run)")
		quit(2)
		return
	var back_layer := CanvasLayer.new()
	root.add_child(back_layer)
	var back := ColorRect.new()
	back.color = BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_layer.add_child(back)
	var layer := CanvasLayer.new()
	layer.layer = 3
	root.add_child(layer)
	_frame = PlayerFx.ImpactFrame.new()
	_frame.rect_source = func() -> Array[Rect2]: return _rects
	layer.add_child(_frame)
	_run.call_deferred()


func _grab() -> Image:
	_frame.hide_now()
	_frame.fire(Vector2(800.0, 450.0), 1.0, 5, 0.9)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


# Counts pixels that differ from the background inside `area` (image px).
func _changed(img: Image, area: Rect2i) -> int:
	var n := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if img.get_pixel(x, y) != BACKGROUND:
				n += 1
	return n


func _run() -> void:
	await process_frame
	# The first draw after the shader loads comes up empty; one throwaway fire primes it.
	await _grab()
	var img0 := await _grab()
	var scale: float = float(img0.get_width()) / get_root().get_visible_rect().size.x
	var margin := PlayerFx.ImpactFrame.YIELD_MARGIN_PX
	# Inside the grown rect, one image pixel shy of its edge on every side.
	var grown := WARNING.grow(margin)
	var inside := Rect2i(Vector2i(ceili(grown.position.x * scale) + 1, ceili(grown.position.y * scale) + 1), Vector2i(floori(grown.size.x * scale) - 3, floori(grown.size.y * scale) - 3))
	# The band beside it: the strip of the left edge above the rect, clear of the margin.
	var beside := Rect2i(Vector2i(0, 0), Vector2i(floori(WARNING.end.x * scale), floori((grown.position.y - 1.0) * scale)))
	var unyielded := _changed(img0, inside)
	var band := _changed(img0, beside)
	_rects = [WARNING]
	var img1 := await _grab()
	var yielded := _changed(img1, inside)
	var band_kept := _changed(img1, beside)
	print("impact_frame_render_check: image %s, scale %.3f, inside area %s (%d px), beside area %s" % [img1.get_size(), scale, inside, inside.get_area(), beside])
	print("impact_frame_render_check: no rects: %d changed px inside the rect, %d beside it" % [unyielded, band])
	print("impact_frame_render_check: one rect: %d changed px inside the rect (want 0), %d beside it (want > 0)" % [yielded, band_kept])
	var ok := unyielded > 0 and yielded == 0 and band_kept > 0
	print("impact_frame_render_check: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
