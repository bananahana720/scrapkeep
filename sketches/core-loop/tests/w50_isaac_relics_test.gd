extends SceneTree

# W50-ISAAC-RELICS verification suite:
# Exercises all 6 new World 1 symmetry kit-swap relics (9 -> 15 W1 swaps) and all 6 new
# World 2 & World 3 transformational kit-swap / RoR2 Survivor Alternate Loadout relics,
# undo/duplicate guards, anti-loop bounds (proc depth 1, single repeat, zero movement lockout,
# zero HAZARD player colour), lifecycle resets, and planted negative controls.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const Grip := preload("res://src/movement/grip.gd")
const Palette := preload("res://src/core/palette.gd")
const Parts := preload("res://src/build/parts.gd")
const Relics := preload("res://src/build/relics.gd")
const RelicSwaps := preload("res://src/combat/relic_swaps.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

const W1_NEW := ["arc_sling", "voltaic_ring", "fan_cylinder", "drill_auger", "thermite_dive", "zip_cluster"]
const W23_NEW := ["wrecking_chain", "tape_loop", "siege_mortar", "halo_coil", "slotted_rail", "updraft_snare"]

var _t := T.new("w50_isaac_relics_test")
var _game
var _combat
var _player
var _swaps
var _source := Intent.Scripted.new()
var _steps: Array = []
var _index := 0
var _ticks := 0
var _booted := false
var _struck: Array = []


func _initialize() -> void:
	_check_table_and_controls()
	_check_anti_loop_guards()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _booted:
		_boot()
		return false
	if _index >= _steps.size():
		quit(_t.verdict())
		return true
	var step: Array = _steps[_index]
	if _ticks == 0:
		(step[0] as Callable).call()
	_ticks += 1
	if _ticks >= int(step[1]):
		(step[2] as Callable).call()
		_index += 1
		_ticks = 0
	return false


func _boot() -> void:
	_booted = true
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_player = _game.player
	_swaps = _combat.relic_swaps
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float):
		if is_instance_valid(enemy):
			_struck.append([enemy.get_instance_id(), kind, force]))
	_steps = [
		[_noop, 1, _check_undo_and_duplicate_guards],
		[_noop, 1, _check_arc_sling],
		[_noop, 1, _check_voltaic_ring],
		[_noop, 1, _check_fan_cylinder],
		[_noop, 1, _check_drill_auger],
		[_noop, 1, _check_thermite_dive],
		[_noop, 1, _check_zip_cluster],
		[_noop, 1, _check_wrecking_chain],
		[_noop, 1, _check_tape_loop],
		[_noop, 1, _check_siege_mortar],
		[_noop, 1, _check_halo_coil],
		[_noop, 1, _check_slotted_rail],
		[_noop, 1, _check_updraft_snare],
		[_noop, 1, _check_resets],
	]


func _noop() -> void:
	pass


# --- 1. Table, Symmetry, RoR2 Loadouts & Planted Negative Controls ---------------------

