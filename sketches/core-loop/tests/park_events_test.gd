extends SceneTree

const Director := preload("res://src/world/event_director.gd")
const Kinds := preload("res://src/core/event_kinds.gd")
const H := 0.05
const BAR := 240.0 / 172.0
const FAR := Vector3(1000.0, 1.0, 1000.0)
const LABELS := ["both trigger kinds", "lead floors and one bar", "clearance and grounded water", "overlap 10000 steps and break quiet"]

class Map:
	extends RefCounted
	var park := {}

var _failures := 0


func _initialize() -> void:
	var probe = _director([])
	if not probe.has_method("register_family"):
		for label in LABELS:
			_check(label, false, "park row scheduling interface absent")
	else:
		_triggers()
		_leads()
		_clearance()
		_overlap()
		_lifecycle()
		_weather()
		_ending_safety()
	print("park_events_test: PASS" if _failures == 0 else "park_events_test: FAIL")
	quit(0 if _failures == 0 else 1)


func _director(rows: Array, weather: Array = [], seed_value := 813):
	var map := Map.new()
	map.park = {"map": "fixture", "event_rows": rows, "weather_rows": weather,
		"park_rows": [{"id": "site", "at": [0, 0], "y": 0.0, "size": [20, 2, 20], "yaw_deg": 0}],
		"routes": [{"id": "main", "from": "drop_in", "to": "landmark", "via": []}]}
	return Director.new(seed_value, {}, map, 14.0, func(_x, _z): return 0.0)


func _row(id: String, kind := "collapse", family := "natural", lead := 0.1, on_bar := false) -> Dictionary:
	var form: String = {"natural": "flood_rising", "fleet": "fleet_inbound", "ancient": "ancient_stirring", "industrial": "boiler_pressure"}[family]
	return {"id": id, "kind": kind, "family": family, "site": "site", "trigger": {"on": "clock_tier", "value": 1},
		"weight": 1.0, "telegraph": {"lead_s": lead, "form": form, "on_bar": on_bar}, "live_s": 4.0,
		"effect": {}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 12.0,
		"cooldown_s": 2.0, "once": true, "music_cue": {"telegraph": "riser_" + family, "land": "drop_" + family}}


func _step(d, delta := H, ball := FAR, velocity := Vector3.ZERO, extra: Dictionary = {}) -> Array:
	var ctx := {"clock_tier": 4, "grounded": true, "bar_s": BAR, "bar_origin_s": 0.0}
	ctx.merge(extra, true)
	return d.advance(delta, ball, velocity, ctx)


func _triggers() -> void:
	var clock := _row("clock")
	clock.trigger.value = 2
	var phase := _row("phase", "boiler_burst", "industrial", 5.0)
	phase.trigger = {"on": "warden_phase", "value": "chunk_2"}
	var d = _director([clock, phase])
	var seen := {}
	var early := false
	for i in 800:
		var context := {"clock_tier": 0 if i < 40 else 2, "warden_phases": ["chunk_2"] if i == 100 else []}
		for f in _step(d, H, FAR, Vector3.ZERO, context):
			if f.kind == "announced":
				early = early or (f.id == "clock" and i < 40) or (f.id == "phase" and i < 100)
			if f.kind == "started":
				seen[f.id] = true
	_check(LABELS[0], seen.has("clock") and seen.has("phase") and not early, str(seen))
	# Stagger is a pulse, not a remembered state: every occurrence can trigger again.
	phase.once = false
	phase.live_s = 1.0
	phase.cooldown_s = 0.0
	phase.trigger.value = "stagger"
	d = _director([phase])
	var starts := 0
	for i in 500:
		for f in _step(d, H, FAR, Vector3.ZERO, {"warden_phases": ["stagger"] if i in [0, 220] else []}):
			if f.kind == "started":
				starts += 1
	_check("stagger pulses", starts == 2, "%d starts for two stagger pulses" % starts)


