extends SceneTree

const Game := preload("res://src/game.gd")
const Objectives := preload("res://src/core/objectives.gd")
const Interactables := preload("res://src/world/interactables.gd")
const RescueSites := preload("res://src/world/rescue_site.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")

# The plate's detour row on the park dam (gameplay critique finding 8, W1-69): from the drop the
# goal row is "Find the Warden" and under it a quieter row names Rivet's cage by its own prompt, with
# its metres, while the cage has an edge target in its ally colour. Once the cage is freed the row
# names the nearest side site not yet started, by what finishes it and in its marker's colour; a
# started site steps aside for the next. Engaging the Warden takes the row and the cage's target
# away, so a fight keeps its word budget; on the road the row costs at most the plate's cap and its metres. Every wait is counted physics frames.

var _t := preload("res://tests/support/t.gd").new("ui_objective_detour_test")
var _game


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame


func _cage_targets() -> Array:
	return _game.hud.edge_markers.targets().filter(func(t): return t["kind"] == "rescue_completed")


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.flow.press_start()
	_game.flow.choose_class(0)
	# Calm keeps packs and events off the road; the Warden is forced in so the road has its goal.
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(60)
	var hud = _game.hud
	var view = hud._objective
	var acts = _game.world.activities
	# Sites are started by hand below, so their own watch stands still meanwhile.
	acts.set_physics_process(false)
	for site in acts.sites:
		site.started = false
	hud._engaged = false
	hud._process(0.0)

	var cage = _game.world.rescue.cage("rivet")
	_t.check("the dam stands Rivet's cage", cage != null)
	if cage == null:
		quit(_t.verdict())
		return
	var goal: Dictionary = hud.objective_reading()
	var detour: Dictionary = hud.detour_reading(goal)
	var ball: Vector3 = _game.player.shown_position()
	_t.eq("from the drop the goal is the Warden", goal["id"], "find_warden")
	_t.eq("the detour row names the cage by its prompt", [detour.get("what"), detour.get("words")], ["cage", "Free the runner"])
	_t.eq("the cage row's metres", detour.get("distance"), int(ball.distance_to(cage.global_position)))
	_t.eq("the cage row wears the cage's ally colour and glyph", [detour.get("color"), detour.get("icon")],
		[Interactables.color("ally"), Interactables.row("ally")["icon"]])
	var drawn: PackedStringArray = view.drawn_words()
	_t.check("the plate draws the goal and the detour", drawn.has(Objectives.words("find_warden")) and drawn.has("Free the runner"), str(drawn))
	_t.check("the plate grows by the detour row", view.extent().y > view.ICON, str(view.extent()))
	var targets := _cage_targets()
	_t.check("the cage has an edge target at its foot in its ally colour", targets.size() == 1 \
		and targets[0]["at"].is_equal_approx(cage.global_position) and targets[0]["color"] == Interactables.color("ally"), str(targets))
	# The 25-word budget is a fight's (LEGIBILITY.md; ui_word_budget_test, engaged, where the row is
	# gone): on the road the row costs at most the plate's cap and its metres.
	var cost := WordBudget.words_in("%s %dm" % [detour["words"], detour["distance"]])
	_t.check("the detour row costs at most the plate's cap and its metres", cost <= Objectives.MAX_WORDS + 1, "%d words" % cost)

	# Freed: the row turns to the nearest site not yet started.
	cage.fire()
	await _frames(int(ceil(RescueSites.BREAK_SECONDS * Engine.physics_ticks_per_second)) + 10)
	_t.check("the cage is freed", cage.spent)
	hud._process(0.0)
	ball = _game.player.shown_position()
	var sites: Array = hud.edge_markers.unfinished_sites().filter(func(s): return not s.started and not s.failed)
	sites.sort_custom(func(a, b): return ball.distance_to(a.global_position) < ball.distance_to(b.global_position))
	_t.check("the dam has side sites", sites.size() > 0, "%d" % sites.size())
	_t.eq("a freed cage has no edge target", _cage_targets().size(), 0)
	if sites.is_empty():
		quit(_t.verdict())
		return
	detour = hud.detour_reading(hud.objective_reading())
	var first = sites[0]
	_t.eq("freed, the row names the nearest site by what finishes it", [detour.get("what"), detour.get("words")],
		[String(first.id), Objectives.activity_words(String(first.id), acts.called(String(first.id)))])
	_t.eq("the site row's metres", detour.get("distance"), int(ball.distance_to(first.global_position)))
	var site_mark: Array = hud.edge_markers.targets().filter(func(t): return t.get("activity", "") != "" and t["at"] == first.global_position)
	_t.check("the site row wears its marker's colour", site_mark.size() == 1 and detour.get("color") == hud.edge_markers.marker_color(site_mark[0]))
	first.started = true
	detour = hud.detour_reading(hud.objective_reading())
	_t.eq("a started site steps aside for the next", detour.get("what", ""), String(sites[1].id) if sites.size() > 1 else "")
	first.started = false

	# Engaged: the fight reads alone.
	hud._engaged = true
	hud._process(0.0)
	_t.eq("engaged, the detour row is gone", hud.detour_reading(hud.objective_reading()), {})
	_t.check("engaged, the plate draws no detour words", not view.drawn_words().has(detour.get("words", "?")), str(view.drawn_words()))
	_game.free()
	quit(_t.verdict())
