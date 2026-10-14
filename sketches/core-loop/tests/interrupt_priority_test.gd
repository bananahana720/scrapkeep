extends SceneTree

# SR3 (W13-INTEGRATION-3, "Interrupt priority"): ability rows and the Fleet counters' states carry one
# integer interrupt priority (TADR-008: one integer per row, no tags or framework). A request lands only
# when it is strictly stronger than the state it would replace, and a tick changes the state at most once.
# A row also carries a sprint-cancel flag, and an active ability runs its base duration over attack speed.
#
# Checks: 2 row contract, 6 ability orderings (run count, weaker accepted, stronger refused, changes per
# tick, both outcomes seen, planted tie-accepting arbiter caught), 6 duration (value and run at attack
# speed 0.5, 1 and 2), 3 sprint cancel, 4 counter states (ladder, run count, weaker accepted, stronger
# refused), 1 check count. The count is fixed below and any other count fails.

const AbilityState := preload("res://src/core/ability_state.gd")
const Counter := preload("res://src/combat/counter.gd")
const T := preload("res://tests/support/t.gd")

const EXPECTED_CHECKS := 22
const ORDERINGS := 1000
const TICKS_PER_ORDERING := 6
const DT := 1.0 / 60.0
const SPEEDS := [0.5, 1.0, 2.0]
# Rivet's kit: the movement row has a 2 s duration, the rest run instantly.
const KIT := {"weapon": "rapid_laser", "movement": "overdrive_sprint", "special": "overdrive_blast",
	"smash": "shockwave_skid", "line": "line_drive"}
const ABILITY_API := ["request", "running_priority", "set_attack_speed", "duration_of", "take_sprint_cancel"]
const COUNTER_API := ["state_priority", "resolve_interrupt"]

var _t := T.new("interrupt_priority_test")
# Untyped, so a missing member reads as a failed check rather than a parse error.
var _ab = AbilityState.new()


func _counter_const(key: String) -> int:
	var script: Script = load("res://src/combat/counter.gd")
	return int(script.get_script_constant_map().get(key, -100))


func _initialize() -> void:
	var probe = _ab
	var counter = Counter.new()
	var missing := []
	for m in ABILITY_API:
		if not probe.has_method(m):
			missing.append("AbilityState." + m)
	for m in COUNTER_API:
		if not counter.has_method(m):
			missing.append("counter." + m)
	if not missing.is_empty():
		_t.check("the interrupt contract exists", false, "missing %s" % ", ".join(missing))
		counter.free()
		_finish()
		return
	_rows()
	_orderings()
	_planted()
	_durations()
	_sprint_cancel()
	_counter(counter)
	counter.free()
	_finish()


func _finish() -> void:
	var count := _t.checks
	_t.check("check count", count == EXPECTED_CHECKS - 1, "ran %d checks before this one, expected %d" % [count, EXPECTED_CHECKS - 1])
	quit(_t.verdict())


func _fit() -> Object:
	var a = AbilityState.new()
	for name in KIT:
		a.swap(name, KIT[name])
		a.set_max_charges(name, 99)
	a.refill()
	return a


func _rows() -> void:
	var bad := []
	for id in AbilityState.ABILITIES:
		var p = _ab.priority_of(id)
		var c = _ab.cancels_sprint_of(id)
		if typeof(p) != TYPE_INT or typeof(c) != TYPE_BOOL:
			bad.append(id)
	_t.check("every row carries an integer priority and a sprint-cancel flag", bad.is_empty(),
		"%d rows, bad %s" % [AbilityState.ABILITIES.size(), bad])
	var a = _fit()
	var copied := true
	for name in KIT:
		var s = a.slot(name)
		copied = copied and s.priority == _ab.priority_of(KIT[name]) \
			and s.cancels_sprint == _ab.cancels_sprint_of(KIT[name])
	_t.check("a swap copies the row's priority and flag into the slot", copied, "rivet kit")


# The oracle: a tick's winner is the first strongest ready request, and it lands only when strictly
# stronger than the state at the tick's start. Returns [weaker accepted, stronger refused, changes].
func _judge(before: int, asks: Array, after_name: String, after_priority: int, changed: int,
		before_name: String) -> Array:
	var best := -1
	for p in asks:
		best = maxi(best, p)
	var weaker := 0
	var stronger := 0
	var accepted: bool = changed > 0 and after_name != "" and (after_name != before_name or best > before)
	if accepted and after_priority <= before:
		weaker = 1
	if best > before and not (accepted and after_priority == best):
		stronger = 1
	return [weaker, stronger]


