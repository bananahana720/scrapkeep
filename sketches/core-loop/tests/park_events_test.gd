extends SceneTree

const Director := preload("res://src/world/event_director.gd")
const Kinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const H := 0.05
const BAR := 240.0 / 172.0
const FAR := Vector3(1000.0, 1.0, 1000.0)
# Steps in the director's flood hold cap (PARK_FLOOD_HOLD_CAP_S, W1-148).
const CAP_STEPS := int(Director.PARK_FLOOD_HOLD_CAP_S / H + 0.5)
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
		_warning_grammar()
		_clearance()
		_site_footprints()
		_site_clearance()
		_site_corridors()
		_toe_vents_wake()
		_water_lifetime()
		_flood_hold_cap()
		_full_water_at_entry()
		_overlap()
		_held_announcements()
		_corridors()
		_lifecycle()
		_teardown_announcements()
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


func _warning_grammar() -> void:
	var bad := []
	for form in ["flood_rising", "fleet_inbound", "ancient_stirring", "boiler_pressure", "lightning_charge"]:
		var row: Dictionary = Kinds.world_row(form)
		if row.get("color") != Palette.HAZARD or row.get("sound") != "threat_whistle" or row.get("priority") != 2 or not str(row.get("sound_next", "")).ends_with("falling_pure"):
			bad.append(form)
	_check("hostile telegraph colour and sound grammar", bad.is_empty(), "five WORLD_ROWS warnings use Palette.HAZARD, threat_whistle, priority 2 and falling_pure; mismatches=%s" % [bad])


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
		var ball := Vector3(0, 1, 0) if i >= 120 and i < 120 + CAP_STEPS - 5 else FAR
		_step(d, H, ball)
	_check("water pauses mid-fill", water_checks.under == 0 and water_checks.safe > 0 and water_checks.depth, "rise hooks under grounded ball=%d; safe=%d; depth cap=%s" % [water_checks.under, water_checks.safe, water_checks.depth])
	_check(LABELS[2], not bad and started and water_checks.under == 0 and water_checks.safe > 0 and water_checks.depth, "clearance, projected travel, mid-fill grounding and 1.2 m water cap")


# These fixtures use hand-computed yaw-30 coordinates: cos=√3/2, sin=1/2.
# The centre is [17,-23], local X is width, and local Z is length along the facing.
func _site_world(local: Vector2, yaw := 30.0) -> Vector2:
	if yaw == 0.0:
		return Vector2(17, -23) + local
	return Vector2(17 + 0.866025403784 * local.x + 0.5 * local.y,
		-23 - 0.5 * local.x + 0.866025403784 * local.y)


func _long_site(yaw := 30.0) -> Dictionary:
	return {"id": "site", "element": "ground", "at": [17, -23], "y": 0,
		"size": [100, 2, 20], "yaw_deg": yaw, "recipe": "greybox:ground", "ride_fact": ""}


func _site_director(row: Dictionary, yaw := 30.0):
	var map := Map.new()
	map.park = {"map": "fixture", "event_rows": [row], "weather_rows": [], "park_rows": [_long_site(yaw)],
		"routes": [{"id": "main", "from": "drop_in", "to": "landmark"}, {"id": "bypass", "from": "drop_in", "to": "landmark"}]}
	return Director.new(891, {}, map, 14.0, func(_x, _z): return 0.0)


