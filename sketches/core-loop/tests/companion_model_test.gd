extends SceneTree

# The SPIL-9 companion data model: acquire, assemble rules, serialization, table check.

const Companion := preload("res://src/core/companion.gd")

var fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b


func _initialize() -> void:
	var c := Companion.new()
	_check(c.acquire("primer_coil"), "acquire known")
	_check(c.sockets.is_empty(), "acquire leaves sockets empty")
	_check(not c.acquire("nope"), "unknown id refused")
	_check(not c.acquire("primer_coil"), "duplicate refused")
	_check(c.owned.size() == 1, "refusals add nothing")
	c.acquire("ram_prow")
	c.acquire("escape_vent")
	c.acquire("primer_mesh")

	_check(c.assemble(["primer_coil", "ram_prow"]) == "", "two families assemble")
	var first := c.sockets.duplicate()
	c.unassemble()
	_check(c.assemble(["ram_prow", "primer_coil"]) == "", "reverse order assembles")
	_check(c.sockets == first, "either order, same set")
	_check(c.has_family("ram_brace") and not c.has_family("escape_corridor"), "has_family")
	_check(Companion.family_of("escape_vent") == "escape_corridor", "family_of")

	c.unassemble()
	_check(c.assemble(["primer_coil", "primer_mesh"]) != "", "duplicate family refused")
	_check(c.assemble(["primer_coil", "ram_prow", "escape_vent"]) != "", "third piece refused")
	_check(c.assemble(["primer_coil", "ram_spring"]) != "", "unowned piece refused")
	_check(c.assemble(["primer_coil", "primer_coil"]) != "", "same piece twice refused")
	_check(c.sockets.is_empty(), "refusals leave sockets empty")

	c.assemble(["primer_coil", "escape_vent"])
	c.unassemble()
	_check(c.sockets.is_empty() and c.owned.size() == 4, "unassemble keeps owned")

	c.assemble(["ram_prow", "escape_vent"])
	c.spend_escape()
	var parsed = JSON.parse_string(JSON.stringify(c.to_dict()))
	var r := Companion.new()
	_check(typeof(parsed) == TYPE_DICTIONARY and r.from_dict(parsed), "round trip loads")
	_check(_sorted(r.owned) == _sorted(c.owned) and r.sockets == c.sockets, "round trip arrays")
	_check(r.escape_spent() and not r.escape_ready(), "round trip flag")
	_check(typeof(r.owned) == TYPE_ARRAY and r.owned.size() == 4, "owned size int")

	var before := r.to_dict()
	var bads := [
		{}, {"chassis": "spil9", "owned": "x", "sockets": [], "escape_ready": true},
		{"chassis": "spil9", "owned": [1], "sockets": [], "escape_ready": true},
		{"chassis": "spil9", "owned": ["ram_prow"], "sockets": [], "escape_ready": 1},
		{"chassis": "spil9", "owned": ["ram_prow", "ram_spring"], "sockets": ["ram_prow", "ram_spring"], "escape_ready": true},
		{"chassis": "spil9", "owned": [], "sockets": ["ram_prow", "escape_vent"], "escape_ready": true},
		{"chassis": "other", "owned": [], "sockets": [], "escape_ready": true},
	]
	for b in bads:
		_check(not r.from_dict(b), "bad dict refused: %s" % str(b))
	_check(r.to_dict() == before, "bad dicts change nothing")

	r.reset()
	_check(r.owned.is_empty() and r.sockets.is_empty() and not r.escape_spent() and not r.escape_ready(), "reset")

	_check(Companion.validate().is_empty(), "shipped table valid: %s" % str(Companion.validate()))
	var bad := [
		{"id": "a", "family": "ram_brace", "name": "One", "effect": "x"},
		{"id": "a", "family": "bogus", "name": "Far Too Many Words Here", "effect": ""},
	]
	_check(Companion.validate(bad).size() >= 3, "bad fixture flagged")

	print("companion_model_test: PASS" if fails == 0 else "companion_model_test: FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
