extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Elements := preload("res://src/build/elements.gd")
const ElementField := preload("res://src/build/element_field.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const T := preload("res://tests/support/t.gd")

const CRUISE := 14.0
const DT := 1.0 / 60.0
const TOL := 1.0e-3

var _t := T.new("sim_elements_chains_test")
var _game
var _combat
var _field
var _player
var _source := Intent.Scripted.new()


class FakeScrap extends RefCounted:
	var scrap: Array[int] = []
	var cogs: Array[int] = []

	func drop(_at: Vector3, amount: int, _rng: RandomNumberGenerator) -> void:
		scrap.append(amount)

	func drop_cogs(_at: Vector3, amount: int) -> void:
		cogs.append(amount)

	func scrap_sum() -> int:
		var total := 0
		for n in scrap:
			total += n
		return total

	func cog_sum() -> int:
		var total := 0
		for n in cogs:
			total += n
		return total


class FakeCombat extends RefCounted:
	var strikes: Array[Dictionary] = []
	var consumables: Array[String] = []

	func strike(enemy: Node3D, kind: String, force: float, part := "", source := "", _impact := "") -> void:
		strikes.append({"enemy": enemy, "kind": kind, "force": force, "part": part, "source": source})

	func drop_consumable(cons_id: String, _at: Vector3) -> void:
		consumables.append(cons_id)


class FakeEnemy extends Node3D:
	var knocks := 0
	var pushes: Array[Vector3] = []
	var forces: Array[float] = []

	func knock(direction: Vector3, force: float) -> void:
		knocks += 1
		pushes.append(direction)
		forces.append(force)

	func is_dead() -> bool:
		return false


func _initialize() -> void:
	_run.call_deferred()


func _sim(ticks: int) -> void:
	for _i in ticks:
		await physics_frame


func _run() -> void:
	_check_four_element_table()
	await _check_destructible_chains()

	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(6)
	_combat = _game.ctx.spawner
	_field = _game.build.field

	await _check_molten_slag_fusion()
	await _check_steam_cross_reactions()

	_field.clear()
	_field.clear_providers()
	_game.free()
	quit(_t.verdict())


func _check_four_element_table() -> void:
	_t.eq("Elements.problems() is clean", Elements.problems(), [] as Array[String])
	_t.eq("Elements.all_problems() is clean", Elements.all_problems(), [] as Array[String])
	_t.eq("base FUSIONS keeps 3 core pairs", Elements.FUSIONS.size(), 3)
	_t.eq("all_fusions covers all 6 pairs of 4 elements", Elements.all_fusions().size(), 6)
	_t.eq("fusion_key orders heat+kinetic alphabetically", Elements.fusion_key("kinetic", "heat"), "heat+kinetic")

	var hk_a := Elements.fuse("heat", "kinetic")
	var hk_b := Elements.fuse("kinetic", "heat")
	_t.check("heat+kinetic Molten Slag resolves identically in either order as burst overload with immunity",
		not hk_a.is_empty() and hk_a == hk_b
		and hk_a.get("behaviour") == "overload" and hk_a.get("kind") == "burst"
		and String(hk_a.get("immunity", "")) != "" and float(hk_a.get("damage", 0.0)) > 0.0,
		str(hk_a))

	var all_pairs_ok := true
	var elems := Elements.all_elements()
	for i in elems.size():
		for j in range(i + 1, elems.size()):
			var a: String = elems[i]
			var b: String = elems[j]
			if Elements.fuse(a, b).is_empty() or Elements.fuse(a, b) != Elements.fuse(b, a):
				all_pairs_ok = false
	_t.check("every unordered pair of the 4 elements fuses symmetrically", all_pairs_ok)

	_t.check("steam cross-reaction rows resolve for arc and frost",
		Elements.resolve("arc", "steam").get("behaviour") == "storm_pulse"
		and Elements.resolve("frost", "steam").get("behaviour") == "flash_condense"
		and "steam" in Elements.all_materials())
	_t.check("planted: non-reacting pairs and self-fusions return empty",
		Elements.fuse("heat", "heat").is_empty()
		and Elements.fuse("kinetic", "kinetic").is_empty()
		and Elements.resolve("heat", "steam").is_empty()
		and Elements.resolve("kinetic", "steam").is_empty())


func _spawn_dummy(spot: Vector3, elite := false) -> Node3D:
	var e: Node3D = _combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(spot.x, spot.z, 2.0))
	e.hp = 10000.0
	e.max_hp = 10000.0
	e.plating = 0.0
	e.set_physics_process(false)
	e.set_process(false)
	if elite:
		e.set_meta("elite_pack", true)
	return e


