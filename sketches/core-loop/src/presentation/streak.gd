extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")


var window_ms := 700
var cap := 9
var rung := 0
var length := 0
var last_ms := -100000


static func for_kind(kind: String) -> RefCounted:
	var streak: RefCounted = load("res://src/presentation/streak.gd").new()
	var row := EventKinds.juice(kind)
	streak.window_ms = int(row.get("chain_ms", 700))
	streak.cap = int(row.get("chain_cap", 9))
	return streak


func bump(now_ms: int) -> int:
	if now_ms - last_ms < window_ms:
		rung = mini(rung + 1, cap)
		length += 1
	else:
		rung = 0
		length = 1
	last_ms = now_ms
	return rung


func live(now_ms: int) -> bool:
	return length > 0 and now_ms - last_ms < window_ms


func reset() -> void:
	rung = 0
	length = 0
	last_ms = -100000
