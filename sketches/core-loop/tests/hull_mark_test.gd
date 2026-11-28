extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")
const HullMark := preload("res://src/core/hull_mark.gd")
const TradePockets := preload("res://src/world/trade_pockets.gd")
const Interactables := preload("res://src/world/interactables.gd")

# Marked hull (docs/systems-audit/feature-fit.md, new mechanic 1), in the running game as Rivet
# in calm:
#   - flag off: a health price marks nothing, and the offer reads as before;
#   - flag on: the device reads `--marked-hull=on`, the price says "max HP", paying lowers max
#     hull by the price, regen fills only to the mark, and the build sheet keeps the mark when it
#     re-applies;
#   - the HUD's hull bar spans the unmarked max and caps at the mark (gauge set_cap);
#   - a retry's rewind, the entrance doc round trip and its validation carry the mark;
#   - a heft or part change re-applies the sheet (build.gd on scrap) and keeps the mark;
#   - the mark never takes max hull below the floor, and lifting returns exactly what it took;
#   - the Warden break (beacon_unsealed) and a ward's heal lift it.

const RIVET := 1

var _game
var _failures := 0
var _ticks := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.player.source = Intent.Scripted.new()
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(RIVET)
	elif _ticks == 30:
		_run_checks()
		print("hull_mark_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	return false


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng


func _full(run) -> void:
	run.hp = run.max_hp
	run.since_damage = 99.0


func _run_checks() -> void:
	var run = _game.run
	var tuning = _game.tuning
	_full(run)
	var unmarked: float = run.max_hp

	# Flag off: today's price.
	_check("flag default", tuning.option("marked_hull") == "off", "marked_hull defaults off")
	var plain: Dictionary = StakeDevices.make_offer("blood_shrine", 2, "health", run, _rng())
	StakeDevices.take(plain, run, Vector3.ZERO)
	_check("off marks nothing", is_equal_approx(run.max_hp, unmarked) and HullMark.held(run) == 0.0 and not run.trade_memory.has(HullMark.KEY),
		"max %.1f after a %d HP price with the flag off" % [run.max_hp, plain["cost"]])
	_check("off words", StakeDevices.offer_words(plain).contains("%d HP" % plain["cost"]) and not StakeDevices.offer_words(plain).contains("max"), StakeDevices.offer_words(plain))
	_full(run)

	# Flag on: the offer marks, says so, and the payment lowers max hull.
	tuning.apply_args(PackedStringArray(["--marked-hull=on"]), "launch")
	_check("flag on", tuning.option("marked_hull") == "on", "--marked-hull=on applies")
	var o: Dictionary = StakeDevices.make_offer("trade_chest", 1, "health", run, _rng(), tuning.option("marked_hull") == "on")
	var cost := float(o["cost"])
	var words: String = StakeDevices.offer_words(o)
	_check("on words", words.begins_with("Weld %d HP" % int(cost)) and words.split(" ", false).size() <= Interactables.PROMPT_WORDS,
		"\"%s\", %d words of %d" % [words, words.split(" ", false).size(), Interactables.PROMPT_WORDS])
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	var r: Dictionary = StakeDevices.take(o, run, Vector3.ZERO)
	# A max-health part the chest pays may raise the sheet; the mark comes off whatever it is.
	_game.build.sheet.apply(tuning, run)
	var sheet_max: float = run.base_max_hp() + _game.build.sheet.max_hp_bonus
	_check("stake", bool(r.get("ok", false)) and is_equal_approx(HullMark.held(run), cost) and is_equal_approx(run.max_hp, sheet_max - cost),
		"paid %d: mark %.1f, max %.1f (sheet %.1f)" % [int(cost), HullMark.held(run), run.max_hp, sheet_max])

	# Regen fills only to the mark.
	run.since_damage = 99.0
	run.advance(60.0)
	_check("regen to mark", is_equal_approx(run.hp, run.max_hp) and run.hp < sheet_max - cost + 0.01, "hp %.1f of marked max %.1f" % [run.hp, run.max_hp])

	# The sheet re-applies without wiping the mark.
	_game.build.sheet.apply(tuning, run)
	_check("sheet keeps mark", is_equal_approx(run.max_hp, sheet_max - cost), "max %.1f after sheet.apply" % run.max_hp)
	# Fresh scrap re-applies max hull through build.gd's scrap hook; the mark stays off it.
	run.add_scrap(60, Vector3.ZERO)
	var grown: float = run.base_max_hp() + _game.build.sheet.max_hp_bonus
	_check("scrap keeps mark", is_equal_approx(HullMark.held(run), cost) and is_equal_approx(run.max_hp, grown - cost),
		"after 60 scrap: max %.1f of unmarked %.1f, mark %.1f" % [run.max_hp, grown, HullMark.held(run)])
	sheet_max = grown

	# The hull bar: full is the unmarked max, and the cap sits at the marked max.
	_game.hud._process(0.016)
	var cap: float = _game.hud.hull_cap_shown()
	var fill: float = _game.hud.hull_shown()
	_check("bar caps at mark", is_equal_approx(cap, run.max_hp / (run.max_hp + cost)) and is_equal_approx(fill, run.hp / (run.max_hp + cost)),
		"cap %.3f, fill %.3f (max %.1f, mark %.1f)" % [cap, fill, run.max_hp, cost])

	# A retry rewinds the mark with the max hull it lowered (the stage start, taken before it).
	run.restore()
	_game.build.sheet.apply(tuning, run)
	_check("retry rewinds", HullMark.held(run) == 0.0 and is_equal_approx(run.max_hp, run.base_max_hp() + _game.build.sheet.max_hp_bonus),
		"after restore: mark %.1f, max %.1f" % [HullMark.held(run), run.max_hp])

	# Stake again, then cross a stage entrance with the mark held.
	var o2: Dictionary = StakeDevices.make_offer("trade_chest", 1, "health", run, _rng(), true)
	StakeDevices.take(o2, run, Vector3.ZERO)
	cost = float(o2["cost"])

	# The entrance doc carries it and validates; a bad mark is refused. A doc is written at a stage
	# entrance, so the mark rides in when it was staked before the cut: checkpoint it here.
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	var doc: Dictionary = run.to_entrance_doc()
	var trade_doc: Dictionary = TradePockets.to_doc(run.trade_memory)
	_check("doc carries", is_equal_approx(float(trade_doc.get(HullMark.KEY, -1.0)), cost) and TradePockets.validate_doc(trade_doc, run.stage) == "",
		"trade doc mark %s" % trade_doc.get(HullMark.KEY))
	var bad: Dictionary = trade_doc.duplicate(true)
	bad[HullMark.KEY] = -5.0
	_check("bad mark refused", TradePockets.validate_doc(bad, run.stage) != "", TradePockets.validate_doc(bad, run.stage))
	_check("doc validates", run.validate_entrance_doc(doc) == "", "entrance doc: '%s'" % run.validate_entrance_doc(doc))
	# Load the doc back: the mark and the marked max return together.
	var marked_max: float = run.max_hp
	run.trade_memory.erase(HullMark.KEY)
	var loaded: bool = run.from_entrance_doc(JSON.parse_string(JSON.stringify(doc)))
	_check("doc round trip", loaded and is_equal_approx(HullMark.held(run), cost) and is_equal_approx(run.max_hp, marked_max),
		"loaded %s: mark %.1f, max %.1f of %.1f" % [loaded, HullMark.held(run), run.max_hp, marked_max])
	_game.build.sheet.apply(tuning, run)

	# The floor: when the unmarked max falls under a big mark, the mark is trimmed, never the
	# floor, and lifting returns exactly what it took.
	_full(run)
	var whole: float = run.max_hp
	StakeDevices.take(StakeDevices.make_offer("trade_chest", 3, "health", run, _rng(), true), run, Vector3.ZERO)
	var shrunk := whole * 0.5
	var capped := HullMark.ceiling(run, shrunk)
	run.set_max_hp(capped)
	_check("floor", capped >= ceilf(shrunk * HullMark.FLOOR_SHARE) and is_equal_approx(capped + HullMark.held(run), shrunk),
		"unmarked %.1f -> %.1f: max %.1f, mark %.1f" % [whole, shrunk, capped, HullMark.held(run)])
	HullMark.lift(run)
	_check("lift exact", is_equal_approx(run.max_hp, shrunk) and HullMark.held(run) == 0.0, "after lift: max %.1f of %.1f" % [run.max_hp, shrunk])
	_game.build.sheet.apply(tuning, run)

	# The Warden break lifts it, and the hull rises with the max like any max-hull gain.
	_full(run)
	var before_max: float = run.max_hp
	var shrine: Dictionary = StakeDevices.make_offer("blood_shrine", 1, "health", run, _rng(), true)
	StakeDevices.take(shrine, run, Vector3.ZERO)
	var hp_marked: float = run.hp
	_game.ctx.events.beacon_unsealed.emit(run.stage)
	_check("warden lifts", HullMark.held(run) == 0.0 and is_equal_approx(run.max_hp, before_max) and is_equal_approx(run.hp, hp_marked + float(shrine["cost"])),
		"after the break: mark %.1f, max %.1f of %.1f, hp %.1f" % [HullMark.held(run), run.max_hp, before_max, run.hp])

	# A ward's heal lifts it too.
	_full(run)
	StakeDevices.take(StakeDevices.make_offer("blood_shrine", 1, "health", run, _rng(), true), run, Vector3.ZERO)
	run.bonus_cores = 1
	var ward: Dictionary = StakeDevices.make_offer("healing_ward", 1, "cores", run, _rng())
	var healed: Dictionary = StakeDevices.take(ward, run, Vector3.ZERO)
	_check("ward lifts", bool(healed.get("ok", false)) and HullMark.held(run) == 0.0 and is_equal_approx(run.max_hp, before_max),
		"after the ward: mark %.1f, max %.1f" % [HullMark.held(run), run.max_hp])
