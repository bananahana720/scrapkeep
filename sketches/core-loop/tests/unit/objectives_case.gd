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
# reactor changes only the guard row (and the flume the stagger's too) and Brindle's phases show
# only in the arena. A side site takes the row only while the ball is at it; the done row; the
# marks' tags. Then the struggle tally on fed gains and simulated seconds.

const DT := 0.1

# The reading that reaches each row, and nothing else does.
const CASES := {
	"find_activity": {"state": "stage", "sealed": true, "engaged": false, "site_at_hand": true, "fight": "posture"},
	"find_warden": {"state": "stage", "sealed": true, "fight": "posture", "engaged": false},
	"break_guard": {"state": "stage", "sealed": true, "fight": "posture", "engaged": true},
	"smash_core": {"state": "beacon", "sealed": true, "fight": "posture", "engaged": true, "staggered": true},
	"grow_return": {"state": "stage", "sealed": true, "fight": "posture", "engaged": true, "struggling": true},
	"break_warden": {"state": "stage", "sealed": true, "fight": "plating", "distance": 90.0},
	"charge_beacon": {"state": "stage", "sealed": false},
	"roll_gate": {"state": "gates"},
	"hold_line": {"state": "launch"},
	"break_brindle": {"state": "boss"},
	"break_yard_crew": {"state": "stage", "sealed": true, "yard_locked": true, "site_at_hand": true, "fight": "posture"},
	"break_clamp_crews": {"state": "stage", "sealed": true, "fight": "posture", "engaged": true, "clamp_shut": true, "struggling": true},
	"ride_sheet": {"state": "stage", "sealed": true, "fight": "posture", "engaged": true, "mount": "dam_face"},
	"line_fight": {"state": "stage", "sealed": true, "fight": "posture", "engaged": true, "mount": "flume"},
	"shoot_magnets": {"state": "boss", "phase": 1},
	"slam_caps": {"state": "boss", "phase": 2},
	"bait_charge": {"state": "boss", "phase": 3},
	"ram_scooter": {"state": "boss", "phase": 4},
}

# The mounted reactor's road and Brindle's phase, each as one axis of the walk.
const MOUNTS := [{}, {"mount": "dam_face"}, {"mount": "flume"}, {"mount": "plain"}]
const PHASES := [{}, {"phase": 1}, {"phase": 2}, {"phase": 3}, {"phase": 1, "open": true}, {"phase": 3, "open": true}, {"phase": 4}, {"phase": 9}, {"open": true}]
const MOUNT_ROWS := ["ride_sheet", "line_fight"]
const PHASE_ROWS := ["shoot_magnets", "slam_caps", "bait_charge", "ram_scooter"]


# Stand-ins for what the reactor's mounting reads off a Warden: its spec, family and
# mounting, where it hangs, whether it is staggered, and through its target the ball's line.
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
	var home := Vector3(10.0, 4.0, -20.0)
	var global_position := Vector3(10.0, 16.0, -20.0)
	var terrain = null
	var open := false

	func staggered() -> bool:
		return open


func run(t) -> void:
	_rows(t)
	_done(t)
	_reached_once(t)
	_fights(t)
	_mount_reading(t)
	_struggle(t)
	_detour(t)


# What the mounting hands the plate (WardenReactor.plate_reading): the dam and the flume by
# name, nothing for a reactor that is not a park landmark. And what it hands the markers
# (plate_targets): on the flume the relic, by the step of the line fight that is next; on the dam
# the water sheet's foot once the first pulse has set its heading, running or coming.
func _mount_reading(t) -> void:
	var driver = WardenReactor.new()
	var warden := FakeWarden.new()
	warden.mounting = "dam_face"
	t.eq("the dam's mounting names the dam", driver.plate_reading(warden), {"mount": "dam_face"})
	t.eq("before the first pulse the sheet has no place to mark", driver.plate_targets(warden), [])
	driver.sheet_dir = Vector3(0.0, 0.0, 1.0)
	var foot := warden.home + Vector3(0.0, 0.0, WardenReactor.SHEET_RUN)
	t.eq("between pulses the foot is where the water is coming", driver.plate_targets(warden), [{"at": foot, "what": "sheet_soon"}])
	driver.sheet_left = WardenReactor.SHEET_SECONDS
	t.eq("while the sheet runs the foot is where to ride", driver.plate_targets(warden), [{"at": foot, "what": "sheet"}])
	driver = WardenReactor.new()
	warden.mounting = "flume"
	t.eq("the flume's mounting names the flume", driver.plate_reading(warden), {"mount": "flume"})
	t.eq("line off: the relic is the thing to latch", driver.plate_targets(warden), [{"at": warden.global_position, "what": "latch"}])
	warden.target.kit.hooked = true
	warden.target.kit.on_body = true
	warden.target.kit.anchor_body = FakeWarden.new()
	t.eq("a line on another body is not a latch", driver.plate_targets(warden)[0]["what"], "latch")
	warden.target.kit.anchor_body = warden
	t.eq("the line bitten into the flume Warden: shoot", driver.plate_targets(warden)[0]["what"], "shoot")
	warden.open = true
	t.eq("staggered: the core, line on or off", driver.plate_targets(warden)[0]["what"], "core")
	warden.open = false
	warden.spec = {}
	t.eq("a reactor off the park landmark keeps the guard row", [driver.plate_reading(warden), driver.plate_targets(warden)], [{}, []])
	warden.spec = {"park_landmark": true}
	warden.mounting = "head_house"
	t.eq("another mounting keeps the guard row", [driver.plate_reading(warden), driver.plate_targets(warden)], [{}, []])


