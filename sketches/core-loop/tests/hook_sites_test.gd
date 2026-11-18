extends SceneTree
# smoke: solo timeout=360s

const T := preload("res://tests/support/t.gd")
const Teardown := preload("res://tests/support/teardown_noise.gd")
const HookSites := preload("res://tools/hook_sites.gd")


func _initialize() -> void:
	var t := T.new("hook_sites_test")
	var output := []
	# The smoke runner gives this process a fresh scratch home. The headless child
	# inherits it and runs one physics tick per frame regardless of rendering load.
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--fixed-fps", "90",
		"--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/hook_sites.gd"], output, true)
	var rows := []
	var log := Teardown.strip("\n".join(output))
	for line in log.split("\n"):
		if line.begins_with("HOOK_SITES "):
			var payload = JSON.parse_string(line.trim_prefix("HOOK_SITES "))
			if payload is Array:
				rows = payload
	if not t.check("fixed-tick probe ran", code == 0 and not "ERROR:" in log and not rows.is_empty()):
		printerr(log)
		quit(t.verdict())
		return
	var stations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HookSites.STATIONS))
	# The exceptional passive release at one tick cannot buy energy on another.
	t.near("an unchanged stock excess adds nothing", HookSites.added_excess({"3": 3.0}, {"3": 3.0}), 0.0)
	t.near("the same tick catches an extra unit", HookSites.added_excess({"3": 4.0}, {"3": 3.0}), 1.0)
	t.near("another tick cannot borrow that excess", HookSites.added_excess({"4": 3.0}, {"3": 3.0}), 3.0)
	var sampled := {}
	_check_station_list(t, stations)
	var paid := 0
	var hold_pays := 0
	var all_releases_preserved := true
	var usable_at_round0 := []
	var usable_passing := []
	for row: Dictionary in rows:
		if not t.check("known distinct site", stations.has(row.site) and not sampled.has(row.site), row.site):
			continue
		sampled[row.site] = true
		var station: Dictionary = stations[row.site]
		var baseline = station.round0_early_landing_mps
		# null is the recorded absence of a bite in round 0. Its first real
		# release in c has no earlier speed to preserve; all other checks apply.
		if baseline != null:
			usable_at_round0.append(row.site)
			t.eq("%s round-0 anchor still takes the line" % row.site, row.status, "measured")
		t.check("%s comparison finished" % row.site, row.status in ["no hold", "measured"], row.status)
		if row.status != "measured":
			if baseline != null:
				all_releases_preserved = false
			continue
		t.eq("%s tried every earlier physics tick" % row.site, int(row.early_trials), HookSites.HOLD_TICKS - 1)
		row["early_speed_preserved"] = baseline == null or float(row.best_early.landing_mps) >= float(baseline) - 0.001
		row["hold_pays"] = row.held_only_tier or row.held.landing_mps >= row.best_early.landing_mps
		row["within_energy_bound"] = row.exit_excess_by_tick.is_empty()
		row["added_excess"] = HookSites.added_excess(row.exit_excess_by_tick, station.get("round0_exit_excess_by_tick", {}))
		row["within_stock_allowance"] = row.added_excess <= float(station.get("round0_excess_noise", 0.0))
		if row.hold_pays:
			hold_pays += 1
		all_releases_preserved = all_releases_preserved and row.early_speed_preserved
		if row.early_speed_preserved and row.hold_pays and row.within_stock_allowance:
			paid += 1
			if baseline != null:
				usable_passing.append(row.site)
	t.eq("station count", sampled.size(), stations.size())
	t.check("measured flume control in round 0", usable_at_round0.has("flume_hollow_trestles"))
	print("RECEIPT ", JSON.stringify({"row": "hook-pays", "pass": paid == stations.size() and t.failures == 0,
		"measured": {"entry_mps": HookSites.ENTRY_SPEED, "sites_passing": paid, "stations": rows,
			"sites_where_hold_beats_release": hold_pays, "release_speed_not_below_round0": all_releases_preserved,
			"usable_at_round0": usable_at_round0, "usable_sites_passing": usable_passing}}))
	quit(t.verdict())

# Every anchor_field or grapple ride assigned to a route in the shared file
# needs a trial. Before W1-132a is stacked use its three route ids.
func _check_station_list(t, stations: Dictionary) -> void:
	for id in ["dam_viga_span", "flume_hollow_trestles", "bowl_mast"]:
		t.check("required station %s" % id, stations.has(id))
	var shared_path := "res://tools/stations/shared_route.json"
	var routes := ["west_wash_run", "canal_run", "incline_line"]
	if FileAccess.file_exists(shared_path):
		var shared: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(shared_path))
		routes = shared.keys()
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/park_dam.json"))
	for feature in park.park_rows:
		if feature.element != "anchor_field" and feature.get("ride_fact") != "ride_grapple_line":
			continue
		if feature.routes.any(func(route): return routes.has(route)):
			t.check("shared route grapple %s" % feature.id, stations.values().any(
				func(site): return int(site.stage) == 1 and site.get("park_row") == feature.id))
