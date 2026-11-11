extends Control

const AbilityState := preload("res://src/core/ability_state.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Bindings := preload("res://src/core/bindings.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The prompt (design-v3/LEGIBILITY.md sections 2, 3 and 5): a sand keycap about 28 px tall plus
# the verb's icon in the live colour, drawn at the thing the verb acts on and only on ticks
# where pressing the key would succeed (player.verb_ready). The keys come from the bindings
# table. At most two show at once, the verb in the higher ball state first. A prompt retires
# after RETIRE_AFTER successes on the profile (ui_profile.gd), five for the smash, and comes
# back after a failed press, after IDLE_RETURN seconds unused in a run, and at its first
# availability in each run. Each return lasts at most FAIL_RETURN seconds of ticks on which
# the verb is ready, then the prompt retires again. HOOK rides the harpoon prompt until the
# first bite on the profile and SMASH the haul prompt on a body until the first smash. The
# haul prompt waits for the line to stand LINE_STAND seconds without a Ctrl press (ready or not) and wears
# the reel glyph on a world line, the smash glyph on a body. Sable's E (mount) and Space
# (slingshot, only while mounted) come through the same table. The brake has no prompt.
# Tab's field notes keep the full key list. A deflector in its vault window (0.45 s after a
# rebound, deflector.gd vault_anchor) moves the jump prompt from the ball to the dish for that
# window only, and shows it whenever the ball can jump, even when the slingshot would not:
# a jump there is a vault. Those vault-only ticks spend none of the jump prompt's allowance.
# LET GO is the right-mouse prompt for a line standing on the world: the RMB keycap, a fling arrow and the words, at the anchor below
# the winch prompt, on the first RETIRE_AFTER["letgo"] world latches of a profile only.
# The ultimate's prompt (design-v3/SKILL-BAR.md section 5) is the Q keycap in the meter arc's gap
# at the reticle, on ticks the meter is full and a press would start the set piece; it follows
# the same retire and return rules (its first availability in a run is the run's first full
# meter) and wears ULTIMATE until the profile has used it RETIRE_AFTER["ultimate"] times. While it
# shows, the reticle leaves its own Q off.

const AimReticle := preload("res://src/ui/aim_reticle.gd")

const PROMPT_VERBS := ["haul", "interact", "jump", "harpoon", "boost", "ultimate"]
const BALL_VERBS := ["boost", "interact", "jump"]
const RETICLE_VERBS := ["ultimate"]
const LETGO := "letgo"
const LETGO_WORD := "LET GO"
# The bindings table's readings that are words for the code and not for a player, and what a
# player reads instead: E off the pylon mounts it, the boost key goes, a bite is the hook.
const READ_AS := {"interact": "mount", "go": "boost", "bite": "hook"}
const ULTIMATE_WORD := "ULTIMATE"
const MAX_PROMPTS := 2
const RETIRE_AFTER := {"harpoon": 3, "haul": 3, "smash": 5, "boost": 3, "interact": 3, "jump": 3, "letgo": 3, "ultimate": 3}
const LINE_STAND := 1.5
const FAIL_RETURN := 3.0
const IDLE_RETURN := 90.0
const KEY_H := 28.0
const BALL_OFFSET := Vector2(52.0, -34.0)
const AIM_OFFSET := Vector2(34.0, 24.0)
const STACK := 36.0
const WORD_SIZE := UiTokens.BODY

var game
var profile
# The prompts drawn this tick, in draw order: [{verb, state, word}].
var shown: Array = []
var _forced := {}
var _unused := {}
var _revived := {}
var _first := {}
var _free := {}
var _letgo_latch := 0
var _stood := 0.0
var _winch_held := false
var _line := ""
var _points := {}
var _vault := Vector3.INF
var _placed: Array = []
var _was_drawn := {}


func setup(game_ref, profile_ref) -> void:
	game = game_ref
	profile = profile_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	new_run()
	game.events.run_started.connect(func(_class_id: String): new_run())
	game.events.line_state_changed.connect(_on_line_state)
	game.events.verb_failed.connect(func(verb: String, reason: String, _at: Vector3): returned(verb, reason))
	game.events.boosted.connect(func(_direction: Vector3): record_use("boost"))
	game.events.sprint_started.connect(func(_direction: Vector3): record_use("boost"))
	game.events.blink_used.connect(func(_from: Vector3, _to: Vector3): record_use("boost"))
	game.events.mounted.connect(func(_at: Vector3, _banked: float): record_use("interact"))
	game.events.dismounted.connect(func(velocity: Vector3):
		if velocity.length() > 0.1:
			record_use("jump"))
	if game.events.has_signal("ultimate_started"):
		game.events.ultimate_started.connect(func(_id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float):
			record_use("ultimate"))


# A new run: every prompt is owed its first availability, and nothing is overdue.
func new_run() -> void:
	for verb in PROMPT_VERBS:
		_forced[verb] = 0.0
		_unused[verb] = 0.0
		_revived[verb] = false
		_first[verb] = true
		_free[verb] = 0.0
	_stood = 0.0
	_winch_held = false
	_letgo_latch = 0
	shown = []
	_was_drawn = {}


func _on_line_state(state: String, _target, _at: Vector3, _cause: String) -> void:
	match state:
		"latched_world", "latched_body":
			record_use("harpoon")
			if state == "latched_world" and game.flow.in_play():
				_letgo_latch = profile.add_use(LETGO)
		"smash_committed":
			record_use("smash")


# The verb whose prompt a profile use feeds: a smash is the haul's.
static func verb_of_use(use: String) -> String:
	return "haul" if use == "smash" else use


func record_use(use: String) -> void:
	if not game.flow.in_play():
		return
	profile.add_use(use)
	var verb := verb_of_use(use)
	_unused[verb] = 0.0
	_revived[verb] = false
	_first[verb] = false
	_free[verb] = 0.0
	if verb == "haul":
		_stood = 0.0


# A failed press brings its prompt back for FAIL_RETURN seconds of ready ticks; a failed Ctrl
# also restarts the haul prompt's wait, except a press before a Warden's stagger: that line has
# stood, and its SMASH shows the tick the stagger opens it.
func returned(verb: String, reason := "") -> void:
	if verb in PROMPT_VERBS:
		_forced[verb] = FAIL_RETURN
	if verb == "haul" and reason != "unstaggered":
		_stood = 0.0


func use_key(verb: String, line: String) -> String:
	return "smash" if verb == "haul" and line == "body" else verb


func retired(verb: String, line := "") -> bool:
	var use := use_key(verb, line)
	return profile.uses(use) >= RETIRE_AFTER[use]


# The icon on a prompt: the haul wears the reel on a world line and the smash on a body.
func icon_of(verb: String, line: String) -> String:
	if verb == "haul" and line == "world":
		return Icons.REEL
	return Bindings.icon(verb)


# The word riding a prompt: HOOK until the first bite on the profile, SMASH until the first smash,
# and for E and Space what the key does in the ball's `state` (the bindings table's reading). A keycap and an icon alone told a new player nothing (player's-eye
# pass, 10 Nov 2026). A prompt never draws a key and an icon alone (PF-03): once the first-use
# words have retired, the word is what the key does in `state` (reading_word).
func word_for(verb: String, line: String, state := "") -> String:
	if verb == "harpoon" and profile.uses("harpoon") == 0:
		return EventKinds.LINE_ROWS["locked"]["word"]
	if verb == "haul" and line == "body" and profile.uses("smash") == 0:
		return EventKinds.LINE_ROWS["latched_body"]["word"]
	if verb == "ultimate" and profile.uses("ultimate") < RETIRE_AFTER["ultimate"]:
		return ULTIMATE_WORD
	return reading_word(verb, state)


# What the key does in `state`, in capitals: the bindings table's reading, or its "any" reading
# for a state that names none, so no verb is ever wordless.
static func reading_word(verb: String, state: String) -> String:
	var reading := Bindings.reading(verb, state)
	if reading == "":
		reading = Bindings.reading(verb, "any")
	return String(READ_AS.get(reading, reading)).to_upper()


# Q would start the set piece this tick: the meter is full (AbilityState.ultimate()) and the
# ball is free to act. B3's set piece answers the rest when its press is refused.
static func ultimate_ready(player) -> bool:
	var abilities = player.get("abilities")
	if abilities == null or not abilities.has_method("ultimate"):
		return false
	return String(abilities.ultimate().get("state", "")) == AbilityState.READY and player.get("_frozen") != true


# What the prompts need to know of the ball this tick, read off the player.
static func view_of(player) -> Dictionary:
	var kit = player.kit
	var special = player.abilities.gauge(AbilityState.SPECIAL)
	var ready := {}
	for verb in PROMPT_VERBS:
		ready[verb] = player.verb_ready(verb) if not verb in RETICLE_VERBS else false
	ready["interact"] = player.mount_ready()
	ready["ultimate"] = ultimate_ready(player)
	var jump_possible: bool = ready["jump"]
	ready["jump"] = ready["jump"] and kit.mounted
	return {
		"ready": ready,
		"jump_possible": jump_possible,
		"line": "" if not kit.hooked else ("body" if kit.on_body else "world"),
		"charging": (special != null and special.charging) or kit.slingshot.charging,
		"mounted": kit.mounted,
		"airborne": not player.state.grounded,
		"winching": kit.winching,
		"points": {"harpoon": kit.aim.get("point", Vector3.INF), "haul": kit.anchor, "boost": player.shown_position(),
			"interact": player.shown_position(), "jump": player.shown_position()},
	}


func _state_of(verb: String, view: Dictionary) -> String:
	if verb == "haul":
		return Bindings.ball_state(view["line"], false, false, false)
	return Bindings.ball_state("", view["charging"], view["mounted"], view["airborne"])


# The state a prompt's word reads. On the pylon Space is the slingshot whether or not it is
# charging, which the ball's state ranks first.
func _word_state(verb: String, view: Dictionary) -> String:
	return "mounted" if verb == "jump" and view["mounted"] else _state_of(verb, view)


# One tick of the prompt rules over `view`; fills `shown`.
func step(delta: float, view: Dictionary) -> void:
	for verb in PROMPT_VERBS:
		_unused[verb] += delta
		if _unused[verb] >= IDLE_RETURN:
			_revived[verb] = true
	_vault = vault_anchor()
	var ready: Dictionary = view["ready"].duplicate()
	# A view that names no verb (one built before the ultimate) reads it not ready.
	for verb in PROMPT_VERBS:
		if not ready.has(verb):
			ready[verb] = false
	var vault_open: bool = _vault != Vector3.INF and view.get("jump_possible", true)
	var vault_only: bool = vault_open and not ready["jump"]
	if vault_open:
		ready["jump"] = true
	for verb in PROMPT_VERBS:
		if ready[verb] and not (verb == "jump" and vault_only):
			_forced[verb] = maxf(0.0, _forced[verb] - delta)
	var line: String = view["line"]
	if view["winching"] and not _winch_held:
		record_use("haul")
	_winch_held = view["winching"]
	# The wait counts while the line stands, ready or not, so a Warden line's SMASH shows the
	# tick its stagger opens the haul.
	if line == "" or view["winching"]:
		_stood = 0.0
	else:
		_stood += delta
	_points = view["points"].duplicate()
	if _vault != Vector3.INF:
		_points["jump"] = _vault
	_line = line
	var candidates: Array = []
	for verb in PROMPT_VERBS:
		var open: bool = ready[verb] and (verb != "haul" or _stood >= LINE_STAND)
		if not open:
			continue
		if _first[verb] or _forced[verb] > 0.0 or _revived[verb] or not retired(verb, line) or (verb == "jump" and vault_open):
			var word := word_for(verb, line, _word_state(verb, view))
			assert(word != "", "the %s prompt has no word (a key and an icon alone read as nothing)" % verb)
			candidates.append({"verb": verb, "state": _state_of(verb, view), "word": word})
	if line == "world" and _letgo_latch >= 1 and _letgo_latch <= RETIRE_AFTER[LETGO]:
		candidates.append({"verb": LETGO, "state": _state_of("haul", view), "word": LETGO_WORD})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = Bindings.STATES.find(a["state"])
		var rb: int = Bindings.STATES.find(b["state"])
		if ra != rb:
			return ra < rb
		return _order(a["verb"]) < _order(b["verb"]))
	shown = candidates.slice(0, MAX_PROMPTS)
	for prompt in shown:
		var verb: String = prompt["verb"]
		if verb != LETGO and not (verb == "jump" and vault_only) and (_first[verb] or _revived[verb]):
			_free[verb] += delta
			if _free[verb] >= FAIL_RETURN:
				_first[verb] = false
				_revived[verb] = false
				_free[verb] = 0.0
				_unused[verb] = 0.0
	var drawn_now := {}
	for prompt in shown:
		var verb: String = prompt["verb"]
		if _drawn(prompt):
			drawn_now[verb] = true
			if not _was_drawn.has(verb):
				game.events.prompt_shown.emit(verb)
	_was_drawn = drawn_now


