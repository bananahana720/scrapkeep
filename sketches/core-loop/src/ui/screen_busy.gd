extends Node

const WhyCallout := preload("res://src/ui/why_callout.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")

# Is the screen busy? The one answer (PF-19), read by every card that can wait: a record, a
# take, an achievement, a look, a field note, a synergy, a fleet grade find, and the crate (which
# holds the slot like a card, and while it is up counts as busy through add_source). A
# card asks may_show(key) each frame; it is told yes only when the screen has been quiet long
# enough and the card is the oldest one ready, and then it holds the screen alone until it
# calls done(key). Nothing a player must act on ever asks: those cards show when they are due.
#
# Quiet means none of these in the last `hold` seconds of game time: a fight (the stage's
# pressure through MixRows.combat_after, the one hysteresis the music uses too; a named fight
# that has entered a phase and whose enemy has not died; the Warden), a screen that registered
# itself with add_source (the kit pick, the briefing card, the crate), damage to the player, a
# live telegraph. SETTLE is the usual hold; a kind that must wait longer on purpose passes it.
# A card still waiting when the run ends is dropped. Whether the fact survives is up to the
# card's owner; the achievements page keeps an achievement.

const SETTLE := 2.0
# The longer hold the finds keep from before this gate: no damage or telegraph for this long.
const FIND_HOLD := WhyCallout.CALM_SECONDS
# A card asks every frame while it is ready to show. One that has not asked within this many
# seconds is not ready (its own module holds it back), and a younger card may go ahead of it.
const ASK_WINDOW := 0.3

var _sources: Array[Callable] = []
var _combat := false
var _fights := {}
# A screen nothing has disturbed yet has been quiet for as long as any hold asks (a find's card
# at a calm start showed at once before this gate, and still does).
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
	# A named fight is live from its first phase until its own enemy dies.
	events.fight_phase_changed.connect(func(id: String, _phase: int, _phases: int): _fights[id] = true)
	events.boss_arena_entered.connect(func(): _fights["boss"] = true)
	events.enemy_killed.connect(func(kind: String, _at: Vector3, _scrap: int): _fights.erase(kind))
	events.boss_defeated.connect(func(): _fights.erase("boss"))
	events.beacon_unsealed.connect(func(_stage: int): fight_over())
	events.run_started.connect(func(_class_id: String): fight_over(); drop_all())
	events.stage_entered.connect(func(_stage: int, _retry: bool): fight_over())
	# The field's machines are freed without a kill when the arena opens or a lap turns: their
	# named fights go with them. A retry inside the arena keeps the Warden's own fight.
	events.stage_content_cleared.connect(func(reason: String):
		if reason != "arena_retry":
			_fights.clear())
	events.run_ended.connect(func(_won: bool): drop_all())
	events.player_hit.connect(func(_amount: float, _source: String): _quiet_for = 0.0)


# A screen that holds the fight's attention while it is up: a Callable returning true while it is.
func add_source(source: Callable) -> void:
	_sources.append(source)


# Every named fight is over (a stage starts, a Warden breaks).
func fight_over() -> void:
	_combat = false
	_fights.clear()


# A fight is on: pressure, a named fight with its enemy alive, or a Warden standing and engaged.
func fighting() -> bool:
	return _combat or not _fights.is_empty() or WhyCallout.warden_fight_live(_flow)


# A fight is on, or a pick, briefing or crate is up.
func busy() -> bool:
	if fighting():
		return true
	for source in _sources:
		if source.call():
			return true
	return false


# The screen is not busy and has been quiet for `hold` seconds. A paused tree is never settled:
# a waiting card waits for play to resume (the finds' rule from WhyCallout.is_calm).
func settled(hold := SETTLE) -> bool:
	if is_inside_tree() and get_tree().paused:
		return false
	return _quiet_for >= hold and not busy()


# A card that wants the screen joins the line, oldest first. A moment that matters more (a finished
# set) asks `first`: it goes ahead of every other card waiting and behind an earlier `first`,
# never off the one on screen.
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


# A card that is ready but behind the one on screen says so, so it stays ahead of younger cards.
func ready(key: String) -> void:
	_asked[key] = _clock


# True when `key` may show now. It takes the screen on the first yes and keeps it until done.
# Ask every frame while the card is ready: the oldest ready card goes first.
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


# A screen that does not wait for quiet (a boss's crate, opened as the boss falls) still waits for
# the card on screen: it takes the slot ahead of the line the moment no card holds it.
func take(key: String) -> bool:
	_asked[key] = _clock
	if key == _holder:
		return true
	if _holder != "":
		return false
	_waiting.erase(key)
	_holder = key
	return true


# The card is gone, shown or dropped; the next one in line may come at once.
func done(key: String) -> void:
	_waiting.erase(key)
	_asked.erase(key)
	_firsts.erase(key)
	if _holder == key:
		_holder = ""


# The card on screen was pushed off by something else (a crate): it keeps its place, first in line.
func give_back(key: String) -> void:
	if _holder == key:
		_holder = ""
	_waiting.erase(key)
	_waiting.insert(0, key)


func waiting() -> Array[String]:
	return _waiting.duplicate()


# The card holding the screen, or "" when none does.
func showing() -> String:
	return _holder


# A run ended: what still waits is not shown.
func drop_all() -> void:
	_waiting.clear()
	_asked.clear()
	_firsts.clear()
	_holder = ""


func _process(delta: float) -> void:
	step(delta)


# Game time passes: the screen is quiet for `delta` more seconds, or busy again. A test that
# drives its cards with a clock of its own steps this too.
func step(delta: float) -> void:
	_clock += delta
	var tree := get_tree() if is_inside_tree() else null
	if busy() or WhyCallout.threat_live(tree):
		_quiet_for = 0.0
	else:
		_quiet_for += delta
