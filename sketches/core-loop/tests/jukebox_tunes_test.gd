extends SceneTree

const Game := preload("res://src/game.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")
const TuneEar := preload("res://src/presentation/tune_ear.gd")
const Profile := preload("res://src/core/profile.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const T := preload("res://tests/support/t.gd")
const AceSequencer := preload("res://src/presentation/ace_sequencer.gd")

# Moss's jukebox (TUNE-JUKEBOX, Andrew 2026-10-17: "finding and discovering these different
# tunes ... having ways to come back to them"):
#   - every row has a unique id, a shelf, a known source and short words, and key_of reads
#     each row's own source back as that row (one row per tune the band can tell apart);
#   - the ear finds a tune only after it holds 4 s, once, and never one the profile holds;
#   - the profile keeps tunes across a save and a reload, a file without the list reads as
#     none, and two writers keep the union;
#   - on the real game, the title theme heard at the title is filed, saved and announced
#     on the HUD's record plate, once;
#   - J on the camp opens the jukebox, which counts found records, shows a blank sleeve's
#     hint, plays a found record (the band cuts to its track), refuses a blank one, sets
#     the dial on 1 to 3, hears nothing new while it spins, and J lifts the needle and
#     returns to the camp with the title theme queued;
#   - every source kind plays its own track: menu, level, warden, boss, lounge and miniboss;
#     a recorded-only pack wins over the synth track under it, and its boss stands in on
#     the synth when the pack is not on disk;
#   - the 23 place-and-moment tunes the music thread wired (tunes.json ids and names) are
#     records, found while their pack plays; the camp course, still unwired, is not; each hidden one is rare and its hint says where to listen;
#     on the deck a place tune with no pack on disk plays its zone's roam on the synth;
#   - leaving the title while a record spins hands the music back to the game.

const STORE_DIR := "user://jukebox_tunes_test/"

var _t := T.new("jukebox_tunes_test")
var _game


func _initialize() -> void:
	_rows()
	_ear()
	_profile()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _source_state(row: Dictionary) -> Dictionary:
	var source: Dictionary = row["source"]
	match String(source["kind"]):
		"menu":
			var section := "" if source["pack"] == "title" else ("won" if source.get("won", true) else "lost")
			return {"mode": "idle", "track": source["pack"], "section": section, "lounge": false, "zone": "1-1"}
		"level":
			return {"mode": "play", "track": "level", "section": "", "lounge": false, "zone": source["zone"]}
		"warden":
			return {"mode": "play", "track": "warden", "section": "build", "lounge": false, "zone": source["zone"]}
		"boss":
			return {"mode": "play", "track": source["boss"], "section": "2", "lounge": false, "zone": "1-2"}
		"lounge":
			return {"mode": "play", "track": "level", "section": "", "lounge": true, "zone": "2-1"}
		"miniboss":
			return {"mode": "play", "track": "miniboss", "section": "", "lounge": false, "zone": "3-1"}
		"pack":
			return {"mode": "play", "track": source.get("boss", "level"), "section": "3", "lounge": bool(source.get("lounge", false)), "zone": source.get("zone", "1-2"), "pack": source["pack"]}
	return {}


func _rows() -> void:
	var seen := {}
	var kinds := ["menu", "level", "warden", "boss", "lounge", "miniboss", "pack"]
	var long := []
	for row in TuneRows.ROWS:
		var id := String(row["id"])
		_t.check("row %s is unique" % id, not seen.has(id))
		seen[id] = true
		_t.check("row %s has a shelf" % id, int(row["shelf"]) >= 0 and int(row["shelf"]) < TuneRows.SHELVES.size())
		_t.check("row %s has a known source" % id, String(row["source"]["kind"]) in kinds, str(row["source"]))
		for key in ["where", "sleeve"]:
			if WordBudget.words_in(String(row[key])) > 12:
				long.append("%s.%s" % [id, key])
		_t.eq("key_of reads %s's own source back" % id, TuneRows.key_of(_source_state(row)), id)
		var zone := String(row["source"].get("zone", ""))
		if zone != "":
			_t.check("%s names a music row" % id, MusicRows.ROWS.has(zone), zone)
	_t.eq("every sleeve and hint is 12 words or fewer", long, [])
	for shelf in TuneRows.SHELVES.size():
		_t.check("shelf %d holds records" % shelf, not TuneRows.on_shelf(shelf).is_empty())
	_t.eq("the death break's keys are no record", TuneRows.key_of({"mode": "dead", "track": "level", "zone": "1-1"}), "")
	_t.eq("a zone's own recorded pack leaves the roam record", TuneRows.key_of({"mode": "play", "track": "level", "zone": "1-1", "pack": "spillway"}), "roam-1-1")
	_t.eq("a recorded-only pack wins over the boss under it", TuneRows.key_of({"mode": "play", "track": "brindle", "zone": "1-2", "pack": "euro-brindle-p3"}), "euro-brindle-p3")
	var place := {
		"landmark-spillway-dam": "Over the Dam", "landmark-penstock": "Penstock Pressure",
		"landmark-headframe": "Down the Headframe", "landmark-sinkhole": "Sinkhole Echo",
		"landmark-hanging-isle": "The Hanging Isle", "landmark-crown-spire": "Crown of the Spire",
		"event-scrap-stampede": "Scrap Stampede", "event-surge-run": "Surge Run",
		"event-hold-relay": "Hold the Relay", "event-flood": "Flood Gates",
		"event-dust-squall": "Dust Squall", "event-arena": "Round Arena",
		"moss-shop": "Moss's Counter", "modifier-par": "Beat the Par",
		"secret-lost-tape": "The Lost Tape", "secret-after-hours": "Moss After Hours",
		"secret-brindle-swing": "Brindle Swings", "secret-chip-keepers": "Chiptune Keepers",
		"secret-highdraft-rain": "Rain over the Highdraft", "secret-dig-dub": "Deep Works Dub",
		"miniboss": "Heavyweight", "fabricator": "The Fabricator",
		"modifier-curse": "Cursed Run",
	}
	var named := {}
	for id in place:
		named[id] = String(TuneRows.row(id).get("name", ""))
	_t.eq("the 23 wired tunes are records under their tunes.json names", named, place)
	_t.eq("the unwired tune is not a record yet", ["camp-course"].filter(func(id): return not TuneRows.row(id).is_empty()), [])
	_t.eq("the crate holds 52 records", TuneRows.ROWS.size(), 52)
	for id in place:
		if String(id).begins_with("secret-"):
			_t.check("%s is rare" % id, bool(TuneRows.row(id)["rare"]))
	_t.check("the Lost Tape's hint names the Cable Reach", "Cable Reach" in String(TuneRows.row("secret-lost-tape")["where"]))
	_t.check("the Brindle remix's hint says sometimes", String(TuneRows.row("secret-brindle-swing")["where"]).begins_with("Sometimes"))
	_t.eq("a landmark pack is its record over the roam under it", TuneRows.key_of({"mode": "play", "track": "level", "zone": "1-1", "pack": "landmark-spillway-dam"}), "landmark-spillway-dam")
	_t.eq("a remix replacing Brindle's opening is its record", TuneRows.key_of({"mode": "play", "track": "brindle", "section": "1", "zone": "1-2", "pack": "secret-brindle-swing"}), "secret-brindle-swing")
	_t.eq("the shop pack wins over the lounge mask", TuneRows.key_of({"mode": "play", "track": "level", "lounge": true, "zone": "1-1", "pack": "moss-shop"}), "moss-shop")
	_t.eq("the miniboss pack is the Heavyweight record", TuneRows.key_of({"mode": "play", "track": "level", "zone": "2-1", "pack": "miniboss"}), "miniboss")
	_t.eq("an unknown zone is no record", TuneRows.key_of({"mode": "play", "track": "level", "zone": "9-9"}), "")
	_t.eq("a stopped level (menu mode) is no roam record", TuneRows.key_of({"mode": "idle", "track": "level", "zone": "1-1"}), "")


func _ear() -> void:
	var ear := TuneEar.new()
	var found := []
	for i in 30:
		var id := ear.listen("roam-1-1" if i % 10 < 9 else "roam-1-2", 0.4)
		if id != "":
			found.append(id)
	_t.eq("a tune that never holds 4 s is not found", found, [])
	for i in 11:
		var id := ear.listen("roam-1-1", 0.4)
		if id != "":
			found.append(id)
	_t.eq("a tune held 4 s is found once", found, ["roam-1-1"])
	ear.listen("title", 1.0)
	var later := ""
	for i in 20:
		later += ear.listen("roam-1-1", 1.0)
	_t.eq("a found tune stays quiet", later, "")
	ear.knows("title")
	var again := ""
	for i in 10:
		again += ear.listen("title", 1.0)
	_t.eq("a tune the profile holds is never reported", again, "")


func _profile() -> void:
	DirAccess.make_dir_recursive_absolute(STORE_DIR)
	var path := STORE_DIR.path_join("profile.json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var a := Profile.new(path)
	a.load_profile()
	_t.eq("a new profile holds no tunes", a.tune_ids(), [])
	_t.check("hearing a tune the first time is news", a.hear_tune("roam-2-1"))
	_t.check("hearing it again is not", not a.hear_tune("roam-2-1"))
	_t.check("the profile saves its tunes", a.save(), a.last_error)
	var b := Profile.new(path)
	b.load_profile()
	_t.check("a reload keeps the tune", b.has_tune("roam-2-1"))
	var c := Profile.new(path)
	c.load_profile()
	b.hear_tune("boss-mind")
	b.save()
	c.hear_tune("lounge")
	c.save()
	var d := Profile.new(path)
	d.load_profile()
	_t.check("two writers keep the union", d.has_tune("roam-2-1") and d.has_tune("boss-mind") and d.has_tune("lounge"), str(d.tune_ids()))
	var old := FileAccess.open(path, FileAccess.WRITE)
	old.store_string(JSON.stringify({"schema": 4, "generation": 3, "pilots": ["pylon_engineer"]}))
	old.close()
	var e := Profile.new(path)
	_t.check("a file from before the jukebox loads", e.load_profile(), e.last_error)
	_t.eq("and holds no tunes", e.tune_ids(), [])


# The ball set down in a camp station's zone, 2 m toward the plaza from its centre (camp_hub_test.gd walks them all).
func _put_in(id: String) -> void:
	var hub = _game.camp_hub
	var toward: Vector3 = hub.root.global_position - hub.zone_position(id)
	toward.y = 0.0
	var at: Vector3 = hub.zone_position(id) + toward.normalized() * 1.5
	at.y = 1.3
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	for i in 4:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= maxf(_game.get_process_delta_time(), 1.0 / 120.0)


func _render(audio, frames := 8192) -> void:
	audio.engine.render(frames)


# The game's own audio path (no device): _pump hands the band over before each block,
# which a bare engine.render never does.
func _pump_for(audio, frames: int) -> void:
	var until: int = audio.engine.clock + frames
	while audio.engine.clock < until:
		audio._pump(mini(4096, until - audio.engine.clock))


func _rms(buf: PackedVector2Array, minus := PackedVector2Array()) -> float:
	if buf.is_empty():
		return 0.0
	var sum := 0.0
	for i in buf.size():
		sum += (buf[i] - (minus[i] if i < minus.size() else Vector2.ZERO)).length_squared()
	return sqrt(sum / buf.size())


func _oggs_in(dir: String) -> int:
	var n := 0
	for file in DirAccess.get_files_at(dir):
		n += 1 if file.ends_with(".ogg") else 0
	for sub in DirAccess.get_directories_at(dir):
		n += _oggs_in(dir.path_join(sub))
	return n


# With the recorded music on disk (Andrew's PC; the Oggs are gitignored), a record plays the
# ACE take and the synth band hands over to it. Without the Oggs this part is skipped.
func _ace(audio) -> void:
	if _oggs_in("res://assets/music_ace") == 0:
		print("jukebox_tunes_test: ACE part skipped (no Oggs under res://assets/music_ace)")
		return
	_game.tuning.set_option(preload("res://src/movement/tuning.gd").MUSIC_KEY, "ace")
	_t.check("ACE: roam-1-1 spins", audio.spin("roam-1-1"))
	_pump_for(audio, 44100 * 2)
	_t.check("ACE: the recorded take plays", audio.ace_playing() and audio.ace.mode == "level", audio.ace_missing)
	# Two seconds is well past sound_from + STOP_RAMP: the synth band is muted and silent
	# under the take, and the take itself sounds, so the hand-over leaves no hole.
	var band_rms := _rms(audio.engine.out_music, audio.engine.out_landmark)
	var heard_rms := _rms(audio.out_music)
	_t.check("ACE: the synth band hands over", audio.engine.band_muted and audio._band_fade_start >= 0 and audio.engine.clock >= audio._band_fade_start + AceSequencer.STOP_RAMP, "muted=%s fade_start=%d clock=%d" % [audio.engine.band_muted, audio._band_fade_start, audio.engine.clock])
	_t.check("ACE: the synth band is silent under the take", band_rms < 0.0001, "band rms %.5f" % band_rms)
	_t.check("ACE: the take is heard", heard_rms > 0.01, "music rms %.5f" % heard_rms)
	_t.check("ACE: warden-1-1 spins", audio.spin("warden-1-1"))
	_render(audio, 44100)
	_t.check("ACE: the Warden take plays", audio.ace_playing() and audio.ace.mode == "warden")
	for id in ["brindle-p2-furnace", "euro-mind-final", "champion-hype", "landmark-spillway-dam", "secret-lost-tape"]:
		if MusicRows.resolve(id)["ace_manifest"] != "":
			_t.check("ACE: %s spins" % id, audio.spin(id))
			_render(audio, 44100)
			_t.eq("ACE: %s is what the ear hears" % id, TuneRows.key_of(audio.music_state()), id)
	audio.stop_spin()
	_render(audio, 44100 * 2)
	_t.check("ACE: the title take comes back", audio.ace_playing() and audio.ace.mode == "menu")


func _run() -> void:
	await _frames(3)
	var audio = _game.presentation.audio
	audio.bake_now()
	await _frames(2)
	var profile = _game.ctx.profile
	var screens = _game.screens
	var hud = _game.hud

	# The title theme heard at the title: filed, saved, announced once.
	_render(audio, 4096)
	_t.eq("the band plays the title at the title", audio.engine.track, "title")
	await _settle(TuneEar.HOLD + 1.0)
	_t.check("the title theme is filed after 4 s", profile.has_tune("title"), str(profile.tune_ids()))
	var reread := Profile.new(profile.path)
	reread.load_profile()
	_t.check("and saved", reread.has_tune("title"))
	var plate: Array = hud.tune_waiting() + hud.ach_toasts()
	_t.check("and announced on the record plate", plate.any(func(t): return String(t).begins_with("Lights On")), str(plate))
	await _settle(1.0)
	# The radio's b-side earned by hearing the title shares the name's opening; it has its own plate.
	var count: int = (hud.tune_waiting() + hud.ach_toasts()).filter(func(t): return String(t).begins_with("Lights On") and not String(t).contains("On the radio")).size()
	_t.eq("once", count, 1)

	# Seed two more records so the crate has a pick.
	profile.hear_tune("roam-1-1")
	profile.hear_tune("boss-brindle")

	# Camp, then J.
	_game._screen_key(KEY_K)
	_t.check("K opens the camp", screens.camp_open())
	_game._screen_key(KEY_J)
	_t.check("J outside the jukebox's zone opens nothing", not screens.jukebox_open())
	await _put_in("jukebox")
	_t.check("the jukebox station shows its prompt", _game.camp_hub.card_for("jukebox") != null)
	_game._screen_key(KEY_J)
	_t.check("J opens the jukebox", screens.jukebox_open() and not screens.walk_live())
	var page = screens.jukebox_page()
	var shelved := TuneRows.ids().filter(func(id): return not TuneRows.shut(id, _game.ctx.profile)).size()
	_t.eq("the jukebox counts found records", page._count.text, "3 / %d" % shelved)
	_t.eq("a blank sleeve reads ???", page.sleeve("boss-mind").text, "???")
	page.sleeve("boss-mind").grab_focus()
	await _frames(1)
	_t.check("a blank sleeve's note is its hint", page.note_text().ends_with(TuneRows.row("boss-mind")["where"]), page.note_text())
	_game._screen_key(KEY_SPACE)
	_t.eq("a blank record does not play", audio.spinning, "")
	_t.check("Space on the jukebox never launches", _game.flow.state_name() == "title")

	page.sleeve("roam-1-1").grab_focus()
	await _frames(1)
	_t.check("a found sleeve's note is its sleeve line", page.note_text().ends_with(TuneRows.row("roam-1-1")["sleeve"]), page.note_text())
	_game._screen_key(KEY_SPACE)
	_t.eq("Space plays the focused record", audio.spinning, "roam-1-1")
	_t.eq("the band cuts to its track", [audio.engine.track, audio.engine.mode, audio.engine.theme],
		["level", MusicEngine.PLAY, MusicRows.stage_theme("1-1")])
	_t.eq("the deck shows it", page.deck.record.get("id", ""), "roam-1-1")
	_t.eq("the play button reads Stop", page.play_button.text, "Stop")
	_game._screen_key(KEY_1)
	_t.eq("1 turns the dial to idle", audio.spin_detent, 0)
	_t.check("and the band reads it", float(audio.engine.parameter_source.call()["threat"]) < 0.2)
	_game._screen_key(KEY_3)
	_t.eq("3 turns it to full tilt", audio.spin_detent, 2)
	_t.check("the dial button shows it", page.detent_button(2).button_pressed and not page.detent_button(0).button_pressed)
	var before: Array = profile.tune_ids()
	audio.engine.force_track("warden", 0)
	await _settle(TuneEar.HOLD + 0.5)
	_t.eq("nothing is found while a record spins", profile.tune_ids(), before)
	page.sleeve("boss-mind").grab_focus()
	_game._screen_key(KEY_SPACE)
	_t.eq("Space on a blank sleeve lifts the needle", audio.spinning, "")
	page.sleeve("roam-1-1").grab_focus()
	page.play_button.pressed.emit()
	_t.eq("the Play button plays the focused record", audio.spinning, "roam-1-1")
	_t.eq("and keeps focus on the sleeve", page.focused_id(), "roam-1-1")
	_game._screen_key(KEY_SPACE)
	_t.eq("Space again lifts the needle", audio.spinning, "")
	page.sleeve("boss-brindle").grab_focus()
	_game._screen_key(KEY_SPACE)
	_t.eq("a boss record plays its fight", [audio.spinning, audio.engine.track], ["boss-brindle", "brindle"])
	_game._screen_key(KEY_J)
	_t.check("J goes back to the camp walk", screens.walk_live() and not screens.jukebox_open())
	_t.eq("and lifts the needle", audio.spinning, "")
	_render(audio, 44100)
	_t.eq("the title theme comes back", [audio.engine.track, audio.engine.mode], ["title", MusicEngine.IDLE])
	_t.check("the run parameters come back", audio.engine.parameter_source == Callable(audio, "sample_run_parameters"))

	# Every source kind plays its own track.
	for id in ["summary-loss", "warden-2-2", "lounge", "roam-3-2", "boss-mind", "miniboss"]:
		_t.check("%s spins" % id, audio.spin(id))
		_render(audio, 44100 * 2)
		var row: Dictionary = TuneRows.row(id)
		_t.eq("%s is what the ear would hear" % id, TuneRows.key_of(audio.music_state().merged({"zone": String(row["source"].get("zone", "1-1"))}, true)), id)
	_t.check("a recorded-only record spins", audio.spin("brindle-p2-furnace"))
	_t.eq("its boss stands in on the synth", audio.engine.track, "brindle")
	for id in ["landmark-sinkhole", "event-dust-squall", "secret-highdraft-rain"]:
		_t.check("%s spins" % id, audio.spin(id))
		var zone := String(TuneRows.row(id)["source"]["zone"])
		_t.eq("%s plays its zone's roam on the synth" % id, [audio.engine.track, audio.engine.theme], ["level", MusicRows.stage_theme(zone)])
	_t.check("a remix of a boss spins", audio.spin("secret-brindle-swing"))
	_t.eq("and the boss stands in", audio.engine.track, "brindle")
	audio.spin("secret-after-hours")
	_render(audio, 44100)
	_t.check("the bay's B-side masks the band like the lounge", audio.engine.lounge)
	audio.spin("lounge")
	_render(audio, 44100 * 2)
	_t.check("the lounge record masks the band", audio.engine.lounge)
	audio.stop_spin()
	_render(audio, 44100 * 2)
	_t.check("stopping it never leaves the mask on", not audio.engine.lounge and audio.engine.track == "title")
	_ace(audio)

	# Moss's B-side is a first-win secret (secrets.gd, PR #97): shut, it has no sleeve, no count
	# and no flip; open, it is an ordinary hidden record. With no secrets.gd nothing is shut.
	var b_side := "secret-after-hours"
	var fresh := Profile.new()
	if not ResourceLoader.exists(TuneRows.SECRETS):
		_t.check("without secrets.gd the B-side is never shut", not TuneRows.shut(b_side, fresh))
	else:
		var secrets = load(TuneRows.SECRETS)
		_t.eq("the secret tune is the B-side", String(secrets.TUNE), b_side)
		_t.check("a fresh profile has the B-side shut", TuneRows.shut(b_side, fresh))
		_t.check("the sitting opens it", not TuneRows.shut(b_side, fresh, true))
		_t.check("nothing else is shut", TuneRows.ids().all(func(id): return id == b_side or not TuneRows.shut(id, fresh)))
		var shut_read: Dictionary = page.reading(fresh)
		_t.eq("shut, the B-side leaves the crate and the count", [b_side in shut_read["shown"], shut_read["total"]], [false, TuneRows.ROWS.size() - 1])
		var saved = _game.ctx.profile
		_game.ctx.profile = fresh
		audio._moments.clear()
		audio.jukebox_flipped()
		_t.check("shut, flipping Moss's jukebox starts no B-side", not audio._moments.any(func(m): return m.id == b_side))
		page.refresh(fresh)
		_t.check("shut, its sleeve is hidden", not page.sleeve(b_side).visible)
		_game.ctx.profile = saved
		audio._moments.clear()
		page.refresh(saved)
	var opened: int = audio._moments.size()
	if not TuneRows.shut(b_side, _game.ctx.profile):
		audio.jukebox_flipped()
		_t.check("open, flipping Moss's jukebox starts the B-side", audio._moments.any(func(m): return m.id == b_side))
		audio.jukebox_flipped()
		_t.eq("and flipping it back ends it", audio._moments.size(), opened)
		_t.check("open, its sleeve shows", page.sleeve(b_side).visible)

	# A run taking the title while a record spins gets the music back.
	_game._screen_key(KEY_J)
	_t.check("the jukebox reopens", screens.jukebox_open())
	page.sleeve("roam-1-1").grab_focus()
	_game._screen_key(KEY_SPACE)
	_t.eq("a record spins", audio.spinning, "roam-1-1")
	_game.flow.press_start()
	await _frames(2)
	_t.check("leaving the title releases the deck", audio.spinning == "" and not screens.jukebox_open(), "spinning %s, flow %s" % [audio.spinning, _game.flow.state_name()])
	_t.check("and the run parameters", audio.engine.parameter_source == Callable(audio, "sample_run_parameters"))

	_game.free()
	quit(_t.verdict())
