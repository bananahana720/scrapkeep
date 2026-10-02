extends CanvasLayer

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const RunState := preload("res://src/core/run_state.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const Icons := preload("res://src/ui/icons.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const Gauge := preload("res://src/ui/gauge.gd")
const HeftDial := preload("res://src/ui/heft_dial.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const SpeedGlyph := preload("res://src/ui/speed_glyph.gd")
const RunStatus := preload("res://src/ui/run_status.gd")
const ObjectiveView := preload("res://src/ui/objective_view.gd")
const RestartMeter := preload("res://src/ui/restart_meter.gd")
const LaunchCard := preload("res://src/ui/launch_card.gd")
const Callouts := preload("res://src/ui/callouts.gd")
const KeyGlyphs := preload("res://src/ui/key_glyphs.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")

# The spine's HUD, built to a word budget (playtest entry 7): icons, gauges and keycaps
# carry the facts, and words appear only where nothing else can say it. Top band: the
# run status (stage pips, clock, threat) and the objective (icon, at most five words,
# punch against plating as two bars, core pips). Toast band: one toast at a time or the
# stage card, then a first-run callout or the hold-R meter. Bottom band: speed, health,
# the ability bar, heft and scrap. The play view carries the reticle, contextual key
# glyphs and edge markers. Colour, shape and wording come from event_kinds.gd, and
# where each piece sits from screen_regions.gd.

# Toast timing (VISUAL-LANGUAGE.md section 7): in over 0.12 s, held 2.4 s for a critical
# fact and 1.6 s for a notable one, out over 0.2 s.
const TOAST_IN := 0.12
const TOAST_OUT := 0.2
const TOAST_HOLD := {3: 2.4, 2: 1.6}
const TOAST_FONT := {3: 23, 2: 19}
const TOAST_WORDS := 4
const OBJECTIVE_WORDS := 5
const TOAST_ICON := 26.0
# Facts whose on-screen moment belongs to something else: presentation's banner, or the
# stage card, which shows the stage it names.
const PRESENTATION_OWNED := ["synergy_discovered"]
const CARD_OWNED := ["run_started", "stage_entered", "stage_cleared", "launched", "boss_arena_entered"]
# Notable (priority 2) facts that still toast, because the player acts on them: a part
# gained outside a gate, and scrap torn loose to chase down. Every other toast is a
# critical (priority 3) fact.
const NOTABLE := ["part_gained", "scrap_lost"]
const TOAST_WIDTH := 800.0
const MARGIN := 18.0
const BOTTOM_GAP := 20.0
const HEALTH_BAR := 190.0
const LOW_HEALTH := 0.25
# Facts whose wording needs a field from the signal, by argument position.
const FIELD_ARGS := {
	"stage_cleared": "stage",
	"reward_chosen": "part",
	"event_announced": "event",
	"event_started": "event",
	"milestone_won": "event",
	"heft_class_changed": "class",
}

var game
var reticle
var profile
var ability_bar
var key_glyphs
var edge_markers
var callouts
var launch_card
# Where each prompt went this frame, for tests: prompt node to its screen rect.
var prompt_rects := {}

var _slots := AbilitySlots.new()
var _objective: Control
var _status: Control
var _toasts: VBoxContainer
var _toast_row: HBoxContainer
var _toast_icon: TextureRect
var _toast_label: Label
var _toast := {}
var _held_toast := {}
var _lower: Control
var _restart: Control
var _health: Control
var _heft: Control
var _scrap: Control
var _speed: Control
# The armour gauge (scrap mode `armor`): the scrap layer over the hull, left of the hull
# gauge, in the scrap colour where the hull is sand. A hit that reached the scrap flashes
# its edge amber for ARMOR_FLASH seconds; the hull gauge turns rust only at low health.
# Wear draws nothing but the bar sinking. The bar is mass against the run's peak.
const ARMOR_BAR := 120.0
const ARMOR_FLASH := 0.35
const ARMOR_PEAK_FLOOR := 100.0
var _armor: Control
var _armor_flash := 0.0
var _armor_peak := ARMOR_PEAK_FLOOR
var _threat := 0
var _laid_out := Vector2.ZERO
# What layout() last read besides the screen: the pieces whose own size moves their neighbours.
var _laid_pieces: Array = []
# Counts layout() runs, so a test can see it stay quiet on an idle frame.
var layout_runs := 0


func setup(game_ref) -> void:
	game = game_ref
	layer = 1
	profile = UiProfile.new(game.storage_dir)

	edge_markers = EdgeMarkers.new()
	add_child(edge_markers)
	edge_markers.setup(game)
	key_glyphs = KeyGlyphs.new()
	add_child(key_glyphs)
	key_glyphs.setup(game, profile)

	_objective = ObjectiveView.new()
	add_child(_objective)
	_status = RunStatus.new()
	add_child(_status)

	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 4)
	add_child(_toasts)
	launch_card = LaunchCard.new()
	_toasts.add_child(launch_card)
	_toast_row = HBoxContainer.new()
	_toast_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_toast_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_row.add_theme_constant_override("separation", 8)
	_toast_row.visible = false
	_toasts.add_child(_toast_row)
	_toast_icon = TextureRect.new()
	_toast_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_toast_icon.custom_minimum_size = Vector2(TOAST_ICON, TOAST_ICON)
	_toast_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_row.add_child(_toast_icon)
	_toast_label = _label(TOAST_FONT[3])
	_toast_row.add_child(_toast_label)
	_lower = Control.new()
	_lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lower.custom_minimum_size = Vector2(0.0, 30.0)
	_toasts.add_child(_lower)
	callouts = Callouts.new()
	_lower.add_child(callouts)
	callouts.setup(game, profile)
	callouts.set_anchors_preset(Control.PRESET_FULL_RECT)
	_restart = RestartMeter.new()
	_lower.add_child(_restart)
	_restart.set_anchors_preset(Control.PRESET_FULL_RECT)

	ability_bar = AbilityBar.new()
	add_child(ability_bar)
	_speed = SpeedGlyph.new()
	add_child(_speed)
	_health = Gauge.new("res_health", HEALTH_BAR, true)
	add_child(_health)
	_heft = HeftDial.new()
	add_child(_heft)
	_scrap = Gauge.new("res_scrap", 0.0)
	add_child(_scrap)
	_armor = Gauge.new("res_scrap", ARMOR_BAR, true)
	add_child(_armor)
	_armor.visible = false
	game.run.armor_hit.connect(func(_removed: float, _spill: int, _source: String): _armor_flash = ARMOR_FLASH)

	reticle = AimReticle.new()
	add_child(reticle)
	reticle.setup(game.player, game.camera.cam)

	_connect_toasts(game.events)
	game.events.boss_phase_changed.connect(func(_phase: int, phase_name: String):
		toast_kind("boss_phase_changed", {"name": phase_name.capitalize()}))
	game.events.event_ended.connect(_on_event_ended)
	game.events.part_gained.connect(_on_part_gained)
	game.events.heft_class_changed.connect(func(_c: int, _h: float): _heft.flash(Color.WHITE))
	game.events.heft_class_dropped.connect(func(_c: int, _h: float): _heft.flash(EventKinds.color("heft_class_dropped")))
	game.events.launched.connect(_on_launched)
	game.events.stage_entered.connect(_on_stage_entered)
	game.events.threat_rose.connect(func(tier: int): _threat = maxi(_threat, tier))
	game.events.boss_arena_entered.connect(func():
		launch_card.show_card("fac_fleet", EventKinds.hud("boss_arena_entered"), EventKinds.color("boss_arena_entered")))
	game.events.run_started.connect(func(_class_id: String):
		_threat = 0
		_armor_peak = ARMOR_PEAK_FLOOR)
	layout(_screen_size())


# Every kind the HUD may toast, for the wording check.
static func toast_kinds() -> Array[String]:
	var out: Array[String] = []
	for kind in EventKinds.ROWS:
		if EventKinds.row(kind).get("hud", "") == "" or kind in CARD_OWNED or kind in PRESENTATION_OWNED:
			continue
		if EventKinds.priority(kind) > EventKinds.TOAST_PRIORITY or kind in NOTABLE or kind == "event_ended":
			out.append(kind)
	return out


# A toast's words are its row's hud wording.
static func toast_text(kind: String, fields := {}) -> String:
	return EventKinds.hud(kind, fields)


func _connect_toasts(events) -> void:
	for kind in toast_kinds():
		if kind in ["boss_phase_changed", "event_ended", "part_gained"]:
			continue
		var argc: int = _arg_count(events, kind)
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


func _on_field_fact(value, kind: String) -> void:
	var shown = value
	if kind == "heft_class_changed":
		shown = RunState.roman(int(value))
	elif value is String:
		shown = (value as String).replace("_", " ").capitalize()
	toast_kind(kind, {FIELD_ARGS[kind]: shown})


func _on_fact(kind: String) -> void:
	toast_kind(kind)


# A gate's part already toasts through reward_chosen; any other source toasts here.
func _on_part_gained(part_id: String, source: String) -> void:
	if source != "gate":
		toast_kind("part_gained", {"part": part_id.replace("_", " ").capitalize()})


# Only a lost event gets a toast: a win already has its milestone toast.
func _on_event_ended(event_id: String, outcome: String) -> void:
	if outcome == "lost":
		toast(toast_text("event_ended", {"event": event_id.replace("_", " ").capitalize()}), Palette.RUST, "wave", 2)


func toast_kind(kind: String, fields := {}) -> void:
	toast(toast_text(kind, fields), EventKinds.color(kind), EventKinds.row(kind).get("shape", "none"), mini(EventKinds.priority(kind), 3))


# One toast at a time: a new one replaces the one showing, and the same words already
# showing stay up for another full beat instead (the gates re-publish their offers
# whenever they move). While the stage card is up, the newest toast waits for it.
func toast(text: String, color := Palette.SAND, shape := "diamond", priority := 3) -> void:
	if text == "":
		return
	var hold: float = TOAST_HOLD.get(priority, TOAST_HOLD[2])
	if not _toast.is_empty() and _toast["text"] == text:
		_toast["left"] = maxf(_toast["left"], hold + TOAST_OUT)
		return
	if not _held_toast.is_empty() and _held_toast["text"] == text:
		return
	var entry := {"text": text, "color": color, "shape": shape, "priority": priority, "left": TOAST_IN + hold + TOAST_OUT, "age": 0.0}
	if launch_card.showing():
		_held_toast = entry
		return
	_show_toast(entry)


func _show_toast(entry: Dictionary) -> void:
	_toast = entry
	_toast_label.text = entry["text"]
	_toast_label.add_theme_color_override("font_color", entry["color"])
	_toast_label.add_theme_font_size_override("font_size", TOAST_FONT.get(entry["priority"], TOAST_FONT[2]))
	_toast_icon.texture = Icons.shape(entry["shape"])
	_toast_icon.modulate = entry["color"]
	_toast_row.visible = true
	_toast_row.modulate.a = 0.0


# The toast on screen, or the one waiting for the stage card to clear.
func toast_texts() -> Array[String]:
	var out: Array[String] = []
	var entry := _held_toast if launch_card.showing() and not _held_toast.is_empty() else _toast
	if not entry.is_empty():
		out.append(entry["text"])
	return out


func _on_launched(_velocity: Vector3) -> void:
	var next: int = game.run.stage + 1
	if next <= game.ctx.stages.COUNT:
		_card_for_stage(next)


func _on_stage_entered(stage: int, retry: bool) -> void:
	_threat = 0
	if retry:
		return
	if launch_card.showing():
		launch_card.extend()
	else:
		_card_for_stage(stage)


func _card_for_stage(stage: int) -> void:
	launch_card.show_card("obj_beacon", game.ctx.stages.of(stage)["name"], EventKinds.color("stage_entered"))


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600.0, 900.0)


