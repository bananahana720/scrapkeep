extends Node3D

const AppShell := preload("res://src/core/app_shell.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const Warden := preload("res://src/combat/warden.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

# The Mind's body: the open crown over the pad (boss_mind_base.glb) and the combat seat's kit
# (boss_mind_kit.glb) under the choir Warden. Visual only. mind.gd still owns every attack,
# hazard and hand; this node reads that state each physics frame and cues the clip that
# matches it, so a body cue starts on the frame its hazard commits, goes live and ends.
# The lens follows the Warden's real open choir seat (family_point_at) and never moves a
# collider. A missing GLB makes attach() return null and the stub's Warden body stays.

const BASE := "res://assets/models/bosses/boss_mind_base.glb"
const KIT := "res://assets/models/bosses/boss_mind_kit.glb"
# Test seam: a test points these at a missing file to prove the stub body stays.
static var base_path := BASE
static var kit_path := KIT


static func reset_for_tests() -> void:
	base_path = BASE
	kit_path = KIT
const BASE_PARTS := ["CombatSeat", "CrownFrame", "Mantle0", "Mantle5"]
const KIT_PARTS := ["CombatSeat", "LensRoot", "Shutter0", "PulseLip", "FamilyRecoil", "EmitterL", "BracePlate", "RushCollar"]
const FAMILY_CLIPS := {"lane": "lane_warn", "split_lane": "split_lane_warn", "rush": "rush_warn", "plate": "plate_warn"}
# Phase p breaks one more mantle: phase 2 sheds the first, 3 the second, 4 the third.
const PHASE_CLIPS := {2: "phase_break", 3: "phase_break_2", 4: "phase_break_3"}
# All hands (Andrew, 2026-10-18): the crew were the Mind's hands, so a body built as a hand
# carries the old roster's stencils on its fingers and clocks one out per phase, little finger
# (04) first, and its defeat sets a glove down by the empty place. A base with these clips
# plays them in place of the mantle breaks and final_quiet; one without them keeps those.
const CLOCK_OUT_CLIPS := {2: "clock_out_04", 3: "clock_out_03", 4: "clock_out_02"}
const DEFEAT_CLIP := "glove_down"
const SHUTTERS := ["Shutter0", "Shutter1", "Shutter2", "Shutter3", "Shutter4", "Shutter5"]
# How fast the lens settles onto a new choir seat; the clips' own change is 0.6 s.
const LENS_SETTLE := 8.0
# How far a warn clip may be stretched or squeezed to fit its sim timer.
const WARN_SPEED_MIN := 0.5
const WARN_SPEED_MAX := 2.0
# The two story cards (W49-MAPS). Both sit on a CanvasLayer under this node, ignore the mouse, never
# pause the tree and never take input from the ball; a press of jump, accept or cancel only dismisses.
const CALL_IN_NODE := "ForemanCallIn"
const HIRED_NODE := "HiredStamp"
const CARD_LAYER := 40
# The last part of a card's life fades it out.
const CARD_FADE_S := 0.45
# The stamp lands tilted and a size too big, then settles (TONE-BIBLE: cards ink-stamp on).
const STAMP_TILT_DEG := -8.0
const STAMP_LAND_SCALE := 1.35
const STAMP_LAND_S := 0.1

var module
var base: Node3D
var kit: Node3D
var _base_anim: AnimationPlayer
var _kit_anim: AnimationPlayer
var _lens_anim: AnimationPlayer
var _pulse_anim: AnimationPlayer
var _lens: Node3D
var _recoil: Node3D
var _open := false
var _charging := false
var _phase := 1
var _attack_seen := 0
var _hands_seen := 0
var _current := {}
var _defeated := false
var _lens_placed := false
# Each card's layer and the seconds it has left on screen; 0 means it is not up.
var _call_in: CanvasLayer
var _call_in_left := 0.0
var _hired: CanvasLayer
var _hired_left := 0.0


# Reads the base and kit ahead on loader threads while the approach runs (mind.gd's prepare_arena):
# loading them took 18 to 31 ms of the boss-entry frame on the cloud (scrapkeep#241).
static func prepare() -> void:
	# Headless loads stay on the main thread: the dummy rasterizer's mesh RIDs are not thread-safe.
	if AppShell.headless():
		return
	for path in [base_path, kit_path]:
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path)


