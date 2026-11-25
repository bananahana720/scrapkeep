extends Node

signal turned(voice: String)

const VOICES := ["title", "moss", "tip", "plate"]
const TAKE := -1
const TITLE := 0
const MOSS := 1
const PLATE := 3
const MOSS_TURN := 6.0
const MOSS_MIN := 0.4
const PLATE_AFTER := 4.0
const ROLLING := 1.0
const OPEN_ROW := "cold_open"

var game
var live := false
var _turn := TAKE
var _turn_age := 0.0
var _rolled := 0.0
var _entered := false
var _fresh := false
var _clear := false


func setup(game_ref) -> void:
	name = "Opening"
	game = game_ref
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var events = game.events
	events.run_started.connect(_on_run_started)
	events.stage_entered.connect(_on_stage_entered)
	events.warden_engaged.connect(func(_stage: int): finish())
	events.flow_changed.connect(func(_state: String):
		if _entered and not game.flow.in_stage():
			finish())


func waits(voice: String) -> bool:
	if not live:
		return false
	var at := VOICES.find(voice)
	return at > _turn or (at == PLATE and _rolled < PLATE_AFTER)


func turn() -> String:
	return VOICES[_turn] if live and _turn >= 0 else ""


func begin() -> void:
	finish()
	live = true
	_fresh = true
	_turn = TAKE
	_turn_age = 0.0
	_rolled = 0.0
	_entered = false
	_clear = false


func _on_run_started(_class_id: String) -> void:
	if _fresh:
		_fresh = false
	else:
		live = false


func _on_stage_entered(_stage: int, retry: bool) -> void:
	if not live:
		return
	if retry or _entered:
		finish()
		return
	_entered = true


func _process(delta: float) -> void:
	if not live:
		return
	if not _entered:
		finish()
		return
	step(delta)


func step(delta: float) -> void:
	_turn_age += delta
	if _turn >= TITLE and game.player != null and game.player.state.velocity.length() > ROLLING:
		_rolled += delta
	match _turn:
		TAKE:
			if _take_busy():
				_clear = false
			elif _clear:
				_next()
			else:
				_clear = true
		TITLE:
			if not _written_up():
				_next()
		MOSS:
			if (_turn_age >= MOSS_MIN and not _moss_up()) or _turn_age >= MOSS_TURN:
				while _turn < PLATE:
					_next()
		PLATE:
			if _rolled >= PLATE_AFTER:
				finish()


func _next() -> void:
	_turn += 1
	_turn_age = 0.0
	turned.emit(VOICES[_turn])


func finish() -> void:
	if not live:
		return
	live = false
	_fresh = false
	for at in range(_turn + 1, VOICES.size()):
		turned.emit(VOICES[at])


func _take_busy() -> bool:
	var take = game.get("launch_take")
	return take != null and take.busy()


func _written_up() -> bool:
	var flourish = game.presentation.get("flourish") if game.get("presentation") != null else null
	return flourish != null and flourish.reading(OPEN_ROW)


func _moss_up() -> bool:
	var host = game.get_node_or_null("Workshop")
	var bubble = host.get("bubble") if host != null else null
	return bubble != null and bubble.showing()
