extends Control

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/core/icons.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")
const CallerTile := preload("res://src/ui/caller_tile.gd")
const ScreenRegions := preload("res://src/core/screen_regions.gd")
const Comfort := preload("res://src/core/comfort.gd")


const TEXT_WIDTH := 330.0
const FONT := UiTokens.BODY
const PAD := Vector2(20.0, 14.0)
const TAIL := 28.0
const RADIUS := 18.0
const TOOTH := 16.0
const MAX_EXASPERATION := 5
const HOLD_BASE := 1.6
const HOLD_PER_WORD := 0.3
const FADE := 0.25
const HAND := 15.0
const GESTURE_SECONDS := 0.6
const INTRO_HOLD := 4.0
const KEEP_CLEAR_GROUP := "speech_keep_clear"
const KEEP_CLEAR_GAP := 8.0
const SEAT_SPEED := 900.0
const PLATE_AT := Vector2(6.0, 4.0)
const PLATE_LEAD := CallerTile.SIDE - 8.0
const PLATE_HEAD := 10.0


var text := ""
var kind := "moss_beat"
var mood := ""
var exasperation := 0.0
var shown_exasperation := 0.0
var grumble := false
var sticky := false
var gesture := ""
var _label: Label
var _tile: CallerTile
var _lead := 0.0
var _head := 0.0
var _clock := 0.0
var _hold := 0.0
var _gesture_clock := 0.0
var _body := Vector2.ZERO
var _seat_base := 0.0
var _seated_y := -1.0
var _spin := 0.0
var _pop := 1.0
var _tween: Tween
var _game
var _exchange: Array = []
var _exchange_index := 0
var _exchange_held := false
var _zones_played := {}
var _intros_played := {}
var _intro_queue: Array = []
var _intro_showing := false
var _intro_row := {}
var _hello_due := 0
var _calls_played := {}
var _pair_call_used := false
var _call := {}
var _call_fresh := 0.0
var _call_quiet := LoreRows.CALL_GAP_S
var _took_interact := -1000


class ExchangeInput extends Node:
	var bubble

	func _input(event: InputEvent) -> void:
		bubble._exchange_input(event)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)
	_label.add_theme_font_override("font", UiFonts.bold())
	_label.add_theme_font_size_override("font_size", FONT)
	_label.add_theme_color_override("font_color", Palette.SAND)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_tile = CallerTile.new()
	_tile.name = "Caller"
	_tile.position = PLATE_AT
	add_child(_tile)


func _ready() -> void:
	_game = get_parent().game
	_install_exchange_input.call_deferred()
	_game.events.run_started.connect(_on_run_started)
	_game.events.stage_entered.connect(_on_stage_entered)
	_game.events.warden_sighted.connect(_on_warden_sighted)
	_game.events.warden_engaged.connect(_on_warden_engaged)
	_game.events.boss_arena_entered.connect(_on_boss_arena_entered)
	_connect_calls()
	_game.events.shot_fired.connect(func(_w: String, _from: Vector3, _to: Vector3): _end_exchange())
	_game.events.grapple_fired.connect(func(_anchor: Vector3): _end_exchange())
	_game.events.flow_changed.connect(func(_state: String):
		if not _game.flow.in_stage():
			_end_exchange()
		if not _game.flow.in_play():
			_end_intro()
			_end_call())


func _install_exchange_input() -> void:
	var listener := ExchangeInput.new()
	listener.name = "LoreExchangeInput"
	listener.bubble = self
	listener.process_mode = Node.PROCESS_MODE_ALWAYS
	_game.add_child(listener)


func _on_run_started(_class_id: String) -> void:
	_end_exchange(false)
	_end_intro()
	_calls_played.clear()
	_pair_call_used = false
	_call = {}
	_call_quiet = LoreRows.CALL_GAP_S
	if mood == "call":
		_clear_line()
	_hello_due = 0
	_took_interact = -1000
	_zones_played.clear()
	_intros_played.clear()


func _on_stage_entered(stage: int, _retry: bool) -> void:
	_end_exchange(false)
	_end_intro()
	_hello_due = 0
	_begin_exchange.call_deferred(stage)


