extends CanvasLayer

const EventKinds := preload("res://src/core/event_kinds.gd")
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
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")
const HotwireScreen := preload("res://src/ui/hotwire_screen.gd")
const Companion := preload("res://src/core/companion.gd")

# The wallet readout: the brass cog and the cogs the run holds, the one number the HUD
# shows because it is what the next roll through a hoop spends.
class CogChip extends Control:
	const ICON := "res_scrap"
	const COLOR := Palette.BRASS

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
		UiDraw.icon(self, Icons.texture(ICON), Rect2(Vector2(0.0, mid - 10.0), Vector2(20.0, 20.0)), Icons.tint(ICON, COLOR))
		UiDraw.text(self, 26.0, mid, str(amount), 18, Palette.SAND, true)


# The field-notes key drawn small: the cap Tab opens the notes with.
class NoteKey extends Control:
	const KEY := "key_tab"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Keycap.size_of(KEY, 24.0)

	func _draw() -> void:
		Keycap.draw(self, size * 0.5, KEY, Palette.SAND, 24.0)


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
# What the cores held do for the gates, by count (parts.gd gate_rarities reads min(count, RunState.CORE_TIER_CAP)):
# one core lets a gate offer a rare, two make a gate offer rares or relics, and from a third the gates
# are already at their best. Held cores still stake a bet, so the third is not called useless.
const CORE_WORDS := ["", "Gates may offer rares", "Gates offer rares, relics", "Gates at their best"]
# An earned achievement's toast: an amber star, "Achievement" and the row's name, 3 s in all
# (in, hold, out). It sits at the top right, clear of the objective, above the menu screens (layer 8), so one earned as a run ends
# still reads. While a Warden fight is live it waits, and the queue shows in order.
const ACH_LAYER := 8
const ACH_TOTAL := 3.0
const ACH_TOP := 14.0
const ACH_FONT := 21
const ACH_DETAIL_FONT := 15
# A jukebox record found in play shares the achievement plate, in the one line with every other card
# (screen_busy.gd), oldest first.
# A record found in play wears the drawn wave on amber. A radio take wears the radio chip's knob
# (the radio_take icon, radio-take-icon.md), tinted by tier: mint for a take, slate for a B-side,
# brass for a legend (the edge radio_page.gd gives a legend). The icon and tint say which card it
# is, so only a B-side keeps a word: nothing but the name carries "the record's second version".
const RECORD_MARK := {"shape": "wave", "tint": Palette.AMBER, "word": ""}
const TAKE_ICON := "radio_take"
const TAKE_MARKS := {"b-side": {"id": TAKE_ICON, "tint": Palette.SLATE, "word": "B-side"},
	"take": {"id": TAKE_ICON, "tint": Palette.ARC, "word": ""},
	"legend": {"id": TAKE_ICON, "tint": Palette.BRASS, "word": ""}}
const ACHIEVEMENT_MARK := {"shape": "star", "tint": Palette.AMBER, "word": ""}
# A new field note: the Tab cap and these words under the achievement slot, 3 s, faded in and out.
const LORE_TOTAL := 3.0
const LORE_TOP := 66.0
# The top-right corner is one column: the radio chip, the unlock plate, the field note pill.
# Each sits under whichever of the others is showing, this far apart, so none covers another.
const CORNER_GAP := 4.0
const CORNER_SLIDE := 480.0
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
	"grow_return": "warden_engaged", "break_warden": "warden_engaged", "charge_beacon": "beacon_charge_changed",
	"find_activity": "activity_done", "roll_gate": "reward_offered", "hold_line": "launched", "break_brindle": "boss_arena_entered",
	"break_yard_crew": "pack_arrived", "break_clamp_crews": "pack_arrived",
	"ride_sheet": "warden_engaged", "line_fight": "warden_engaged",
	"shoot_magnets": "boss_arena_entered", "slam_caps": "boss_arena_entered", "bait_charge": "boss_arena_entered",
	"ram_scooter": "boss_arena_entered"}
# The rows whose glyph is ringed by how much of the Warden is broken.
const RING_ROWS := ["find_warden", "break_guard", "smash_core", "grow_return", "break_warden", "charge_beacon",
	"ride_sheet", "line_fight"]
