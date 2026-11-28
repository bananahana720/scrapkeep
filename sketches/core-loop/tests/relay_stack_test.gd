extends SceneTree

const HoldRelay := preload("res://src/world/hold_relay.gd")
const Cards := preload("res://src/core/director_cards.gd")
const T := preload("res://tests/support/t.gd")

# SR10 relay risk stack (W13-INTEGRATION-3.md, SR10; comps/ror2/events-and-objectives.md).
# Before charging, the player may stack the relay k = 0 to 4 times. A stake of k multiplies
# the relay's pack and miniboss credit by 1 + k and pays 1 + k part rolls, staking no scrap
# or core.
#
# (a) 100 seeds x k = 0 to 4: pack credit and miniboss credit equal base x (1 + k), rewards 1 + k.
# (b) no price changes: every card's cost reads the same at any stake.
# (c) the stake clamps to 0 to 4 and stake_up wraps from 4 back to 0.
# (d) the stake locks once charging starts and frees after a loss.
# (e) the stake shows before commit: the line names the multiplier and the part rolls.
# (f) k = 0 keeps today's relay: credit equals base and one part roll.

const SEEDS := 100
const DT := 1.0 / 60.0
const EXPECTED_CHECKS := 11

var _t := T.new("relay_stack_test")


func _initialize() -> void:
	_seeded_credit()
	_no_price_changes()
	_clamp_and_wrap()
	_lock()
	_stake_line()
	_default()
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


func _relay() -> RefCounted:
	return HoldRelay.new({"relay": Vector2.ZERO, "ring": Vector2.ZERO}, 0.0)


func _random_pack(rng: RandomNumberGenerator) -> Array:
	var kinds: Array = Cards.CARDS.keys()
	var pack := []
	for i in rng.randi_range(1, 3):
		pack.append(kinds[rng.randi() % kinds.size()])
	return pack


func _seeded_credit() -> void:
	var bad := []
	for seed_value in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var pack := _random_pack(rng)
		var pack_base: float = Cards.cost(pack, rng.randf() < 0.2)
		if not is_finite(pack_base):
			pack_base = float(Cards.CARDS[pack[0]].cost)
		var miniboss_base := float(rng.randi_range(4, 40))
		for k in Cards.RELAY_STAKE_MAX + 1:
			var relay = _relay()
			relay.set_stakes(k)
			var want_pack := pack_base * (1 + k)
			var want_boss := miniboss_base * (1 + k)
			if not is_equal_approx(relay.pack_credit(pack_base), want_pack) \
					or not is_equal_approx(relay.miniboss_credit(miniboss_base), want_boss) \
					or relay.rewards() != 1 + k:
				bad.append("seed %d k %d: pack %s/%s boss %s/%s rewards %d" % [seed_value, k,
					relay.pack_credit(pack_base), want_pack, relay.miniboss_credit(miniboss_base), want_boss, relay.rewards()])
	_t.check("100 seeds x k 0-4: credit = base x (1 + k), rewards = 1 + k", bad.is_empty(), ", ".join(bad.slice(0, 3)))


func _no_price_changes() -> void:
	var before := {}
	for kind in Cards.CARDS:
		before[kind] = Cards.cost([kind])
	var relay = _relay()
	relay.set_stakes(Cards.RELAY_STAKE_MAX)
	relay.pack_credit(10.0)
	var changed := []
	for kind in Cards.CARDS:
		if Cards.cost([kind]) != before[kind]:
			changed.append(kind)
	_t.check("no card price changes at the top stake", changed.is_empty(), str(changed))


func _clamp_and_wrap() -> void:
	var relay = _relay()
	relay.set_stakes(9)
	_t.eq("stake clamps at 4", relay.stakes, Cards.RELAY_STAKE_MAX)
	relay.set_stakes(-2)
	_t.eq("stake clamps at 0", relay.stakes, 0)
	var seen := []
	for i in Cards.RELAY_STAKE_MAX + 1:
		relay.stake_up()
		seen.append(relay.stakes)
	_t.eq("stake_up walks 1, 2, 3, 4 and wraps to 0", seen, [1, 2, 3, 4, 0])


func _lock() -> void:
	var relay = _relay()
	relay.set_stakes(2)
	relay.begin()
	_t.check("stake locks once charging starts", not relay.set_stakes(4) and relay.stakes == 2)
	var outcome := ""
	var steps := 0
	while outcome == "" and steps < int(HoldRelay.WINDOW / DT) + 10:
		outcome = relay.step(DT, Vector3(100.0, 0.0, 100.0), Vector3.ZERO)
		steps += 1
	_t.check("stake frees after a loss", outcome == "lost" and relay.set_stakes(3) and relay.stakes == 3, outcome)


func _stake_line() -> void:
	var relay = _relay()
	relay.set_stakes(3)
	var line: String = relay.stake_line()
	_t.check("the stake shows before commit", "x3" in line and "x4" in line and "4 part rolls" in line, line)
	relay.begin()
	_t.check("the live status carries the stake", "Stake x3" in relay.status(), relay.status())


func _default() -> void:
	var relay = _relay()
	_t.check("k = 0 keeps today's relay", relay.stakes == 0 and relay.rewards() == 1 and relay.pack_credit(7.0) == 7.0
		and not "Stake" in relay.status(), relay.status())
