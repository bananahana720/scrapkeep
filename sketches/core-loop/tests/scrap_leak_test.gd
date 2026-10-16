extends SceneTree

# SCRAP-LEAK: scrap nobody collects must not grow the scene without bound. 800 kills drop
# 12 pieces and 12 gears each with no collection; the live node count stays at the cap and
# every unit of value is still collectable. The planted control lifts the caps and must go red.
const Field := preload("res://src/build/scrap_field.gd")
const T := preload("res://tests/support/t.gd")
const KILLS := 800
const PER_KILL := 12

var t := T.new("scrap_leak_test")


func _initialize() -> void:
	_run.call_deferred()


func _fight(field, kills: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	for k in kills:
		var at := Vector3(float(k % 40) * 5.0, 0.0, float(k / 40) * 5.0)
		field.drop(at, PER_KILL, rng)
		field.drop_cogs(at, PER_KILL)
	# Warden-style line payouts take the same path.
	field.drop_line(Vector3.ZERO, Vector3.FORWARD, 30.0, 40, rng)
	field.drop_cogs_line(Vector3.ZERO, Vector3.FORWARD, 30.0, 40)


func _live(field) -> int:
	var n := 0
	for child in field.get_children():
		if not child.is_queued_for_deletion():
			n += 1
	return n


func _value_of(field) -> Array:
	var pieces := 0
	for item in field._items:
		if not field._cogs.has(item) and not field._value.has(item):
			pieces += 1 + int(field._units.get(item, 0))
	return [pieces, field.cog_value()]


func _run() -> void:
	var want := KILLS * PER_KILL + 40
	var field = Field.new()
	root.add_child(field)
	field.setup()
	_fight(field, KILLS)
	var live := _live(field)
	var cap: int = field.MAX_PIECES + field.MAX_GEARS
	t.check("live nodes at the cap after %d kills, nothing collected" % KILLS, live <= cap and live > 0, "%d live, cap %d" % [live, cap])
	t.check("loose pieces at or under their cap", field.count() <= field.MAX_PIECES, "%d" % field.count())
	t.check("loose gears at or under their cap", field.cog_count() <= field.MAX_GEARS, "%d" % field.cog_count())
	var totals := _value_of(field)
	t.eq("scrap value conserved", totals[0], want)
	t.eq("cog value conserved", totals[1], want)
	# Collecting everything pays every unit once: park the ball on each survivor in turn.
	var paid := 0
	var cogs_paid := 0
	var guard := 0
	while field._items.size() > 0 and guard < 5000:
		guard += 1
		var ball: Vector3 = field._items[0].global_position
		paid += field.step(ball, 0.0, 0.0).size()
		for v in field.cog_values:
			cogs_paid += int(v)
	t.eq("collecting the field pays every scrap unit", paid, want)
	t.eq("collecting the field pays every cog", cogs_paid, want)
	field.queue_free()

	var control = Field.new()
	root.add_child(control)
	control.setup()
	control.max_pieces = 1000000
	control.max_gears = 1000000
	_fight(control, KILLS)
	var open := _live(control)
	t.check("planted control: caps off, live nodes exceed the cap (the base behaviour)", open > cap, "%d live" % open)
	t.check("planted control would fail the cap check", not (open <= cap), "%d vs %d" % [open, cap])
	control.queue_free()
	quit(t.verdict())
