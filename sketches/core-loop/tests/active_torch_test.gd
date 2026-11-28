extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const Torch := preload("res://src/combat/actives/cutting_torch.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const T := preload("res://tests/support/t.gd")

# The Cutting Torch active (Redjaw Workshops, design page "Makers and Actives", 17 Oct 2026). A
# real Game with the first pilot and --actives on. Covers: the row; a press draws the guide line
# (an outline) for the 0.3 s wind-up and fires nothing; then the beam lights filled on the same
# lane, which runs REACH along the aim; it cuts a machine in the lane, one just inside its edge, and
# never one behind, beside or just past the edge; a plated machine takes every cut in full (no
# deflection) and about the damage an unplated one takes; a plate heavier than one burn delivers
# is cut by the next burn, still in full; a stage clear drops a live burn; the beam sweeps after the
# aim at its capped rate; the burn ends and the lane clears; Spiral Wave fans out more beams;
# weapon damage mods raise the burn; overflow burns longer; a Jam in the wind-up cancels and
# refunds; the sound has a recipe. Evidence limit: rules in a headless run, not the feel.

const ID := "cutting_torch"
const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const WIDTH_HALF := Torch.WIDTH * 0.5
const FORGIVENESS := preload("res://src/core/ability_state.gd").FORGIVENESS

var _t := T.new("active_torch_test")
var _game
var _player
var _combat
var _rack
var _torch
var _source := Intent.Scripted.new()
var _fired: Array = []
var _deflected: Array = []
var _heat: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _never() -> bool:
	return false


func _ground(dx: float, dz := 0.0) -> Vector3:
	return _game.ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z + dz, 1.0)


func _enemy(offset: Vector3, plating := 0.0) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy("chaser", _ground(offset.x, offset.z))
	if "live" in enemy:
		enemy.live = Callable(self, "_never")
	enemy.max_hp = 9999.0
	enemy.hp = 9999.0
	enemy.plating = plating
	return enemy


func _press() -> void:
	_source.press = {"active_pressed": true}
	await physics_frame
	await physics_frame


