extends SceneTree

const AbilityState := preload("res://src/core/ability_state.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const ChainCounter := preload("res://src/ui/chain_counter.gd")
const ControlsDiagram := preload("res://src/ui/controls_diagram.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const T := preload("res://tests/support/t.gd")

# W1-06 (PF-21, w37 film 014, 022, 059, 071): the ability row explains itself.
#   a  a slot that cannot fire says why: a cooldown is a clock, an empty charge that only
#      contact refills (Tally's pressure) is "empty", and the published record names the
#      pool it spends and how that pool refills;
#   b  an empty slot shows its pool's pips, all hollow;
#   c  in the set piece the bar's marks dim but solid plates stay behind them, so the row
#      never fades out; after it, the plates go;
#   d  the chain counter's links, times sign and two digits fit its box, and its text is still
#      the count;
#   e  the notes' ultimate key wears the meter arc, inside its tile.

var _t := T.new("ui_ability_row_reads_test")


func _initialize() -> void:
	_reasons()
	_set_piece()
	_chain()
	_notes_arc()
	quit(_t.verdict())


func _record(state: AbilityState, name: String) -> Dictionary:
	for entry in state.slots():
		if entry["slot"] == name:
			return entry
	return {}


func _reasons() -> void:
	var w: String = AbilityState.WEAPON
	var tally := AbilityState.new()
	tally.swap(w, "ledger_reader")
	for i in 3:
		tally.spend(w)
	var reader := _record(tally, w)
	_t.eq("a: an empty reader publishes its pool and contact refill", [reader["state"], reader["pool"], reader["refill"]], ["cooling", w, "contact"])
	_t.eq("a: and the bar reads it as empty, not a clock", AbilityBar.slot_reason(reader), "empty")
	var sable := AbilityState.new()
	sable.swap(AbilityState.SPECIAL, "detonation_gauge")
	sable.spend(AbilityState.SPECIAL)
	var special := _record(sable, AbilityState.SPECIAL)
	_t.eq("a: a spent special publishes a time refill", [special["state"], special["refill"]], ["cooling", "time"])
	_t.eq("a: and the bar reads it as a clock", AbilityBar.slot_reason(special), "clock")
	sable.refill()
	_t.eq("a: a ready slot needs no reason", AbilityBar.slot_reason(_record(sable, AbilityState.SPECIAL)), "")
	_t.eq("a: a record from before the field reads as a clock", AbilityBar.slot_reason({"state": "cooling"}), "clock")

	var bar := AbilityBar.new()
	bar.slots = tally.slots()
	_t.eq("b: the empty reader shows its pool's three pips", bar.pool_pips(reader), 3)
	bar.free()


func _set_piece() -> void:
	var bar := AbilityBar.new()
	root.add_child(bar)
	bar.update_slots([AbilityState.new().slots()[0]], Color.WHITE)
	bar.set_piece = true
	_t.check("c: in the set piece the marks dim and the plates stay solid", is_equal_approx(bar.self_modulate.a, AbilityBar.SET_PIECE_ALPHA)
		and is_equal_approx(bar.modulate.a, 1.0) and bar.plates_shown(), "self %.2f, modulate %.2f, plates %s" % [bar.self_modulate.a, bar.modulate.a, bar.plates_shown()])
	bar.set_piece = false
	_t.check("c: after it, full marks and no plates", is_equal_approx(bar.self_modulate.a, 1.0) and not bar.plates_shown())
	bar.free()


func _chain() -> void:
	var counter := ChainCounter.new()
	counter.step(0.016, 2)
	_t.eq("d: the counter's text is still the count", counter.text(), "2")
	var drawn := ChainCounter.LINK * 3.4 + UiDraw.width(ChainCounter.TIMES, UiTokens.LABEL) + 1.0 + UiDraw.width("88", ChainCounter.FONT, true)
	_t.check("d: links, times sign and two digits fit the box", drawn <= ChainCounter.BOX.x, "%.1f of %.1f px" % [drawn, ChainCounter.BOX.x])
	counter.free()


func _notes_arc() -> void:
	var diagram := ControlsDiagram.new()
	_t.eq("e: the arc rides the ultimate's key", ControlsDiagram.arc_key(), "key_q")
	_t.check("e: that key is on the diagram", diagram.shown_keys().has(ControlsDiagram.arc_key()), str(diagram.shown_keys()))
	# The arc rides the picture corner (ICON wide, 4 px from the tile's top, 6 px from its right),
	# centred 2 px low: it must stay inside the tile, whose plate is GAP / 2 in from its slot.
	var reach := ControlsDiagram.ARC_R + ControlsDiagram.ARC_W * 0.5
	var top_room := 4.0 + ControlsDiagram.ICON * 0.5 + 2.0
	var side_room := 6.0 + ControlsDiagram.ICON * 0.5
	_t.check("e: the arc stays inside its tile", reach <= minf(top_room, side_room), "reach %.1f, room %.1f" % [reach, minf(top_room, side_room)])
	diagram.free()