func _site_footprints() -> void:
	var row := _long_site()
	var parent := Node3D.new()
	root.add_child(parent)
	var placed := ParkRecipes.place_greybox(row, "ground", parent)
	var shape: BoxShape3D = placed.get_node("Collider").get_child(0).shape
	var collider_half := Vector2(shape.size.x, shape.size.z) * 0.5
	var geometry: Script = ParkMap
	var helpers := geometry.has_method("footprint_half_extents") and geometry.has_method("footprint_contains")
	_check("shared site footprint helpers exist", helpers, "non-square yaw-30 greybox collider half=%s; require ParkMap helpers" % collider_half)
	if not helpers:
		parent.free()
		return
	var half: Vector2 = geometry.call("footprint_half_extents", row)
	_check("site footprint agrees with placed collider", half.is_equal_approx(collider_half) and half.is_equal_approx(Vector2(10, 50)),
		"helper=%s collider=%s hand expected=[10,50]" % [half, collider_half])
	var bad := []
	# Each edge has a point 0.1 m inside and outside; repeat with a 2 m margin.
	for margin in [0.0, 2.0]:
		for edge in [[Vector2(9.9 + margin, 0), true], [Vector2(10.1 + margin, 0), false],
			[Vector2(-9.9 - margin, 0), true], [Vector2(-10.1 - margin, 0), false],
			[Vector2(0, 49.9 + margin), true], [Vector2(0, 50.1 + margin), false],
			[Vector2(0, -49.9 - margin), true], [Vector2(0, -50.1 - margin), false]]:
			var point := _site_world(edge[0])
			var inside: bool = geometry.call("footprint_contains", row, point, margin)
			if inside != edge[1]:
				bad.append([edge[0], margin, inside, edge[1]])
	_check("rotated site containment at every edge", bad.is_empty(), "16 hand-computed inside/outside points; mismatches=%s" % [bad])
	parent.free()


func _site_clearance() -> void:
	for fixture in [["covered", Vector2(0, 40), Vector2.ZERO], ["margin", Vector2(0, 55), Vector2.ZERO],
		["travel", Vector2(-40, 40), Vector2(30, 0)]]:
		var row := _row("site_hold")
		row.live_s = 0.0
		var d = _site_director(row)
		var hooks := {"land": 0}
		d.register_family("natural", func(action, _r, _ctx):
			if action == "land":
				hooks.land += 1)
		var facts := []
		var point := _site_world(fixture[1])
		var travel: Vector2 = _site_world(fixture[2]) - Vector2(17, -23)
		for i in 180:
			facts.append_array(_step(d, H, Vector3(point.x, 1, point.y), Vector3(travel.x, 0, travel.y)))
		var announced: int = facts.filter(func(f): return f.kind == "announced").size()
		var starts: int = facts.filter(func(f): return f.kind == "started").size()
		var landing: int = facts.filter(func(f): return f.kind == "world" and f.get("phase") == "land").size()
		_check("site-derived %s holds landing" % fixture[0], announced == 1 and starts == 0 and landing == 0 and hooks.land == 0,
			"local=%s velocity=%s announced=%d started=%d landing_world=%d land_hooks=%d" % [fixture[1], fixture[2], announced, starts, landing, hooks.land])
		var released := []
		for i in 100:
			released.append_array(_step(d))
		_check("site-derived %s lands after clearance" % fixture[0], released.filter(func(f): return f.kind == "started").size() == 1
			and released.filter(func(f): return f.kind == "world" and f.get("phase") == "land").size() == 1 and hooks.land == 1,
			"clearance returned at 9 s; one start, landing fact and callback required")
	# Flood landing itself must wait for a grounded ball covered only by the long Z side.
	var water := _row("site_water", "flash_flood", "natural", 5.0)
	water.hold_clear_m = 0.0
	water.effect = {"depth_m": 1.2, "fill_s": 10.0, "material": "water"}
	water.live_s = 20.0
	var d = _site_director(water)
	var point := _site_world(Vector2(0, 40))
	var under := Vector3(point.x, 1, point.y)
	var facts := []
	var hooks := {"land": 0, "unsafe": 0, "safe": 0, "before": -1.0, "resumed": -1.0}
	d.register_family("natural", func(action, _r, ctx):
		if action == "land":
			hooks.land += 1
		if action == "step":
			if ctx.grounded and ctx.ball.is_equal_approx(under) and ctx.rise_s < 10.0:
				hooks.unsafe += 1
			else:
				hooks.safe += 1
				if ctx.clock_s <= 11.0 + 0.000001:
					hooks.before = ctx.rise_s
				elif ctx.clock_s >= 11.0 + (CAP_STEPS - 5) * H - 0.000001 and hooks.resumed < 0.0:
					hooks.resumed = ctx.rise_s)
	for i in 180:
		facts.append_array(_step(d, H, under))
	_check("site-derived grounded flood holds landing", facts.filter(func(f): return f.kind == "announced").size() == 1
		and facts.filter(func(f): return f.kind == "started").is_empty()
		and facts.filter(func(f): return f.kind == "world" and f.get("phase") == "land").is_empty() and hooks.land == 0,
		"grounded local [0,40], no footprint override; land_hooks=%d" % hooks.land)
	var released := []
	for i in 40:
		released.append_array(_step(d))
	_check("site-derived grounded flood lands after clearance", released.filter(func(f): return f.kind == "started").size() == 1
		and released.filter(func(f): return f.kind == "world" and f.get("phase") == "land").size() == 1 and hooks.land == 1,
		"grounded ball clears at 9 s; one landing required")
	for i in CAP_STEPS - 5:
		_step(d, H, under)
	for i in 85:
		_step(d)
	_check("site-derived live flood pauses under grounded ball", hooks.unsafe == 0 and hooks.safe > 0 and hooks.before > 0.0
		and absf(hooks.resumed - hooks.before - H) < 0.000001,
		"unsafe=%d safe=%d fill before=%.3f resumed=%.3f expected increment=%.2f" % [hooks.unsafe, hooks.safe, hooks.before, hooks.resumed, H])


