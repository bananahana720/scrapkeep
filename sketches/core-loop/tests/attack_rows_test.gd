# 2026-10-12, W13 smoke triage: class c re-pin for 8bfcc13; earlier ROWS changes b50a7e8, d37f62c, 17c0b65.
# ROWS hash 1435315606 -> 997489691; merged impact voice rows, not a design number.
extends SceneTree

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Roster := preload("res://src/combat/roster.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Rogue := preload("res://src/combat/rogue.gd")

# The attack rows of ATTACK-READS.md (prerequisite A) are a frozen contract: one row per
# attack ID the document names, all eight fields, an allegiance colour from the runtime
# palette, voices by reference to the roster and class rows, and the rows that existed
# before untouched. Nothing consumes the rows yet.

const DOC := "res://design-v3/research/attack-reads/ATTACK-READS.md"
# Hashes of var_to_str at base e05c1e3, before the attack rows were added. ROWS was re-pinned
# for the harpoon prototype, which moves grapple_fired off Kest's amber onto the rope craft's
# colour, and again for the legibility grammar, which moves harpoon_bit and harpoon_smashed into
# LINE_ROWS and adds the five grammar signals' quiet rows, and again for the deleted laps and
# drop loops, which takes their eight signals' rows out, and again for the standing activities,
# which add the activity_done row, and again for the cross-world flow's world_entered row,
# and again for the run log's quiet prompt_shown row (alpha wave 1, 2026-10-03).
const THREAT_ROWS_HASH := 952578719
const FIELDS_HASH := 4081964357
# 2026-10-04: re-pinned once at integration for the rescue_completed (META-1) and escape_window (META-5) rows (alpha wave 5).
# 2026-10-04: re-pinned again for the cogs_collected row (CG2, alpha wave 5 fix round).
# 2026-10-04: re-pinned for the achievement_earned and rescue_completed rows hearing their own cues (alpha wave 7, snd-achievement-rescue).
# 2026-10-04: re-pinned for the world_entered row hearing the world stinger at priority 3 (alpha wave 11 fix, zone-entry cue).
const ROWS_HASH := 782810388  # 2026-11-10 (wave 36 unslop-hudwords): hud wording only on three rows (core_gained, synergy_discovered, launched) and the callout_notes row; was 84001769. 2026-11-09 (call-ins): the quiet trade_taken row; existing rows unchanged; was 697194992. 2026-10-24 (intro cards clear before a fight): the silent warden_sighted row; existing rows unchanged; was 3961079298. 2026-10-24 merge of #391 (boss phases: attack_cued, fight_phase_changed) onto IL-01 grey panels (panel_gained); was 1309837529 (panels) and 1222827016 (#391). 2026-10-23 (IL-01 grey panels): the panel_gained row hearing panel_ratchet; existing rows unchanged; was 394211231. 2026-10-19 (ACHIEVEMENTS-REFRESH): five quiet rows for the new achievement signals (special_broken, radio_take_found, relay_stake_paid, maker_set_completed, overflow_cashed); existing rows unchanged; was 766403076. 2026-10-18 (Highdraft ring-outs, merged onto stage/alpha-w17): the enemy_ringed_out row hearing ring_out_fall; was 1463771709. 2026-10-17 (item tiers and actives): the active_fired row; was 997489691. 2026-10-09 (wave 12 VX-SURF): ANCIENT moved from 3d8bff to 9dff3c (Andrew's pick), which changes the colour value of weak_point_opened, landmark_hum and reactor_vented; rows otherwise unchanged (restoring the old colour restores the old hash); was 1079977938
# E04 is the one enemy row whose committed lane differs from its roster row's telegraph
# (the roster names the miniboss's leap, INSTANT).
const ROSTER_TELEGRAPH_EXEMPT := ["E04"]

var _failures := 0


func _initialize() -> void:
	_check_ids()
	_check_fields()
	_check_palette()
	_check_references()
	_check_placeholders()
	_check_existing()
	_report_counts()
	print("attack_rows_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _doc_ids() -> Array[String]:
	var ids: Array[String] = []
	var text := FileAccess.get_file_as_string(DOC)
	var re := RegEx.create_from_string("(?m)^\\| ([EWBP][0-9]{2}) ")
	for m in re.search_all(text):
		ids.append(m.get_string(1))
	return ids


func _check_ids() -> void:
	var doc := _doc_ids()
	var seen := {}
	var dup_doc: Array[String] = []
	for id in doc:
		if seen.has(id):
			dup_doc.append(id)
		seen[id] = true
	# F6 2026-10-04: W05 left the document with the magnet, so it names 42 ids.
	_report("doc ids", doc.size() == 42 and dup_doc.is_empty(), "%d ids parsed from the document, %d repeated %s" % [doc.size(), dup_doc.size(), dup_doc])
	var missing: Array[String] = []
	for id in doc:
		if not EventKinds.has_attack(id):
			missing.append(id)
	_report("every id has a row", missing.is_empty(), "%d of %d document ids without a row %s" % [missing.size(), doc.size(), missing])
	# 2026-10-04, alpha wave 8: an id owned by a declared later-world roster kind (a row with
	# a "world", roster_dig.gd and roster_highdraft.gd) is reserved ahead of the document, and
	# so is one owned by a kill-first special (a "priority", roster_specials.gd).
	var extra: Array[String] = []
	for id in EventKinds.ATTACK_ROWS:
		if not seen.has(id) and not _reserved(id):
			extra.append(id)
	_report("no invented ids", extra.is_empty(), "%d rows the document does not name %s" % [extra.size(), extra])
	# A dictionary literal cannot hold a key twice, so a shared ID also shows as two rows
	# claiming one pose key, one label or one accessor result.
	var poses := {}
	var labels := {}
	var shared: Array[String] = []
	for id in EventKinds.attack_ids():
		var pose := EventKinds.attack_pose(id)
		var label := EventKinds.attack_label(id)
		if pose != EventKinds.PLACEHOLDER and poses.has(pose):
			shared.append("%s/%s pose" % [poses[pose], id])
		if labels.has(label):
			shared.append("%s/%s label" % [labels[label], id])
		poses[pose] = id
		labels[label] = id
	_report("ids unique", shared.is_empty() and EventKinds.attack_ids().size() == EventKinds.ATTACK_ROWS.size(), "%d rows share a pose key or label %s" % [shared.size(), shared])


func _reserved(id: String) -> bool:
	var row := EventKinds.attack_row(id)
	var owner := Roster.row(String(row["owner"]))
	# 2026-10-23 (rogue fleet mini-bosses, Q-P25): E34 to E39 are owned by the rogue rows
	# (combat/rogue.gd), which sit outside the roster and the document.
	if row["owner_kind"] == "rogue":
		return Rogue.ROWS.has(String(row["owner"]))
	return row["owner_kind"] == "roster" and (owner.has("world") or owner.has("priority"))


func _check_fields() -> void:
	var lacking: Array[String] = []
	var malformed: Array[String] = []
	for id in EventKinds.ATTACK_ROWS:
		var row := EventKinds.attack_row(id)
		for field in EventKinds.ATTACK_FIELDS:
			if not row.has(field):
				lacking.append("%s.%s" % [id, field])
		if row.get("group", "") not in EventKinds.ATTACK_GROUPS \
				or row.get("glyph", "") not in EventKinds.SHAPES \
				or row.get("floor", "") not in EventKinds.FLOOR_MODES and row.get("floor", "") != EventKinds.PLACEHOLDER \
				or not row.get("color") is Color \
				or (row.get("threat", "x") != "" and not EventKinds.THREAT_ROWS.has(row.get("threat", "x"))) \
				or String(row.get("label", "")) == "" or String(row.get("pose", "")) == "" \
				or String(row.get("warn", "")) == "" or String(row.get("release", "")) == "" \
				or row.get("allegiance", "") not in ["hostile", "player", "neutral"]:
			malformed.append(id)
	_report("eight fields", lacking.is_empty(), "%d missing fields %s" % [lacking.size(), lacking])
	_report("well formed", malformed.is_empty(), "%d malformed rows %s" % [malformed.size(), malformed])
	var acc_ok := true
	for id in EventKinds.ATTACK_ROWS:
		var row := EventKinds.attack_row(id)
		acc_ok = acc_ok and EventKinds.attack_label(id) == row["label"] and EventKinds.attack_threat(id) == row["threat"] \
			and EventKinds.attack_glyph(id) == row["glyph"] and EventKinds.attack_color(id) == row["color"] \
			and EventKinds.attack_pose(id) == row["pose"] and EventKinds.attack_warn_cue(id) == row["warn"] \
			and EventKinds.attack_release_cue(id) == row["release"] and EventKinds.attack_floor(id) == row["floor"]
	acc_ok = acc_ok and EventKinds.attack_row("Z99").is_empty() and not EventKinds.has_attack("Z99") \
		and EventKinds.attack_label("Z99") == "" and EventKinds.attack_warn_cue("Z99") == EventKinds.NONE
	_report("accessors", acc_ok, "every accessor reads its row; an unknown id reads empty")


func _check_palette() -> void:
	var palette: Array[Color] = []
	var script: GDScript = load("res://src/core/palette.gd")
	var constants: Dictionary = script.get_script_constant_map()
	for name in constants:
		var value = constants[name]
		if value is Color:
			palette.append(value)
	var off: Array[String] = []
	for id in EventKinds.ATTACK_ROWS:
		if not EventKinds.attack_color(id) in palette:
			off.append(id)
	_report("palette colours", off.is_empty() and palette.size() >= 10, "%d rows outside the %d runtime palette colours %s" % [off.size(), palette.size(), off])
	var hostile_off: Array[String] = []
	for id in EventKinds.ATTACK_ROWS:
		var row := EventKinds.attack_row(id)
		if row["allegiance"] == "hostile" and row["color"] != Palette.HAZARD:
			hostile_off.append(id)
	_report("hostile is hazard", hostile_off.is_empty(), "%d hostile rows not HAZARD %s" % [hostile_off.size(), hostile_off])


func _check_references() -> void:
	var bad: Array[String] = []
	for id in EventKinds.ATTACK_ROWS:
		var row := EventKinds.attack_row(id)
		var owner := String(row["owner"])
		match String(row["owner_kind"]):
			"roster":
				if not Roster.has(owner):
					bad.append("%s roster %s" % [id, owner])
				elif id not in ROSTER_TELEGRAPH_EXEMPT and Roster.row(owner)["telegraph"] != _threat_type(row["threat"]):
					bad.append("%s threat vs roster telegraph" % id)
			"rogue":
				if not Rogue.ROWS.has(owner):
					bad.append("%s rogue %s" % [id, owner])
			"faction":
				if not Roster.FACTIONS.has(owner) or not owner in Roster.WARDEN_FAMILIES:
					bad.append("%s faction %s" % [id, owner])
			"boss":
				if owner != "brindle":
					bad.append("%s boss %s" % [id, owner])
			"class":
				var def := ClassDef.by_id(owner)
				if def == null:
					bad.append("%s class %s" % [id, owner])
				elif row["glyph"] != def.shape or row["color"] != def.color:
					bad.append("%s glyph or colour differs from class %s" % [id, owner])
			"pilot_any":
				if owner != "any":
					bad.append("%s pilot_any %s" % [id, owner])
			_:
				bad.append("%s owner_kind %s" % [id, row["owner_kind"]])
	# enemy._facts_row tells a rogue's two rows apart by lane: each rogue has one lane attack,
	# so it owns one lane row and one row for its ring.
	for owner in Rogue.ROWS:
		var lanes := 0
		var rings := 0
		for id in EventKinds.ATTACK_ROWS:
			var row := EventKinds.attack_row(id)
			if row["owner_kind"] == "rogue" and row["owner"] == owner:
				lanes += 1 if row["threat"] == "threat_lane" else 0
				rings += 0 if row["threat"] == "threat_lane" else 1
		if lanes != _rogue_lanes(owner) or lanes + rings != Rogue.ROWS[owner].attacks.size():
			bad.append("%s rows: %d lane, %d ring" % [owner, lanes, rings])
	_report("voices by reference", bad.is_empty(), "%d rows whose owner does not resolve to the roster or class rows %s" % [bad.size(), bad])
	var groups_ok := true
	for id in EventKinds.attack_ids():
		var prefix: String = {"E": "enemy", "W": "warden", "B": "brindle", "P": "pilot"}[id.substr(0, 1)]
		groups_ok = groups_ok and EventKinds.attack_row(id)["group"] == prefix
	_report("group matches id", groups_ok, "E, W, B and P rows sit in enemy, warden, brindle and pilot")


func _rogue_lanes(owner: String) -> int:
	var lanes := 0
	for name in Rogue.ROWS[owner].attacks:
		lanes += 1 if String(Rogue.ATTACKS[name].shape) == "lane" else 0
	return lanes


func _threat_type(key: String) -> int:
	var at := Threat.KINDS.find(key)
	return at if at >= 0 else -1


func _check_placeholders() -> void:
	var unlisted: Array[String] = []
	var unknown: Array[String] = []
	for id in EventKinds.ATTACK_ROWS:
		var row := EventKinds.attack_row(id)
		for field in EventKinds.ATTACK_FIELDS:
			if row[field] is String and row[field] == EventKinds.PLACEHOLDER and not field in row["open"]:
				unlisted.append("%s.%s" % [id, field])
		for field in row["open"]:
			if not field in EventKinds.ATTACK_FIELDS:
				unknown.append("%s.%s" % [id, field])
	_report("placeholders listed", unlisted.is_empty() and unknown.is_empty(), "%d placeholder values not in open %s, %d open names that are no field %s" % [unlisted.size(), unlisted, unknown.size(), unknown])


func _check_existing() -> void:
	var threat_hash := var_to_str(EventKinds.THREAT_ROWS).hash()
	var fields_hash := var_to_str(EventKinds.FIELDS).hash()
	_report("threat rows unchanged", threat_hash == THREAT_ROWS_HASH and EventKinds.THREAT_ROWS.size() == 4, "THREAT_ROWS hash %d, expected %d" % [threat_hash, THREAT_ROWS_HASH])
	_report("row schema unchanged", fields_hash == FIELDS_HASH, "FIELDS hash %d, expected %d" % [fields_hash, FIELDS_HASH])
	var rows_hash := var_to_str(EventKinds.ROWS).hash()
	_report("existing row values pinned", rows_hash == ROWS_HASH, "ROWS hash %d, expected %d" % [rows_hash, ROWS_HASH])
	var acc_ok := true
	for kind in EventKinds.ROWS:
		var row: Dictionary = EventKinds.ROWS[kind]
		acc_ok = acc_ok and EventKinds.has(kind) and EventKinds.row(kind) == row and EventKinds.color(kind) == row["color"] \
			and EventKinds.priority(kind) == row["priority"] and EventKinds.hud(kind) == String(row["hud"]).format({}) \
			and EventKinds.objective(kind) == String(row["objective"]).format({})
	acc_ok = acc_ok and not EventKinds.has("no_such_kind") and EventKinds.row("no_such_kind").is_empty() \
		and EventKinds.priority("no_such_kind") == 0 and EventKinds.color("no_such_kind") == Palette.SAND
	_report("existing accessors", acc_ok, "has, row, color, priority, hud and objective read every ROWS row as before")


func _report_counts() -> void:
	var placeholders: Array[String] = []
	for id in EventKinds.ATTACK_ROWS:
		for field in EventKinds.attack_open(id):
			placeholders.append("%s.%s" % [id, field])
	print("[counts] enemy %d, warden %d, brindle %d, pilot %d, total %d" % [EventKinds.attack_ids("enemy").size(), EventKinds.attack_ids("warden").size(), EventKinds.attack_ids("brindle").size(), EventKinds.attack_ids("pilot").size(), EventKinds.attack_ids().size()])
	print("[open fields] %d: %s" % [placeholders.size(), ", ".join(placeholders)])