func _check_molten_slag_fusion() -> void:
	_field.clear()
	var base: Vector3 = _player.ball_position()
	var row := Elements.fuse("heat", "kinetic")
	var r: float = float(row["radius"])

	var c1 := _spawn_dummy(base + Vector3(-24.0, 0.0, 18.0))
	var in1 := _spawn_dummy(c1.global_position + Vector3(r - 0.5, 0.0, 0.0))
	var out1 := _spawn_dummy(c1.global_position + Vector3(-(r + 0.8), 0.0, 0.0))
	var c2 := _spawn_dummy(base + Vector3(24.0, 0.0, 18.0))
	var el := _spawn_dummy(base + Vector3(0.0, 0.0, 44.0), true)

	var ext: Array = []
	var on_ext := func(res: Dictionary) -> void: ext.append(res)
	_field.extended_fused.connect(on_ext)

	_field.apply("heat", c1.global_position, "test")
	var s1_before: String = _field.status_of(c1)
	_combat.strike(c1, "slam", 5.0)
	var hp_c1 := float(c1.hp)
	var hp_in1 := float(in1.hp)
	var hp_out1 := float(out1.hp)

	_combat.strike(c2, "slam", 5.0)
	var s2_before: String = _field.status_of(c2)
	_field.apply("heat", c2.global_position, "test")
	var hp_c2 := float(c2.hp)

	_field.touch(el, "heat")
	_field.touch(el, "kinetic")
	var hp_el := float(el.hp)

	_t.check("heat+kinetic commits in both orders and spends statuses",
		s1_before == "heat" and s2_before == "kinetic"
		and _field.status_of(c1) == "" and _field.status_of(c2) == ""
		and ext.size() == 3 and ext.all(func(x: Dictionary) -> bool: return x.get("key") == "heat+kinetic"),
		"ext=%d s1=%s s2=%s" % [ext.size(), s1_before, s2_before])

	var want_col := ElementField.fusion_colour("heat+kinetic")
	var preview_col: Color = ext[0]["preview"].material_override.albedo_color
	_t.check("Molten Slag preview ring wears the heat+kinetic colour mix",
		Color(preview_col.r, preview_col.g, preview_col.b).is_equal_approx(want_col))

	var ext_before := ext.size()
	_field.touch(c1, "kinetic")
	_t.check("planted: repeat kinetic hit after fusion spends status does not re-fuse",
		ext.size() == ext_before and _field.status_of(c1) == "kinetic")

	await _sim(24)
	_field.extended_fused.disconnect(on_ext)

	var dmg1 := hp_c1 - float(c1.hp)
	var dmg2 := hp_c2 - float(c2.hp)
	var dmg_el := hp_el - float(el.hp)
	_t.check("Molten Slag deals identical burst damage in either order and full burst to elites without holding",
		dmg1 > 10.0 and absf(dmg1 - dmg2) <= TOL * dmg1
		and absf(dmg_el - dmg1) <= TOL * dmg1
		and not _field.is_held(c1) and not _field.is_held(el),
		"d1=%.2f d2=%.2f el=%.2f" % [dmg1, dmg2, dmg_el])
	_t.check("Molten Slag hits probe inside committed radius and spares outside probe",
		float(in1.hp) < hp_in1 - TOL and is_equal_approx(float(out1.hp), hp_out1),
		"in=%.2f out=%.2f" % [hp_in1 - float(in1.hp), hp_out1 - float(out1.hp)])

	for n in [c1, in1, out1, c2, el]:
		if is_instance_valid(n):
			n.remove_from_group("enemy")
			n.queue_free()
	_field.clear()
	await _sim(2)


func _spawn_dummy_exact(spot: Vector3, elite := false) -> Node3D:
	var e: Node3D = _combat.spawn_enemy("chaser", spot)
	e.hp = 10000.0
	e.max_hp = 10000.0
	e.plating = 0.0
	e.set_physics_process(false)
	e.set_process(false)
	if elite:
		e.set_meta("elite_pack", true)
	return e


