extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const Events := preload("res://src/core/game_events.gd")
const Swarm := preload("res://src/combat/warden_swarm.gd")

class Fleet extends RefCounted:
	var bus
	func events():
		return bus

class Warden extends Node:
	var fleet
	var target = null

var _failures := 0
var _first := 0
var _second := 0
var _named := 0

func _initialize() -> void:
	_run.call_deferred()

func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])

func _on_clear(_reason := "") -> void:
	_named += 1

func _audio(loose: bool) -> void:
	var events := Events.new()
	_first = 0
	_second = 0
	_named = 0
	var first: Callable
	var second: Callable
	if loose:
		first = func(): _first += 1
		second = func(): _second += 1
	else:
		first = func(_reason: String): _first += 1
		second = func(_reason: String): _second += 1
	Audio._listen(events, "stage_content_cleared", first, loose)
	Audio._listen(events, "stage_content_cleared", second, loose)
	Audio._listen(events, "stage_content_cleared", first, loose)
	events.stage_content_cleared.emit("arena")
	_report("distinct lambdas loose=%s" % loose, _first == 1 and _second == 1,
		"first=%d second=%d connections=%d" % [_first, _second, events.get_signal_connection_list("stage_content_cleared").size()])
	_report("identical lambda loose=%s" % loose, events.get_signal_connection_list("stage_content_cleared").size() == 2,
		"connections=%d want=2" % events.get_signal_connection_list("stage_content_cleared").size())
	events.free()
	events = Events.new()
	Audio._listen(events, "stage_content_cleared", _on_clear, loose)
	Audio._listen(events, "stage_content_cleared", _on_clear, loose)
	Audio._listen(events, "stage_content_cleared", _on_clear)
	events.stage_content_cleared.emit("arena")
	_report("named method dedupes loose=%s" % loose, _named == 1 and events.get_signal_connection_list("stage_content_cleared").size() == 1,
		"calls=%d connections=%d want=1" % [_named, events.get_signal_connection_list("stage_content_cleared").size()])
	events.free()

func _swarm() -> void:
	var events := Events.new()
	var fleet := Fleet.new()
	fleet.bus = events
	var warden := Warden.new()
	warden.fleet = fleet
	root.add_child(warden)
	var driver := Swarm.new()
	driver._listen(warden)
	_report("swarm alive listener", events.get_signal_connection_list("enemy_struck").size() == 1, "one lamp listener")
	events.enemy_struck.emit(null, "weapon", 1.0)
	warden.free()
	_report("freed Warden disconnects", events.get_signal_connection_list("enemy_struck").is_empty(),
		"remaining=%d want=0" % events.get_signal_connection_list("enemy_struck").size())
	events.enemy_struck.emit(null, "weapon", 1.0)
	events.free()

func _run() -> void:
	_audio(false)
	_audio(true)
	_swarm()
	print("signal_lifetime_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
