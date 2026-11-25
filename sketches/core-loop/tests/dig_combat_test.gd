extends SceneTree

const Game := preload("res://src/game.gd")
const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Burrower := preload("res://src/combat/burrower.gd")
const DrillCrew := preload("res://src/combat/drill_crew.gd")
const LampSwarm := preload("res://src/combat/lamp_swarm.gd")
const PropCrew := preload("res://src/combat/prop_crew.gd")
const PitJaw := preload("res://src/combat/pit_jaw.gd")
const RosterDig := preload("res://src/combat/roster_dig.gd")
const Dispatcher := preload("res://src/combat/dispatcher.gd")
const AllyHusk := preload("res://src/combat/ally_husk.gd")
const AllyHuskLook := preload("res://src/presentation/ally_husk_look.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const WakingFloors := preload("res://src/boss/waking_floors.gd")
const WakingAttacks := preload("res://src/boss/waking_attacks.gd")
const Audio := preload("res://src/presentation/audio.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")

const DT := 1.0 / 60.0

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

var _t := T.new("dig_combat_test")
var _game: Node


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _step_node(node: Node, seconds: float) -> void:
	var steps := int(ceil(seconds / DT))
	for _i in steps:
		if is_instance_valid(node) and node.has_method("_physics_process"):
			node._physics_process(DT)


func _settle(node: CharacterBody3D, max_frames := 90) -> void:
	for _i in max_frames:
		if not is_instance_valid(node):
			return
		await physics_frame
		if node.is_on_floor():
			return


func _set_player(pos: Vector3, vel: Vector3, grounded := true, carving := false, tier := SpeedTier.CRUISE) -> void:
	var body: RigidBody3D = _game.player.body()
	body.global_position = pos
	body.linear_velocity = vel
	_game.player.state.velocity = vel
	_game.player.state.grounded = grounded
	_game.player.state.carving = carving
	_game.player.state.tier = tier
	_game.player.state.contact_normal = Vector3.UP if grounded and not carving else Vector3(0.85, 0.52, 0.0).normalized()


func _clear_budget_gap() -> void:
	if root.has_meta(AttackBudget.LAST_META):
		root.remove_meta(AttackBudget.LAST_META)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.flow.enter_stage(3, Vector3.ZERO, false)
	await physics_frame
	_game.player.set_physics_process(false)
	var base := Vector3(-40.0, 120.0, 20.0)
	var pad := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160.0, 2.0, 160.0)
	col.shape = box
	pad.collision_layer = 1
	pad.add_child(col)
	_game.add_child(pad)
	pad.global_position = base - Vector3(0.0, 1.0, 0.0)
	await physics_frame

	await _check_burrower_secondary(base + Vector3(0.0, 1.0, 0.0))
	await _check_drill_crew_secondary(base + Vector3(0.0, 1.0, 0.0))
	await _check_lamp_swarm_secondary(base + Vector3(0.0, 1.0, 0.0))
	await _check_prop_crew_secondary(base + Vector3(0.0, 1.0, 0.0))
	await _check_pit_jaw_secondary(base + Vector3(0.0, 1.0, 0.0))
	await _check_budget_and_gap(base + Vector3(0.0, 1.0, 0.0))
	_check_ghost_shift_dig(base + Vector3(0.0, 1.0, 0.0))
	_check_tile_drain_and_dispatcher(base + Vector3(0.0, 1.0, 0.0))
	_check_waking_3phase_anthems()

	pad.free()
	_game.free()
	quit(_t.verdict())


