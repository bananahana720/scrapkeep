# smoke: timeout=300s
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const StatCache := preload("res://src/build/stat_cache.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")

# SI6 three-part sets (W13-INTEGRATION-3.md SI6). Three distinct members of one set give an
# optional rule change shown on the mech; losing one removes it and keeps the discovery;
# duplicates never count; no set is needed to clear a route.
# 1. Admission: every set is clean (alpha parts, enough of them class-neutral, no shared
#    member, more members than a set needs, known triggers); planted bad sets are refused.
# 2. Counting: three distinct members complete a set; two, three copies of one member, or
#    members of two sets do not.
# 3. The rule: a complete set adds its element triggers to the sheet, and the cached sheet
#    equals a full recompute.
# 4. Respec: dropping one member removes the rule from the cached sheet; the ledger keeps
#    the set, and completing it again is not a new discovery.
# 5. The sweep: 10,000 builds per size drawn through Parts.roll on the alpha list, one pilot
#    per build in turn: the share completing a set, per set and per pilot; every set is
#    reachable.
# 6. No route reads a set: only the sheet, the cache, the build and the tell load the module.
# 7. A driven run: picking up three members shows the tell and logs the set as found; selling
#    one hides the tell and drops the rule, and the run keeps the discovery.

const MODULE := "res://src/build/part_sets.gd"
const TELL := "res://src/presentation/set_tell.gd"
const SEED := 11
const BUILDS := 10000
const BUILD_SIZES := [8]
const OFFER_SIZE := 2
const READERS := ["src/build/part_sets.gd", "src/build/build_sheet.gd", "src/build/stat_cache.gd",
	"src/build/build.gd", "src/presentation/set_tell.gd"]
# Live Wire without Arc Coil, whose own slam arc would hide the set's.
const WIRE := ["live_line", "beacon_lamp", "echo_locator"]
const EXPECTED_REPORTS := 11

var S
var _game
var _build
var _ticks := 0
var _failures := 0
var _reports := 0


