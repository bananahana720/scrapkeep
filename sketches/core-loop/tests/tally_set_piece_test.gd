extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Ultimate := preload("res://src/combat/ultimate.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Progress := preload("res://src/core/progress.gd")
const Profile := preload("res://src/core/profile.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const CosmeticArt := preload("res://tests/support/cosmetic_art.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Triggers := preload("res://src/build/triggers.gd")
const T := preload("res://tests/support/t.gd")

# PC-TALLY, 2026-10-11 (design-v3/pilots/tally.md sections 3, 7, 8, 9). Plate Return and its two
# depth-3 variants through the real game on a calm shelf: the plate target in plan(), the
# volleys and the clip cap, the peak plate, the landing's strike and settles, Wardens and
# bosses, Audit Trail, Flywheel Throw, each depth-4 knob, the tree swaps and the world-2 offer,
# and the three grants. Rows are called through ultimate.gd's _ult_rows, as the framework does.
# Measured 2026-10-11 on 4ae242b plus this unit: 63 checks including the count assertion.
# Re-pinned 2026-10-12 (PC-TALLY fix round): the P-C stacking and movement rules (P-UNITS.md
# wave P-C, comps rows 7, 8 and 24) gain their own checks: 30 nodes, MAX_CHAIN_DEPTH 1, no
# unsafe growth, nodes 6 to 29 capped with class_id tally (24), every movement node Tally's
# own (11 movers), and a 20-copy sweep per depth-4 leaf (16). Measured 107 checks (was 63).
# 2026-10-12 (PC-TALLY round 3): live unspent three-clip settle pays once, no arc.
# 2026-10-12 (PC-TALLY round 3): Flywheel peak pull ring includes its landing bonus.
# 2026-10-16 (pilot paint): Abacus Lattice is live; the pending check splits into three.
const EXPECTED_CHECKS := 111
const DT := 1.0 / 60.0
const SHELF := Vector3(-45.0, 122.0, 6.0)

var _t := T.new("tally_set_piece_test")
var _game
var _player
var _combat
var _ult
var _source := Intent.Scripted.new()
var _struck: Array = []
var _landed: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _boot() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	var def: Resource = ClassDef.by_id("tally")
	_game.run.class_def = def
	_player.fit_class(def)
	await _sim(0.6)
	_ult = _combat.ultimate
	_player.set_physics_process(false)
	_combat.set_physics_process(false)
	_ult.set_physics_process(false)
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float): _struck.append([enemy.get_instance_id(), kind, force]))
	_game.events.ultimate_landed.connect(func(id: String, _at: Vector3, hits: int, _damage: float): _landed.append([id, hits]))
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	collision.shape = box
	floor_body.add_child(collision)
	_game.add_child(floor_body)
	floor_body.global_position = SHELF + Vector3(0.0, -2.5, 0.0)
	await _fresh()


func _never() -> bool:
	return false


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _fresh() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.queue_free()
	_ult._phase = "idle"
	_ult.meter.locked = false
	_player.kit.drop_line("reset")
	_player.kit.rewind_left = 0.0
	_player.chain.reset()
	_player.abilities.refill()
	_player.abilities.ultimate_id = "plate_return"
	_player.tree._knobs.clear()
	_combat._line_load = {}
	_combat._bite_pending = false
	_combat._reset_cards()
	_combat.plate = {}
	_combat.link_group = {}
	_struck.clear()
	_landed.clear()
	_game.run.mass = 0.0
	_game.run.parts.clear()
	_game.run._heft_class = 1
	_player.body().freeze = true
	_player.reset_to(SHELF)
	await physics_frame
	await physics_frame


func _enemy(kind: String, dx: float, dz := 0.0) -> Node3D:
	var ball: Vector3 = _player.ball_position()
	var enemy: Node3D = _combat.spawn_enemy(kind, ball + Vector3(dx, 0.0, dz))
	enemy.global_position = ball + Vector3(dx, 0.0, dz)
	if enemy.get("live") != null:
		enemy.live = _never
	if enemy.get("hp") != null:
		enemy.hp = 10000.0
		enemy.max_hp = 10000.0
	enemy.set_physics_process(false)
	return enemy


