extends RefCounted

const Posture := preload("res://src/combat/boss_posture.gd")

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
	_hit("ram", PLATING * 4.0, strong)
	t.near("the multiplier caps at 1.5", strong.posture, 45.0)


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

	var slow := Posture.new()
	_stagger(slow)
	var crack := _hit("ram", PLATING, slow, {"tier": 1})
	t.check("a tier-1 ram cracks and deals 0", crack["crack"] and not crack["shatter"] and crack["dealt"] == 0.0 and slow.cracked and slow.chunks == 4, "result %s" % crack)
	slow.step(Posture.STAGGER_SECONDS + 0.1)
	t.check("a stagger that runs out keeps the crack and clears the bar", not slow.staggered and slow.cracked and slow.posture == 0.0 and slow.chunks == 4, "cracked %s" % slow.cracked)
	_stagger(slow)
	var broken := _hit("ram", PLATING, slow, {"tier": 1})
	t.check("the second stagger's tier-1 ram shatters", broken["shatter"] and slow.chunks == 3 and not slow.cracked, "result %s" % broken)

	var fast := Posture.new()
	_stagger(fast)
	t.check("a tier-2 ram shatters", _hit("ram", PLATING, fast, {"tier": 2})["shatter"], "tier 2 ram")

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
			rule.shattered_this_stagger, rule.gain_frame, rule.gain_in_frame, rule.staggers, rule.glances]
	var hit := {"kind": "stomp", "punch": PLATING, "plating": PLATING, "smash": true, "tier": 2, "charging": true, "frame": rule.gain_frame, "hp": HP, "max_hp": HP}
	var first: Dictionary = rule.judge(hit)
	var same := true
	for i in 20:
		same = same and rule.judge(hit) == first
	var after := [rule.posture, rule.staggered, rule.stagger_left, rule.stagger_frame, rule.idle, rule.chunks, rule.cracked,
			rule.shattered_this_stagger, rule.gain_frame, rule.gain_in_frame, rule.staggers, rule.glances]
	t.check("judge twenty times changes nothing and answers the same", same and after == snapshot, "before %s after %s" % [snapshot, after])
