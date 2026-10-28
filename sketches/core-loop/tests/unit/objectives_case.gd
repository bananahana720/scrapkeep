extends RefCounted
# F6 2026-10-04: the lesson rows are gone; every Warden fights on posture.

const Objectives := preload("res://src/core/objectives.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const Hud := preload("res://src/ui/hud.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The objective table (design-v3/LEGIBILITY.md, "A goal exists") and its chooser, walked on
# bare readings with no scene: every row is reached by one reading, every row has a glyph
# and one to five words, a posture Warden never shows a lesson and a plating Warden never
# shows the posture rows; the yard lock and a shut clamp each hold their row. Then the struggle
# tally on fed gains and simulated seconds.

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
}


func run(t) -> void:
	_rows(t)
	_reached_once(t)
	_fights(t)
	_struggle(t)


func _rows(t) -> void:
	var bad := []
	for id in Objectives.ROWS:
		var n := WordBudget.words_in(Objectives.words(id))
		if n < 1 or n > Objectives.MAX_WORDS or Objectives.glyph(id) == "":
			bad.append(id)
	t.eq("every row has a glyph and one to five words", bad, [])
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
											var id := Objectives.choose({"state": state, "sealed": sealed, "fight": fight, "engaged": engaged,
												"staggered": staggered, "struggling": struggling, "lesson": lesson, "distance": distance,
												"activities_left": activities_left, "yard_locked": bool(locks & 1), "clamp_shut": bool(locks & 2)})
											reached[id] = true
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