# The done row (Objectives.Done): up for SECONDS of stepped time from the first step after the
# note, gone at once when the goal under it changes again, and never up for an empty note.
func _done(t) -> void:
	var done := Objectives.Done.new()
	t.eq("nothing finished, nothing shown", done.showing(), false)
	done.note("Camp cleared")
	t.eq("a finished goal shows at once, as won", [done.showing(), done.words, done.won], [true, "Camp cleared", true])
	var steps := 0
	while done.showing() and steps < 1000:
		done.step(DT, "Find the Warden")
		steps += 1
	t.near("it stays up for SECONDS under one goal", steps * DT, Objectives.Done.SECONDS, DT + 0.001)
	done.note("Yard open")
	done.step(DT, "Find the Warden")
	done.step(DT, "Find the Warden")
	t.eq("still up while the goal under it holds", done.showing(), true)
	done.step(DT, "Break the clamp crews")
	t.eq("the goal under it changes again: it gives way at once", done.showing(), false)
	done.note("Relay lost", false)
	t.eq("a lost goal shows as lost", [done.showing(), done.won], [true, false])
	done.clear()
	t.eq("clear() takes it down", done.showing(), false)
	done.note("")
	t.eq("an empty note shows nothing", done.showing(), false)
	done.note("Camp cleared")
	done.note("Clamp open", true, true)
	t.eq("a note that yields leaves the one showing", done.words, "Camp cleared")
	done.clear()
	done.note("Clamp open", true, true)
	t.eq("and shows on a plate with no tick on it", [done.showing(), done.words], [true, "Clamp open"])


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
	t.eq("the risky trade spots are the keeper's gamble", ["trade_risk", "curse", "sacrifice"].map(func(kind): return Objectives.activity_words(kind)).filter(func(w): return w != "The keeper's gamble"), [])
	t.eq("the safe trade spot is the foreman's kindness", Objectives.activity_words("trade_safe"), "The foreman's kindness")
	t.eq("a drawn pocket is named by its marker's word", Objectives.activity_words("arena", Activities.called("arena")), "Arena")
	# The done row: every site kind has its own finished words, and every kind the plate can meet has some.
	t.eq("every named site has its done words", Objectives.ACTIVITY_WORDS.keys().filter(func(kind): return not Objectives.DONE_WORDS.has(kind)), [])
	t.eq("every done and lost row keeps to five words", (Objectives.DONE_WORDS.values() + Objectives.LOST_WORDS.values()).filter(func(w):
		return WordBudget.words_in(w) < 1 or WordBudget.words_in(w) > Objectives.MAX_WORDS), [])
	t.eq("every site kind's done row keeps to five words", Activities.RULES.keys().filter(func(kind):
		return WordBudget.words_in(Objectives.done_words(kind, Activities.called(kind))) > Objectives.MAX_WORDS), [])
	t.eq("a drawn pocket's done row is its marker's word, done", Objectives.done_words("arena", Activities.called("arena")), "Arena done")
	# A site is lost by a loss that re-arms it (`retry_s`) or by a forfeit clock (`out_s`, the Stocktake yard).
	t.eq("only a site that can be lost has lost words", Objectives.LOST_WORDS.keys().filter(func(kind):
		return not (Activities.RULES[kind].has("retry_s") or Activities.RULES[kind].has("out_s"))), [])
	t.eq("a kind that cannot be lost has none", Objectives.lost_words("enemy_camp"), "")
	# A mark's tag is one or two words in capitals, and names every thing a fight can mark.
	t.eq("every tag is one or two words in capitals", Objectives.TAGS.values().filter(func(w):
		return WordBudget.words_in(w) < 1 or WordBudget.words_in(w) > 2 or w != w.to_upper()), [])
	t.eq("a thing with no tag wears none", Objectives.tag("no_such_thing"), "")
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
									for site_at_hand in [false, true]:
										for locks in 4:
											for extra in MOUNTS + PHASES:
												var reading := {"state": state, "sealed": sealed, "fight": fight, "engaged": engaged,
													"staggered": staggered, "struggling": struggling, "lesson": lesson, "distance": distance,
													"site_at_hand": site_at_hand, "yard_locked": bool(locks & 1), "clamp_shut": bool(locks & 2)}
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
# posture, the clamp open, no stagger and no struggle. The flume's line fight also keeps its row
# through a stagger (the mark on the relic says the core is open). Everything else keeps its row.
func _mounts(t) -> void:
	var changed := []
	for mount in MOUNTS:
		for state in ["stage", "beacon", "gates", "launch", "boss"]:
			for mask in 256:
				var reading := {"state": state, "sealed": bool(mask & 1), "fight": "posture" if mask & 2 else "plating",
					"engaged": bool(mask & 4), "staggered": bool(mask & 8), "struggling": bool(mask & 16),
					"site_at_hand": bool(mask & 32), "yard_locked": bool(mask & 64), "clamp_shut": bool(mask & 128)}
				var plain := Objectives.choose(reading)
				var mounted := Objectives.choose(reading.merged(mount, true))
				var flume_stagger: bool = plain == "smash_core" and mounted == "line_fight" and mount.get("mount", "") == "flume"
				if mounted != plain and not (plain == "break_guard" and mounted in MOUNT_ROWS) and not flume_stagger:
					changed.append([mount, reading, plain, mounted])
	t.eq("a mounting changes only the guard row, and the flume the stagger's", changed, [])
	t.eq("an unknown mounting keeps the guard row", Objectives.choose(CASES["break_guard"].merged({"mount": "plain"}, true)), "break_guard")
	t.eq("the dam's struggle still says to grow", Objectives.choose(CASES["ride_sheet"].merged({"struggling": true}, true)), "grow_return")
	t.eq("the dam's stagger still says to smash", Objectives.choose(CASES["ride_sheet"].merged({"staggered": true}, true)), "smash_core")
	t.eq("the flume's stagger keeps the line fight's row", Objectives.choose(CASES["line_fight"].merged({"staggered": true}, true)), "line_fight")
	t.eq("the flume's struggle still says to grow", Objectives.choose(CASES["line_fight"].merged({"struggling": true}, true)), "grow_return")
	t.eq("and a stagger beats the struggle there too", Objectives.choose(CASES["line_fight"].merged({"struggling": true, "staggered": true}, true)), "line_fight")
	t.eq("a shut clamp holds the plate over the dam's road", Objectives.choose(CASES["ride_sheet"].merged({"clamp_shut": true}, true)), "break_clamp_crews")
	t.eq("a site at hand still stands before an unengaged dam Warden", Objectives.choose(CASES["find_activity"].merged({"mount": "dam_face"}, true)), "find_activity")
	t.eq("with no site at hand the Warden is the goal from the drop", Objectives.choose(CASES["find_activity"].merged({"site_at_hand": false}, true)), "find_warden")
	t.eq("a site at hand never takes the row from a fight", Objectives.choose(CASES["break_guard"].merged({"site_at_hand": true}, true)), "break_guard")


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
	t.eq("an open cockpit never takes the row: every phase holds its loop's row",
		[1, 2, 3].map(func(phase): return Objectives.choose({"state": "boss", "phase": phase, "open": true})), ["shoot_magnets", "slam_caps", "bait_charge"])
	# A loop row has a step for each part of its words, and the live one is the one the fight asks for.
	var uneven := []
	for id in Objectives.STEPS:
		if Objectives.words(id).split(", ").size() != Objectives.STEPS[id].size():
			uneven.append(id)
	t.eq("every loop row has one step for each part of its words", uneven, [])
	t.eq("the live step is the one the fight asks for, and the first when it asks for nothing",
		[Objectives.live_step("line_fight", "latch"), Objectives.live_step("line_fight", "shoot"), Objectives.live_step("line_fight", "core"),
			Objectives.live_step("slam_caps", "cockpit"), Objectives.live_step("bait_charge", ""), Objectives.live_step("ride_sheet", "sheet")],
		[0, 1, 2, 1, 0, 0])
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


