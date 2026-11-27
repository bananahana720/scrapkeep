extends SceneTree

const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")
const LiveRunBridge := preload("res://src/experimental/live_run_bridge.gd")
const DynamicSetpieces := preload("res://src/experimental/dynamic_setpieces.gd")

const BALL_RADIUS_M := 1.0
const BALL_GRAVITY_SCALE := 26.0 / 9.8
const PIER_CHUNKS: Array[Dictionary] = [
	{
		"path": "res://src/experimental/compactor_canyon_chunk.tscn",
		"piers": [
			"Tier1_QuarryCatwalks/CatwalkPierNW", "Tier1_QuarryCatwalks/CatwalkPierNE",
			"Tier1_QuarryCatwalks/CatwalkPierSW", "Tier1_QuarryCatwalks/CatwalkPierSE",
			"Tier2_HydraulicGantry/BridgeStanchionWest", "Tier2_HydraulicGantry/BridgeStanchionEast",
			"Tier2_HydraulicGantry/CranePortalWest", "Tier2_HydraulicGantry/CranePortalEast",
		],
	},
	{
		"path": "res://src/experimental/orbital_graveyard_chunk.tscn",
		"piers": [
			"Tier1_SalvageDecks/DeckPierNW", "Tier1_SalvageDecks/DeckPierNE",
			"Tier1_SalvageDecks/DeckPierSW", "Tier1_SalvageDecks/DeckPierSE",
			"Tier2_ChoirCrane/BridgeStanchionWest", "Tier2_ChoirCrane/BridgeStanchionEast",
			"Tier2_ChoirCrane/CranePortalWest", "Tier2_ChoirCrane/CranePortalEast",
		],
	},
]
const PAD_CHUNKS: Array[Dictionary] = [
	{"path": "res://src/experimental/smelter_crane_chunk.tscn", "pads": ["jump_pad_sw", "jump_pad_ne"], "deck_top": 7.5},
	{"path": "res://src/experimental/compactor_canyon_chunk.tscn", "pads": ["vent_pad_sw", "vent_pad_ne"], "deck_top": 7.5},
	{"path": "res://src/experimental/orbital_graveyard_chunk.tscn", "pads": ["updraft_pad_sw", "updraft_pad_ne"], "deck_top": 8.0},
]
const STAGE_CHUNKS := {1: "SmelterCraneChunk", 3: "CompactorCanyonChunk", 5: "OrbitalGraveyardChunk"}
const STAGE_BIOMES := {1: &"spillway", 3: &"dig", 5: &"highdraft"}

