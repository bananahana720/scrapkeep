extends SceneTree

# A new enemy kind is wired in several tables beside its roster row. This test names what a
# kind is missing, so adding one is a list to finish, not a hunt (BACKLOG.md "World 1 and
# scaling backlog", SG-05). Every director kind (Director.KIND_NAMES) must be a built roster
# row with a chassis row, a director card and a windup row, and a telegraph record unless its
# roster row says it never attacks (telegraph -1). Every built roster kind must be a director
# kind, apart from the kinds that never arrive in a pack.
#
# KIND_NAMES stays a hand-kept list: arrivals store a kind as its index in it, so its order is
# frozen and a list derived from the roster could reorder it.

const T := preload("res://tests/support/t.gd")
const Director := preload("res://src/world/director.gd")
const Roster := preload("res://src/combat/roster.gd")
const DirectorCards := preload("res://src/world/director_cards.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const TelegraphRecord := preload("res://src/combat/telegraph_record.gd")

# Built roster kinds that never arrive in a pack, so the director does not list them.
const NOT_PACK_KINDS := ["miniboss", "vault", "warden", "splitter_pod"]
# Known gaps, each "kind/table". The list must stay exact: a gap that is filled fails here
# until its line is removed.
const KNOWN_GAPS := [
	# World 3 kinds (Highdraft) with no chassis row yet; world 3 is parked until after the
	# world 1 sitting (ruling at).
	"ballast_heavy/chassis", "gap_net/chassis",
]

var _t := T.new("kind_wiring_test")


func _initialize() -> void:
	var gaps: Array = []
	for kind in Director.KIND_NAMES:
		if not Roster.ROWS.has(kind):
			gaps.append("%s/roster" % kind)
			continue
		if not Roster.built(kind):
			gaps.append("%s/script" % kind)
		if not Roster.CHASSIS.has(kind):
			gaps.append("%s/chassis" % kind)
		if not DirectorCards.CARDS.has(kind):
			gaps.append("%s/card" % kind)
		if not WindupRows.ROWS.has(kind):
			gaps.append("%s/windup" % kind)
		if int(Roster.row(kind).get("telegraph", -1)) >= 0 and TelegraphRecord.id_of(kind) == "":
			gaps.append("%s/telegraph" % kind)
	var new_gaps := gaps.filter(func(g): return not KNOWN_GAPS.has(g))
	var filled := KNOWN_GAPS.filter(func(g): return not gaps.has(g))
	_t.eq("every director kind is wired in each table", new_gaps, [])
	_t.eq("every known gap is still a gap (remove a filled one)", filled, [])
	var unlisted: Array = []
	for kind in Roster.ROWS:
		if Roster.built(kind) and not Director.KIND_NAMES.has(kind) and not NOT_PACK_KINDS.has(kind):
			unlisted.append(kind)
	_t.eq("every built roster kind is a director kind or a known non-pack kind", unlisted, [])
	var stale := NOT_PACK_KINDS.filter(func(k): return not Roster.ROWS.has(k) or Director.KIND_NAMES.has(k))
	_t.eq("every non-pack kind is a roster row the director does not list", stale, [])
	var seen := {}
	var twice: Array = []
	for kind in Director.KIND_NAMES:
		if seen.has(kind):
			twice.append(kind)
		seen[kind] = true
	_t.eq("no director kind is listed twice", twice, [])
	quit(_t.verdict())
