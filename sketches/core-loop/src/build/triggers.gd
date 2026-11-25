extends RefCounted


enum Kind { ON_HIT, ON_KILL, ON_SMASH, ON_REBOUND, ON_VAULT, ON_CHARGE_RELEASE, ON_CLOAK_BREAK, ON_LAND,
	ON_SPEED_TIER_UP, ON_PICKUP, ON_DAMAGE_TAKEN, TIMED }

const NAMES := ["on_hit", "on_kill", "on_smash", "on_rebound", "on_vault", "on_charge_release", "on_cloak_break",
	"on_land", "on_speed_tier_up", "on_pickup", "on_damage_taken", "timed"]
const PASSIVE := ""
const CHAIN_TYPES := ["domino"]
const MAX_CHAIN_DEPTH := 1

const DISCRETE_PROC := 1.0
const STRIKE_PROC := {
	"stomp": 1.0, "ram": 1.0, "slam": 1.0, "shell": 1.0, "ring": 1.0, "line": 1.0,
	"arc": 0.6, "turret": 0.5, "pin": 0.5, "runner": 0.4, "synergy": 0.0, "fusion": 0.0,
}
const UNKNOWN_STRIKE_PROC := 0.5
const SPREAD := 0.6180339887


static func name_of(kind: int) -> String:
	return NAMES[kind] if kind >= 0 and kind < NAMES.size() else ""


static func kind_of(trigger_name: String) -> int:
	return NAMES.find(trigger_name)


static func is_trigger(trigger_name: String) -> bool:
	return trigger_name == PASSIVE or NAMES.has(trigger_name)


static func icon(trigger_name: String) -> String:
	return "trg_" + trigger_name if NAMES.has(trigger_name) else ""


static func strike_proc(strike_kind: String) -> float:
	return STRIKE_PROC.get(strike_kind, UNKNOWN_STRIKE_PROC)


static func chain_bit(proc_type: String) -> int:
	var i := CHAIN_TYPES.find(proc_type)
	return (1 << i) if i >= 0 else 0


static func chain_allows(mask: int, bit: int) -> bool:
	return bit != 0 and (mask & bit) == 0


static func chain_add(mask: int, bit: int) -> int:
	return mask | bit


static func roll(draw: float, commitment_index: int, item_index: int) -> float:
	return fposmod(draw + SPREAD * float(1 + item_index + 7 * commitment_index), 1.0)


class Commitment:
	extends RefCounted

	var kind := 0
	var source := ""
	var base_proc := 1.0
	var at := Vector3.ZERO
	var enemy: Node3D = null
	var amount := 0.0
	var index := 0

	func _init(kind_value: int = 0, source_value: String = "", proc: float = 1.0, where: Vector3 = Vector3.ZERO, target: Node3D = null,
			size: float = 0.0) -> void:
		assert(kind_value >= 0 and kind_value < NAMES.size(), "unknown trigger kind: %d" % kind_value)
		kind = kind_value
		source = source_value
		base_proc = proc
		at = where
		enemy = target
		amount = size


class Bus:
	extends RefCounted

	var pending: Array[Commitment] = []
	var queue: Array[Commitment] = []
	var resolving := {}
	var in_pass := false
	var passes := 0
	var fired := {}
	var refused := 0
	var max_same_kind := 0
	var _pass_counts := {}
	var _count := 0

	func post(c: Commitment) -> bool:
		if not in_pass:
			pending.append(c)
			return true
		if resolving.has(c.kind):
			refused += 1
			return false
		resolving[c.kind] = true
		c.index = _count
		_count += 1
		queue.append(c)
		return true

	func run(resolver: Callable, rng: RandomNumberGenerator) -> void:
		var roots := pending
		pending = []
		for root in roots:
			_pass(root, resolver, rng.randf())

	func _pass(root: Commitment, resolver: Callable, draw: float) -> void:
		in_pass = true
		passes += 1
		resolving = {}
		_pass_counts = {}
		_count = 1
		root.index = 0
		resolving[root.kind] = true
		queue.clear()
		queue.append(root)
		while not queue.is_empty():
			var c: Commitment = queue.pop_front()
			var n: int = _pass_counts.get(c.kind, 0) + 1
			_pass_counts[c.kind] = n
			max_same_kind = maxi(max_same_kind, n)
			fired[c.kind] = fired.get(c.kind, 0) + 1
			resolver.call(c, draw)
		resolving = {}
		in_pass = false

	func leaked() -> bool:
		return not in_pass and not resolving.is_empty()

	func clear() -> void:
		pending.clear()
		queue.clear()
		resolving = {}
		in_pass = false
