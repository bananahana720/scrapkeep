extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const Icons := preload("res://src/ui/icons.gd")

# The ability slot adapter (CONTRACTS, Ability slots) builds well-formed slots from
# today's state, and the bar reads them:
#   - the runner's four slots, in bar order, are rapid_laser, dash, overdrive and smash
#     with Rivet's ab_ icons and key ids, each with every field, a state from the four,
#     a cooldown fraction in 0..1 and charges in range;
#   - holding fire makes the weapon active, and F makes overdrive active, then cooling
#     with a fraction below 1 once the burst ends;
#   - the engineer's slots are arc_caster, grapple, pylon_turret and smash with Sable's;
#   - a module that publishes ability_slots() is read instead, and a malformed one is not;
#   - a slot whose cooldown ends pulses once.

const OVERDRIVE_TICKS := 290

var _game
var _source
var _failures := 0
var _phase := "boot"
var _wait := 0
var _adapter := AbilitySlots.new()


class PublishingCombat extends Node:
	var list: Array = []

	func ability_slots() -> Array:
		return list


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
			_game.flow.choose_class(1)
			_phase = "runner"
			_wait = 0
		"runner":
			if _wait == 20:
				var list: Array = _adapter.slots(_game)
				_report("runner slots", AbilitySlots.valid(list) and _ids(list) == ["rapid_laser", "dash", "overdrive", "smash"]
						and _keys(list) == ["key_lmb", "key_shift", "key_f", "key_ctrl"]
						and _icons(list) == ["ab_rivet_weapon", "ab_rivet_move", "ab_rivet_special", "ab_rivet_smash"]
						and _icons(list).all(func(id): return Icons.has(id)),
					"ids %s keys %s icons %s states %s" % [_ids(list), _keys(list), _icons(list), _states(list)])
				_source.hold["fire_held"] = true
				_source.press["special_pressed"] = true
				_phase = "special"
				_wait = 0
		"special":
			if _wait == 3:
				var list: Array = _adapter.slots(_game)
				_report("firing", list[0]["state"] == "active" and list[2]["state"] == "active" and AbilitySlots.valid(list),
					"fire held and F pressed: weapon %s, overdrive %s" % [list[0]["state"], list[2]["state"]])
				_source.hold.erase("fire_held")
			if _wait == OVERDRIVE_TICKS:
				var list: Array = _adapter.slots(_game)
				var special: Dictionary = list[2]
				_report("cooling", special["state"] == "cooling" and special["cooldown_frac"] > 0.0 and special["cooldown_frac"] < 1.0
						and special["charges"] == 0 and list[0]["state"] == "ready",
					"after the burst: overdrive %s at %.2f with %d charge; weapon %s"
						% [special["state"], special["cooldown_frac"], special["charges"], list[0]["state"]])
				_game.run.damage(99999.0, "test")
				_game.flow.open_class_select()
				_game.flow.choose_class(0)
				_phase = "engineer"
				_wait = 0
		"engineer":
			if _wait == 20:
				var list: Array = _adapter.slots(_game)
				_report("engineer slots", AbilitySlots.valid(list) and _ids(list) == ["arc_caster", "grapple", "pylon_turret", "smash"]
						and list[1]["key"] == "key_rmb" and _icons(list)[1] == "ab_sable_move",
					"ids %s keys %s icons %s states %s" % [_ids(list), _keys(list), _icons(list), _states(list)])
				_check_published()
				_check_pulse()
				print("ui_ability_slots_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


func _check_published() -> void:
	var real = _game.combat
	var stub := PublishingCombat.new()
	stub.list = [AbilitySlots.slot("sticky_charge", "ab_kest_weapon", "key_lmb", 0.0, 2, 3, "ready")]
	_game.combat = stub
	var read: Array = _adapter.slots(_game)
	stub.list = [{"id": "sticky_charge", "state": "bogus"}]
	var fallback: Array = _adapter.slots(_game)
	_game.combat = real
	stub.free()
	_report("published slots", _ids(read) == ["sticky_charge"] and read[0]["max_charges"] == 3 and _ids(fallback).size() == 4
			and not AbilitySlots.valid([]),
		"a published slot is read (%s); a malformed one falls back to the adapter (%s)" % [_ids(read), _ids(fallback)])


func _check_pulse() -> void:
	var bar := AbilityBar.new()
	root.add_child(bar)
	bar.update_slots([AbilitySlots.slot("overdrive", "ab_rivet_special", "key_f", 0.4, 0, 1, "cooling")], Color.WHITE)
	var before: float = bar.pulse_left("overdrive")
	bar.update_slots([AbilitySlots.slot("overdrive", "ab_rivet_special", "key_f", 0.0, 1, 1, "ready")], Color.WHITE)
	var after: float = bar.pulse_left("overdrive")
	bar.update_slots([AbilitySlots.slot("smash", "ab_rivet_smash", "key_ctrl", 0.0, 1, 1, "unavailable")], Color.WHITE)
	bar.update_slots([AbilitySlots.slot("smash", "ab_rivet_smash", "key_ctrl", 0.0, 1, 1, "ready")], Color.WHITE)
	var smash: float = bar.pulse_left("smash")
	bar.free()
	_report("ready pulse", before == 0.0 and after > 0.0 and smash == 0.0,
		"a cooldown ending pulses for %.2f s; leaving the ground does not (%.2f)" % [after, smash])


static func _ids(list: Array) -> Array:
	return list.map(func(s): return s["id"])


static func _keys(list: Array) -> Array:
	return list.map(func(s): return s["key"])


static func _icons(list: Array) -> Array:
	return list.map(func(s): return s["icon"])


static func _states(list: Array) -> Array:
	return list.map(func(s): return s["state"])
