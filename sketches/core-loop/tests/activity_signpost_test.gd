extends SceneTree

const Game := preload("res://src/game.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const Objectives := preload("res://src/core/objectives.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")

# Activity signposting: every unfinished activity site gets one amber edge target in its own
# row's colour while the Warden fight is not engaged; a finished site gets none; engaging the
# fight hides them and the Warden target stays; disengaging brings them back. The objective
# plate's find_activity row comes before the Warden rows only when the beacon is sealed, the
# fight is not engaged and a site is left, and never in the gates.

var _game
var _t := preload("res://tests/support/t.gd").new("activity_signpost_test")


func _initialize() -> void:
	_run()


func _activity_targets(markers) -> Array:
	return markers.targets().filter(func(t): return t.has("activity"))


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.flow.press_start()
	_game.flow.choose_class(1)
	for i in 30:
		await physics_frame
	var hud = _game.hud
	var markers = hud.edge_markers
	var sites: Array = _game.world.activities.sites.duplicate()
	_t.check("sites_exist", sites.size() > 0, "%d sites" % sites.size())
	_game.flow.sealed = true
	hud._engaged = false
	hud._process(0.0)

	var targets := _activity_targets(markers)
	var ok := targets.size() == sites.size()
	for site in sites:
		var hit := false
		for target in targets:
			if target["at"] == site.global_position and EdgeMarkers.marker_color(target) == EventKinds.activity_color(site.id) \
					and EventKinds.activity_color(site.id) == EventKinds.role_color("amber"):
				hit = true
		ok = ok and hit
	_t.check("a_one_amber_target_per_site", ok, "%d targets for %d sites" % [targets.size(), sites.size()])

	# The plate names the nearest site and gives the metres to it (Objectives.ACTIVITY_WORDS).
	var ball: Vector3 = _game.player.ball_position()
	var nearest = sites[0]
	for site in sites:
		if ball.distance_squared_to(site.global_position) < ball.distance_squared_to(nearest.global_position):
			nearest = site
	var plate: Dictionary = hud.objective_reading()
	_t.eq("a2_plate_names_the_nearest_site", [plate["id"], plate["words"], plate["distance"]],
		["find_activity", Objectives.activity_words(String(nearest.id)), int(ball.distance_to(nearest.global_position))])
	_t.check("a2_named_site_has_its_own_words", Objectives.ACTIVITY_WORDS.has(String(nearest.id)) and plate["words"] != Objectives.words("find_activity"),
		"%s reads \"%s\"" % [nearest.id, plate["words"]])
	_t.eq("a2_plate_glyph_is_the_marker_glyph", plate["icon"], Objectives.glyph("find_activity"))

	var finished = sites[0]
	finished.done = true
	hud._process(0.0)
	var has_finished := false
	for target in _activity_targets(markers):
		if target["at"] == finished.global_position:
			has_finished = true
	_t.check("b_done_site_not_a_target", not has_finished and _activity_targets(markers).size() == sites.size() - 1, "done site dropped")
	finished.done = false

	hud._engaged = true
	hud._process(0.0)
	var warden_kept := false
	for target in markers.targets():
		if target["kind"] == "warden_engaged":
			warden_kept = true
	_t.check("c_engaged_hides_activities", _activity_targets(markers).is_empty() and warden_kept, "no activity target, warden target %s" % warden_kept)
	_t.check("c_plate_not_activity_when_engaged", hud.objective_reading()["id"] != "find_activity", hud.objective_reading()["id"])

	hud._engaged = false
	hud._process(0.0)
	_t.check("d_disengage_restores", _activity_targets(markers).size() == sites.size(), "%d targets" % _activity_targets(markers).size())

	var base := {"state": "stage", "sealed": true, "engaged": false, "fight": "posture"}
	_t.eq("e_activity_row", Objectives.choose(base.merged({"activities_left": 2}, true)), "find_activity")
	_t.eq("f_none_left_warden_row", Objectives.choose(base.merged({"activities_left": 0}, true)), "find_warden")
	_t.eq("f_engaged_warden_row", Objectives.choose(base.merged({"activities_left": 2, "engaged": true}, true)), "break_guard")
	_t.eq("f_plating_engaged_row", Objectives.choose({"state": "stage", "sealed": true, "engaged": true, "activities_left": 3}), "break_warden")
	_t.eq("f_unsealed_beacon_first", Objectives.choose({"state": "stage", "sealed": false, "activities_left": 3}), "charge_beacon")
	_t.eq("g_gates_never_activity", Objectives.choose({"state": "gates", "sealed": true, "activities_left": 3}), "roll_gate")
	_t.eq("g_launch_never_activity", Objectives.choose({"state": "launch", "activities_left": 3}), "hold_line")
	var row_words: PackedStringArray = Objectives.words("find_activity").split(" ")
	_t.check("h_words_and_icon", row_words.size() <= Objectives.MAX_WORDS and Icons.has(Objectives.glyph("find_activity")),
		"%s / %s" % [Objectives.words("find_activity"), Objectives.glyph("find_activity")])
	_game.free()
	quit(_t.verdict())
