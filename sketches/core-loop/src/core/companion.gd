extends RefCounted

# The SPIL-9 companion as pure data: one hover chassis, two unordered module sockets, and
# any two different families. Pieces are found in runs and acquired without equipping;
# assemble() runs at intermission. Effects are text only here; nothing reads this in play
# yet. The escape corridor acts after a survived low-hull hit, never revives and never
# spends or refills a retry; the ready/spent flag is what the body and chirp cues will show.

const CHASSIS := "spil9"
const SOCKETS := 2
const CONDUCTIVE_PRIMER := "conductive_primer"
const RAM_BRACE := "ram_brace"
const ESCAPE_CORRIDOR := "escape_corridor"
const FAMILIES := [CONDUCTIVE_PRIMER, RAM_BRACE, ESCAPE_CORRIDOR]
const MAX_NAME_WORDS := 3

const PIECES := [
	{"id": "primer_coil", "family": CONDUCTIVE_PRIMER, "name": "Primer Coil",
		"effect": "Primes struck foes so the next arc hits harder."},
	{"id": "primer_mesh", "family": CONDUCTIVE_PRIMER, "name": "Conductive Mesh",
		"effect": "Primed foes pass a share of arc damage to neighbours."},
	{"id": "ram_prow", "family": RAM_BRACE, "name": "Ram Prow",
		"effect": "Ram hits stagger what they strike."},
	{"id": "ram_spring", "family": RAM_BRACE, "name": "Brace Spring",
		"effect": "A ram buffs your next shot after landing."},
	{"id": "escape_vent", "family": ESCAPE_CORRIDOR, "name": "Escape Vent",
		"effect": "After a survived low-hull hit, opens a short escape lane once."},
	{"id": "escape_rail", "family": ESCAPE_CORRIDOR, "name": "Corridor Rail",
		"effect": "After a survived low-hull hit, shoves nearby foes clear once."},
]

var owned: Array[String] = []
var sockets: Array[String] = []
var escape_ready := true


static func _row(id: String) -> Dictionary:
	for p in PIECES:
		if p["id"] == id:
			return p
	return {}


static func family_of(id: String) -> String:
	return String(_row(id).get("family", ""))


func has_family(family: String) -> bool:
	for id in sockets:
		if family_of(id) == family:
			return true
	return false


# Adds a found piece to the pile. Never equips. Refuses unknown ids and duplicates.
func acquire(id: String) -> bool:
	if _row(id).is_empty() or owned.has(id):
		return false
	owned.append(id)
	return true


# Returns "" on success or the refusal reason. Exactly two owned pieces of two different
# families, in either order; the socket set is stored in table order so order never shows.
func assemble(ids: Array) -> String:
	if ids.size() != SOCKETS:
		return "needs exactly %d pieces" % SOCKETS
	for id in ids:
		if typeof(id) != TYPE_STRING or _row(id).is_empty():
			return "unknown piece"
		if not owned.has(id):
			return "piece not owned: %s" % id
	if ids[0] == ids[1]:
		return "same piece twice"
	if family_of(ids[0]) == family_of(ids[1]):
		return "needs two different families"
	var next: Array[String] = []
	for p in PIECES:
		if ids.has(p["id"]):
			next.append(p["id"])
	sockets = next
	escape_ready = true
	return ""


func unassemble() -> void:
	sockets.clear()


func reset() -> void:
	owned.clear()
	sockets.clear()
	escape_ready = true


# Problems in the PIECES table, empty when it is sound.
static func validate(table: Array = PIECES) -> Array:
	var problems := []
	var seen := {}
	var per_family := {}
	for p in table:
		var id := String(p.get("id", ""))
		if id == "" or seen.has(id):
			problems.append("bad or duplicate id: %s" % id)
		seen[id] = true
		var fam := String(p.get("family", ""))
		if not FAMILIES.has(fam):
			problems.append("%s: family not in FAMILIES" % id)
		per_family[fam] = int(per_family.get(fam, 0)) + 1
		var words := String(p.get("name", "")).strip_edges().split(" ", false).size()
		if words < 1 or words > MAX_NAME_WORDS:
			problems.append("%s: name must be 1 to %d words" % [id, MAX_NAME_WORDS])
		if String(p.get("effect", "")).strip_edges() == "":
			problems.append("%s: missing effect text" % id)
	if table == PIECES:
		for f in FAMILIES:
			if int(per_family.get(f, 0)) < 2:
				problems.append("%s: needs at least two pieces" % f)
	return problems


func to_dict() -> Dictionary:
	return {"chassis": CHASSIS, "owned": owned.duplicate(), "sockets": sockets.duplicate(),
		"escape_ready": escape_ready}


# Loads a saved dict. False, with nothing changed, when any field is the wrong type or
# names a piece that does not exist, or the sockets break the assembly rule.
func from_dict(d: Dictionary) -> bool:
	if d.get("chassis", "") != CHASSIS or typeof(d.get("escape_ready")) != TYPE_BOOL:
		return false
	var o: Array[String] = []
	var s: Array[String] = []
	for pair in [["owned", o], ["sockets", s]]:
		var src = d.get(pair[0])
		if typeof(src) != TYPE_ARRAY:
			return false
		for id in src:
			if typeof(id) != TYPE_STRING or _row(id).is_empty() or pair[1].has(id):
				return false
			pair[1].append(id)
	for id in s:
		if not o.has(id):
			return false
	if not s.is_empty():
		if s.size() != SOCKETS or family_of(s[0]) == family_of(s[1]):
			return false
	owned = o
	sockets = s
	escape_ready = d["escape_ready"]
	return true