func _site_corridors() -> void:
	for spec in [["fleet_landing", "fleet"], ["machine_eruption", "ancient"]]:
		for yaw in [0.0, 30.0]:
			# The long side ends at local Z=50; the corridor ends at Z=58.
			for fixture in [["held", 57.0, false, 0], ["clear", 59.0, false, 1], ["alternate", 57.0, true, 1]]:
				var row := _row("site_corridor", spec[0], spec[1])
				row.live_s = 0.0
				if fixture[2]:
					row.route_change = {"closes": ["main"], "opens": ["bypass"]}
				var d = _site_director(row, yaw)
				var hooks := {"land": 0}
				d.register_family(spec[1], func(action, _r, _ctx):
					if action == "land":
						hooks.land += 1)
				var lines := [[_site_world(Vector2(-30, fixture[1]), yaw), _site_world(Vector2(30, fixture[1]), yaw)]]
				var facts := []
				for i in 400:
					facts.append_array(_step(d, H, FAR, Vector3.ZERO, {"pilot_lines": lines}))
				var announced: int = facts.filter(func(f): return f.kind == "announced").size()
				var starts: int = facts.filter(func(f): return f.kind == "started").size()
				var landing: int = facts.filter(func(f): return f.kind == "world" and f.get("phase") == "land").size()
				_check("site-derived corridor %s yaw %.0f %s" % [spec[1], yaw, fixture[0]], announced == 1
					and starts == fixture[3] and landing == fixture[3] and hooks.land == fixture[3],
					"local line Z=%s announced=%d started=%d landing_world=%d land_hooks=%d expected=%d" % [fixture[1], announced, starts, landing, hooks.land, fixture[3]])


func _toe_vents_wake() -> void:
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/park_dam.json"))
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/park/park_dam/lines.json"))
	var places := {"drop_in": park.spawn.at, "landmark": park.landmark.beacon}
	for table in ["park_rows", "activity_rows"]:
		for row in park[table]:
			places[row.id] = row.at
	var site: Dictionary
	for row in park.park_rows:
		if row.id == "toe_vent_pits":
			site = row
	var resolved := []
	var all: Dictionary = lines.pilots.duplicate(true)
	all.floor = lines.floor
	var clear := true
	for key in all:
		var points := []
		for wp in all[key].waypoints:
			var at: Array = places[wp] if wp is String else wp
			points.append(Vector2(at[0], at[1]))
		var hit := false
		for i in range(1, points.size()):
			hit = hit or ParkMap.footprint_contains(site, points[i - 1], Director.PARK_CORRIDOR_M, points[i])
		clear = clear and not hit
		resolved.append(points)
	var event: Dictionary
	for row in park.event_rows:
		if row.id == "toe_vents_wake":
			event = row
	park.event_rows = [event]
	park.weather_rows = []
	var map := Map.new()
	map.park = park
	var d = Director.new(77731, {}, map, 14.0, func(_x, _z): return 0.0)
	var observed := {"announced": 0, "started": 0, "telegraph": 0, "land": 0, "land_hooks": 0}
	d.register_family("ancient", func(action, _row, _ctx):
		if action == "land":
			observed.land_hooks += 1)
	for i in 400:
		for f in d.advance(0.05, Vector3(5000, 1, 5000), Vector3.ZERO, {"clock_tier": 2, "grounded": true, "bar_origin_s": 0.0, "pilot_lines": resolved}):
			if f.kind in ["announced", "started"]:
				observed[f.kind] += 1
			if f.kind == "world" and f.get("phase") in ["telegraph", "land"]:
				observed[f.phase] += 1
	_check("toe_vents_wake telegraphs and lands off all seven corridors", clear and observed.values().all(func(value): return value == 1), str(observed))