# Teardown: collects the files prepare() asked for that attach never took.
static func settle() -> void:
	for path in [base_path, kit_path]:
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(path)


static func attach(owner_module):
	preload("res://src/presentation/quiet_gun.gd").attach(owner_module)
	# The loader thread's copies, held so load_scene's load() finds them in the cache.
	var _read := [_take(base_path), _take(kit_path)]
	var base_scene := BossModel.load_scene(base_path)
	var kit_scene := BossModel.load_scene(kit_path)
	if base_scene == null or kit_scene == null or not _has_parts(base_scene, BASE_PARTS) or not _has_parts(kit_scene, KIT_PARTS):
		if base_scene != null:
			base_scene.free()
		if kit_scene != null:
			kit_scene.free()
		return null
	var dress = new()
	dress.name = "MindDress"
	dress.module = owner_module
	owner_module.add_child(dress)
	dress.global_position = owner_module.pad.global_position + Vector3.UP * owner_module.PAD_THICK * 0.5
	dress.setup(base_scene, kit_scene)
	return dress


# A file prepare() asked for, from its loader thread (waiting if it is still loading); null when
# nothing asked, and load_scene loads it.
static func _take(path: String) -> Resource:
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return ResourceLoader.load_threaded_get(path)
	return null


static func _has_parts(scene: Node, parts: Array) -> bool:
	for part in parts:
		if scene.find_child(part, true, false) == null:
			return false
	return true


func setup(base_scene: Node3D, kit_scene: Node3D) -> void:
	base = base_scene
	kit = kit_scene
	base.name = "MindBase"
	kit.name = "MindKit"
	add_child(base)
	module.warden.add_child(kit)
	kit.position = Vector3.DOWN * Warden.HALF_HEIGHT
	_base_anim = BossModel.player_of(base)
	_kit_anim = BossModel.player_of(kit)
	BossModel.own_clips(_base_anim)
	BossModel.own_clips(_kit_anim)
	BossModel.loop_clip(_kit_anim, "attention")
	_lens = kit.find_child("LensRoot", true, false)
	_recoil = kit.find_child("FamilyRecoil", true, false)
	# Code owns where the lens is and what it faces; the lens shutters and the pulse lip each
	# get their own player so a stagger or a pulse can run beside any family cue.
	BossModel.strip_tracks(_kit_anim, "LensRoot")
	_lens_anim = BossModel.split_player(_kit_anim, ["stagger_open"], SHUTTERS)
	_pulse_anim = BossModel.split_player(_kit_anim, ["pulse_warn", "pulse"], ["PulseLip"])
	BossModel.hide_warden_body(module.warden)
	BossModel.play(_kit_anim, "attention")
	show_call_in()


func _physics_process(delta: float) -> void:
	if module == null or not is_instance_valid(module):
		queue_free()
		return
	_step_cards(delta)
	var warden = module.warden
	if is_instance_valid(warden):
		BossModel.hide_warden_body(warden)
		_step_lens(warden, delta)
		var open: bool = warden.staggered()
		if open != _open:
			_open = open
			BossModel.play(_lens_anim, "stagger_open", not open)
		var charging: bool = warden._charging
		if charging != _charging:
			_charging = charging
			BossModel.play(_pulse_anim, "pulse_warn" if charging else "pulse")
	var phase: int = module.phase
	if phase != _phase:
		if phase > _phase and PHASE_CLIPS.has(phase):
			if not BossModel.play(_base_anim, CLOCK_OUT_CLIPS[phase]):
				BossModel.play(_base_anim, PHASE_CLIPS[phase])
		_phase = phase
	_step_attack()
	if module.state == module.DEFEATED and not _defeated:
		_defeated = true
		if not BossModel.play(_base_anim, DEFEAT_CLIP):
			BossModel.play(_base_anim, "final_quiet")
		BossModel.play(_kit_anim, "final_quiet")
		show_hired()


