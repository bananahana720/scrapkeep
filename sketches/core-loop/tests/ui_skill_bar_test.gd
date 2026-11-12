extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const KeyGlyphs := preload("res://src/ui/key_glyphs.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const Palette := preload("res://src/core/palette.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Keycap := preload("res://src/ui/keycap.gd")

# The skill bar's HUD (design-v3/SKILL-BAR.md sections 5 and 10, unit B2), on the real game:
#   - the bar draws three numbered slots and two chips at 0.75 scale, 24 px right of slot 3, and
#     the chain counter sits right of the chips;
#   - the mouse glyph sits over the selected slot and slides there in 0.12 s on a pick and home
#     on a snap; its underline drains with the pick's timeout;
#   - selected and active are distinct: the colours the bar draws a selected slot's keycap with
#     (sand fill, charcoal digit, no lift) differ from an active slot's (charcoal cap, class tint,
#     3 px lift and a doubled frame). Headless Godot runs the dummy renderer, which has no pixels
#     to sample, so the smoke checks the colours the control draws with (slot_look);
#   - re-pinned 2026-10-11 (B2 fix round, gate finding 2): on a real renderer the test also draws
#     two bars and the reticle into a 1920x1080 SubViewport, samples the keycap fill and the 3 px
#     lift row of slot 2 selected+ready and slot 2 active (slot 1 selected), asserts they differ,
#     and saves the frame as the 1080p blind still of both rings at a full meter. Run it windowed
#     on workspace 10 (the PNG lands under --out=, default artifacts/local/w13-b2-pixel/):
#       claude-open godot --path sketches/core-loop --resolution 1920x1080 --script res://tests/ui_skill_bar_test.gd -- --out=/abs/dir
#     Headless it prints a SKIP line for the pixel case and the data checks above stand;
#   - a refused pick shakes the slot 3 px and flashes slate, and the glyph stays put; a loaded
#     line skill wears the hook badge on slot 3;
#   - the meter arc sits 10 px outside the gauge ring, sweeps 270 degrees clockwise round a gap
#     at six o'clock, fills in the class colour (sand-light bare metal where the class colour is
#     the live mint), closes with a mint rim at full and breathes at 1 Hz; it reads 0 with no
#     meter (B3 builds it);
#   - the Q prompt follows LEGIBILITY's rules: first full meter of a run, retired after 3 uses,
#     back after a refused press and after 90 s unused;
#   - during the set piece the bar dims to 40 percent;
#   - Q does nothing on the pause menu and X held 0.6 s quits;
#   - the field notes retire the special row and add select and ultimate;
#   - with a full meter in a fight the HUD reads 25 words or fewer and draws Q exactly once
#     (re-pinned 2026-10-11, gate finding 1: was "at least once"); with the Q prompt live the
#     reticle leaves its Q off, with the prompt retired the reticle draws it.

const FIGHT_BUDGET := 25
const PIXEL_SIZE := Vector2i(1920, 1080)
const PIXEL_BACK := Color(0.32, 0.36, 0.34)
const PIXEL_TOLERANCE := 0.04


# A stand-in for B3's UltimateMeter: only what ability_state.ultimate() reads.
class FakeMeter:
	extends RefCounted
	var value := 0.0
	var locked := false

	func fraction() -> float:
		return clampf(value, 0.0, 1.0)

	func full() -> bool:
		return value >= 1.0


var _game
var _failures := 0
var _phase := "boot"
var _wait := 0
var _quits := 0
var _pixel_view: SubViewport
var _pixel_bars: Array = []


func _initialize() -> void:
	# One physics tick a frame, as on an idle box: a loaded box otherwise packs several ticks into one
	# frame and the frame-paced checks drift (w33 gate, red only under load). The game just runs slower.
	Engine.max_physics_steps_per_frame = 1
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "play"
			_wait = 0
		"play":
			if _wait < 10:
				return false
			_check_layout()
			_check_glyph()
			_check_looks()
			_check_refusal()
			_check_meter_static()
			_check_meter_live()
			_check_prompt()
			_check_fight_words()
			_check_set_piece()
			_check_notes()
			_phase = "pixels"
			_wait = 0
		"pixels":
			if DisplayServer.get_name() == "headless":
				print("[selected vs active pixels] SKIP: headless runs the dummy renderer; run windowed for the pixel case and the 1080p still")
				_phase = "pause"
				_wait = 0
				return false
			if _wait == 1:
				_build_pixel_view()
			if _wait == 6:
				_check_pixels()
				_phase = "pause"
				_wait = 0
		"pause":
			if _wait == 1:
				_open_pause()
			if _wait == 6:
				_check_pause()
				print("ui_skill_bar_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


func _bar() -> AbilityBar:
	return _game.hud.ability_bar


func _check_layout() -> void:
	var bar = _bar()
	var rects: Dictionary = bar.slot_rects()
	var order: Array = bar.slots.map(func(e): return e.get("slot", ""))
	var w: Rect2 = rects.get("weapon", Rect2())
	var s: Rect2 = rects.get("special", Rect2())
	var l: Rect2 = rects.get("line", Rect2())
	var m: Rect2 = rects.get("movement", Rect2())
	var k: Rect2 = rects.get("smash", Rect2())
	# Re-pinned 2026-10-24 (#445, actives on by default): the racked active's chip follows the
	# Ctrl chip, one more chip at the bar's end, keyed by its id.
	var f: Rect2 = rects.get("active_scrap_rocket", Rect2())
	var chip := AbilityBar.SLOT * AbilityBar.CHIP_SCALE
	var size_ok: bool = absf(AbilityBar.bar_size(6).x - f.end.x) < 0.5 and is_equal_approx(f.size.x, chip) and f.position.x > k.end.x
	_report("bar shape", order.slice(0, 5) == ["weapon", "special", "line", "movement", "smash"] and bar.slots.size() == 6
			and String(bar.slots[5].get("id", "")) == "active_scrap_rocket" and w.size.x == AbilityBar.SLOT
			and l.size.x == AbilityBar.SLOT and is_equal_approx(m.size.x, chip) and is_equal_approx(k.size.x, chip)
			and absf(m.position.x - l.end.x - AbilityBar.CHIP_GAP) < 0.5 and w.end.x < s.position.x and s.end.x < l.position.x
			and size_ok,
		"order %s; slot %.0f px, chip %.0f px, chip gap %.0f px, bar width %.0f vs last chip edge %.0f"
			% [order, w.size.x, m.size.x, m.position.x - l.end.x, AbilityBar.bar_size(6).x, f.end.x])
	var keys: Array = bar.slots.map(func(e): return e["key"])
	# A prompt on screen (the boost's Shift at the drop) hides its key on the bar; read it bare.
	var none: Array[String] = []
	var source: Callable = bar.hidden_source
	bar.hidden_source = Callable()
	bar.hide_keys(none)
	var bare: PackedStringArray = bar.drawn_words()
	bar.hidden_source = func() -> Array[String]:
		var shift: Array[String] = ["key_shift"]
		return shift
	var hidden: PackedStringArray = bar.drawn_words()
	bar.hidden_source = source
	_report("bar keys", keys == ["key_1", "key_2", "key_3", "key_shift", "key_ctrl", "key_f"]
			and bare == PackedStringArray(["1", "2", "3", "Shift", "Ctrl", "F"]) and hidden == PackedStringArray(["1", "2", "3", "Ctrl", "F"]),
		"keys %s, words %s, with a live Shift prompt %s" % [keys, bare, hidden])
	var chain: Control = _game.hud.chain_counter
	_report("chain right of chips", chain.position.x >= bar.position.x + f.end.x,
		"chain at x %.0f, last chip ends at %.0f" % [chain.position.x, bar.position.x + f.end.x])


func _check_glyph() -> void:
	var bar = _bar()
	var abilities = _game.player.abilities
	var rects: Dictionary = bar.slot_rects()
	bar.step(1.0)
	var home: float = bar.glyph_x
	var took: String = abilities.select(AbilityState.SPECIAL)
	_refresh()
	bar.step(AbilityBar.GLYPH_SLIDE * 0.5)
	var mid: float = bar.glyph_x
	bar.step(AbilityBar.GLYPH_SLIDE * 0.5 + 0.001)
	var there: float = bar.glyph_x
	var under: float = bar.underline_share()
	abilities._select_held = AbilityState.SELECT_TIMEOUT * 0.5
	_refresh()
	var drained: float = bar.underline_share()
	abilities.snap_back("deselect")
	_refresh()
	bar.step(AbilityBar.GLYPH_SLIDE + 0.001)
	var back: float = bar.glyph_x
	var w: float = (rects["weapon"] as Rect2).get_center().x
	var s: float = (rects["special"] as Rect2).get_center().x
	_report("glyph slides", took == "" and absf(home - w) < 0.5 and mid > w + 1.0 and mid < s - 1.0 and absf(there - s) < 0.5
			and absf(back - w) < 0.5,
		"home %.1f (slot 1 at %.1f), half way %.1f, after 0.12 s %.1f (slot 2 at %.1f), snapped back to %.1f"
			% [home, w, mid, there, s, back])
	_report("underline drains", is_equal_approx(under, 1.0) and absf(drained - 0.5) < 0.01,
		"underline %.2f at the pick, %.2f half way through the timeout" % [under, drained])


func _check_looks() -> void:
	var bar = _bar()
	var tint: Color = _game.run.class_def.color
	var base := {"slot": "special", "id": "x", "icon": "ab_sable_special", "key": "key_2", "cooldown_frac": 0.0,
		"charges": 1, "max_charges": 1, "number": 2, "group": "bar", "select_left": 1.0}
	var picked: Dictionary = base.duplicate()
	picked.merge({"state": "ready", "selected": true})
	var active: Dictionary = base.duplicate()
	active.merge({"state": "active", "selected": false})
	var both: Dictionary = base.duplicate()
	both.merge({"state": "active", "selected": true})
	var a: Dictionary = bar.slot_look(picked)
	var b: Dictionary = bar.slot_look(active)
	var c: Dictionary = bar.slot_look(both)
	_report("selected reads", a["cap_fill"] == Palette.SAND and a["cap_ink"] == Palette.CHARCOAL and a["lift"] == 0.0 and not a["doubled"] and a["glyph"],
		"selected: cap %s ink %s lift %.0f doubled %s glyph %s" % [a["cap_fill"].to_html(false), a["cap_ink"].to_html(false), a["lift"], a["doubled"], a["glyph"]])
	_report("active reads", b["cap_fill"] != b["cap_ink"] and b["cap_fill"] != Palette.SAND and b["cap_ink"] == tint and b["lift"] == 3.0 and b["doubled"] and not b["glyph"],
		"active: cap %s ink %s lift %.0f doubled %s glyph %s" % [b["cap_fill"].to_html(false), b["cap_ink"].to_html(false), b["lift"], b["doubled"], b["glyph"]])
	_report("selected and active distinct", a["cap_fill"] != b["cap_fill"] and a["cap_ink"] != b["cap_ink"]
			and c["cap_fill"] == Palette.SAND and c["doubled"] and c["lift"] == 3.0 and c["glyph"],
		"both at once: cap %s, doubled %s, lift %.0f, glyph %s" % [c["cap_fill"].to_html(false), c["doubled"], c["lift"], c["glyph"]])


func _check_refusal() -> void:
	var bar = _bar()
	bar.step(1.0)
	var before: float = bar.glyph_x
	var events = _game.events
	_game.player.intent.slot_pick = 2
	events.verb_failed.emit("select", "cooling", Vector3.ZERO)
	_game.player.intent.slot_pick = -1
	var widest := 0.0
	for i in 8:
		bar.step(0.01)
		widest = maxf(widest, absf(bar.shake_offset("line").x))
	var flash: Color = bar.flash_color("line")
	var other: float = bar.shake_offset("special").length()
	_report("refused pick", widest > 1.0 and widest <= AbilityBar.SHAKE + 0.01 and Color(flash, 1.0).is_equal_approx(Palette.SLATE)
			and flash.a > 0.0 and other == 0.0 and is_equal_approx(bar.glyph_x, before),
		"slot 3 shook %.1f px (cap %.0f), flash %s, slot 2 still, glyph %.1f -> %.1f"
			% [widest, AbilityBar.SHAKE, flash.to_html(), before, bar.glyph_x])
	bar.step(1.0)
	_report("refusal ends", bar.shake_offset("line") == Vector2.ZERO and bar.flash_color("line").a == 0.0, "after 1 s the slot is still")
	bar.line_loaded = true
	var badge: bool = bar.badge_shown()
	bar.line_loaded = false
	_report("hook badge", badge and not bar.badge_shown(), "a loaded line skill wears the badge on slot 3")


func _check_meter_static() -> void:
	var span: Vector2 = AimReticle.meter_span(1.0)
	var half: Vector2 = AimReticle.meter_span(0.5)
	var gap_mid := fposmod((span.x + span.y) * 0.5 + PI, TAU)
	_report("arc geometry", is_equal_approx(AimReticle.meter_radius(), AimReticle.GAUGE_RING + 10.0) and AimReticle.METER_WIDTH == 4.0
			and is_equal_approx(span.y - span.x, TAU * 0.75) and absf(gap_mid - PI * 0.5) < 0.001 and is_equal_approx(half.y - half.x, TAU * 0.375)
			and half.x == span.x,
		"radius %.0f, width %.0f, sweep %.0f deg, gap centred at %.0f deg (90 is six o'clock), half fill %.0f deg"
			% [AimReticle.meter_radius(), AimReticle.METER_WIDTH, rad_to_deg(span.y - span.x), rad_to_deg(gap_mid), rad_to_deg(half.y - half.x)])
	var rivet := Color("b77843")
	var mint := Palette.live()
	var fill_rivet: Color = AimReticle.meter_fill_color(rivet)
	var fill_sable: Color = AimReticle.meter_fill_color(mint)
	_report("arc colours", fill_rivet == rivet and fill_sable != mint and fill_sable == Palette.SAND.lightened(0.25)
			and AimReticle.meter_rim(true) == mint and AimReticle.meter_rim(false) != mint,
		"fill %s for copper, %s for the mint class; rim %s at full, %s below"
			% [fill_rivet.to_html(false), fill_sable.to_html(false), AimReticle.meter_rim(true).to_html(false), AimReticle.meter_rim(false).to_html(false)])
	var b0: float = AimReticle.breathe(0.25)
	var b1: float = AimReticle.breathe(1.25)
	var b2: float = AimReticle.breathe(0.75)
	_report("breathes at 1 Hz", absf(b0 - b1) < 0.0001 and absf(b0 - b2) > 0.05, "breath %.3f at 0.25 s, %.3f at 1.25 s, %.3f at 0.75 s" % [b0, b1, b2])


func _check_meter_live() -> void:
	var reticle = _game.hud.reticle
	var empty: Dictionary = AbilitySlots.ultimate_of(_game)
	_report("no meter reads 0", AbilitySlots.meter_fill(_game) == 0.0 and empty["state"] == "charging" and reticle.meter == 0.0 and not reticle.q_shown(),
		"fill %.2f, state %s, reticle %.2f, Q %s" % [AbilitySlots.meter_fill(_game), empty["state"], reticle.meter, reticle.q_shown()])
	var meter := FakeMeter.new()
	meter.value = 0.4
	_game.player.abilities.meter = meter
	_refresh()
	var part: float = reticle.meter
	var part_q: bool = reticle.q_shown()
	meter.value = 1.0
	_refresh()
	_report("arc fills", is_equal_approx(part, 0.4) and not part_q and is_equal_approx(reticle.meter, 1.0) and reticle.meter_full
			and reticle.meter_color == AimReticle.meter_fill_color(_game.run.class_def.color),
		"0.4 reads %.2f (Q %s); full reads %.2f, full %s, colour %s" % [part, part_q, reticle.meter, reticle.meter_full, reticle.meter_color.to_html(false)])


func _check_prompt() -> void:
	var glyphs = _game.hud.key_glyphs
	var view := {"ready": {"haul": false, "interact": false, "jump": false, "harpoon": false, "boost": false, "ultimate": true},
		"jump_possible": false, "line": "", "charging": false, "mounted": false, "airborne": false, "winching": false,
		"points": {}}
	var profile = glyphs.profile
	glyphs.new_run()
	# A profile that has never fired the ultimate meets its prompt outside a fight (pass E): a live
	# fight holds the first full meter's prompt, and the prompt shows once the fight lets go.
	var unused: bool = profile.uses("ultimate") == 0
	view["fight"] = true
	glyphs.step(0.016, view)
	var held: bool = not "ultimate" in glyphs.shown_verbs()
	view.erase("fight")
	glyphs.step(0.016, view)
	var first: bool = "ultimate" in glyphs.shown_verbs()
	_report("a first ultimate prompt waits out a fight", unused and held and first, "unused %s, held %s, after %s" % [unused, held, first])
	var word: String = glyphs.shown[0]["word"] if first else ""
	for i in KeyGlyphs.RETIRE_AFTER["ultimate"]:
		profile.add_use("ultimate")
	glyphs.step(KeyGlyphs.FAIL_RETURN + 0.1, view)
	glyphs.step(0.016, view)
	var retired: bool = not "ultimate" in glyphs.shown_verbs()
	glyphs.returned("ultimate")
	glyphs.step(0.016, view)
	var back: bool = "ultimate" in glyphs.shown_verbs()
	glyphs.step(KeyGlyphs.FAIL_RETURN + 0.1, view)
	glyphs.step(0.016, view)
	var gone: bool = not "ultimate" in glyphs.shown_verbs()
	view["ready"]["ultimate"] = false
	glyphs.step(KeyGlyphs.IDLE_RETURN + 0.1, view)
	view["ready"]["ultimate"] = true
	glyphs.step(0.016, view)
	var idle: bool = "ultimate" in glyphs.shown_verbs()
	_report("Q prompt rules", first and word == "ULTIMATE" and retired and back and gone and idle and KeyGlyphs.glyph_of("ultimate") == "key_q",
		"first full meter %s (word %s), retired after 3 uses %s, back on a refusal %s, gone again %s, back after 90 s %s"
			% [first, word, retired, back, gone, idle])
	glyphs.new_run()


func _check_fight_words() -> void:
	var meter = _game.player.abilities.meter
	meter.value = 1.0
	_refresh()
	_game.hud.key_glyphs.step(0.016, KeyGlyphs.view_of(_game.player))
	_refresh()
	var seen: Dictionary = WordBudget.count(_game.hud)
	print("  fight words: %s" % " | ".join(seen["items"].map(func(i): return "%s %d \"%s\"" % [i["node"], i["words"], i["text"]])))
	# Q is drawn exactly once: the words the HUD draws hold one Q, by the reticle or the prompt.
	var q_words: int = _q_drawn(seen)
	_report("fight budget", seen["hud"] <= FIGHT_BUDGET and q_words == 1, "%d HUD words with a full meter (budget %d); Q drawn %d times" % [seen["hud"], FIGHT_BUDGET, q_words])
	_check_q_handoff()


# The handoff between the reticle's Q and the prompt's Q (hud._step_ultimate sets hide_q from
# key_glyphs.shown_glyphs): with the prompt live the reticle leaves its Q off; with the prompt
# retired the reticle draws it. Either way the HUD draws one Q.
func _check_q_handoff() -> void:
	var glyphs = _game.hud.key_glyphs
	var reticle = _game.hud.reticle
	var profile = glyphs.profile
	glyphs.new_run()
	glyphs.step(0.016, KeyGlyphs.view_of(_game.player))
	_refresh()
	var live_prompt: bool = "ultimate" in glyphs.shown_verbs()
	var live_reticle: bool = reticle.q_shown()
	var live_q: int = _q_drawn(WordBudget.count(_game.hud))
	# Retire the prompt: the profile has used Q RETIRE_AFTER times, and no first, forced or
	# revived showing is owed this run.
	while profile.uses("ultimate") < KeyGlyphs.RETIRE_AFTER["ultimate"]:
		profile.add_use("ultimate")
	glyphs._first["ultimate"] = false
	glyphs._forced["ultimate"] = 0.0
	glyphs._revived["ultimate"] = false
	glyphs._unused["ultimate"] = 0.0
	glyphs.step(0.016, KeyGlyphs.view_of(_game.player))
	_refresh()
	var retired_prompt: bool = "ultimate" in glyphs.shown_verbs()
	var retired_reticle: bool = reticle.q_shown()
	var retired_q: int = _q_drawn(WordBudget.count(_game.hud))
	_report("Q handoff", live_prompt and not live_reticle and live_q == 1 and not retired_prompt and retired_reticle and retired_q == 1,
		"prompt live: prompt %s, reticle Q %s, Q drawn %d; prompt retired: prompt %s, reticle Q %s, Q drawn %d"
			% [live_prompt, live_reticle, live_q, retired_prompt, retired_reticle, retired_q])
	glyphs.new_run()


# How many times the HUD draws the Q key's label, read off the words it draws.
func _q_drawn(seen: Dictionary) -> int:
	var q: String = Keycap.label("key_q")
	var n := 0
	for item in seen["items"]:
		for token in String(item["text"]).replace(" / ", " ").split(" ", false):
			if token == q:
				n += 1
	return n


func _check_set_piece() -> void:
	var meter = _game.player.abilities.meter
	var before: float = _bar().self_modulate.a
	meter.locked = true
	_refresh()
	var during: float = _bar().self_modulate.a
	meter.locked = false
	meter.value = 0.0
	_refresh()
	var after: float = _bar().self_modulate.a
	# Re-pinned 2026-11-12 (W1-06, PF-21, w37 film 059): the marks dim through self_modulate and solid
	# plates stay behind them, so the row never fades out. Was the whole bar's modulate at 0.4.
	_report("set piece dims", is_equal_approx(before, 1.0) and is_equal_approx(during, 0.4) and is_equal_approx(after, 1.0)
			and is_equal_approx(_bar().modulate.a, 1.0),
		"bar marks alpha %.2f before, %.2f during the set piece, %.2f after" % [before, during, after])
	_game.player.abilities.meter = null
	_refresh()


func _check_notes() -> void:
	var verbs: Array = FieldNotes.VERB_ROWS.map(func(r): return r[0])
	var rows := {}
	for r in FieldNotes.VERB_ROWS:
		rows[r[0]] = r[1]
	var menu: String = ""
	for r in FieldNotes.MENU_ROWS:
		if String(r["keys"]).begins_with("P"):
			menu = r["does"]
	_report("field notes", not "special" in verbs and "select" in verbs and "ultimate" in verbs
			and String(rows.get("fire", "")).contains("picked") and String(rows.get("harpoon", "")).contains("line skill loaded")
			and menu.contains("X (hold)"),
		"verbs %s; pause row \"%s\"" % [verbs, menu])


# Two bars and the reticle in a fixed 1920x1080 SubViewport, so the window's size never
# changes the frame: bar A has slot 2 selected and ready, bar B has slot 2 active with slot 1
# selected; the reticle shows the gauge and the meter both full.
func _build_pixel_view() -> void:
	_pixel_view = SubViewport.new()
	_pixel_view.size = PIXEL_SIZE
	_pixel_view.transparent_bg = false
	_pixel_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_pixel_view)
	var back := ColorRect.new()
	back.color = PIXEL_BACK
	back.size = Vector2(PIXEL_SIZE)
	_pixel_view.add_child(back)
	var tint: Color = _game.run.class_def.color
	var shape: String = _game.run.class_def.shape
	var live: Array = AbilitySlots.new().slots(_game)
	var picked: Array = []
	var active: Array = []
	for entry in live:
		var a: Dictionary = (entry as Dictionary).duplicate(true)
		a.merge({"state": "ready", "selected": a["slot"] == "special", "select_left": 0.0}, true)
		picked.append(a)
		var b: Dictionary = (entry as Dictionary).duplicate(true)
		b.merge({"state": "active" if b["slot"] == "special" else "ready", "selected": b["slot"] == "weapon", "select_left": 0.0}, true)
		active.append(b)
	var y := 960.0
	for list in [picked, active]:
		var bar := AbilityBar.new()
		bar.position = Vector2(160.0 + 520.0 * _pixel_bars.size(), y)
		_pixel_view.add_child(bar)
		bar.update_slots(list, tint, shape)
		bar.step(1.0)
		_pixel_bars.append(bar)
	var reticle := AimReticle.new()
	_pixel_view.add_child(reticle)
	reticle.setup(_game.player, null)
	reticle.gauge = 1.0
	reticle.gauge_color = tint
	reticle.meter = 1.0
	reticle.meter_full = true
	reticle.meter_color = AimReticle.meter_fill_color(tint)
	reticle.hide_q = false


func _check_pixels() -> void:
	var image: Image = _pixel_view.get_texture().get_image()
	var at := func(bar: Control, local: Vector2) -> Color:
		var p := bar.position + local
		return image.get_pixel(int(p.x), int(p.y))
	var rects: Dictionary = (_pixel_bars[0] as Control).call("slot_rects")
	var cx: float = (rects["special"] as Rect2).get_center().x
	var cap: Vector2 = Keycap.size_of("key_2", AbilityBar.KEY_H)
	# Inside the keycap, past its 2 px border and clear of the digit; and the row 3.5 px above
	# the slot's resting top, which only a lifted (active) slot's frame reaches.
	var cap_at := Vector2(cx - cap.x * 0.5 + 4.0, AbilityBar.SLOT + AbilityBar.KEY_GAP + AbilityBar.KEY_H * 0.5)
	var lift_at := Vector2(cx, -3.5)
	var sel_cap: Color = at.call(_pixel_bars[0], cap_at)
	var act_cap: Color = at.call(_pixel_bars[1], cap_at)
	var sel_lift: Color = at.call(_pixel_bars[0], lift_at)
	var act_lift: Color = at.call(_pixel_bars[1], lift_at)
	var ok := (_near(sel_cap, Palette.SAND) and _far(act_cap, Palette.SAND) and act_cap.get_luminance() < 0.3
		and _near(sel_lift, PIXEL_BACK) and _far(act_lift, PIXEL_BACK))
	_report("selected vs active pixels", ok,
		"keycap fill: selected %s (sand %s), active %s; lift row: selected %s (back %s), active %s"
			% [sel_cap.to_html(false), Palette.SAND.to_html(false), act_cap.to_html(false),
				sel_lift.to_html(false), PIXEL_BACK.to_html(false), act_lift.to_html(false)])
	var out := ProjectSettings.globalize_path("res://").path_join("../../artifacts/local/w13-b2-pixel").simplify_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var path := out.path_join("skill_bar_1080p.png")
	var saved := image.save_png(path)
	_report("1080p still", saved == OK and image.get_size() == PIXEL_SIZE, "%dx%d saved to %s (error %d)" % [image.get_width(), image.get_height(), path, saved])
	_pixel_view.queue_free()


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= PIXEL_TOLERANCE and absf(a.g - b.g) <= PIXEL_TOLERANCE and absf(a.b - b.b) <= PIXEL_TOLERANCE


func _far(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.3


func _open_pause() -> void:
	var menu = _game.get_node("PauseMenu")
	menu.quit_chosen.connect(func(): _quits += 1)
	menu.open()


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	root.push_input(event)


func _check_pause() -> void:
	var menu = _game.get_node("PauseMenu")
	var open_before: bool = menu.is_open()
	_key(KEY_Q, true)
	_key(KEY_Q, false)
	var q_quit := _quits
	_key(KEY_X, true)
	menu.step_quit(0.2)
	_key(KEY_X, false)
	menu.step_quit(1.0)
	var short_quit := _quits
	_key(KEY_X, true)
	menu.step_quit(0.3)
	var mid := _quits
	var fill: float = menu.quit_fill()
	menu.step_quit(0.31)
	_key(KEY_X, false)
	_report("pause quit", open_before and q_quit == 0 and short_quit == 0 and mid == 0 and fill > 0.45 and fill < 0.55 and _quits == 1
			and menu.QUIT_HOLD == 0.6 and menu.row("quit").key == "key_x",
		"Q quit %d; a short X %d; X held 0.3 s %d at fill %.2f; X held 0.61 s %d" % [q_quit, short_quit, mid, fill, _quits])


# One HUD tick: the bar and the reticle read the record now.
func _refresh() -> void:
	_game.hud._process(0.0)
