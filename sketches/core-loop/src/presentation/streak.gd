extends RefCounted

const EventJuice := preload("res://src/presentation/event_juice.gd")


const FAST_RATIO := 0.45
const TIER_RUNGS := [0, 2, 4, 6]

var window_ms := 700
var cap := 9
var rung := 0
var length := 0
var last_ms := -100000
var last_gap_ms := -1
var fast_links := 0
var peak_rung := 0


static func for_kind(kind: String) -> RefCounted:
	var streak: RefCounted = load("res://src/presentation/streak.gd").new()
	var row := EventJuice.juice(kind)
	streak.window_ms = int(row.get("chain_ms", 700))
	streak.cap = int(row.get("chain_cap", 9))
	return streak


func fast_window_ms() -> int:
	return maxi(1, roundi(float(window_ms) * FAST_RATIO))


func bump(now_ms: int) -> int:
	var gap := now_ms - last_ms
	if length > 0 and gap < window_ms:
		rung = mini(rung + 1, cap)
		length += 1
		last_gap_ms = maxi(0, gap)
		fast_links = fast_links + 1 if gap <= fast_window_ms() else 0
	else:
		rung = 0
		length = 1
		last_gap_ms = -1
		fast_links = 0
	peak_rung = maxi(peak_rung, rung)
	last_ms = now_ms
	return rung


func live(now_ms: int) -> bool:
	return length > 0 and now_ms - last_ms < window_ms


func heat_fraction() -> float:
	return clampf(float(rung) / float(maxi(1, cap)), 0.0, 1.0)


func tempo() -> float:
	if length <= 1 or last_gap_ms < 0 or window_ms <= 0:
		return 0.0
	return clampf(1.0 - float(last_gap_ms) / float(window_ms), 0.0, 1.0)


func tier() -> int:
	var found := 0
	for i in TIER_RUNGS.size():
		if rung >= int(TIER_RUNGS[i]):
			found = i
	if fast_links >= 2 and rung >= 1:
		found = mini(found + 1, TIER_RUNGS.size() - 1)
	return found


func momentum(now_ms: int) -> float:
	if not live(now_ms):
		return 0.0
	var fresh := clampf(1.0 - float(maxi(0, now_ms - last_ms)) / float(maxi(1, window_ms)), 0.0, 1.0)
	return clampf((heat_fraction() * 0.65 + tempo() * 0.35) * (0.45 + 0.55 * fresh), 0.0, 1.0)


func reset() -> void:
	rung = 0
	length = 0
	last_ms = -100000
	last_gap_ms = -1
	fast_links = 0
	peak_rung = 0