# The stage locks' facts that finish a goal (stage_locks.gd), and the done row each one shows.
const DONE_FACTS := {"arena_unlocked": "yard", "warden_gate_opened": "clamp"}
# Brindle's rows that hold their words through a stagger; the open cockpit turns their glyph.
const NOTE_KEY := "hud:note"
const OPEN_ROWS := ["shoot_magnets", "slam_caps", "bait_charge"]
# The gaps of the top slot when a plate is mounted: from the band's top to the plate, and
# from the plate to the objective plate under it.
const PLATE_TOP := 6.0
const PLATE_GAP := 10.0
const TOAST_WIDTH := 800.0
const MARGIN := 18.0
const BOTTOM_GAP := 20.0
const HEALTH_BAR := 190.0
# The word under each bar (ui/gauge.gd caption): the game's own words for them, as the perk
# rows say "max health" and the wear stamp says "ARMOUR OFF".
const HEALTH_WORD := "HEALTH"
const ARMOR_WORD := "ARMOUR"
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
var first_steps
var field_tips
var edge_markers
var part_name
var danger_mark
var launch_card
var _world_card_at := -1
# The world and stage whose cards wait for the title's turn in a run's opening; 0 when none.
var _title_world := 0
var _title_stage := 0
var _cursed := false
var why_callout
var hotwire_screen
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
var _ach_detail: Label
# What the cards that can wait say, by the key screen_busy.gd holds them under: {tune, text}. The
# owner keeps the order and the turns; this keeps the words and the kind.
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
# A field note was found while a flourish had reading matter up: the pill goes up after it.
var _lore_due := false
var _lore_age := 0.0
var _corner_chip: Control
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
# The finished goal the plate shows ticked before the next one (objectives.gd Done).
var _done := Objectives.Done.new()
# The side site the plate holds as its goal (activities.gd at_hand), stepped each physics tick: a
# site once at hand keeps the row until it is finished or the ball has left it.
var _site = null
# The armour gauge (scrap mode `armor`): the mass heap and the scrap layer over the hull, left of the hull
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
# SR6: floating damage numbers, one layer over the world (presentation/damage_numbers.gd).
var damage_numbers: Control
var _armor_flash := 0.0
var _armor_peak := ARMOR_PEAK_FLOOR
# The companion pip, left of the armour gauge: the escape charge read from run.companion,
# drawn and chirped from the companion_ready / companion_spent UI rows.
var _companion: TextureRect
var _companion_state := "none"
var _companion_cues: Array[String] = []
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
	damage_numbers = DamageNumbers.new()
	damage_numbers.project = _project_to_screen
	add_child(damage_numbers)
	# Juice raises the numbers from the hits it draws, so a number and its effect agree.
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
	why_callout = WhyCallout.new()
	add_child(why_callout)
	why_callout.setup(game, profile)
	part_name = PartName.new()
	add_child(part_name)
	danger_mark = DangerMark.new()
	add_child(danger_mark)
	_mount_hotwire_screen()

	_build_ach_toast()
	_build_lore_pulse()
	_busy = game.ctx.screen_busy
	game.codex.lore_found.connect(func(_id: String): _show_lore())
	game.events.achievement_earned.connect(func(id: String): _raise_card(Achievements.toast_text(id), false))
	game.events.run_ended.connect(func(_won: bool): clear_achievement_toasts())
	game.opening.turned.connect(_on_turned)
	_connect_toasts(game.events)
	game.events.boss_phase_changed.connect(func(_phase: int, phase_name: String):
		toast_kind("boss_phase_changed", {"name": phase_name.capitalize()}))
	game.events.event_ended.connect(_on_event_ended)
	game.events.event_announced.connect(_on_event_announced)
	game.events.part_gained.connect(func(part_id: String, _source: String): part_name.show_part(part_id))
	game.events.warden_engaged.connect(func(_stage: int): _begin_engagement(true))
	game.events.boss_arena_entered.connect(_seat_boss_plate)
	game.events.beacon_unsealed.connect(func(_stage: int): _begin_engagement(false))
	# A finished goal is ticked on the plate before the next one shows (plate_shown).
	game.events.activity_done.connect(func(id: String, _at: Vector3): _done.note(Objectives.done_words(id, game.world.activities.called(id))))
	game.events.trade_taken.connect(func(kind: String, _at: Vector3): _done.note(Objectives.done_words(kind)))
	game.events.event_ended.connect(func(id: String, outcome: String):
		if outcome == "lost":
			_done.note(Objectives.lost_words(id), false))
	game.events.beacon_unsealed.connect(func(_stage: int): _done.note(Objectives.done_words("warden")))
	# The clamp is the fight's: opened from the road it is ticked nowhere (the plate never said it
	# was shut), and a site finished in the same breath keeps its own tick.
	game.events.world_fact.connect(func(kind: String, _at: Vector3):
		if DONE_FACTS.has(kind) and (kind != "warden_gate_opened" or _engaged):
			_done.note(Objectives.done_words(DONE_FACTS[kind]), true, true))
	game.events.posture_changed.connect(_on_posture)
	game.events.launched.connect(_on_launched)
	game.events.world_entered.connect(_on_world_entered)
	game.events.stage_entered.connect(_on_stage_entered)
	game.events.threat_rose.connect(func(tier: int): _threat = maxi(_threat, tier))
	# The boss's title, unless its arrival row is saying the name on a card of its own. The row
	# starts on this signal too, and first: the presentation is set up before the HUD.
	game.events.boss_arena_entered.connect(func():
		var presentation = game.get("presentation")
		if presentation == null or not presentation.names_boss():
			launch_card.show_card("fac_fleet", EventKinds.hud("boss_arena_entered"), EventKinds.color("boss_arena_entered")))
	game.events.run_started.connect(func(_class_id: String):
		_title_world = 0
		_title_stage = 0
		_threat = 0
		_begin_engagement(false)
		_armor_peak = ARMOR_PEAK_FLOOR
		_health.clear()
		_armor.clear())
	layout(_screen_size())


