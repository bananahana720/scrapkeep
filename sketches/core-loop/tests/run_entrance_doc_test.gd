extends SceneTree

const RunState := preload("res://src/core/run_state.gd")
const Companion := preload("res://src/core/companion.gd")

# The entrance document (RS1): a pure, versioned Dictionary that round-trips through JSON.

var _failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: ", what)


func _populated() -> RunState:
	var r := RunState.new(null)
	r.run_id = "1760000000-004242"
	r.run_seed = 123456789
	r._loaded_class_id = "rivet"
	r.stage = 5
	r.world = 2
	r.max_hp = 120.0
	r.hp = 87.5
	r.mass = 431.25
	r.scrap = 77
	r._heft_class = 2
	r._wear_accum = 0.375
	r.bonus_cores = 1
	r.class_rewarded = 2
	r.parts.assign(["plate", "coil", "plate", "arm"])
	r.kills = 19
	r.events_won.assign(["vault_a", "crane"])
	r.run_time = 301.125
	r.retries = 3
	r.tree_picks.assign(["a1", "b2"])
	r.tree_allowed = 3
	r.retries_spent = {1: 2, 2: 1}
	r.cogs = 14
	r.companion = _companion_doc()
	r.snapshot(Vector3(1.5, -2.25, 3.125), Vector3(0.1, 0.2, -30.5), 1.75)
	return r


func _companion_doc() -> Dictionary:
	var piece: String = Companion.PIECES[0]["id"]
	return {"chassis": Companion.CHASSIS, "owned": [piece], "sockets": [piece], "escape_ready": true, "escape_spent": false}


func _initialize() -> void:
	# (a) JSON round trip. The companion is a real one: a restore sanitizes it (Companion.sanitize),
	# so a made-up shape would come back empty.
	var a := _populated()
	var doc_a := a.to_entrance_doc()
	_check(RunState.validate_entrance_doc(doc_a) == "", "fresh doc validates: " + RunState.validate_entrance_doc(doc_a))
	var parsed = JSON.parse_string(JSON.stringify(doc_a))
	var b := RunState.new(null)
	_check(b.from_entrance_doc(parsed), "round trip applies")
	_check(b.to_entrance_doc() == doc_a, "round trip doc equals original")
	_check(b.parts == a.parts and b.parts == (["plate", "coil", "plate", "arm"] as Array[String]), "parts order kept")
	_check(b.stage == 5 and typeof(b.stage) == TYPE_INT, "stage int")
	_check(typeof(b.scrap) == TYPE_INT and b.scrap == 77, "scrap int")
	_check(typeof(b.run_seed) == TYPE_INT and b.run_seed == 123456789, "seed int")
	_check(typeof(b.retries_spent.keys()[0]) == TYPE_INT and b.retries_spent == {1: 2, 2: 1}, "retries_spent int keys and values")
	_check(b.snapshot_value("entry_position") == Vector3(1.5, -2.25, 3.125), "entry position exact")
	_check(b.snapshot_value("entry_velocity") == Vector3(0.1, 0.2, -30.5), "entry velocity exact")
	_check(b.class_id() == "rivet" and b.cogs == 14 and b.companion == _companion_doc(), "class, cogs, companion")
	_check(b.tree_picks == (["a1", "b2"] as Array[String]) and b.tree_allowed == 3, "tree picks")

	# (b) a wrong-typed field is rejected and nothing changes.
	var c := _populated()
	var before := JSON.stringify(c.to_entrance_doc())
	var bad := doc_a.duplicate(true)
	bad["hp"] = "full"
	bad["kills"] = 500
	_check(RunState.validate_entrance_doc(bad).contains("hp"), "bad hp named")
	_check(not c.from_entrance_doc(bad), "wrong-typed doc rejected")
	_check(JSON.stringify(c.to_entrance_doc()) == before, "live state unchanged after rejection")

	# (c) newer schema.
	var newer := doc_a.duplicate(true)
	newer["schema"] = 99
	var msg := RunState.validate_entrance_doc(newer)
	_check(msg.contains("schema") and msg.contains("99"), "schema 99 named: " + msg)
	_check(not c.from_entrance_doc(newer), "schema 99 rejected")
	_check(JSON.stringify(c.to_entrance_doc()) == before, "live state unchanged after schema reject")

	# (d) merge by max.
	var d := RunState.new(null)
	d.retries_spent = {1: 3, 2: 1}
	d.merge_retries_spent({1: 2, 2: 4, 3: 1})
	_check(d.retries_spent == {1: 3, 2: 4, 3: 1}, "merge takes max per world")
	d.merge_retries_spent({})
	d.merge_retries_spent({"1": 0, "2": 2})
	_check(d.retries_spent == {1: 3, 2: 4, 3: 1}, "merge never decreases")

	# (e) absent cogs and companion.
	var e_doc := doc_a.duplicate(true)
	e_doc.erase("cogs")
	e_doc.erase("companion")
	var e := _populated()
	_check(e.from_entrance_doc(e_doc), "doc without cogs and companion applies")
	_check(e.cogs == 0 and e.companion == {}, "absent cogs and companion restore as 0 and {}")

	# (f) unknown key survives.
	var f_doc = JSON.parse_string(JSON.stringify(doc_a))
	f_doc["future_thing"] = {"n": 1, "list": ["q"]}
	var f := RunState.new(null)
	_check(f.from_entrance_doc(f_doc), "doc with unknown key applies")
	_check(f.extra.has("future_thing") and f.extra["future_thing"]["list"] == ["q"], "unknown key in extra")
	var again = JSON.parse_string(JSON.stringify(f.to_entrance_doc()))
	_check(again.has("future_thing") and again["future_thing"]["n"] == 1, "unknown key survives round trip")

	print("run_entrance_doc_test: PASS" if _failures == 0 else "run_entrance_doc_test: FAIL (%d)" % _failures)
	quit(1 if _failures > 0 else 0)