func _check_table_and_controls() -> void:
	_t.eq("full relic table validates (ROWS + ALT_ROWS)", Relics.validate(), [])
	_t.eq("alt swap relic table validates cleanly", Relics.validate_alt(), [])
	_t.eq("12 new W50 kit-swap relics registered in ALT_ROWS", Relics.ALT_ROWS.size(), 12)
	_t.eq("World 1 total kit swaps raised 9 -> 15", Relics.swap_ids(1).size(), 15)
	_t.eq("World 2 & 3 transformational alt loadouts count", Relics.alt_loadouts().size(), 6)
	# Symmetry check: every pilot has >= 2 W1 swaps and exactly 1 W2/W3 alt loadout.
	for pilot in Relics.PILOTS:
		var w1_swaps: Array = Relics.swap_ids(1).filter(func(id): return Relics.fits(id, pilot))
		var alt_loadout: Array = Relics.alt_loadouts(pilot)
		_t.check("%s has >= 2 W1 swaps and 1 W2/W3 alt loadout" % pilot,
			w1_swaps.size() >= 2 and alt_loadout.size() == 1,
			"w1=%s alt=%s" % [w1_swaps, alt_loadout])
	for id in W1_NEW + W23_NEW:
		var r := Relics.row(id)
		var swap := Relics.swap_of(id)
		var name_words := String(r["name"]).split(" ", false).size()
		var text_words := String(r["text"]).split(" ", false).size()
		var slot := String(r["slot"])
		var icon := String(AbilityState.ABILITIES.get(swap, {}).get("icon", ""))
		_t.check("%s data, words, icon suffix, part_row valid" % id,
			Relics.has(id) and Relics.is_relic(Relics.part_of(id))
			and name_words >= 1 and name_words <= Relics.MAX_NAME_WORDS
			and text_words >= 1 and text_words <= Relics.MAX_TEXT_WORDS
			and int(r["world"]) in [1, 2, 3]
			and String(r["maker"]) in Relics.VALID_MAKERS
			and AbilityState.ABILITIES.has(swap)
			and ClassKit.WORDS.has(swap)
			and icon.ends_with(String(Relics.SUFFIX[slot]))
			and not ("PAID" in String(r["text"]))
			and not ("bodies" in String(r["text"]))
			and Parts.def(Relics.part_of(id)).rarity == "relic",
			"%s -> %s (%s)" % [id, swap, icon])
	# Verify tape_loop specifically carries zero PAID slop in name, text, or ClassKit words.
	var tape := Relics.row("tape_loop")
	_t.check("tape_loop has zero PAID slop",
		not ("PAID" in String(tape["name"])) and not ("PAID" in String(tape["text"]))
		and not ("PAID" in String(ClassKit.WORDS["ledger_echo"])), str(tape))
	# Planted negative controls: every invalid mutation MUST be refused.
	var bad_ult := Relics.all_rows().duplicate(true)
	bad_ult["arc_sling"]["slot"] = AbilityState.ULTIMATE
	_t.check("planted ultimate slot relic refused", not Relics.validate(bad_ult).is_empty(), str(Relics.validate(bad_ult)))

	var bad_words := Relics.all_rows().duplicate(true)
	bad_words["voltaic_ring"]["text"] = "one two three four five six seven eight nine"
	_t.check("planted 9-word text refused", not Relics.validate(bad_words).is_empty(), str(Relics.validate(bad_words)))

	var bad_name := Relics.all_rows().duplicate(true)
	bad_name["fan_cylinder"]["name"] = "One Two Three Four"
	_t.check("planted 4-word name refused", not Relics.validate(bad_name).is_empty(), str(Relics.validate(bad_name)))

	var bad_maker := Relics.all_rows().duplicate(true)
	bad_maker["drill_auger"]["maker"] = "unknown_forge"
	_t.check("planted invalid maker refused", not Relics.validate(bad_maker).is_empty(), str(Relics.validate(bad_maker)))

	var bad_world := Relics.all_rows().duplicate(true)
	bad_world["siege_mortar"]["world"] = 4
	_t.check("planted out-of-range world refused", not Relics.validate(bad_world).is_empty(), str(Relics.validate(bad_world)))

	var bad_suffix := Relics.all_rows().duplicate(true)
	bad_suffix["halo_coil"]["slot"] = AbilityState.WEAPON
	_t.check("planted mismatched icon suffix/slot refused", not Relics.validate(bad_suffix).is_empty(), str(Relics.validate(bad_suffix)))

	var bad_alt_cd := Relics.ALT_ROWS.duplicate(true)
	bad_alt_cd["tape_loop"]["cooldown"] = 0.7
	_t.check("planted cooldown scalar on alt swap refused by validate_alt", not Relics.validate_alt(bad_alt_cd).is_empty(), str(Relics.validate_alt(bad_alt_cd)))

	# Player colour safety guard + planted HAZARD control.
	_t.check("planted HAZARD player colour rejected", not RelicSwaps.player_color_safe(Palette.HAZARD), "")
	for c in [ClassDef.SABLE_COLOR, ClassDef.RIVET_COLOR, ClassDef.KEST_COLOR, ClassDef.TARN_COLOR,
			ClassDef.TALLY_COLOR, ClassDef.CANNON_COLOR, Palette.BRASS, Palette.COPPER, Palette.AMBER, Palette.LEDGER_CREAM]:
		_t.check("player colour safe", RelicSwaps.player_color_safe(c), str(c))


# --- 2. Anti-Loop Bounds & Planted Looping Controls ------------------------------------

