extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Sheet := preload("res://src/build/build_sheet.gd")
const Effects := preload("res://src/build/item_effects.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
# Authored row review: parts.gd CATALOGUE/EVOLVED, items.gd TABLE/CELLS;
# alpha_defs.gd PARTS is a subset. This oracle is literal, independent of PartDef.
const EXPECTED_LAYERS := {
	# 2026-10-11 SG3 merge: SG5's load_dividend (trigger on_hit, effect burden_payout) is player-global.
	"load_dividend": "global",
	# 2026-10-12 SR9 merge: relay_convergence tunes the hold relay's ring and charge, player-global.
	"relay_convergence": "global",
	"hot_rivets": "local", "loose_trigger": "local", "long_barrel": "local",
	"long_spool": "global", "tread_plating": "global", "boost_coil": "global",
	"dash_vane": "global", "rivet_plating": "global", "magnet_spool": "global",
	# 2026-10-15 PC-POOL re-pin: live_line was a global reel_speed mod, now a harpoon_lock_deg mod,
	# which is not a weapon mod, so it stays global (re-pinned again on coordinator ruling P4; round 1 had it local).
	"grip_tread": "global", "live_line": "global", "vent_baffle": "global",
	# 2026-10-15 SQ19b: Tally's winch_pawl is a reel_speed mod, not a weapon mod, so global.
	"winch_pawl": "global",
	"spring_shims": "global", "drop_weight": "global", "slag_rounds": "local",
	"double_feed": "local", "focus_lens": "local", "cross_split": "local",
	"spiral_wave": "local", "chain_arc": "local", "frost_vane": "global",
	"arc_coil": "global", "pylon_capacitor": "global", "runner_overclock": "global",
	"sunforged_core": "local", "gatling_heart": "local", "horizon_optic": "local",
	"rime_rounds": "local", "galvanic_rounds": "local", "ram_plow": "global",
	"spare_cell": "global", "tempest_core": "local", "rime_heart": "global",
	"scrap_gravity": "global",
	"cap_relay": "global", "vault_battery": "global", "sprint_cell": "global",
	"cloak_flask": "global", "quick_spool": "global", "overcharge_coil": "global",
	"reserve_tank": "global", "flywheel": "global", "pin_setter": "global",
	"spring_hull": "global", "long_lane": "global", "gutter_guard": "global",
	"ten_pin": "global", "ballast_drum": "global", "strike_pocket": "global",
	"re_rack": "global", "fan_spread": "local", "ring_wave": "global",
	"helix_drill": "local", "scrap_geyser": "global", "echo_charge": "global",
	"feedback_loop": "global", "momentum_thief": "global", "domino_wire": "global",
	"hairline_fracture": "global", "barrage_spring": "global", "warhead_slug": "global",
	"static_burr": "global", "frost_barb": "global", "overpressure": "global",
	"clean_break": "global", "tracer_round": "local", "impact_driver": "global",
	"last_word": "global", "light_frame": "global", "glide_vane": "global",
	"grapple_coil": "global", "tumbler_bearing": "global", "slipstream": "global",
	"anchor_spring": "global", "jet_vent": "global", "low_rider": "global",
	"rivet_seam": "global", "shock_liner": "global", "crush_guard": "global",
	"deflect_plate": "global", "brace_frame": "global", "scrap_armor": "global",
	"rebound_skin": "global", "warden_ward": "global", "magnet_coil": "global",
	# 2026-10-22 earned save (19fb8d79): spare_frame is a death_save perk on the hull, player-global.
	"spare_frame": "global",
	"cache_key": "global", "beacon_lamp": "global", "fast_hands": "global",
	"echo_locator": "global", "synergy_lens": "global", "salvage_drone": "global",
	"par_chip": "global", "cell_weapon": "global", "cell_movement": "global",
	"cell_special": "global", "cell_smash": "global",
	"breaker_drive": "local", "bladestorm_rotor": "local", "storm_mast": "local",
	"grounding_spike": "local",
}
const FIXED_CHECKS := 29
const FITTED_PARTS := ["hot_rivets", "hot_rivets", "slag_rounds", "rivet_plating", "quick_spool",
	"crush_guard", "cap_relay", "cap_relay", "cap_relay", "cap_relay", "magnet_spool", "cross_split"]

var EXPECTED_CHECKS := 0
var _checks := 0
var _dotted_key := RegEx.create_from_string("[A-Za-z][A-Za-z0-9]*\\.[A-Za-z]")

var _game
var _readout
var _failures := 0
var _phase := 0
var _frames := 0
var _completed := 0
var _esc_view
var _esc_after_first: Array = []
var _esc_pick_after_second := true


func _initialize() -> void:
	var unique := {}
	for id in FITTED_PARTS:
		unique[id] = true
	# 26 fixed + one per class + four per authored row + two per expected pool + one per fitted part.
	EXPECTED_CHECKS = FIXED_CHECKS + ClassDef.all().size() + 4 * _authored_rows().size() \
		+ 2 * _expected_pools(_held()).size() + unique.size()
	print("ui_build_readout_test: EXPECTED_CHECKS=%d" % EXPECTED_CHECKS)
	if not ResourceLoader.exists("res://src/ui/build_readout.gd"):
		print("ui_build_readout_test: FAIL missing Build readout implementation (red first)")
		quit(1)
		return
	_readout = load("res://src/ui/build_readout.gd")
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_frames += 1
	if _phase == 0:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_check_classes()
		_game.flow.choose_class(0)
		_phase = 1
		_frames = 0
	elif _phase == 1 and _frames >= 10:
		_check_build()
		_check_tree()
		_check_refunds()
		_phase = 2
		_frames = 0
		_esc_setup()
	elif _phase == 2 and _frames == 6:
		_esc_first()
	elif _phase == 2 and _frames == 12:
		_esc_second()
	elif _phase == 2 and _frames == 18:
		_esc_done()
		_report("all acceptance groups completed", _completed == 5, "%d of 5 groups returned normally" % _completed)
		_report("expected check count", _checks + 1 == EXPECTED_CHECKS, "%d / EXPECTED_CHECKS=%d" % [_checks + 1, EXPECTED_CHECKS])
		print("ui_build_readout_test: %s (%d checks, EXPECTED_CHECKS=%d)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _checks, EXPECTED_CHECKS])
		quit(0 if _failures == 0 else 1)
		return true
	return false


# One real Esc over the readout popup, which stands over the workshop pick: the press closes the
# popup alone, and a second press is the one that reaches the pick. Events go through the engine's
# own input path (Input.parse_input_event), not a direct call.
func _esc_setup() -> void:
	var workshop = _game.get_node("Workshop")
	workshop.armed = true
	var def = ClassDef.all()[0]
	workshop.pick.open(def.id, 2, UpgradeTree.nodes(def.id).slice(0, 2), [], def.color)
	_esc_view = workshop.pick.cards()[0].find_children("BuildReadout", "", true, false)[0]
	_esc_view.pressed.emit()


func _press_esc() -> void:
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	Input.flush_buffered_events()


func _esc_first() -> void:
	var workshop = _game.get_node("Workshop")
	var before: bool = _esc_view.popup_visible() and workshop.pick.is_open()
	_press_esc()
	_esc_after_first = [before, _esc_view.popup_visible(), workshop.pick.is_open()]


func _esc_second() -> void:
	var workshop = _game.get_node("Workshop")
	_report("one Esc closes the readout popup and leaves the pick open",
		_esc_after_first == [true, false, true], "popup and pick open before, then popup open %s, pick open %s" % [_esc_after_first[1], _esc_after_first[2]])
	_press_esc()
	_esc_pick_after_second = workshop.pick.is_open()


func _esc_done() -> void:
	_report("a second Esc acts on the pick", not _esc_pick_after_second, "pick open after the second press: %s" % _esc_pick_after_second)
	_completed += 1


func _check_classes() -> void:
	var cards: Array = _game.screens.class_cards()
	_report("six trade-offs", cards.size() == 6, "%d class cards" % cards.size())
	for card in cards:
		var labels: Array = card.find_children("Tradeoff", "Label", true, false)
		_report("trade-off %s" % card.def.id, labels.size() == 1 and card.tradeoff_text() != ""
			and labels[0].text == card.tradeoff_text() and not "\n" in card.tradeoff_text(), card.tradeoff_text())
	_completed += 1


func _held() -> Array[String]:
	var held: Array[String] = []
	held.assign(FITTED_PARTS)
	for i in 30:
		held.append("crush_guard")
	return held


func _expected_pools(held: Array) -> Dictionary:
	var sheet = Sheet.from_parts(held)
	var effects = Effects.new(null)
	effects.refresh(held)
	var expected: Dictionary = sheet.mods.duplicate()
	expected.merge({"punch": sheet.punch, "max_hp_bonus": sheet.max_hp_bonus, "magnet": sheet.magnet,
		"kill_scrap": sheet.kill_scrap, "cooldown_scale": sheet.cooldown_scale,
		"resistance": effects.damage_reduction, "price_scale": effects.price_scale,
		"hp_per_mass": effects.hp_per_mass, "vault_cooldown_scale": effects.vault_cooldown_scale,
		"vault_charges": effects.vault_charges})
	for pattern in sheet.patterns:
		expected["pattern." + pattern] = sheet.patterns[pattern]
	for slot in effects.charges:
		expected["charges." + slot] = effects.charges[slot]
	for slot in effects.cooldown_scale:
		expected["cooldown." + slot] = effects.cooldown_scale[slot]
	for dial in sheet.dials:
		expected["dial." + dial] = sheet.dials[dial]
	return expected


# SG15: a levelled part's row shows its held level's numbers and text, once, never level 1
# raised to the copy count. Two and three Hot Rivets, against def_at and the sheet.
func _check_levels() -> void:
	var wrong: Array = []
	for n in [2, 3]:
		var held: Array = []
		for i in n:
			held.append("hot_rivets")
		var level: Resource = Parts.def_at("hot_rivets", n)
		var sheet = Sheet.from_parts(held)
		var row: Dictionary = _readout.describe(held)["parts"][0]
		var totals := {}
		for bonus in row["bonuses"]:
			totals[bonus["key"]] = float(bonus["total"])
		var punch: float = totals.get("punch", -1.0)
		var damage: float = totals.get("weapon_damage", -1.0)
		if not (is_equal_approx(punch, level.punch) and is_equal_approx(punch, sheet.punch)
				and is_equal_approx(damage, level.mods["weapon_damage"]) and is_equal_approx(damage, sheet.mod("weapon_damage"))
				and level.display_name in row["text"] and _readout._signed((level.mods["weapon_damage"] - 1.0) * 100.0, "%") + " weapon damage" in row["text"] and row["copies"] == n):
			wrong.append("x%d: punch %s damage %s, level %d is %s / %s; text %s" % [n, punch, damage, n, level.punch, level.mods["weapon_damage"], [row["text"]]])
	var plates: Array = ["rivet_plating", "rivet_plating", "rivet_plating"]
	var plate_row: Dictionary = _readout.describe(plates)["parts"][0]
	var hp := -1.0
	for bonus in plate_row["bonuses"]:
		if bonus["key"] == "max_hp_bonus":
			hp = float(bonus["total"])
	if not (is_equal_approx(hp, Parts.def_at("rivet_plating", 3).max_hp_bonus) and is_equal_approx(hp, Sheet.from_parts(plates).max_hp_bonus)):
		wrong.append("three Rivet Plating: max health %s, level 3 is %s" % [hp, Parts.def_at("rivet_plating", 3).max_hp_bonus])
	_report("levelled part reads its held level", wrong.is_empty(), "two and three Hot Rivets, three Rivet Plating: wrong %s" % [wrong])


func _check_build() -> void:
	var held := _held()
	_game.run.parts = held
	_game.build.recompute()
	var view = _readout.new()
	root.add_child(view)
	view.show_build(held)
	var data: Dictionary = view.snapshot()
	var sheet = Sheet.from_parts(held)
	var effects = Effects.new(null)
	effects.refresh(held)
	var pools: Dictionary = data["pools"]
	var expected := _expected_pools(held)
	for key in expected:
		_report("simulation %s" % key, pools.has(key) and is_equal_approx(float(pools[key]["total"]), float(expected[key])),
			"shown %s, simulated %s" % [pools.get(key, {}).get("total", "missing"), expected[key]])
	var live := {"weapon_damage": _game.build.sheet.mod("weapon_damage"),
		"max_hp_bonus": _game.build.sheet.max_hp_bonus, "resistance": _game.build.effects.damage_reduction}
	for key in live:
		_report("live game %s" % key, pools.has(key) and is_equal_approx(float(pools[key]["total"]), float(live[key])),
			"shown %s, live %s" % [pools.get(key, {}).get("total", "missing"), live[key]])
	_report("scripted additive and multiplying totals", pools["punch"]["pool"] == "additive"
		and is_equal_approx(pools["punch"]["total"], sheet.punch)
		and pools["weapon_damage"]["pool"] == "multiplying"
		and is_equal_approx(pools["weapon_damage"]["total"], sheet.mod("weapon_damage"))
		and is_equal_approx(pools["max_hp_bonus"]["total"], sheet.max_hp_bonus)
		and is_equal_approx(pools["magnet"]["total"], sheet.magnet), str(pools))
	var resistance: Dictionary = pools["resistance"]
	_report("resistance cap", is_equal_approx(resistance["total"], effects.damage_reduction)
		and resistance["total"] <= resistance["cap"] and is_equal_approx(resistance["cap"], Parts.def("crush_guard").stack_cap), str(resistance))
	_check_catalog()
	var empty = _readout.new()
	root.add_child(empty)
	empty.show_build([])
	_report("neutral pools hidden", empty.visible_text() == "No parts fitted", empty.visible_text())
	empty.queue_free()
	var capped := false
	for row in data["parts"]:
		if row["id"] == "cap_relay":
			capped = row["copies"] == 4 and row["cap"] == 3 and row["at_cap"] and row["pips"] == {"filled": 3, "total": 3} and not "(at cap)" in row["text"]
		_report("part %s" % row["id"], row["text"] != "" and row["text"] in view.visible_text(), row["text"])
	_report("family cap shown", capped, "four Cap Relay copies show three full pips")
	_check_levels()
	for key in pools:
		var row: Dictionary = pools[key]
		var neutral := 1.0 if row["pool"] == "multiplying" else 0.0
		var hidden := is_equal_approx(float(row["total"]), neutral)
		_report("pool %s drawn" % key, is_finite(float(row["total"]))
			and (row["text"] == "" if hidden else row["text"] != "" and row["text"] in view.visible_text())
			and _player_words(row["text"]), "hidden neutral" if hidden else row["text"])
	view.queue_free()
	_completed += 1


func _authored_rows() -> Dictionary:
	var rows := Parts.rows().duplicate(true)
	rows.merge(Parts.EVOLVED)
	return rows


func _layer_mismatch(id: String, actual: String) -> String:
	if not EXPECTED_LAYERS.has(id):
		return "%s: missing from EXPECTED_LAYERS" % id
	var expected: String = EXPECTED_LAYERS[id]
	return "" if actual == expected else "%s: expected %s, got %s" % [id, expected, actual]


func _player_words(words: String) -> bool:
	return not "_" in words and _dotted_key.search(words) == null


func _stat_keys(rows: Dictionary) -> Array:
	var keys := {}
	for id in rows:
		var d = Parts.def(id)
		for key in d.reads:
			keys[key] = true
		var data: Dictionary = _readout.describe([id])
		for key in data["pools"]:
			keys[key] = true
		var effect_key := Effects.stack_key(String(d.effect.get("do", "")))
		if effect_key != "" and d.effect.has(effect_key):
			keys[String(d.effect["do"]) + "." + effect_key] = true
	for key in _expected_pools(rows.keys()):
		keys[key] = true
	return keys.keys()


func _missing_stat_words(keys: Array, words: Dictionary) -> Array:
	var missing: Array = []
	for key in keys:
		if not words.has(key) or String(words[key]).strip_edges() == "":
			missing.append(key)
	missing.sort()
	return missing


func _check_catalog() -> void:
	var rows := _authored_rows()
	_report("authored rows exist", not rows.is_empty(), "%d authored rows" % rows.size())
	var missing_ids: Array = []
	var extra_ids: Array = []
	for id in rows:
		if not EXPECTED_LAYERS.has(id):
			missing_ids.append(id)
	for id in EXPECTED_LAYERS:
		if not rows.has(id):
			extra_ids.append(id)
	_report("literal layer table coverage", missing_ids.is_empty() and extra_ids.is_empty(),
		"%d rows, %d expectations; missing %s; unauthored %s" % [rows.size(), EXPECTED_LAYERS.size(), missing_ids, extra_ids])
	_report("alpha parts covered", AlphaDefs.PARTS.all(func(id): return rows.has(id) and EXPECTED_LAYERS.has(id)),
		"%d alpha offer ids present in the authored table" % AlphaDefs.PARTS.size())
	for id in rows:
		var d = Parts.def(id)
		var data: Dictionary = _readout.describe([id])
		var mismatch := _layer_mismatch(id, d.layer)
		var shown: Dictionary = data["parts"][0]
		_report("layer %s" % id, mismatch == "" and _layer_mismatch(id, shown["layer"]) == "" and d.display_name in shown["text"] and not "weapon-local" in shown["text"] and not "player-global" in shown["text"],
			"%s layer %s" % [id, d.layer] if mismatch == "" else mismatch)
		var raw: Dictionary = rows[id].duplicate(true)
		raw.erase("layer")
		var derived = PartDef.from_row(id, raw)
		var derived_mismatch := _layer_mismatch(id, derived.layer)
		_report("derived layer %s" % id, derived_mismatch == "", "PartDef rule agrees with table" if derived_mismatch == "" else derived_mismatch)
		_report("reads %s" % id, d.layer == "local" or not d.reads.is_empty() and not "Reads:" in shown["text"], str(d.reads))
		var words_ok := true
		for part in data["parts"]:
			words_ok = words_ok and _player_words(part["text"])
			for bonus in part["bonuses"]:
				words_ok = words_ok and _player_words(bonus["text"])
		for pool in data["pools"].values():
			words_ok = words_ok and _player_words(pool["text"])
		_report("player words %s" % id, words_ok, str(data))
	var stat_keys := _stat_keys(rows)
	var missing_words := _missing_stat_words(stat_keys, _readout.STAT_WORDS)
	_report("STAT_WORDS coverage", missing_words.is_empty(), "missing %s from %d read, pool and bonus keys" % [missing_words, stat_keys.size()])
	var planted_words: Dictionary = _readout.STAT_WORDS.duplicate()
	planted_words.erase("magnet")
	var planted_missing := _missing_stat_words(stat_keys, planted_words)
	_report("planted STAT_WORDS control", "magnet" in planted_missing, "missing %s" % [planted_missing])
	var capped_mod: Dictionary = _readout.describe(["tracer_round", "tracer_round", "tracer_round", "tracer_round", "tracer_round"])
	var mod_text: String = capped_mod["parts"][0]["bonuses"][0]["text"]
	var capped_bonus: Dictionary = capped_mod["parts"][0]["bonuses"][0]
	_report("multiplying cap unit", mod_text.contains("%") and mod_text.contains(" +") and float(capped_bonus["cap"]) >= float(capped_bonus["total"]), mod_text)
	var resistance_text: String = _readout.describe(["crush_guard"])["pools"]["resistance"]["text"]
	_report("remaining pool player phrase", resistance_text.begins_with("Damage resistance +") and resistance_text.ends_with("%"), resistance_text)
	for control in [{"id": "spring_shims", "layer": "local"}, {"id": "hot_rivets", "layer": "global"}]:
		var planted: Dictionary = rows[control["id"]].duplicate(true)
		planted["layer"] = control["layer"]
		var planted_def = PartDef.from_row(control["id"], planted)
		var planted_mismatch := _layer_mismatch(control["id"], planted_def.layer)
		_report("planted layer control %s" % control["id"], planted_mismatch != "" and planted_def.layer == control["layer"], planted_mismatch)


func _check_tree() -> void:
	var workshop = _game.get_node("Workshop")
	var def = ClassDef.all()[0]
	workshop.pick.open(def.id, 1, UpgradeTree.nodes(def.id).slice(0, 2), [], def.color)
	var card = workshop.pick.cards()[0]
	var rows: Array = card.depth_rows()
	_report("depth table", rows.size() == 3 and rows.map(func(r): return r["depth"]) == [2, 3, 4]
		and rows.all(func(r): return r["depth"] == UpgradeTree.depth_cap(r["world"]))
		and "2" in card.depth_text() and "3" in card.depth_text() and "4" in card.depth_text(), card.depth_text())
	var views: Array = card.find_children("BuildReadout", "", true, false)
	_report("build screen wired", views.size() == 1, "tree card carries clickable Build readout")
	if views.size() == 1:
		views[0].pressed.emit()
		_report("live build opens", views[0].popup_visible() and views[0].snapshot()["parts"].size() > 0, views[0].visible_text())
	workshop.close_pick()
	_completed += 1


func _check_refunds() -> void:
	var abilities = _game.player.abilities
	var bar = _game.hud.ability_bar
	abilities.refill()
	var slot: String = abilities.refund_slot()
	abilities.spend(slot)
	var before: int = bar.refund_flash_count()
	var granted: float = abilities.combat_refund("hit_landed")
	bar.step(0.0)
	var once: int = bar.refund_flash_count()
	_report("refund flashes once", granted > 0.0 and once == before + 1 and bar.refund_flash_left(slot) > 0.0,
		"grant %.2f s, flashes %d -> %d" % [granted, before, once])
	bar.step(0.0)
	_report("drained event stays once", bar.refund_flash_count() == once, "second frame adds no flash")
	bar.step(1.0)
	_report("refund flash expires", bar.refund_flash_left(slot) == 0.0, "no persistent flash after 1 s")
	bar.cooldown_refunded({"kind": "cooldown_refunded", "slot": slot})
	bar.cooldown_refunded({"kind": "cooldown_refunded", "slot": slot})
	bar.step(0.0)
	var first: int = bar.refund_flash_count()
	bar.step(bar.PULSE_SECONDS + 0.001)
	_report("batched refunds each flash", first == once + 1 and bar.refund_flash_count() == once + 2,
		"two records play two successive flashes")
	_completed += 1
