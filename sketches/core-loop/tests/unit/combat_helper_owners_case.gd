extends RefCounted

const ActiveBase := preload("res://src/combat/actives/active_base.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Warden := preload("res://src/combat/warden.gd")


class RadiusDummy:
	extends Node3D
	var radius := 1.4


func _has_decl(path: String, pattern: String) -> bool:
	var re := RegEx.new()
	re.compile(pattern)
	return re.search(FileAccess.get_file_as_string(path)) != null


func _combat_decl_owners(pattern: String) -> Array:
	var out := []
	for file in DirAccess.get_files_at("res://src/combat"):
		if not file.ends_with(".gd"):
			continue
		var path := "res://src/combat/" + file
		if _has_decl(path, pattern):
			out.append(file)
	out.sort()
	return out


func run(t) -> void:
	var bad_base := []
	var bad_dup := []
	for id in ActiveDefs.ROWS:
		var script: GDScript = ActiveDefs.ROWS[id]["kind"]
		if script.get_base_script() != ActiveBase:
			bad_base.append(id)
		var path := script.resource_path
		for pat in ["(?m)^func _pattern\\(", "(?m)^func _girth\\(", "(?m)^func _aim\\(", "(?m)^func setup\\("]:
			if _has_decl(path, pat):
				bad_dup.append(id + ":" + pat)
	t.eq("every active script extends ActiveBase", bad_base, [])
	t.eq("no active script duplicates ActiveBase helpers", bad_dup, [])

	var bare := Node3D.new()
	var sized := RadiusDummy.new()
	t.near("enemy_girth uses explicit 0.6 fallback", ActiveBase.enemy_girth(bare, 0.6), 0.6)
	t.near("enemy_girth uses explicit 1.0 fallback", ActiveBase.enemy_girth(bare, 1.0), 1.0)
	t.near("enemy_girth reads radius when present", ActiveBase.enemy_girth(sized, 0.6), 1.4)
	bare.free()
	sized.free()

	t.eq("hazard_stripe has one owner in src/combat",
		_combat_decl_owners("(?m)^\\s*static func hazard_stripe\\("), ["threat_grammar.gd"])
	t.eq("_fill has one owner in src/combat",
		_combat_decl_owners("(?m)^func _fill\\("), ["enemy.gd"])
	t.eq("_absorb lives only on counter.gd",
		_combat_decl_owners("(?m)^var _absorb\\b"), ["counter.gd"])
	t.check("drill_crew and plated_brute inherit Counter.take_damage",
		not _has_decl("res://src/combat/drill_crew.gd", "(?m)^func take_damage\\(")
		and not _has_decl("res://src/combat/plated_brute.gd", "(?m)^func take_damage\\("))
	t.check("warden_mind shares Warden.parse_point",
		not _has_decl("res://src/combat/warden_mind.gd", "(?m)^static func _point\\("))

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
