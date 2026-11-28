extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const Redline := preload("res://src/combat/redline.gd")
const Combat := preload("res://src/combat/combat.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")
const EliteAffixes := preload("res://src/combat/elite_affixes.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

# Heft destructibles, unit E (design-v3/HEFT-DESTRUCTIBLES.md sections 3.2, 5, 10.1 E and 10.2 T4). A real Game, real
# machines and a real module:
#   T4  a break next to machines strikes up to three of them as kind "debris" through Combat.strike and the damage door
#       (every stage runs, in the door's order), knocks each once, and the door's multipliers (the arc mark, a plated
#       elite's armour) reach the shard's damage; the ledger keeps one "debris" bucket; the kind has its own IMPACT row so
#       a shard freezes and shakes nothing. Planted controls: a direct take_damage leaves no door trace, an unnamed kind
#       lands as a plain hit, a bypassed multiplier reads as one.
#   synergy  the on-hit listeners see kind "debris" (the build's last strike kind, the bus), wrecking_ball keeps to rams,
#       and a debris-knocked machine is a pin carrier like any other. Redline spends on SPEND_KINDS only: a full shell
#       does not detonate on a shard or a shatter, and a kind in the list does (planted control).
#   Q    every pilot's Q landing (the default row, Tally, Kest, Tarn, Rivet) breaks a tier 2 piece inside the ring it
#       committed and leaves a tier 2 piece outside it and a tier 3 piece inside it, at class I.
# Evidence limit: rules and state in a headless run, not the look or the sound.

const FLAT_SHELF := Vector3(-45.0, 15.0, 6.0)
const WIDE := 4.0

var _t := T.new("destructibles_combat_test")
var _game
var _ctx
var _player
var _combat
var _source := Intent.Scripted.new()
var _fixture: Destructibles = null
var _struck: Array[Dictionary] = []
var _pins := 0


# The module with every blast it is asked for kept, so a landing's radius can be read against its own ring.
class Spy extends Destructibles:
	var blasts: Array[Dictionary] = []

	func on_blast(at: Vector3, radius: float, source: String, tier_bonus: int = 1, heft_class: int = -1) -> void:
		blasts.append({"at": at, "radius": radius, "source": source, "bonus": tier_bonus, "heft": heft_class})
		super.on_blast(at, radius, source, tier_bonus, heft_class)


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _ground(dx: float, dz := 0.0, lift := 2.0) -> Vector3:
	return _ctx.terrain.drop_point(FLAT_SHELF.x + dx, FLAT_SHELF.z + dz, lift)


func _row(id: String, tier: int, at: Vector3, size := Vector3(1.0, 2.0, 1.0)) -> Dictionary:
	return {"id": id, "tier": tier, "at": [at.x, at.y, at.z], "size": [size.x, size.y, size.z], "yaw_deg": 0.0}


func _host(rows: Array) -> Spy:
	_drop_fixture()
	var spy := Spy.new()
	spy.build({"destructible_rows": rows}, {"ctx": _ctx, "root": _ctx.root, "no_visuals": true})
	spy.finish_build()
	_ctx.destructibles = spy
	_player.bind_destructibles(spy, Callable(_ctx.run, "heft_class"))
	_fixture = spy
	return spy


func _drop_fixture() -> void:
	if _fixture != null and is_instance_valid(_fixture):
		_player.bind_destructibles(null)
		_ctx.destructibles = null
		_fixture.teardown()
		_fixture.queue_free()
	_fixture = null


func _machine(at: Vector3, affix := "") -> Node3D:
	var enemy: Node3D = _combat.spawn_enemy("chaser", at, affix)
	enemy.hp = 5000.0
	enemy.max_hp = 5000.0
	return enemy


func _clear_machines() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()


func _kinds() -> Array:
	return _struck.map(func(s: Dictionary) -> String: return String(s["kind"]))


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_ctx = _game.ctx
	_ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	await _sim(0.4)
	_ctx.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float) -> void:
		_struck.append({"enemy": enemy, "kind": kind, "force": force}))
	_ctx.events.enemy_pinned.connect(func(_victim: Node3D, _damage: float) -> void: _pins += 1)
	_t.eq("00 the run starts at class I", _ctx.run.heft_class(), 1)

	await _registered_kind()
	await _door()
	await _synergy()
	await _redline()
	await _landings()
	_clear_machines()
	_drop_fixture()
	quit(_t.verdict())


# --- T4: the kind is registered ------------------------------------------------------------------------------

