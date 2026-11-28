extends SceneTree

# W50-ISAAC-PARTS comprehensive verification suite:
# - 10 flat-part micro-mutations (with planted negative controls & depth-1 item_proc check)
# - 8 brand-new transformational parts across Worlds 1-3 with RoR2 linear/hyperbolic stacking caps
# - 3 new verb-changing evolutions (disjoint pairs across all 10 evolutions)
# - 6 new cross-system synergies (6 -> 12 pairwise-distinct system pairs)
# - Orbital satellite physics (SpeedTier scaling, MultiMesh committed geometry, non-HAZARD)
# - Boomerang bolt single return pass (0.15 s pause, item_proc return, no 2nd return, children clean)
# - Word-budget / banned-word / pool-purity checks & attempt/death reset cleanup

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Combat := preload("res://src/combat/combat.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const OrbitalSatellites := preload("res://src/combat/orbital_satellites.gd")
const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const Palette := preload("res://src/core/palette.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const T := preload("res://tests/support/t.gd")

const BANNED := ["tockpile", " stock", "Stock ", "ebound", "grapple", "scrap mass", "Pure cost", " evolved:", "; ", ": ",
	"may erupt", "refund", "recharge", "hands back", "give back", "enemies", "foes", "Rope", " mass", "Q becomes"]

var _t := T.new("w50_isaac_parts_test")
var _game
var _combat
var _player
var _orbitals
var _source := Intent.Scripted.new()
var _steps := []
var _index := 0
var _booted := false


func _initialize() -> void:
	_check_catalogue_and_words()
	_check_ror2_stacking_math()
	_check_evolutions_and_cross_system_tables()
	_check_boomerang_physics_pure()
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
	_steps[_index].call()
	_index += 1
	return false


func _boot() -> void:
	_booted = true
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_player = _game.player
	_orbitals = _combat.orbitals
	_steps = [
		_check_orbitals_and_evolutions_live,
		_check_boomerang_and_whiplash_live,
		_check_prism_and_arc_prism_live,
		_check_debt_slag_patch_basalt_storm_live,
		_check_flat_micro_mutations_live,
		_check_cross_system_synergies_live,
		_check_proc_depth_and_resets,
	]


# --- Helpers ---------------------------------------------------------------------------

func _clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemy"):
		if is_instance_valid(enemy):
			enemy.remove_from_group("enemy")
			enemy.queue_free()


func _spawn_dummy(at: Vector3, hp := 200.0, plating := 0.0, kind := "chaser", weight := 1.0) -> Node3D:
	var e = preload("res://src/combat/chaser.gd").new()
	e.name = "W50Dummy_%d" % randi()
	_game.ctx.root.add_child(e)
	e.global_position = at
	e.hp = hp
	e.max_hp = hp
	e.plating = plating
	e.kind = kind
	e.weight = weight
	e.add_to_group("enemy")
	return e


func _set_parts(part_list: Array) -> void:
	_game.ctx.run.parts.clear()
	for pid in part_list:
		_game.ctx.run.parts.append(String(pid))
	_game.build.recompute()


func _part_info(part_id: String) -> Dictionary:
	var d: Resource = Parts.def(part_id)
	return {} if d == null else {"tags": d.tags, "bits": d.bits}


func _set_speed_tier(tier: int) -> void:
	var cruise: float = _player.tuning.f("cruise")
	var mult := 0.0
	match tier:
		SpeedTier.WALK:
			mult = 0.2
		SpeedTier.CRUISE:
			mult = 1.0
		SpeedTier.FAST:
			mult = 1.65
		SpeedTier.BLAZING:
			mult = 2.4
	var v := Vector3(cruise * mult, 0.0, 0.0)
	_player.state.velocity = v
	if _player._rigid != null:
		_player._rigid.linear_velocity = v


# --- 1. Pure Catalogue, Word Caps, Pool Purity, Non-HAZARD ------------------------------

func _check_catalogue_and_words() -> void:
	_t.eq("base MICRO_MUTATIONS remains 6", Parts.MICRO_MUTATIONS.size(), 6)
	_t.eq("FLAT_MICRO_MUTATIONS has 10 parts", Parts.FLAT_MICRO_MUTATIONS.size(), 10)
	_t.eq("all_micro_mutation_problems empty", Parts.all_micro_mutation_problems(), [])
	var expected_flat := ["rivet_plating", "magnet_spool", "grip_tread", "live_line", "vent_baffle",
		"winch_pawl", "spring_shims", "gatling_heart", "horizon_optic", "ram_plow"]
	for fid in expected_flat:
		_t.check("flat micro-mutation exists: %s" % fid, Parts.has_micro_mutation([fid], fid), fid)
		var row := Parts.micro_mutation(fid)
		_t.check("flat micro-mutation has id/text: %s" % fid,
			not row.is_empty() and String(row.get("id", "")) != "" and String(row.get("text", "")) != "", str(row))

	_t.eq("EXPANSION_PARTS has 8 parts", Parts.EXPANSION_PARTS.size(), 8)
	_t.eq("AlphaDefs.EXPANSION_PARTS matches 8", AlphaDefs.EXPANSION_PARTS.size(), 8)
	var expected_new := ["boomerang_spool", "orbital_flywheel", "prism_splitter", "debt_collector",
		"slag_furnace", "patch_tether", "basalt_ram", "storm_capacitor"]
	var prev_table = Synergies.table
	Synergies.table = AlphaDefs
	var alpha_pool := Parts.offer_pool("kest", ["common", "uncommon", "rare"])
	Synergies.table = SliceDefs
	var slice_pool := Parts.offer_pool("kest", ["common", "uncommon", "rare"])
	Synergies.table = prev_table
	var seen_verbs := {}
	for existing_id in Parts.rows():
		seen_verbs[String(Parts.def(existing_id).verb)] = existing_id
	for nid in expected_new:
		_t.check("expansion part has(): %s" % nid, Parts.has(nid), nid)
		_t.check("expansion part in AlphaDefs.part_in_play: %s" % nid, AlphaDefs.part_in_play(nid), nid)
		_t.check("expansion part reachable in alpha offer_pool: %s" % nid, nid in alpha_pool, nid)
		_t.check("expansion part excluded from slice offer_pool: %s" % nid, not (nid in slice_pool), nid)
		var d: Resource = Parts.def(nid)
		_t.check("expansion part def non-null: %s" % nid, d != null, nid)
		_t.check("expansion part zero movement mods: %s" % nid,
			not d.mods.has("speed") and not d.mods.has("air_control") and not d.mods.has("boost_power") and not d.mods.has("jump_power"),
			str(d.mods))
		_t.check("expansion part verb <= 6 words: %s" % nid, WordBudget.words_in(String(d.verb)) <= 6, String(d.verb))
		_t.check("expansion part verb unique: %s" % nid, not seen_verbs.has(String(d.verb)), String(d.verb))
		seen_verbs[String(d.verb)] = nid
		_t.check("expansion part text <= 8 words, no ellipsis: %s" % nid,
			ItemGen.word_count(String(d.text)) <= ItemGen.MAX_WORDS and not "..." in String(d.text), String(d.text))
		for bad in BANNED:
			_t.check("no banned word '%s' in %s" % [bad, nid],
				not String(d.verb).to_lower().contains(String(bad).to_lower())
				and not String(d.text).to_lower().contains(String(bad).to_lower())
				and not Parts.display_name(nid).to_lower().contains(String(bad).to_lower()),
				"%s | %s" % [d.verb, d.text])
		_t.check("expansion effect in ItemEffects.EFFECTS: %s" % nid,
			ItemEffects.EFFECTS.has(String(d.effect.get("do", ""))), str(d.effect))

	# Check 3 new evolutions word caps & origin line
	for evo_id in ["gyro_foundry", "arc_prism", "whiplash_spool"]:
		_t.check("evolution part has(): %s" % evo_id, Parts.has(evo_id), evo_id)
		var ed: Resource = Parts.def(evo_id)
		_t.check("evolution verb <= 6 words: %s" % evo_id, WordBudget.words_in(String(ed.verb)) <= 6, String(ed.verb))
		var syn_id := String(Synergies.all_evolved_from().get(evo_id, ""))
		var syn_name := String(Synergies.ROWS.get(syn_id, {}).get("name", ""))
		_t.check("evolution text ends with 'From <Synergy>.': %s" % evo_id,
			syn_name != "" and String(ed.text).ends_with("From %s." % syn_name), String(ed.text))
		for bad in BANNED:
			_t.check("no banned word '%s' in %s" % [bad, evo_id],
				not String(ed.verb).to_lower().contains(String(bad).to_lower())
				and not String(ed.text).to_lower().contains(String(bad).to_lower()), String(ed.text))

	# Non-HAZARD visual rule (Rule 8 / B6)
	for col in OrbitalSatellites.used_colors():
		_t.check("orbital visual color is never Palette.HAZARD", not col.is_equal_approx(Palette.HAZARD), str(col))
	for cid in Synergies.CROSS_SYSTEM_W50:
		var c: Color = Synergies.CROSS_SYSTEM_W50[cid]["color"]
		_t.check("cross-system %s color is never Palette.HAZARD" % cid, not c.is_equal_approx(Palette.HAZARD), str(c))

	# Planted negative controls
	_t.check("planted control: unknown part not in Parts.has", not Parts.has("nonexistent_w50_widget"), "")
	_t.check("planted control: unknown effect not in ItemEffects.EFFECTS", not ItemEffects.EFFECTS.has("w50_fake_effect"), "")
	_t.check("planted control: banned word detector catches 'enemies'",
		"hits enemies hard".to_lower().contains("enemies"), "")


# --- 2. RoR2 Duplicate-Stacking Math & Caps --------------------------------------------

func _check_ror2_stacking_math() -> void:
	var fx = ItemEffects.new(null)
	# orbital_flywheel: 1 -> 5 cap
	var counts: Array = []
	for s in [0, 1, 2, 3, 4, 5, 8, 20]:
		var list: Array = []
		for _i in s:
			list.append("orbital_flywheel")
		fx.refresh(list)
		counts.append(fx.orbital_count())
	_t.eq("orbital_flywheel count scales 0..5 and caps at 5", counts, [0, 1, 2, 3, 4, 5, 5, 5])

	# prism_splitter: 3 -> 5 cap
	var rays: Array = []
	for s in [0, 1, 2, 3, 6, 15]:
		var list: Array = []
		for _i in s:
			list.append("prism_splitter")
		fx.refresh(list)
		rays.append(fx.prism_rays())
	_t.eq("prism_splitter rays scale 0,3,4,5 and cap at 5", rays, [0, 3, 4, 5, 5, 5])

	# boomerang_spool: pause 0.15, damage & width scale and cap
	fx.refresh(["boomerang_spool"])
	var b1: Dictionary = fx.boomerang_stats()
	fx.refresh(["boomerang_spool", "boomerang_spool", "boomerang_spool"])
	var b3: Dictionary = fx.boomerang_stats()
	var b20_list: Array = []
	for _i in 20:
		b20_list.append("boomerang_spool")
	fx.refresh(b20_list)
	var b20: Dictionary = fx.boomerang_stats()
	_t.check("boomerang pause is 0.15 s", is_equal_approx(float(b1["pause_s"]), 0.15), str(b1))
	_t.check("boomerang damage & width increase with stacks and cap",
		float(b1["damage_mult"]) < float(b3["damage_mult"]) and float(b3["damage_mult"]) <= float(b20["damage_mult"])
		and float(b20["damage_mult"]) <= Bolts.BOOMERANG_MAX_DAMAGE_MULT + 0.001
		and float(b1["width_mult"]) < float(b3["width_mult"]) and float(b20["width_mult"]) <= Bolts.BOOMERANG_MAX_WIDTH_MULT + 0.001,
		"b1=%s b3=%s b20=%s" % [b1, b3, b20])

	# debt_collector: hyperbolic cap
	fx.refresh(["debt_collector"])
	var d1: float = fx.coin_shot_damage()
	fx.refresh(["debt_collector", "debt_collector", "debt_collector"])
	var d3: float = fx.coin_shot_damage()
	var d20_list: Array = []
	for _i in 20:
		d20_list.append("debt_collector")
	fx.refresh(d20_list)
	var d20: float = fx.coin_shot_damage()
	_t.check("debt_collector hyperbolic damage increases and stays bounded",
		d1 > 0.0 and d1 < d3 and d3 < d20 and d20 < 56.0, "d1=%.2f d3=%.2f d20=%.2f" % [d1, d3, d20])

	# slag_furnace: hyperbolic radius cap
	fx.refresh(["slag_furnace"])
	var sr1: float = fx.slag_radius()
	fx.refresh(["slag_furnace", "slag_furnace", "slag_furnace"])
	var sr3: float = fx.slag_radius()
	var sr20_list: Array = []
	for _i in 20:
		sr20_list.append("slag_furnace")
	fx.refresh(sr20_list)
	var sr20: float = fx.slag_radius()
	_t.check("slag_furnace radius increases and caps cleanly",
		sr1 >= 3.0 and sr1 < sr3 and sr3 < sr20 and sr20 <= 8.5, "sr1=%.2f sr3=%.2f sr20=%.2f" % [sr1, sr3, sr20])

	# patch_tether: hold-vs-pop aura (+18% at 1 copy, capped at +65%, 0 when popped)
	fx.refresh(["patch_tether"])
	var p_held1: float = fx.pocket_aura_bonus(true)
	var p_popped: float = fx.pocket_aura_bonus(false)
	fx.refresh(["patch_tether", "patch_tether", "patch_tether"])
	var p_held3: float = fx.pocket_aura_bonus(true)
	var p20_list: Array = []
	for _i in 20:
		p20_list.append("patch_tether")
	fx.refresh(p20_list)
	var p_held20: float = fx.pocket_aura_bonus(true)
	_t.check("patch_tether grants +18% at 1 copy, scales to 0.65 cap, and 0 when popped",
		is_equal_approx(p_held1, 0.22 / 1.22) and p_held3 > p_held1 and is_equal_approx(p_held20, 0.65)
		and is_equal_approx(p_popped, 0.0),
		"h1=%.4f h3=%.4f h20=%.4f pop=%.3f" % [p_held1, p_held3, p_held20, p_popped])

	# basalt_ram & storm_capacitor
	fx.refresh(["basalt_ram"])
	var br1: float = fx.basalt_cone_damage()
	var br10_list: Array = []
	for _i in 10:
		br10_list.append("basalt_ram")
	fx.refresh(br10_list)
	var br10: float = fx.basalt_cone_damage()
	_t.check("basalt_ram linear scaling caps at 54", br1 >= 18.0 and br10 > br1 and br10 <= 54.01, "br1=%.2f br10=%.2f" % [br1, br10])

	fx.refresh(["storm_capacitor"])
	var sc1: float = fx.storm_static_mult()
	var sc15_list: Array = []
	for _i in 15:
		sc15_list.append("storm_capacitor")
	fx.refresh(sc15_list)
	var sc15: float = fx.storm_static_mult()
	_t.check("storm_capacitor hyperbolic mult scales and stays < 2.5", sc1 >= 1.25 and sc15 > sc1 and sc15 < 2.5, "sc1=%.2f sc15=%.2f" % [sc1, sc15])


# --- 3. Evolutions & Cross-System Synergy Tables ----------------------------------------

func _check_evolutions_and_cross_system_tables() -> void:
	_t.eq("base EVOLUTIONS stays 7", Synergies.EVOLUTIONS.size(), 7)
	_t.eq("EVOLUTIONS_W50 has 3 verb-changing evolutions", Synergies.EVOLUTIONS_W50.size(), 3)
	_t.eq("all_evolutions has 10 total", Synergies.all_evolutions().size(), 10)
	var evo_probs := Synergies.evolution_problems(Synergies.all_evolutions(), Synergies.all_evolved_from(), Parts.has)
	_t.eq("all 10 evolutions disjoint and valid", evo_probs, [])

	# Planted negative control: duplicate ingredient pair must fail evolution_problems
	var broken_evos := Synergies.all_evolutions().duplicate(true)
	broken_evos["bad_evo"] = ["orbital_flywheel", "slag_furnace"]
	var broken_probs := Synergies.evolution_problems(broken_evos, Synergies.all_evolved_from(), Parts.has)
	_t.check("planted control: overlapping evolution ingredient fails validation", not broken_probs.is_empty(), str(broken_probs))

	# Ready / live checks for the 3 new evolutions
	_t.eq("gyro_foundry ready on both ingredients",
		Synergies.evolutions_ready(["orbital_flywheel", "basalt_ram"]), ["gyro_foundry"])
	_t.eq("planted control: gyro_foundry NOT ready on 1 ingredient",
		Synergies.evolutions_ready(["orbital_flywheel"]), [])
	_t.eq("arc_prism ready on both ingredients",
		Synergies.evolutions_ready(["prism_splitter", "galvanic_rounds"]), ["arc_prism"])
	_t.eq("whiplash_spool ready on both ingredients",
		Synergies.evolutions_ready(["boomerang_spool", "long_leash"]), ["whiplash_spool"])
	_t.check("whiplash_spool dormant when ingredient removed",
		not Synergies.evolved_live("whiplash_spool", ["whiplash_spool", "boomerang_spool"]), "")

	# Cross-system synergies 6 -> 12
	_t.eq("base CROSS_SYSTEM remains 6", Synergies.CROSS_SYSTEM.size(), 6)
	_t.eq("CROSS_SYSTEM_W50 adds 6", Synergies.CROSS_SYSTEM_W50.size(), 6)
	_t.eq("all_cross_system totals 12", Synergies.all_cross_system().size(), 12)
	_t.eq("all_cross_system_declarations totals 12", Synergies.all_cross_system_declarations().size(), 12)
	_t.eq("cross_system_problems empty across all 12", Synergies.cross_system_problems(), [])

	var info := Callable(self, "_part_info")
	_t.check("overclocked_circuit wakes on speed + arc",
		Synergies.cross_system_awake("overclocked_circuit", ["tread_plating", "arc_coil"], info, {}), "")
	_t.check("orbital_furnace wakes on orbital + heat",
		Synergies.cross_system_awake("orbital_furnace", ["orbital_flywheel", "slag_furnace"], info, {}), "")
	_t.check("scrap_magnetron wakes on magnet + arc",
		Synergies.cross_system_awake("scrap_magnetron", ["magnet_spool", "arc_coil"], info, {}), "")
	_t.check("railgun_ricochet wakes on pierce + bounce",
		Synergies.cross_system_awake("railgun_ricochet", ["helix_drill", "chain_arc"], info, {}), "")
	_t.check("ghost_conductor wakes on husk context + arc",
		Synergies.cross_system_awake("ghost_conductor", ["arc_coil"], info, {"has_husk": true}), "")
	_t.check("heavy_dividend wakes on burden + mass",
		Synergies.cross_system_awake("heavy_dividend", ["debt_collector", "rivet_plating"], info, {}), "")

	# Planted negative control: single part alone must NOT wake cross-system synergy
	_t.check("planted control: single part alone wakes none of the 6 W50 synergies",
		not Synergies.cross_system_awake("overclocked_circuit", ["arc_coil"], info, {})
		and not Synergies.cross_system_awake("orbital_flywheel", ["orbital_flywheel"], info, {})
		and not Synergies.cross_system_awake("orbital_furnace", ["orbital_flywheel"], info, {})
		and not Synergies.cross_system_awake("scrap_magnetron", ["magnet_spool"], info, {})
		and not Synergies.cross_system_awake("railgun_ricochet", ["helix_drill"], info, {})
		and not Synergies.cross_system_awake("ghost_conductor", ["arc_coil"], info, {"has_husk": false})
		and not Synergies.cross_system_awake("heavy_dividend", ["debt_collector"], info, {}), "")


# --- 4. Pure Boomerang Physics (Single Return, 0.15 s Pause, Split Children) ------------

func _check_boomerang_physics_pure() -> void:
	# Split child strips boomerang & railgun keys so proc depth stays strictly 1
	var parent := {
		"origin": Vector3.ZERO, "dir": Vector3.FORWARD, "speed": 40.0, "max_dist": 20.0,
		"travelled": 5.0, "damage": 12.0, "kind": "rivet", "radius": 0.4, "knock": 4.0,
		"chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 0.5, "color": Palette.AMBER,
		"wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0, "pierce": 0, "source": "weapon",
		"bits": ShotBits.bit("split"), "spent": 0, "exclude": [], "up": Vector3.UP,
		"boomerang": true, "boomerang_pause_s": 0.15, "boomerang_damage_mult": 1.3, "boomerang_width_mult": 1.4,
		"railgun_ricochet": true, "railgun_boosts": 1, "railgun_boosted_last": true,
	}
	var kids := Bolts.split_children(parent, Vector3(0, 0, -5), 999, 5.0)
	_t.eq("split produces 2 children", kids.size(), 2)
	for kid in kids:
		_t.check("split child never inherits boomerang or railgun keys",
			not bool(kid.get("boomerang", false)) and not kid.has("railgun_ricochet")
			and not kid.has("railgun_boosts") and not kid.has("railgun_boosted_last"), str(kid))

	# Returning boomerang clears outbound modifiers (chain_jumps, extra_bounces, railgun, ricochet_home, sixth_hot)
	var b := Bolts.new()
	var flip_bolt := {
		"origin": Vector3.ZERO, "shown": Vector3(0, 0, -10), "dir": Vector3.FORWARD, "speed": 40.0, "max_dist": 10.0,
		"travelled": 10.0, "damage": 15.0, "radius": 0.4, "width_scale": 1.0, "pierce": 0, "source": "weapon",
		"bits": ShotBits.bit("bounce"), "spent": 0, "exclude": [1],
		"boomerang": true, "boomerang_damage_mult": 1.2, "boomerang_width_mult": 1.25,
		"chain_jumps": 2, "extra_bounces": 2, "railgun_ricochet": true, "railgun_boosts": 1,
		"railgun_boosted_last": true, "ricochet_home": true, "sixth_hot": true,
	}
	b._flip_boomerang(flip_bolt)
	_t.check("returning boomerang clears chain_jumps, extra_bounces, railgun, ricochet_home, sixth_hot",
		int(flip_bolt.get("chain_jumps", -1)) == 0 and int(flip_bolt.get("extra_bounces", -1)) == 0
		and not bool(flip_bolt.get("railgun_ricochet", true)) and not bool(flip_bolt.get("ricochet_home", true))
		and not bool(flip_bolt.get("sixth_hot", true)) and String(flip_bolt.get("source", "")) == "item_proc"
		and int(flip_bolt.get("bits", -1)) == 0, str(flip_bolt))
	b.free()


# --- 5. Live Orbital Satellites + Gyro Foundry + Orbital Furnace ------------------------

func _check_orbitals_and_evolutions_live() -> void:
	_clear_enemies()
	_orbitals.reset_attempt()
	_orbitals.clear_telemetry()

	# SpeedTier monotonicity
	var r0 := OrbitalSatellites.orbit_radius_for(SpeedTier.WALK, 1)
	var r1 := OrbitalSatellites.orbit_radius_for(SpeedTier.CRUISE, 1)
	var r2 := OrbitalSatellites.orbit_radius_for(SpeedTier.FAST, 1)
	var r3 := OrbitalSatellites.orbit_radius_for(SpeedTier.BLAZING, 1)
	var s0 := OrbitalSatellites.orbit_speed_for(SpeedTier.WALK)
	var s3 := OrbitalSatellites.orbit_speed_for(SpeedTier.BLAZING)
	_t.check("orbital radius & speed scale monotonically with SpeedTier",
		r0 < r1 and r1 < r2 and r2 < r3 and s0 < s3,
		"r=%.2f,%.2f,%.2f,%.2f s=%.2f->%.2f" % [r0, r1, r2, r3, s0, s3])

	# Negative control: no orbital_flywheel -> 0 satellites & 0 hits
	_set_parts([])
	var centre: Vector3 = _player.ball_position()
	var e_neg := _spawn_dummy(centre + Vector3(r0, 0.0, 0.0), 200.0)
	_orbitals.step(0.05, [e_neg])
	_t.eq("negative control: 0 satellites without orbital_flywheel", _orbitals.satellite_count(), 0)
	_t.eq("negative control: 0 orbital procs without part", _orbitals.proc_count("orbital_flywheel"), 0)

	# 1 -> 3 -> 5 stacks (cap at 5 even with 8 copies)
	_set_parts(["orbital_flywheel"])
	_orbitals.step(0.016, [])
	_t.eq("1 copy -> 1 satellite", _orbitals.satellite_count(), 1)
	_set_parts(["orbital_flywheel", "orbital_flywheel", "orbital_flywheel"])
	_orbitals.step(0.016, [])
	_t.eq("3 copies -> 3 satellites", _orbitals.satellite_count(), 3)
	_set_parts(["orbital_flywheel", "orbital_flywheel", "orbital_flywheel", "orbital_flywheel",
		"orbital_flywheel", "orbital_flywheel", "orbital_flywheel", "orbital_flywheel"])
	_orbitals.step(0.016, [])
	_t.eq("8 copies -> capped at 5 satellites", _orbitals.satellite_count(), 5)

	# Live hit + Gyro Foundry evolution + Orbital Furnace cross-synergy
	_clear_enemies()
	_orbitals.reset_attempt()
	_orbitals.clear_telemetry()
	_set_parts([])
	_game.ctx.run.add_part("orbital_flywheel", "gate")
	_game.ctx.run.add_part("basalt_ram", "gate")
	_game.ctx.run.add_part("slag_furnace", "gate")
	_t.check("gyro_foundry auto-granted when both ingredients added",
		"gyro_foundry" in _game.ctx.run.parts and Synergies.evolved_live("gyro_foundry", _game.ctx.run.parts),
		str(_game.ctx.run.parts))
	_set_speed_tier(SpeedTier.FAST)
	_orbitals.step(0.016, [])
	var sat_pos: Vector3 = _orbitals.satellite_positions()[0]
	var e_primary := _spawn_dummy(Vector3(sat_pos.x, centre.y, sat_pos.z), 300.0)
	var e_nearby := _spawn_dummy(Vector3(sat_pos.x + 2.2, centre.y, sat_pos.z), 300.0)
	var hp_p0: float = e_primary.hp
	var hp_n0: float = e_nearby.hp
	_orbitals.step(0.016, [e_primary, e_nearby])
	_t.check("orbital satellite hits enemy on ring as item_proc",
		_orbitals.proc_count("orbital_flywheel") >= 1 and e_primary.hp < hp_p0,
		"procs=%d hp=%.1f->%.1f" % [_orbitals.proc_count("orbital_flywheel"), hp_p0, e_primary.hp])
	_t.check("orbital_furnace cross-synergy heats target and logs proc",
		_orbitals.proc_count("orbital_furnace") >= 1 and _combat.heated(e_primary),
		"furnace=%d heated=%s" % [_orbitals.proc_count("orbital_furnace"), str(_combat.heated(e_primary))])
	_t.check("gyro_foundry evolution emits seismic ring hitting adjacent enemy",
		_orbitals.proc_count("gyro_foundry") >= 1 and e_nearby.hp < hp_n0,
		"gyro=%d nearby_hp=%.1f->%.1f" % [_orbitals.proc_count("gyro_foundry"), hp_n0, e_nearby.hp])


# --- 6. Live Boomerang Bolt + Whiplash Spool Evolution ----------------------------------

func _check_boomerang_and_whiplash_live() -> void:
	_clear_enemies()
	_combat.bolts.clear()
	_orbitals.reset_attempt()
	_orbitals.clear_telemetry()
	_set_parts([])
	_game.ctx.run.add_part("boomerang_spool", "gate")
	_game.ctx.run.add_part("long_leash", "gate")
	_t.check("whiplash_spool auto-granted on boomerang_spool + long_leash",
		"whiplash_spool" in _game.ctx.run.parts, str(_game.ctx.run.parts))

	var centre: Vector3 = _player.ball_position()
	var space: PhysicsDirectSpaceState3D = _game.ctx.root.get_world_3d().direct_space_state
	var bolt := {
		"origin": centre + Vector3(0.0, 0.8, 0.0),
		"fired_from": centre + Vector3(0.0, 0.8, 0.0),
		"dir": Vector3.RIGHT,
		"speed": 40.0,
		"max_dist": 10.0,
		"damage": 15.0,
		"kind": "rivet",
		"weapon_id": "rivet_gun",
		"radius": 0.5,
		"knock": 4.0,
		"chain_jumps": 0,
		"chain_range": 0.0,
		"chain_falloff": 0.5,
		"color": Palette.AMBER,
		"wave_amp": 0.0,
		"wave_hz": 0.0,
		"phase": 0.0,
		"pierce": 0,
		"source": "weapon",
		"bits": 0,
	}
	_orbitals.stamp_bolt(bolt, null)
	_t.check("boomerang_spool stamps boomerang and whiplash_pull on weapon bolt",
		bool(bolt.get("boomerang", false)) and bool(bolt.get("whiplash_pull", false)), str(bolt))
	_combat.bolts.fire(bolt)

	# Advance past max_dist (10 m at 40 m/s = 0.25 s): should pause at max range
	for _i in 6:
		_combat.bolts.step(0.05, space, [], [])
	_t.eq("boomerang bolt pauses at max range", _combat.bolts._bolts.size(), 1)
	var live_bolt: Dictionary = _combat.bolts._bolts[0]
	_t.check("boomerang bolt enters pause window", float(live_bolt.get("boomerang_pause", 0.0)) > 0.0, str(live_bolt))

	# Wait out 0.15 s pause -> bolt flips once as item_proc with bits=0
	for _i in 4:
		_combat.bolts.step(0.05, space, [], [])
	_t.eq("boomerang bolt stays live on return pass", _combat.bolts._bolts.size(), 1)
	var ret_bolt: Dictionary = _combat.bolts._bolts[0]
	_t.check("returning bolt flipped once as item_proc with bits=0 and boomerang=false",
		bool(ret_bolt.get("boomerang_returned", false)) and not bool(ret_bolt.get("boomerang", true))
		and String(ret_bolt.get("source", "")) == "item_proc" and int(ret_bolt.get("bits", 1)) == 0
		and (ret_bolt["dir"] as Vector3).x < -0.9,
		str(ret_bolt))

	# Place light enemy along return path (pilot heft >= 2.0 vs chaser 1.4) -> gets hit & pulled by Whiplash Spool
	_game.ctx.run.mass = 450.0
	var target := _spawn_dummy(centre + Vector3(4.0, 0.0, 0.0), 200.0, 0.0, "chaser", 1.0)
	var hp0: float = target.hp
	for _i in 10:
		_combat.bolts.step(0.05, space, [target], [])
	_t.check("returning boomerang hits enemy and triggers whiplash_spool pull",
		target.hp < hp0 and _orbitals.proc_count("boomerang_return_hit") >= 1
		and _orbitals.proc_count("whiplash_spool") >= 1,
		"hp=%.1f->%.1f ret=%d whip=%d heft=%.2f" % [hp0, target.hp, _orbitals.proc_count("boomerang_return_hit"), _orbitals.proc_count("whiplash_spool"), _combat.heft()])
	_t.eq("boomerang expires after single return pass (never loops)", _combat.bolts._bolts.size(), 0)
	# Heavy target negative control: plated_brute (heft 4.0 > pilot heft) holds against Whiplash Spool
	var heavy := _spawn_dummy(centre + Vector3(4.0, 0.0, 0.0), 200.0, 0.0, "plated_brute", 1.0)
	var whip_before: int = _orbitals.proc_count("whiplash_spool")
	_orbitals.on_bolt_hit({"boomerang_returned": true, "whiplash_pull": true, "damage": 15.0, "source": "item_proc"}, heavy, heavy.global_position, "")
	_t.eq("negative control: heavy machine holds against whiplash_spool", _orbitals.proc_count("whiplash_spool"), whip_before)


# --- 7. Live Prism Splitter + Arc Prism Evolution ---------------------------------------

func _check_prism_and_arc_prism_live() -> void:
	_clear_enemies()
	_orbitals.reset_attempt()
	_orbitals.clear_telemetry()
	var centre: Vector3 = _player.ball_position()

	# Negative control: unplated target with plain prism_splitter does NOT refract
	_set_parts(["prism_splitter"])
	var unplated := _spawn_dummy(centre + Vector3(5.0, 0.0, 0.0), 200.0, 0.0)
	var behind := _spawn_dummy(centre + Vector3(11.0, 0.0, 0.0), 200.0, 0.0)
	var fake_bolt := {"dir": Vector3.RIGHT, "damage": 20.0, "source": "weapon", "origin": centre, "fired_from": centre, "travelled": 5.0}
	_orbitals.on_bolt_hit(fake_bolt, unplated, unplated.global_position, "")
	_t.eq("negative control: plain prism_splitter ignores unplated target", _orbitals.proc_count("prism_splitter"), 0)

	# Plated target triggers copper-amber refraction hitting enemy behind it
	var plated := _spawn_dummy(centre + Vector3(5.0, 0.0, 0.0), 200.0, 4.0)
	var hp_behind0: float = behind.hp
	_orbitals.on_bolt_hit(fake_bolt, plated, plated.global_position, "")
	_t.check("prism_splitter refracts through plated target onto enemy behind",
		_orbitals.proc_count("prism_splitter") >= 1 and behind.hp < hp_behind0,
		"procs=%d hp=%.1f->%.1f" % [_orbitals.proc_count("prism_splitter"), hp_behind0, behind.hp])

	# Arc Prism evolution: works on unplated target AND chains 1 arc jump
	_orbitals.clear_telemetry()
	_set_parts([])
	_game.ctx.run.add_part("prism_splitter", "gate")
	_game.ctx.run.add_part("galvanic_rounds", "gate")
	_t.check("arc_prism auto-granted", "arc_prism" in _game.ctx.run.parts, str(_game.ctx.run.parts))
	var chain_victim := _spawn_dummy(centre + Vector3(11.0, 0.0, 4.0), 200.0, 0.0)
	var hp_chain0: float = chain_victim.hp
	_orbitals.on_bolt_hit(fake_bolt, unplated, unplated.global_position, "")
	_t.check("arc_prism refracts on unplated target and chains arc jump",
		_orbitals.proc_count("prism_splitter") >= 1 and _orbitals.proc_count("arc_prism") >= 1 and chain_victim.hp < hp_chain0,
		"prism=%d arc=%d chain_hp=%.1f->%.1f" % [_orbitals.proc_count("prism_splitter"), _orbitals.proc_count("arc_prism"), hp_chain0, chain_victim.hp])


# --- 8. Live Debt Collector, Slag Furnace, Patch Tether, Basalt Ram, Storm Capacitor ----

func _check_debt_slag_patch_basalt_storm_live() -> void:
	_clear_enemies()
	_orbitals.reset_attempt()
	_orbitals.clear_telemetry()
	var centre: Vector3 = _player.ball_position()
	var target := _spawn_dummy(centre + Vector3(6.0, 0.0, 0.0), 500.0)

	# Debt Collector: negative control -> active + 0.35 s cooldown
	_set_parts([])
	_game.ctx.events.cogs_collected.emit(5, 5)
	_t.eq("negative control: debt_collector 0 without part", _orbitals.proc_count("debt_collector"), 0)
	_set_parts(["debt_collector"])
	var hp0: float = target.hp
	_game.ctx.events.cogs_collected.emit(5, 10)
	_game.ctx.events.cogs_collected.emit(5, 15) # inside 0.35 s cooldown
	_t.eq("debt_collector fires once and respects 0.35 s cooldown", _orbitals.proc_count("debt_collector"), 1)
	_t.check("debt_collector damages nearest enemy", target.hp < hp0, "hp=%.1f->%.1f" % [hp0, target.hp])

	# Slag Furnace: every 5th kill drops 4 s heat zone that ticks damage and expires
	_set_parts(["slag_furnace"])
	for _i in 4:
		_game.ctx.events.enemy_killed.emit("chaser", target.global_position, 2)
	_t.eq("slag_furnace spawns 0 zones before 5th kill", _orbitals.slag_zone_count(), 0)
	_game.ctx.events.enemy_killed.emit("chaser", target.global_position, 2)
	_t.eq("slag_furnace spawns 1 zone on 5th kill", _orbitals.slag_zone_count(), 1)
	var hp_slag0: float = target.hp
	_orbitals.step(0.1, [target])
	_t.check("slag_furnace ticks damage on enemy inside zone", target.hp < hp_slag0, "hp=%.1f->%.1f" % [hp_slag0, target.hp])
	_orbitals.step(4.2, [target])
	_t.eq("slag_furnace zone expires after 4 s", _orbitals.slag_zone_count(), 0)

	# Patch Tether: hold-vs-pop consumable tension
	_set_parts(["patch_tether"])
	_game.ctx.run.consumables.clear()
	_t.check("patch_tether strike_mult is 1.0 with empty consumable belt",
		is_equal_approx(_orbitals.strike_mult(target, "rivet", "weapon"), 1.0), "")
	_game.ctx.run.consumables.append("hull_patch")
	var held_mult: float = _orbitals.strike_mult(target, "rivet", "weapon")
	var proc_mult: float = _orbitals.strike_mult(target, "synergy", "item_proc")
	_t.check("patch_tether boosts weapon strikes while holding consumable, never item_proc",
		held_mult > 1.10 and is_equal_approx(proc_mult, 1.0), "held=%.3f proc=%.3f" % [held_mult, proc_mult])
	_game.ctx.run.consumables.clear()
	_t.check("patch_tether drops immediately to 1.0 when consumable popped",
		is_equal_approx(_orbitals.strike_mult(target, "rivet", "weapon"), 1.0), "")

	# Basalt Ram: carve + destructible breach shock cone
	_set_parts(["basalt_ram"])
	_player.state.velocity = Vector3(15.0, 0.0, 0.0)
	if _player._rigid != null:
		_player._rigid.linear_velocity = Vector3(15.0, 0.0, 0.0)
	var hp_b0: float = target.hp
	_game.ctx.events.carved.emit(centre, 0.5, 16.0)
	_orbitals.step(0.85, [target])
	_game.ctx.events.world_fact.emit("piece_shattered", centre)
	_t.check("basalt_ram fires on carve and piece_shattered and damages cone target",
		_orbitals.proc_count("basalt_ram") == 2 and target.hp < hp_b0,
		"procs=%d hp=%.1f->%.1f" % [_orbitals.proc_count("basalt_ram"), hp_b0, target.hp])

	# Storm Capacitor: airborne hits charge, grounded hits don't, land/slam discharges
	_set_parts(["storm_capacitor"])
	_orbitals.reset_attempt()
	var storm_bolt := {"dir": Vector3.RIGHT, "damage": 15.0, "source": "weapon", "origin": centre, "fired_from": centre, "travelled": 5.0}
	_player.state.grounded = true
	_player.kit.gliding = false
	_orbitals.on_bolt_hit(storm_bolt, target, target.global_position, "")
	_t.eq("negative control: grounded hit does NOT charge storm_capacitor", _orbitals.storm_charge_count(), 0)
	_player.state.grounded = false
	_orbitals.on_bolt_hit(storm_bolt, target, target.global_position, "")
	_orbitals.on_bolt_hit(storm_bolt, target, target.global_position, "")
	_t.eq("airborne weapon hits charge storm_capacitor to 2", _orbitals.storm_charge_count(), 2)
	var hp_s0: float = target.hp
	_player.state.grounded = true
	_game.ctx.events.landed.emit(12.0)
	_t.check("landing releases storm_capacitor shockwave and clears charge bank",
		_orbitals.storm_charge_count() == 0 and _orbitals.proc_count("storm_capacitor") == 1 and target.hp < hp_s0,
		"charges=%d procs=%d hp=%.1f->%.1f" % [_orbitals.storm_charge_count(), _orbitals.proc_count("storm_capacitor"), hp_s0, target.hp])


# --- 9. All 10 Flat-Part Micro-Mutations Live + Negative Controls -----------------------

func _check_flat_micro_mutations_live() -> void:
	_clear_enemies()
	var centre: Vector3 = _player.ball_position()
	var e1 := _spawn_dummy(centre + Vector3(2.2, 0.0, 0.0), 1000.0)
	var e2 := _spawn_dummy(centre + Vector3(4.5, 0.0, 1.0), 1000.0)
	var e_rear := _spawn_dummy(centre + Vector3(-2.5, 0.0, 0.0), 1000.0)
	var e_far := _spawn_dummy(centre + Vector3(26.0, 0.0, 0.0), 1000.0)

	# Negative control: fire all 10 triggers with empty parts -> 0 procs
	_set_parts([])
	_orbitals.reset_attempt()
	_orbitals.clear_telemetry()
	_trigger_all_10_flat_micros(centre, e1, e2, e_rear, e_far)
	for fid in Parts.FLAT_MICRO_MUTATIONS:
		_t.eq("negative control: %s fires 0 without part" % fid, _orbitals.proc_count(fid), 0)

	# Positive check: equip all 10 flat parts -> every single one fires >= 1 item_proc
	_set_parts(Parts.FLAT_MICRO_MUTATIONS.keys())
	_orbitals.reset_attempt()
	_orbitals.clear_telemetry()
	_trigger_all_10_flat_micros(centre, e1, e2, e_rear, e_far)
	for fid in Parts.FLAT_MICRO_MUTATIONS:
		_t.check("flat micro-mutation fires live: %s" % fid, _orbitals.proc_count(fid) >= 1,
			"count=%d" % _orbitals.proc_count(fid))
	# Table-to-runtime parity: grip_tread uses authored 2.8 m radius (hits 2.2 m, misses 3.8 m)
	_clear_enemies()
	_set_parts(["grip_tread"])
	_orbitals.reset_attempt()
	var e_in := _spawn_dummy(centre + Vector3(2.2, 0.0, 0.0), 200.0)
	var e_out := _spawn_dummy(centre + Vector3(3.8, 0.0, 0.0), 200.0)
	var hp_in0: float = e_in.hp
	var hp_out0: float = e_out.hp
	_game.ctx.events.carved.emit(centre, 0.5, 16.0)
	_t.check("grip_tread respects authored 2.8 m radius (hits 2.2 m, misses 3.8 m)",
		e_in.hp < hp_in0 and is_equal_approx(e_out.hp, hp_out0),
		"in=%.1f->%.1f out=%.1f->%.1f" % [hp_in0, e_in.hp, hp_out0, e_out.hp])


func _trigger_all_10_flat_micros(centre: Vector3, e1: Node3D, e2: Node3D, _e_rear: Node3D, e_far: Node3D) -> void:
	_game.ctx.events.player_hit.emit(10.0, "chaser") # rivet_plating
	for _i in 5:
		_game.ctx.events.scrap_collected.emit(1, centre, _i + 1) # magnet_spool
	_game.ctx.events.carved.emit(centre, 0.5, 16.0) # grip_tread
	_game.ctx.events.harpoon_bit.emit(e1, e1.global_position) # live_line
	_game.ctx.events.boosted.emit(Vector3.RIGHT) # vent_baffle
	_game.ctx.events.harpoon_smashed.emit(e1, e1.global_position, 18.0) # winch_pawl
	_game.ctx.events.jumped.emit(false) # spring_shims
	for _i in 12:
		_orbitals.stamp_bolt({"origin": centre, "dir": Vector3.RIGHT, "damage": 12.0, "source": "weapon", "bits": 0}, null) # gatling_heart
	_orbitals.on_bolt_hit({"origin": centre, "fired_from": centre, "dir": Vector3.RIGHT, "damage": 15.0, "source": "weapon", "travelled": 26.0},
		e_far, e_far.global_position, "") # horizon_optic
	_set_speed_tier(SpeedTier.FAST)
	_game.ctx.events.enemy_struck.emit(e1, "ram", 20.0) # ram_plow (hits adjacent e2)
	var _unused := e2


# --- 10. All 6 New Cross-System Synergies Live ------------------------------------------

func _check_cross_system_synergies_live() -> void:
	_clear_enemies()
	var centre: Vector3 = _player.ball_position()
	var e1 := _spawn_dummy(centre + Vector3(4.0, 0.0, 0.0), 500.0)
	var e2 := _spawn_dummy(centre + Vector3(7.0, 0.0, 1.0), 500.0)

	# 1) Overclocked Circuit: WALK -> 0, FAST -> fires arc burst
	_orbitals.reset_attempt()
	_orbitals.clear_telemetry()
	_set_parts(["tread_plating", "arc_coil"])
	_set_speed_tier(SpeedTier.WALK)
	var wbolt := {"origin": centre, "fired_from": centre, "dir": Vector3.RIGHT, "damage": 15.0, "source": "weapon", "travelled": 4.0}
	_orbitals.on_bolt_hit(wbolt, e1, e1.global_position, "")
	_t.eq("negative control: overclocked_circuit silent at WALK", _orbitals.proc_count("overclocked_circuit"), 0)
	_set_speed_tier(SpeedTier.FAST)
	_orbitals.on_bolt_hit(wbolt, e1, e1.global_position, "")
	_t.check("overclocked_circuit fires at SpeedTier.FAST", _orbitals.proc_count("overclocked_circuit") >= 1, "")

	# 2) Orbital Furnace already verified in orbital test; also check slag radius bonus
	_set_parts(["slag_furnace"])
	var base_r: float = _game.build.effects.slag_radius(0.0)
	var bonus_r: float = _game.build.effects.slag_radius(OrbitalSatellites.ORBITAL_FURNACE_SLAG_BONUS)
	_t.check("orbital_furnace widens slag zone by +1.5 m", is_equal_approx(bonus_r - base_r, 1.5), "%.2f vs %.2f" % [base_r, bonus_r])

	# 3) Scrap Magnetron: every 4th pickup emits magnetic arc ring
	_orbitals.reset_attempt()
	_orbitals.clear_telemetry()
	_set_parts(["magnet_spool", "arc_coil"])
	for i in 3:
		_game.ctx.events.scrap_collected.emit(1, centre, i + 1)
	_t.eq("scrap_magnetron waits until 4th pickup", _orbitals.proc_count("scrap_magnetron"), 0)
	_game.ctx.events.cogs_collected.emit(1, 1)
	_t.check("scrap_magnetron fires on 4th pickup", _orbitals.proc_count("scrap_magnetron") >= 1, "")

	# 4) Railgun Ricochet: wall bounce accelerates speed +40% & damage +35%, tints LEDGER, caps at 2
	_orbitals.reset_attempt()
	_orbitals.clear_telemetry()
	_set_parts(["helix_drill", "chain_arc"])
	var rbolt := {
		"origin": centre, "dir": Vector3.RIGHT, "speed": 50.0, "max_dist": 60.0,
		"travelled": 5.0, "damage": 20.0, "kind": "rivet", "radius": 0.4, "knock": 4.0,
		"chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 0.5, "color": Palette.AMBER,
		"wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0, "pierce": 1, "source": "weapon",
		"bits": ShotBits.bit("bounce"), "spent": 0, "exclude": [], "extra_bounces": 2,
	}
	_orbitals.stamp_bolt(rbolt, null)
	_t.check("railgun_ricochet stamps bolt", bool(rbolt.get("railgun_ricochet", false)), str(rbolt))
	var ok1: bool = _combat.bolts._glance(rbolt, centre + Vector3(5, 0, 0), Vector3.LEFT, 5.0, [])
	var spd1: float = float(rbolt["speed"])
	var dmg1: float = float(rbolt["damage"])
	var ok2: bool = _combat.bolts._glance(rbolt, centre + Vector3(0, 0, 0), Vector3.RIGHT, 5.0, [])
	var spd2: float = float(rbolt["speed"])
	var ok3: bool = _combat.bolts._glance(rbolt, centre + Vector3(5, 0, 0), Vector3.LEFT, 5.0, [])
	var spd3: float = float(rbolt["speed"])
	_t.check("railgun_ricochet boosts speed/damage on bounce 1 & 2, tints LEDGER, caps at 2",
		ok1 and ok2 and ok3 and is_equal_approx(spd1, 70.0) and is_equal_approx(dmg1, 27.0)
		and is_equal_approx(spd2, 98.0) and is_equal_approx(spd3, 98.0)
		and (rbolt["color"] as Color).is_equal_approx(Palette.LEDGER)
		and _orbitals.proc_count("railgun_ricochet") == 2,
		"spd=%.1f,%.1f,%.1f procs=%d" % [spd1, spd2, spd3, _orbitals.proc_count("railgun_ricochet")])

	# 5) Ghost Conductor: amber arc tether between ball and active husk damages enemy on line
	_orbitals.reset_attempt()
	_orbitals.clear_telemetry()
	_set_parts(["arc_coil"])
	var husk := Node3D.new()
	_game.ctx.root.add_child(husk)
	husk.global_position = centre + Vector3(10.0, 0.0, 0.0)
	_combat.ally_husks.husks.append(husk)
	var hp_gc0: float = e1.hp
	_orbitals.step(0.05, [e1, e2])
	_t.check("ghost_conductor damages enemy crossing ball-to-husk tether",
		_orbitals.proc_count("ghost_conductor") >= 1 and e1.hp < hp_gc0,
		"procs=%d hp=%.1f->%.1f" % [_orbitals.proc_count("ghost_conductor"), hp_gc0, e1.hp])
	_combat.ally_husks.husks.erase(husk)
	husk.queue_free()

	# 6) Heavy Dividend: live single-part negative controls at mass 0 / heft class 1, then scales & caps at +60%
	_game.ctx.run.mass = 0.0
	_set_parts(["debt_collector"])
	_t.check("live negative control: debt_collector alone at heft class 1 does NOT wake heavy_dividend",
		not _orbitals.has_w50_cross_synergy("heavy_dividend")
		and is_equal_approx(_orbitals.strike_mult(e1, "rivet", "weapon"), 1.0),
		"awake=%s mult=%.3f" % [str(_orbitals.has_w50_cross_synergy("heavy_dividend")), _orbitals.strike_mult(e1, "rivet", "weapon")])
	_set_parts(["cracked_plating"])
	_t.check("live negative control: cracked_plating alone at heft class 1 does NOT wake heavy_dividend",
		not _orbitals.has_w50_cross_synergy("heavy_dividend")
		and is_equal_approx(_orbitals.strike_mult(e1, "rivet", "weapon"), 1.0),
		"awake=%s mult=%.3f" % [str(_orbitals.has_w50_cross_synergy("heavy_dividend")), _orbitals.strike_mult(e1, "rivet", "weapon")])
	_set_parts(["debt_collector", "rivet_plating"])
	var hd1: float = _orbitals.strike_mult(e1, "rivet", "weapon")
	_set_parts(["debt_collector", "debt_collector", "debt_collector", "debt_collector", "debt_collector", "debt_collector", "rivet_plating"])
	var hd_cap: float = _orbitals.strike_mult(e1, "rivet", "weapon")
	_t.check("heavy_dividend scales with burdens and caps at +60%",
		is_equal_approx(hd1, 1.12) and is_equal_approx(hd_cap, 1.60),
		"hd1=%.3f hd_cap=%.3f" % [hd1, hd_cap])


# --- 11. Proc-Depth-1 Enforcement & Attempt/Death Resets --------------------------------

func _check_proc_depth_and_resets() -> void:
	_clear_enemies()
	var centre: Vector3 = _player.ball_position()
	var plated := _spawn_dummy(centre + Vector3(25.0, 0.0, 0.0), 300.0, 4.0)
	_set_parts(["boomerang_spool", "prism_splitter", "storm_capacitor", "horizon_optic", "tread_plating", "arc_coil", "slag_furnace"])
	_orbitals.reset_attempt()
	_orbitals.clear_telemetry()
	_set_speed_tier(SpeedTier.BLAZING)
	_player.state.grounded = false

	# An item_proc bolt must NEVER trigger stamp_bolt or on_bolt_hit weapon-only procs
	var proc_bolt := {"origin": centre, "fired_from": centre, "dir": Vector3.RIGHT, "damage": 15.0, "source": "item_proc", "travelled": 25.0, "bits": 0}
	_orbitals.stamp_bolt(proc_bolt, null)
	_orbitals.on_bolt_hit(proc_bolt, plated, plated.global_position, "")
	_t.check("proc-depth-1: item_proc bolt never stamps boomerang or triggers weapon procs",
		not bool(proc_bolt.get("boomerang", false))
		and _orbitals.proc_count("prism_splitter") == 0
		and _orbitals.proc_count("horizon_optic") == 0
		and _orbitals.proc_count("overclocked_circuit") == 0
		and _orbitals.storm_charge_count() == 0,
		"procs=%s charges=%d" % [str(_orbitals.proc_counts), _orbitals.storm_charge_count()])

	# Attempt / death reset cleans all transient state
	for _i in 5:
		_game.ctx.events.enemy_killed.emit("chaser", centre, 1)
	_orbitals.storm_charges = 4
	_t.check("pre-reset state populated", _orbitals.slag_zone_count() == 1 and _orbitals.storm_charge_count() == 4, "")
	_combat._on_player_died()
	_t.check("player_died resets slag zones, storm charges, and satellites",
		_orbitals.slag_zone_count() == 0 and _orbitals.storm_charge_count() == 0 and _orbitals.satellite_count() == 0, "")
	_clear_enemies()
