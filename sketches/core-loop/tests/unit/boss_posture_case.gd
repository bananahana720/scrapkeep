extends RefCounted

const Posture := preload("res://src/core/boss_posture.gd")
const Sweep := preload("res://tools/posture_sweep.gd")
const BotDriver := preload("res://tools/bot_driver.gd")

# The Warden's posture rule on the bare rule object (LEGIBILITY section 4): gain, one gain
# per frame from contacts, the glance floor, the stagger, the open core, one chunk per
# stagger, the drain and a pure judge.

const PLATING := 45.0
const HP := 800.0

var _frame := 0


func _hit(kind: String, punch: float, rule, extra := {}) -> Dictionary:
	_frame += 1
	var hit := {"kind": kind, "punch": punch, "plating": PLATING, "smash": false, "tier": 0, "charging": false,
			"frame": _frame, "hp": HP, "max_hp": HP}
	hit.merge(extra, true)
	var result: Dictionary = rule.judge(hit)
	rule.apply(result, _frame)
	return result


func _stagger(rule) -> void:
	while not rule.staggered:
		_hit("ram", PLATING, rule)
	_frame += 1


func run(t) -> void:
	_gain(t)
	_frame_max(t)
	_drain(t)
	_outside_a_stagger(t)
	_core(t)
	_pure(t)
	_defaults_unchanged(t)
	_curve(t)
	_ram_shatters(t)
	_heavy(t)
	_row_numbers(t)
	_base_override(t)
	_sweep_record(t)


func _gain(t) -> void:
	var rule := Posture.new()
	for i in 3:
		_hit("ram", PLATING, rule)
	t.near("three matched rams leave 90", rule.posture, 90.0)
	t.check("not staggered yet", not rule.staggered, "staggered at 90")
	_hit("ram", PLATING, rule)
	t.check("a fourth matched ram staggers", rule.staggered and rule.posture == 100.0 and rule.staggers == 1, "posture %s" % rule.posture)

	var floor_rule := Posture.new()
	var glance := _hit("ram", PLATING * Posture.MULT_MIN, floor_rule)
	t.near("a build at the floor gains 6 a ram", floor_rule.posture, 6.0)
	t.check("the floor hit is a glance", glance["glance"] and not glance["full"] and floor_rule.glances == 1, "glance %s" % glance["glance"])
	t.check("a matched hit is not a glance", not _hit("ram", PLATING, floor_rule)["glance"], "matched ram")

	var gun := Posture.new()
	_hit("runner", PLATING * 0.5, gun)
	t.near("a gun gains 1.5 times the multiplier", gun.posture, 1.5 * 0.5)
	var charging := Posture.new()
	_hit("runner", PLATING * 0.5, charging, {"charging": true})
	t.near("a gun gains 3.0 times the multiplier while charging", charging.posture, 3.0 * 0.5)
	var strong := Posture.new()
	t.near("a rule never told a class starts at the ordinary 1.5 ceiling", strong.mult_max, 1.5)
	strong.set_monster(true)
	_hit("ram", PLATING * 4.0, strong)
	# Andrew's tap "Lift the ceiling" (17 Oct 22:04Z): the cap is 3.0, was 1.5.
	t.near("a monster build caps at MULT_MAX 3.0", strong.posture, 90.0)
	var unknown := Posture.new()
	unknown.set_monster(false)
	t.near("a rule told no monster holds 1.5", unknown.mult_max, 1.5)
	var fresh := Posture.new()
	_hit("ram", PLATING * 4.0, fresh)
	t.near("a fresh rule meets the ordinary 1.5", fresh.posture, 45.0)
	var ordinary := Posture.new()
	ordinary.set_monster(false)
	_hit("ram", PLATING * 4.0, ordinary)
	t.near("a pilot who is no monster keeps the old 1.5 ceiling", ordinary.posture, 45.0)