func _orderings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1003
	var runs := 0
	var weaker := 0
	var stronger := 0
	var worst_changes := 0
	var accepted := 0
	var refused := 0
	var names: Array = KIT.keys()
	for i in ORDERINGS:
		var a = _fit()
		for name in names:
			a.slot(name).priority = rng.randi_range(0, 4)
		a.set_attack_speed(SPEEDS[rng.randi_range(0, 2)])
		for tick in TICKS_PER_ORDERING:
			var requested := []
			var n := rng.randi_range(0, 4)
			for k in n:
				var name: String = names[rng.randi_range(0, names.size() - 1)]
				# Now and then a request on a slot with no charge, which never counts.
				if rng.randf() < 0.1:
					a.slot(name).charges = 0
				a.request(name)
				requested.append(name)
			var asks := []
			for name in requested:
				if a.ready(name):
					asks.append(a.slot(name).priority)
			var before: int = a.running_priority()
			var before_name: String = a.running
			var changes_before: int = a.state_changes
			a.tick(DT)
			var changed: int = a.state_changes - changes_before
			worst_changes = maxi(worst_changes, changed)
			var verdict := _judge(before, asks, a.running, a.running_priority(), changed, before_name)
			weaker += verdict[0]
			stronger += verdict[1]
			var best := -1
			for p in asks:
				best = maxi(best, p)
			if not asks.is_empty():
				if best > before:
					accepted += 1
				else:
					refused += 1
		runs += 1
	_t.eq("randomized orderings run", runs, ORDERINGS)
	_t.eq("weaker interrupts accepted", weaker, 0)
	_t.eq("stronger interrupts refused", stronger, 0)
	_t.check("at most one state change per tick", worst_changes <= 1, "worst %d" % worst_changes)
	_t.check("both outcomes exercised", accepted > 100 and refused > 100,
		"%d ticks with a stronger ask, %d with only weaker or equal asks" % [accepted, refused])


# Positive control: an arbiter that accepts a tie is caught by the same oracle.
func _planted() -> void:
	var caught := _judge(2, [2], "special", 2, 1, "weapon")
	_t.eq("the oracle flags a tie-accepting arbiter", caught[0], 1)


func _durations() -> void:
	var base: float = AbilityState.ABILITIES["overdrive_sprint"]["duration"]
	for speed in SPEEDS:
		var a = _fit()
		a.set_attack_speed(speed)
		var want: float = base / speed
		_t.near("duration at attack speed %s" % speed, a.duration_of("movement"), want, DT)
		a.request("movement")
		a.tick(DT)
		var ticks := 0
		while a.running == "movement" and ticks < 10000:
			a.tick(DT)
			ticks += 1
		_t.near("a run at attack speed %s lasts base over speed" % speed, ticks * DT, want, DT)


func _sprint_cancel() -> void:
	var a = _fit()
	a.slot("special").cancels_sprint = true
	a.request("special")
	a.tick(DT)
	var first: bool = a.take_sprint_cancel()
	var second: bool = a.take_sprint_cancel()
	_t.eq("a flagged activation cancels the sprint once", [first, second], [true, false])
	var b = _fit()
	b.request("weapon")
	b.tick(DT)
	_t.eq("an unflagged activation leaves the sprint", b.take_sprint_cancel(), false)
	var c = _fit()
	c.slot("weapon").priority = 4
	c.slot("special").priority = 1
	c.slot("special").cancels_sprint = true
	c.slot("weapon").base_duration = 1.0
	c.set_attack_speed(1.0)
	c.request("weapon")
	c.tick(DT)
	c.request("special")
	c.tick(DT)
	_t.eq("a refused flagged request cancels nothing", [c.running, c.take_sprint_cancel()], ["weapon", false])


func _counter(counter) -> void:
	var ladder := []
	for phase in [Counter.Phase.ROAM, Counter.Phase.WARN, Counter.Phase.LIVE]:
		counter.phase = phase
		ladder.append([counter.resolve_interrupt([_counter_const("KNOCK_PRIORITY")]) == 0,
			counter.resolve_interrupt([_counter_const("BREAK_PRIORITY")]) == 0])
	counter.phase = Counter.Phase.WARN
	var ladder_ok: bool = ladder[1] == [true, true] and ladder[2] == [false, true]
	_t.check("a knock breaks the warning, only the player's break ends the live phase", ladder_ok, str(ladder))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2003
	var runs := 0
	var weaker := 0
	var stronger := 0
	for i in ORDERINGS:
		counter.phase = [Counter.Phase.ROAM, Counter.Phase.WARN, Counter.Phase.LIVE][rng.randi_range(0, 2)]
		var before: int = counter.state_priority()
		var asks := []
		for k in rng.randi_range(0, 4):
			asks.append(rng.randi_range(0, 5))
		var win: int = counter.resolve_interrupt(asks)
		var best := -1
		for p in asks:
			best = maxi(best, p)
		if win >= 0 and asks[win] <= before:
			weaker += 1
		if best > before and (win < 0 or asks[win] != best):
			stronger += 1
		runs += 1
	counter.phase = Counter.Phase.ROAM
	_t.eq("counter orderings run", runs, ORDERINGS)
	_t.eq("counter: weaker interrupts accepted", weaker, 0)
	_t.eq("counter: stronger interrupts refused", stronger, 0)
