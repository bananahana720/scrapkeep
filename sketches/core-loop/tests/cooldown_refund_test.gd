extends SceneTree

const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")

# SQ6 (W13-INTEGRATION-3.md, "SQ6 Combat cooldown refunds"): hits landed and damage taken
# shorten each pilot's mobility cooldown by 1 to 2 s, so fighting feeds movement
# (comps/roboquest/movement-and-feel.md:66). Per pilot, with scripted hits and damage:
# every refund is 1 to 2 s, no effective cooldown drops under half its base, a per-stage cap
# holds, mobility never reaches 100% uptime, and no base cooldown moves.

const DT := 0.05
# Worst-case pressure: a hit every tick and a hit taken every half second.
const HURT_EVERY := 0.5
const RUN_SECONDS := 60.0

var _t := T.new("cooldown_refund_test")


func _initialize() -> void:
	_check_table()
	var rows := []
	for def in ClassDef.all():
		rows.append(_pilot(def))
	print("pilot      slot      base_cd  min_gap  floor  uptime  grants  stage_total  cap")
	for r in rows:
		print("%-10s %-9s %6.2f  %7.2f  %5.2f  %5.2f  %6d  %11.2f  %5.1f" % [r["name"], r["slot"], r["base"],
			r["min_gap"], r["base"] * AbilityState.REFUND_CYCLE_SHARE, r["uptime"], r["grants"], r["stage_total"],
			AbilityState.STAGE_REFUND_CAP])
	quit(_t.verdict())


func _check_table() -> void:
	var sources: Array = AbilityState.REFUNDS.keys()
	_t.check("the table names hits landed and damage taken",
		AbilityState.REFUNDS.has(AbilityState.HIT_LANDED) and AbilityState.REFUNDS.has(AbilityState.DAMAGE_TAKEN),
		"sources %s" % [sources])
	var out_of_band := []
	for source in sources:
		var s := float(AbilityState.REFUNDS[source].get("seconds", -1.0))
		if not is_finite(s) or s < AbilityState.REFUND_MIN or s > AbilityState.REFUND_MAX:
			out_of_band.append("%s %s" % [source, s])
	_t.check("every table row refunds 1 to 2 s", out_of_band.is_empty()
		and is_equal_approx(AbilityState.REFUND_MIN, 1.0) and is_equal_approx(AbilityState.REFUND_MAX, 2.0),
		"out of band %s" % [out_of_band])
	_t.check("the cycle share keeps half the base", AbilityState.REFUND_CYCLE_SHARE > 0.0
		and AbilityState.REFUND_CYCLE_SHARE <= 0.5, "share %s" % AbilityState.REFUND_CYCLE_SHARE)
	_t.check("the stage cap is a positive finite number", is_finite(AbilityState.STAGE_REFUND_CAP)
		and AbilityState.STAGE_REFUND_CAP > 0.0, "cap %s" % AbilityState.STAGE_REFUND_CAP)
	var row: Dictionary = EventKinds.UI_ROWS.get("cooldown_refunded", {})
	var ok: bool = not row.is_empty() and row.get("color") is Color and row.get("group", "") in EventKinds.GROUPS \
		and row.get("shape", "") in EventKinds.SHAPES and String(row.get("sound", "")) != ""
	for field in EventKinds.FIELDS:
		ok = ok and row.has(field)
	_t.check("event_kinds carries one well-formed cooldown_refunded row", ok, "row %s" % [row])
	var a := AbilityState.new()
	a.fit(ClassDef.by_id("runner_gunner"))
	a.spend(AbilityState.MOVEMENT)
	_t.eq("an unknown source refunds nothing", [a.combat_refund("sneezed"), a.drain_refunds()], [0.0, []])