func _layer(i := 0) -> Dictionary:
	return _player.indicator.shapes.get(Torch.LAYER % i, {})


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_game.tuning.set_option("actives", "on")
	await _sim(0.4)
	_rack = _combat.get("actives")
	var ev = _game.events
	ev.active_fired.connect(func(id: String, _at: Vector3, count: int): _fired.append([id, count]))
	ev.active_heat.connect(func(id: String, _at: Vector3, fraction: float):
		if id == ID:
			_heat.append(fraction))
	ev.strike_deflected.connect(func(_e: Node3D, kind: String, _punch: float, _plating: float):
		if kind == Torch.KIND:
			_deflected.append(kind))

	# --- The row ---------------------------------------------------------------------------
	var row := ActiveDefs.row(ID)
	_t.check("01 the torch is a rare Redjaw Workshops active with a 0.3 s wind-up",
		row.get("maker") == "redjaw" and row.get("rarity") == "rare" and is_equal_approx(float(row.get("windup", 0.0)), 0.3), str(row))
	_t.check("02 its launch sound has a recipe", SfxBank.has_recipe("active_" + ID) and SfxBank.samples("active_" + ID).size() > 0)
	_t.check("03 the rack takes it", _rack.rack(ID) and _rack.active_id == ID)
	_torch = _rack._kinds[ID]

	# --- Guide line, then the beam on the same lane -----------------------------------------
	_player.reset_to(_ground(0.0) + Vector3.UP)
	await _sim(0.2)
	var aim: Vector3 = _torch.flat_aim()
	var side := aim.cross(Vector3.UP).normalized()
	var front := _enemy(aim * 6.0)
	var behind := _enemy(-aim * 6.0)
	var off_side := _enemy(side * 5.0)
	var plated := _enemy(aim * 9.0 + side * 0.3, 40.0)
	var heavy := _enemy(aim * 11.0, 119.0)
	var hull: float = _combat.hull_radius(front)
	var edge := WIDTH_HALF * (1.0 + FORGIVENESS) + hull
	var edge_in := _enemy(aim * 3.5 + side * (edge - 0.1))
	var edge_out := _enemy(aim * 3.5 - side * (edge + 0.4))
	for probe in [edge_in, edge_out]:
		var at: Vector3 = probe.global_position
		var want: Vector3 = _ground(at.x - FLAT_SHELF.x, at.z - FLAT_SHELF.z)
		probe.global_position = Vector3(want.x, at.y, want.z)
	await _sim(0.05)
	var cap := int(row["max_charges"])
	await _press()
	var guide := _layer()
	_t.check("04 the press fires nothing yet and draws the guide as an outline",
		_fired.is_empty() and _torch.guiding and guide.get("kind") == "line" and float(guide.get("fill", -1.0)) == 0.0, str(guide))
	_t.eq("05 the charge is spent on the press", _rack.charges, cap - 1)
	var guide_dir: Vector3 = guide["to"] - guide["from"]
	_t.check("06 the guide runs the torch's full reach along the aim",
		absf(guide_dir.length() - Torch.REACH) < 0.05 and guide_dir.normalized().angle_to(aim) < 0.01, "length %.2f" % guide_dir.length())
	_t.eq("07 nothing is cut during the wind-up", [front.hp, _torch.cuts], [9999.0, 0])
	await _sim(0.35)
	_t.eq("08 the wind-up ends in one fire with one beam", _fired, [[ID, 1]])
	var beam := _layer()
	var beam_dir: Vector3 = beam["to"] - beam["from"]
	_t.check("09 the beam is drawn filled on the guide's lane",
		float(beam.get("fill", 0.0)) == 1.0 and absf(beam_dir.length() - guide_dir.length()) < 0.05 and beam_dir.angle_to(guide_dir) < 0.01 and _torch.beam_left > 0.0, str(beam))
	await _sim(Torch.BEAM_SECONDS + 0.2)
	_t.check("10 a machine in the lane is cut", front.hp < 9999.0, "hp %.1f" % front.hp)
	_t.check("11 machines outside the drawn lane are never cut", behind.hp == 9999.0 and off_side.hp == 9999.0 and edge_out.hp == 9999.0,
		"behind %.1f side %.1f past edge %.1f" % [behind.hp, off_side.hp, edge_out.hp])
	_t.check("11b a machine just inside the lane's edge is cut", edge_in.hp < 9999.0, "hp %.1f" % edge_in.hp)
	_t.check("12 it beats plating: every cut on a 40-plate machine lands in full", plated.hp < 9999.0 and _deflected.is_empty(),
		"hp %.1f deflections %d" % [plated.hp, _deflected.size()])
	var front_lost: float = 9999.0 - front.hp
	var plated_lost: float = 9999.0 - plated.hp
	_t.check("13 plating only delays the bite: the plated machine loses at least half what a bare one does",
		plated_lost >= front_lost * 0.5, "bare %.1f plated %.1f" % [front_lost, plated_lost])
	_t.check("14 the burn ends and the lane clears", _torch.beam_left <= 0.0 and _torch.lanes.is_empty() and _layer().is_empty())
	_t.eq("14b a 119 plate outlasts one burn's heat untouched", heavy.hp, 9999.0)
	var climbing := _heat.size() >= 3
	for i in range(1, _heat.size()):
		climbing = climbing and _heat[i] > 0.0 and _heat[i] <= 1.0
	_t.check("14b2 but its heat shows while it builds: glow-and-sizzle steps that climb", climbing and _heat.max() >= 0.75
		and SfxBank.has_recipe("active_cutting_torch_heat") and SfxBank.samples("active_cutting_torch_heat").size() > 0, str(_heat))
	_rack.charges = 1
	await _press()
	await _sim(0.35 + Torch.BEAM_SECONDS + 0.2)
	_t.check("14c the next burn cuts the 119 plate in full: heat carries between burns", 9999.0 - heavy.hp >= 119.0 and _deflected.is_empty(),
		"lost %.1f deflections %d" % [9999.0 - heavy.hp, _deflected.size()])
	_rack.charges = 1
	await _press()
	await _sim(0.5)
	_t.check("14c2 a burn is live before the clear", _torch.beam_left > 0.0 and not _layer().is_empty())
	_game.events.stage_content_cleared.emit("test")
	_t.check("14d a stage clear drops a live burn and its lane", _torch.beam_left <= 0.0 and _layer().is_empty() and _torch._heat.is_empty())

	# --- It sweeps after the aim at a capped rate ---------------------------------------------
	_torch.heading = side
	_torch._turn(1.0 / 60.0)
	var first: float = _torch.heading.angle_to(aim)
	_t.check("15 the beam turns toward the aim by at most its sweep rate a tick",
		first < PI * 0.5 and first >= PI * 0.5 - Torch.SWEEP / 60.0 - 0.001, "angle %.3f" % first)
	for i in 60:
		_torch._turn(1.0 / 60.0)
	_t.check("16 and settles on the aim", _torch.heading.angle_to(aim) < 0.01)

	# --- A strong build makes a bigger torch ----------------------------------------------------
	var patterns: Dictionary = _game.ctx.build.sheet.patterns
	patterns["spiral_wave"] = 2
	_rack.charges = 1
	_fired.clear()
	await _press()
	await _sim(0.35)
	var dirs: Array = _torch.lanes.map(func(l): return (l["to"] - l["from"]).normalized())
	_t.check("17 Spiral Wave 2 fans out three beams, each on its own drawn lane",
		_fired == [[ID, 3]] and dirs.size() == 3 and dirs[0].angle_to(dirs[2]) > deg_to_rad(Torch.FAN_DEG) and not _layer(2).is_empty(), "fired %s" % [_fired])
	await _sim(Torch.BEAM_SECONDS + 0.2)
	_t.check("18 every fanned lane clears at the end", _layer(0).is_empty() and _layer(2).is_empty())
	patterns.erase("spiral_wave")
	var base: float = _torch.burn()
	_game.tuning.set_mod("weapon_damage", 2.0)
	_t.near("19 weapon damage mods scale the burn", _torch.burn(), base * 2.0, 0.01)
	_game.tuning.clear_mods()
	_torch.fire(_rack, row, 2)
	_t.near("20 overflow pieces burn longer", _torch.beam_left, Torch.BEAM_SECONDS + 2.0 * Torch.BONUS_SECONDS, 0.001)
	_torch.clear()

	# --- A Jam during the wind-up cancels and refunds ---------------------------------------------
	_rack.charges = 1
	_fired.clear()
	await _press()
	_rack.lock(0.5)
	await _sim(0.5)
	_t.check("21 a Jam mid wind-up drops the guide, fires nothing and refunds the charge",
		_fired.is_empty() and _rack.charges == 1 and not _torch.guiding and _layer().is_empty(), "fired %s charges %d" % [_fired, _rack.charges])

	for enemy in [front, behind, off_side, plated, heavy, edge_in, edge_out]:
		if is_instance_valid(enemy):
			enemy.queue_free()
	quit(_t.verdict())