# The dish an open deflector vault window points the jump prompt at, or Vector3.INF.
func vault_anchor() -> Vector3:
	if not is_inside_tree():
		return Vector3.INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.has_method("vault_anchor"):
			var at: Vector3 = enemy.vault_anchor()
			if at != Vector3.INF:
				return at
	return Vector3.INF


# Where a verb's prompt is anchored this tick, in the world: Vector3.INF with none.
func prompt_point(verb: String) -> Vector3:
	return _points.get(verb, Vector3.INF)


# The slot a prompt sorts into among equals: the verbs in table order, LET GO after them.
static func _order(verb: String) -> int:
	return PROMPT_VERBS.size() if verb == LETGO else PROMPT_VERBS.find(verb)


# The key glyph a prompt draws: LET GO is the harpoon's key.
static func glyph_of(verb: String) -> String:
	return Glyphs.of("harpoon" if verb == LETGO else verb)


# Whether the screen draws a prompt: its anchor is a real point, in front of the camera
# and inside the view. A reticle prompt sits at the screen centre, always in view.
func _drawn(prompt: Dictionary) -> bool:
	if prompt["verb"] in RETICLE_VERBS:
		return true
	var world: Vector3 = _points.get("haul" if prompt["verb"] == LETGO else prompt["verb"], Vector3.INF)
	if world == Vector3.INF:
		return false
	var camera = game.get("camera")
	if camera == null:
		return true
	var cam: Camera3D = camera.cam
	return not cam.is_position_behind(world) and cam.get_viewport().get_visible_rect().has_point(cam.unproject_position(world))


