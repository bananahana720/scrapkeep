extends RefCounted

# The shift board: what a player's first world 1 runs open, in the order a new player meets
# them, and the time card that makes every finished run move one mark (design-v3/FIRST-HOUR.md).
# It stands at the camp's trophy wall. Pure reads of the profile: a rung is stamped when its
# grant row is earned (or its tune heard), so the board never stores a stamp of its own and a
# profile that earned a row before the board existed shows it stamped. The time card is the one
# number it adds, the profile stat PUNCH_STAT.
#
# A rung:
# name   3 words or fewer, the stamp's caption
# text   what to do, 12 words or fewer, shown while it is the next rung
# when   exactly one of {"earned": achievements.gd row id} or {"tune": tune_rows.gd id}
# stamp  the word inked on the board when it lands (HIRED for a pilot, LOGGED for a mark or an item)
# pays   what it opens, for the board's words only: {"pilot"|"cosmetic"|"item"|"tune"|"option": id}.
#        The grant itself is the achievement row's reward, so the two must agree (validate).
# pilot  optional: the pilot whose mark this is; the board shows it only once that pilot is open
#
# Items opened here join the run's offer pool on the next run (Parts.opened_items, set at
# run_started by game.gd). They are rows the park table does not list, so a fresh profile's
# pool and every bot run stay exactly as they were.

const Achievements := preload("res://src/core/achievements.gd")
const Items := preload("res://src/build/items.gd")
const ClassDef := preload("res://src/core/class_def.gd")

const FIELDS := ["name", "text", "when", "stamp", "pays", "pilot"]
const PAY_KINDS := ["pilot", "cosmetic", "item", "tune", "option"]
const STAMPS := ["CLOCKED IN", "LOGGED", "HIRED", "FOUND"]
const NAME_WORDS := 3
const TEXT_WORDS := 12
const PUNCH_STAT := "shift.punches"

const RUNGS := {
	"clock_in": {"name": "Clocked In", "text": "Finish your first shift, however it ends.",
		"when": {"earned": "ach_d7_salt_skip"}, "stamp": "CLOCKED IN", "pays": {"cosmetic": "trail_salt_skip"}},
	"first_warden": {"name": "Warden Breaker", "text": "Break a Warden's core in the Spillway.",
		"when": {"earned": "warden_broken"}, "stamp": "LOGGED", "pays": {"cosmetic": "paint_any_night"}},
	"rivet_freed": {"name": "Rivet Freed", "text": "Find the cage on the dam and ram it open.",
		"when": {"earned": "rivet_rescued"}, "stamp": "HIRED", "pays": {"pilot": "runner_gunner"}},
	"lost_tape": {"name": "Lost Tape", "text": "Something by the flume weir still plays. Find it.",
		"when": {"tune": "secret-lost-tape"}, "stamp": "FOUND", "pays": {"tune": "secret-lost-tape"}},
	"brindle_routed": {"name": "Brindle Routed", "text": "Rout Admiral Brindle in the Slag Bowl.",
		"when": {"earned": "brindle_routed"}, "stamp": "HIRED", "pays": {"pilot": "tarn"}},
	"mark_sable": {"name": "Sable's Mark", "text": "Rout Brindle flying Sable.", "pilot": "pylon_engineer",
		"when": {"earned": "brindle_mark_sable"}, "stamp": "LOGGED", "pays": {"item": "strike_pocket"}},
	"mark_rivet": {"name": "Rivet's Mark", "text": "Rout Brindle flying Rivet.", "pilot": "runner_gunner",
		"when": {"earned": "brindle_mark_rivet"}, "stamp": "LOGGED", "pays": {"item": "clean_break"}},
	"mark_tarn": {"name": "Tarn's Mark", "text": "Rout Brindle flying Tarn.", "pilot": "tarn",
		"when": {"earned": "brindle_mark_tarn"}, "stamp": "LOGGED", "pays": {"item": "warhead_slug"}},
	"mark_kest": {"name": "Kest's Mark", "text": "Rout Brindle flying Kest.", "pilot": "demolitions_caster",
		"when": {"earned": "brindle_mark_kest"}, "stamp": "LOGGED", "pays": {"item": "ring_wave"}},
	"mark_tally": {"name": "Tally's Mark", "text": "Rout Brindle flying Tally.", "pilot": "tally",
		"when": {"earned": "brindle_mark_tally"}, "stamp": "LOGGED", "pays": {"item": "salvage_drone"}},
	"mark_cannon": {"name": "Cannon's Mark", "text": "Rout Brindle flying the Cannon.", "pilot": "remembered_cannon",
		"when": {"earned": "brindle_mark_cannon"}, "stamp": "LOGGED", "pays": {"item": "scrap_geyser"}},
}

