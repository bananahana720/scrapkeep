extends SceneTree

const Game := preload("res://src/game.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/core/icons.gd")
const Objectives := preload("res://src/core/objectives.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const Activities := preload("res://src/world/activities.gd")

# Activity signposting: every unfinished activity site gets one amber edge target in its own
# row's colour while the Warden fight is not engaged; a finished site gets none; engaging the
# fight hides them and the Warden target stays; disengaging brings them back. The Warden is the
# plate's goal from the drop; the find_activity row comes before the Warden rows only when the
# beacon is sealed, the fight is not engaged and the ball is at a site it has started
# (activities.gd at_hand), and never in the gates. A finished goal is ticked on the plate for
# Objectives.Done.SECONDS before the next one shows; a lost relay or surge is crossed.

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

	# The Warden is the goal from the drop: sites stand, none is started, and the plate gives the
	# metres to the Warden (second first-timer film, PF-11: the row named whichever site lay ahead,
	# and changed six times on the dam road with nothing done).
	var acts = _game.world.activities
	var home: Vector3 = _game.player.ball_position()
	# The sites are started and stopped by hand below, so their own watch stands still meanwhile
	# (a camp started with no pack would finish on its next tick).
	acts.set_physics_process(false)
	for site in sites:
		site.started = false
	var road: Dictionary = hud.objective_reading()
	_t.eq("a2_the_warden_is_the_goal_while_sites_stand", [road["id"], road["words"], road["distance"] >= 0, acts.at_hand(home) == null],
		["find_warden", Objectives.words("find_warden"), true, true])
	# A site takes the row only while the ball is at one it has started.
	var site = sites[0]
	var near: Vector3 = site.global_position + Vector3(Activities.AT_HAND_M * 0.5, 0.0, 0.0)
	var far: Vector3 = site.global_position + Vector3(Activities.AT_HAND_M + 5.0, 0.0, 0.0)
	_t.check("a3_a_site_not_started_is_not_at_hand_even_beside_it", acts.at_hand(near) == null)
	site.started = true
	_t.eq("a3_started_and_near_it_is_at_hand", [acts.at_hand(near) == site, acts.at_hand(far) == null], [true, true])
	_game.player.reset_to(near)
	await physics_frame
	await physics_frame
	var at_site: Dictionary = hud.objective_reading()
	_t.eq("a3_the_plate_names_the_site_at_hand_with_no_metres", [at_site["id"], at_site["words"], at_site["distance"], at_site["icon"]],
		["find_activity", Objectives.activity_words(String(site.id), Activities.called(String(site.id))), -1, Objectives.glyph("find_activity")])
	_t.check("a3_and_the_site_has_its_own_words", at_site["words"] != Objectives.words("find_activity"), "%s reads \"%s\"" % [site.id, at_site["words"]])
	# The site at hand keeps the row past AT_HAND_M, and lets go at LET_GO_M: the goal never
	# flickers at the edge of a site's reach.
	var gone: Vector3 = site.global_position + Vector3(Activities.LET_GO_M + 5.0, 0.0, 0.0)
	_t.eq("a4_a_held_site_stays_at_hand_until_let_go", [acts.at_hand(far, site) == site, acts.at_hand(gone, site) == null, acts.at_hand(far) == null], [true, true, true])
	_game.player.reset_to(far)
	await physics_frame
	await physics_frame
	_t.eq("a4_rolled_a_little_past_its_reach_the_site_keeps_the_row", hud.objective_reading()["id"], "find_activity")
	_game.player.reset_to(gone)
	await physics_frame
	await physics_frame
	_t.eq("a4_rolled_away_the_warden_has_the_row_again", hud.objective_reading()["id"], "find_warden")
	if sites.size() > 1:
		var other = sites[1]
		other.started = true
		var between: Vector3 = site.global_position.lerp(other.global_position, 0.1)
		if _t.check("a5_(premise)_a_place_at_hand_of_the_first_site", site.global_position.distance_to(between) < Activities.AT_HAND_M, "%.0f m" % site.global_position.distance_to(between)):
			_t.check("a5_of_two_started_sites_the_nearer_is_at_hand", acts.at_hand(between) == site)
			_t.check("a5_and_the_one_held_keeps_the_row_from_a_nearer_one", acts.at_hand(between, other) == other or other.global_position.distance_to(between) > Activities.LET_GO_M,
				"%.0f m" % other.global_position.distance_to(between))
		other.started = false
	site.done = true
	_t.check("a6_a_finished_site_is_never_at_hand", acts.at_hand(near) == null)
	site.done = false
	site.failed = true
	_t.check("a6_nor_a_lost_one", acts.at_hand(near) == null)
	site.failed = false
	site.set_meta("find", "x")
	_t.check("a6_nor_a_field_find", acts.at_hand(near) == null)
	site.remove_meta("find")
	# A trade spot is started by standing near it, so it never takes the row.
	var rule = site.rule
	_t.check("a6_(premise)_the_site_is_at_hand_by_its_own_rule", acts.at_hand(near) == site)
	site.rule = Activities.RULES["trade_safe"]
	_t.check("a6_nor_a_trade_spot_however_near", acts.at_hand(near) == null)
	site.rule = rule
	site.surge_live = true
	_t.check("a6_a_live_surge_is_at_hand_wherever_its_water_has_carried_the_ball", acts.at_hand(far) == site)
	site.surge_live = false
	site.started = false
	_game.player.reset_to(home)
	await physics_frame
	await physics_frame

	# The done row: a finished goal is ticked in the plate's own place before the next one shows.
	var step := 1.0 / 90.0
	var goal: Dictionary = hud.objective_reading()
	_game.events.activity_done.emit(String(site.id), site.global_position)
	var shown: Dictionary = hud.plate_shown()
	_t.eq("a7_a_finished_site_is_ticked_on_the_plate", [shown["words"], shown.get("done", ""), shown["distance"], shown["progress"]],
		[Objectives.done_words(String(site.id), Activities.called(String(site.id))), "won", -1, -1.0])
	_t.eq("a7_the_goal_under_it_is_untouched", [shown["id"], hud.objective_reading()], [goal["id"], goal])
	hud._process(0.0)
	_t.eq("a7_the_plate_draws_the_done_row_and_the_markers_keep_the_goal", [hud._objective.words, hud._objective.done, markers.objective_id], [shown["words"], "won", goal["id"]])
	var ticks := 0
	while hud.plate_shown().has("done") and ticks < 900:
		hud._physics_process(step)
		ticks += 1
	_t.near("a7_for_done_seconds_of_play", ticks * step, Objectives.Done.SECONDS, 2.0 * step)
	_t.eq("a7_then_the_goal_shows", hud.plate_shown(), hud.objective_reading())
	_game.events.event_ended.emit("hold_the_relay", "lost")
	_t.eq("a8_a_lost_relay_is_crossed", [hud.plate_shown()["words"], hud.plate_shown().get("done", "")], ["Relay lost", "lost"])
	hud._done.clear()
	_game.events.trade_taken.emit("trade_risk", home)
	_t.eq("a8_a_trade_taken_is_ticked", [hud.plate_shown()["words"], hud.plate_shown().get("done", "")], ["Gamble taken", "won"])
	_game.events.event_ended.emit("hold_the_relay", "lost")
	_game.events.event_ended.emit("some_flood", "passed")
	_t.eq("a8_a_park_event_ending_changes_nothing", hud.plate_shown()["words"], "Relay lost")
	# What an act opened never covers the act: the yard and the clamp are ticked only on a plate
	# with no tick on it, and the clamp only in the fight (the road's plate never said it was shut).
	_game.events.world_fact.emit("arena_unlocked", home)
	_t.eq("a8_a_fact_leaves_a_tick_that_is_showing", hud.plate_shown()["words"], "Relay lost")
	hud._done.clear()
	_game.events.world_fact.emit("arena_unlocked", home)
	_t.eq("a8_the_yard_opening_is_ticked", [hud.plate_shown()["words"], hud.plate_shown().get("done", "")], ["Yard open", "won"])
	hud._done.clear()
	_game.events.world_fact.emit("warden_gate_opened", home)
	_t.eq("a8_the_clamp_opened_from_the_road_is_not", hud.plate_shown().has("done"), false)
	hud._engaged = true
	_game.events.world_fact.emit("warden_gate_opened", home)
	_t.eq("a8_in_the_fight_it_is", hud.plate_shown()["words"], "Clamp open")
	hud._engaged = false
	_game.events.world_fact.emit("warden_gate_pip", home)
	_t.eq("a8_a_fact_that_finishes_nothing_changes_nothing", hud.plate_shown()["words"], "Clamp open")
	# The goal under a done row changing again takes the done row down at once.
	hud._physics_process(step)
	site.started = true
	_game.player.reset_to(near)
	await physics_frame
	await physics_frame
	hud._physics_process(step)
	_t.eq("a9_a_new_goal_under_it_takes_the_done_row_down", [hud.plate_shown().has("done"), hud.plate_shown()["id"]], [false, "find_activity"])
	site.started = false
	_game.player.reset_to(home)
	await physics_frame
	await physics_frame
	_game.events.activity_done.emit(String(site.id), site.global_position)
	hud._on_stage_entered(_game.run.stage, true)
	_t.eq("a9_a_stage_entered_clears_it", hud.plate_shown().has("done"), false)
	acts.set_physics_process(true)

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
	_t.eq("e_activity_row", Objectives.choose(base.merged({"site_at_hand": true}, true)), "find_activity")
	_t.eq("f_none_at_hand_warden_row", Objectives.choose(base.merged({"site_at_hand": false}, true)), "find_warden")
	_t.eq("f_engaged_warden_row", Objectives.choose(base.merged({"site_at_hand": true, "engaged": true}, true)), "break_guard")
	_t.eq("f_plating_engaged_row", Objectives.choose({"state": "stage", "sealed": true, "engaged": true, "site_at_hand": true}), "break_warden")
	_t.eq("f_unsealed_beacon_first", Objectives.choose({"state": "stage", "sealed": false, "site_at_hand": true}), "charge_beacon")
	_t.eq("g_gates_never_activity", Objectives.choose({"state": "gates", "sealed": true, "site_at_hand": true}), "roll_gate")
	_t.eq("g_launch_never_activity", Objectives.choose({"state": "launch", "site_at_hand": true}), "hold_line")
	var row_words: PackedStringArray = Objectives.words("find_activity").split(" ")
	_t.check("h_words_and_icon", row_words.size() <= Objectives.MAX_WORDS and Icons.has(Objectives.glyph("find_activity")),
		"%s / %s" % [Objectives.words("find_activity"), Objectives.glyph("find_activity")])
	_game.free()
	quit(_t.verdict())
