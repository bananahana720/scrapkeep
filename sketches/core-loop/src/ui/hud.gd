extends CanvasLayer

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const Objectives := preload("res://src/core/objectives.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const Icons := preload("res://src/ui/icons.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const Gauge := preload("res://src/ui/gauge.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const SpeedGlyph := preload("res://src/ui/speed_glyph.gd")
const RunStatus := preload("res://src/ui/run_status.gd")
const ObjectiveView := preload("res://src/ui/objective_view.gd")
const RestartMeter := preload("res://src/ui/restart_meter.gd")
const LaunchCard := preload("res://src/ui/launch_card.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Worlds := preload("res://src/core/worlds.gd")
const KeyGlyphs := preload("res://src/ui/key_glyphs.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const WhyCallout := preload("res://src/ui/why_callout.gd")
const PartName := preload("res://src/ui/part_name.gd")
const BossPlate := preload("res://src/ui/boss_plate.gd")
const ChainCounter := preload("res://src/ui/chain_counter.gd")

# The wallet readout: the brass cog and the cogs the run holds, the one number the HUD
# shows because it is what the next roll through a hoop spends.
class CogChip extends Control:
	var amount := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(72.0, 24.0)
		size = custom_minimum_size

	func set_amount(value: int) -> void:
		if value != amount:
			amount = value
			queue_redraw()

	func drawn_words() -> PackedStringArray:
		return PackedStringArray([str(amount)])

	func _draw() -> void:
		var mid := size.y * 0.5
		draw_texture_rect(Icons.texture("res_scrap"), Rect2(Vector2(0.0, mid - 10.0), Vector2(20.0, 20.0)), false, Icons.tint("res_scrap", Palette.BRASS))
		UiDraw.text(self, 26.0, mid, str(amount), 18, Palette.SAND, true)


# The spine's HUD, built to a word budget (playtest entry 7): icons, gauges and keycaps
# carry the facts, and words appear only where nothing else can say it. Top band: the
# run status (stage pips, threat), a boss plate when one is mounted (mount_plate) and the
# objective: a glyph and at most five words from objectives.gd, the fight's state right
# now. Toast band: one toast at a time or the stage card, then the hold-R meter. Bottom
# band: speed, health, the armour gauge and the ability bar. The play view carries the
# reticle, contextual key glyphs, the name of a part just gained above the ball and edge
# markers. Colour and shape come from event_kinds.gd, and where each piece sits from
# screen_regions.gd. Scrap, heft, the punch and plating bars, core pips and the run clock
# are not shown in play; the one number shown is the cog wallet, beside the speed glyph.

# Toast timing (VISUAL-LANGUAGE.md section 7): in over 0.12 s, held 2.4 s for a critical
# fact and 1.6 s for a notable one, out over 0.2 s.
const TOAST_IN := 0.12
const TOAST_OUT := 0.2
const TOAST_HOLD := {3: 2.4, 2: 1.6}
const TOAST_FONT := {3: 23, 2: 19}
const TOAST_WORDS := 4
# An earned achievement's toast: an amber star, "Achievement" and the row's name, 3 s in all
# (in, hold, out). It sits at the top right, clear of the objective, above the menu screens (layer 8), so one earned as a run ends
# still reads. While a Warden fight is live it waits, and the queue shows in order.
const ACH_LAYER := 8
const ACH_TOTAL := 3.0
const ACH_TOP := 14.0
const ACH_WORD := "Achievement"
const OBJECTIVE_WORDS := Objectives.MAX_WORDS
const TOAST_ICON := 26.0
# How long a world card stands alone before its first stage card replaces it.
const WORLD_CARD_BEAT := 1.2
# Facts whose on-screen moment belongs to something else: presentation's banner, or the
# stage card, which shows the stage it names.
const PRESENTATION_OWNED := ["synergy_discovered"]
const CARD_OWNED := ["run_started", "world_entered", "stage_entered", "stage_cleared", "launched", "boss_arena_entered"]
# Notable (priority 2) facts that still toast, because the player acts on them: scrap
# torn loose to chase down. Every other toast is a critical (priority 3) fact. A part
# gained shows its name at the ball (part_name.gd), not as a toast.
const NOTABLE := ["scrap_lost"]
# Facts whose wording stays in event_kinds.gd but whose moment moved: a part gained shows its
# name at the ball, a gate's reward is the part gained, and the heft class has no dial to flash.
const RETIRED_TOASTS := ["part_gained", "reward_chosen", "heft_class_changed", "heft_class_dropped"]
# The event_kinds row whose colour each objective row wears.
const ROW_COLOR := {"find_warden": "warden_engaged", "break_guard": "warden_engaged", "smash_core": "warden_engaged",
	"grow_return": "warden_engaged", "break_warden": "warden_engaged", "lesson_plate": "warden_engaged",
	"lesson_caps": "warden_engaged", "lesson_magnet": "warden_engaged", "charge_beacon": "beacon_charge_changed",
	"find_activity": "activity_done", "roll_gate": "reward_offered", "hold_line": "launched", "break_brindle": "boss_arena_entered"}
# The rows whose glyph is ringed by how much of the Warden is broken.
const RING_ROWS := ["find_warden", "break_guard", "smash_core", "grow_return", "break_warden", "lesson_plate",
	"lesson_caps", "lesson_magnet", "charge_beacon"]
# The gaps of the top slot when a plate is mounted: from the band's top to the plate, and
# from the plate to the objective plate under it.
const PLATE_TOP := 6.0
const PLATE_GAP := 10.0
const TOAST_WIDTH := 800.0
const MARGIN := 18.0
const BOTTOM_GAP := 20.0
const HEALTH_BAR := 190.0
const LOW_HEALTH := 0.25
# Facts whose wording needs a field from the signal, by argument position.
const FIELD_ARGS := {
	"stage_cleared": "stage",
	"event_announced": "event",
	"event_started": "event",
	"milestone_won": "event",
}

var game
var reticle
var profile
var ability_bar
var key_glyphs
var edge_markers
var part_name
var launch_card
var _world_card_at := -1
var why_callout
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
var _ach_panel: PanelContainer
var _ach_name: Label
var _ach_queue: Array[String] = []
var _ach_entry := {}
var _lower: Control
var _restart: Control
var _health: Control
var _speed: Control
# The plate in the top-centre slot, or null (mount_plate), and the HUD's own boss plate
# while a posture Warden is engaged.
var _plate: Control
var _plate_floor := Vector2.ZERO
var boss_plate: Control
# Whether the Warden is engaged, from warden_engaged, and the tally of a build that is
# trying without getting anywhere (objectives.gd).
var _engaged := false
var _struggle := Objectives.Struggle.new()
# The armour gauge (scrap mode `armor`): the scrap layer over the hull, left of the hull
# gauge, in the scrap colour where the hull is sand. A hit that reached the scrap flashes
# its edge amber for ARMOR_FLASH seconds; the hull gauge turns rust only at low health.
# Wear draws nothing but the bar sinking. The bar is mass against the run's peak, with no
# number: the scrap count is read where it is spent.
const ARMOR_BAR := 120.0
const ARMOR_FLASH := 0.35
const ARMOR_PEAK_FLOOR := 100.0
var _armor: Control
var _cogs: CogChip
var chain_counter: Control
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
	_restart = RestartMeter.new()
	_lower.add_child(_restart)
	_restart.set_anchors_preset(Control.PRESET_FULL_RECT)

	ability_bar = AbilityBar.new()
	add_child(ability_bar)
	_speed = SpeedGlyph.new()
	add_child(_speed)
	_health = Gauge.new("res_health", HEALTH_BAR, true)
	add_child(_health)
	_armor = Gauge.new("res_scrap", ARMOR_BAR, true)
	add_child(_armor)
	_armor.visible = false
	_cogs = CogChip.new()
	add_child(_cogs)
	chain_counter = ChainCounter.new()
	add_child(chain_counter)
	game.run.armor_hit.connect(func(_removed: float, _spill: int, _source: String): _armor_flash = ARMOR_FLASH)

	reticle = AimReticle.new()
	add_child(reticle)
	reticle.setup(game.player, game.camera.cam)
	why_callout = WhyCallout.new()
	add_child(why_callout)
	why_callout.setup(game, profile)
	part_name = PartName.new()
	add_child(part_name)

	_build_ach_toast()
	game.events.achievement_earned.connect(func(id: String): _ach_queue.append(String(Achievements.row(id).get("name", id))))
	_connect_toasts(game.events)
	game.events.boss_phase_changed.connect(func(_phase: int, phase_name: String):
		toast_kind("boss_phase_changed", {"name": phase_name.capitalize()}))
	game.events.event_ended.connect(_on_event_ended)
	game.events.part_gained.connect(func(part_id: String, _source: String): part_name.show_part(part_id))
	game.events.warden_engaged.connect(func(_stage: int): _begin_engagement(true))
	game.events.boss_arena_entered.connect(_seat_boss_plate)
	game.events.beacon_unsealed.connect(func(_stage: int): _begin_engagement(false))
	game.events.posture_changed.connect(_on_posture)
	game.events.launched.connect(_on_launched)
	game.events.world_entered.connect(_on_world_entered)
	game.events.stage_entered.connect(_on_stage_entered)
	game.events.threat_rose.connect(func(tier: int): _threat = maxi(_threat, tier))
	game.events.boss_arena_entered.connect(func():
		launch_card.show_card("fac_fleet", EventKinds.hud("boss_arena_entered"), EventKinds.color("boss_arena_entered")))
	game.events.run_started.connect(func(_class_id: String):
		_threat = 0
		_begin_engagement(false)
		_armor_peak = ARMOR_PEAK_FLOOR)
	layout(_screen_size())


func _build_ach_toast() -> void:
	var layer_node := CanvasLayer.new()
	layer_node.layer = ACH_LAYER
	add_child(layer_node)
	_ach_panel = PanelContainer.new()
	_ach_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ach_panel.visible = false
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(Palette.CHARCOAL, 0.94)
	plate.border_color = Palette.AMBER
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(8)
	plate.content_margin_left = 16.0
	plate.content_margin_right = 20.0
	plate.content_margin_top = 8.0
	plate.content_margin_bottom = 8.0
	_ach_panel.add_theme_stylebox_override("panel", plate)
	layer_node.add_child(_ach_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ach_panel.add_child(row)
	var star := TextureRect.new()
	star.texture = Icons.shape("star")
	star.modulate = Palette.AMBER
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.custom_minimum_size = Vector2(TOAST_ICON, TOAST_ICON)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(star)
	var word := _label(18)
	word.text = ACH_WORD
	word.add_theme_color_override("font_color", Palette.AMBER)
	row.add_child(word)
	_ach_name = _label(TOAST_FONT[3])
	_ach_name.add_theme_color_override("font_color", Palette.SAND)
	row.add_child(_ach_name)


# The achievement toast on screen (its row's name), then the names still waiting.
func ach_toasts() -> Array[String]:
	var out: Array[String] = []
	if not _ach_entry.is_empty():
		out.append(_ach_entry["text"])
	return out


func ach_waiting() -> Array[String]:
	return _ach_queue.duplicate()


# A fight is live while the Warden is engaged and still standing.
func _fight_live() -> bool:
	return game.flow != null and game.flow.engaged() and game.flow.sealed


func _step_ach(delta: float) -> void:
	if _ach_entry.is_empty() and not _ach_queue.is_empty() and not _fight_live():
		_ach_entry = {"text": _ach_queue.pop_front(), "left": ACH_TOTAL, "age": 0.0}
		_ach_name.text = _ach_entry["text"]
		_ach_panel.visible = true
	if _ach_entry.is_empty():
		return
	_ach_entry["left"] -= delta
	_ach_entry["age"] += delta
	_ach_panel.modulate.a = clampf(minf(_ach_entry["age"] / TOAST_IN, _ach_entry["left"] / TOAST_OUT), 0.0, 1.0)
	_ach_panel.position = Vector2(_screen_size().x - _ach_panel.size.x - MARGIN, ACH_TOP)
	if _ach_entry["left"] <= 0.0:
		_ach_entry = {}
		_ach_panel.visible = false


# Every kind the HUD may toast, for the wording check.
static func toast_kinds() -> Array[String]:
	var out: Array[String] = []
	for kind in EventKinds.ROWS:
		if EventKinds.row(kind).get("hud", "") == "" or kind in CARD_OWNED or kind in PRESENTATION_OWNED or kind in RETIRED_TOASTS:
			continue
		if EventKinds.priority(kind) > EventKinds.TOAST_PRIORITY or kind in NOTABLE or kind == "event_ended":
			out.append(kind)
	return out


# A toast's words are its row's hud wording.
static func toast_text(kind: String, fields := {}) -> String:
	return EventKinds.hud(kind, fields)


func _connect_toasts(events) -> void:
	for kind in toast_kinds():
		if kind in ["boss_phase_changed", "event_ended"]:
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
	if value is String:
		shown = (value as String).replace("_", " ").capitalize()
	toast_kind(kind, {FIELD_ARGS[kind]: shown})


func _on_fact(kind: String) -> void:
	toast_kind(kind)


# A new engagement starts the struggle tally over; `engaged` is whether the Warden is awake.
func _begin_engagement(engaged: bool) -> void:
	_engaged = engaged
	_struggle.begin()
	_seat_boss_plate()


# The boss plate is up while a Warden on the posture rule is engaged, or the arena's boss
# is live (Brindle's hull, or a stub boss's Warden), bound to its posture body.
func _seat_boss_plate() -> void:
	var warden = game.flow.warden if _engaged else _brindle_hull()
	if is_instance_valid(warden) and warden.has_method("fight") and warden.fight() == "posture":
		if boss_plate == null:
			boss_plate = BossPlate.new()
		boss_plate.bind(warden)
		mount_plate(boss_plate)
	elif boss_plate != null:
		if _plate == boss_plate:
			unmount_plate()
		boss_plate.unbind()
		boss_plate.queue_free()
		boss_plate = null


# The posture body of the arena fight that is live, else null: Brindle's hull, or the
# Warden a stub boss stands. It reads ctx.boss, which flow points at the entered arena's
# module, so worlds whose boss is the stub get the plate too.
func _brindle_hull():
	var boss = game.ctx.boss
	if boss == null or not boss.has_method("active") or not boss.active():
		return null
	if is_instance_valid(boss.get("ship")):
		return boss.ship.hull
	var stub_warden = boss.get("warden")
	return stub_warden if is_instance_valid(stub_warden) else null


func _exit_tree() -> void:
	if boss_plate != null and boss_plate.get_parent() == null:
		boss_plate.free()
		boss_plate = null


func _on_posture(enemy: Node3D, posture: float, staggered: bool) -> void:
	if enemy == game.flow.warden:
		_struggle.note_posture(posture, staggered)


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
	var stages = game.ctx.stages
	if next <= stages.last_of(stages.world_of(game.run.stage)):
		_card_for_stage(next)


# On a table of more than one world, a new world is announced by name before its first
# stage's card, which follows after the world card has been up for a beat. A one-world
# table shows no world card.
func _on_world_entered(world: int) -> void:
	if game.ctx.stages.worlds().size() <= 1:
		return
	var row := Worlds.row(world)
	if row.is_empty():
		return
	launch_card.show_card("obj_beacon", String(row["name"]), EventKinds.color("stage_entered"))
	_world_card_at = Time.get_ticks_msec()


func _on_stage_entered(stage: int, retry: bool) -> void:
	_threat = 0
	_begin_engagement(false)
	if retry:
		return
	if _world_card_at >= 0:
		_world_card_at = -1
		get_tree().create_timer(WORLD_CARD_BEAT).timeout.connect(func():
			if game != null and game.run != null and game.run.stage == stage:
				_card_for_stage(stage))
	elif launch_card.showing():
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
	if _plate != null:
		var plate_size := _plate_size()
		_plate.size = plate_size
		_plate.position = Vector2((size.x - plate_size.x) * 0.5, top.position.y + PLATE_TOP)
		_objective.position.y = _plate.position.y + plate_size.y + PLATE_GAP
	part_name.position = Vector2.ZERO
	part_name.size = size
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
	_armor.position = Vector2(_health.position.x - BOTTOM_GAP - _armor.size.x, slot_mid - _armor.size.y * 0.5)
	_speed.position = Vector2(MARGIN, slot_mid - _speed.size.y * 0.5)
	_cogs.position = Vector2(_speed.position.x + _speed.size.x + BOTTOM_GAP, slot_mid - _cogs.size.y * 0.5)
	chain_counter.position = Vector2(ability_bar.position.x + bar_size.x + BOTTOM_GAP, slot_mid - chain_counter.size.y * 0.5)


# The sizes layout() depends on. Relayout when one changes, not every frame: each
# extent() call shapes text.
func _piece_sizes() -> Array:
	return [_objective.custom_minimum_size, _health.size, _armor.size, maxi(ability_bar.slots.size(), 4), _plate_size()]


# The slot's plate: a boss plate (about 420 by 44 at 1080p) that the coordinator mounts. Its
# size is the larger of its minimum size and its size at mount, so any Control places. It
# sits top-centre and the objective plate moves directly under it. unmount_plate gives
# the layout back exactly as it was and leaves the plate for its owner to free.
func mount_plate(plate: Control) -> void:
	unmount_plate()
	_plate = plate
	_plate_floor = plate.size
	if plate.get_parent() != null:
		plate.get_parent().remove_child(plate)
	add_child(plate)
	layout(_screen_size())


func unmount_plate() -> void:
	if _plate == null:
		return
	remove_child(_plate)
	_plate = null
	_plate_floor = Vector2.ZERO
	layout(_screen_size())


func _plate_size() -> Vector2:
	return _plate.get_combined_minimum_size().max(_plate.custom_minimum_size).max(_plate_floor) if _plate != null else Vector2.ZERO


# The screen rect of each piece, for the layout test: {region: [Rect2, ...]}.
func piece_rects() -> Dictionary:
	return {
		"top": [_rect_of(_objective), _rect_of(_status)] + ([_rect_of(_plate)] if _plate != null else []),
		"toasts": [_rect_of(_toasts)],
		"bottom": [_rect_of(ability_bar), _rect_of(_health), _rect_of(_speed)]
			+ ([_rect_of(_armor)] if _armor.visible else []),
	}


# The wallet the HUD shows: the cogs the run holds.
func wallet_cogs() -> int:
	return _cogs.amount


# The beacon row reads the beacon's own state row, so the HUD, the ring and the edge marker
# agree that an open beacon is an offering, not a live verb.
static func row_color(id: String) -> Color:
	if id == "charge_beacon":
		return EventKinds.state_color("beacon_open")
	return EventKinds.color(ROW_COLOR[id])


static func _rect_of(control: Control) -> Rect2:
	var s := control.get_combined_minimum_size()
	return Rect2(control.position, Vector2(maxf(s.x, control.size.x), maxf(s.y, control.size.y)))


# The objective for the flow's state: the row objectives.gd picks, with its glyph, its colour
# and, while the Warden is still to be found, the metres to it.
func objective_reading() -> Dictionary:
	var flow = game.flow
	var warden = flow.warden if is_instance_valid(flow.warden) else null
	var distance: float = game.player.ball_position().distance_to(warden.global_position) if warden != null else INF
	var id := Objectives.choose({
		"state": flow.state_name(),
		"sealed": flow.sealed,
		"engaged": _engaged,
		"fight": warden.fight() if warden != null and warden.has_method("fight") else "plating",
		"staggered": warden != null and warden.has_method("staggered") and warden.staggered(),
		"struggling": _struggle.struggling,
		"lesson": flow.stage_def()["warden_lesson"],
		"distance": distance,
		"card": launch_card.showing(),
		"activities_left": edge_markers.unfinished_sites().size(),
	})
	if id == "":
		return {"id": "", "icon": "", "words": "", "color": Palette.SAND, "progress": -1.0, "distance": -1}
	return {"id": id, "icon": Objectives.glyph(id), "words": Objectives.words(id), "color": row_color(id),
		"progress": game.beacon.fraction() if id in RING_ROWS else -1.0,
		"distance": int(distance) if id == "find_warden" and distance < INF else -1}


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
	_step_ach(delta)

	var flow = game.flow
	var playing: bool = flow.in_play()
	place_prompts(size, playing)
	for piece in [_objective, _status, _toasts, ability_bar, _health, _speed, _cogs, reticle, key_glyphs, edge_markers, why_callout]:
		piece.visible = playing
	if _plate != null:
		_plate.visible = playing
	part_name.visible = playing and part_name.left > 0.0
	_armor.visible = playing and game.run.armor_mode
	if not playing:
		_restart.set_fraction(0.0)
		chain_counter.step(delta, 0)
		chain_counter.visible = false
		return
	chain_counter.step(delta, game.player.chain.combo)

	var run = game.run
	var reading := objective_reading()
	_objective.set_objective(reading["icon"], reading["words"], reading["color"], reading["progress"], reading["distance"])
	edge_markers.objective_id = reading["id"]
	edge_markers.engaged = _engaged
	var tbl = game.ctx.stages
	var world: int = tbl.world_of(run.stage)
	var world_stages: int = tbl.last_of(world) - tbl.first_of(world) + 1
	var has_boss: bool = game.boss != null and tbl.BOSS != "" and bool(flow.boss_row(world).get("built", false))
	_status.set_status(tbl.local(run.stage), world_stages, has_boss, flow.in_arena, _threat)

	var hp_share: float = clampf(run.hp / maxf(1.0, run.max_hp), 0.0, 1.0)
	_health.set_reading(hp_share, Palette.SAND, "", hp_share <= LOW_HEALTH, EventKinds.color("player_hit"))
	if run.armor_mode:
		_armor_peak = maxf(_armor_peak, run.mass)
		_armor_flash = maxf(0.0, _armor_flash - delta)
		_armor.set_reading(clampf(run.mass / _armor_peak, 0.0, 1.0), EventKinds.color("scrap_collected"),
			"", _armor_flash > 0.0, Palette.AMBER)
	_speed.set_tier(game.player.state.tier)
	_cogs.set_amount(run.cogs)

	var tint: Color = run.class_def.color if run.class_def != null else Palette.SAND
	var shape: String = run.class_def.shape if run.class_def != null else "ring"
	var slots: Array = _slots.slots(game)
	ability_bar.update_slots(slots, tint, shape)
	ability_bar.hide_keys(key_glyphs.shown_glyphs())
	if part_name.visible:
		var cam: Camera3D = game.camera.cam
		var ball: Vector3 = game.player.shown_position()
		if not cam.is_position_behind(ball):
			part_name.follow(cam.unproject_position(ball))
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


# Simulated time: the tally of a build's trying and the part name's 1.2 s run on the physics
# tick, never the wall clock.
func _physics_process(delta: float) -> void:
	if game == null:
		return
	if _engaged:
		_struggle.step(delta)
	part_name.step(delta)


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