func _initialize() -> void:
	if not ResourceLoader.exists(MODULE):
		_report("part sets module", false, "%s is missing" % MODULE)
		_finish()
		return
	S = load(MODULE)
	_check_admission()
	_check_counting()
	_check_rule()
	_check_respec()
	_check_sweep()
	_check_readers()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
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
	print("part_sets_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	_reports += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _row(part_id: String) -> Dictionary:
	return Parts.row(part_id)


func _check_admission() -> void:
	var clean: Array = S.problems(_row, AlphaDefs.part_in_play)
	_report("every set admissible", clean.is_empty() and S.SETS.size() >= 3,
		"%d sets, problems %s" % [S.SETS.size(), clean])
	var planted := {
		"short": {"members": ["hot_rivets", "slag_rounds", "pin_setter"], "elements": {"slam": "arc"}},
		"shared": {"members": ["hot_rivets", "focus_lens", "long_barrel", "drop_weight"], "elements": {"dash": "frost"}},
		"classy": {"members": ["grip_tread", "sprint_cell", "cap_relay", "fast_hands"], "elements": {"slam": "frost"}},
		"unknown": {"members": ["cache_key", "re_rack", "overpressure", "brace_frame"], "elements": {"jump": "lava"}},
	}
	var found: Array = S.problems(_row, AlphaDefs.part_in_play, planted)
	var wants := ["short has 3 members", "hot_rivets is in short and shared", "classy has 2 class-neutral members", "unknown rule jump:lava"]
	var missed: Array = wants.filter(func(w): return not found.any(func(line): return w in line))
	_report("planted bad sets refused", missed.is_empty(), "missed %s of %d planted problems" % [missed, wants.size()])


func _check_counting() -> void:
	var cases := [
		[WIRE, ["live_wire"]],
		[WIRE.slice(0, 2), []],
		[["live_line", "live_line", "live_line"], []],
		[["live_line", "live_line", "beacon_lamp"], []],
		[["live_line", "beacon_lamp", "hot_rivets", "slag_rounds"], []],
		[["hot_rivets", "slag_rounds", "pin_setter", "rivet_plating", "rivet_seam", "deflect_plate"], ["shatter_crew", "ballast_rig"]],
		[WIRE + WIRE, ["live_wire"]],
	]
	var wrong: Array = []
	for c in cases:
		var got: Array = S.complete(c[0])
		if got != c[1]:
			wrong.append("%s gave %s, want %s" % [c[0], got, c[1]])
	_report("three distinct members complete a set; copies never count", wrong.is_empty(),
		"%d cases, wrong %s" % [cases.size(), wrong])


func _check_rule() -> void:
	var without := BuildSheet.from_parts(WIRE.slice(0, 2) + ["hot_rivets"])
	var with := BuildSheet.from_parts(WIRE)
	var cache := StatCache.new()
	var cached: RefCounted = cache.sync(WIRE)
	var ok: bool = with.sets == ["live_wire"] and "arc" in with.elements_for("slam") and "arc" in with.elements_for("shot") \
		and without.sets.is_empty() and not "arc" in without.elements_for("shot") and not "arc" in without.elements_for("slam") \
		and cached.sets == with.sets and cached.triggers == with.triggers
	_report("a complete set changes what slam and shot do", ok,
		"Live Wire held: sets %s, slam %s, shot %s; two members: slam %s, shot %s; cache sets %s triggers %s"
			% [with.sets, with.elements_for("slam"), with.elements_for("shot"), without.elements_for("slam"),
				without.elements_for("shot"), cached.sets, cached.triggers])
	var others := {"storm_front": ["slam", "frost"], "shatter_crew": ["shot", "frost"], "ballast_rig": ["dash", "frost"],
		"hair_trigger": ["dash", "arc"]}
	var bad: Array = []
	for key in others:
		var members: Array = S.SETS[key]["members"].slice(0, 3)
		var sheet := BuildSheet.from_parts(members)
		var short := BuildSheet.from_parts(members.slice(0, 2))
		var action: String = others[key][0]
		if not others[key][1] in sheet.elements_for(action) or others[key][1] in short.elements_for(action):
			bad.append("%s: %s %s with three, %s with two" % [key, action, sheet.elements_for(action), short.elements_for(action)])
	_report("each set's rule is its own trigger", bad.is_empty(), "wrong %s" % [bad])


func _check_respec() -> void:
	var cache := StatCache.new()
	var ledger = S.Ledger.new()
	var full: Array = WIRE + ["hot_rivets"]
	var first: Array = ledger.note(cache.sync(full).sets)
	var dropped: Array = full.duplicate()
	dropped.erase("beacon_lamp")
	var after: RefCounted = cache.sync(dropped)
	var kept: Array = ledger.note(after.sets)
	var again: Array = ledger.note(cache.sync(full).sets)
	var recompute := BuildSheet.from_parts(dropped)
	var ok: bool = first == ["live_wire"] and after.sets.is_empty() and not "arc" in after.elements_for("shot") \
		and after.triggers == recompute.triggers and kept.is_empty() and again.is_empty() and ledger.found == ["live_wire"]
	_report("respec removes the rule and keeps the discovery", ok,
		"first completion new %s; after selling Beacon Lamp sets %s shot %s (recompute %s); ledger %s; completing again new %s"
			% [first, after.sets, after.elements_for("shot"), recompute.elements_for("shot"), ledger.found, again])


func _sweep(run_seed: int, builds: int, size: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var pilots: Array = Parts.KITS.keys()
	var per_set := {}
	var per_pilot := {}
	var any := 0
	for n in builds:
		var class_id: String = pilots[n % pilots.size()]
		var held: Array = []
		var offered := {}
		for pick in size:
			var offer: Array = Parts.roll(rng, Parts.gate_rarities(rng.randi_range(0, 2)), class_id, held, OFFER_SIZE, [], offered)
			if offer.is_empty():
				continue
			for key in offer:
				offered[key] = offered.get(key, 0) + 1
			held.append(offer[rng.randi_range(0, offer.size() - 1)])
		var done: Array = S.complete(held)
		for key in done:
			per_set[key] = per_set.get(key, 0) + 1
		if not done.is_empty():
			any += 1
			per_pilot[class_id] = per_pilot.get(class_id, 0) + 1
	return {"any": float(any) / builds, "per_set": per_set, "per_pilot": per_pilot, "builds": builds, "pilots": pilots.size()}


func _check_sweep() -> void:
	var before = Synergies.table
	Synergies.table = AlphaDefs
	var lines: Array = []
	var unreachable: Array = []
	for size in BUILD_SIZES:
		var stats := _sweep(SEED, BUILDS, size)
		var per_pilot := {}
		for pilot in stats["per_pilot"]:
			per_pilot[pilot] = "%.1f%%" % (100.0 * stats["per_pilot"][pilot] / (stats["builds"] / stats["pilots"]))
		var per_set := {}
		for key in S.SETS:
			per_set[key] = "%.1f%%" % (100.0 * stats["per_set"].get(key, 0) / stats["builds"])
			if size == BUILD_SIZES[-1] and stats["per_set"].get(key, 0) == 0:
				unreachable.append(key)
		print("part_sets sweep | seed %d | %d builds of %d parts on the alpha list | any set %.1f%% | per set %s | per pilot %s"
			% [SEED, stats["builds"], size, 100.0 * stats["any"], per_set, per_pilot])
		lines.append("%d parts: %.1f%% complete a set" % [size, 100.0 * stats["any"]])
	Synergies.table = before
	_report("the sweep reports the set share", unreachable.is_empty(), "%s; unreachable sets %s" % [lines, unreachable])


func _check_readers() -> void:
	var stray: Array = []
	for path in _gd_files("res://src"):
		var rel: String = path.trim_prefix("res://")
		if rel in READERS:
			continue
		var text := FileAccess.get_file_as_string(path)
		if "part_sets.gd" in text or "PartSets" in text:
			stray.append(rel)
	_report("no route, gate or pocket reads a set", stray.is_empty(), "readers outside the build: %s" % [stray])


func _gd_files(dir: String) -> Array:
	var out: Array = []
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	return out


func _check_driven_run() -> void:
	var tell = _build.get("set_tell")
	_report("the build carries the tell", tell != null and tell.get_script() == load(TELL),
		"build.set_tell is %s" % [tell])
	if tell == null:
		_report("picking up a set shows it", false, "no tell")
		_report("selling a member hides it and keeps the find", false, "no tell")
		return
	var run = _game.run
	for part_id in WIRE:
		run.add_part(part_id, "test")
	var shown: Array = tell.shown()
	var found: Array = _build.found()
	var live_shot: Array = _build.sheet.elements_for("shot")
	_report("picking up a set shows it", shown == ["live_wire"] and _build.sheet.sets == ["live_wire"] and "arc" in live_shot
		and found.any(func(text): return text.begins_with("Live Wire")),
		"after %s: tell %s, sheet sets %s, shot %s, found %s" % [WIRE, shown, _build.sheet.sets, live_shot, found])
	_build.shop._remove_part("beacon_lamp")
	var hidden: Array = tell.shown()
	_report("selling a member hides it and keeps the find", hidden.is_empty() and _build.sheet.sets.is_empty()
		and not "arc" in _build.sheet.elements_for("shot") and _build.set_ledger.found == ["live_wire"]
		and _build.found().any(func(text): return text.begins_with("Live Wire")),
		"after selling Beacon Lamp: tell %s, sheet sets %s, shot %s, ledger %s"
			% [hidden, _build.sheet.sets, _build.sheet.elements_for("shot"), _build.set_ledger.found])
