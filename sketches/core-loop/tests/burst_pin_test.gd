# smoke: fixed-fps=60 (every wait is counted in physics frames; none reads the wall clock)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const Industrial := preload("res://src/world/events/industrial.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const T := preload("res://tests/support/t.gd")

const SEED := 47
const FIGHT_FRAMES := 240
const NEAR := 0.01
const CREW := [["swatter", Vector3(4, 0, 0)], ["plated_brute", Vector3(-5, 0, 2)], ["boom_tender", Vector3(0, 0, 6)],
	["netcaster", Vector3(3, 0, -5)], ["ramp_flipper", Vector3(-4, 0, -4)], ["dispatcher", Vector3(7, 0, 4)],
	["chaser", Vector3(-7, 0, 0)], ["lobber", Vector3(0, 0, -9)], ["jolt_layer", Vector3(6, 0, -2)],
	["foreman", Vector3(-3, 0, 7)], ["hooker", Vector3(-6, 0, -7)], ["mag_trapper", Vector3(8, 0, -6)]]
const EXPECTED := [
	[189, "brass_spark", "root", 8, "d9b44aff", false, 5.9093633, 65.08954, -167.43033, 0.0, 0.0, -1.0],
	[207, "slam_dust", "root", 10, "c6a274ff", false, 0.0, 57.331463, -160.0, 0.0, 0.0, -1.0],
	[208, "brass_spark", "root", 10, "d9b44aff", false, 1.269556, 58.12515, -162.0575, 0.0, 0.0, -1.0],
	[208, "steam_puff", "root", 5, "e6d9b8bf", false, 1.269556, 58.12515, -162.0575, 0.0, 0.0, -1.0],
	[240, "arc_fizz", "root", 4, "9dff3cff", false, 9.026425, 60.84256, -160.59593, 0.0, 0.0, -1.0],
	[240, "brass_spark", "root", 3, "d9b44aff", false, 9.026425, 60.84256, -160.59593, 0.0, 0.0, -1.0],
	[241, "steam_puff", "root", 10, "e6d9b8bf", false, -3.1668277, 62.11821, -152.14732, 0.0, 0.0, -1.0],
	[241, "brass_spark", "root", 8, "d9b44aff", false, -3.5102835, 63.449333, -153.08931, 0.0, 0.0, -1.0],
	[242, "brass_spark", "root", 14, "d9b44aff", false, -5.379856, 58.38577, -160.38443, 0.0, 0.0, -1.0],
	[242, "plate_chunks", "root", 10, "9b513aff", false, -5.379856, 58.38577, -160.38443, 0.0, 0.0, -1.0],
	[243, "brass_spark", "root", 14, "d9b44aff", false, 2.3620012, 58.75751, -159.99278, 0.0, 0.0, -1.0],
	[243, "spark_core", "root", 10, "d2c5a5ff", false, 2.3620012, 58.75751, -159.99278, 0.0, 0.0, -1.0],
	[244, "brass_spark", "root", 14, "d9b44aff", false, 3.9789808, 60.025146, -160.35484, 0.0, 0.0, -1.0],
	[244, "steam_puff", "root", 8, "e6d9b8bf", false, 3.9789808, 60.025146, -160.35484, 0.0, 0.0, -1.0],
	[244, "slam_ring", "root", 16, "d2c5a5ff", false, 3.9789808, 60.025146, -160.35484, 0.0, 0.0, -1.0],
	[245, "brass_spark", "root", 14, "d9b44aff", false, -5.379856, 58.38577, -160.38443, 0.0, 0.0, -1.0],
	[245, "plate_chunks", "root", 10, "9b513aff", false, -5.379856, 58.38577, -160.38443, 0.0, 0.0, -1.0],
	[245, "arc_fizz", "root", 14, "9dff3cff", false, 0.0, 59.081463, -160.0, 0.0, 0.0, -1.0],
	[245, "phase_ring", "root", 24, "d9b44aff", false, 0.0, 58.781464, -160.0, 0.0, 0.0, -1.0],
	[245, "brass_spark", "root", 12, "d9b44aff", false, 0.0, 59.081463, -160.0, 0.0, 0.0, -1.0],
	[246, "plate_chunks", "root", 14, "9b513aff", false, 7.0, 65.87425, -156.0, 0.0, 0.0, -1.0],
	[246, "brass_spark", "root", 16, "d9b44aff", false, 7.0, 65.87425, -156.0, 0.0, 0.0, -1.0],
	[246, "steam_puff", "root", 10, "e6d9b8bf", false, 7.0, 65.87425, -156.0, 0.0, 0.0, -1.0],
	[247, "brass_spark", "root", 14, "d9b44aff", false, 0.0, 0.4, 0.0, 0.0, 0.0, -1.0],
	[297, "steam_puff", "root", 6, "e6d9b8bf", false, 0.48026112, 68.199615, -167.94469, 0.0, 0.0, -1.0],
	[298, "brass_spark", "root", 10, "d9b44aff", false, 0.0, 57.731464, -160.0, 0.0, 0.0, -1.0],
	[298, "slam_dust", "root", 8, "c6a274ff", false, 0.0, 57.331463, -160.0, 0.0, 0.0, -1.0],
	[337, "steam_puff", "IndustrialEvents", 10, "e6d9b8bf", false, 1.2470766, 59.181465, -148.72, 0.0, 0.0, -1.0],
	[337, "steam_puff", "IndustrialEvents", 10, "e6d9b8bf", false, 3.4641016, 59.181465, -150.0, 0.0, 0.0, -1.0],
	[337, "steam_puff", "IndustrialEvents", 10, "e6d9b8bf", false, 5.6811266, 59.181465, -151.28, 0.0, 0.0, -1.0],
	[338, "steam_puff", "IndustrialEvents", 10, "e6d9b8bf", false, 1.2470766, 59.181465, -148.72, 0.0, 0.0, -1.0],
	[338, "arc_fizz", "IndustrialEvents", 12, "9dff3cff", false, 1.2470766, 59.181465, -148.72, 0.0, 0.0, -1.0],
	[338, "steam_puff", "IndustrialEvents", 10, "e6d9b8bf", false, 3.4641016, 59.181465, -150.0, 0.0, 0.0, -1.0],
	[338, "arc_fizz", "IndustrialEvents", 12, "9dff3cff", false, 3.4641016, 59.181465, -150.0, 0.0, 0.0, -1.0],
	[338, "steam_puff", "IndustrialEvents", 10, "e6d9b8bf", false, 5.6811266, 59.181465, -151.28, 0.0, 0.0, -1.0],
	[338, "arc_fizz", "IndustrialEvents", 12, "9dff3cff", false, 5.6811266, 59.181465, -151.28, 0.0, 0.0, -1.0],
	[339, "steam_puff", "IndustrialEvents", 10, "e5a044ff", false, 1.2470766, 59.181465, -148.72, 0.0, 0.0, -1.0],
	[339, "brass_spark", "IndustrialEvents", 12, "e5a044ff", false, 1.2470766, 59.181465, -148.72, 0.0, 0.0, -1.0],
	[339, "steam_puff", "IndustrialEvents", 10, "e5a044ff", false, 3.4641016, 59.181465, -150.0, 0.0, 0.0, -1.0],
	[339, "brass_spark", "IndustrialEvents", 12, "e5a044ff", false, 3.4641016, 59.181465, -150.0, 0.0, 0.0, -1.0],
	[339, "steam_puff", "IndustrialEvents", 10, "e5a044ff", false, 5.6811266, 59.181465, -151.28, 0.0, 0.0, -1.0],
	[339, "brass_spark", "IndustrialEvents", 12, "e5a044ff", false, 5.6811266, 59.181465, -151.28, 0.0, 0.0, -1.0],
	[340, "steam_puff", "IndustrialEvents", 8, "e6d9b8bf", false, 2.1, 59.081463, -148.0, 0.0, 0.0, -1.0],
	[340, "crack_debris", "IndustrialEvents", 8, "242a28ff", false, 2.1, 59.081463, -148.0, 0.0, 0.0, -1.0],
	[340, "steam_puff", "IndustrialEvents", 8, "e6d9b8bf", false, 1.05, 59.081463, -146.18135, 0.0, 0.0, -1.0],
	[340, "crack_debris", "IndustrialEvents", 8, "242a28ff", false, 1.05, 59.081463, -146.18135, 0.0, 0.0, -1.0],
	[340, "steam_puff", "IndustrialEvents", 8, "e6d9b8bf", false, -1.05, 59.081463, -146.18135, 0.0, 0.0, -1.0],
	[340, "crack_debris", "IndustrialEvents", 8, "242a28ff", false, -1.05, 59.081463, -146.18135, 0.0, 0.0, -1.0],
	[340, "steam_puff", "IndustrialEvents", 8, "e6d9b8bf", false, -2.1, 59.081463, -148.0, 0.0, 0.0, -1.0],
	[340, "crack_debris", "IndustrialEvents", 8, "242a28ff", false, -2.1, 59.081463, -148.0, 0.0, 0.0, -1.0],
	[340, "steam_puff", "IndustrialEvents", 8, "e6d9b8bf", false, -1.05, 59.081463, -149.81865, 0.0, 0.0, -1.0],
	[340, "crack_debris", "IndustrialEvents", 8, "242a28ff", false, -1.05, 59.081463, -149.81865, 0.0, 0.0, -1.0],
	[340, "steam_puff", "IndustrialEvents", 8, "e6d9b8bf", false, 1.05, 59.081463, -149.81865, 0.0, 0.0, -1.0],
	[340, "crack_debris", "IndustrialEvents", 8, "242a28ff", false, 1.05, 59.081463, -149.81865, 0.0, 0.0, -1.0],
	[341, "steam_puff", "Contraptions", 8, "e6d9b8bf", false, 0.0, 59.281464, -172.0, 0.0, 0.0, -1.0]
]