# The hot-wired Fit / Recycle screen (hotwire_screen.gd) is a modal like the pause menu, so it
# sits beside it on the game, out of the HUD's play-view word budget; the HUD keeps the handle
# and hides it outside play. It opens itself from build's hotwire_offered. Added at once, as the
# pause menu is: a deferred add left the screen unparented when a test freed the game in the same
# frame, and its labels then leaked at exit (2026-10-04, wave 6 gate 2 flagged 24 tests).
func _mount_hotwire_screen() -> void:
	hotwire_screen = HotwireScreen.new()
	game.add_child(hotwire_screen)
	hotwire_screen.setup(game)


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
	plate.content_margin_top = 5.0
	plate.content_margin_bottom = 5.0
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
	_ach_icon = star
	# A record or take says which it is here; an achievement's star and amber frame already do.
	var word := _label(18)
	word.add_theme_color_override("font_color", Palette.AMBER)
	word.visible = false
	row.add_child(word)
	_ach_word = word
	# The name, then what it gives in smaller type: two lines that fit the top band under the chip.
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -3)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	_ach_name = _label(ACH_FONT)
	_ach_name.add_theme_color_override("font_color", Palette.SAND)
	words.add_child(_ach_name)
	_ach_detail = _label(ACH_DETAIL_FONT)
	_ach_detail.add_theme_color_override("font_color", Color(Palette.SAND, 0.78))
	words.add_child(_ach_detail)


