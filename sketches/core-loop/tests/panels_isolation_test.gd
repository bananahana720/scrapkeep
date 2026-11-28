extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const Panels := preload("res://src/build/panels.gd")
const RunState := preload("res://src/core/run_state.gd")
const T := preload("res://tests/support/t.gd")

# IL-01 isolation and director checks on a real Game, with 60 grey panels held:
# 1. Panels are not parts: run.parts and its digest, the maker counts and a fixed-seed draw of
#    gate offers (the offer weights) are byte-identical before and after the 60 panels.
# 2. Director honesty: enemy health scale, rest scale and stage threat are unchanged, and a
#    spawned chaser has the same health and damage with 60 panels as with none.
# 3. The panels act: heft rose by 60 x PANEL_MASS, the build's tuning mods carry the steps,
#    and the ball draws the plates.
# 4. The run keeps them: a retry restores the stage-start list and pity count, and the entrance document
#    round-trips the pickup order (a doc with an unknown panel is refused).
# smoke: solo timeout=180s

const START_TICKS := 30
const GRANT := 60

var _t := T.new("panels_isolation_test")
var _game
var _ticks := 0


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
		return false
	if _ticks < START_TICKS:
		return false
	_check()
	_game.free()
	quit(_t.verdict())
	return true


func _snapshot() -> Dictionary:
	var build = _game.build
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var offers := []
	for i in 40:
		offers.append(PartOffers.roll_gate(rng, PartOffers.gate_rarities(0), _game.run.class_id(), _game.run.parts, 2, 1, {}, Parts.offer_ops()))
	var world = _game.ctx.root.get_node("World")
	var spawned: Node3D = _game.ctx.spawner.spawn_enemy("chaser", _game.player.ball_position() + Vector3(30.0, 0.0, 30.0))
	var enemy := {"max_hp": spawned.get("max_hp"), "damage": spawned.get("damage"), "contact_damage": spawned.get("contact_damage")}
	spawned.queue_free()
	return {
		"parts": var_to_bytes(Array(_game.run.parts)).hex_encode().sha256_text(),
		"makers": build.maker_counts(),
		"offers": var_to_bytes(offers).hex_encode().sha256_text(),
		"hp_scale": world.director.hp_scale(),
		"rest_scale": world.director.rest_scale(),
		"threat": _game.ctx.spawner._threat(),
		"enemy": enemy,
	}


func _check() -> void:
	var run = _game.run
	var build = _game.build
	_game.run.add_part("hot_rivets", "test")
	var before := _snapshot()
	var heft_before: float = run.heft()
	for i in GRANT:
		run.add_panel(Panels.ROWS.keys()[i % Panels.ROWS.size()], _game.player.ball_position())
	var after := _snapshot()
	_t.eq("parts digest unchanged", after["parts"], before["parts"])
	_t.eq("maker counts unchanged", after["makers"], before["makers"])
	_t.eq("offer weights unchanged (40 seeded gate draws)", after["offers"], before["offers"])
	_t.eq("enemy hp scale unchanged", after["hp_scale"], before["hp_scale"])
	_t.eq("enemy rest scale unchanged", after["rest_scale"], before["rest_scale"])
	_t.eq("stage threat unchanged", after["threat"], before["threat"])
	_t.eq("spawned chaser health and damage unchanged", after["enemy"], before["enemy"])
	_t.near("heft rose by the panel mass", run.heft() - heft_before, GRANT * Panels.PANEL_MASS * RunState.HEFT_PER_MASS, 0.00001)
	_t.eq("panels held", run.panels.size(), GRANT)
	_t.near("fire-rate mod carries five louvres", _game.tuning.mod("weapon_rate") / build.stat_cache.copy().mod("weapon_rate"), 1.25, 0.0001)
	_t.near("area radius from five skirts", _game.tuning.add("area_radius"), 5 * 0.35, 0.0001)
	_t.check("ball draws the plates", build.panel_shell.shown_count() == GRANT and build.panel_shell.draw_calls() <= Panels.ROWS.size(),
		"%d plates in %d draw calls" % [build.panel_shell.shown_count(), build.panel_shell.draw_calls()])
	# The entrance document round-trips the pickup order; an unknown id is refused.
	var doc: Dictionary = run.to_entrance_doc()
	var copy = RunState.new(null, 1)
	_t.check("doc round-trips panels", copy.from_entrance_doc(doc) and Array(copy.panels) == Array(run.panels), "%d panels" % copy.panels.size())
	var bad := doc.duplicate(true)
	bad["panels"] = ["gold_heart"]
	_t.check("doc refuses an unknown panel", RunState.validate_entrance_doc(bad) != "", RunState.validate_entrance_doc(bad))
	var empty_doc: Dictionary = RunState.new(null, 1).to_entrance_doc()
	_t.check("a run with no panels writes no panels key", not empty_doc.has("panels"), str(empty_doc.keys().size()))
	# A retry rewinds to the stage-start list (empty here) and the plates follow.
	build.dropper.dry = 5
	_game.flow.retry_stage()
	_t.eq("retry restores the stage-start pity", build.dropper.dry, 0)
	_t.eq("retry restores the stage-start panels", run.panels.size(), 0)
	_t.eq("plates follow the retry", build.panel_shell.shown_count(), 0)