func _boss(dx: float, dz := 0.0) -> Node3D:
	var enemy := Enemy.new()
	enemy.kind = "brindle_hull"
	enemy.weight = 1.0
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	_game.add_child(enemy)
	enemy.add_to_group("enemy")
	enemy.global_position = _player.ball_position() + Vector3(dx, 0.0, dz)
	enemy.set_physics_process(false)
	return enemy


# A ride in flight toward `to`, as ultimate.start leaves it, with the started fact published.
func _piece(id: String, from: Vector3, to: Vector3) -> void:
	_player.abilities.ultimate_id = id
	_ult._id = id
	_ult._plan = {"path": "line", "from": from, "to": to, "flight": 2.4, "seconds": 2.75, "beats": 7,
		"legs": [{"mode": "line", "to": to, "seconds": 2.4, "beats": 7, "strike": true}]}
	_ult.last_plan = _ult._plan
	_ult._leg = 0
	_ult._leg_time = 0.0
	_ult._phase = "flight"
	_ult._posture_spent = {}
	_game.events.ultimate_started.emit(id, "line", from, to, 2.75)


func _tech(id: String, ball: Vector3, aim := Vector3.RIGHT) -> int:
	return int(_ult._ult_rows[id]["tech"].call(1, ball, aim, Ultimate.HEFT_MULT[_ult.heft_index()]))


func _land(id: String, at: Vector3, chain := 1.0) -> Array:
	return _ult._ult_rows[id]["landing"].call(at, Ultimate.HEFT_MULT[_ult.heft_index()], chain)


func _hits(enemy: Node3D, kind := "") -> Array:
	return _struck.filter(func(row): return row[0] == enemy.get_instance_id() and (kind == "" or row[1] == kind))


func _forces(enemy: Node3D, kind := "") -> Array:
	return _hits(enemy, kind).map(func(row): return snappedf(float(row[2]), 0.01))


func _aim(forward: Vector3) -> Dictionary:
	var ball: Vector3 = _player.ball_position()
	return {"origin": ball + Vector3.UP * 2.0, "forward": forward.normalized(), "harpoon": {"state": 0}}


func _plate_at(dx: float, dz := 0.0) -> Vector3:
	var at: Vector3 = _combat.floor_at(_player.ball_position() + Vector3(dx, 2.0, dz))
	_combat.plate = {"at": at, "until": _combat._clock + 4.0}
	return at


func _finish() -> void:
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	_game.free()
	quit(_t.verdict())


func _run() -> void:
	await _boot()
	_t.eq("base Q is Plate Return", _player.abilities.ultimate_id, "plate_return")
	var keyed := func(id): return _ult._ult_rows.has(id) and _ult._ult_rows[id].keys() == ["target", "tech", "peak", "landing"]
	_t.check("all three rows register target, tech, peak and landing", ["plate_return", "plate_audit", "plate_flywheel"].all(keyed))
	await _plan_cases()
	await _volley_cases()
	await _peak_and_landing_cases()
	await _warden_and_boss_cases()
	await _variant_cases()
	await _knob_cases()
	_tree_cases()
	_stack_cases()
	await _grants()
	_finish()


# --- plan: her plate first, then the framework order --------------------------------------