# The time card. A finished run (won or lost, never abandoned) that stamps no rung and broke at
# least min_kills machines punches one hole; every holes punches pays the next card, in order.
# A card pays an item into the pool, the same way a mark does. Past the last card the card keeps
# punching and pays nothing, and the board says so.
const TIME_CARD := {"holes": 3, "min_kills": 5}
const CARDS := [
	{"name": "First Card", "pays": {"item": "spring_hull"}},
	{"name": "Second Card", "pays": {"item": "shock_liner"}},
	{"name": "Third Card", "pays": {"item": "rebound_skin"}},
]

# Seeds for the layered variation that comes after the world 1 core (Andrew, 23 Oct: stage
# variants, run modifiers and unlock-gated anticipation in the spirit of Isaac's variant floors).
# ShiftVariants (src/core/shift_variants.gd) asks open_seeds() which are open and plays only the
# built ones. Each names the rung that opens it, so the player sees it coming on the board.
# A seed shows to the player only once its variant or modifier is built (Andrew, 12 Nov 2026, card on
# W1-72): a teaser for something stamping the rung would not deliver is a broken promise.
# kind   stage_variant or run_modifier
# gate   the rung id that opens it
# text   what it would be, 12 words or fewer
const SEED_KINDS := ["stage_variant", "run_modifier"]
const SEEDS := {
	"dam_night_shift": {"kind": "stage_variant", "gate": "brindle_routed",
		"text": "The dam at night has floodlights, a fuller crew, one more cage."},
	"flume_backwash": {"kind": "stage_variant", "gate": "mark_rivet",
		"text": "The flume runs backwards, and the weir becomes the drop-in."},
	"overtime": {"kind": "run_modifier", "gate": "first_warden",
		"text": "Overtime wakes Wardens one tick early and pays one more panel."},
	"crew_short": {"kind": "run_modifier", "gate": "mark_sable",
		"text": "Short crew means no dam shop and a cache instead."},
}


static func ids() -> Array:
	return RUNGS.keys()


static func rung(id: String) -> Dictionary:
	return RUNGS.get(id, {})


static func stamped(id: String, profile) -> bool:
	if profile == null or not RUNGS.has(id):
		return false
	var when: Dictionary = RUNGS[id]["when"]
	if when.has("earned"):
		return profile.earned(String(when["earned"]))
	return profile.has_tune(String(when["tune"]))


static func stamped_ids(profile) -> Array:
	return RUNGS.keys().filter(func(id): return stamped(id, profile))


# A mark row for a pilot the profile cannot fly yet stays off the board, so a new player sees
# only the marks they can chase. The sitting opens every pilot, and the caller says so.
static func shown(id: String, profile, sitting := false) -> bool:
	var pilot := String(RUNGS[id].get("pilot", ""))
	if pilot == "" or sitting:
		return true
	var def = ClassDef.by_id(pilot)
	return (def != null and def.starter) or (profile != null and profile.has_pilot(pilot))


# The first shown rung not yet stamped, in table order, or "" when the board is full.
static func next_rung(profile, sitting := false) -> String:
	for id in RUNGS:
		if shown(id, profile, sitting) and not stamped(id, profile):
			return id
	return ""


static func punches(profile) -> int:
	return int(profile.stat(PUNCH_STAT)) if profile != null else 0


static func cards_paid(profile) -> int:
	return mini(punches(profile) / int(TIME_CARD["holes"]), CARDS.size())


# Holes on the card in hand: 0 to holes - 1, or holes once every card has paid.
static func holes_on_card(profile) -> int:
	if cards_paid(profile) >= CARDS.size():
		return int(TIME_CARD["holes"])
	return punches(profile) % int(TIME_CARD["holes"])


