extends Node

const WhyCallout := preload("res://src/ui/why_callout.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")

# Is the screen busy? The one answer (PF-19), read by every card that can wait: a record, a
# B-side, an achievement, a look, a field note, a synergy, a fleet grade find. A card asks
# may_show(key) each frame; it is told yes only when the screen has been quiet for SETTLE seconds
# of game time and the card is the oldest one waiting, and then it holds the screen alone until
# it calls done(key). Nothing a player must act on ever asks: those cards show when they are due.
#
# Busy is read from what is already published, never from a card: the fight on the bus
# (pressure_changed with the mix's own hysteresis, fight_phase_changed, boss_arena_entered, the
# Warden fight the flow reports), plus the screens that register themselves with add_source (the
# kit pick, the briefing card, the reward crate). A waiting card is dropped when the run ends;
# the run summary lists what was earned.

const SETTLE := 2.0

var _sources: Array[Callable] = []
var _pressure_fight := false
var _phase_fight := false
var _arena_fight := false
var _quiet_for := SETTLE
var _waiting: Array[String] = []
var _holder := ""
var _flow = null


func setup(ctx) -> void:
	name = "ScreenBusy"
	_flow = ctx.flow
	var events = ctx.events
	events.pressure_changed.connect(_on_pressure)
	events.fight_phase_changed.connect(func(_id: String, _phase: int, _phases: int): _phase_fight = true)
	events.boss_arena_entered.connect(func(): _arena_fight = true)
	events.boss_defeated.connect(_end_fights)
	events.run_started.connect(func(_class_id: String): _end_fights(); drop_all())
	events.stage_entered.connect(func(_stage: int, _retry: bool): _end_fights())
	events.run_ended.connect(func(_won: bool): drop_all())
	events.player_died.connect(drop_all)


# A screen that holds the fight's attention while it is up: a Callable returning true while it is.
func add_source(source: Callable) -> void:
	_sources.append(source)


func _on_pressure(pressure: float) -> void:
	if pressure >= MixRows.COMBAT_ON:
		_pressure_fight = true
	elif pressure < MixRows.COMBAT_OFF:
		_pressure_fight = false
		_phase_fight = false


func _end_fights() -> void:
	_pressure_fight = false
	_phase_fight = false
	_arena_fight = false


# A fight is on: pressure, a boss phase, the boss arena or a Warden standing and engaged.
func fighting() -> bool:
	return _pressure_fight or _phase_fight or _arena_fight or WhyCallout.warden_fight_live(_flow)


# A fight is on, or a pick, briefing or crate is up.
func busy() -> bool:
	if fighting():
		return true
	for source in _sources:
		if source.call():
			return true
	return false


# A card that wants the screen joins the line, oldest first.
func request(key: String) -> void:
	if key != "" and not key in _waiting and key != _holder:
		_waiting.append(key)


# True when `key` may show now. It takes the screen on the first yes and keeps it until done.
func may_show(key: String) -> bool:
	if key == _holder:
		return true
	request(key)
	if _holder != "" or _quiet_for < SETTLE or busy() or _waiting[0] != key:
		return false
	_waiting.erase(key)
	_holder = key
	return true


# The card is gone, shown or dropped; the next one in line may come at once.
func done(key: String) -> void:
	_waiting.erase(key)
	if _holder == key:
		_holder = ""


func waiting() -> Array[String]:
	return _waiting.duplicate()


# A run ended: what still waits is not shown. The summary lists what was earned.
func drop_all() -> void:
	_waiting.clear()
	_holder = ""


func _process(delta: float) -> void:
	if busy():
		_quiet_for = 0.0
	else:
		_quiet_for += delta
