extends RefCounted

const PhaseMusic := preload("res://src/presentation/phase_music.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")

# The place-and-moment tunes (design-v3/sound/tunes.json). Pure decisions: audio.gd reports
# what happened (a landmark in reach, an event, the bay, a find) and asks which tune the level
# band plays now; it does the playing. Ids are tunes.json's, so the camp jukebox reads the
# same names. A tune's pack is assets/music_ace/<id with underscores>, a MusicRows row, and a
# tune whose pack is not on disk is never chosen, so the band keeps what it plays.

const RATE := 44100
# One pass of a flat pack, in bars: a find plays its tune once through and then hands back.
const FIND_BARS := 16
# The chance, rolled once per run for each, that a rare remix replaces its parent's music.
const REMIX_CHANCE := 0.1
# Landmark reach as the band's approach parameter (1 at the landmark, 0 at the drop-in): the
# tune comes in at LANDMARK_IN and leaves below LANDMARK_OUT, so a ball on the line holds it.
const LANDMARK_IN := 0.8
const LANDMARK_OUT := 0.7

# The kinds of moment, highest first wins; a tie goes to the newest.
const PRIORITY := {"miniboss": 5, "event": 4, "find": 4, "jukebox": 3, "fabricator": 2, "shop": 2, "landmark": 1}
# Kinds that play one pass of their tune and hand back; another trigger restarts the pass.
const ONE_PASS := ["find", "fabricator"]
# Kinds that do not begin while a Warden's fight has the band: the one-pass tunes and an event's.
const NOT_IN_A_FIGHT := ["find", "fabricator", "event"]

# Every row of tunes.json: its hook, the key the hook reports, and its bpm.
const TUNES := {
	"landmark-spillway-dam": {"hook": "landmark", "key": "spillway_dam", "bpm": 172},
	"landmark-penstock": {"hook": "landmark", "key": "penstock_tower", "bpm": 129},
	"landmark-headframe": {"hook": "landmark", "key": "headframe", "bpm": 172},
	"landmark-sinkhole": {"hook": "landmark", "key": "sinkhole", "bpm": 129},
	"landmark-hanging-isle": {"hook": "landmark", "key": "hanging_isle", "bpm": 172},
	"landmark-crown-spire": {"hook": "landmark", "key": "crown_spire", "bpm": 129},
	"event-scrap-stampede": {"hook": "event", "key": "scrap_stampede", "bpm": 150},
	"event-surge-run": {"hook": "event", "key": "surge_run", "bpm": 150},
	"event-hold-relay": {"hook": "event", "key": "hold_the_relay", "bpm": 140},
	"event-flood": {"hook": "event", "key": "flood", "bpm": 140},
	"event-dust-squall": {"hook": "event", "key": "dust_squall", "bpm": 145},
	"event-arena": {"hook": "activity", "keys": ["arena", "round_arena"], "bpm": 145},
	"miniboss": {"hook": "miniboss", "key": "miniboss", "bpm": 140},
	# The rogue fleet machines' own anthems, keyed by rogue kind (audio.gd picks them by Rogue.ROWS).
	"anthem-gate-crane": {"hook": "miniboss", "key": "rogue_crane", "bpm": 140},
	"anthem-haul-skip": {"hook": "miniboss", "key": "rogue_skip", "bpm": 145},
	"anthem-cable-tender": {"hook": "miniboss", "key": "rogue_tender", "bpm": 150},
	# Phase two of each mini-boss anthem (ruling 23 Oct): audio moves tune X to "X-heavy" on the next downbeat.
	"anthem-gate-crane-heavy": {"hook": "miniboss", "key": "rogue_crane_heavy", "bpm": 150},
	"anthem-haul-skip-heavy": {"hook": "miniboss", "key": "rogue_skip_heavy", "bpm": 155},
	"anthem-cable-tender-heavy": {"hook": "miniboss", "key": "rogue_tender_heavy", "bpm": 160},
	"miniboss-heavy": {"hook": "miniboss", "key": "miniboss_heavy", "bpm": 150},
	"moss-shop": {"hook": "shop", "key": "bay", "bpm": 112},
	"fabricator": {"hook": "fabricator", "key": "fabricator_used", "bpm": 120},
	"camp-course": {"hook": "", "bpm": 172},
	"modifier-curse": {"hook": "modifier", "key": "curse", "bpm": 100},
	"modifier-par": {"hook": "modifier", "key": "par", "bpm": 176},
	"secret-lost-tape": {"hook": "find", "keys": ["reach_pressure_cache", "flume_weir_cache", "spillway_shift_radio", "spillway_crew_radio"], "bpm": 90},
	"secret-after-hours": {"hook": "jukebox", "key": "bay_jukebox", "bpm": 96},
	"secret-brindle-swing": {"hook": "remix", "key": "brindle", "bpm": 160},
	"secret-chip-keepers": {"hook": "remix", "key": "champion", "bpm": 150},
	"secret-highdraft-rain": {"hook": "remix", "key": "3-1", "bpm": 86},
	"secret-dig-dub": {"hook": "remix", "key": "2-2", "bpm": 140},
}

