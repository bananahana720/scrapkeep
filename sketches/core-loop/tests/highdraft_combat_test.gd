extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const RosterHighdraft := preload("res://src/combat/roster_highdraft.gd")
const AllyHusk := preload("res://src/combat/ally_husk.gd")
const AllyHuskLook := preload("res://src/presentation/ally_husk_look.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const Parts := preload("res://src/build/parts.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Worlds := preload("res://src/core/worlds.gd")
const T := preload("res://tests/support/t.gd")

const DT := 1.0 / 90.0


class FakeAudioCtx:
	extends RefCounted
	var events: Node


class AnthemRig:
	extends Audio
	var named: Array = []
	func ace_wanted() -> bool:
		return true
	func _ace_named(id: String, at: int, _boss := false, _won := true) -> void:
		named.append([id, at])


var _t := T.new("highdraft_combat_test")
var _game: Node


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _clear_budget_gap() -> void:
	if root.has_meta(AttackBudget.LAST_META):
		root.remove_meta(AttackBudget.LAST_META)


func _clear_enemies() -> void:
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.free()


func _ground(x: float, z: float) -> float:
	return _game.ctx.terrain.height(x, z)


func _park_ball(at: Vector3, vel := Vector3.ZERO) -> void:
	_game.player.reset_to(Vector3(at.x, _ground(at.x, at.z) + 1.05, at.z), vel)


func _set_player(pos: Vector3, vel: Vector3, grounded := true, carving := false, tier := SpeedTier.CRUISE) -> void:
	var body: RigidBody3D = _game.player.body()
	body.global_position = pos
	body.linear_velocity = vel
	_game.player.state.velocity = vel
	_game.player.state.grounded = grounded
	_game.player.state.carving = carving
	_game.player.state.tier = tier


func _step_node(node: Node, seconds: float) -> void:
	var steps := int(ceil(seconds / DT))
	for _i in steps:
		if is_instance_valid(node) and node.has_method("_physics_process"):
			node._physics_process(DT)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_s: float): pass
	_game.flow.enter_stage(5, Vector3.ZERO, false)
	await _frames(3)
	_clear_enemies()
	_park_ball(Vector3(0.0, 0.0, 128.0))
	await _frames(2)

	await _check_line_cutter_boomerang()
	await _check_kite_drone_slipstream()
	await _check_ballast_heavy_counter_tug()
	await _check_gap_net_shock_net()
	await _check_budget_and_gap()
	await _check_highdraft_ghost_shift_husks()
	await _check_mind_husk_counter_hack()
	_check_stage5_event_prewarm()
	_check_mind_3phase_anthems()
	await _check_full_alpha_and_brindle_cobalt()

	_clear_enemies()
	EventDirector.settle_prewarm()
	EventDirector.reset_prewarm()
	_game.free()
	quit(_t.verdict())


func _check_line_cutter_boomerang() -> void:
	_clear_budget_gap()
	_park_ball(Vector3(-4.0, 0.0, 120.0))
	await _frames(2)
	var cutter = _game.combat.spawn_enemy("line_cutter", Vector3(-13.0, _ground(-13.0, 120.0) + 1.2, 120.0))
	cutter._rest = 99.0
	for _i in 30:
		await physics_frame
		if cutter.is_on_floor():
			break
	cutter.set_physics_process(false)
	cutter.next_attack = "boomerang"
	cutter._rest = 0.0
	cutter._physics_process(DT)
	var tele = cutter.telegraph()
	_t.check("line_cutter boomerang commits LANE telegraph >= 0.75 s",
		tele != null and tele.type == Threat.Type.LANE and cutter.warn_seconds >= 0.75,
		"tele=%s warn=%.2f" % [str(tele), cutter.warn_seconds])
	_t.eq("line_cutter boomerang uses Palette.HAZARD", Threat.row(tele.type)["color"] if tele != null else Color.BLACK, Palette.HAZARD)

	# Outbound over a gap cuts hooked line and grants <= 0.5 s re-hook kick.
	var air := Vector3(-24.0, _ground(-13.0, 120.0) + 2.0, 120.0)
	_game.player.reset_to(air, Vector3(-10.0, 0.0, 0.0))
	await physics_frame
	_game.player.kit.hooked = true
	_game.player.kit.gliding = false
	cutter._t = cutter.warn_seconds
	cutter._physics_process(DT)
	# Force lane check along outbound flight.
	cutter._boom_apex = air + Vector3(-4.0, 0.0, 0.0)
	cutter._t = 0.3
	cutter._live(DT)
	# Move ball out of auto-bat radius to assert returning_disc phase, then bat it cleanly.
	_game.player.reset_to(air + Vector3(0.0, 0.0, 20.0), Vector3.ZERO)
	await physics_frame
	cutter._t = cutter.BOOMERANG_OUT + 0.25
	cutter._live(DT)
	_t.check("line_cutter boomerang enters returning_disc phase", cutter.returning_disc)
	var knocked_before: int = cutter.knocks
	var batted: bool = cutter.bat_return_disc()
	_t.check("batting returning disc knocks Cutter toward rim for ring-out",
		batted and cutter.boomerangs_batted == 1 and cutter.knocks > knocked_before and cutter.broken_by == "boomerang_bat",
		"batted=%s count=%d knocks=%d broken=%s" % [str(batted), cutter.boomerangs_batted, cutter.knocks, cutter.broken_by])
	cutter.free()
	await physics_frame


