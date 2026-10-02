extends SceneTree

const BossPlate := preload("res://src/ui/boss_plate.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const T := preload("res://tests/support/t.gd")

# The posture Warden's health ring on the ground (LEGIBILITY section 4), on the slice table
# with a real fight driven through combat.strike() and a real harpoon smash: lit arcs equal
# chunks_left() after each shatter; the crack sits on the next arc to go exactly when
# chunk_cracked(); lit arcs take the open colour exactly while staggered(); every arc colour
# equals the plate's own reader for that state; the ring is freed with its Warden; a plating
# Warden has no ring.

const PLATING := 45.0

var _t := T.new("warden_ring_test")
var _game
var _combat
var _player
var _warden
var _plate
var _smashed := 0
var _source := Intent.Scripted.new()


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * Engine.physics_ticks_per_second))


func _matched_force() -> float:
	var force := 1.0
	while _combat.punch_of("ram", force) < PLATING:
		force += 0.05
	return force


func _fast_force() -> float:
	var force := _matched_force()
	var cruise: float = _player.tuning.f("cruise")
	while SpeedTier.of(force, cruise) < 2:
		force += 0.5
	return force


func _fill() -> void:
	var guard := 0
	while is_instance_valid(_warden) and not _warden.staggered() and guard < 20:
		_combat.strike(_warden, "ram", _matched_force())
		await physics_frame
		guard += 1
	await physics_frame


func _smash() -> void:
	_smashed = 0
	var at: Vector3 = _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT
	_player.reset_to(at + Vector3(-6.0, 6.0, 0.0))
	_player.grapple_to(at, Vector3.UP, _warden)
	_source.hold = {"harpoon_held": true}
	await _seconds(0.02)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	for tick in roundi(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if _smashed > 0:
			break
	_source.hold = {}


func _start(table: String) -> bool:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _speed: float): _smashed += 1)
	await _seconds(0.4)
	_game.run.set_max_hp(99999.0)
	_combat.heft_override = 1.0
	_warden = _game.flow.warden
	if not is_instance_valid(_warden):
		return false
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	return table != ""


# The ring against the warden's facts and the plate's readers, after the ring has run a frame.
func _state(label: String) -> void:
	await process_frame
	await process_frame
	var ring = _warden.get_node_or_null("WardenRing")
	if not _t.check("%s: the ring is there" % label, ring != null):
		return
	var left: int = _warden.chunks_left()
	var open: bool = _warden.staggered()
	var pips: Array = _plate.pips()
	_t.eq("%s: lit arcs equal chunks_left" % label, ring.lit_count(), left)
	var cracked_at: int = left - 1 if _warden.chunk_cracked() else -1
	_t.eq("%s: the crack sits on the next arc to go exactly when cracked" % label, ring.cracked_arc(), cracked_at)
	_t.eq("%s: the crack is drawn exactly when cracked" % label, ring.crack_visible(), _warden.chunk_cracked())
	var colours_ok := true
	var shown_ok := true
	for i in BossPosture.CHUNKS:
		var want: Color
		if pips[i]["filled"]:
			want = _plate.bar_color() if open else BossPlate.pip_color(true)
		else:
			want = BossPlate.pip_color(false)
		if ring.arc_color(i) != want:
			colours_ok = false
		if ring.shown_arc_color(i) != want:
			shown_ok = false
		_t.eq("%s: arc %d lit as the plate's pip %d" % [label, i, i], ring.lit(i), pips[i]["filled"])
	_t.check("%s: every arc colour is the plate's reader for its state" % label, colours_ok)
	_t.check("%s: every arc's material holds that colour" % label, shown_ok)
	_t.check("%s: lit arcs take the open colour exactly while staggered" % label, open == (left > 0 and ring.shown_arc_color(0) == _plate.bar_color() and _plate.bar_color() != BossPlate.pip_color(true)))
	_t.check("%s: the crack mark is the plate's crack colour" % label, ring.shown_crack_color() == _plate.crack_color() and ring.shown_backing_color() == BossPlate.crack_backing())


func _run() -> void:
	if not await _start("slice"):
		print("warden_ring_test: FAIL (no Warden on the slice table)")
		quit(1)
		return
	_plate = BossPlate.new()
	_plate.set_process(false)
	root.add_child(_plate)
	_plate.bind(_warden)
	_player.reset_to(_game.ctx.terrain.drop_point(_warden.global_position.x + 58.0, _warden.global_position.z, 1.5))
	await _seconds(0.3)
	await _state("fresh")
	await _fill()
	_t.check("the fight opened", _warden.staggered())
	await _state("open")
	_combat.strike(_warden, "stomp", _matched_force())
	await _frames(2)
	await _state("cracked and open")
	await _seconds(BossPosture.STAGGER_SECONDS + 0.5)
	_t.check("the stagger ran out", not _warden.staggered())
	await _state("cracked and closed")
	await _fill()
	await physics_frame
	_combat.strike(_warden, "ram", _fast_force())
	await _frames(2)
	_t.eq("a shatter leaves three chunks", _warden.chunks_left(), 3)
	await _state("after one shatter")
	await _seconds(0.5)
	await _fill()
	await _smash()
	await _seconds(1.0)
	_t.eq("a harpoon smash leaves two chunks", _warden.chunks_left(), 2)
	await _state("after two shatters")
	var ring = _warden.get_node_or_null("WardenRing")
	var warden: Node3D = _warden
	_plate.unbind()
	warden.free()
	await process_frame
	_t.check("the ring is freed with its Warden", not is_instance_valid(ring))
	_plate.free()
	_game.free()
	await _plating()
	quit(_t.verdict())


func _plating() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	if not await _start("plating"):
		_t.check("a Warden stands on the default table", false)
		return
	await _seconds(0.3)
	_t.eq("the default Warden fights by plating", _warden.fight(), "plating")
	_t.check("a plating Warden has no ring", _warden.get_node_or_null("WardenRing") == null)
	_game.free()
