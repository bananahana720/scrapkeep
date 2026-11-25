extends RefCounted


const RadioTakes := preload("res://src/core/radio_takes.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")

const OFF := "off"
const LIVE := RadioTakes.LIVE
const AUTO := RadioTakes.AUTO
const MIXTAPE := RadioTakes.MIXTAPE
const AIRTIME := 150.0
const MAX_MIXTAPES := 6
const MAX_TRACKS := 20
const MIXTAPE_NAMES := ["Night Shift", "Overtime", "Ballast", "Long Haul", "Spare Parts", "Last Call"]

var station := LIVE
var track := ""
var pinned := false
var mixtapes: Array = [{"name": MIXTAPE_NAMES[0], "ids": []}]
var mixtape := 0
var why := ""
var _aired := 0.0
var _last_on := LIVE
var _premiere_from := ""
var _cursor := {}


static func dial() -> Array:
	return [OFF] + RadioTakes.station_ids()


static func call_sign(id: String) -> String:
	return "OFF" if id == OFF else String(RadioTakes.station(id).get("call", id.to_upper()))


static func station_name(id: String) -> String:
	return "Radio off" if id == OFF else String(RadioTakes.station(id).get("name", id))


func decide(context: Dictionary) -> Dictionary:
	if station == OFF:
		return _plan("silence", "", "off")
	if bool(context.get("boss", false)) and bool(context.get("finale", false)):
		return _plan("score", "", "finale")
	if bool(context.get("fresh", false)):
		return _plan("score", "", "new_signal")
	if station == LIVE:
		return _plan("score", "", "live")
	if bool(context.get("boss", false)) and not (pinned and track != ""):
		return _plan("score", "", "boss")
	if station == AUTO and bool(context.get("moment", false)):
		return _plan("score", "", "moment")
	var rotation := rotation_of(station, context)
	if rotation.is_empty():
		track = ""
		return _plan("score", "", "no_signal")
	if not track in rotation:
		track = rotation[clampi(int(_cursor.get(station, 0)), 0, rotation.size() - 1)]
		_aired = 0.0
	return _plan("track", track, "on_air")


func _plan(play: String, id: String, reason: String) -> Dictionary:
	why = reason
	return {"play": play, "id": id, "why": reason}


func rotation_of(id: String, context: Dictionary) -> Array:
	var found: Array = context.get("found", [])
	var have := {}
	for f in found:
		have[f] = true
	var ids: Array = []
	match id:
		OFF, LIVE:
			return []
		AUTO:
			var world := int(context.get("world", 0))
			for t in RadioTakes.all_ids():
				var row := RadioTakes.track(t)
				if have.has(t) and (world == 0 or int(row.get("world", 0)) in [0, world]):
					ids.append(t)
		MIXTAPE:
			ids = current_mixtape()["ids"].filter(func(t): return have.has(t))
		_:
			ids = RadioTakes.on_station(id).filter(func(t): return have.has(t))
	return ids


func tick(delta: float, context: Dictionary) -> bool:
	if track == "" or station in [OFF, LIVE] or why != "on_air":
		return false
	_aired += delta
	if _aired < AIRTIME:
		return false
	if _premiere_from != "":
		if bool(context.get("boss", false)):
			return false
		var back := _premiere_from
		_premiere_from = ""
		tune(back)
		return true
	skip(context)
	return true


func skip(context: Dictionary) -> String:
	var rotation := rotation_of(station, context)
	pinned = false
	_aired = 0.0
	if rotation.is_empty():
		track = ""
		return ""
	var at := (rotation.find(track) + 1) % rotation.size()
	_cursor[station] = at
	track = rotation[at]
	return track


func turn(direction: int) -> String:
	var stops := dial()
	var at := stops.find(station)
	tune(stops[posmod(at + signi(direction if direction != 0 else 1), stops.size())])
	return station


func tune(id: String) -> void:
	if not id in dial():
		return
	if station != id:
		track = ""
		pinned = false
		_aired = 0.0
		_premiere_from = ""
	station = id
	if id != OFF:
		_last_on = id


func toggle_off() -> String:
	tune(_last_on if station == OFF else OFF)
	return station


func toggle_pin() -> bool:
	pinned = not pinned and track != ""
	return pinned


func premiere(id: String, context := {}) -> bool:
	var home := RadioTakes.station_of(id)
	if station == OFF or home == "" or not home in dial() or bool(context.get("boss", false)):
		return false
	var back := station if _premiere_from == "" else _premiere_from
	tune(home)
	_premiere_from = back if back != home else ""
	track = id
	_aired = 0.0
	return true


func current_mixtape() -> Dictionary:
	return mixtapes[clampi(mixtape, 0, mixtapes.size() - 1)]


func new_mixtape() -> int:
	if mixtapes.size() >= MAX_MIXTAPES:
		return -1
	mixtapes.append({"name": MIXTAPE_NAMES[mixtapes.size()], "ids": []})
	return mixtapes.size() - 1


func add_to(list: int, id: String) -> bool:
	if list < 0 or list >= mixtapes.size() or RadioTakes.track(id).is_empty():
		return false
	var ids: Array = mixtapes[list]["ids"]
	if id in ids or ids.size() >= MAX_TRACKS:
		return false
	ids.append(id)
	return true


func remove_from(list: int, id: String) -> bool:
	if list < 0 or list >= mixtapes.size():
		return false
	var ids: Array = mixtapes[list]["ids"]
	var at := ids.find(id)
	if at < 0:
		return false
	ids.remove_at(at)
	return true


func nudge(list: int, id: String, step: int) -> bool:
	if list < 0 or list >= mixtapes.size():
		return false
	var ids: Array = mixtapes[list]["ids"]
	var at := ids.find(id)
	var to := at + step
	if at < 0 or to < 0 or to >= ids.size():
		return false
	ids[at] = ids[to]
	ids[to] = id
	return true


func shuffle_mixtape(list: int, rng: RandomNumberGenerator) -> void:
	if list < 0 or list >= mixtapes.size():
		return
	var ids: Array = mixtapes[list]["ids"]
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var keep = ids[i]
		ids[i] = ids[j]
		ids[j] = keep


func to_dict() -> Dictionary:
	return {"station": station, "last_on": _last_on, "mixtape": mixtape, "mixtapes": mixtapes.duplicate(true)}


func from_dict(saved: Dictionary) -> void:
	var known := RadioTakes.all_ids()
	var lists: Array = []
	var saved_lists = saved.get("mixtapes", [])
	for m in (saved_lists if saved_lists is Array else []):
		if m is Dictionary and lists.size() < MAX_MIXTAPES:
			var ids: Array = []
			var saved_ids = m.get("ids", [])
			for id in (saved_ids if saved_ids is Array else []):
				if id is String and id in known and not id in ids and ids.size() < MAX_TRACKS:
					ids.append(id)
			var name = m.get("name")
			lists.append({"name": (name if name is String else MIXTAPE_NAMES[lists.size()]).left(24), "ids": ids})
	if not lists.is_empty():
		mixtapes = lists
	var at_tape = saved.get("mixtape", 0)
	mixtape = clampi(int(at_tape) if typeof(at_tape) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(at_tape)) else 0, 0, mixtapes.size() - 1)
	var on = saved.get("last_on", LIVE)
	_last_on = on if on is String and on in dial() and on != OFF else LIVE
	var at = saved.get("station", LIVE)
	station = at if at is String and at in dial() else LIVE