func _build_lore_pulse() -> void:
	var layer_node := CanvasLayer.new()
	layer_node.layer = ACH_LAYER
	add_child(layer_node)
	_lore_panel = PanelContainer.new()
	_lore_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lore_panel.visible = false
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(Palette.CHARCOAL, 0.94)
	plate.border_color = Palette.SAND
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(8)
	plate.content_margin_left = 12.0
	plate.content_margin_right = 16.0
	plate.content_margin_top = 6.0
	plate.content_margin_bottom = 6.0
	_lore_panel.add_theme_stylebox_override("panel", plate)
	layer_node.add_child(_lore_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lore_panel.add_child(row)
	row.add_child(NoteKey.new())


func _show_lore() -> void:
	_lore_due = true
	_busy.request(NOTE_KEY)
	_step_lore(0.0)


# A flourish has a card, a caption or a comic panel up or on the way (presentation.reading):
# one voice at a time, so the corner's plates and pill wait for it.
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
	# It slides, not jumps, when the plate above it leaves.
	var want := _corner_under(_ach_panel, _corner_under(_corner_chip, LORE_TOP))
	var y := want if _lore_age <= delta else move_toward(_lore_panel.position.y, want, delta * CORNER_SLIDE)
	_lore_panel.position = Vector2(_screen_size().x - _lore_panel.size.x - MARGIN, y)
	if _lore_left <= 0.0:
		_lore_panel.visible = false
		_free_slot(NOTE_KEY)


# A chip that lives in the top-right corner (the pilot radio). The plate and the pill line up
# under it while it shows.
func mount_corner(chip: Control) -> void:
	# Stepped before the HUD, so the plate under it reads this frame's size and not last frame's.
	chip.process_priority = process_priority - 1
	add_child(chip)
	_corner_chip = chip


# The chip is mid-swell (a station change, radio_dial.gd): for those seconds it is twice its
# height, and a plate under it would hang below the top band. A new plate waits it out.
func _corner_swollen() -> bool:
	return _corner_chip != null and _corner_chip.visible and _corner_chip.has_method("swollen") and _corner_chip.swollen()


# The y for a corner piece: under the piece above when that one is showing, else its own top.
func _corner_under(above: Control, top: float) -> float:
	if above == null or not above.visible:
		return top
	return above.position.y + above.size.y + CORNER_GAP


# The corner's pieces now showing, top to bottom, each as its name and screen rect.
func corner_rects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for piece in [["chip", _corner_chip], ["plate", _ach_panel], ["pill", _lore_panel]]:
		var control: Control = piece[1]
		if control != null and control.visible:
			out.append({"name": piece[0], "rect": Rect2(control.position, control.size)})
	return out


# The achievement toast on screen (its row's name), then the names still waiting.
func ach_toasts() -> Array[String]:
	var out: Array[String] = []
	if not _ach_entry.is_empty():
		out.append(_ach_entry["text"])
	return out


func ach_waiting() -> Array[String]:
	return _waiting_texts(false)


# A record found for Moss's jukebox: its name, then where to play it.
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


# The oldest card of this HUD still waiting, by the owner's order.
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


# A take found for the pilot radio: its name, then the station it airs on.
func take_found(take_name: String, station_name: String, tier := "take") -> void:
	var text := "%s\nOn the radio at %s" % [take_name, station_name]
	_take_tiers[text] = tier
	_raise_card(text, true)


# The mark a card wears, by what it is: {id or shape, tint, word}. An achievement is a star, a
# record the wave, a take the knob; a take's tier ("" for a take found with no tier) picks the tint.
static func card_mark(tune: bool, tier := "") -> Dictionary:
	if not tune:
		return ACHIEVEMENT_MARK
	if tier == "":
		return RECORD_MARK
	return TAKE_MARKS.get(tier, TAKE_MARKS["take"])


# The ending owns the screen: no achievement toast waits for it or shows over it.
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


# The victory lap opens on its own banner: no toast left over from the win shows under it.
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
		# The first line is the name; whatever follows it is the detail.
		var lines := String(_ach_entry["text"]).split("\n", true, 1)
		_ach_name.text = lines[0]
		_ach_detail.text = lines[1] if lines.size() > 1 else ""
		_ach_detail.visible = _ach_detail.text != ""
		var mark := card_mark(tune, String(_take_tiers.get(_ach_entry["text"], "")))
		_ach_word.text = String(mark["word"])
		_ach_word.visible = _ach_word.text != ""
		_ach_icon.texture = Icons.texture(String(mark["id"])) if mark.has("id") else Icons.shape(String(mark["shape"]))
		_ach_icon.modulate = mark["tint"]
		# A panel grows to its words by itself and never shrinks: a short entry after a long one resets it.
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


func _on_field_fact(value, kind: String) -> void:
	var shown = value
	if value is String:
		shown = (value as String).replace("_", " ").capitalize()
	toast_kind(kind, {FIELD_ARGS[kind]: shown})


func _on_fact(kind: String) -> void:
	toast_kind(kind)


# The core toast names what the cores held do now, not one line for every core.
func _on_core_gained(_source: String, _at: Vector3, count: int) -> void:
	toast(core_words(count), EventKinds.color("core_gained"), EventKinds.row("core_gained").get("shape", "none"), mini(EventKinds.priority("core_gained"), 3))


static func core_words(count: int) -> String:
	return CORE_WORDS[clampi(count, 0, CORE_WORDS.size() - 1)]


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
		boss_plate.bind(warden, null if _engaged else _arena_phases())
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


# The live arena fight's phases (a FightPhases, Brindle's _phases), for the plate's diamonds,
# or null for a boss without them. Read, never written: the fight owns it.
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


# "incoming" warns of something still on its way. An announcement with no lead is already here
# (a stage's resting weather starts with the stage: "Dawn Still"), so it warns of nothing.
func _on_event_announced(event_id: String, seconds_until: float) -> void:
	if seconds_until > 0.0:
		_on_field_fact(event_id, "event_announced")


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


# The escape charge the pip shows: "none" without a seated escape corridor, else
# "ready" or "spent".
static func companion_state_of(doc: Dictionary) -> String:
	if doc.is_empty():
		return "none"
	var model := Companion.new()
	if not model.from_dict(doc) or not model.has_family(Companion.ESCAPE_CORRIDOR):
		return "none"
	return "ready" if model.escape_ready() else "spent"


# The chirps played so far, oldest first.
func companion_cues() -> Array[String]:
	return _companion_cues.duplicate()


func companion_state() -> String:
	return _companion_state


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
	if game.opening.waits("title"):
		_title_world = world
		return
	if game.ctx.stages.worlds().size() <= 1:
		return
	var row := Worlds.row(world)
	if row.is_empty():
		return
	# The world card carries the first stage's modifier, so it is on screen from the drop's start.
	launch_card.show_card("obj_beacon", String(row["name"]), EventKinds.color("stage_entered"), StageModifier.card_line(game.run, game.ctx.terrain, game.run.stage))
	_world_card_at = Time.get_ticks_msec()


func _on_stage_entered(stage: int, retry: bool) -> void:
	_threat = 0
	_begin_engagement(false)
	_done.clear()
	_site = null
	if retry:
		return
	if game.opening.waits("title"):
		_title_stage = stage
		return
	_title_for(stage)


# The title's turn in a run's opening (opening.gd): the world and stage cards held under the
# launch take's panel go up now, where they can be read.
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
		# This run's card only: a restart inside the beat has its own on the way.
		var run_id := String(game.run.run_id)
		get_tree().create_timer(WORLD_CARD_BEAT).timeout.connect(func():
			if game != null and game.run != null and game.run.stage == stage and String(game.run.run_id) == run_id:
				_card_for_stage(stage))
	elif launch_card.showing():
		launch_card.extend()
	else:
		_card_for_stage(stage)


# The moment a run turns cursed, its card goes up; a retry's rewind or a new run clears it quietly.
func _step_curse() -> void:
	var now: bool = game.run != null and game.run.cursed()
	if now and not _cursed:
		launch_card.show_card("obj_beacon", StageModifier.CURSE.word, EventKinds.color("stage_entered"), StageModifier.CURSE.line)
		if game.player != null:
			StageModifier.announce(game.player.shown_position())
	_cursed = now


# The stage's name, and its SI3 modifier read from the same pick the pocket draw applies, after
# the cursed line once the run is cursed.
func _card_for_stage(stage: int) -> void:
	var modifier := StageModifier.for_stage(game.run, game.ctx.terrain, stage)
	launch_card.show_card("obj_beacon", game.ctx.stages.of(stage)["name"], EventKinds.color("stage_entered"), StageModifier.card_line(game.run, game.ctx.terrain, stage))
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


# Where a world point sits on screen, null behind the camera (the damage-number layer's projector).
func _project_to_screen(at: Vector3) -> Variant:
	var cam: Camera3D = game.camera.cam
	if cam.is_position_behind(at):
		return null
	return cam.unproject_position(at)


# Puts every piece in its band for a screen of this size (screen_regions.gd).
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

	# Three numbered slots and two chips (SKILL-BAR section 5); the chain counter sits right of the chips.
	var bar_size: Vector2 = ability_bar.bar_size(maxi(ability_bar.slots.size(), AbilityBar.NUMBERED + 2))
	var bar_y := bottom.position.y + (bottom.size.y - bar_size.y) * 0.5
	ability_bar.position = Vector2((size.x - bar_size.x) * 0.5, bar_y)
	var slot_mid := bar_y + AbilityBar.SLOT * 0.5
	_health.position = Vector2(ability_bar.position.x - BOTTOM_GAP - _health.size.x, slot_mid - _health.bar_mid())
	_armor.position = Vector2(_health.position.x - BOTTOM_GAP - _armor.size.x, slot_mid - _armor.bar_mid())
	_companion.position = Vector2(_armor.position.x - BOTTOM_GAP - _companion.size.x, slot_mid - _companion.size.y * 0.5)
	_speed.position = Vector2(MARGIN, slot_mid - _speed.size.y * 0.5)
	_cogs.position = Vector2(_speed.position.x + _speed.size.x + BOTTOM_GAP, slot_mid - _cogs.size.y * 0.5)
	chain_counter.position = Vector2(ability_bar.position.x + bar_size.x + BOTTOM_GAP, slot_mid - chain_counter.size.y * 0.5)


# The sizes layout() depends on. Relayout when one changes, not every frame: each
# extent() call shapes text.
func _piece_sizes() -> Array:
	return [_objective.custom_minimum_size, _health.size, _armor.size, maxi(ability_bar.slots.size(), AbilityBar.NUMBERED + 2), _plate_size()]


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
			+ ([_rect_of(_armor)] if _armor.visible else [])
			+ ([_rect_of(_companion)] if _companion.visible else []),
	}