func _registered_kind() -> void:
	var row: Dictionary = EventKinds.impact(Combat.DEBRIS)
	_t.check("T4 the debris kind has its own impact row", EventKinds.IMPACT.has(Combat.DEBRIS), str(row))
	_t.check("T4 a shard freezes and shakes nothing and shoves nothing", row["stop"] == "none" and float(row["shake"]) == 0.0
		and float(row["knock"]) == 0.0, str(row))
	_t.check("T4 control: a kind with no row lands as a plain hit that stops time", EventKinds.impact("no_such_kind")["stop"] == "hit"
		and EventKinds.impact("no_such_kind") != row, str(EventKinds.impact("no_such_kind")))
	_t.eq("T4 every debris strike is one source class", _combat._classify_source(Combat.DEBRIS, "debris:p7"), "debris")
	_t.eq("T4 control: another kind keeps the source it names", _combat._classify_source("ram", "weapon"), "weapon")
	await physics_frame


# --- T4: a break strikes through the door --------------------------------------------------------------------

# One class I blast on a tier 2 piece at `at`, `count` machines around the break point.
func _shatter_beside(count: int) -> Dictionary:
	_clear_machines()
	var at := _ground(-6.0, -6.0)
	var piece := Vector3(at.x + 3.0, at.y, at.z)
	var d := _host([_row("w", 2, piece)])
	var machines: Array = []
	for i in count:
		machines.append(_machine(Vector3(at.x + 2.0 + 0.3 * i, at.y, at.z + 0.4 * i - 0.8)))
	_struck.clear()
	_combat.door.traces.clear()
	_combat.door.trace_on = true
	_combat._ledger = {}
	var hp_before: Array = machines.map(func(m: Node3D) -> float: return float(m.hp))
	var knocks_before: Array = machines.map(func(m: Node3D) -> int: return int(m.knocks))
	_ctx.break_props(at, 6.0, "slam")
	_combat.door.trace_on = false
	return {"d": d, "machines": machines, "hp": hp_before, "knocks": knocks_before}


func _door() -> void:
	var r := _shatter_beside(5)
	var d: Spy = r["d"]
	var machines: Array = r["machines"]
	_t.eq("T4 the piece broke", d.state_of("w"), "shattered")
	var shards: Array = _struck.filter(func(s: Dictionary) -> bool: return s["kind"] == Combat.DEBRIS)
	_t.eq("T4 at most three of five machines in reach are struck, as the debris kind", shards.size(), 3)
	var hit_ids := {}
	for s in shards:
		hit_ids[s["enemy"].get_instance_id()] = true
	_t.eq("T4 no machine is struck twice", hit_ids.size(), 3)
	var knocked := 0
	var knocked_once := true
	for i in machines.size():
		var gained: int = int(machines[i].knocks) - int(r["knocks"][i])
		knocked += gained
		knocked_once = knocked_once and gained <= 1 and (gained == 1) == hit_ids.has(machines[i].get_instance_id())
	_t.check("T4 each struck machine is knocked once and the other two not at all", knocked == 3 and knocked_once, "%d knocks" % knocked)
	_t.check("T4 only the debris kind came out of the break", _kinds().all(func(k: String) -> bool: return k == Combat.DEBRIS), str(_kinds()))

	var traces: Array = _combat.door.traces
	var ran := traces.size() == 3 and traces.all(func(tr: Array) -> bool: return tr.slice(0, DamageDoor.ORDER.size()) == DamageDoor.ORDER)
	_t.check("T4 each strike passed every stage of the damage door, armour to events, in the door's order", ran, str(traces.size()))
	var lost := 0.0
	for s in shards:
		var m: Node3D = s["enemy"]
		lost += float(r["hp"][machines.find(m)]) - float(m.hp)
	_t.check("T4 the shards removed health through the door's health stage", lost > 0.0, "%.1f lost" % lost)
	var ledger: Dictionary = _combat.delivered_damage()
	_t.check("T4 the ledger keeps one debris bucket and no per-piece source", ledger["by_source"].has("debris")
		and not ledger["by_source"].keys().any(func(k: String) -> bool: return k.begins_with("debris:")), str(ledger["by_source"]))
	_t.check("T4 the ledger counts them as a debris action", ledger["by_action"].has("debris"), str(ledger["by_action"]))

	# Planted control: damage that bypasses strike() leaves no door trace.
	_combat.door.traces.clear()
	_combat.door.trace_on = true
	machines[0].take_damage(1.0)
	_combat.door.trace_on = false
	_t.check("T4 control: a direct take_damage runs no stage", _combat.door.traces.is_empty(), str(_combat.door.traces))

	await _multipliers()
	_clear_machines()
	_drop_fixture()
	await physics_frame