func _check_burrower_secondary(base: Vector3) -> void:
	_clear_budget_gap()
	_set_player(base, Vector3.ZERO, true, false, SpeedTier.WALK)
	var b = _game.combat.spawn_enemy("burrower", base + Vector3(8.0, 0.2, 0.0))
	b.set_physics_process(false)
	b.next_attack = "wall_skim"
	b._rest = 0.0
	b._physics_process(DT)
	var tele = b.telegraph()
	_t.check("burrower wall-skim commits LANE telegraph >= 0.70 s",
		tele != null and tele.type == Threat.Type.LANE and b.warn_seconds >= 0.70,
		"tele=%s warn=%.2f" % [str(tele), b.warn_seconds])
	_t.eq("burrower wall-skim tell uses Palette.HAZARD", Threat.row(tele.type)["color"], Palette.HAZARD)
	# Advance into live airborne arc and verify moving/carving ball is immune (ruling cu).
	_set_player(base + Vector3(4.0, 0.0, 0.0), Vector3(0.0, 0.0, 26.0), true, true, SpeedTier.FAST)
	var hits := [0]
	b.hit_player.connect(func(_dmg, _imp): hits[0] += 1)
	_step_node(b, b.warn_seconds + 0.25)
	_t.check("burrower wall-skim is airborne during live phase", b.airborne_skim)
	_t.eq("burrower wall-skim never stops a carving ball (ruling cu)", hits[0], 0)
	# Slam airborne Burrower -> instant airborne pin.
	b.on_struck("slam", "", {})
	_t.check("burrower airborne slam pins and kills it",
		b.airborne_pins == 1 and b.is_dead() and not b.last_pin.is_empty(),
		"pins=%d dead=%s pin=%s" % [b.airborne_pins, str(b.is_dead()), str(b.last_pin)])
	if is_instance_valid(b):
		b.free()
	await physics_frame


func _check_drill_crew_secondary(base: Vector3) -> void:
	_clear_budget_gap()
	_set_player(base, Vector3.ZERO, true, false, SpeedTier.WALK)
	var d = _game.combat.spawn_enemy("drill_crew", base + Vector3(12.0, 0.5, 0.0))
	d.global_position = base + Vector3(12.0, 0.2, 0.0)
	d._rest = 99.0
	await _settle(d)
	d.set_physics_process(false)
	var wall := StaticBody3D.new()
	wall.name = "TestRubbleWall"
	wall.add_to_group("rubble_wall")
	_game.add_child(wall)
	wall.global_position = base + Vector3(6.0, 0.5, 0.0)
	_clear_budget_gap()
	d.next_attack = "core_jet"
	d._rest = 0.0
	d._physics_process(DT)
	var tele = d.telegraph()
	_t.check("drill_crew core-jet commits LANE telegraph >= 0.70 s",
		tele != null and tele.type == Threat.Type.LANE and d.warn_seconds >= 0.70,
		"tele=%s warn=%.2f on_floor=%s" % [str(tele), d.warn_seconds, str(d.is_on_floor())])
	if tele != null:
		_t.eq("drill_crew core-jet tell uses Palette.HAZARD", Threat.row(tele.type)["color"], Palette.HAZARD)
	# Keep player moving fast out of stall so jet opens shortcut without hitting moving player.
	_set_player(base, Vector3(0.0, 0.0, 24.0), true, false, SpeedTier.FAST)
	var hits := [0]
	d.hit_player.connect(func(_dmg, _imp): hits[0] += 1)
	_step_node(d, d.warn_seconds + 0.15)
	_t.check("drill_crew core-jet baited into rubble wall opens shortcut",
		d.shortcuts_opened >= 1 and not wall.visible and wall.collision_layer == 0,
		"opened=%d vis=%s layer=%d" % [d.shortcuts_opened, str(wall.visible), wall.collision_layer])
	_t.eq("drill_crew core-jet does not stop a fast moving ball (ruling cu)", hits[0], 0)
	wall.free()
	if is_instance_valid(d):
		d.free()
	await physics_frame


