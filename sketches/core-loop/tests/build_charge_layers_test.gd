extends SceneTree

const AbilityState := preload("res://src/core/ability_state.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")

# Items and upgrade-tree picks both raise a slot's charge cap and cooldown scale. The
# item layer re-applies after every part, so it must apply as a delta: a pick's extra
# charge and faster cooldown survive any number of later purchases, in either order.


class Stub:
	extends RefCounted
	var abilities


var _failures := 0


func _initialize() -> void:
	var abilities := AbilityState.new()
	var player := Stub.new()
	player.abilities = abilities
	var items := ItemEffects.new(null)
	var slot := AbilityState.SPECIAL

	# A tree pick first: +1 charge and 0.8x cooldown, the way upgrade_tree applies it.
	abilities.set_max_charges(slot, abilities.slot(slot).max_charges + 1)
	abilities.set_cooldown_scale(slot, abilities.slot(slot).cooldown_scale * 0.8)
	items.apply_abilities(player)
	_check("pick survives an empty item pass", abilities.slot(slot).max_charges == 2 and is_equal_approx(abilities.slot(slot).cooldown_scale, 0.8),
		"cap %d, scale %.2f" % [abilities.slot(slot).max_charges, abilities.slot(slot).cooldown_scale])

	# Then a charge cell and a cooldown part.
	items.charges[slot] = 1
	items.cooldown_scale[slot] = 0.5
	items.apply_abilities(player)
	_check("item adds on top of the pick", abilities.slot(slot).max_charges == 3 and is_equal_approx(abilities.slot(slot).cooldown_scale, 0.4),
		"cap %d, scale %.2f" % [abilities.slot(slot).max_charges, abilities.slot(slot).cooldown_scale])

	# Re-applying the same items changes nothing.
	items.apply_abilities(player)
	_check("re-apply is stable", abilities.slot(slot).max_charges == 3 and is_equal_approx(abilities.slot(slot).cooldown_scale, 0.4),
		"cap %d, scale %.2f" % [abilities.slot(slot).max_charges, abilities.slot(slot).cooldown_scale])

	# A second pick after the items, then the items again (a later purchase).
	abilities.set_max_charges(slot, abilities.slot(slot).max_charges + 1)
	items.apply_abilities(player)
	_check("second pick survives a later purchase", abilities.slot(slot).max_charges == 4,
		"cap %d" % abilities.slot(slot).max_charges)

	# Selling the cell back drops only the item's charge.
	items.charges[slot] = 0
	items.cooldown_scale[slot] = 1.0
	items.apply_abilities(player)
	_check("sell-back removes only the item layer", abilities.slot(slot).max_charges == 3 and is_equal_approx(abilities.slot(slot).cooldown_scale, 0.8),
		"cap %d, scale %.2f" % [abilities.slot(slot).max_charges, abilities.slot(slot).cooldown_scale])

	# The cap still holds: items can't push past MAX_CHARGES, and a later sale restores the pick's count.
	items.charges[slot] = 9
	items.apply_abilities(player)
	var capped: int = abilities.slot(slot).max_charges
	items.charges[slot] = 0
	items.apply_abilities(player)
	_check("cap holds and unwinds", capped == ItemEffects.MAX_CHARGES and abilities.slot(slot).max_charges == 3,
		"capped %d, after %d" % [capped, abilities.slot(slot).max_charges])

	if _failures == 0:
		print("build_charge_layers_test: PASS")
	quit(1 if _failures > 0 else 0)


func _check(name: String, ok: bool, detail: String) -> void:
	print("%s %s: %s" % ["ok  " if ok else "FAIL", name, detail])
	if not ok:
		_failures += 1
