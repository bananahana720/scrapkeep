extends Node

const Radio := preload("res://src/core/radio.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const RadioDial := preload("res://src/ui/radio_dial.gd")
const RadioCache := preload("res://src/world/radio_cache.gd")


const PLAN_EVERY := 0.25
const SILENT_STATES := ["stage", "beacon", "gates", "launch", "boss", "dead"]

var game
var radio := Radio.new()
var dial
var applied := {}
var _audio
var _counts := {}
var _cut_in := ""
var _plan_left := 0.0
var _dirty := false


func setup(game_ref) -> void:
	game = game_ref
	_audio = game.audio()
	radio.from_dict(game.ctx.profile.radio())
	if game.hud != null:
		dial = RadioDial.new()
		dial.name = "RadioDial"
		dial.deck = self
		game.hud.mount_corner(dial)
	var events = game.events
	if events != null:
		events.run_started.connect(func(_class_id: String): _counts.clear())
		events.flow_changed.connect(_on_flow_changed)
		events.stage_entered.connect(func(_stage: int, _retry: bool):
			_place_caches.call_deferred()
			plan_now())
		var bus_args := _signal_args(events)
		for on in RadioTakes.by_signal():
			if not bus_args.has(on):
				push_warning("radio: no bus signal %s for a take" % on)
				continue
			_listen(events, on, bus_args[on])
	if _audio != null:
		if _audio.has_signal("tune_heard"):
			_audio.tune_heard.connect(_on_tune_heard)
		if _audio.has_signal("radio_yielded"):
			_audio.radio_yielded.connect(func(_reason: String): applied = {})


static func _signal_args(events: Object) -> Dictionary:
	var out := {}
	for info in events.get_signal_list():
		out[info["name"]] = info["args"].map(func(a): return a["name"])
	return out


func _listen(events: Object, on: String, names: Array) -> void:
	var handler := func(a = null, b = null, c = null, d = null, e = null, f = null):
		var values := [a, b, c, d, e, f]
		var args := {}
		for i in names.size():
			args[names[i]] = values[i]
		bus_signal(on, args)
	events.connect(on, handler)


func bus_signal(on: String, args: Dictionary) -> void:
	var stage := _stage()
	for id in RadioTakes.by_signal().get(on, []):
		if _found(id):
			continue
		var rule: Dictionary = RadioTakes.take(id)["found"]
		if not RadioTakes.counts(rule, args, stage):
			continue
		_counts[id] = int(_counts.get(id, 0)) + 1
		if int(_counts[id]) >= RadioTakes.needed(rule):
			find(id)


func _on_tune_heard(tune: String) -> void:
	for t in RadioTakes.takes():
		if t["found"].get("on") == "heard" and t["found"].get("tune") == tune:
			find(String(t["id"]))


func cache_found(id: String) -> bool:
	var t := RadioTakes.take(id)
	if t.is_empty() or t["found"].get("on") != "cache" or not live():
		return false
	find(id)
	return game.ctx.profile.has_tune(id)


func find(id: String) -> bool:
	var profile = game.ctx.profile
	if RadioTakes.take(id).is_empty() or not profile.hear_tune(id):
		return false
	var t := RadioTakes.take(id)
	if game.hud != null and game.hud.has_method("take_found"):
		game.hud.take_found(String(t["name"]), Radio.station_name(String(t["station"])), String(t["tier"]))
	if _audio != null:
		_audio.play("bay_jukebox", 0.0, 1.0, "UI")
	var before := radio.station
	if radio.premiere(id, context()) and radio.station != before and dial != null:
		dial.swell()
	game.events.radio_take_found.emit(id, String(t["tier"]), String(t["found"].get("on", "")))
	save()
	plan_now()
	return true


func _place_caches() -> void:
	for old in get_tree().get_nodes_in_group(RadioCache.GROUP):
		old.queue_free()
	var terrain = game.ctx.get("terrain")
	var root = game.ctx.get("root")
	if terrain == null or root == null or not terrain.has_method("map") or terrain.map() == null:
		return
	RadioCache.spawn_for(String(terrain.map().title), _found, root, self, game.ctx.player)


func _found(id: String) -> bool:
	return game.ctx.profile.has_tune(id)


func _unhandled_input(event: InputEvent) -> void:
	if not live() or event.is_echo():
		return
	if event.is_action_pressed("cl_radio_next"):
		turn(1)
	elif event.is_action_pressed("cl_radio_prev"):
		turn(-1)
	elif event.is_action_pressed("cl_radio_skip"):
		skip()
	elif event.is_action_pressed("cl_radio_pin"):
		toggle_pin()
	else:
		return
	get_viewport().set_input_as_handled()


func turn(direction: int) -> void:
	radio.turn(direction)
	_cut_in = ""
	_blip(Radio.dial().find(radio.station))
	_changed()


func skip() -> void:
	if radio.station in [Radio.OFF, Radio.LIVE]:
		turn(1)
		return
	radio.skip(context())
	_cut_in = ""
	_blip(3)
	_changed()


func toggle_off() -> void:
	radio.toggle_off()
	_blip(0)
	_changed()


func toggle_pin() -> void:
	radio.toggle_pin()
	if _audio != null and _audio.radio_hold != "":
		_audio.radio_pinned = radio.pinned
	_changed()


func tune(id: String) -> void:
	radio.tune(id)
	_changed()


func _changed() -> void:
	_dirty = true
	if dial != null:
		dial.swell()
	plan_now()


func _blip(step: int) -> void:
	if _audio != null:
		_audio.play("flow_changed", -4.0, pow(2.0, [0, 2, 4, 5, 7, 9, 11][posmod(step, 7)] / 12.0), "UI")


func live() -> bool:
	return game != null and game.flow != null and game.flow.in_play()


func meter_level(layer: int) -> float:
	var engine = _audio.engine if _audio != null else null
	if engine == null:
		return 0.0
	var want := clampf(float(engine.layer_gain(layer)), 0.0, 1.0)
	var beat: int = maxi(1, engine.beat_len())
	return want * (0.75 + 0.25 * (1.0 - float(engine.clock % beat) / beat))


func _stage() -> int:
	var run = game.ctx.get("run") if game.ctx != null else null
	return int(run.stage) if run != null else 0


func context() -> Dictionary:
	var world := 0
	var fresh := false
	if _audio != null:
		var zone := String(_audio.music_state().get("zone", ""))
		world = int(zone.get_slice("-", 0)) if zone != "" else 0
		var wanted: String = _audio.score_tune_wanted()
		if _audio.tune_unheard(wanted):
			_cut_in = wanted
		fresh = _cut_in != "" and _cut_in == wanted
		if not fresh:
			_cut_in = ""
	var flow = game.flow
	var boss: bool = flow.state_name() == "boss" or (flow.has_method("engaged") and flow.engaged() and bool(flow.get("sealed")))
	var moment: bool = _audio != null and _audio.has_method("moment_live") and _audio.moment_live()
	var finale: bool = _audio != null and bool(_audio.get("radio_finale"))
	return {"found": game.ctx.profile.tune_ids(), "world": world, "boss": boss, "fresh": fresh, "moment": moment, "finale": finale}


func _process(delta: float) -> void:
	if not live():
		return
	var ctx := context()
	if radio.tick(delta, ctx):
		_changed()
	_plan_left -= delta
	if _plan_left <= 0.0:
		_apply(radio.decide(ctx))


func plan_now() -> void:
	_plan_left = 0.0
	if live():
		_apply(radio.decide(context()))


func _apply(plan: Dictionary) -> void:
	_plan_left = PLAN_EVERY
	if _audio == null or not _audio.sound_ready:
		return
	_audio.set_radio_silenced(plan["play"] == "silence")
	match plan["play"]:
		"track":
			if _audio.radio_hold != plan["id"]:
				if not _audio.radio_play(plan["id"], RadioTakes.record_of(plan["id"]), radio.pinned):
					return
			_audio.radio_pinned = radio.pinned
		_:
			if _audio.radio_hold != "":
				_audio.radio_release()
	applied = plan


func _on_flow_changed(state: String) -> void:
	if not state in SILENT_STATES and _audio != null:
		_audio.set_radio_silenced(false)
	if not game.flow.in_play():
		applied = {}
		if _dirty:
			save()
	else:
		plan_now()


func save() -> void:
	_dirty = false
	var profile = game.ctx.profile
	profile.set_radio(radio.to_dict())
	if not profile.save_if_allowed():
		push_warning("radio: not saved: %s" % profile.last_error)


func _hint(station: String) -> String:
	for id in RadioTakes.on_station(station):
		if RadioTakes.is_take(id) and not _found(id):
			return String(RadioTakes.take(id)["where"])
	return ""


func reading() -> Dictionary:
	var station := radio.station
	var st := RadioTakes.station(station)
	var on_air := String(applied.get("id", "")) if applied.get("play", "") == "track" else ""
	var row := RadioTakes.track(on_air)
	var line := ""
	match String(applied.get("why", radio.why)):
		"off":
			line = "Radio off"
		"live", "":
			line = "Live from the run"
		"new_signal":
			var fresh := String(RadioTakes.track(_cut_in).get("name", ""))
			if fresh == "":
				line = "New signal. Listen in."
			elif _audio != null and _audio.tune_unheard(_cut_in):
				line = "New signal: %s" % fresh
			else:
				line = "Live: %s" % fresh
		"boss":
			line = "The fight has the air"
		"finale":
			line = "The finale has the air"
		"no_signal":
			line = "No signal yet. " + _hint(station)
		"moment":
			line = "Stepping aside for the moment"
		_:
			line = String(row.get("name", ""))
	return {"station": station, "call": Radio.call_sign(station), "name": Radio.station_name(station),
		"dial": String(st.get("dial", "")), "color": String(st.get("color", "SLATE")), "line": line,
		"track": on_air, "pinned": radio.pinned and on_air != "", "off": station == Radio.OFF}