# The detour row (Objectives.detour_shown): it stands under "Find the Warden" and nothing else, so
# it is up on the road from the drop and gone once the Warden is engaged, a lock holds or a side
# site has the row. The cage's row is its own prompt, capitalised, within the plate's word cap.
func _detour(t) -> void:
	var under := []
	for id in CASES:
		if Objectives.detour_shown(Objectives.choose(CASES[id])):
			under.append(id)
	t.eq("the detour row stands only under the road to the Warden", under, ["find_warden"])
	var road: Dictionary = CASES["find_warden"]
	for key in ["engaged", "yard_locked", "site_at_hand"]:
		var reading := road.duplicate()
		reading[key] = true
		t.eq("the detour row goes once %s" % key, Objectives.detour_shown(Objectives.choose(reading)), false)
	t.eq("the cage's row is its prompt, capitalised", Objectives.cage_words("free the runner"), "Free the runner")
	t.eq("a cage with no prompt is the caged pilot", Objectives.cage_words(""), Objectives.CAGE_WORDS)
	t.eq("a prompt over the word cap falls back", Objectives.cage_words("free the one runner in the cage"), Objectives.CAGE_WORDS)
	t.eq("the fallback fits the plate", Objectives.CAGE_WORDS.split(" ").size() <= Objectives.MAX_WORDS, true)
