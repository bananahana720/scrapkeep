extends SceneTree

# Rule: world-one zones carry typed required slots; seeded optional placements
# use their own sites, repeat for a seed, and never mutate authored map positions.
const ZoneSchema := preload("res://src/world/zone_schema.gd")
const ZoneSeed := preload("res://src/world/zone_seed.gd")
const Spillway := preload("res://src/world/map_spillway.gd")
const Reach := preload("res://src/world/map_reach.gd")

var _failures := 0


func _initialize() -> void:
	var spillway := Spillway.new()
	var reach := Reach.new()
	for map in [spillway, reach]:
		_report(map.title + " validates", ZoneSchema.validate(map).is_empty(), str(ZoneSchema.validate(map)))
		_check_fill(map)
	_check_bay(spillway, reach)
	_check_doubles()
	print("zone_schema_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _check_bay(spillway, reach) -> void:
	var props := Node3D.new()
	spillway.build_props(props, func(x: float, z: float, clearance: float) -> Vector3:
		return Vector3(x, clearance, z))
	var benches := []
	for body in props.get_children():
		if not body is StaticBody3D:
			continue
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D and child.shape.size == Vector3(26.0, 3.0, 9.0):
				benches.append({"at": Vector2(body.position.x, body.position.z)})
	_report("Spillway bay means built launch benches", ZoneSchema.slots(spillway)["bay"] == benches, str(benches))
	_report("Reach bay means workshop gate row", ZoneSchema.slots(reach)["bay"] == reach.gate_slots, str(reach.gate_slots))
	props.free()


func _check_fill(map) -> void:
	var before := _position_hash(map)
	var first := ZoneSeed.fill(map, 77)
	var again := ZoneSeed.fill(map, 77)
	_report(map.title + " same seed", first == again, "two fills with seed 77 are equal")
	_report(map.title + " filled schema", ZoneSchema.validate(first).is_empty(), str(ZoneSchema.validate(first)))
	var own_positions := []
	for row in map.activity_sites:
		own_positions.append(row["at"])
	for row in map.sites.values():
		own_positions.append(row["ring"])
	var own: bool = first.has("activity_sites") and not first["activity_sites"].is_empty() \
		and first.has("hard_points") and not first["hard_points"].is_empty() and first.has("relic_spot")
	if own:
		for row in first["activity_sites"] + first["hard_points"]:
			own = own and row["at"] in own_positions
		own = own and first["relic_spot"] in own_positions
	_report(map.title + " own sites only", own, "all optional positions belong to this map")
	var varied := false
	for seed in range(78, 94):
		if ZoneSeed.fill(map, seed) != first:
			varied = true
	_report(map.title + " seeds can vary", varied, "at least one seed 78..93 differs from 77")
	_report(map.title + " authored activities", map.activity_sites.is_empty() or first["activity_sites"] == map.activity_sites,
		"nonempty authored activities are preserved")
	first["bay"][0]["at"] = Vector2(900.0, 900.0)
	first["activity_sites"][0]["at"] = Vector2(901.0, 901.0)
	first["hard_points"][0]["at"] = Vector2(902.0, 902.0)
	_report(map.title + " unchanged position hash", before == _position_hash(map),
		"map hash unchanged after fills and nested result edits: %s" % before)
	_report(map.title + " results do not alias", ZoneSeed.fill(map, 77) == again,
		"editing one returned dictionary changes neither the map nor later fills")


# Hash raw authored positions, not just the adapter's output.
func _position_hash(map) -> String:
	var positions := {}
	for id in ZoneSchema.REQUIRED + ZoneSchema.OPTIONAL + ["sites", "gate_slots"]:
		if ZoneSchema.has_field(map, id):
			positions[id] = ZoneSchema.field(map, id)
	return var_to_bytes(positions).hex_encode().sha256_text()


func _check_doubles() -> void:
	var valid := {"spawn": Vector2.ZERO, "beacon": Vector2(1.0, 2.0), "vault": Vector2(3.0, 4.0),
		"bay": [{"at": Vector2(5.0, 6.0)}]}
	var missing := valid.duplicate(true)
	missing.erase("beacon")
	_report("missing beacon", ZoneSchema.validate(missing) == ["beacon"], str(ZoneSchema.validate(missing)))
	for id in ZoneSchema.REQUIRED:
		var absent := valid.duplicate(true)
		absent.erase(id)
		_report("missing " + id + " only", ZoneSchema.validate(absent) == [id], str(ZoneSchema.validate(absent)))
		var wrong := valid.duplicate(true)
		wrong[id] = "wrong type"
		var issues := ZoneSchema.validate(wrong)
		_report(id + " wrong type", issues.size() == 1 and issues[0].begins_with(id + ":"), str(issues))
	var nested := valid.duplicate(true)
	nested["bay"] = [{"at": Vector3.ZERO}]
	nested["activity_sites"] = [{"id": "cache", "at": Vector3.ZERO}]
	nested["hard_points"] = [{"at": "wrong type"}]
	nested["relic_spot"] = Vector3.ZERO
	var issues := ZoneSchema.validate(nested)
	_report("nested and optional types", issues.size() == 4, str(issues))
	var empty_bay := valid.duplicate(true)
	empty_bay["bay"] = []
	_report("bay must carry a position", not ZoneSchema.validate(empty_bay).is_empty(), str(ZoneSchema.validate(empty_bay)))
	var authored := valid.duplicate(true)
	authored["activity_sites"] = [{"id": "cache", "at": Vector2(8.0, 9.0)}]
	authored["hard_points"] = [{"at": Vector2(10.0, 11.0)}]
	authored["relic_spot"] = Vector2(12.0, 13.0)
	var before := _position_hash(authored)
	_report("authored optional slots preserved", ZoneSeed.fill(authored, 77) == authored, str(ZoneSeed.fill(authored, 77)))
	_report("dictionary map unchanged", before == _position_hash(authored), before)
	_report("no sites invents no positions", ZoneSeed.fill(valid, 77) == valid, "an empty candidate set leaves optional slots absent")
	var ordered := valid.duplicate(true)
	ordered["sites"] = {"b": {"ring": Vector2(1.0, 1.0)}, "a": {"ring": Vector2(2.0, 2.0)}}
	var reversed := valid.duplicate(true)
	reversed["sites"] = {"a": {"ring": Vector2(2.0, 2.0)}, "b": {"ring": Vector2(1.0, 1.0)}}
	_report("site insertion order does not affect seed", ZoneSeed.fill(ordered, 77) == ZoneSeed.fill(reversed, 77),
		"candidate ids and positions have a stable order")
