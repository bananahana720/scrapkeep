extends RefCounted

const ORDER := ["armour", "caps", "crit", "announce", "plates", "health", "execute", "events"]
const EVENTS := ["hit", "deflect", "kill"]
const HOOK_CAP := 4

var trace_on := false
var traces: Array = []

var _hooks := {"hit": [], "deflect": [], "kill": []}


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
		var fn: Callable = stages.get(stage, Callable())
		if not fn.is_valid():
			push_error("damage door: missing stage %s" % stage)
			if trace_on:
				trace.append("missing:%s" % stage)
			continue
		if trace_on:
			trace.append(stage)
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


static func health(enemy: Node3D, amount: float, hp_before: float) -> float:
	var removed: float = enemy.take_damage(amount)
	if is_instance_valid(enemy):
		removed = maxf(removed, hp_before - maxf(0.0, hp_of(enemy)))
	return removed


static func hp_of(enemy) -> float:
	if not is_instance_valid(enemy):
		return 0.0
	var v = enemy.get("hp")
	return float(v) if v != null else 0.0


static func dead(enemy) -> bool:
	return not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead())