# The door's multipliers reach a shard: an arc mark raises it a tenth, a plated elite's armour resists it.
func _multipliers() -> void:
	_clear_machines()
	var at := _ground(-6.0, 8.0)
	var plain := _machine(at)
	var marked := _machine(at + Vector3(1.0, 0.0, 0.0))
	var plated := _machine(at + Vector3(2.0, 0.0, 0.0), EliteAffixes.PLATED)
	var force := 80.0
	_combat._arc_mark(marked)
	var hp := [float(plain.hp), float(marked.hp), float(plated.hp)]
	for m in [plain, marked, plated]:
		_combat.strike(m, Combat.DEBRIS, force, "", "debris:test")
	var plain_lost: float = hp[0] - float(plain.hp)
	var marked_lost: float = hp[1] - float(marked.hp)
	var plated_lost: float = hp[2] - float(plated.hp)
	_t.check("T4 a shard of force %.0f hurts a plain machine" % force, plain_lost > 0.0, "%.2f lost" % plain_lost)
	_t.check("T4 the arc mark's stage multiplier reaches the shard", is_equal_approx(marked_lost / plain_lost, 1.0 + Combat.ARC_MARK_FRACTION),
		"%.3f x" % (marked_lost / plain_lost))
	_t.check("T4 plated armour resists the shard", is_equal_approx(plated_lost / plain_lost, 0.6), "%.3f x" % (plated_lost / plain_lost))
	_t.check("T4 control: a bypassed multiplier reads as one, not as the marked figure", not is_equal_approx(plain_lost / plain_lost, marked_lost / plain_lost))
	await physics_frame


# --- synergy participation ---------------------------------------------------------------------------------

func _synergy() -> void:
	_clear_machines()
	var at := _ground(-6.0, -14.0)
	var build = _ctx.build
	build.sheet.transformers.append("wrecking_ball")
	build._rams.clear()
	var a := _machine(at)
	var b := _machine(at + Vector3(1.5, 0.0, 0.0))
	_struck.clear()
	_combat.strike(a, Combat.DEBRIS, 30.0, "", "debris:s1")
	_t.check("synergy the bus carries the debris strike", _kinds() == [Combat.DEBRIS], str(_kinds()))
	_t.eq("synergy the build's on-hit path read the strike's kind", build._last_strike_kind, Combat.DEBRIS)
	_t.eq("synergy wrecking_ball keeps to rams: a shard queues no shockwave", build._rams.size(), 0)
	_combat.strike(a, "ram", 20.0)
	_t.eq("synergy control: a ram does queue one", build._rams.size(), 1)
	build._rams.clear()
	build.sheet.transformers.erase("wrecking_ball")

	# A shard throws a machine like any knock, so the pin chain (ten_pin, domino_wire) reads it.
	_clear_machines()
	_ctx.run.add_part("ten_pin", "test")
	_ctx.run.add_part("domino_wire", "test")
	var d := _host([_row("p", 2, Vector3(at.x + 3.0, at.y, at.z))])
	var carrier := _machine(Vector3(at.x + 2.0, at.y, at.z))
	var victim := _machine(Vector3(at.x + 3.2, at.y, at.z + 0.1))
	_pins = 0
	_ctx.break_props(at, 6.0, "slam")
	_t.eq("synergy the piece broke", d.state_of("p"), "shattered")
	var struck_carrier: bool = carrier.knocks > 0
	var speed: float = carrier._knocked_speed() if struck_carrier else 0.0
	_t.check("synergy a machine a shard struck leaves the shatter as a knocked body", struck_carrier and speed > 0.0, "%.2f m/s" % speed)
	var before := _pins
	carrier.position = victim.position - Vector3(0.8, 0.0, 0.0)
	carrier.velocity = Vector3(Weapons.PIN_MIN_SPEED + 4.0, 0.0, 0.0)
	_combat._pin_step([carrier, victim])
	_t.check("synergy the pin chain reads a debris-knocked machine like any other (a pin lands)", _pins > before,
		"%d pins, %.1f m/s" % [_pins - before, carrier._knocked_speed()])
	_clear_machines()
	_drop_fixture()
	await physics_frame


# --- Redline ---------------------------------------------------------------------------------------------

func _redline() -> void:
	_t.check("Redline the debris kind is not in SPEND_KINDS", not Combat.DEBRIS in Redline.SPEND_KINDS, str(Redline.SPEND_KINDS))
	_t.check("Redline control: the ball's own contacts are", Redline.SPEND_KINDS == ["ram", "stomp", "slam"], str(Redline.SPEND_KINDS))
	var redline: Redline = _player.redline
	redline.set_mode(Redline.ON)
	redline._set_value(Redline.MAX)
	var before: int = redline.detonations

	_clear_machines()
	var at := _ground(-6.0, -22.0)
	var d := _host([_row("r", 2, Vector3(at.x + 3.0, at.y, at.z))])
	var m := _machine(Vector3(at.x + 2.0, at.y, at.z))
	_struck.clear()
	_ctx.break_props(at, 6.0, "slam")
	_t.check("Redline the shatter struck a machine as debris", d.state_of("r") == "shattered" and _kinds().has(Combat.DEBRIS), str(_kinds()))
	_t.check("Redline a debris strike at full redline spends nothing and detonates nothing", redline.detonations == before
		and is_equal_approx(redline.value, Redline.MAX) and redline.spend(Combat.DEBRIS, at, 30.0) == 0.0, "%d detonations" % (redline.detonations - before))
	_combat.strike(m, Combat.DEBRIS, 30.0, "", "debris:r")
	_t.check("Redline the strike path itself never asks Redline to spend", redline.detonations == before and is_equal_approx(redline.value, Redline.MAX))
	# Planted control: a kind in the list does spend, from the same full shell.
	var blast := redline.spend("ram", at, 30.0)
	_t.check("Redline control: a ram at the same full shell detonates it", blast > 0.0 and redline.detonations == before + 1, "blast %.1f" % blast)
	redline.set_mode(Redline.OFF)
	_clear_machines()
	_drop_fixture()
	await physics_frame


