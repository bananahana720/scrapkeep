extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const Rockets := preload("res://src/combat/actives/scrap_rockets.gd")
const MakerDefs := preload("res://src/build/maker_defs.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const MakerBonuses := preload("res://src/build/maker_bonuses.gd")
const T := preload("res://tests/support/t.gd")

# Maker set bonuses in a real Game with the first pilot (design page "Makers and Actives",
# 17 Oct 2026). Each set is completed by adding its pieces to the run, then its bonus is made to
# fire: Rounded Up rounds a strike to the next 5, Full Pressure vents on an active, the racked
# active counts as a piece, Open Frame fires an airborne active twice, Tremor ripples a landing,
# Noticed splinters a crit, Bench Teeth bite, and Packed a Spare copies the next item once a
# stage. Evidence limit: the rules in a headless run, not how a full set feels.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)

var _t := T.new("maker_bonuses_test")
var _game
var _player
var _combat
var _build
var _source := Intent.Scripted.new()
var _fired: Array = []


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


func _enemy(dx: float, dz: float) -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy("chaser", _ground(dx, dz))
	if "live" in enemy:
		enemy.live = Callable(self, "_never")
	enemy.max_hp = 9999.0
	enemy.hp = 9999.0
	return enemy


func _give(ids: Array) -> void:
	for id in ids:
		_game.ctx.run.add_part(id, "test")


func _home() -> void:
	_player.reset_to(_ground(0.0) + Vector3.UP * 0.6)
	for i in 120:
		await physics_frame
		if bool(_player.state.grounded):
			break


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	# Actives are on by default (24 Oct); this run racks its active itself, further down.
	_game.tuning.set_option("actives", "off")
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_build = _game.ctx.build
	await _sim(0.4)
	var ev = _game.events
	ev.active_fired.connect(func(id: String, _at: Vector3, count: int): _fired.append([id, count]))
	_t.eq("00 a fresh run holds no set", _build.maker_bonuses(), [])

	# --- Rounded Up (Fleet Surplus) --------------------------------------------------------
	await _home()
	_give(["tracer_round", "magnet_coil"])
	_t.eq("01 two Fleet pieces are not a set", _build.maker_bonuses(), [])
	_give(["rivet_seam"])
	_t.eq("02 the third Fleet piece completes Rounded Up", _build.maker_bonuses(), ["rounded_up"])
	var fleet := _enemy(4.0, 0.0)
	await _sim(0.05)
	_combat.strike(fleet, "synergy", 7.0)
	await _sim(0.05)
	var removed: float = 9999.0 - float(fleet.hp)
	_t.check("03 a 7-point strike lands as 10", is_equal_approx(removed, 10.0), "removed %.3f" % removed)
	fleet.hp = 9999.0
	_combat.strike(fleet, "synergy", 15.0)
	await _sim(0.05)
	_t.check("04 a strike already on a 5 is left alone", is_equal_approx(9999.0 - float(fleet.hp), 15.0), "removed %.3f" % (9999.0 - float(fleet.hp)))
	fleet.queue_free()

	# --- The racked active is a piece; Full Pressure (Spillway Works) ----------------------
	_give(["quick_spool", "cap_relay"])
	_t.eq("05 two Spillway parts alone are not a set", _build.maker_counts().get(MakerDefs.SPILLWAY, 0), 2)
	_game.tuning.set_option("actives", "on")
	await _sim(0.2)
	var rack = _combat.get("actives")
	_t.check("06 the racked Scrap Rocket Rack is the third Spillway piece",
		rack.active_id == ActiveDefs.SCRAP_ROCKET and _build.maker_counts().get(MakerDefs.SPILLWAY, 0) == 3 \
		and "full_pressure" in _build.maker_bonuses(), str(_build.maker_counts()))
	var near := _enemy(3.0, 0.0)
	var far := _enemy(20.0, 0.0)
	await _sim(0.05)
	var at_before: Vector3 = near.global_position
	ev.active_fired.emit(ActiveDefs.SCRAP_ROCKET, _player.ball_position(), 4)
	await _sim(0.2)
	_t.check("07 the steam ring hurts and shoves a machine in reach",
		float(near.hp) < 9999.0 and near.global_position.distance_to(_player.ball_position()) > at_before.distance_to(_player.ball_position()),
		"hp %.1f moved %s -> %s" % [near.hp, at_before, near.global_position])
	_t.check("08 and leaves one out of reach alone", is_equal_approx(float(far.hp), 9999.0), "far hp %.1f" % far.hp)
	_t.eq("09 Full Pressure fired once", int(_build.makers.fires.get("full_pressure", 0)), 1)
	near.queue_free()
	far.queue_free()

	# --- Open Frame (Highdraft Roosts) ------------------------------------------------------
	_give(["light_frame", "low_rider", "slipstream"])
	_t.check("10 Open Frame is live", "open_frame" in _build.maker_bonuses())
	await _home()
	_t.check("11 on the ground an active fires once", not _build.maker_fires_twice(), "grounded %s" % _player.state.grounded)
	_enemy(12.0, 4.0)
	_enemy(-10.0, 6.0)
	_player.reset_to(_ground(0.0) + Vector3.UP * 14.0)
	await _sim(0.1)
	_t.check("12 in the air an active fires twice", _build.maker_fires_twice(), "grounded %s" % _player.state.grounded)
	rack.charges = 1
	_fired.clear()
	rack.press()
	_t.eq("13 the airborne press fires both volleys", _fired, [[ActiveDefs.SCRAP_ROCKET, Rockets.ROCKETS * 2]])
	await _sim(3.0)

	# --- Tremor (Waking-made) ---------------------------------------------------------------
	await _home()
	_give(["re_rack", "brace_frame", "ring_wave"])
	_t.check("14 Tremor is live", "tremor" in _build.maker_bonuses())
	var quake := _enemy(4.0, 0.0)
	await _sim(0.05)
	# The ball's own settling may already have rippled; count from here, past the re-ripple gap.
	await _sim(MakerBonuses.TREMOR_GAP + 0.05)
	quake.hp = 9999.0
	var ripples := int(_build.makers.fires.get("tremor", 0))
	ev.landed.emit(2.0)
	_t.check("15 a soft landing sends no ripple", is_equal_approx(float(quake.hp), 9999.0) and int(_build.makers.fires.get("tremor", 0)) == ripples,
		"hp %.1f ripples %d -> %d" % [quake.hp, ripples, int(_build.makers.fires.get("tremor", 0))])
	# A ripple from the ball's own settling may have shoved it away: put it back in reach.
	quake.global_position = _player.ball_position() + Vector3(3.0, 0.0, 0.0)
	ev.landed.emit(10.0)
	await _sim(0.1)
	_t.check("16 a real landing ripples the ground", float(quake.hp) < 9999.0 and int(_build.makers.fires.get("tremor", 0)) == ripples + 1,
		"hp %.1f ripples %d -> %d" % [quake.hp, ripples, int(_build.makers.fires.get("tremor", 0))])
	quake.queue_free()

	# --- Noticed (Mind-glass) ---------------------------------------------------------------
	_give(["chain_arc", "static_burr", "synergy_lens"])
	_t.check("17 Noticed is live", "noticed" in _build.maker_bonuses())
	var glass := _enemy(5.0, 0.0)
	await _sim(0.05)
	_build.makers._on_door_hit({"enemy": glass, "kind": "ram", "killed": false,
		"result": {"dealt": 20.0, "punch": 10.0, "plating": 0.0, "part": "", "full": true}})
	_t.eq("18 the crit queues one splinter", _build.makers._splinters.size(), 1)
	await _sim(0.5)
	_t.check("19 a crit leaves a splinter that strikes a beat later",
		float(glass.hp) < 9999.0 and int(_build.makers.fires.get("noticed", 0)) == 1, "hp %.1f" % glass.hp)
	glass.hp = 9999.0
	_build.makers._on_door_hit({"enemy": glass, "kind": "ram", "killed": false,
		"result": {"dealt": 10.0, "punch": 10.0, "plating": 0.0, "part": "", "full": true}})
	await _sim(0.5)
	_t.eq("20 a plain hit leaves no splinter", int(_build.makers.fires.get("noticed", 0)), 1)
	# Rounded Up is live too (02). A crew fitter, which no player hit hurts, wakes neither bonus.
	var rounds := int(_build.makers.fires.get("rounded_up", 0))
	var fitter: Node3D = _combat.spawn_enemy("crew_fitter", _ground(-5.0, 0.0))
	await _sim(0.05)
	_build.makers._on_door_hit({"enemy": fitter, "kind": "ram", "killed": false,
		"result": {"dealt": 23.0, "punch": 10.0, "plating": 0.0, "part": "", "full": true, "absorbed": true}})
	_t.check("20b a crew fitter wakes neither Noticed nor Rounded Up",
		_build.makers._splinters.is_empty() and int(_build.makers.fires.get("rounded_up", 0)) == rounds,
		"splinters %d, rounded_up %d -> %d" % [_build.makers._splinters.size(), rounds, int(_build.makers.fires.get("rounded_up", 0))])
	fitter.queue_free()
	# A drill crew's plate takes a breaking hit whole, but Rounded Up's top-up still lands through it.
	var crew: Node3D = _combat.spawn_enemy("drill_crew", _ground(0.0, 6.0))
	if "live" in crew:
		crew.live = Callable(self, "_never")
	await _sim(0.05)
	var crew_hp: float = crew.hp
	_combat.strike(crew, "arc", 203.0)
	var topped: float = crew_hp - float(crew.hp)
	_t.check("20c a plate pop keeps Rounded Up's top-up",
		int(_build.makers.fires.get("rounded_up", 0)) == rounds + 1 and topped > 0.0 and topped < 5.0,
		"rounded_up %d -> %d, hp %.2f -> %.2f" % [rounds, int(_build.makers.fires.get("rounded_up", 0)), crew_hp, crew.hp])
	_build.makers._splinters.clear()
	crew.queue_free()
	glass.queue_free()

	# --- Bench Teeth (Redjaw Workshops) -----------------------------------------------------
	_give(["pin_setter", "ten_pin", "clean_break"])
	_t.check("21 Bench Teeth is live", "bench_teeth" in _build.maker_bonuses())
	var bite := _enemy(6.0, 0.0)
	await _sim(0.05)
	_build.makers.lay_tooth(bite.global_position)
	await _sim(0.2)
	_t.check("22 a tooth bites a machine on it", float(bite.hp) < 9999.0 and int(_build.makers.fires.get("bench_teeth", 0)) >= 1,
		"hp %.1f" % bite.hp)
	await _sim(MakerBonuses.TOOTH_LIFE + 0.2)
	_t.eq("23 teeth wear out", _build.makers.teeth().size(), 0)
	bite.queue_free()

	# --- Packed a Spare (Moss's Spares, two pieces) -----------------------------------------
	var before: int = _game.ctx.run.part_count("momentum_thief")
	_give(["fast_hands", "momentum_thief"])
	_t.check("24 two Moss pieces complete Packed a Spare", "packed_a_spare" in _build.maker_bonuses())
	_t.eq("25 the completing piece is not its own spare", _game.ctx.run.part_count("momentum_thief"), before + 1)
	var held: int = _game.ctx.run.part_count("tracer_round")
	_give(["tracer_round"])
	_t.eq("26 the next item comes with a second copy", _game.ctx.run.part_count("tracer_round"), held + 2)
	_give(["tracer_round"])
	_t.eq("27 only one spare a stage", _game.ctx.run.part_count("tracer_round"), held + 3)

	# --- Every set at once ------------------------------------------------------------------
	_t.eq("28 all seven bonuses live together", _build.maker_bonuses(),
		["full_pressure", "rounded_up", "bench_teeth", "open_frame", "tremor", "noticed", "packed_a_spare"])
	var swapped: Array = _game.ctx.run.parts.duplicate()
	swapped[swapped.find("rivet_seam")] = "gen:weapon:rare:arc:on_hit"
	_game.ctx.run.parts.assign(swapped)
	_t.check("29 swapping a piece out at the same part count (a retry, a sale) is recounted",
		not "rounded_up" in _build.maker_bonuses() and _build.maker_counts().get(MakerDefs.FLEET, 0) == 2, str(_build.maker_counts()))
	ev.run_started.emit("pylon_engineer")
	_t.eq("30 a new run clears the sets' firings", _build.makers.fires, {})
	quit(_t.verdict())
