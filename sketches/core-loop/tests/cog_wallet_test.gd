extends SceneTree

const Game := preload("res://src/game.gd")
const RunState := preload("res://src/core/run_state.gd")
const Fabricators := preload("res://src/build/fabricators.gd")

# The cog wallet (CG1): scrap is mass and cogs are money, and neither moves the other.
#   - a scrap piece the magnet takes raises mass and no cogs; a gear raises cogs and no mass;
#   - spend_cogs short of the price fails and leaves the wallet as it was;
#   - a shop buy and a drive-through fabricator spend cogs and never mass;
#   - a sale (the shop's refund path) pays cogs and keeps mass;
#   - recover_mass and a theft never touch cogs; a retry rewinds them with the checkpoint;
#   - the wallet round-trips through the entrance document.
# Runs on the flat top shelf with ctx.calm set; the field is cleared before each pickup.

const LANE_X := -62.0
const HOOP_Z := -70.0
const APPROACH := 16.0
const APPROACH_SPEED := 20.0
const PICKUP_TICKS := 30
const PART := "long_spool"

var _game
var _build
var _failures := 0
var _ticks := 0
var _phase := "boot"
var _wait := 0
var _before := {}
var _fab := {}
var _gained: Array = []
var _cogs_heard: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks > 60 * 20:
		_report("timeout", false, "stalled in phase %s" % _phase)
		return _finish()
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.events.cogs_collected.connect(func(amount: int, total: int): _cogs_heard.append([amount, total]))
			_game.events.part_gained.connect(func(id: String, source: String): _gained.append([id, source]))
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_build = _game.ctx.get_meta("build")
			_phase = "settle"
		"settle":
			_wait += 1
			if _wait == 10:
				_drop("scrap")
		"scrap":
			_wait += 1
			if _wait == PICKUP_TICKS:
				var r = _game.run
				_report("scrap pickup", r.mass > _before["mass"] + 0.5 and r.cogs == _before["cogs"],
					"mass %.1f -> %.1f, cogs %d -> %d" % [_before["mass"], r.mass, _before["cogs"], r.cogs])
				_drop("cog")
		"cog":
			_wait += 1
			if _wait == PICKUP_TICKS:
				var r = _game.run
				_report("cog pickup", r.cogs == _before["cogs"] + 1 and is_equal_approx(r.mass, _before["mass"])
						and r.scrap == _before["scrap"],
					"cogs %d -> %d, mass %.1f -> %.1f, scrap %d -> %d"
						% [_before["cogs"], r.cogs, _before["mass"], r.mass, _before["scrap"], r.scrap])
				_report("cog pickup announces itself", _cogs_heard == [[1, _game.run.cogs]], "cogs_collected %s, wallet %d" % [_cogs_heard, _game.run.cogs])
				_check_cog_sound()
				_check_spend()
				_check_shop()
				_check_recover()
				_check_doc()
				_start_fabricator()
		"fab":
			if (_game.player.ball_position() - (_fab["at"] as Vector3)).dot(_fab["facing"]) > 0.0:
				_wait += 1
			if _wait == 6:
				_check_fabricator()
				return _finish()
	return false


func _drop(kind: String) -> void:
	_build.scrap.clear()
	_snap()
	var at: Vector3 = _game.player.ball_position()
	if kind == "scrap":
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		_build.scrap.drop(at, 1, rng)
	else:
		_build.scrap.drop_cogs(at, 1)
	_wait = 0
	_phase = kind


func _snap() -> void:
	_before = {"mass": _game.run.mass, "cogs": _game.run.cogs, "scrap": _game.run.scrap}


# Repeated gears climb their own streak and sound as cog_tick, apart from scrap's.
func _check_cog_sound() -> void:
	var audio = _game.presentation.audio
	audio.cue_log.clear()
	audio.cog_streak.reset()
	_game.events.cogs_collected.emit(1, 2)
	_game.events.cogs_collected.emit(1, 3)
	var cues: Array = audio.cue_log.filter(func(c: Array): return c[0] == "cogs_collected")
	var rose: bool = cues.size() == 2 and float(cues[1][4]) > float(cues[0][4])
	_report("gears climb the pentatonic", rose, "cues %s" % [cues])