# Puts every piece in its band for a screen of this size (screen_regions.gd).
func layout(size: Vector2) -> void:
	_laid_out = size
	_laid_pieces = _piece_sizes()
	layout_runs += 1
	var top := ScreenRegions.rect("top", size)
	var toasts := ScreenRegions.rect("toasts", size)
	var bottom := ScreenRegions.rect("bottom", size)

	var objective_size: Vector2 = _objective.extent()
	_objective.size = Vector2(minf(size.x * 0.5, maxf(objective_size.x, 420.0)), objective_size.y)
	_objective.position = Vector2((size.x - _objective.size.x) * 0.5, top.position.y + 12.0)
	_status.position = Vector2(MARGIN, top.position.y + 12.0)

	var toast_width := minf(TOAST_WIDTH, size.x - 2.0 * MARGIN)
	_toasts.position = Vector2((size.x - toast_width) * 0.5, toasts.position.y + 2.0)
	_toasts.custom_minimum_size = Vector2(toast_width, 0.0)
	_toasts.size = Vector2(toast_width, 0.0)

	var bar_size: Vector2 = ability_bar.bar_size(maxi(ability_bar.slots.size(), 4))
	var bar_y := bottom.position.y + (bottom.size.y - bar_size.y) * 0.5
	ability_bar.position = Vector2((size.x - bar_size.x) * 0.5, bar_y)
	var slot_mid := bar_y + AbilityBar.SLOT * 0.5
	_health.position = Vector2(ability_bar.position.x - BOTTOM_GAP - _health.size.x, slot_mid - _health.size.y * 0.5)
	_heft.position = Vector2(ability_bar.position.x + bar_size.x + BOTTOM_GAP, slot_mid - _heft.size.y * 0.5)
	_scrap.position = Vector2(_heft.position.x + _heft.size.x + BOTTOM_GAP, slot_mid - _scrap.size.y * 0.5)
	_armor.position = Vector2(_health.position.x - BOTTOM_GAP - _armor.size.x, slot_mid - _armor.size.y * 0.5)
	_speed.position = Vector2(MARGIN, slot_mid - _speed.size.y * 0.5)


