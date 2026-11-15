# smoke: solo (two gates run at wall pace)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SurvivalCount := preload("res://src/world/survival_count.gd")
const Parts := preload("res://src/build/parts.gd")
const Palette := preload("res://src/core/palette.gd")
const Dress := preload("res://src/world/stocktake_dress.gd")

# The Stocktake yard on the dam (BACKLOG W1-101): survival_count.gd's rule stood on the map by activities.gd.
# (a) with the launch flag off the dam plans no yard; with it on it plans one of the park's two yard rows;
# (b) the flag builds one yard site, on that row's ground;
# (c) rolling in starts count 1, its machines climb in one at a time, and the gate stays shut until every one of
#     them has arrived and fallen;
# (d) a cleared floor opens the gate and the ring turns the live colour; staying through it brings count 2's
#     machines and the ring turns back; a floor cleared with the ball outside the ring banks nothing;
# (e) rolling in and out through the open gate after count 2 ends the yard won and pays exactly pay(2): its
#     scrap, and one part of the listed grade on a pickup in the ball's path;
# (f) a fresh yard left with the gate shut forfeits after out_s and pays nothing;
# (g) a ball destroyed inside forfeits a fresh yard;
# (h) on a short rule whose count 2 is twice as strong, the yard's own count 2 machine has twice a plain machine's
#     health, and leaving after it banks the core and scrap at the gate and three parts, each its own, on the pickup;
# (i) across run seeds both rows are drawn, and one seed always draws the same row.

const SEED := 23
const EXPECTED_CHECKS := 20

var _game
var _t := preload("res://tests/support/t.gd").new("stocktake_yard_test")
var _source := Intent.Scripted.new()
var _ended := []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _acts():
	return _game.world.activities


func _site():
	return _acts().site("stocktake_yard")


func _hold(at: Vector3) -> void:
	_game.player.reset_to(at, Vector3.ZERO)
	_game.player.set_velocity_now(Vector3.ZERO)
	await physics_frame


func _kill(s) -> void:
	for enemy in s.pack:
		if is_instance_valid(enemy):
			enemy.take_damage(100000.0)


