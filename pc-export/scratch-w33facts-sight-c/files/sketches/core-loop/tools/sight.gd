extends "res://tools/bot_run.gd"
# Scratch (untracked, never committed): sight-thread evidence on the real renderer.
#   -- --mode=probe|d1v|d1a|d2|still|drum --shots=<abs dir> [bot_run flags]
# A bot run warms up to stage 1 in play; then this takes over (the driver stops ticking) and does the job.

const WorldLook := preload("res://src/presentation/world_look.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")

var _sg: Dictionary = {}
var _sg_state := "warm"
var _sg_dir := ""
var _sg_mode := ""
var _sg_frame := 0
var _sg_saved := 0
var _sg_started := false


func _initialize() -> void:
	_sg = _parse(OS.get_cmdline_user_args())
	_sg_dir = String(_sg.get("shots", ""))
	_sg_mode = String(_sg.get("mode", "probe"))
	if not _sg_mode.begins_with("probe") and (DisplayServer.get_name() == "headless" or _sg_dir == ""):
		printerr("sight: needs a rendered display and --shots=<abs dir>")
		quit(2)
		return
	if _sg_dir != "":
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


func _wait_phys(n: int) -> void:
	for i in n:
		await physics_frame


func _lighting() -> String:
	var parts := "%s (stage %d, WorldLook.STAGE_TIME)" % [WorldLook.time_id(_game.run.stage), _game.run.stage]
	var best: DirectionalLight3D = null
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		if l is DirectionalLight3D and l.is_visible_in_tree() and (best == null or l.light_energy > best.light_energy):
			best = l
	if best != null:
		parts += "; live sun pitch=%.0f yaw=%.0f energy=%.2f color=#%s" % [best.rotation_degrees.x, best.rotation_degrees.y, best.light_energy, best.light_color.to_html(false)]
	return parts


func _save_png(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)