func _check_anti_loop_guards() -> void:
	_t.check("voltaic_follows: weapon blazing only",
		RelicSwaps.voltaic_follows("weapon", "arc_ring", true)
		and not RelicSwaps.voltaic_follows("item_proc", "arc_ring", true)
		and not RelicSwaps.voltaic_follows("weapon", "arc_ring", false)
		and not RelicSwaps.voltaic_follows("weapon", "", true), "")
	_t.check("fan_burst_follows: weapon only",
		RelicSwaps.fan_burst_follows("weapon", "fan_burst")
		and not RelicSwaps.fan_burst_follows("item_proc", "fan_burst")
		and not RelicSwaps.fan_burst_follows("weapon", ""), "")
	_t.check("tape_echo_follows: weapon only",
		RelicSwaps.tape_echo_follows("weapon", "ledger_echo")
		and not RelicSwaps.tape_echo_follows("item_proc", "ledger_echo")
		and not RelicSwaps.tape_echo_follows("weapon", ""), "")
	_t.check("thermite_follows: glide slam only",
		RelicSwaps.thermite_follows("drop_or_slam", "thermite_slam", true)
		and not RelicSwaps.thermite_follows("item_proc", "thermite_slam", true)
		and not RelicSwaps.thermite_follows("drop_or_slam", "thermite_slam", false), "")
	_t.check("auger_follows: slam only",
		RelicSwaps.auger_follows("drop_or_slam", "auger_slam")
		and not RelicSwaps.auger_follows("item_proc", "auger_slam"), "")
	# Planted runaway loop control: item_proc stops at 1, weapon tag would loop past 1.
	_t.eq("real tape echo chain stops at 1", _echo_chain(5, "item_proc"), 1)
	_t.check("planted weapon-tagged echo loops and is caught", _echo_chain(5, "weapon") > 1, "depth=%d" % _echo_chain(5, "weapon"))
	_t.eq("real fan burst chain stops at 1", _fan_chain(5, "item_proc"), 1)
	_t.check("planted weapon-tagged fan loops and is caught", _fan_chain(5, "weapon") > 1, "depth=%d" % _fan_chain(5, "weapon"))


func _echo_chain(depth: int, next_tag: String) -> int:
	var n := 0
	var src := "weapon"
	for _i in depth:
		if not RelicSwaps.tape_echo_follows(src, "ledger_echo"):
			break
		n += 1
		src = next_tag
	return n


func _fan_chain(depth: int, next_tag: String) -> int:
	var n := 0
	var src := "weapon"
	for _i in depth:
		if not RelicSwaps.fan_burst_follows(src, "fan_burst"):
			break
		n += 1
		src = next_tag
	return n


# --- Helpers ---------------------------------------------------------------------------

func _as_pilot(pilot_id: String) -> void:
	var def: Resource = ClassDef.by_id(pilot_id)
	_game.run.class_def = def
	_player.fit_class(def)
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()
	_source.hold = {}
	_source.press = {}
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at
	_player.kit.drop_line("reset")
	_player.chain.reset()
	_player.abilities.refill()
	_combat.bolts.clear()
	_combat.sticky.clear()
	_combat._reset_cards()
	_combat._free_cannon()
	_swaps.reset(true)
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_game.camera.pitch = 0.0
	_struck.clear()


func _equip(slot: String, ability_id: String) -> void:
	_player.abilities.swap(slot, ability_id)
	_player._refit()


func _spawn(kind: String, flat: Vector3, hp := 100000.0) -> Node3D:
	var ground: float = _game.ctx.terrain.height(flat.x, flat.z)
	var enemy: Node3D = _combat.spawn_enemy(kind, Vector3(flat.x, ground + 1.5, flat.z))
	enemy.max_hp = hp
	enemy.hp = hp
	enemy.set_physics_process(false)
	return enemy


func _ball_flat() -> Vector3:
	var b: Vector3 = _player.ball_position()
	return Vector3(b.x, 0.0, b.z)


func _aim_flat() -> Vector3:
	return _combat._flat_aim()


func _step_swaps(ticks: int, dt := 1.0 / 60.0) -> void:
	for _i in ticks:
		var enemies: Array = _game.get_tree().get_nodes_in_group("enemy")
		_swaps.step(dt, enemies)


# --- 3. Undo & Duplicate Guards --------------------------------------------------------

