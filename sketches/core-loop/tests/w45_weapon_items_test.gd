extends SceneTree

# W45-B2 U6 (design-v3/ABILITY-MUTATIONS.md sections 7 C1 and C2): the two weapon items.
# Slag Pike fuses every sixth weapon volley into one thick piercing bolt: volley five lights the
# muzzle ring copper, the fused damage is the volley's sum capped at 6x one bolt, range x1.25,
# the pierce bit rides inside MAX_SHOT_BITS, and only the player's own press advances the count.
# Halo Rig is one Pattern.TRANSFORMERS row: adds 5 arms (+1 base = 6 ring bolts), 55% damage, 85% rate, under the
# existing caps. Each rule carries a planted control: the naive version the rule exists to refuse.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Combat := preload("res://src/combat/combat.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const Parts := preload("res://src/build/parts.gd")
const Items := preload("res://src/build/items.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Palette := preload("res://src/core/palette.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("w45_weapon_items_test")
var _game
var _combat
var _player
var _source := Intent.Scripted.new()
var _steps := []
var _index := 0
var _ticks := 0
var _booted := false


func _initialize() -> void:
	_check_rows()
	_check_pike_table()
	_check_fused_bits()
	_check_halo()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _booted:
		_boot()
		return false
	if _index >= _steps.size():
		quit(_t.verdict())
		return true
	var step: Array = _steps[_index]
	step[0].call()
	_index += 1
	return false


func _boot() -> void:
	_booted = true
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_player = _game.player
	_steps = [
		[_check_cycle], [_check_cap_sum], [_check_idle_and_proc], [_check_live_bits], [_check_helix],
	]


# --- the data: both rows, their words, the admission ------------------------------------

func _check_rows() -> void:
	var pike: Resource = Parts.def("slag_pike")
	var halo: Resource = Parts.def("halo_rig")
	_t.check("both rows exist", pike != null and halo != null, "")
	_t.eq("pike maker, rarity and stack", [pike.maker, pike.rarity, pike.stack_rule, pike.stack_cap],
		["fleet_surplus", "rare", "capped", 1.0])
	_t.eq("pike effect", pike.effect, {"do": "pike_fuse", "every": 6, "cap_mult": 6.0, "range_mult": 1.25, "idle_s": 3.0})
	_t.check("pike is a kinetic weapon row that touches fire", pike.tags == ["kinetic"] and Items.TABLE["slag_pike"]["touches"] == "fire"
		and Items.TABLE["slag_pike"]["base"] == "weapon", str(pike.tags))
	_t.eq("halo maker, patterns and tags", [halo.maker, halo.patterns, halo.tags], ["highdraft_roosts", {"halo": 1}, ["split"]])
	_t.check("halo is a pattern row that touches fire and stacks to three",
		Items.TABLE["halo_rig"]["base"] == "pattern" and Items.TABLE["halo_rig"]["touches"] == "fire" and halo.stack_cap == 3.0, "")
	_t.check("halo settles at or below uncommon", halo.rarity in ["common", "uncommon"], halo.rarity)
	for id in ["slag_pike", "halo_rig"]:
		var d: Resource = Parts.def(id)
		_t.check("%s card line is at most six words" % id, WordBudget.words_in(String(d.verb)) <= 6, String(d.verb))
		_t.check("%s admitted to the alpha table and never a relic" % id, id in AlphaDefs.PARTS and not d.rarity in ["relic", "rare_plus"], d.rarity)
		_t.check("%s text carries its numbers and is never clipped" % id,
			String(d.text).count(" ") >= 4 and not "..." in String(d.text) and not "unleash" in String(d.text).to_lower()
			and WordBudget.words_in(String(d.text)) <= ItemGen.MAX_WORDS, String(d.text))
	_t.check("pike settled text keeps 6x intact", "6x" in String(pike.text) and not "..." in String(pike.text), String(pike.text))
	_t.check("halo settled text keeps 55% intact", "55%" in String(halo.text) and not "..." in String(halo.text), String(halo.text))
	_t.eq("pike's verb", String(pike.verb), "Every sixth volley fuses into one")
	_t.eq("halo's verb", String(halo.verb), "Fires shots in a wide ring")
	_t.check("pike_fuse is a closed-table effect", ItemEffects.EFFECTS.has("pike_fuse"), "")
	_t.check("halo is a transformer row", Pattern.has_transformer("halo"), "")
	# Planted control: a row naming an effect outside the closed table must not be in it.
	_t.check("a made-up effect id is not in the closed table", not ItemEffects.EFFECTS.has("pike_unleash"), "")


# --- Slag Pike's pure rules ---------------------------------------------------------------

func _check_pike_table() -> void:
	var row := {"every": 6, "cap_mult": 6.0, "range_mult": 1.25, "idle_s": 3.0}
	var count := 0
	var last := -INF
	var now := 0.0
	var seen: Array = []
	for press in 14:
		now += 0.2
		var step := Combat.pike_advance(count, last, now, row)
		count = int(step["count"])
		last = now
		seen.append("F" if step["fuse"] else ("R" if step["ring"] else "."))
	_t.eq("volleys 1-4 plain, 5 rings, 6 fuses, twice over", "".join(seen), "....RF....RF..")
	# 3.0 s of quiet restarts the count; 2.9 s keeps it.
	_t.eq("2.9 s of quiet keeps the count", int(Combat.pike_advance(3, 0.0, 2.9, row)["count"]), 4)
	_t.eq("3.0 s of quiet restarts the count", int(Combat.pike_advance(3, 0.0, 3.0, row)["count"]), 1)
	# Planted control: with no idle reset, five slow presses (3.5 s apart) would still reach the fuse.
	var slow := 0
	var never := true
	var t := 0.0
	var prev := -INF
	for press in 11:
		t += 3.5
		var s := Combat.pike_advance(slow, prev, t, row)
		slow = int(s["count"])
		prev = t
		never = never and not s["fuse"]
	_t.check("slow presses never fuse", never, "count %d" % slow)
	var no_idle := row.duplicate()
	no_idle["idle_s"] = INF
	var naive := 0
	var naive_prev := -INF
	var naive_fused := false
	t = 0.0
	for press in 11:
		t += 3.5
		var s := Combat.pike_advance(naive, naive_prev, t, no_idle)
		naive = int(s["count"])
		naive_prev = t
		naive_fused = naive_fused or s["fuse"]
	_t.check("planted control: a count with no idle reset fuses on slow presses", naive_fused, "")
	# Planted control: a count that also took proc volleys would fuse inside ten of them.
	var proc := 0
	var proc_fused := false
	for volley in 10:
		var s := Combat.pike_advance(proc, 0.0, 0.0, row)
		proc = int(s["count"])
		proc_fused = proc_fused or s["fuse"]
	_t.check("planted control: counting item_proc volleys would fuse", proc_fused, "")
	# The fused bolt: damage sum capped at 6x, range x1.25, wider, pierce colour.
	var record := {"damage": 10.0, "max_dist": 70.0, "radius": 0.3, "bits": 0, "color": Color.WHITE}
	var five := Combat.pike_bolt(record, 5, row)
	var nine := Combat.pike_bolt(record, 9, row)
	var one := Combat.pike_bolt(record, 1, row)
	_t.near("five bolts fuse to 5x", float(five["damage"]), 50.0)
	_t.near("nine bolts fuse to the 6x cap", float(nine["damage"]), 60.0)
	_t.check("planted control: an uncapped sum of nine would pass 6x", 10.0 * 9 > float(nine["damage"]), "")
	_t.near("one bolt stays 1x", float(one["damage"]), 10.0)
	_t.near("range x1.25", float(nine["max_dist"]), 87.5)
	_t.check("radius grows", float(nine["radius"]) > 0.3, str(nine["radius"]))
	_t.near("width_scale matches PIKE_RADIUS_MULT", float(nine.get("width_scale", 1.0)), Combat.PIKE_RADIUS_MULT)
	_t.eq("pierce colour", nine["color"], ShotBits.TABLE["pierce"]["color"])
	_t.check("the record is not edited in place", float(record["damage"]) == 10.0 and float(record["max_dist"]) == 70.0, "")


func _check_fused_bits() -> void:
	var pierce := ShotBits.bit("pierce")
	var three := ShotBits.bit("bounce") | ShotBits.bit("split") | ShotBits.bit("heat")
	_t.eq("three non-pierce bits is a full set", ShotBits.count(three), ShotBits.MAX_SHOT_BITS)
	var fused := Combat.fused_bits(three)
	_t.check("pierce replaces the third held bit, never a fourth", ShotBits.has(fused, pierce) and ShotBits.count(fused) <= ShotBits.MAX_SHOT_BITS,
		"%s" % [ShotBits.names(fused)])
	_t.check("the first two held bits stay", ShotBits.has(fused, ShotBits.bit("bounce")) and ShotBits.has(fused, ShotBits.bit("split")), "")
	_t.check("planted control: a plain union gives four bits", ShotBits.count(three | pierce) == 4, "%d" % ShotBits.count(three | pierce))
	_t.eq("a set that already holds pierce is unchanged", Combat.fused_bits(pierce | ShotBits.bit("heat")), pierce | ShotBits.bit("heat"))
	_t.eq("an empty set gains pierce", Combat.fused_bits(0), pierce)
	_t.eq("two bits gain pierce as a third", ShotBits.names(Combat.fused_bits(ShotBits.bit("split") | ShotBits.bit("pull"))), ["pierce", "split", "pull"])
	for mask in range(0, ShotBits.ALL + 1):
		if ShotBits.count(mask) > ShotBits.MAX_SHOT_BITS:
			continue
		var out := Combat.fused_bits(mask)
		if not ShotBits.has(out, pierce) or ShotBits.count(out) > ShotBits.MAX_SHOT_BITS:
			_t.check("every legal set fuses inside the cap (%d)" % mask, false, str(ShotBits.names(out)))
			return
	_t.check("every legal set fuses with pierce inside the cap", true, "")


# --- Halo Rig ---------------------------------------------------------------------------

func _check_halo() -> void:
	var base: Resource = Pattern.make({"damage": 10.0, "rate": 5.0})
	var ring: Resource = base.transformed(["halo"])
	_t.eq("halo adds five arms to a single line (six ring bolts)", ring.arms, 6)
	_t.check("the ring is at least 10 degrees off the aim", ring.arm_offset_deg >= 10.0, "%.1f" % ring.arm_offset_deg)
	_t.near("55% damage", ring.damage, 5.5)
	_t.near("85% rate", ring.rate, 4.25)
	_t.eq("a ring volley is the centre bolt and six ring bolts", ring.volley_size(), 7)
	_t.check("the arms stay apart", _arms_apart(ring), "")
	for weapon in Weapons.ALL:
		var row: Resource = Weapons.base(weapon)
		var r: Resource = row.transformed(["halo"])
		_t.check("%s keeps 55%% damage and 85%% rate" % weapon, absf(r.damage - row.damage * 0.55) < 0.0001
			and absf(r.rate - clampf(row.rate * 0.85, Pattern.MIN_RATE, Pattern.MAX_RATE)) < 0.0001, "%.2f/%.2f" % [r.damage, r.rate])
	var crossed: Resource = base.transformed(["halo", "cross_split"])
	_t.check("planted control: halo and cross split are nine arms before the cap", 1 + 5 + 3 > Pattern.MAX_ARMS, "")
	_t.eq("halo and cross split clamp at MAX_ARMS", crossed.arms, Pattern.MAX_ARMS)
	_t.check("and the volley stays under MAX_VOLLEY", crossed.volley_size() <= Pattern.MAX_VOLLEY and crossed.layout(Vector3.FORWARD, 0).size() <= Pattern.MAX_VOLLEY,
		"%d" % crossed.volley_size())
	var fanned: Resource = base.transformed(["halo", "cross_split", "fan_spread"])
	_t.check("planted control: halo, cross split and fan spread are over 16 bolts before the cap", 1 + 8 * 5 > Pattern.MAX_VOLLEY, "")
	_t.eq("the volley clamps at MAX_VOLLEY", fanned.volley_size(), Pattern.MAX_VOLLEY)
	var laid: Array = fanned.layout(Vector3.FORWARD, 0)
	_t.check("the trim drops the outermost, so the centre bolt stays", laid.size() == Pattern.MAX_VOLLEY and laid[0]["centre"], "%d bolts" % laid.size())
	var stacked: Resource = base.transformed(["halo", "fan_spread", "helix_drill"])
	_t.check("halo, fan spread and helix drill stay under every cap",
		stacked.arms <= Pattern.MAX_ARMS and stacked.volley_size() <= Pattern.MAX_VOLLEY and stacked.pierce <= Pattern.MAX_PIERCE
		and stacked.arm_offset_deg <= Pattern.MAX_ARM_OFFSET and stacked.wave_amp <= Pattern.MAX_WAVE,
		"arms %d, volley %d, pierce %d" % [stacked.arms, stacked.volley_size(), stacked.pierce])
	_t.near("their damage multiplies", stacked.damage, 10.0 * 0.55 * 0.65 * 0.75)
	var many: Resource = base.transformed(["halo", "halo", "halo"])
	_t.eq("three rigs still clamp at MAX_ARMS", many.arms, Pattern.MAX_ARMS)
	_t.check("three rigs hold the rate above the floor", many.rate >= Pattern.MIN_RATE, "%.3f" % many.rate)


func _arms_apart(p: Resource) -> bool:
	var dirs: Array = p.directions(Vector3.FORWARD, 0)
	for i in dirs.size():
		for j in range(i + 1, dirs.size()):
			if (dirs[i] as Vector3).dot(dirs[j]) > 0.99999:
				return false
	return true


# --- Slag Pike in the running game ---------------------------------------------------------

func _setup_player(parts: Array, transformers: Array, live_mask := 17) -> String:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()
	_source.hold = {}
	_source.press = {}
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_game.camera.pitch = 0.0
	_game.tuning.set_value("shot_bits_live", live_mask)
	_game.run.parts.assign(parts)
	_game.ctx.build.recompute()
	var weapon: String = _combat.active_weapon()
	_combat._patterns[weapon] = Weapons.base(weapon).transformed(transformers)
	_combat.bolts.clear()
	_combat.effects.clear()
	_combat._pike_count = 0
	_combat._pike_last = -INF
	_combat.volleys = 0
	return weapon


# One weapon press: what it fired and lit. `source` is the volley's tag.
func _press(weapon: String, source := "weapon") -> Dictionary:
	_combat.bolts.clear()
	var fired_before: int = _combat.bolts.fired
	var rings_before: int = _combat.effects._rings.size()
	_combat._clock += 0.2
	_combat._fire(weapon, source)
	var rings: Array = _combat.effects._rings
	return {"bolts": _combat.bolts.fired - fired_before, "live": _combat.bolts._bolts.duplicate(true),
		"rings": rings.size() - rings_before, "ring_color": rings[rings.size() - 1]["color"] if rings.size() > rings_before else null}


func _check_cycle() -> void:
	var weapon := _setup_player(["slag_pike"], ["cross_split", "cross_split", "cross_split"])
	var p: Resource = _combat._patterns[weapon]
	_t.eq("the held pike reaches combat as its table", int(_combat._pike_row().get("every", 0)), 6)
	var size: int = p.volley_size()
	_t.eq("the test volley is nine bolts", size, 9)
	var reach: float = p.range_m * _game.ctx.tuning.mod("weapon_range")
	var one_damage := 0.0
	var plain_width := 0.0
	for volley in range(1, 8):
		var shot := _press(weapon)
		var live: Array = shot["live"]
		var label := "volley %d" % volley
		if volley <= 5 or volley == 7:
			_t.eq("%s fires the whole pattern" % label, shot["bolts"], size)
			_t.check("%s is plain weapon fire, not the pike" % label, live.all(func(b): return b["source"] == "weapon" and absf(float(b["max_dist"]) - reach) < 0.001), "")
			one_damage = float(live[0]["damage"])
			if volley == 1:
				plain_width = Bolts.drawn_width(live[0])
		if volley == 5:
			_t.eq("volley five lights the muzzle ring", shot["rings"], 1)
			_t.eq("the ring is copper", shot["ring_color"], Palette.COPPER)
		elif volley != 6:
			_t.eq("%s lights no ring" % label, shot["rings"], 0)
		if volley == 6:
			var bolt: Dictionary = live[0]
			_t.eq("volley six fuses into one bolt", [shot["bolts"], live.size()], [1, 1])
			_t.eq("it is the player's own press", bolt["source"], "weapon")
			_t.near("its range is x1.25", float(bolt["max_dist"]), reach * 1.25, 0.001)
			_t.check("the pierce bit is on", ShotBits.has(int(bolt["bits"]), ShotBits.bit("pierce")), str(ShotBits.names(int(bolt["bits"]))))
			_t.eq("it draws in the pierce colour", bolt["color"], ShotBits.TABLE["pierce"]["color"])
			_t.check("it is wider than a plain bolt", float(bolt["radius"]) > p.bolt_radius, "%.2f" % float(bolt["radius"]))
			_t.near("it draws twice as thick as a plain bolt", Bolts.drawn_width(bolt), plain_width * Combat.PIKE_RADIUS_MULT, 0.001)
			_t.near("nine bolts' damage is capped at 6x one bolt", float(bolt["damage"]), one_damage * 6.0, 0.001)
			_t.check("planted control: the uncapped sum would be 9x", one_damage * size > float(bolt["damage"]) + 0.001, "")
			_t.eq("the cycle restarts at zero", _combat._pike_count, 0)
			_t.check("the last shot reads one fused bolt", _combat.last_shot["bolts"] == 1 and _combat.last_shot["fused"], str(_combat.last_shot))


func _check_cap_sum() -> void:
	# Five bolts fuse to 5x, under the cap: the cap bounds the sum, it does not set it.
	var weapon := _setup_player(["slag_pike"], ["cross_split"])
	var size: int = _combat._patterns[weapon].volley_size()
	var one := 0.0
	var fused := {}
	for volley in 6:
		var shot := _press(weapon)
		if volley == 0:
			one = float(shot["live"][0]["damage"])
		if volley == 5:
			fused = shot["live"][0]
	_t.eq("a cross volley is five bolts", size, 5)
	_t.near("five bolts fuse to 5x", float(fused["damage"]), one * 5.0, 0.001)


func _check_idle_and_proc() -> void:
	var weapon := _setup_player(["slag_pike"], ["cross_split"])
	for i in 3:
		_press(weapon)
	_t.eq("three presses count three", _combat._pike_count, 3)
	# item_proc volleys (Kick Shot, tree volleys) never advance the count and never fuse.
	var proc_ok := true
	for i in 12:
		var shot := _press(weapon, "item_proc")
		proc_ok = proc_ok and shot["bolts"] == 5 and shot["rings"] == 0 and shot["live"].all(func(b): return b["source"] == "item_proc" and int(b["bits"]) == 0)
	_t.check("twelve item_proc volleys fire plain and light nothing", proc_ok, "")
	_t.eq("and the count is untouched", _combat._pike_count, 3)
	# 3.0 s without firing restarts it.
	_combat._clock += 3.0
	var after := _press(weapon)
	_t.eq("a press after 3.0 s of quiet is volley one", _combat._pike_count, 1)
	_t.eq("and fires plain", after["bolts"], 5)
	_combat._pike_last = -INF
	_combat._pike_count = 3
	_combat._start_attempt()
	_t.eq("an attempt start clears the count", _combat._pike_count, 0)
	# Dropping the pike clears the cadence: a held part list without it counts nothing.
	_combat._pike_count = 4
	_game.run.parts.assign([])
	_game.ctx.build.recompute()
	var bare := _press(weapon)
	_t.check("without the pike a volley counts nothing and fires plain", _combat._pike_count == 0 and bare["bolts"] == 5, "count %d" % _combat._pike_count)


func _check_live_bits() -> void:
	# Three non-pierce bits held ahead of the pike: the cap already left pierce out, so the fuse swaps it in.
	var held := ["static_burr", "halo_rig", "tracer_round", "slag_pike"]
	var weapon := _setup_player(held, [], 31)
	var plain: int = _combat.shot_bits()
	_t.check("precondition: three non-pierce bits ride the shot", ShotBits.count(plain) == 3 and not ShotBits.has(plain, ShotBits.bit("pierce")),
		str(ShotBits.names(plain)))
	_combat._patterns[weapon] = Weapons.base(weapon)
	var fused := {}
	for volley in 6:
		var shot := _press(weapon)
		for bolt in shot["live"]:
			if ShotBits.count(int(bolt["bits"])) > ShotBits.MAX_SHOT_BITS:
				_t.check("no bolt holds four bits", false, str(ShotBits.names(int(bolt["bits"]))))
		if volley == 5:
			fused = shot["live"][0]
	var bits := int(fused["bits"])
	_t.check("the fused bolt holds pierce inside three bits", ShotBits.has(bits, ShotBits.bit("pierce")) and ShotBits.count(bits) <= ShotBits.MAX_SHOT_BITS,
		str(ShotBits.names(bits)))
	_t.check("planted control: a plain union of the held bits would be four", ShotBits.count(plain | ShotBits.bit("pierce")) == 4, "")
	_t.eq("the build's own bits are untouched after the fuse", _combat.shot_bits(), plain)


func _check_helix() -> void:
	var weapon := _setup_player(["slag_pike"], ["helix_drill"])
	var p: Resource = _combat._patterns[weapon]
	var fused := {}
	for volley in 6:
		var shot := _press(weapon)
		if volley == 5:
			fused = shot["live"][0]
	_t.eq("the pattern's pierce survives the fuse", int(fused["pierce"]), p.pierce)
	_t.eq("and the pierce bit adds one pass", Bolts.passes_left(fused), p.pierce + 1)