var _t := T.new("experimental_live_game_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	LiveRunBridge._reset()
	await _test_piers_are_solid()
	await _test_pads_launch_onto_decks()
	await _test_default_game_stays_clean()
	await _test_opt_in_game()
	LiveRunBridge._reset()
	quit(_t.verdict())


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> int:
	return int(ceil(s * Engine.physics_ticks_per_second))


func _ball(at: Vector3, velocity: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	body.gravity_scale = BALL_GRAVITY_SCALE
	body.continuous_cd = true
	body.can_sleep = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BALL_RADIUS_M
	shape.shape = sphere
	body.add_child(shape)
	root.add_child(body)
	body.global_position = at
	body.linear_velocity = velocity
	return body


func _count_named(node: Node, prefix: String) -> int:
	var count := 1 if String(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_named(child, prefix)
	return count


func _count_experimental_scripts(node: Node) -> int:
	var script: Script = node.get_script()
	var count := 1 if script != null and script.resource_path.begins_with("res://src/experimental/") else 0
	for child in node.get_children():
		count += _count_experimental_scripts(child)
	return count


func _test_piers_are_solid() -> void:
	for spec in PIER_CHUNKS:
		var chunk := (load(String(spec["path"])) as PackedScene).instantiate() as Node3D
		root.add_child(chunk)
		await _physics(2)
		var rolls: Array[Dictionary] = []
		for rel in spec["piers"]:
			var pier := chunk.get_node_or_null(String(rel)) as Node3D
			var body: StaticBody3D = null
			if pier != null:
				for child in pier.get_children():
					if child is StaticBody3D:
						body = child as StaticBody3D
			var solid := body != null and body.collision_layer == 1 and body.collision_mask == 0
			_t.check("%s has a StaticBody3D on layer 1, mask 0" % rel, solid)
			if not solid:
				continue
			var box := (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
			var at := pier.global_position
			var side := 1.0 if at.x < 0.0 else -1.0
			var ball := _ball(Vector3(at.x + side * 6.0, BALL_RADIUS_M + 0.05, at.z), Vector3(-side * 12.0, 0.0, 0.0))
			rolls.append({"rel": rel, "ball": ball, "x": at.x, "side": side, "reach": box.size.x * 0.5 + BALL_RADIUS_M, "closest": INF, "passed": false, "ground": box.size.y * 0.5 - absf(pier.position.y) })
		for _i in _seconds(1.2):
			await physics_frame
			for roll in rolls:
				var gap: float = ((roll["ball"] as RigidBody3D).global_position.x - float(roll["x"])) * float(roll["side"])
				roll["closest"] = minf(float(roll["closest"]), gap)
				if gap < 0.0:
					roll["passed"] = true
		for roll in rolls:
			_t.check("%s stops a rolling ball (does not pass through)" % roll["rel"],
				not bool(roll["passed"]) and float(roll["closest"]) >= float(roll["reach"]) - 0.2,
				"closest %.2f m, contact at %.2f m" % [float(roll["closest"]), float(roll["reach"])])
			_t.check("%s was reached by the ball" % roll["rel"], float(roll["closest"]) <= float(roll["reach"]) + 0.3,
				"closest %.2f m" % float(roll["closest"]))
			_t.check("%s collider reaches the ground" % roll["rel"], absf(float(roll["ground"])) <= 0.05, "gap %.2f m" % float(roll["ground"]))
			(roll["ball"] as RigidBody3D).free()
		root.remove_child(chunk)
		chunk.free()
		await _physics(1)


func _test_pads_launch_onto_decks() -> void:
	for spec in PAD_CHUNKS:
		var chunk := (load(String(spec["path"])) as PackedScene).instantiate() as Node3D
		root.add_child(chunk)
		var setpieces := DynamicSetpieces.new()
		root.add_child(setpieces)
		var info := setpieces.setup_from_chunk(chunk)
		_t.eq("%s wires 2 jump pad triggers" % chunk.name, int(info.get("jump_pad_count", 0)), 2)
		await _physics(2)
		var pads := {}
		for pad in setpieces.snapshot()["jump_pads"]:
			pads[String(pad["id"])] = pad["origin"]
		var flights: Array[Dictionary] = []
		for index in (spec["pads"] as Array).size():
			var pad_id := String(spec["pads"][index])
			_t.check("%s exposes pad %s" % [chunk.name, pad_id], pads.has(pad_id))
			if not pads.has(pad_id):
				continue
			var origin: Vector3 = pads[pad_id]
			var inward := 1.0 if origin.x < 0.0 else -1.0
			var parked := index == 1
			var start := Vector3(origin.x, BALL_RADIUS_M + 0.05, origin.z) if parked \
				else Vector3(origin.x + inward * 5.0, BALL_RADIUS_M + 0.05, origin.z)
			var ball := _ball(start, Vector3.ZERO if parked else Vector3(-inward * 6.0, 0.0, 0.0))
			flights.append({"id": pad_id, "ball": ball, "peak": -INF, "parked": parked})
		for _i in _seconds(2.6):
			await physics_frame
			for flight in flights:
				flight["peak"] = maxf(float(flight["peak"]), (flight["ball"] as RigidBody3D).global_position.y)
		var deck_rest := float(spec["deck_top"]) + BALL_RADIUS_M
		for flight in flights:
			var ball := flight["ball"] as RigidBody3D
			var how := "parked on" if bool(flight["parked"]) else "rolling onto"
			_t.check("%s: a ball %s %s launches upward (peak > 4.0 m)" % [chunk.name, how, flight["id"]],
				float(flight["peak"]) > 4.0, "peak %.2f m" % float(flight["peak"]))
			_t.check("%s: %s lifts the ball clear of the deck" % [chunk.name, flight["id"]],
				float(flight["peak"]) >= deck_rest + 0.5, "peak %.2f m, deck rest %.2f m" % [float(flight["peak"]), deck_rest])
			_t.check("%s: %s lands the ball on the deck" % [chunk.name, flight["id"]],
				absf(ball.global_position.y - deck_rest) <= 0.35,
				"resting y %.2f m, deck rest %.2f m" % [ball.global_position.y, deck_rest])
			_t.eq("%s: %s leaves no deck pass-through behind" % [chunk.name, flight["id"]], ball.get_collision_exceptions().size(), 0)
			ball.free()
		var launches := 0
		for pad in setpieces.snapshot()["jump_pads"]:
			launches += int(pad["launches"])
		_t.check("%s: both pads fired" % chunk.name, launches >= 2, "launches %d" % launches)
		root.remove_child(setpieces)
		setpieces.free()
		root.remove_child(chunk)
		chunk.free()
		await _physics(1)


func _test_default_game_stays_clean() -> void:
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	await _physics(2)
	_t.eq("default Game starts with experimental_override off", game.experimental_override, false)
	_t.check("default Game has no experimental bridge", game.experimental_bridge == null)
	await _check_pad_interact_in_camp(game)
	game.flow.launch_from_title(game.flow.classes[0])
	await _physics(10)
	_t.check("default Game is in a stage", game.flow.in_stage(), game.flow.state_name())
	_t.check("default Game still has no experimental bridge in a stage", game.experimental_bridge == null)
	_t.eq("default Game holds 0 experimental nodes", _count_experimental_scripts(game), 0)
	_t.eq("default Game has no ExperimentalLiveRunBridge", _count_named(game, "ExperimentalLiveRunBridge"), 0)
	_t.eq("default Game has no ExperimentalArenaChunk", _count_named(game, LiveRunBridge.CHUNK_HOLDER_NAME), 0)
	_t.eq("default Game has no ExpAudio players", _count_named(game, "ExpAudio_"), 0)
	_t.eq("game.gd names the same flag as the bridge", Game.EXPERIMENTAL_FLAG, LiveRunBridge.FLAG_ARG_BARE)
	_t.eq("game.gd names the same environment variable as the bridge", Game.EXPERIMENTAL_ENV, LiveRunBridge.ENV_VAR)
	root.remove_child(game)
	game.free()
	await _physics(2)


func _check_pad_interact_in_camp(game) -> void:
	var pad_interact: InputEventJoypadButton = null
	for event in InputMap.action_get_events("cl_interact"):
		if event is InputEventJoypadButton:
			pad_interact = (event as InputEventJoypadButton).duplicate()
	_t.check("cl_interact has a pad button", pad_interact != null)
	if pad_interact == null:
		return
	pad_interact.pressed = true
	_t.eq("pad interact on the plain title presses nothing", game.pad_screen_key(pad_interact), KEY_NONE)
	game._screen_key(KEY_K)
	await _physics(2)
	_t.check("K starts the camp walk", game.screens.walk_live())
	_t.eq("pad interact outside a station presses nothing", game.pad_screen_key(pad_interact), KEY_NONE)
	var hub = game.camp_hub
	var centre: Vector3 = hub.zone_position("settings")
	var toward: Vector3 = hub.root.global_position - centre
	toward.y = 0.0
	var at: Vector3 = centre + toward.normalized() * 1.5
	at.y = 1.3
	game.player.reset_to(at)
	game.player.body().global_position = at
	await _physics(4)
	_t.eq("pad interact at a station presses that station", game.pad_screen_key(pad_interact), hub.confirm_key())
	_t.eq("the settings station's key is S", hub.confirm_key(), KEY_S)
	game._screen_key(KEY_K)
	await _physics(2)
	_t.check("K ends the camp walk on the title", not game.screens.walk_live() and game.flow.state_name() == "title")


func _check_stage(game, stage: int) -> void:
	var bridge = game.experimental_bridge
	var chunk: Node3D = bridge.live_chunk()
	_t.check("stage %d configures the bridge" % stage, bridge.configured and bridge.stage_index == stage,
		"configured=%s stage_index=%d" % [bridge.configured, bridge.stage_index])
	_t.eq("stage %d biome" % stage, bridge.biome_id, STAGE_BIOMES[stage])
	_t.eq("stage %d spawns the world's chunk" % stage, String(chunk.name) if chunk != null else "", STAGE_CHUNKS[stage])
	if chunk == null:
		return
	var holder := chunk.get_parent()
	_t.check("stage %d chunk sits in an ExperimentalArenaChunk holder under the stage's geometry root" % stage,
		holder.name == LiveRunBridge.CHUNK_HOLDER_NAME and holder.get_parent() == game.ctx.terrain.geometry_root(stage))
	_t.eq("stage %d keeps exactly one arena chunk" % stage, _count_named(game, LiveRunBridge.CHUNK_HOLDER_NAME), 1)
	var spawn: Vector3 = game.ctx.terrain.spawn_point(stage)
	var away := Vector2(chunk.global_position.x - spawn.x, chunk.global_position.z - spawn.z).length()
	_t.check("stage %d chunk stands clear of the spawn" % stage, away >= 40.0, "%.1f m" % away)
	_t.check("stage %d starts the ambience loop on an ExpAudio player" % stage,
		bridge.get_node_or_null("ExpAudio_smelter_ambience") != null and bridge.active_audio_loops().has("smelter_ambience"))
	_t.eq("stage %d equips three parts from the world's pool" % stage, bridge.synergies.equipped_parts().size(), 3)
	_t.check("stage %d wires setpieces with two jump pads" % stage,
		bridge.setpieces != null and (bridge.setpieces.snapshot()["jump_pads"] as Array).size() == 2)
	var before: float = bridge.sim_time_s
	await _physics(20)
	_t.check("stage %d steps the bridge each physics tick" % stage, bridge.sim_time_s > before + 0.1,
		"sim_time %.3f -> %.3f" % [before, bridge.sim_time_s])


func _cue_names(bridge) -> Array[String]:
	var out: Array[String] = []
	for cue in bridge.audio_cue_log():
		out.append(String(cue["event_id"]))
	return out


func _test_opt_in_game() -> void:
	_t.eq("the opt-in flag enables the bridge", LiveRunBridge.is_enabled([LiveRunBridge.FLAG_ARG_ON], {}), true)
	for text in LiveRunBridge.FACT_CALLOUTS.values() + LiveRunBridge.ENCOUNTER_CALLOUTS.values():
		_t.check("callout '%s' is five words or fewer" % text, String(text).split(" ", false).size() <= 5)

	var game = Game.new()
	game.test_mode = true
	game.experimental_override = true
	root.add_child(game)
	await _physics(2)
	var bridge = game.experimental_bridge
	_t.check("opt-in Game adds ExperimentalLiveRunBridge under Game",
		bridge != null and bridge.name == "ExperimentalLiveRunBridge" and bridge.get_parent() == game)
	if bridge == null:
		root.remove_child(game)
		game.free()
		return
	_t.check("the bridge stays idle on the title", not bridge.configured and bridge.live_chunk() == null)

	game.flow.launch_from_title(game.flow.classes[0])
	await _physics(4)
	await _check_stage(game, 1)

	bridge.bridge_fact_emitted.emit({"kind": "hazard_announced"})
	_t.check("a hazard announcement toasts 'Squall incoming'", game.hud.toast_texts().has("Squall incoming"), str(game.hud.toast_texts()))
	_t.eq("an airdrop announcement maps to 'Salvage pod inbound'",
		LiveRunBridge.callout_for({"kind": "random_encounter_announced", "encounter_kind": &"airdrop_salvage_pod"}), "Salvage pod inbound")
	_t.eq("a lockdown maps to 'Press lockdown'", LiveRunBridge.callout_for({"kind": "encounter_lockdown_started"}), "Press lockdown")
	_t.eq("a minor fact maps to no callout", LiveRunBridge.callout_for({"kind": "hazard_tier_rose"}), "")

	var first_chunk: Node3D = bridge.live_chunk()
	bridge.director.start_hazard(&"corrosive_steam_squall", Vector3.ZERO, 0.0)
	var first_cues := _cue_names(bridge)
	_t.check("attempt 1 fires pa_hazard_squall_incoming", first_cues.has("pa_hazard_squall_incoming"), str(first_cues))
	_t.eq("the PA cue is on cooldown within the attempt", String(bridge.trigger_audio_cue("pa_hazard_squall_incoming").get("reason", "")), "cooldown")
	game.flow.retry_stage()
	await _physics(2)
	_t.check("retry reconfigures the bridge from time zero", bridge.configured and bridge.sim_time_s < 0.2, "sim_time %.3f" % bridge.sim_time_s)
	_t.check("retry keeps the same chunk", bridge.live_chunk() == first_chunk and _count_named(game, LiveRunBridge.CHUNK_HOLDER_NAME) == 1)
	bridge.director.start_hazard(&"corrosive_steam_squall", Vector3.ZERO, 0.0)
	_t.eq("attempt 2 fires the same audio cues as attempt 1", _cue_names(bridge), first_cues)

	await _launch_player_from_pad(game)

	for stage in [3, 5]:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await _physics(4)
		await _check_stage(game, stage)

	game.flow.enter_boss(Vector3.ZERO)
	await _physics(3)
	_t.eq("boss entry leaves the stage flow", game.flow.state_name(), "boss")
	_t.check("boss entry tears the bridge down", not bridge.configured and bridge.setpieces == null)
	_t.eq("boss entry stops every loop", bridge.active_audio_loops().size(), 0)
	_t.eq("boss entry frees the ExpAudio players", _count_named(bridge, "ExpAudio_"), 0)
	_t.check("boss entry frees the arena chunk", bridge.live_chunk() == null and _count_named(game, LiveRunBridge.CHUNK_HOLDER_NAME) == 0)
	_t.eq("a torn-down bridge steps to nothing", bridge.live_step(1.0 / 90.0), {})

	root.remove_child(game)
	game.free()
	await _physics(2)


func _launch_player_from_pad(game) -> void:
	var bridge = game.experimental_bridge
	var chunk: Node3D = bridge.live_chunk()
	var pad: Dictionary = bridge.setpieces.snapshot()["jump_pads"][0]
	var origin: Vector3 = pad["origin"]
	var floor_y := chunk.global_position.y
	game.player.set_frozen(false)
	game.player.reset_to(Vector3(origin.x, floor_y + BALL_RADIUS_M + 0.05, origin.z))
	var peak := -INF
	for _i in _seconds(2.4):
		await physics_frame
		peak = maxf(peak, game.player.ball_position().y - floor_y)
	var rest: float = game.player.ball_position().y - floor_y
	_t.check("the PlayerBall parked on %s launches upward (peak > 4.0 m)" % pad["id"], peak > 4.0, "peak %.2f m" % peak)
	_t.check("the PlayerBall lands on the catwalk", absf(rest - 8.5) <= 0.35, "resting %.2f m above the chunk floor" % rest)
	_t.eq("the PlayerBall keeps no deck pass-through", game.player.body().get_collision_exceptions().size(), 0)