func _check_kite_drone_slipstream() -> void:
	_clear_budget_gap()
	var start_at := Vector3(0.0, _ground(0.0, 40.0) + 8.0, 40.0)
	_game.player.reset_to(start_at, Vector3(16.0, 0.0, 0.0))
	await physics_frame
	var kite = _game.combat.spawn_enemy("kite_drone", start_at + Vector3(8.0, 4.0, 0.0))
	kite.set_physics_process(false)
	kite.next_attack = "slipstream"
	kite._rest = 0.0
	kite._physics_process(DT)
	var tele = kite.telegraph()
	_t.check("kite_drone slipstream commits LANE telegraph >= 0.75 s",
		tele != null and tele.type == Threat.Type.LANE and kite.warn_seconds >= 0.75,
		"tele=%s warn=%.2f" % [str(tele), kite.warn_seconds])
	_t.eq("kite_drone slipstream uses Palette.HAZARD", Threat.row(tele.type)["color"], Palette.HAZARD)

	var hits := [0]
	kite.hit_player.connect(func(_d, _s): hits[0] += 1)
	_step_node(kite, kite.warn_seconds + 0.1)
	_t.check("kite_drone slipstream spawns active updraft wake", kite.slipstream_active and kite.swoops == 1,
		"active=%s swoops=%d" % [str(kite.slipstream_active), kite.swoops])
	# Park kite out of ball collision path while its wake stays active, then ride airborne across chasm.
	kite.global_position = kite.slipstream_origin + Vector3(0.0, 12.0, 0.0)
	var ride_pos: Vector3 = kite.slipstream_origin + kite.slipstream_dir * 3.0 + Vector3.UP * 1.0
	_game.player.reset_to(ride_pos, kite.slipstream_dir * 16.0)
	await physics_frame
	for _i in 95:
		_game.player.state.grounded = false
		kite._step_slipstream(DT)
		await physics_frame
	_t.eq("kite_drone slipstream never stops a moving/airborne ball (ruling cu)", hits[0], 0)
	_t.check("riding slipstream wake carries ball >= 20 m across chasm",
		kite.slipstream_rides >= 1 and kite.slipstream_carry_m >= 20.0,
		"rides=%d carry=%.1f m" % [kite.slipstream_rides, kite.slipstream_carry_m])
	if is_instance_valid(kite):
		kite.free()
	await physics_frame