func _check_undo_and_duplicate_guards() -> void:
	_as_pilot("pylon_engineer")
	var run = _game.ctx.run
	var abilities = _player.abilities
	run.parts.clear()
	_game.ctx.build.sync_relics()
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	_t.eq("Sable starts on bank_shot", abilities.id_of(AbilityState.LINE), "bank_shot")
	run.add_part(Relics.part_of("arc_sling"), "cache")
	_t.eq("arc_sling swaps LINE slot to bank_arc", abilities.id_of(AbilityState.LINE), "bank_arc")
	var held := Relics.held(run.parts)
	_t.check("one-per-slot blocks another LINE relic while arc_sling held",
		not Relics.can_hold("pit_coil", "pylon_engineer", held)
		and not ("pit_coil" in Relics.eligible("pylon_engineer", held, null, 0, true))
		and ("voltaic_ring" in Relics.eligible("pylon_engineer", held, null, 1, true)),
		"held=%s" % [held])
	# Duplicate part in same slot never overrides the first held relic.
	run.parts.append(Relics.part_of("pit_coil"))
	_t.eq("Relics.held keeps first relic in slot", Relics.held(run.parts)[AbilityState.LINE], "arc_sling")
	_game.flow.retry_stage()
	_t.eq("retry undoes arc_sling and restores bank_shot", abilities.id_of(AbilityState.LINE), "bank_shot")
	_t.check("retry empties held relics", Relics.held(run.parts).is_empty(), str(Relics.held(run.parts)))


# --- 4. W1 Relics (6) ------------------------------------------------------------------

func _check_arc_sling() -> void:
	_as_pilot("pylon_engineer")
	var aim := _aim_flat()
	var anchor := _ball_flat() + aim * 10.0 + Vector3.UP * 2.0
	var mid_enemy := _spawn("chaser", _ball_flat() + aim * 5.0)
	_equip(AbilityState.LINE, "bank_arc")
	_player.grapple_to(anchor, Vector3.UP, null)
	_combat._fire_line_skill("bank_arc", 1.0)
	_t.eq("bank_arc leaves 1 live conductive chord", _swaps._arc_chords.size(), 1)
	_t.check("chord colour is player-safe (never HAZARD)", RelicSwaps.player_color_safe(_swaps._arc_chords[0]["color"]), "")
	var before := _struck.size()
	_step_swaps(20)
	_t.check("conductive chord zaps enemy along swing chord", _struck.size() > before and int(_swaps._arc_chords[0]["hits"]) > 0,
		"hits=%d" % int(_swaps._arc_chords[0]["hits"]))
	# Planted control: plain bank_shot leaves zero chord arcs.
	_as_pilot("pylon_engineer")
	_player.grapple_to(anchor, Vector3.UP, null)
	_combat._fire_line_skill("bank_shot", 1.0)
	_t.eq("planted: plain bank_shot leaves no chord arc", _swaps._arc_chords.size(), 0)
	if is_instance_valid(mid_enemy):
		mid_enemy.queue_free()


func _check_voltaic_ring() -> void:
	_as_pilot("pylon_engineer")
	_equip(AbilityState.WEAPON, "arc_ring")
	_t.eq("arc_ring resolves pattern to arc_caster", _combat.active_weapon(), "arc_caster")
	var aim := _aim_flat()
	var target := _spawn("chaser", _ball_flat() + aim * 6.0)
	# Walk speed -> no halo (planted control).
	_player.state.velocity = Vector3.ZERO
	_combat._fire(_combat.active_weapon(), "weapon", {})
	_t.eq("planted: walking shot spawns no voltaic halo", _swaps._halos.size(), 0)
	# Blazing speed -> spawns brass conductive halo!
	var blazing_speed: float = _player.tuning.f("cruise") * SpeedTier.MULTIPLES[SpeedTier.BLAZING] + 2.0
	_player.state.velocity = aim * blazing_speed
	var vel_before: Vector3 = _player.state.velocity
	_combat._fire(_combat.active_weapon(), "weapon", {})
	_t.eq("Blazing shot spawns 1 brass halo", _swaps._halos.size(), 1)
	_t.eq("halo colour is brass (never HAZARD)", _swaps._halos[0]["color"], Palette.BRASS)
	_t.check("ball velocity untouched", _player.state.velocity == vel_before, "")
	var hits_before := _struck.filter(func(s): return s[0] == target.get_instance_id()).size()
	_step_swaps(35)
	var hits_after := _struck.filter(func(s): return s[0] == target.get_instance_id()).size()
	_t.eq("expanding halo strikes target exactly once", hits_after - hits_before, 1)
	# item_proc fire spawns no halo.
	_swaps._halos.clear()
	_combat._fire(_combat.active_weapon(), "item_proc", {"blazing": true})
	_t.eq("item_proc volley spawns no halo", _swaps._halos.size(), 0)


