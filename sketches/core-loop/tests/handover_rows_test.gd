extends SceneTree

# Wave 36, ruling cv (one ride through a world): every hand-over between world 1 stages is a data row, and this test
# reads the rows and says whether the exit a player takes matches how they arrive. Data only: no scene boots.
#
# Rows: ParkMap.handover() for the dam and the flume (park_dam.json, park_flume.json: atlas, exit, arrives) and
# Arena.handover() for the Slag Bowl. Each stage's rows are in its own frame; the atlas puts them in one frame. Today the
# dam and the flume sit unmoved in it (origin 0, heading 0): the maps were never placed against each other, so that is
# the measure of what a player gets now. The bowl hangs above the flume's beacon (Arena.place), so its origin is that point.
#
# One line per seam and check: `HANDOVER <seam> <check> <value> pass <line> PASS|FAIL|OWED`.
#   kind     the exit kind and the arrival kind are a declared pair (ParkSchema.HANDOVER_PAIRS)
#   heading  angle between the exit heading and the arrival heading, atlas frame, at most HEADING_MAX_DEG
#   speed    arrival speed over exit speed, at least SPEED_MIN
#   ahead    angle between the exit heading and the line from the exit point to the arrival point, at most AHEAD_MAX_DEG
# This unit measures; wave 38 fixes the seams. A seam under a line today is listed in OWED with its measured value: it
# prints OWED and passes, the line stays here, and the test fails if an OWED line now meets it (prune it) or an unlisted
# line fails. Planted: a clean seam must pass all four, and each of four bent copies (arrival kind swapped, heading
# turned 90 degrees, speed halved, arrival placed behind the exit) must fail its own check and no other.
#
# The camp gate to dam seam is not read: the camp's gate lives in camp_layout.gd, outside the park file (follow-up).

