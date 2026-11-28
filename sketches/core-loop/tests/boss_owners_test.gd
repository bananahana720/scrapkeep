extends SceneTree

const BossAttacks := preload("res://src/boss/boss_attacks.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const StubBoss := preload("res://src/boss/stub_boss.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const WakingAttacks := preload("res://src/boss/waking_attacks.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("boss_owners_test")


func _initialize() -> void:
	_check_waking_mind_boundary()
	_check_attack_owners()
	_check_dress_and_cleanup_owners()
	quit(_t.verdict())


func _src_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	out.sort()
	return out


func _owners_of(token: String, paths: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for path in paths:
		if FileAccess.get_file_as_string(path).contains(token):
			found.append(path)
	return found


func _check_waking_mind_boundary() -> void:
	var forbidden := [
		"res://src/boss/mind_attacks.gd",
		"res://src/boss/mind_dress.gd",
		"res://src/boss/mind.gd",
	]
	var hits: Array[String] = []
	for path in _src_files("res://src/boss"):
		if not path.get_file().begins_with("waking"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for target in forbidden:
			if text.contains(target):
				hits.append("%s -> %s" % [path, target])
	_t.check("waking*.gd never preloads mind*.gd", hits.is_empty(), str(hits))


func _check_attack_owners() -> void:
	var boss_files := _src_files("res://src/boss")
	_t.eq("Hazard.from_def has one definition in src/boss/",
		_owners_of("func from_def(", boss_files), ["res://src/boss/hazard.gd"])
	var attack_files: Array[String] = ["res://src/boss/mind_attacks.gd", "res://src/boss/waking_attacks.gd"]
	_t.eq("MindAttacks and WakingAttacks do not define build()",
		_owners_of("func build(", attack_files), [])
	for token in [
		"func escape_point(",
		"func _clear(",
		"func covers(",
		"func bearing(",
		"func rng(",
		"func flat(",
	]:
		_t.eq("%s has one definition in src/boss/" % token,
			_owners_of(token, boss_files), ["res://src/boss/boss_attacks.gd"])
	for old_token in ["func _bearing(", "func _rng(", "static func _flat("]:
		_t.eq("%s does not reappear in src/boss/" % old_token,
			_owners_of(old_token, boss_files), [])
	_t.eq("func _flat( does not reappear in attack or hazard scripts",
		_owners_of("func _flat(", ["res://src/boss/mind_attacks.gd", "res://src/boss/waking_attacks.gd", "res://src/boss/hazard.gd"]), [])

	_t.eq("BossAttacks.flat zeroes y", BossAttacks.flat(Vector3(3.0, 9.0, -4.0)), Vector3(3.0, 0.0, -4.0))
	_t.eq("MindAttacks.choose matches BossAttacks.choose",
		MindAttacks.choose(17, 3, ["rush"]), BossAttacks.choose(MindAttacks.FAMILIES, 17, 3, ["rush"]))
	_t.eq("WakingAttacks.choose matches BossAttacks.choose",
		WakingAttacks.choose(17, 3, ["bore"]), BossAttacks.choose(WakingAttacks.FAMILIES, 17, 3, ["bore"]))
	var lane_desc: Dictionary = MindAttacks.lane(5, Vector3(8.0, 0.0, 0.0), Vector3.ZERO, 1, 36.0)[0]
	var lane_h := Hazard.from_def(lane_desc)
	_t.check("Hazard.from_def builds lane hazard",
		lane_h.shape == Hazard.Shape.LANE and lane_h.attack_id == lane_desc["id"]
		and is_equal_approx(lane_h.half_width, MindAttacks.LANE_HALF))
	lane_h.free()
	var rush_desc: Dictionary = MindAttacks.rush(5, Vector3(12.0, 0.0, 0.0), Vector3.ZERO, 3, 36.0)[0]
	var rush_h := Hazard.from_def(rush_desc)
	_t.check("Hazard.from_def builds annulus hazard",
		rush_h.shape == Hazard.Shape.ANNULUS and is_equal_approx(rush_h.r_in, 8.0) and is_equal_approx(rush_h.r_out, 16.0))
	rush_h.free()
	var plate_desc: Dictionary = MindAttacks.plate(5, Vector3(12.0, 0.0, 0.0), Vector3.ZERO, 4, 36.0)[0]
	var plate_h := Hazard.from_def(plate_desc)
	_t.check("Hazard.from_def builds sector hazard",
		plate_h.shape == Hazard.Shape.SECTOR and plate_h.type == Threat.Type.WAVE
		and is_equal_approx(plate_h.a_to - plate_h.a_from, 2.0 * MindAttacks.PLATE_HALF_SPAN))
	plate_h.free()


func _check_dress_and_cleanup_owners() -> void:
	var boss_files := _src_files("res://src/boss")
	_t.eq("has_parts has one definition in src/boss/",
		_owners_of("func has_parts(", boss_files), ["res://src/boss/boss_model.gd"])
	_t.eq("_has_parts does not reappear in src/boss/",
		_owners_of("func _has_parts(", boss_files), [])
	var dress_files: Array[String] = ["res://src/boss/mind_dress.gd", "res://src/boss/waking_dress.gd"]
	for token in ["func _card_layer(", "func _fade(", "func _label("]:
		_t.eq("%s does not reappear in dress scripts" % token, _owners_of(token, dress_files), [])
	var card_files: Array[String] = [
		"res://src/boss/boss_model.gd",
		"res://src/boss/mind_dress.gd",
		"res://src/boss/waking_dress.gd",
	]
	for token in ["CanvasLayer.new()", "StyleBoxFlat.new()", 'event.is_action_pressed("ui_accept")']:
		_t.eq("%s lives only in boss_model.gd among boss dress scripts" % token,
			_owners_of(token, card_files), ["res://src/boss/boss_model.gd"])
	_t.eq("_free_hazards has one definition in src/boss/",
		_owners_of("func _free_hazards(", boss_files), ["res://src/boss/stub_boss.gd"])
	_t.eq("_is_reel_impact has one definition in src/boss/",
		_owners_of("func _is_reel_impact(", boss_files), ["res://src/boss/stub_boss.gd"])
	var mod_files: Array[String] = ["res://src/boss/mind.gd", "res://src/boss/waking.gd"]
	_t.eq("mind.gd and waking.gd do not duplicate spawner.is_reel_impact fallback",
		_owners_of("ctx.spawner.is_reel_impact(", mod_files), [])

	var parent := Node3D.new()
	var child := Node3D.new()
	child.name = "CombatSeat"
	parent.add_child(child)
	_t.check("BossModel.has_parts finds present part", BossModel.has_parts(parent, ["CombatSeat"]))
	_t.check("BossModel.has_parts rejects missing part", not BossModel.has_parts(parent, ["CombatSeat", "MissingPart"]))
	parent.free()

	var host := Node3D.new()
	var layer := BossModel.card_layer(host, "ProbeCard")
	var panel := BossModel.card_panel(Color(0.1, 0.1, 0.1, 0.9), Color.WHITE, 18.0)
	var card_root: Control = layer.get_child(0)
	card_root.add_child(panel)
	panel.get_child(0).add_child(BossModel.card_label("Test", 18, Color.WHITE))
	_t.check("BossModel.card_layer sets layer 40 and ignores mouse",
		layer.layer == BossModel.CARD_LAYER and card_root.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var left := BossModel.step_card(layer, BossModel.CARD_FADE_S, BossModel.CARD_FADE_S * 0.5)
	_t.near("BossModel.step_card fades alpha over CARD_FADE_S", card_root.modulate.a, 0.5, 0.001)
	left = BossModel.step_card(layer, left, BossModel.CARD_FADE_S)
	_t.check("BossModel.step_card queues free when timer expires", left == 0.0 and layer.is_queued_for_deletion())
	host.free()

	var stub := StubBoss.new()
	var h := Hazard.new()
	stub.attacks.append({"hazards": [h]})
	stub._clear_attacks()
	_t.check("StubBoss._clear_attacks frees hazards and clears attacks",
		stub.attacks.is_empty() and h.is_queued_for_deletion())
	h.free()
	stub.free()
