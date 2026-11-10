extends RefCounted
# F6 2026-10-04: the lesson rows are gone; every Warden fights on posture.

const Objectives := preload("res://src/core/objectives.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const Hud := preload("res://src/ui/hud.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Activities := preload("res://src/world/activities.gd")
const WardenReactor := preload("res://src/combat/warden_reactor.gd")

# The objective table (design-v3/LEGIBILITY.md, "A goal exists") and its chooser, walked on
# bare readings with no scene: every row is reached by one reading, every row has a glyph
# and one to five words, a posture Warden never shows a lesson and a plating Warden never
# shows the posture rows; the yard lock and a shut clamp each hold their row; a mounted
# reactor changes only the guard row and Brindle's phases show only in the arena. Then the
# struggle tally on fed gains and simulated seconds.

const DT := 0.1

# The reading that reaches each row, and nothing else does.
const CASES := {
	"find_activity": {"state": "stage", "sealed": true, "engaged": false, "activities_left": 1, "fight": "posture"},
	"find_warden": {"state": "stage", "sealed": true, "fight": "posture", "engaged": false},
	"break_guard": {"state": "stage", "sealed": true, "fight": "posture", "engaged": true},
	"smash_core": {"state": "beacon", "sealed": true, "fight": "posture", "engaged": true, "staggered": true},
	"grow_return": {"state": "stage", "sealed": true, "fight": "posture", "engaged": true, "struggling": true},
	"break_warden": {"state": "stage", "sealed": true, "fight": "plating", "distance": 90.0},
	"charge_beacon": {"state": "stage", "sealed": false},
	"roll_gate": {"state": "gates"},
	"hold_line": {"state": "launch"},
	"break_brindle": {"state": "boss"},
	"break_yard_crew": {"state": "stage", "sealed": true, "yard_locked": true, "activities_left": 1, "fight": "posture"},
	"break_clamp_crews": {"state": "stage", "sealed": true, "fight": "posture", "engaged": true, "clamp_shut": true, "struggling": true},
	"ride_sheet": {"state": "stage", "sealed": true, "fight": "posture", "engaged": true, "mount": "dam_face"},
	"latch_warden": {"state": "stage", "sealed": true, "fight": "posture", "engaged": true, "mount": "flume"},
	"fire_from_line": {"state": "stage", "sealed": true, "fight": "posture", "engaged": true, "mount": "flume", "latched": true},
	"shoot_magnets": {"state": "boss", "phase": 1},
	"slam_caps": {"state": "boss", "phase": 2},
	"bait_charge": {"state": "boss", "phase": 3},
	"hit_cockpit": {"state": "boss", "phase": 3, "open": true},
	"ram_scooter": {"state": "boss", "phase": 4},
}

# The mounted reactor's road and Brindle's phase, each as one axis of the walk.
const MOUNTS := [{}, {"mount": "dam_face"}, {"mount": "flume"}, {"mount": "flume", "latched": true}, {"mount": "plain"}]
const PHASES := [{}, {"phase": 1}, {"phase": 2}, {"phase": 3}, {"phase": 1, "open": true}, {"phase": 3, "open": true}, {"phase": 4}, {"phase": 9}, {"open": true}]
const MOUNT_ROWS := ["ride_sheet", "latch_warden", "fire_from_line"]
const PHASE_ROWS := ["shoot_magnets", "slam_caps", "bait_charge", "hit_cockpit", "ram_scooter"]


# Stand-ins for what the reactor's mounting reads off a Warden: its spec, family and
# mounting, and through its target the ball's line.
class FakeKit extends RefCounted:
	var hooked := false
	var on_body := false
	var anchor_body = null


class FakeBall extends RefCounted:
	var kit := FakeKit.new()


class FakeWarden extends RefCounted:
	var spec := {"park_landmark": true}
	var family := "reactor"
	var mounting := ""
	var target = FakeBall.new()


func run(t) -> void:
	_rows(t)
	_site_pick(t)
	_reached_once(t)
	_fights(t)
	_mount_reading(t)
	_struggle(t)


# What the mounting hands the plate (WardenReactor.plate_reading): the dam and the flume by
# name, the flume's latch only while the line is bitten into this Warden, nothing for a
# reactor that is not a park landmark.
func _mount_reading(t) -> void:
	var driver = WardenReactor.new()
	var warden := FakeWarden.new()
	warden.mounting = "dam_face"
	t.eq("the dam's mounting names the dam", driver.plate_reading(warden), {"mount": "dam_face"})
	warden.mounting = "flume"
	t.eq("the flume's mounting names the flume, line off", driver.plate_reading(warden), {"mount": "flume", "latched": false})
	warden.target.kit.hooked = true
	warden.target.kit.on_body = true
	warden.target.kit.anchor_body = FakeWarden.new()
	t.eq("a line on another body is not a latch", driver.plate_reading(warden)["latched"], false)
	warden.target.kit.anchor_body = warden
	t.eq("the line bitten into the flume Warden is the latch", driver.plate_reading(warden), {"mount": "flume", "latched": true})
	t.eq("and the plate then says to fire", Objectives.choose(CASES["latch_warden"].merged(driver.plate_reading(warden), true)), "fire_from_line")
	warden.spec = {}
	t.eq("a reactor off the park landmark keeps the guard row", driver.plate_reading(warden), {})
	warden.spec = {"park_landmark": true}
	warden.mounting = "head_house"
	t.eq("another mounting keeps the guard row", driver.plate_reading(warden), {})


# The activity row names the site ahead, and keeps it until another clearly wins.
func _site_pick(t) -> void:
	var north := Vector3(0, 0, 1)
	t.eq("no site, no pick", Objectives.pick_site([], north), -1)
	t.eq("one site is the pick wherever it lies", Objectives.pick_site([Vector3(0, 0, -50)], north), 0)
	t.eq("straight ahead scores its distance", Objectives.site_score(Vector3(0, 0, 100), north), 100.0)
	t.eq("abeam scores double", Objectives.site_score(Vector3(100, 0, 0), north), 200.0)
	t.eq("behind scores triple", Objectives.site_score(Vector3(0, 0, -100), north), 300.0)
	t.eq("height counts in the distance, not the angle", Objectives.site_score(Vector3(0, 30, 40), north), 50.0)
	t.eq("a site on the ball scores its distance", Objectives.site_score(Vector3(0, 2, 0), north), 2.0)
	t.eq("ahead beats a little nearer but off the view", Objectives.pick_site([Vector3(110, 0, 280), Vector3(0, 0, 310)], north), 1)
	t.eq("much nearer wins even from behind", Objectives.pick_site([Vector3(0, 0, -60), Vector3(0, 0, 310)], north), 0)
	t.eq("the held site stays while the other is not clearly better", Objectives.pick_site([Vector3(0, 0, 100), Vector3(0, 0, 90)], north, 0), 0)
	t.eq("the held site gives way under SITE_KEEP of its score", Objectives.pick_site([Vector3(0, 0, 100), Vector3(0, 0, 79)], north, 0), 1)
	t.eq("a held index that has gone is no hold", Objectives.pick_site([Vector3(0, 0, 100), Vector3(0, 0, 90)], north, 5), 1)
	# The dam as authored (park_dam.json): the drop faces the camp, and the relay beside it is 5 m nearer.
	var dam: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/park_dam.json"))
	var at := Vector3(dam["spawn"]["at"][0], 0.0, dam["spawn"]["at"][1])
	var heading := deg_to_rad(float(dam["spawn"]["heading_deg"]))
	var kinds := []
	var offsets := []
	for row in dam["activity_rows"]:
		kinds.append(String(row["activity"]))
		offsets.append(Vector3(row["at"][0], 0.0, row["at"][1]) - at)
	var picked := Objectives.pick_site(offsets, Vector3(sin(heading), 0.0, cos(heading)))
	t.eq("the dam's drop names the camp it faces", kinds[picked] if picked >= 0 else "", "enemy_camp")
	var plain := 0
	for i in offsets.size():
		if offsets[i].length() < offsets[plain].length():
			plain = i
	t.eq("the nearest site at the dam's drop is the relay, which is why the view decides", kinds[plain], "hold_the_relay")
	_way(t)


# The heading the row reads is the view until the ball has travelled, then where the ball is going:
# a look round changes nothing once it rolls.
func _way(t) -> void:
	var north := Vector3(0, 0, 1)
	var east := Vector3(1, 0, 0)
	var way := Objectives.Way.new()
	t.eq("before the ball has travelled, ahead is the view", [way.ahead(north), way.ahead(east)], [north, east])
	way.step(east * (Objectives.Way.SPEED - 0.5), 1.0)
	t.eq("a ball slower than SPEED sets no way", way.ahead(north), north)
	way.step(east * 20.0 + Vector3.UP * 30.0, 1.0 / 90.0)
	t.eq("the first travel sets the way at once, flat", way.ahead(north), east)
	t.eq("and the view no longer moves it", [way.ahead(north), way.ahead(-east), way.ahead(-north)], [east, east, east])
	way.step(Vector3.ZERO, 5.0)
	t.eq("a stopped ball keeps its way", way.ahead(north), east)
	way.step(north * 20.0, 1.0 / 90.0)
	t.check("one tick of a new heading barely turns it (a bounce)", way.ahead(north).dot(east) > 0.99, str(way.ahead(north)))
	for i in 270:
		way.step(north * 20.0, 1.0 / 90.0)
	t.check("three seconds on the new heading turns it there", way.ahead(east).dot(north) > 0.99, str(way.ahead(east)))
	for i in 270:
		way.step(-north * 20.0, 1.0 / 90.0)
	t.check("a full reversal turns it round, never to nothing", way.ahead(east).dot(-north) > 0.99 and is_equal_approx(way.ahead(east).length(), 1.0), str(way.ahead(east)))
	way.begin()
	t.eq("begin() hands ahead back to the view", way.ahead(north), north)
	# Two sites either side of the road: by the view a look round trades the row; by the way it holds.
	var offsets := [Vector3(0, 0, 300), Vector3(0, 0, -250)]
	t.eq("by the view, turning round moves the row to the site behind", [Objectives.pick_site(offsets, north, -1), Objectives.pick_site(offsets, -north, 0)], [0, 1])
	way.step(north * 20.0, 1.0 / 90.0)
	t.eq("by the way, it stays on the site the ball is heading for", [Objectives.pick_site(offsets, way.ahead(north), -1), Objectives.pick_site(offsets, way.ahead(-north), 0)], [0, 0])


func _rows(t) -> void:
	var bad := []
	for id in Objectives.ROWS:
		var n := WordBudget.words_in(Objectives.words(id))
		if n < 1 or n > Objectives.MAX_WORDS or Objectives.glyph(id) == "":
			bad.append(id)
	t.eq("every row has a glyph and one to five words", bad, [])
	var long_sites := []
	for kind in EventKinds.ACTIVITY_ROWS:
		var n := WordBudget.words_in(Objectives.activity_words(kind))
		if not Objectives.ACTIVITY_WORDS.has(kind) or n < 1 or n > Objectives.MAX_WORDS:
			long_sites.append(kind)
	t.eq("every activity kind names its site in one to five words", long_sites, [])
	t.eq("every named site is a site kind", Objectives.ACTIVITY_WORDS.keys().filter(func(kind): return not Activities.RULES.has(kind)), [])
	t.eq("every named site keeps to five words", Objectives.ACTIVITY_WORDS.keys().filter(func(kind):
		return WordBudget.words_in(Objectives.ACTIVITY_WORDS[kind]) > Objectives.MAX_WORDS), [])
	t.eq("a kind with no words of its own keeps the row's", Objectives.activity_words("no_such_kind"), Objectives.words("find_activity"))
	# Trade spots go by their ruled names (ruling ci); a drawn pocket by what its marker calls it.
	t.eq("the risky trade spots are the keeper's gamble", ["trade_risk", "curse", "sacrifice"].map(func(kind): return Objectives.activity_words(kind)).filter(func(w): return w != "Find the keeper's gamble"), [])
	t.eq("the safe trade spot is the foreman's kindness", Objectives.activity_words("trade_safe"), "Find the foreman's kindness")
	t.eq("a drawn pocket is named by its marker's word", Objectives.activity_words("arena", Activities.called("arena")), "Find the arena")
	var unnamed := []
	for kind in Activities.RULES:
		var words := Objectives.activity_words(kind, Activities.called(kind))
		if words == Objectives.words("find_activity") or WordBudget.words_in(words) > Objectives.MAX_WORDS:
			unnamed.append(kind)
	t.eq("every site kind the plate can meet has a name in five words", unnamed, [])
	t.eq("the chooser has a case for every row", CASES.keys().size(), Objectives.ROWS.size())
	var lessons := []
	for stage in StageDefs.COUNT:
		var row: Dictionary = StageDefs.of(stage + 1)
		lessons.append(not row.has("warden_fight") and row.get("warden_lesson", "") == "")
	t.eq("no stage row picks a fight or a lesson", lessons.all(func(ok): return ok), true)
	t.eq("the HUD colours every row from an event row that exists", Objectives.ROWS.keys().filter(func(id): return not Hud.ROW_COLOR.has(id) or EventKinds.row(Hud.ROW_COLOR[id]).is_empty()), [])
	t.eq("the HUD rings only rows the table has", Hud.RING_ROWS.filter(func(id): return not Objectives.ROWS.has(id)), [])


func _reached_once(t) -> void:
	for id in CASES:
		t.eq("reading reaches " + id, Objectives.choose(CASES[id]), id)
	var reached := {}
	for state in ["", "stage", "beacon", "gates", "launch", "boss"]:
		for sealed in [false, true]:
			for fight in ["plating", "posture"]:
				for engaged in [false, true]:
					for staggered in [false, true]:
						for struggling in [false, true]:
							for lesson in [""]:
								for distance in [5.0, 39.9, 40.0, 200.0]:
									for activities_left in [0, 1]:
										for locks in 4:
											for extra in MOUNTS + PHASES:
												var reading := {"state": state, "sealed": sealed, "fight": fight, "engaged": engaged,
													"staggered": staggered, "struggling": struggling, "lesson": lesson, "distance": distance,
													"activities_left": activities_left, "yard_locked": bool(locks & 1), "clamp_shut": bool(locks & 2)}
												reading.merge(extra, true)
												reached[Objectives.choose(reading)] = true
	var missing := Objectives.ROWS.keys().filter(func(id): return not reached.has(id))
	var stray := reached.keys().filter(func(id): return id != "" and not Objectives.ROWS.has(id))
	t.eq("the walk reaches every row", missing, [])
	t.eq("the walk reaches no row the table lacks", stray, [])
	t.eq("the stage card holds the launch row back", Objectives.choose({"state": "launch", "card": true}), "")
	t.eq("a menu state shows no row", Objectives.choose({"state": "dead"}), "")


func _fights(t) -> void:
	var lesson_on_posture := []
	var posture_on_plating := []
	for sealed in [true]:
		for engaged in [false, true]:
			for staggered in [false, true]:
				for struggling in [false, true]:
					for lesson in [""]:
						for distance in [5.0, 200.0]:
							var posture := Objectives.choose({"state": "stage", "sealed": sealed, "fight": "posture", "engaged": engaged,
								"staggered": staggered, "struggling": struggling, "lesson": lesson, "distance": distance})
							if posture.begins_with("lesson") or posture == "break_warden":
								lesson_on_posture.append(posture)
							var plating := Objectives.choose({"state": "stage", "sealed": sealed, "fight": "plating", "engaged": engaged,
								"staggered": staggered, "struggling": struggling, "lesson": lesson, "distance": distance})
							if plating in ["break_guard", "smash_core", "find_warden", "grow_return"]:
								posture_on_plating.append(plating)
	t.eq("a posture Warden never shows a lesson row", lesson_on_posture, [])
	t.eq("a plating Warden never shows a posture row", posture_on_plating, [])
	t.eq("a stagger beats the struggle", Objectives.choose(CASES["smash_core"].merged({"struggling": true}, true)), "smash_core")
	t.eq("the yard lock holds the plate over the beacon and the activities",
		[Objectives.choose(CASES["charge_beacon"].merged({"yard_locked": true}, true)), Objectives.choose(CASES["find_activity"].merged({"yard_locked": true}, true))],
		["break_yard_crew", "break_yard_crew"])
	t.eq("a shut clamp leaves a plating Warden's row alone", Objectives.choose(CASES["break_warden"].merged({"clamp_shut": true, "engaged": true}, true)), "break_warden")
	t.eq("a shut clamp never shows before the Warden is found", Objectives.choose(CASES["find_warden"].merged({"clamp_shut": true}, true)), "find_warden")
	t.eq("the yard lock outside a stage shows nothing of it", Objectives.choose({"state": "gates", "yard_locked": true}), "roll_gate")
	_mounts(t)
	_phases(t)


# A mounted reactor names its own road only where "Break its guard" would stand: engaged, on
# posture, the clamp open, no stagger and no struggle. Everything else keeps its row.
func _mounts(t) -> void:
	var changed := []
	for mount in MOUNTS:
		for state in ["stage", "beacon", "gates", "launch", "boss"]:
			for mask in 256:
				var reading := {"state": state, "sealed": bool(mask & 1), "fight": "posture" if mask & 2 else "plating",
					"engaged": bool(mask & 4), "staggered": bool(mask & 8), "struggling": bool(mask & 16),
					"activities_left": 1 if mask & 32 else 0, "yard_locked": bool(mask & 64), "clamp_shut": bool(mask & 128)}
				var plain := Objectives.choose(reading)
				var mounted := Objectives.choose(reading.merged(mount, true))
				if mounted != plain and not (plain == "break_guard" and mounted in MOUNT_ROWS):
					changed.append([mount, reading, plain, mounted])
	t.eq("a mounting changes only the guard row", changed, [])
	t.eq("an unknown mounting keeps the guard row", Objectives.choose(CASES["break_guard"].merged({"mount": "plain"}, true)), "break_guard")
	t.eq("the dam's struggle still says to grow", Objectives.choose(CASES["ride_sheet"].merged({"struggling": true}, true)), "grow_return")
	t.eq("the flume's stagger still says to smash", Objectives.choose(CASES["fire_from_line"].merged({"staggered": true}, true)), "smash_core")
	t.eq("a shut clamp holds the plate over the dam's road", Objectives.choose(CASES["ride_sheet"].merged({"clamp_shut": true}, true)), "break_clamp_crews")
	t.eq("an activity still stands before an unengaged dam Warden", Objectives.choose(CASES["find_activity"].merged({"mount": "dam_face"}, true)), "find_activity")


# Brindle's phase rows stand only in the arena, and a fight that names no phase keeps the standing row.
func _phases(t) -> void:
	var outside := []
	for phase in PHASES:
		for state in ["stage", "beacon", "gates", "launch"]:
			for engaged in [false, true]:
				var id := Objectives.choose({"state": state, "sealed": true, "fight": "posture", "engaged": engaged}.merged(phase, true))
				if id in PHASE_ROWS:
					outside.append([state, phase, id])
	t.eq("a phase row never shows outside the arena", outside, [])
	t.eq("an arena with no phase keeps the standing row", [Objectives.choose({"state": "boss", "phase": 0}), Objectives.choose({"state": "boss", "phase": 9})],
		["break_brindle", "break_brindle"])
	t.eq("an open cockpit takes the plate in every fight phase",
		[1, 2, 3].map(func(phase): return Objectives.choose({"state": "boss", "phase": phase, "open": true})), ["hit_cockpit", "hit_cockpit", "hit_cockpit"])
	t.eq("the scooter and a fight with no phase have no cockpit row",
		[Objectives.choose(CASES["ram_scooter"].merged({"open": true}, true)), Objectives.choose({"state": "boss", "open": true})], ["ram_scooter", "break_brindle"])


# One gain every `gap` seconds for `seconds`, in DT steps: posture drains to 10 between gains
# and climbs 8 on each, so it never nears 50.
func _feed(tally, seconds: float, gap := 1.0) -> void:
	var elapsed := 0.0
	var until_gain := 0.0
	while elapsed < seconds:
		if until_gain <= 0.0:
			tally.note_posture(10.0, false)
			tally.note_posture(18.0, false)
			until_gain = gap
		tally.step(DT)
		until_gain -= DT
		elapsed += DT


func _struggle(t) -> void:
	var tally := Objectives.Struggle.new()
	_feed(tally, 9.5)
	t.eq("9.5 s of gains that never reach 50 is not yet struggling", tally.struggling, false)
	_feed(tally, 1.0)
	t.eq("10 s of gains that never reach 50 is struggling", tally.struggling, true)

	tally = Objectives.Struggle.new()
	_feed(tally, 8.5)
	tally.note_posture(52.0, false)
	_feed(tally, 6.0)
	t.eq("posture reaching 50 at second 9 never struggles", tally.struggling, false)

	tally = Objectives.Struggle.new()
	_feed(tally, 120.0, 4.0)
	t.eq("gains with 4 s gaps never count up", [tally.struggling, tally.tally <= Objectives.Struggle.GAIN_WINDOW + DT], [false, true])

	tally = Objectives.Struggle.new()
	_feed(tally, 12.0)
	tally.note_posture(0.0, true)
	t.eq("a stagger clears it", tally.struggling, false)
	_feed(tally, 12.0)
	t.eq("and it stays clear for the engagement", tally.struggling, false)
	tally.begin()
	_feed(tally, 10.5)
	t.eq("a new engagement counts again", tally.struggling, true)

	tally = Objectives.Struggle.new()
	var posture := 0.0
	var struggled := false
	for second in 60:
		posture += BossPosture.BASE["ram"]
		tally.note_posture(posture, posture >= 100.0)
		for i in 10:
			tally.step(DT)
		struggled = struggled or tally.struggling
		if posture >= 100.0:
			posture = 0.0
	t.eq("a matched build (30 a hit, a hit a second) never sees it", struggled, false)

	tally = Objectives.Struggle.new()
	_feed(tally, 12.0)
	t.eq("a build that has been struggling reads it", tally.struggling, true)
	for i in 100:
		tally.step(DT)
	tally.note_posture(30.0, false)
	t.eq("a gain after leaving for 10 s clears the struggle and the tally", [tally.struggling, tally.tally], [false, 0.0])
	_feed(tally, 6.0)
	t.eq("and it counts afresh from the return", tally.struggling, false)

	tally = Objectives.Struggle.new()
	for i in 200:
		tally.step(DT)
	t.eq("seconds with no gain at all never count", [tally.struggling, tally.tally], [false, 0.0])
	tally.begin()
	t.eq("a retry clears a standing struggle", tally.struggling, false)