# Every item the board has opened for this profile: stamped marks and paid cards, board order.
static func opened_items(profile) -> Array:
	var out: Array = []
	for id in RUNGS:
		var item := String(RUNGS[id]["pays"].get("item", ""))
		if item != "" and stamped(id, profile):
			out.append(item)
	for i in cards_paid(profile):
		out.append(String(CARDS[i]["pays"]["item"]))
	return out


# Every item the board could ever open, board order.
static func all_items() -> Array:
	var out: Array = []
	for id in RUNGS:
		var item := String(RUNGS[id]["pays"].get("item", ""))
		if item != "":
			out.append(item)
	for card in CARDS:
		out.append(String(card["pays"]["item"]))
	return out


static func open_seeds(profile) -> Array:
	return SEEDS.keys().filter(func(id): return stamped(String(SEEDS[id]["gate"]), profile))


# What a finished run did to the board, as one line for the summary: the rungs it stamped, else
# the hole it punched, else why it did neither. before is stamped_ids at run_started.
static func run_line(before: Array, profile, punched: bool) -> String:
	var fresh: Array = stamped_ids(profile).filter(func(id): return not id in before)
	if not fresh.is_empty():
		return _deeds_sentence(fresh)
	if punched:
		var holes := int(TIME_CARD["holes"])
		if cards_paid(profile) >= CARDS.size() and punches(profile) > holes * CARDS.size():
			return "Time card punched. Every card is paid, and the clerk punches it anyway."
		var on_card := holes_on_card(profile)
		if on_card == 0 or on_card == holes:
			var card: Dictionary = CARDS[cards_paid(profile) - 1]
			return "Time card full. %s pays %s next shift." % [String(card["name"]), item_name(String(card["pays"]["item"]))]
		return "Time card punched, %d of %d." % [on_card, holes]
	return ""


# The rungs a run stamped, as a plain sentence for the summary: what the player did, by the rungs'
# own names, in board order. Clocked In is the first finished shift and is not a deed to list.
static func _deeds_sentence(ids: Array) -> String:
	var deeds := PackedStringArray()
	for id in ids:
		if id != "clock_in":
			deeds.append(String(RUNGS[id]["name"]))
	var clocked: bool = "clock_in" in ids
	if deeds.is_empty():
		return "You clocked in. Your first shift is on the shift board."
	var list := deeds[0] if deeds.size() == 1 else "%s and %s" % [", ".join(deeds.slice(0, deeds.size() - 1)), deeds[deeds.size() - 1]]
	return "You %smarked off %s on the shift board." % ["clocked in and " if clocked else "", list]


# The board as the camp shows it: the stamp count, the next rung's name and words, and the card.
static func reading(profile, sitting := false) -> Dictionary:
	var shown_ids: Array = RUNGS.keys().filter(func(id): return shown(id, profile, sitting))
	var done: Array = shown_ids.filter(func(id): return stamped(id, profile))
	var next := next_rung(profile, sitting)
	var out := {"stamped": done.size(), "shown": shown_ids.size(), "next": next, "next_name": "", "next_text": "",
		"next_pays": "", "holes": holes_on_card(profile), "holes_max": int(TIME_CARD["holes"]),
		"card_next": "", "items_open": opened_items(profile).size()}
	if next != "":
		out["next_name"] = String(RUNGS[next]["name"])
		out["next_text"] = String(RUNGS[next]["text"])
		out["next_pays"] = pays_words(RUNGS[next]["pays"])
	if cards_paid(profile) < CARDS.size():
		out["card_next"] = item_name(String(CARDS[cards_paid(profile)]["pays"]["item"]))
	return out


static func pays_words(pays: Dictionary) -> String:
	for kind in pays:
		var id := String(pays[kind])
		match kind:
			"item":
				return "%s can turn up in runs" % item_name(id)
			"pilot":
				return "Signs on a pilot"
			"cosmetic":
				return "A new look"
			"tune":
				return "A record for the jukebox"
			"option":
				return "A head start"
	return ""


static func item_name(id: String) -> String:
	var parts = load("res://src/build/parts.gd")
	var row: Dictionary = parts.row(id)
	return String(row.get("name", id))