func _frame_max(t) -> void:
	var rule := Posture.new()
	var first := rule.judge({"kind": "stomp", "punch": PLATING, "plating": PLATING, "smash": true, "frame": 7, "hp": HP, "max_hp": HP})
	rule.apply(first, 7)
	var second := rule.judge({"kind": "slam", "punch": PLATING, "plating": PLATING, "smash": true, "frame": 7, "hp": HP, "max_hp": HP})
	rule.apply(second, 7)
	t.near("a smash landing's two strikes gain 45 times the multiplier, not 75", rule.posture, 45.0)
	var later := rule.judge({"kind": "stomp", "punch": PLATING, "plating": PLATING, "smash": false, "frame": 8, "hp": HP, "max_hp": HP})
	t.near("the next frame's contact gains in full", later["gain"], 30.0)
	var bigger := Posture.new()
	var small := bigger.judge({"kind": "stomp", "punch": PLATING, "plating": PLATING, "frame": 3, "hp": HP, "max_hp": HP})
	bigger.apply(small, 3)
	var big := bigger.judge({"kind": "slam", "punch": PLATING, "plating": PLATING, "smash": true, "frame": 3, "hp": HP, "max_hp": HP})
	t.near("a larger second contact adds only the excess", big["gain"], 15.0)
	var gun_rule := Posture.new()
	var contact := gun_rule.judge({"kind": "ram", "punch": PLATING, "plating": PLATING, "frame": 4, "hp": HP, "max_hp": HP})
	gun_rule.apply(contact, 4)
	var bolt := gun_rule.judge({"kind": "runner", "punch": PLATING, "plating": PLATING, "frame": 4, "hp": HP, "max_hp": HP})
	t.near("another kind adds on top in the same frame", bolt["gain"], 1.5)


func _drain(t) -> void:
	var rule := Posture.new()
	_hit("ram", PLATING, rule)
	rule.step(3.0)
	t.near("3 s idle drains nothing", rule.posture, 30.0)
	rule.step(1.0)
	t.near("then 1 s of drain leaves 12 less", rule.posture, 18.0)
	rule.step(10.0)
	t.near("posture floors at 0", rule.posture, 0.0)
	var hold := Posture.new()
	_hit("ram", PLATING, hold)
	for i in 5:
		hold.step(2.0)
		_hit("runner", PLATING, hold)
	t.check("a gain resets the idle clock", hold.posture > 30.0, "posture %s" % hold.posture)


func _outside_a_stagger(t) -> void:
	var rule := Posture.new()
	var dealt := 0.0
	var kinds := ["ram", "stomp", "slam", "runner", "arc", "turret", "synergy", "shell"]
	var n := 0
	for i in 50:
		var result := _hit(kinds[i % kinds.size()], PLATING * 2.0, rule, {"smash": i % 3 == 0, "tier": 3})
		dealt += float(result["dealt"])
		if rule.staggered:
			rule.step(10.0)
			n += 1
	t.check("50 mixed hits outside a stagger leave 4 chunks", rule.chunks == 4 and dealt == 0.0 and n >= 1,
		"chunks %d, dealt %s, %d staggers passed" % [rule.chunks, dealt, n])

	var edge := Posture.new()
	for i in 3:
		_hit("ram", PLATING, edge)
	var filling := _hit("ram", PLATING, edge, {"smash": true, "tier": 3})
	t.check("the hit that staggers cannot shatter in that frame", edge.staggered and not filling["shatter"] and filling["dealt"] == 0.0, "result %s" % filling)
	var same := edge.judge({"kind": "slam", "punch": PLATING, "plating": PLATING, "smash": true, "frame": _frame, "hp": HP, "max_hp": HP})
	t.check("nor can the same frame's next strike", not same["shatter"] and same["dealt"] == 0.0 and same["part"] == "", "result %s" % same)
	var ignored := edge.judge({"kind": "ram", "punch": PLATING, "plating": PLATING, "frame": _frame + 1, "hp": HP, "max_hp": HP})
	t.near("gains are ignored while staggered", ignored["gain"], 0.0)


