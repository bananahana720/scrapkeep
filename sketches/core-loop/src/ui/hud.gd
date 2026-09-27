extends CanvasLayer

const SpeedTier := preload("res://src/movement/speed_tier.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Palette := preload("res://src/core/palette.gd")
const RunState := preload("res://src/core/run_state.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")

# The spine's HUD: the objective line that is always on screen during play, the run's
# numbers, toasts for notable facts, and the placement of every world-attached prompt.
# Wording and colour come from event_kinds.gd, so a toast reads the same as the row
# presentation and audio use. Where each piece sits comes from screen_regions.gd, so
# the objective, the toasts, the prompts and the HUD never overlap.

const TOAST_SECONDS := 2.6
# Facts whose on-screen moment presentation owns (a banner with its own fanfare), so
# the HUD adds no toast of its own. The event_kinds wording still names them.
const PRESENTATION_OWNED := ["synergy_discovered"]
const TOAST_LINES := ScreenRegions.TOAST_ROWS
const OBJECTIVE_WIDTH := 1400.0
const TOAST_WIDTH := 800.0
const MARGIN := 18.0
# Facts whose wording needs a field from the signal, by argument position.
const FIELD_ARGS := {
	"stage_entered": ["stage", 0],
	"stage_cleared": ["stage", 0],
	"part_gained": ["part", 0],
	"reward_chosen": ["part", 0],
	"event_announced": ["event", 0],
	"event_started": ["event", 0],
	"milestone_won": ["event", 0],
	"heft_class_changed": ["class", 0],
	"heft_class_dropped": ["class", 0],
	"synergy_discovered": ["name", 0],
}

var game
var reticle
# Where each prompt went this frame, for tests: prompt node to its screen rect.
var prompt_rects := {}

var _row: HBoxContainer
var _objective: Label
var _pips: Label
var _status: Label
var _speed: Label
var _hint: Label
var _restart: Label
var _toasts: VBoxContainer
var _toast_rows: Array = []
var _bottom: VBoxContainer
var _laid_out := Vector2.ZERO


func setup(game_ref) -> void:
	game = game_ref
	layer = 1

	# The objective and the core pips share one centred row: the pips are the bonus
	# cores that overcharge this stage's gates, so they sit beside what the stage wants.
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 18)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_objective = _label(26)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_row.add_child(_objective)
	_pips = _label(26)
	_pips.add_theme_color_override("font_color", EventKinds.color("core_gained"))
	_row.add_child(_pips)

	_status = _label(20)
	add_child(_status)

	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	_restart = _label(24)
	_restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_restart.add_theme_color_override("font_color", Palette.AMBER)
	add_child(_restart)

	_bottom = VBoxContainer.new()
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom)
	_speed = _label(22)
	_bottom.add_child(_speed)
	_hint = _label(15)
	_hint.text = FieldNotes.hint_rows()
	_bottom.add_child(_hint)

	reticle = AimReticle.new()
	add_child(reticle)
	reticle.setup(game.player, game.camera.cam)

	_connect_toasts(game.events)
	# The phase name is the signal's second argument, so it gets its own handler.
	game.events.boss_phase_changed.connect(func(_phase: int, phase_name: String):
		toast(EventKinds.hud("boss_phase_changed", {"name": phase_name.capitalize()}), EventKinds.color("boss_phase_changed")))
	game.events.event_ended.connect(_on_event_ended)
	layout(_screen_size())


# Only a lost event gets a toast, in the colour of a loss: a win already has its
# milestone toast, and an event that simply passes needs none.
func _on_event_ended(event_id: String, outcome: String) -> void:
	if outcome == "lost":
		toast(EventKinds.hud("event_ended", {"event": event_id.replace("_", " ").capitalize()}), Palette.RUST)


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600.0, 900.0)


# Puts every piece in its band for a screen of this size (screen_regions.gd). The
# status and the objective share the top band; the restart meter sits under the
# toasts in the toast band; the speed line and hints fill the bottom band.
func layout(size: Vector2) -> void:
	_laid_out = size
	var top := ScreenRegions.rect("top", size)
	var toasts := ScreenRegions.rect("toasts", size)
	var bottom := ScreenRegions.rect("bottom", size)
	var row_width := minf(OBJECTIVE_WIDTH, size.x - 2.0 * MARGIN)
	_row.position = Vector2((size.x - row_width) * 0.5, top.position.y + 16.0)
	_row.custom_minimum_size = Vector2(row_width, 0.0)
	_row.size = Vector2(row_width, 0.0)
	_status.position = Vector2(MARGIN, top.position.y + 10.0)
	var toast_width := minf(TOAST_WIDTH, size.x - 2.0 * MARGIN)
	_toasts.position = Vector2((size.x - toast_width) * 0.5, toasts.position.y)
	_toasts.custom_minimum_size = Vector2(toast_width, 0.0)
	_toasts.size = Vector2(toast_width, 0.0)
	var restart_height := _restart.get_combined_minimum_size().y
	_restart.position = Vector2((size.x - toast_width) * 0.5, toasts.end.y - restart_height)
	_restart.custom_minimum_size = Vector2(toast_width, 0.0)
	_restart.size = Vector2(toast_width, 0.0)
	_bottom.position = Vector2(MARGIN, bottom.position.y + 4.0)


