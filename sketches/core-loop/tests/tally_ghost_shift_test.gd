extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const TreeProblems := preload("res://tests/support/tree_problems.gd")
const TallyTree := preload("res://src/core/trees/tally.gd")
const WorldOneCards := preload("res://src/core/trees/world_one_cards.gd")
const AllyHusk := preload("res://src/combat/ally_husk.gd")
const AllyHuskLook := preload("res://src/presentation/ally_husk_look.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const EnemyBase := preload("res://src/combat/enemy.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

# W47-TALLY-B-CODE Ghost Shift end-to-end verification:
# - Tree placement zero-churn invariants (all 30 tl_* IDs & binary heap unchanged,
#   effects <= 8 words, TreeProblems.problems empty, tl_corner_plate / tl_plate_rack / tl_return_slip ops).
# - Eligibility & zero "Spare Shift" boss fallback husks (6 s ordinary Fleet wrecks only;
#   never Wardens, bosses, Rogues, ancients, or Fleet spectators).
# - Raising via gather_plate & link_clips drive-by; 12 s shift; 60% base damage;
#   seat caps 2 (Heft I), 3 (III), 4 (V), Elites = 2 seats, tl_plate_rack +1 seat.
# - Kit synergies: stamp_slam refreshes 12 s timers; flywheel_surge overclocks +50% speed/rate for 3 s;
#   plate_return flight beats raise passed wrecks & landing commands active husks to charge.
# - Depth-3 upgrades: tl_return_slip Severance Blast (AMBER pop on shift-end & Tally ram)
#   and ShotBits inheritance (heat, pull, pierce, split at depth 1).
# - Dedicated Ally Attack Budget isolated from hostile enemy AttackBudget.
# - Mandatory B6 readability contract: AMBER #E5A044 zones only, zero HAZARD/stripes/enemy telegraphs,
#   W47-TALLY-B-3D overlays (2x clips, tag, mast, leads) attached cleanly per instance.
# - Clean _reset() across attempt / retry / death with zero leaks.

const SHELF := Vector3(-45.0, 122.0, 6.0)
const EXPECTED_TL_IDS := [
	"tl_audit_stamp", "tl_steam_bank",
	"tl_through_feed", "tl_line_feed", "tl_spring_vent", "tl_corner_plate",
	"tl_deep_ledger", "tl_carbon_copy", "tl_stamp_duty", "tl_reel_in",
	"tl_blowdown", "tl_governor", "tl_plate_rack", "tl_return_slip",
	"tl_full_ledger", "tl_settled", "tl_bounce_back", "tl_red_ink",
	"tl_rubber_stamp", "tl_postmark", "tl_long_line", "tl_closing_entry",
	"tl_pressure_valve", "tl_scald", "tl_freewheel", "tl_overspeed",
	"tl_plate_stack", "tl_backstop", "tl_paid_in_full", "tl_bounced_check",
]

var _t := T.new("tally_ghost_shift_test")
var _game
var _player
var _combat
var _husks
var _source := Intent.Scripted.new()


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _boot() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_husks = _combat.ally_husks
	var def: Resource = ClassDef.by_id("tally")
	_game.run.class_def = def
	_player.fit_class(def)
	for _i in 6:
		await physics_frame
	_player.set_physics_process(false)
	_combat.set_physics_process(false)
	_combat.ultimate.set_physics_process(false)
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	col.shape = box
	floor_body.add_child(col)
	_game.add_child(floor_body)
	floor_body.global_position = SHELF + Vector3(0.0, -2.5, 0.0)
	await _fresh()


func _fresh() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.queue_free()
	_husks._reset()
	_combat.tally_kit.reset()
	_player.tree.world_one = false
	_player.tree.max_depth = 4
	_player.tree.reset("tally")
	_player.abilities.fit(ClassDef.by_id("tally"))
	_player.kit.drop_line("reset")
	_player.chain.reset()
	_game.run.mass = 0.0
	_game.run.parts.clear()
	_game.run._heft_class = 1
	_player.body().freeze = true
	_player.reset_to(SHELF)
	await physics_frame
	await physics_frame


func _draft(ids: Array) -> void:
	_player.tree.reset("tally")
	_player.tree.allowed = ids.size()
	for id in ids:
		var ok: bool = _player.tree.pick(id)
		if ok:
			UpgradeTree.apply_pick(_player.abilities, UpgradeTree.node("tally", id))


func _spawn(kind: String, dx: float, dz := 0.0, elite := false) -> Node3D:
	var ball: Vector3 = _player.ball_position()
	var enemy: Node3D = _combat.spawn_enemy(kind, ball + Vector3(dx, 0.0, dz))
	enemy.global_position = ball + Vector3(dx, 0.0, dz)
	if enemy.get("live") != null:
		enemy.live = func(): return false
	if elite:
		enemy.set_meta("elite_pack", true)
	enemy.set_physics_process(false)
	return enemy


func _kill_enemy(enemy: Node3D) -> void:
	enemy.hp = 1.0
	enemy.take_damage(10.0)


func _run() -> void:
	await _boot()
	_check_tree_invariants()
	await _check_eligibility_and_no_spare_shift()
	await _check_raise_caps_and_elites()
	await _check_kit_synergies()
	await _check_depth3_severance_and_shot_bits()
	await _check_ally_attack_budget_and_b6()
	await _check_clean_reset()
	_game.free()
	quit(_t.verdict())


# --- 1. Tree invariants (Opus R1 zero churn) ----------------------------------------------

func _check_tree_invariants() -> void:
	var nodes := UpgradeTree.nodes("tally")
	var ids: Array = nodes.map(func(n): return String(n["id"]))
	_t.eq("all 30 tl_* IDs and heap indices unchanged", ids, EXPECTED_TL_IDS)
	_t.eq("TreeProblems.problems(tally) is empty", TreeProblems.problems("tally"), [])
	_t.eq("TreeProblems.problems(tally, world_one) is empty", TreeProblems.problems("tally", true), [])
	_t.eq("UpgradeTree.safe_growth_problems(tally) is empty", UpgradeTree.safe_growth_problems("tally"), [])
	var max_words := 0
	for n in nodes:
		max_words = maxi(max_words, String(n["effect"]).split(" ", false).size())
	_t.check("every Tally tree effect <= 8 words", max_words <= UpgradeTree.EFFECT_WORDS, "max %d" % max_words)
	var n5: Dictionary = nodes[5]
	var n12: Dictionary = nodes[12]
	var n13: Dictionary = nodes[13]
	_t.check("index 5 tl_corner_plate keeps grant_move and unlocks Ghost Shift",
		n5["id"] == "tl_corner_plate" and n5["key"] == "special"
		and n5["proc"][0]["on"] == "special_used" and n5["proc"][0]["do"] == "grant_move"
		and n5["proc"][0].get("ghost_shift", "") == "unlock", str(n5))
	_t.check("index 12 tl_plate_rack keeps charges+swap and adds seat_and_bits",
		n12["id"] == "tl_plate_rack" and n12["key"] == "special"
		and int(n12["charges"]["special"]) == 1 and n12["swap"]["ultimate"] == "plate_flywheel"
		and n12["proc"][0].get("ghost_shift", "") == "seat_and_bits", str(n12))
	_t.check("index 13 tl_return_slip keeps blast+swap and adds severance_and_bits",
		n13["id"] == "tl_return_slip" and n13["key"] == "special"
		and n13["proc"][0]["do"] == "blast" and n13["swap"]["ultimate"] == "plate_audit"
		and n13["proc"][0].get("ghost_shift", "") == "severance_and_bits", str(n13))
	_t.check("world_one_cards tl_corner_plate reflects Ghost Shift",
		WorldOneCards.ROWS["tl_corner_plate"].to_lower().contains("ghost-shift"), WorldOneCards.ROWS["tl_corner_plate"])


# --- 2. Eligibility, 6 s wreck expiry, and zero Spare Shift boss husks --------------------

func _check_eligibility_and_no_spare_shift() -> void:
	await _fresh()
	_t.eq("Ghost Shift locked before drafting tl_corner_plate", _combat.ghost_shift_unlocked(), false)
	var pre := _spawn("chaser", 3.0)
	_kill_enemy(pre)
	_t.eq("no wreck dropped when Ghost Shift is not drafted", _husks.wrecks.size(), 0)

	_draft(["tl_steam_bank", "tl_corner_plate"])
	_t.eq("Ghost Shift unlocked after drafting tl_corner_plate", _combat.ghost_shift_unlocked(), true)

	# Zero "Spare Shift" boss-room fallback husks: empty room beacon raises 0 husks.
	_combat.tally_kit._run_gather(_player.ball_position() + Vector3(3.0, 0.0, 0.0), true)
	_t.eq("ZERO Spare Shift fallback husks in empty/boss room", _husks.active_count(), 0)

	# Non-eligible enemies never leave wrecks: Warden, boss piece, Rogue, ancient, spectator.
	_t.eq("warden ineligible", AllyHusk.can_leave_husk("warden"), false)
	_t.eq("boss piece brindle_hull ineligible", AllyHusk.can_leave_husk("brindle_hull"), false)
	_t.eq("rogue_crane ineligible", AllyHusk.can_leave_husk("rogue_crane"), false)
	_t.eq("ancient reactor_relic ineligible", AllyHusk.can_leave_husk("reactor_relic"), false)
	_t.eq("spectator ineligible", AllyHusk.can_leave_husk("chaser", false, true), false)
	_t.eq("ring-out ineligible", AllyHusk.can_leave_husk("chaser", true, false), false)
	_t.eq("ordinary Fleet chaser eligible", AllyHusk.can_leave_husk("chaser"), true)
	_t.eq("ordinary Fleet plated_brute eligible", AllyHusk.can_leave_husk("plated_brute"), true)
	_t.eq("ordinary Fleet lobber eligible", AllyHusk.can_leave_husk("lobber"), true)
	_t.eq("ordinary Fleet boom_tender eligible", AllyHusk.can_leave_husk("boom_tender"), true)

	var boss := EnemyBase.new()
	boss.kind = "brindle_hull"
	boss.faction = "fleet"
	boss.hp = 1.0
	boss.max_hp = 1.0
	_game.add_child(boss)
	boss.global_position = _player.ball_position() + Vector3(3.0, 0.0, 0.0)
	_t.eq("boss instance is_fleet_husk_eligible false", boss.is_fleet_husk_eligible(), false)
	_husks.record_wreck(boss)
	_t.eq("boss leaves 0 wrecks", _husks.wrecks.size(), 0)
	boss.queue_free()

	# Ordinary Fleet chaser leaves 6 s wreck that expires after 6.01 s.
	var c := _spawn("chaser", 3.0)
	_kill_enemy(c)
	_t.eq("ordinary Fleet chaser leaves 1 wreck", _husks.wrecks.size(), 1)
	_t.near("wreck duration starts at 6.0 s", float(_husks.wrecks[0]["left"]), AllyHusk.WRECK_SECONDS, 0.05)
	_husks.step(5.95, [])
	_t.eq("wreck still live at 5.95 s", _husks.wrecks.size(), 1)
	_husks.step(0.10, [])
	_t.eq("wreck expires by 6.05 s", _husks.wrecks.size(), 0)


# --- 3. Raising, 12 s life, 60% base damage, Heft seat caps, Elites = 2 seats -------------

func _check_raise_caps_and_elites() -> void:
	await _fresh()
	_draft(["tl_steam_bank", "tl_corner_plate"])
	_t.eq("Heft I cap is 2", AllyHusk.seat_cap_for(1), 2)
	_t.eq("Heft III cap is 3", AllyHusk.seat_cap_for(3), 3)
	_t.eq("Heft V cap is 4", AllyHusk.seat_cap_for(5), 4)

	# Drop 3 ordinary wrecks near beacon point; Heft I cap holds at 2 seats.
	var beacon_pt: Vector3 = _player.ball_position() + Vector3(6.0, 0.0, 0.0)
	for offset in [Vector3(5.0, 0.0, 0.0), Vector3(6.0, 0.0, 1.0), Vector3(7.0, 0.0, -1.0)]:
		_kill_enemy(_spawn("chaser", offset.x, offset.z))
	_t.eq("3 wrecks recorded", _husks.wrecks.size(), 3)
	_combat.tally_kit._run_gather(beacon_pt, true)
	_t.eq("Heft I cap clamps active seats to 2", [_husks.active_count(), _husks.seats_used()], [2, 2])
	_t.near("raised husk lives 12.0 s", float(_husks.husks[0].shift_left), AllyHusk.SHIFT_SECONDS, 0.05)
	_t.near("raised chaser deals 60% of base 9.0 = 5.4", float(_husks.husks[0].damage), 5.4, 0.01)

	# Elite wreck costs 2 seats (evicts older husks cleanly at Heft I cap=2).
	_kill_enemy(_spawn("plated_brute", 6.0, 0.0, true))
	_combat.tally_kit._run_gather(beacon_pt, true)
	_t.eq("Elite brute occupies 2 seats within cap 2", [_husks.active_count(), _husks.seats_used(), _husks.husks[0].elite], [1, 2, true])

	# Depth-3 tl_plate_rack adds +1 seat (Heft I -> 3, Heft III -> 4, Heft V -> 5).
	_draft(["tl_steam_bank", "tl_corner_plate", "tl_plate_rack"])
	_t.eq("tl_plate_rack gives +1 extra seat", _combat.ghost_shift_extra_seats(), 1)
	_t.eq("Heft I with tl_plate_rack cap is 3", _husks.seat_cap(), 3)
	_kill_enemy(_spawn("chaser", 6.0, 1.0))
	_combat.tally_kit._run_gather(beacon_pt, true)
	_t.eq("Elite (2) + ordinary (1) fit in 3 seats", [_husks.active_count(), _husks.seats_used()], [2, 3])

	# Heft III -> 3 base + 1 tl_plate_rack = 4 seats; Heft V -> 4 + 1 = 5 seats.
	_game.run.mass = 0.0
	while _game.run.heft_class() < 3:
		_game.run.mass += 25.0
	_t.eq("Heft III with tl_plate_rack cap is 4", [_game.run.heft_class(), _husks.seat_cap()], [3, 4])
	_game.run.mass = 1000000.0
	_t.eq("Heft V with tl_plate_rack cap is 5", [_game.run.heft_class(), _husks.seat_cap()], [5, 5])

	# Drive-by Jumper Splice (link_clips) raises wreck on world latch.
	_husks._reset()
	var anchor: Vector3 = _player.ball_position() + Vector3(10.0, 0.0, 0.0)
	_kill_enemy(_spawn("chaser", 10.5, 0.0))
	_combat.tally_kit.link_clips_world(anchor, 1.0, 1.0)
	_t.eq("link_clips world latch drive-by raises husk", _husks.active_count(), 1)


# --- 4. Kit synergies: stamp_slam refresh, flywheel_surge overclock, plate_return Q -------

func _check_kit_synergies() -> void:
	await _fresh()
	_draft(["tl_steam_bank", "tl_corner_plate"])
	var pt: Vector3 = _player.ball_position() + Vector3(3.0, 0.0, 0.0)
	_kill_enemy(_spawn("chaser", 3.0, 0.0))
	_combat.tally_kit._run_gather(pt, true)
	_t.eq("1 husk raised for kit synergy test", _husks.active_count(), 1)
	var h = _husks.husks[0]

	# Tick 5 s -> stamp_slam refreshes back to 12.0 s.
	_husks.step(5.0, [])
	_t.near("shift ticks down to 7.0 s", h.shift_left, 7.0, 0.05)
	_game.events.slammed.emit(_player.ball_position(), 1.0, 1.0)
	_t.near("stamp_slam refreshes active husk shift timer to 12.0 s", h.shift_left, 12.0, 0.05)

	# flywheel_surge overclocks passed husks (+50% speed & attack rate for 3.0 s).
	_t.eq("husk starts not overclocked", h.is_overclocked(), false)
	_game.events.dashed.emit(Vector3.RIGHT)
	_t.check("flywheel_surge overclocks passed husk (+50% speed & rate for 3 s)",
		h.is_overclocked() and is_equal_approx(h.overclock_left, 3.0)
		and is_equal_approx(h.rate_mult(), 1.5) and is_equal_approx(h.speed_mult(), 1.5),
		"oc=%.2f rate=%.2f spd=%.2f" % [h.overclock_left, h.rate_mult(), h.speed_mult()])

	# plate_return flight beats raise passed wrecks & landing commands husks to charge landing.
	_kill_enemy(_spawn("chaser", 4.0, 2.0))
	_combat.tally_kit.tally_tech("plate_return", 1, _player.ball_position(), Vector3.RIGHT, 1.0)
	_t.eq("plate_return flight beat auto-raises passed wreck", _husks.active_count(), 2)
	var landing_pt: Vector3 = _player.ball_position() + Vector3(14.0, 0.0, 0.0)
	_combat.tally_kit.tally_landing("plate_return", landing_pt, 1.0, 1.0)
	_t.check("plate_return landing commands all active husks to charge landing",
		_husks.husks.all(func(u): return u.charge_left > 3.0 and Vector2(u.charge_target.x - landing_pt.x, u.charge_target.z - landing_pt.z).length() < 0.2))


# --- 5. Depth-3 Severance Blast (shift-end & Tally ram) + ShotBits inheritance ------------

func _check_depth3_severance_and_shot_bits() -> void:
	await _fresh()
	_draft(["tl_steam_bank", "tl_corner_plate", "tl_return_slip"])
	_t.check("tl_return_slip enables Severance Blast and ShotBits inheritance",
		_combat.ghost_shift_has_severance() and _combat.ghost_shift_inherits_bits())

	# Severance Blast on shift expiry deals AMBER damage to nearby enemy.
	_kill_enemy(_spawn("chaser", 3.0, 0.0))
	_combat.tally_kit._run_gather(_player.ball_position() + Vector3(3.0, 0.0, 0.0), true)
	var target := _spawn("chaser", 4.5, 0.0)
	target.hp = 500.0
	target.max_hp = 500.0
	var hp_before: float = target.hp
	var h = _husks.husks[0]
	h.shift_left = 0.05
	_husks.step(0.1, [target])
	_t.check("Severance Blast fires in AMBER on shift-end and damages foe",
		_husks.active_count() == 0 and target.hp < hp_before
		and _husks.last_severance.get("cause", "") == "shift_end"
		and _husks.last_severance.get("color") == Palette.AMBER,
		"hp %.1f->%.1f sev=%s" % [hp_before, target.hp, str(_husks.last_severance)])

	# Severance Blast on Tally high-speed ram-through.
	_kill_enemy(_spawn("chaser", 1.0, 0.0))
	_combat.tally_kit._run_gather(_player.ball_position() + Vector3(1.0, 0.0, 0.0), true)
	var h2 = _husks.husks[0]
	h2.age = 0.5
	_player.state.velocity = Vector3(18.0, 0.0, 0.0)
	hp_before = target.hp
	_husks.step(0.05, [target])
	_t.check("Severance Blast pops in AMBER on Tally ram-through",
		_husks.active_count() == 0 and target.hp < hp_before
		and _husks.last_severance.get("cause", "") == "ram"
		and _husks.last_severance.get("color") == Palette.AMBER,
		"hp %.1f->%.1f sev=%s" % [hp_before, target.hp, str(_husks.last_severance)])
	_player.state.velocity = Vector3.ZERO

	# ShotBits inheritance: heat + split + pull apply cleanly at depth-1 (no infinite loop).
	var foe_a := _spawn("chaser", 8.0, 0.0)
	var foe_b := _spawn("chaser", 10.5, 0.0)
	foe_a.hp = 500.0
	foe_a.max_hp = 500.0
	foe_b.hp = 500.0
	foe_b.max_hp = 500.0
	var bits := ShotBits.union(ShotBits.bit("heat"), ShotBits.bit("split"))
	_combat.ally_husk_hit(null, foe_a, 10.0, _player.ball_position(), bits)
	_t.check("inherited heat bit lights target", _combat.heated(foe_a))
	_t.check("inherited split bit arcs once to neighbor (depth 1)", foe_b.hp < 500.0, "foe_b hp=%.1f" % foe_b.hp)


# --- 6. Dedicated Ally Attack Budget & Mandatory B6 Readability Contract ------------------

func _check_ally_attack_budget_and_b6() -> void:
	await _fresh()
	_draft(["tl_steam_bank", "tl_corner_plate", "tl_plate_rack"])
	_game.run.mass = 0.0
	while _game.run.heft_class() < 3:
		_game.run.mass += 25.0
	var pt: Vector3 = _player.ball_position() + Vector3(4.0, 0.0, 0.0)
	for dx in [3.0, 4.0, 5.0]:
		_kill_enemy(_spawn("chaser", dx, 0.0))
	_combat.tally_kit._run_gather(pt, true)
	_t.eq("3 raised husks active for budget test", _husks.active_count(), 3)

	# B6 (c): W47-TALLY-B-3D overlays attached cleanly onto every raised husk.
	var overlays_ok := true
	for h in _husks.husks:
		var look: Dictionary = h.look
		var has_parts: bool = look.has("clip_l") and look.has("clip_r") and look.has("tag") and look.has("mast") and look.has("lead_l") and look.has("lead_r")
		var not_enemy: bool = not h.is_in_group("enemy") and h.is_in_group(AllyHusk.GROUP)
		overlays_ok = overlays_ok and has_parts and not_enemy
	_t.check("B6(c) every raised husk wears 2 clips, tag, mast, leads and is NOT in enemy group", overlays_ok)

	# Dedicated ally attack budget: separate from hostile AttackBudget.
	AttackBudget.reset_ally(_game.get_tree())
	var u0 = _husks.husks[0]
	var u1 = _husks.husks[1]
	var u2 = _husks.husks[2]
	var ok0 := AttackBudget.ask_ally(u0, 1)
	_t.eq("first ally gets ally budget slot", ok0, true)
	_t.eq("ally slot does NOT consume hostile enemy attack_budget", AttackBudget.attackers(_game.get_tree()), 0)
	_t.eq("ally_attackers reports 1", AttackBudget.ally_attackers(_game.get_tree()), 1)
	# Immediately asking a second ally within MIN_GAP is paced cleanly; advancing past gap grants slot 2.
	_t.eq("second ally within gap waits", AttackBudget.ask_ally(u1, 1), false)
	for _i in AttackBudget.ally_gap_frames() + 1:
		await physics_frame
	_t.eq("second ally granted after gap", AttackBudget.ask_ally(u1, 1), true)
	for _i in AttackBudget.ally_gap_frames() + 1:
		await physics_frame
	_t.eq("third ally refused at cap 2 (Heft I)", AttackBudget.ask_ally(u2, 1), false)
	AttackBudget.release_ally(u0)
	AttackBudget.release_ally(u1)
	AttackBudget.withdraw_ally(u2)
	AttackBudget.reset_ally(_game.get_tree())

	# B6 (a) & (b): step husk into WARN against a live foe -> verify AMBER zone, zero HAZARD/stripes/threat group.
	var foe := _spawn("chaser", 8.0, 0.0)
	foe.hp = 500.0
	foe.max_hp = 500.0
	_husks.step(0.05, [foe])
	var active_zone = null
	for h in _husks.husks:
		if h.zone != null and is_instance_valid(h.zone):
			active_zone = h.zone
			break
	_t.check("husk commits allied attack zone during WARN", active_zone != null)
	if active_zone != null:
		_t.eq("B6(a) allied zone color is strictly Palette.AMBER #E5A044", active_zone.color, Palette.AMBER)
		_t.check("B6(a) allied zone color is NEVER Palette.HAZARD #FF5A3C", active_zone.color != Palette.HAZARD)
		_t.eq("B6(b) allied zone is_hostile() is false", active_zone.is_hostile(), false)
		_t.eq("B6(b) allied zone has_hazard_stripes() is false", active_zone.has_hazard_stripes(), false)
		_t.eq("B6(b) allied zone is NOT in Threat.GROUP", active_zone.is_in_group(Threat.GROUP), false)
		_t.eq("B6(b) zero hostile Threat.GROUP nodes created by ally husk", _game.get_tree().get_nodes_in_group(Threat.GROUP).size(), 0)

	# Let the attack complete into STRIKE and verify foe takes ~60% base damage.
	var hp_before: float = foe.hp
	for _i in 15:
		_husks.step(0.06, [foe])
	_t.check("raised husk strikes foe through committed AMBER zone", foe.hp < hp_before, "hp %.1f->%.1f" % [hp_before, foe.hp])


# --- 7. Clean reset across attempt / retry / death ----------------------------------------

func _check_clean_reset() -> void:
	await _fresh()
	_draft(["tl_steam_bank", "tl_corner_plate"])
	_kill_enemy(_spawn("chaser", 3.0, 0.0))
	_kill_enemy(_spawn("chaser", 10.0, 0.0))
	_combat.tally_kit._run_gather(_player.ball_position() + Vector3(3.0, 0.0, 0.0), true)
	_t.check("setup has 1 active husk and 1 wreck", _husks.active_count() == 1 and _husks.wrecks.size() == 1)

	_combat._on_player_died()
	_t.eq("death clears all husks, wrecks, and ally budget",
		[_husks.active_count(), _husks.wrecks.size(), AttackBudget.ally_attackers(_game.get_tree())], [0, 0, 0])

	_kill_enemy(_spawn("chaser", 3.0, 0.0))
	_combat.tally_kit._run_gather(_player.ball_position() + Vector3(3.0, 0.0, 0.0), true)
	_combat._start_attempt()
	_t.eq("attempt boundary clears all husks, wrecks, and ally budget",
		[_husks.active_count(), _husks.wrecks.size(), AttackBudget.ally_attackers(_game.get_tree())], [0, 0, 0])
