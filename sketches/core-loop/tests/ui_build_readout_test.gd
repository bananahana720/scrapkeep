extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Sheet := preload("res://src/build/build_sheet.gd")
const Effects := preload("res://src/build/item_effects.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const FIXED_CHECKS := 19
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


func _initialize() -> void:
	var unique := {}
	for id in FITTED_PARTS:
		unique[id] = true
	# 19 fixed + one per class + three per authored row + two per expected pool + one per fitted part.
	EXPECTED_CHECKS = FIXED_CHECKS + ClassDef.all().size() + 3 * _authored_rows().size() \
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
	elif _frames >= 10:
		_check_build()
		_check_tree()
		_check_refunds()
		_report("all acceptance groups completed", _completed == 4, "%d of 4 groups returned normally" % _completed)
		_report("expected check count", _checks + 1 == EXPECTED_CHECKS, "%d / EXPECTED_CHECKS=%d" % [_checks + 1, EXPECTED_CHECKS])
		print("ui_build_readout_test: %s (%d checks, EXPECTED_CHECKS=%d)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _checks, EXPECTED_CHECKS])
		quit(0 if _failures == 0 else 1)
		return true
	return false


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
			capped = row["copies"] == 4 and row["cap"] == 3 and row["at_cap"] and "cap 3" in row["text"]
		_report("part %s" % row["id"], row["text"] != "" and row["text"] in view.visible_text(), row["text"])
	_report("family cap shown", capped, "four Cap Relay copies show cap 3")
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


func _expected_layer(row: Dictionary) -> String:
	return "global" if float(row.get("max_hp_bonus", 0.0)) != 0.0 \
		or not row.get("effect", {}).is_empty() or not row.get("charges", {}).is_empty() \
		or row.get("trigger", "") != "" or float(row.get("magnet", 1.0)) != 1.0 \
		or float(row.get("cooldown_scale", 1.0)) != 1.0 or float(row.get("kill_scrap", 1.0)) != 1.0 else "local"


func _layer_mismatch(id: String, row: Dictionary, actual: String) -> String:
	var expected := _expected_layer(row)
	return "" if actual == expected else "%s: expected %s, got %s" % [id, expected, actual]


func _player_words(words: String) -> bool:
	return not "_" in words and _dotted_key.search(words) == null


func _check_catalog() -> void:
	var rows := _authored_rows()
	_report("authored rows exist", not rows.is_empty(), "%d authored rows" % rows.size())
	for id in rows:
		var d = Parts.def(id)
		var mismatch := _layer_mismatch(id, rows[id], d.layer)
		_report("layer %s" % id, mismatch == "", "%s layer %s" % [id, d.layer] if mismatch == "" else mismatch)
		_report("reads %s" % id, d.layer == "local" or not d.reads.is_empty(), str(d.reads))
		var data: Dictionary = _readout.describe([id])
		var words_ok := true
		for part in data["parts"]:
			for line in String(part["text"]).split("\n"):
				if line.begins_with("Reads: "):
					words_ok = words_ok and _player_words(line)
			for bonus in part["bonuses"]:
				words_ok = words_ok and _player_words(bonus["text"])
		for pool in data["pools"].values():
			words_ok = words_ok and _player_words(pool["text"])
		_report("player words %s" % id, words_ok, str(data))
	var planted: Dictionary = rows["rivet_plating"].duplicate(true)
	planted["layer"] = "local"
	var planted_def = PartDef.from_row("planted_rivet_plating", planted)
	var planted_mismatch := _layer_mismatch("planted_rivet_plating", planted, planted_def.layer)
	_report("planted layer control", planted_mismatch != "" and _expected_layer(planted) == "global", planted_mismatch)


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
