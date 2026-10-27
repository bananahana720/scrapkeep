extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Dunk := preload("res://src/combat/dunk.gd")

# The dunk charge (src/combat/dunk.gd): an air slam stores its slam damage, the next reel
# impact inside Dunk.WINDOW spends exactly that on the body it lands on, and plain slams and
# plain reels deal what they always did. Real Game, real player and combat; a reel impact is a
# smash landing on the bitten enemy (the same test punch_of's winch branch reads), a slam is
# the body's own slam handler. The clock is the dunk's own tick, so every step is synchronous.
# Evidence limit: the rule and its numbers, not a played dunk; how it feels is unjudged.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const FORCE := 40.0
const SPEED := 30.0

var _failures := 0
var _count := 0
var _game
var _player
var _combat
var _source := Intent.Scripted.new()
var _stored: Array = []
var _spent: Array = []
var _expired: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	_count += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _never() -> bool:
	return false


func _enemy(plating := 0.0) -> Node3D:
	var at: Vector3 = _game.ctx.terrain.drop_point(FLAT_SHELF.x, FLAT_SHELF.z, 1.0)
	var enemy: Node3D = _combat.spawn_enemy("chaser", at)
	enemy.live = Callable(self, "_never")
	enemy.hp = 100000.0
	enemy.max_hp = 100000.0
	enemy.plating = plating
	return enemy


func _fresh() -> void:
	_player.kit.drop_line("reset")
	_player.smash_landing = null
	_player._landing_mult = 1.0
	_player.dunk.clear("reset")
	_player.dunk.clock = 0.0
	_stored.clear()
	_spent.clear()
	_expired.clear()


# The body's own slam, landed well away from the enemy so only the charge is under test.
func _slam() -> void:
	_player._on_rigid_slammed(Vector3(500.0, 0.0, 500.0), SPEED, 1.0)


# One hit on a fresh enemy; returns the HP it removed. reel makes it a smash landing on it.
func _hit(kind: String, reel: bool, plating := 0.0) -> float:
	var enemy := _enemy(plating)
	var before: float = enemy.hp
	_player.smash_landing = enemy if reel else null
	_combat.strike(enemy, kind, FORCE)
	_player.smash_landing = null
	var removed: float = before - enemy.hp
	enemy.queue_free()
	return removed


# A hooked, winching ram on a fresh enemy while the line is on the anchor: the enemy itself
# (the bitten body) or a bystander. Returns the HP removed.
func _haul_hit(on_bitten: bool) -> float:
	var enemy := _enemy()
	var other := _enemy()
	_player.kit.hooked = true
	_player.kit.winching = true
	_player.kit.anchor_body = enemy if on_bitten else other
	var before: float = enemy.hp
	_combat.strike(enemy, "ram", FORCE)
	_player.kit.hooked = false
	_player.kit.winching = false
	_player.kit.anchor_body = null
	var removed: float = before - enemy.hp
	enemy.queue_free()
	other.queue_free()
	return removed