# The tunes with no game hook yet, and the hook each one needs.
const UNWIRED := {
	"camp-course": "a camp movement-course area; the camp is a menu page today (ui/camp_menu.gd)",
}
# event-arena is wired to the in-run arena activities; its camp half needs a camp arena area.
const PARTLY_WIRED := {"event-arena": "a camp arena area for its camp half"}


static func theme_of(id: String) -> String:
	return PhaseMusic.theme_of(id)


static func manifest_of(id: String) -> String:
	return PhaseMusic.manifest_of(id)


# Whether the tune's pack plays: its manifest and every stem it names are on disk. The Oggs
# are not committed, so a checkout with the manifest alone keeps the band it has.
static var _available := {}


static func available(id: String) -> bool:
	if not _available.has(id):
		_available[id] = _pack_on_disk(id)
	return _available[id]


static func _pack_on_disk(id: String) -> bool:
	return TUNES.has(id) and MusicRows.pack_on_disk(manifest_of(id))


static func is_hidden(id: String) -> bool:
	return id.begins_with("secret-")


# The tune a hook's key starts, "" for none.
static func tune_for(hook: String, key: String) -> String:
	for id in TUNES:
		var row: Dictionary = TUNES[id]
		if row.hook == hook and (row.get("key", "") == key or key in row.get("keys", [])):
			return id
	return ""


static func landmark_tune(landmark_id: String) -> String:
	return tune_for("landmark", landmark_id)


static func event_tune(event_id: String) -> String:
	return tune_for("event", event_id)


static func activity_tune(activity_id: String) -> String:
	return tune_for("activity", activity_id)


static func find_tune(discovery_id: String) -> String:
	return tune_for("find", discovery_id)


# Whether the landmark tune holds at this approach: in at LANDMARK_IN, out below LANDMARK_OUT,
# never once the Warden is engaged (its fight takes the band).
static func landmark_holds(approach: float, holding: bool, engaged: bool) -> bool:
	if engaged:
		return false
	return approach >= (LANDMARK_OUT if holding else LANDMARK_IN)


# One pass of the tune's pack, in transport samples.
static func pass_frames(id: String) -> int:
	var bpm := float(TUNES.get(id, {}).get("bpm", 120))
	return roundi(FIND_BARS * 4 * 60.0 / bpm * RATE)


# A moment: {"id", "kind", "key", "seq"}. The one the band plays: the highest priority whose
# pack loads, the newest on a tie; "" when none does.
static func top(moments: Array, avail: Callable) -> String:
	var best := {}
	for m in moments:
		if not avail.call(String(m.id)):
			continue
		if best.is_empty() or _outranks(m, best):
			best = m
	return String(best.get("id", ""))


static func _outranks(a: Dictionary, b: Dictionary) -> bool:
	var pa := int(PRIORITY.get(a.kind, 0))
	var pb := int(PRIORITY.get(b.kind, 0))
	return pa > pb or (pa == pb and int(a.seq) > int(b.seq))


# The rare remixes this run: {slot: tune id} for each one whose roll came up. Rolled once at
# run start, in TUNES order, so a seeded rng gives the same run every time.
static func roll_remixes(rng: RandomNumberGenerator, chance := REMIX_CHANCE) -> Dictionary:
	var out := {}
	for id in TUNES:
		if TUNES[id].hook == "remix" and rng.randf() < chance:
			out[String(TUNES[id].key)] = id
	return out


# What a slot plays this run: its remix when rolled and on disk, else the parent it was given.
static func remixed(slot: String, parent: String, remixes: Dictionary, avail: Callable) -> String:
	var id := String(remixes.get(slot, ""))
	if id != "" and avail.call(id):
		return id
	return parent


# The tune that replaces a stage's own band, "" for its own: a run modifier's tune first, then
# the stage's rolled remix.
static func stage_tune(zone: String, modifiers: Array, remixes: Dictionary, avail: Callable) -> String:
	for modifier in modifiers:
		var id := tune_for("modifier", String(modifier))
		if id != "" and avail.call(id):
			return id
	return remixed(zone, "", remixes, avail)