func _begin_exchange(stage: int) -> void:
	_hello_due = 0
	if stage != _game.run.stage or not _game.flow.in_stage() or _game.flow.engaged():
		return
	if _waits() or _reading() or _call_up():
		_hello_due = stage
		return
	var zone := "%d-%d" % [_game.ctx.stages.world_of(stage), _game.ctx.stages.local(stage)]
	if _zones_played.has(zone):
		return
	var exchange_id := ""
	for row in LoreRows.ROWS:
		if row["kind"] == "exchange" and row["zone"] == zone:
			if exchange_id == "":
				exchange_id = row["exchange"]
			if row["exchange"] == exchange_id:
				_exchange.append(row)
	if _exchange.is_empty():
		return
	_zones_played[zone] = true
	_exchange_index = 0
	position = Vector2(0.0, get_viewport().get_visible_rect().size.y * 0.30)
	_show_exchange_line()


func _zone_of(stage: int) -> String:
	return "%d-%d" % [_game.ctx.stages.world_of(stage), _game.ctx.stages.local(stage)]


func _on_warden_sighted(stage: int) -> void:
	_queue_intro(_zone_of(stage), true)


func _on_warden_engaged(_stage: int) -> void:
	_end_exchange(false)
	_end_intro()


func _on_boss_arena_entered() -> void:
	_queue_intro(_zone_of(_game.run.stage), false)


func _queue_intro(zone: String, warden: bool) -> void:
	var key := "%s/%s" % [zone, "warden" if warden else "boss"]
	if _intros_played.has(key) or _intro_queue.any(func(queued): return queued["intro_key"] == key):
		return
	var pilot: String = _game.run.class_id()
	var chosen := {}
	for row in LoreRows.ROWS:
		if row["kind"] == "intro" and row["zone"] == zone and (row.get("subject", "") == "warden") == warden:
			if row.get("pilot", pilot) != pilot:
				continue
			chosen = row
			if row.has("pilot"):
				break
	if not chosen.is_empty():
		var entry := chosen.duplicate()
		entry["intro_key"] = key
		_intro_queue.append(entry)
	_flush_intro()


func _waits() -> bool:
	if get_tree().paused or _close_up():
		return true
	var opening = _game.get("opening")
	return opening != null and opening.waits("moss")


func _close_up() -> bool:
	var presentation = _game.get("presentation")
	return presentation != null and presentation.close_up()


func _flush_intro() -> void:
	if _intro_queue.is_empty() or not _exchange.is_empty() or _hello_due > 0 or _waits():
		return
	if _yields(_intro_queue[0]) and _reading():
		return
	var row: Dictionary = _intro_queue.pop_front()
	_intro_row = row
	_intros_played[String(row["intro_key"])] = true
	position = Vector2(0.0, get_viewport().get_visible_rect().size.y * 0.30)
	var who := LoreRows.world_voice_of(row)
	var voice_s := _voice(who, LoreRows.spoken(row))
	_say(String(row["text"]), "moss_beat", "intro", 0.0, false, "", who, voice_s)
	_hold = maxf(INTRO_HOLD, voice_s)
	_intro_showing = true


func _yields(row: Dictionary) -> bool:
	return row.get("subject", "") == "warden"


func _end_intro() -> void:
	_intro_queue.clear()
	_intro_row = {}
	if _intro_showing:
		_intro_showing = false
		_clear_line()


func _show_exchange_line() -> void:
	var line: Dictionary = _exchange[_exchange_index]
	var who := LoreRows.world_voice_of(line)
	_say("%s: %s" % [line["speaker"], line["text"]], "moss_beat", "exchange", 0.0, false, "", who, _voice(who, String(line["text"])))


func _advance_exchange() -> void:
	_exchange_index += 1
	if _exchange_index >= _exchange.size():
		_end_exchange()
	else:
		_show_exchange_line()


func _end_exchange(flush := true) -> void:
	if _exchange.is_empty():
		return
	_exchange.clear()
	_exchange_index = 0
	_exchange_held = false
	_clear_line()
	if flush:
		_flush_intro()


func _clear_line() -> void:
	if _tween != null:
		_tween.kill()
	_hold = 0.0
	text = ""
	_label.text = ""
	_tile.clear()
	_end_voice()
	visible = false
	modulate.a = 0.0


func _exchange_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if _intro_showing:
		if event.is_action_pressed("cl_interact") or event.is_action_pressed("cl_fire") or event.is_action_pressed("cl_harpoon"):
			if event.is_action_pressed("cl_interact"):
				_took_interact = Engine.get_physics_frames()
			_end_intro()
		return
	if _exchange.is_empty():
		return
	if event.is_action_pressed("cl_interact"):
		if _exchange_held:
			return
		_took_interact = Engine.get_physics_frames()
		_advance_exchange()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cl_fire") or event.is_action_pressed("cl_harpoon"):
		_end_exchange()


