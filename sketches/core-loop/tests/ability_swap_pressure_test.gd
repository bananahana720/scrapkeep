extends SceneTree

const AbilityState := preload("res://src/core/ability_state.gd")
const T := preload("res://tests/support/t.gd")

# BUGFIX-CORE F003 (2026-10-09): a pressure row's cap belongs to that row. Swapping a slot
# away from ledger_reader (pressure 3) leaves the slot at 1 plus whatever items and picks
# added, never the pressure cap. No shipped tree makes this swap yet.

var _t := T.new("ability_swap_pressure_test")


func _initialize() -> void:
	var w: String = AbilityState.WEAPON
	var a := AbilityState.new()
	a.swap(w, "ledger_reader")
	_t.eq("ledger_reader raises the cap to its pressure", a.slot(w).max_charges, 3)
	a.swap(w, "rapid_laser")
	_t.eq("a swap away drops the pressure cap", a.slot(w).max_charges, 1)

	var b := AbilityState.new()
	b.swap(w, "rapid_laser")
	b.set_max_charges(w, b.slot(w).max_charges + 1)
	b.swap(w, "ledger_reader")
	_t.eq("a pick before the swap still reads pressure 3", b.slot(w).max_charges, 3)
	b.swap(w, "rapid_laser")
	_t.eq("the pick bought before ledger_reader stays", b.slot(w).max_charges, 2)

	var c := AbilityState.new()
	c.swap(w, "ledger_reader")
	c.set_max_charges(w, c.slot(w).max_charges + 1)
	_t.eq("a pick on top of pressure", c.slot(w).max_charges, 4)
	c.swap(w, "rapid_laser")
	_t.eq("a swap away keeps the pick, drops the pressure", c.slot(w).max_charges, 2)
	_t.eq("the swapped slot starts full", c.slot(w).charges, 2)

	# Re-pinned 2026-10-10 for the skill bar (SKILL-BAR.md section 1, "Tally's deck, re-cut",
	# wave P-B unit B1): a row's pool names the slot whose charges it spends, so Tally's slot 2
	# (gather plate) and slot 3 (link clips) draw from the reader's one pressure pool.
	# Re-pinned 2026-10-11 for wave P-C unit PC-TALLY (design-v3/pilots/tally.md sections 2 and 3,
	# Calls): Gather Plate leaves the pressure pool for its own 6 s cooldown and the ledger clip
	# carries no pool, so slots 2 and 3 spend their own charge and an empty reader leaves them
	# ready. Measured: [3, 0, 0] after one cast of each, and [true, true, 0] with the reader empty.
	# No ability row carries a pool after this unit; pool_of stays and the last case still covers
	# a row without one.
	var d := AbilityState.new()
	d.swap(w, "ledger_reader")
	d.swap(AbilityState.SPECIAL, "gather_plate")
	d.swap(AbilityState.LINE, "link_clips")
	d.spend(AbilityState.SPECIAL)
	d.spend(AbilityState.LINE)
	_t.eq("slots 2 and 3 spend their own charge, never the reader's pressure", [d.slot(w).charges, d.slot(AbilityState.SPECIAL).charges,
		d.slot(AbilityState.LINE).charges], [3, 0, 0])
	d.refill()
	for i in 3:
		d.spend(w)
	_t.eq("an empty reader leaves slots 2 and 3 ready", [d.ready(AbilityState.SPECIAL), d.ready(AbilityState.LINE),
		d.slot(w).charges], [true, true, 0])
	d.swap(AbilityState.SPECIAL, "detonation_gauge")
	_t.eq("a row with no pool spends its own charge", d.pool_of(AbilityState.SPECIAL), AbilityState.SPECIAL)
	quit(_t.verdict())