func _core(t) -> void:
	var rule := Posture.new()
	_stagger(rule)
	var smash := _hit("stomp", PLATING, rule, {"smash": true})
	t.check("a smash on the open core shatters", smash["shatter"] and smash["part"] == "core" and not rule.staggered, "result %s" % smash)
	t.near("the shatter deals one chunk", smash["dealt"], HP / 4.0)
	t.check("a shatter closes the Warden and clears the bar", rule.chunks == 3 and rule.posture == 0.0 and not rule.cracked and rule.shattered_this_stagger, "chunks %d posture %s" % [rule.chunks, rule.posture])
	var shockwave := rule.judge({"kind": "slam", "punch": PLATING, "plating": PLATING, "smash": true, "frame": _frame, "hp": HP, "max_hp": HP})
	t.near("the shatter's own frame gains nothing", shockwave["gain"], 0.0)
	var next := rule.judge({"kind": "ram", "punch": PLATING, "plating": PLATING, "frame": _frame + 1, "hp": HP, "max_hp": HP})
	t.near("the next frame's contact gains in full again", next["gain"], 30.0)

	var slow := Posture.new()
	_stagger(slow)
	var crack := _hit("ram", PLATING, slow, {"tier": 1})
	t.check("a tier-1 ram cracks and deals 0", crack["crack"] and not crack["shatter"] and crack["dealt"] == 0.0 and slow.cracked and slow.chunks == 4, "result %s" % crack)
	var again := _hit("ram", PLATING, slow, {"tier": 1})
	t.check("a second lesser hit in the same stagger does not shatter", not again["shatter"] and again["dealt"] == 0.0 and slow.chunks == 4 and slow.staggered and slow.cracked, "result %s" % again)
	slow.step(Posture.STAGGER_SECONDS + 0.1)
	t.check("a stagger that runs out keeps the crack and clears the bar", not slow.staggered and slow.cracked and slow.posture == 0.0 and slow.chunks == 4, "cracked %s" % slow.cracked)
	_stagger(slow)
	var broken := _hit("ram", PLATING, slow, {"tier": 1})
	t.check("the second stagger's tier-1 ram shatters", broken["shatter"] and slow.chunks == 3 and not slow.cracked, "result %s" % broken)

	var fast := Posture.new()
	_stagger(fast)
	t.check("a tier-2 ram shatters", _hit("ram", PLATING, fast, {"tier": 2})["shatter"], "tier 2 ram")

	var weak := Posture.new()
	_stagger(weak)
	var weak_stomp := _hit("stomp", PLATING * Posture.MULT_MIN, weak)
	t.check("a glancing contact on the open core still cracks", weak_stomp["glance"] and weak_stomp["crack"] and weak.cracked and weak.chunks == 4, "result %s" % weak_stomp)
	var weak_smash := Posture.new()
	_stagger(weak_smash)
	t.check("a glancing smash on the open core still shatters", _hit("stomp", PLATING * Posture.MULT_MIN, weak_smash, {"smash": true})["shatter"] and weak_smash.chunks == 3, "chunks %d" % weak_smash.chunks)

	var gun := Posture.new()
	_stagger(gun)
	var bolt := _hit("runner", PLATING * 4.0, gun)
	var blast := _hit("synergy", PLATING * 4.0, gun, {"smash": true})
	t.check("a gun on the open core does nothing", not bolt["shatter"] and not bolt["crack"] and bolt["dealt"] == 0.0 and not gun.cracked and gun.staggered, "result %s" % bolt)
	t.check("a synergy strike on the open core does nothing", not blast["shatter"] and not blast["crack"] and blast["dealt"] == 0.0, "result %s" % blast)

	var all := Posture.new()
	var hp := HP
	var total := 0.0
	for i in 4:
		_stagger(all)
		var result := _hit("stomp", PLATING, all, {"smash": true, "hp": hp})
		hp -= float(result["dealt"])
		total += float(result["dealt"])
	t.check("four shatters leave 0 chunks and sum to max_hp", all.chunks == 0 and absf(total - HP) < 0.001 and absf(hp) < 0.001, "chunks %d, dealt %s" % [all.chunks, total])


func _pure(t) -> void:
	var rule := Posture.new()
	_hit("ram", PLATING, rule)
	var snapshot := [rule.posture, rule.staggered, rule.stagger_left, rule.stagger_frame, rule.idle, rule.chunks, rule.cracked,
			rule.shattered_this_stagger, rule.gain_frame, rule.gain_in_frame, rule.staggers, rule.glances, rule.get("crack_stagger"), rule.get("shatter_frame")]
	var hit := {"kind": "stomp", "punch": PLATING, "plating": PLATING, "smash": true, "tier": 2, "charging": true, "frame": rule.gain_frame, "hp": HP, "max_hp": HP}
	var first: Dictionary = rule.judge(hit)
	var same := true
	for i in 20:
		same = same and rule.judge(hit) == first
	var after := [rule.posture, rule.staggered, rule.stagger_left, rule.stagger_frame, rule.idle, rule.chunks, rule.cracked,
			rule.shattered_this_stagger, rule.gain_frame, rule.gain_in_frame, rule.staggers, rule.glances, rule.get("crack_stagger"), rule.get("shatter_frame")]
	t.check("judge twenty times changes nothing and answers the same", same and after == snapshot, "before %s after %s" % [snapshot, after])


