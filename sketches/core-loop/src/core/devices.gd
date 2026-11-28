extends RefCounted


const STICKY_CAP := 3
const STICKY_CONTACT_REACH := 0.6
const QUICK_REFILL := 0.0
const MINI_CAP := 8
const SENTRY_CAP := 1
const SENTRY_REFILL := 2.0
const KEST_MINE_CAP := 10
const KEST_RAID_CAP := 64
const SABLE_STAKE_CAP := 11
const KEST_MINE_LIFETIME := 6.0
const SABLE_STAKE_LIFETIME := 6.0
const SABLE_SENTRY_SECONDS := 4.0
const DEVICE_LEASH := 60.0
const DEVICE_RECALL := 1.0

const STICKY := "sticky"
const MINI := "mini"
const SENTRY := "sentry"
const KEST_MINE := "kest_mine"
const KEST_RAID := "kest_raid"
const SABLE_STAKE := "sable_stake"
const KINDS := [STICKY, MINI, SENTRY, KEST_MINE, KEST_RAID, SABLE_STAKE]
const REASONS := ["destroyed", "expired", "recalled", "evicted"]

const ROWS := {
	STICKY: {"cap": STICKY_CAP, "cap_knob": "sticky_max_live", "refill": QUICK_REFILL,
		"leash_m": DEVICE_LEASH, "recall_after": DEVICE_RECALL},
	MINI: {"cap": MINI_CAP, "refill": QUICK_REFILL, "leash_m": DEVICE_LEASH, "recall_after": DEVICE_RECALL},
	SENTRY: {"cap": SENTRY_CAP, "refill": SENTRY_REFILL, "leash_m": DEVICE_LEASH, "recall_after": DEVICE_RECALL},
	KEST_MINE: {"cap": KEST_MINE_CAP, "refill": QUICK_REFILL, "leash_m": DEVICE_LEASH,
		"recall_after": DEVICE_RECALL, "lifetime": KEST_MINE_LIFETIME},
	KEST_RAID: {"cap": KEST_RAID_CAP, "refill": QUICK_REFILL, "leash_m": DEVICE_LEASH, "recall_after": DEVICE_RECALL},
	SABLE_STAKE: {"cap": SABLE_STAKE_CAP, "refill": QUICK_REFILL, "leash_m": DEVICE_LEASH,
		"recall_after": DEVICE_RECALL, "lifetime": SABLE_STAKE_LIFETIME, "sentry_seconds": SABLE_SENTRY_SECONDS},
}

var _live := {}
var _refill := {}
var _caps := {}
var _next_id := 1


static func validate_rows(rows: Dictionary = ROWS) -> Array:
	var out := []
	for kind in KINDS:
		if not rows.has(kind):
			out.append("%s: no row" % kind)
	for kind in rows:
		var row: Dictionary = rows[kind]
		if int(row.get("cap", 0)) < 1:
			out.append("%s: cap below 1" % kind)
		for field in ["refill", "leash_m", "recall_after"]:
			var v = row.get(field)
			if not (v is float or v is int) or not is_finite(float(v)) or float(v) < 0.0:
				out.append("%s: %s not a finite non-negative number" % [kind, field])
		if float(row.get("leash_m", 0.0)) <= 0.0:
			out.append("%s: leash_m not positive" % kind)
	return out


func cap(kind: String) -> int:
	return int(_caps.get(kind, ROWS.get(kind, {}).get("cap", 0)))


func set_cap(kind: String, n: int) -> void:
	_caps[kind] = maxi(1, n)


func count(kind: String) -> int:
	return (_live.get(kind, []) as Array).size()


func refilling(kind: String) -> int:
	return (_refill.get(kind, []) as Array).size()


func kind_of(id: int) -> String:
	for kind in _live:
		for entry in _live[kind]:
			if entry["id"] == id:
				return kind
	return ""


func deploy(kind: String, at: Vector3) -> Dictionary:
	if not ROWS.has(kind):
		return {"id": 0, "evicted": []}
	var live: Array = _live.get(kind, [])
	_live[kind] = live
	var evicted := []
	while not live.is_empty() and live.size() + refilling(kind) >= cap(kind):
		evicted.append(live.pop_front()["id"])
	if live.size() + refilling(kind) >= cap(kind):
		return {"id": 0, "evicted": evicted}
	var id := _next_id
	_next_id += 1
	live.append({"id": id, "at": at, "far": 0.0})
	return {"id": id, "evicted": evicted}


func move(id: int, at: Vector3) -> void:
	var entry := _entry(id)
	if not entry.is_empty():
		entry["at"] = at


func remove(id: int, reason := "destroyed") -> bool:
	for kind in _live:
		var live: Array = _live[kind]
		for i in live.size():
			if live[i]["id"] == id:
				live.remove_at(i)
				var refill: float = float(ROWS[kind]["refill"])
				if reason != "evicted" and refill > 0.0:
					var slots: Array = _refill.get(kind, [])
					slots.append(refill)
					_refill[kind] = slots
				return true
	return false


func step(delta: float, owner_at: Vector3) -> Array:
	for kind in _refill:
		var slots: Array = _refill[kind]
		for i in slots.size():
			slots[i] = float(slots[i]) - delta
		_refill[kind] = slots.filter(func(s): return s > 0.000001)
	var recalled := []
	for kind in _live:
		var row: Dictionary = ROWS[kind]
		for entry in (_live[kind] as Array).duplicate():
			if (entry["at"] as Vector3).distance_to(owner_at) > float(row["leash_m"]):
				entry["far"] = float(entry["far"]) + delta
			else:
				entry["far"] = 0.0
			if float(entry["far"]) >= float(row["recall_after"]) - 0.000001 and float(entry["far"]) > 0.0:
				remove(entry["id"], "recalled")
				recalled.append({"id": entry["id"], "kind": kind})
	return recalled


func clear() -> void:
	_live = {}
	_refill = {}
	_caps = {}


func _entry(id: int) -> Dictionary:
	for kind in _live:
		for entry in _live[kind]:
			if entry["id"] == id:
				return entry
	return {}
