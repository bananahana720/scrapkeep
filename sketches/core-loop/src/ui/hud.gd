extends CanvasLayer

const SpeedTier := preload("res://src/movement/speed_tier.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Palette := preload("res://src/core/palette.gd")
const RunState := preload("res://src/core/run_state.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")

# The spine's HUD: the objective line that is always on screen during play, the run's
# numbers, and toasts for notable facts. Wording and colour come from event_kinds.gd,
# so a toast reads the same as the row presentation and audio use.

const TOAST_SECONDS := 2.6
# Facts whose on-screen moment presentation owns (a banner with its own fanfare), so
# the HUD adds no toast of its own. The event_kinds wording still names them.
const PRESENTATION_OWNED := ["synergy_discovered"]
const TOAST_LINES := 3
# Facts whose wording needs a field from the signal, by argument position.
const FIELD_ARGS := {
	"stage_entered": ["stage", 0],
	"stage_cleared": ["stage", 0],
	"part_gained": ["part", 0],
	"reward_chosen": ["part", 0],
	"event_announced": ["event", 0],
	"event_started": ["event", 0],
	"event_ended": ["event", 0],
	"milestone_won": ["event", 0],
	"heft_class_changed": ["class", 0],
	"heft_class_dropped": ["class", 0],
	"synergy_discovered": ["name", 0],
}

var game
var reticle

var _objective: Label
var _pips: Label
var _status: Label
var _speed: Label
var _hint: Label
var _restart: Label
var _toasts: VBoxContainer
var _toast_rows: Array = []


func setup(game_ref) -> void:
	game = game_ref
	layer = 1

	# The objective and the core pips share one centred row: the pips are the bonus
	# cores that overcharge this stage's gates, so they sit beside what the stage wants.
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	row.position = Vector2(-700.0, 16.0)
	row.custom_minimum_size = Vector2(1400.0, 0.0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_objective = _label(26)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_objective)
	_pips = _label(26)
	_pips.add_theme_color_override("font_color", EventKinds.color("core_gained"))
	row.add_child(_pips)

	_status = _label(20)
	_status.position = Vector2(18.0, 14.0)
	add_child(_status)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-400.0, 70.0)
	_toasts.custom_minimum_size = Vector2(800.0, 0.0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	_restart = _label(24)
	_restart.set_anchors_preset(Control.PRESET_CENTER)
	_restart.position = Vector2(-160.0, 90.0)
	_restart.add_theme_color_override("font_color", Palette.AMBER)
	add_child(_restart)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.position = Vector2(18.0, -84.0)
	add_child(bottom)
	_speed = _label(22)
	bottom.add_child(_speed)
	_hint = _label(15)
	_hint.text = FieldNotes.hint_rows()
	bottom.add_child(_hint)

	reticle = AimReticle.new()
	add_child(reticle)
	reticle.setup(game.player, game.camera.cam)

	_connect_toasts(game.events)
	# The phase name is the signal's second argument, so it gets its own handler.
	game.events.boss_phase_changed.connect(func(_phase: int, phase_name: String):
		toast(EventKinds.hud("boss_phase_changed", {"name": phase_name.capitalize()}), EventKinds.color("boss_phase_changed")))


func _connect_toasts(events) -> void:
	for kind in GameEvents.signal_names():
		if EventKinds.priority(kind) < EventKinds.TOAST_PRIORITY or EventKinds.row(kind).get("hud", "") == "":
			continue
		var argc: int = _arg_count(events, kind)
		if kind == "boss_phase_changed" or kind in PRESENTATION_OWNED:
			continue
		if FIELD_ARGS.has(kind):
			events.connect(kind, _drop_args(_on_field_fact.bind(kind), argc - 1))
		else:
			events.connect(kind, _drop_args(_on_fact.bind(kind), argc))


static func _drop_args(callable: Callable, count: int) -> Callable:
	return callable.unbind(count) if count > 0 else callable


static func _arg_count(events, kind: String) -> int:
	for info in events.get_signal_list():
		if info["name"] == kind:
			return (info["args"] as Array).size()
	return 0


# A field fact's first argument names the field; later arguments were unbound.
func _on_field_fact(value, kind: String) -> void:
	var field: String = FIELD_ARGS[kind][0]
	var shown = value
	if kind == "heft_class_changed" or kind == "heft_class_dropped":
		shown = RunState.roman(int(value))
	elif kind == "synergy_discovered" and game.codex != null:
		shown = game.codex.name_of(value)
	elif value is String:
		shown = (value as String).replace("_", " ").capitalize()
	toast(EventKinds.hud(kind, {field: shown}), EventKinds.color(kind))


func _on_fact(kind: String) -> void:
	toast(EventKinds.hud(kind), EventKinds.color(kind))


# "Heft II ▸ 40%": the class, and how far toward the next one.
func heft_text() -> String:
	var run = game.run
	var cls: int = run.heft_class()
	if cls >= RunState.HEFT_CLASS_AT.size():
		return "Heft %s ▸ max" % RunState.roman(cls)
	return "Heft %s ▸ %d%%" % [RunState.roman(cls), int(run.heft_progress() * 100.0)]


# Two slots, one per gate tier the cores can buy, and a count past that.
static func core_pips(cores: int) -> String:
	var shown := ""
	for i in RunState.CORE_TIER_CAP:
		shown += "◆" if i < cores else "◇"
	if cores > RunState.CORE_TIER_CAP:
		shown += " +%d" % (cores - RunState.CORE_TIER_CAP)
	return shown


func toast(text: String, color := Palette.SAND) -> void:
	if text == "":
		return
	var row := _label(22)
	row.text = text
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_theme_color_override("font_color", color)
	_toasts.add_child(row)
	_toast_rows.append({"label": row, "left": TOAST_SECONDS})
	while _toast_rows.size() > TOAST_LINES:
		(_toast_rows.pop_front()["label"] as Label).queue_free()


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _process(delta: float) -> void:
	if game == null:
		return
	var i := _toast_rows.size() - 1
	while i >= 0:
		var row: Dictionary = _toast_rows[i]
		row["left"] -= delta
		(row["label"] as Label).modulate.a = clampf(row["left"] / 0.5, 0.0, 1.0)
		if row["left"] <= 0.0:
			(row["label"] as Label).queue_free()
			_toast_rows.remove_at(i)
		i -= 1

	var flow = game.flow
	var playing: bool = flow.in_play()
	_objective.visible = playing
	_pips.visible = playing
	_status.visible = playing
	_speed.visible = playing
	_hint.visible = playing
	reticle.visible = playing
	if not playing:
		_restart.text = ""
		return
	_objective.text = flow.objective_text()
	_pips.text = core_pips(game.run.bonus_cores)
	_objective.add_theme_color_override("font_color", EventKinds.color("beacon_charge_changed") if flow.state_name() == "beacon" else Palette.SAND)

	var run = game.run
	var def: Dictionary = StageDefs.of(run.stage)
	var minutes := int(run.run_time) / 60
	var seconds := int(run.run_time) % 60
	_status.text = "%s\nStage %d / %d  ·  %s\nHP %d / %d  ·  scrap %d  ·  parts %d  ·  %d:%02d" % [
		run.class_def.display_name if run.class_def != null else "", run.stage, StageDefs.COUNT, def["name"],
		int(ceil(run.hp)), int(run.max_hp), run.scrap, run.parts.size(), minutes, seconds,
	]
	_status.add_theme_color_override("font_color", Palette.SAND.lerp(Palette.RUST, 1.0 - run.hp / run.max_hp))

	var state = game.player.state
	var speed: float = state.velocity.length()
	_speed.text = "%.1f m/s  ·  %s  ·  %s%s%s" % [speed, SpeedTier.label(state.tier), heft_text(),
		"" if state.grounded else "  ·  airborne",
		"  ·  MOUNTED: fire from the pylon, Space slingshots off" if game.player.kit.mounted else ""]
	_speed.add_theme_color_override("font_color", SpeedTier.COLORS[state.tier])
	var hold: float = game.restart_hold_fraction()
	_restart.text = "restarting stage %d%%" % int(hold * 100.0) if hold > 0.0 else ""