# A strike at an exact force on a fresh enemy; returns the HP removed.
func _hit_at(kind: String, force: float) -> float:
	var enemy := _enemy()
	var before: float = enemy.hp
	_combat.strike(enemy, kind, force)
	var removed: float = before - enemy.hp
	enemy.queue_free()
	return removed


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_combat = _game.ctx.spawner
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(0.6)
	_combat.heft_override = 1.0
	_player.set_physics_process(false)
	_player.dunk.stored.connect(func(r: Dictionary): _stored.append(r))
	_player.dunk.spent.connect(func(r: Dictionary, _e: Node3D): _spent.append(r))
	_player.dunk.expired.connect(func(r: Dictionary, cause: String): _expired.append([r, cause]))

	var slam_row: Array = _combat.STRIKE_DAMAGE["slam"]
	var stomp_row: Array = _combat.STRIKE_DAMAGE["stomp"]
	var stored_expect: float = (slam_row[0] + Augments.SLAM_KNOCK * _strength() * slam_row[1]) * 1.0
	var plain_reel := _hit("stomp", true)
	var plain_stomp_expect: float = stomp_row[0] + FORCE * stomp_row[1]
	_check("4 plain reel", absf(plain_reel - plain_stomp_expect) < 0.01,
		"reel with no charge removed %.2f, the stomp row says %.2f" % [plain_reel, plain_stomp_expect])

	_fresh()
	var plain_slam := _hit("slam", false)
	var slam_expect: float = slam_row[0] + FORCE * slam_row[1]
	_check("3 plain slam", absf(plain_slam - slam_expect) < 0.01,
		"slam with no charge removed %.2f, the slam row says %.2f" % [plain_slam, slam_expect])

	_fresh()
	_slam()
	var charge: Dictionary = _player.dunk.charge.duplicate()
	_check("store", _player.dunk.held() and absf(float(charge["damage"]) - stored_expect) < 0.01 and _stored.size() == 1,
		"air slam stored %.2f (expected %.2f), %d stored event" % [float(charge.get("damage", -1.0)), stored_expect, _stored.size()])
	var slam_with_charge := _hit("slam", false)
	_check("3b slam does not spend", absf(slam_with_charge - slam_expect) < 0.01 and _player.dunk.held(),
		"a plain slam with a charge held removed %.2f and left the charge held %s" % [slam_with_charge, _player.dunk.held()])
	_player.dunk.tick(1.0)
	var dunked := _hit("stomp", true)
	_check("1 dunk then reel", absf(dunked - (plain_reel + float(charge["damage"]))) < 0.01 and not _player.dunk.held(),
		"reel at 1.0 s removed %.2f = plain %.2f + stored %.2f" % [dunked, plain_reel, float(charge["damage"])])
	_check("7a spent event", _spent.size() == 1 and absf(float(_spent[0]["damage"]) - float(charge["damage"])) < 0.001,
		"%d spent event carrying %.2f" % [_spent.size(), float(_spent[0]["damage"]) if _spent.size() > 0 else -1.0])
	var second := _hit("stomp", true)
	_check("5 spent once", absf(second - plain_reel) < 0.01 and _spent.size() == 1,
		"the next reel removed %.2f, plain is %.2f, spends %d" % [second, plain_reel, _spent.size()])

	# The stored value is the real slam: a slam strike at the slam's own force deals it.
	_fresh()
	var real_force: float = Augments.SLAM_KNOCK * _strength()
	var real_dealt := _hit_at("slam", real_force)
	_check("3c stored equals the real slam", absf(real_dealt - float(charge["damage"])) < 0.01,
		"a slam strike at force %.1f dealt %.2f, the stored charge is %.2f" % [real_force, real_dealt, float(charge["damage"])])

	# A reel only on the bitten body: a bystander rammed during a world-line haul keeps the charge.
	_fresh()
	var plain_ram := _haul_hit(false)
	_slam()
	var bystander := _haul_hit(false)
	var held_after: bool = _player.dunk.held()
	var bitten := _haul_hit(true)
	_check("9 bystander keeps it, bitten body spends it", absf(bystander - plain_ram) < 0.01 and held_after \
			and absf(bitten - (plain_ram + stored_expect)) < 0.01 and not _player.dunk.held(),
		"haul ram on a bystander %.2f (plain %.2f, charge held %s); on the bitten body %.2f (plain+stored %.2f)" \
		% [bystander, plain_ram, held_after, bitten, plain_ram + stored_expect])

	# One plating rule: the stored slam meets the body's plating like the reel it rides on.
	_fresh()
	var chip_plain := _hit("stomp", true, 200.0)
	_slam()
	var chip_dunk := _hit("stomp", true, 200.0)
	_check("10a plated: both chipped", absf(chip_plain - plain_reel * _combat.CHIP) < 0.01 \
			and absf(chip_dunk - (plain_reel + stored_expect) * _combat.CHIP) < 0.01,
		"plating 200: reel %.2f (74 x chip), dunk-reel %.2f ((74 + stored) x chip)" % [chip_plain, chip_dunk])
	_slam()
	var over := _hit("stomp", true, 90.0)
	_check("10b plated: the stored slam lifts the reel over the plating", absf(over - (plain_reel + stored_expect)) < 0.01,
		"plating 90: dunk-reel %.2f in full (plain reel alone is chipped)" % over)

	# A new slam replaces the held one: the old charge is reported expired as replaced.
	_fresh()
	_slam()
	_player._on_rigid_slammed(Vector3(500.0, 0.0, 500.0), SPEED * 0.5, 1.0)
	var smaller: float = _player.dunk.charge["damage"]
	_check("11 replaced charge", _expired.size() == 1 and _expired[0][1] == "replaced" and _stored.size() == 2 \
			and smaller < stored_expect - 0.01 and _player.dunk.held(),
		"expired %s, stored events %d, held %.2f (first %.2f)" % [_expired.map(func(e): return e[1]), _stored.size(), smaller, stored_expect])

	_fresh()
	_slam()
	_player.dunk.tick(Dunk.WINDOW - 0.1)
	var late_ok := _hit("stomp", true)
	_check("2a just inside the window", absf(late_ok - (plain_reel + stored_expect)) < 0.01,
		"reel at %.1f s removed %.2f" % [Dunk.WINDOW - 0.1, late_ok])
	_fresh()
	_slam()
	_player.dunk.tick(Dunk.WINDOW + 0.1)
	var expired_hit := _hit("stomp", true)
	_check("2 planted control: expiry", absf(expired_hit - plain_reel) < 0.01 and _expired.size() == 1 and _expired[0][1] == "timeout",
		"reel at %.1f s removed %.2f (plain %.2f), expired events %s" % [Dunk.WINDOW + 0.1, expired_hit, plain_reel, _expired.map(func(e): return e[1])])

	_fresh()
	var lone := _hit("stomp", false)
	_check("6a non-reel stomp is plain", absf(lone - plain_reel) < 0.01, "a stomp with no line removed %.2f" % lone)
	_slam()
	var unreeled := _hit("stomp", false)
	_check("6b stomp with a charge held is plain", absf(unreeled - plain_reel) < 0.01 and _player.dunk.held(),
		"a free stomp removed %.2f and the charge stayed %s" % [unreeled, _player.dunk.held()])

	# Every pilot's slam feeds the one charge, and every reel spends it; same number, own label.
	var seen := {}
	var all_ok := true
	var detail := ""
	var amounts: Array = []
	for def in ClassDef.all():
		_fresh()
		_player.fit_class(def)
		_slam()
		var rec: Dictionary = _player.dunk.charge
		var fed: bool = _player.dunk.held() and rec["pilot"] == def.id and rec["color"] == def.color \
				and rec["flavour"] == _player.kit.smash_flavour
		var paid := _hit("stomp", true)
		var ok: bool = fed and absf(paid - (plain_reel + stored_expect)) < 0.01
		all_ok = all_ok and ok
		seen[String(rec.get("flavour", "?"))] = true
		amounts.append(snappedf(paid, 0.01))
		detail += " %s/%s" % [def.id, rec.get("flavour", "?")]
	_check("6 every pilot feeds and every reel spends", all_ok and seen.size() >= 2,
		"pilots/flavours:%s; paid %s; %d distinct flavours" % [detail, amounts, seen.size()])

	# An absorbed hit bites nothing: a reel into a miniboss's turn leaves the charge held, and the
	# next reel spends it whole. Control: the same reel outside the turn spends it.
	_fresh()
	_player.fit_class(ClassDef.all()[0])
	_slam()
	var turning := _miniboss(true)
	var turn_removed := _reel_on(turning)
	var kept: bool = _player.dunk.held() and _spent.is_empty()
	var after_turn := _hit("stomp", true)
	_check("12 absorbed hit keeps the charge", turn_removed == 0.0 and kept and _spent.size() == 1 \
			and absf(after_turn - (plain_reel + stored_expect)) < 0.01,
		"reel in the turn removed %.2f, charge held after %s; the next reel removed %.2f (plain+stored %.2f), spends %d" \
		% [turn_removed, kept, after_turn, plain_reel + stored_expect, _spent.size()])
	_fresh()
	_slam()
	var stalking := _miniboss(false)
	var stalk_removed := _reel_on(stalking)
	_check("12b control: outside the turn the reel spends it", stalk_removed > 0.0 and not _player.dunk.held() and _spent.size() == 1,
		"reel on a stalking miniboss removed %.2f, charge held %s, spends %d" % [stalk_removed, _player.dunk.held(), _spent.size()])
	turning.queue_free()
	stalking.queue_free()

	_fresh()
	var enemy := _enemy()
	_player.fit_class(ClassDef.all()[0])
	_player.grapple_to(enemy.global_position, Vector3.UP, enemy)
	_player._publish_line(0.0)
	_player.kit.line_state = Augments.LINE_SMASH
	_player.dunk.clear("reset")
	_player._begin_landing(enemy)
	_player._finish_landing(enemy, 20.0)
	_check("8 harpoon smash stores nothing", not _player.dunk.held(),
		"a smash landing (the reel's own slam) left the charge held %s" % _player.dunk.held())
	enemy.queue_free()

	_fresh()
	_slam()
	_player.dunk.tick(Dunk.WINDOW + 1.0)
	_check("7 events", _stored.size() == 1 and _expired.size() == 1 and _spent.size() == 0,
		"stored %d, spent %d, expired %d" % [_stored.size(), _spent.size(), _expired.size()])

	print("dunk_charge_test: %s (%d checks)" % ["PASS" if _failures == 0 else "FAIL", _count])
	quit(1 if _failures > 0 else 0)


# A miniboss on the shelf, in its turn or stalking; it never acts.
func _miniboss(in_turn: bool) -> Node3D:
	var at: Vector3 = _game.ctx.terrain.drop_point(FLAT_SHELF.x + 12.0, FLAT_SHELF.z, 1.0)
	var boss: Node3D = _combat.spawn_enemy("miniboss", at)
	boss.live = Callable(self, "_never")
	boss.hp = 100000.0
	boss.max_hp = 100000.0
	boss.state = boss.State.TURN if in_turn else boss.State.STALK
	return boss


# A reel impact (a smash landing) on the given body; returns the HP it removed.
func _reel_on(enemy: Node3D) -> float:
	var before: float = enemy.hp
	_player.smash_landing = enemy
	_combat.strike(enemy, "stomp", FORCE)
	_player.smash_landing = null
	return before - enemy.hp


func _strength() -> float:
	return _player.slam_strength(SPEED, 1.0)
