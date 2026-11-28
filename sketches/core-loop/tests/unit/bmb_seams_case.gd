extends RefCounted

const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const PartMutations := preload("res://src/build/part_mutations.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const MakerDefs := preload("res://src/build/maker_defs.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Relics := preload("res://src/build/relics.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Synergies := preload("res://src/build/synergies.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const MindHand := preload("res://src/combat/mind_hand.gd")
const Warden := preload("res://src/combat/warden.gd")
const Waking := preload("res://src/boss/waking.gd")
const Boss := preload("res://src/boss/boss.gd")
const RigidBall := preload("res://src/movement/rigid_ball.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")


func run(t) -> void:
	var src_files := _walk_gd("res://src")
	_check_single_sources(t, src_files)
	_check_grapple_head_precedence(t)
	_check_closed_reach_ins(t, src_files)
	_check_seeded_roll_determinism(t)
	_check_preload_and_seams_hygiene(t)
	_check_explicit_setters(t, src_files)


func _read_src(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _walk_gd(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				out.append_array(_walk_gd(full))
			elif entry.ends_with(".gd"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _strip_comment(line: String) -> String:
	var idx := line.find("#")
	return line.substr(0, idx) if idx >= 0 else line


func _check_single_sources(t, src_files: Array[String]) -> void:
	t.eq("ItemGen.RARITIES aliases PartDef.RARITIES", ItemGen.RARITIES, PartDef.RARITIES)
	var expected_pilots: Array = []
	for c in ClassDef.all():
		expected_pilots.append(String(c.id))
	t.eq("Relics.pilots derives from ClassDef.all", Relics.pilots(), expected_pilots)
	t.eq("Relics.valid_makers derives from MakerSets.SETS", Relics.valid_makers(), MakerSets.SETS.keys())
	t.check("Parts drops MAKER_SET_PIECES", not ("MAKER_SET_PIECES" in Parts))
	t.check("MakerSets drops SPILLWAY alias", not ("SPILLWAY" in MakerSets))
	t.check("MakerSets drops GRAPPLE_MUTATIONS alias", not ("GRAPPLE_MUTATIONS" in MakerSets))
	t.eq("MakerSets.SETS matches MakerDefs.SETS", MakerSets.SETS, MakerDefs.SETS)
	var rarity_owners: Array = []
	var maker_set_owners: Array = []
	var maker_piece_owners: Array = []
	var relic_list_owners: Array = []
	for path in src_files:
		var text := _read_src(path)
		for raw_line in text.split("\n"):
			var code := _strip_comment(raw_line)
			if code.contains("const RARITIES :=") and code.contains("[\"common\""):
				rarity_owners.append(path)
			if code.contains("const SETS := {") and text.contains("spillway_works"):
				maker_set_owners.append(path)
			if code.contains("MAKER_SET_PIECES"):
				maker_piece_owners.append(path)
			if path.begins_with("res://src/build/") and (code.contains("const PILOTS :=") or code.contains("const VALID_MAKERS :=")):
				relic_list_owners.append(path)
	t.eq("RARITIES literal table has one owner", rarity_owners, ["res://src/build/part_def.gd"])
	t.eq("Maker SETS literal table has one owner", maker_set_owners, ["res://src/build/maker_defs.gd"])
	t.eq("MAKER_SET_PIECES has zero declarations in src", maker_piece_owners, [])
	t.eq("Relics omits hardcoded PILOTS and VALID_MAKERS", relic_list_owners, [])


func _pieces_for_maker(maker: String) -> Array:
	var need: int = int(MakerDefs.SETS[maker]["pieces"])
	var held: Array = []
	for part_id in Parts.ids():
		if MakerSets.maker_of(part_id) == maker:
			held.append(part_id)
			if held.size() >= need:
				break
	return held


func _check_grapple_head_precedence(t) -> void:
	var moss_pieces := _pieces_for_maker(MakerDefs.MOSS)
	var mind_pieces := _pieces_for_maker(MakerDefs.MIND)
	var fleet_pieces := _pieces_for_maker(MakerDefs.FLEET)
	t.check("MakerSets.live_grapple_mutations activates moss head",
		"dragnet_siphon" in MakerSets.live_grapple_mutations(moss_pieces))
	var moss_and_mind: Array = moss_pieces + mind_pieces
	var active_mm: Dictionary = Parts.active_grapple_mutations(moss_and_mind)
	t.eq("moss + mind head winner matches GRAPPLE_MUTATIONS order (live_bus)",
		String(active_mm.get("head", {}).get("id", "")), "live_bus")
	var moss_and_fleet: Array = moss_pieces + fleet_pieces
	var active_mf: Dictionary = Parts.active_grapple_mutations(moss_and_fleet)
	t.eq("moss + fleet head winner matches GRAPPLE_MUTATIONS order (wrecking_flail)",
		String(active_mf.get("head", {}).get("id", "")), "wrecking_flail")
	var all_three: Array = moss_pieces + mind_pieces + fleet_pieces
	var active_all: Dictionary = Parts.active_grapple_mutations(all_three)
	t.eq("moss + mind + fleet head winner is wrecking_flail",
		String(active_all.get("head", {}).get("id", "")), "wrecking_flail")


func _check_closed_reach_ins(t, src_files: Array[String]) -> void:
	var forbidden := [
		"._pickup_material",
		"._rest",
		"._takeover_cd",
		"._probe",
		"._refit(",
		"._center",
		"._dropping",
		"\"_look\"",
		"\"_kit\"",
		"._charging",
		"._pulse_clock",
	]
	var allowed := {
		"._rest": [
			"res://src/combat/dispatcher.gd",
			"res://src/combat/flail.gd",
			"res://src/combat/foreman.gd",
		],
		"._center": [
			"res://src/presentation/arena_waking_dress.gd",
		],
		"._charging": ["res://src/combat/warden_reactor.gd"],
		"._pulse_clock": ["res://src/combat/warden_reactor.gd"],
	}
	var hits: Array = []
	for path in src_files:
		var text := _read_src(path)
		var lines := text.split("\n")
		for i in lines.size():
			var code := _strip_comment(lines[i])
			for bad in forbidden:
				if code.contains(bad) and not path in allowed.get(bad, []):
					hits.append("%s:%d %s" % [path, i + 1, bad])
	t.eq("zero unallowed cross-file ._ reach-ins across src", hits, [])
	t.check("ScrapField exposes pickup_material", ScrapField.pickup_material(Color.WHITE) is ShaderMaterial)
	var hand := MindHand.new()
	t.check("MindHand exposes reset_rest", hand.has_method("reset_rest"))
	hand.free()
	var warden := Warden.new()
	t.check("Warden exposes is_charging/pulse_clock/visual_rig",
		warden.has_method("is_charging") and warden.has_method("pulse_clock") and warden.has_method("visual_rig"))
	warden.free()
	var waking := Waking.new()
	t.check("Waking exposes arena_center/is_dropping",
		waking.has_method("arena_center") and waking.has_method("is_dropping"))
	waking.free()
	var boss := Boss.new()
	t.check("Boss exposes suppress_lobbers", boss.has_method("suppress_lobbers"))
	boss.free()
	var rigid := RigidBall.new()
	t.check("RigidBall exposes probe", rigid.has_method("probe"))
	rigid.free()
	var player := PlayerBall.new()
	t.check("PlayerBall exposes refit, shove_planar, body_planar_speed, speed_bank_move",
		player.has_method("refit") and player.has_method("shove_planar")
		and player.has_method("body_planar_speed") and player.has_method("speed_bank_move"))
	t.check("PlayerBall deletes _refit alias", not player.has_method("_refit"))
	player.free()


func _check_seeded_roll_determinism(t) -> void:
	for seed_val in [101, 20260927, 9981]:
		var rng_a := RandomNumberGenerator.new()
		var rng_b := RandomNumberGenerator.new()
		rng_a.seed = seed_val
		rng_b.seed = seed_val
		var a1: Array = Parts.roll(rng_a, ["common", "rare"], "pylon_engineer", [], 3)
		var b1: Array = Parts.roll(rng_b, ["common", "rare"], "pylon_engineer", [], 3)
		t.eq("Parts.roll deterministic picks seed %d" % seed_val, a1, b1)
		t.eq("Parts.roll deterministic rng state seed %d" % seed_val, rng_a.randi(), rng_b.randi())
		var a2: Array = Parts.roll_for_stage(rng_a, ["common", "rare", "relic"], "runner_gunner", a1, 3, 2)
		var b2: Array = Parts.roll_for_stage(rng_b, ["common", "rare", "relic"], "runner_gunner", b1, 3, 2)
		t.eq("Parts.roll_for_stage deterministic picks seed %d" % seed_val, a2, b2)
		t.eq("Parts.roll_for_stage deterministic rng state seed %d" % seed_val, rng_a.randi(), rng_b.randi())


func _check_preload_and_seams_hygiene(t) -> void:
	var boss_src := _read_src("res://src/boss/boss.gd")
	t.check("boss omits reward_gates.gd preload", not boss_src.contains("reward_gates.gd"))
	t.check("boss calls shove_planar unconditionally", boss_src.contains("\tctx.player.shove_planar("))
	var mind_dress_src := _read_src("res://src/boss/mind_dress.gd")
	var inline_preload := false
	for line in mind_dress_src.split("\n"):
		if line.begins_with("\t") and line.contains("preload("):
			inline_preload = true
	t.check("mind_dress hoists inline preloads", not inline_preload)
	var waking_src := _read_src("res://src/boss/waking.gd")
	t.check("waking routes planar speed through body_planar_speed", waking_src.contains("body_planar_speed()"))
	var offers_src := _read_src("res://src/build/part_offers.gd")
	t.check("part_offers reads PartDef.RARITIES directly", offers_src.contains("PartDef.RARITIES"))


func _check_explicit_setters(t, src_files: Array[String]) -> void:
	var direct_writes: Array = []
	var assign_re := RegEx.new()
	assign_re.compile("(Parts\\.(seams|opened_items)|Synergies\\.table)(\\[[^\\]]+\\])?\\s*=(?!=)")
	for path in src_files:
		if path in ["res://src/build/parts.gd", "res://src/build/synergies.gd"]:
			continue
		var lines := _read_src(path).split("\n")
		for i in lines.size():
			var code := _strip_comment(lines[i])
			if assign_re.search(code) != null:
				direct_writes.append("%s:%d" % [path, i + 1])
	t.eq("no file under src assigns Parts.seams, Parts.opened_items or Synergies.table", direct_writes, [])
	var prev_seams: Dictionary = Parts.seams.duplicate(true)
	var prev_opened: Dictionary = Parts.opened_items.duplicate(true)
	var prev_table = Synergies.table
	Parts.set_seams({"probe_flag": true})
	t.eq("Parts.set_seams writes Parts.seams", Parts.seams.get("probe_flag", false), true)
	Parts.set_opened_items({"probe_item": true})
	t.eq("Parts.set_opened_items writes Parts.opened_items", Parts.opened_items.get("probe_item", false), true)
	var sentinel := {"tag": "probe"}
	Synergies.set_table(sentinel)
	t.eq("Synergies.set_table writes Synergies.table", Synergies.table, sentinel)
	Parts.set_seams(prev_seams)
	Parts.set_opened_items(prev_opened)
	Synergies.set_table(prev_table)
