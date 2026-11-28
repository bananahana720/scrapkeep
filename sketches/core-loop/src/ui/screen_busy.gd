extends Node

const WhyCallout := preload("res://src/ui/why_callout.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")


const SETTLE := 2.0
const FIND_HOLD := WhyCallout.CALM_SECONDS
const ASK_WINDOW := 0.3

var _sources: Array[Callable] = []
var _combat := false
var _fights := {}
var _quiet_for := INF
var _waiting: Array[String] = []
var _firsts := {}
var _holder := ""
var _clock := 0.0
var _asked := {}
var _flow = null


func setup(ctx) -> void:
	name = "ScreenBusy"
	_flow = ctx.flow
	var events = ctx.events
	events.pressure_changed.connect(func(pressure: float): _combat = MixRows.combat_after(_combat, pressure))
	events.fight_phase_changed.connect(func(id: String, _phase: int, _phases: int): _fights[id] = true)
	events.boss_arena_entered.connect(func(): _fights["boss"] = true)
	events.enemy_killed.connect(func(kind: String, _at: Vector3, _scrap: int): _fights.erase(kind))
	events.boss_defeated.connect(func(): _fights.erase("boss"))
	events.beacon_unsealed.connect(func(_stage: int): fight_over())
	events.run_started.connect(func(_class_id: String): fight_over(); drop_all())
	events.stage_entered.connect(func(_stage: int, _retry: bool): fight_over())
	events.stage_content_cleared.connect(func(reason: String):
		if reason != "arena_retry":
			_fights.clear())
	events.run_ended.connect(func(_won: bool): drop_all())
	events.player_hit.connect(func(_amount: float, _source: String): _quiet_for = 0.0)


func add_source(source: Callable) -> void:
	_sources.append(source)


func fight_over() -> void:
	_combat = false
	_fights.clear()


func fighting() -> bool:
	return _combat or not _fights.is_empty() or (_flow != null and _flow.warden_fight_live())


func busy() -> bool:
	if fighting():
		return true
	for source in _sources:
		if source.call():
			return true
	return false


func settled(hold := SETTLE) -> bool:
	if is_inside_tree() and get_tree().paused:
		return false
	return _quiet_for >= hold and not busy()


func request(key: String, first := false) -> void:
	if key == "" or key == _holder or _firsts.has(key):
		return
	if first:
		_waiting.erase(key)
		var at := 0
		while at < _waiting.size() and _firsts.has(_waiting[at]):
			at += 1
		_waiting.insert(at, key)
		_firsts[key] = true
	elif not key in _waiting:
		_waiting.append(key)


func ready(key: String) -> void:
	_asked[key] = _clock


func may_show(key: String, hold := SETTLE) -> bool:
	_asked[key] = _clock
	if key == _holder:
		return true
	request(key)
	if _holder != "" or not settled(hold):
		return false
	for older in _waiting:
		if older == key:
			break
		if _clock - float(_asked.get(older, -1000.0)) <= ASK_WINDOW:
			return false
	_waiting.erase(key)
	_holder = key
	return true


func take(key: String) -> bool:
	_asked[key] = _clock
	if key == _holder:
		return true
	if _holder != "":
		return false
	_waiting.erase(key)
	_holder = key
	return true


func done(key: String) -> void:
	_waiting.erase(key)
	_asked.erase(key)
	_firsts.erase(key)
	if _holder == key:
		_holder = ""


func give_back(key: String) -> void:
	if _holder == key:
		_holder = ""
	_waiting.erase(key)
	_waiting.insert(0, key)


func waiting() -> Array[String]:
	return _waiting.duplicate()


func showing() -> String:
	return _holder


func drop_all() -> void:
	_waiting.clear()
	_asked.clear()
	_firsts.clear()
	_holder = ""


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_clock += delta
	var tree := get_tree() if is_inside_tree() else null
	if busy() or WhyCallout.threat_live(tree):
		_quiet_for = 0.0
	else:
		_quiet_for += delta