# The wallet the HUD shows: the cogs the run holds.
func wallet_cogs() -> int:
	return _cogs.amount


# The beacon row reads the beacon's own state row, so the HUD, the ring and the edge marker
# agree that an open beacon is an offering, not a live verb.
static func row_color(id: String) -> Color:
	if id == "charge_beacon":
		return EventKinds.state_color("beacon_open")
	# The locks' rows are "not yet" (LEGIBILITY colour law: slate, a locked thing), like a glancing hit.
	if id in ["break_yard_crew", "break_clamp_crews"]:
		return EventKinds.state_color("glancing")
	return EventKinds.color(ROW_COLOR[id])


# A change between ready and spent plays that row's chirp; a change from or to "none" is silent.
func _step_companion(playing: bool) -> void:
	var state := companion_state_of(game.run.companion)
	if state != _companion_state and state != "none" and _companion_state != "none":
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


# The share of the hull bar that stands full, 0 to 1 (-1 before the HUD's first frame): what a player
# reads as the hull. The play watch holds it against the hull itself.
func hull_shown() -> float:
	return _health.fraction


# The objective for the flow's state: the row objectives.gd picks, with its glyph, its colour
# and, while the Warden is still to be found, the metres to it.
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
	# A mounted Warden and the arena's boss each say which verb their fight asks for now.
	var driver = warden.get("mount_driver") if warden != null else null
	if driver != null and driver.has_method("plate_reading"):
		reading.merge(driver.plate_reading(warden), true)
	# What the fight asks for now (the things its marks stand on), for the row's live step.
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
	if id == "find_activity":
		# The side site the ball is at, by what finishes it. No metres: the ball is there.
		words = Objectives.activity_words(String(site.id), activities.called(String(site.id)))
	elif id in OPEN_ROWS and reading.get("open", false):
		# The cockpit is open: the row's words hold and its glyph turns to the cockpit row's.
		icon = Objectives.COCKPIT_GLYPH
	return {"id": id, "icon": icon, "words": words, "color": row_color(id),
		"progress": _clamp_fraction(gate) if id == "break_clamp_crews" else game.beacon.fraction() if id in RING_ROWS else -1.0,
		"distance": int(distance) if id == "find_warden" and distance < INF else -1,
		"step": Objectives.live_step(id, String(asked[0]["what"]) if not asked.is_empty() else "")}