# The ball rolls in one tick before the ground event has finished filling, then again once it has.
# Rates and fill times are swept because the fault was a rounding remainder that only some pairs leave.
func _full_water_at_entry() -> void:
	for kind in ["flash_flood", "collapse"]:
		for hz in [60.0, 90.0, 120.0]:
			for fill_s in [4.0, 6.0]:
				# Every real collapse row has no live time; every real flood row has one.
				for live_s in [20.0, 0.0]:
					var row := _row("boundary", kind)
					row.effect = {"fill_s": fill_s, "material": "water"} if kind == "flash_flood" else {"fill_s": fill_s}
					row.live_s = live_s
					var director = _director([row])
					var occupied_steps := []
					director.register_family("natural", func(action, _row, context):
						if action == "step" and context.ball == Vector3.UP:
							occupied_steps.append(context.rise_s))
					var delta: float = 1.0 / hz
					var started := false
					for tick in 1800:
						if _step(director, delta).any(func(fact): return fact.kind == "started"):
							started = true
							break
					var at := "%s, %d ticks a second, %.0f s fill, %.0f s live" % [kind, int(hz), fill_s, live_s]
					_check("boundary event starts on clear ground (%s)" % at, started, "")
					for tick in int(round(fill_s * hz)) - 1:
						_step(director, delta)
					_step(director, delta, Vector3.UP)
					_check("one tick short of full still waits under a grounded ball (%s)" % at, occupied_steps.is_empty(), str(occupied_steps))
					_step(director, delta)
					_step(director, delta, Vector3.UP)
					_step(director, delta, Vector3.UP)
					_check("a full event keeps stepping under the ball (%s)" % at, occupied_steps.size() == 2, str(occupied_steps))
					if kind == "flash_flood":
						_check("full water reports its whole fill time (%s)" % at, occupied_steps == [fill_s, fill_s], str(occupied_steps))


func _water_lifetime() -> void:
	for release_s in [10.0, 24.0]:
		var row := _row("water_lifetime", "flood_fill", "natural", 5.0)
		row.hold_clear_m = 0.0
		row.effect = {"depth_m": 1.2, "fill_s": 10.0, "material": "water"}
		row.live_s = 20.0
		var d = _director([row])
		var starts := []
		var ends := []
		var hooks := {"unsafe": 0, "end": 0, "last_rise": -1.0, "resume_rise": -1.0}
		d.register_family("natural", func(action, _r, ctx):
			if action == "end":
				hooks.end += 1
			if action == "step":
				if not starts.is_empty():
					var elapsed: float = ctx.clock_s - starts[0].time_s
					# The hold is spent CAP s after the ball sits down at 1 s; a rise step before that is unsafe.
					hooks.unsafe += int(ctx.grounded and ctx.ball == Vector3(0, 1, 0) and ctx.rise_s < 10.0 and elapsed < 1.0 + Director.PARK_FLOOD_HOLD_CAP_S - 2.0 * H)
					if elapsed < 1.0 - 0.000001:
						hooks.last_rise = ctx.rise_s
					elif elapsed >= release_s - 0.000001 and hooks.resume_rise < 0.0:
						hooks.resume_rise = ctx.rise_s)
		for i in 900:
			var now := (i + 1) * H
			var held: bool = not starts.is_empty() and now >= starts[0].time_s + 1.0 - 0.000001 and now < starts[0].time_s + release_s - 0.000001
			for f in _step(d, H, Vector3(0, 1, 0) if held else FAR):
				if f.kind == "started":
					starts.append(f)
				if f.kind == "ended":
					ends.append(f)
		var expected := -1.0
		if starts.size() == 1:
			expected = float(starts[0].time_s) + maxf(float(row.live_s), release_s)
		var ok: bool = starts.size() == 1 and ends.size() == 1 and hooks.end == 1 and hooks.unsafe == 0
		if ends.size() == 1:
			ok = ok and ends[0].time_s >= expected - 0.000001 and ends[0].time_s <= expected + H + 0.000001
		if release_s < float(row.live_s):
			# The ball sat down at 1 s; the rise waited the cap, then went on around it.
			var expected_rise: float = hooks.last_rise + release_s - 1.0 - Director.PARK_FLOOD_HOLD_CAP_S + H
			ok = ok and hooks.last_rise >= 0.0 and absf(hooks.resume_rise - expected_rise) < 2.0 * H
		_check("water lifetime release %.0f s" % release_s, ok,
			"starts=%s ends=%s expected=%.3f unsafe_hooks=%d end_hooks=%d fill_before=%.3f fill_after=%.3f" % [starts.map(func(f): return f.time_s), ends.map(func(f): return f.time_s), expected, hooks.unsafe, hooks.end, hooks.last_rise, hooks.resume_rise])