func _plan_cases() -> void:
	await _fresh()
	var plate := _plate_at(20.0)
	var plan: Dictionary = _ult.plan(_player.ball_position(), _aim(Vector3(1.0, -0.2, 0.0)))
	_t.eq("a plate 20 m out on the aim is B, on a line", [plan["path"], _flat(plan["to"]).distance_to(_flat(plate)) < 0.01], ["line", true])
	plan = _ult.plan(_player.ball_position(), _aim(Vector3(1.0, -0.2, 0.9)))
	_t.check("a plate 42 degrees off the aim is not B", _flat(plan["to"]).distance_to(_flat(plate)) > 0.5, str(plan["to"]))
	_combat.plate = {}
	_plate_at(_player.grapple_range() + 5.0)
	plan = _ult.plan(_player.ball_position(), _aim(Vector3(1.0, -0.2, 0.0)))
	_t.check("a plate past rope range is not B", _flat(plan["to"]).distance_to(_flat(_combat.plate["at"])) > 0.5, str(plan["to"]))
	_combat.plate = {}
	var ball: Vector3 = _player.ball_position()
	_player.grapple_to(ball + Vector3(15.0, 0.0, 0.0), Vector3.LEFT, null)
	plan = _ult.plan(ball, _aim(Vector3(1.0, -0.2, 0.0)))
	_t.eq("no plate: a standing line runs first", plan["path"], "line")
	_player.abilities.ultimate_id = "plate_flywheel"
	plan = _ult.plan(ball, _aim(Vector3(1.0, -0.5, 0.0)))
	_t.eq("Flywheel Throw prefers the arc over a standing line", plan["path"], "arc")
	plate = _plate_at(25.0)
	plan = _ult.plan(ball, _aim(Vector3(1.0, -0.5, 0.0)))
	_t.eq("Flywheel Throw arcs onto her plate", [plan["path"], _flat(plan["to"]).distance_to(_flat(plate)) < 0.01], ["arc", true])
	_player.kit.drop_line("reset")


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- volleys: 3 per beat, nearest the reticle first, up to the class cap ----------------------

func _volley_cases() -> void:
	await _fresh()
	var ball: Vector3 = _player.ball_position()
	_piece("plate_return", ball, ball + Vector3.RIGHT * 25.0)
	var far := _enemy("chaser", 9.0)
	var near: Array = []
	for z in [-2.0, -3.0, -4.0]:
		near.append(_enemy("chaser", -2.0, z))
	_t.eq("a beat punches three", _tech("plate_return", ball, Vector3.RIGHT), 3)
	_t.check("the target on the reticle goes first", _combat.ride_clips.has(far.get_instance_id()))
	_t.eq("a volley deals 12 x heft", _forces(far, "ledger"), [12.0])
	for x in [3.0, 4.0, 5.0, 6.0]:
		_enemy("chaser", x, 3.0)
	_tech("plate_return", ball)
	_tech("plate_return", ball)
	_t.eq("class I caps the ride at 6 clips", _combat.ride_clips.size(), 6)
	await _fresh()
	_game.run.mass = 1000000.0
	ball = _player.ball_position()
	_piece("plate_return", ball, ball + Vector3.RIGHT * 25.0)
	for i in 12:
		_enemy("chaser", 2.0 + 0.6 * i, -2.0 + 0.3 * i)
	for beat in 4:
		_tech("plate_return", ball)
	_t.eq("class V caps the ride at 10 clips", [_ult.heft_index(), _combat.ride_clips.size()], [4, 10])


# --- the peak and the landing --------------------------------------------------------------