func _check_ballast_heavy_counter_tug() -> void:
	_clear_budget_gap()
	_park_ball(Vector3(-4.0, 0.0, 120.0))
	await _frames(2)
	var heavy = _game.combat.spawn_enemy("ballast_heavy", Vector3(-10.0, _ground(-10.0, 120.0) + 1.2, 120.0))
	heavy._rest = 99.0
	for _i in 240:
		await physics_frame
		if heavy.posted:
			break
	_t.check("ballast_heavy posts on west rim", heavy.posted and not heavy.beached)
	_clear_budget_gap()
	heavy.next_attack = "counter_tug"
	heavy._rest = 0.0
	for _i in 10:
		await physics_frame
		if heavy.tug_active:
			break
	var tele = heavy.telegraph()
	_t.check("ballast_heavy counter_tug commits LANE >= 0.75 s and plants stake",
		tele != null and tele.type == Threat.Type.LANE and heavy.warn_seconds >= 0.75 and is_instance_valid(heavy.stake),
		"tele=%s warn=%.2f stake=%s" % [str(tele), heavy.warn_seconds, str(heavy.stake)])
	_t.eq("ballast_heavy counter_tug uses Palette.HAZARD", Threat.row(tele.type)["color"], Palette.HAZARD)

	# Roll over stake during tug -> snaps stake and catapults Heavy off its cliff to ring-out!
	var stake_pos: Vector3 = heavy.stake.global_position
	var died := [false]
	var cause := [""]
	var catapult_count := [0]
	heavy.died.connect(func(_at, _s):
		died[0] = true
		cause[0] = heavy.last_damage_source
		catapult_count[0] = heavy.catapults)
	_park_ball(stake_pos)
	for _i in 180:
		await physics_frame
		if died[0]:
			break
	if catapult_count[0] == 0 and is_instance_valid(heavy):
		catapult_count[0] = heavy.catapults
	_t.check("rolling over stake during counter_tug catapults Heavy off cliff to ring-out",
		catapult_count[0] == 1 and died[0] and cause[0] == "ring_out",
		"catapults=%d died=%s cause='%s'" % [catapult_count[0], str(died[0]), cause[0]])
	if is_instance_valid(heavy):
		heavy.free()
	await physics_frame


func _check_gap_net_shock_net() -> void:
	_clear_budget_gap()
	_park_ball(Vector3(12.0, 0.0, 40.0))
	await _frames(2)
	var net = _game.combat.spawn_enemy("gap_net", Vector3(12.0, _ground(12.0, 40.0) + 1.2, 40.0))
	await _frames(2)
	net.set_physics_process(false)
	if not net.nets.is_empty():
		var c0: Vector3 = net.nets[0]["center"]
		var n0: Vector3 = net.nets[0]["normal"]
		_game.player.reset_to(c0 - n0 * 4.0 + Vector3(0.0, 2.0, 0.0), Vector3.ZERO)
		await physics_frame
	net.next_attack = "shock_net"
	net._rest = 0.0
	net._physics_process(DT)
	var tele = net.telegraph()
	_t.check("gap_net shock_net commits LANE >= 0.75 s and deploys dual layer",
		tele != null and tele.type == Threat.Type.LANE and net.warn_seconds >= 0.75 and net.shock_layer_active and net.nets.size() >= 2,
		"tele=%s warn=%.2f dual=%s nets=%d" % [str(tele), net.warn_seconds, str(net.shock_layer_active), net.nets.size()])
	_t.eq("gap_net shock_net uses Palette.HAZARD", Threat.row(tele.type)["color"] if tele != null else Color.BLACK, Palette.HAZARD)

	# Rip at Blazing -> grants 3.0 s electric aura that survives net death onto next island.
	var n: Dictionary = net.nets[0]
	var c: Vector3 = (n["center"] as Vector3) + Vector3.UP * 4.0
	var normal: Vector3 = n["normal"]
	net.phase = net.Phase.LIVE
	_game.player.reset_to(c - normal * 1.0, normal * 30.0)
	await physics_frame
	n["last"] = net._side_of(n, c - normal * 1.0)
	_game.player.reset_to(c + normal * 0.4, normal * 30.0)
	await _frames(2)
	_game.player.state.tier = SpeedTier.BLAZING
	net._live(DT)
	var shock_rips_count: int = net.shock_rips
	var aura_node = net.last_shock_rip.get("aura")
	await physics_frame
	var aura_active := bool(_game.player.get_meta("electric_aura_active", false))
	var aura_left := float(_game.player.get_meta("electric_aura_left", 0.0))
	_t.check("blazing rip of dual-layer shock net grants 3 s electric aura onto next island",
		shock_rips_count == 1 and aura_active and aura_left >= 2.5 and is_instance_valid(aura_node),
		"rips=%d active=%s left=%.2f aura=%s" % [shock_rips_count, str(aura_active), aura_left, str(aura_node)])
	if is_instance_valid(aura_node):
		aura_node.free()
	if is_instance_valid(net):
		net.free()
	await physics_frame