# The kinds and ratios of 20 hits, each answered with the rule's original formula (base times
# the ratio clamped to 0.2-1.5, the ordinary ceiling a rule never told a class holds, gain only outside a stagger, a core hit shattering for a smash or a ram of
# tier 2 or better) written out here. A stagger filled on a hit whose index is a multiple of 3 stays open for the next hit, and the
# gun hits at i = 4 and 14 are charging.
func _defaults_unchanged(t) -> void:
	var kinds := ["ram", "stomp", "slam", "ram", "runner"]
	var ratios := [1.5, 1.3, 2.5, 1.0, 0.9, 0.2, 0.5, 0.05]
	var plain := Posture.new()
	var explicit := Posture.new({"curve": 1.0, "ram_shatters": true})
	var same := true
	var detail := ""
	var core_hits := 0
	var charging_gun := 0
	var shatters := 0
	for i in 20:
		var kind: String = kinds[i % kinds.size()]
		var ratio: float = ratios[i % ratios.size()]
		var smash := i % 4 == 3
		var charging := kind == "runner" and i % 10 == 4
		var expected := 30.0
		if kind == "runner":
			expected = Posture.OTHER_BASE_CHARGING if charging else Posture.OTHER_BASE
		elif smash:
			expected = Posture.SMASH_BASE
		expected *= clampf(ratio, 0.2, 1.5)
		var was_open: bool = plain.staggered
		var paid: bool = plain.cracked and plain.crack_stagger < plain.staggers
		var expected_shatter := was_open and kind != "runner" and (smash or kind == "ram" or paid)
		if was_open:
			expected = 0.0
			core_hits += 1
			shatters += 1 if expected_shatter else 0
		if charging:
			charging_gun += 1
		var extra := {"smash": smash, "charging": charging, "tier": 3}
		_frame += 1
		var hit := {"kind": kind, "punch": PLATING * ratio, "plating": PLATING, "frame": _frame, "hp": HP, "max_hp": HP}
		hit.merge(extra, true)
		var a: Dictionary = plain.judge(hit)
		var b: Dictionary = explicit.judge(hit)
		if a != b or not is_equal_approx(float(a["gain"]), expected) or bool(a["shatter"]) != expected_shatter:
			same = false
			detail = "hit %d %s ratio %s: plain %s, explicit %s, expected gain %s shatter %s" % [i, kind, ratio, a, b, expected, expected_shatter]
		plain.apply(a, _frame)
		explicit.apply(b, _frame)
		if plain.staggered and i % 3 != 0:
			plain.step(10.0)
			explicit.step(10.0)
	t.check("the 20 hits include open-core hits, a shatter and a charging gun hit", core_hits >= 2 and shatters >= 1 and charging_gun >= 1,
			"%d core hits (%d shatters), %d charging gun hits" % [core_hits, shatters, charging_gun])
	t.check("curve 1.0 and ram_shatters true reproduce the original gain and shatter results over 20 hits", same, detail)
	t.check("both rules end in the same state", plain.posture == explicit.posture and plain.staggers == explicit.staggers and plain.glances == explicit.glances,
			"%s vs %s" % [plain.posture, explicit.posture])
	var open := Posture.new({"curve": 1.0, "ram_shatters": true})
	_stagger(open)
	t.check("a tier-2 ram still shatters with the numbers given", _hit("ram", PLATING, open, {"tier": 2})["shatter"], "tier 2 ram")