func _peak_and_landing_cases() -> void:
	await _fresh()
	var ball: Vector3 = _player.ball_position()
	var b := ball + Vector3.RIGHT * 20.0
	_piece("plate_return", ball, b)
	_ult._ult_rows["plate_return"]["peak"].call(ball + Vector3.RIGHT * 10.0)
	_t.check("the peak plants a plate at B", not _combat.plate.is_empty() and _flat(_combat.plate["at"]).distance_to(_flat(b)) < 0.5,
		str(_combat.plate))
	_t.near("the peak plate pulls at the landing radius", float(_combat.plate.get("radius", 0.0)), _ult.landing_radius())
	await _fresh()
	ball = _player.ball_position()
	var mine := _plate_at(15.0)
	_piece("plate_return", ball, mine)
	var until: float = _combat.plate["until"]
	_ult._ult_rows["plate_return"]["peak"].call(ball)
	_t.check("her own plate at B grows and lasts to the landing", _flat(_combat.plate["at"]).distance_to(_flat(mine)) < 0.01
		and is_equal_approx(float(_combat.plate["radius"]), _ult.landing_radius()) and float(_combat.plate["until"]) != until)

	await _fresh()
	ball = _player.ball_position()
	_piece("plate_return", ball, ball)
	var inside_clip := _enemy("chaser", 2.0)
	var inside := _enemy("chaser", -2.0)
	var outs: Array = []
	for z in [10.0, 12.0, 14.0]:
		outs.append(_enemy("chaser", 0.0, z))
	for enemy in outs + [inside_clip]:
		_combat.ride_clips[enemy.get_instance_id()] = true
	_player.abilities.slot(AbilityState.WEAPON).charges = 0
	var result := _land("plate_return", ball)
	_t.eq("the landing reports strike hits plus settles", int(result[0]), 2 + 3)
	_t.eq("each clip outside settles once at 40%", outs.map(func(e): return _forces(e, "ledger")), [[24.0], [24.0], [24.0]])
	_t.eq("a clip inside takes the strike, never a settle too", [_forces(inside_clip, "ledger"), _hits(inside_clip, "ultimate").size()], [[], 1])
	_t.eq("an unclipped enemy inside takes the strike only", [_hits(inside, "ultimate").size(), _hits(inside, "ledger").size()], [1, 0])
	_t.eq("the landing refills pressure to full", _player.abilities.slot(AbilityState.WEAPON).charges, 3)
	_t.eq("the settle record", [_combat.tally_last_settle.get("hits"), _combat.tally_last_settle.get("settles")], [2, 3])
	# Through the framework strike: ultimate_landed carries the settles and the chain ends.
	await _fresh()
	ball = _player.ball_position()
	_piece("plate_return", ball, ball)
	for z in [10.0, 12.0]:
		_combat.ride_clips[_enemy("chaser", 0.0, z).get_instance_id()] = true
	for i in 3:
		_player.chain.link(true, false)
	_ult._strike(ball)
	_t.eq("ultimate_landed's hits counts the settled clips", _landed, [["plate_return", 2]])
	_t.eq("the landing ends the chain", _player.chain.combo, 0)
	# Clips from the ledger clip line skill settle too, once.
	await _fresh()
	ball = _player.ball_position()
	_piece("plate_return", ball, ball)
	var lined := _enemy("chaser", 0.0, 11.0)
	_combat.link_group = {"ids": [lined.get_instance_id()], "until": _combat._clock + 4.0, "spent": false, "mult": 1.0}
	_combat.ride_clips[lined.get_instance_id()] = true
	_land("plate_return", ball)
	_t.eq("a line clip and a ride clip on one enemy settle once", _forces(lined, "ledger"), [24.0])


	await _fresh()
	ball = _player.ball_position()
	_piece("plate_return", ball, ball)
	var linked: Array = []
	for z in [11.0, 13.0, 15.0]:
		linked.append(_enemy("chaser", 0.0, z))
	_combat.link_group = {"ids": linked.map(func(e): return e.get_instance_id()), "until": _combat._clock + 4.0, "spent": false, "mult": 1.0}
	_land("plate_return", ball)
	_t.eq("a live unspent three-clip group takes one settle each and no arc", linked.map(func(e): return _forces(e, "ledger")), [[24.0], [24.0], [24.0]])


# --- Wardens and bosses ----------------------------------------------------------------------