const T := preload("res://tests/support/t.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const Arena := preload("res://src/boss/arena.gd")

const PARK_DIR := "res://src/world/park"
const HEADING_MAX_DEG := 30.0
const SPEED_MIN := 0.8
const AHEAD_MAX_DEG := 45.0
const CHECKS := ["kind", "heading", "speed", "ahead"]

# Seam under its line today: "<seam> <check>" -> {"value": measured, "why": text}. Measured on base 501b2821a.
const OWED := {
	"dam_to_flume heading": {"value": 31.0, "why": "the dam launch leaves at 0 degrees and the flume spawn faces 31"},
	"dam_to_flume ahead": {"value": 158.7, "why": "the maps are not placed against each other: the flume spawn lies behind the dam gate's heading"},
	"flume_to_bowl heading": {"value": 60.0, "why": "the flume gate faces 90 and the bowl's entry tangent faces 150"},
	"flume_to_bowl ahead": {"value": 169.0, "why": "the bowl hangs over the beacon and its entry sits 35 m behind and to the side of the gate"},
}

var t := T.new("handover_rows_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dam := ParkMap.new("%s/park_dam.json" % PARK_DIR)
	var flume := ParkMap.new("%s/park_flume.json" % PARK_DIR)
	var dam_rows := dam.handover()
	var flume_rows := flume.handover()
	var bowl_rows := Arena.handover()
	if not t.check("dam and flume declare a hand-over", not dam_rows.is_empty() and not flume_rows.is_empty(), "atlas, exit and arrives rows load through the schema"):
		quit(t.verdict())
		return
	t.check("one exit and one arrival per stage", dam_rows.has("exit") and dam_rows.has("arrives") and flume_rows.has("exit") and flume_rows.has("arrives") and bowl_rows.has("arrives"), "dam, flume, bowl")
	# The bowl's atlas origin: the flume's beacon, which Arena.place only pulls inward when the bowl would leave the map.
	var bowl_origin := to_atlas(flume.beacon, flume_rows["atlas"])
	var half := float(flume.park["size_m"]) * 0.5
	t.check("the bowl fits over the flume's beacon without being pulled inward", absf(flume.beacon.x) + Arena.BANK_R + Arena.WALL_THICK + 2.0 <= half and absf(flume.beacon.y) + Arena.BANK_R + Arena.WALL_THICK + 2.0 <= half, "beacon %s" % flume.beacon)
	var bowl_atlas := {"origin": bowl_origin, "heading_deg": float(bowl_rows["atlas"]["heading_deg"])}
	_seam("dam_to_flume", dam_rows["exit"], dam_rows["atlas"], flume_rows["arrives"], flume_rows["atlas"])
	_seam("flume_to_bowl", flume_rows["exit"], flume_rows["atlas"], bowl_rows["arrives"], bowl_atlas)
	_planted()
	quit(t.verdict())


# A local point into the atlas frame: turned by the atlas heading (yaw 0 faces +z, turning toward +x), then moved to its origin.
static func to_atlas(p: Vector2, atlas: Dictionary) -> Vector2:
	var a := deg_to_rad(float(atlas["heading_deg"]))
	return Vector2(atlas["origin"]) + Vector2(p.x * cos(a) + p.y * sin(a), -p.x * sin(a) + p.y * cos(a))


static func yaw_dir(yaw_deg: float) -> Vector2:
	return Vector2(sin(deg_to_rad(yaw_deg)), cos(deg_to_rad(yaw_deg)))


# The four readings of one seam, both rows turned into the atlas frame.
static func measure(exit_row: Dictionary, exit_atlas: Dictionary, arrive_row: Dictionary, arrive_atlas: Dictionary) -> Dictionary:
	var exit_at := to_atlas(exit_row["at"], exit_atlas)
	var arrive_at := to_atlas(arrive_row["at"], arrive_atlas)
	var exit_yaw := float(exit_row["heading_deg"]) + float(exit_atlas["heading_deg"])
	var arrive_yaw := float(arrive_row["heading_deg"]) + float(arrive_atlas["heading_deg"])
	var exit_dir := yaw_dir(exit_yaw)
	return {
		"kind": 1.0 if ParkSchema.HANDOVER_PAIRS.get(str(exit_row["kind"]), "") == str(arrive_row["kind"]) else 0.0,
		"heading": absf(rad_to_deg(exit_dir.angle_to(yaw_dir(arrive_yaw)))),
		"speed": float(arrive_row["speed_cruise"]) / float(exit_row["speed_cruise"]),
		"ahead": absf(rad_to_deg(exit_dir.angle_to(arrive_at - exit_at))),
	}


static func meets(check: String, value: float) -> bool:
	match check:
		"kind":
			return value >= 1.0
		"heading":
			return value <= HEADING_MAX_DEG
		"speed":
			return value >= SPEED_MIN
		"ahead":
			return value <= AHEAD_MAX_DEG
	return false


static func line_of(check: String) -> String:
	match check:
		"kind":
			return "pair"
		"heading":
			return "<=%.0f" % HEADING_MAX_DEG
		"speed":
			return ">=%.2f" % SPEED_MIN
	return "<=%.0f" % AHEAD_MAX_DEG


func _seam(seam: String, exit_row: Dictionary, exit_atlas: Dictionary, arrive_row: Dictionary, arrive_atlas: Dictionary) -> void:
	var m := measure(exit_row, exit_atlas, arrive_row, arrive_atlas)
	for check in CHECKS:
		var key := "%s %s" % [seam, check]
		var ok := meets(check, m[check])
		var owed := OWED.has(key)
		var status := "PASS" if ok else ("OWED" if owed else "FAIL")
		print("HANDOVER %s %s %.1f pass %s %s" % [seam, check, m[check], line_of(check), status])
		if owed:
			t.check("%s OWED still under its line (prune the entry when it meets it)" % key, not ok, "%.1f, expected about %.1f: %s" % [m[check], float(OWED[key]["value"]), OWED[key]["why"]])
			t.check("%s OWED reading is the one recorded" % key, absf(m[check] - float(OWED[key]["value"])) < 1.0, "%.1f vs %.1f" % [m[check], float(OWED[key]["value"])])
		else:
			t.check("%s meets its line %s" % [key, line_of(check)], ok, "%.1f" % m[check])


func _planted() -> void:
	var atlas := {"origin": Vector2.ZERO, "heading_deg": 0.0}
	var exit_row := {"kind": "launch", "at": Vector2(0.0, 0.0), "heading_deg": 0.0, "speed_cruise": 1.0}
	var clean := {"kind": "land", "at": Vector2(0.0, 100.0), "heading_deg": 0.0, "speed_cruise": 1.0}
	var base := measure(exit_row, atlas, clean, atlas)
	var all_pass := true
	for check in CHECKS:
		all_pass = all_pass and meets(check, base[check])
	t.check("control: a clean seam meets all four lines", all_pass, str(base))
	var bent := {
		"kind": {"kind": "slide"},
		"heading": {"heading_deg": 90.0},
		"speed": {"speed_cruise": 0.5},
		"ahead": {"at": Vector2(0.0, -100.0)},
	}
	for planted in bent:
		var row := clean.duplicate()
		row.merge(bent[planted], true)
		var m := measure(exit_row, atlas, row, atlas)
		var failed := []
		for check in CHECKS:
			if not meets(check, m[check]):
				failed.append(check)
		print("PLANTED %s failed %s" % [planted, str(failed)])
		t.check("planted: %s fails its own check and no other" % planted, failed == [planted], str(failed))