# --- Q landings --------------------------------------------------------------------------------------------

func _ring_fixture(at: Vector3, radius: float) -> Spy:
	return _host([
		_row("in2", 2, at + Vector3(radius - 1.5, 0.0, 0.0)),
		_row("out2", 2, at + Vector3(-(radius + 3.0), 0.0, 0.0)),
		_row("in3", 3, at + Vector3(0.0, 0.0, radius - 1.5)),
	])


func _split(d: Spy) -> bool:
	return d.state_of("in2") == "shattered" and d.state_of("out2") == "intact" and d.state_of("in3") == "intact"


func _states(d: Spy) -> String:
	return "in2 %s, out2 %s, in3 %s" % [d.state_of("in2"), d.state_of("out2"), d.state_of("in3")]


func _same_spot(a: Vector3, b: Vector3) -> bool:
	return absf(a.x - b.x) < 0.01 and absf(a.z - b.z) < 0.01


# One landing, fired at `at`, whose committed ring is `radius`: the +1 bypass, the one call it made, and the planted
# control, the same blast with a radius worked out separately (wider), which must disagree.
func _landing_case(label: String, at: Vector3, radius: float, fire: Callable) -> void:
	_clear_machines()
	var d := _ring_fixture(at, radius)
	fire.call(at)
	_t.check("Q %s: a class I landing breaks the tier 2 inside its ring and leaves the tier 2 outside and the tier 3 inside" % label,
		_split(d), _states(d))
	var blast: Dictionary = d.blasts.back() if not d.blasts.is_empty() else {}
	_t.check("Q %s: one call carrying the landing's own ring, a +1 bonus, the ultimate source and the run's class" % label,
		d.blasts.size() == 1 and blast.get("source") == "ultimate" and is_equal_approx(float(blast.get("radius", -1.0)), radius)
		and int(blast.get("bonus", 0)) == 1 and int(blast.get("heft", 0)) == _ctx.run.heft_class() and _same_spot(blast.get("at", Vector3.INF), at),
		str(d.blasts))
	var control := _ring_fixture(at, radius)
	_ctx.break_props(at, radius + WIDE, "control")
	_t.check("Q %s: planted control, a radius computed apart from the landing's ring breaks the piece outside it" % label,
		not _split(control), _states(control))


func _landings() -> void:
	var at := _ground(30.0, 20.0)
	var ult = _combat.ultimate
	var ring: float = ult.landing_radius()
	ult._plan = {"legs": []}

	_landing_case("default", at, ring, func(p: Vector3): _combat._ult_landing(p, 1.0, 1.0))
	for id in ["plate_return", "plate_audit", "plate_flywheel"]:
		var radius: float = ring + (Weapons.FLY_LANDING_BONUS if id == "plate_flywheel" else 0.0)
		_landing_case("Tally %s" % id, at, radius, func(p: Vector3): _combat.tally_kit.tally_landing(id, p, 1.0, 1.0))
	ult._id = "air_raid"
	ult._cast = {"id": "air_raid", "targets": {}, "landed": false, "posture": {}}
	_landing_case("Kest", at, ring, func(p: Vector3): ult.landing(p, 1.0, 1.0))
	ult._id = "windhover"
	_landing_case("Kest windhover (+1)", at, ring + 1.0, func(p: Vector3): ult.landing(p, 1.0, 1.0))
	ult._id = ""
	var tarn = _combat.get_node("TarnClaw")
	for id in ["redjaw_rend", "rake_run", "vice_leap"]:
		var radius: float = ring + (2.0 if id == "vice_leap" else 0.0)
		_landing_case("Tarn %s" % id, at, radius, func(p: Vector3): tarn.landing(id, p, 1.0, 1.0))
	var rivet = _combat.get_node("RivetKit")
	_landing_case("Rivet Breach", at, ring, func(p: Vector3): rivet.landing("foundry_cutter", p, 1.0, 1.0))
	_clear_machines()
	_drop_fixture()
	await physics_frame
