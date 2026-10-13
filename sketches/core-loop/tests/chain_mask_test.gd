extends SceneTree

# SR11 chain mask (wave 13, 2026-10-13). A chain carries a 32-bit mask with one bit per proc
# type (RoR2 ProcChainMask, design-v3/research/comps/ror2/items-and-stacking.md). A link whose
# type bit is already set in its chain is refused, so a chain ends instead of repeating. Distinct
# sources still combine. Today's single chain (Domino Wire) keeps its one-link depth.
# - Five distinct sources in one hit each fire once; no same-type repeat fires.
# - A 32-type mask admits every type once.
# - The domino read site consults the mask: a second link inside the window is refused before its
#   roll (no serial draw), and the link fires again once the one-second window has expired.
# Expected: 17 checks before the final "every check ran" check.

const T := preload("res://tests/support/t.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Triggers := preload("res://src/build/triggers.gd")

const EXPECTED_CHECKS := 17
const CLOCK := 2.5
const WINDOW_EXPIRED := 3.5
const CHANCE := 0.5
const SOURCES := 5
const TYPES := 32
const FULL_MASK := 4294967295


class Victim extends Node3D:
	var weight := 1.0
	var knocks := 0

	func knock(_direction: Vector3, _force: float) -> void:
		knocks += 1

	func is_dead() -> bool:
		return false


class FakeBuild extends RefCounted:
	var near: Array = []

	func enemies_near(_at: Vector3, _radius: float, _limit: int) -> Array:
		return near


var _ran := false


# The checks run on the first frame, once the scene tree is live, so victims are inside the tree
# when their global positions are read.
func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_checks()
	return false


func _run_checks() -> void:
	var t := T.new("chain_mask_test")
	_primitives(t)
	_domino_chain(t)
	t.eq("every check ran", t.checks, EXPECTED_CHECKS)
	var code := t.verdict()
	print("chain_mask_test: %s" % ("PASS" if code == 0 else "FAIL"))
	quit(code)


# The mask arithmetic on its own: five sources in one hit, then 32 types.
func _primitives(t) -> void:
	t.eq("domino owns bit one", Triggers.chain_bit("domino"), 1)
	t.eq("a type that cannot chain has no bit", Triggers.chain_bit("pin_chain"), 0)
	t.check("an empty chain admits a type", Triggers.chain_allows(0, 1))
	t.check("a chain refuses a type it already holds", not Triggers.chain_allows(1, 1))
	t.check("a zero bit is never admitted", not Triggers.chain_allows(0, 0))

	var mask := 0
	var fires := 0
	for i in SOURCES:
		var bit := 1 << i
		if Triggers.chain_allows(mask, bit):
			mask = Triggers.chain_add(mask, bit)
			fires += 1
	var repeats := 0
	for i in SOURCES:
		if Triggers.chain_allows(mask, 1 << i):
			repeats += 1
	t.eq("five distinct sources in one hit each fire once", fires, SOURCES)
	t.eq("zero same-type repeats after the five fire", repeats, 0)
	t.eq("the hit mask holds exactly the five bits", mask, 31)

	var full := 0
	var admitted := 0
	for i in TYPES:
		if Triggers.chain_allows(full, 1 << i):
			full = Triggers.chain_add(full, 1 << i)
			admitted += 1
	t.eq("32 distinct types fit one chain mask", admitted, TYPES)
	t.eq("the full mask sets every bit", full, FULL_MASK)


# The domino read site: one link per chain, refused links draw no roll, and a window that has
# expired clears the chain.
func _domino_chain(t) -> void:
	var build := FakeBuild.new()
	var fx := ItemEffects.new(build)
	var part := _domino_part()
	t.eq("MAX_CHAIN_DEPTH is still one link", Triggers.MAX_CHAIN_DEPTH, 1)
	t.eq("one chain bit per chain type", Triggers.CHAIN_TYPES.size(), Triggers.MAX_CHAIN_DEPTH)

	fx._clock = CLOCK
	var a := _victim(Vector3(0.0, 0.0, 0.0))
	var b := _victim(Vector3(2.0, 0.0, 0.0))
	var c := _victim(Vector3(4.0, 0.0, 0.0))
	build.near = [a, b]
	fx._domino("domino_test", part, 1, a)
	t.eq("the first link flings its victim", a.knocks, 1)

	build.near = [b, c]
	fx._domino("domino_test", part, 1, b)
	t.eq("a second link inside the window is refused", b.knocks, 0)
	t.eq("the refused link draws no roll", fx._domino_serial, 1)

	fx._clock = WINDOW_EXPIRED
	fx._domino("domino_test", part, 1, b)
	t.eq("after the window the chain links again", b.knocks, 1)
	t.eq("the allowed link draws the next roll", fx._domino_serial, 2)


func _victim(at: Vector3) -> Victim:
	var v := Victim.new()
	root.add_child(v)
	v.position = at
	return v


func _domino_part() -> PartDef:
	var d := PartDef.new()
	d.effect = {"do": "domino", "chance": CHANCE, "speed": 10.0}
	return d
