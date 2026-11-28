# 2026-10-12, W13 smoke triage: class c re-pin for 24cc872 and 000763f.
# shared Icons.REEL for every line slot -> Sable ab_sable_line, Kest ab_kest_line; Rivet keeps Icons.REEL.
extends SceneTree
# 2026-10-11 (PC-RIVET, pending a coordinator ruling: SCOPE amendment attributed to B2, or a B2
# follow-up): slot 3 wears its line row's own picture, read from AbilityState (Rivet's
# ab_rivet_line; Sable and Kest still the shared reel), and the five pictures must be distinct.
# Was Icons.REEL for every pilot, which B2 did not generalize (P-UNITS 0.4 item 6). Measured:
# Rivet's bar reads ab_rivet_weapon, ab_rivet_special, ab_rivet_line, ab_rivet_move, ab_rivet_smash.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const Icons := preload("res://src/core/icons.gd")
const AbilityState := preload("res://src/core/ability_state.gd")

# The ability bar reads W3's published slots (player.abilities.slots()) through the UI's
# normaliser (CONTRACTS, Ability slots):
#   - each pilot's five slots, in bar order (slots 1, 2, 3, then the Shift and Ctrl chips),
#     carry that pilot's ab_ icons (slot 3 wears its row's picture) and key glyph ids, with
#     every field well formed;
#   - Rivet's routed special (the router's special_* output, which a pick of 2 and a click
#     feed) makes the special active and fills its gauge, which the HUD hands to the reticle
#     ring; letting go fires it and puts the slot to cooling;
#   - a malformed record empties the bar instead of drawing it;
#   - a slot whose cooldown ends swells once, and the pips and swell wear the class shape.

const PILOTS := ["sable", "rivet", "kest"]
# Re-pinned 2026-10-10 (wave 13 unit B2, SKILL-BAR sections 1 and 5): the bar is slots 1, 2
# and 3 on the number keys, then the Shift and Ctrl chips; the movement chip reads Shift for
# every pilot, Sable included (her chip is her boost). Was LMB, RMB or Shift, F, Ctrl.
const KEYS := ["key_1", "key_2", "key_3", "key_shift", "key_ctrl"]
# Re-pinned 2026-10-24 (#445, actives on by default): a run opens with the starter active racked,
# so its F chip follows the five class slots (active_rack.gd slot_record).
const ACTIVE_CHIP := {"id": "active_scrap_rocket", "icon": "cat_damage", "key": "key_f"}
const CHARGE_TICKS := 45

