extends "res://tests/park_natural_test.gd"

const Bank := preload("res://src/presentation/sfx_bank.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const LIVE_KEY := 3


func _run() -> void:
	t = T.new("park_natural_cue_test")
	var cases := []
	for k in KINDS.size():
		cases.append(_row(KINDS[k], FORMS[k]))
	for family in [["fleet", "fleet_landing", "fleet_inbound"], ["ancient", "machine_eruption", "ancient_stirring"], ["industrial", "boiler_burst", "boiler_pressure"]]:
		var row := _row(family[1], family[2])
		row.family = family[0]
		cases.append(row)
	for row in cases:
		var kind: String = row.kind
		var fixture := _fixture(row, true)
		var w = fixture[0]
		var handler = fixture[1]
		var audio = w.presentation.audio
		audio.engine.key = LIVE_KEY
		audio.cue_log.clear()
		var phases := []
		for i in 93:
			for fact in w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1, "grounded": true}):
				if fact.kind != "world":
					continue
				audio._last_start.clear()
				w.ctx.events.world_fact.emit(fact.fact, fact.at)
				phases.append(fact)
		t.eq(kind + " both cue phases", phases.size(), 2)
		var cues: Array = audio.cue_log.filter(func(c): return c[0] == "world_fact" and c[2] == "now")
		t.eq(kind + " one sound per phase", cues.size(), 2)
		for p in mini(2, cues.size()):
			var cue: Array = cues[p]
			var spec: Dictionary = EventKinds.world_row(phases[p].fact)
			t.eq(kind + " row chooses sound", cue[1], Rows.heard(spec, audio.cue_context()))
			t.near(kind + " bank and priority level", cue[5], Bank.trim_db(cue[1]) + Audio.PRIORITY_DB[Rows.priority(cue[0])])
			t.near(kind + " follows live key", cue[4], Harmony.ratio(LIVE_KEY))
		var original: Callable = handler.get("_world_sound") if handler.get("_world_sound") != null else Callable()
		handler.release()
		t.check(kind + " releases sound listener", not w.ctx.events.world_fact.is_connected(Callable(handler, "_on_world_sound")))
		t.check(kind + " restores original listener", original.is_valid() and w.ctx.events.world_fact.is_connected(original))
		w.free()
	t.eq("seven natural and three shared family cue paths checked", t.checks + 1, 101)
	quit(t.verdict())