func _check_spend() -> void:
	var r = _game.run
	r.cogs = 5
	var short: bool = r.spend_cogs(6)
	var negative: bool = r.spend_cogs(-1)
	var exact: bool = r.spend_cogs(5)
	_report("spend_cogs short", not short and not negative and exact and r.cogs == 0,
		"spend 6 of 5: %s, spend -1: %s, spend 5 of 5: %s, left %d" % [short, negative, exact, r.cogs])


func _check_shop() -> void:
	var r = _game.run
	var shop = _build.shop
	shop.enter()
	r.cogs = 500
	_snap()
	var price: int = shop.shelf_offers()[0]["price"]
	var bought: Dictionary = shop.buy(0)
	_report("shop buy spends cogs", bought["ok"] and r.cogs == _before["cogs"] - price and is_equal_approx(r.mass, _before["mass"])
			and r.scrap == _before["scrap"],
		"price %d: cogs %d -> %d, mass %.1f -> %.1f, scrap %d -> %d"
			% [price, _before["cogs"], r.cogs, _before["mass"], r.mass, _before["scrap"], r.scrap])
	r.add_part("light_frame", "test")
	_snap()
	var quote: int = shop.sell_quote("light_frame")
	var sold: Dictionary = shop.sell("light_frame")
	_report("sell pays cogs", sold["ok"] and quote > 0 and r.cogs == _before["cogs"] + quote
			and is_equal_approx(r.mass, _before["mass"]) and r.scrap == _before["scrap"],
		"quote %d: cogs %d -> %d, mass %.1f -> %.1f" % [quote, _before["cogs"], r.cogs, _before["mass"], r.mass])
	shop.leave()


func _check_recover() -> void:
	var r = _game.run
	r.cogs = 12
	_snap()
	r.recover_mass(9)
	var recovered: bool = r.cogs == 12 and is_equal_approx(r.mass, _before["mass"] + 9.0)
	r.lose_scrap(4, Vector3.ZERO, "test")
	_report("recover and theft leave cogs", recovered and r.cogs == 12,
		"cogs 12 -> %d after recover_mass(9) and lose_scrap(4); mass %.1f -> %.1f" % [r.cogs, _before["mass"], r.mass])
	r.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	r.add_cogs(30)
	r.restore()
	_report("retry rewinds cogs", r.cogs == 12, "cogs 12 at the checkpoint, +30, restored to %d" % r.cogs)


func _check_doc() -> void:
	var r = _game.run
	r.cogs = 37
	var doc: Dictionary = r.to_entrance_doc()
	var back := RunState.new(null)
	var applied: bool = back.from_entrance_doc(JSON.parse_string(JSON.stringify(doc)))
	_report("entrance doc carries cogs", applied and back.cogs == 37 and typeof(back.cogs) == TYPE_INT,
		"applied %s, cogs %s" % [applied, back.cogs])


func _start_fabricator() -> void:
	_build.scrap.clear()
	_build.fabricators.clear()
	var at: Vector3 = _game.ctx.terrain.drop_point(LANE_X, HOOP_Z, 0.0)
	_fab = _build.fabricators.add_at(at, Vector3(0.0, 0.0, 1.0), PART)
	_game.run.cogs = 60
	_gained.clear()
	var start: Vector3 = at - Vector3(0.0, 0.0, 1.0) * APPROACH
	_game.player.reset_to(_game.ctx.terrain.drop_point(start.x, start.z, 1.05), Vector3(0.0, 0.0, 1.0) * APPROACH_SPEED)
	_snap()
	_before["parts"] = _game.run.parts.size()
	_wait = 0
	_phase = "fab"


func _check_fabricator() -> void:
	var r = _game.run
	var price := Fabricators.hoop_price(PART, _before["parts"])
	_report("fabricator spends cogs", _gained == [[PART, "fabricator"]] and r.cogs == _before["cogs"] - price
			and is_equal_approx(r.mass, _before["mass"]),
		"price %d: part_gained %s, cogs %d -> %d, mass %.1f -> %.1f"
			% [price, _gained, _before["cogs"], r.cogs, _before["mass"], r.mass])


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _finish() -> bool:
	print("cog_wallet_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