# The lens sits on the seat the Warden has open and faces the ball.
func _step_lens(warden, delta: float) -> void:
	var seat: Vector3 = warden.family_point_at()
	if _lens_placed:
		_lens.global_position = _lens.global_position.lerp(seat, 1.0 - exp(-LENS_SETTLE * delta))
	else:
		_lens.global_position = seat
		_lens_placed = true
	var to: Vector3 = module.ctx.player.ball_position() - _lens.global_position
	if to.length() > 0.5:
		_lens.global_basis = Basis.looking_at(to.normalized(), Vector3.UP if absf(to.normalized().y) < 0.95 else Vector3.FORWARD)


# One clip per committed attack: the warn on commit, the snap when its hazard goes live, the
# release when every hazard of the attack is done.
func _step_attack() -> void:
	if module.attack_count != _attack_seen and not module.attacks.is_empty():
		_attack_seen = module.attack_count
		_current = {"attack": module.attacks.back(), "struck": false}
		var family: String = String(_current["attack"]["family"])
		_aim(_current["attack"])
		var warn_clip: String = FAMILY_CLIPS.get(family, "lane_warn")
		BossModel.play(_kit_anim, warn_clip, false, -1.0, _warn_speed(warn_clip, _current["attack"]))
		_hands_seen = module.hands.size()
		return
	if _current.is_empty():
		return
	var live := false
	var done := true
	for h in _current["attack"]["hazards"]:
		if is_instance_valid(h):
			live = live or h.is_live()
			done = done and h.is_done()
	if live and not _current["struck"]:
		_current["struck"] = true
		BossModel.play(_kit_anim, "family_strike")
	elif done:
		var sent: bool = module.hands.size() > _hands_seen
		_hands_seen = module.hands.size()
		BossModel.play(_kit_anim, "hand_send" if sent else "recovery")
		_current = {}


# From phase 2 the sim tightens each warn below its clip's authored length, so the strike cut
# the clip short. The clip is stretched to end exactly when the hazard's own warn timer does;
# the timer itself is only read.
func _warn_speed(clip: String, attack: Dictionary) -> float:
	var hazards: Array = attack["hazards"]
	if hazards.is_empty() or not is_instance_valid(hazards[0]) or not _kit_anim.has_animation(clip):
		return 1.0
	var warn: float = hazards[0].warn_seconds
	if warn <= 0.0:
		return 1.0
	return clampf(_kit_anim.get_animation(clip).length / warn, WARN_SPEED_MIN, WARN_SPEED_MAX)


# Emitters yaw to the committed bearing: a lane's heading, or the middle of a plate's sector.
func _aim(attack: Dictionary) -> void:
	for h in attack["hazards"]:
		if not is_instance_valid(h):
			continue
		var dir := Vector3.ZERO
		if h.shape == h.Shape.LANE:
			dir = h.heading
		elif h.shape == h.Shape.SECTOR:
			var angle: float = (h.a_from + h.a_to) * 0.5
			dir = Vector3(cos(angle), 0.0, sin(angle))
		if dir.length() > 0.1:
			_recoil.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP)
		return


# --- The story cards (W49-MAPS) ---

