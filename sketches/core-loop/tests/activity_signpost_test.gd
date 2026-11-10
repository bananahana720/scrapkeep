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

	# Before the ball has travelled, the plate names the site in front of the view and gives the metres to it (Objectives.pick_site,
	# ACTIVITY_WORDS). The expected site is worked out here from the rule's own words: distance,
	# stretched by one for each unit the site's bearing falls short of straight ahead.
	var ball: Vector3 = _game.player.ball_position()
	var cam: Camera3D = _game.camera.cam
	var named := []
	for facing in sites:
		var eye := cam.global_position
		var target: Vector3 = facing.global_position
		if Vector2(target.x - eye.x, target.z - eye.z).length() < 1.0:
			continue
		cam.look_at(Vector3(target.x, eye.y, target.z), Vector3.UP)
		var forward := -cam.global_transform.basis.z
		var nearest = null
		var low := INF
		for site in sites:
			var to: Vector3 = site.global_position - ball
			var flat := Vector3(to.x, 0.0, to.z).normalized()
			var score := to.length() * (2.0 - flat.dot(Vector3(forward.x, 0.0, forward.z).normalized()))
			if score < low:
				low = score
				nearest = site
		hud._plate_site = null
		var faced: Dictionary = hud.objective_reading()
		named.append([faced["id"], faced["words"], faced["distance"]] ==
			["find_activity", Objectives.activity_words(String(nearest.id)), int(ball.distance_to(nearest.global_position))])
	_t.check("a2_plate_names_the_site_ahead", not named.is_empty() and not named.has(false), "%s" % [named])
	# Held: with the view turned right round, the row keeps its site unless another is clearly better.
	var held = hud._plate_site
	cam.rotate_y(PI)
	var after: Dictionary = hud.objective_reading()
	var held_score := Objectives.site_score(held.global_position - ball, -cam.global_transform.basis.z)
	var now_score := Objectives.site_score(hud._plate_site.global_position - ball, -cam.global_transform.basis.z)
	_t.check("a2_row_keeps_its_site_until_clearly_beaten", hud._plate_site == held or now_score < held_score * Objectives.SITE_KEEP,
		"held %.1f now %.1f" % [held_score, now_score])
	# Once the ball has travelled, the row reads where the ball is going and not where the camera
	# looks (Objectives.Way). The ball is stood between the two sites farthest apart and sent at one
	# of them; there the view alone would trade the row as the camera turns (worked out here, so the
	# check is not empty), and the row holds through a whole look round.
	var home: Vector3 = _game.player.ball_position()
	var first = sites[0]
	var far = sites[0]
	for site in sites:
		if site.global_position.distance_to(first.global_position) > far.global_position.distance_to(first.global_position):
			far = site
	var mid: Vector3 = (first.global_position + far.global_position) * 0.5
	var toward: Vector3 = first.global_position - mid
	hud._way.begin()
	_game.player.reset_to(mid, Vector3(toward.x, 0.0, toward.z).normalized() * 20.0)
	hud._physics_process(1.0 / 90.0)
	_game.player.reset_to(mid)
	await physics_frame
	await physics_frame
	hud._plate_site = null
	cam.look_at(Vector3(first.global_position.x, cam.global_position.y, first.global_position.z), Vector3.UP)
	var rolling: Dictionary = hud.objective_reading()
	var from: Vector3 = _game.player.shown_position()
	var offsets := []
	for site in sites:
		offsets.append(site.global_position - from)
	var by_view := {}
	var by_view_held := -1
	var seen := {}
	for i in 36:
		cam.rotate_y(TAU / 36.0)
		by_view_held = Objectives.pick_site(offsets, -cam.global_transform.basis.z, by_view_held)
		by_view[by_view_held] = true
		seen[hud.objective_reading()["words"]] = true
	_t.check("a2_between_two_sites_the_view_alone_would_trade_the_row", by_view.size() > 1, "sites the view names in one look round: %s" % [by_view.keys()])
	_t.eq("a2_a_look_round_does_not_change_the_row_once_rolling", seen.keys(), [rolling["words"]])
	_game.player.reset_to(home)
	await physics_frame
	await physics_frame
	hud._plate_site = null
	hud._way.begin()
	after = hud.objective_reading()
	var nearest = hud._plate_site
	var plate: Dictionary = after
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