static func _words(s: String) -> int:
	return s.split(" ", false).size()


# rows: rungs. grants: achievement rows. tunes: tune ids. Returns the problems, empty when sound.
static func validate(rows: Dictionary, grants: Dictionary, tunes: Array) -> Array:
	var problems: Array = []
	var items_seen := {}
	for id in rows:
		var r: Dictionary = rows[id]
		for key in r:
			if not FIELDS.has(key):
				problems.append("%s: unknown field %s" % [id, key])
		if _words(String(r.get("name", ""))) < 1 or _words(String(r.get("name", ""))) > NAME_WORDS:
			problems.append("%s: name must be 1 to %d words" % [id, NAME_WORDS])
		if _words(String(r.get("text", ""))) < 1 or _words(String(r.get("text", ""))) > TEXT_WORDS:
			problems.append("%s: text must be 1 to %d words" % [id, TEXT_WORDS])
		if not STAMPS.has(String(r.get("stamp", ""))):
			problems.append("%s: stamp %s is not one of %s" % [id, r.get("stamp", ""), STAMPS])
		var when = r.get("when", {})
		if not (when is Dictionary) or when.size() != 1:
			problems.append("%s: when must carry exactly one of earned or tune" % id)
			continue
		var pays = r.get("pays", {})
		if not (pays is Dictionary) or pays.size() != 1 or not PAY_KINDS.has(pays.keys()[0]):
			problems.append("%s: pays must carry exactly one of %s" % [id, PAY_KINDS])
			continue
		var kind: String = pays.keys()[0]
		var target := String(pays[kind])
		if when.has("earned"):
			var grant := String(when["earned"])
			if not grants.has(grant):
				problems.append("%s: earned row %s is not an achievement" % [id, grant])
			elif kind != "tune":
				var reward: Dictionary = grants[grant].get("reward", {})
				if String(reward.get(kind, "")) != target:
					problems.append("%s: pays %s %s but %s rewards %s" % [id, kind, target, grant, reward])
		elif when.has("tune"):
			if not tunes.has(String(when["tune"])):
				problems.append("%s: tune %s is not a jukebox row" % [id, when["tune"]])
		else:
			problems.append("%s: when key %s is unknown" % [id, when.keys()[0]])
		if kind == "item":
			if not Items.TABLE.has(target):
				problems.append("%s: item %s is not an items.gd row" % [id, target])
			elif items_seen.has(target):
				problems.append("%s: item %s is already opened by %s" % [id, target, items_seen[target]])
			else:
				items_seen[target] = id
	for card in CARDS:
		var item := String(card.get("pays", {}).get("item", ""))
		if not Items.TABLE.has(item):
			problems.append("card %s: item %s is not an items.gd row" % [card.get("name", ""), item])
		elif items_seen.has(item):
			problems.append("card %s: item %s is already opened by %s" % [card.get("name", ""), item, items_seen[item]])
		else:
			items_seen[item] = String(card.get("name", ""))
	for grant in grants:
		var reward = grants[grant].get("reward", {})
		if not (reward is Dictionary) or not reward.has("item"):
			continue
		var item := String(reward["item"])
		if not Items.TABLE.has(item):
			problems.append("%s: reward item %s is not an items.gd row" % [grant, item])
		elif not rows.keys().any(func(r): return rows[r].get("when", {}).get("earned", "") == grant):
			problems.append("%s: pays item %s but no rung reads it, so the item could never show" % [grant, item])
	for item in items_seen:
		var row: Dictionary = Items.TABLE[item]
		if row.has("class") or row.has("needs"):
			problems.append("%s: an opened item must suit every pilot and need no seam" % item)
	for id in SEEDS:
		var s: Dictionary = SEEDS[id]
		if not SEED_KINDS.has(String(s.get("kind", ""))):
			problems.append("seed %s: kind must be one of %s" % [id, SEED_KINDS])
		if not rows.has(String(s.get("gate", ""))):
			problems.append("seed %s: gate %s is not a rung" % [id, s.get("gate", "")])
		if _words(String(s.get("text", ""))) > TEXT_WORDS:
			problems.append("seed %s: text must be %d words or fewer" % [id, TEXT_WORDS])
	return problems
