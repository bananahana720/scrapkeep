extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

const EVENTS := ["dust", "sparks", "crit", "slam", "latch", "crack", "ember", "rupture", "grit", "thermal_occ", "thermal_idle", "net_sag", "miniboss"]
const SCENES := {"rupture": 3, "grit": 3, "thermal_occ": 5, "thermal_idle": 5, "net_sag": 5, "miniboss": 1}
const T0 := 240
const STEP := 3
const SHOTS := 8

var game
var out := ""
var event := "slam"
var ticks := 0
var cam: Camera3D
var source := Intent.Scripted.new()
var site := Vector3.ZERO
var enemy: Node3D
var shot := 0
var waiting := -1
var done := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--event="):
			event = arg.substr(8)
	if out == "" or event not in EVENTS:
		printerr("w12_fx_capture: -- --out=<abs dir> --event=", "|".join(EVENTS))
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("FXCAP renderer: ", RenderingServer.get_video_adapter_name(), " | ", RenderingServer.get_current_rendering_method())
	game = Game.new()
	game.test_mode = true
	if SCENES.has(event):
		game.table = "alpha"
	root.add_child(game)
	RenderingServer.frame_post_draw.connect(_drawn)


func _physics_process(_delta: float) -> bool:
	if game == null or game.flow == null or done:
		return false
	ticks += 1
	if ticks == 1:
		_stage()
	elif ticks == T0 - 150 and event in ["sparks", "crit", "latch"]:
		enemy = game.ctx.spawner.spawn_enemy("lobber", game.ctx.terrain.drop_point(site.x + 1.5, site.z - 1.0, 1.2))
	elif SCENES.has(event):
		_scene_tick()
	elif ticks == T0 - 40 and event != "dust":
		_hold_still()
	elif ticks == T0 - 30 and event != "dust":
		game.player.body().freeze = true
	elif ticks == T0 - 20 and event == "dust":
		game.player.reset_to(game.ctx.terrain.drop_point(site.x - 14.0, site.z, 1.0), Vector3(24, 0, 0))
	elif ticks == T0:
		_fire()
	if event == "dust" and ticks >= T0 - 20:
		source.hold = {"move": Vector2(0, -1)}
	if ticks >= T0 and (ticks - T0) % STEP == 0 and shot < SHOTS:
		waiting = 1
	return false


func _stage() -> void:
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = source
	source.hold = {"brake_held": true}
	if SCENES.has(event):
		if SCENES[event] != 1:
			game.flow.enter_stage(SCENES[event], Vector3.ZERO, false)
		cam = Camera3D.new()
		cam.far = 1800.0
		game.add_child(cam)
		cam.current = true
		game.hud.visible = false
		return
	var bowl: Vector3 = game.ctx.terrain.beacon_point(1) + Vector3(10, 0, 8)
	site = game.ctx.terrain.drop_point(bowl.x, bowl.z, 0.0)
	game.player.reset_to(game.ctx.terrain.drop_point(bowl.x - 3.0, bowl.z + 1.5, 1.2))
	cam = Camera3D.new()
	game.add_child(cam)
	cam.fov = 50.0
	cam.current = true
	game.hud.visible = false
	cam.global_position = site + Vector3(7.5, 5.0, 9.0)
	cam.look_at(site + Vector3(0, 0.8, 0))
	if event == "ember":
		var cache := site + Vector3(1.5, 0.0, -1.0)
		cam.global_position = cache + Vector3(7.0, 3.0, -6.0)
		cam.look_at(cache, Vector3.UP)


func _hold_still() -> void:
	game.player.reset_to(game.ctx.terrain.drop_point(site.x - 3.0, site.z + 1.5, 1.2))
	if is_instance_valid(enemy):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.global_position = game.ctx.terrain.drop_point(site.x + 1.5, site.z - 1.0, 0.0)