func _warden_and_boss_cases() -> void:
	await _fresh()
	var ball: Vector3 = _player.ball_position()
	_piece("plate_return", ball, ball)
	var warden := _enemy("warden", 4.0)
	var posture = warden.get("_posture")
	var before: float = warden.posture()
	_tech("plate_return", ball)
	_t.check("a volley fills a closed Warden's posture and clips it", warden.posture() > before
		and _combat.ride_clips.has(warden.get_instance_id()), "posture %.2f -> %.2f" % [before, warden.posture()])
	posture.staggered = true
	posture.stagger_left = 5.0
	posture.ram_shatters = true
	var chunks: int = warden.chunks_left()
	_combat.ride_clips.clear()
	_tech("plate_return", ball)
	_t.eq("a volley never takes a chunk from an open core", warden.chunks_left(), chunks)
	# Settle: the Warden is a clip outside the radius.
	warden.global_position = ball + Vector3(0.0, 0.0, 14.0)
	posture.staggered = true
	posture.stagger_left = 5.0
	_land("plate_return", ball)
	_t.eq("a settle never takes a chunk from an open core", warden.chunks_left(), chunks)
	# The landing on the open core shatters it.
	await _fresh()
	ball = _player.ball_position()
	_piece("plate_return", ball, ball)
	warden = _enemy("warden", 2.0)
	posture = warden.get("_posture")
	posture.staggered = true
	posture.stagger_left = 5.0
	posture.ram_shatters = true
	chunks = warden.chunks_left()
	_land("plate_return", ball)
	_t.check("the landing on an open core shatters it", warden.chunks_left() < chunks, "chunks %d -> %d" % [chunks, warden.chunks_left()])
	# A boss takes half from the volley, the settle and the landing.
	await _fresh()
	ball = _player.ball_position()
	_piece("plate_return", ball, ball)
	var boss := _boss(3.0)
	var hp: float = boss.hp
	_tech("plate_return", ball)
	_t.near("a volley on a boss deals half", hp - float(boss.hp), 6.0, 0.01)
	_t.check("a boss is clipped once like anyone", _combat.ride_clips.has(boss.get_instance_id()) and _combat.ride_clips.size() == 1)
	boss.global_position = ball + Vector3(0.0, 0.0, 14.0)
	hp = boss.hp
	_land("plate_return", ball)
	_t.near("a settle on a boss deals half", hp - float(boss.hp), 12.0, 0.01)
	boss.global_position = ball + Vector3(2.0, 0.0, 0.0)
	_combat.ride_clips.clear()
	hp = boss.hp
	_land("plate_return", ball)
	_t.near("the landing on a boss deals half", hp - float(boss.hp), Ultimate.LANDING_DAMAGE * 0.5, 0.01)


# --- Audit Trail and Flywheel Throw ----------------------------------------------------------

func _variant_cases() -> void:
	await _fresh()
	var ball: Vector3 = _player.ball_position()
	_piece("plate_audit", ball, ball + Vector3.RIGHT * 20.0)
	var under: Array = [_enemy("chaser", 2.0), _enemy("chaser", -1.0, 2.0), _enemy("chaser", 0.0, -3.0), _enemy("chaser", 1.0, 1.0)]
	var reticle := _enemy("chaser", 9.0)
	var made := _tech("plate_audit", ball, Vector3.RIGHT)
	_t.eq("Audit Trail stamps all four under the ball, no 3-target limit", made, 4)
	_t.eq("the stamp leaves the reticle target alone", _hits(reticle).size(), 0)
	_t.eq("a stamp deals 12 x heft", _forces(under[0], "ledger"), [12.0])
	_combat.ride_clips.clear()
	_struck.clear()
	_t.eq("Audit Trail ignores the aim", _tech("plate_audit", ball, Vector3.BACK), 4)
	_combat.ride_clips.clear()
	_t.eq("no ground within 12 m below, no stamp", _tech("plate_audit", ball + Vector3.UP * 20.0), 0)

	await _fresh()
	ball = _player.ball_position()
	_piece("plate_flywheel", ball, ball + Vector3.RIGHT * 20.0)
	_enemy("chaser", -6.0)
	var knot: Array = [_enemy("chaser", 10.0, 0.0), _enemy("chaser", 11.0, 1.0), _enemy("chaser", 10.5, -1.0), _enemy("chaser", 11.5, 0.0)]
	made = _tech("plate_flywheel", ball)
	_t.check("Flywheel Throw throws its plate at the densest knot", _combat._fly_plates.size() == 1
		and _flat(_combat._fly_plates[0]["at"]).distance_to(_flat(knot[0].global_position)) < 2.0, str(_combat._fly_plates))
	_t.eq("a knot plate clips three", made, Weapons.FLY_KNOT_CLIPS)
	_ult._ult_rows["plate_flywheel"]["peak"].call(ball)
	_t.near("Flywheel peak plate pull ring equals its landing radius including bonus", float(_combat.plate["radius"]), _ult.landing_radius() + Weapons.FLY_LANDING_BONUS)
	var edge := _enemy("chaser", _ult.landing_radius() + 1.0)
	var base_hit := _land("plate_return", ball)
	_struck.clear()
	_piece("plate_flywheel", ball, ball)
	_land("plate_flywheel", ball)
	_t.check("Flywheel Throw lands 2 m wider", _hits(edge, "ultimate").size() == 1 and int(base_hit[0]) >= 0)