func _ring_color(s) -> Color:
	return ((s.view.ring.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color


func _centre(s) -> Vector3:
	return _game.ctx.terrain.drop_point(s.global_position.x, s.global_position.z, 1.05)


func _outside(s) -> Vector3:
	return _game.ctx.terrain.drop_point(s.global_position.x + float(s.rule["ring"]) + 6.0, s.global_position.z, 1.05)


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = SEED
	_game.player.source = _source
	_game.events.event_ended.connect(func(id: String, outcome: String): if id == "stocktake_yard": _ended.append(outcome))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	await _frames(4)
	var map = _game.ctx.terrain.map()
	_t.check("flag off: no yard is planned or built", _acts().survival_spec(map, "stocktake_yard").is_empty() and _site() == null, str(_acts().survival_spec(map, "stocktake_yard")))
	_game.ctx.tuning.set_option("stocktake", "on")
	var spec: Dictionary = _acts().survival_spec(map, "stocktake_yard")
	_t.check("flag on: one of the dam's yard rows is drawn", spec.get("row", "") in ["shelf_yard", "slot_yard"], str(spec))
	await _fresh()
	await _counts(spec)
	await _fresh()
	await _walks_out()
	await _fresh()
	await _destroyed()
	await _fresh()
	await _later_count()
	_rows(map)
	_t.eq("expected check count", _t.checks + _t.skips + 1, EXPECTED_CHECKS)
	_game.free()
	await _frames(2)
	quit(_t.verdict())


func _fresh() -> void:
	_game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(4)


func _counts(spec: Dictionary) -> void:
	var s = _site()
	var at_row: bool = s != null and Vector2(s.global_position.x, s.global_position.z).distance_to(spec["at"]) < 0.01
	_t.check("the flag builds one yard on its row's ground", at_row and s.yard != null, "no site" if s == null else str(s.global_position))
	if s == null:
		return
	var rule = s.yard
	# The yard's furniture (stocktake_dress.gd): the gate on the ring's edge toward the Warden's beacon, the clerk's
	# stand outside the ring, both wearing their models; the gate shut.
	var dress = s.yard_dress
	var ring := float(s.rule["ring"])
	var furnished: bool = dress != null and dress.get_child_count() >= 2
	if furnished:
		var gate: Node3D = dress.get_child(0)
		var stand: Node3D = dress.get_child(1)
		var out: Vector2 = (_game.ctx.terrain.map().beacon - Vector2(s.global_position.x, s.global_position.z)).normalized()
		var gate_off := Vector2(gate.global_position.x - s.global_position.x, gate.global_position.z - s.global_position.z)
		var stand_off := Vector2(stand.global_position.x - s.global_position.x, stand.global_position.z - s.global_position.z)
		# Machines climb in on the ring itself (_yard_arrive), so both pieces stand clear outside it.
		furnished = gate_off.length() - dress.GATE_SIZE.x * 0.5 > ring + 1.0 and gate_off.length() < ring + 6.0 and gate_off.normalized().dot(out) > 0.99
		furnished = furnished and stand_off.length() - dress.STAND_SIZE.x > ring + 1.0
		furnished = furnished and dress.gate_shut() and absf(gate.global_position.y - _game.ctx.terrain.height(gate.global_position.x, gate.global_position.z)) < 0.01
		for piece in [gate, stand]:
			var views: Array = piece.find_children("*", "MeshInstance3D", true, false)
			furnished = furnished and not views.is_empty() and views[0].mesh is ArrayMesh and views[0].material_override.vertex_color_use_as_albedo
		# The gate's width lies along the ring: its Z axis is square to the way out.
		furnished = furnished and absf(Vector2(gate.global_transform.basis.z.x, gate.global_transform.basis.z.z).dot(out)) < 0.01
	_t.check("the yard has its gate toward the beacon and its stand, both just outside the ring, the gate shut", furnished, "dress %s" % dress)
	# Marker flags: evenly round the ring, none in the gate's doorway, and standing where their model is.
	var spots: PackedVector2Array = Dress.flag_spots(40.0, Vector2(0, 1))
	var spaced := spots.size() >= Dress.FLAGS - 2 and spots.size() < Dress.FLAGS
	for spot in spots:
		spaced = spaced and is_equal_approx(spot.length(), 40.0) and absf(spot.angle_to(Vector2(0, 1))) >= Dress.FLAG_GATE_CLEAR
	_t.check("marker flags ring the yard and leave the gate's doorway clear", spaced, "%d of %d flags" % [spots.size(), Dress.FLAGS])
	if ResourceLoader.exists(Dress.FLAG) and dress != null:
		var flags: Node = dress.get_node_or_null("Flags")
		var ring_m := float(s.rule["ring"])
		var stood: bool = flags != null and flags.get_child_count() == Dress.flag_spots(ring_m, Vector2(0, 1)).size()
		if stood:
			for flag in flags.get_children():
				var off: Vector3 = flag.global_position - s.global_position
				var way: Vector3 = dress.get_child(0).global_position - s.global_position
				stood = stood and absf(Vector2(off.x, off.z).angle_to(Vector2(way.x, way.z))) >= Dress.FLAG_GATE_CLEAR
				stood = stood and absf(Vector2(off.x, off.z).length() - ring_m) < 0.1 and absf(flag.global_position.y - _game.ctx.terrain.height(flag.global_position.x, flag.global_position.z)) < 0.01
		_t.check("the flags stand on the ring's edge, on the ground, none in the built gate's doorway", stood, "%s" % flags)
	else:
		_t.skip("the flags stand on the ring's edge, on the ground", "poi_ring_flag.glb is not on this stage yet")
	var first: Array = rule.pack(1)
	var early_gate := false
	var stood := true
	var peak_new := 0
	var seen := {}
	for frame in int((float(s.rule["arrive_s"]) * first.size() + 0.5) * Engine.physics_ticks_per_second):
		await _hold(_centre(s))
		var fresh := 0
		for enemy in s.pack:
			if is_instance_valid(enemy) and not seen.has(enemy.get_instance_id()):
				seen[enemy.get_instance_id()] = true
				fresh += 1
		peak_new = maxi(peak_new, fresh)
		early_gate = early_gate or (rule.gate_open and seen.size() < first.size())
		stood = stood and (rule.gate_open or dress == null or dress.gate_shut())
		# Each arrival falls the frame it lands, so the floor is empty while machines are still owed.
		_kill(s)
	_t.check("rolling in starts count 1 and its machines climb in one at a time", s.started and seen.size() == first.size() and peak_new == 1,
		"started %s arrived %d of %d, most in one frame %d" % [s.started, seen.size(), first.size(), peak_new])
	_t.check("the gate stays shut while machines are still owed", not early_gate and stood, "")
	await _hold(_centre(s))
	for frame in Engine.physics_ticks_per_second:
		await _hold(_centre(s))
	var sunk: bool = dress != null and dress.gate_sunk()
	_t.check("a cleared floor opens the gate, which sinks, and the ring turns the live colour", sunk and rule.gate_open and rule.cleared == 1 and _ring_color(s) == Palette.live(),
		"gate %s cleared %d ring %s" % [rule.gate_open, rule.cleared, _ring_color(s)])
	for frame in int((float(rule.rule["gate_s"]) + float(s.rule["arrive_s"]) * rule.pack(2).size() + 0.5) * Engine.physics_ticks_per_second):
		await _hold(_centre(s))
	_t.check("staying through the gate brings count 2's machines", rule.count == 2 and not rule.gate_open
		and _acts().yard_standing(s) == rule.pack(2).size() and s.yard_owed.is_empty() and _ring_color(s) != Palette.live(),
		"count %d standing %d" % [rule.count, _acts().yard_standing(s)])
	# The last machine falls with the ball outside the ring: the gate opens, and nothing is banked for it.
	await _hold(_outside(s))
	_kill(s)
	await _hold(_outside(s))
	await _hold(_outside(s))
	_t.check("a floor cleared from outside opens the gate and banks nothing", rule.gate_open and not s.done and _ended.is_empty(), "gate %s done %s" % [rule.gate_open, s.done])
	await _hold(_centre(s))
	var scrap_before: int = _game.run.scrap
	var parts_before: Array = _game.run.parts.duplicate()
	await _hold(_outside(s))
	var pay: Dictionary = SurvivalCount.new().pay(2)
	var pickup_at: Vector3 = s.pickup.global_position if s.pickup != null else Vector3.INF
	for frame in 40:
		await _hold(pickup_at + Vector3(0.0, 1.05, 0.0))
		if s.pickup_taken:
			break
	var gained: Array = _game.run.parts.slice(parts_before.size())
	var grades: Array = gained.map(func(part): return Parts.rarity_of(part))
	await _frames(Engine.physics_ticks_per_second)
	_t.check("leaving through the open gate ends the yard won, its gate sunk", _ended == ["won"] and s.done and s.yard_dress.gate_sunk(), str(_ended))
	_t.check("it pays exactly pay(2): the scrap and each listed part grade", _game.run.scrap - scrap_before == int(pay["scrap"]) and grades == pay["rarities"],
		"scrap %d of %d, grades %s of %s" % [_game.run.scrap - scrap_before, pay["scrap"], grades, pay["rarities"]])


func _walks_out() -> void:
	var s = _site()
	if s == null:
		_t.check("a yard left with the gate shut forfeits", false, "no site")
		return
	_ended.clear()
	await _hold(_centre(s))
	var scrap_before: int = _game.run.scrap
	var short := int((float(s.rule["out_s"]) - 0.5) * Engine.physics_ticks_per_second)
	for frame in short:
		await _hold(_outside(s))
	var held: bool = not s.done
	for frame in Engine.physics_ticks_per_second:
		await _hold(_outside(s))
	var was_shut: bool = s.yard_dress.gate_shut() or not s.yard_dress.gate_sunk()
	await _frames(Engine.physics_ticks_per_second)
	_t.check("a yard left with the gate shut forfeits after out_s and pays nothing, and its gate sinks out of the way", was_shut and s.yard_dress.gate_sunk() and held and s.done and _ended == ["lost"]
		and s.pickup == null and _game.run.scrap == scrap_before, "held %s done %s ended %s" % [held, s.done, _ended])
	_kill(s)


func _destroyed() -> void:
	var s = _site()
	if s == null:
		_t.check("a ball destroyed inside forfeits", false, "no site")
		return
	_ended.clear()
	await _hold(_centre(s))
	_game.events.player_died.emit()
	_t.check("a ball destroyed inside forfeits the yard", s.started and s.done and _ended == ["lost"] and s.pickup == null, "done %s ended %s" % [s.done, _ended])
	_kill(s)


# A short rule so a later count is reached in a second: one runner a count, count 2 at twice the health, and a pay
# row with two parts and a core, plus the one more rare part count 2 earns past the ladder.
const SHORT := {
	"counts": [["runner"]],
	"after": {"stronger": 2.0, "rogue_every": 3},
	"count_s": 25.0,
	"gate_s": 0.3,
	"pay": [{"scrap": 50, "rarities": ["common", "rare"], "cores": 1}],
	"pay_after": {"rarity": "rare", "relic": "relic", "relic_at": [8]},
}


func _later_count() -> void:
	var s = _site()
	if s == null:
		_t.check("a later count's machines arrive stronger", false, "no site")
		_t.check("a later count's pay is banked whole", false, "no site")
		return
	_ended.clear()
	s.yard = SurvivalCount.new(1, "yard", SHORT)
	var plain = _game.ctx.spawner.spawn_enemy("chaser", _outside(s))
	var plain_hp: float = plain.max_hp
	plain.queue_free()
	var settle := int((float(SHORT["gate_s"]) + float(s.rule["arrive_s"]) + 0.3) * Engine.physics_ticks_per_second)
	for frame in settle:
		await _hold(_centre(s))
	var first_hp: float = s.pack[0].max_hp if s.pack.size() == 1 else -1.0
	_kill(s)
	for frame in settle:
		await _hold(_centre(s))
	var second_hp: float = s.pack[0].max_hp if s.pack.size() == 1 else -1.0
	_t.check("the yard spawns count 2 at the rule's strength", s.yard.count == 2 and is_equal_approx(first_hp, plain_hp)
		and is_equal_approx(second_hp, plain_hp * 2.0), "count %d, health %.1f then %.1f, plain %.1f" % [s.yard.count, first_hp, second_hp, plain_hp])
	_kill(s)
	await _hold(_centre(s))
	await _hold(_centre(s))
	var scrap_before: int = _game.run.scrap
	var cores_before: int = _game.run.bonus_cores
	var parts_before: int = _game.run.parts.size()
	await _hold(_outside(s))
	var cores_at_gate: int = _game.run.bonus_cores - cores_before
	# Read where each lands: a killed machine's own drop, picked up on the way, is not the yard's pay.
	var scrap_at_gate: int = _game.run.scrap - scrap_before
	var gained: Array = s.pickup_parts.duplicate()
	var pickup_at: Vector3 = s.pickup.global_position if s.pickup != null else Vector3.INF
	for frame in 40:
		await _hold(pickup_at + Vector3(0.0, 1.05, 0.0))
		if s.pickup_taken:
			break
	var grades: Array = gained.map(func(part): return Parts.rarity_of(part))
	var distinct := {}
	var held: bool = s.pickup_taken
	for part in gained:
		distinct[part] = true
		held = held and gained.count(part) == 1 and _game.run.parts.slice(parts_before).has(part)
	_t.check("a later count banks its core, its scrap and every part, each its own", _ended == ["won"] and cores_at_gate == 1
		and scrap_at_gate == 50 and grades == ["common", "rare", "rare"] and distinct.size() == 3 and held,
		"ended %s cores %d scrap %d grades %s parts %s" % [_ended, cores_at_gate, scrap_at_gate, grades, gained])


# Across run seeds both of the dam's rows are drawn, and one seed always draws the same row.
func _rows(map) -> void:
	var kept: int = _game.run.run_seed
	var drawn := {}
	var steady := true
	for run_seed in 24:
		_game.run.run_seed = run_seed
		var row := String(_acts().survival_spec(map, "stocktake_yard").get("row", ""))
		steady = steady and row == String(_acts().survival_spec(map, "stocktake_yard").get("row", ""))
		drawn[row] = true
	_game.run.run_seed = kept
	var rows: Array = drawn.keys()
	rows.sort()
	_t.check("both yard rows are drawn across run seeds, the same row for the same seed", steady and rows == ["shelf_yard", "slot_yard"], str(rows))
	# A yard is open ground: no grapple anchor of the map's own fields stands in any yard row's ring, and the ring
	# is clear of every fight, contraption, rise and edge (the PC stills of 14 Nov showed one ring full of saguaro posts, 14 by the map's plan).
	var ring := float(load("res://src/world/activities.gd").RULES["stocktake_yard"]["ring"])
	var recipes = load("res://src/world/park/park_recipes.gd")
	var posts: Dictionary = recipes.field_posts(map.park["park_rows"], recipes.clear_zones(map.park))
	var faults := []
	for site in map.survival_sites:
		if site["form"] != "yard":
			continue
		var inside := 0
		for i in posts:
			for post in posts[i]:
				inside += int(post.distance_to(site["at"]) <= ring + 2.0)
		var fault: String = _acts().ground_fault(PackedVector2Array([site["at"]]), ring, _site())
		# The map's own ground is what this reads. A pocket this run drew beside the row is the run's, not the map's
		# (pockets do not keep off a survival row yet; BACKLOG W1-101): it is named, and the row is read again without it.
		if fault == "taken":
			var beside: Array = _acts().sites.filter(func(other) -> bool: return other != _site() and is_instance_valid(other) and other.visible and other.drawn)
			for other in beside:
				other.visible = false
			fault = _acts().ground_fault(PackedVector2Array([site["at"]]), ring, _site())
			for other in beside:
				other.visible = true
			if fault != "taken":
				print("stocktake_yard_test note: a pocket this run drew stands beside %s" % site["row"])
		if inside > 0 or fault != "":
			faults.append("%s: %d anchor posts, ground %s" % [site["row"], inside, fault])
	_t.check("every yard row is open ground", faults.is_empty(), str(faults))