func _pilot(def) -> Dictionary:
	var name: String = def.display_name
	var a := AbilityState.new()
	a.fit(def)
	var slot: String = a.refund_slot()
	var base: float = a.cooldown_of(slot)
	var cooldowns_before := []
	for s in AbilityState.SLOTS:
		cooldowns_before.append(a.cooldown_of(s))
	_t.check("%s refunds a slot with a cooldown" % name, slot in AbilityState.SLOTS and base > 0.0,
		"slot %s base %s" % [slot, base])
	if slot != AbilityState.MOVEMENT:
		_t.check("%s falls back off the movement slot only when it has no cooldown" % name,
			a.cooldown_of(AbilityState.MOVEMENT) <= 0.0, "movement cd %s" % a.cooldown_of(AbilityState.MOVEMENT))

	# A full slot has nothing to shorten: no grant, no event, nothing off the stage cap.
	_t.eq("%s full slot takes no refund" % name, [a.combat_refund(AbilityState.HIT_LANDED), a.stage_refunded,
		a.drain_refunds()], [0.0, 0.0, []])

	# One scripted hit and one hit taken on a fresh cooldown.
	a.spend(slot)
	a.tick(DT)
	var hit := a.combat_refund(AbilityState.HIT_LANDED)
	var hurt_a := AbilityState.new()
	hurt_a.fit(def)
	hurt_a.spend(slot)
	hurt_a.tick(DT)
	var hurt := hurt_a.combat_refund(AbilityState.DAMAGE_TAKEN)
	_t.check("%s each scripted refund is 1 to 2 s" % name, hit >= 1.0 and hit <= 2.0 and hurt >= 1.0 and hurt <= 2.0,
		"hit %.2f, hurt %.2f" % [hit, hurt])
	var events := a.drain_refunds()
	var ev: Dictionary = events[0] if events.size() == 1 else {}
	_t.check("%s the refund publishes one cooldown_refunded record" % name, events.size() == 1
		and ev.get("kind", "") == "cooldown_refunded" and ev.get("slot", "") == slot and ev.get("id", "") == a.id_of(slot)
		and ev.get("source", "") == AbilityState.HIT_LANDED and is_equal_approx(float(ev.get("seconds", 0.0)), hit),
		"events %s" % [events])
	_t.eq("%s drain empties the queue" % name, a.drain_refunds(), [])

	# Worst-case pressure, stage cap lifted each tick, the pilot casting whenever ready.
	var b := AbilityState.new()
	b.fit(def)
	var floor_run := _spam(b, slot, true)
	var min_gap: float = floor_run["min_gap"]
	_t.check("%s effective cooldown never under half its base" % name,
		floor_run["casts"] >= 2 and min_gap >= base * 0.5 - DT - 0.0001,
		"min gap %.2f s, base %.2f s, %d casts" % [min_gap, base, floor_run["casts"]])
	_t.check("%s every granted refund is 1 to 2 s under pressure" % name, floor_run["bad_grants"].is_empty()
		and floor_run["grants"] > 0, "%d grants, out of band %s" % [floor_run["grants"], floor_run["bad_grants"]])
	var duration: float = maxf(b.slot(slot).duration, DT)
	var uptime: float = minf(1.0, duration * floor_run["casts"] / RUN_SECONDS)
	_t.check("%s mobility stays under 100%% uptime" % name, uptime < 1.0 and floor_run["cooling"] > 0.0,
		"uptime %.2f, cooling share %.2f" % [uptime, floor_run["cooling"] / RUN_SECONDS])

	# The per-stage cap holds without a reset, and a stage entry (refill) clears it.
	var c := AbilityState.new()
	c.fit(def)
	var cap_run := _spam(c, slot, false)
	_t.check("%s the stage cap holds" % name, cap_run["total"] <= AbilityState.STAGE_REFUND_CAP + 0.0001
		and is_equal_approx(c.stage_refunded, cap_run["total"]) and cap_run["total"] > 0.0,
		"granted %.2f s of a %.1f s cap" % [cap_run["total"], AbilityState.STAGE_REFUND_CAP])
	c.spend(slot)
	var past: float = c.combat_refund(AbilityState.DAMAGE_TAKEN)
	_t.check("%s once the cap is spent a hit taken refunds nothing" % name,
		c.stage_refunded + AbilityState.REFUND_MIN > AbilityState.STAGE_REFUND_CAP and past == 0.0,
		"stage tally %.2f, refund %.2f" % [c.stage_refunded, past])
	c.refill()
	_t.eq("%s a stage entry clears the stage tally" % name, c.stage_refunded, 0.0)

	var cooldowns_after := []
	for s in AbilityState.SLOTS:
		cooldowns_after.append(c.cooldown_of(s))
	_t.eq("%s base cooldowns unchanged" % name, cooldowns_after, cooldowns_before)
	return {"name": name, "slot": slot, "base": base, "min_gap": min_gap, "uptime": uptime,
		"grants": cap_run["grants"], "stage_total": cap_run["total"]}


func _spam(a, slot: String, lift_cap: bool) -> Dictionary:
	var t := 0.0
	var last_cast := -1.0
	var min_gap := INF
	var casts := 0
	var grants := 0
	var total := 0.0
	var cooling := 0.0
	var bad := []
	var next_hurt := 0.0
	var steps := int(round(RUN_SECONDS / DT))
	for i in steps:
		if a.ready(slot):
			if a.spend(slot):
				if last_cast >= 0.0:
					min_gap = minf(min_gap, t - last_cast)
				last_cast = t
				casts += 1
		if lift_cap:
			a.stage_refunded = 0.0
		var got: float = a.combat_refund(AbilityState.HIT_LANDED)
		if t >= next_hurt:
			next_hurt += HURT_EVERY
			if lift_cap:
				a.stage_refunded = 0.0
			var g2: float = a.combat_refund(AbilityState.DAMAGE_TAKEN)
			if g2 > 0.0:
				grants += 1
				total += g2
				if g2 < 1.0 or g2 > 2.0:
					bad.append(g2)
		if got > 0.0:
			grants += 1
			total += got
			if got < 1.0 or got > 2.0:
				bad.append(got)
		if a.state_of(slot) == AbilityState.COOLING:
			cooling += DT
		a.tick(DT)
		t += DT
	a.drain_refunds()
	return {"min_gap": min_gap, "casts": casts, "grants": grants, "total": total, "cooling": cooling, "bad_grants": bad}
