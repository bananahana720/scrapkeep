extends SceneTree

const Palette := preload("res://src/core/palette.gd")
const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const Anchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const Cable := preload("res://src/presentation/world_fx/world_fx_cable.gd")


var _out := ""
var _only: Array = []
var _shots: Array = []
var _i := -1
var _frame := 0
var _stage: Node3D
var _shot: Dictionary


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = Array(arg.trim_prefix("--only=").split(","))
	DirAccess.make_dir_recursive_absolute(_out)
	_shots = _define().filter(func(s): return _only.is_empty() or _only.has(s["name"]))
	_next.call_deferred()


func _process(_delta: float) -> bool:
	if _stage == null:
		return false
	_frame += 1
	for f in _shot.get("fire", []):
		if f[0] == _frame:
			WorldFx.fire(f[1], f[2])
	for f in _shot.get("level", []):
		if f[0] == _frame:
			for a in _stage.find_children("WorldFx_relay", "", true, false):
				a.set_level(f[1])
	if _frame == _shot.get("frames", 90):
		var img := root.get_texture().get_image()
		var path := _out.path_join("%s.png" % _shot["name"])
		img.save_png(path)
		print("still ", path)
		_stage.queue_free()
		_stage = null
		_next.call_deferred()
	return false


func _next() -> void:
	_i += 1
	if _i >= _shots.size():
		quit(0)
		return
	_shot = _shots[_i]
	_frame = 0
	_stage = Node3D.new()
	_stage.name = "Shot_%s" % _shot["name"]
	root.add_child(_stage)
	_environment(_shot)
	var cam := Camera3D.new()
	cam.fov = _shot.get("fov", 70.0)
	cam.far = 1500.0
	_stage.add_child(cam)
	cam.global_position = _shot["cam"][0]
	cam.look_at(_shot["cam"][1])
	cam.current = true
	var ball := _ball(_shot.get("ball", Vector3(0, 1.1, 0)))
	if _shot.has("world"):
		var fx := WorldFx.install(_stage, _shot["world"])
		fx.bind(cam, ball)
		if _shot.has("overlay"):
			fx.set_overlay(_shot["overlay"])
	else:
		var fx := WorldFx.install(_stage, -1)
		fx.bind(cam, ball)
	_shot["setup"].call(_stage)


