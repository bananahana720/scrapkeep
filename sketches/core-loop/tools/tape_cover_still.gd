extends SceneTree

# Stills for UA-02: how much of the screen a live hostile ground warning covers in the clear look
# and in the tape look (hostile stripes back as faint bands), at the play camera on the park map,
# and a player's own ring beside a hostile ring in each look. frames.json records, per look:
#   changed_share  the share of screen pixels that differ from the same view with no warning;
#   stripe_share   the share of pixels where this look's still differs from the clear look's
#                  (the stripes alone; 0 for clear itself);
#   stripe_added   changed_share minus the clear look's changed_share.
# Pixels are every second row and column; the HUD is in the frame and cancels out of every share.
#   gpu-run.sh <worktree> stripes --path sketches/core-loop --script res://tools/tape_cover_still.gd -- --out=/abs/dir

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

const SETTLE := 45
const WAIT_TICKS := 2400
const LANDED := 1.6
const RADIUS := 5.0
const AHEAD := 12.0
const SIDE := 7.0
const CHANGE_DISTANCE := 0.06
const LOOKS := ["clear", "tape"]

var game
var out := ""
var failed := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(3)
		return
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	var waited := 0
	while game.flow == null and waited < 600:
		waited += 1
		await physics_frame
	if game.flow == null:
		return _fail("the game never built its flow")
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	var ground = game.ctx.spawner.ground
	var down := 0
	for i in WAIT_TICKS:
		await physics_frame
		var p: Vector3 = game.player.ball_position()
		down = down + 1 if p.y - Telegraph.ground_under(ground, p) < LANDED else 0
		if down >= 30:
			break
	if down < 30:
		return _fail("the ball never landed")
	if game.hud.get("first_steps") != null:
		game.hud.first_steps.modulate.a = 0.0
	var spot: Vector3 = game.player.ball_position()
	var ahead := _flat(game.flow.beacon.global_position - spot) if is_instance_valid(game.flow.beacon) else Vector3.BACK
	await _place(spot, ahead)
	await _ticks(600)
	var side := ahead.cross(Vector3.UP)
	var at := spot + ahead * AHEAD
	var base := await _grab(spot, ahead)
	var records := []
	var clear_image: Image = null
	var clear_changed := 0.0
	for look in LOOKS:
		Threat.set_look(look)
		Threat.Painter._warmed = false
		var ring = Telegraph.ring(game.ctx.root, ground, Threat.Type.INSTANT, at, RADIUS)
		ring.lands_on_live = false
		ring.set_progress(1.0)
		await _frames(3)
		if not is_instance_valid(ring) or not ring.is_hostile() or ring.progress < 1.0:
			return _fail("%s: the hostile warning is not live" % look)
		var image := await _grab(spot, ahead)
		ring.free()
		var changed := _share(image, base)
		var stripe := 0.0
		if look == "clear":
			clear_image = image
			clear_changed = changed
		else:
			stripe = _share(image, clear_image)
		var path := out.path_join("%s.png" % look)
		if image.save_png(path) != OK:
			return _fail("could not save %s" % path)
		records.append({"id": look, "look": Threat.look(), "changed_share": snappedf(changed, 0.0001),
			"stripe_share": snappedf(stripe, 0.0001), "stripe_added": snappedf(changed - clear_changed, 0.0001),
			"png": path, "sha256": FileAccess.get_sha256(path)})
		print("COVER %s changed_share %.4f stripe_share %.4f" % [look, changed, stripe])
		var own = Telegraph.ring(game.ctx.root, ground, Threat.Type.INSTANT, at - side * SIDE, RADIUS, 3.5, Palette.AMBER)
		var foe = Telegraph.ring(game.ctx.root, ground, Threat.Type.INSTANT, at + side * SIDE, RADIUS)
		own.lands_on_live = false
		foe.lands_on_live = false
		own.set_progress(0.6)
		foe.set_progress(0.6)
		await _frames(3)
		var pair := await _grab(spot, ahead)
		own.free()
		foe.free()
		var pair_path := out.path_join("pair_%s.png" % look)
		if pair.save_png(pair_path) != OK:
			return _fail("could not save %s" % pair_path)
		records.append({"id": "pair_%s" % look, "look": Threat.look(), "png": pair_path, "sha256": FileAccess.get_sha256(pair_path)})
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	var size := root.get_visible_rect().size
	file.store_string(JSON.stringify({"tool": "tape_cover_still.gd", "size": [size.x, size.y], "change_distance": CHANGE_DISTANCE,
		"radius_m": RADIUS, "adapter": RenderingServer.get_video_adapter_name(), "frames": records}, "\t"))
	file.close()
	Threat.set_look("clear")
	quit(0)


# The frame with the game held still, so two grabs of one view differ only by the marks.
func _grab(spot: Vector3, ahead: Vector3) -> Image:
	await _place(spot, ahead, 10)
	paused = true
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	paused = false
	return image


# The share of sampled pixels where two same-size frames differ by more than CHANGE_DISTANCE.
func _share(a: Image, b: Image) -> float:
	var changed := 0
	var total := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var c := a.get_pixel(x, y)
			var o := b.get_pixel(x, y)
			if Vector3(c.r - o.r, c.g - o.g, c.b - o.b).length() > CHANGE_DISTANCE:
				changed += 1
			total += 1
	return float(changed) / maxf(1.0, total)


func _place(point: Vector3, heading: Vector3, settle := SETTLE) -> void:
	var body = game.player.body()
	body.freeze = false
	game.player.reset_to(point)
	await _ticks(2)
	body.freeze = true
	game.camera.snap(heading)
	await _frames(settle)


func _fail(why: String) -> void:
	if failed != "":
		return
	failed = why
	push_error("tape_cover_still: %s" % why)
	paused = false
	quit(4)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()