# What the plate shows: the objective, or for Objectives.Done.SECONDS after a goal is finished
# (or lost) that goal ticked (crossed), in the objective's own place.
func plate_shown(reading := {}) -> Dictionary:
	if reading.is_empty():
		reading = objective_reading()
	if not _done.showing() or reading["id"] == "":
		return reading
	return {"id": reading["id"], "icon": "", "words": _done.words, "color": EventKinds.color("activity_done") if _done.won else Palette.RUST,
		"progress": -1.0, "distance": -1, "step": 0, "done": "won" if _done.won else "lost"}


# How many of the crews the Warden's clamp asks for are down, as the ring round the plate's glyph.
static func _clamp_fraction(gate) -> float:
	return clampf(float(gate.cleared) / float(gate.packs_wanted()), 0.0, 1.0) if gate.packs_wanted() > 0 else 0.0


# Every world-attached prompt in front of the camera and within its reach goes in the
# prompts band, nearest first, at most MAX_PROMPTS of them. Each takes the free spot
# nearest its anchor's column (free_spot); the rest wait off screen. A prompt shows its
# detail only while the ball is within its detail_range.
func place_prompts(size: Vector2, playing: bool) -> void:
	prompt_rects.clear()
	var cam: Camera3D = game.camera.cam
	var ball: Vector3 = game.player.shown_position()
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
		prompt.near = ball.distance_to(entry[2]) <= prompt.detail_range
		var spot := prompt_spot(prompt, cam.unproject_position(entry[2]), size, placed, band)
		if spot.size == Vector2.ZERO:
			continue
		prompt.position = spot.position
		prompt.size = spot.size
		prompt.visible = true
		placed.append(spot)
		prompt_rects[prompt] = spot