func _check_fan_cylinder() -> void:
	_as_pilot("runner_gunner")
	_equip(AbilityState.WEAPON, "fan_burst")
	_t.eq("fan_burst resolves pattern to rapid_laser", _combat.active_weapon(), "rapid_laser")
	var vel_before: Vector3 = _player.state.velocity
	_combat.bolts.clear()
	_combat._fire(_combat.active_weapon(), "weapon", {})
	_t.eq("round 1 queues 2 staggered follow-up rounds (3 total)", _swaps._fan_queue.size(), 2)
	_step_swaps(10)
	_t.eq("all 3 rounds fired (1 weapon + 2 item_proc)", _combat.bolts._bolts.size(), 3)
	var procs: Array = _combat.bolts._bolts.filter(func(b): return b["source"] == "item_proc" and int(b["bits"]) == 0)
	_t.eq("2 staggered follow-ups are item_proc with bits=0", procs.size(), 2)
	# Round 6 amplified ricochet!
	_combat.bolts.clear()
	_combat._fire(_combat.active_weapon(), "weapon", {"sixth_hot": true})
	_t.check("round 6 flags sixth_ricochet", bool(_swaps.last_swap.get("sixth_ricochet", false)), str(_swaps.last_swap))
	_step_swaps(12)
	var ricochets: Array = _combat.bolts._bolts.filter(func(b): return int(b.get("extra_bounces", 0)) == RelicSwaps.FAN_SIXTH_BOUNCES)
	_t.eq("round 6 fires amplified ricochet bolt", ricochets.size(), 1)
	_t.check("ball velocity untouched", _player.state.velocity == vel_before, "")
	# Planted control: item_proc fire queues zero fan rounds.
	_swaps._fan_queue.clear()
	_combat._fire(_combat.active_weapon(), "item_proc", {})
	_t.eq("planted: item_proc fire queues zero fan rounds", _swaps._fan_queue.size(), 0)


func _check_drill_auger() -> void:
	_as_pilot("runner_gunner")
	_equip(AbilityState.SMASH, "auger_slam")
	_t.eq("auger_slam keeps skid flavour", _player.kit.smash_flavour, "skid")
	var target := _spawn("chaser", _ball_flat() + _aim_flat() * 2.0)
	var vel_before: Vector3 = _player.state.velocity
	_game.events.skid_smashed.emit(_player.ball_position(), 1)
	_t.eq("drill_auger creates 1 spinning shred crater", _swaps._augers.size(), 1)
	_t.eq("drill_auger records +1 heft tier breach", int(_swaps.last_swap.get("tier_bonus", 0)), 1)
	_t.check("ball velocity untouched", _player.state.velocity == vel_before, "")
	var before := _struck.filter(func(s): return s[0] == target.get_instance_id()).size()
	_step_swaps(60)
	var after := _struck.filter(func(s): return s[0] == target.get_instance_id()).size()
	_t.check("auger crater ticks spinning shred hits", after > before, "before=%d after=%d" % [before, after])
	# Planted control: plain shockwave_skid creates zero auger craters.
	_as_pilot("runner_gunner")
	_game.events.skid_smashed.emit(_player.ball_position(), 1)
	_t.eq("planted: plain shockwave_skid creates no auger", _swaps._augers.size(), 0)