# The sizes layout() depends on. Relayout when one changes, not every frame: each
# extent() call shapes text.
func _piece_sizes() -> Array:
	return [_objective.custom_minimum_size, _health.size, _armor.size, _heft.size, _scrap.size, maxi(ability_bar.slots.size(), 4)]


# The screen rect of each piece, for the layout test: {region: [Rect2, ...]}.
func piece_rects() -> Dictionary:
	return {
		"top": [_rect_of(_objective), _rect_of(_status)],
		"toasts": [_rect_of(_toasts)],
		"bottom": [_rect_of(ability_bar), _rect_of(_health), _rect_of(_heft), _rect_of(_scrap), _rect_of(_speed)]
			+ ([_rect_of(_armor)] if _armor.visible else []),
	}


static func _rect_of(control: Control) -> Rect2:
	var s := control.get_combined_minimum_size()
	return Rect2(control.position, Vector2(maxf(s.x, control.size.x), maxf(s.y, control.size.y)))


# The objective for the flow's state, in at most five words: what to do, with the
# Warden's lesson once it is awake, and punch against plating while a lock stands.
func objective_reading() -> Dictionary:
	var flow = game.flow
	var out := {"icon": "", "words": "", "color": Palette.SAND, "progress": -1.0, "punch": -1.0, "plating": -1.0}
	match flow.state_name():
		"stage", "beacon":
			if flow.sealed and flow.lap_dormant():
				# Laps mode: nothing lands on a sleeping Warden, so no punch bars; the
				# beacon's charge is the laps.
				out["icon"] = "obj_beacon"
				out["words"] = flow.lap_objective(true)
				out["color"] = EventKinds.color("lap_completed")
				out["progress"] = game.beacon.fraction()
			elif flow.sealed:
				var engaged: bool = is_instance_valid(flow.warden) and game.player.ball_position().distance_to(flow.warden.global_position) < 40.0
				out["icon"] = "obj_warden"
				out["words"] = EventKinds.LESSON_SHORT.get(flow.stage_def()["warden_lesson"], "") if engaged else EventKinds.OBJECTIVE_SHORT["stage_entered"]
				out["color"] = EventKinds.color("warden_engaged")
				out["progress"] = game.beacon.fraction()
				out["punch"] = flow.punch_now()
				out["plating"] = flow.warden_plating()
				# The drop mode's badge: drops left as whole segments, no punch race.
				var drop = flow.warden.get("drop") if is_instance_valid(flow.warden) else null
				if drop != null:
					out["words"] = EventKinds.drop_objective(drop.gun_role)
					out["punch"] = -1.0
					out["plating"] = -1.0
					out["progress"] = -1.0
					out["segments"] = drop.drops
					out["segments_left"] = drop.segments_left()
			else:
				out["icon"] = "obj_beacon"
				out["words"] = EventKinds.objective("beacon_unsealed")
				out["color"] = EventKinds.color("beacon_charge_changed")
				out["progress"] = game.beacon.fraction()
		"gates":
			out["icon"] = "obj_gate"
			out["words"] = EventKinds.objective("reward_offered")
			out["color"] = EventKinds.color("reward_offered")
		"launch":
			if not launch_card.showing():
				out["icon"] = "obj_gate"
				out["words"] = EventKinds.objective("launched")
				out["color"] = EventKinds.color("launched")
		"boss":
			out["icon"] = "fac_fleet"
			out["words"] = EventKinds.OBJECTIVE_SHORT["boss_arena_entered"]
			out["color"] = EventKinds.color("boss_arena_entered")
			out["punch"] = flow.punch_now()
			out["plating"] = flow.boss_plating_now()
	return out