# The glyphs of the prompts the screen draws this tick, for the ability bar to leave its own caps off.
func shown_glyphs() -> Array[String]:
	var out: Array[String] = []
	for prompt in shown:
		if _drawn(prompt):
			out.append(glyph_of(prompt["verb"]))
	return out


# The ids of every prompt rules show this tick: the verbs and LET GO, which is a prompt and no verb.
func shown_prompts() -> Array[String]:
	var out: Array[String] = []
	for prompt in shown:
		out.append(prompt["verb"])
	return out


# The verbs shown this tick, each one a Bindings verb player.verb_ready answers.
func shown_verbs() -> Array[String]:
	var out: Array[String] = []
	for prompt in shown:
		if prompt["verb"] != LETGO:
			out.append(prompt["verb"])
	return out


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	if not visible:
		return out
	# Only the prompts the screen draws: one whose anchor left the view shows no words, and the
	# bar keeps its own cap for that key (shown_glyphs), so the count matches the picture.
	for prompt in shown:
		if not _drawn(prompt):
			continue
		out.append_array(Keycap.words(glyph_of(prompt["verb"])))
		if prompt["word"] != "":
			out.append(prompt["word"])
	return out


func _physics_process(delta: float) -> void:
	if game == null:
		return
	if not game.flow.in_play():
		shown = []
		return
	step(delta, view_of(game.player))


