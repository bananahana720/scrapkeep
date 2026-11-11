extends RefCounted

# Marked hull (docs/systems-audit/feature-fit.md, new mechanic 1; Andrew 11 Nov 2026, 19:08Z):
# hull paid at a keeper's gamble lowers MAX hull by the same amount until the next Warden break,
# so regen fills only to the marked line and the stake costs a thinner bar through the next
# fight instead of 9 to 18 s of waiting. A heal at the foreman's kindness also lifts it.
#
# The mark is held in run.trade_memory ("hull_mark", in HP), because that Dictionary already
# rides the stage checkpoint, the entrance doc and Continue (as run_state.cursed() reads it), so
# a retry rewinds the mark together with the max hull it lowered. With nothing marked the key is
# absent and every doc is byte for byte as before.
#
# Max hull is the build sheet's (base + max_hp_bonus); ceiling() is the one place the mark comes
# off it, so a part or a heft change re-applies the sheet without wiping the mark.
# The launch flag `--marked-hull=on` (Tuning "marked_hull") lets a stake device mark; lifting
# needs no flag, because with the flag off nothing is ever marked.

const KEY := "hull_mark"
const FLOOR_SHARE := 0.1


static func held(run) -> float:
	if run == null:
		return 0.0
	return float(run.trade_memory.get(KEY, 0.0))


# Max hull with the mark taken off: what the build sheet sets. The mark never takes max hull
# below FLOOR_SHARE of the unmarked max (stake_devices.gd's floor): when the unmarked max falls
# (a heft class lost, a part sold) the mark is trimmed here, so max = unmarked - held always holds
# and lift() returns exactly what the mark took.
static func ceiling(run, unmarked: float) -> float:
	var room := maxf(0.0, unmarked - maxf(1.0, ceilf(unmarked * FLOOR_SHARE)))
	if held(run) > room:
		if room > 0.0:
			run.trade_memory[KEY] = room
		else:
			run.trade_memory.erase(KEY)
	return unmarked - held(run)


# Marks `amount` HP of max hull. The payment itself (the hull) is already taken by the caller.
static func stake(run, amount: float) -> void:
	if amount <= 0.0:
		return
	run.trade_memory[KEY] = held(run) + amount
	run.set_max_hp(run.max_hp - amount)


# Lifts the whole mark: max hull returns, and like any max-hull gain (set_max_hp) the hull
# rises with it. Returns the HP lifted, 0.0 when nothing was marked.
static func lift(run) -> float:
	var amount := held(run)
	if amount <= 0.0:
		return 0.0
	run.trade_memory.erase(KEY)
	run.set_max_hp(run.max_hp + amount)
	return amount


# A saved mark is a finite, non-negative number; trade_pockets.validate_doc asks.
static func doc_ok(doc: Dictionary) -> bool:
	if not doc.has(KEY):
		return true
	var value = doc[KEY]
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(value) and value >= 0.0
