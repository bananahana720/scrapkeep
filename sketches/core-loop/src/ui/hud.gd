extends CanvasLayer

const EventKinds := preload("res://src/core/event_kinds.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Palette := preload("res://src/core/palette.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Objectives := preload("res://src/core/objectives.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const Icons := preload("res://src/ui/icons.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const Gauge := preload("res://src/ui/gauge.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const SpeedGlyph := preload("res://src/ui/speed_glyph.gd")
const RunStatus := preload("res://src/ui/run_status.gd")
const ObjectiveView := preload("res://src/ui/objective_view.gd")
const RestartMeter := preload("res://src/ui/restart_meter.gd")
const LaunchCard := preload("res://src/ui/launch_card.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Worlds := preload("res://src/core/worlds.gd")
const KeyGlyphs := preload("res://src/ui/key_glyphs.gd")
const FirstSteps := preload("res://src/ui/first_steps.gd")
const FieldTips := preload("res://src/ui/field_tips.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const WhyCallout := preload("res://src/ui/why_callout.gd")
const PartName := preload("res://src/ui/part_name.gd")
const DangerMark := preload("res://src/ui/danger_mark.gd")
const BossPlate := preload("res://src/ui/boss_plate.gd")
const ChainCounter := preload("res://src/ui/chain_counter.gd")
const NixieRail := preload("res://src/ui/nixie_rail.gd")
const Consumables := preload("res://src/build/consumables.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const WorkOrders := preload("res://src/core/work_orders.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const PickupLines := preload("res://src/ui/pickup_lines.gd")
const PanelFx := preload("res://src/presentation/panel_fx.gd")
const Companion := preload("res://src/core/companion.gd")
const HullMark := preload("res://src/world/hull_mark.gd")
const RunState := preload("res://src/core/run_state.gd")
const Interactables := preload("res://src/world/interactables.gd")

class CogChip extends Control:
	const ICON := "res_scrap"
	const COLOR := Palette.STEEL
	const HOOK_ICON := "res_heft"
	const WIDTH := 72.0
	const PIN_WIDTH := 56.0

	var amount := 0
	var hook_class := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(WIDTH, 24.0)
		size = custom_minimum_size

	func set_amount(value: int) -> void:
		if value != amount:
			amount = value
			queue_redraw()

	func set_hook(heft_class: int) -> void:
		if heft_class == hook_class:
			return
		hook_class = heft_class
		custom_minimum_size.x = WIDTH + (PIN_WIDTH if hook_class > 0 else 0.0)
		size = custom_minimum_size
		queue_redraw()

	func drawn_words() -> PackedStringArray:
		var out := PackedStringArray([str(amount)])
		if hook_class > 0:
			out.append(RunState.roman(hook_class))
		return out

	func _draw() -> void:
		var mid := size.y * 0.5
		UiDraw.icon(self, Icons.texture(ICON), Rect2(Vector2(0.0, mid - 10.0), Vector2(20.0, 20.0)), Icons.tint(ICON, COLOR))
		UiDraw.text(self, 26.0, mid, str(amount), UiTokens.BODY, Palette.SAND, true)
		if hook_class > 0:
			UiDraw.icon(self, Icons.texture(HOOK_ICON), Rect2(Vector2(WIDTH, mid - 10.0), Vector2(20.0, 20.0)), Icons.tint(HOOK_ICON, Palette.AMBER))
			UiDraw.text(self, WIDTH + 24.0, mid, RunState.roman(hook_class), UiTokens.BODY, Palette.AMBER, true)


class NoteKey extends Control:
	const KEY := "key_tab"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Keycap.size_of(KEY, 24.0)

	func _draw() -> void:
		Keycap.draw(self, size * 0.5, KEY, Palette.SAND, 24.0)


const TOAST_IN := 0.12
const TOAST_OUT := 0.2
const TOAST_HOLD := {3: 2.4, 2: 1.6}
const EVENT_LINE_CAP := 12.0
const TOAST_FONT := {3: UiTokens.LABEL, 2: UiTokens.BODY}
const TOAST_WORDS := 4
const CORE_WORDS := ["", "Gates may offer rares", "Gates offer rares, relics", "Gates at their best"]
const ACH_LAYER := 8
const ACH_TOTAL := 3.0
const ACH_TOP := 14.0
const ACH_FONT := UiTokens.LABEL
const ACH_DETAIL_FONT := UiTokens.CAPTION
const RECORD_MARK := {"shape": "wave", "tint": Palette.AMBER, "word": ""}
const TAKE_ICON := "radio_take"
const TAKE_MARKS := {"b-side": {"id": TAKE_ICON, "tint": Palette.SLATE, "word": "B-side"},
	"take": {"id": TAKE_ICON, "tint": Palette.ARC, "word": ""},
	"legend": {"id": TAKE_ICON, "tint": Palette.BRASS, "word": ""}}
const ACHIEVEMENT_MARK := {"shape": "star", "tint": Palette.AMBER, "word": ""}
const LORE_TOTAL := 3.0
const LORE_TOP := 66.0
const CORNER_GAP := float(UiTokens.GAP_XS)
const CORNER_SLIDE := 480.0
const OBJECTIVE_WORDS := Objectives.MAX_WORDS
const TOAST_ICON := 26.0
const WORLD_CARD_BEAT := 1.2
const PRESENTATION_OWNED := ["synergy_discovered"]
const CARD_OWNED := ["run_started", "world_entered", "stage_entered", "stage_cleared", "launched", "boss_arena_entered"]
const NOTABLE := ["scrap_lost"]
const RETIRED_TOASTS := ["part_gained", "reward_chosen", "heft_class_changed", "heft_class_dropped"]
const ROW_COLOR := {"find_warden": "warden_engaged", "break_guard": "warden_engaged", "smash_core": "warden_engaged",
	"grow_return": "warden_engaged", "break_warden": "warden_engaged", "charge_beacon": "beacon_charge_changed",
	"find_activity": "activity_done", "roll_gate": "reward_offered", "hold_line": "launched", "break_brindle": "boss_arena_entered",
	"break_yard_crew": "pack_arrived", "break_clamp_crews": "pack_arrived",
	"ride_sheet": "warden_engaged", "line_fight": "warden_engaged",
	"shoot_magnets": "boss_arena_entered", "slam_caps": "boss_arena_entered", "bait_charge": "boss_arena_entered",
	"ram_scooter": "boss_arena_entered"}
const RING_ROWS := ["find_warden", "break_guard", "smash_core", "grow_return", "break_warden", "charge_beacon",
	"ride_sheet", "line_fight"]
const DONE_FACTS := {"arena_unlocked": "yard", "warden_gate_opened": "clamp"}
const NOTE_KEY := "hud:note"
const OPEN_ROWS := ["shoot_magnets", "slam_caps", "bait_charge"]
const PLATE_TOP := 6.0
const PLATE_GAP := float(UiTokens.GAP_M)
const TOAST_WIDTH := 800.0
const MARGIN := 18.0
const BOTTOM_GAP := float(UiTokens.GAP_L)
const WALLET_GAP := float(UiTokens.GAP_XS)
const HEALTH_BAR := 190.0
const HEALTH_WORD := "HEALTH"
const ARMOR_WORD := "ARMOUR"
const LOW_HEALTH := 0.25
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
var first_steps
var field_tips
var edge_markers
var part_name
var danger_mark
var launch_card
var _world_card_at := -1
var _title_world := 0
var _title_stage := 0
var _cursed := false
var why_callout
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
var _ach_detail: Label
var _cards := {}
var _card_count := 0
var _busy = null
var _quiet := false
var _quiet_hid: Array = []
var _take_tiers := {}
var _ach_word: Label
var _ach_icon: TextureRect
var _ach_entry := {}
var _lore_panel: PanelContainer
var _lore_left := 0.0
var _lore_due := false
var _lore_age := 0.0
var _corner_chip: Control
var _lower: Control
var _restart: Control
var _health: Control
var _speed: Control
var _plate: Control
var _plate_floor := Vector2.ZERO
var boss_plate: Control
var _plate_rogue := 0
var _engaged := false
var _struggle := Objectives.Struggle.new()
var _done := Objectives.Done.new()
var _detour_site = null
var _detour_ticked = null
var _detour_done := Objectives.Done.new()
var _site = null
const ARMOR_BAR := 120.0
const ARMOR_FLASH := 0.35
const ARMOR_PEAK_FLOOR := 100.0
class ConsumableSlot:
	extends Control

	const SLOT_SIZE := Vector2(56.0, 68.0)
	const DUAL_SIZE := Vector2(94.0, 68.0)
	const NEXT_W := 34.0
	const NEXT_GAP := 4.0
	const BORDER := 2.0
	const ICON_SIZE := 32.0
	const NEXT_ICON := 22.0
	const PIP_RADIUS := 3.5
	const PIP_GAP := 12.0
	const PIP_Y := 56.0
	const STRIPE_H := 5.0
	const CAP_H := 16.0

	var set_piece := false:
		set(value):
			if set_piece != value:
				set_piece = value
				modulate.a = NixieRail.SET_PIECE_ALPHA if value else 1.0

	var _held: Array[String] = []
	var _capacity := 1
	var _icon: Texture2D = null
	var _next_icon: Texture2D = null
	var _duplicator_left := 0.0
	var _overload_armed := false

	func _init() -> void:
		custom_minimum_size = SLOT_SIZE
		size = SLOT_SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func set_belt(held: Array, capacity: int) -> void:
		var next_cap := clampi(capacity, 1, 2)
		var next_held: Array[String] = []
		for item in held:
			var cid := String(item)
			if Consumables.is_valid(cid):
				next_held.append(cid)
		if next_held == _held and next_cap == _capacity:
			return
		_held = next_held
		_capacity = next_cap
		_icon = Icons.texture(Consumables.icon_of(_held[0])) if not _held.is_empty() else null
		_next_icon = Icons.texture(Consumables.icon_of(_held[1])) if _held.size() >= 2 else null
		_sync_size()

	func set_armed(duplicator_left: float, overload_armed: bool) -> void:
		var clamped := maxf(0.0, duplicator_left)
		if is_equal_approx(clamped, _duplicator_left) and overload_armed == _overload_armed:
			return
		_duplicator_left = clamped
		_overload_armed = overload_armed
		_sync_size()

	func _sync_size() -> void:
		var want := DUAL_SIZE if _held.size() >= 2 else SLOT_SIZE
		if size != want:
			custom_minimum_size = want
			size = want
		visible = showing()
		queue_redraw()

	func clear() -> void:
		_duplicator_left = 0.0
		_overload_armed = false
		set_belt([], 1)
		_sync_size()

	func showing() -> bool:
		return not _held.is_empty() or _duplicator_left > 0.0 or _overload_armed

	func held_ids() -> Array[String]:
		return _held.duplicate()

	func slot_capacity() -> int:
		return _capacity

	func armed_state() -> Dictionary:
		return {"duplicator_left": _duplicator_left, "overload_armed": _overload_armed}

	func piece_rect() -> Rect2:
		return Rect2(position, size) if showing() else Rect2()

	func place(right_bottom: Vector2) -> void:
		position = Vector2(right_bottom.x - size.x, right_bottom.y - size.y)

	func _draw() -> void:
		if not showing():
			return
		var steel := Palette.SLATE.darkened(0.45)
		var copper := Palette.COPPER
		var bone := NixieRail.BONE
		var main_w := SLOT_SIZE.x
		var main_rect := Rect2(Vector2.ZERO, Vector2(main_w, size.y))
		var accent: Color = Consumables.color_of(_held[0]) if not _held.is_empty() else (Palette.AMBER if _duplicator_left > 0.0 else Palette.COPPER)
		draw_rect(main_rect, Color(steel.r, steel.g, steel.b, 0.94), true)
		draw_rect(Rect2(BORDER, BORDER, main_w - BORDER * 2.0, STRIPE_H), accent, true)
		draw_rect(main_rect, Palette.AMBER if (_duplicator_left > 0.0 or _overload_armed) else copper, false, BORDER)
		if not _held.is_empty():
			if _icon != null:
				var icon_pos := Vector2((main_w - ICON_SIZE) * 0.5, STRIPE_H + 5.0)
				draw_texture_rect(_icon, Rect2(icon_pos, Vector2(ICON_SIZE, ICON_SIZE)), false, Color.WHITE)
			else:
				draw_circle(Vector2(main_w * 0.5, STRIPE_H + 21.0), 11.0, accent)
		elif _duplicator_left > 0.0 or _overload_armed:
			var armed_icon := Icons.texture("cons_duplicator_spool" if _duplicator_left > 0.0 else "cons_overload_fuse")
			var icon_pos := Vector2((main_w - ICON_SIZE) * 0.5, STRIPE_H + 5.0)
			draw_texture_rect(armed_icon, Rect2(icon_pos, Vector2(ICON_SIZE, ICON_SIZE)), false, accent)
		var cap_id := Glyphs.of_action("cl_consumable", "key_c")
		var cap_sz := Keycap.size_of(cap_id, CAP_H)
		Keycap.draw(self, Vector2(BORDER + cap_sz.x * 0.5 + 2.0, STRIPE_H + CAP_H * 0.5 + 3.0), cap_id, bone, CAP_H)
		if _duplicator_left > 0.0:
			var share := clampf(_duplicator_left / Consumables.DUPLICATOR_WINDOW_S, 0.0, 1.0)
			draw_rect(Rect2(BORDER + 2.0, size.y - 6.0, (main_w - BORDER * 2.0 - 4.0) * share, 3.0), Palette.AMBER, true)
		elif _overload_armed:
			draw_rect(Rect2(BORDER + 2.0, size.y - 6.0, main_w - BORDER * 2.0 - 4.0, 3.0), Palette.COPPER, true)
		var pips := maxi(_capacity, _held.size())
		var span := float(pips - 1) * PIP_GAP
		var start_x := (main_w - span) * 0.5
		for i in pips:
			var center := Vector2(start_x + float(i) * PIP_GAP, PIP_Y)
			if i < _held.size():
				var pip_col: Color = bone if i == 0 else Consumables.color_of(_held[i])
				draw_circle(center, PIP_RADIUS, pip_col)
			else:
				draw_circle(center, PIP_RADIUS, steel.darkened(0.35))
				draw_arc(center, PIP_RADIUS, 0.0, TAU, 16, copper, 1.5)
		if _held.size() >= 2:
			var nx := main_w + NEXT_GAP
			var next_rect := Rect2(Vector2(nx, 10.0), Vector2(NEXT_W, size.y - 10.0))
			var next_accent: Color = Consumables.color_of(_held[1])
			draw_rect(next_rect, Color(steel.r, steel.g, steel.b, 0.84), true)
			draw_rect(Rect2(nx + BORDER, 10.0 + BORDER, NEXT_W - BORDER * 2.0, STRIPE_H - 1.0), Color(next_accent, 0.85), true)
			draw_rect(next_rect, Color(copper, 0.75), false, BORDER)
			if _next_icon != null:
				var nip := Vector2(nx + (NEXT_W - NEXT_ICON) * 0.5, 10.0 + STRIPE_H + 8.0)
				draw_texture_rect(_next_icon, Rect2(nip, Vector2(NEXT_ICON, NEXT_ICON)), false, Color(1.0, 1.0, 1.0, 0.82))
			else:
				draw_circle(Vector2(nx + NEXT_W * 0.5, 10.0 + STRIPE_H + 19.0), 8.0, Color(next_accent, 0.82))


var _armor: Control
var _cogs: CogChip
var chain_counter: Control
var nixie_rail: Control
var consumable_slot: Control
var damage_numbers: Control
var pickup_lines: Control
var _armor_flash := 0.0
var _armor_peak := ARMOR_PEAK_FLOOR
var _companion: TextureRect
var _companion_state := "none"
var _companion_cues: Array[String] = []
var _companion_doc := {}
var _play_pieces: Array[Control] = []
var _quiet_pieces: Array[Control] = []
var _threat := 0
var _laid_out := Vector2.ZERO
var _laid_pieces: Array = []
var layout_runs := 0


func setup(game_ref) -> void:
	game = game_ref
	layer = 1
	add_to_group(PlayerFx.KEEP_GROUP)
	profile = UiProfile.new(game.storage_dir)

	edge_markers = EdgeMarkers.new()
	add_child(edge_markers)
	edge_markers.setup(game)
	key_glyphs = KeyGlyphs.new()
	add_child(key_glyphs)
	key_glyphs.setup(game, profile)
	first_steps = FirstSteps.new()
	add_child(first_steps)
	first_steps.setup(game, profile)
	field_tips = FieldTips.new()
	add_child(field_tips)
	field_tips.setup(game, profile, self)

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
	ability_bar.hidden_source = key_glyphs.shown_glyphs
	_speed = SpeedGlyph.new()
	add_child(_speed)
	_health = Gauge.new("res_health", HEALTH_BAR, true, HEALTH_WORD)
	add_child(_health)
	_armor = Gauge.new("res_mass", ARMOR_BAR, true, ARMOR_WORD)
	add_child(_armor)
	_armor.visible = false
	_cogs = CogChip.new()
	add_child(_cogs)
	chain_counter = ChainCounter.new()
	add_child(chain_counter)
	nixie_rail = NixieRail.new()
	add_child(nixie_rail)
	consumable_slot = ConsumableSlot.new()
	add_child(consumable_slot)
	damage_numbers = DamageNumbers.new()
	damage_numbers.project = _project_to_screen
	damage_numbers.keep_off = func() -> Dictionary:
		return {"ring": [reticle.rect(), _ball_rect()], "tags": edge_markers.tag_rects()}
	add_child(damage_numbers)
	pickup_lines = PickupLines.new()
	add_child(pickup_lines)
	var panel_fx = game.presentation.get("panel_fx") if game.get("presentation") != null else null
	if panel_fx != null:
		panel_fx.popped.connect(pickup_lines.show_line)
	if game.presentation != null and game.presentation.get("juice") != null:
		game.presentation.juice.number_sink = Callable(damage_numbers, "add")
	_companion = TextureRect.new()
	_companion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_companion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_companion.custom_minimum_size = Vector2(TOAST_ICON, TOAST_ICON)
	_companion.size = Vector2(TOAST_ICON, TOAST_ICON)
	_companion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_companion.visible = false
	add_child(_companion)
	game.run.armor_hit.connect(func(_removed: float, _spill: int, _source: String): _armor_flash = ARMOR_FLASH)

	reticle = AimReticle.new()
	add_child(reticle)
	reticle.setup(game.player, game.camera.cam)
	game.events.verb_failed.connect(_on_verb_failed)
	game.player.talk_claim = _talk_takes_interact
	why_callout = WhyCallout.new()
	add_child(why_callout)
	why_callout.setup(game, profile)
	part_name = PartName.new()
	add_child(part_name)
	danger_mark = DangerMark.new()
	add_child(danger_mark)
	_play_pieces.assign([_objective, _status, _toasts, ability_bar, _health, _speed, _cogs, reticle, key_glyphs, first_steps, edge_markers, why_callout, damage_numbers, pickup_lines])
	_quiet_pieces.assign([_toasts, why_callout, damage_numbers, part_name])

	_build_ach_toast()
	_build_lore_pulse()
	_busy = game.ctx.screen_busy
	game.codex.lore_found.connect(func(_id: String): _show_lore())
	game.events.achievement_earned.connect(func(id: String): _raise_card(Achievements.toast_text(id), false))
	var progress = game.get("progress")
	if progress != null:
		if progress.has_signal("work_order_changed"):
			progress.work_order_changed.connect(_on_work_order_changed)
		if progress.has_signal("story_chapter_punched"):
			progress.story_chapter_punched.connect(_on_story_chapter_punched)
	game.events.run_ended.connect(func(_won: bool): clear_achievement_toasts())
	game.opening.turned.connect(_on_turned)
	_connect_toasts(game.events)
	game.events.boss_phase_changed.connect(func(_phase: int, phase_name: String):
		toast_kind("boss_phase_changed", {"name": phase_name.capitalize()}))
	game.events.event_ended.connect(_on_event_ended)
	game.events.event_started.connect(_end_event_line)
	game.events.event_announced.connect(_on_event_announced)
	game.events.part_gained.connect(func(part_id: String, _source: String): part_name.show_part(part_id))
	game.events.warden_engaged.connect(func(_stage: int): _begin_engagement(true))
	game.events.boss_arena_entered.connect(_seat_boss_plate)
	game.events.beacon_unsealed.connect(func(_stage: int): _begin_engagement(false))
	game.events.activity_done.connect(func(id: String, _at: Vector3): _done.note(Objectives.done_words(id, game.world.activities.called(id))))
	game.events.activity_done.connect(func(id: String, _at: Vector3): _note_detour(id, true))
	game.events.trade_taken.connect(func(kind: String, _at: Vector3): _done.note(Objectives.done_words(kind)))
	game.events.event_ended.connect(func(id: String, outcome: String):
		if outcome == "lost":
			_done.note(Objectives.lost_words(id), false)
			_note_detour(id, false))
	game.events.beacon_unsealed.connect(func(_stage: int): _done.note(Objectives.done_words("warden")))
	game.events.world_fact.connect(func(kind: String, _at: Vector3):
		if DONE_FACTS.has(kind) and (kind != "warden_gate_opened" or _engaged):
			_done.note(Objectives.done_words(DONE_FACTS[kind]), true, true))
	game.events.posture_changed.connect(_on_posture)
	game.events.launched.connect(_on_launched)
	game.events.world_entered.connect(_on_world_entered)
	game.events.stage_entered.connect(_on_stage_entered)
	game.events.threat_rose.connect(func(tier: int): _threat = maxi(_threat, tier))
	game.events.boss_arena_entered.connect(func():
		var presentation = game.get("presentation")
		if presentation == null or not presentation.names_boss():
			var row: Dictionary = game.flow.boss_row(game.ctx.stages.world_of(game.run.stage))
			var title := String(row.get("name", EventKinds.hud("boss_arena_entered")))
			var icon := String(row.get("card_icon", "fac_fleet"))
			var tint: Color = EventKinds.color("boss_arena_entered") if bool(row.get("card_event_tint", true)) else Palette.ANCIENT
			launch_card.show_card(icon, title, tint))
	game.events.run_started.connect(func(_class_id: String):
		_title_world = 0
		_title_stage = 0
		_threat = 0
		_begin_engagement(false)
		_armor_peak = ARMOR_PEAK_FLOOR
		_health.clear()
		_armor.clear())
	layout(_screen_size())


func _build_ach_toast() -> void:
	var layer_node := CanvasLayer.new()
	layer_node.layer = ACH_LAYER
	add_child(layer_node)
	_ach_panel = PanelContainer.new()
	_ach_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ach_panel.visible = false
	var plate := UiTokens.plate(UiTokens.ACCENT)
	plate.content_margin_top = UiTokens.GAP_XS
	plate.content_margin_bottom = UiTokens.GAP_XS
	_ach_panel.add_theme_stylebox_override("panel", plate)
	layer_node.add_child(_ach_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ach_panel.add_child(row)
	var star := TextureRect.new()
	star.texture = Icons.shape("star")
	star.modulate = UiTokens.ACCENT
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.custom_minimum_size = Vector2(TOAST_ICON, TOAST_ICON)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(star)
	_ach_icon = star
	var word := _label(UiTokens.BODY)
	word.add_theme_color_override("font_color", UiTokens.ACCENT)
	word.visible = false
	row.add_child(word)
	_ach_word = word
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -3)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	_ach_name = _label(ACH_FONT)
	_ach_name.add_theme_color_override("font_color", UiTokens.TEXT)
	words.add_child(_ach_name)
	_ach_detail = _label(ACH_DETAIL_FONT)
	_ach_detail.add_theme_color_override("font_color", UiTokens.quiet())
	words.add_child(_ach_detail)


func _build_lore_pulse() -> void:
	var layer_node := CanvasLayer.new()
	layer_node.layer = ACH_LAYER
	add_child(layer_node)
	_lore_panel = PanelContainer.new()
	_lore_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lore_panel.visible = false
	var plate := UiTokens.plate(UiTokens.TEXT)
	plate.content_margin_left = UiTokens.GAP_M
	plate.content_margin_top = UiTokens.GAP_XS
	plate.content_margin_bottom = UiTokens.GAP_XS
	_lore_panel.add_theme_stylebox_override("panel", plate)
	layer_node.add_child(_lore_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lore_panel.add_child(row)
	row.add_child(NoteKey.new())


func _show_lore() -> void:
	_lore_due = true
	_busy.request(NOTE_KEY)
	_step_lore(0.0)


func _reading() -> bool:
	var presentation = game.get("presentation")
	return presentation != null and presentation.reading()


func lore_pulse_visible() -> bool:
	return _lore_panel != null and _lore_panel.visible


func _step_lore(delta: float) -> void:
	if _lore_due and not _reading() and _busy.may_show(NOTE_KEY):
		_lore_due = false
		_lore_left = LORE_TOTAL
		_lore_age = 0.0
		_lore_panel.visible = true
	if _lore_left <= 0.0:
		return
	_lore_left -= delta
	_lore_age += delta
	_lore_panel.modulate.a = clampf(minf(_lore_age / TOAST_IN, _lore_left / TOAST_OUT), 0.0, 1.0)
	var want := _corner_under(_ach_panel, _corner_under(_corner_chip, LORE_TOP))
	var y := want if _lore_age <= delta else move_toward(_lore_panel.position.y, want, delta * CORNER_SLIDE)
	_lore_panel.position = Vector2(_screen_size().x - _lore_panel.size.x - MARGIN, y)
	if _lore_left <= 0.0:
		_lore_panel.visible = false
		_free_slot(NOTE_KEY)


func mount_corner(chip: Control) -> void:
	chip.process_priority = process_priority - 1
	add_child(chip)
	_corner_chip = chip


func _corner_swollen() -> bool:
	return _corner_chip != null and _corner_chip.visible and _corner_chip.has_method("swollen") and _corner_chip.swollen()


func _corner_under(above: Control, top: float) -> float:
	if above == null or not above.visible:
		return top
	return above.position.y + above.size.y + CORNER_GAP


func corner_rects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for piece in [["chip", _corner_chip], ["plate", _ach_panel], ["pill", _lore_panel]]:
		var control: Control = piece[1]
		if control != null and control.visible:
			out.append({"name": piece[0], "rect": Rect2(control.position, control.size)})
	return out


func ach_toasts() -> Array[String]:
	var out: Array[String] = []
	if not _ach_entry.is_empty():
		out.append(_ach_entry["text"])
	return out


func ach_waiting() -> Array[String]:
	return _waiting_texts(false)


func _on_work_order_changed(order_id: String, phase: String, summary: Dictionary) -> void:
	if phase != "completed":
		return
	var row: Dictionary = WorkOrders.order(order_id)
	var title := String(row.get("name", order_id))
	var sub := "Order stamped"
	var new_tiers = summary.get("new_license_tiers", [])
	if new_tiers is Array and not (new_tiers as Array).is_empty():
		sub = WorkOrders.license_tier_name(int((new_tiers as Array)[-1]))
	_raise_card("%s\n%s" % [title, sub], false)


func _on_story_chapter_punched(cast_id: String, num: int, ch_id: String) -> void:
	var title := ""
	for row in PilotStory.CHAPTERS:
		if String(row.get("id", "")) == ch_id:
			title = String(row.get("title", ""))
			break
	if title == "":
		title = "%s chapter %d" % [cast_id.capitalize(), num]
	_raise_card("%s\nChapter %d punched" % [title, num], false)


func tune_found(tune_name: String) -> void:
	_raise_card("%s\nOn Moss's jukebox at camp" % tune_name, true)


func tune_waiting() -> Array[String]:
	return _waiting_texts(true)


func _waiting_texts(tune: bool) -> Array[String]:
	var out: Array[String] = []
	for key in _busy.waiting():
		if _cards.has(key) and _cards[key]["tune"] == tune:
			out.append(_cards[key]["text"])
	return out


func _head_card() -> String:
	for key in _busy.waiting():
		if _cards.has(key):
			return key
	return ""


func _raise_card(text: String, tune: bool) -> void:
	_card_count += 1
	var key := "hud:%d" % _card_count
	_cards[key] = {"tune": tune, "text": text}
	_busy.request(key)


func _free_slot(key: String) -> void:
	_busy.done(key)


func take_found(take_name: String, station_name: String, tier := "take") -> void:
	var text := "%s\nOn the radio at %s" % [take_name, station_name]
	_take_tiers[text] = tier
	_raise_card(text, true)


static func card_mark(tune: bool, tier := "") -> Dictionary:
	if not tune:
		return ACHIEVEMENT_MARK
	if tier == "":
		return RECORD_MARK
	return TAKE_MARKS.get(tier, TAKE_MARKS["take"])


func clear_achievement_toasts() -> void:
	for key in _cards:
		_free_slot(key)
	_cards.clear()
	if not _ach_entry.is_empty():
		_free_slot(_ach_entry["key"])
	_ach_entry = {}
	_ach_panel.visible = false
	_lore_due = false
	_lore_left = 0.0
	_lore_panel.visible = false
	_free_slot(NOTE_KEY)


func clear_toasts() -> void:
	_toast = {}
	_held_toast = {}
	_toast_row.visible = false


func _step_ach(delta: float) -> void:
	if game.screens != null and game.screens.ending_open():
		clear_achievement_toasts()
		return
	var head := _head_card()
	if head != "" and not _ach_entry.is_empty():
		_busy.ready(head)
	if _ach_entry.is_empty() and head != "" and not _corner_swollen() and not game.opening.waits("plate") and not _reading() \
			and _busy.may_show(head):
		var card: Dictionary = _cards[head]
		_cards.erase(head)
		var tune: bool = card["tune"]
		_ach_entry = {"text": card["text"], "key": head, "left": ACH_TOTAL, "age": 0.0}
		var lines := String(_ach_entry["text"]).split("\n", true, 1)
		_ach_name.text = lines[0]
		_ach_detail.text = lines[1] if lines.size() > 1 else ""
		_ach_detail.visible = _ach_detail.text != ""
		var mark := card_mark(tune, String(_take_tiers.get(_ach_entry["text"], "")))
		_ach_word.text = String(mark["word"])
		_ach_word.visible = _ach_word.text != ""
		_ach_icon.texture = Icons.texture(String(mark["id"])) if mark.has("id") else Icons.shape(String(mark["shape"]))
		_ach_icon.modulate = mark["tint"]
		_ach_panel.reset_size()
		_ach_panel.visible = true
	if _ach_entry.is_empty():
		return
	_ach_entry["left"] -= delta
	_ach_entry["age"] += delta
	_ach_panel.modulate.a = clampf(minf(_ach_entry["age"] / TOAST_IN, _ach_entry["left"] / TOAST_OUT), 0.0, 1.0)
	_ach_panel.position = Vector2(_screen_size().x - _ach_panel.size.x - MARGIN, _corner_under(_corner_chip, ACH_TOP))
	if _ach_entry["left"] <= 0.0:
		_free_slot(_ach_entry["key"])
		_ach_entry = {}
		_ach_panel.visible = false


static func toast_kinds() -> Array[String]:
	var out: Array[String] = []
	for kind in EventKinds.ROWS:
		if EventKinds.row(kind).get("hud", "") == "" or kind in CARD_OWNED or kind in PRESENTATION_OWNED or kind in RETIRED_TOASTS:
			continue
		if EventKinds.priority(kind) > EventKinds.TOAST_PRIORITY or kind in NOTABLE or kind == "event_ended":
			out.append(kind)
	return out


static func toast_text(kind: String, fields := {}) -> String:
	return EventKinds.hud(kind, fields)


func _connect_toasts(events) -> void:
	for kind in toast_kinds():
		if kind in ["boss_phase_changed", "event_ended", "event_announced"]:
			continue
		if kind == "core_gained":
			events.connect(kind, _on_core_gained)
			continue
		var argc: int = SignalWire.arg_count(events, kind)
		if FIELD_ARGS.has(kind):
			events.connect(kind, _drop_args(_on_field_fact.bind(kind), argc - 1))
		else:
			events.connect(kind, _drop_args(_on_fact.bind(kind), argc))


static func _drop_args(callable: Callable, count: int) -> Callable:
	return callable.unbind(count) if count > 0 else callable


func _on_field_fact(value, kind: String, hold := -1.0, tint := Color(0, 0, 0, 0)) -> void:
	var shown = value
	if value is String:
		shown = (value as String).replace("_", " ").capitalize()
	toast_kind(kind, {FIELD_ARGS[kind]: shown}, hold, tint)


func _on_fact(kind: String) -> void:
	toast_kind(kind)


func _on_core_gained(_source: String, _at: Vector3, count: int) -> void:
	toast(core_words(count), EventKinds.color("core_gained"), EventKinds.row("core_gained").get("shape", "none"), mini(EventKinds.priority("core_gained"), 3))


static func core_words(count: int) -> String:
	return CORE_WORDS[clampi(count, 0, CORE_WORDS.size() - 1)]


func _begin_engagement(engaged: bool) -> void:
	_engaged = engaged
	_struggle.begin()
	_seat_boss_plate()


func _seat_boss_plate() -> void:
	var warden = game.flow.warden if _engaged else _brindle_hull()
	var posture: bool = is_instance_valid(warden) and warden.has_method("fight") and warden.fight() == "posture"
	var body = warden if posture else _live_rogue()
	_plate_rogue = 0 if posture or body == null else body.get_instance_id()
	if body != null:
		if boss_plate == null:
			boss_plate = BossPlate.new()
		boss_plate.bind(body, _arena_phases() if posture and not _engaged else null)
		mount_plate(boss_plate)
	elif boss_plate != null:
		if _plate == boss_plate:
			unmount_plate()
		boss_plate.unbind()
		boss_plate.queue_free()
		boss_plate = null


func _live_rogue():
	var rogue = game.world.rogue if game.world != null else null
	return rogue if is_instance_valid(rogue) and not rogue.is_dead() else null


func _follow_rogue() -> void:
	if boss_plate != null and _plate_rogue == 0:
		return
	var rogue = _live_rogue()
	if (rogue.get_instance_id() if rogue != null else 0) != _plate_rogue:
		_seat_boss_plate()


func _brindle_hull():
	var boss = game.ctx.boss
	if boss == null or not boss.has_method("active") or not boss.active():
		return null
	if is_instance_valid(boss.get("ship")):
		return boss.ship.hull
	var stub_warden = boss.get("warden")
	return stub_warden if is_instance_valid(stub_warden) else null


func _arena_phases():
	var boss = game.ctx.boss
	var phases = boss.get("_phases") if boss != null else null
	return phases if phases is FightPhases else null


func _exit_tree() -> void:
	if boss_plate != null and boss_plate.get_parent() == null:
		boss_plate.free()
		boss_plate = null


func _on_posture(enemy: Node3D, posture: float, staggered: bool) -> void:
	if enemy == game.flow.warden:
		_struggle.note_posture(posture, staggered)


func _on_event_announced(event_id: String, seconds_until: float, _at: Vector3) -> void:
	if seconds_until > 0.0:
		var called: String = game.world.activities.called(event_id)
		var life := minf(seconds_until, EVENT_LINE_CAP)
		_on_field_fact(called if called != "" else event_id, "event_announced", maxf(life - TOAST_IN - TOAST_OUT, 0.0), Palette.SLATE_INK)
		var line := _held_toast if launch_card.showing() else _toast
		if not line.is_empty():
			line["event"] = event_id


func _end_event_line(event_id: String) -> void:
	if event_id == "":
		return
	for entry in [_toast, _held_toast]:
		if entry.has("event") and entry["event"] == event_id:
			entry["left"] = minf(entry["left"], TOAST_OUT)
			entry["event"] = ""


func _on_event_ended(event_id: String, outcome: String) -> void:
	_end_event_line(event_id)
	if outcome == "lost":
		var called: String = game.world.activities.called(event_id)
		toast(toast_text("event_ended", {"event": called if called != "" else event_id.replace("_", " ").capitalize()}), Palette.RUST, "wave", 2)


func toast_kind(kind: String, fields := {}, hold := -1.0, tint := Color(0, 0, 0, 0)) -> void:
	var shape: String = EventKinds.row(kind).get("shape", "none")
	if tint.a > 0.0:
		toast(toast_text(kind, fields), tint, shape, mini(EventKinds.priority(kind), 3), hold)
		return
	toast(toast_text(kind, fields), EventKinds.color(kind), shape, mini(EventKinds.priority(kind), 3), hold)


func toast(text: String, color := Palette.SAND, shape := "diamond", priority := 3, hold_s := -1.0) -> void:
	if text == "":
		return
	var hold: float = hold_s if hold_s >= 0.0 else TOAST_HOLD.get(priority, TOAST_HOLD[2])
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


static func companion_state_of(doc: Dictionary) -> String:
	if doc.is_empty():
		return "none"
	var model := Companion.new()
	if not model.from_dict(doc) or not model.has_family(Companion.ESCAPE_CORRIDOR):
		return "none"
	return "ready" if model.escape_ready() else "spent"


func companion_cues() -> Array[String]:
	return _companion_cues.duplicate()


func companion_state() -> String:
	return _companion_state


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


func _on_world_entered(world: int) -> void:
	if game.opening.waits("title"):
		_title_world = world
		return
	if game.ctx.stages.worlds().size() <= 1:
		return
	var row := Worlds.row(world)
	if row.is_empty():
		return
	launch_card.show_card("obj_beacon", String(row["name"]), EventKinds.color("stage_entered"), StageModifier.card_line(game.run, game.ctx.terrain, game.run.stage, game.ctx.profile))
	_world_card_at = Time.get_ticks_msec()


func _on_stage_entered(stage: int, retry: bool) -> void:
	_threat = 0
	_begin_engagement(false)
	_done.clear()
	_detour_done.clear()
	_detour_site = null
	_detour_ticked = null
	_site = null
	if retry:
		return
	if game.opening.waits("title"):
		_title_stage = stage
		return
	_title_for(stage)


func _on_turned(voice: String) -> void:
	if voice != "title":
		return
	var world := _title_world
	var stage := _title_stage
	_title_world = 0
	_title_stage = 0
	if game.run == null or stage != game.run.stage or not game.flow.in_stage():
		return
	if world > 0:
		_on_world_entered(world)
	_title_for(stage)


func _title_for(stage: int) -> void:
	if _world_card_at >= 0:
		_world_card_at = -1
		var run_id := String(game.run.run_id)
		get_tree().create_timer(WORLD_CARD_BEAT).timeout.connect(func():
			if game != null and game.run != null and game.run.stage == stage and String(game.run.run_id) == run_id:
				_card_for_stage(stage))
	elif launch_card.showing():
		launch_card.extend()
	else:
		_card_for_stage(stage)


func _step_curse() -> void:
	var now: bool = game.run != null and game.run.cursed()
	if now and not _cursed:
		launch_card.show_card("obj_beacon", StageModifier.CURSE.word, EventKinds.color("stage_entered"), StageModifier.CURSE.line)
		if game.player != null:
			StageModifier.announce(game.player.shown_position())
	_cursed = now


func _card_for_stage(stage: int) -> void:
	var modifier := StageModifier.for_stage(game.run, game.ctx.terrain, stage)
	launch_card.show_card("obj_beacon", game.ctx.stages.of(stage)["name"], EventKinds.color("stage_entered"), StageModifier.card_line(game.run, game.ctx.terrain, stage, game.ctx.profile))
	if not modifier.is_empty() and game.player != null:
		StageModifier.announce(game.player.shown_position())


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


func _project_to_screen(at: Vector3) -> Variant:
	var cam: Camera3D = game.camera.cam
	if cam.is_position_behind(at):
		return null
	return cam.unproject_position(at)


func layout(size: Vector2) -> void:
	_laid_out = size
	damage_numbers.size = size
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
	var ring := AimReticle.meter_radius() + AimReticle.METER_WIDTH
	part_name.avoid = Rect2(size * 0.5 - Vector2.ONE * ring, Vector2.ONE * ring * 2.0)
	danger_mark.position = Vector2.ZERO
	danger_mark.size = size
	danger_mark.avoid = part_name.avoid
	_status.position = Vector2(MARGIN, top.position.y + 12.0)

	var toast_width := minf(TOAST_WIDTH, size.x - 2.0 * MARGIN)
	_toasts.position = Vector2((size.x - toast_width) * 0.5, toasts.position.y + 2.0)
	_toasts.custom_minimum_size = Vector2(toast_width, 0.0)
	_toasts.size = Vector2(toast_width, 0.0)

	var bar_size: Vector2 = ability_bar.bar_size(maxi(ability_bar.slots.size(), AbilityBar.NUMBERED + 2))
	var bar_y := bottom.position.y + (bottom.size.y - bar_size.y) * 0.5
	ability_bar.position = Vector2((size.x - bar_size.x) * 0.5, bar_y)
	var slot_mid := bar_y + AbilityBar.SLOT * 0.5
	_health.position = Vector2(ability_bar.position.x - BOTTOM_GAP - _health.size.x, slot_mid - _health.bar_mid())
	_armor.position = Vector2(_health.position.x - BOTTOM_GAP - _armor.size.x, slot_mid - _armor.bar_mid())
	_companion.position = Vector2(_armor.position.x - BOTTOM_GAP - _companion.size.x, slot_mid - _companion.size.y * 0.5)
	_speed.position = Vector2(MARGIN, slot_mid - _speed.size.y * 0.5)
	_cogs.position = Vector2(_speed.position.x + _speed.size.x + BOTTOM_GAP, slot_mid - _cogs.size.y * 0.5)
	var gauges_from := _health.position.x
	for gauge in [_armor, _companion]:
		if gauge.visible:
			gauges_from = gauge.position.x
	if _cogs.position.x + _cogs.size.x + BOTTOM_GAP > gauges_from:
		var pair := _speed.size.y + WALLET_GAP + _cogs.size.y
		_speed.position.y = slot_mid - pair * 0.5
		_cogs.position = Vector2(MARGIN, _speed.position.y + _speed.size.y + WALLET_GAP)
	pickup_lines.layout(size, PanelFx.POP_ROWS)
	chain_counter.position = Vector2(ability_bar.position.x + bar_size.x + BOTTOM_GAP, slot_mid - chain_counter.size.y * 0.5)
	nixie_rail.place(Vector2(size.x - MARGIN, bottom.end.y - NixieRail.FLOOR))
	var cons_right: float = (nixie_rail.piece_rect().position.x - BOTTOM_GAP) if nixie_rail.showing() else (size.x - MARGIN)
	consumable_slot.place(Vector2(cons_right, bottom.end.y - NixieRail.FLOOR))


func _piece_sizes() -> Array:
	return [_objective.custom_minimum_size, _health.size, _armor.size, maxi(ability_bar.slots.size(), AbilityBar.NUMBERED + 2), _plate_size(),
		_cogs.size, _armor.visible, _companion.visible, consumable_slot.showing(), consumable_slot.piece_rect().size.x, nixie_rail.showing(), nixie_rail.piece_rect().size.x]


func mount_plate(plate: Control) -> void:
	if plate != _plate:
		unmount_plate()
		_plate = plate
		if plate.get_parent() != null:
			plate.get_parent().remove_child(plate)
		add_child(plate)
	_plate_floor = plate.size
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


func piece_rects() -> Dictionary:
	return {
		"top": [_rect_of(_objective), _rect_of(_status)] + ([_rect_of(_plate)] if _plate != null else []),
		"toasts": [_rect_of(_toasts)],
		"bottom": [_rect_of(ability_bar), _rect_of(_health), _rect_of(_speed), _rect_of(_cogs), _rect_of(chain_counter)]
			+ ([_rect_of(_armor)] if _armor.visible else [])
			+ ([_rect_of(_companion)] if _companion.visible else [])
			+ ([nixie_rail.piece_rect()] if nixie_rail.showing() else [])
			+ ([consumable_slot.piece_rect()] if consumable_slot.showing() else []),
	}


func buff_rows() -> Array:
	var ctx = game.get("ctx")
	var buffs = ctx.get("buffs") if ctx != null else null
	if buffs == null or not buffs.has_method("active_rows"):
		return []
	return buffs.active_rows(NixieRail.MAX_TUBES)


func wallet_cogs() -> int:
	return _cogs.amount


static func row_color(id: String) -> Color:
	if id == "charge_beacon":
		return EventKinds.state_color("beacon_open")
	if id in ["break_yard_crew", "break_clamp_crews"]:
		return EventKinds.state_color("glancing")
	return EventKinds.color(ROW_COLOR[id])


func _step_companion(playing: bool) -> void:
	var doc: Dictionary = game.run.companion
	if doc.is_empty() and _companion_state == "none":
		_companion.visible = false
		return
	var state := _companion_state
	if doc != _companion_doc:
		_companion_doc = doc.duplicate(true)
		state = companion_state_of(doc)
	if state != _companion_state:
		if state != "none" and _companion_state != "none":
			var kind := "companion_" + state
			_companion_cues.append(kind)
			var audio = game.audio()
			if audio != null and audio.has_method("play"):
				audio.play(kind, 0.0, 1.0, "UI")
		_companion_state = state
		if state != "none":
			var row: Dictionary = EventKinds.UI_ROWS["companion_" + state]
			_companion.texture = Icons.shape(String(row["shape"]))
			_companion.modulate = row["color"]
	_companion.visible = playing and state != "none"


static func _rect_of(control: Control) -> Rect2:
	var s := control.get_combined_minimum_size()
	return Rect2(control.position, Vector2(maxf(s.x, control.size.x), maxf(s.y, control.size.y)))


func hull_shown() -> float:
	return _health.fraction


func hull_cap_shown() -> float:
	return _health.cap


func _ball_readouts() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for rect in prompt_rects.values():
		out.append(rect)
	var ball := _ball_rect()
	if not ball.has_area():
		return out
	out.append(ball)
	for rect in [part_name.rect(), danger_mark.rect()]:
		if rect.has_area():
			out.append(rect)
	return out


func keep_clear_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [reticle.rect(), _ball_rect()]
	out.append_array(edge_markers.drawn_rects())
	for rect in prompt_rects.values():
		out.append(rect)
	out.append(part_name.rect())
	out.append(danger_mark.rect())
	return out


func _ball_rect() -> Rect2:
	var cam: Camera3D = game.camera.cam
	var at: Vector3 = game.player.shown_position()
	if cam == null or cam.is_position_behind(at):
		return Rect2()
	var centre := cam.unproject_position(at)
	var half := centre.distance_to(cam.unproject_position(at + cam.global_basis.x * Tuning.RADIUS))
	return Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0)


func objective_reading() -> Dictionary:
	var flow = game.flow
	var warden = flow.warden if is_instance_valid(flow.warden) else null
	var distance: float = game.player.shown_position().distance_to(warden.global_position) if warden != null else INF
	var gate = flow.gate
	var activities = game.world.activities if game.world != null else null
	var site = _site if is_instance_valid(_site) and not _site.done and not _site.failed else null
	var reading := {
		"state": flow.state_name(),
		"sealed": flow.sealed,
		"engaged": _engaged,
		"fight": warden.fight() if warden != null and warden.has_method("fight") else "plating",
		"staggered": warden != null and warden.has_method("staggered") and warden.staggered(),
		"struggling": _struggle.struggling,
		"distance": distance,
		"card": launch_card.showing(),
		"site_at_hand": site != null,
		"yard_locked": gate != null and gate.lock_active(),
		"clamp_shut": gate != null and gate.locked(),
	}
	var driver = warden.get("mount_driver") if warden != null else null
	if driver != null and driver.has_method("plate_reading"):
		reading.merge(driver.plate_reading(warden), true)
	var asked: Array = []
	if driver != null and driver.has_method("plate_targets"):
		asked.append_array(driver.plate_targets(warden))
	var boss = game.ctx.boss
	if is_instance_valid(boss) and boss.has_method("plate_reading"):
		reading.merge(boss.plate_reading(), true)
		asked.append_array(boss.plate_targets())
	var id := Objectives.choose(reading)
	if id == "":
		return {"id": "", "icon": "", "words": "", "color": Palette.SAND, "progress": -1.0, "distance": -1, "step": 0}
	var words := Objectives.words(id)
	var icon := Objectives.glyph(id)
	var color := row_color(id)
	if id == "find_activity":
		words = Objectives.activity_words(String(site.id), activities.called(String(site.id)))
	elif id in OPEN_ROWS and reading.get("open", false):
		icon = Objectives.COCKPIT_GLYPH
	elif id == "break_brindle":
		var boss_row: Dictionary = flow.boss_row(game.ctx.stages.world_of(game.run.stage))
		if boss_row.has("obj_closed"):
			var boss_body = _brindle_hull()
			var boss_open: bool = is_instance_valid(boss_body) and boss_body.has_method("staggered") and boss_body.staggered()
			words = String(boss_row["obj_open"]) if boss_open else String(boss_row["obj_closed"])
			icon = "cat_damage" if boss_open else "obj_warden"
			color = EventKinds.state_color("open") if boss_open else Palette.ANCIENT
	return {"id": id, "icon": icon, "words": words, "color": color,
		"progress": _clamp_fraction(gate) if id == "break_clamp_crews" else gate.yard_fraction() if id == "break_yard_crew" \
			else game.beacon.fraction() if id in RING_ROWS else -1.0,
		"distance": int(distance) if id == "find_warden" and distance < INF else -1,
		"step": Objectives.live_step(id, String(asked[0]["what"]) if not asked.is_empty() else "")}


func detour_reading(goal: Dictionary) -> Dictionary:
	if game.world == null:
		return {}
	var goal_id := String(goal.get("id", ""))
	var held_run: bool = is_instance_valid(_detour_site) and _detour_site == _site
	if (held_run or _detour_done.showing()) and goal_id in ["find_warden", "find_activity"]:
		return _held_detour(held_run)
	if not Objectives.detour_shown(goal_id):
		return {}
	var ball: Vector3 = game.player.shown_position()
	var rescue = game.world.get("rescue")
	if rescue != null:
		for waiting in rescue.waiting():
			var cage = rescue.cage(String(waiting["quest"]))
			return {"what": "cage", "icon": Interactables.row("ally")["icon"], "color": Interactables.color("ally"),
				"words": Objectives.cage_words(cage.terms() if cage != null else ""),
				"distance": int(ball.distance_to(waiting["at"]))}
	var warden = game.flow.warden if is_instance_valid(game.flow.warden) else null
	var best = null
	var best_m := INF
	for site in edge_markers.unfinished_sites():
		if site.started or site.failed:
			continue
		if warden != null and not _ahead_of(ball, site.global_position, warden.global_position):
			continue
		var m := ball.distance_to(site.global_position)
		if m < best_m:
			best = site
			best_m = m
	if is_instance_valid(_detour_site) and _detour_site.started and not _detour_site.done and not _detour_site.failed \
			and _detour_site.rule.finishes != "trade":
		var to_kept: Vector3 = _detour_site.global_position - ball
		if _detour_site.surge_live or Vector2(to_kept.x, to_kept.z).length() <= game.world.activities.LET_GO_M:
			return _site_row(_detour_site, int(to_kept.length()))
	_detour_site = best
	if best == null:
		return {}
	return _site_row(best, int(best_m))


static func _ahead_of(ball: Vector3, point: Vector3, goal: Vector3) -> bool:
	var to_point := Vector2(point.x - ball.x, point.z - ball.z)
	var to_goal := Vector2(goal.x - ball.x, goal.z - ball.z)
	return to_point.dot(to_goal) > 0.0


func _site_row(site, metres: int, words := "") -> Dictionary:
	var kind := String(site.id)
	return {"what": kind, "icon": Objectives.glyph("find_activity"),
		"color": EdgeMarkers.marker_color({"activity": String(site.rule.get("cue", {}).get("view", kind))}),
		"words": words if words != "" else Objectives.activity_words(kind, game.world.activities.called(kind)), "distance": metres}


func _held_detour(running: bool) -> Dictionary:
	if running or (_done.showing() and _done.words == _detour_done.words):
		return {}
	var row := _site_row(_detour_site, -1, _detour_done.words) if is_instance_valid(_detour_site) else {"what": "", "icon": "", "words": _detour_done.words, "color": Color.WHITE, "distance": -1}
	row["color"] = EventKinds.color("activity_done") if _detour_done.won else Palette.RUST
	row["done"] = "won" if _detour_done.won else "lost"
	return row


func _note_detour(id: String, good: bool) -> void:
	if not Objectives.detour_site_matches(_detour_site, id, good, _detour_ticked):
		return
	if good:
		_detour_ticked = _detour_site
	var text := Objectives.done_words(id, game.world.activities.called(id)) if good else Objectives.lost_words(id)
	_detour_done.note(text, good)


func plate_shown(reading := {}) -> Dictionary:
	if reading.is_empty():
		reading = objective_reading()
	if not _done.showing() or reading["id"] == "":
		return reading
	return {"id": reading["id"], "icon": "", "words": _done.words, "color": EventKinds.color("activity_done") if _done.won else Palette.RUST,
		"progress": -1.0, "distance": -1, "step": 0, "done": "won" if _done.won else "lost"}


static func _clamp_fraction(gate) -> float:
	return clampf(float(gate.cleared) / float(gate.packs_wanted()), 0.0, 1.0) if gate.packs_wanted() > 0 else 0.0


func place_prompts(size: Vector2, playing: bool) -> void:
	prompt_rects.clear()
	var cam: Camera3D = game.camera.cam
	var ball: Vector3 = game.player.shown_position()
	var near: Array = []
	for prompt in get_tree().get_nodes_in_group(ScreenRegions.PROMPT_GROUP):
		if prompt.owner_placed:
			continue
		prompt.visible = false
		if not playing or prompt.is_empty():
			continue
		var at: Vector3 = prompt.anchor_point()
		if at == Vector3.INF or cam.is_position_behind(at):
			continue
		var d: float = cam.global_position.distance_to(at)
		if d <= prompt.reach:
			near.append([d, prompt, at])
	if near.size() > 1:
		near.sort_custom(func(a, b): return a[0] < b[0])
	var taken: Array[Rect2] = []
	if pickup_lines.rect().has_area():
		taken.append(pickup_lines.rect())
	var band_placed := 0
	for entry in near:
		if band_placed >= ScreenRegions.MAX_PROMPTS:
			break
		var prompt: Label = entry[1]
		prompt.near = ball.distance_to(entry[2]) <= prompt.detail_range
		var spot := prompt_spot(prompt, cam.unproject_position(entry[2]), size, taken)
		if spot.size == Vector2.ZERO:
			continue
		prompt.position = spot.position
		prompt.size = spot.size
		prompt.visible = true
		band_placed += 1
		taken.append(spot)
		prompt_rects[prompt] = spot


static func prompt_spot(prompt, at: Vector2, size: Vector2, taken: Array[Rect2]) -> Rect2:
	var room := ScreenRegions.rect("prompts", size)
	var spot := free_spot(_wanted(prompt, at, size), taken, room)
	if spot.size == Vector2.ZERO and prompt.near:
		prompt.near = false
		spot = free_spot(_wanted(prompt, at, size), taken, room)
	return spot


static func _wanted(prompt, at: Vector2, size: Vector2) -> Rect2:
	var extent: Vector2 = prompt.shown_extent()
	return Rect2(ScreenRegions.clamp_prompt(at, extent, size), extent)


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
	_step_curse()
	damage_numbers.step(delta)
	pickup_lines.step(delta)
	_step_ach(delta)
	_step_lore(delta)
	_follow_rogue()

	var flow = game.flow
	var playing: bool = flow.in_play()
	place_prompts(size, playing)
	for piece in _play_pieces:
		piece.visible = playing
	if _plate != null:
		_plate.visible = playing
	part_name.visible = playing and part_name.left > 0.0
	if _quiet:
		for piece in _quiet_pieces:
			piece.visible = false
	danger_mark.show_run(game.combat.near_miss.standing_in() if playing else -1.0)
	if playing:
		danger_mark.aim(game.camera.cam, game.player.shown_position(), game.combat.near_miss.escape())
	else:
		danger_mark.aim(null, Vector3.ZERO, {})
	danger_mark.visible = danger_mark.shown()
	_armor.visible = playing and game.run.armor_mode
	_step_companion(playing)
	if not playing:
		_restart.set_fraction(0.0)
		chain_counter.step(delta, 0)
		chain_counter.visible = false
		nixie_rail.clear()
		consumable_slot.clear()
		return
	chain_counter.step(delta, game.player.chain.combo)
	nixie_rail.set_rows(buff_rows())
	consumable_slot.set_belt(game.run.consumables, game.run.consumable_capacity())
	consumable_slot.set_armed(Consumables.duplicator_left(game.run), Consumables.overload_armed(game.run))

	var run = game.run
	var goal := objective_reading()
	var reading := plate_shown(goal)
	_objective.set_objective(reading["icon"], reading["words"], reading["color"], reading["progress"], reading["distance"], reading.get("done", ""), reading["step"])
	var detour := detour_reading(goal)
	_objective.set_detour(detour.get("icon", ""), detour.get("words", ""), detour.get("color", Color.WHITE), detour.get("distance", -1), detour.get("done", ""))
	edge_markers.objective_id = goal["id"]
	edge_markers.objective_icon = goal["icon"]
	edge_markers.engaged = _engaged
	edge_markers.yard_locked = reading["id"] == "break_yard_crew"
	edge_markers.keep_clear = _ball_readouts()
	var signs: Array[Rect2] = []
	if not edge_markers.gate_points.is_empty():
		signs = game.build.gates.keep_clear_rects()
	edge_markers.sign_rects = signs
	var tbl = game.ctx.stages
	var world: int = tbl.world_of(run.stage)
	var world_stages: int = tbl.last_of(world) - tbl.first_of(world) + 1
	var has_boss: bool = game.boss != null and tbl.BOSS != "" and bool(flow.boss_row(world).get("built", false))
	_status.set_status(tbl.local(run.stage), world_stages, has_boss, flow.in_arena, _threat)

	var full: float = maxf(1.0, run.max_hp + HullMark.held(run))
	var hp_share: float = clampf(run.hp / full, 0.0, 1.0)
	_health.set_cap(run.max_hp / full, EventKinds.color("warden_engaged"))
	_health.set_reading(hp_share, Palette.SAND, "", hp_share <= LOW_HEALTH, EventKinds.color("player_hit"))
	if run.armor_mode:
		_armor_peak = maxf(_armor_peak, run.mass)
		_armor_flash = maxf(0.0, _armor_flash - delta)
		_armor.set_reading(clampf(run.mass / _armor_peak, 0.0, 1.0), EventKinds.color("scrap_collected"),
			"", _armor_flash > 0.0, Palette.AMBER)
	_speed.set_tier(game.player.state.tier)
	_cogs.set_amount(run.cogs)
	var shop = game.build.get("shop") if game.build != null else null
	_cogs.set_hook(shop.hook_goal() if shop != null and not flow.in_arena else 0)

	var tint: Color = run.class_def.color if run.class_def != null else Palette.SAND
	var shape: String = run.class_def.shape if run.class_def != null else "ring"
	var slots: Array = _slots.slots(game)
	ability_bar.update_slots(slots, tint, shape)
	ability_bar.hide_keys(key_glyphs.shown_glyphs())
	ability_bar.point_at(tip_slot(field_tips.showing, slots))
	if part_name.visible or danger_mark.visible:
		var cam: Camera3D = game.camera.cam
		var top: Vector3 = game.player.shown_position() + cam.global_basis.y * Tuning.RADIUS
		if not cam.is_position_behind(top):
			var over: Vector2 = cam.unproject_position(top)
			danger_mark.follow(over)
			part_name.follow(Vector2(over.x, danger_mark.rect().position.y) if danger_mark.visible else over)
		else:
			danger_mark.visible = false
	reticle.gauge = AbilitySlots.gauge_of(slots)
	var interact = game.world.get("interact") if game.world != null else null
	if interact != null:
		reticle.gauge = maxf(reticle.gauge, interact.hold_fraction())
	reticle.gauge_color = tint
	var combat = game.get("combat")
	var driver = combat.get("weapon_driver") if combat != null else null
	reticle.cadence = driver.state_snapshot() if driver != null else {}
	reticle.cadence_color = tint
	_step_ultimate(tint)
	nixie_rail.set_piece = ability_bar.set_piece
	consumable_slot.set_piece = ability_bar.set_piece
	if _piece_sizes() != _laid_pieces:
		layout(size)

	var hold: float = game.restart_hold_fraction()
	_restart.set_fraction(hold)
	_restart.visible = hold > 0.0


static func tip_slot(tip: String, slots: Array) -> String:
	if tip != "active":
		return ""
	for entry in slots:
		if String(entry.get("id", "")).begins_with("active_"):
			return AbilityBar.slot_name(entry)
	return ""


func _step_ultimate(tint: Color) -> void:
	var ult: Dictionary = AbilitySlots.ultimate_of(game)
	var active: bool = ult["state"] == "active"
	reticle.meter_active = active
	reticle.meter_full = ult["state"] == "ready"
	reticle.meter = _set_piece_left(float(ult["fill"])) if active else float(ult["fill"])
	reticle.meter_color = AimReticle.meter_fill_color(tint)
	reticle.hide_q = key_glyphs.shown_glyphs().has(reticle.q_glyph())
	ability_bar.set_piece = active
	var combat = game.get("combat")
	ability_bar.line_loaded = combat != null and combat.has_method("line_load") and not (combat.line_load() as Dictionary).is_empty()


func _set_piece_left(fill: float) -> float:
	var combat = game.get("combat")
	var piece = combat.get("ultimate") if combat != null else null
	if piece != null and piece is Object and piece.has_method("progress"):
		return clampf(1.0 - float(piece.progress()), 0.0, 1.0)
	return fill


func _on_verb_failed(verb: String, _reason: String, _at: Vector3) -> void:
	if verb == "haul":
		ability_bar.refuse(AbilitySlots.AbilityState.SMASH)
		return
	if verb != "select" or game.player == null:
		return
	var pick: int = int(game.player.intent.slot_pick)
	var bar: Array = AbilitySlots.AbilityState.BAR
	ability_bar.refuse(bar[pick] if pick >= 0 and pick < bar.size() else "line")


func _talk_takes_interact() -> bool:
	var shop = game.get_node_or_null("Workshop")
	var bubble = shop.get("bubble") if shop != null else null
	return bubble != null and bubble.takes_interact()


func _physics_process(delta: float) -> void:
	if game == null:
		return
	if _engaged:
		_struggle.step(delta)
	var activities = game.world.activities if game.world != null else null
	_site = activities.at_hand(game.player.shown_position(), _site if is_instance_valid(_site) else null) if activities != null and game.flow != null and game.flow.in_play() else null
	if _done.showing() and game.flow != null and game.flow.in_play():
		_done.step(delta, String(objective_reading()["words"]))
	if _detour_done.showing():
		_detour_done.step(delta, "")
	part_name.step(delta)
	_step_fight_hint()


func _step_fight_hint() -> void:
	var boss = game.get("boss")
	if boss == null or not boss.has_method("take_hint") or game.flow == null or not game.flow.in_play():
		return
	if not _toast.is_empty() or not _held_toast.is_empty():
		return
	var kind := String(boss.take_hint())
	var row: Dictionary = EventKinds.UI_ROWS.get(kind, {})
	if row.is_empty():
		return
	toast(String(row["hud"]), row["color"], row["shape"], mini(int(row["priority"]), 3))
	var audio = game.audio() if game.has_method("audio") else null
	if audio != null and audio.has_method("play"):
		audio.play(kind, 0.0, 1.0, "UI")
	game.events.prompt_shown.emit(kind)


func toast_on_screen() -> String:
	if _toast.is_empty() or launch_card.showing():
		return ""
	return _toast["text"]


func drop_toast(text: String) -> void:
	if not _toast.is_empty() and _toast["text"] == text:
		_toast = {}
		_toast_row.visible = false
	if not _held_toast.is_empty() and _held_toast["text"] == text:
		_held_toast = {}


func quiet(on: bool) -> void:
	_quiet = on
	if on:
		for piece in [_toast_row, _toasts, why_callout, damage_numbers, part_name, _ach_panel, _lore_panel]:
			if piece != null and piece.visible:
				piece.visible = false
				_quiet_hid.append(piece)
		return
	for piece in _quiet_hid:
		if is_instance_valid(piece):
			piece.visible = true
	_quiet_hid.clear()


func _step_toast(delta: float) -> void:
	if not launch_card.showing() and not _held_toast.is_empty():
		_show_toast(_held_toast)
		_held_toast = {}
	_toast_row.visible = not _toast.is_empty() and not launch_card.showing() and not _quiet
	if _toast.is_empty():
		return
	if not _toast_row.visible:
		return
	_toast["left"] -= delta
	_toast["age"] += delta
	_toast_row.modulate.a = clampf(minf(_toast["age"] / TOAST_IN, _toast["left"] / TOAST_OUT), 0.0, 1.0)
	if _toast["left"] <= 0.0:
		_toast = {}
		_toast_row.visible = false