func takes_interact() -> bool:
	return _intro_showing or (not _exchange.is_empty() and not _exchange_held) \
			or Engine.get_physics_frames() - _took_interact <= 1


func dismiss_exchange() -> void:
	_end_exchange()


func stand_down() -> void:
	_hello_due = 0
	_call = {}
	_end_exchange(false)
	_end_intro()
	hush()


func _connect_calls() -> void:
	var relays := [_call_event_0, _call_event_1, _call_event_2, _call_event_3, _call_event_4]
	var wanted := {}
	for name in LoreRows.call_signals():
		wanted[String(name)] = true
	for row in LoreRows.WORLD_CALLS:
		wanted[String(row["on"])] = true
	for pid in PilotStory.PAIRS:
		wanted[String(PilotStory.PAIRS[pid]["field"]["on"])] = true
	wanted["enemy_killed"] = true
	wanted["world_fact"] = true
	for sig in _game.events.get_signal_list():
		var arity: int = (sig["args"] as Array).size()
		if wanted.has(sig["name"]) and arity < relays.size():
			_game.events.connect(sig["name"], relays[arity].bind(sig["name"]))


func _call_event_0(event: String) -> void:
	call_caused(event, [])


func _call_event_1(a, event: String) -> void:
	call_caused(event, [a])


func _call_event_2(a, b, event: String) -> void:
	call_caused(event, [a, b])


func _call_event_3(a, b, c, event: String) -> void:
	call_caused(event, [a, b, c])


func _call_event_4(a, b, c, d, event: String) -> void:
	call_caused(event, [a, b, c, d])


func call_caused(event: String, args: Array) -> Dictionary:
	if _call_quiet < LoreRows.CALL_GAP_S or not _call.is_empty() or not _game.flow.in_play() or _fight():
		return {}
	var row := _call_for(event, args)
	if row.is_empty():
		return {}
	_call = row
	_call_fresh = LoreRows.CALL_FRESH_S
	_tick_call(0.0)
	return row


func _call_for(event: String, args: Array) -> Dictionary:
	var world: int = _game.ctx.stages.world_of(_game.run.stage)
	var unlocked: Array = []
	for def in _game.flow.classes:
		if _game.pilot_unlocked(def):
			unlocked.append(String(def.id))
	var story_row := PilotStory.pick_run_call(
		event, args, world, _game.run.class_id(), _game.run.run_seed,
		unlocked, _game.ctx.profile, _game.codex, _calls_played, _pair_call_used
	)
	if not story_row.is_empty():
		return story_row
	var pilots: Array = []
	for row in LoreRows.CALLS:
		if _calls_played.has(row["id"]) or int(row["world"]) != world or not LoreRows.call_matches(row, event, args):
			continue
		if not _call_holds(row):
			continue
		if not row.has("pilot"):
			return row
		if row["pilot"] != _game.run.class_id() and _pilot_free(row["pilot"]):
			pilots.append(row)
	return pilots[absi(_game.run.run_seed) % pilots.size()] if not pilots.is_empty() else {}


func _call_holds(row: Dictionary) -> bool:
	if row.get("when", "") != "low_hull":
		return true
	return _game.run.hp > 0.0 and _game.run.hp < _game.run.max_hp * LoreRows.CALL_LOW_HULL


func _fight() -> bool:
	var flow = _game.flow
	return flow.warden_fight_live() or (flow.state_name() == "boss" and flow.boss_active)


func _pilot_free(class_id: String) -> bool:
	for def in _game.flow.classes:
		if def.id == class_id:
			return _game.pilot_unlocked(def)
	return false


func _reading() -> bool:
	var presentation = _game.get("presentation")
	return presentation != null and presentation.reading()


func _call_up() -> bool:
	return visible and mood == "call"


func _end_call() -> void:
	_call = {}
	if _call_up():
		hush()


func _call_may_speak() -> bool:
	if not _game.flow.in_play() or _waits() or _fight() or _reading():
		return false
	var opening = _game.get("opening")
	if opening != null and opening.live:
		return false
	return not visible and _exchange.is_empty() and _intro_queue.is_empty() and _hello_due == 0


