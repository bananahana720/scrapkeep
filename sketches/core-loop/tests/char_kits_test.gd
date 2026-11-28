extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const Augments := preload("res://src/movement/augments.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const Contact := preload("res://src/movement/contact.gd")
const Combat := preload("res://src/combat/combat.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Indicator := preload("res://src/movement/indicator.gd")
const Icons := preload("res://src/core/icons.gd")

# The v2 W3 rules as data and pure functions (DESIGN-V2 sections 1 to 6): three class
# rows that every layer reads, class-gated movement kits with no shared air dash, the
# ability slots W1's HUD reads, charges that stockpile one at a time, the 0.4 s floor,
# the gauge's release scaling and cancel, the bowling-ball rebound, the vault's exit and
# its face lock, and the skill-shot forgiveness living in the hit test.
# Re-pinned 2026-10-10 (wave P-B unit B1, design-v3/SKILL-BAR.md sections 1 to 3): the bar
# has five slots on keys 1, Shift, 2, Ctrl, 3, the fifth the line skill; each record gains
# number, group, selected and select_left. The two shared placeholder rows (line_reel and
# ult_default) wear the drawn reel picture (Icons.EXTRA) until P-C gives every pilot its own
# ab_<pilot>_line and ab_<pilot>_ult file; no other row may lack a file.

const FIELDS := ["id", "display_name", "role", "species", "weapon_id", "movement_id", "special_id", "smash_id",
	"color", "shape", "motif", "sound", "bible_home"]
const SLOT_FIELDS := ["id", "icon", "key", "cooldown_frac", "charges", "max_charges", "state", "number", "group",
	"selected", "select_left"]
const BAR_KEYS := ["1", "Shift", "2", "Ctrl", "3"]
# The placeholder rows allowed a drawn icon until P-C, and the one picture they may wear.
const PLACEHOLDER_ICONS := {"line_reel": "ab_sable_reel", "ult_default": "ab_sable_reel"}

var _failures := 0


func _initialize() -> void:
	_rows()
	_kits()
	_slots()
	_charges()
	_floor()
	_gauge()
	_contact()
	_vault()
	_look()


# The hit test reads positions in the tree, so it runs on the first frame.
func _process(_delta: float) -> bool:
	_forgiveness()
	print("char_kits_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _rows() -> void:
	var rows := ClassDef.all()
	var ids := rows.map(func(d): return d.id)
	var complete := true
	var colours := {}
	for def in rows:
		for field in FIELDS:
			complete = complete and String(str(def.get(field))) != ""
		complete = complete and def.shape in EventKinds.SHAPES and def.color != Palette.HAZARD
		complete = complete and AbilityState.ABILITIES.has(def.weapon_id) and AbilityState.ABILITIES.has(def.movement_id) \
			and AbilityState.ABILITIES.has(def.special_id) and AbilityState.ABILITIES.has(def.smash_id) \
			and AbilityState.ABILITIES.has(def.line_id) and AbilityState.ABILITIES.has(def.ultimate_id)
		colours[def.color.to_html()] = true
	var motifs := rows.map(func(d): return d.motif)
	# The cannon (wave 16 look) has its own motif, shape and colour.
	_report("six rows", ids == ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"] \
			and complete and colours.size() == 6 and motifs == ["sable", "rivet", "kest", "tarn", "tally", "cannon"],
		"classes %s, every field set, shapes from the event vocabulary, six colours, none HAZARD, motif ids %s" % [ids, motifs])
	var tarn: Resource = ClassDef.by_id("tarn")
	var rivet: Resource = ClassDef.by_id("runner_gunner")
	var tarn_ids := [tarn.weapon_id, tarn.movement_id, tarn.special_id, tarn.smash_id]
	var rivet_ids := [rivet.weapon_id, rivet.movement_id, rivet.special_id, rivet.smash_id]
	var disjoint := tarn_ids.all(func(i): return not i in rivet_ids)
	var prose := (String(tarn.role) + " " + String(tarn.pitch) + " " + String(tarn.bible_home)).to_lower()
	_report("tarn is its own kit", disjoint and not prose.contains("placeholder") and Weapons.color(tarn.weapon_id) == ClassDef.TARN_COLOR,
		"Tarn ids %s share none with Rivet's %s; no placeholder prose; claw strikes in the class colour" % [tarn_ids, rivet_ids])
	var one_source := EventKinds.color("vault_kicked") == ClassDef.SABLE_COLOR \
		and EventKinds.color("sprint_started") == ClassDef.RIVET_COLOR and EventKinds.color("sticky_detonated") == ClassDef.KEST_COLOR
	_report("one colour source", one_source and Weapons.color(Weapons.RAPID_LASER) == ClassDef.RIVET_COLOR \
			and Weapons.color(Weapons.STICKY_CHARGE) == ClassDef.KEST_COLOR,
		"class-owned event rows read the class_def colour constants; Rivet's bolts are copper, Kest's charges amber")
	var gauge_sound: String = EventKinds.row("gauge_released")["sound"]
	var plant_sound: String = EventKinds.row("mounted")["sound"]
	_report("two Sable discharges", gauge_sound != plant_sound and gauge_sound != EventKinds.row("special_used")["sound"],
		"the gauge release rides gauge_released (%s) and the free plant discharge rides mounted (%s), both over special_used (%s)"
			% [gauge_sound, plant_sound, EventKinds.row("special_used")["sound"]])


func _kits() -> void:
	var ok := true
	var seen := []
	for def in ClassDef.all():
		var kit := AugmentKit.new()
		kit.fit(def.movement_id, def.smash_id)
		var on := []
		for spec in Augments.SPECS:
			if kit.on(spec["key"]):
				on.append(spec["key"])
		var want: Array = AbilityState.ABILITIES[def.movement_id]["augments"] + Augments.SHARED
		if not Augments.GRAPPLE in want:
			want.append(Augments.GRAPPLE)
		on.sort()
		want.sort()
		ok = ok and on == want
		seen.append("%s %s" % [def.display_name, on])
	var no_dash := Augments.SPECS.all(func(spec): return spec["key"] != "dash")
	_report("own movement only", ok and no_dash, "%s (every kit carries the harpoon line); no shared air dash row" % ", ".join(seen))


func _slots() -> void:
	var state := AbilityState.new()
	state.fit(ClassDef.by_id("runner_gunner"))
	var slots := state.slots()
	var shaped := slots.size() == 5
	for s in slots:
		for field in SLOT_FIELDS:
			shaped = shaped and (s as Dictionary).has(field)
	var keys := slots.map(func(s): return s["key"])
	var missing := []
	for id in AbilityState.ABILITIES:
		var icon: String = AbilityState.ABILITIES[id]["icon"]
		if PLACEHOLDER_ICONS.get(id, "") == icon and Icons.EXTRA.has(icon):
			continue
		if not icon.begins_with("ab_") or not FileAccess.file_exists(AbilityState.ICON_DIR + icon + ".svg"):
			missing.append(icon)
	_report("canonical icons", missing.is_empty() and slots[0]["icon"] == "ab_rivet_weapon",
		"every ability's icon is an ab_ id with a file in assets/icons; missing %s" % [missing])
	state.spend(AbilityState.MOVEMENT)
	var cooling: String = state.slots()[1]["state"]
	state.tick(2.5)
	var frac: float = state.slots()[1]["cooldown_frac"]
	var tarn: Resource = ClassDef.by_id("tarn")
	var tarn_state := AbilityState.new()
	tarn_state.fit(tarn)
	var tarn_slots := tarn_state.slots()
	var want_ids := [tarn.weapon_id, tarn.movement_id, tarn.special_id, tarn.smash_id, tarn.line_id]
	var tarn_ids := tarn_slots.map(func(s): return s["id"])
	var tarn_keys := tarn_slots.map(func(s): return s["key"])
	_report("tarn slots", tarn_slots.size() == 5 and tarn_ids == want_ids and tarn_keys == BAR_KEYS,
		"Tarn's five slots %s on keys %s" % [tarn_ids, tarn_keys])
	_report("slot contract", shaped and keys == BAR_KEYS and cooling == AbilityState.COOLING and is_equal_approx(frac, 0.5),
		"5 slots with %s; keys %s; a spent sprint reads %s, half recharged reads cooldown_frac %.2f" % [SLOT_FIELDS, keys, cooling, frac])


func _charges() -> void:
	var state := AbilityState.new()
	state.fit(ClassDef.by_id("demolitions_caster"))
	state.set_max_charges(AbilityState.MOVEMENT, 3)
	state.tick(100.0)
	var spent := 0
	while state.spend(AbilityState.MOVEMENT):
		spent += 1
	var cd := state.cooldown_of(AbilityState.MOVEMENT)
	var counts := []
	for i in 4:
		state.tick(cd * 0.5)
		counts.append(state.slot(AbilityState.MOVEMENT).charges)
		state.tick(cd * 0.5)
		counts.append(state.slot(AbilityState.MOVEMENT).charges)
	state.tick(100.0)
	var capped := state.slot(AbilityState.MOVEMENT).charges
	_report("charges stockpile", spent == 3 and counts == [0, 1, 1, 2, 2, 3, 3, 3] and capped == 3,
		"max 3: spent %d, then per half cooldown %s, capped at %d after a long wait" % [spent, counts, capped])


func _floor() -> void:
	var state := AbilityState.new()
	var worst := INF
	for def in ClassDef.all():
		state.fit(def)
		for name in AbilityState.SLOTS:
			state.set_cooldown_scale(name, 0.0)
			if state.slot(name).cooldown > 0.0:
				worst = minf(worst, state.cooldown_of(name))
	var rocket := AbilityState.floored(Weapons.ROCKET_COOLDOWN, 0.0)
	_report("cooldown floor", is_equal_approx(worst, AbilityState.COOLDOWN_FLOOR) and is_equal_approx(rocket, AbilityState.COOLDOWN_FLOOR),
		"every cooldown scaled to 0 floors at %.2f s; the rocket jump's self-launch floors at %.2f s" % [worst, rocket])


func _gauge() -> void:
	var fractions := []
	for hold in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var g := AbilityState.Gauge.new(1.0)
		g.begin()
		var t := 0.0
		while t < hold:
			g.step(1.0 / 90.0, true)
			t += 1.0 / 90.0
		g.step(1.0 / 90.0, false)
		fractions.append(snappedf(g.fired_fraction, 0.01))
	var rising := true
	for i in range(1, fractions.size()):
		rising = rising and fractions[i] > fractions[i - 1]
	var auto := AbilityState.Gauge.new(0.6)
	auto.begin()
	var ticks := 0
	while not auto.step(1.0 / 90.0, true):
		ticks += 1
	var cancel := AbilityState.Gauge.new(1.0)
	cancel.begin()
	cancel.step(0.3, true)
	var dropped := cancel.cancel()
	_report("gauge", rising and auto.auto and absf(float(ticks + 1) / 90.0 - 1.1) < 0.02 and dropped and not cancel.charging and cancel.fraction() == 0.0,
		"release fraction rises with hold %s; held full it fires itself at %.2f s (0.6 + 0.5 grace); a cancel leaves it idle at 0" % [fractions, float(ticks + 1) / 90.0])


func _contact() -> void:
	var heft := 1.6
	var rebound := Contact.rebounds(heft * 1.2, heft, false)
	var crush := not Contact.rebounds(heft * 0.8, heft, false)
	var sprint_edge := Contact.rebounds(heft * 1.05, heft, true) and not Contact.rebounds(heft * 1.05, heft, false)
	var v := Vector3(20.0, -2.0, 0.0)
	var n := Vector3(-1.0, 0.0, 0.0)
	var out := Contact.rebound_velocity(v, n, 13.0)
	var cap := Contact.rebound_velocity(Vector3(0.0, -40.0, 0.0), Vector3.UP, 13.0)
	_report("rebound rule", rebound and crush and sprint_edge and is_equal_approx(out.x, -13.0) and is_equal_approx(out.y, -2.0) \
			and is_equal_approx(cap.y, 13.0 * Contact.VERTICAL_CAP),
		"weight 1.2 x heft rebounds, 0.8 x crushes, 1.05 x rebounds only while sprinting; 20 m/s head-on leaves at %.1f, a 40 m/s drop bounces at most %.1f" % [out.x, cap.y])


func _vault() -> void:
	var slow := Augments.vault_exit(20.0, 13.0)
	var fast := Augments.vault_exit(30.0, 13.0)
	var floor_speed := Augments.vault_exit(2.0, 13.0)
	var a := Augments.face_key(Vector3(10.0, 5.0, 3.0), Vector3(-1.0, 0.0, 0.0))
	var a_far := Augments.face_key(Vector3(10.0, 9.0, -20.0), Vector3(-1.0, 0.05, 0.0))
	var b := Augments.face_key(Vector3(7.0, 5.0, 3.0), Vector3(1.0, 0.0, 0.0))
	_report("vault exit", absf(slow - 36.0) <= 36.0 * 0.05 and is_equal_approx(fast, Augments.VAULT_CAP) and is_equal_approx(floor_speed, 13.0),
		"incoming 20 -> %.1f m/s, 30 -> %.1f (cap %.0f), 2 -> %.1f (never slower than a jump)" % [slow, fast, Augments.VAULT_CAP, floor_speed])
	_report("face key", a == a_far and a != b, "one wall is one face anywhere along it (%s); the facing wall is another (%s)" % [a, b])


func _forgiveness() -> void:
	var edge := Node3D.new()
	var outside := Node3D.new()
	var centre := Vector3.ZERO
	var radius := 12.0
	var hull := 1.0
	edge.position = Vector3(radius * 1.1 + hull, 0.0, 0.0)
	outside.position = Vector3(radius * 1.3 + hull, 0.0, 0.0)
	root.add_child(edge)
	root.add_child(outside)
	var ring_ok := Combat.in_ring(centre, radius, edge) and not Combat.in_ring(centre, radius, outside)
	var from := Vector3.ZERO
	var to := Vector3(0.0, 0.0, 10.0)
	var line_ok := Combat.in_line(from, to, 2.5, Vector3(1.25 * 1.1 + hull, 0.0, 5.0), hull) \
		and not Combat.in_line(from, to, 2.5, Vector3(1.25 * 1.4 + hull, 0.0, 5.0), hull) \
		and Combat.in_line(from, to, 2.5, Vector3(0.0, 0.0, 10.0 * 1.1), 0.0)
	_report("forgiveness in the hit test", ring_ok and line_ok,
		"a hull 10%% past a drawn 12 m ring or 2.5 m lane is hit, 30%% past is not (allowance %.0f%%)" % [AbilityState.FORGIVENESS * 100.0])
	edge.free()
	outside.free()


func _look() -> void:
	var ring := {"kind": "ring", "centre": Vector3.ZERO, "radius": 12.0, "color": ClassDef.RIVET_COLOR, "ticks": "chevron", "fill": 0.4}
	var style := Indicator.style(ring, 0.0)
	var clean: bool = style["fill"] == Color(ClassDef.RIVET_COLOR, Indicator.FILL_ALPHA) and style["edge"] == ClassDef.RIVET_COLOR \
		and not style["dashed"] and not style["cross"]
	var full := ring.duplicate()
	full["fill"] = 1.0
	var alphas := []
	for i in 5:
		alphas.append(snappedf((Indicator.style(full, i * Indicator.BREATHE / 4.0)["fill"] as Color).a, 0.001))
	var breathes: bool = alphas[0] == alphas[4] and alphas[1] != alphas[0] and alphas[1] != alphas[3]
	var blocked := ring.duplicate()
	blocked["blocked"] = true
	var b := Indicator.style(blocked, 0.0)
	_report("indicator look", clean and breathes and b["edge"] == Palette.SAND and b["dashed"] and b["cross"] and Indicator.COLLAPSE == 0.12,
		"yours: class colour edge, %.0f%% clean fill, solid; at full the fill breathes on a %.1f s period %s; blocked: bone, dashed, charcoal cross; collapse %.2f s"
			% [Indicator.FILL_ALPHA * 100.0, Indicator.BREATHE, alphas, Indicator.COLLAPSE])
