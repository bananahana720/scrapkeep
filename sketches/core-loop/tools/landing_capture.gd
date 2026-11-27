extends SceneTree


const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const AppShell := preload("res://src/core/app_shell.gd")

const SETTLE := 45
const WAIT_TICKS := 2400
const LANDED := 1.6
const WARN := 1.0
const AFTER := [0.0, 0.15, 0.35]
const RING_AT := 9.0
const RING_RADIUS := 5.0

var game
var out := ""
var records := []
var failed := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty() or AppShell.headless():
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

	var mid := _on(ground, spot + ahead * RING_AT)
	var ring: Node3D = Telegraph.ring(game.ctx.root, ground, Threat.Type.INSTANT, mid, RING_RADIUS)
	await _staged("ring", ring, true)
	var side := Vector3.UP.cross(ahead).normalized()
	var from := _on(ground, spot + ahead * 4.0 + side * 6.0)
	var lane: Node3D = Telegraph.lane(game.ctx.root, ground, Threat.Type.LANE, from, ahead, 14.0, 3.0)
	await _staged("lane", lane, false)
	if failed == "":
		await _crew(ground, spot, ahead)
	if failed != "":
		return
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	var size := root.get_visible_rect().size
	file.store_string(JSON.stringify({"tool": "landing_capture.gd", "size": [size.x, size.y], "table": game.table,
		"adapter": RenderingServer.get_video_adapter_name(), "frames": records,
		"limits": "The ring and lane are staged through the game's builders on their own clock with no fight running; the crew scene is a real chaser's lunge. Size, place and read only on a software renderer."}, "\t"))
	file.close()
	quit(0)


func _staged(id: String, mark: Node3D, free_on_land: bool) -> void:
	var ticks := roundi(WARN * Engine.physics_ticks_per_second)
	for i in ticks:
		mark.set_progress(float(i) / ticks)
		if i == roundi(ticks * 0.9):
			await _shot(id, "before", {"progress": mark.progress})
		await physics_frame
	var before: int = game.ctx.root.get_child_count()
	mark.set_progress(1.0)
	var flash: Node = game.ctx.root.get_child(game.ctx.root.get_child_count() - 1) if game.ctx.root.get_child_count() > before else null
	if flash == null:
		return _fail("%s left no landing" % id)
	if free_on_land:
		mark.free()
	await _after(id, flash, null)
	if is_instance_valid(mark):
		mark.free()
	await _ticks(30)


func _crew(ground, spot: Vector3, ahead: Vector3) -> void:
	var side := Vector3.UP.cross(ahead).normalized()
	var crew: Node3D = game.ctx.spawner.spawn_enemy("chaser", _on(ground, spot + ahead * 7.0 + side * 2.0) + Vector3.UP)
	var struck := [false]
	crew.attack_phase.connect(func(facts: Dictionary) -> void:
		if String(facts.get("phase", "")) == "strike":
			struck[0] = true)
	for i in WAIT_TICKS:
		if struck[0]:
			break
		var tele = crew.telegraph() if is_instance_valid(crew) else null
		if tele != null and tele.progress >= 0.9 and not records.any(func(r): return r["id"] == "crew" and r["at"] == "before"):
			await _shot("crew", "before", {"progress": tele.progress})
		await physics_frame
	if not struck[0]:
		return _fail("the chaser never struck")
	await _after("crew", null, crew)
	if is_instance_valid(crew):
		crew.queue_free()


func _after(id: String, flash, crew) -> void:
	var elapsed := 0.0
	for k in AFTER.size():
		var target: float = AFTER[k]
		while elapsed < target:
			await physics_frame
			elapsed += 1.0 / Engine.physics_ticks_per_second
		if k == 0:
			await _ticks(1)
			elapsed += 1.0 / Engine.physics_ticks_per_second
		var note := {"seconds": snappedf(elapsed, 0.01)}
		if flash != null:
			note["landing_alive"] = is_instance_valid(flash)
		if crew != null and is_instance_valid(crew):
			note["body_strike_flash"] = crew.strike_flashing()
		await _shot(id, str(k), note)


func _shot(id: String, at: String, note: Dictionary) -> void:
	if failed != "":
		return
	paused = true
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path := out.path_join("%s-%s.png" % [id, at])
	if root.get_texture().get_image().save_png(path) != OK:
		paused = false
		return _fail("could not save %s" % path)
	var row := {"id": id, "at": at, "sha256": FileAccess.get_sha256(path)}
	row.merge(note)
	records.append(row)
	paused = false


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
	push_error("landing_capture: %s" % why)
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


static func _on(ground, point: Vector3) -> Vector3:
	return Vector3(point.x, Telegraph.ground_under(ground, point), point.z)