var _game
var _source
var _failures := 0
var _phase := "boot"
var _wait := 0
var _class := 0
var _adapter := AbilitySlots.new()


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	match _phase:
		"boot":
			_game.ctx.calm = true
			_source = Intent.Scripted.new()
			_game.player.source = _source
			_game.flow.press_start()
			_game.flow.choose_class(_class)
			_phase = "pilot"
			_wait = 0
		"pilot":
			if _wait == 20:
				var list: Array = _adapter.slots(_game)
				var pilot: String = PILOTS[_class]
				var line_icon := String(AbilityState.ABILITIES[_game.player.abilities.id_of("line")]["icon"])
				var want := ["ab_%s_weapon" % pilot, "ab_%s_special" % pilot, line_icon, "ab_%s_move" % pilot, "ab_%s_smash" % pilot]
				var distinct := {}
				for id in want:
					distinct[id] = true
				var chip: Dictionary = list[5] if list.size() == 6 else {}
				var own: Array = list.slice(0, 5)
				_report("%s slots" % pilot, AbilitySlots.valid(list) and distinct.size() == 5 and _field(own, "icon") == want and _field(own, "key") == KEYS
						and _field(own, "slot") == ["weapon", "special", "line", "movement", "smash"] and _field(own, "number") == [1, 2, 3, 0, 0]
						and ACTIVE_CHIP.keys().all(func(k): return chip.get(k) == ACTIVE_CHIP[k])
						and want.all(func(id): return Icons.has(id) or Icons.EXTRA.has(id)),
					"ids %s icons %s keys %s states %s" % [_field(list, "id"), _field(list, "icon"), _field(list, "key"), _field(list, "state")])
				_class += 1
				_game.run.damage(99999.0, "test")
				_game.flow.open_class_select()
				if _class < PILOTS.size():
					_game.flow.choose_class(_class)
				else:
					_game.flow.choose_class(1)
					_phase = "rivet"
				_wait = 0
		"rivet":
			if _wait == 20:
				_source.press["special_pressed"] = true
				_source.hold["special_held"] = true
			if _wait == 20 + CHARGE_TICKS:
				var list: Array = _adapter.slots(_game)
				var gauge: float = AbilitySlots.gauge_of(list)
				var ring: float = _game.hud.reticle.gauge
				_report("charging", list[1]["state"] == "active" and gauge > 0.2 and gauge < 1.0 and absf(ring - gauge) < 0.05,
					"special held %d ticks: special %s, gauge %.2f, reticle ring %.2f" % [CHARGE_TICKS, list[1]["state"], gauge, ring])
				_source.hold.erase("special_held")
			if _wait == 30 + CHARGE_TICKS:
				var list: Array = _adapter.slots(_game)
				var special: Dictionary = list[1]
				_report("released", special["state"] == "cooling" and special["cooldown_frac"] > 0.0 and special["charges"] == 0
						and special["gauge"] == 0.0 and _game.hud.reticle.gauge == 0.0,
					"after the release: special %s at %.2f with %d charge, gauge %.2f, reticle ring %.2f"
						% [special["state"], special["cooldown_frac"], special["charges"], special["gauge"], _game.hud.reticle.gauge])
				_check_malformed()
				_check_pulse()
				print("ui_ability_slots_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


func _check_malformed() -> void:
	var def = _game.run.class_def
	var good: Dictionary = AbilitySlots.normalized({"slot": "special", "id": "overdrive_blast", "icon": "blast_chevron", "key": "F",
		"cooldown_frac": 0.5, "charges": 0, "max_charges": 2, "state": "cooling", "gauge": 0.0}, def)
	var bad: Dictionary = AbilitySlots.normalized({"slot": "special", "id": "overdrive_blast", "state": "bogus"}, def)
	_report("normalised", good["icon"] == "ab_rivet_special" and good["key"] == "key_f" and AbilitySlots.valid([good])
			and not AbilitySlots.valid([good, bad]) and not AbilitySlots.valid([]),
		"W3's icon blast_chevron reads as %s and key F as %s; a record missing fields fails validation" % [good["icon"], good["key"]])


func _check_pulse() -> void:
	var bar := AbilityBar.new()
	root.add_child(bar)
	bar.update_slots([AbilitySlots.slot("overdrive_blast", "ab_rivet_special", "key_f", 0.4, 0, 1, "cooling")], Color.WHITE, "chevron")
	var before: float = bar.pulse_left("overdrive_blast")
	bar.update_slots([AbilitySlots.slot("overdrive_blast", "ab_rivet_special", "key_f", 0.0, 1, 1, "ready")], Color.WHITE, "chevron")
	var after: float = bar.pulse_left("overdrive_blast")
	bar.update_slots([AbilitySlots.slot("shockwave_skid", "ab_rivet_smash", "key_ctrl", 0.0, 1, 1, "unavailable")], Color.WHITE, "chevron")
	bar.update_slots([AbilitySlots.slot("shockwave_skid", "ab_rivet_smash", "key_ctrl", 0.0, 1, 1, "ready")], Color.WHITE, "chevron")
	var smash: float = bar.pulse_left("shockwave_skid")
	var motif: String = bar.motif
	bar.free()
	_report("ready pulse", before == 0.0 and after > 0.0 and smash == 0.0 and motif == "chevron",
		"a cooldown ending swells for %.2f s; leaving the ground does not (%.2f); the bar wears the %s motif" % [after, smash, motif])


static func _field(list: Array, key: String) -> Array:
	return list.map(func(s): return s.get(key))