func _check_budget_and_gap() -> void:
	_clear_budget_gap()
	_park_ball(Vector3(0.0, 0.0, 120.0))
	await physics_frame
	var k1 = _game.combat.spawn_enemy("kite_drone", Vector3(6.0, _ground(6.0, 120.0) + 6.0, 120.0))
	var k2 = _game.combat.spawn_enemy("kite_drone", Vector3(-6.0, _ground(-6.0, 120.0) + 6.0, 120.0))
	k1.set_physics_process(false)
	k2.set_physics_process(false)
	k1.next_attack = "slipstream"
	k2.next_attack = "slipstream"
	k1._rest = 0.0
	k2._rest = 0.0
	k1._physics_process(DT)
	k2._physics_process(DT)
	_t.check("AttackBudget 0.2 s inter-warning gap blocks simultaneous Highdraft tells",
		k1.phase == k1.Phase.WARN and k2.phase == k2.Phase.ROAM,
		"k1=%s k2=%s" % [k1.state_name(), k2.state_name()])
	k1.free()
	k2.free()
	await physics_frame


func _check_highdraft_ghost_shift_husks() -> void:
	var mgr = _game.combat.ally_husks
	mgr._reset()
	for kind in RosterHighdraft.HIGHDRAFT_KINDS:
		_t.check("AllyHusk has Highdraft profile for %s" % kind, AllyHusk.PROFILES.has(kind))
		_t.check("%s eligible for Ghost Shift wreck (not ringed out)" % kind, AllyHusk.can_leave_husk(kind, false, false))
		_t.check("%s ringed out leaves no husk" % kind, not AllyHusk.can_leave_husk(kind, true, false))
	var at := Vector3(0.0, _ground(0.0, 120.0), 120.0)
	var dummy := CharacterBody3D.new()
	dummy.set_script(preload("res://src/combat/line_cutter.gd"))
	_game.add_child(dummy)
	dummy.set_physics_process(false)
	dummy.global_position = at
	dummy.kind = "line_cutter"
	dummy.ringed_out = false
	var w: Dictionary = mgr.record_wreck(dummy)
	dummy.free()
	_t.check("Highdraft line_cutter leaves Ghost Shift wreck", not w.is_empty())
	var raised: Array = mgr.raise_in_radius(at, 8.0)
	_t.eq("Highdraft wreck raises as AllyHusk", raised.size(), 1)
	if not raised.is_empty():
		var h: AllyHusk.HuskUnit = raised[0]
		var foe := Node3D.new()
		_game.add_child(foe)
		foe.global_position = at + Vector3(6.0, 0.0, 0.0)
		mgr._begin_warn(h, foe)
		var zone: AllyHuskLook.AllyZone = h.zone
		_t.check("Highdraft husk AllyZone strictly uses B6 AMBER #E5A044 (zero HAZARD)",
			zone != null and zone.is_in_group("ally_zone") and not zone.is_in_group(Threat.GROUP)
			and zone.color == Palette.AMBER and zone.color != Palette.HAZARD,
			"zone=%s color=%s" % [str(zone), str(zone.color) if zone != null else "null"])
		foe.free()
	mgr._reset()