# W1-148: the wait for a grounded ball is capped (PARK_FLOOD_HOLD_CAP_S of live time), then the water rises around
# it, so a ball parked in the basin from the landing is stepped and taxed. The wait itself keeps its reason: a
# ball that arrives as the water lands is not swapped under inside the cap.
func _flood_hold_cap() -> void:
	var row := _row("hold_cap", "flood_fill", "natural", 5.0)
	row.hold_clear_m = 0.0
	row.effect = {"depth_m": 1.2, "fill_s": 10.0, "material": "water"}
	row.live_s = 30.0
	var d = _director([row])
	var under := Vector3(0, 1, 0)
	var landed_at := -1.0
	var stats := {"steps": [], "under": []}
	d.register_family("natural", func(action, _r, ctx):
		if action == "step":
			stats.steps.append(ctx.clock_s)
			if ctx.ball == under and ctx.grounded:
				stats.under.append(ctx.clock_s))
	var ends := 0
	for i in 800:
		var parked: bool = landed_at >= 0.0 and float(d.stage_time) < landed_at + row.live_s
		for f in _step(d, H, under if parked else FAR):
			if f.kind == "started" and landed_at < 0.0:
				landed_at = float(f.time_s)
			ends += int(f.kind == "ended")
	var first_under: float = stats.under[0] if not stats.under.is_empty() else INF
	var risen_under: int = stats.under.size()
	_check("hold reason: a ball arriving as the water lands is not swapped under within the cap",
		landed_at >= 0.0 and first_under >= landed_at + Director.PARK_FLOOD_HOLD_CAP_S - 2.0 * H,
		"landed %.2f s; first step under the ball %.2f s; cap %.1f s" % [landed_at, first_under, Director.PARK_FLOOD_HOLD_CAP_S])
	_check("hold cap: past the cap the water rises around a parked ball", landed_at >= 0.0
		and first_under <= landed_at + Director.PARK_FLOOD_HOLD_CAP_S + 2.0 * H and risen_under >= int(10.0 / H) - 2,
		"first step under the ball %.2f s after landing; %d steps under it" % [first_under - landed_at, risen_under])
	_check("hold cap: a flood with a ball parked through its whole live time ends once the ball leaves", ends == 1,
		"ends=%d" % ends)


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


