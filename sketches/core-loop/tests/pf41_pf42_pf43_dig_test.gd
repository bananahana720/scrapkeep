extends SceneTree

# Regression checks for World 2 blockers PF-41, PF-42, and PF-43:
# - PF-41: Stage 4 park_sinkhole clears the overlapping sheer plateau pocket at (-78.9, -90.7, -2.9)
#   with beveled anchor rows and open floor clearance.
# - PF-42: Stage 3 park_pit headframe Warden sits in floor ram reach at low dwell, keeps all three
#   hardpoints within 45 m rope reach at high dwell from collar floor/rim and tipple_deck, and pauses
#   posture drain while lifted out of floor reach with no attached line (while draining normally at
#   low dwell or outside engage reach).
# - PF-43: Stage 4 park_sinkhole SwarmPoolFloor survives Warden break, floods smoothly flush to
#   gallery_ring (y -100), frees cleanly on stage unload (zero leak), keeps permanent wall-side
#   exit ramps flush <= -100, and seats reward gates at [0, 305] within CLIMB_TOLERANCE.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const WardenSwarm := preload("res://src/combat/warden_swarm.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")

const ROPE_RANGE := 45.0

var t := T.new("pf41_pf42_pf43_dig_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _run() -> void:
	_check_pf41_geometry()
	await _check_pf42_and_pf43_runtime()
	quit(t.verdict())


func _check_pf41_geometry() -> void:
	var read := ParkSchema.load_park("res://src/world/park/park_sinkhole.json")
	if not t.check("PF-41: park_sinkhole.json loads", read["errors"].is_empty(), str(read["errors"])):
		return
	var park: Dictionary = read["data"]
	var by_id := {}
	for row in park["park_rows"]:
		by_id[String(row["id"])] = row
	var beveled_ids := ["west_breakthrough_post_2o", "west_breakthrough_fill_45", "west_breakthrough_fill_55",
		"west_gallery_post_14i", "west_gallery_fill_485", "west_breakthrough_lip_25", "great_room_pillar_62_280"]
	var bad_stamps := []
	for id in beveled_ids:
		if not by_id.has(id) or String(by_id[id].get("stamp", "")) == "plateau":
			bad_stamps.append("%s=%s" % [id, by_id.get(id, {}).get("stamp", "missing")])
	t.check("PF-41: junction anchor rows around (-78.9, -2.9) use beveled stamps, not sheer plateau",
		bad_stamps.is_empty(), str(bad_stamps))
	var f45: Array = by_id["west_breakthrough_fill_45"]["at"]
	var f55: Array = by_id["west_breakthrough_fill_55"]["at"]
	var p2o: Array = by_id["west_breakthrough_post_2o"]["at"]
	var gap_fills := Vector2(float(f45[0]), float(f45[1])).distance_to(Vector2(float(f55[0]), float(f55[1])))
	var gap_post := Vector2(float(p2o[0]), float(p2o[1])).distance_to(Vector2(float(f45[0]), float(f45[1])))
	t.check("PF-41: fill_45, fill_55 and post_2o no longer overlap at the wedge junction",
		gap_fills >= 16.0 and gap_post >= 16.0, "fill_45..55=%.1f m, post_2o..fill_45=%.1f m" % [gap_fills, gap_post])
	t.check("PF-43: permanent caisson wall-side exit ramps authored",
		by_id.has("caisson_exit_ramp_w") and by_id.has("caisson_exit_ramp_e"))


func _check_pf42_and_pf43_runtime() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.force_warden = true
	var source := Intent.Scripted.new()
	game.player.source = source
	game.flow.press_start()
	game.flow.choose_class(1)

	# --- PF-42: Stage 3 park_pit headframe ---
	game.flow.enter_stage(3, Vector3.ZERO, false)
	await _frames(30)
	game.run.set_max_hp(99999.0)
	var terrain = game.ctx.terrain
	var warden = game.flow.warden
	if t.check("PF-42: stage 3 park_pit fields headframe Warden", is_instance_valid(warden) and warden.mounting == WardenSwarm.HEADFRAME):
		var floor_y: float = terrain.height(warden.home.x, warden.home.z)
		var low_above: float = warden.home.y - floor_y
		t.check("PF-42: low-dwell hive sits in floor ram reach over collar_dish",
			low_above <= WardenSwarm.HEADFRAME_FLOOR_REACH, "home.y=%.2f floor=%.2f above=%.2f m" % [warden.home.y, floor_y, low_above])
		var worst_dist := 0.0
		var vantage_points := [
			Vector3(0.0, terrain.height(0.0, 255.0) + 1.0, 255.0),
			Vector3(0.0, terrain.height(0.0, 233.0) + 1.0, 233.0),
			Vector3(0.0, terrain.height(0.0, 225.0) + 1.0, 225.0),
			Vector3(0.0, -59.0, 240.0),
		]
		for hp_offset in warden.hardpoints:
			var high_hp: Vector3 = warden.home + Vector3.UP * WardenSwarm.RISE + (hp_offset as Vector3)
			for vp in vantage_points:
				worst_dist = maxf(worst_dist, vp.distance_to(high_hp))
		t.check("PF-42: all headframe hardpoints at high dwell stay within 45 m rope range",
			worst_dist <= ROPE_RANGE, "worst=%.2f m (limit %.1f m)" % [worst_dist, ROPE_RANGE])
		# Posture drain pauses while hive is out of floor reach without an attached line (engaged inside reach),
		# and resumes outside reach or at low dwell.
		var driver = warden.mount_driver
		warden._posture.posture = 50.0
		warden._posture.idle = BossPosture.DRAIN_DELAY + 1.0
		driver.clock = WardenSwarm.DWELL + WardenSwarm.MOVE + 1.0
		driver.height = WardenSwarm.RISE
		warden.global_position = warden.home + Vector3.UP * WardenSwarm.RISE
		game.player.reset_to(Vector3(0.0, terrain.height(0.0, 240.0) + 1.0, 240.0))
		driver.step(warden, 0.05)
		var scale_in := float(warden._posture.drain_rate_scale)
		warden._posture.step(0.5)
		var held_posture := float(warden.posture())
		# Move ball far outside reach: drain must run normally so a remote camper cannot stall-abuse.
		game.player.reset_to(Vector3(0.0, terrain.height(0.0, 150.0) + 1.0, 150.0))
		driver.step(warden, 0.05)
		var scale_far := float(warden._posture.drain_rate_scale)
		warden._posture.step(0.5)
		var drained_posture := float(warden.posture())
		t.check("PF-42: posture drain pauses while high-dwell hive is out of floor reach without a line (engaged)",
			scale_in == 0.0 and absf(held_posture - 50.0) < 0.01, "scale_in=%.2f held=%.2f" % [scale_in, held_posture])
		t.check("PF-42: posture drains normally outside engage reach",
			scale_far == 1.0 and drained_posture < 49.0, "scale_far=%.2f drained=%.2f" % [scale_far, drained_posture])

	# --- PF-41 terrain check + PF-43: Stage 4 park_sinkhole ---
	game.flow.enter_stage(4, Vector3.ZERO, false)
	await _frames(30)
	game.run.set_max_hp(99999.0)
	# Verify no +20 m sheer pocket exists within 5 m of (-78.9, -2.9).
	var max_wedge_h := -INF
	for dx in [-4.0, 0.0, 4.0]:
		for dz in [-4.0, 0.0, 4.0]:
			max_wedge_h = maxf(max_wedge_h, terrain.height(-78.9 + dx, -2.9 + dz))
	t.check("PF-41: terrain around (-78.9, -2.9) is clear of sheer +20 m pocket walls",
		max_wedge_h < -85.0, "max_h=%.2f m (want < -85.0)" % max_wedge_h)

	# Verify caisson_bowl center & permanent exit ramps stay <= -100.0.
	var center_h: float = terrain.height(0.0, 350.0)
	var ramp_max_h := maxf(terrain.height(-9.9, 331.5), terrain.height(9.9, 331.5))
	var rim_max_h := maxf(terrain.height(-16.0, 319.0), terrain.height(16.0, 319.0))
	t.check("PF-43: caisson center stays -120 and exit ramps stay flush <= -100",
		absf(center_h - (-120.0)) < 0.5 and ramp_max_h < -100.0 and rim_max_h <= -99.8,
		"center=%.2f ramp=%.2f rim=%.2f" % [center_h, ramp_max_h, rim_max_h])

	# Verify reward gates at [0, 305] seat flush at y -100 with climb <= CLIMB_TOLERANCE.
	var gates := RewardGates.new()
	game.ctx.root.add_child(gates)
	gates.setup(terrain)
	for count in [1, 2, 3]:
		gates._ids = []
		for k in count:
			gates._ids.append("part_%d" % k)
		var plan := gates.choose_placement(Vector3(0.0, -99.0, 340.0), Vector3.FORWARD)
		var max_climb := -INF
		var min_y := INF
		for spot: Vector3 in plan.get("spots", []):
			max_climb = maxf(max_climb, spot.y - (-100.0))
			min_y = minf(min_y, spot.y)
		t.check("PF-43: %d reward gate(s) seat on [0, 305] at/below y -100 within CLIMB_TOLERANCE" % count,
			plan.get("fixed", false) and float(plan.get("climb", 99.0)) <= RewardGates.CLIMB_TOLERANCE
			and max_climb <= RewardGates.CLIMB_TOLERANCE and min_y >= -102.0,
			"fixed=%s climb=%.2f max_climb=%.2f min_y=%.2f spots=%s" % [plan.get("fixed", false), float(plan.get("climb", 99.0)), max_climb, min_y, plan.get("spots", [])])
	gates.queue_free()

	# Verify SwarmPoolFloor survives Warden break, floods to y -100, and frees cleanly on stage unload.
	var s4_warden = game.flow.warden
	if t.check("PF-43: stage 4 park_sinkhole fields sinkhole Warden", is_instance_valid(s4_warden) and s4_warden.mounting == WardenSwarm.SINKHOLE):
		var s4_driver = s4_warden.mount_driver
		# Place ball safely on gallery_ring so pool rise is not held.
		game.player.reset_to(Vector3(0.0, -99.0, 305.0))
		await _frames(3)
		var slab: Node3D = s4_driver._slab
		t.check("PF-43: SwarmPoolFloor exists before break", is_instance_valid(slab))
		# Simulate final chunk break and Warden death/free.
		s4_warden._posture.chunks = 0
		s4_driver.on_chunk_lost(s4_warden, 0)
		s4_warden.queue_free()
		await _frames(5)
		t.check("PF-43: SwarmPoolFloor stays alive after Warden break", is_instance_valid(slab))
		# Step until swell (2 s) + rise (4*5 m at 5/3 m/s = 12 s) completes -> 15 s max.
		var tick := 1.0 / Engine.physics_ticks_per_second
		var flood_node := slab.get_node_or_null("PostBreakPoolFlood") if is_instance_valid(slab) else null
		t.check("PF-43: PostBreakPoolFlood stepper attached on break", is_instance_valid(flood_node))
		if is_instance_valid(flood_node):
			for _step in 1500:
				if not is_instance_valid(flood_node):
					break
				flood_node._physics_process(tick)
		var final_top: float = slab.global_position.y + WardenSwarm.POOL_THICKNESS * 0.5 if is_instance_valid(slab) else -999.0
		t.check("PF-43: SwarmPoolFloor floods flush to gallery_ring (y -100) after break",
			is_instance_valid(slab) and absf(final_top - (-100.0)) < 0.05 and absf(float(s4_driver.pool_floor) - (-100.0)) < 0.05,
			"top=%.2f pool_floor=%.2f target=%.2f" % [final_top, float(s4_driver.pool_floor), float(s4_driver.pool_target)])
		# Verify clean free on stage unload (zero leak).
		game.events.stage_content_cleared.emit("test_unload")
		await _frames(3)
		t.check("PF-43: SwarmPoolFloor frees cleanly on stage unload", not is_instance_valid(slab))

	source.hold = {}
	game.queue_free()
	await _frames(3)
