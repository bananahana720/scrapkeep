extends RefCounted

const Weapons := preload("res://src/combat/weapons.gd")

# Device caps (SR8, BIBLE.md "Devices and one main companion"). A quick autonomous device
# is something a pilot leaves in the world to act on its own: Kest's thrown sticky charges
# and dropped mini charges (sticky.gd), ultimate mines and raid charges (kest_kit.gd),
# Sable's Sentry Post (combat.gd) and Outpost stakes (stakes.gd). Each kind has one
# row: a cap on how many stand at once, a refill time before a slot a device left comes
# back, and a leash: a device further than leash_m from its owner for recall_after s is
# recalled, leaving without acting. A destroyed, expired or recalled device leaves the
# count at once. A deploy at the cap replaces the oldest standing device of its kind (the
# caller resolves it); a deploy with every free slot still refilling is refused.
#
# The ledger is per attempt and nameless: combat clears it with the fight, nothing carries
# across stages, and no device has a role or a name (FORBIDDEN: a roster that acts like a
# crew; TADR-011's crew is a separate, later unit).
#
# Shape from comps/ror2/companions.md (Devices bullet): per-kind slot limits (2, 2, 3, 4),
# a spawner refill, recall by the leash and removal on destruction. The numbers below are
# Scrapkeep start values for the lab, not RoR2's.

# Start value (BIBLE.md:568 leaves capacity open): retain the landed Kest weapon default.
const STICKY_CAP := Weapons.STICKY_MAX_LIVE
# Start value (BIBLE.md:568 leaves resource rules open): these quick devices reuse their
# slot immediately; the weapon/special cooldown and ultimate meter still gate deployment.
const QUICK_REFILL := 0.0
# Start value (comps/ror2/companions.md, mines "else 4"): minis stand at most this many;
# above one demo slam's widest scatter (Demo Expert's mini_count 5) so a slam is never cut.
const MINI_CAP := 8
# Start value (comps/ror2/companions.md, the turret slot): one Sentry Post stands at a time,
# as its tree row says ("Leaving a pylon leaves a turret behind").
const SENTRY_CAP := 1
# Start value (comps/ror2/companions.md, the 30 s spawner, shortened for a quick device):
# seconds before an expired, destroyed or recalled sentry's slot comes back.
const SENTRY_REFILL := 2.0
# Start value (BIBLE.md:568; landed kest_kit.gd MINE_CAP): retain ten Minelayer mines.
const KEST_MINE_CAP := 10
# Start value (BIBLE.md:568; comps/ror2/companions.md per-kind slot shape): a bounded
# carpet of 64 keeps a default nine-beat, four-charge Air Raid plus its heavy charge.
const KEST_RAID_CAP := 64
# Start value (BIBLE.md:568; landed stakes.gd CAP): retain eleven route anchors/sentries.
const SABLE_STAKE_CAP := 11
# Start value (BIBLE.md:568; landed kest_kit.gd MINE_FUSE): six seconds after landing.
const KEST_MINE_LIFETIME := 6.0
# Start value (BIBLE.md:568; landed stakes.gd LIFE): six seconds after arming at landing.
const SABLE_STAKE_LIFETIME := 6.0
# Start value (BIBLE.md:568; landed stakes.gd SENTRY_SECONDS): four seconds of turret fire.
const SABLE_SENTRY_SECONDS := 4.0
# Start value (comps/ror2/companions.md, the 400-unit leash and 10 s wait, scaled to
# Scrapkeep): twice the sentry's reach (Weapons.SENTRY_REACH), past which a device can no
# longer help where its owner is, held for DEVICE_RECALL s.
const DEVICE_LEASH := 60.0
# Start value (BIBLE.md:568; comps/ror2/companions.md leash delay): recall after one
# continuous second beyond the range; independent of SR7's following companion leash.
const DEVICE_RECALL := 1.0

const STICKY := "sticky"
const MINI := "mini"
const SENTRY := "sentry"
const KEST_MINE := "kest_mine"
const KEST_RAID := "kest_raid"
const SABLE_STAKE := "sable_stake"
const KINDS := [STICKY, MINI, SENTRY, KEST_MINE, KEST_RAID, SABLE_STAKE]
const REASONS := ["destroyed", "expired", "recalled", "evicted"]

# cap_knob names the kit knob that sets the cap live (combat calls set_cap); the row's
# cap is the knob's default. Thrown charges keep Kest's own cap and refill at once.
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

# kind -> [{id, at, far}], oldest first.
var _live := {}
# kind -> [seconds left] for slots still refilling.
var _refill := {}
# kind -> a live cap from the kit (set_cap); absent means the row's cap.
var _caps := {}
var _next_id := 1


# Problems with a table, [] when sound.
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


# One deploy: {"id": int, 0 when refused, "evicted": [ids the caller must resolve]}.
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


# The device left: it leaves the count now and its slot refills after the row's time.
# An eviction reuses its slot at once. An unknown id is a no-op.
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


# Ticks refills and the leash; returns the devices recalled this tick, [{id, kind}],
# already out of the count. The caller removes them from the world without acting.
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
