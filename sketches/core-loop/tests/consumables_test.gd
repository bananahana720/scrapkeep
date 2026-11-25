extends SceneTree

# W47-C1-CODE: Pocket Consumable Belt, 6 hardware cartridges, wordless HUD slot,
# drop sources (Tier 3+ destructibles, cracked caches, secondary-counter kills, Moss's shop),
# B6 compliance (Foreman's Memo flat #D936B0 cartridge only, zero floor glow),
# and W47-C2 catalyst_cartridge hook via events.consumable_used.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Consumables := preload("res://src/build/consumables.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Palette := preload("res://src/core/palette.gd")
const Icons := preload("res://src/ui/icons.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Augments := preload("res://src/movement/augments.gd")
const Harpoon := preload("res://src/movement/harpoon.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const Shop := preload("res://src/build/shop.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("consumables_test")
var _game
var _combat
var _player
var _build
var _source := Intent.Scripted.new()
var _used_events: Array = []


func _initialize() -> void:
	_check_table_assets_and_b6()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _sim(ticks: int) -> void:
	for _i in ticks:
		await physics_frame


func _check_table_assets_and_b6() -> void:
	_t.check("all 6 cartridges registered", Consumables.ORDER.size() == 6 and Consumables.ROWS.size() == 6)
	var icons_ok := true
	var glbs_ok := true
	var vcol_ok := true
	var no_hazard := true
	var memo_b6_ok := true
	for cid in Consumables.ORDER:
		var row: Dictionary = Consumables.row_of(cid)
		var icon_tex := Icons.texture(String(row["icon"]))
		if icon_tex == null:
			icons_ok = false
		var col: Color = row["color"]
		if col.is_equal_approx(Palette.HAZARD):
			no_hazard = false
		if cid != Consumables.FOREMAN_MEMO and col.is_equal_approx(Palette.KINDNESS):
			memo_b6_ok = false
		var model_path := String(row["model"])
		if not ResourceLoader.exists(model_path):
			glbs_ok = false
		else:
			var inst := Consumables.instantiate_model(model_path, col)
			var patched_any := false
			for view in inst.find_children("*", "MeshInstance3D", true, false):
				var mi := view as MeshInstance3D
				if mi == null or mi.mesh == null:
					continue
				for s in mi.mesh.get_surface_count():
					var mat := mi.mesh.surface_get_material(s) as StandardMaterial3D
					if mat != null and mat.vertex_color_use_as_albedo:
						patched_any = true
					if cid == Consumables.FOREMAN_MEMO and mat != null and String(mat.resource_name).to_lower() == "ancient_enamel":
						if mat.emission_enabled:
							memo_b6_ok = false
			if not patched_any:
				vcol_ok = false
			inst.free()
	var cradle_ok := ResourceLoader.exists(Consumables.CRADLE_MODEL)
	var balloon_ok := ResourceLoader.exists(Consumables.BALLOON_MODEL)
	var memo_row := Consumables.row_of(Consumables.FOREMAN_MEMO)
	memo_b6_ok = memo_b6_ok and memo_row["color"].is_equal_approx(Palette.KINDNESS) and bool(memo_row.get("no_floor_glow", false))
	_t.check("all 6 SVG cartridge icons load", icons_ok)
	_t.check("all 6 cartridge GLBs + cradle + balloon exist", glbs_ok and cradle_ok and balloon_ok)
	_t.check("vertex_color_use_as_albedo patched on cartridge GLB surfaces", vcol_ok)
	_t.check("zero HAZARD color on consumables", no_hazard)
	_t.check("B6: Foreman's Memo flat KINDNESS cartridge only, non-emissive, zero floor glow", memo_b6_ok)
	_t.check("bindings: cl_consumable bound to KEY_C without widening VERBS", Bindings.VERBS.size() == 12 and KEY_C in Bindings.actions().get("cl_consumable", {}).get("keys", []))


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
	_game.ctx.events.consumable_used.connect(func(cid: String, at: Vector3): _used_events.append({"id": cid, "at": at}))

	await _check_belt_and_hud()
	await _check_cap_charge()
	await _check_nitro_siphon()
	await _check_anchor_flare()
	await _check_overclock_card()
	await _check_foreman_memo()
	await _check_moss_patch()
	await _check_drop_sources_and_shop()
	await _check_catalyst_cartridge_hook()
	await _check_cleanup_and_reset()

	Consumables._reset()
	CrackedCache._shared.clear()
	CrackedCache._loaded = false
	_game.free()
	quit(_t.verdict())


func _check_belt_and_hud() -> void:
	var run = _game.ctx.run
	var hud = _game.hud
	_t.check("belt starts empty with 1 slot default", run.consumable_capacity() == 1 and not run.has_consumable())
	# Entrance doc preserves old bytes when belt is empty & default capacity.
	var doc_empty: Dictionary = run.to_entrance_doc()
	_t.check("entrance doc omits consumable keys when empty/default", not doc_empty.has("consumables") and not doc_empty.has("consumable_slots"))
	await _sim(2)
	_t.check("HUD consumable slot hidden when empty", not hud.consumable_slot.showing() and not hud.consumable_slot.visible)

	# Stock 1st cartridge; 2nd refused at 1-slot cap.
	var added1: bool = run.add_consumable(Consumables.CAP_CHARGE)
	var added2: bool = run.add_consumable(Consumables.MOSS_PATCH)
	_t.check("1-slot belt holds 1 and rejects 2nd until expanded", added1 and not added2 and run.consumables.size() == 1)

	# Expand to 2 slots; now holds 2.
	var expanded: bool = run.expand_consumable_belt(2)
	var added2b: bool = run.add_consumable(Consumables.MOSS_PATCH)
	_t.check("expanded 2-slot belt holds 2 cartridges", expanded and run.consumable_capacity() == 2 and added2b and run.consumables.size() == 2)

	# Entrance doc round-trips stocked belt cleanly.
	var doc_stocked: Dictionary = run.to_entrance_doc()
	_t.check("entrance doc validates and carries stocked belt", run.validate_entrance_doc(doc_stocked) == "" and doc_stocked.get("consumables", []).size() == 2 and int(doc_stocked.get("consumable_slots", 0)) == 2)

	# Wordless HUD slot shows beside Nixie rail with zero Labels and zero overlap.
	await process_frame
	await process_frame
	hud.layout(Vector2(1600.0, 900.0))
	var slot: Control = hud.consumable_slot
	var labels: Array = slot.find_children("*", "Label", true, false)
	var rlabels: Array = slot.find_children("*", "RichTextLabel", true, false)
	var slot_rect: Rect2 = slot.piece_rect()
	var chain_rect := Rect2(hud.chain_counter.position, hud.chain_counter.size)
	var nixie_rect: Rect2 = hud.nixie_rail.piece_rect()
	var no_overlap: bool = not slot_rect.intersects(chain_rect) and (not hud.nixie_rail.showing() or not slot_rect.intersects(nixie_rect))
	_t.check("wordless HUD cartridge slot visible with zero text nodes and zero overlap",
		slot.showing() and labels.is_empty() and rlabels.is_empty() and slot_rect.size.x > 0.0 and no_overlap,
		"showing=%s rect=%s chain=%s nixie=%s" % [slot.showing(), slot_rect, chain_rect, nixie_rect])

	# Snapshot & restore preserves belt.
	run.snapshot(_player.ball_position(), Vector3.ZERO, 0.0)
	run.pop_consumable()
	_t.check("pop removes front cartridge FIFO", run.consumables.size() == 1 and run.peek_consumable() == Consumables.MOSS_PATCH)
	run.restore()
	_t.check("restore puts belt back to stage checkpoint", run.consumables.size() == 2 and run.peek_consumable() == Consumables.CAP_CHARGE)

	# Quick-tap C fires instantaneously with zero movement tax.
	var start_vel := Vector3(16.0, 0.0, 0.0)
	_player.set_velocity_now(start_vel, "test")
	var vel_before: Vector3 = _player.state.velocity
	Input.action_press(Bindings.CONSUMABLE_ACTION)
	await _sim(1)
	Input.action_release(Bindings.CONSUMABLE_ACTION)
	await _sim(1)
	var vel_after_flat := Vector2(_player.state.velocity.x, _player.state.velocity.z).length()
	var vel_before_flat := Vector2(vel_before.x, vel_before.z).length()
	_t.check("quick-tap C fires cartridge with zero movement speed tax",
		run.consumables.size() == 1 and _combat.last_consumable.get("id", "") == Consumables.CAP_CHARGE and vel_after_flat >= vel_before_flat - 1.5)
	run.clear_consumables()
	await _sim(2)


func _check_cap_charge() -> void:
	var ball_at: Vector3 = _player.ball_position()
	# Build a Tier 5 Heft Destructible right beside the ball (within 6 m) while player is Heft Class I.
	var dest := Destructibles.new()
	var rows := [{
		"id": "tier5_wall_test",
		"tier": 5,
		"at": ball_at + Vector3(3.0, 0.5, 0.0),
		"size": Vector3(2.0, 2.0, 2.0),
	}]
	dest.build(rows, {"root": _game.ctx.root, "events": _game.ctx.events, "combat": _combat, "no_visuals": true, "run_id": "test_cap", "stage": 1})
	dest.finish_build()
	var prev_dest = _game.ctx.destructibles
	_game.ctx.destructibles = dest

	# Spawn a Plated Brute within 6 m.
	var brute = _combat.spawn_enemy("plated_brute", ball_at + Vector3(-3.0, 0.0, 0.0))
	await _sim(2)
	var plates_before: int = brute.plates
	_game.ctx.run.add_consumable(Consumables.CAP_CHARGE)
	var res: Dictionary = _combat.use_consumable()
	await _sim(2)
	var loot_once := dest.loot()
	var paid_once: int = dest.consumables_paid()
	# Firing a second cap_charge on the already shattered wall must NOT double-pay (Destructibles.tla).
	_game.ctx.run.add_consumable(Consumables.CAP_CHARGE)
	_combat.use_consumable()
	await _sim(1)
	var loot_twice := dest.loot()
	_t.check("cap_charge shatters Tier 5 destructible at Heft I and pays strictly once",
		dest.state_of("tier5_wall_test") == "shattered" and loot_once == loot_twice and dest.consumables_paid() == paid_once)
	_t.check("cap_charge strips Plated Brute outer plate",
		plates_before > 0 and brute.plates == 0 and int(res.get("stripped", 0)) >= 1)
	_game.ctx.destructibles = prev_dest
	dest.teardown()
	dest.queue_free()
	if is_instance_valid(brute):
		brute.queue_free()
	_combat._clear_consumables_runtime()
	_game.ctx.run.clear_consumables()
	await _sim(2)


func _check_nitro_siphon() -> void:
	_combat._clear_consumables_runtime()
	_game.ctx.run.clear_consumables()
	var ball_at: Vector3 = _player.ball_position()
	_player.set_velocity_now(Vector3(1.0, 0.0, 0.0), "test")
	var tender = _combat.spawn_enemy("boom_tender", ball_at + Vector3(4.0, 0.0, 0.0))
	var jolt = _combat.spawn_enemy("jolt_layer", ball_at + Vector3(-4.0, 0.0, 0.0))
	await _sim(2)
	# Activate a live jolt field to verify auto-rip.
	if jolt.has_method("_commit"):
		jolt._commit(Vector3.FORWARD)
	var blazing_floor: float = _player.tuning.f("cruise") * float(SpeedTier.MULTIPLES[SpeedTier.BLAZING])
	_game.ctx.run.add_consumable(Consumables.NITRO_SIPHON)
	var res: Dictionary = _combat.use_consumable()
	await _sim(4)
	var flat_speed := Vector2(_player.state.velocity.x, _player.state.velocity.z).length()
	var all_popped := true
	if is_instance_valid(tender) and tender.get("popped") is Array:
		for p in tender.popped:
			if not bool(p):
				all_popped = false
	var mat_cleared := (not is_instance_valid(jolt)) or jolt.get("field") == null
	_t.check("nitro_siphon holds 6 s Blazing floor and auto-rips booms/mats",
		_combat.nitro_siphon_left() > 5.0 and flat_speed >= blazing_floor - 0.5 and all_popped and mat_cleared and int(res.get("ripped", 0)) > 0,
		"left=%.2f flat=%.2f floor=%.2f popped=%s mat=%s ripped=%s" % [_combat.nitro_siphon_left(), flat_speed, blazing_floor, all_popped, mat_cleared, res.get("ripped", 0)])
	if is_instance_valid(tender):
		tender.queue_free()
	if is_instance_valid(jolt):
		jolt.queue_free()
	await _sim(2)


func _check_anchor_flare() -> void:
	_combat._clear_consumables_runtime()
	_game.ctx.run.clear_consumables()
	var ball_at: Vector3 = _player.ball_position()
	_game.ctx.run.add_consumable(Consumables.ANCHOR_FLARE)
	var res: Dictionary = _combat.use_consumable()
	await _sim(2)
	var balloon = res.get("balloon")
	var valid_b: bool = is_instance_valid(balloon) and balloon.is_in_group(Augments.ANCHOR_GROUP) and balloon.is_in_group(Augments.STAKE_GROUP)
	var height_ok: bool = valid_b and absf(balloon.global_position.y - (ball_at.y + 18.0)) < 1.0
	# Verify 360-degree harpoon raycast bites the sky-balloon from 4 cardinal offsets around it.
	var space: PhysicsDirectSpaceState3D = _game.ctx.root.get_world_3d().direct_space_state
	var bites_360 := true
	if valid_b:
		var target_pt: Vector3 = balloon.global_position
		for off in [Vector3(10.0, -14.0, 0.0), Vector3(-10.0, -14.0, 0.0), Vector3(0.0, -14.0, 10.0), Vector3(0.0, -14.0, -10.0)]:
			var from: Vector3 = target_pt + off
			var dir: Vector3 = (target_pt - from).normalized()
			var aim := Harpoon.target(_player.kit, _player.tuning, space, [], from, dir, from)
			if aim.get("body") != balloon:
				bites_360 = false
	_t.check("anchor_flare spawns 18 m hovering balloon with 360-degree harpoon bite (single ChainState)",
		valid_b and height_ok and bites_360 and _combat.active_balloons().size() >= 1,
		"valid=%s height=%s bites=%s count=%d" % [valid_b, height_ok, bites_360, _combat.active_balloons().size()])
	# Expire balloon cleanly via time step.
	if valid_b:
		balloon.time_left = 0.01
		await _sim(3)
	_t.check("anchor_flare expires cleanly after lifetime", _combat.active_balloons().is_empty())


func _check_overclock_card() -> void:
	_combat._clear_consumables_runtime()
	_game.ctx.run.clear_consumables()
	var abilities = _player.abilities
	abilities.spend(AbilityState.MOVEMENT)
	abilities.spend(AbilityState.SPECIAL)
	_player.state.boost_cooldown = 3.0
	_game.ctx.run.add_consumable(Consumables.OVERCLOCK_CARD)
	_combat.use_consumable()
	await _sim(2)
	var cd_zero: bool = abilities.ready(AbilityState.MOVEMENT) and abilities.ready(AbilityState.SPECIAL) and _player.state.boost_cooldown <= 0.001
	var skilled_before: int = _combat.overclock_skilled_shots
	_source.press = {"fire_pressed": true}
	_source.hold = {"fire_held": true}
	await _sim(4)
	_source.hold = {}
	await _sim(2)
	_t.check("overclock_card gives 8 s zero Movement/Special CD + auto Skilled weapon cadence",
		_combat.overclock_card_left() > 7.0 and cd_zero and _combat.overclock_skilled_shots > skilled_before,
		"left=%.2f cd_zero=%s shots=%d->%d" % [_combat.overclock_card_left(), cd_zero, skilled_before, _combat.overclock_skilled_shots])


func _check_foreman_memo() -> void:
	_combat._clear_consumables_runtime()
	_game.ctx.run.clear_consumables()
	var ball_at: Vector3 = _player.ball_position()
	var run = _game.ctx.run
	var c1 = _combat.spawn_enemy("chaser", ball_at + Vector3(6.0, 0.0, 4.0))
	var c2 = _combat.spawn_enemy("lobber", ball_at + Vector3(-6.0, 0.0, 4.0))
	var w = _combat.spawn_enemy("warden", ball_at + Vector3(0.0, 0.0, -10.0))
	await _sim(2)
	# Case 1: pays 1 core when a core is held.
	run.add_core("test", ball_at)
	var cores_before: int = run.bonus_cores
	var hp_before: float = run.hp
	_game.ctx.run.add_consumable(Consumables.FOREMAN_MEMO)
	var res1: Dictionary = _combat.use_consumable()
	await _sim(2)
	var ordinary_frozen: bool = c1.process_mode == Node.PROCESS_MODE_DISABLED and c2.process_mode == Node.PROCESS_MODE_DISABLED
	var warden_unfrozen: bool = w.process_mode != Node.PROCESS_MODE_DISABLED
	var exposed_mult: float = _combat._strike_mult(c1, "runner", "weapon")
	_t.check("foreman_memo freezes ordinary enemies in aligned formation with exposed weak points (non-ordinary immune)",
		_combat.foreman_memo_left() > 4.0 and ordinary_frozen and warden_unfrozen and int(res1.get("frozen", 0)) >= 2 and exposed_mult >= 1.49,
		"left=%.2f ord=%s w=%s frozen=%s mult=%.2f res1=%s" % [_combat.foreman_memo_left(), ordinary_frozen, warden_unfrozen, res1.get("frozen", 0), exposed_mult, res1])
	_t.check("foreman_memo pays 1 core when held without taxing hull",
		res1.get("cost", "") == "core" and run.bonus_cores == cores_before - 1 and is_equal_approx(run.hp, hp_before),
		"cost=%s cores=%d->%d hp=%.2f->%.2f" % [res1.get("cost", ""), cores_before, run.bonus_cores, hp_before, run.hp])

	# Case 2: with 0 cores, pays 10% max_hp hull (never killing from low HP).
	run.bonus_cores = 0
	run.hp = run.max_hp
	_game.ctx.run.add_consumable(Consumables.FOREMAN_MEMO)
	var res2: Dictionary = _combat.use_consumable()
	await _sim(1)
	_t.check("foreman_memo pays 10% hull when no core is held",
		res2.get("cost", "") == "hull" and absf((run.max_hp - run.hp) - run.max_hp * 0.10) < 0.05,
		"cost=%s hp=%.2f max=%.2f" % [res2.get("cost", ""), run.hp, run.max_hp])

	# Expire memo and verify ordinary enemies resume cleanly.
	_combat._memo_left = 0.01
	await _sim(3)
	_t.check("foreman_memo unfreezes surviving ordinary enemies on expiry",
		c1.process_mode != Node.PROCESS_MODE_DISABLED and c2.process_mode != Node.PROCESS_MODE_DISABLED)
	for n in [c1, c2, w]:
		if is_instance_valid(n):
			n.queue_free()
	await _sim(2)


func _check_moss_patch() -> void:
	_combat._clear_consumables_runtime()
	_game.ctx.run.clear_consumables()
	var run = _game.ctx.run
	var ball_at: Vector3 = _player.ball_position()
	run.hp = run.max_hp * 0.40
	var hp_before: float = run.hp
	var chaser = _combat.spawn_enemy("chaser", ball_at + Vector3(5.0, 0.0, 0.0))
	await _sim(2)
	var knocks_before: int = chaser.knocks
	_game.ctx.run.add_consumable(Consumables.MOSS_PATCH)
	var res: Dictionary = _combat.use_consumable()
	await _sim(1)
	var healed_ok: bool = absf((run.hp - hp_before) - run.max_hp * 0.35) < 0.05
	var knocked_ok: bool = chaser.knocks > knocks_before and int(res.get("knocked", 0)) >= 1
	# Incoming hit during 1.5 s grace must deal 0 damage.
	var hp_during_grace: float = run.hp
	_combat._on_player_hit(25.0, Vector3(5.0, 0.0, 0.0), "chaser")
	var grace_blocked: bool = is_equal_approx(run.hp, hp_during_grace) and run.consumable_grace_active()
	# After grace expires, hits land again.
	run.consumable_grace_left = 0.0
	_combat._on_player_hit(10.0, Vector3.ZERO, "chaser")
	var post_grace_hit: bool = run.hp < hp_during_grace
	_t.check("moss_patch heals +35%, knocks enemies within 12 m, and grants 1.5 s grace",
		healed_ok and knocked_ok and grace_blocked and post_grace_hit,
		"healed=%s(%.2f) knocked=%s grace=%s post=%s res=%s" % [healed_ok, run.hp - hp_before, knocked_ok, grace_blocked, post_grace_hit, res])
	if is_instance_valid(chaser):
		chaser.queue_free()
	await _sim(2)


func _check_drop_sources_and_shop() -> void:
	_combat._clear_consumables_runtime()
	var run = _game.ctx.run
	run.clear_consumables()
	run.consumable_slots = 1
	var ball_at: Vector3 = _player.ball_position()

	# 1. World drop cradle spawns GLB + auto-collects on roll-through.
	var cradle = _combat.drop_consumable(Consumables.ANCHOR_FLARE, ball_at)
	var cradle_ok: bool = is_instance_valid(cradle) and cradle.patched_surfaces > 0
	await _sim(2)
	_t.check("drop cradle instances GLB with vertex_color_use_as_albedo and auto-collects on roll-through",
		cradle_ok and run.peek_consumable() == Consumables.ANCHOR_FLARE,
		"ok=%s peek=%s belt=%s" % [cradle_ok, run.peek_consumable(), run.consumables])
	run.clear_consumables()

	# 2. High-tier Heft Destructible deterministic drop helper (tiers 1-2 never drop, tiers 3-5 drop deterministically).
	var low_never := true
	var high_drops := 0
	for i in 24:
		if Consumables.roll_for_destructible(42, "r1", 1, "p%d" % i, 1) != "":
			low_never = false
		if Consumables.roll_for_destructible(42, "r1", 1, "p%d" % i, 2) != "":
			low_never = false
		if Consumables.roll_for_destructible(42, "r1", 1, "p%d" % i, 5) != "":
			high_drops += 1
	_t.check("high-tier Heft Destructibles (tiers 3-5) drop consumables deterministically; tiers 1-2 do not",
		low_never and high_drops > 0)

	# 3. Secondary-Counter kill drop (kill-first special Linker always drops on death).
	var drops_before: int = _combat.live_consumable_drops().size()
	var linker = _combat.spawn_enemy("linker", ball_at + Vector3(14.0, 0.0, 0.0))
	await _sim(2)
	linker.take_damage(9999.0)
	await _sim(2)
	_t.check("secondary-counter kill drops a Pocket Consumable cradle",
		_combat.live_consumable_drops().size() > drops_before,
		"drops=%d->%d dead=%s" % [drops_before, _combat.live_consumable_drops().size(), linker.is_dead() if is_instance_valid(linker) else true])

	# 4. Cracked Cache opens and drops a Pocket Consumable once.
	var cache := CrackedCache.new()
	cache.id = "test_cache_cons"
	cache.ctx = _game.ctx
	cache.system = _game.world.interact if _game.world != null and _game.world.get("interact") != null else null
	if cache.system != null:
		_game.ctx.root.add_child(cache)
		cache.global_position = ball_at + Vector3(20.0, 0.0, 0.0)
		cache.build()
		cache.crumble()
		var before_cache_drops: int = _combat.live_consumable_drops().size()
		cache.fire()
		_game.ctx.events.interact_fired.emit(cache.family, cache.id, cache.global_position)
		await _sim(2)
		var after_open_drops: int = _combat.live_consumable_drops().size()
		cache.take(0)
		await _sim(1)
		_t.check("cracked cache drops a Pocket Consumable strictly once on open/take",
			Consumables.is_valid(cache.consumable_dropped) and after_open_drops == before_cache_drops + 1 and _combat.live_consumable_drops().size() == after_open_drops)
		cache.stand_down()
		cache.queue_free()

	# 5. Moss's shop stocks cheap cog cartridges & belt slot expansion without changing SHELF_SIZE == 3.
	var shop: Shop = _build.shop
	run.add_cogs(500)
	shop.enter()
	var shelf_offers: Array = shop.shelf_offers()
	var cons_offers: Array = shop.consumable_offers()
	var belt: Dictionary = shop.belt_offer()
	var buy_belt: Dictionary = shop.buy_belt_slot()
	var buy_c0: Dictionary = shop.buy_consumable(0)
	var buy_c1: Dictionary = shop.buy_consumable(1)
	shop.leave()
	_t.check("Moss's shop keeps 3-tile shelf and sells consumables + 2-slot belt expansion for cogs",
		shelf_offers.size() == Shop.SHELF_SIZE and cons_offers.size() == Shop.CONSUMABLE_STOCK_SIZE
		and bool(belt["can"]) and bool(buy_belt["ok"]) and bool(buy_c0["ok"]) and bool(buy_c1["ok"])
		and run.consumable_capacity() == 2 and run.consumables.size() == 2,
		"shelf=%d cons=%d belt=%s buy_belt=%s c0=%s c1=%s cap=%d held=%s" % [shelf_offers.size(), cons_offers.size(), belt, buy_belt, buy_c0, buy_c1, run.consumable_capacity(), run.consumables])

	# 6. RewardGate recognizes consumable & belt offers cleanly.
	var g_rec := Consumables.gate_record(Consumables.OFFER_PREFIX + Consumables.CAP_CHARGE)
	var b_rec := Consumables.gate_record(Consumables.BELT_OFFER_ID)
	_t.check("reward gate offer records build cleanly for cartridges and pocket belt",
		Consumables.is_offer(Consumables.BELT_OFFER_ID) and g_rec["icon"] == "cons_cap_charge" and b_rec["name"] == "Pocket Belt")
	run.clear_consumables()


func _check_catalyst_cartridge_hook() -> void:
	_combat._clear_consumables_runtime()
	_game.ctx.run.clear_consumables()
	# W47-C2 integration: popping a Pocket Consumable emits events.consumable_used,
	# waking catalyst_cartridge for +40% Active charge and free burst ring.
	var rack = _combat.actives
	if rack == null:
		_t.check("catalyst_cartridge hook skipped (no active rack)", false)
		return
	var first_active: String = String(rack.rows().keys()[0])
	rack.rack(first_active, false)
	rack.charges = 0
	rack.progress = 0.20
	_game.ctx.run.parts.assign(["battery_cell", "coil_tap"])
	_build.effects.refresh(_game.ctx.run.parts)
	_game.ctx.run.add_consumable(Consumables.MOSS_PATCH)
	var events_before: int = _used_events.size()
	var cross_before: int = _combat.cross_synergy_count("catalyst_cartridge")
	_combat.use_consumable()
	await _sim(2)
	_t.check("events.consumable_used wires W47-C2 catalyst_cartridge (+40% Active charge)",
		_used_events.size() == events_before + 1
		and _combat.cross_synergy_count("catalyst_cartridge") == cross_before + 1
		and absf(rack.progress - 0.60) < 0.02,
		"events=%d->%d cross=%d->%d progress=%.3f" % [events_before, _used_events.size(), cross_before, _combat.cross_synergy_count("catalyst_cartridge"), rack.progress])


func _check_cleanup_and_reset() -> void:
	_game.ctx.run.add_consumable(Consumables.ANCHOR_FLARE)
	_combat.use_consumable()
	_combat.drop_consumable(Consumables.CAP_CHARGE, _player.ball_position() + Vector3(8.0, 0.0, 0.0))
	await _sim(2)
	_combat._start_attempt()
	await _sim(2)
	_t.check("attempt boundary clears active balloons, drops, and consumable timers",
		_combat.active_balloons().is_empty() and _combat.live_consumable_drops().is_empty()
		and _combat.nitro_siphon_left() == 0.0 and _combat.overclock_card_left() == 0.0 and _combat.foreman_memo_left() == 0.0)
