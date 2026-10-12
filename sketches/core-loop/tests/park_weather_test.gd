extends SceneTree

# Rule (KE7, K-UNITS.md KE7; PARK.md section 6 "Time of day" and veto items 2 and 8): each stage
# enters at its time of day, the six picks read dawn at the dam to dusk at the crown. Every weather
# row keeps its lead, live and gap timings, its fog, sky and sound come from the row and
# WorldLook.WEATHER_SKY, and no weather row changes ball handling: the movement tuning is the same
# and the ball's motion over 600 stepped ticks matches with weather on and off. The rows come from
# the six stage pages' park blocks; the check count is fixed below.
const Weather := preload("res://src/world/events/weather.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const BallState := preload("res://src/movement/ball_state.gd")

const PAGES := "res://design-v3/park/stages"
const PARK := "res://design-v3/PARK.md"
const TIME_ORDER := ["dawn", "morning", "noon", "afternoon", "golden", "dusk"]
const H := 0.05
const TICKS := 600
const TOLERANCE := 0.08
# 9 time checks, 1 row-count check, then 12 timing, 12 look and 12 handling checks.
const EXPECTED_CHECKS := 46

var _checks := 0
var _failures := 0


class Intent extends RefCounted:
	var brake_held := false


func _initialize() -> void:
	_time_rows()
	var weather := _weather_rows()
	_check("twelve weather rows across the six stage pages", weather.size() == 12, "%d rows" % weather.size())
	for row in weather:
		_timing(row)
	for row in weather:
		_look(row)
	for row in weather:
		_handling(row)
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
		for block in _json_blocks(text):
			var json := JSON.new()
			if json.parse(block) != OK:
				continue
			var parsed = json.data
			if parsed is Dictionary and parsed.has("schema"):
				rows.append_array(parsed.get("weather_rows", []))
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


# A cycling row announces, goes live after lead_s, ends after live_s, and is announced again after gap_s.
# An "always" row is live from its first tick and never cycles.
func _timing(row: Dictionary) -> void:
	var always: bool = row.trigger.get("on") == "always"
	var span := float(row.lead_s) + float(row.live_s) + float(row.gap_s)
	var ticks := TICKS if always else int(ceil(2.0 * span / H)) + 20
	var cycle := Weather.Cycle.new(row)
	var events := []
	var t := 0.0
	for i in ticks:
		t += H
		var e: String = cycle.step(H, true)
		if e != "":
			events.append([e, t])
	var names := []
	for e in events:
		names.append(e[0])
	var ok := false
	var detail := str(names.slice(0, 6))
	if always:
		ok = names == ["started"]
		detail = "always live: %s" % str(names)
	elif names.size() >= 6 and names.slice(0, 6) == ["announced", "started", "ended", "announced", "started", "ended"]:
		var lead: float = events[1][1] - events[0][1]
		var live: float = events[2][1] - events[1][1]
		var gap: float = events[3][1] - events[2][1]
		ok = absf(lead - float(row.lead_s)) <= TOLERANCE and absf(live - float(row.live_s)) <= TOLERANCE \
			and absf(gap - float(row.gap_s)) <= TOLERANCE
		detail = "lead %.2f of %.1f, live %.2f of %.1f, gap %.2f of %.1f" % [lead, float(row.lead_s), live, float(row.live_s), gap, float(row.gap_s)]
	_check("%s timings hold" % row.id, ok, detail)


func _look(row: Dictionary) -> void:
	var look := Weather.look(row)
	var sky: Dictionary = WorldLook.WEATHER_SKY.get(row.sky, {})
	var ok: bool = is_equal_approx(look.fog_density, float(row.fog.density)) \
		and look.fog_color == Color(String(row.fog.color)) \
		and not sky.is_empty() and look.sky == row.sky and look.sky_tint == sky.get("tint") \
		and look.sound == row.sound and look.music_layer == row.music_layer and not String(row.sound).is_empty()
	_check("%s fog, sky and sound come from its row" % row.id, ok,
		"fog %.4f sky %s sound %s" % [float(look.fog_density), row.sky, row.sound])


func _snapshot(tuning) -> Dictionary:
	var out := {}
	for spec in Tuning.SPECS:
		out[spec.key] = tuning.f(spec.key)
	return out


# Steps the ball's rolling resistance and drift for TICKS ticks. With weather on, the row's cycle
# runs and its fog is applied when it goes live; the ball's motion must not depend on either.
func _roll(tuning, row: Dictionary, weather: bool) -> Dictionary:
	var state := BallState.new()
	state.velocity = Vector3(12.0, 0.0, 4.0)
	state.grounded = true
	var intent := Intent.new()
	var env := Environment.new()
	var cycle = Weather.Cycle.new(row) if weather else null
	var pos := Vector3.ZERO
	var live_ticks := 0
	for i in TICKS:
		if weather:
			var e: String = cycle.step(H, true)
			if e == "started":
				Weather.apply(env, row)
		if weather and cycle.is_live():
			live_ticks += 1
		state.velocity += Rules.resistance(state, tuning, intent, H)
		pos += state.velocity * H
	return {"velocity": state.velocity, "position": pos, "live_ticks": live_ticks}


func _handling(row: Dictionary) -> void:
	var tuning = Tuning.new()
	var before := _snapshot(tuning)
	var off := _roll(tuning, row, false)
	var on := _roll(tuning, row, true)
	var same: bool = off.velocity == on.velocity and off.position == on.position
	var ok: bool = same and _snapshot(tuning) == before and row.handling == "none" and int(on.live_ticks) > 0
	_check("%s changes no handling over %d ticks" % [row.id, TICKS], ok,
		"off %s on %s live %d" % [str(off.velocity), str(on.velocity), int(on.live_ticks)])