var _t := T.new("burst_pin_test")
var _game
var _ball_at := Vector3.ZERO
var _start := 0
var _pending: Array = []
var _rows: Array = []
var _by_signature := {}


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		_game.player.reset_to(_ball_at)
		await physics_frame
		_take()


func _on_node_added(node: Node) -> void:
	if node is GPUParticles3D and node.one_shot and node.has_meta("fx_look"):
		_pending.append([node, Engine.get_physics_frames() - _start])


func _signature(p: GPUParticles3D) -> String:
	var pm := p.process_material as ParticleProcessMaterial
	return var_to_str([p.amount, p.lifetime, p.get_meta("fx_look"), p.draw_pass_1.get_aabb(), pm.spread,
		pm.initial_velocity_min, pm.initial_velocity_max, pm.radial_velocity_min, pm.gravity, pm.emission_shape, pm.color])


func _ids() -> Dictionary:
	if not _by_signature.is_empty():
		return _by_signature
	for id: String in FxLibrary.SPECS:
		var q := FxLibrary.build(id)
		var key := _signature(q)
		_by_signature[key] = (_by_signature[key] + "|" + id) if _by_signature.has(key) else id
		q.free()
	return _by_signature


func _id_of(p: GPUParticles3D) -> String:
	return _ids().get(_signature(p), "unknown")


