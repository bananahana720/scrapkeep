# smoke: timeout=300s
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const PartDef := preload("res://src/build/part_def.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const StatCache := preload("res://src/build/stat_cache.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")

# SG15 three-level parts (W13-INTEGRATION-3.md SG15). A part is picked in three levels and a
# higher level replaces the lower, as a capped stack of 3 with per-level numbers, not a
# fourth stack rule; the build rebuilds from current selections.
# 1. Admission: the levelled rows are clean and on the alpha list; planted bad rows are refused.
# 2. Replace, never add: n copies fold exactly level min(n, 3)'s numbers, wherever they sit in
#    the held list, and the cached sheet equals a full recompute; selling a copy drops a level.
# 3. Offers: 200 draws per pilot per source shape on the alpha list never show a part held at
#    level 3; the same draws at level 2 do show levelled parts (the control).
# 4. Stake devices: a trade chest's part win, drawn when every tier-1 part is held (the
#    fallback to held parts), never names a part at level 3; at level 2 it does (the control).
# 5. Card builders: the reward gate, fabricator and shop card functions read an offered part
#    only through Parts.offer_def and offer_headline; a planted Parts.def( is caught.
# 6. A driven run: two Hot Rivets give level 2's numbers to the tuning, and an offer of a held
#    part names the level it would reach.

const DRAWS := 200
const SEED := 15
# The offer shapes the sources use: a gate pair, a fabricator or vault single, a shop shelf.
const SHAPES := [["gate", 2], ["single", 1], ["shelf", 3]]
const EXPECTED_REPORTS := 14
# Andrew's ruling (2026-10-16): levels stay on these three neutral shelf parts.
const LEVELLED := ["hot_rivets", "rivet_plating", "magnet_spool"]

var _game
var _build
var _ticks := 0
var _failures := 0
var _reports := 0


func _initialize() -> void:
	_check_admission()
	_check_replace()
	_check_offers()
	_check_stakes()
	_check_card_guard()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_build = _game.ctx.get_meta("build")
		_game.flow.press_start()
		_game.flow.choose_class(0)
	elif _ticks == 10:
		_check_driven_run()
		return _finish()
	return false


func _finish() -> bool:
	if _reports != EXPECTED_REPORTS:
		_failures += 1
		print("FAIL report count: %d of %d checks reported (a check died mid-way)" % [_reports, EXPECTED_REPORTS])
	print("part_levels_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	_reports += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


static func levelled() -> Array:
	return Parts.ids().filter(func(key): return not Parts.rows()[key].get("levels", []).is_empty())


func _check_admission() -> void:
	var ids := levelled()
	var problems: Array = []
	for key in ids:
		problems.append_array(Parts.level_problems(key, Parts.rows()[key]))
		if not AlphaDefs.part_in_play(key):
			problems.append("%s is not on the alpha list" % key)
	_report("levelled rows admissible", problems.is_empty() and ids == LEVELLED,
		"%d levelled parts %s, problems %s" % [ids.size(), ids, problems])
	var base := {"punch": 4.0, "mods": {"weapon_damage": 1.1}, "stack": "capped", "cap": 3}
	var planted := {
		"two_levels": {"levels": [{"punch": 4.0}, {"punch": 6.0}]},
		"linear": {"stack": "linear", "cap": 0, "levels": [{"punch": 4.0}, {"punch": 6.0}, {"punch": 8.0}]},
		"new_key": {"levels": [{"punch": 4.0}, {"punch": 6.0, "magnet": 2.0}, {"punch": 8.0}]},
		"new_knob": {"levels": [{"punch": 4.0}, {"mods": {"weapon_rate": 1.2}}, {"punch": 8.0}]},
		"falls": {"levels": [{"punch": 4.0}, {"punch": 9.0}, {"punch": 7.0}]},
		"drifts": {"levels": [{"punch": 5.0}, {"punch": 6.0}, {"punch": 8.0}]},
	}
	var wants := {"two_levels": "has 2 levels", "linear": "capped stack", "new_key": "sets magnet",
		"new_knob": "moves weapon_rate", "falls": "level 3 punch falls", "drifts": "level 1 punch"}
	var missed: Array = []
	for key in planted:
		var r: Dictionary = base.duplicate(true)
		r.merge(planted[key], true)
		var found: Array = Parts.level_problems(key, r)
		if not found.any(func(line): return wants[key] in line):
			missed.append("%s gave %s" % [key, found])
	_report("planted bad levels refused", missed.is_empty(), "%d planted rows, missed %s" % [planted.size(), missed])


static func _numbers(sheet) -> Dictionary:
	return {"punch": sheet.punch, "mods": sheet.mods, "max_hp": sheet.max_hp_bonus, "magnet": sheet.magnet}


static func _level_numbers(key: String, level: int) -> Dictionary:
	var d: Resource = Parts.def_at(key, level)
	var sheet := BuildSheet.new()
	sheet.punch = d.punch
	sheet._fold(d.mods, {}, {})
	sheet.max_hp_bonus = d.max_hp_bonus
	sheet.magnet = d.magnet
	return _numbers(sheet)


func _check_replace() -> void:
	var wrong: Array = []
	var cache_wrong: Array = []
	for key in levelled():
		var cache := StatCache.new()
		for n in [1, 2, 3, 4, 6]:
			var want := _level_numbers(key, mini(n, PartDef.MAX_LEVEL))
			for held in [_copies(key, n), ["long_barrel"] + _copies(key, n - 1) + ["fast_hands", key]]:
				var got := _numbers(BuildSheet.from_parts(held))
				if held[0] == "long_barrel":
					want = _level_numbers(key, mini(n, PartDef.MAX_LEVEL))
					want["mods"] = want["mods"].duplicate()
					want["mods"]["weapon_range"] = want["mods"].get("weapon_range", 1.0) * Parts.def("long_barrel").mods["weapon_range"]
				if got != want:
					wrong.append("%s x%d in %s: %s, want %s" % [key, n, held, got, want])
				if _numbers(cache.sync(held)) != got:
					cache_wrong.append("%s %s" % [key, held])
	_report("level n's numbers replace level n-1's, never add", wrong.is_empty(),
		"%d levelled parts at 1, 2, 3, 4 and 6 copies, alone and mixed: wrong %s" % [levelled().size(), wrong])
	_report("the cached sheet is the full recompute", cache_wrong.is_empty(), "differs on %s" % [cache_wrong])
	var sold := StatCache.new()
	sold.sync(_copies("hot_rivets", 3))
	var down: RefCounted = sold.sync(_copies("hot_rivets", 2))
	_report("selling a copy drops a level", is_equal_approx(down.punch, Parts.def_at("hot_rivets", 2).punch)
		and _numbers(down) == _numbers(BuildSheet.from_parts(_copies("hot_rivets", 2))),
		"three Hot Rivets then two: punch %s (level 2 is %s)" % [down.punch, Parts.def_at("hot_rivets", 2).punch])


static func _copies(key: String, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(key)
	return out


func _draws(level: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var held: Array = []
	for key in levelled():
		held.append_array(_copies(key, level))
	var shown := {}
	var total := 0
	for pilot in PartOffers.KITS:
		for shape in SHAPES:
			for i in DRAWS:
				var cores := rng.randi_range(0, 2)
				var offer: Array = PartOffers.roll_gate(rng, PartOffers.gate_rarities(cores), pilot, held, shape[1], 1 + i % 3, {}, Parts.offer_ops()) \
					if shape[0] == "gate" else Parts.roll(rng, PartOffers.gate_rarities(cores), pilot, held, shape[1])
				total += 1
				for key in offer:
					if Parts.level_of(key, held) > 0:
						shown[key] = shown.get(key, 0) + 1
	return {"shown": shown, "total": total}


func _check_offers() -> void:
	var before = Synergies.table
	Synergies.set_table(AlphaDefs)
	var top := _draws(PartDef.MAX_LEVEL)
	var mid := _draws(PartDef.MAX_LEVEL - 1)
	Synergies.set_table(before)
	print("part_levels offers | %d draws a level (%d per pilot per shape, 6 pilots, %s) | at level 3 shown %s | at level 2 shown %s"
		% [top["total"], DRAWS, SHAPES, top["shown"], mid["shown"]])
	_report("no offer shows a part at level 3", top["total"] == DRAWS * PartOffers.KITS.size() * SHAPES.size() and top["shown"].is_empty(),
		"%d draws holding every levelled part at level 3: shown %s" % [top["total"], top["shown"]])
	_report("a part at level 2 is still offered", mid["shown"].size() == levelled().size(),
		"%d draws holding every levelled part at level 2: shown %s of %s" % [mid["total"], mid["shown"].keys(), levelled()])


# The functions that build an offer card, by file: none may read an offered id through
# Parts.def( or Parts.headline(, which give level 1.
const CARD_BUILDERS := {
	"res://src/build/reward_gates.gd": ["_place"],
	"res://src/build/fabricators.gd": ["_refresh_label"],
	"res://src/build/shop.gd": ["_offer"],
}
const LEVEL_ONE_READS := ["Parts.def(", "Parts.headline("]


# The body of func name in source: from its line to the next top-level line.
static func _body(source: String, name: String) -> String:
	var lines := source.split("\n")
	var out := PackedStringArray()
	var inside := false
	for line in lines:
		if line.begins_with("func %s(" % name) or line.begins_with("static func %s(" % name):
			inside = true
		elif inside and line != "" and not line.begins_with("\t") and not line.begins_with("#"):
			break
		if inside:
			out.append(line)
	return "\n".join(out)


# One line per card builder that reads level 1, or that is missing; [] is clean.
static func card_problems(sources: Dictionary) -> Array:
	var out: Array = []
	for path in CARD_BUILDERS:
		for name in CARD_BUILDERS[path]:
			var body := _body(sources[path], name)
			if body == "":
				out.append("%s has no %s" % [path.get_file(), name])
			for bad in LEVEL_ONE_READS:
				if bad in body:
					out.append("%s %s calls %s" % [path.get_file(), name, bad])
	return out


func _check_card_guard() -> void:
	var sources := {}
	for path in CARD_BUILDERS:
		sources[path] = FileAccess.get_file_as_string(path)
	var clean := card_problems(sources)
	var planted := sources.duplicate()
	var fab := "res://src/build/fabricators.gd"
	planted[fab] = String(planted[fab]).replace("Parts.offer_headline(part_id, held)", "Parts.headline(part_id)")
	var caught := card_problems(planted)
	_report("card builders read offers at the next level", clean.is_empty(), "problems %s" % [clean])
	_report("a planted level-1 read is caught", caught == ["fabricators.gd _refresh_label calls Parts.headline("],
		"planting Parts.headline(part_id) in the fabricator card: %s" % [caught])


class StakeRun:
	var parts: Array = []
	func class_id() -> String:
		return ""


func _stake_wins(level: int) -> Dictionary:
	var run := StakeRun.new()
	for key in Parts.offer_pool("", ["common", "rare", "relic"]):
		if Parts.def(key).tier == 1 and not key in LEVELLED:
			run.parts.append(key)
	for key in LEVELLED:
		run.parts.append_array(_copies(key, level))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var wins := {}
	for i in DRAWS:
		var win: String = StakeDevices._pick_part(1, run, rng)
		if win in LEVELLED:
			wins[win] = wins.get(win, 0) + 1
	return wins


func _check_stakes() -> void:
	var top := _stake_wins(PartDef.MAX_LEVEL)
	var mid := _stake_wins(PartDef.MAX_LEVEL - 1)
	_report("a stake win never names a part at level 3", top.is_empty(),
		"%d tier-1 wins with every tier-1 part held and the levelled ones at level 3: levelled wins %s" % [DRAWS, top])
	_report("a stake win can name a part at level 2", mid.size() == LEVELLED.size(),
		"the same draws at level 2: levelled wins %s" % [mid])


func _check_driven_run() -> void:
	var run = _game.run
	var plain: String = _build.offer_mark("hot_rivets")
	run.add_part("hot_rivets", "test")
	var one: String = _build.offer_mark("hot_rivets")
	run.add_part("hot_rivets", "test")
	var two: String = _build.offer_mark("hot_rivets")
	var damage: float = _game.tuning.mod("weapon_damage")
	var want: float = Parts.def_at("hot_rivets", 2).mods["weapon_damage"]
	_report("the build plays level 2 and names the next level", is_equal_approx(damage, want)
		and is_equal_approx(_build.punch_bonus(), Parts.def_at("hot_rivets", 2).punch)
		and plain == "" and one == "* level II *" and two == "* level III *",
		"two Hot Rivets: weapon_damage x%.4f (level 2 x%.2f), punch %s; offer marks %s / %s / %s"
			% [damage, want, _build.punch_bonus(), [plain], [one], [two]])
	var ball: Vector3 = _game.player.ball_position()
	var fab: Dictionary = _build.fabricators.add_at(ball + Vector3(0.0, 0.0, 30.0), Vector3(0.0, 0.0, 1.0), "hot_rivets")
	_build.fabricators._refresh_label(fab, 0, run.parts)
	var fab_text: String = fab["text"]
	_build.fabricators.clear()
	var shelf: Dictionary = _build.shop._offer("hot_rivets", false, 0)
	var offers: Array = _build.gates.open(["hot_rivets", "rivet_plating"], ball, Vector3.FORWARD, run.parts)
	_build.gates.close()
	var next: Resource = Parts.def_at("hot_rivets", 3)
	var first: Resource = Parts.def("rivet_plating")
	var card: Dictionary = offers[0] if offers.size() == 2 else {}
	var fresh: Dictionary = offers[1] if offers.size() == 2 else {}
	var punch_words := "+%d punch" % int(next.punch)
	_report("fabricator and shop cards show the level it would give", next.text in fab_text and punch_words in fab_text
		and shelf.get("text", "") == next.text,
		"holding two Hot Rivets: fabricator card %s; shop card %s (level 3: %s, %s)" % [[fab_text], [shelf.get("text", "")], next.text, punch_words])
	_report("an offer card shows the level it would give", card.get("text", "") == next.text
		and is_equal_approx(float(card.get("punch", 0.0)), next.punch) and ("+%d punch" % int(next.punch)) in String(card.get("headline", ""))
		and fresh.get("text", "") == first.text,
		"holding two Hot Rivets, its card reads %s / %s / punch %s (level 3: %s); an unheld Rivet Plating reads %s"
			% [[card.get("headline", "")], [card.get("text", "")], card.get("punch", 0.0), next.text, [fresh.get("text", "")]])
