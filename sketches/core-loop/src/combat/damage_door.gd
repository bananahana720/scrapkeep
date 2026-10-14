extends RefCounted

# SR1 one damage door (comps/W13-INTEGRATION-3.md unit SR1, comps/ror2/architecture.md).
# Every strike enters pass_hit(), which runs its owner's stages in ORDER and then the door's
# hooks for each event the hit raised, at most HOOK_CAP per event. The door holds no damage
# rule: each stage is the owner's existing code, so the numbers are the owner's.
#
#   armour    the plating rule (punch against plating less shred, or a posture judge)
#   caps      multipliers and exposures on what got through
#   crit      a consumed bonus (today the companion's prime; weapon crits ride in the force)
#   announce  the bus facts, before health so a kill never publishes a freed node
#   plates    the target's own reply: a plate pop, posture or boss pressure
#   health    take_damage, measured by health() below
#   execute   whether the hit killed
#   events    the owner's after-hit bookkeeping (shred, discovery, the delivered ledger)
#
# Hooks follow the last stage, so none runs before health. "hit" fires on every pass,
# "deflect" when the hit fell short of the plating, "kill" when it killed. A hook is
# Callable(hit), handed the hit record with every stage's result on it.
#
# health() is the one place HP leaves a target, for the door and for the wear trail's
# bypass (combat.gd _trail_deal), which takes no pass and fires no hook by design.

const ORDER := ["armour", "caps", "crit", "announce", "plates", "health", "execute", "events"]
const EVENTS := ["hit", "deflect", "kill"]
const HOOK_CAP := 4

# A test or the lab turns the trace on; each finished pass appends its stage and hook names.
var trace_on := false
var traces: Array = []

var _hooks := {"hit": [], "deflect": [], "kill": []}


# Seats a named hook on an event. False for an unknown event, a taken name or a full list.
func hook(event: String, name: String, fn: Callable) -> bool:
	if not _hooks.has(event) or hooks(event).has(name):
		return false
	if (_hooks[event] as Array).size() >= HOOK_CAP:
		return false
	_hooks[event].append([name, fn])
	return true


func unhook(event: String, name: String) -> bool:
	if not _hooks.has(event):
		return false
	var rows: Array = _hooks[event]
	for i in rows.size():
		if rows[i][0] == name:
			rows.remove_at(i)
			return true
	return false


func hooks(event: String) -> Array:
	var names := []
	for row in _hooks.get(event, []):
		names.append(row[0])
	return names


func pass_hit(hit: Dictionary, stages: Dictionary) -> Dictionary:
	var trace := []
	for stage in ORDER:
		if trace_on:
			trace.append(stage)
		var fn: Callable = stages.get(stage, Callable())
		if fn.is_valid():
			fn.call(hit)
	for event in EVENTS:
		if not _raised(hit, event):
			continue
		for row in (_hooks[event] as Array).duplicate():
			if trace_on:
				trace.append("hook:%s:%s" % [event, row[0]])
			(row[1] as Callable).call(hit)
	if trace_on:
		traces.append(trace)
	return hit


func _raised(hit: Dictionary, event: String) -> bool:
	match event:
		"deflect":
			return not bool(hit.get("result", {}).get("full", true))
		"kill":
			return bool(hit.get("killed", false))
	return true


# HP the target actually lost. A Brindle piece's hp is a getter over the boss's shared pool,
# which an enemy_struck listener can lower before take_damage runs, so the measure is the
# larger of take_damage's return and the hp drop since hp_before. hp is floored at 0 first:
# enemy.gd subtracts past 0, and the overkill swing is not removed HP.
static func health(enemy: Node3D, amount: float, hp_before: float) -> float:
	var removed: float = enemy.take_damage(amount)
	if is_instance_valid(enemy):
		removed = maxf(removed, hp_before - maxf(0.0, hp_of(enemy)))
	return removed


# hp is not part of the enemy protocol, but every implementation carries it; a target
# without one reads 0.0 and never inflates a delta.
static func hp_of(enemy: Node3D) -> float:
	if not is_instance_valid(enemy):
		return 0.0
	var v = enemy.get("hp")
	return float(v) if v != null else 0.0


static func dead(enemy: Node3D) -> bool:
	return not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead())