func _check_thermite_dive() -> void:
	_as_pilot("demolitions_caster")
	_equip(AbilityState.SMASH, "thermite_slam")
	_t.eq("thermite_slam keeps demo flavour", _player.kit.smash_flavour, "demo")
	var aim := _aim_flat()
	var at: Vector3 = _player.ball_position()
	# Plant one charge within 14 m and one beyond 14 m.
	var near_c: Dictionary = _combat.sticky.drop(at + aim * 8.0, 15.0, 3.0, 10.0, 0.0, 0.0, _combat._clock - 1.0)
	var far_c: Dictionary = _combat.sticky.drop(at + aim * 20.0, 15.0, 3.0, 10.0, 0.0, 0.0, _combat._clock - 1.0)
	near_c["_source"] = "weapon"
	far_c["_source"] = "weapon"
	# Planted control: non-glide slam ignites no seam and leaves charges alone.
	_swaps._glide_left = 0.0
	_player.kit.gliding = false
	_player.air_draw_active = false
	_game.events.demo_slammed.emit(at)
	_t.eq("planted: non-glide slam ignites no thermite seam", _swaps._seams.size(), 0)
	_t.check("planted: non-glide slam leaves near charge stuck", _combat.sticky.charges.has(near_c), "")
	# Glide-hang slam ignites seam and auto-detonates charge within 14 m, leaving 20 m charge intact!
	var vel_before: Vector3 = _player.state.velocity
	_player.air_draw_active = true
	_game.events.demo_slammed.emit(at)
	_player.air_draw_active = false
	_t.eq("glide slam ignites 1 incendiary seam", _swaps._seams.size(), 1)
	_t.eq("auto-detonated stuck charge in 14 m", int(_swaps.last_swap.get("detonated", 0)), 1)
	_t.check("near charge detonated, far 20 m charge untouched",
		not _combat.sticky.charges.has(near_c) and _combat.sticky.charges.has(far_c), "")
	_t.check("ball velocity untouched", _player.state.velocity == vel_before, "")


func _check_zip_cluster() -> void:
	_as_pilot("demolitions_caster")
	_equip(AbilityState.LINE, "cable_cluster")
	var anchor := _ball_flat() + _aim_flat() * 16.0 + Vector3.UP * 2.0
	_player.grapple_to(anchor, Vector3.UP, null)
	_combat.sticky.clear()
	_combat._fire_line_skill("cable_cluster", 1.0)
	var clusters: Array = _combat.sticky.charges.filter(func(c): return bool(c.get("_cluster", false)))
	_t.eq("zip_cluster drops 3 micro-charges along wire", clusters.size(), 3)
	_t.check("all 3 cluster charges are item_proc", clusters.all(func(c): return c.get("_source", "") == "item_proc"), "")
	# Verify spacing along wire (distinct positions).
	var d01: float = (clusters[0]["pos"] as Vector3).distance_to(clusters[1]["pos"] as Vector3)
	var d12: float = (clusters[1]["pos"] as Vector3).distance_to(clusters[2]["pos"] as Vector3)
	_t.check("micro-charges are spaced along wire", d01 > 2.0 and d12 > 2.0, "d01=%.2f d12=%.2f" % [d01, d12])


# --- 5. W2 & W3 Transformational Relics / RoR2 Alternate Loadouts (6) ------------------

func _check_wrecking_chain() -> void:
	_as_pilot("tarn")
	_equip(AbilityState.LINE, "claw_whirl")
	var at := _ball_flat()
	var grabbed := _spawn("swarm_remnant", at + Vector3(5.0, 0.0, 0.0))
	var bystander := _spawn("swarm_remnant", at + Vector3(0.0, 0.0, 5.0))
	var heavy := _spawn("chaser", at + Vector3(-5.0, 0.0, 0.0))
	var vel_before: Vector3 = _player.state.velocity
	var start_pos := grabbed.global_position
	_player.grapple_to(grabbed.global_position, Vector3.UP, grabbed)
	_combat._fire_line_skill("claw_whirl", 1.0)
	_t.eq("claw_whirl starts 180 deg bowling whip on movable enemy", _swaps._whirls.size(), 1)
	_step_swaps(35)
	_t.eq("whirl completes cleanly", _swaps._whirls.size(), 0)
	var end_vec := Vector2(grabbed.global_position.x - at.x, grabbed.global_position.z - at.z)
	var start_vec := Vector2(start_pos.x - at.x, start_pos.z - at.z)
	_t.check("grabbed machine whipped ~180 degrees around ball",
		start_vec.normalized().dot(end_vec.normalized()) < -0.9,
		"dot=%.3f" % start_vec.normalized().dot(end_vec.normalized()))
	_t.check("bystander bowled during arc", _struck.any(func(s): return s[0] == bystander.get_instance_id()), "")
	_t.check("ball velocity untouched", _player.state.velocity == vel_before, "")
	# Planted control: heavy machine (heft > ball heft) is NOT whipped.
	_player.grapple_to(heavy.global_position, Vector3.UP, heavy)
	_combat._fire_line_skill("claw_whirl", 1.0)
	_t.eq("planted: heavy machine is not whipped", _swaps._whirls.size(), 0)


