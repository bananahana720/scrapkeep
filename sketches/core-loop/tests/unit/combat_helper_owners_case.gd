extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")
const ActiveBase := preload("res://src/combat/actives/active_base.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const OrbitalSatellites := preload("res://src/combat/orbital_satellites.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Warden := preload("res://src/combat/warden.gd")
const COMBAT_PATH := "res://src/combat/combat.gd"
const COMBAT_REACH_LEFT: Array[String] = []


class RadiusDummy:
	extends Node3D
	var radius := 1.4


func _combat_decl_owners(t, pattern: String) -> Array:
	return SourceScan.matching(t, ["res://src/combat"], pattern).map(
		func(p: String) -> String: return p.trim_prefix("res://src/combat/"))


func run(t) -> void:
	var bad_base := []
	for id in ActiveDefs.ROWS:
		var script: GDScript = ActiveDefs.ROWS[id]["kind"]
		if script.get_base_script() != ActiveBase:
			bad_base.append(id)
	t.eq("every active script extends ActiveBase", bad_base, [])
	t.eq("only ActiveBase and the rack declare the shared active helpers",
		SourceScan.matching(t, ["res://src/combat/actives"], "(?m)^func (_pattern|_girth|_aim|setup)\\("),
		["res://src/combat/actives/active_base.gd", "res://src/combat/actives/active_rack.gd"])

	var bare := Node3D.new()
	var sized := RadiusDummy.new()
	t.near("enemy_girth uses explicit 0.6 fallback", ActiveBase.enemy_girth(bare, 0.6), 0.6)
	t.near("enemy_girth uses explicit 1.0 fallback", ActiveBase.enemy_girth(bare, 1.0), 1.0)
	t.near("enemy_girth reads radius when present", ActiveBase.enemy_girth(sized, 0.6), 1.4)
	bare.free()
	sized.free()

	t.eq("hazard_stripe has one owner in src/combat",
		_combat_decl_owners(t, "(?m)^\\s*static func hazard_stripe\\("), ["threat_grammar.gd"])
	t.eq("_fill has one owner in src/combat",
		_combat_decl_owners(t, "(?m)^func _fill\\("), ["enemy.gd"])
	t.eq("_absorb lives only on counter.gd",
		_combat_decl_owners(t, "(?m)^var _absorb\\b"), ["counter.gd"])
	t.eq("drill_crew and plated_brute inherit Counter.take_damage",
		_combat_decl_owners(t, "(?m)^func take_damage\\(").filter(
			func(p: String) -> bool: return p in ["counter.gd", "drill_crew.gd", "plated_brute.gd"]), ["counter.gd"])
	t.eq("warden_mind shares Warden.parse_point",
		_combat_decl_owners(t, "(?m)^static func (_point|parse_point)\\("), ["warden.gd"])

	t.eq("parse_point passes Vector3 through", Warden.parse_point(Vector3(1.0, 2.0, 3.0)), Vector3(1.0, 2.0, 3.0))
	t.eq("parse_point converts 3-number array", Warden.parse_point([1, 2.5, -3]), Vector3(1.0, 2.5, -3.0))
	t.eq("parse_point rejects short array", Warden.parse_point([1, 2]), null)
	t.eq("parse_point rejects non-numeric array", Warden.parse_point([1, "x", 3]), null)

	Threat.reset_for_tests()
	var mat := Threat.Painter.hazard_stripe()
	t.check("Threat.Painter.hazard_stripe caches triplanar stripe material",
		mat != null and mat == Threat.Painter.hazard_stripe()
		and mat.albedo_texture == Threat.Painter.stripe_texture()
		and mat.uv1_triplanar and is_equal_approx(mat.roughness, 0.6))
	Threat.reset_for_tests()
	t.check("Threat.reset_for_tests clears hazard_stripe cache", Threat.Painter.hazard_stripe() != mat)
	Threat.reset_for_tests()

	t.eq("no src file outside ultimate.gd reaches into ultimate._*",
		SourceScan.matching(t, ["res://src"], "(?<![A-Za-z0-9_])(ultimate|ult)\\._[A-Za-z]").filter(
			func(p: String) -> bool: return p != "res://src/combat/ultimate.gd"), [])
	t.eq("no src file calls retired combat._* pass-through names",
		SourceScan.matching(t, ["res://src"],
			"combat\\._(nearest_list|heat|post_consumable_buff|clear_buff|synergy_context|shot_bits|floor_at|discover)\\("), [])
	t.eq("only the listed src files reach into combat._* or spawner._*",
		SourceScan.matching(t, ["res://src"], "(?<![A-Za-z0-9_])_?(combat|spawner)\\._[a-z]").filter(
			func(p: String) -> bool: return p != COMBAT_PATH), COMBAT_REACH_LEFT)
	t.eq("no presentation file reads enemy _atk directly", SourceScan.matching(t, ["res://src/presentation"], "\"_atk\""), [])

	t.eq("only ActiveBase and swarm_remnant read get(\"radius\") in src/combat",
		_combat_decl_owners(t, "get\\(\"radius\"\\)"), ["actives/active_base.gd", "swarm_remnant.gd"])

	t.eq("overdrive_for has one owner in src/combat",
		_combat_decl_owners(t, "(?m)^func (_relic_overdrive|_overdrive_for|overdrive_for)\\("), ["relic_swaps.gd"])
	t.eq("part_synergy_info has one owner in src/combat",
		_combat_decl_owners(t, "(?m)^static func (_part_synergy_info|_part_info|part_synergy_info)\\("), ["orbital_satellites.gd"])

	var foe = Enemy.new()
	t.eq("Enemy.attack_state is empty at rest", foe.attack_state(), {})
	foe._atk = {"phase": "windup", "progress": 0.4, "tele": null}
	var st: Dictionary = foe.attack_state()
	t.eq("Enemy.attack_state exposes phase", st["phase"], "windup")
	t.near("Enemy.attack_state exposes progress", float(st["progress"]), 0.4)
	foe.free()

	t.eq("OrbitalSatellites.part_synergy_info returns empty for unknown part",
		OrbitalSatellites.part_synergy_info("__no_such_part__"), {})