# The spot for a prompt whose anchor projects to `at`. A prompt showing its detail that finds no
# room gives the detail up and is placed by its name alone, as it reads at range: a label with
# less on it beats no label (three reward gates' details side by side do not always fit 1280x720).
static func prompt_spot(prompt, at: Vector2, size: Vector2, placed: Array[Rect2], band: Rect2) -> Rect2:
	var extent: Vector2 = prompt.shown_extent()
	var spot := free_spot(Rect2(ScreenRegions.clamp_prompt(at, extent, size), extent), placed, band)
	if spot.size == Vector2.ZERO and prompt.near:
		prompt.near = false
		extent = prompt.shown_extent()
		spot = free_spot(Rect2(ScreenRegions.clamp_prompt(at, extent, size), extent), placed, band)
	return spot


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
	_step_curse()
	damage_numbers.step(delta)
	_step_ach(delta)
	_step_lore(delta)

	var flow = game.flow
	var playing: bool = flow.in_play()
	place_prompts(size, playing)
	for piece in [_objective, _status, _toasts, ability_bar, _health, _speed, _cogs, reticle, key_glyphs, first_steps, edge_markers, why_callout, hotwire_screen, damage_numbers]:
		piece.visible = playing
	if _plate != null:
		_plate.visible = playing
	part_name.visible = playing and part_name.left > 0.0
	if _quiet:
		for piece in [_toasts, why_callout, damage_numbers, part_name]:
			piece.visible = false
	danger_mark.show_run(game.combat.near_miss.standing_in() if playing else -1.0)
	danger_mark.visible = danger_mark.shown()
	_armor.visible = playing and game.run.armor_mode
	_step_companion(playing)
	if not playing:
		_restart.set_fraction(0.0)
		chain_counter.step(delta, 0)
		chain_counter.visible = false
		return
	chain_counter.step(delta, game.player.chain.combo)

	var run = game.run
	var goal := objective_reading()
	var reading := plate_shown(goal)
	_objective.set_objective(reading["icon"], reading["words"], reading["color"], reading["progress"], reading["distance"], reading.get("done", ""), reading["step"])
	edge_markers.objective_id = goal["id"]
	edge_markers.objective_icon = goal["icon"]
	edge_markers.engaged = _engaged
	edge_markers.yard_locked = reading["id"] == "break_yard_crew"
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
	if part_name.visible or danger_mark.visible:
		var cam: Camera3D = game.camera.cam
		var top: Vector3 = game.player.shown_position() + cam.global_basis.y * Tuning.RADIUS
		if not cam.is_position_behind(top):
			var over: Vector2 = cam.unproject_position(top)
			danger_mark.follow(over)
			# A name gained inside a mark stands on the mark, not across it.
			part_name.follow(Vector2(over.x, danger_mark.rect().position.y) if danger_mark.visible else over)
		else:
			# The ball is behind the camera: the mark has no place to stand this frame.
			danger_mark.visible = false
	reticle.gauge = AbilitySlots.gauge_of(slots)
	# An interactable's hold-to-arm fills the same class ring (LOOP-REDESIGN section 9).
	var interact = game.world.get("interact") if game.world != null else null
	if interact != null:
		reticle.gauge = maxf(reticle.gauge, interact.hold_fraction())
	reticle.gauge_color = tint
	_step_ultimate(tint)
	if _piece_sizes() != _laid_pieces:
		layout(size)

	var hold: float = game.restart_hold_fraction()
	_restart.set_fraction(hold)
	_restart.visible = hold > 0.0


