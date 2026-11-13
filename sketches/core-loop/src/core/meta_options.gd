extends RefCounted

# Between-run head starts (SG12; comps gunfire/run-pacing-and-economy "meta-options-tree"
# and roboquest/stage-anatomy "secret-reward-unlocks-later"). A node is a small option, a
# discovery or a pocket key that persists across runs; none adds combat power (BIBLE.md:475,
# :586) and none is bought (BIBLE.md:513 bars invented prices), so a row carries no price,
# cost or stat key. Each node opens when its one grant row in achievements.gd is earned; that
# row pays {"option": <node id>} or, since no screen shows a node (systems audit pass D, row 31),
# one cosmetic, and asks for a one-run accomplishment with a count of
# MAX_GRANT_COUNT or below. The level is the number of nodes opened, so any short session that
# meets one grant moves the bar.
#
# name    3 words or fewer
# text    what the node gives, 12 words or fewer
# kind    one of KINDS
# effect  the id a run reads to apply the head start (the run side is a later unit's)
# grant   the achievements.gd row that opens it

const KINDS := ["option", "discovery", "pocket_key"]
const FIELDS := ["name", "text", "kind", "effect", "grant"]
# Words no key may hold at any depth of a row (P-UNITS B5; W13-INTEGRATION-3 section 6
# items 4 and 5 keep currencies, starting cogs and discounts with Andrew).
const BANNED_KEY_WORDS := ["price", "cost", "stat", "discount", "cogs", "currency"]
# Start value: the largest count a grant may ask for (comps ror2/progression-and-music
# "unlocks-as-lessons": no new lifetime count above 10).
const MAX_GRANT_COUNT := 10
const NAME_WORDS := 3
const TEXT_WORDS := 12

const ROWS := {
	"spare_reroll": {"name": "Spare Reroll", "text": "One extra reroll at each shelf.",
		"kind": "option", "effect": "extra_reroll", "grant": "ach_meta_spare_reroll"},
	"shelf_preview": {"name": "Shelf Preview", "text": "See the next shelf's offers before you reach it.",
		"kind": "option", "effect": "shelf_preview", "grant": "ach_meta_shelf_preview"},
	# Roboquest's secret key, as Scrapkeep's: the hidden pocket pays a key for later runs.
	"pocket_key": {"name": "Pocket Key", "text": "Sealed pockets open for you on later runs.",
		"kind": "pocket_key", "effect": "pocket_key", "grant": "ach_meta_pocket_key"},
	"pocket_tint": {"name": "Pocket Tint", "text": "A seen pocket door tints its zone on the map.",
		"kind": "discovery", "effect": "pocket_tint", "grant": "ach_meta_pocket_tint"},
}


static func ids() -> Array:
	return ROWS.keys()


static func row(id: String) -> Dictionary:
	return ROWS.get(id, {})


# Opens every node whose grant row the profile has earned. Memory only; save() writes.
# Returns the ids opened by this call, in table order.
static func open_earned(profile) -> Array:
	var out: Array = []
	for id in ROWS:
		if profile.earned(String(ROWS[id]["grant"])) and profile.open_option(id):
			out.append(id)
	return out


# Nodes opened, counting only ids that are rows.
static func level(profile) -> int:
	return ROWS.keys().filter(func(id): return profile.has_option(id)).size()


static func _words(s: String) -> int:
	return s.split(" ", false).size()


static func _keys(value, out: Array) -> Array:
	if value is Dictionary:
		for key in value:
			out.append(String(key).to_lower())
			_keys(value[key], out)
	elif value is Array:
		for item in value:
			_keys(item, out)
	return out


# rows: node rows. grants: achievement rows (Achievements.ROWS in the game).
static func validate(rows: Dictionary, grants: Dictionary) -> Array:
	var problems: Array = []
	var granted := {}
	for id in rows:
		var r = rows[id]
		if not (r is Dictionary):
			problems.append("%s: row must be a dictionary" % id)
			continue
		for key in r:
			if not FIELDS.has(key):
				problems.append("%s: unknown field %s" % [id, key])
		for key in _keys(r, []):
			for word in BANNED_KEY_WORDS:
				if key.contains(word):
					problems.append("%s: key %s names a %s" % [id, key, word])
		var title := str(r.get("name", ""))
		if title == "" or _words(title) > NAME_WORDS:
			problems.append("%s: name must be 1 to %d words" % [id, NAME_WORDS])
		var text := str(r.get("text", ""))
		if text == "" or _words(text) > TEXT_WORDS:
			problems.append("%s: text must be 1 to %d words" % [id, TEXT_WORDS])
		if not KINDS.has(r.get("kind", "")):
			problems.append("%s: kind %s is not one of %s" % [id, r.get("kind", ""), KINDS])
		if not (r.get("effect") is String) or String(r.get("effect")) == "":
			problems.append("%s: effect must be an id" % id)
		var grant := str(r.get("grant", ""))
		var g = grants.get(grant)
		if not (g is Dictionary):
			problems.append("%s: grant %s is not an achievement row" % [id, grant])
			continue
		# The grant may pay this node or, since no screen shows a node (systems audit pass D,
		# row 31), one cosmetic a player sees; open_earned reads the grant, not the reward.
		var reward = g.get("reward", {})
		if reward != {"option": id} and not (reward is Dictionary and reward.size() == 1 and reward.has("cosmetic")):
			problems.append("%s: grant %s must pay {\"option\": \"%s\"} or one cosmetic" % [id, grant, id])
		if not (g.get("count", 0) is int) or int(g.get("count", 0)) < 1 or int(g["count"]) > MAX_GRANT_COUNT:
			problems.append("%s: grant %s count must be 1 to %d" % [id, grant, MAX_GRANT_COUNT])
		if g.has("sum"):
			problems.append("%s: grant %s adds up a sum, not a one-run count" % [id, grant])
		granted[grant] = id
	for grant in grants:
		var reward = grants[grant].get("reward", {}) if grants[grant] is Dictionary else {}
		if reward is Dictionary and reward.has("option"):
			var target := str(reward["option"])
			if not rows.has(target):
				problems.append("%s: option reward %s is not a node row" % [grant, target])
			elif granted.get(grant, "") != target:
				problems.append("%s: pays node %s but is not that node's grant" % [grant, target])
	return problems