func _check_steam_cross_reactions() -> void:
	_field.clear()
	_field.clear_providers()
	var base: Vector3 = _player.ball_position()
	var water_y: float = base.y - 0.8
	_field.register_material("water", func(p: Vector3) -> Dictionary:
		if Vector2(p.x - base.x, p.z - base.z).length() <= 200.0:
			return {"surface_y": water_y}
		return {})

	var storm_at := base + Vector3(12.0, 0.0, 0.0)
	var storm_in := _spawn_dummy_exact(storm_at + Vector3(2.5, 0.0, 0.0))
	var storm_out := _spawn_dummy_exact(storm_at + Vector3(11.0, 0.0, 0.0))
	await _sim(1)

	var steam_res: Dictionary = _field.apply("heat", storm_at, "test")
	_t.eq("steam cloud raised before arc discharge", _field.steam_cloud_count(), 1)
	_t.eq("steam cloud behaviour recorded", steam_res.get("behaviour"), "steam_cloud")
	var hp_in_pre := float(storm_in.hp)
	var hp_out_pre := float(storm_out.hp)

	var storm_res: Dictionary = _field.apply("arc", storm_at + Vector3(1.0, 0.0, 0.0), "test")
	_t.check("arc on active steam cloud discharges storm_pulse across cloud radius and consumes cloud",
		storm_res.get("behaviour") == "storm_pulse" and storm_res.get("material") == "steam"
		and storm_res.get("key") == "arc:steam" and bool(storm_res.get("discharged", false))
		and storm_res.get("source") == "item_proc"
		and _field.steam_cloud_count() == 0
		and float(storm_in.hp) < hp_in_pre - TOL and is_equal_approx(float(storm_out.hp), hp_out_pre)
		and _field.status_of(storm_in) == "arc",
		str(storm_res))

	var second_arc: Dictionary = _field.apply("arc", storm_at, "test")
	_t.check("planted: second arc after steam discharge does not re-fire storm_pulse",
		second_arc.get("behaviour") == "electrify" and second_arc.get("material") == "water",
		str(second_arc))

	var cond_at := base + Vector3(-16.0, 0.0, 0.0)
	var hail_in := _spawn_dummy_exact(cond_at + Vector3(2.5, 0.0, 0.0))
	var hail_out := _spawn_dummy_exact(cond_at + Vector3(11.0, 0.0, 0.0))
	await _sim(1)
	_field.apply("heat", cond_at, "test")
	var hail_in_pre := float(hail_in.hp)
	var hail_out_pre := float(hail_out.hp)
	var slabs_before: int = _field.slab_count()

	var cond_res: Dictionary = _field.apply("frost", cond_at + Vector3(-1.0, 0.0, 0.0), "test")
	_t.check("frost on active steam cloud flash-condenses ice slab and hail chill, consuming cloud",
		cond_res.get("behaviour") == "flash_condense" and cond_res.get("material") == "steam"
		and cond_res.get("key") == "frost:steam" and bool(cond_res.get("condensed", false))
		and cond_res.get("source") == "item_proc"
		and _field.steam_cloud_count() == 0 and _field.slab_count() == slabs_before + 1
		and cond_res.has("slab") and is_instance_valid(cond_res.get("body"))
		and float(hail_in.hp) < hail_in_pre - TOL and is_equal_approx(float(hail_out.hp), hail_out_pre)
		and _field.status_of(hail_in) == "frost",
		str(cond_res))

	for n in [storm_in, storm_out, hail_in, hail_out]:
		if is_instance_valid(n):
			n.remove_from_group("enemy")
			n.queue_free()

	for k in ElementField.MAX_STEAM_CLOUDS + 6:
		_field.apply("heat", base + Vector3(float(k) * 0.4, 0.0, 20.0), "cap_test")
	_t.check("steam cloud spam strictly respects MAX_STEAM_CLOUDS",
		_field.steam_cloud_count() == ElementField.MAX_STEAM_CLOUDS,
		"%d / %d" % [_field.steam_cloud_count(), ElementField.MAX_STEAM_CLOUDS])

	_field.clear()
	for k in ElementField.MAX_SLABS + 8:
		var spot := base + Vector3(float(k % 9) * 8.0 - 32.0, 0.0, -24.0 - float(k / 9) * 8.0)
		_field.apply("heat", spot, "cap_test")
		_field.apply("frost", spot, "cap_test")
	_t.check("flash-condense spam strictly respects MAX_SLABS and MAX_STEAM_CLOUDS",
		_field.slab_count() == ElementField.MAX_SLABS and _field.steam_cloud_count() == 0,
		"slabs=%d clouds=%d" % [_field.slab_count(), _field.steam_cloud_count()])

	_field.clear()
	_field.clear_providers()
	await process_frame
	await process_frame
	_t.check("clear() frees every slab, steam cloud, zone, and child node cleanly",
		_field.slab_count() == 0 and _field.steam_cloud_count() == 0
		and _field.zone_count() == 0 and _field.get_child_count() == 0,
		"children=%d" % _field.get_child_count())