func _curve(t) -> void:
	var square := Posture.new({"curve": 2.0})
	t.near("curve 2 turns a half-matched ram into 30 x 0.25", _hit("ram", PLATING * 0.5, square)["gain"], 7.5)
	t.near("curve 2 leaves a matched ram at 30", _hit("ram", PLATING, square)["gain"], 30.0)
	t.near("curve 2 on the ordinary 1.5 cap is 30 x 2.25", _hit("ram", PLATING * 4.0, square)["gain"], 67.5)
	var square_monster := Posture.new({"curve": 2.0})
	square_monster.set_monster(true)
	t.near("curve 2 on the 3.0 cap is 30 x 9", _hit("ram", PLATING * 4.0, square_monster)["gain"], 270.0)
	t.near("curve 2 on a smash at 0.8 is 45 x 0.64", _hit("stomp", PLATING * 0.8, Posture.new({"curve": 2.0}), {"smash": true})["gain"], 28.8)
	var cube := Posture.new({"curve": 3.0})
	t.near("curve 3 turns a half-matched ram into 30 x 0.125", _hit("ram", PLATING * 0.5, cube)["gain"], 3.75)
	var cube_monster := Posture.new({"curve": 3.0})
	cube_monster.set_monster(true)
	t.near("curve 3 on the 3.0 cap is 30 x 27", _hit("ram", PLATING * 4.0, cube_monster)["gain"], 810.0)
	t.near("curve 3 on the ordinary 1.5 cap is 30 x 3.375", _hit("ram", PLATING * 4.0, Posture.new({"curve": 3.0}))["gain"], 101.25)
	t.near("curve 3 on a gun bolt at 0.5 is 1.5 x 0.125", _hit("runner", PLATING * 0.5, Posture.new({"curve": 3.0}))["gain"], 0.1875)
	var floor_rule := Posture.new({"curve": 3.0})
	var glance := _hit("ram", PLATING * Posture.MULT_MIN, floor_rule)
	t.near("curve 3 at the 0.2 floor still gains 30 x 0.008 a ram", glance["gain"], 0.24)
	t.check("the floor hit under a curve is still a glance and still gains", glance["glance"] and floor_rule.posture > 0.0, "gain %s" % glance["gain"])
	var steady := Posture.new({"curve": 2.0})
	var gains := 0
	for i in 5:
		if _hit("ram", PLATING * Posture.MULT_MIN, steady)["gain"] > 0.0:
			gains += 1
	t.check("a build at the floor gains posture on every ram under curve 2", gains == 5, "%d of 5 ram gained" % gains)


func _ram_shatters(t) -> void:
	var rule := Posture.new({"ram_shatters": false})
	_stagger(rule)
	var fast := _hit("ram", PLATING, rule, {"tier": 3})
	t.check("with ram_shatters false a tier-3 ram only cracks", fast["crack"] and not fast["shatter"] and fast["dealt"] == 0.0 and rule.cracked and rule.chunks == 4, "result %s" % fast)
	var smash := Posture.new({"ram_shatters": false})
	_stagger(smash)
	var hit := _hit("stomp", PLATING, smash, {"smash": true, "tier": 3})
	t.check("with ram_shatters false a smash still shatters", hit["shatter"] and smash.chunks == 3 and absf(float(hit["dealt"]) - HP / 4.0) < 0.001, "result %s" % hit)
	rule.step(Posture.STAGGER_SECONDS + 0.1)
	_stagger(rule)
	var second := _hit("ram", PLATING, rule, {"tier": 3})
	t.check("with ram_shatters false the crack still pays off in the next stagger", second["shatter"] and rule.chunks == 3, "result %s" % second)



# The stage 3 hive's heavy stagger (heavy_ratio): a stagger a ram opens at or above the ratio lets a
# smashing ram take two chunks; any other opener, a lighter ram, another smash, a crack payoff or the
# last chunk takes one.
func _heavy(t) -> void:
	var rule := Posture.new({"heavy_ratio": 0.7})
	_stagger(rule)
	t.check("a ram at 1x the plating opens a heavy stagger", rule.heavy_stagger, "heavy %s" % rule.heavy_stagger)
	var smash := _hit("ram", PLATING, rule, {"smash": true})
	t.check("a smashing ram in a heavy stagger takes two chunks", smash["shatter"] and rule.chunks == 2, "chunks %d result %s" % [rule.chunks, smash])
	t.near("the heavy shatter deals two chunks", smash["dealt"], HP / 2.0)
	var slammed := Posture.new({"heavy_ratio": 0.7})
	_stagger(slammed)
	_hit("slam", PLATING, slammed, {"smash": true})
	t.eq("a smashing slam in a heavy stagger takes one chunk", slammed.chunks, 3)
	var stomped := Posture.new({"heavy_ratio": 0.7})
	while not stomped.staggered:
		_hit("stomp", PLATING, stomped)
	_frame += 1
	_hit("ram", PLATING, stomped, {"smash": true})
	t.eq("a stagger a stomp opens is not heavy: one chunk", stomped.chunks, 3)
	var light := Posture.new({"heavy_ratio": 0.7})
	while not light.staggered:
		_hit("ram", PLATING * 0.5, light)
	_frame += 1
	_hit("ram", PLATING, light, {"smash": true})
	t.eq("a stagger a ram under the ratio opens is not heavy: one chunk", light.chunks, 3)
	var crack := Posture.new({"heavy_ratio": 0.7})
	_stagger(crack)
	_hit("ram", PLATING, crack, {"tier": 1})
	crack.step(Posture.STAGGER_SECONDS + 0.1)
	_stagger(crack)
	var paid := _hit("ram", PLATING, crack, {"tier": 1})
	t.check("a crack paying off in a heavy stagger takes one chunk", paid["shatter"] and crack.chunks == 3, "chunks %d result %s" % [crack.chunks, paid])
	var last := Posture.new({"heavy_ratio": 0.7})
	last.chunks = 1
	_stagger(last)
	_hit("ram", PLATING, last, {"smash": true})
	t.eq("a heavy smash on the last chunk takes only that one", last.chunks, 0)
	var after := Posture.new({"heavy_ratio": 0.7})
	_stagger(after)
	_hit("ram", PLATING, after, {"smash": true})
	while not after.staggered:
		_hit("stomp", PLATING, after)
	_frame += 1
	_hit("ram", PLATING, after, {"smash": true})
	t.check("a later stagger a stomp opens is not heavy after a heavy one", not after.heavy_stagger and after.chunks == 1,
		"heavy %s chunks %d" % [after.heavy_stagger, after.chunks])
	var plain := Posture.new()
	_stagger(plain)
	_hit("ram", PLATING, plain, {"smash": true})
	t.eq("without heavy_ratio a heavy ram's smash takes one chunk", plain.chunks, 3)