func _scene_tick() -> void:
	var terrain = game.ctx.terrain
	if ticks == 100:
		match event:
			"rupture":
				var stage_root: Node3D = terrain.geometry_root(3)
				var plate: Dictionary = terrain.map().breach_plates[0]
				var centre: Vector2 = plate["rect"].get_center()
				var cover: Node3D = stage_root.get_node("BreachPlate_" + String(plate["id"]))
				site = Vector3(centre.x, cover.get_meta("home").y, centre.y)
				game.player.reset_to(site + Vector3(7.0, 3.0, 9.0))
				_look(site + Vector3(18, 12, 18), site + Vector3(0, -1, 0), 55.0)
			"grit":
				var fx = terrain.geometry_root(3).get_node("DigScenery/DigFx")
				site = fx.to_global(fx.faces[0])
				game.player.reset_to(site + Vector3(3, 2, 0))
				_look(site + Vector3(7, 2.5, 5), site + Vector3(0, 1, 0), 55.0)
			"thermal_occ", "thermal_idle", "net_sag":
				var wind = terrain.geometry_root(5).get_node("HighdraftScenery/WindEffects")
				site = wind.thermals[0].presence.base
				if event == "thermal_occ":
					game.player.reset_to(site + Vector3.UP * 14.0)
					_look(site + Vector3(-18, 12, 4), site + Vector3(0, 14, 0), 60.0)
				elif event == "thermal_idle":
					game.player.reset_to(site + Vector3(8.0, 14.0, 0.0))
					_look(site + Vector3(-18, 12, 4), site + Vector3(0, 14, 0), 60.0)
				else:
					site = _deck_point(terrain, site)
					game.player.reset_to(site + Vector3(-2.5, 1.0, 1.5))
					_look(site + Vector3(5, 5, 7), site + Vector3(0, 0.5, 0), 55.0)
			"miniboss":
				var b: Vector3 = game.player.ball_position()
				enemy = game.combat.spawn_enemy("miniboss", Vector3(b.x + 22, terrain.height(b.x + 22, b.z + 10) + 6, b.z + 10))
	elif ticks == 101 and event != "miniboss":
		game.player.body().freeze = true
	elif ticks == T0 - 40 and event == "miniboss":
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		site = enemy.global_position
		game.player.reset_to(site + Vector3(-9.0, 1.0, 4.0))
	elif ticks == T0 - 30 and event == "miniboss":
		game.player.body().freeze = true
		_look(site + Vector3(-9, 4, 9), site + Vector3(0, 3, 0), 55.0)
	elif ticks == T0 - 1 and event == "net_sag":
		game.player.body().freeze = true
	elif ticks == T0:
		_fire()


func _deck_point(terrain, near: Vector3) -> Vector3:
	var deck: float = terrain.map().net_deck_height()
	for ring in range(14, 54, 2):
		for step in 12:
			var a := TAU * step / 12.0
			var x: float = near.x + cos(a) * ring
			var z: float = near.z + sin(a) * ring
			if absf(float(terrain.map().sample(x, z)[0]) - deck) <= 0.05:
				return Vector3(x, deck, z)
	return near


func _look(eye: Vector3, target: Vector3, fov: float) -> void:
	cam.global_position = eye
	cam.look_at(target, Vector3.UP)
	cam.fov = fov


func _fire() -> void:
	var events = game.ctx.events
	match event:
		"dust":
			pass
		"sparks":
			if is_instance_valid(enemy):
				events.enemy_struck.emit(enemy, "ram", 24.0)
		"crit":
			if is_instance_valid(enemy):
				game.presentation.juice.resolve_of = func(_e, _k, f): return {"dealt": f * 2.0, "punch": f, "full": true, "part": "", "plating": 0.0}
				events.enemy_struck.emit(enemy, "ram", 24.0)
		"ember":
			events.world_fact.emit("cache_spent", site + Vector3(1.5, 0.0, -1.0))
		"rupture":
			game.world._on_slammed(site, 20, 1)
		"grit", "thermal_occ", "thermal_idle":
			pass
		"net_sag":
			var fx = game.ctx.terrain.geometry_root(5).get_node("HighdraftScenery/WindEffects")
			print("FXCAP net_sag deck point ", site)
			fx.catch_at(site + Vector3(0, 1.0, 0))
			print("FXCAP net_sag catches ", fx.active_catches.size())
		"miniboss":
			var j = game.presentation.juice
			print("FXCAP miniboss resolve ", j.resolve_of.call(enemy, "ram", 24.0) if j.resolve_of.is_valid() else "no resolver")
			j.resolve_of = func(_e, _k, f): return {"dealt": f, "punch": f, "full": true, "part": "", "plating": 0.0}
			events.enemy_struck.emit(enemy, "ram", 24.0)
		"slam":
			events.slammed.emit(game.ctx.terrain.drop_point(site.x, site.z, 0.0), 1.0, 1.0)
		"latch":
			if is_instance_valid(enemy):
				events.harpoon_bit.emit(enemy, _surface_toward_ball(enemy))
		"crack":
			events.world_fact.emit("wall_crumbled", site + Vector3(1.5, 1.0, -1.0))
	print("FXCAP fired ", event, " at tick ", ticks, " ball ", game.player.ball_position(), " speed ", game.player.planar_velocity().length())


func _surface_toward_ball(body: Node3D) -> Vector3:
	var centre: Vector3 = body.global_position + Vector3.UP * 1.2
	var toward: Vector3 = game.player.ball_position() - centre
	toward.y = 0.0
	return centre + toward.normalized() * 1.4


func _drawn() -> void:
	if done or waiting < 0:
		return
	waiting -= 1
	if waiting > 0:
		return
	var path := "%s/f%d.png" % [out, shot]
	root.get_texture().get_image().save_png(path)
	print("FXCAP saved ", path, " tick ", ticks, " target ", T0 + shot * STEP)
	shot += 1
	waiting = -1
	if shot >= SHOTS:
		var vfx = game.presentation.vfx if game.presentation != null else null
		print("FXCAP spawned ", vfx.spawned if vfx != null else {})
		done = true
		quit(0)