# The skill bar's live reads (SKILL-BAR section 5): the ultimate meter on the reticle, the set
# piece's dim on the bar, and the loaded line skill's badge on slot 3. Every layer reads the
# one record (AbilitySlots.ultimate_of), so the arc, the Q and the dim cannot drift apart.
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


# The arc drains with the flight during the set piece: B3's set piece reports its progress
# (0 at the wind-up, 1 at the landing) if it offers one; else the meter's own fill stands.
func _set_piece_left(fill: float) -> float:
	var combat = game.get("combat")
	var piece = combat.get("ultimate") if combat != null else null
	if piece != null and piece is Object and piece.has_method("progress"):
		return clampf(1.0 - float(piece.progress()), 0.0, 1.0)
	return fill


# A refused pick shakes the slot the number named (SKILL-BAR section 5). The router emits the
# refusal on the tick the pick is read, while the intent still holds it.
func _on_verb_failed(verb: String, _reason: String, _at: Vector3) -> void:
	if verb != "select" or game.player == null:
		return
	var pick: int = int(game.player.intent.slot_pick)
	var bar: Array = AbilitySlots.AbilityState.BAR
	ability_bar.refuse(bar[pick] if pick >= 0 and pick < bar.size() else "line")


# Simulated time: the tally of a build's trying and the part name's 1.2 s run on the physics
# tick, never the wall clock.
func _physics_process(delta: float) -> void:
	if game == null:
		return
	if _engaged:
		_struggle.step(delta)
	var activities = game.world.activities if game.world != null else null
	_site = activities.at_hand(game.player.shown_position(), _site if is_instance_valid(_site) else null) if activities != null and game.flow != null and game.flow.in_play() else null
	if _done.showing() and game.flow != null and game.flow.in_play():
		_done.step(delta, String(objective_reading()["words"]))
	part_name.step(delta)
	_step_fight_hint()


# A boss fight's own hint (the boss module's take_hint: Brindle's Scuttle gives one to a build
# too light to hit its way in). The fight owns when and how often; the HUD toasts the hint's UI
# row with that row's chime and records it as a prompt, as every other lesson is.
func _step_fight_hint() -> void:
	var boss = game.get("boss")
	if boss == null or not boss.has_method("take_hint") or game.flow == null or not game.flow.in_play():
		return
	# A toast replaces the one showing, and taking the hint starts its gap: ask only when the row is free.
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


# The words the toast row draws now: "" with no toast, or while the stage card covers it
# (field_tips.gd counts a tip as told only once its words have stayed here long enough).
func toast_on_screen() -> String:
	if _toast.is_empty() or launch_card.showing():
		return ""
	return _toast["text"]


# Takes one toast's words down at once (field_tips.gd, when a fight starts), whether showing or held.
func drop_toast(text: String) -> void:
	if not _toast.is_empty() and _toast["text"] == text:
		_toast = {}
		_toast_row.visible = false
	if not _held_toast.is_empty() and _held_toast["text"] == text:
		_held_toast = {}


# Everything this HUD draws that the player does not need to act hides while a card has the
# screen (pick_quiet.gd), and comes back exactly as it was: the toast row, the synergy callout,
# the hit numbers, the part name and the corner cards. Nothing the HUD tracks changes.
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
	_toast["left"] -= delta
	_toast["age"] += delta
	_toast_row.modulate.a = clampf(minf(_toast["age"] / TOAST_IN, _toast["left"] / TOAST_OUT), 0.0, 1.0)
	if _toast["left"] <= 0.0:
		_toast = {}
		_toast_row.visible = false