func _row_numbers(t) -> void:
	var fast := Posture.new({"stagger_seconds": 2.0, "drain_delay": 1.0, "drain_rate": 10.0, "smash_base": 60.0})
	_hit("ram", PLATING, fast)
	fast.step(2.0)
	t.near("a row's drain delay and rate apply: 1 s of drain at 10", fast.posture, 20.0)
	t.near("a row's smash base applies", _hit("stomp", PLATING, Posture.new({"smash_base": 60.0}), {"smash": true})["gain"], 60.0)
	var long_rule := Posture.new({"stagger_seconds": 2.0})
	_stagger(long_rule)
	long_rule.step(2.1)
	t.check("a row's stagger seconds apply", not long_rule.staggered, "still staggered")
	var empty := Posture.new({})
	t.check("an empty numbers dictionary keeps every constant", empty.curve == 1.0 and empty.ram_shatters and empty.stagger_seconds == Posture.STAGGER_SECONDS
			and empty.mult_min == Posture.MULT_MIN and empty.drain_rate == Posture.DRAIN_RATE, "curve %s" % empty.curve)


func _base_override(t) -> void:
	var partial := Posture.new({"base": {"ram": 20.0}})
	t.near("a base override for the ram changes the ram's gain", _hit("ram", PLATING, partial)["gain"], 20.0)
	t.near("a kind the override leaves out keeps its base", _hit("stomp", PLATING, partial)["gain"], 30.0)
	t.check("a kind the override leaves out is still a contact", partial.judge({"kind": "slam", "punch": PLATING, "plating": PLATING, "frame": 900})["contact"], "slam lost its contact")
	t.check("the constant table is not changed by an override", Posture.BASE["ram"] == 30.0, "BASE ram %s" % Posture.BASE["ram"])


# A made-up stage note stands in for a run: the sweep reads what the driver noted and nothing else.
func _sweep_record(t) -> void:
	var camper := {"warden_engaged_s": 14.0, "warden_fight_s": null, "warden_broken_s": 60.0}
	var run: Dictionary = Sweep.measure(camper, 240.0)
	t.check("a Warden that broke counts as broken even when the bot never engaged", run["broke"], "run %s" % run)
	t.near("a break with no strike counts from the wake", run["fight"], 46.0)
	var whole := {"warden_engaged_s": 1.0, "warden_fight_s": 0.5, "warden_broken_s": 40.0}
	var skipper: Dictionary = Sweep.measure(whole, 240.0)
	t.near("fight seconds start at the later of the turn and the engagement", skipper["fight"], 39.0)
	t.near("the engaged second is reported", skipper["engaged"], 1.0)
	var late := {"warden_engaged_s": 20.0, "warden_fight_s": 3.0, "warden_broken_s": 50.0}
	t.near("a roll from spawn to the Warden is not fight time", Sweep.measure(late, 240.0)["fight"], 30.0)
	t.check("a Warden that never broke counts as the cap", not Sweep.measure({"warden_engaged_s": 5.0}, 240.0)["broke"] and Sweep.measure({"warden_engaged_s": 5.0}, 240.0)["fight"] == 240.0, "never")
	t.near("the driver's fight limit starts from the same later second", float(BotDriver.fight_start_of(late)), 20.0)
	t.check("the driver's fight start is null before either is noted", BotDriver.fight_start_of({"warden_engaged_s": null, "warden_fight_s": null}) == null, "start")
