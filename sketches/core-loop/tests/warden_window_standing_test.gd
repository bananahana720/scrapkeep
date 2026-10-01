extends SceneTree

const WardenDrop := preload("res://src/combat/warden_drop.gd")

# A pulse that finds the window still standing never takes away time or banked share the
# player already earned (warden_drop.gd opened()):
#   full   a stagger longer than the fresh window (seconds + CORE_BONUS per core) keeps
#          its time; a shorter one is replaced by the fresh window
#   hold   a window still open keeps its banked share and held time and is not counted
#          again; its time is never cut below what stands

class StubWarden:
	var CORE_WINDOW := 2.5
	var max_hp := 400.0
	var hp := 400.0
	var _open_left := 0.0


var _failures := 0


func _init() -> void:
	var cores := 1
	var warden := StubWarden.new()
	var drop := WardenDrop.new(warden, {"gun_role": "full", "cores": func(): return cores})
	drop.staggered = true
	warden._open_left = 3.0
	var got := drop.opened(2.5)
	_check("full: a stagger between base and fresh is replaced by the fresh window", is_equal_approx(got, 3.5) and drop.windows == 1,
		"opened returned %.2f, windows %d (needs 3.50, 1)" % [got, drop.windows])

	warden._open_left = 5.0
	drop.staggered = true
	got = drop.opened(2.5)
	_check("full: a longer stagger keeps its time", is_equal_approx(got, 5.0) and drop.windows == 1,
		"opened returned %.2f, windows %d (needs 5.00, 1)" % [got, drop.windows])

	cores = 2
	var hold_warden := StubWarden.new()
	var hold := WardenDrop.new(hold_warden, {"gun_role": "hold", "cores": func(): return cores})
	hold.opened(2.5)
	hold.banked = 3.0
	hold.held = 2.0
	hold_warden._open_left = 0.5
	got = hold.opened(2.5)
	_check("hold: a standing window keeps the banked share", is_equal_approx(hold.banked, 3.0) and is_zero_approx(hold.damage["banked_lost"]),
		"banked %.2f, banked_lost %.2f (needs 3.00, 0.00)" % [hold.banked, hold.damage["banked_lost"]])
	_check("hold: a standing window is not counted again and keeps held time", hold.windows == 1 and is_equal_approx(hold.held, 2.0),
		"windows %d, held %.2f (needs 1, 2.00)" % [hold.windows, hold.held])
	_check("hold: a standing window is never cut short", got >= 0.5 and is_equal_approx(got, 4.5),
		"opened returned %.2f (needs 4.50)" % got)

	hold_warden._open_left = 9.0
	got = hold.opened(2.5)
	_check("hold: a window longer than a fresh one keeps its time", is_equal_approx(got, 9.0),
		"opened returned %.2f (needs 9.00)" % got)

	hold_warden._open_left = 0.0
	hold.banked = 1.0
	hold.opened(2.5)
	_check("hold: a closed window opens a new one and forfeits the leftover share", hold.windows == 2 and is_zero_approx(hold.banked),
		"windows %d, banked %.2f (needs 2, 0.00)" % [hold.windows, hold.banked])
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool, detail: String) -> void:
	print("%s %s: %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures += 1
