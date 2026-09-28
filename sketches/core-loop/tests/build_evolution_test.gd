extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Triggers := preload("res://src/build/triggers.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")

# v3 spike S2 (LOOP-REDESIGN section 8): one evolution, Pinball Hull, behind the tuning
# flag "evolutions". Checks: with the flag off a ripe build does not evolve and the
# codex has no card; with it on the card is declared before it exists, offers read
# "* ripens Pinball Hull *" while a pick moves toward the recipe, and a Warden kill
# with Spring Hull x3 + Light Frame swaps the three hulls for one Pinball Hull (heft
# recomputed, codex discovery, toast source "evolution"). A rebound after that fires
# its speed surge and air jump through the real bus, and a retry to the pre-break part
# list takes the evolution back. Evidence limit: the Warden kill is the bus fact
# emitted directly, not a fought Warden.

const FAR := Vector3(9000.0, 0.0, 9000.0)
const HAND := ["spring_hull", "spring_hull", "spring_hull", "light_frame"]
const RIPENS := "* ripens Pinball Hull *"

var _game
var _build
var _failures := 0
var _ticks := 0
var _gained: Array = []


func _initialize() -> void:
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
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_build = _game.ctx.get_meta("build")
		_game.events.part_gained.connect(func(id: String, source: String): _gained.append([id, source]))
		return false
	if _ticks < 12:
		return false
	_check_row()
	_check_flag_off()
	_check_marks_and_card()
	_check_evolves()
	_check_rebound()
	_check_retry()
	print("build_evolution_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _hold(hand: Array) -> void:
	for part_id in hand:
		_game.run.add_part(part_id, "test")


func _card(cards: Array) -> Dictionary:
	for card in cards:
		if card.get("id", "") == "pinball_hull":
			return card
	return {}


func _warden_break() -> void:
	_game.events.enemy_killed.emit("warden", FAR, 0)


# The row resolves, is never offered at any rarity, and runs only closed-table effects.
func _check_row() -> void:
	var d: Resource = Parts.def("pinball_hull")
	var offered := false
	for rarity in ["common", "uncommon", "rare", "rare_plus"]:
		for class_id in ["", "pylon_engineer", "runner_gunner", "demolitions_caster"]:
			if "pinball_hull" in Parts.offer_pool(class_id, [rarity]):
				offered = true
	var subs: Array = d.effect.get("all", []).map(func(fx): return fx["do"])
	var known: bool = ItemEffects.EFFECTS.has(d.effect["do"]) and subs.all(func(id): return ItemEffects.EFFECTS.has(id))
	_report("pinball hull row", d != null and d.evolved and d.rarity == "rare_plus" and d.tags == ["speed", "kinetic"]
			and d.trigger == "on_rebound" and not offered and not "pinball_hull" in Parts.ids() and Parts.has("pinball_hull")
			and subs == ["speed", "air_jump", "relaunch_pin"] and known,
		"rarity %s, tags %s, family %s, trigger %s, effects %s, offered by any source %s" % [d.rarity, d.tags, d.family,
			d.trigger, subs, offered])


func _check_flag_off() -> void:
	var run = _game.run
	var cards_off: Dictionary = _card(_build.codex_declarations())
	_hold(HAND)
	var mark_off: String = _build.offer_mark("spring_hull")
	_warden_break()
	_report("flag off: nothing evolves", not _game.tuning.on("evolutions") and run.parts == HAND and cards_off.is_empty()
			and mark_off != RIPENS and not "pinball_hull" in _build.discovered(),
		"a Warden kill holding %s leaves %s; card declared %s; Spring Hull offer reads '%s'"
			% [HAND, run.parts, not cards_off.is_empty(), mark_off])
	_game.flow.retry_stage()


func _check_marks_and_card() -> void:
	var run = _game.run
	_game.tuning.set_value("evolutions", 1.0)
	var card: Dictionary = _card(_build.codex_declarations())
	_build._declare()
	var entry: Dictionary = _card(_game.ctx.codex.entries("build"))
	var empty_mark: String = _build.offer_mark("spring_hull")
	_hold(["spring_hull", "spring_hull"])
	var two_mark: String = _build.offer_mark("spring_hull")
	_hold(["spring_hull"])
	var ripe_hull: String = _build.offer_mark("spring_hull")
	var ripe_fast: String = _build.offer_mark("light_frame")
	var ripe_slow: String = _build.offer_mark("hot_rivets")
	_hold(["light_frame"])
	var paired_fast: String = _build.offer_mark("tread_plating")
	_report("hint card before it exists", card.get("hint", "") == "Spring Hull ×3 + something fast"
			and entry.get("name", "") == "Pinball Hull" and entry.get("hint", "") == card.get("hint", "")
			and not "pinball_hull" in _build.discovered(),
		"card '%s' / '%s' declared to the codex, discovered %s" % [entry.get("name", ""), entry.get("hint", ""),
			"pinball_hull" in _build.discovered()])
	_report("offer marks", empty_mark == RIPENS and two_mark == RIPENS and ripe_hull != RIPENS and ripe_fast == RIPENS
			and ripe_slow != RIPENS and paired_fast != RIPENS,
		"Spring Hull at 0 '%s', at 2 '%s', at 3 '%s'; at 3 Light Frame '%s', Hot Rivets '%s'; once paired Tread Plating '%s'"
			% [empty_mark, two_mark, ripe_hull, ripe_fast, ripe_slow, paired_fast])
	# The stage-start checkpoint flow would take holding this hand; the retry check reads it.
	run.snapshot(_game.player.ball_position(), Vector3.ZERO, _game.ctx.camera.yaw)


func _check_evolves() -> void:
	var run = _game.run
	var heft_before: float = run.heft()
	var size_before: int = run.parts.size()
	var rebound_before: Array = _build.effects.by_kind.get(Triggers.Kind.ON_REBOUND, []).map(func(e): return e["id"])
	_gained.clear()
	_warden_break()
	var parts_after: Array = run.parts.duplicate()
	var heft_after: float = run.heft()
	var per_part: float = (heft_before - heft_after) / float(size_before - parts_after.size())
	var rebound_after: Array = _build.effects.by_kind.get(Triggers.Kind.ON_REBOUND, []).map(func(e): return e["id"])
	_warden_break()
	var once: bool = run.parts.count("pinball_hull") == 1 and run.parts.size() == 2
	_report("evolves at the Warden break", parts_after.count("pinball_hull") == 1 and parts_after.count("spring_hull") == 0
			and "light_frame" in parts_after and parts_after.size() == 2 and _gained == [["pinball_hull", "evolution"]] and once,
		"%s became %s; published %s; a second break leaves %s" % [HAND, parts_after, _gained, run.parts])
	_report("heft and sheet recomputed", heft_after < heft_before and per_part > 0.0 and is_equal_approx(heft_after, run.heft())
			and rebound_before == ["spring_hull"] and rebound_after == ["pinball_hull"],
		"heft %.3f -> %.3f (%.3f per part removed); on_rebound items %s -> %s" % [heft_before, heft_after, per_part,
			rebound_before, rebound_after])
	var codex = _game.ctx.codex
	_report("codex discovery", "pinball_hull" in _build.discovered() and "pinball_hull" in codex.discovered_this_run()
			and codex.category_of("pinball_hull") == "build",
		"build discovered %s; codex this run %s" % [_build.discovered(), codex.discovered_this_run()])


# A rebound through the real bus: one ON_REBOUND pass, the surge and the air jump both
# fire, and the combo posts nothing of its own kind (the guard refuses nothing).
func _check_rebound() -> void:
	var player = _game.player
	var at: Vector3 = player.ball_position() + Vector3(3.0, 0.0, 0.0)
	var enemy: Node3D = _game.ctx.spawner.spawn_enemy("chaser", _game.ctx.terrain.drop_point(at.x, at.z, 2.4))
	player.state.velocity = Vector3(12.0, 0.0, 0.0)
	player.state.air_actions = 0
	var bus = _build.bus
	var fired_before: int = bus.fired.get(Triggers.Kind.ON_REBOUND, 0)
	var refused_before: int = bus.refused
	bus.pending.clear()
	_game.events.enemy_rebounded.emit(enemy, 12.0)
	bus.run(_build.effects.resolve, _build.loot_rng)
	var procs: Dictionary = _build.item_procs()
	_report("rebound fires speed and air jump", procs.get("pinball_hull", 0) == 1 and procs.get("pinball_hull:speed", 0) == 1
			and procs.get("pinball_hull:air_jump", 0) == 1 and player.state.air_actions == 1
			and bus.fired.get(Triggers.Kind.ON_REBOUND, 0) - fired_before == 1 and bus.refused == refused_before
			and not bus.leaked(),
		"procs %s; air actions %d; on_rebound passes %d, refused %d" % [procs, player.state.air_actions,
			bus.fired.get(Triggers.Kind.ON_REBOUND, 0) - fired_before, bus.refused - refused_before])


func _check_retry() -> void:
	_game.flow.retry_stage()
	var run = _game.run
	_report("retry takes the evolution back", run.parts == HAND and not _build.effects.copies.has("pinball_hull")
			and _build.effects.copies.get("spring_hull", 0) == 3,
		"after a retry to the pre-break checkpoint the part list is %s" % [run.parts])