func _leads() -> void:
	# These expectations come from PARK rule 1, not Director or ParkSchema helpers.
	var cases := [["lightning", "natural", 3.0], ["collapse", "natural", 5.0],
		["fleet_landing", "fleet", 8.0], ["machine_eruption", "ancient", 8.0], ["boiler_burst", "industrial", 5.0]]
	var good := true
	var count := 0
	var details := []
	for spec in cases:
		for lead in [0.1, float(spec[2]) + 2.7]:
			for on_bar in [false, true]:
				var r := _row("lead", spec[0], spec[1], lead, on_bar)
				if spec[0] == "boiler_burst":
					r.effect.swap = "roof"
				var d = _director([r])
				var announced := -1.0
				var landed := -1.0
				var cues := []
				var hook_log := []
				d.register_family(spec[1], func(action, _row_data, ctx): hook_log.append([action, ctx.clock_s]))
				for i in 500:
					for f in _step(d):
						if f.kind == "announced":
							announced = d.stage_time
						if f.kind == "world":
							cues.append(f)
						if f.kind == "started":
							landed = d.stage_time
					if landed >= 0.0:
						break
				var want: float = maxf(lead, float(spec[2]))
				var due := announced + want
				var aligned: float = ceil((due - 0.00000001) / BAR) * BAR if on_bar else due
				var ok: bool = announced >= 0.0 and landed >= aligned - 0.000001 and landed < aligned + H + 0.000001
				ok = ok and landed - announced >= want - 0.000001 and landed - announced <= want + (BAR if on_bar else 0.0) + H
				ok = ok and cues.size() == 2 and hook_log.size() >= 2
				if cues.size() == 2:
					ok = ok and cues[0].fact == r.telegraph.form and not Kinds.world_row(cues[0].fact).is_empty() and not Kinds.world_row(cues[1].fact).is_empty()
					ok = ok and cues[0].music_cue == r.music_cue.telegraph and cues[1].music_cue == r.music_cue.land
					ok = ok and cues[0].get("phase") == "telegraph" and cues[1].get("phase") == "land"
				if hook_log.size() >= 2:
					ok = ok and hook_log[0][0] == "telegraph" and hook_log[1][0] == "land" and hook_log[1][1] >= aligned - 0.000001
				good = good and ok
				count += 1
				if not ok:
					details.append("%s lead %.1f bar %s: announce %.3f land %.3f expected %.3f" % [spec[0], lead, on_bar, announced, landed, aligned])
	_check(LABELS[1], good and count == 20, "%d schedules; %s" % [count, details])


func _clearance() -> void:
	var d = _director([_row("hold")])
	var bad := false
	var started := false
	for i in 300:
		# Site ends at x=10: x=21 is still inside its independently known 12 m margin.
		var ball := Vector3(21, 1, 0) if i < 180 else FAR
		for f in _step(d, H, ball):
			if f.kind == "started":
				bad = bad or i < 180
				started = true
	_check("hold_clear_m", started and not bad, "held until the ball leaves the site plus 12 m")
	d = _director([_row("travel")])
	bad = false
	started = false
	for i in 300:
		# Currently clear at x=50, but its next 2 s crosses the footprint.
		for f in _step(d, H, Vector3(50, 1, 0), Vector3(-30, 0, 0) if i < 180 else Vector3.ZERO):
			if f.kind == "started":
				bad = bad or i < 180
				started = true
	_check("next two seconds clear", started and not bad, "50 m out, 30 m/s toward the site")
	var water := _row("water", "flood_fill", "natural", 5.0)
	water.hold_clear_m = 0.0
	water.effect = {"depth_m": 9.0, "fill_s": 10.0, "material": "water"}
	water.live_s = 20.0
	d = _director([water])
	var water_checks := {"under": 0, "safe": 0, "depth": true}
	d.register_family("natural", func(action, r, ctx):
		if action == "step":
			if ctx.grounded and absf(ctx.ball.x) <= 10.0 and absf(ctx.ball.z) <= 10.0 and ctx.rise_s < 10.0:
				water_checks.under += 1
			else:
				water_checks.safe += 1
		water_checks.depth = water_checks.depth and float(r.effect.depth_m) <= 1.2)
	for i in 500:
		var ball := Vector3(0, 1, 0) if i >= 120 and i < 300 else FAR
		_step(d, H, ball)
	_check("water pauses mid-fill", water_checks.under == 0 and water_checks.safe > 0 and water_checks.depth, "rise hooks under grounded ball=%d; safe=%d; depth cap=%s" % [water_checks.under, water_checks.safe, water_checks.depth])
	_check(LABELS[2], not bad and started and water_checks.under == 0 and water_checks.safe > 0 and water_checks.depth, "clearance, projected travel, mid-fill grounding and 1.2 m water cap")