func _check_mind_husk_counter_hack() -> void:
	var mgr = _game.combat.ally_husks
	mgr._reset()
	var at := Vector3(0.0, _ground(0.0, 120.0), 120.0)
	_park_ball(at + Vector3(18.0, 0.0, 0.0))
	await physics_frame
	# Raise a Highdraft kite_drone husk.
	var src_node := CharacterBody3D.new()
	src_node.set_script(preload("res://src/combat/kite_drone.gd"))
	_game.add_child(src_node)
	src_node.set_physics_process(false)
	src_node.global_position = at
	src_node.kind = "kite_drone"
	src_node.ringed_out = false
	mgr.record_wreck(src_node)
	src_node.free()
	var raised: Array = mgr.raise_in_radius(at, 8.0)
	var husk: AllyHusk.HuskUnit = raised[0]
	var base_dmg: float = husk.damage

	# 1. Mind's Hand attempts re-possession -> 1.0 s Palette.HAZARD #FF5A3C telegraph (NEVER purple).
	var hand = _game.combat.spawn_enemy("mind_hand", at + Vector3(8.0, 1.2, 0.0))
	hand.set_physics_process(false)
	var started: bool = hand.attempt_husk_takeover(husk)
	_t.check("mind_hand initiates 1.0 s Palette.HAZARD #FF5A3C takeover telegraph",
		started and husk.takeover_active and is_equal_approx(husk.takeover_duration, 1.0)
		and husk.takeover_color == Palette.HAZARD and husk.takeover_visual != null
		and husk.takeover_visual.get_meta("color") == Palette.HAZARD,
		"started=%s active=%s dur=%.2f color=%s" % [str(started), str(husk.takeover_active), husk.takeover_duration, str(husk.takeover_color)])
	var wps: Array = hand.weak_points()
	var has_node := wps.any(func(wp): return String(wp.get("id", "")) == "takeover_node")
	_t.check("mind_hand exposes shootable takeover_node weak point", has_node and is_equal_approx(hand.plating_for("bolt", "takeover_node"), 0.0))

	# Shooting the takeover node interrupts mind_hand and overcharges the husk!
	var node_pos: Vector3 = husk.takeover_node_pos
	_game.events.shot_fired.emit("rivet_gun", node_pos + Vector3(10.0, 0.0, 0.0), node_pos - Vector3(2.0, 0.0, 0.0))
	_t.check("shooting takeover node interrupts Mind Hand and overcharges husk",
		not husk.takeover_active and husk.is_overcharged() and husk.effective_damage() > base_dmg
		and hand.takeovers_interrupted == 1 and hand.stunned(),
		"active=%s overcharged=%s dmg=%.1f>%.1f hand_int=%d stun=%s" % [str(husk.takeover_active), str(husk.is_overcharged()), husk.effective_damage(), base_dmg, hand.takeovers_interrupted, str(hand.stunned())])

	# 2. Tapping the takeover node with the ball interrupts a Mind takeover too!
	var mind_stub := Node3D.new()
	mind_stub.set_script(preload("res://src/boss/mind.gd"))
	mind_stub.ctx = _game.ctx
	_game.add_child(mind_stub)
	husk.overcharge_left = 0.0
	husk.overcharged = false
	var boss_started: bool = mind_stub.attempt_husk_takeover(husk)
	_t.check("mind.gd initiates 1.0 s Palette.HAZARD takeover on active husk",
		boss_started and husk.takeover_active and husk.takeover_color == Palette.HAZARD)
	mgr._step_takeover(husk, DT, husk.takeover_node_pos)
	_t.check("tapping takeover node interrupts Mind and overcharges husk",
		not husk.takeover_active and husk.is_overcharged() and mind_stub.takeovers_interrupted == 1,
		"active=%s overcharged=%s mind_int=%d" % [str(husk.takeover_active), str(husk.is_overcharged()), mind_stub.takeovers_interrupted])

	# 3. Uninterrupted 1.0 s takeover completes and re-possesses (removes) the husk.
	var started3: bool = mind_stub.attempt_husk_takeover(husk)
	_t.check("uninterrupted takeover starts cleanly", started3 and husk.takeover_active)
	var completed := false
	for _i in 100:
		if mgr._step_takeover(husk, DT, Vector3(999.0, 0.0, 999.0)):
			completed = true
			break
	_t.check("uninterrupted 1.0 s takeover completes re-possession",
		completed and mind_stub.takeovers_completed == 1 and mgr.takeovers_completed >= 1)

	mind_stub.free()
	hand.free()
	mgr._reset()
	await physics_frame


func _check_stage5_event_prewarm() -> void:
	EventDirector.reset_prewarm()
	var res: Dictionary = EventDirector.prewarm_stage_families(_game.ctx.terrain, 5)
	_t.check("Stage 5 EventFamilies prewarm loads all 4 event family scripts",
		int(res.get("scripts_loaded", 0)) == 4 and res.get("stage") == 5,
		"res=%s" % [str(res)])
	EventDirector.settle_prewarm()


func _check_mind_3phase_anthems() -> void:
	_t.eq("Mind 3-phase anthem mapping (4 fight phases -> 3 anthem phases)",
		[MindAttacks.anthem_phase(1), MindAttacks.anthem_phase(2), MindAttacks.anthem_phase(3), MindAttacks.anthem_phase(4)],
		[1, 2, 3, 3])
	_t.eq("Mind anthem BPM deltas (Base / +10 / +20 BPM)",
		[MindAttacks.anthem_bpm_delta(1), MindAttacks.anthem_bpm_delta(2), MindAttacks.anthem_bpm_delta(3), MindAttacks.anthem_bpm_delta(4)],
		[0, 10, 20, 20])
	_t.eq("Mind anime whole-step finale lift (+2 semitones in finale)",
		[MindAttacks.finale_lift_semitones(1), MindAttacks.finale_lift_semitones(2), MindAttacks.finale_lift_semitones(3), MindAttacks.finale_lift_semitones(4)],
		[0, 0, 2, 2])
	var events := GameEvents.new()
	root.add_child(events)
	var fake_ctx := FakeAudioCtx.new()
	fake_ctx.events = events
	var rig := AnthemRig.new()
	root.add_child(rig)
	rig.setup(fake_ctx)
	rig.sound_ready = true
	rig.pack_available = func(_id: String): return true
	rig.engine.force_track("mind", 0, "1", true)
	rig._boss_arena_track = "mind"
	rig._boss_phase = 1
	rig._phase_music_done = 1
	var p2: Dictionary = rig.phase_music(2)
	var p3: Dictionary = rig.phase_music(3)
	var has_lift_cue: bool = rig.cue_log.any(func(entry): return entry.size() >= 5 and entry[1] == "mind_finale_lift" and is_equal_approx(float(entry[4]), Harmony.ratio(2.0)))
	_t.check("Mind audio phase 2/3 books heavy/heavier anthems + whole-step finale lift",
		String(p2.get("track", "")) == "anthem-mind-heavy"
		and String(p3.get("track", "")) == "anthem-mind-heavier"
		and int(p3.get("lift_semitones", 0)) == 2 and has_lift_cue,
		"p2=%s p3=%s lift_cue=%s" % [str(p2), str(p3), str(has_lift_cue)])
	rig.free()
	events.free()


