extends RefCounted

# The trigger vocabulary (DESIGN-V2 section 7, I2 section 1). It is closed: an item's
# trigger is one of these twelve kinds or "" (passive), and a thirteenth kind is a code
# change here, never a data row. Each kind has one icon id (VISUAL-LANGUAGE section 5,
# trg_*), so a gate, a card and the codex all draw the same glyph for it.
#
# Every trigger is read at a commitment that already exists (a strike, a kill, a landed
# smash, a released gauge) and resolved in build's own physics step, never inside the
# signal handler that reported it (TADR-008). A root commitment opens one pass. While
# the pass resolves, a consumer may post other kinds, but a kind already queued or
# resolved in this pass is refused, so each kind fires at most once per commitment and
# every chain ends by construction: at most twelve resolutions. Five kills from one
# burst are one on_kill in that pass. The one sanctioned exception is an explicit chain
# (Domino Wire), which carries a chain mask and is refused when its type bit is already set.

enum Kind { ON_HIT, ON_KILL, ON_SMASH, ON_REBOUND, ON_VAULT, ON_CHARGE_RELEASE, ON_CLOAK_BREAK, ON_LAND,
	ON_SPEED_TIER_UP, ON_PICKUP, ON_DAMAGE_TAKEN, TIMED }

const NAMES := ["on_hit", "on_kill", "on_smash", "on_rebound", "on_vault", "on_charge_release", "on_cloak_break",
	"on_land", "on_speed_tier_up", "on_pickup", "on_damage_taken", "timed"]
const PASSIVE := ""
# The chain mask (RoR2 ProcChainMask, design-v3/research/comps/ror2/items-and-stacking.md):
# one bit per proc type a chain may carry, bits 0 to 31. A link whose type bit is already set
# in its chain is refused, so a chain ends instead of repeating, and distinct types still
# combine. Each chain type owns one bit; only domino (Domino Wire) chains today.
const CHAIN_TYPES := ["domino"]
# The most links one chain holds. Each chain type joins a chain once, so the mask bounds depth
# at one link per type, which is CHAIN_TYPES.size() today.
const MAX_CHAIN_DEPTH := 1

# base_proc for a discrete action the player chose: it already happened, so it always
# counts in full. on_hit and on_kill read the weapon's own value instead, keyed by the
# strike kind combat reports (a laser that fires ten times a second procs less per hit
# than a sticky charge). "synergy" is build's own strike: it never procs an item, which
# is the second guard against build feeding itself. "fusion" (SG2, element_field.gd) is the
# same: a grind strikes every enemy in its area on a beat, so it procs nothing.
const DISCRETE_PROC := 1.0
const STRIKE_PROC := {
	"stomp": 1.0, "ram": 1.0, "slam": 1.0, "shell": 1.0, "ring": 1.0, "line": 1.0,
	"arc": 0.6, "turret": 0.5, "pin": 0.5, "runner": 0.4, "synergy": 0.0, "fusion": 0.0,
}
const UNKNOWN_STRIKE_PROC := 0.5
# Golden-ratio offsets turn a pass's one draw into a separate roll per item, so two
# low-chance items in one pass never proc in lockstep, and the pass still draws once.
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


# The mask bit of a chain type, or 0 for a type that cannot chain.
static func chain_bit(proc_type: String) -> int:
	var i := CHAIN_TYPES.find(proc_type)
	return (1 << i) if i >= 0 else 0


# True when a link with this bit may join a chain whose mask is `mask`: a zero bit never
# joins, and a type the chain already holds is refused.
static func chain_allows(mask: int, bit: int) -> bool:
	return bit != 0 and (mask & bit) == 0


static func chain_add(mask: int, bit: int) -> int:
	return mask | bit


# One item's roll in a pass: the pass draw, spread by the item's slot and the
# commitment's place in the pass.
static func roll(draw: float, commitment_index: int, item_index: int) -> float:
	return fposmod(draw + SPREAD * float(1 + item_index + 7 * commitment_index), 1.0)


# A committed fact an item can answer. enemy may be null; at is where it happened;
# amount is the fact's size (a strike's force, damage taken, a release's fraction).
class Commitment:
	extends RefCounted

	var kind := 0
	var source := ""
	var base_proc := 1.0
	var at := Vector3.ZERO
	var enemy: Node3D = null
	var amount := 0.0
	var index := 0

	func _init(kind_value := 0, source_value := "", proc := 1.0, where := Vector3.ZERO, target: Node3D = null,
			size := 0.0) -> void:
		kind = kind_value
		source = source_value
		base_proc = proc
		at = where
		enemy = target
		amount = size


# The pass machinery. post() queues a root outside a pass, or a consequence inside one
# (refused when its kind is already queued or resolved in this pass). run() drains the roots, one
# pass each. The explicit, depth-capped chain (Domino Wire) lives with the pins in
# item_effects.gd, because a pin is combat's consequence, not a trigger kind.
class Bus:
	extends RefCounted

	var pending: Array = []
	var queue: Array = []
	# Kinds queued or resolved in the pass now running; cleared when it publishes.
	var resolving := {}
	var in_pass := false
	# Instrumentation the fuzzer and the tests read.
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

	# resolver(c: Commitment, draw: float). One draw per root pass.
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
		queue = [root]
		while not queue.is_empty():
			var c: Commitment = queue.pop_front()
			var n: int = _pass_counts.get(c.kind, 0) + 1
			_pass_counts[c.kind] = n
			max_same_kind = maxi(max_same_kind, n)
			fired[c.kind] = fired.get(c.kind, 0) + 1
			resolver.call(c, draw)
		resolving = {}
		in_pass = false

	# True if a pass left its guard set: the resolving flag leaked past publish.
	func leaked() -> bool:
		return not in_pass and not resolving.is_empty()

	func clear() -> void:
		pending.clear()
		queue.clear()
		resolving = {}
		in_pass = false