func _tick_call(delta: float) -> void:
	_call_quiet += delta
	if _call_up() and _fight():
		hush()
	if _call.is_empty():
		return
	if _call_may_speak():
		var row := _call
		_call = {}
		if not _call_holds(row):
			return
		_calls_played[row["id"]] = true
		if bool(row.get("consumes_pair_budget", false)):
			_pair_call_used = true
		var codex_id := String(row.get("codex_id", ""))
		if codex_id != "" and _game.codex != null and _game.codex.has_method("mark_known"):
			_game.codex.mark_known(codex_id)
		for other in LoreRows.CALLS:
			if other["id"] == row["id"] or (row.has("pilot") and row.has("on") and other.has("pilot") and other["on"] == row["on"]):
				_calls_played[other["id"]] = true
		_call_quiet = 0.0
		var words := LoreRows.call_text(row, _game.run.run_seed)
		_present(String(row["speaker"]), words, _voice(String(row["speaker"]), words))
		return
	_call_fresh -= delta
	if _call_fresh <= 0.0:
		_call = {}


func _voice(speaker: String, words: String) -> float:
	_end_voice()
	var audio = _audio()
	return float(audio.call_in("call_in", speaker, words)) if audio != null and speaker != "" else 0.0


func _end_voice() -> void:
	var audio = _audio()
	if audio != null:
		audio.call_end()


func _audio():
	var presentation = _game.get("presentation") if _game != null else null
	return presentation.get("audio") if presentation != null else null


func _present(speaker: String, words: String, voice_s: float) -> void:
	position = Vector2(0.0, get_viewport().get_visible_rect().size.y * 0.30)
	_say("%s: %s" % [LoreRows.SPEAKERS.get(speaker, speaker), words], "moss_beat", "call", 0.0, false, "", speaker, voice_s)
	_hold = maxf(_hold, voice_s)


func row() -> Dictionary:
	return EventKinds.LOOT_ROWS.get(kind, EventKinds.LOOT_ROWS["moss_beat"])


func showing() -> bool:
	return visible and modulate.a > 0.05 and text != ""


func beat(record: Dictionary) -> void:
	if record.is_empty():
		return
	_end_exchange(false)
	_intro_showing = false
	_end_voice()
	var mood_now := "beat"
	if record.get("relent", false):
		mood_now = "relent"
	elif record.get("restart", false):
		mood_now = "restart"
	var level := 0.0 if mood_now != "beat" else float(record.get("exasperation", 0))
	_say(String(record.get("text", "")), "moss_relent" if mood_now == "relent" else "moss_beat", mood_now,
		level, bool(record.get("grumble", false)), "give" if mood_now == "relent" else "tap")


func bark(line: Dictionary, fact: String) -> void:
	if line.is_empty():
		return
	_end_exchange(false)
	_intro_showing = false
	_end_voice()
	var refused := fact == "shop_refused"
	_say(String(line.get("text", "")), fact, "refuse" if refused else "bark", 0.0, refused,
		"refuse" if refused else ("give" if fact in ["shop_bought", "shop_charge", "shop_sold"] else ""))


func hush(spoken := false) -> void:
	_end_exchange(false)
	_intro_showing = false
	_hold = 0.0
	if not visible:
		return
	_tile.quiet()
	if not spoken:
		_end_voice()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		if _hold <= 0.0:
			visible = false)