# The heft dial's reading: the class, its numeral and the share of the way to the next.
func heft_reading() -> Dictionary:
	var run = game.run
	var cls: int = run.heft_class()
	var at_max: bool = cls >= RunState.HEFT_CLASS_AT.size()
	return {"class": cls, "classes": RunState.HEFT_CLASS_AT.size(), "numeral": RunState.roman(cls),
		"progress": 0.0 if at_max else run.heft_progress()}


# Every world-attached prompt in front of the camera and within its reach goes in the
# prompts band, nearest first, at most MAX_PROMPTS of them. Each takes the free spot
# nearest its anchor's column (free_spot); the rest wait off screen. A prompt shows its
# detail only while the ball is within its DETAIL_RANGE.
func place_prompts(size: Vector2, playing: bool) -> void:
	prompt_rects.clear()
	var cam: Camera3D = game.camera.cam
	var ball: Vector3 = game.player.ball_position()
	var near: Array = []
	for prompt in get_tree().get_nodes_in_group(ScreenRegions.PROMPT_GROUP):
		prompt.visible = false
		if not playing or prompt.is_empty():
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
		prompt.near = ball.distance_to(entry[2]) <= WorldPrompt.DETAIL_RANGE
		var extent: Vector2 = prompt.shown_extent()
		var want := Rect2(ScreenRegions.clamp_prompt(cam.unproject_position(entry[2]), extent, size), extent)
		var spot := free_spot(want, placed, band)
		if spot.size == Vector2.ZERO:
			continue
		prompt.position = spot.position
		prompt.size = extent
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
	_step_toast(delta)

	var flow = game.flow
	var playing: bool = flow.in_play()
	place_prompts(size, playing)
	for piece in [_objective, _status, _toasts, ability_bar, _health, _heft, _scrap, _speed, reticle, key_glyphs, edge_markers]:
		piece.visible = playing
	_armor.visible = playing and game.run.armor_mode
	if not playing:
		_restart.set_fraction(0.0)
		return

	var run = game.run
	var reading := objective_reading()
	_objective.set_objective(reading["icon"], reading["words"], reading["color"], reading["progress"],
		reading["punch"], reading["plating"], run.bonus_cores, RunState.CORE_TIER_CAP)
	_objective.set_segments(int(reading.get("segments", 0)), int(reading.get("segments_left", 0)))
	_status.set_status(run.stage, game.ctx.stages.COUNT, game.boss != null and game.ctx.stages.BOSS != "", flow.in_arena, run.run_time, _threat)

	var hp_share: float = clampf(run.hp / maxf(1.0, run.max_hp), 0.0, 1.0)
	_health.set_reading(hp_share, Palette.SAND, "", hp_share <= LOW_HEALTH, EventKinds.color("player_hit"))
	var heft := heft_reading()
	_heft.set_reading(heft["class"], heft["classes"], heft["progress"], heft["numeral"], EventKinds.color("heft_class_changed"))
	_scrap.set_reading(-1.0, EventKinds.color("scrap_collected"), str(run.scrap))
	if run.armor_mode:
		_armor_peak = maxf(_armor_peak, run.mass)
		_armor_flash = maxf(0.0, _armor_flash - delta)
		_armor.set_reading(clampf(run.mass / _armor_peak, 0.0, 1.0), EventKinds.color("scrap_collected"),
			str(int(round(run.mass))), _armor_flash > 0.0, Palette.AMBER)
	_speed.set_tier(game.player.state.tier)

	var tint: Color = run.class_def.color if run.class_def != null else Palette.SAND
	var shape: String = run.class_def.shape if run.class_def != null else "ring"
	var slots: Array = _slots.slots(game)
	ability_bar.update_slots(slots, tint, shape)
	reticle.gauge = AbilitySlots.gauge_of(slots)
	# An interactable's hold-to-arm fills the same class ring (LOOP-REDESIGN section 9).
	var interact = game.world.get("interact") if game.world != null else null
	if interact != null:
		reticle.gauge = maxf(reticle.gauge, interact.hold_fraction())
	reticle.gauge_color = tint
	if _piece_sizes() != _laid_pieces:
		layout(size)

	var hold: float = game.restart_hold_fraction()
	_restart.set_fraction(hold)
	_restart.visible = hold > 0.0
	callouts.suppressed = hold > 0.0


func _step_toast(delta: float) -> void:
	if not launch_card.showing() and not _held_toast.is_empty():
		_show_toast(_held_toast)
		_held_toast = {}
	_toast_row.visible = not _toast.is_empty() and not launch_card.showing()
	if _toast.is_empty():
		return
	_toast["left"] -= delta
	_toast["age"] += delta
	_toast_row.modulate.a = clampf(minf(_toast["age"] / TOAST_IN, _toast["left"] / TOAST_OUT), 0.0, 1.0)
	if _toast["left"] <= 0.0:
		_toast = {}
		_toast_row.visible = false
