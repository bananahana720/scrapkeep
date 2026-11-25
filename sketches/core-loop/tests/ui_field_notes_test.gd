extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const ControlsDiagram := preload("res://src/ui/controls_diagram.gd")
const Push := preload("res://tests/workshop/push.gd")

# Tab's field notes as pictures (v3 W12, playtest entry 8: "a whole essay of text").
# For each class, in a real run with Tab held:
#   - the Keys page reads in 45 words or fewer, What hurts and Growth in 40;
#   - the controls diagram lights exactly the pilot's own keys (class_kit.gd, from the
#     class row) in the row's colour, and nothing else;
#   - Q and E turn pages, the mouse wheel and buttons turn them too, hovering a page
#     icon opens it, and E past Growth reaches the codex.
# The title's Help page draws the same diagram, with no pilot lit.

const CALM_BUDGET := 40
# The Keys page reads in 45 words or fewer since the skill bar (re-pinned 40 -> 45 on 2026-10-10,
# wave 13 unit B2, design-v3/SKILL-BAR.md section 5): the diagram gains the pick keys 1 and 2 and
# Q, each lit with the pilot's ability words (the weapon now on 1, the ultimate on Q), and LMB
# reads "fire"; F and its word go. Sable, with vault kick and wall mount, is the most at 45.
# What hurts and Growth keep CALM_BUDGET.
const KEYS_BUDGET := 45
const SETTLE := 0.4
const PICTURES := ["keys", "hurts", "grow"]

var _game
var _failures := 0
var _phase := "boot"
var _clock := 0.0
var _class := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _next(phase: String) -> void:
	_phase = phase
	_clock = 0.0


func _process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	if _clock < SETTLE and _phase != "boot":
		return false
	var notes = _game.notes
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			var help = _game.screens._help.diagram
			_report("help reuses the diagram", help.get_script() == ControlsDiagram and help.lit_keys().is_empty()
					and help.shown_keys().size() == notes.diagram().shown_keys().size(),
				"help diagram %s with %d keys, lit %s" % [help.get_script().resource_path.get_file(), help.shown_keys().size(), help.lit_keys()])
			var help_fit: Array = help.text_fit_issues()
			_report("help diagram fits all labels", help_fit.is_empty(), str(help_fit))
			_game.flow.press_start()
			_game.flow.choose_class(_class)
			_next("hold")
		"hold":
			_game.hold_notes(true)
			notes.show_page(0)
			_next("pages")
		"pages":
			_check_pages(notes)
			_check_turns(notes)
			_game.hold_notes(false)
			_class += 1
			if _class < _game.flow.classes.size():
				_game.run.damage(99999.0, "test")
				_game.flow.open_class_select()
				_game.flow.choose_class(_class)
				_next("hold")
				return false
			print("ui_field_notes_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _check_pages(notes) -> void:
	var def = _game.run.class_def
	for i in PICTURES.size():
		notes.show_page(i)
		var seen: Dictionary = WordBudget.count(notes)
		print("  %s %s words: %s" % [def.display_name, PICTURES[i], " | ".join(seen["items"].map(func(it): return "%s %d \"%s\"" % [it["node"], it["words"], it["text"]]))])
		var budget: int = KEYS_BUDGET if PICTURES[i] == "keys" else CALM_BUDGET
		_report("%s %s budget" % [def.display_name, PICTURES[i]], notes.current_page() == PICTURES[i] and seen["hud"] > 0 and seen["hud"] <= budget,
			"%d words on %s (budget %d)" % [seen["hud"], PICTURES[i], budget])
	notes.show_page(0)
	var lit: Dictionary = notes.diagram().lit_keys()
	var own: Array = ClassKit.by_key(def).keys()
	own.sort()
	var got: Array = lit.keys()
	got.sort()
	# A screen draws the pilot's screen colour: Sable's is off mint (LEGIBILITY 14.3, E2-14).
	var tone := ClassDef.screen_color(def.color)
	var colours_ok: bool = lit.values().all(func(c): return c == tone)
	_report("%s lights its keys" % def.display_name, got == own and colours_ok and not lit.has("key_w") and not lit.has("key_tab"),
		"lit %s in %s; the class row's keys are %s" % [got, tone.to_html(false), own])
	var fit_issues: Array = notes.diagram().text_fit_issues()
	_report("%s diagram fits every key without clipping or overlap" % def.display_name,
		fit_issues.is_empty() and notes.diagram().custom_minimum_size.x <= notes._notes.size.x and notes.diagram().custom_minimum_size.y <= notes._notes.size.y,
		"issues=%s diag=%s panel=%s" % [fit_issues, notes.diagram().custom_minimum_size, notes._notes.size])


func _check_turns(notes) -> void:
	notes.show_page(0)
	Push.key(root, KEY_E)
	var after_e: String = notes.current_page()
	Push.key(root, KEY_E)
	Push.key(root, KEY_E)
	var codex: String = notes.current_page()
	Push.key(root, KEY_Q)
	var after_q: String = notes.current_page()
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	var wheel_up: String = notes.current_page()
	_wheel(MOUSE_BUTTON_LEFT)
	var clicked: String = notes.current_page()
	var strip = notes._tabs
	var over := InputEventMouseMotion.new()
	over.position = strip.get_global_transform() * (strip._spots[0]["rect"] as Rect2).get_center()
	over.global_position = over.position
	root.push_input(over, true)
	var hovered: String = notes.current_page()
	_report("pages turn", after_e == "hurts" and codex == "build" and after_q == "grow" and wheel_up == "hurts" and clicked == "grow" and hovered == "keys",
		"E -> %s, E E -> %s, Q -> %s, wheel up -> %s, left click -> %s, hover on the first icon -> %s"
			% [after_e, codex, after_q, wheel_up, clicked, hovered])


func _wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