func _overlap() -> void:
	var rows := []
	for spec in [["collapse", "natural"], ["fleet_landing", "fleet"], ["machine_eruption", "ancient"], ["boiler_burst", "industrial"]]:
		for i in 3:
			var r := _row(spec[1] + str(i), spec[0], spec[1], 0.1)
			r.once = false
			r.live_s = 6.0
			if spec[1] == "industrial":
				r.effect.swap = "roof"
			rows.append(r)
	var d = _director(rows, [], 90871)
	var live := {}
	var counts := {"natural": 0, "fleet": 0, "ancient": 0, "industrial": 0}
	var random := RandomNumberGenerator.new()
	random.seed = 90902
	var now := 0.0
	var broken := -INF
	var violations := 0
	var starts := 0
	for i in 10000:
		var dt := random.randf_range(0.03, 0.2)
		now += dt
		var pulse: Array = []
		if i % 1500 == 200:
			broken = now
			pulse = ["broken"]
		for f in _step(d, dt, FAR, Vector3.ZERO, {"warden_phases": pulse}):
			if f.kind == "announced" or f.kind == "started":
				if now < broken + 20.0 - 0.000001:
					violations += 1
			if f.kind == "started":
				live[f.id] = f.family
				counts[f.family] += 1
				starts += 1
			if f.kind == "ended":
				live.erase(f.id)
			var fleet := 0
			var ancient := 0
			for family in live.values():
				fleet += int(family == "fleet")
				ancient += int(family == "ancient")
			if live.size() > 2 or fleet > 1 or ancient > 1:
				violations += 1
	_check(LABELS[3], violations == 0 and starts > 100 and counts.values().all(func(n): return n > 0),
		"10000 seeded steps; starts=%d families=%s violations=%d" % [starts, counts, violations])
	# A pending landing must also obey the break quiet window.
	d = _director([_row("pending")])
	var resumed := false
	violations = 0
	for i in 700:
		for f in _step(d, H, FAR, Vector3.ZERO, {"warden_phases": ["broken"] if i == 50 else []}):
			if f.kind == "started":
				violations += int(d.stage_time < 2.55 + 20.0 - 0.000001)
				resumed = true
	_check("pending landing quiet window", violations == 0 and resumed, "break at 2.55 s, landing deferred until 22.55 s")


func _lifecycle() -> void:
	var r := _row("repeat")
	r.once = false
	r.live_s = 1.0
	r.cooldown_s = 4.0
	var d = _director([r])
	var last_end := -INF
	var starts := 0
	var good := true
	for i in 600:
		for f in _step(d):
			if f.kind == "announced":
				good = good and d.stage_time >= last_end + 4.0 - 0.000001
			if f.kind == "started":
				starts += 1
			if f.kind == "ended":
				last_end = d.stage_time
	_check("row cooldown", starts >= 3 and good, "%d repeats after independent 4 s cooldown" % starts)
	r.once = true
	r.live_s = 0.0
	d = _director([r])
	var persistent := false
	for i in 500:
		for f in _step(d):
			persistent = persistent or f.kind == "started"
	var ended: Array = d.finish_row("repeat")
	_check("persistent row finish and cleanup", persistent and ended.size() == 1 and ended[0].kind == "ended" and d.end_all().is_empty(), str(ended))


