extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const TuneMoments := preload("res://src/presentation/tune_moments.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RunClock := preload("res://src/build/run_clock.gd")
const T := preload("res://tests/support/t.gd")

# The place-and-moment tunes (tune_moments.gd). Every tunes.json row is wired with a case here
# or listed unwired with the hook it needs. The decisions are pure; the glue is read from what
# the level band is asked to play (Rig records _ace_stage with the tune it resolves). A tune
# whose pack is not on disk must change nothing.

const TUNES_JSON := "res://design-v3/sound/tunes.json"

class FakeBuild:
	extends RefCounted
	var clock := RunClock.new()

class FakeCtx:
	extends RefCounted
	var events: Node
	var build

class Rig:
	extends Audio
	var named: Array = []
	var staged: Array = []
	func ace_wanted() -> bool:
		return true
	func _ace_named(id: String, at: int, _boss := false, _won := true) -> void:
		named.append([id, at])
	func _ace_stage(stage: int, at: int) -> void:
		staged.append([stage, at, level_tune(stage)])

class FakeElite:
	extends Node3D
	signal died(where: Vector3, scrap: int)
	var affix := {"id": "rail_strike"}
	var hp := 100.0
	var max_hp := 100.0

var _t := T.new("tune_moments_test")
var _nodes: Array = []
var _rows: Array = []


func _initialize() -> void:
	_rows = JSON.parse_string(FileAccess.get_file_as_string(TUNES_JSON))
	_registry()
	_pure()


func _registry() -> void:
	var ids := []
	for row in _rows:
		ids.append(row.id)
		var id: String = row.id
		_t.check("%s is in the tune table" % id, TuneMoments.TUNES.has(id))
		if not TuneMoments.TUNES.has(id):
			continue
		var wired: bool = TuneMoments.TUNES[id].hook != ""
		_t.check("%s is wired or listed unwired with its hook" % id, wired != TuneMoments.UNWIRED.has(id))
		_t.eq("%s bpm matches tunes.json" % id, int(TuneMoments.TUNES[id].bpm), int(row.bpm))
		_t.check("%s is hidden exactly when tunes.json says" % id, TuneMoments.is_hidden(id) == bool(row.hidden))
		_t.check("%s has a music row on its own pack" % id, MusicRows.ROWS.has(id) and String(MusicRows.ROWS[id]["ace_manifest"]).ends_with("/%s/manifest.json" % TuneMoments.theme_of(id)))
	_t.eq("the table holds exactly the tunes.json ids", TuneMoments.TUNES.keys().size(), ids.size())
	_t.eq("one tune waits on a hook", TuneMoments.UNWIRED.keys(), ["camp-course"])


func _pure() -> void:
	var cases := {
		"landmark-spillway-dam": ["landmark", "spillway_dam"], "landmark-penstock": ["landmark", "penstock_tower"],
		"landmark-headframe": ["landmark", "headframe"], "landmark-sinkhole": ["landmark", "sinkhole"],
		"landmark-hanging-isle": ["landmark", "hanging_isle"], "landmark-crown-spire": ["landmark", "crown_spire"],
		"event-scrap-stampede": ["event", "scrap_stampede"], "event-surge-run": ["event", "surge_run"],
		"event-hold-relay": ["event", "hold_the_relay"], "event-flood": ["event", "flood"],
		"event-dust-squall": ["event", "dust_squall"], "event-arena": ["activity", "round_arena"],
		"miniboss": ["miniboss", "miniboss"], "moss-shop": ["shop", "bay"], "modifier-par": ["modifier", "par"], "modifier-curse": ["modifier", "curse"],
		"fabricator": ["fabricator", "fabricator_used"],
		"secret-lost-tape": ["find", "flume_weir_cache"], "secret-after-hours": ["jukebox", "bay_jukebox"],
		"secret-brindle-swing": ["remix", "brindle"], "secret-chip-keepers": ["remix", "champion"],
		"secret-highdraft-rain": ["remix", "3-1"], "secret-dig-dub": ["remix", "2-2"],
	}
	for id in TuneMoments.TUNES:
		if TuneMoments.UNWIRED.has(id):
			continue
		_t.check("%s has a mapping case" % id, cases.has(id))
		if cases.has(id):
			_t.eq("%s maps from its hook" % id, TuneMoments.tune_for(cases[id][0], cases[id][1]), id)
	_t.eq("the plain arena maps too", TuneMoments.activity_tune("arena"), "event-arena")
	_t.eq("the alpha Cable Reach cache maps too", TuneMoments.find_tune("reach_pressure_cache"), "secret-lost-tape")
	_t.eq("an elite arena is the miniboss's, not the arena's", TuneMoments.activity_tune("elite_arena"), "")
	_t.eq("a park event row has no tune", TuneMoments.event_tune("park_flood_fill_1"), "")
	_t.eq("another cache is no find", TuneMoments.find_tune("spillway_gallery_cache"), "")
	_t.check("a landmark comes in at its reach", TuneMoments.landmark_holds(0.8, false, false) and not TuneMoments.landmark_holds(0.75, false, false))
	_t.check("and holds down to its exit", TuneMoments.landmark_holds(0.75, true, false) and not TuneMoments.landmark_holds(0.65, true, false))
	_t.check("never once the Warden is engaged", not TuneMoments.landmark_holds(1.0, true, true))
	_t.eq("one pass of the lost tape is 16 bars at 90", TuneMoments.pass_frames("secret-lost-tape"), roundi(16 * 4 * 60.0 / 90.0 * 44100))
	var yes := func(_id): return true
	var moments := [{"id": "landmark-sinkhole", "kind": "landmark", "seq": 1}, {"id": "event-flood", "kind": "event", "seq": 2},
		{"id": "moss-shop", "kind": "shop", "seq": 3}]
	_t.eq("the higher priority plays", TuneMoments.top(moments, yes), "event-flood")
	_t.eq("a missing pack is passed over", TuneMoments.top(moments, func(id): return id != "event-flood"), "moss-shop")
	_t.eq("no pack, no moment", TuneMoments.top(moments, func(_id): return false), "")
	_t.eq("a tie goes to the newest", TuneMoments.top([{"id": "event-flood", "kind": "event", "seq": 1}, {"id": "event-arena", "kind": "event", "seq": 2}], yes), "event-arena")
	# The rare remixes: a seeded rng rolls the same run twice; the chance holds over many runs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var first := TuneMoments.roll_remixes(rng)
	rng.seed = 41
	_t.eq("a seeded roll repeats", TuneMoments.roll_remixes(rng), first)
	_t.eq("chance 1 rolls all four", TuneMoments.roll_remixes(rng, 1.0), {"brindle": "secret-brindle-swing", "champion": "secret-chip-keepers", "3-1": "secret-highdraft-rain", "2-2": "secret-dig-dub"})
	_t.eq("chance 0 rolls none", TuneMoments.roll_remixes(rng, 0.0), {})
	rng.seed = 2026
	var hits := 0
	var runs := 4000
	for i in runs:
		hits += TuneMoments.roll_remixes(rng).size()
	var rate := float(hits) / (runs * 4)
	_t.check("each remix comes up about one run in ten", absf(rate - TuneMoments.REMIX_CHANCE) < 0.015, "rate %.4f" % rate)
	var rolled := {"3-1": "secret-highdraft-rain", "champion": "secret-chip-keepers"}
	_t.eq("a rolled remix replaces its stage", TuneMoments.stage_tune("3-1", [], rolled, yes), "secret-highdraft-rain")
	_t.eq("another stage keeps its own", TuneMoments.stage_tune("1-1", [], rolled, yes), "")
	_t.eq("a missing remix pack keeps the stage's own", TuneMoments.stage_tune("3-1", [], rolled, func(_id): return false), "")
	_t.eq("par plays over a remix", TuneMoments.stage_tune("3-1", ["par"], rolled, yes), "modifier-par")
	_t.eq("a curse plays over a remix", TuneMoments.stage_tune("3-1", ["curse"], rolled, yes), "modifier-curse")
	_t.eq("scrapless has no tune", TuneMoments.stage_tune("1-1", ["scrapless"], {}, yes), "")
	_t.eq("a remix replaces its parent", TuneMoments.remixed("champion", "champion-hype", rolled, yes), "secret-chip-keepers")
	_t.eq("an unrolled slot keeps its parent", TuneMoments.remixed("brindle", "brindle-p1-requisition", rolled, yes), "brindle-p1-requisition")


func _rig(avail: Callable) -> Rig:
	var events := GameEvents.new()
	var ctx := FakeCtx.new()
	ctx.events = events
	var audio := Rig.new()
	audio.setup(ctx)
	audio.bake_now()
	audio.pack_available = func(_id): return true
	audio.tune_available = avail
	audio._stage_now = 4
	_nodes.append_array([events, audio])
	return audio


func _last(a: Rig) -> String:
	return String(a.staged[-1][2]) if not a.staged.is_empty() else "<none>"


func _process(_delta: float) -> bool:
	var a := _rig(func(_id): return true)
	var events: GameEvents = a.ctx.events
	for event_id in ["scrap_stampede", "surge_run", "hold_the_relay", "flood", "dust_squall"]:
		events.event_started.emit(event_id)
		var want := TuneMoments.event_tune(event_id)
		_t.check("%s starts %s on the next downbeat" % [event_id, want], _last(a) == want and int(a.staged[-1][1]) == a.engine.next_bar(), str(a.staged[-1]))
		events.event_ended.emit(event_id, "passed")
		_t.eq("%s's end returns to the stage's music" % event_id, _last(a), "")
	a.activity_cue("round_arena", "telegraph")
	_t.eq("the round arena starts its tune", _last(a), "event-arena")
	events.activity_done.emit("round_arena", Vector3.ZERO)
	_t.eq("the arena's end returns", _last(a), "")

	var boss := FakeElite.new()
	boss.affix = {}
	root.add_child(boss)
	a._on_enemy_spawned(boss, "miniboss")
	_t.eq("a miniboss starts Heavyweight", _last(a), "miniboss")
	a._on_kill("miniboss", Vector3.ZERO, 0)
	_t.eq("its kill returns", _last(a), "")
	boss.free()

	a.landmark_moment("spillway_dam", 0.85)
	_t.eq("the dam in reach starts its tune", _last(a), "landmark-spillway-dam")
	var n := a.staged.size()
	a.landmark_moment("spillway_dam", 0.75)
	_t.eq("it holds inside the exit", a.staged.size(), n)
	events.event_started.emit("flood")
	_t.eq("an event plays over the landmark", _last(a), "event-flood")
	events.event_ended.emit("flood", "passed")
	_t.eq("and hands back to the landmark, not the stage", _last(a), "landmark-spillway-dam")
	a.landmark_moment("spillway_dam", 0.6)
	_t.eq("leaving the reach returns", _last(a), "")
	a.landmark_moment("spillway_dam", 0.9)
	events.warden_engaged.emit(4)
	_t.eq("the Warden takes the landmark's place", _last(a), "")
	n = a.staged.size()
	a.landmark_moment("spillway_dam", 0.95)
	_t.eq("and the landmark does not come back this stage", a.staged.size(), n)

	a.begin_moment("shop", "bay", "moss-shop")
	_t.eq("Moss's bay plays his counter", _last(a), "moss-shop")
	a.jukebox_flipped()
	_t.eq("the jukebox finds After Hours", _last(a), "secret-after-hours")
	a.jukebox_flipped()
	_t.eq("a second press goes back to the counter", _last(a), "moss-shop")
	a.end_moment("shop", "bay")
	_t.eq("leaving the bay returns", _last(a), "")

	events.synergy_discovered.emit("flume_weir_cache", "world", true)
	_t.eq("the Cable Reach cache finds the Lost Tape", _last(a), "secret-lost-tape")
	a.engine.clock = int(a._moments[0].until)
	a._tend_moments()
	_t.eq("after one pass it hands back", _last(a), "")
	events.synergy_discovered.emit("thermal_ride", "world", true)
	_t.eq("another discovery plays nothing", _last(a), "")

	a.fabricator_used()
	_t.eq("a fabricator hoop plays The Fabricator", _last(a), "fabricator")
	var first_until := int(a._moments[0].until)
	a.engine.clock += TuneMoments.pass_frames("fabricator") / 2
	a.fabricator_used()
	_t.check("a second hoop restarts the pass", a._moments.size() == 1 and int(a._moments[0].until) > first_until)
	a.engine.clock = int(a._moments[0].until)
	a._tend_moments()
	_t.eq("after one pass it hands back", _last(a), "")

	# Rare remixes, read where they play.
	var zone31 := 0
	for s in range(1, 13):
		if MusicRows.zone_id(s) == "3-1":
			zone31 = s
	a._remixes = {"3-1": "secret-highdraft-rain", "brindle": "secret-brindle-swing", "champion": "secret-chip-keepers"}
	_t.eq("a rolled stage plays its remix", a.level_tune(zone31), "secret-highdraft-rain")
	_t.eq("Brindle opens on the swing", a._boss_entry("brindle"), "secret-brindle-swing")
	var elite := FakeElite.new()
	root.add_child(elite)
	a._on_enemy_spawned(elite, "plated_brute")
	_t.check("a champion on a chiptune run plays the chiptune", not a.named.is_empty() and a.named[-1][0] == "secret-chip-keepers", str(a.named))
	elite.free()
	a._remixes = {}
	_t.eq("an unrolled run opens on phase 1", a._boss_entry("brindle"), "brindle-p1-requisition")

	var p := _rig(func(_id): return true)
	p.ctx.build = FakeBuild.new()
	p.ctx.build.clock.begin_run({"par": true})
	_t.eq("a par run's stages play Beat the Par", p.level_tune(4), "modifier-par")

	# No packs on disk: nothing moves.
	var none := _rig(func(_id): return false)
	var ev: GameEvents = none.ctx.events
	ev.event_started.emit("flood")
	none.activity_cue("arena", "telegraph")
	none.landmark_moment("headframe", 1.0)
	none.begin_moment("shop", "bay", "moss-shop")
	none.jukebox_flipped()
	none.fabricator_used()
	ev.synergy_discovered.emit("reach_pressure_cache", "world", true)
	var mb := FakeElite.new()
	mb.affix = {}
	root.add_child(mb)
	none._on_enemy_spawned(mb, "miniboss")
	ev.event_ended.emit("flood", "passed")
	mb.free()
	_t.check("missing packs never change the music", none.staged.is_empty() and none.named.is_empty(), str(none.staged))
	none._remixes = {"3-1": "secret-highdraft-rain", "brindle": "secret-brindle-swing"}
	_t.check("a missing remix keeps the parent", none.level_tune(zone31) == "" and none._boss_entry("brindle") == "brindle-p1-requisition")

	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	quit(_t.verdict())
	return true