# --- each depth-4 knob changes its number ------------------------------------------------------

func _knob_cases() -> void:
	await _fresh()
	var ball: Vector3 = _player.ball_position()
	_piece("plate_return", ball, ball)
	var out := _enemy("chaser", 0.0, 12.0)
	_combat.ride_clips[out.get_instance_id()] = true
	_player.tree._knobs["ult_settle"] = 0.7
	_land("plate_return", ball)
	_t.eq("ult_settle 0.7 settles at 70%", _forces(out, "ledger"), [42.0])
	_player.tree._knobs.clear()

	await _fresh()
	ball = _player.ball_position()
	_piece("plate_return", ball, ball)
	for x in [2.0, 3.0, 4.0, 5.0, 6.0]:
		_enemy("chaser", x)
	_player.tree._knobs["ult_volley"] = 1
	_t.eq("ult_volley 1 punches four a beat", _tech("plate_return", ball), 4)
	_combat.ride_clips.clear()
	_piece("plate_audit", ball, ball)
	_enemy("chaser", 0.0, 4.6)
	_t.eq("ult_volley 1 widens the stamp to 5 m", _tech("plate_audit", ball), 6)
	_player.tree._knobs.clear()

	await _fresh()
	ball = _player.ball_position()
	_piece("plate_flywheel", ball, ball)
	for i in 5:
		_enemy("chaser", 10.0 + 0.4 * i, 0.3 * i)
	_player.tree._knobs["ult_volley"] = 1
	_t.eq("ult_volley 1 clips four per knot", _tech("plate_flywheel", ball), 4)
	_player.tree._knobs.clear()

	var plain: float = _ult.landing_radius()
	_player.tree._knobs["ult_radius"] = 2.0
	_t.near("ult_radius 2 lands 2 m wider", _ult.landing_radius(), plain + 2.0)
	_player.tree._knobs.clear()

	await _fresh()
	ball = _player.ball_position()
	_player.abilities.ultimate_id = "plate_return"
	var aim := _aim(Vector3(1.0, -0.2, 0.0))
	_plate_at(20.0)
	var beats: int = _ult.plan(ball, aim)["beats"]
	_player.tree._knobs["ult_beats"] = 2
	_t.eq("ult_beats 2 flies two more beats", _ult.plan(ball, aim)["beats"], beats + 2)
	_player.tree._knobs.clear()
	_enemy("chaser", 15.0)
	_t.check("ult_encore finds a second landing", _ult._encore_target(ball) != null)


# --- the tree: swaps and the world-2 offer -----------------------------------------------------

func _tree_cases() -> void:
	var abilities := AbilityState.new()
	abilities.fit(ClassDef.by_id("tally"))
	UpgradeTree.apply_pick(abilities, UpgradeTree.node("tally", "tl_deep_ledger"))
	var audit: String = abilities.ultimate_id
	UpgradeTree.apply_pick(abilities, UpgradeTree.node("tally", "tl_carbon_copy"))
	_t.eq("tl_deep_ledger swaps Q to Audit Trail, tl_carbon_copy to Flywheel Throw", [audit, abilities.ultimate_id],
		["plate_audit", "plate_flywheel"])
	var list: Array = UpgradeTree.nodes("tally")
	var pairs_ok := true
	var seen := 0
	for first in [0, 1]:
		for second in UpgradeTree.children_of(first):
			var tree := UpgradeTree.new()
			tree.reset("tally")
			for i in 3:
				tree.open_checkpoint()
			tree.pick(list[first]["id"])
			tree.pick(list[second]["id"])
			var offer: Array = tree.offered("tally", 3)
			var swaps: Array = offer.map(func(n): return n.get("swap", {}).get(AbilityState.ULTIMATE, ""))
			swaps.sort()
			pairs_ok = pairs_ok and swaps == ["plate_audit", "plate_flywheel"]
			seen += 1
	_t.check("every world-2 offer is one Audit Trail and one Flywheel Throw", pairs_ok and seen == 4, "routes %d" % seen)
	_t.eq("the tree has no problems", UpgradeTree.problems("tally"), [])


