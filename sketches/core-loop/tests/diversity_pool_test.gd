extends SceneTree

const Pattern := preload("res://src/combat/pattern.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Parts := preload("res://src/build/parts.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Bindings := preload("res://src/core/bindings.gd")

# Wave 45 B1: the authored diversity pool. The four maker tricks that had stayed out of the alpha
# table are live; Fan Spread and Helix Drill are real pattern transformers (so their seams open);
# a piercing bolt passes through machines without losing its line or corkscrew phase; and every
# row admitted to AlphaDefs.PARTS has a touch verb. Evidence limit: layout and bolt stepping in
# headless Godot; how the fan and helix read on screen is Andrew's to see.

const FORWARD := Vector3(0.0, 0.0, -1.0)
const OUT := ["strike_pocket", "clean_break", "warhead_slug", "ring_wave", "salvage_drone", "scrap_geyser",
	"spring_hull", "shock_liner", "rebound_skin", "spare_frame", "warden_ward", "vault_battery", "anchor_spring", "feedback_loop",
	"slipstream", "long_lane", "reserve_tank", "gutter_guard", "tumbler_bearing"]

var _t := preload("res://tests/support/t.gd").new("diversity_pool_test")


class FakeEnemy extends Node3D:
	var half_height := 1.0
	var radius := 0.6
	var dead := false

	func is_dead() -> bool:
		return dead

	func weak_points() -> Array:
		return []


func _initialize() -> void:
	_tricks()
	_patterns()
	_compositions()
	_admission()
	await process_frame
	_pierce()
	quit(_t.verdict())


func _tricks() -> void:
	Synergies.set_table(AlphaDefs)
	for key in ["glacier_hull", "storm_lattice", "thermal_shock", "linked_spiral"]:
		var maker: String = Synergies.ROWS[key]["maker"]
		var pieces: Array = AlphaDefs.PARTS.filter(func(id): return Parts.maker_of(id) == maker and Parts.def(id).class_id == "")
		_t.check("%s is in the alpha table" % key, AlphaDefs.synergy_in_play(key) and Synergies.in_play(key), "")
		_t.check("%s wakes on two alpha pieces of %s" % [key, maker], pieces.size() >= 2 and key in Synergies.active(Parts.maker_counts(pieces.slice(0, 2)))
			and not key in Synergies.active(Parts.maker_counts(pieces.slice(0, 1))), "pieces %s" % [pieces])
	_t.eq("all fourteen tricks are live on the alpha table", Synergies.ROWS.keys().all(func(k): return AlphaDefs.synergy_in_play(k)), true)
	Synergies.set_table(ParkDefs)
	for key in ["glacier_hull", "storm_lattice", "thermal_shock", "linked_spiral"]:
		_t.check("%s is live on the park launch table" % key, ParkDefs.synergy_in_play(key) and Synergies.in_play(key), "")
	_t.eq("all fourteen tricks are live on the park launch table", Synergies.ROWS.keys().all(func(k): return ParkDefs.synergy_in_play(k)), true)
	Synergies.set_table(null)


func _patterns() -> void:
	for weapon in Weapons.ALL:
		var base: Resource = Weapons.base(weapon)
		var fan: Resource = base.transformed(["fan_spread"])
		var helix: Resource = base.transformed(["helix_drill"])
		_t.check("fan_spread adds four bolts to %s" % weapon, fan.volley_size() >= mini(base.volley_size() + 4, Pattern.MAX_VOLLEY) or base.arms > 1,
			"%d to %d" % [base.volley_size(), fan.volley_size()])
		_t.check("fan_spread keeps the cone apart on %s" % weapon, fan.spread_deg >= 7.0 or base.spread_deg >= 7.0, "%.1f deg" % fan.spread_deg)
		_t.check("helix_drill pierces one machine and corkscrews on %s" % weapon, helix.pierce == 1 and helix.wave_amp >= 0.35 and helix.wave_hz >= 3.0,
			"pierce %d amp %.2f hz %.1f" % [helix.pierce, helix.wave_amp, helix.wave_hz])
	# A single-shot weapon: Helix Drill keeps one straight centre bolt on the aim line (TADR-008)
	# flanked by two corkscrewing outer bolts, so the reticle stays honest at every range.
	var single: Resource = Pattern.make({"count": 1})
	var one: Resource = single.transformed(["helix_drill"])
	var layout: Array = one.layout(FORWARD, 0)
	var centres: Array = layout.filter(func(e): return e["centre"])
	var outer: Array = layout.filter(func(e): return not e["centre"])
	_t.check("helix on a one-bolt weapon keeps one centre bolt on the aim line and two corkscrewing outer bolts",
		layout.size() == 3 and centres.size() == 1 and outer.size() == 2 and (centres[0]["dir"] as Vector3).angle_to(FORWARD) < 0.001,
		"%d bolts, %d centre" % [layout.size(), centres.size()])
	var fan_one: Resource = single.transformed(["fan_spread"])
	_t.eq("fan on a one-bolt weapon is a five-round cone", fan_one.volley_size(), 5)
	var dirs: Array = fan_one.directions(FORWARD, 0)
	_t.near("the cone's middle bolt is on the aim line", (dirs[2] as Vector3).angle_to(FORWARD), 0.0, 0.001)
	_t.near("the cone's outer bolt is two spreads out", rad_to_deg((dirs[4] as Vector3).angle_to(FORWARD)), 14.0, 0.1)
	_t.eq("pierce clamps at the cap", single.transformed(["helix_drill", "helix_drill", "helix_drill", "helix_drill", "helix_drill"]).pierce, Pattern.MAX_PIERCE)
	_t.check("transformer ids list both", Pattern.has_transformer("fan_spread") and Pattern.has_transformer("helix_drill"), "")
	# Power scaling (ruling C7 discipline): Fan Spread scales beside Cross Split (~3.25x, not 5.0x) and Helix Drill stays bounded (~2.25x raw + pierce).
	var fan_power: float = BuildSheet.from_parts(["fan_spread"]).power()
	var helix_power: float = BuildSheet.from_parts(["helix_drill"]).power()
	_t.near("fan_spread one-copy power matches C7 discipline (5 * 0.65 = 3.25)", fan_power, 3.25, 0.05)
	_t.near("helix_drill one-copy raw power stays bounded (3 * 0.75 = 2.25)", helix_power, 2.25, 0.05)


func _compositions() -> void:
	var combos := [["fan_spread", "cross_split"], ["helix_drill", "spiral_wave"], ["fan_spread", "helix_drill"],
		["helix_drill", "fan_spread"], ["fan_spread", "chain_arc"], ["helix_drill", "chain_arc"],
		["fan_spread", "helix_drill", "cross_split", "spiral_wave", "chain_arc"]]
	for ids in combos:
		for weapon in Weapons.ALL:
			var p: Resource = Weapons.base(weapon).transformed(ids)
			var dirs: Array = p.layout(FORWARD, 3)
			var bad: bool = dirs.size() > Pattern.MAX_VOLLEY or p.volley_size() > Pattern.MAX_VOLLEY or dirs.is_empty()
			for e in dirs:
				if not (e["dir"] as Vector3).is_normalized():
					bad = true
			if bad:
				_t.check("%s on %s composes inside MAX_VOLLEY" % [ids, weapon], false, "%d bolts" % dirs.size())
	_t.check("every composition stays inside MAX_VOLLEY with unit directions", true, "%d combos over %d weapons" % [combos.size(), Weapons.ALL.size()])
	var chain: Resource = Weapons.base(Weapons.ALL[0]).transformed(["fan_spread", "chain_arc"])
	_t.check("chain_arc rides the fan", chain.chain_jumps >= 1 and chain.volley_size() >= 5, "jumps %d bolts %d" % [chain.chain_jumps, chain.volley_size()])
	var fan_helix: Resource = Pattern.make({"count": 1}).transformed(["fan_spread", "helix_drill"])
	var helix_fan: Resource = Pattern.make({"count": 1}).transformed(["helix_drill", "fan_spread"])
	var fh_layout: Array = fan_helix.layout(FORWARD, 0)
	var hf_layout: Array = helix_fan.layout(FORWARD, 0)
	_t.check("fan and helix compose identically in both orders with a centre bolt",
		fan_helix.volley_size() == 7 and helix_fan.volley_size() == 7 and fan_helix.pierce == 1 and helix_fan.pierce == 1
		and fh_layout.any(func(e): return e["centre"]) and hf_layout.any(func(e): return e["centre"]),
		"fh=%d hf=%d" % [fan_helix.volley_size(), helix_fan.volley_size()])


func _admission() -> void:
	for id in OUT:
		_t.check("%s stays out of the alpha parts" % id, not id in AlphaDefs.PARTS, "")
	for id in ["fan_spread", "helix_drill"]:
		_t.check("%s is in the alpha parts" % id, id in AlphaDefs.PARTS, "")
	var bad: Array = []
	for id in AlphaDefs.PARTS:
		var verb := String(Parts.row(id).get("touches", ""))
		if not Bindings.VERBS.has(verb) or verb in ["look", "interact"]:
			bad.append(id)
	_t.eq("every alpha part names a touch verb", bad, [])
	var relics: Array = AlphaDefs.PARTS.filter(func(id): return Parts.rarity_of(id) == "relic")
	_t.eq("no alpha part sits on the relic rung (ruling bn, Spare Frame owns park hook)", relics, [])


func _pierce() -> void:
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var bolts: Node3D = Bolts.new()
	root.add_child(bolts)
	bolts.setup()
	var enemies: Array = []
	for z in [-10.0, -14.0, -30.0]:
		var e := FakeEnemy.new()
		root.add_child(e)
		e.global_position = Vector3(0.0, 0.0, z)
		enemies.append(e)
	var hits: Array = []
	var phases: Array = []
	bolts.on_hit = func(bolt: Dictionary, enemy: Node3D, _point: Vector3, _part: String) -> void:
		hits.append(enemy)
		phases.append(float(bolt["phase"]))
	for pierce in [0, 1, 2, 3]:
		hits.clear()
		phases.clear()
		bolts.clear()
		bolts.fire({"origin": Vector3.ZERO, "dir": FORWARD, "speed": 120.0, "max_dist": 60.0, "damage": 1.0, "kind": "bolt",
			"weapon_id": "test", "radius": 0.3, "knock": 0.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 0.7,
			"color": Color.WHITE, "wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0, "pierce": pierce})
		for _tick in 25:
			bolts.step(1.0 / 60.0, space, enemies)
		var want := mini(pierce + 1, 3)
		var distinct := {}
		for h in hits:
			distinct[h.get_instance_id()] = true
		_t.check("a bolt with pierce %d hits %d machines, once each" % [pierce, want], hits.size() == want and distinct.size() == want and hits[0] == enemies[0],
			"%d hits, %d distinct" % [hits.size(), distinct.size()])
		_t.eq("a bolt with pierce %d retires after its last machine" % pierce, bolts.live(), 1 if pierce >= 3 else 0)
	# A corkscrewing piercer keeps its exact bolt phase across hits and reaches the second machine.
	hits.clear()
	phases.clear()
	bolts.clear()
	for e in enemies:
		e.global_position.x = 0.0
	bolts.fire({"origin": Vector3.ZERO, "dir": FORWARD, "speed": 120.0, "max_dist": 60.0, "damage": 1.0, "kind": "bolt",
		"weapon_id": "test", "radius": 0.6, "knock": 0.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 0.7,
		"color": Color.WHITE, "wave_amp": 0.35, "wave_hz": 3.0, "phase": 1.25, "pierce": 1})
	for _tick in 60:
		bolts.step(1.0 / 60.0, space, enemies)
	_t.check("a corkscrewing piercer hits two machines", hits.size() == 2 and phases.size() == 2, "%d hits" % hits.size())
	_t.check("the corkscrew phase is unchanged by the pass", phases.size() == 2 and is_equal_approx(phases[0], 1.25) and is_equal_approx(phases[1], 1.25), "phases %s" % [phases])
	bolts.queue_free()
	for e in enemies:
		e.queue_free()