func _held_announcements() -> void:
	var held_a := _row("held_a")
	var held_b := _row("held_b")
	var clear := _row("clear")
	clear.site = "clear_site"
	clear.trigger.value = 2
	var map := Map.new()
	map.park = {"map": "fixture", "event_rows": [held_a, held_b, clear], "weather_rows": [],
		"park_rows": [{"id": "site", "at": [0, 0], "y": 0, "size": [20, 2, 20], "yaw_deg": 0},
			{"id": "clear_site", "at": [100, 0], "y": 0, "size": [20, 2, 20], "yaw_deg": 0}],
		"routes": [{"id": "main", "from": "drop_in", "to": "landmark"}]}
	var d = Director.new(891, {}, map, 14.0, func(_x, _z): return 0.0)
	var announced := {}
	var starts := []
	var land := []
	d.register_family("natural", func(action, row_data, _ctx):
		if action == "land":
			land.append(row_data.id))
	for i in 600:
		for f in _step(d, H, Vector3(0, 1, 0), Vector3.ZERO, {"clock_tier": 1 if i < 300 else 2}):
			if f.kind == "announced":
				announced[f.id] = d.stage_time
			if f.kind == "started":
				starts.append(f.id)
	_check("held announcements do not reserve live capacity", announced.has("held_a") and announced.has("held_b")
		and announced.has("clear") and starts == ["clear"] and land == ["clear"],
		"announced=%s starts=%s land=%s" % [announced.keys(), starts, land])


func _corridors() -> void:
	for spec in [["fleet_landing", "fleet"], ["machine_eruption", "ancient"]]:
		# The 40 x 8 footprint ends at z=4. Its 8 m corridor reaches z=12.
		# At yaw 90 the long side instead reaches world z=20, plus the 8 m corridor.
		for fixture in [["margin held", 0, 10.0, false, false], ["clear", 0, 13.0, false, true],
			["alternate", 0, 10.0, true, true], ["yaw held", 90, 20.0, false, false],
			["yaw clear", 90, 29.0, false, true], ["yaw alternate", 90, 20.0, true, true]]:
			var row := _row("corridor", spec[0], spec[1])
			row.effect.footprint_m = [40, 8]
			row.live_s = 0.0
			if fixture[3]:
				row.route_change = {"closes": ["main"], "opens": ["bypass"]}
			var map := Map.new()
			map.park = {"map": "fixture", "event_rows": [row], "weather_rows": [],
				"park_rows": [{"id": "site", "at": [0, 0], "y": 0, "size": [100, 2, 100], "yaw_deg": fixture[1]}],
				"routes": [{"id": "main", "from": "drop_in", "to": "landmark"}, {"id": "bypass", "from": "drop_in", "to": "landmark"}]}
			var d = Director.new(891, {}, map, 14.0, func(_x, _z): return 0.0)
			var land := []
			d.register_family(spec[1], func(action, _r, _ctx):
				if action == "land":
					land.append(action))
			var announced := 0
			var started := 0
			var landing_world := 0
			var lines := [[Vector2(-50, fixture[2]), Vector2(50, fixture[2])]]
			for i in 400:
				for f in _step(d, H, FAR, Vector3.ZERO, {"pilot_lines": lines}):
					announced += int(f.kind == "announced")
					started += int(f.kind == "started")
					landing_world += int(f.kind == "world" and f.get("phase") == "land")
			var expected := int(fixture[4])
			_check("pilot corridor %s %s" % [spec[1], fixture[0]], announced == 1 and started == expected
				and landing_world == expected and land.size() == expected,
				"yaw=%s line z=%s announced=%d started=%d landing_world=%d land_hooks=%d expected=%d" % [fixture[1], fixture[2], announced, started, landing_world, land.size(), expected])


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
	var arrival := _row("persistent", "fleet_landing", "fleet")
	arrival.live_s = 0.0
	arrival.route_change = {"closes": ["main"], "opens": ["bypass"]}
	var rival := _row("rival", "fleet_landing", "fleet")
	rival.trigger.value = 2
	var dependent := _row("dependent", "lightning", "natural")
	dependent.trigger.value = 2
	dependent.route_change.closes = ["main"]
	var map := Map.new()
	map.park = {"map": "fixture", "event_rows": [arrival, rival, dependent], "weather_rows": [],
		"park_rows": [{"id": "site", "at": [0, 0], "y": 0, "size": [20, 2, 20], "yaw_deg": 0}],
		"routes": [{"id": "main", "from": "drop_in", "to": "landmark"}, {"id": "bypass", "from": "drop_in", "to": "landmark"}]}
	d = Director.new(891, {}, map, 14.0, func(_x, _z): return 0.0)
	var facts := []
	var hooks := []
	d.register_family("fleet", func(action, row_data, _ctx): hooks.append([action, row_data.id]))
	for i in 300:
		facts.append_array(_step(d, H, FAR, Vector3.ZERO, {"clock_tier": 1}))
	var early_end: Array = d.finish_row("persistent")
	facts.append_array(early_end)
	for i in 600:
		facts.append_array(_step(d, H, FAR, Vector3.ZERO, {"clock_tier": 2}))
	var persistent_starts := facts.filter(func(f): return f.kind == "started").map(func(f): return f.id)
	var endings := facts.filter(func(f): return f.kind == "ended" and f.id == "persistent")
	var teardown: Array = d.end_all()
	var cleanup := teardown.filter(func(f): return f.kind == "ended" and f.id == "persistent")
	var rival_cleanup := teardown.filter(func(f): return f.kind == "ended" and f.id == "rival")
	var hooks_after_teardown := hooks.size()
	var second_teardown: Array = d.end_all()
	_check("persistent row holds routes and capacity until teardown", early_end.is_empty() and endings.is_empty()
		and persistent_starts.has("persistent") and persistent_starts.has("dependent") and not persistent_starts.has("rival")
		and cleanup.size() == 1 and hooks.count(["end", "persistent"]) == 1 and second_teardown.is_empty(),
		"starts=%s early_end=%s teardown=%s" % [persistent_starts, early_end, teardown.map(func(f): return f.id)])
	_check("teardown closes capacity-blocked announcement", facts.filter(func(f): return f.kind == "announced" and f.id == "rival").size() == 1
		and rival_cleanup.size() == 1 and hooks.count(["telegraph", "rival"]) == 1 and hooks.count(["end", "rival"]) == 1
		and hooks.count(["land", "rival"]) == 0 and not persistent_starts.has("rival")
		and second_teardown.is_empty() and hooks.size() == hooks_after_teardown,
		"rival ended=%d end_hooks=%d land_hooks=%d second_facts=%d" % [rival_cleanup.size(), hooks.count(["end", "rival"]), hooks.count(["land", "rival"]), second_teardown.size()])


