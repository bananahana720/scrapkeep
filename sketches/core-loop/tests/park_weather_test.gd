extends SceneTree

# Rule (KE7, K-UNITS.md KE7; PARK.md section 6 "Time of day" and veto items 2 and 8): each stage enters at its
# time of day, the six picks read dawn at the dam to dusk at the crown. The weather rows run through the real
# event director, the same one that schedules them in play, with the weather module's hook registered. Each row
# keeps its lead, live and gap timings, writes its fog when it goes live and restores it when it ends, and changes
# no ball handling: the ball's motion, its physics material and the movement tuning match with weather on and off,
# and a planted friction change in the hook is caught. The rows come from the six stage pages' park blocks.
#
# Checks: 10 time (six time rows, fields, sun peak, six stage ids, row count), 6 stage look, 6 stage entry,
# 12 timing, 12 look (fog, sky, music, sound id), 12 handling, 1 planted control, 6 park fog (the stage's loaded park
# file gives the fog the file read does). The check count is fixed below.
const Weather := preload("res://src/world/events/weather.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Director := preload("res://src/world/event_director.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const BallState := preload("res://src/movement/ball_state.gd")

const PAGES := "res://design-v3/park/stages"
const PARK := "res://design-v3/PARK.md"
const TIME_ORDER := ["dawn", "morning", "noon", "afternoon", "golden", "dusk"]
const H := 0.05
const TICKS := 600
const TOLERANCE := 0.08
const FAR := Vector3(1000.0, 1.0, 1000.0)
const FOG_BEFORE := 0.0123
const EXPECTED_CHECKS := 65

var _checks := 0
var _failures := 0


class Intent extends RefCounted:
	var brake_held := false


class Map extends RefCounted:
	var park := {}


class Terrain extends RefCounted:
	var environment: Environment
	var root := Node3D.new()

	func _init(env: Environment) -> void:
		environment = env

	func geometry_root(_stage: int) -> Node3D:
		return root

	func map_for(_stage: int) -> RefCounted:
		return null


class StageCtx extends RefCounted:
	var terrain
	var stages = StageDefs
	var root = null
	var player = null
	var events = null


func _initialize() -> void:
	_time_rows()
	var weather := _weather_rows()
	_check("twelve weather rows across the six stage pages", weather.size() == 12, "%d rows" % weather.size())
	for stage in range(1, 7):
		_stage_look(stage)
	for stage in range(1, 7):
		_stage_entry(stage)
	for stage in range(1, 7):
		_park_fog(stage)
	var runs := []
	for row in weather:
		runs.append(_run(row, true, false))
	for i in weather.size():
		_timing(weather[i], runs[i])
	for i in weather.size():
		_look(weather[i], runs[i])
	for i in weather.size():
		_handling(weather[i], runs[i], _run(weather[i], false, false))
	_control(weather[0])
	var count_ok := _checks == EXPECTED_CHECKS
	print("park_weather_test: checks %d, expected %d" % [_checks, EXPECTED_CHECKS])
	print("park_weather_test: %s" % ("PASS" if _failures == 0 and count_ok else "FAIL"))
	quit(0 if _failures == 0 and count_ok else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	_failures += int(not ok)
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _json_blocks(text: String) -> Array:
	var blocks := []
	var parts := text.split("```")
	for i in range(1, parts.size(), 2):
		blocks.append(parts[i].trim_prefix("json"))
	return blocks


func _weather_rows() -> Array:
	var rows := []
	var names := Array(DirAccess.get_files_at(PAGES)).filter(func(n): return n.ends_with(".md"))
	names.sort()
	for page in names:
		var text := FileAccess.get_file_as_string(PAGES + "/" + page)
		var park := {}
		for block in _json_blocks(text):
			var json := JSON.new()
			if json.parse(block) != OK:
				continue
			var parsed = json.data
			if parsed is Dictionary and parsed.has("schema"):
				# 2026-10-13: KD6 merge e8471670, 6-park_crown.md:850-852 keeps the draft
				# before its shipped snapshot. Match park_schema_test.gd:172-179's last-object reader.
				park = parsed
		rows.append_array(park.get("weather_rows", []))
	return rows


# The stage number and time id from PARK.md's stage table (the Time of day column).
func _page_times() -> Dictionary:
	var out := {}
	for line in FileAccess.get_file_as_string(PARK).split("\n"):
		var cells := line.split("|")
		if not line.begins_with("| ") or cells.size() < 10:
			continue
		var stage := cells[1].strip_edges()
		var id := cells[8].strip_edges().trim_prefix("`").trim_suffix("`")
		if stage.is_valid_int() and TIME_ORDER.has(id):
			out[int(stage)] = id
	return out


func _time_rows() -> void:
	var rows: Dictionary = WorldLook.TIME_ROWS
	_check("six time rows from dawn to dusk", rows.size() == 6 and WorldLook.TIME_ORDER == TIME_ORDER,
		str(WorldLook.TIME_ORDER))
	var fields := true
	for id in TIME_ORDER:
		var row: Dictionary = rows.get(id, {})
		fields = fields and row.get("sun_rotation") is Vector3 and row.get("sun_color") is Color \
			and row.get("sun_energy") is float and row.get("ambient") is Color and row.get("energy") is float
	_check("each time row sets sun rotation, colour, energy and ambient", fields, "")
	# The sun's height is minus its pitch. It peaks at noon and is lowest at dawn and dusk.
	var height := {}
	for id in TIME_ORDER:
		height[id] = -float(rows.get(id, {}).get("sun_rotation", Vector3.ZERO).x)
	var peaked: bool = height.get("noon", 0.0) > height.get("morning", 0.0) \
		and height.get("noon", 0.0) > height.get("afternoon", 0.0) \
		and height.get("dawn", 0.0) < height.get("morning", 0.0) \
		and height.get("dusk", 0.0) < height.get("golden", 0.0) \
		and height.get("golden", 0.0) < height.get("afternoon", 0.0)
	_check("sun height peaks at noon, lowest at dawn and dusk", peaked, str(height))
	var page_times := _page_times()
	for stage in range(1, 7):
		var id: String = page_times.get(stage, "")
		_check("stage %d enters at %s" % [stage, id],
			id != "" and WorldLook.time_id(stage) == id and rows.has(id),
			"world_look says %s" % WorldLook.time_id(stage))


# A stage's look is its time row laid over its world row. A dome world keeps its own energy and sun energy.
func _stage_look(stage: int) -> void:
	var world := StageDefs.world_of(stage)
	var base: Dictionary = WorldLook.row(world)
	var time: Dictionary = WorldLook.time_row(stage)
	var look := WorldLook.stage_look(stage, world)
	var dome: bool = base.get("sky") == "dome"
	var sun_ok: bool = look.sun_rotation == time.sun_rotation and look.sun_color == time.sun_color and look.ambient == time.ambient
	var energy_ok: bool = is_equal_approx(float(look.energy), float(base.energy if dome else time.energy)) \
		and is_equal_approx(float(look.sun_energy), float(base.sun_energy if dome else time.sun_energy))
	var world_ok := not base.is_empty()
	for key in base:
		if key in ["sun_rotation", "sun_color", "sun_energy", "ambient", "energy"]:
			continue
		world_ok = world_ok and look.get(key) == base[key]
	_check("stage %d look is its time over world %d" % [stage, world], sun_ok and energy_ok and world_ok,
		"dome %s energy %.3f sun %.3f" % [str(dome), float(look.energy), float(look.sun_energy)])


# Stage entry runs the real hook: the environment must hold the stage's look, not the world row.
func _stage_entry(stage: int) -> void:
	var env := Environment.new()
	env.ambient_light_energy = 9.0
	var ctx := StageCtx.new()
	ctx.terrain = Terrain.new(env)
	WorldLook._on_stage_entered(stage, false, ctx)
	var look := WorldLook.stage_look(stage, StageDefs.world_of(stage))
	var ok: bool = is_equal_approx(env.ambient_light_energy, float(look.energy)) and env.ambient_light_color == look.ambient
	_check("stage %d entry writes its look to the environment" % stage, ok,
		"ambient energy %.3f of %.3f" % [env.ambient_light_energy, float(look.energy)])


# The fog from the stage's loaded park equals the fog read from its file, each from an empty cache.
func _park_fog(stage: int) -> void:
	var map := String(StageDefs.of(stage).get("map", ""))
	WorldLook._park_fog.clear()
	var read := WorldLook.park_fog(map)
	WorldLook._park_fog.clear()
	var loaded := WorldLook.park_fog(map, ParkMap.new(WorldLook.PARK_DIR + map + ".json").park)
	WorldLook._park_fog.clear()
	_check("stage %d (%s) fog from its loaded park matches the file's" % [stage, map], read == loaded and read.has("density"),
		"%s vs %s" % [read, loaded])


func _director(rows: Array):
	var map := Map.new()
	map.park = {"map": "fixture", "event_rows": [], "weather_rows": rows,
		"park_rows": [{"id": "site", "at": [0, 0], "y": 0.0, "size": [20, 2, 20], "yaw_deg": 0}],
		"routes": [{"id": "main", "from": "drop_in", "to": "landmark", "via": []}]}
	return Director.new(813, {}, map, 14.0, func(_x, _z): return 0.0)


func _snapshot(tuning) -> Dictionary:
	var out := {}
	for spec in Tuning.SPECS:
		out[spec.key] = tuning.f(spec.key)
	return out


func _body(body: RigidBody3D) -> Dictionary:
	var mat: PhysicsMaterial = body.physics_material_override
	return {"friction": mat.friction, "bounce": mat.bounce, "rough": mat.rough, "absorbent": mat.absorbent,
		"gravity_scale": body.gravity_scale}


# A row's run covers its full cycle, and at least TICKS ticks.
func _ticks(row: Dictionary) -> int:
	return maxi(TICKS, int(ceil(2.0 * (float(row.lead_s) + float(row.live_s) + float(row.gap_s)) / H)) + 20)


# One director run with the ball stepped beside it. With weather on, the row is the only row and the module's
# hook is registered; the wrapper records the environment fog after each hook call and checks the ball's
# physics material and movement tuning around it. A control run changes friction in the hook on land.
func _run(row: Dictionary, weather_on: bool, control: bool) -> Dictionary:
	var env := Environment.new()
	env.fog_enabled = false
	env.fog_density = FOG_BEFORE
	env.fog_light_color = Color.WHITE
	var tuning = Tuning.new()
	var tuning_before := _snapshot(tuning)
	var body := RigidBody3D.new()
	var mat := PhysicsMaterial.new()
	mat.friction = 0.9
	mat.bounce = 0.25
	body.physics_material_override = mat
	var body_before := _body(body)
	var w := Weather.new(env)
	var flags := {"changed": false}
	var trail := []
	var director = _director([row] if weather_on else [])
	if weather_on:
		director.register_family("weather", func(action: String, r: Dictionary, ctx: Dictionary) -> void:
			w.hook(action, r, ctx)
			if control and action == "land":
				mat.friction = 0.1
			trail.append([action, env.fog_enabled, env.fog_density, env.fog_light_color])
			if _body(body) != body_before or _snapshot(tuning) != tuning_before:
				flags.changed = true)
	var ball := BallState.new()
	ball.velocity = Vector3(12.0, 0.0, 4.0)
	ball.grounded = true
	var intent := Intent.new()
	var pos := Vector3.ZERO
	var live := false
	var live_ticks := 0
	var trace := []
	var facts := []
	for i in _ticks(row):
		for f in director.advance(H, FAR, Vector3.ZERO, {"clock_tier": 4, "grounded": true}):
			if f.get("id") == row.id:
				facts.append(f)
				if f.kind == "started":
					live = true
				elif f.kind == "ended":
					live = false
		if live:
			live_ticks += 1
		ball.velocity += Rules.resistance(ball, tuning, intent, H)
		pos += ball.velocity * H
		trace.append([ball.velocity, pos])
	var tuning_same := _snapshot(tuning) == tuning_before and _body(body) == body_before
	body.free()
	return {"facts": facts, "trail": trail, "trace": trace, "velocity": ball.velocity, "position": pos,
		"live_ticks": live_ticks, "changed": flags.changed, "tuning_same": tuning_same}


# A cycling row announces, goes live after lead_s, ends after live_s, and is announced again after gap_s.
# An "always" row is live from its first tick and never cycles.
func _timing(row: Dictionary, run: Dictionary) -> void:
	var always: bool = row.trigger.get("on") == "always"
	var events := []
	for f in run.facts:
		if f.kind in ["announced", "started", "ended"]:
			events.append([f.kind, float(f.time_s)])
	var names := []
	for e in events:
		names.append(e[0])
	var ok := false
	var detail := str(names.slice(0, 6))
	if always:
		ok = names.size() >= 2 and names.slice(0, 2) == ["announced", "started"] and not names.has("ended")
		detail = "always: %s" % str(names.slice(0, 3))
	elif names.size() >= 6 and names.slice(0, 6) == ["announced", "started", "ended", "announced", "started", "ended"]:
		var lead: float = events[1][1] - events[0][1]
		var live: float = events[2][1] - events[1][1]
		var gap: float = events[3][1] - events[2][1]
		ok = absf(lead - float(row.lead_s)) <= TOLERANCE and absf(live - float(row.live_s)) <= TOLERANCE \
			and absf(gap - float(row.gap_s)) <= TOLERANCE
		detail = "lead %.2f of %.1f, live %.2f of %.1f, gap %.2f of %.1f" % [lead, float(row.lead_s), live, float(row.live_s), gap, float(row.gap_s)]
	_check("%s timings hold" % row.id, ok, detail)


# The row's look, and the fog the hook writes at go-live and restores at end, from the director run.
func _look(row: Dictionary, run: Dictionary) -> void:
	var look := Weather.look(row)
	var sky: Dictionary = WorldLook.WEATHER_SKY.get(row.sky, {})
	var values_ok: bool = is_equal_approx(look.fog_density, float(row.fog.density)) \
		and look.fog_color == Color(String(row.fog.color)) and not sky.is_empty() and look.sky == row.sky \
		and look.sky_tint == sky.get("tint") and look.music_layer == row.music_layer \
		and look.sound == row.sound and not String(row.sound).is_empty()
	var always: bool = row.trigger.get("on") == "always"
	var landed := false
	var ends := 0
	var ends_ok := true
	for entry in run.trail:
		if entry[0] == "land":
			landed = landed or (entry[1] == true and is_equal_approx(float(entry[2]), float(row.fog.density))
				and entry[3] == Color(String(row.fog.color)))
		if entry[0] == "end":
			ends += 1
			ends_ok = ends_ok and entry[1] == false and is_equal_approx(float(entry[2]), FOG_BEFORE) and entry[3] == Color.WHITE
	var restored: bool = ends_ok and (ends == 0 if always else ends > 0)
	_check("%s fog applied at go-live and restored at end; sky, music and sound id from its row" % row.id,
		values_ok and landed and restored, "land %s, %d ends, fog %.4f" % [str(landed), ends, float(look.fog_density)])


# Ball motion, its physics material and the movement tuning match with weather on and off.
func _handling(row: Dictionary, on: Dictionary, off: Dictionary) -> void:
	var same: bool = off.trace == on.trace and off.velocity == on.velocity and off.position == on.position
	var ok: bool = same and not bool(on.changed) and bool(on.tuning_same) and row.handling == "none" and int(on.live_ticks) > 0
	_check("%s changes no handling over %d ticks" % [row.id, _ticks(row)], ok,
		"off %s on %s live %d changed %s" % [str(off.velocity), str(on.velocity), int(on.live_ticks), str(on.changed)])


# A planted friction change in the hook must be caught, or the handling checks cannot go red.
func _control(row: Dictionary) -> void:
	var run := _run(row, true, true)
	_check("planted friction change in the weather hook is caught", bool(run.changed), "changed %s" % str(run.changed))
