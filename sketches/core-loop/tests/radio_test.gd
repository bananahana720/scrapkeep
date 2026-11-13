extends SceneTree

const Game := preload("res://src/game.gd")
const Radio := preload("res://src/core/radio.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Profile := preload("res://src/core/profile.gd")
const RadioCache := preload("res://src/world/radio_cache.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const PhaseMusic := preload("res://src/presentation/phase_music.gd")
const T := preload("res://tests/support/t.gd")

# The pilot radio (Andrew 2026-10-17 20:02Z: a persistent HUD radio to switch, auto, skip and
# turn off, playlists, and collectible tracks scaled to the challenge; design-v3/sound/RADIO.md):
#   - the catalogue validates against the bus, with more takes than needed, legends, two or more
#     Signal caches in every park, and at least one take on every content station;
#   - the model: Live plays the score, Off silences, a fresh tune cuts in, a boss keeps its score
#     unless the track is pinned, an empty station plays the score with no signal, a found take
#     airs on its station, skip rotates, the dial wraps through Off, off returns to the last
#     station, a premiere goes back after one airing, mixtapes keep their limits, and the state
#     survives a save with unknown ids dropped;
#   - on the real game in a run: the radio waits out a tune not heard yet, then holds a found
#     take with the run's own parameters driving the band; Off mutes the music bus alone; a stage
#     hit keeps the track; a Warden takes the air back unless the track is pinned; a found rule
#     files, announces and premieres its take; the keys turn the dial; the dial draws on the HUD;
#     a death hands the music back; the dial and mixtapes save.

var _t := T.new("radio_test")
var _game


# A take plays its own pack once one is packaged at assets/music_ace/<take id>/; with no pack
# the radio plays its parent record. All 81 takes are packaged, so each resolves to its manifest
# (the Oggs are gitignored, the manifests are not); an id that is no take has none.
# Rows that name a pack keep it.
func _packs() -> void:
	var ids := RadioTakes.take_ids()
	var unpackaged := []
	for id in ids:
		if MusicRows.take_manifest(String(id)) == "":
			unpackaged.append(String(id))
	_t.eq("every catalogue take has a pack", unpackaged, [])
	_t.eq("the catalogue holds 81 takes", ids.size(), 81)
	_t.eq("an id that is no take has no pack", MusicRows.take_manifest("take-not-a-take"), "")
	_t.eq("a row that names a pack keeps it", MusicRows.take_manifest("1-1"), MusicRows.ROWS["1-1"]["ace_manifest"])
	_t.eq("an unknown id has no pack", MusicRows.take_manifest("nope"), "")


func _initialize() -> void:
	_catalogue()
	_model()
	_packs()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _catalogue() -> void:
	var doc := RadioTakes.doc()
	var errors := RadioTakes.validate(doc, Achievements.bus_signals())
	_t.eq("the catalogue validates", errors, [])
	var takes: Array = doc["takes"]
	_t.check("more takes than the alpha needs", takes.size() >= 72, str(takes.size()))
	_t.check("a dozen legends or more", takes.filter(func(t): return t["tier"] == "legend").size() >= 12)
	for map in ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"]:
		var caches := takes.filter(func(t): return t["found"].get("on") == "cache" and t["found"].get("park") == map)
		_t.check("%s hides two Signal caches or more" % map, caches.size() >= 2, str(caches.size()))
	for s in doc["stations"]:
		if s["id"] in RadioTakes.BUILT_IN:
			continue
		_t.check("station %s airs a take" % s["id"], not RadioTakes.on_station(String(s["id"])).is_empty())
	_t.eq("Off leads the dial", Radio.dial()[0], Radio.OFF)
	_t.check("the dial holds Live, Auto and Mixtape", [Radio.LIVE, Radio.AUTO, Radio.MIXTAPE].all(func(id): return id in Radio.dial()))


func _first_take_on(station: String, skip: Array = []) -> String:
	for id in RadioTakes.on_station(station):
		if RadioTakes.is_take(id) and not id in skip:
			return id
	return ""


func _content_station() -> String:
	for id in RadioTakes.station_ids():
		if not id in RadioTakes.BUILT_IN and RadioTakes.on_station(id).filter(func(t): return RadioTakes.is_take(t)).size() >= 2:
			return id
	return ""


func _model() -> void:
	var station := _content_station()
	var a := _first_take_on(station)
	var b := _first_take_on(station, [a])
	var r := Radio.new()
	var ctx := {"found": [a, b], "world": 0, "boss": false, "fresh": false}
	_t.eq("Live plays the score", r.decide(ctx)["play"], "score")
	r.tune(Radio.OFF)
	_t.eq("Off silences", r.decide(ctx)["play"], "silence")
	r.tune(station)
	var plan := r.decide(ctx)
	_t.eq("a found take airs on its station", [plan["play"], plan["id"], plan["why"]], ["track", a, "on_air"])
	_t.eq("a fresh tune cuts in", r.decide(ctx.merged({"fresh": true}, true))["why"], "new_signal")
	_t.eq("a boss keeps its score", r.decide(ctx.merged({"boss": true}, true))["why"], "boss")
	r.decide(ctx)
	r.toggle_pin()
	_t.eq("unless the track is pinned", r.decide(ctx.merged({"boss": true}, true))["id"], a)
	_t.eq("but the finale wins over a pin", r.decide(ctx.merged({"boss": true, "finale": true}, true))["why"], "finale")
	_t.eq("and the pin plays again after the fight", [r.decide(ctx)["id"], r.pinned], [a, true])
	_t.eq("skip moves on and unpins", [r.skip(ctx), r.pinned], [b, false])
	_t.eq("and wraps", r.skip(ctx), a)
	_t.eq("an empty station plays the score", r.decide(ctx.merged({"found": []}, true))["why"], "no_signal")
	r.decide(ctx)
	_t.check("airtime moves the station on", r.tick(Radio.AIRTIME + 0.1, ctx) and r.track == b)
	r.tune(Radio.LIVE)
	r.turn(-1)
	_t.eq("the dial wraps back through Off", r.station, Radio.OFF)
	r.turn(-1)
	_t.eq("and round to the last station", r.station, Radio.dial()[-1])
	r.tune(station)
	r.toggle_off()
	_t.eq("off", r.station, Radio.OFF)
	r.toggle_off()
	_t.eq("and on again to the last station", r.station, station)
	r.tune(Radio.LIVE)
	_t.check("a find premieres on its own station", r.premiere(b) and r.station == station and r.track == b)
	r.decide(ctx)
	r.tick(Radio.AIRTIME + 0.1, ctx)
	_t.eq("then the dial goes back", r.station, Radio.LIVE)
	r.tune(Radio.OFF)
	_t.check("Off stays off for a find", not r.premiere(a) and r.station == Radio.OFF)
	r.tune(Radio.AUTO)
	_t.check("Auto airs found tracks", r.decide(ctx)["play"] == "track")
	r.tune(Radio.MIXTAPE)
	_t.eq("an empty mixtape plays the score", r.decide(ctx)["why"], "no_signal")
	_t.check("a mixtape takes a track", r.add_to(0, b) and r.add_to(0, a))
	_t.check("once", not r.add_to(0, a))
	_t.check("and never an unknown id", not r.add_to(0, "take-nope"))
	_t.eq("it airs in its own order", r.decide(ctx)["id"], b)
	_t.check("a track moves down", r.nudge(0, b, 1) and r.mixtapes[0]["ids"] == [a, b])
	_t.check("not off the end", not r.nudge(0, b, 1))
	for i in Radio.MAX_MIXTAPES - 1:
		r.new_mixtape()
	_t.eq("six mixtapes at most", r.new_mixtape(), -1)
	_t.check("a track comes off", r.remove_from(0, a) and r.mixtapes[0]["ids"] == [b])
	var saved := r.to_dict()
	saved["mixtapes"][1]["ids"] = ["take-nope", a, a]
	saved["station"] = "nowhere"
	var back := Radio.new()
	back.from_dict(saved)
	_t.eq("a reload keeps the mixtapes, drops unknown and repeated ids", back.mixtapes[1]["ids"], [a])
	_t.eq("and an unknown station reads as Live", back.station, Radio.LIVE)
	_t.eq("six lists come back", back.mixtapes.size(), Radio.MAX_MIXTAPES)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_game.radio_deck._unhandled_input(event)


func _run() -> void:
	await _frames(3)
	var audio = _game.presentation.audio
	audio.bake_now()
	await _frames(2)
	var deck = _game.radio_deck
	var profile = _game.ctx.profile
	_t.check("the game carries a radio deck", deck != null and deck.dial != null)
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(4)
	_t.check("a run is in play", _game.flow.in_play(), _game.flow.state_name())
	var station := _content_station()
	var a := _first_take_on(station)
	var b := _first_take_on(station, [a])
	profile.hear_tune(a)
	deck.tune(station)
	await _frames(2)
	var wanted: String = audio.score_tune_wanted()
	_t.eq("the score wants the stage's roam", wanted, "roam-1-1")
	_t.eq("a tune not heard yet keeps the air", [audio.radio_hold, deck.applied.get("why", "")], ["", "new_signal"])
	_t.eq("and the dial names it", deck.reading()["line"], "New signal: Top Shelf")
	audio.knows_tune("roam-1-1")
	profile.hear_tune("roam-1-1")
	deck._plan_now()
	_t.eq("a heard tune keeps the air until the moment moves on", audio.radio_hold, "")
	_t.eq("and is no longer news on the dial", deck.reading()["line"], "Live: Top Shelf")
	_press("cl_radio_skip")
	_t.check("a key press lets the radio back on air", audio.radio_hold != "" and audio.radio_hold in RadioTakes.on_station(station), audio.radio_hold)
	deck.radio.track = a
	deck._plan_now()
	_t.eq("then the radio holds the take", audio.radio_hold, a)
	# A packaged take plays its own pack; one with no manifest plays its parent record.
	var played := a if MusicRows.take_manifest(a) != "" else RadioTakes.record_of(a)
	_t.eq("the band plays the take's pack, else its record", audio.spinning, played)
	_t.check("with the run's own parameters", audio.engine.parameter_source == Callable(audio, "sample_run_parameters"))
	_t.eq("the dial names it", deck.reading()["line"], String(RadioTakes.take(a)["name"]))

	deck.tune(Radio.OFF)
	var music := AudioServer.get_bus_index("Music")
	var sfx := AudioServer.get_bus_index("SFX")
	_t.check("Off mutes the music bus", AudioServer.is_bus_mute(music))
	_t.check("and never the effects", not AudioServer.is_bus_mute(sfx))
	_t.eq("and gives the band back to the score", audio.radio_hold, "")
	deck.tune(station)
	_t.check("on again unmutes it", not AudioServer.is_bus_mute(music) and audio.radio_hold == a)

	audio._flow_queue.append(["stage", 1, true])
	audio._flush_flow()
	_t.eq("a stage hit keeps the track", [audio.radio_hold, audio.spinning], [a, played])

	var yielded := []
	audio.radio_yielded.connect(func(reason: String): yielded.append(reason))
	audio._begin_boss("warden_engaged", "warden")
	_t.eq("a Warden takes the air back", [audio.radio_hold, yielded], ["", ["boss"]])
	audio.engine.render(44100 * 2)
	_t.eq("its own music plays", audio.engine.track, "warden")
	audio.engine.force_track("level", 0)
	deck._plan_now()
	deck.toggle_pin()
	_t.check("a pinned track", audio.radio_hold == a and audio.radio_pinned)
	audio._begin_boss("warden_engaged", "warden")
	_t.eq("holds through the Warden", audio.radio_hold, a)
	audio._begin_boss("boss_arena_entered", "brindle")
	_t.eq("and through a boss", audio.radio_hold, a)
	var before_finale := yielded.size()
	audio.phase_music(PhaseMusic.LAST_PHASE)
	_t.eq("the finale takes the air from a pin", [audio.radio_hold, audio.radio_finale, yielded.slice(before_finale)], ["", true, ["finale"]])
	audio.engine.render(44100 * 2)
	_t.eq("and the boss it held off plays", audio.engine.track, "brindle")
	_t.eq("the deck leaves the finale on", deck.radio.decide(deck.context().merged({"boss": true}, true))["why"], "finale")
	audio._on_boss_defeated()
	_t.eq("the pin plays again after the fight", [audio.radio_finale, deck.radio.decide(deck.context().merged({"boss": false}, true))["id"], deck.radio.pinned], [false, a, true])
	audio.engine.force_track("level", 0)
	deck._plan_now()
	deck.toggle_pin()

	var c := ""
	for t in RadioTakes.takes():
		var rule: Dictionary = t["found"]
		if not rule.get("on") in RadioTakes.SPECIAL_RULES and rule.get("stage", []).is_empty() and rule.get("at_least", {}).is_empty() and RadioTakes.needed(rule) == 1 and t["station"] != station:
			c = String(t["id"])
			break
	_t.check("a take with a one-shot rule exists", c != "")
	var rule: Dictionary = RadioTakes.take(c)["found"]
	var args: Dictionary = rule.get("where", {}).duplicate()
	deck.bus_signal(String(rule["on"]), args)
	_t.check("its rule files it", profile.has_tune(c))
	_t.check("and the record plate announces it", _game.hud.tune_waiting().any(func(t): return String(t).contains("On the radio")), str(_game.hud.tune_waiting()))
	_t.eq("and it premieres on its station", [deck.radio.station, audio.radio_hold], [String(RadioTakes.take(c)["station"]), c])
	deck.bus_signal(String(rule["on"]), args)
	_t.eq("once", _game.hud.tune_waiting().filter(func(t): return String(t).begins_with(String(RadioTakes.take(c)["name"]))).size(), 1)

	var before: String = deck.radio.station
	_press("cl_radio_next")
	_t.eq("period turns the dial on", Radio.dial().find(deck.radio.station), (Radio.dial().find(before) + 1) % Radio.dial().size())
	_press("cl_radio_prev")
	_t.eq("comma turns it back", deck.radio.station, before)
	_t.check("a turn swells the dial", deck.dial.swollen())
	await _frames(2)
	_t.check("the dial draws on the HUD in play", deck.dial.visible and deck.dial.get_parent() == _game.hud)

	var cache_take := ""
	for t in RadioTakes.takes():
		if t["found"].get("on") == "cache" and t["found"].get("park") == "park_dam" and not profile.has_tune(String(t["id"])):
			cache_take = String(t["id"])
			break
	var spots := {cache_take: [1.0, 2.0, 3.0]}
	var cache_wanted: Array = RadioCache.wanted("park_dam", func(id): return profile.has_tune(id), spots)
	_t.eq("a placed cache of the park is wanted", cache_wanted, [[cache_take, Vector3(1.0, 2.0, 3.0)]])
	# 2026-10-17 (stage/alpha-w16): spots now cover several parks, so count only the dam's cache takes that have one.
	var dam_spotted := RadioTakes.takes().filter(func(t): return (t["found"].get("on") == "cache" and t["found"].get("park") == "park_dam"
		and RadioCache.spots().has(String(t["id"])))).size()
	_t.eq("one with no spot is not", RadioCache.wanted("park_dam", func(id): return false, {}).size(), dam_spotted)
	var cache = RadioCache.new()
	cache.take_id = cache_take
	cache.deck = deck
	_game.ctx.root.add_child(cache)
	var twin = RadioCache.new()
	_game.ctx.root.add_child(twin)
	_t.check("caches share their meshes and materials (made once, not per cache on the entry frame)",
		cache._ring.mesh == twin._ring.mesh and cache._ring.material_override == twin._ring.material_override and cache._lamp.mesh == twin._lamp.mesh)
	twin.free()
	# W1-23: the cache draws the crew mast model, no Godot primitive.
	var plain := cache.find_children("*", "MeshInstance3D", true, false).filter(func(v): return v.mesh is PrimitiveMesh)
	_t.check("the cache draws its mast model, no plain shapes", cache.get_node_or_null("RadioMast") != null and plain.is_empty(), "%d plain" % plain.size())
	# The cache is handed the game's own ball, as radio_deck hands it: the PlayerBall node sits at
	# the origin for the whole run, so reach is measured from the ball, never from that node.
	var ball: Vector3 = _game.ctx.player.ball_position()
	_t.check("the ball is away from the PlayerBall node's own origin", ball.distance_to(_game.ctx.player.global_position) > RadioCache.REACH * 4.0, "ball at %s" % ball)
	cache.player = _game.ctx.player
	cache.global_position = _game.ctx.player.global_position - Vector3.UP
	cache._physics_process(0.0)
	_t.check("a cache out of the ball's reach stays", not cache.is_queued_for_deletion() and not profile.has_tune(cache_take))
	cache.global_position = ball - Vector3.UP
	# A find is made in play. Under the summary or after a death the ball can still roll into a
	# cache: nothing is filed, announced or premiered, and the cache stands for the next run.
	var flow = _game.flow
	var in_play_state: int = flow.state
	var station_before: String = deck.radio.station
	for off_air in [flow.SUMMARY, flow.DEAD]:
		flow.state = off_air
		cache._physics_process(0.0)
		_t.check("a ball in reach of a cache finds nothing in %s" % flow.state_name(),
			not cache.is_queued_for_deletion() and not profile.has_tune(cache_take) and deck.radio.station == station_before)
	flow.state = in_play_state
	cache._physics_process(0.0)
	_t.check("rolling up to a Signal cache files its take", cache.is_queued_for_deletion() and profile.has_tune(cache_take))
	_t.eq("and a found one is no longer wanted", RadioCache.wanted("park_dam", func(id): return profile.has_tune(id), spots), [])

	deck.tune(station)
	deck.radio.mixtapes[0]["ids"] = [a]
	deck._save()
	var reread := Profile.new(profile.path)
	reread.load_profile()
	_t.eq("the dial and mixtapes save", [reread.radio().get("station", ""), reread.radio().get("mixtapes", [{}])[0].get("ids", [])], [station, [a]])

	deck._plan_now()
	_t.eq("the radio holds before a death", audio.radio_hold, a)
	audio._flow_queue.append(["dead"])
	audio._flush_flow()
	_t.eq("a death hands the music back", [audio.radio_hold, audio.spinning], ["", ""])
	quit(_t.verdict())