func _check_full_alpha_and_brindle_cobalt() -> void:
	# Full-alpha unlock: ruling du automatic stop is removed from game.gd, --final-world stays clean.
	var game_src := FileAccess.get_file_as_string("res://src/game.gd")
	_t.check("ruling du automatic World-1 stop removed from game.gd",
		not game_src.contains("end_players_run_at_world_one(") and Tuning.FULL_ALPHA_UNLOCKED and Worlds.FULL_ALPHA)
	var plain := Tuning.new()
	plain.apply_args(PackedStringArray([]), "launch")
	_t.eq("plain launch has full-alpha final_world == 0", plain.final_world(), 0)
	var capped := Tuning.new()
	capped.apply_args(PackedStringArray(["--final-world=1"]), "launch")
	_t.eq("--final-world=1 CLI override stays intact", capped.final_world(), 1)

	# Brindle's cobalt pick (ruling ap): rolls 2 rare/cobalt parts and preserves admirals_crest.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var picks := RewardGates.roll_cobalt_boss_picks(rng, "pylon_engineer", [], 2)
	var all_rare: bool = picks.size() == 2 and picks.all(func(id): return Parts.rung_of(id) >= Parts.RUNG_FLOOR)
	_t.check("RewardGates.roll_cobalt_boss_picks returns 2 guaranteed rare/cobalt parts",
		all_rare, "picks=%s" % [str(picks)])

	# Simulate Brindle rout when continuing into World 2: keeps admirals_crest + offers cobalt pick.
	_game.ctx.run.enter_stage(_game.ctx.stages.last_of(1))
	_game.ctx.run.extra.erase("brindle_cobalt_pending")
	_game.ctx.run.extra.erase("brindle_cobalt_picked")
	_game.boss.enter_arena(Vector3(16.0, 0.0, 0.0))
	await physics_frame
	_game.boss._defeat("ram", _game.player.ball_position())
	var has_crest: bool = _game.ctx.run.parts.has(Rules.CREST_PART)
	var has_offers: bool = _game.boss.brindle_cobalt_offers.size() == 2
	var pending_id: String = String(_game.ctx.run.extra.get("brindle_cobalt_pending", ""))
	_t.check("Brindle defeat on full-alpha run keeps admirals_crest and opens cobalt pick",
		has_crest and has_offers and pending_id != "" and Parts.rung_of(pending_id) >= Parts.RUNG_FLOOR,
		"crest=%s offers=%s pending=%s" % [str(has_crest), str(_game.boss.brindle_cobalt_offers), pending_id])
	# Fallback settle grants the cobalt pick exactly once (idempotent on second call / Continue).
	var count_before: int = _game.ctx.run.parts.size()
	_game.flow._settle_brindle_cobalt_pick()
	var count_after: int = _game.ctx.run.parts.size()
	_game.flow._settle_brindle_cobalt_pick()
	var count_twice: int = _game.ctx.run.parts.size()
	_t.check("Brindle cobalt pick fallback settles at most once (idempotent across Continue)",
		count_after == count_before + 1 and count_twice == count_after
		and _game.ctx.run.parts.has(pending_id) and not _game.ctx.run.extra.has("brindle_cobalt_pending"),
		"before=%d after=%d twice=%d" % [count_before, count_after, count_twice])
	_game.boss.exit_arena()
	await physics_frame