# --- stacking and movement (P-UNITS wave P-C common rules, comps rows 7, 8 and 24) ----------------
# Every depth-3 and depth-4 node this unit rewrote (indices 6 to 29) is capped and Tally's own; a
# node that touches a movement knob (a movement charge or cooldown, or a surge or air-jump proc)
# carries class_id "tally"; chains stay at depth 1; 1 to 20 more picks of a held leaf or its
# depth-3 parent change nothing.

const MOVE_PROCS := ["refund_move", "grant_move", "air"]


func _moves(n: Dictionary) -> bool:
	if n.get("charges", {}).has(AbilityState.MOVEMENT) or n.get("cooldown", {}).has(AbilityState.MOVEMENT):
		return true
	return n.get("proc", []).any(func(p): return MOVE_PROCS.has(String(p.get("do", ""))))


func _stack_cases() -> void:
	var nodes: Array = UpgradeTree.nodes("tally")
	_t.eq("tally keeps 30 nodes", nodes.size(), 30)
	_t.eq("proc chain cap remains one", Triggers.MAX_CHAIN_DEPTH, 1)
	_t.eq("tally has no unsafe growth route", UpgradeTree.safe_growth_problems("tally"), [])
	var movers: Array = []
	var stray: Array = []
	for i in range(6, 30):
		var n: Dictionary = nodes[i]
		_t.check("%s capped and pilot local" % n["id"],
			n.get("stack_rule") in PartDef.STACK_RULES and n["stack_rule"] == "capped" and n.get("class_id") == "tally",
			"stack_rule %s class_id %s" % [n.get("stack_rule"), n.get("class_id")])
		if _moves(n):
			movers.append(n["id"])
			if n.get("class_id") != "tally":
				stray.append(n["id"])
	_t.check("every movement node carries class_id tally", movers.size() >= 10 and stray.is_empty(),
		"movers %d stray %s" % [movers.size(), stray])
	for i in range(14, 30):
		var leaf: Dictionary = nodes[i]
		var tree := UpgradeTree.new()
		tree.max_depth = 4
		tree.reset("tally")
		tree.allowed = 4
		var route := UpgradeTree.path_to("tally", leaf["id"])
		var live := true
		for id in route:
			live = tree.pick(id) and live
		var knob: String = leaf["knob"].keys()[0]
		var before := [tree.path(), tree.knob(knob)]
		var refused := 0
		for copies in range(1, 21):
			if not tree.pick(leaf["id"]) and not tree.pick(route[2]) and before == [tree.path(), tree.knob(knob)]:
				refused += 1
		_t.check("%s route picks, and 20 more copies stay capped" % leaf["id"], live and route.size() == 4 and refused == 20,
			"live %s route %d refused %d" % [live, route.size(), refused])


# --- the three grants and her codex rows --------------------------------------------------------