func _drow(id: String, tier: int, at: Vector3, size := Vector3(1.4, 2.0, 1.4)) -> Dictionary:
	return {"id": id, "tier": tier, "at": at, "size": size}


func _check_destructible_chains() -> void:
	await process_frame
	await process_frame
	var base_nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)

	var fast_combat := FakeCombat.new()
	var fast_scrap := FakeScrap.new()
	var fast := Destructibles.new()
	fast.build([
		_drow("lead", 2, Vector3(0.0, 1.0, 0.0)),
		_drow("adj1", 1, Vector3(2.2, 1.0, 0.3)),
		_drow("adj2", 2, Vector3(2.5, 1.0, -0.4)),
		_drow("adj3_heavy", 3, Vector3(2.0, 1.0, 0.0)),
		_drow("behind1", 1, Vector3(-3.0, 1.0, 0.0)),
		_drow("far1", 1, Vector3(7.0, 1.0, 0.0)),
		_drow("hop2", 1, Vector3(4.8, 1.0, 0.3)),
	], {"root": root, "cruise": CRUISE, "run_seed": 11, "run_id": "chain-1", "stage": 1,
		"scrap": fast_scrap, "combat": fast_combat})
	fast.finish_build()
	fast.set_process(false)

	var e_ext := FakeEnemy.new()
	e_ext.position = Vector3(2.6, 1.0, 0.0)
	e_ext.add_to_group("enemy")
	root.add_child(e_ext)

	var high_speed := CRUISE * 1.4
	fast.on_ball(Vector3(-3.0, 1.0, 0.0), Vector3(high_speed, 0.0, 0.0), 2, DT)
	_t.check("high-speed breach shatters primary and propagates micro-shatter into adjacent tier<=2 in cone only",
		fast.state_of("lead") == "shattered"
		and fast.state_of("adj1") == "shattered"
		and fast.state_of("adj2") == "shattered"
		and fast.state_of("adj3_heavy") == "intact"
		and fast.state_of("behind1") == "intact"
		and fast.state_of("far1") == "intact"
		and fast.state_of("hop2") == "intact"
		and fast.chain_breaks() == 2,
		"order=%s chains=%d" % [fast.break_order(), fast.chain_breaks()])
	var first_push: Vector3 = e_ext.pushes[0] if not e_ext.pushes.is_empty() else Vector3.ZERO
	var first_force: float = e_ext.forces[0] if not e_ext.forces.is_empty() else 0.0
	_t.check("high-speed breach projects directional shrapnel knockback beyond standard reach with boosted force",
		e_ext.knocks >= 1 and first_push.x > 0.5
		and first_force > Destructibles.BASE_FORCE * 0.7 * 1.4,
		"knocks=%d push=%s force=%.2f" % [e_ext.knocks, first_push, first_force])

	var low_combat := FakeCombat.new()
	var low := Destructibles.new()
	low.build([
		_drow("lead", 2, Vector3(0.0, 1.0, 30.0)),
		_drow("adj1", 1, Vector3(2.2, 1.0, 30.2)),
	], {"root": root, "cruise": CRUISE, "run_seed": 11, "run_id": "chain-low", "stage": 1,
		"scrap": FakeScrap.new(), "combat": low_combat, "enemies": func() -> Array: return []})
	low.finish_build()
	low.set_process(false)
	low.on_ball(Vector3(-3.0, 1.0, 30.0), Vector3(CRUISE, 0.0, 0.0), 2, DT)
	_t.check("planted: standard cruise Class II breach does not trigger micro-shatter chain",
		low.state_of("lead") == "shattered" and low.state_of("adj1") == "intact" and low.chain_breaks() == 0,
		"order=%s chains=%d" % [low.break_order(), low.chain_breaks()])

	var heavy := Destructibles.new()
	heavy.build([
		_drow("hlead", 3, Vector3(0.0, 1.0, 60.0)),
		_drow("hadj", 2, Vector3(2.2, 1.0, 60.0)),
		_drow("ht3", 3, Vector3(2.2, 1.0, 61.5)),
	], {"root": root, "cruise": CRUISE, "run_seed": 11, "run_id": "chain-heavy", "stage": 1,
		"scrap": FakeScrap.new(), "combat": FakeCombat.new(), "enemies": func() -> Array: return []})
	heavy.finish_build()
	heavy.set_process(false)
	heavy.on_ball(Vector3(-3.0, 1.0, 60.0), Vector3(CRUISE, 0.0, 0.0), 3, DT)
	_t.check("heavy-heft (Class III) breach chains into adjacent tier<=2 and spares tier 3",
		heavy.state_of("hlead") == "shattered" and heavy.state_of("hadj") == "shattered"
		and heavy.state_of("ht3") == "intact" and heavy.chain_breaks() == 1,
		"order=%s chains=%d" % [heavy.break_order(), heavy.chain_breaks()])

	var cluster_rows: Array = []
	for i in 16:
		var tier := 3 if i % 4 == 0 else (2 if i % 2 == 0 else 1)
		cluster_rows.append(_drow("c%02d" % i, tier, Vector3(float(i % 4) * 1.8, 1.0, 90.0 + float(i / 4) * 1.8)))
	var c_scrap := FakeScrap.new()
	var c_combat := FakeCombat.new()
	var cluster := Destructibles.new()
	cluster.build(cluster_rows, {"root": root, "cruise": CRUISE, "run_seed": 99, "run_id": "cap-chain", "stage": 2,
		"scrap": c_scrap, "combat": c_combat, "enemies": func() -> Array: return []})
	cluster.finish_build()
	cluster.set_process(false)

	for pass_i in 3:
		cluster.on_ball(Vector3(-2.5, 1.0, 90.0), Vector3(CRUISE * 1.5, 0.0, 0.0), 5, DT)
		cluster.on_blast(Vector3(2.7, 1.0, 92.7), 8.0, "slam", 1, 5)
	var breaks_after_first := cluster.break_order()
	var loot_after_first := cluster.loot()
	var cons_after_first := cluster.consumables_paid()
	cluster.on_ball(Vector3(-2.5, 1.0, 90.0), Vector3(CRUISE * 1.5, 0.0, 0.0), 5, DT)
	cluster.on_blast(Vector3(2.7, 1.0, 92.7), 12.0, "slam", 1, 5)

	var seen_ids := {}
	for bid in breaks_after_first:
		seen_ids[bid] = true
	_t.check("chain cluster respects pay-once (every piece broken and paid at most once)",
		breaks_after_first.size() == 16 and seen_ids.size() == 16
		and cluster.break_order() == breaks_after_first
		and cluster.loot() == loot_after_first
		and cluster.consumables_paid() == cons_after_first,
		"breaks=%d unique=%d loot=%s" % [breaks_after_first.size(), seen_ids.size(), str(loot_after_first)])
	_t.check("chain cluster strictly respects SHARD_POOL, NODE_CEILING, SCRAP_CAP, COG_CAP, CONSUMABLE_CAP",
		cluster.live_shards() <= Destructibles.SHARD_POOL
		and cluster.pool_nodes().size() <= Destructibles.NODE_CEILING
		and int(loot_after_first["scrap"]) <= Destructibles.SCRAP_CAP
		and int(loot_after_first["cogs"]) <= Destructibles.COG_CAP
		and cons_after_first <= Destructibles.CONSUMABLE_CAP
		and c_scrap.scrap_sum() == int(loot_after_first["scrap"])
		and c_scrap.cog_sum() == int(loot_after_first["cogs"]),
		"live=%d pool=%d loot=%s cons=%d" % [cluster.live_shards(), cluster.pool_nodes().size(), str(loot_after_first), cons_after_first])

	e_ext.free()
	for mod in [fast, low, heavy, cluster]:
		mod.teardown()
		mod.queue_free()
	await process_frame
	await process_frame
	_t.eq("destructibles teardown leaves zero leaked nodes",
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), base_nodes)