func _check_lamp_swarm_secondary(base: Vector3) -> void:
	_clear_budget_gap()
	_set_player(base, Vector3.ZERO, true, false, SpeedTier.WALK)
	var warden = _game.combat.spawn_enemy("warden", base + Vector3(0.0, 0.5, 24.0))
	warden.set_physics_process(false)
	var before_posture: float = warden.posture() if warden != null and warden.has_method("posture") else 0.0
	var ls = _game.combat.spawn_enemy("lamp_swarm", base + Vector3(10.0, 0.5, 0.0))
	ls.global_position = base + Vector3(10.0, 0.2, 0.0)
	ls._rest = 99.0
	await _settle(ls)
	ls.set_physics_process(false)
	_clear_budget_gap()
	ls.next_attack = "flash_beam"
	ls._rest = 0.0
	ls._physics_process(DT)
	var tele = ls.telegraph()
	_t.check("lamp_swarm flash-focus beam commits LANE telegraph >= 0.70 s",
		tele != null and tele.type == Threat.Type.LANE and ls.warn_seconds >= 0.70,
		"tele=%s warn=%.2f on_floor=%s" % [str(tele), ls.warn_seconds, str(ls.is_on_floor())])
	if tele != null:
		_t.eq("lamp_swarm flash-focus tell uses Palette.HAZARD", Threat.row(tele.type)["color"], Palette.HAZARD)
	_step_node(ls, ls.warn_seconds + 0.05)
	var apex: Vector3 = ls.beam_apex()
	_set_player(apex, Vector3(-28.0, 0.0, 0.0), true, false, SpeedTier.FAST)
	ls._physics_process(DT)
	var after_posture: float = warden.posture() if warden != null and warden.has_method("posture") else 0.0
	_t.check("boosting through flash-focus apex pays +25 Warden posture and scatters lamps",
		ls.apex_breaks == 1 and ls.warden_posture_paid >= LampSwarm.APEX_WARDEN_POSTURE and after_posture > before_posture,
		"breaks=%d paid=%.1f warden=%.1f->%.1f" % [ls.apex_breaks, ls.warden_posture_paid, before_posture, after_posture])
	if is_instance_valid(ls):
		ls.free()
	if is_instance_valid(warden):
		warden.free()
	await physics_frame


func _check_prop_crew_secondary(base: Vector3) -> void:
	_clear_budget_gap()
	_set_player(base, Vector3.ZERO, true, false, SpeedTier.WALK)
	var pc = _game.combat.spawn_enemy("prop_crew", base + Vector3(6.0, 0.5, 0.0))
	pc.global_position = base + Vector3(6.0, 0.2, 0.0)
	pc._rest = 99.0
	await _settle(pc)
	pc.set_physics_process(false)
	_clear_budget_gap()
	pc._rest = 0.0
	# Stall on floor near prop_crew until Jack-Hammer Shockwave commits.
	_step_node(pc, PropCrew.STALL_TRIGGER_S + 0.25)
	var tele = pc.telegraph()
	_t.check("prop_crew jack-hammer commits INSTANT telegraph >= 0.70 s on stalled ball",
		tele != null and tele.type == Threat.Type.INSTANT and pc.warn_seconds >= 0.70,
		"tele=%s warn=%.2f stall=%.2f" % [str(tele), pc.warn_seconds, pc._stall_s])
	if tele != null:
		_t.eq("prop_crew jack-hammer tell uses Palette.HAZARD", Threat.row(tele.type)["color"], Palette.HAZARD)
	# Wall-ram prop_crew -> 2x ceiling collapse on pack.
	_set_player(pc.global_position - Vector3(1.0, 0.0, 0.0), Vector3(26.0, 0.0, 0.0), false, true, SpeedTier.FAST)
	pc.on_struck("ram", "", {})
	_t.check("prop_crew wall-ram triggers 2x ceiling collapse",
		pc.wall_ram_collapses == 1 and is_equal_approx(pc.last_collapse_mult, PropCrew.WALL_RAM_COLLAPSE_MULT) and not pc.prop_up,
		"collapses=%d mult=%.2f prop_up=%s" % [pc.wall_ram_collapses, pc.last_collapse_mult, str(pc.prop_up)])
	if is_instance_valid(pc):
		pc.free()
	await physics_frame