func _environment(shot: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = shot.get("sky", Color("8fb3c4"))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = shot.get("ambient", Color("9aa6a8"))
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = shot.get("sky", Color("8fb3c4"))
	env.fog_density = shot.get("fog", 0.0025)
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.tonemap_white = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = shot.get("sun", Vector3(-38, 60, 0))
	sun.light_color = shot.get("sun_colour", Color("fff1d8"))
	sun.light_energy = shot.get("sun_energy", 0.95)
	sun.shadow_enabled = true
	_stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	ground.mesh = plane
	ground.material_override = _mat(shot.get("ground", Palette.SANDSTONE))
	_stage.add_child(ground)
	if shot.get("deck", false):
		ground.position.y = -160.0
		_box(_stage, Vector3(60, 2, 60), Vector3(0, -1, -10), shot.get("deck_colour", Color("8b8f8a")))


func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _ball(at: Vector3) -> Node3D:
	var b := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.1
	s.height = 2.2
	b.mesh = s
	b.material_override = _mat(Palette.COPPER, 0.4)
	_stage.add_child(b)
	b.global_position = at
	return b


func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = _mat(c)
	parent.add_child(m)
	m.global_position = at
	return m


func _cyl(parent: Node3D, r: float, h: float, at: Vector3, c: Color, top := -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r if top < 0.0 else top
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	m.material_override = _mat(c)
	parent.add_child(m)
	m.global_position = at
	return m


func _fx(parent: Node3D, set_id: String, at: Vector3, yaw_deg := 0.0) -> Node3D:
	var a := Anchor.make(set_id)
	parent.add_child(a)
	a.global_position = at
	a.rotation_degrees.y = yaw_deg
	return a


func _water(parent: Node3D, size: Vector2, at: Vector3) -> void:
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = size
	m.mesh = p
	var mat := _mat(Color("4f7c7a"), 0.08)
	mat.metallic = 0.3
	m.material_override = mat
	parent.add_child(m)
	m.global_position = at


func _define() -> Array:
	var spill := {"sky": Color("9cc1cc"), "ground": Color("b99a72"), "ambient": Color("a7b4b2")}
	var dig := {"sky": Color("3b2e26"), "ground": Color("8a6a4c"), "ambient": Color("6e5a48"), "fog": 0.012,
		"sun": Vector3(-60, 30, 0), "sun_colour": Color("ffc27a"), "sun_energy": 0.9}
	var high := {"sky": Color("b8d3e3"), "ground": Color("c9d6dd"), "deck": true, "ambient": Color("b5c3cc"), "fog": 0.0012}
	var shots: Array = []
	shots.append(spill.merged({"name": "01-spillway-air", "world": 1, "cam": [Vector3(0, 5.5, 13), Vector3(0, 1.5, -6)], "frames": 60,
		"setup": func(s):
			_water(s, Vector2(40, 24), Vector3(0, 0.05, -18))
			_box(s, Vector3(40, 9, 3), Vector3(0, 4.5, -30), Palette.SANDSTONE)
			_fx(s, "spill_falls", Vector3(-4, 0.2, -26))
			_fx(s, "spill_pool", Vector3(-6, 0.08, -18))
			_box(s, Vector3(0.6, 0.6, 3), Vector3(7, 4, -12), Palette.RUST)
			_fx(s, "spill_pipe", Vector3(7, 3.6, -10.6))}))
	shots.append(spill.merged({"name": "02-spillway-splash", "world": 1, "cam": [Vector3(4, 3.5, 8), Vector3(0, 1, -4)], "frames": 40,
		"fire": [[30, "ball_splash", Vector3(0, 0.1, -4)]], "ball": Vector3(0, 0.6, -4),
		"setup": func(s): _water(s, Vector2(30, 30), Vector3(0, 0.05, -4))}))
	shots.append(dig.merged({"name": "03-dig-air", "world": 2, "cam": [Vector3(0, 4.5, 11), Vector3(0, 2, -8)], "frames": 60,
		"setup": func(s):
			_box(s, Vector3(30, 14, 2), Vector3(0, 7, -16), Color("6d523c"))
			_box(s, Vector3(5, 1.2, 2.4), Vector3(-6, 9, -14), Color("5a4532"))
			_fx(s, "dig_ledge", Vector3(-6, 8.3, -13.6))
			_cyl(s, 0.9, 3.0, Vector3(6, 2.5, -12), Palette.CHARCOAL)
			var drill := _fx(s, "dig_drill", Vector3(6, 2.2, -10.6), 180.0)
			drill.rotation_degrees.y = 200.0
			_cyl(s, 0.35, 0.4, Vector3(-11, 0.2, -10), Palette.RUST)
			_fx(s, "dig_vent", Vector3(-11, 0.5, -10))
			_cyl(s, 0.08, 4.0, Vector3(2, 2.0, -6), Palette.CHARCOAL)
			var lamp := _cyl(s, 0.22, 0.3, Vector3(2, 4.1, -6), Palette.AMBER)
			(lamp.material_override as StandardMaterial3D).emission_enabled = true
			(lamp.material_override as StandardMaterial3D).emission = Palette.AMBER
			_fx(s, "dig_lamp", Vector3(2, 4.3, -6))}))
	shots.append(high.merged({"name": "04-highdraft-air", "world": 3, "cam": [Vector3(0, 6, 14), Vector3(0, 2, -10)], "frames": 70,
		"setup": func(s):
			_cyl(s, 0.3, 14, Vector3(-9, 7, -12), Palette.CHARCOAL)
			_cyl(s, 0.3, 11, Vector3(12, 5.5, -22), Palette.CHARCOAL)
			s.add_child(Cable.make(Vector3(-9, 13.5, -12), Vector3(12, 10.8, -22), 3.5))
			s.add_child(Cable.make(Vector3(-9, 12.0, -12), Vector3(12, 9.5, -22), 4.5))
			_fx(s, "hd_cable", Vector3(1, 9.0, -17))}))
	shots.append(spill.merged({"name": "05-landmark-dam", "world": 1, "cam": [Vector3(26, 10, 46), Vector3(0, 16, -20)], "frames": 110,
		"sun": Vector3(-30, 150, 0),
		"setup": func(s):
			_box(s, Vector3(70, 40, 10), Vector3(0, 20, -30), Color("9f8d74"))
			_water(s, Vector2(120, 80), Vector3(0, 0.05, 20))
			_fx(s, "landmark_dam", Vector3(0, 38, -24.5))}))
	shots.append(spill.merged({"name": "06-landmark-penstock", "world": 1, "cam": [Vector3(-26, 10, 40), Vector3(0, 22, -6)], "frames": 120,
		"setup": func(s):
			_cyl(s, 5, 46, Vector3(0, 23, -10), Color("8c7b67"))
			_cyl(s, 1.2, 4, Vector3(5.5, 34, -10), Palette.RUST)
			_fx(s, "landmark_penstock_tower", Vector3(6.5, 34, -10))}))
	shots.append(dig.merged({"name": "07-landmark-headframe", "world": 2, "cam": [Vector3(18, 8, 30), Vector3(0, 14, -6)], "frames": 120,
		"setup": func(s):
			for x in [-5.0, 5.0]:
				_box(s, Vector3(0.8, 30, 0.8), Vector3(x, 15, -8), Palette.RUST)
			_box(s, Vector3(11, 0.8, 0.8), Vector3(0, 30, -8), Palette.RUST)
			_cyl(s, 3, 0.6, Vector3(0, 32, -8), Palette.CHARCOAL).rotation_degrees.x = 90
			_fx(s, "landmark_headframe", Vector3(0, 26, -8))
			_fx(s, "landmark_headframe", Vector3(0, 32, -8)).set_meta("note", "sheave")}))
	shots.append(dig.merged({"name": "08-landmark-sinkhole", "world": 2, "cam": [Vector3(0, 48, 72), Vector3(0, -6, 0)], "frames": 150,
		"fog": 0.004,
		"setup": func(s):
			_cyl(s, 48, 2, Vector3(0, 0.6, 0), Color("2a211b"), 40)
			_cyl(s, 36, 30, Vector3(0, -14, 0), Color("17120f"), 20)
			_fx(s, "landmark_sinkhole", Vector3(0, 3.0, 0))}))
	shots.append(high.merged({"name": "09-landmark-sky-island", "world": 3, "cam": [Vector3(40, 10, 70), Vector3(0, 30, -10)], "frames": 140,
		"setup": func(s):
			_cyl(s, 18, 14, Vector3(0, 52, -10), Color("8a7f72"), 22)
			_cyl(s, 14, 18, Vector3(0, 38, -10), Color("6e6458"), 2)
			s.add_child(Cable.make(Vector3(10, 45, -10), Vector3(40, 0, -30), 6.0, 0.25, Palette.CABLE))
			_fx(s, "landmark_sky_island", Vector3(0, 30, -10))
			_fx(s, "landmark_sky_island", Vector3(10, 45, -10)).name = "TetherSparks"}))
	shots.append(high.merged({"name": "10-landmark-spire", "world": 3, "cam": [Vector3(0, 30, 80), Vector3(0, 45, 0)], "frames": 120,
		"setup": func(s):
			_cyl(s, 30, 40, Vector3(0, 20, 0), Color("7d7468"), 15)
			_cyl(s, 15, 30, Vector3(0, 55, 0), Color("837a6e"), 26)
			_cyl(s, 26, 10, Vector3(0, 75, 0), Color("8c8276"), 8)
			_fx(s, "landmark_spire", Vector3(0, 48, 0))}))
	for step in [["11-relay-charge-30", 0.3, []], ["12-relay-charge-90", 0.9, []],
			["13-relay-full", 1.0, [[48, "relay_full", Vector3(0, 0.5, 0)]]]]:
		shots.append(spill.merged({"name": step[0], "world": 1, "cam": [Vector3(0, 18, 38), Vector3(0, 3, 0)], "frames": 60,
			"level": [[1, step[1]]], "fire": step[2], "ball": Vector3(6, 1.1, 8),
			"setup": func(s):
				_cyl(s, 1.6, 9, Vector3(0, 4.5, 0), Palette.CHARCOAL, 0.8)
				_cyl(s, 24, 0.1, Vector3(0, 0.06, 0), Color("a88c69"))
				_fx(s, "relay", Vector3(0, 0.3, 0))}))
	shots.append(spill.merged({"name": "14-relay-stake", "world": 1, "cam": [Vector3(0, 8, 20), Vector3(0, 4, 0)], "frames": 46,
		"fire": [[30, "relay_stake", Vector3(0, 9, 0)]], "ball": Vector3(4, 1.1, 6),
		"setup": func(s): _cyl(s, 1.6, 9, Vector3(0, 4.5, 0), Palette.CHARCOAL, 0.8)}))
	shots.append(spill.merged({"name": "15-modifier-shown", "world": 1, "cam": [Vector3(0, 4, 10), Vector3(0, 3, 0)], "frames": 42,
		"fire": [[30, "modifier_shown", Vector3(0, 1, 0)]], "ball": Vector3(0, 1.1, 0), "setup": func(_s): pass}))
	for o in [["16-overlay-plenty", "plenty", 1, spill], ["17-overlay-scarce", "scarce", 2, dig],
			["18-overlay-hidden", "hidden", 1, spill], ["19-weather-dust", "dust", 1, spill],
			["20-weather-storm", "storm_build", 3, high]]:
		shots.append(o[3].merged({"name": o[0], "world": o[2], "overlay": o[1], "cam": [Vector3(0, 5, 12), Vector3(0, 1.5, -6)],
			"frames": 70, "setup": func(s): _box(s, Vector3(8, 6, 8), Vector3(-10, 3, -18), Palette.SANDSTONE)}))
	shots.append(spill.merged({"name": "21-secret-glint", "world": 1, "cam": [Vector3(3, 3, 12), Vector3(-2, 2, -6)], "frames": 70,
		"ball": Vector3(4, 1.1, 2),
		"setup": func(s):
			_box(s, Vector3(10, 7, 2), Vector3(-2, 3.5, -10), Palette.SANDSTONE)
			_box(s, Vector3(2.2, 3, 2.2), Vector3(-2, 1.5, -9), Palette.CHARCOAL)
			_fx(s, "secret", Vector3(-2, 1.8, -7.6))}))
	shots.append(spill.merged({"name": "22-secret-found", "world": 1, "cam": [Vector3(3, 3, 9), Vector3(-1, 2.5, -4)], "frames": 46,
		"fire": [[30, "secret_found", Vector3(-1, 1, -4)]], "ball": Vector3(-1, 1.1, -4),
		"setup": func(s): _box(s, Vector3(10, 7, 2), Vector3(-2, 3.5, -10), Palette.SANDSTONE)}))
	shots.append({"name": "23-camp", "sky": Color("2b3346"), "ground": Color("5e5240"), "ambient": Color("47506a"),
		"sun": Vector3(-14, 110, 0), "sun_colour": Color("e07a52"), "sun_energy": 0.5, "fog": 0.01,
		"cam": [Vector3(0, 3.2, 9), Vector3(0, 1.2, 0)], "frames": 90, "ball": Vector3(-3.5, 1.1, 1),
		"setup": func(s):
			var fire := OmniLight3D.new()
			fire.light_color = Color("ff9a4a")
			fire.light_energy = 3.0
			fire.omni_range = 9.0
			s.add_child(fire)
			fire.global_position = Vector3(0, 0.9, 0)
			_cyl(s, 0.9, 0.3, Vector3(0, 0.15, 0), Palette.CHARCOAL)
			_fx(s, "camp", Vector3(0, 0.4, 0))
			_cyl(s, 0.25, 0.4, Vector3(1.6, 0.5, 0.6), Palette.COPPER)})
	shots.append({"name": "24-title-slam", "sky": Color("1d1f24"), "ground": Color("2c2a28"), "ambient": Color("3a3c44"),
		"sun": Vector3(-50, -30, 0), "sun_energy": 0.6, "cam": [Vector3(0, 1.6, 6), Vector3(0, 1.6, 0)], "frames": 40,
		"fire": [[33, "title_slam", Vector3(0, 1.6, 0)]], "ball": Vector3(2.2, 1.1, -1),
		"setup": func(s):
			var shaft := SpotLight3D.new()
			shaft.light_energy = 6.0
			shaft.spot_angle = 18.0
			shaft.spot_range = 14.0
			s.add_child(shaft)
			shaft.global_position = Vector3(-1.5, 8, 0)
			shaft.look_at(Vector3(-1.5, 0, 0), Vector3.FORWARD)
			_fx(s, "title", Vector3(-1.5, 3.2, 0))})
	shots.append({"name": "25-summary-win", "sky": Color("2f3a33"), "ground": Color("4b4a3c"), "ambient": Color("6b7360"),
		"cam": [Vector3(0, 1.8, 6), Vector3(0, 1.6, 0)], "frames": 70, "ball": Vector3(0, 1.1, 0),
		"fire": [[52, "summary_win", Vector3(0, 0.5, 0.5)]],
		"setup": func(s): _fx(s, "summary_win", Vector3(0, 0, 0))})
	shots.append({"name": "26-summary-loss", "sky": Color("2a2d33"), "ground": Color("3c3b38"), "ambient": Color("50555e"),
		"sun_energy": 0.6, "cam": [Vector3(0, 1.8, 6), Vector3(0, 1.6, 0)], "frames": 90, "ball": Vector3(0, 1.1, 0),
		"setup": func(s): _fx(s, "summary_loss", Vector3(0, 0, 0))})
	return shots
