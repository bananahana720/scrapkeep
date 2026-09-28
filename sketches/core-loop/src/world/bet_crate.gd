extends "res://src/world/device.gd"

# A double-or-nothing crate, the risk-bet family (LOOP-REDESIGN section 9): a copper
# crate with a HAZARD stripe and an odds dial on a post, half mint (heads) and half rust
# (tails). Hold E to stake every bonus core you carry this stage: heads doubles them,
# tails burns them. The stake is on the prompt from the moment E locks the crate, before
# the hold starts. The result lands as three beats: the drum roll while the needle
# spins (interact_armed), the clunk as it stops on its half (interact_fired), then the
# crack of a win or the dry refusal of a loss (bet_resolved) as the cores move.
#
# One committed wager per crate per stage: once it lands the crate is spent. Its luck is
# the interact system's stream for this crate, run and stage, which a stage restart
# replays, so restarting to bet again lands the same way and fishing pays nothing.
# With no core to stake it is not ready: the dial shows, the keycap does not.

const ODDS := 0.5
const SPIN := 0.9
const LAND := 0.35
const TURNS := 3.0

var stake := 0
var outcome := false
var rolling := false
var last := {}
var _clock := 0.0
var _needle: Node3D
var _landed := false


func _init() -> void:
	family = "bet"


func build() -> void:
	box(Vector3(2.4, 1.8, 2.4), Vector3.UP * 0.9, Palette.solid(Palette.COPPER))
	box(Vector3(2.5, 0.35, 2.5), Vector3.UP * 1.2, Palette.striped(Palette.HAZARD, Palette.CHARCOAL))
	cylinder(0.15, 2.6, Vector3(0.0, 3.1, 0.0), Palette.solid(Palette.COPPER))
	var dial := Node3D.new()
	dial.position = Vector3(0.0, 4.6, 0.0)
	add_child(dial)
	var face := cylinder(1.2, 0.12, Vector3.ZERO, Palette.solid(Palette.SAND), dial)
	face.rotation.x = PI * 0.5
	box(Vector3(1.1, 2.2, 0.06), Vector3(-0.56, 0.0, 0.08), Palette.solid(Palette.ARC, 0.8), false, dial)
	box(Vector3(1.1, 2.2, 0.06), Vector3(0.56, 0.0, 0.08), Palette.solid(Palette.RUST), false, dial)
	_needle = Node3D.new()
	_needle.position = Vector3(0.0, 0.0, 0.16)
	dial.add_child(_needle)
	box(Vector3(0.14, 1.0, 0.05), Vector3(0.0, 0.45, 0.0), Palette.solid(Palette.CHARCOAL), false, _needle)


func reach_point() -> Vector3:
	return global_position + Vector3.UP * 1.2


func ready_now() -> bool:
	return not spent and not rolling and ctx.run.bonus_cores >= 1


func gauge() -> float:
	return _clock / (SPIN + LAND) if rolling else 0.0


func terms() -> String:
	var n: int = ctx.run.bonus_cores
	return "%d %s or none" % [n, "core" if n == 1 else "cores"]


func fire() -> bool:
	stake = ctx.run.bonus_cores
	outcome = system.luck(id).randf() < ODDS
	rolling = true
	_landed = false
	_clock = 0.0
	return false


# The needle sweeps TURNS turns and eases onto the middle of the winning half: left
# (mint) for heads, right (rust) for tails.
func tick(delta: float) -> void:
	if not rolling:
		return
	_clock += delta
	var rest := PI * 0.5 if outcome else -PI * 0.5
	var t := clampf(_clock / SPIN, 0.0, 1.0)
	_needle.rotation.z = rest + TAU * TURNS * (1.0 - t) * (1.0 - t)
	if not _landed and _clock >= SPIN:
		_landed = true
		system.fired(self)
	if _clock >= SPIN + LAND:
		rolling = false
		_resolve()


func _resolve() -> void:
	var at := reach_point()
	if outcome:
		for i in stake:
			ctx.run.add_core("bet", at)
	else:
		ctx.run.burn_cores()
	spent = true
	last = {"won": outcome, "stake": stake, "cores": ctx.run.bonus_cores}
	ctx.events.bet_resolved.emit(id, outcome, stake, at)