func _parent_label(p: Node) -> String:
	var parent := p.get_parent()
	if parent == _game.ctx.root:
		return "root"
	var label := String(parent.name)
	return label.get_slice("@", 1) if label.begins_with("@") else label


func _take() -> void:
	for entry in _pending:
		var p: GPUParticles3D = entry[0]
		if not is_instance_valid(p):
			_rows.append([entry[1], "freed", "", 0, "", false, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
			continue
		var at := p.global_transform.origin
		var fwd := -p.global_transform.basis.z
		var tint: Color = p.get_instance_shader_parameter(FxLibrary.TINT)
		_rows.append([entry[1], _id_of(p), _parent_label(p), roundi(p.amount_ratio * p.amount),
			tint.to_html(), p.top_level, at.x, at.y, at.z, fwd.x, fwd.y, fwd.z])
	_pending.clear()


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = SEED
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	for i in 3:
		await physics_frame
	for group in ["enemy", "enemy_shot", "telegraph"]:
		for node in get_nodes_in_group(group):
			if is_instance_valid(node):
				node.free()
	var spawn: Vector3 = _game.ctx.terrain.spawn_point(1)
	_ball_at = _game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)


func _spawn(kind: String, offset: Vector3) -> Node3D:
	var at := _ball_at + offset
	var unit = _game.combat.spawn_enemy(kind, _game.ctx.terrain.drop_point(at.x, at.z, 1.4))
	unit.hp = 5000.0
	return unit


func _fight() -> Dictionary:
	var units := {}
	for row in CREW:
		units[row[0]] = _spawn(row[0], row[1])
	await _frames(FIGHT_FRAMES)
	return units


func _scripted(units: Dictionary) -> void:
	units.jolt_layer._crackle(4, 3)
	await _frames(1)
	units.foreman._steam_blast_fx()
	await _frames(1)
	units.plated_brute._fling_plate()
	await _frames(1)
	units.chaser._air_parry(false)
	await _frames(1)
	units.swatter._springboard_vault()
	await _frames(1)
	units.netcaster._trigger_emp(_ball_at)
	await _frames(1)
	units.dispatcher._on_cargo_pod_impact()
	await _frames(1)
	units.mag_trapper._polarity_flip = true
	units.mag_trapper._punt_disc()
	await _frames(90)


func _stage_event() -> void:
	var industrial := Industrial.new()
	industrial.name = "IndustrialEvents"
	industrial.world = _game.world
	_game.world.add_child(industrial)
	var at := _ball_at + Vector3(0, 0, 12)
	for kind in ["steam_cone", "arc_steam_cone", "burner_flare", "fallout_ring"]:
		industrial._spawn_plume({"effect": {"hazard": kind, "hazard_m": [8.0, 6.0]}}, {"site": {"yaw_deg": 30.0}, "at": at})
		await _frames(1)
	var machines := Contraptions.new()
	machines.name = "Contraptions"
	_game.world.add_child(machines)
	machines._puff(_ball_at + Vector3(0, 1, -12), 5.0)
	await _frames(1)


func _matches(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in 6:
		if got[i] != want[i]:
			return false
	for i in range(6, 12):
		if absf(float(got[i]) - float(want[i])) > NEAR:
			return false
	return true


func _run() -> void:
	await _boot()
	_ids()
	node_added.connect(_on_node_added)
	_start = Engine.get_physics_frames()
	var units := await _fight()
	await _scripted(units)
	await _stage_event()
	node_added.disconnect(_on_node_added)
	_t.check("the fight, the scripted calls and the stage event ask for bursts", not _rows.is_empty())
	_t.check("the pin holds a record to compare", not EXPECTED.is_empty())
	_t.check("every burst names exactly one effect of the library",
		_rows.all(func(row: Array) -> bool: return FxLibrary.SPECS.has(row[1])))
	_t.eq("as many bursts as the record", _rows.size(), EXPECTED.size())
	var first_wrong := -1
	for i in mini(_rows.size(), EXPECTED.size()):
		if not _matches(_rows[i], EXPECTED[i]):
			first_wrong = i
			break
	_t.check("every burst has the recorded effect, parent, frame, count, tint and place", first_wrong < 0,
		"first difference at row %d: got %s want %s" % [first_wrong, _rows[first_wrong], EXPECTED[first_wrong]] if first_wrong >= 0 else "")
	if first_wrong >= 0 or _rows.size() != EXPECTED.size():
		print("BURSTS %d" % _rows.size())
		for row in _rows:
			print("\t%s," % var_to_str(row).replace("\n", ""))
	_game.free()
	quit(_t.verdict())