# Where each shown prompt sits on screen: [{verb, at, word, glyph, icon}]. Redraw only when it changes.
func _placements() -> Array:
	var out := []
	if game == null or not game.flow.in_play():
		return out
	var cam: Camera3D = game.camera.cam
	var stacked := 0
	for prompt in shown:
		if not _drawn(prompt):
			continue
		if prompt["verb"] in RETICLE_VERBS:
			# The meter arc's gap at six o'clock (aim_reticle.gd).
			var gap := (cam.get_viewport().get_visible_rect().size * 0.5 + Vector2(0.0, AimReticle.meter_radius())).round()
			out.append({"verb": prompt["verb"], "at": gap, "word": prompt["word"], "glyph": glyph_of(prompt["verb"]), "icon": ""})
			continue
		var world: Vector3 = _points.get("haul" if prompt["verb"] == LETGO else prompt["verb"], Vector3.INF)
		var at := cam.unproject_position(world).round()
		if prompt["verb"] == "jump" and _vault != Vector3.INF:
			at += AIM_OFFSET
		elif prompt["verb"] in BALL_VERBS:
			at += BALL_OFFSET + Vector2(0.0, STACK * stacked)
			stacked += 1
		elif prompt["verb"] == LETGO:
			at += AIM_OFFSET + Vector2(0.0, STACK if "haul" in shown_prompts() else 0.0)
		else:
			at += AIM_OFFSET
		out.append({"verb": prompt["verb"], "at": at, "word": prompt["word"],
			"glyph": glyph_of(prompt["verb"]),
			"icon": "" if prompt["verb"] == LETGO else icon_of(prompt["verb"], _line)})
	return out


func _process(_delta: float) -> void:
	var now := _placements()
	if now != _placed:
		_placed = now
		queue_redraw()


func _draw() -> void:
	var cap_color: Color = EventKinds.UI_ROWS["key_glyph"]["color"]
	var live := EventKinds.role_color("live")
	for placed in _placed:
		var verb: String = placed["verb"]
		var at: Vector2 = placed["at"]
		var cap := Keycap.draw(self, at, placed["glyph"], cap_color, KEY_H)
		var icon_id: String = placed["icon"]
		var edge := cap.end.x + 5.0
		if verb == LETGO:
			var arrow := Rect2(Vector2(edge, at.y - KEY_H * 0.45), Vector2(KEY_H * 0.9, KEY_H * 0.9))
			draw_texture_rect(Icons.shape("arrow"), arrow, false, live)
			edge = arrow.end.x + 5.0
		elif icon_id != "":
			var icon := Rect2(Vector2(edge, at.y - KEY_H * 0.45), Vector2(KEY_H * 0.9, KEY_H * 0.9))
			draw_texture_rect(Icons.texture(icon_id), icon, false, Icons.tint(icon_id, live))
			edge = icon.end.x + 5.0
		var word: String = placed["word"]
		if word != "":
			# Outlined, as every word drawn over the world is: the live colour alone is lost on pale sand.
			UiDraw.text(self, edge, at.y, word, WORD_SIZE, live)