func _weather() -> void:
	var w := {"id": "monsoon", "kind": "monsoon", "trigger": {"on": "clock_tier", "value": 2}, "lead_s": 4.0,
		"live_s": 10.0, "gap_s": 5.0, "fog": {}, "sky": "storm", "sound": "monsoon_far_thunder",
		"music_layer": "monsoon_pad", "event_odds": {"test": 2.5}, "handling": "none"}
	var d = _director([], [w])
	var log := []
	d.register_family("weather", func(action, r, ctx): log.append([action, ctx.clock_s, r]))
	var facts := []
	for i in 600:
		facts.append_array(_step(d))
	var announces := facts.filter(func(f): return f.kind == "announced")
	var starts := facts.filter(func(f): return f.kind == "started")
	var ends := facts.filter(func(f): return f.kind == "ended")
	var ok := announces.size() >= 2 and starts.size() >= 2 and ends.size() >= 1 and not log.is_empty()
	if ok:
		ok = starts[0].time_s - announces[0].time_s >= 4.0 - 0.000001 and announces[1].time_s - ends[0].time_s >= 5.0 - 0.000001
		ok = ok and log[0][2].handling == "none" and log[0][2].event_odds.test == 2.5
	_check("weather row scheduler", ok, "%d announcements, %d starts, %d ends, hook retains fog/sky/sound/music/odds/handling" % [announces.size(), starts.size(), ends.size()])
	w.trigger = {"on": "always"}
	w.lead_s = 0.0
	w.live_s = 100.0
	w.event_odds.test = 0.0
	d = _director([_row("test")], [w])
	var suppressed := true
	var weather_live := false
	for i in 1000:
		for f in _step(d, H, FAR, Vector3.ZERO, {"clock_tier": 0 if i < 5 else 4}):
			weather_live = weather_live or (f.kind == "started" and f.id == "monsoon")
			suppressed = suppressed and not (f.kind == "announced" and f.id == "test")
	_check("weather odds applied", weather_live and suppressed, "a live weather multiplier of zero suppresses the named event")


func _ending_safety() -> void:
	var row := _row("restore")
	row.live_s = 1.0
	var d = _director([row])
	var ended := false
	var early := false
	for i in 300:
		var ball := Vector3(21, 1, 0) if i >= 110 and i < 200 else FAR
		for f in _step(d, H, ball):
			if f.kind == "ended":
				ended = true
				early = early or i < 200
	_check("restoration waits for clearance", ended and not early, "duration ends at 6.05 s, ball inside clearance until 10 s")
	# The only bypass is a live opening. It may not expire while a second row
	# still closes the original edge, even though removing either alone is safe.
	var opening := _row("open", "lightning", "natural", 3.0)
	opening.route_change.opens = ["bypass"]
	opening.live_s = 10.0
	var closing := _row("close", "lightning", "natural", 3.0)
	closing.trigger.value = 2
	closing.route_change.closes = ["main"]
	closing.live_s = 20.0
	var map := Map.new()
	map.park = {"map": "fixture", "event_rows": [opening, closing], "weather_rows": [],
		"park_rows": [{"id": "site", "at": [0, 0], "y": 0, "size": [20, 2, 20], "yaw_deg": 0}],
		"routes": [{"id": "main", "from": "drop_in", "to": "landmark", "via": []}, {"id": "bypass", "from": "drop_in", "to": "landmark", "via": []}]}
	d = Director.new(891, {}, map, 14.0, func(_x, _z): return 0.0)
	var live := {}
	var connected := true
	var completed := false
	var closure_seen := false
	for i in 800:
		for f in _step(d, H, FAR, Vector3.ZERO, {"clock_tier": 1 if i < 75 else 2}):
			if f.kind == "started":
				live[f.id] = true
				closure_seen = closure_seen or f.id == "close"
			if f.kind == "ended":
				live.erase(f.id)
				completed = completed or f.id == "open"
			connected = connected and (not live.has("close") or live.has("open"))
	_check("restoration keeps a route", connected and completed and closure_seen and live.is_empty(), "opening held until the independent main closure expires")


func _check(label: String, ok: bool, detail: String) -> void:
	_failures += int(not ok)
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