func _teardown_announcements() -> void:
	var held := _row("held_teardown")
	held.route_change = {"closes": ["main"], "opens": ["unused"]}
	var silent := _row("never_announced")
	silent.trigger.value = 5
	var d = _director([held, silent])
	var hooks := []
	d.register_family("natural", func(action, row_data, _ctx): hooks.append([action, row_data.id]))
	var facts := []
	for i in 300:
		facts.append_array(_step(d, H, Vector3(0, 1, 0)))
	var teardown: Array = d.end_all()
	var hook_count := hooks.size()
	var second: Array = d.end_all()
	var after := []
	for i in 300:
		after.append_array(_step(d))
	var announcements := facts.filter(func(f): return f.kind == "announced" and f.id == held.id)
	var starts := facts.filter(func(f): return f.kind == "started")
	var lands := facts.filter(func(f): return f.kind == "world" and f.get("phase") == "land")
	var ok: bool = announcements.size() == 1 and starts.is_empty() and lands.is_empty() and teardown.size() == 1
	if teardown.size() == 1:
		ok = ok and teardown[0].kind == "ended" and teardown[0].id == held.id and teardown[0].outcome == "passed"
		ok = ok and teardown[0].family == "natural" and absf(teardown[0].time_s - 300 * H) < 0.000001 and teardown[0].row == held
	ok = ok and hooks.count(["telegraph", held.id]) == 1 and hooks.count(["end", held.id]) == 1
	ok = ok and hooks.count(["land", held.id]) == 0 and hooks.size() == hook_count
	ok = ok and facts.filter(func(f): return f.id == silent.id).is_empty() and hooks.filter(func(h): return h[1] == silent.id).is_empty()
	ok = ok and second.is_empty() and after.is_empty()
	_check("teardown cancels held announcement once", ok,
		"announced=%d starts=%d landing_facts=%d teardown=%s hooks=%s second_facts=%d after_facts=%d" % [announcements.size(), starts.size(), lands.size(), teardown.map(func(f): return f.id), hooks, second.size(), after.size()])


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
