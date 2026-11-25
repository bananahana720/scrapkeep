extends RefCounted


const TuneRows := preload("res://src/core/tune_rows.gd")

const PATH := "res://assets/radio/catalogue.json"
const TIERS := ["b-side", "take", "legend"]
const SPECIAL_RULES := ["heard", "cache"]
const LIVE := "live"
const AUTO := "auto"
const MIXTAPE := "mixtape"
const BUILT_IN := [LIVE, AUTO, MIXTAPE]
const TAKE_FIELDS := ["id", "name", "station", "parent", "pick", "tier", "world", "place", "found", "where", "sleeve",
	"bpm", "key", "strength", "seconds", "form", "textures", "references", "caption"]

static var _doc := {}


static func doc() -> Dictionary:
	if _doc.is_empty():
		_doc = load_doc(PATH)
	return _doc


static func load_doc(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text) if text != "" else null
	if not (parsed is Dictionary):
		push_warning("radio: catalogue %s did not load" % path)
		return {"format": 1, "stations": [], "takes": [], "records": {}}
	return parsed


static func stations() -> Array:
	return doc().get("stations", [])


static func station_ids() -> Array:
	return stations().map(func(s: Dictionary): return String(s["id"]))


static func station(id: String) -> Dictionary:
	for s in stations():
		if s["id"] == id:
			return s
	return {}


static func takes() -> Array:
	return doc().get("takes", [])


static func take_ids() -> Array:
	return takes().map(func(t: Dictionary): return String(t["id"]))


static func take(id: String) -> Dictionary:
	for t in takes():
		if t["id"] == id:
			return t
	return {}


static func is_take(id: String) -> bool:
	return not take(id).is_empty()


static func record_station(id: String) -> String:
	return String(doc().get("records", {}).get(id, ""))


static func station_of(id: String) -> String:
	var t := take(id)
	return String(t["station"]) if not t.is_empty() else record_station(id)


static func track(id: String) -> Dictionary:
	var t := take(id)
	if not t.is_empty():
		return t
	var r := TuneRows.row(id)
	if r.is_empty():
		return {}
	return {"id": id, "name": r["name"], "station": record_station(id), "parent": id, "tier": "take" if r["rare"] else "b-side",
		"world": int(r["shelf"]), "where": r["where"], "sleeve": r["sleeve"]}


static func record_of(id: String) -> String:
	var t := take(id)
	return String(t["parent"]) if not t.is_empty() else id


static func on_station(id: String) -> Array:
	var out: Array = []
	for t in takes():
		if t["station"] == id:
			out.append(String(t["id"]))
	for r in TuneRows.ROWS:
		if record_station(String(r["id"])) == id:
			out.append(String(r["id"]))
	return out


static func all_ids() -> Array:
	return TuneRows.ids() + take_ids()


static func by_signal() -> Dictionary:
	var out := {}
	for t in takes():
		var on := String(t["found"].get("on", ""))
		if on in SPECIAL_RULES:
			continue
		if not out.has(on):
			out[on] = []
		out[on].append(String(t["id"]))
	return out


static func counts(rule: Dictionary, args: Dictionary, stage: int) -> bool:
	var stages: Array = rule.get("stage", [])
	if not stages.is_empty() and not stage in stages:
		return false
	for key in rule.get("where", {}):
		if not args.has(key) or str(args[key]) != str(rule["where"][key]):
			return false
	for key in rule.get("at_least", {}):
		var value = args.get(key)
		if not (value is int or value is float) or float(value) < float(rule["at_least"][key]):
			return false
	return true


static func needed(rule: Dictionary) -> int:
	return maxi(1, int(rule.get("count", 1)))


static func validate(catalogue: Dictionary, signals: Dictionary) -> Array:
	var errors: Array = []
	var seen := {}
	var station_set := {}
	for s in catalogue.get("stations", []):
		for key in ["id", "name", "call", "dial", "blurb"]:
			if String(s.get(key, "")) == "":
				errors.append("station %s: no %s" % [s.get("id", "?"), key])
		if station_set.has(s.get("id")):
			errors.append("station %s: listed twice" % s.get("id"))
		station_set[s.get("id")] = true
	for id in BUILT_IN:
		if not station_set.has(id):
			errors.append("station %s: missing" % id)
	for t in catalogue.get("takes", []):
		var id := String(t.get("id", ""))
		for key in TAKE_FIELDS:
			if not t.has(key):
				errors.append("take %s: no %s" % [id, key])
		if seen.has(id) or not TuneRows.row(id).is_empty():
			errors.append("take %s: id taken" % id)
		seen[id] = true
		if not station_set.has(t.get("station")) or t.get("station") in BUILT_IN:
			errors.append("take %s: station %s is not a content station" % [id, t.get("station")])
		if TuneRows.row(String(t.get("parent", ""))).is_empty():
			errors.append("take %s: parent %s is no jukebox record" % [id, t.get("parent")])
		if not t.get("tier") in TIERS:
			errors.append("take %s: tier %s" % [id, t.get("tier")])
		var caption := String(t.get("caption", "")).to_lower()
		if "anime" in caption:
			errors.append("take %s: the caption says anime" % id)
		errors.append_array(_rule_errors(id, t.get("found", {}), signals))
	for record in catalogue.get("records", {}):
		if TuneRows.row(record).is_empty():
			errors.append("records: %s is no jukebox record" % record)
		elif not station_set.has(catalogue["records"][record]):
			errors.append("records: %s airs on unknown station %s" % [record, catalogue["records"][record]])
	return errors


static func _rule_errors(id: String, rule: Dictionary, signals: Dictionary) -> Array:
	var on := String(rule.get("on", ""))
	match on:
		"heard":
			return [] if not TuneRows.row(String(rule.get("tune", ""))).is_empty() else ["take %s: heard names no record" % id]
		"cache":
			return [] if String(rule.get("park", "")) != "" and String(rule.get("spot", "")) != "" else ["take %s: cache needs park and spot" % id]
	if not signals.has(on):
		return ["take %s: no bus signal %s" % [id, on]]
	var errors: Array = []
	for part in ["where", "at_least"]:
		for key in rule.get(part, {}):
			if not key in signals[on]:
				errors.append("take %s: %s has no argument %s" % [id, on, key])
	return errors
