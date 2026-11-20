extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

# Rivet's Run and Gun wear trail (--world-one-builds=on, --wear=on, node r_run_gun). Each whole
# unit of rolling wear (run_state.wear_taken) leaves one short arc patch on the ground the ball
# is rolling over. The patches are combat's own damage, not a weapon: they hit an enemy
# through take_damage directly, never through strike(), so no item, chain or element listener
# sees them. They may kill; a spark kill drops scrap and counts, but procs no item or tree
# effect (run_state.last_kill_triggerless). And only wear makes a patch, so a patch never spawns a patch.
#
#   DAMAGE per hit, RADIUS from the patch to an enemy's hull, LIFE seconds, MAX_LIVE at once
#   (a new patch retires the oldest), and one hit per enemy per HIT_GAP across all patches.
# Drawn as a thin ring that pulses and a short arc to a struck enemy through combat's Effects,
# never a particle carpet. Reduce flashes dims both to the information share and slows the
# pulse to FlashGuard's 3 Hz cap. One soft sputter per patch: `patched` carries the spot, audio
# plays it.

const NODE_ID := "r_run_gun"
const DAMAGE := 14.0
const RADIUS := 1.0
const LIFE := 2.0
const MAX_LIVE := 6
const HIT_GAP := 0.5
const PULSE := 0.25
# The floor must lie this far below the ball or the ball is not on ground it traversed.
const FLOOR_REACH := 2.5

signal patched(at: Vector3)

var patches: Array = []
var hits := 0

var _ctx
var _effects
var _floor_at: Callable
var _clock := 0.0
var _last_hit := {}
var _run
# Wear below one whole unit, carried to the next signal so chunks under 1.0 still add up (F007).
var _wear_debt := 0.0
# Set by combat: deals the hit and writes it into the M0 delivered-damage ledger, returning the
# HP actually removed. Unset (a bare trail in a test), the patch calls take_damage itself.
var deal: Callable


func setup(ctx, effects, floor_at: Callable) -> void:
	_ctx = ctx
	_effects = effects
	_floor_at = floor_at


# True when the trail is live for this build: the world-one profile, the node picked.
func active() -> bool:
	if _ctx == null or not _ctx.tuning.world_one():
		return false
	return NODE_ID in _ctx.player.tree.path()


# One combat tick. Attaches to the current run's wear signal, drops everything when the trail
# is not active, ages and prunes the patches and lets them hit.
func step(delta: float, enemies: Array) -> void:
	if _ctx.run != _run:
		_run = _ctx.run
		_wear_debt = 0.0
		if _run != null and _run.has_signal("wear_taken") and not _run.wear_taken.is_connected(_on_wear):
			_run.wear_taken.connect(_on_wear)
	if not active():
		patches.clear()
		_last_hit.clear()
		return
	_clock += delta
	for patch in patches:
		patch["age"] += delta
	patches = patches.filter(func(p): return p["age"] < LIFE)
	for patch in patches:
		if _clock >= patch["pulse"]:
			patch["pulse"] = _clock + FlashGuard.period(PULSE)
			_effects.ring(patch["at"] + Vector3.UP * 0.05, RADIUS, _tone(1.0 - patch["age"] / LIFE))
		for enemy in enemies:
			_touch(patch, enemy)


func _on_wear(removed: float) -> void:
	if not active():
		return
	_wear_debt += removed
	var whole := int(floorf(_wear_debt))
	_wear_debt -= whole
	for i in whole:
		_place()


# One patch where the ball is, if it is on ground. Airborne wear leaves nothing.
func _place() -> void:
	var player = _ctx.player
	if not player.state.on_floor():
		return
	var ball: Vector3 = player.ball_position()
	var ground: Vector3 = _floor_at.call(ball)
	if ball.y - ground.y > FLOOR_REACH:
		return
	patches.append({"at": ground, "age": 0.0, "pulse": 0.0})
	while patches.size() > MAX_LIVE:
		patches.pop_front()
	patched.emit(ground)


func _touch(patch: Dictionary, enemy) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	if enemy.has_method("is_dead") and enemy.is_dead():
		return
	var id: int = enemy.get_instance_id()
	if _clock - float(_last_hit.get(id, -HIT_GAP)) < HIT_GAP:
		return
	var reach: float = RADIUS
	var r = enemy.get("radius")
	if r != null:
		reach += float(r)
	var offset: Vector3 = enemy.global_position - patch["at"]
	offset.y = 0.0
	if offset.length() > reach:
		return
	_last_hit[id] = _clock
	hits += 1
	var at: Vector3 = enemy.global_position
	# A patch may kill. The source rides on the enemy through the death emit, so run_state can
	# tell build and combat this kill procs no item and no tree effect, and is cleared after so
	# a hit that does not kill leaves nothing behind.
	var tagged: bool = "last_damage_source" in enemy
	if tagged:
		enemy.last_damage_source = "spark"
	if deal.is_valid():
		deal.call(enemy, DAMAGE)
	else:
		enemy.take_damage(DAMAGE)
	if tagged and is_instance_valid(enemy):
		enemy.last_damage_source = ""
	_effects.arc(patch["at"] + Vector3.UP * 0.1, at, _tone(1.0))


func _tone(fade: float) -> Color:
	var c := Palette.AMBER
	c.a = FlashGuard.info(clampf(0.25 + 0.5 * fade, 0.0, 1.0))
	return c