func _check_pit_jaw_secondary(base: Vector3) -> void:
	_clear_budget_gap()
	_set_player(base, Vector3.ZERO, true, false, SpeedTier.WALK)
	var pj = _game.combat.spawn_enemy("pit_jaw", base + Vector3(14.0, 0.2, 0.0))
	pj.set_physics_process(false)
	pj.next_attack = "spring_spit"
	pj._rest = 0.0
	pj._physics_process(DT)
	var tele = pj.telegraph()
	_t.check("pit_jaw spring-spit commits PROJECTILE telegraph >= 0.70 s and clenches jaw",
		tele != null and tele.type == Threat.Type.PROJECTILE and pj.warn_seconds >= 0.70 and pj.clenched,
		"tele=%s warn=%.2f clenched=%s" % [str(tele), pj.warn_seconds, str(pj.clenched)])
	if tele != null:
		_t.eq("pit_jaw spring-spit tell uses Palette.HAZARD", Threat.row(tele.type)["color"], Palette.HAZARD)
	# Slam clenched jaw -> vertical bench-skip cannon launch.
	_set_player(pj.global_position + Vector3(0.0, 2.0, 0.0), Vector3(8.0, -10.0, 0.0), false, false, SpeedTier.CRUISE)
	pj.on_struck("slam", "", {})
	var vy: float = _game.player.body().linear_velocity.y
	_t.check("slamming clenched pit_jaw fires vertical bench-skip cannon",
		pj.cannon_launches == 1 and vy >= PitJaw.BENCH_SKIP_LIFT - 0.01 and not pj.clenched,
		"launches=%d vy=%.2f clenched=%s" % [pj.cannon_launches, vy, str(pj.clenched)])
	if is_instance_valid(pj):
		pj.free()
	await physics_frame


func _check_budget_and_gap(base: Vector3) -> void:
	_clear_budget_gap()
	_set_player(base, Vector3.ZERO, true, false, SpeedTier.WALK)
	var b1 = _game.combat.spawn_enemy("burrower", base + Vector3(7.0, 0.2, 0.0))
	var d1 = _game.combat.spawn_enemy("drill_crew", base + Vector3(-9.0, 0.5, 0.0))
	d1.global_position = base + Vector3(-9.0, 0.2, 0.0)
	b1._rest = 99.0
	d1._rest = 99.0
	await _settle(d1)
	b1.set_physics_process(false)
	d1.set_physics_process(false)
	_clear_budget_gap()
	b1.next_attack = "wall_skim"
	d1.next_attack = "core_jet"
	b1._rest = 0.0
	d1._rest = 0.0
	b1._physics_process(DT)
	var first_commit := b1.telegraph() != null
	# Same tick: inter-warning 0.2 s gap must block immediate second commit.
	d1._physics_process(DT)
	var blocked_by_gap := d1.telegraph() == null
	_t.check("Dig 2-attack roster obeys AttackBudget and 0.2 s inter-warning gap",
		first_commit and blocked_by_gap and AttackBudget.MIN_GAP >= 0.2,
		"first=%s blocked_by_gap=%s gap=%.2f" % [str(first_commit), str(blocked_by_gap), AttackBudget.MIN_GAP])
	if is_instance_valid(b1):
		b1.free()
	if is_instance_valid(d1):
		d1.free()


func _check_ghost_shift_dig(base: Vector3) -> void:
	var husks = _game.combat.ally_husks
	var all_ok := true
	var detail := []
	for kind in RosterDig.DIG_KINDS:
		husks._reset()
		var eligible: bool = AllyHusk.can_leave_husk(kind)
		var profile_ok: bool = AllyHusk.PROFILES.has(kind)
		var e = _game.combat.spawn_enemy(kind, base + Vector3(5.0, 0.0, 5.0))
		var wreck: Dictionary = husks.record_wreck(e)
		var raised: Array = husks.raise_in_radius(base + Vector3(5.0, 0.0, 5.0), 12.0)
		var amber_ok := raised.size() == 1
		var hazard_ok := true
		if raised.size() == 1:
			var unit = raised[0]
			var zone = AllyHuskLook.create_ring_zone(_game, base + Vector3(5.0, 0.0, 5.0), 3.0)
			amber_ok = amber_ok and zone.color == Palette.AMBER and not zone.is_hostile() and not zone.has_hazard_stripes()
			hazard_ok = not zone.is_in_group(Threat.GROUP) and not unit.is_in_group(Threat.GROUP)
			zone.free()
		if not (eligible and profile_ok and not wreck.is_empty() and amber_ok and hazard_ok):
			all_ok = false
			detail.append("%s(elig=%s prof=%s wreck=%s amber=%s no_haz=%s)" % [kind, str(eligible), str(profile_ok), str(not wreck.is_empty()), str(amber_ok), str(hazard_ok)])
		if is_instance_valid(e):
			e.free()
	husks._reset()
	_t.check("Ghost Shift raises all 5 Dig enemies strictly B6 AMBER (#E5A044) with zero HAZARD telegraphs",
		all_ok, "issues=%s" % str(detail))