func _tsv(file: String, row: String) -> void:
	var p := _sg_dir.path_join("shots.tsv")
	var f := FileAccess.open(p, FileAccess.READ_WRITE if FileAccess.file_exists(p) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(file + "\t" + row)
	f.close()


# Take control from the bot: a plain scripted source, calm, a ball that cannot die.
func _take_control() -> void:
	_game.run.set_max_hp(999999.0)
	_game.ctx.calm = true
	_driver.source.hold = {}
	_driver.source.press = {}


func _dam_node() -> Node3D:
	return _game.find_child("Landmark_spillway_dam", true, false) as Node3D


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var space = _game.get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


func _place_ball(at: Vector3, face: Vector3, pitch := -0.18, frozen := true) -> void:
	_game.player.set_frozen(false)
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	if frozen:
		_game.player.set_frozen(true)
	_game.camera.snap(face - at, pitch)


# ------------------------------------------------------------------------- film helpers

# Records `frames` rendered frames; every `step`th is saved as a PNG in dir (90 Hz fixed: step 3 is 30 fps).
func _film(dir: String, frames: int, step: int, per_frame: Callable = Callable()) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var n := 0
	for i in frames:
		if per_frame.is_valid():
			per_frame.call(i)
		await RenderingServer.frame_post_draw
		if i % step == 0:
			_save_png(dir.path_join("f%04d.png" % n))
			n += 1
	print("sight: film ", dir, " frames saved ", n)


func _go() -> void:
	_take_control()
	print("sight: control taken mode=", _sg_mode, " stage=", _game.run.stage, " stage_time=", _game.run.stage_time, " ball=", _game.player.ball_position())
	match _sg_mode:
		"probe":
			await _probe()
		"probe2":
			await _probe2()
		"probe3":
			await _probe3()
		"d1v", "d1a":
			await _d1(_sg_mode)
		"d2":
			await _d2()
		"still":
			await _still()
		"drum":
			await _drum()
	print("sight: done")
	quit(0)


# ------------------------------------------------------------------------- probe

func _probe() -> void:
	var dam := _dam_node()
	print("sight: ball ", _game.player.ball_position(), " yaw ", _game.camera.yaw)
	if dam != null:
		print("sight: dam node ", dam.get_path(), " xform ", dam.global_transform)
		for lp in [Vector3(0, 40, 130), Vector3(0, 40, 90), Vector3(0, 40, 60), Vector3(0, 40, 30), Vector3(0, 10, 130), Vector3(40, 40, 130), Vector3(-40, 40, 130)]:
			var from := dam.to_global(lp)
			var to := dam.to_global(Vector3(lp.x, lp.y, -200))
			var hit := _ray(from, to)
			print("sight: dam ray local ", lp, " hit ", hit.get("position", "none"), " n ", hit.get("normal", "none"), " collider ", hit.get("collider", null))
	else:
		print("sight: no dam node")
	var terr = _game.ctx.terrain
	var b: Vector3 = _game.player.ball_position()
	for dir in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var hit := _ray(b + Vector3.UP * 3, b + Vector3.UP * 3 + dir * 400.0)
		print("sight: ray ", dir, " from ball hit ", hit.get("position", "none"), " n ", hit.get("normal", "none"))
	var found := 0
	for n in _game.find_children("*", "Node3D", true, false):
		var nm := String(n.name).to_lower()
		if "cable" in nm or "drum" in nm or "spool" in nm:
			print("sight: node ", n.get_path(), " class ", n.get_class(), " pos ", n.global_position)
			found += 1
			if found > 25:
				break
	for n in _game.find_children("*", "MultiMeshInstance3D", true, false):
		print("sight: mmi ", n.get_path(), " count ", n.multimesh.instance_count, " mesh ", n.multimesh.mesh.resource_path if n.multimesh.mesh != null else "-")
		if found > 60:
			break
		found += 1


func _probe3() -> void:
	await _wait_phys(120)
	var n_group := 0
	for v in get_nodes_in_group("park_props"):
		n_group += 1
		var nm := String(v.name)
		if nm.begins_with("cable_drum") or nm.begins_with("Far_L2"):
			var info := ""
			if v is MultiMeshInstance3D:
				var mm: MultiMesh = v.multimesh
				for i in mini(mm.instance_count, 6):
					info += " " + str((v.global_transform * mm.get_instance_transform(i)).origin.snapped(Vector3.ONE * 0.1))
			elif v.has_meta("dress_member_kinds"):
				var kinds: Array = v.get_meta("dress_member_kinds")
				var pos: Array = v.get_meta("dress_member_pos")
				for i in kinds.size():
					if "cable_drum" in str(kinds[i]):
						info += " " + str(kinds[i]) + "@" + str((pos[i] as Vector3).snapped(Vector3.ONE * 0.1))
			print("sight: PP ", v.get_path(), " class ", v.get_class(), " vis ", v.visibility_range_begin, "-", v.visibility_range_end, " shadow ", v.cast_shadow, info)
	print("sight: park_props group size ", n_group)


func _probe2() -> void:
	var terr = _game.ctx.terrain
	var rows := []
	for xi in range(-160, 161, 20):
		for zi in range(380, 641, 10):
			var gp: Vector3 = terr.drop_point(float(xi), float(zi), 2.0)
			var best := 9.0
			var bn := Vector3.ZERO
			var bd := 0.0
			for k in 12:
				var a := TAU * k / 12.0
				var d := Vector3(cos(a), 0, sin(a))
				var hit := _ray(gp + Vector3.UP * 1.0, gp + Vector3.UP * 1.0 + d * 6.0)
				if hit.is_empty():
					continue
				var ny := absf((hit["normal"] as Vector3).y)
				if ny < best:
					best = ny
					bn = hit["normal"]
					bd = (hit["position"] - (gp + Vector3.UP)).length()
			if best < 0.25:
				rows.append([xi, zi, gp.y, best, bn, bd])
	print("sight: steep-wall ground points ", rows.size())
	for r in rows:
		print("sight: wall gx=%d gz=%d gy=%.1f ny=%.2f n=%s dist=%.1f" % [r[0], r[1], r[2], r[3], str(r[4]), r[5]])
	var dam := _dam_node()
	if dam != null:
		# sample the dam face column: heights where the face is vertical
		for y in range(0, 161, 10):
			var from := Vector3(0, float(y), 540.0)
			var hit := _ray(from, Vector3(0, float(y), 700.0))
			print("sight: damcol y=%d hit=%s n=%s" % [y, str(hit.get("position", "none")), str(hit.get("normal", "none"))])
		print("sight: dam z-extent test at y=60: ", _ray(Vector3(-300, 60, 639.0), Vector3(300, 60, 639.0)))


# ------------------------------------------------------------------------- D1

func _vault_state() -> String:
	var p = _game.player
	var va: Dictionary = p.kit.vault_aim
	var shapes: Dictionary = p.indicator.shapes if p.indicator != null else {}
	return "vault_aim=%s indicator_layers=%s" % ["set" if not va.is_empty() else "empty", str(shapes.keys())]


func _d1(which: String) -> void:
	var outdir := _sg_dir
	var at := Vector3(-30.0, 72.0, 638.55)
	_place_ball(at, at + Vector3(100, 0, 0), -0.15, false)
	var body: RigidBody3D = _game.player.body()
	body.gravity_scale = 0.0
	body.linear_velocity = Vector3.ZERO
	var log_f := FileAccess.open(outdir.path_join("trace.tsv"), FileAccess.WRITE)
	log_f.store_line("saved_frame\ttick_i\tball\tvelocity\tcam_pos\tcam_yaw\tstate\tinput")
	var src = _driver.source
	var saved := [0]
	var tick := func(i: int):
		var input := "none"
		if i < 180:
			body.linear_velocity = Vector3.ZERO
		else:
			if which == "d1v":
				if i == 180:
					body.gravity_scale = 1.0
					src.press = {"jump_pressed": true}
				src.hold = {"jump_held": true}
				input = "vault: jump (Space) held from tick 180 (pressed once at 180)"
			else:
				# aim: mouse look sweeps, ball hovers (gravity 0) the whole film
				body.linear_velocity = Vector3.ZERO
				var dx := 0.0
				if i < 360:
					dx = 6.0
				elif i < 720:
					dx = -6.0
				else:
					dx = 6.0
				_game.camera.look(Vector2(dx, 0))
				input = "aim: mouse look dx=%.0f px/tick" % dx
		if i % 3 == 0:
			var cam := root.get_camera_3d()
			log_f.store_line("%d\t%d\t%s\t%s\t%s\t%.3f\t%s\t%s" % [saved[0], i, str(_game.player.ball_position().snapped(Vector3.ONE * 0.01)), str(body.linear_velocity.snapped(Vector3.ONE * 0.01)), str(cam.global_position.snapped(Vector3.ONE * 0.01)), _game.camera.yaw, _vault_state(), input])
			saved[0] += 1
	# settle one second at hover before the film so the camera has caught up
	for i in 90:
		body.linear_velocity = Vector3.ZERO
		await RenderingServer.frame_post_draw
	await _film(outdir.path_join("frames"), 900, 3, tick)
	log_f.close()


# ------------------------------------------------------------------------- D2

func _d2() -> void:
	var terr = _game.ctx.terrain
	var gp: Vector3 = terr.drop_point(float(_sg.get("wallx", "-59.5")), 440.0, 2.0)
	var spot0: Vector3 = gp + Vector3.UP * 0.2
	_place_ball(spot0, gp + Vector3(100, 0, 0), -0.18, false)
	var src = _driver.source
	src.hold = {"brake_held": true}
	var log_f := FileAccess.open(_sg_dir.path_join("trace.tsv"), FileAccess.WRITE)
	log_f.store_line("saved_frame\ttick_i\tball\tcam_dist_to_ball\tcam_pitch\tpanels_run\tevent\tpop_text\tpop_width_share_of_view\tlabel_centre_px\tlabel_centre_in_view")
	var saved := [0]
	var ev := [""]
	# each pickup: re-seat the ball against the wall 30 ticks before the drop (camera pulled in each time), then drop the panel 1.2 m ahead.
	var plan := {90: ["vent_louvre", -0.18], 360: ["hull_tile", 0.55], 630: ["punch_rivet", 0.55]}
	var tick := func(i: int):
		ev[0] = ""
		for k in plan:
			if i == int(k) - 40:
				_game.player.reset_to(spot0)
				_game.player.body().linear_velocity = Vector3.ZERO
				_game.camera.snap(Vector3(100, 0, 0), float(plan[k][1]))
				ev[0] = "ball re-seated at the wall spot, camera pitch %.2f" % float(plan[k][1])
		if plan.has(i):
			var b: Vector3 = _game.player.ball_position()
			var fwd := Vector3(-sin(_game.camera.yaw), 0, -cos(_game.camera.yaw))
			var spot: Vector3 = terr.drop_point(b.x + fwd.x * 1.2, b.z + fwd.z * 1.2, 0.0) + Vector3.UP * 0.3
			_game.build.scrap.drop_panel(spot, String(plan[i][0]))
			ev[0] = "drop_panel(%s) at %s" % [plan[i][0], str(spot.snapped(Vector3.ONE * 0.01))]
		if i % 3 == 0:
			var cam := root.get_camera_3d()
			var m := _pop_measure()
			log_f.store_line("%d\t%d\t%s\t%.2f\t%.2f\t%s\t%s\t%s\t%.4f\t%s\t%s" % [saved[0], i, str(_game.player.ball_position().snapped(Vector3.ONE * 0.01)), cam.global_position.distance_to(_game.player.shown_position()), _game.camera.pitch, str(_game.run.panels), ev[0], m[0], m[1], m[2], str(m[3])])
			saved[0] += 1
	for i in 120:
		await RenderingServer.frame_post_draw
	print("sight: d2 settled; ball ", _game.player.ball_position(), " cam dist ", root.get_camera_3d().global_position.distance_to(_game.player.shown_position()))
	await _film(_sg_dir.path_join("frames"), 900, 3, tick)
	log_f.close()


# The widest visible word label on screen: [text, its width as a share of the view width]. A billboard label's two ends
# are projected: width = (string px + outline) x pixel_size x scale, along the camera's right axis.
func _pop_measure() -> Array:
	var cam := root.get_camera_3d()
	var best := ["", 0.0, "", false]
	for n in root.find_children("Word", "Label3D", true, false):
		var l := n as Label3D
		if l == null or not l.visible or l.text == "" or l.modulate.a < 0.05:
			continue
		var font: Font = l.font if l.font != null else ThemeDB.fallback_font
		var px: float = font.get_string_size(l.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x + l.outline_size
		var half: float = px * l.pixel_size * l.scale.x * 0.5
		var a: Vector3 = l.global_position - cam.global_basis.x * half
		var b: Vector3 = l.global_position + cam.global_basis.x * half
		if cam.is_position_behind(a) or cam.is_position_behind(b):
			continue
		var w := absf(cam.unproject_position(b).x - cam.unproject_position(a).x) / float(root.content_scale_size.x)
		if w > best[1]:
			var cp := cam.unproject_position(l.global_position)
			best = [l.text, w, "%d,%d" % [int(cp.x), int(cp.y)], Rect2(Vector2.ZERO, Vector2(root.content_scale_size)).has_point(cp)]
	return best


# ------------------------------------------------------------------------- lighting switch

func _daylight() -> String:
	var terrain = _game.ctx.terrain
	var stage: int = _game.run.stage
	var rootn: Node3D = terrain.geometry_root(stage)
	var world: int = _game.ctx.stages.world_of(stage)
	var loaded = terrain.map_for(stage)
	var look := WorldLook.stage_look(3, world, String(_game.ctx.stages.of(stage).get("map", "")), loaded.park if loaded != null and "park" in loaded else {})
	GraphicsPreset.enter_world(rootn, terrain.environment, look)
	if _game.world != null and _game.world.view != null:
		_game.world.view.record_fog()
	for i in 30:
		await RenderingServer.frame_post_draw
	return "noon row forced on the stage-1 map: WorldLook.stage_look(3, ...) through GraphicsPreset.enter_world"


func _shot(file: String, shows: String, lighting: String, dist: String, mode: String) -> void:
	_save_png(_sg_dir.path_join(file))
	_tsv(file, "%s\t%s\t%s\t%s\t%s" % [shows, String(_sg.get("tree", "")), lighting, dist, mode])
	print("sight: SHOT ", file)


# A temporary Camera3D (fov 50) at `pos` aimed at `aim`; returns it already current.
func _temp_cam(pos: Vector3, aim: Vector3, fov: float) -> Camera3D:
	var c := Camera3D.new()
	c.fov = fov
	c.near = 0.1
	c.far = 3000.0
	_game.add_child(c)
	c.global_position = pos
	c.look_at(aim, Vector3.UP)
	c.make_current()
	return c


# ------------------------------------------------------------------------- A

func _still() -> void:
	var terr = _game.ctx.terrain
	var pass_id := String(_sg.get("pass", "p1"))
	var b: Vector3 = _game.player.ball_position()
	var fwd := Vector3(-sin(_game.camera.yaw), 0, -cos(_game.camera.yaw))
	var side := fwd.cross(Vector3.UP).normalized()
	var mid := b + fwd * 12.0
	var pl: Vector3 = terr.drop_point(mid.x - side.x * 2.6, mid.z - side.z * 2.6, 0.0)
	var pf: Vector3 = terr.drop_point(mid.x + side.x * 2.6, mid.z + side.z * 2.6, 0.0)
	var lobber = _game.ctx.spawner.spawn_enemy("lobber", pl)
	var boss = _game.ctx.spawner.spawn_enemy("foreman", pf)
	await _wait_phys(150)
	if lobber == null or boss == null or not is_instance_valid(lobber) or not is_instance_valid(boss):
		print("sight: spawn failed ", lobber, " ", boss)
		return
	print("sight: lobber ", lobber.global_position, " foreman(Shift Boss) ", boss.global_position)
	var centre: Vector3 = (lobber.global_position + boss.global_position) * 0.5 + Vector3.UP * 1.4
	var flat := -fwd
	for e in [lobber, boss]:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	# the ball stands 12 m back and 7 m to the left of the pair, camera looking straight along fwd, so the pair sits right of centre and the ball does not cover them
	var bsp: Vector3 = terr.drop_point(centre.x - fwd.x * 12.0 - side.x * 7.0, centre.z - fwd.z * 12.0 - side.z * 7.0, 2.0)
	_place_ball(bsp, bsp + fwd * 50.0, -0.12)
	await _wait_phys(90)
	var lights := [["dawn", "natural stage-1 look"], ["day", ""]]
	for li in lights:
		var light_note: String = li[1]
		if li[0] == "day":
			light_note = await _daylight()
		var lit := _lighting()
		# chase: the game's own camera
		await RenderingServer.frame_post_draw
		var cam := root.get_camera_3d()
		_shot("a_%s_chase_%s.png" % [pass_id, li[0]], "lobber (left) + Shift Boss/foreman (right) %s; game chase camera" % pass_id, lit + " | " + light_note, "%.1f m from game camera to pair centre" % cam.global_position.distance_to(centre), "spawned (ctx.spawner.spawn_enemy), frozen (process_mode disabled) before shots; ball placed+frozen")
		# close: temporary camera
		var cpos: Vector3 = centre + flat.rotated(Vector3.UP, deg_to_rad(28.0)) * 10.5 + Vector3.UP * 1.4
		var prev := root.get_camera_3d()
		var c := _temp_cam(cpos, centre + Vector3.UP * 1.0, 55.0)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		_shot("a_%s_close_%s.png" % [pass_id, li[0]], "lobber (left) + Shift Boss/foreman (right) %s; temp Camera3D fov 55" % pass_id, lit + " | " + light_note, "%.1f m temp camera to pair centre" % cpos.distance_to(centre), "spawned (ctx.spawner.spawn_enemy), frozen; temp camera")
		prev.make_current()
		c.queue_free()
		await process_frame


# ------------------------------------------------------------------------- B

func _drum() -> void:
	var drum := Vector3(float(_sg.get("dx", "-259.0")), float(_sg.get("dy", "140.2")), float(_sg.get("dz", "-636.0")))
	if not _sg.has("dx"):
		var ball0: Vector3 = _game.player.ball_position()
		var best_d := 1.0e9
		for v in get_nodes_in_group("park_props"):
			if v is MultiMeshInstance3D and String(v.name) == "cable_drum_a_L0":
				var mm: MultiMesh = v.multimesh
				for i in mm.instance_count:
					var at: Vector3 = (v.global_transform * mm.get_instance_transform(i)).origin
					print("sight: drum_a instance ", v.get_parent().name, " ", at)
					if at.distance_to(ball0) < best_d and at.length() > 1.0:
						best_d = at.distance_to(ball0)
						drum = at
		print("sight: drum chosen ", drum)
	# keep the ball near so the stage's own streaming holds this area
	var terr = _game.ctx.terrain
	var lit_note := await _daylight()
	var sun: DirectionalLight3D = null
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		if l is DirectionalLight3D and l.is_visible_in_tree() and (sun == null or l.light_energy > sun.light_energy):
			sun = l
	var travel: Vector3 = -sun.global_basis.z
	var toward_sun := Vector3(-travel.x, 0, -travel.z).normalized()
	var lit := _lighting()
	var n := 0
	for d in [80.0, 100.0]:
		for ang in [0.0, 100.0]:
			var dir := toward_sun.rotated(Vector3.UP, deg_to_rad(ang))
			var h := 6.0
			var pos := drum + dir * sqrt(d * d - h * h) + Vector3.UP * h
			var c := _temp_cam(pos, drum + Vector3.UP * 0.6, 55.0)
			for i in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			var file := "b_drum_%dm_%s.png" % [int(d), "sunlit" if ang == 0.0 else "side"]
			_shot(file, "cable drum variant a (Vignette_mid_tool_bench_2) from %.0f m; temp Camera3D fov 55 aimed at drum, full frame" % d, lit + " | " + lit_note, "%.1f m" % pos.distance_to(drum + Vector3.UP * 0.6), "live (the stage's own park-props drum, not moved)")
			# crop: 480x270 around the screen centre, scaled 4x nearest
			var img := root.get_texture().get_image()
			var crop := img.get_region(Rect2i(720, 405, 480, 270))
			crop.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
			crop.save_png(_sg_dir.path_join(file.replace(".png", "_crop4x.png")))
			c.queue_free()
			await process_frame
