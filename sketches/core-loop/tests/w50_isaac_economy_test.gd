extends SceneTree

# W50-ISAAC-ECONOMY comprehensive verification suite:
# 1. RoR2 Scrapper + Part Press (3D Printer) + Tri-Terminal multi-choice bay shelves
# 2. RoR2 Challenge Stake stacking (bounded cap, +1 Warden roll/stack, zero HP inflation) + W2/W3 Quick Breaks
# 3. 4-Element Chemistry ("heat": Steam Cloud, Flash Melt, heat+frost, heat+arc)
# 4. 2 new physical F-key Actives (slag_mortar, magnet_sling; ActiveDefs.ROWS 6 -> 8)
# 5. 3 new Isaac Consumables (scrap_dice, duplicator_spool, overload_fuse; 6 -> 9) + Trade Counter contracts
# 6. 4th SPIL-9 Companion family (SALVAGE_MAGNET: cog_scoop & cartridge_caddy)
# Plus planted negative controls for every bound and anti-duping guard.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const Shop := preload("res://src/build/shop.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")
const RunClock := preload("res://src/build/run_clock.gd")
const Elements := preload("res://src/build/elements.gd")
const ElementField := preload("res://src/build/element_field.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const Consumables := preload("res://src/build/consumables.gd")
const TradePockets := preload("res://src/world/trade_pockets.gd")
const Companion := preload("res://src/core/companion.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const Parts := preload("res://src/build/parts.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("w50_isaac_economy_test")
var _game
var _combat
var _player
var _build
var _source := Intent.Scripted.new()


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _sim(ticks: int) -> void:
	for _i in ticks:
		await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1) # Rivet
	await _sim(6)
	_combat = _game.ctx.spawner
	_build = _game.ctx.build

	_check_scrapper_press_and_tri_terminal()
	_check_challenge_stakes_and_quick_breaks()
	await _check_four_element_chemistry()
	await _check_new_actives()
	await _check_isaac_consumables_and_trade_contracts()
	await _check_salvage_magnet_companion()

	Consumables.reset_for_tests()
	_game.free()
	quit(_t.verdict())


# ---- 1. Scrapper + Part Press + Tri-Terminal ------------------------------------------

func _check_scrapper_press_and_tri_terminal() -> void:
	var run = _game.ctx.run
	var shop: Shop = _build.shop
	Fabricators.reset_ingots(run)
	run.parts.clear()

	# Planted negative control: empty inventory & welded/relic parts cannot be scrapped or pressed.
	var empty_scrap := Fabricators.scrap_part(run, "hot_rivets", _build)
	var empty_press := Fabricators.press_part(run, "hot_rivets", null, _build)
	_t.check("planted: empty scrapper refuses cleanly without crash", not bool(empty_scrap["ok"]) and empty_scrap["reason"] == "empty")
	_t.check("planted: empty press refuses cleanly without fuel", not bool(empty_press["ok"]) and empty_press["reason"] == "no_fuel")

	run.add_part("cross_split", "test") # pattern part (welded)
	run.add_part("spare_frame", "test") # relic
	var welded_scrap := Fabricators.scrap_part(run, "cross_split", _build)
	var relic_scrap := Fabricators.scrap_part(run, "spare_frame", _build)
	_t.check("planted: welded pattern part and relic refuse scrapping",
		not bool(welded_scrap["ok"]) and welded_scrap["reason"] == "welded"
		and not bool(relic_scrap["ok"]) and relic_scrap["reason"] == "welded"
		and Fabricators.ingot_count(run, 1) == 0 and Fabricators.ingot_count(run, 2) == 0 and Fabricators.ingot_count(run, 3) == 0)

	# Scrap an ordinary tier-1 part into a Common Scrap Ingot, then press a guaranteed duplicate.
	run.add_part("hot_rivets", "test")
	run.add_part("light_frame", "test")
	var t1 := Fabricators.tier_of("light_frame")
	var scrapped := Fabricators.scrap_part(run, "light_frame", _build)
	_t.check("scrapper removes ordinary part and mints rarity-matched ingot",
		bool(scrapped["ok"]) and not run.parts.has("light_frame")
		and int(scrapped["tier"]) == t1 and Fabricators.ingot_count(run, t1) == 1)

	# Press using matching-tier ingot first.
	var hr_before: int = run.parts.count("hot_rivets")
	var pressed_ingot := Fabricators.press_part(run, "hot_rivets", null, _build)
	_t.check("part press spends matching-tier ingot first for guaranteed duplicate stack",
		bool(pressed_ingot["ok"]) and pressed_ingot["paid_kind"] == "ingot"
		and Fabricators.ingot_count(run, t1) == 0 and run.parts.count("hot_rivets") == hr_before + 1)

	# Press fallback: sacrifices a random held same-tier ordinary part (never target itself).
	run.add_part("light_frame", "test")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pressed_part := Fabricators.press_part(run, "hot_rivets", rng, _build)
	_t.check("part press falls back to held same-tier ordinary part when 0 ingots held",
		bool(pressed_part["ok"]) and pressed_part["paid_kind"] == "part"
		and pressed_part["sacrificed"] == "light_frame" and not run.parts.has("light_frame")
		and run.parts.count("hot_rivets") == hr_before + 2)

	# Planted negative control: anti-duping refuses self-sacrifice when only target copies remain.
	var no_self_dupe := Fabricators.press_part(run, "hot_rivets", rng, _build)
	_t.check("planted: part press refuses self-sacrifice or capped stack (anti-dupe)",
		not bool(no_self_dupe["ok"]) and no_self_dupe["reason"] in ["no_fuel", "capped"])

	# Save safety: ingots doc round-trip & malformed doc rejection.
	run.add_part("light_frame", "test")
	Fabricators.scrap_part(run, "light_frame", _build)
	var doc := Fabricators.ingots_to_doc(run)
	_t.check("planted: malformed ingot doc is rejected atomically",
		not Fabricators.ingots_from_doc(run, {"1": -2, "2": 0, "3": 0}) and Fabricators.ingot_count(run, t1) == 1)
	Fabricators.reset_ingots(run)
	_t.check("ingot doc round-trip restores counts", Fabricators.ingots_from_doc(run, doc) and Fabricators.ingot_count(run, t1) == 1)

	# World Part Press station node + Bay Tri-Terminal multi-choice shelf.
	var press_station: Dictionary = _build.fabricators.add_press_at(_player.ball_position() + Vector3(6.0, 0.0, 0.0), Vector3.FORWARD, "light_frame")
	var use_res: Dictionary = _build.fabricators.use_press(press_station, run, rng, _build)
	_t.check("world part press node mints target and increments uses",
		bool(use_res["ok"]) and int(press_station["uses"]) == 1 and run.parts.has("light_frame"))

	run.add_cogs(500)
	shop.enter()
	var tri := shop.tri_terminal_offers()
	_t.check("tri-terminal offers 3 choices while keeping SHELF_SIZE == 3",
		tri.size() == Shop.TRI_TERMINAL_SIZE and shop.shelf_offers().size() == Shop.SHELF_SIZE)
	var buy_tri := shop.buy_tri_terminal(1)
	var buy_tri_again := shop.buy_tri_terminal(0)
	_t.check("tri-terminal buys 1 choice and locks the other 2",
		bool(buy_tri["ok"]) and shop.tri_terminal_closed and not bool(buy_tri_again["ok"]) and buy_tri_again["reason"] == Shop.TRI_CLOSED)
	shop.rewind_stage()
	_t.check("shop rewind restores tri-terminal open state", not shop.tri_terminal_closed and shop.tri_terminal_offers().size() == 3)
	shop.leave()


# ---- 2. Challenge Stake Stacking + W2/W3 Quick Breaks ---------------------------------

func _check_challenge_stakes_and_quick_breaks() -> void:
	var run = _game.ctx.run
	StakeDevices.reset_challenge_stakes(run)
	_t.eq("challenge stakes start at 0", StakeDevices.challenge_stacks(run), 0)

	var mods_per_stack: Array = []
	for i in StakeDevices.CHALLENGE_STAKE_CAP:
		var r := StakeDevices.stack_challenge(run, Vector3.ZERO)
		mods_per_stack.append(r)
	var cap_hit := StakeDevices.stack_challenge(run, Vector3.ZERO)
	_t.check("challenge stakes stack up to bounded cap with +1 Warden roll/stack and zero HP inflation",
		mods_per_stack.size() == StakeDevices.CHALLENGE_STAKE_CAP
		and mods_per_stack.all(func(m): return bool(m["ok"]) and is_equal_approx(float(m["hp_mult"]), 1.0))
		and StakeDevices.warden_gate_bonus_rolls(run) == StakeDevices.CHALLENGE_STAKE_CAP
		and float(StakeDevices.challenge_modifiers(run)["aggression_mult"]) > 1.0
		and int(StakeDevices.challenge_modifiers(run)["pack_pressure_bonus"]) == StakeDevices.CHALLENGE_STAKE_CAP)
	_t.check("planted: stacking past cap is refused cleanly",
		not bool(cap_hit["ok"]) and cap_hit["reason"] == "capped"
		and StakeDevices.challenge_stacks(run) == StakeDevices.CHALLENGE_STAKE_CAP
		and is_equal_approx(float(cap_hit["hp_mult"]), 1.0))

	# Advancing stage resets per-stage challenge stakes.
	var prev_stage: int = run.stage
	run.stage = prev_stage + 1
	_t.eq("stage transition clears prior stage's challenge stakes", StakeDevices.challenge_stacks(run), 0)
	run.stage = prev_stage

	# W2 & W3 Quick Breaks in RunClock.
	_t.eq("QUICK_BREAK_SECONDS filled for W1/W2/W3", RunClock.QUICK_BREAK_SECONDS, [30.0, 20.0, 28.0, 24.0, 26.0, 22.0])
	var clock := RunClock.new()
	for s in range(1, 7):
		var lim: float = RunClock.QUICK_BREAK_SECONDS[s - 1]
		clock.enter_stage(s)
		clock.stage_seconds = 10.0
		clock.warden_engaged()
		clock.stage_seconds = 10.0 + lim - 1.0
		clock.warden_broken()
		_t.check("stage %d quick break pays under %.0fs limit" % [s, lim], clock.quick_break())
		clock.enter_stage(s)
		clock.stage_seconds = 10.0
		clock.warden_engaged()
		clock.stage_seconds = 10.0 + lim + 1.0
		clock.warden_broken()
		_t.check("planted: stage %d slow break over %.0fs limit does not pay" % [s, lim], not clock.quick_break())
	clock.enter_stage(7)
	clock.warden_engaged()
	clock.warden_broken()
	_t.check("planted: out-of-range stage 7 never pays quick break", not clock.quick_break())


# ---- 3. 4-Element Chemistry ("heat") --------------------------------------------------

func _check_four_element_chemistry() -> void:
	_game.ctx.run.parts.clear()
	_build.recompute()
	_t.check("Elements supports 4 elements and passes full admission",
		Elements.all_elements().size() == 4 and "heat" in Elements.all_elements()
		and Elements.problems().is_empty() and Elements.all_problems().is_empty())
	_t.check("existing element rows and codex found text preserved verbatim",
		Elements.ROWS["frost:water"]["found"] == "Frost on water freezes into a road you can drive."
		and Elements.ROWS["kinetic:ice"]["found"] == "Frost, then a heavy hit: slamming ice shatters it into shrapnel.")
	_t.check("planted: heat+heat fuses nothing and unknown material does nothing",
		Elements.fuse("heat", "heat").is_empty() and Elements.resolve("heat", "lava").is_empty())

	var field: ElementField = _build.field
	field.clear()
	field.clear_providers()
	var base_at: Vector3 = _player.ball_position()
	var water_y: float = base_at.y - 0.8
	field.register_material("water", func(p: Vector3) -> Dictionary:
		if Vector2(p.x - base_at.x, p.z - base_at.z).length() <= 24.0:
			return {"surface_y": water_y}
		return {})

	# heat:water -> Steam Cloud (scald burst + thermal updraft lift, item_proc).
	var inside_e = _combat.spawn_enemy("chaser", base_at + Vector3(2.0, 0.0, 0.0))
	var outside_e = _combat.spawn_enemy("chaser", base_at + Vector3(14.0, 0.0, 0.0))
	inside_e.hp = 500.0
	inside_e.max_hp = 500.0
	outside_e.hp = 500.0
	outside_e.max_hp = 500.0
	inside_e.set_physics_process(false)
	outside_e.set_physics_process(false)
	await _sim(1)

	var steam_res := field.apply("heat", base_at, "test")
	field.step(0.05)
	_t.check("heat:water raises Steam Cloud with scald burst (inside hit, outside untouched) and updraft lift",
		steam_res.get("behaviour") == "steam_cloud" and steam_res.get("source") == "item_proc"
		and field.steam_cloud_count() == 1 and int(field.steam_clouds()[0]["lifts"]) >= 1
		and inside_e.hp < 500.0 and is_equal_approx(outside_e.hp, 500.0))

	# heat:ice -> Flash Melt (explosive steam-shatter nova, committed geometry, item_proc).
	var melt_spot := base_at + Vector3(0.0, 0.0, 10.0)
	field.apply("frost", melt_spot, "test")
	_t.check("frost freezes water into ice slab for Flash Melt test", field.slab_count() >= 1)
	var melt_in = _combat.spawn_enemy("chaser", melt_spot + Vector3(2.0, 0.0, 0.0))
	var melt_out = _combat.spawn_enemy("chaser", melt_spot + Vector3(11.0, 0.0, 0.0))
	melt_in.hp = 500.0
	melt_in.max_hp = 500.0
	melt_out.hp = 500.0
	melt_out.max_hp = 500.0
	melt_in.set_physics_process(false)
	melt_out.set_physics_process(false)
	var melt_res := field.apply("heat", melt_spot, "test")
	_t.check("heat:ice triggers Flash Melt nova (melts slab, hits inside, spares outside, item_proc)",
		melt_res.get("behaviour") == "flash_melt" and melt_res.get("source") == "item_proc"
		and int(melt_res.get("melted", 0)) >= 1 and melt_in.hp < 500.0 and is_equal_approx(melt_out.hp, 500.0))

	# SG2 fusions: heat+frost (burst) & heat+arc (sustained, elite <= 10%), both orders identical.
	var f_hf_a := Elements.fuse("heat", "frost")
	var f_hf_b := Elements.fuse("frost", "heat")
	var f_ha_a := Elements.fuse("heat", "arc")
	var f_ha_b := Elements.fuse("arc", "heat")
	_t.check("heat+frost and heat+arc fusions resolve identically in either order",
		not f_hf_a.is_empty() and f_hf_a == f_hf_b and f_hf_a["kind"] == "burst"
		and not f_ha_a.is_empty() and f_ha_a == f_ha_b and f_ha_a["kind"] == "sustained" and float(f_ha_a["elite_share"]) <= 0.1)

	var fuse_dummy = _combat.spawn_enemy("chaser", base_at + Vector3(-12.0, 0.0, 0.0))
	var fuse_elite = _combat.spawn_enemy("chaser", base_at + Vector3(-24.0, 0.0, 0.0))
	fuse_elite.set_meta("elite_pack", true)
	for d in [fuse_dummy, fuse_elite]:
		d.hp = 1000.0
		d.max_hp = 1000.0
		d.plating = 0.0
		d.set_physics_process(false)
	var ext_fused: Array = []
	var on_ext := func(r: Dictionary): ext_fused.append(r)
	field.extended_fused.connect(on_ext)
	field.touch(fuse_dummy, "arc")
	var ha_res := field.touch(fuse_dummy, "heat")
	field.touch(fuse_elite, "heat")
	var ha_elite_res := field.touch(fuse_elite, "arc")
	_t.check("arc+heat commits fusion and spends both statuses",
		ha_res.get("key") == "arc+heat" and ha_elite_res.get("key") == "arc+heat"
		and field.status_of(fuse_dummy) == "" and ext_fused.size() == 2)
	await _sim(220)
	field.extended_fused.disconnect(on_ext)
	var dmg_norm: float = 1000.0 - float(fuse_dummy.hp)
	var dmg_elite: float = 1000.0 - float(fuse_elite.hp)
	_t.check("arc+heat sustained fusion damages normal dummy and caps elite to <= 10%",
		dmg_norm > 10.0 and dmg_elite > 0.0 and dmg_elite <= dmg_norm * 0.105,
		"norm=%.2f elite=%.2f" % [dmg_norm, dmg_elite])

	for n in [inside_e, outside_e, melt_in, melt_out, fuse_dummy, fuse_elite]:
		if is_instance_valid(n):
			n.queue_free()
	field.clear()
	field.clear_providers()
	await _sim(2)


# ---- 4. 2 New Physical F-Key Actives (6 -> 8) -----------------------------------------

func _check_new_actives() -> void:
	_t.eq("ActiveDefs.ROWS expanded from 6 to 8", ActiveDefs.ROWS.size(), 8)
	_t.check("slag_mortar and magnet_sling registered with expected makers",
		ActiveDefs.row("slag_mortar").get("maker") == "redjaw"
		and ActiveDefs.row("magnet_sling").get("maker") == "fleet_surplus")

	_game.tuning.set_option("actives", "on")
	var rack = _combat.actives
	var ball_at: Vector3 = _player.ball_position()

	# Test slag_mortar: committed heat zone + Destructibles.on_blast(..., 1) breaks Tier 2 at Heft I.
	var dest := Destructibles.new()
	var wall_at := ball_at + Vector3(0.0, 0.5, -5.0)
	dest.build([{"id": "slag_tier2_wall", "tier": 2, "at": wall_at, "size": Vector3(2.0, 2.0, 2.0)}],
		{"root": _game.ctx.root, "events": _game.ctx.events, "combat": _combat, "no_visuals": true, "run_id": "slag_t", "stage": 1})
	dest.finish_build()
	var prev_dest = _game.ctx.destructibles
	_game.ctx.destructibles = dest

	var slag_e = _combat.spawn_enemy("chaser", wall_at + Vector3(1.0, 0.0, 0.0))
	slag_e.hp = 500.0
	slag_e.max_hp = 500.0
	slag_e.set_physics_process(false)
	rack.rack("slag_mortar", true)
	var slag_press: String = rack.press()
	await _sim(35)
	_t.check("slag_mortar fires committed heat zone, hits enemy, and shatters Tier 2 wall via on_blast(..., 1)",
		slag_press == "" and dest.state_of("slag_tier2_wall") == "shattered" and slag_e.hp < 500.0,
		"press='%s' wall=%s hp=%.1f" % [slag_press, dest.state_of("slag_tier2_wall"), slag_e.hp])

	_game.ctx.destructibles = prev_dest
	dest.teardown()
	dest.queue_free()
	if is_instance_valid(slag_e):
		slag_e.queue_free()

	# Test magnet_sling: cluster-pull anchor buoy pulls enemies inward before item_proc snap.
	var drop := func(dx: float, dz: float) -> Vector3:
		return _game.ctx.terrain.drop_point(ball_at.x + dx, ball_at.z + dz, 1.0)
	var mag_a = _combat.spawn_enemy("chaser", drop.call(0.0, -7.0))
	var mag_b = _combat.spawn_enemy("chaser", drop.call(5.0, -7.0))
	var mag_far = _combat.spawn_enemy("chaser", drop.call(25.0, -7.0))
	for e in [mag_a, mag_b, mag_far]:
		e.hp = 500.0
		e.max_hp = 500.0
		e.set_physics_process(false)
	var dist_before: float = mag_a.global_position.distance_to(mag_b.global_position)
	rack.rack("magnet_sling", true)
	var mag_press: String = rack.press()
	await _sim(45)
	var dist_after: float = mag_a.global_position.distance_to(mag_b.global_position)
	_t.check("magnet_sling pulls cluster inward before snapping for item_proc damage (spares far enemy)",
		mag_press == "" and dist_after < dist_before - 1.0 and mag_a.hp < 500.0 and mag_b.hp < 500.0 and is_equal_approx(mag_far.hp, 500.0),
		"dist %.2f->%.2f hp=(%.1f, %.1f, far=%.1f)" % [dist_before, dist_after, mag_a.hp, mag_b.hp, mag_far.hp])
	for e in [mag_a, mag_b, mag_far]:
		if is_instance_valid(e):
			e.queue_free()
	await _sim(2)


# ---- 5. 3 New Isaac Consumables (6 -> 9) + Deeper Trade Counters ----------------------

func _check_isaac_consumables_and_trade_contracts() -> void:
	var run = _game.ctx.run
	_combat.consumables.reset()
	run.clear_consumables()
	run.expand_consumable_belt(2)

	_t.check("Consumables expanded to 9 total while base ORDER stays 6",
		Consumables.ORDER.size() == 6 and Consumables.all_order().size() == 9 and Consumables.all_rows().size() == 9)

	# 5a. scrap_dice (Foreman's Audit Die): rerolls shop offers to same-or-higher tier at 0 cog / 0 reroll cost.
	var shop: Shop = _build.shop
	shop.enter()
	var rerolls_before: int = shop.rerolls_left
	var cogs_before: int = run.cogs
	run.add_consumable(Consumables.SCRAP_DICE)
	var dice_res: Dictionary = _combat.consumables.use_consumable()
	var before_tiers: Array = dice_res.get("before_tiers", [])
	var after_tiers: Array = dice_res.get("after_tiers", [])
	var tiers_non_decreasing := before_tiers.size() > 0 and before_tiers.size() == after_tiers.size()
	for i in before_tiers.size():
		if int(after_tiers[i]) < int(before_tiers[i]):
			tiers_non_decreasing = false
	_t.check("scrap_dice rerolls shop stock to same-or-higher tier without spending cogs or rerolls_left",
		int(dice_res.get("rerolled_shop", 0)) > 0 and tiers_non_decreasing
		and shop.rerolls_left == rerolls_before and run.cogs == cogs_before)
	shop.leave()

	# 5b. duplicator_spool (Carbon Tape): clones next pickup/core/consumable strictly ONCE within 12 s.
	run.clear_consumables()
	run.bonus_cores = 0
	run.add_consumable(Consumables.DUPLICATOR_SPOOL)
	var dup_res: Dictionary = _combat.consumables.use_consumable()
	_t.check("duplicator_spool arms 12 s clone window",
		bool(dup_res.get("armed", false)) and Consumables.duplicator_armed(run)
		and is_equal_approx(float(dup_res.get("duration_s", 0.0)), 12.0))
	var first_clone := Consumables.try_clone_pickup(_game.ctx, _combat, "core", 1, _player.ball_position())
	var second_clone := Consumables.try_clone_pickup(_game.ctx, _combat, "core", 1, _player.ball_position())
	_t.check("duplicator_spool clones strictly once per pop (2nd pickup in window NOT cloned)",
		bool(first_clone["cloned"]) and not bool(second_clone["cloned"]) and not Consumables.duplicator_armed(run)
		and run.bonus_cores == 1)

	# Planted negative control: expired duplicator window (> 12 s) clones nothing.
	run.add_consumable(Consumables.DUPLICATOR_SPOOL)
	_combat.consumables.use_consumable()
	Consumables.step_w50(_game.ctx, 12.5)
	var expired_clone := Consumables.try_clone_pickup(_game.ctx, _combat, "core", 1, _player.ball_position())
	_t.check("planted: expired duplicator_spool window clones nothing",
		not Consumables.duplicator_armed(run) and not bool(expired_clone["cloned"]) and run.bonus_cores == 1)

	# 5c. overload_fuse (Breaker Fuse): next Active echoes strictly ONCE at 0.75x (item_proc).
	var rack = _combat.actives
	rack.rack("magnet_sling", true)
	rack.charges = 2
	var echo_before: int = rack.echo_fires
	run.add_consumable(Consumables.OVERLOAD_FUSE)
	var fuse_res: Dictionary = _combat.consumables.use_consumable()
	_t.check("overload_fuse arms 0.75x single echo", bool(fuse_res.get("armed", false)) and Consumables.overload_armed(run))
	rack.press()
	var after_first_echo: int = rack.echo_fires
	rack.press()
	var after_second_press: int = rack.echo_fires
	_t.check("overload_fuse echoes Active strictly once (2nd Active press does NOT echo)",
		after_first_echo == echo_before + 1 and after_second_press == after_first_echo and not Consumables.overload_armed(run))

	# Ultimate echo path + planted single-echo bound.
	var ult_e = _combat.spawn_enemy("chaser", _player.ball_position() + Vector3(3.0, 0.0, 0.0))
	ult_e.hp = 500.0
	ult_e.max_hp = 500.0
	ult_e.set_physics_process(false)
	run.add_consumable(Consumables.OVERLOAD_FUSE)
	_combat.consumables.use_consumable()
	var ult1 := Consumables.echo_ultimate(_game.ctx, _combat, 40.0, _player.ball_position(), 8.0)
	var ult2 := Consumables.echo_ultimate(_game.ctx, _combat, 40.0, _player.ball_position(), 8.0)
	_t.check("overload_fuse Ultimate echo deals 0.75x item_proc strictly once",
		bool(ult1["echoed"]) and is_equal_approx(float(ult1["mult"]), 0.75) and ult1["source"] == "item_proc"
		and int(ult1["hits"]) >= 1 and not bool(ult2["echoed"]))
	if is_instance_valid(ult_e):
		ult_e.queue_free()

	# 5d. Deeper Trade Counter contracts: Overtime Contract & Salvage Auction.
	_t.eq("two new analog Trade Counter contracts registered", TradePockets.contract_ids(), ["overtime_contract", "salvage_auction"])
	var cogs_pre: int = run.cogs
	var sign_res := TradePockets.sign_overtime_contract(run)
	var win_res := TradePockets.settle_overtime_contract(run, 30.0, _player.ball_position())
	var double_settle := TradePockets.settle_overtime_contract(run, 20.0, _player.ball_position())
	_t.check("Overtime Contract pays on fast clear and refuses double settlement",
		bool(sign_res["ok"]) and bool(win_res["ok"]) and bool(win_res["won"])
		and run.cogs == cogs_pre + 140 and not bool(double_settle["ok"]) and double_settle["reason"] == "already_settled")

	# Salvage Auction: low bid refused; valid bid spends cogs & awards part.
	run.add_cogs(200)
	var cogs_auc_pre: int = run.cogs
	var low_bid := TradePockets.bid_salvage_auction(run, 10)
	_t.check("planted: Salvage Auction refuses bid below minimum without spending cogs",
		not bool(low_bid["ok"]) and low_bid["reason"] == "bid_too_low" and run.cogs == cogs_auc_pre)
	var parts_pre: int = run.parts.size()
	var good_bid := TradePockets.bid_salvage_auction(run, 100)
	_t.check("Salvage Auction spends bid and grants part",
		bool(good_bid["ok"]) and run.cogs == cogs_auc_pre - 100 and run.parts.size() == parts_pre + 1 and Parts.def(String(good_bid["part_id"])) != null)


# ---- 6. 4th SPIL-9 Companion Family (SALVAGE_MAGNET) ----------------------------------

func _check_salvage_magnet_companion() -> void:
	_t.check("Companion has 4 families, 8 pieces, clean validate() and validate_drivers()",
		Companion.FAMILIES.size() == 4 and Companion.SALVAGE_MAGNET in Companion.FAMILIES
		and Companion.PIECES.size() == 8 and Companion.validate().is_empty() and Companion.validate_drivers().is_empty())

	var c := Companion.new()
	c.acquire("cog_scoop")
	c.acquire("cartridge_caddy")
	c.acquire("ram_prow")
	_t.check("planted: two SALVAGE_MAGNET pieces refuse assembly together",
		c.assemble(["cog_scoop", "cartridge_caddy"]) != "")
	_t.eq("cog_scoop assembles with ram_prow", c.assemble(["cog_scoop", "ram_prow"]), "")
	var doc := c.to_dict()
	var rt := Companion.new()
	_t.check("SALVAGE_MAGNET companion round-trips cleanly", rt.from_dict(doc) and rt.sockets == c.sockets)

	# cog_scoop: wider vacuum scale when seated (1.0 when unseated) + streak cog drip bounded per stage.
	var run = _game.ctx.run
	run.companion = {}
	_t.near("planted: unseated cog_scoop keeps 1.0 vacuum scale", Companion.vacuum_scale(run.companion), 1.0)
	run.companion = doc
	_t.near("seated cog_scoop widens vacuum scale", Companion.vacuum_scale(run.companion), Companion.COG_SCOOP_VACUUM_MULT)
	Companion.reset_salvage_stage(run)
	var cogs_start: int = run.cogs
	for _k in Companion.COG_SCOOP_STREAK_STEP:
		Companion.on_salvage_kill(run)
	_t.eq("cog_scoop drips streak cogs after 5 kills", run.cogs - cogs_start, Companion.COG_SCOOP_STREAK_COGS)
	for _k in 200:
		Companion.on_salvage_kill(run)
	_t.eq("planted: cog_scoop drip respects per-stage cap", run.cogs - cogs_start, Companion.COG_SCOOP_STAGE_CAP)

	# cartridge_caddy: prints a random Pocket Consumable every 2 cleared yards, strictly capped at CADDY_STAGE_CAP.
	c.unassemble()
	c.assemble(["cartridge_caddy", "ram_prow"])
	run.companion = c.to_dict()
	Companion.reset_salvage_stage(run)
	run.clear_consumables()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var prints := 0
	var first_yard := Companion.on_yard_cleared(run, _combat, _player.ball_position(), rng, Consumables.roll_id)
	var second_yard := Companion.on_yard_cleared(run, _combat, _player.ball_position(), rng, Consumables.roll_id)
	_t.check("cartridge_caddy prints on 2nd cleared yard (not 1st)",
		not bool(first_yard["printed"]) and bool(second_yard["printed"]) and Consumables.is_valid(String(second_yard["consumable_id"])))
	prints += 1
	for _y in 10:
		var yr := Companion.on_yard_cleared(run, _combat, _player.ball_position(), rng, Consumables.roll_id)
		if bool(yr["printed"]):
			prints += 1
	_t.eq("planted: cartridge_caddy respects per-stage bounded cap", prints, Companion.CADDY_STAGE_CAP)
	await _sim(2)
