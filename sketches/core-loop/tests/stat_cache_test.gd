extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const Synergies := preload("res://src/build/synergies.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const RunTier := preload("res://src/core/run_tier.gd")

# SI5 stat cache (W13-INTEGRATION-3 SI5). Parts declare the stat categories they touch
# (stat_touches); the build's cache refolds only those categories on pickup and respec.
# 1. Every part's stat_touches is complete: adding the part, alone or beside any other
#    part, moves no sheet category it does not declare.
# 2. 1,000 random builds driven by pickups, respecs and restores: after every step the
#    cached sheet equals a full BuildSheet.from_parts recompute, field for field.
# 3. A real driven run: the build's sheet comes from the cache, and the cache refolds on
#    no physics frame other than a run start, a pickup or a respec.

const CACHE_PATH := "res://src/build/stat_cache.gd"
const BUILDS := 1000
const STEPS_PER_BUILD := 14
const MAX_HELD := 12
const RUN_TICKS := 600
# The driven run's scripted beats, by test tick.
const PICKUP_TICKS := {60: "hot_rivets", 140: "long_spool", 220: "frost_vane", 300: "rivet_plating"}
const RESPEC_TICK := 380
const RETRY_TICK := 460
const QUIET_RETRY_TICK := 520
# After the four pickups, before the respec: the live sheet is read here.
const LIVE_CHECK_TICK := 340

var _game
var _build
var _failures := 0
var _ticks := 0
var _cache_script
# Physics frame to the reasons a refold may happen on it.
var _allowed := {}
# Physics frame to the categories the build's cache refolded on it.
var _refolds := {}
var _pickup_frames: Array = []
var _quiet_frame := -1
var _respec_frame := -1
var _live_diffs := ["unread"]
var _live_held: Array = []


class TierRun:
	var tier := 0
	func selected_run_tier() -> int:
		return tier


func _initialize() -> void:
	if ResourceLoader.exists(CACHE_PATH):
		_cache_script = load(CACHE_PATH)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		if _cache_script == null:
			_report("stat cache exists", false, "%s is missing" % CACHE_PATH)
			return _finish()
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_build = _game.ctx.get_meta("build")
		_watch_driven_run()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	if _ticks < RUN_TICKS:
		_drive_tick()
		return false
	_check_driven_run()
	_check_declared_touches()
	_check_random_builds()
	return _finish()


func _finish() -> bool:
	print("stat_cache_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


# ---- 3. The driven run ----

func _allow(reason: String) -> void:
	var frame := Engine.get_physics_frames()
	_allowed[frame] = _allowed.get(frame, []) + [reason]


func _watch_driven_run() -> void:
	var cache = _build.get("stat_cache")
	if cache == null:
		return
	cache.recomputed.connect(func(categories: Array):
		var frame := Engine.get_physics_frames()
		_refolds[frame] = _refolds.get(frame, []) + categories)
	_game.events.run_started.connect(func(_c: String): _allow("run start"))
	_game.events.part_gained.connect(func(_p: String, _s: String): _allow("pickup"))


func _drive_tick() -> void:
	var run = _game.run
	if PICKUP_TICKS.has(_ticks):
		_pickup_frames.append(Engine.get_physics_frames())
		run.add_part(PICKUP_TICKS[_ticks], "test")
	elif _ticks == LIVE_CHECK_TICK:
		_live_held = run.parts.duplicate()
		_live_diffs = _sheet_diffs(_build.sheet, BuildSheet.from_parts(_live_held), ["max_hp_bonus"])
	elif _ticks == RESPEC_TICK:
		# Respec through the shop's sell path: the part leaves run.parts and the build recomputes.
		_allow("respec")
		_respec_frame = Engine.get_physics_frames()
		_build.shop._remove_part("long_spool")
	elif _ticks == RETRY_TICK:
		# A retry restores the stage-start part list: a respec back to it.
		_allow("respec")
		_game.flow.retry_stage()
	elif _ticks == QUIET_RETRY_TICK:
		# Nothing was gained since the last retry, so this one restores the same list:
		# stage entry recomputes, and the cache refolds nothing.
		_quiet_frame = Engine.get_physics_frames()
		_game.flow.retry_stage()


func _check_driven_run() -> void:
	var cache = _build.get("stat_cache")
	_report("the build owns the cache", cache != null and cache.get_script() == _cache_script,
		"build.stat_cache is %s" % ("a stat_cache.gd instance" if cache != null and cache.get_script() == _cache_script else str(cache)))
	if cache == null:
		return
	var stray: Array = []
	var refold_frames := 0
	var categories := 0
	for frame in _refolds:
		refold_frames += 1
		categories += _refolds[frame].size()
		if not _allowed.has(frame):
			stray.append("frame %d refolded %s" % [frame, _refolds[frame]])
	var physics_frames := RUN_TICKS
	_report("zero refolds per tick outside run start, pickup and respec", stray.is_empty() and refold_frames > 0,
		"%d driven ticks, %d frames refolded (%d category folds), all on run-start, pickup or respec frames %s; stray %s"
			% [physics_frames, refold_frames, categories, _allowed.keys(), stray])
	var silent: Array = []
	for frame in _pickup_frames:
		if _refolds.get(frame, []).is_empty():
			silent.append(frame)
	_report("every pickup goes through the cache", silent.is_empty() and _pickup_frames.size() == PICKUP_TICKS.size(),
		"%d scripted pickups, frames with no refold %s" % [_pickup_frames.size(), silent])
	_report("respec goes through the cache", not _refolds.get(_respec_frame, []).is_empty(),
		"selling Long Spool refolded %s" % [_refolds.get(_respec_frame, [])])
	_report("an unchanged restore refolds nothing", _quiet_frame > 0 and _refolds.get(_quiet_frame, []).is_empty(),
		"second retry with the same part list refolded %s" % [_refolds.get(_quiet_frame, [])])
	_report("the live sheet is the cached fold", _live_diffs.is_empty() and _live_held.size() >= PICKUP_TICKS.size(),
		"build.sheet at tick %d over %s against a full recompute (max_hp_bonus carries Scrap Armor): differs in %s"
			% [LIVE_CHECK_TICK, _live_held, _live_diffs])


# ---- 1. Declared touches are complete ----

# The sheet value each category owns. Independent of stat_cache.gd on purpose.
static func _category_values(sheet) -> Dictionary:
	return {
		"mods": sheet.mods, "cooldown": sheet.cooldown_scale, "patterns": sheet.patterns,
		"elements": sheet.triggers, "magnet": sheet.magnet, "kill_scrap": sheet.kill_scrap,
		"max_hp": sheet.max_hp_bonus, "punch": sheet.punch,
		"synergy": [sheet.synergies, sheet.transformers, sheet.dials],
	}


static func _moved(before, after) -> Array:
	var a := _category_values(before)
	var b := _category_values(after)
	var out: Array = []
	for key in a:
		if var_to_str(a[key]) != var_to_str(b[key]):
			out.append(key)
	return out


# Read at run time so the test reports a missing declaration instead of failing to parse.
static func _categories() -> Array:
	return (load("res://src/build/part_def.gd") as Script).get_script_constant_map().get("STAT_CATEGORIES", [])


static func _touches(d: Resource) -> Array:
	var t = d.get("stat_touches")
	return t if t is Array else []


func _all_ids() -> Array:
	var ids: Array = Parts.ids().duplicate()
	for key in Parts.EVOLVED.keys() + Parts.burdens():
		if not key in ids:
			ids.append(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in 120:
		var gen := ItemGen.roll_id(rng, ItemGen.RARITIES[i % 3])
		if gen != "" and not gen in ids:
			ids.append(gen)
	return ids


func _ingredients(part_id: String) -> Array:
	return Synergies.EVOLUTIONS.get(part_id, []).duplicate()


func _check_declared_touches() -> void:
	var ids := _all_ids()
	var partners: Array = ids.filter(func(p): return not ItemGen.is_generated(p))
	var tier_run := TierRun.new()
	Parts.bind_run(tier_run)
	var undeclared: Array = []
	var unknown: Array = []
	var checked := 0
	var pairs := 0
	for tier in [0, 1]:
		tier_run.tier = tier
		var tier_ids: Array = ids if tier == 0 else RunTier.ENHANCED.keys()
		for part_id in tier_ids:
			var d: Resource = Parts.def(part_id)
			if d == null:
				continue
			checked += 1
			if _touches(d).is_empty() and d.get("stat_touches") == null:
				unknown.append("%s has no stat_touches" % part_id)
			for c in _touches(d):
				if not c in _categories():
					unknown.append("%s:%s" % [part_id, c])
			var base := _ingredients(part_id)
			for c in _moved(BuildSheet.from_parts(base), BuildSheet.from_parts(base + [part_id])):
				if not c in _touches(d):
					undeclared.append("t%d %s alone moves %s" % [tier, part_id, c])
			if tier == 1:
				continue
			# Beside every other part: synergies are what a pair adds.
			for other in partners:
				pairs += 1
				var with_other := _ingredients(part_id) + [other]
				var moved := _moved(BuildSheet.from_parts(with_other), BuildSheet.from_parts(with_other + [part_id]))
				var allowed: Array = _touches(d).duplicate()
				# A synergy row the pair brings live folds its own mods, patterns and elements.
				if "synergy" in moved:
					allowed += ["mods", "patterns", "elements"]
				for c in moved:
					if not c in allowed:
						undeclared.append("%s beside %s moves %s" % [part_id, other, c])
	Parts.bind_run(null)
	_report("every part declares what it touches", undeclared.is_empty() and unknown.is_empty() and checked >= 150 and _categories().size() >= 9,
		"%d part defs at tiers 0 and 1, %d pairs; undeclared %s (first 8 of %d); unknown categories %s"
			% [checked, pairs, undeclared.slice(0, 8), undeclared.size(), unknown])


# ---- 2. Random builds ----

static func _sheet_fields(sheet) -> Array:
	var out: Array = []
	for p in sheet.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(p["name"])
	return out


static func _sheet_diffs(got, want, skip: Array = []) -> Array:
	var out: Array = []
	for field in _sheet_fields(want):
		if field in skip:
			continue
		# var_to_str keeps key order and exact float text, so it is stricter than ==.
		if var_to_str(got.get(field)) != var_to_str(want.get(field)):
			out.append(field)
	return out


func _check_random_builds() -> void:
	var cache_script = _cache_script
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261015
	var pool := _all_ids()
	# Evolution ingredients, drawn often enough that live Evolved parts come and go.
	var ingredients: Array = []
	for key in Synergies.EVOLUTIONS:
		ingredients += Synergies.EVOLUTIONS[key]
	var tier_run := TierRun.new()
	Parts.bind_run(tier_run)
	var mismatches: Array = []
	var overreach: Array = []
	var restale := 0
	var steps := 0
	var folds := 0
	var evolutions := 0
	for build_i in BUILDS:
		tier_run.tier = 0
		var cache = cache_script.new()
		var held: Array = []
		var snapshots: Array = [[]]
		cache.sync(held)
		for step in STEPS_PER_BUILD:
			var before: Array = held.duplicate()
			var roll := rng.randf()
			if roll < 0.6 and held.size() < MAX_HELD or held.is_empty():
				var from: Array = ingredients if rng.randf() < 0.25 else pool
				held.append(from[rng.randi() % from.size()])
				for evolved in Synergies.evolutions_ready(held):
					held.append(evolved)
					evolutions += 1
			elif roll < 0.8:
				held.remove_at(held.rfind(held[rng.randi() % held.size()]))
			elif roll < 0.95:
				held = snapshots[rng.randi() % snapshots.size()].duplicate()
			else:
				tier_run.tier = 1 - tier_run.tier
			if rng.randf() < 0.3:
				snapshots.append(held.duplicate())
			steps += 1
			var sheet = cache.sync(held)
			folds += cache.last_dirty.size()
			var diffs := _sheet_diffs(sheet, BuildSheet.from_parts(held))
			if not diffs.is_empty():
				mismatches.append("build %d step %d %s -> %s differs in %s" % [build_i, step, before, held, diffs])
			var allowed := _allowed_dirty(before, held)
			for c in cache.last_dirty:
				if not c in allowed and roll < 0.95:
					overreach.append("%s -> %s refolded %s" % [before, held, c])
			cache.sync(held)
			if not cache.last_dirty.is_empty():
				restale += 1
	Parts.bind_run(null)
	var full: int = steps * _categories().size()
	_report("cached stats equal a full recompute", mismatches.is_empty() and steps >= BUILDS * STEPS_PER_BUILD and evolutions >= 100,
		"%d builds, %d pickup, respec, restore and tier steps (%d evolutions granted); mismatches %s (first 4 of %d)"
			% [BUILDS, steps, evolutions, mismatches.slice(0, 4), mismatches.size()])
	_report("only touched categories refold", overreach.is_empty() and restale == 0 and folds < full,
		"%d category folds against %d for a full refold every step (%.1f%%); outside declared touches %s (first 4 of %d); a repeat sync refolded %d times"
			% [folds, full, 100.0 * folds / maxf(full, 1.0), overreach.slice(0, 4), overreach.size(), restale])


# The categories a change from before to after may refold: everything the added or
# removed parts declare, every held Evolved part's (its gate reads its ingredients), and
# the row-fed categories when synergy refolds.
func _allowed_dirty(before: Array, after: Array) -> Array:
	var changed: Array = []
	var left := after.duplicate()
	for part_id in before:
		var i := left.find(part_id)
		if i >= 0:
			left.remove_at(i)
		else:
			changed.append(part_id)
	changed += left
	var out: Array = []
	for part_id in changed + after.filter(func(p): return Parts.rarity_of(p) == "evolved"):
		var d: Resource = Parts.def(part_id)
		if d != null:
			out += _touches(d)
	if "synergy" in out:
		out += ["mods", "patterns", "elements"]
	return out