func _check_tape_loop() -> void:
	_as_pilot("tally")
	_equip(AbilityState.WEAPON, "ledger_echo")
	var target := _spawn("chaser", _ball_flat() + _aim_flat() * 5.0)
	_player.abilities.slot(AbilityState.WEAPON).charges = 3
	var cast_ok: bool = _combat._run_balance(target.global_position, true, {}, "weapon")
	_t.check("ledger_echo casts Balance Due", cast_ok, "")
	_t.eq("queues exactly 1 splice echo at 0.3 s", _swaps._tape_echoes.size(), 1)
	_t.near("echo delay is 0.3 s", float(_swaps._tape_echoes[0]["left"]), 0.3, 0.001)
	var charges_after_cast: int = _player.abilities.slot(AbilityState.WEAPON).charges
	var hits_before := _struck.filter(func(s): return s[0] == target.get_instance_id()).size()
	# 0.2 s -> echo not yet landed.
	_step_swaps(12)
	_t.eq("echo has not fired early at 0.2 s", _swaps._tape_echoes.size(), 1)
	# +0.15 s -> echo lands once!
	_step_swaps(10)
	var hits_after := _struck.filter(func(s): return s[0] == target.get_instance_id()).size()
	_t.eq("echo landed once and queue is empty (no loop)", [_swaps._tape_echoes.size(), hits_after - hits_before], [0, 1])
	_t.eq("echo spends zero extra pressure", _player.abilities.slot(AbilityState.WEAPON).charges, charges_after_cast)
	# Planted control: plain ledger_reader queues zero echoes.
	_equip(AbilityState.WEAPON, "ledger_reader")
	_combat._run_balance(target.global_position, true, {}, "weapon")
	_t.eq("planted: plain ledger_reader queues no echo", _swaps._tape_echoes.size(), 0)


func _check_siege_mortar() -> void:
	_as_pilot("remembered_cannon")
	_equip(AbilityState.SPECIAL, "cannon_mortar")
	var vel_before: Vector3 = _player.state.velocity
	var row: Dictionary = _combat._specials["cannon_mortar"]
	var shape: Dictionary = row["geometry"].call(1.0)
	_t.eq("siege_mortar draws committed ring geometry", shape["kind"], "ring")
	row["fire"].call(1.0, shape)
	_t.eq("shell 1 commits immediately, 2 staggered shells queued", [_combat._cannon.size(), _swaps._mortars.size()], [1, 2])
	_step_swaps(40)
	_t.eq("all 3 barrage shells committed", _combat._cannon.size(), 3)
	var sources: Array = _combat._cannon.map(func(e): return e["source"])
	_t.eq("shell 1 is special, shells 2-3 are item_proc", sources, ["special", "item_proc", "item_proc"])
	var all_safe: bool = _combat._cannon.all(func(e): return RelicSwaps.player_color_safe(e["hazards"][0].color))
	_t.check("all mortar hazards use player-safe colour (never HAZARD)", all_safe, "")
	_t.check("ball velocity untouched", _player.state.velocity == vel_before, "")


func _check_halo_coil() -> void:
	_as_pilot("pylon_engineer")
	_equip(AbilityState.SPECIAL, "halo_discharge")
	var target := _spawn("chaser", _ball_flat() + Vector3(RelicSwaps.ORBIT_RADIUS, 0.0, 0.0))
	var vel_before: Vector3 = _player.state.velocity
	var row: Dictionary = _combat._specials["halo_discharge"]
	var shape: Dictionary = row["geometry"].call(0.5)
	row["fire"].call(0.5, shape)
	_t.check("halo_discharge activates orbiting lightning perimeter", not _swaps._orbit_halo.is_empty(), "")
	var before := _struck.filter(func(s): return s[0] == target.get_instance_id()).size()
	_step_swaps(45)
	var after := _struck.filter(func(s): return s[0] == target.get_instance_id()).size()
	_t.check("orbiting lightning perimeter zaps enemy on perimeter", after > before and int(_swaps._orbit_halo.get("hits", 0)) > 0,
		"before=%d after=%d" % [before, after])
	_t.check("ball velocity untouched", _player.state.velocity == vel_before, "")