func _say(line: String, fact: String, mood_now: String, level: float, grumbles: bool, hand: String, who := "", voice_s := 0.0) -> void:
	var words := _seat_caller(who, line, voice_s)
	text = line
	kind = fact
	mood = mood_now
	exasperation = clampf(level, 0.0, MAX_EXASPERATION)
	grumble = grumbles
	gesture = hand
	_gesture_clock = 0.0
	_clock = 0.0
	_label.text = words
	_label.add_theme_color_override("font_color", Palette.SAND)
	_label.size = Vector2(TEXT_WIDTH, 0.0)
	_body = Vector2(TEXT_WIDTH, _label.get_minimum_size().y + _head) + PAD * 2.0
	_label.position = Vector2(TAIL + _lead, _head) + PAD
	size = Vector2(TAIL + _lead + _body.x + 12.0, _body.y + HAND * 3.5)
	pivot_offset = Vector2(0.0, _body.y * 0.5)
	_hold = HOLD_BASE + HOLD_PER_WORD * line.split(" ", false).size()
	visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.12).set_ease(Tween.EASE_OUT)
	var still := Comfort.reduced_motion
	match mood_now:
		"restart":
			_spin = 0.0 if still else -0.35
			_pop = 1.0 if still else 0.7
			_tween.tween_property(self, "_spin", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "_pop", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "shown_exasperation", 0.0, 0.45)
		"relent":
			_spin = 0.0
			_pop = 1.0 if still else 0.6
			_tween.tween_property(self, "_pop", 1.0, 0.4).set_trans(UiTokens.hand(UiTokens.Hand.KEEPER).trans).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "shown_exasperation", 0.0, 0.3)
		_:
			_spin = 0.0
			_pop = 1.0 if still else (0.9 if grumbles else 0.96)
			_tween.tween_property(self, "_pop", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "shown_exasperation", exasperation, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _seat_caller(who: String, line: String, voice_s: float) -> String:
	var shown := String(LoreRows.SPEAKERS.get(who, ""))
	if _game != null and _game.flow != null:
		_tile.pilots = _game.flow.classes
	var named := shown != "" and _tile.present(who, shown, voice_s)
	if not named:
		_tile.clear()
	_lead = PLATE_LEAD if named else 0.0
	_head = PLATE_HEAD if named else 0.0
	return line.trim_prefix(shown + ": ") if named else line


func caller() -> String:
	return _tile.speaker if visible and _tile.visible else ""


func _tick_turn() -> void:
	if _exchange_held:
		if _rolled_off():
			_end_exchange()
		elif not _reading() and not _waits():
			_exchange_held = false
			_show_exchange_line()
		return
	if not visible or not _reading():
		return
	if not _exchange.is_empty():
		_exchange_held = true
		_clear_line()
	elif _intro_showing and _yields(_intro_row):
		_intro_queue.push_front(_intro_row)
		_intro_showing = false
		_clear_line()


func _rolled_off() -> bool:
	return _game.player != null and _game.player.state.velocity.length() > _game.ctx.tuning.f("cruise")


func _process(delta: float) -> void:
	_tick_call(delta)
	_tick_turn()
	if _hello_due > 0 and not _waits():
		_begin_exchange(_hello_due)
	if not _intro_queue.is_empty() and not visible:
		_flush_intro()
	if not visible:
		return
	_clock += delta
	_gesture_clock += delta
	_seat(delta)
	if not _exchange.is_empty() and _rolled_off():
		_end_exchange()
		return
	if _exchange.is_empty() and not sticky and _hold > 0.0 and not get_tree().paused:
		_hold -= delta
		if _hold <= 0.0:
			hush(true)
	queue_redraw()


func _seat(delta: float) -> void:
	if not is_inside_tree():
		return
	if not is_equal_approx(position.y, _seated_y):
		_seat_base = position.y
	var rects: Array[Rect2] = []
	for node in get_tree().get_nodes_in_group(KEEP_CLEAR_GROUP):
		if node.has_method("keep_clear_rects"):
			rects.append_array(node.keep_clear_rects())
	var limit := ScreenRegions.rect("prompts", get_viewport().get_visible_rect().size).position.y
	var want := seat_y(_seat_base, Rect2(position.x, _seat_base, size.x, size.y), rects, limit)
	position.y = move_toward(position.y, want, SEAT_SPEED * delta)
	_seated_y = position.y


static func seat_y(base_y: float, box: Rect2, rects: Array[Rect2], limit_y: float) -> float:
	var y := base_y
	for _pass in rects.size() + 1:
		var moved := false
		for r in rects:
			if r.intersects(Rect2(box.position.x, y, box.size.x, box.size.y)):
				y = r.end.y + KEEP_CLEAR_GAP
				moved = true
		if not moved:
			break
	return minf(y, maxf(base_y, limit_y - box.size.y))


func outline(e: float) -> PackedVector2Array:
	var r := maxf(3.0, RADIUS - e * 3.0)
	var box := Rect2(Vector2(TAIL + _lead, 0.0), _body)
	var corners := [
		[box.position + Vector2(r, r), PI, PI * 1.5],
		[Vector2(box.end.x - r, box.position.y + r), PI * 1.5, TAU],
		[box.end - Vector2(r, r), 0.0, PI * 0.5],
		[Vector2(box.position.x + r, box.end.y - r), PI * 0.5, PI],
	]
	var ring := PackedVector2Array()
	for c in corners:
		for step in 5:
			var a: float = lerpf(c[1], c[2], step / 4.0)
			ring.append(c[0] + Vector2(cos(a), sin(a)) * r)
	if e <= 0.05:
		return ring
	var toothed := PackedVector2Array()
	var amp := e * 1.6
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		toothed.append(a)
		var n := int(a.distance_to(b) / TOOTH)
		if n < 1:
			continue
		var normal := (b - a).orthogonal().normalized()
		for k in n:
			var rise := a.lerp(b, (k + 0.3) / n)
			var fall := a.lerp(b, (k + 0.7) / n)
			toothed.append_array([rise, rise + normal * amp, fall + normal * amp, fall])
	return toothed


func _draw() -> void:
	if text == "":
		return
	var e := shown_exasperation
	var shake := Vector2(sin(_clock * TAU * 13.0), cos(_clock * TAU * 11.0)) * (e * 0.8 + (3.0 if grumble else 0.0)) * exp(-_clock * 5.0)
	if Comfort.reduced_motion:
		shake = Vector2.ZERO
	var squash := Vector2(1.0 / _pop, _pop) if grumble and mood == "beat" else Vector2(_pop, _pop)
	draw_set_transform(pivot_offset + shake, _spin, squash)
	var root := -pivot_offset
	var edge: Color = _tile.tint() if _tile.visible else row().get("color", Palette.SAND)
	if mood == "relent":
		var star := Icons.shape(String(row().get("shape", "star")))
		var burst := _body.y * 1.6
		draw_texture_rect(star, Rect2(root + Vector2(TAIL + _lead + _body.x - burst * 0.5, -burst * 0.3), Vector2(burst, burst)), false, Color(edge, 0.35))
	var body := outline(e)
	var shifted := PackedVector2Array()
	for p in body:
		shifted.append(p + root)
	var mid_y := _body.y * 0.5
	var wag := 0.0 if Comfort.reduced_motion else sin(_clock * TAU * 3.0) * e * 1.5
	var tip := -4.0 if _lead == 0.0 else PLATE_AT.x + CallerTile.SIDE + 2.0
	var tail := PackedVector2Array([root + Vector2(TAIL + _lead + 2.0, mid_y - 10.0), root + Vector2(tip, mid_y + 8.0 + wag), root + Vector2(TAIL + _lead + 2.0, mid_y + 10.0)])
	draw_colored_polygon(tail, Color(Palette.CHARCOAL, 0.94))
	draw_colored_polygon(shifted, Color(Palette.CHARCOAL, 0.94))
	shifted.append(shifted[0])
	draw_polyline(shifted, edge, 3.0 if mood == "relent" else 2.0 + e * 0.3)
	draw_line(tail[0], tail[1], edge, 2.0)
	draw_line(tail[1], tail[2], edge, 2.0)
	var glyph := String(row().get("shape", "none"))
	if glyph != "none" and mood in ["refuse", "bark"]:
		draw_texture_rect(Icons.shape(glyph), Rect2(root + Vector2(TAIL + _lead + _body.x - 14.0, -10.0), Vector2(24.0, 24.0)), false, edge)
	draw_set_transform(Vector2.ZERO)
	_label.position = Vector2(TAIL + _lead, _head) + PAD + shake
	_draw_hand(Vector2(0.0, _body.y + HAND * 1.8), edge)


func _draw_hand(at: Vector2, edge: Color) -> void:
	var t := clampf(_gesture_clock / GESTURE_SECONDS, 0.0, 1.0)
	if gesture == "" or t >= 1.0:
		return
	var reach := sin(t * PI)
	var p := at
	var angle := 0.0
	match gesture:
		"give":
			p.x += -HAND + reach * HAND * 3.0
		"tap":
			p.x += HAND * 0.8
			p.y += -absf(sin(t * TAU * 2.0)) * HAND * 0.7
		"refuse":
			p.x += HAND * 1.2 * reach
			angle = sin(t * TAU * 3.0) * 0.35
	draw_set_transform(p, angle, Vector2.ONE)
	var palm := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		palm.append(Vector2(cos(a) * HAND, sin(a) * HAND * 0.8))
	draw_colored_polygon(palm, Palette.SANDSTONE)
	palm.append(palm[0])
	draw_polyline(palm, Palette.CHARCOAL, 2.0)
	var fingers := 4
	for i in fingers:
		var x := -HAND * 0.6 + i * HAND * 0.4
		var tip := Vector2(x, -HAND * 1.35) if gesture == "refuse" else Vector2(HAND * 1.35, -HAND * 0.5 + i * HAND * 0.33)
		var base := Vector2(x, -HAND * 0.5) if gesture == "refuse" else Vector2(HAND * 0.5, -HAND * 0.5 + i * HAND * 0.33)
		draw_line(base, tip, Palette.CHARCOAL, 7.0)
		draw_line(base, tip, Palette.SANDSTONE, 4.5)
	draw_set_transform(Vector2.ZERO)
