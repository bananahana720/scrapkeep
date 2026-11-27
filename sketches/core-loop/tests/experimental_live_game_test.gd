extends SceneTree

const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")
const LiveRunBridge := preload("res://src/experimental/live_run_bridge.gd")
const DynamicSetpieces := preload("res://src/experimental/dynamic_setpieces.gd")
const LiveWorldActors := preload("res://src/experimental/live_world_actors.gd")
const RefurbishedElites := preload("res://src/experimental/refurbished_elites.gd")
const AdversityDirector := preload("res://src/experimental/adversity_director.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

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
const STAGE_CHUNKS := {
	1: "SmelterCraneChunk", 2: "SmelterCraneChunk", 3: "CompactorCanyonChunk",
	4: "CompactorCanyonChunk", 5: "OrbitalGraveyardChunk", 6: "OrbitalGraveyardChunk",
}
const STAGE_BIOMES := {1: &"spillway", 2: &"spillway", 3: &"dig", 4: &"dig", 5: &"highdraft", 6: &"highdraft"}
const SHOT_LIMIT := 80

var _t := T.new("experimental_live_game_test")


class FakeMap extends RefCounted:
	var line_x := INF
	var everywhere := false

	func line_within(at: Vector2, reach_m: float) -> bool:
		return everywhere or absf(at.x - line_x) <= reach_m


class FakeTerrain extends RefCounted:
	var stage := 1
	var beacon := Vector3(9999.0, 0.0, 9999.0)
	var map := FakeMap.new()

	func spawn_point(_index: int) -> Vector3:
		return Vector3.ZERO

	func entry_heading(_index: int) -> Vector3:
		return Vector3.FORWARD

	func height(_x: float, _z: float) -> float:
		return 0.0

	func contains(point: Vector3) -> bool:
		return absf(point.x) < 400.0 and absf(point.z) < 400.0

	func beacon_point(_index: int) -> Vector3:
		return beacon

	func map_for(_index: int) -> RefCounted:
		return map


class FakeCtx extends RefCounted:
	var terrain := FakeTerrain.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	LiveRunBridge._reset()
	await _test_piers_are_solid()
	await _test_pads_launch_onto_decks()
	_test_chunk_site_clearance()
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
	_t.eq("default Game has no ExperimentalLiveActors", _count_named(game, LiveWorldActors.NODE_NAME), 0)
	_t.eq("default Game has no Salvage Press beacon", _count_named(game, "SalvagePressBeacon"), 0)
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
	_t.check("stage %d chunk stands 80 m clear of the spawn" % stage, away >= LiveRunBridge.CHUNK_SPAWN_CLEAR_M, "%.1f m" % away)
	var beacon: Vector3 = game.ctx.terrain.beacon_point(stage)
	var beacon_m := Vector2(chunk.global_position.x - beacon.x, chunk.global_position.z - beacon.z).length()
	_t.check("stage %d chunk stands 52 m clear of the beacon" % stage, beacon_m >= LiveRunBridge.CHUNK_BEACON_CLEAR_M, "%.1f m" % beacon_m)
	var site: Dictionary = bridge.snapshot()["live_site"]
	_t.check("stage %d chunk site is clear of riding lines" % stage, bool(site.get("clear", false)) and int(site.get("line_hits", -1)) == 0, str(site))
	var actors = bridge.live_actors
	_t.check("stage %d mounts live actors beside the chunk" % stage,
		actors != null and is_instance_valid(actors) and actors.get_parent() == holder and _count_named(game, LiveWorldActors.NODE_NAME) == 1)
	if actors != null and is_instance_valid(actors):
		var snap: Dictionary = actors.snapshot()
		_t.eq("stage %d spawns 4 elemental props" % stage, snap["props"], 4)
		_t.eq("stage %d spawns its hauler drones" % stage, snap["haulers"], 1 if stage <= 2 else 2)
		_t.eq("stage %d arms the Salvage Press beacon" % stage, snap["lockdown"], "armed")
		_t.eq("stage %d live actors draw no primitive mesh" % stage, _primitive_meshes(actors), 0)
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
	await _check_live_props_and_haulers(game)
	await _check_live_elites(game)
	await _check_live_squall(game)
	await _check_live_lockdown(game)
	await _check_live_retry(game)

	for stage in [2, 3, 4, 5, 6]:
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
	_t.check("boss entry frees the live actors", bridge.live_actors == null and _count_named(game, LiveWorldActors.NODE_NAME) == 0)
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


func _primitive_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh is PrimitiveMesh else 0
	for child in node.get_children():
		count += _primitive_meshes(child)
	return count


func _targets(game, kind: StringName) -> Array:
	var out: Array = []
	for row in game.experimental_bridge.live_actors.snapshot()["targets"]:
		if row["kind"] == kind:
			out.append(row)
	return out


func _target(game, id: String) -> Dictionary:
	for row in game.experimental_bridge.live_actors.snapshot()["targets"]:
		if String(row["id"]) == id:
			return row
	return {}


func _shoot(game, at: Vector3) -> void:
	game.ctx.events.shot_fired.emit("test_rifle", at + Vector3(0.0, 9.0, 0.0), at)


func _has_fact(bridge, kind: String) -> bool:
	for fact in bridge.fact_log():
		if String(fact.get("kind", "")) == kind:
			return true
	return false


func _park(game, at: Vector3) -> void:
	game.player.reset_to(Vector3(at.x, at.y + BALL_RADIUS_M + 0.05, at.z))


func _check_live_props_and_haulers(game) -> void:
	var bridge = game.experimental_bridge
	var actors = bridge.live_actors
	var run = game.ctx.run
	var ecology = bridge.ecology
	var before: Dictionary = actors.snapshot()
	var scrap_before: int = run.scrap
	var cases := [
		{"id": "live_prop_0", "tag": &"coolant_brittle", "verb": "shot"},
		{"id": "live_prop_1", "tag": &"burning", "verb": "shot"},
		{"id": "live_prop_2", "tag": &"electrified", "verb": "slam"},
	]
	for row in cases:
		var target := _target(game, "prop:" + String(row["id"]))
		_t.check("prop %s stands in the live world" % row["id"], not target.is_empty())
		if target.is_empty():
			continue
		var at: Vector3 = target["pos"]
		if row["verb"] == "shot":
			_shoot(game, at)
		else:
			game.player.shockwave.emit(at, 1.0)
		await _physics(1)
		var tags: Array[StringName] = bridge.env_tags.tags_at(at, 1.0)
		_t.check("a %s on %s emits %s" % [row["verb"], ecology.prop(String(row["id"])).kind, row["tag"]], tags.has(row["tag"]), str(tags))
		if row["verb"] == "shot":
			_t.check("the shot ruptures %s in ecology and clears its node" % row["id"],
				not ecology.prop(String(row["id"])).intact and _target(game, "prop:" + String(row["id"])).is_empty())
		else:
			var reactions: Array = actors.snapshot()["reactions"]
			_t.check("the slammed conduit's magnetic field sparks a Rail Surge", reactions.has(&"rail_surge"), str(reactions))
	var after: Dictionary = actors.snapshot()
	_t.eq("three props reacted", int(after["ruptures"]) - int(before["ruptures"]), 3)
	_t.check("each reaction spawns a shock ring", int(after["rings_spawned"]) - int(before["rings_spawned"]) >= 3)
	_t.check("ruptured props pay scrap", run.scrap > scrap_before, "%d -> %d" % [scrap_before, run.scrap])

	var cogs_before: int = run.cogs
	var shots := 0
	while shots < SHOT_LIMIT and not _targets(game, &"hauler").is_empty():
		_shoot(game, _targets(game, &"hauler")[0]["pos"])
		shots += 1
		await _physics(1)
	var snap: Dictionary = actors.snapshot()
	_t.eq("shots scrap the hauler drone", int(snap["kills"].get(&"hauler", 0)), 1)
	_t.check("the hauler drone pays cogs", run.cogs > cogs_before, "%d -> %d" % [cogs_before, run.cogs])
	_t.check("a hauler kill logs hauler_scrapped", _has_fact(bridge, "hauler_scrapped"))
	_t.eq("the hauler node is gone", _count_named(game, "ExpHauler_"), 0)


func _check_live_elites(game) -> void:
	var bridge = game.experimental_bridge
	var actors = bridge.live_actors
	var ball: Vector3 = game.player.ball_position()
	var insts: Array = []
	for i in LiveWorldActors.ELITE_CAP + 2:
		var inst = RefurbishedElites.spawn_instance(&"over_plated_juggernaut", "test_elite_%d" % i, ball + Vector3(10.0, 0.0, float(i) * 2.0), 1.0)
		insts.append(inst)
		bridge.director.elite_purchased.emit(inst)
	await _physics(1)
	_t.eq("elite purchases spawn live elites up to the cap", int(actors.snapshot()["elites"]), LiveWorldActors.ELITE_CAP)
	_t.eq("live elites are sculpted nodes", _count_named(game, "ExpElite_"), LiveWorldActors.ELITE_CAP)

	var first = insts[0]
	var row := _target(game, "elite:test_elite_0")
	var at: Vector3 = row["pos"]
	var integrity := float(first.plates[0]["integrity"])
	game.player.reset_to(at + Vector3(-2.0, -LiveWorldActors.ELITE_HOVER_M, 0.0), Vector3(16.0, 0.0, 0.0))
	await _physics(2)
	var rebound: Vector3 = game.player.body().linear_velocity
	_t.check("a fast ram cracks the elite's plate", float(first.plates[0]["integrity"]) < integrity,
		"%.1f -> %.1f" % [integrity, float(first.plates[0]["integrity"])])
	_t.check("the ram rebounds the ball", rebound.x < 0.0, str(rebound))

	var scrap_before := int(actors.snapshot()["paid_scrap"])
	var shots := 0
	while shots < SHOT_LIMIT and not _target(game, "elite:test_elite_0").is_empty():
		_shoot(game, _target(game, "elite:test_elite_0")["pos"])
		shots += 1
		await _physics(1)
	_t.check("shots scrap the elite", first.is_defeated() and _target(game, "elite:test_elite_0").is_empty(), "%d shots" % shots)
	_t.check("the elite pays its bounty", int(actors.snapshot()["paid_scrap"]) - scrap_before >= 85)
	_t.check("an elite kill toasts 'Elite scrapped'", game.hud.toast_texts().has("Elite scrapped"), str(game.hud.toast_texts()))


func _check_live_squall(game) -> void:
	var bridge = game.experimental_bridge
	var director = bridge.director
	if director.hazard_phase == AdversityDirector.HazardPhase.IDLE or director.hazard_phase == AdversityDirector.HazardPhase.COOLDOWN:
		director.start_hazard(&"corrosive_steam_squall", game.player.ball_position(), 0.0)
	if director.hazard_phase == AdversityDirector.HazardPhase.WARNING:
		director.hazard_elapsed_s = 99.0
	await _physics(3)
	_t.check("the squall ramps", director.hazard_phase in [AdversityDirector.HazardPhase.RAMP, AdversityDirector.HazardPhase.PEAK], str(director.hazard_phase))
	_t.eq("an active squall shows wind streaks", int(bridge.live_actors.snapshot()["streaks_visible"]), LiveWorldActors.STREAK_COUNT)
	var was: bool = UiTokens.reduced_motion
	UiTokens.reduced_motion = true
	await _physics(2)
	_t.eq("reduced motion hides the wind streaks", int(bridge.live_actors.snapshot()["streaks_visible"]), 0)
	UiTokens.reduced_motion = was


func _check_live_lockdown(game) -> void:
	var bridge = game.experimental_bridge
	var actors = bridge.live_actors
	var run = game.ctx.run
	var hits: Array[float] = []
	var on_hit := func(amount: float, source: String) -> void:
		if source == "experimental_slag":
			hits.append(amount)
	game.ctx.events.player_hit.connect(on_hit)
	_park(game, actors.beacon_position())
	await _physics(3)
	var snap: Dictionary = actors.snapshot()
	_t.eq("rolling onto the beacon starts the lockdown", snap["lockdown"], "locked")
	_t.check("encounters hold the lockdown", bridge.encounters.has_active_lockdown())
	_t.eq("the lockdown spawns 3 wave defenders", snap["defenders"], 3)
	_t.check("the lockdown toasts 'Press lockdown'", game.hud.toast_texts().has("Press lockdown"), str(game.hud.toast_texts()))

	var setpieces = bridge.setpieces
	var furnace_id := String(setpieces.snapshot()["furnace"]["id"])
	var centre: Vector3 = bridge.live_chunk().global_position
	var waited := 0
	while waited < _seconds(24.0) and String(setpieces.snapshot()["furnace"]["state"]) != "molten_pour":
		if String(setpieces.snapshot()["furnace"]["state"]) == "dormant":
			setpieces.trigger_setpiece(furnace_id)
		_park(game, centre)
		await physics_frame
		waited += 1
	_t.eq("the slag furnace pours", String(setpieces.snapshot()["furnace"]["state"]), "molten_pour")
	var knocked := false
	var damage_before := float(actors.snapshot()["construct_hazard_damage"])
	for _i in _seconds(3.4):
		var count: int = actors.snapshot()["hazard_times"].size()
		await physics_frame
		if actors.snapshot()["hazard_times"].size() > count:
			knocked = knocked or game.player.body().linear_velocity.length() > 3.0
		_park(game, centre)
	var times: Array = actors.snapshot()["hazard_times"]
	var spaced := true
	for i in range(1, times.size()):
		spaced = spaced and float(times[i]) - float(times[i - 1]) >= LiveWorldActors.HAZARD_COOLDOWN_S - 0.02
	_t.check("a ball sitting in the pour takes hull hits", times.size() >= 2 and hits.size() >= 2, "times %s hits %s" % [times, hits])
	_t.check("pour hits wait out the 1.2 s cooldown", spaced, str(times))
	_t.check("a pour hit knocks the ball back", knocked)
	game.ctx.events.player_hit.disconnect(on_hit)
	_t.check("the pour damages constructs inside it", float(actors.snapshot()["construct_hazard_damage"]) > damage_before)

	var scrap_before := int(actors.snapshot()["paid_scrap"])
	var cogs_before: int = run.cogs
	var saw_apex := false
	var steps := 0
	while steps < _seconds(40.0) and String(actors.snapshot()["lockdown"]) == "locked":
		var apex := _targets(game, &"apex")
		var defenders := _targets(game, &"defender")
		if not apex.is_empty():
			saw_apex = true
			_shoot(game, apex[0]["pos"])
		elif not defenders.is_empty():
			_shoot(game, defenders[0]["pos"])
		steps += 1
		await physics_frame
	snap = actors.snapshot()
	_t.check("the Foreman Rig rolls out after the waves", saw_apex)
	_t.eq("scrapping the rig ends the lockdown", snap["lockdown"], "spent")
	_t.check("the lockdown settles as won", not bridge.encounters.settled_history.is_empty()
		and bridge.encounters.settled_history[-1]["outcome"] == &"won", str(bridge.encounters.settled_history))
	_t.check("the rig pays the press jackpot scrap", int(snap["paid_scrap"]) - scrap_before >= 240, "%d" % (int(snap["paid_scrap"]) - scrap_before))
	_t.check("the rig pays the press jackpot cogs", run.cogs - cogs_before >= 30, "%d" % (run.cogs - cogs_before))
	_t.check("the rig kill toasts 'Foreman rig scrapped'", game.hud.toast_texts().has("Foreman rig scrapped"), str(game.hud.toast_texts()))
	_t.eq("the rig node is gone", _count_named(game, "ForemanRig"), 0)


func _check_live_retry(game) -> void:
	var bridge = game.experimental_bridge
	var old = bridge.live_actors
	game.flow.retry_stage()
	await _physics(2)
	var fresh = bridge.live_actors
	_t.check("retry rebuilds the live actors", fresh != null and is_instance_valid(fresh) and fresh != old and not is_instance_valid(old))
	if fresh == null or not is_instance_valid(fresh):
		return
	var snap: Dictionary = fresh.snapshot()
	_t.eq("retry re-arms the beacon", snap["lockdown"], "armed")
	_t.check("retry clears the lockdown", not bridge.encounters.has_active_lockdown())
	_t.check("retry restores the props and hauler", snap["props"] == 4 and snap["haulers"] == 1, str(snap))
	_t.check("retry clears every construct", snap["defenders"] == 0 and not snap["apex"] and snap["elites"] == 0, str(snap))
	_t.eq("retry keeps one live actor host", _count_named(game, LiveWorldActors.NODE_NAME), 1)
	_t.eq("retry leaves no elite nodes", _count_named(game, "ExpElite_"), 0)
	_t.eq("retry leaves no defender nodes", _count_named(game, "ExpDefender_"), 0)
	_t.eq("retry leaves no shock rings", _count_named(game, "ShockRing"), 0)


func _site_for(setup: Callable) -> Dictionary:
	var ctx := FakeCtx.new()
	setup.call(ctx.terrain)
	var bridge = LiveRunBridge.new()
	bridge._live_ctx = ctx
	var site: Dictionary = bridge._live_chunk_site(1)
	bridge._live_ctx = null
	bridge.free()
	return site


func _test_chunk_site_clearance() -> void:
	var open := _site_for(func(_terrain) -> void: pass)
	var first: Vector3 = open.get("origin", Vector3.INF)
	_t.check("an open map takes the first clean site", bool(open.get("clear", false)) and absf(first.x + 84.0) < 0.1, str(open))
	var lined := _site_for(func(terrain) -> void: terrain.map.line_x = first.x)
	_t.check("a riding line through the first site moves the chunk off it",
		bool(lined.get("clear", false)) and int(lined.get("line_hits", -1)) == 0 and (lined["origin"] as Vector3).distance_to(first) > 1.0, str(lined))
	var beaconed := _site_for(func(terrain) -> void: terrain.beacon = first)
	_t.check("a beacon on the first site moves the chunk 52 m clear",
		bool(beaconed.get("clear", false)) and float(beaconed.get("beacon_m", 0.0)) >= LiveRunBridge.CHUNK_BEACON_CLEAR_M, str(beaconed))
	_t.check("every site clears the spawn by 80 m", float(open.get("spawn_m", 0.0)) >= LiveRunBridge.CHUNK_SPAWN_CLEAR_M, str(open))
	var crowded := _site_for(func(terrain) -> void: terrain.map.everywhere = true)
	_t.check("a map with lines everywhere still places a chunk at the lowest-cost site",
		not crowded.is_empty() and not bool(crowded.get("clear", true)), str(crowded))