# The Foreman's scheduled call-in, a small card in the top right corner.
func show_call_in() -> void:
	dismiss_call_in()
	var card := LoreRows.FOREMAN_CALL_IN
	var words := UiFonts.face(UiTokens.Hand.OLD_WORKS)
	_call_in = _card_layer(CALL_IN_NODE)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -392.0
	panel.offset_right = -32.0
	panel.offset_top = 32.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.CHARCOAL, 0.9)
	style.border_color = Palette.SLATE_INK
	style.border_width_left = 6
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	_call_in.get_child(0).add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_child(_label(String(card["title"]), words, 26, Palette.LEDGER_CREAM))
	var line := _label(String(card["line"]), words, 16, Palette.SAND)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(line)
	for stat in card["stats"] + [card["likes"]]:
		box.add_child(_label("%s  %s" % [stat[0], stat[1]], words, 15, Palette.SLATE_INK))
	_call_in_left = float(card["duration_s"])


# The defeat edge: a giant ink HIRED over the screen's middle and the Mind's memo under it.
func show_hired() -> void:
	dismiss_hired()
	var card := LoreRows.HIRED_CEREMONY
	_hired = _card_layer(HIRED_NODE)
	var root: Control = _hired.get_child(0)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var stamp := _label(String(card["stamp"]), UiFonts.face(UiTokens.Hand.KEEPER), 132, Palette.RUST)
	stamp.name = "Stamp"
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.add_theme_color_override("font_outline_color", Palette.LEDGER_CREAM)
	stamp.add_theme_constant_override("outline_size", 6)
	box.add_child(stamp)
	var memo := _label(String(card["memo"]), UiFonts.face(UiTokens.Hand.OLD_WORKS), 18, Palette.LEDGER_CREAM)
	memo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	memo.add_theme_color_override("font_outline_color", Palette.CHARCOAL)
	memo.add_theme_constant_override("outline_size", 5)
	box.add_child(memo)
	# The stamp lands: tilted, a size too big, settling in STAMP_LAND_S.
	stamp.rotation_degrees = STAMP_TILT_DEG
	stamp.scale = Vector2.ONE * STAMP_LAND_SCALE
	stamp.resized.connect(func(): stamp.pivot_offset = stamp.size * 0.5)
	var land := stamp.create_tween()
	land.tween_property(stamp, "scale", Vector2.ONE, STAMP_LAND_S)
	_hired_left = float(card["duration_s"])


func dismiss_call_in() -> void:
	_call_in_left = 0.0
	if is_instance_valid(_call_in):
		_call_in.queue_free()
	_call_in = null


func dismiss_hired() -> void:
	_hired_left = 0.0
	if is_instance_valid(_hired):
		_hired.queue_free()
	_hired = null


# Retries and new runs leave no card behind.
func _exit_tree() -> void:
	dismiss_call_in()
	dismiss_hired()


func _input(event: InputEvent) -> void:
	if _call_in_left <= 0.0 and _hired_left <= 0.0:
		return
	var accept := InputMap.has_action("ui_accept") and event.is_action_pressed("ui_accept")
	var cancel := InputMap.has_action("ui_cancel") and event.is_action_pressed("ui_cancel")
	var jump := InputMap.has_action("cl_jump") and event.is_action_pressed("cl_jump")
	if accept or cancel or jump:
		dismiss_call_in()
		dismiss_hired()


func _step_cards(delta: float) -> void:
	if _call_in_left > 0.0:
		_call_in_left -= delta
		if _call_in_left <= 0.0:
			dismiss_call_in()
		else:
			_fade(_call_in, _call_in_left)
	if _hired_left > 0.0:
		_hired_left -= delta
		if _hired_left <= 0.0:
			dismiss_hired()
		else:
			_fade(_hired, _hired_left)


static func _fade(layer: CanvasLayer, left: float) -> void:
	if is_instance_valid(layer) and left < CARD_FADE_S:
		(layer.get_child(0) as Control).modulate.a = clampf(left / CARD_FADE_S, 0.0, 1.0)


# A card's layer and its full-screen root, which lets every click through.
func _card_layer(node_name: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = node_name
	layer.layer = CARD_LAYER
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	return layer


static func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