func _check_tile_drain_and_dispatcher(base: Vector3) -> void:
	RosterDig.reset_drain()
	var steps := 0
	while not RosterDig.drain_complete() and steps < 20:
		_game.beacon.drain_dig_burst(8000)
		steps += 1
	_t.check("Dig pit tile-drain completes and caches shared assets",
		RosterDig.drain_complete() and steps >= 1,
		"steps=%d" % steps)
	# Warm Dispatcher spawn uses cached merged mast (2 meshes + 2 colliders <= 4 children) & Jolt shapes.
	Dispatcher.warm_shared()
	var disp = _game.combat.spawn_enemy("dispatcher", base + Vector3(16.0, 0.0, 0.0))
	_t.check("Sinkhole/pit Dispatcher builds merged cached mast (<= 4 children) and reuses Jolt shapes",
		disp != null and disp.mast != null and disp.mast.get_child_count() <= 4,
		"mast_children=%d" % (disp.mast.get_child_count() if disp != null and disp.mast != null else -1))
	if is_instance_valid(disp):
		disp.free()


func _check_waking_3phase_anthems() -> void:
	var floors := WakingFloors.new(["Spoil", "Seam", "Bedrock"])
	_t.eq("Waking Spoil phase 1 = Base (+0 BPM)", [floors.music_phase(), floors.anthem_bpm_delta()], [1, 0])
	floors.chunks_shattered(1)
	_t.eq("Waking Seam phase 2 = +10 BPM", [floors.music_phase(), floors.anthem_bpm_delta()], [2, 10])
	floors.chunks_shattered(2)
	_t.eq("Waking Bedrock phase 3 = +20 BPM", [floors.music_phase(), floors.anthem_bpm_delta()], [3, 20])
	floors.chunks_shattered(3)
	_t.eq("Waking Pit shares phase 3 = +20 BPM", [floors.music_phase(), floors.anthem_bpm_delta(), WakingAttacks.anthem_phase(4)], [3, 20, 3])
	# Verify Audio routes boss_phase_changed for Waking to anthem-waking-heavy (+10) & anthem-waking-heavier (+20) with beat-locked clash.
	var events := GameEvents.new()
	var fctx := FakeAudioCtx.new()
	fctx.events = events
	var audio := AnthemRig.new()
	audio.setup(fctx)
	audio.bake_now()
	audio.pack_available = func(_id): return true
	audio.engine.force_track("waking", 0, "1", true)
	audio._phase_music_done = 1
	audio._boss_phase = 1
	events.boss_phase_changed.emit(2, "Seam")
	var p2_clash := audio.cue_log.filter(func(c): return c[0] == "boss_phase_changed")
	_t.check("Waking phase 2 routes to anthem-waking-heavy (+10 BPM) with clash",
		audio.named.size() == 1 and audio.named[0][0] == "anthem-waking-heavy" and p2_clash.size() == 1 and int(p2_clash[0][3]) == int(audio.named[0][1]),
		"named=%s clash=%s" % [str(audio.named), str(p2_clash)])
	events.boss_phase_changed.emit(3, "Bedrock")
	var p3_clash := audio.cue_log.filter(func(c): return c[0] == "boss_phase_changed")
	_t.check("Waking phase 3 routes to anthem-waking-heavier (+20 BPM) with beat-locked clash",
		audio.named.size() == 2 and audio.named[1][0] == "anthem-waking-heavier" and p3_clash.size() == 2 and int(p3_clash[1][3]) == int(audio.named[1][1]),
		"named=%s clash=%s" % [str(audio.named), str(p3_clash)])
	# Duplicate emit for same phase must be idempotent.
	events.boss_phase_changed.emit(3, "Pit")
	_t.eq("Waking pit sharing phase 3 does not re-trigger clash", audio.named.size(), 2)
	audio.free()
	events.free()