# The screen rect of each piece, for the layout test: {region: [Rect2, ...]}.
func piece_rects() -> Dictionary:
	return {
		"top": [_rect_of(_row), _rect_of(_status)],
		"toasts": [_rect_of(_toasts), _rect_of(_restart)],
		"bottom": [_rect_of(_bottom)],
	}


static func _rect_of(control: Control) -> Rect2:
	var s := control.get_combined_minimum_size()
	return Rect2(control.position, Vector2(maxf(s.x, control.size.x), maxf(s.y, control.size.y)))


func _connect_toasts(events) -> void:
	for kind in GameEvents.signal_names():
		if EventKinds.priority(kind) < EventKinds.TOAST_PRIORITY or EventKinds.row(kind).get("hud", "") == "":
			continue
		var argc: int = _arg_count(events, kind)
		if kind == "boss_phase_changed" or kind == "event_ended" or kind in PRESENTATION_OWNED:
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


# A toast already showing the same words is not repeated: it stays up for another
# full beat instead (the gates re-publish their offers whenever they move).
func toast(text: String, color := Palette.SAND) -> void:
	if text == "":
		return
	for shown in _toast_rows:
		if shown["text"] == text:
			shown["left"] = TOAST_SECONDS
			return
	var row := _label(22)
	row.text = text
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_theme_color_override("font_color", color)
	_toasts.add_child(row)
	_toast_rows.append({"label": row, "left": TOAST_SECONDS, "text": text})
	while _toast_rows.size() > TOAST_LINES:
		var gone: Label = _toast_rows.pop_front()["label"]
		_toasts.remove_child(gone)
		gone.queue_free()


func toast_texts() -> Array[String]:
	var out: Array[String] = []
	for shown in _toast_rows:
		out.append(shown["text"])
	return out


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# Every world-attached prompt in front of the camera and within its reach goes in the
# prompts band, nearest first, at most MAX_PROMPTS of them. Each takes the free spot
# nearest its anchor's column (free_spot); the rest wait off screen.
func place_prompts(size: Vector2, playing: bool) -> void:
	prompt_rects.clear()
	var cam: Camera3D = game.camera.cam
	var near: Array = []
	for prompt in get_tree().get_nodes_in_group(ScreenRegions.PROMPT_GROUP):
		prompt.visible = false
		if not playing or prompt.text == "":
			continue
		var at: Vector3 = prompt.anchor_point()
		if at == Vector3.INF or cam.is_position_behind(at):
			continue
		var d: float = cam.global_position.distance_to(at)
		if d <= prompt.reach:
			near.append([d, prompt, at])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var band := ScreenRegions.rect("prompts", size)
	var placed: Array[Rect2] = []
	for entry in near:
		if placed.size() >= ScreenRegions.MAX_PROMPTS:
			break
		var prompt: Label = entry[1]
		prompt.size = Vector2(ScreenRegions.PROMPT_WIDTH, 0.0)
		var extent := Vector2(ScreenRegions.PROMPT_WIDTH, prompt.get_combined_minimum_size().y)
		var want := Rect2(ScreenRegions.clamp_prompt(cam.unproject_position(entry[2]), extent, size), extent)
		var spot := free_spot(want, placed, band)
		if spot.size == Vector2.ZERO:
			continue
		prompt.position = spot.position
		prompt.visible = true
		placed.append(spot)
		prompt_rects[prompt] = spot


# The spot for `want` that overlaps nothing already placed and stays in the band: its
# own spot if free, else beside a placed prompt on the same row or on the row below,
# whichever is nearest the anchor's column. A zero rect when nothing fits.
static func free_spot(want: Rect2, placed: Array[Rect2], band: Rect2) -> Rect2:
	var gap := ScreenRegions.PROMPT_GAP
	var rows: Array[float] = [want.position.y]
	var xs: Array[float] = [want.position.x]
	for other in placed:
		xs.append(other.end.x + gap)
		xs.append(other.position.x - gap - want.size.x)
		rows.append(other.end.y + gap)
	var best := Rect2()
	var best_cost := INF
	for y in rows:
		for x in xs:
			var spot := Rect2(Vector2(x, y), want.size)
			if not band.grow(0.5).encloses(spot) or placed.any(func(r): return r.intersects(spot)):
				continue
			var cost: float = absf(x - want.position.x) + 4.0 * absf(y - want.position.y)
			if cost < best_cost:
				best_cost = cost
				best = spot
	return best


func _process(delta: float) -> void:
	if game == null:
		return
	var size := _screen_size()
	if size != _laid_out:
		layout(size)
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
	place_prompts(size, playing)
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