func _check_slotted_rail() -> void:
	_as_pilot("runner_gunner")
	_equip(AbilityState.LINE, "rail_vault")
	# Simulate partially spent cylinder before haul.
	_combat.weapon_driver.step(0.0, null, Weapons.RAPID_LASER, _combat._patterns[Weapons.RAPID_LASER], 0.0)
	_combat.weapon_driver._chamber = 1
	_combat.weapon_driver._hot_rounds = 0
	var anchor := _ball_flat() + _aim_flat() * 14.0 + Vector3.UP * 1.5
	_player.grapple_to(anchor, Vector3.UP, null)
	_combat.bolts.clear()
	_combat._fire_line_skill("rail_vault", 1.0)
	_t.eq("slotted_rail auto-reloads full hot cylinder (6/6 hot)",
		[_combat.weapon_driver._mag, _combat.weapon_driver._chamber, _combat.weapon_driver._hot_rounds],
		[6, 6, 6])
	_t.eq("queues 4 rail haul sparks", _swaps._rail_sparks.size(), RelicSwaps.RAIL_SPARK_COUNT)
	_step_swaps(45)
	_t.eq("all 4 sparks fired as item_proc bolts with bits=0",
		_combat.bolts._bolts.filter(func(b): return b["source"] == "item_proc" and int(b["bits"]) == 0).size(),
		RelicSwaps.RAIL_SPARK_COUNT)


func _check_updraft_snare() -> void:
	_as_pilot("demolitions_caster")
	_equip(AbilityState.SPECIAL, "snare_detonate")
	var aim := _aim_flat()
	var light := _spawn("swarm_remnant", _ball_flat() + aim * 6.0)
	var heavy := _spawn("chaser", _ball_flat() + aim * 8.0)
	var light_y_before: float = light.global_position.y
	var heavy_y_before: float = heavy.global_position.y
	var vel_before: Vector3 = _player.state.velocity
	_player.air_draw_left = 0.0
	var row: Dictionary = _combat._specials["snare_detonate"]
	var shape: Dictionary = row["geometry"].call(1.0)
	row["fire"].call(1.0, shape)
	_t.check("light machine launched into apex trap (+5.5 m)",
		light.global_position.y >= light_y_before + RelicSwaps.SNARE_APEX_LIFT - 0.1 and not _swaps._snares.is_empty(),
		"y %.2f -> %.2f" % [light_y_before, light.global_position.y])
	_t.check("heavy machine is NOT snared", absf(heavy.global_position.y - heavy_y_before) < 0.1,
		"y %.2f -> %.2f" % [heavy_y_before, heavy.global_position.y])
	_t.check("snare refreshes Kest Air-Draw", _player.air_draw_left > 0.5, "air_draw=%.2f" % _player.air_draw_left)
	_t.check("ball velocity untouched", _player.state.velocity == vel_before, "")
	_step_swaps(100)
	_t.eq("apex trap expires cleanly", _swaps._snares.size(), 0)


# --- 6. Reset Cleanliness --------------------------------------------------------------

func _check_resets() -> void:
	_as_pilot("tally")
	_equip(AbilityState.WEAPON, "ledger_echo")
	_swaps._tape_echoes.append({"point": Vector3.ZERO, "damage": 10.0, "left": 0.3, "color": ClassDef.TALLY_COLOR})
	_swaps._arc_chords.append({"from": Vector3.ZERO, "to": Vector3.FORWARD, "width": 2.0, "damage": 5.0, "left": 2.0, "tick": 0.2, "color": ClassDef.SABLE_COLOR, "hits": 0})
	_game.events.player_died.emit()
	_t.check("player_died clears all transient swap state",
		_swaps._tape_echoes.is_empty() and _swaps._arc_chords.is_empty() and _swaps._orbit_halo.is_empty(), "")
	_swaps._mortars.append({"at": Vector3.ZERO, "damage": 10.0, "source": "item_proc", "left": 0.2})
	_game.events.stage_content_cleared.emit("retry")
	_t.check("stage_content_cleared clears all transient swap state", _swaps._mortars.is_empty(), "")