func _grants() -> void:
	await _fresh()
	var store := Profile.new("user://tally-grants-%d.json" % OS.get_process_id())
	store.load_profile()
	var progress := Progress.new()
	progress.rows = {}
	var grant_ids := ["ach_tally_punch_tape", "ach_tally_eyeshade", "ach_tally_books_balanced"]
	for id in grant_ids:
		progress.rows[id] = Achievements.row(id)
	progress.setup(_game.events, null, store, func(): return 50.0, _game.ctx.codex)
	var found: Array = []
	var frames: Array = []
	_game.events.synergy_discovered.connect(func(id: String, _category: String, _first: bool):
		found.append(id)
		frames.append([id, Engine.get_physics_frames()]))
	var codex = _game.ctx.codex
	codex.mark_discovered("loaded_line")
	codex.mark_discovered("set_piece")
	_game.events.stage_entered.emit(1, false)
	var ball: Vector3 = _player.ball_position()
	var anchor: Vector3 = ball + Vector3.RIGHT * 8.0
	for i in 10:
		_player.kit.drop_line("reset")
		_player.grapple_to(anchor, Vector3.UP, null)
		_player.abilities.refill()
		_combat._cast_line("link_clips", 1.0)
		if i == 8:
			await physics_frame
			_combat._step_tally_cards()
			_t.check("nine clip casts do not grant the tape", not store.earned("ach_tally_punch_tape"))
	_player.kit.drop_line("reset")
	await physics_frame
	_combat._step_tally_cards()
	_t.eq("ten ledger clips in a stage fire the tape discovery", found.count("tally_punch_tape"), 1)
	# One landing settling five clips does not balance the books; six does.
	for settles in [5, 6, 6, 6]:
		_piece("plate_return", ball, ball)
		var clips: Array = []
		for i in settles:
			var enemy := _enemy("chaser", -10.0 + 4.0 * i, 14.0)
			_combat.ride_clips[enemy.get_instance_id()] = true
			clips.append(enemy)
		_land("plate_return", ball)
		if settles == 5:
			await physics_frame
			_combat._step_tally_cards()
			_t.check("five settles do not balance the books", not found.has("tally_books_balanced"))
		for enemy in clips:
			enemy.remove_from_group("enemy")
			enemy.queue_free()
		await physics_frame
		_combat._step_tally_cards()
	for i in 3:
		await physics_frame
		_combat._step_tally_cards()
	_t.eq("six settles in one landing balance the books, once", found.count("tally_books_balanced"), 1)
	_t.eq("twenty settles in a run fire the eyeshade, once", found.count("tally_eyeshade"), 1)
	# A real three-clip ledger clip opens the skim card.
	var row: Array = [_enemy("chaser", 4.0), _enemy("chaser", 5.0, 1.0), _enemy("chaser", 6.0)]
	_combat._link_from(row[0])
	await physics_frame
	_combat._step_tally_cards()
	await physics_frame
	_combat._step_tally_cards()
	_t.eq("Skim opens once on a three-clip cast", found.count("tally_skim"), 1)
	var pilot_frames: Array = frames.filter(func(r): return String(r[0]).begins_with("tally_")).map(func(r): return r[1])
	var unique := {}
	for frame in pilot_frames:
		unique[frame] = true
	_t.check("her cards never share a discovery tick", pilot_frames.size() == unique.size(), str(frames))
	_t.check("all three grants earned", grant_ids.all(func(id): return store.earned(id)), str(grant_ids.map(func(id): return store.earned(id))))
	var items := ["trail_tally_punch_tape", "outfit_tally_eyeshade", "shell_tally_abacus"]
	_t.check("all three looks unlocked", items.all(func(id): return store.has_cosmetic(id)))
	_t.check("every granted look is pending or ships, and none has a price", CosmeticArt.unaccounted(items).is_empty() and items.all(func(id): return not Cosmetics.row(id).has("price") and not Cosmetics.row(id).has("cost")), str(CosmeticArt.unaccounted(items)))
	_t.check("the shell is live", not Cosmetics.is_pending("shell_tally_abacus") and FileAccess.file_exists("res://assets/models/world_one/shell_tally_abacus.glb"))
	_t.check("no price", items.all(func(id): return not Cosmetics.row(id).has("price") and not Cosmetics.row(id).has("cost")))
	var reload_store := Profile.new(store.path)
	reload_store.load_profile()
	_t.check("grants survive reload", grant_ids.all(func(id): return reload_store.earned(id)) and items.all(func(id): return reload_store.has_cosmetic(id)))
	progress.free()
