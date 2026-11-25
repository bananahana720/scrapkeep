extends RefCounted

# Every class ability's charges, cooldown and gauge, in the four slots the ability bar
# shows (DESIGN-V2 sections 4 and 5). Movement and combat both spend from here, and
# slots() publishes the bar in W1's ability-slot shape, so the HUD, the rules and the
# tests read one record.

const Bindings := preload("res://src/core/bindings.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const Palette := preload("res://src/core/palette.gd")
const BuffLedger := preload("res://src/core/buff_ledger.gd")

const WEAPON := "weapon"
const MOVEMENT := "movement"
const SPECIAL := "special"
const SMASH := "smash"
# Slot 3, the line skill (design-v3/SKILL-BAR.md section 3). Appended so the first four keep
# their order.
const LINE := "line"
const SLOTS := [WEAPON, MOVEMENT, SPECIAL, SMASH, LINE]
# The numbered bar keys 1, 2 and 3 pick from, the chips beside it that are never selectable,
# and each bar slot's number (SKILL-BAR section 1).
const BAR := [WEAPON, SPECIAL, LINE]
const CHIPS := [MOVEMENT, SMASH]
const NUMBER := {WEAPON: 1, SPECIAL: 2, LINE: 3}
# Q's set piece. Its charge is the meter, not a cooldown, so it stays out of SLOTS (_recharge
# refills any slot whose cooldown is 0); an upgrade may still swap it.
const ULTIMATE := "ultimate"
const SWAPPABLE := SLOTS + [ULTIMATE]
# A pick with no cast snaps back to slot 1 after this long (SKILL-BAR section 9, start).
const SELECT_TIMEOUT := 3.0
# The key each slot shows: the bar slots their number, the movement chip Shift for every
# pilot (Sable's chip is her boost; her movement row is the harpoon, which has no slot) and the
# smash chip the haul.
static var KEYS := {WEAPON: "1", MOVEMENT: Bindings.label("boost"),
	SPECIAL: "2", SMASH: Bindings.label("haul"), LINE: "3"}

const READY := "ready"
const COOLING := "cooling"
const ACTIVE := "active"
const UNAVAILABLE := "unavailable"
# The refusal a jammed slot answers (FIELDS-AND-CASTS section 3); its state reads UNAVAILABLE.
const JAMMED := "jammed"

# No modifier may drive a cooldown below this (DESIGN-V2 section 6, risk 4).
const COOLDOWN_FLOOR := 0.4
# Combat cooldown refunds (W13-INTEGRATION-3 SQ6): a hit landed or a hit taken moves the
# mobility cooldown along, so fighting feeds movement. Start values from
# comps/roboquest/movement-and-feel.md:45 and :66 (a 1 s hit refund, a 2 s damage refund,
# inside its 1 to 2 s band); the caps are Scrapkeep's own. Every refund goes through refund().
const HIT_LANDED := "hit_landed"
const DAMAGE_TAKEN := "damage_taken"
const REFUNDS := {
	HIT_LANDED: {"seconds": 1.0},
	DAMAGE_TAKEN: {"seconds": 2.0},
}
# No grant falls outside this band: a grant the caps would cut under REFUND_MIN is dropped whole.
const REFUND_MIN := 1.0
const REFUND_MAX := 2.0
# At most this share of one charge's cooldown comes back from combat, so the effective
# cooldown never drops under half its base (start).
const REFUND_CYCLE_SHARE := 0.5
# Seconds of refund one stage hands out; a stage entry (refill) resets the tally (start).
const STAGE_REFUND_CAP := 20.0
# The slot a refund feeds: the first in this order whose ability has a cooldown. Sable's
# grapple has none and her Shift boost lives in the movement state, so hers feeds the line.
const REFUND_SLOTS := [MOVEMENT, LINE]
# The kind each refund record carries (event_kinds UI_ROWS row; the chip flash reads it).
const REFUND_KIND := "cooldown_refunded"
# Interrupt priority (W13-INTEGRATION-3 SR3; TADR-008 keeps it one integer per row, no tags or
# framework). A row's `priority` (default PRIORITY) is held by the ability state it starts; a
# request() lands on the next tick only when strictly stronger than the state running, the first
# strongest request winning, and a tick changes the state at most once. `cancels_sprint` (default
# false: Run and Gun and the full blast fire through a sprint) marks a row whose activation ends
# the sprint; the kit reads it through take_sprint_cancel(). A running state lasts its row's
# duration over attack_speed.
const PRIORITY := 1
const IDLE_PRIORITY := -1
const MIN_ATTACK_SPEED := 0.05
# A run ends on the tick its seconds reach this close to zero, so float drift costs no tick.
const RUN_EPSILON := 0.000001
# Fractional pressure comparison tolerance (PILOT-CADENCE.md section 3.5): ensures the fifth
# stamp at exactly 1.0 pressure succeeds cleanly despite float stepping.
const PRESSURE_EPS := 0.0001
# A skill shot draws exactly its committed geometry; the hit test forgives a hull this
# share beyond the drawn edge, so what you see is never bigger than what can hit.
const FORGIVENESS := 0.18
# Cast times and the jam (design-v3/FIELDS-AND-CASTS.md sections 3 and 4). A row's `cast` is the
# seconds between the press and the effect; the ball keeps rolling at full speed the whole time,
# unless the row has `plant`: Andrew's "Depends on the pilot" (Q2, 2026-10-17 22:12:39Z) has the
# heavy pilots, Tarn and the Cannon, plant for their heavy casts (their Q variants), braking to a
# stop through the wind-up by their own choice; Sable, Kest, Rivet and Tally cast on the move.
# An interrupting hit (the crowd-control door) drops a running cast with nothing spent, as it
# drops a gauge. A jam (an enemy field's pulse) shuts the SILENCED slots for its seconds: the
# weapon, the movement chip, the smash and Q stay open, so a jam never takes the ball's speed.
const SILENCED := [SPECIAL, LINE]
# Andrew's "Big ones only" (2026-10-17 19:56:59Z): Q's 0.35 s wind-up stays and a jolt recalls it;
# the depth-3 Q variants cast longer, at this start value until the power read ranks them (the
# strongest may go to 0.8 s); Gather Plate casts in 0.3 s; everything else stays instant.
const VARIANT_CAST := 0.5
const UNSTARTED := ""

# One row per ability id; the class row names which id fills each slot, and an upgrade
# swaps a slot to a variant row. The rest of the game dispatches on a row's
# capabilities, never on its id, so a variant is one row here plus, when it plays
# differently, one entry in the owning dispatch table (combat's _specials, the ball's
# SMASHES). icon is the canonical id in assets/icons (VISUAL-LANGUAGE section 5).
# cooldown is per charge. charge_max > 0 makes the slot a hold-gauge-release shot.
# duration is how long an active ability runs on one charge.
#   weapon    pattern (the Pattern it fires, default its id), mounted (the weapon it
#             becomes on a pylon), lob (how many sticky charges one throw scatters),
#             cards (the bay programs in bay order; the weapon runs the selected one on a
#             press), pressure (the slot's charges are shared pressure that time never refills),
#             bolts (false for a weapon that fires no bolts, so it carries no shot bits; default true)
#   movement  augments (the movement kit it fits), rocket, cloak (Kest's passives)
#   special   plant_discharge (planting a pylon fires it free)
#   smash     flavour (arc, skid or demo landing), spends_special
#   line      line (marks a line-skill row), load_seconds (how long a cast with no line
#             waits for the next bite)
#   ultimate  paths (preference order over line, arc, rail), beats (0 lets the path length
#             set the flight beats, a positive number fixes them), hold_beats (a hold leg
#             before the last leg), variant_of (a depth-3 row names its base ultimate)
#   any slot  cast (seconds from the press to the effect, 0 or absent for none), plant (the
#             pilot plants, braking to a stop, through that cast), family (lane, split_lane, plate or rush: the Mind family this slot commits),
#             pool (the slot whose charges this row spends: Tally's slots 2 and 3 spend
#             slot 1's pressure), mutation (authored kit-swap behaviour id read by the slot's
#             owning module). A special or line row with no charge_max is a tap: it
#             casts on the press.
# Each pilot owns one marked block below for its wave P-C rows (SKILL-BAR section 12, item
# 4), so the six pilot units never edit the same lines.
const ABILITIES := {
	"arc_caster": {"icon": "ab_sable_weapon", "cooldown": 0.0, "mounted": "pylon_turret"},
	"grapple": {"icon": "ab_sable_move", "cooldown": 0.0, "augments": ["grapple", "pylon", "vault"]},
	"detonation_gauge": {"icon": "ab_sable_special", "cooldown": 5.0, "charge_max": 1.0, "plant_discharge": true},
	"arc_slam": {"icon": "ab_sable_smash", "cooldown": 0.0, "flavour": "arc"},
	"crater_slam": {"icon": "ab_sable_smash", "cooldown": 0.0, "flavour": "arc", "spends_special": true},
	"rapid_laser": {"icon": "ab_rivet_weapon", "cooldown": 0.0},
	"overdrive_sprint": {"icon": "ab_rivet_move", "cooldown": 5.0, "duration": 2.0, "augments": ["sprint"]},
	"overdrive_blast": {"icon": "ab_rivet_special", "cooldown": 6.0, "charge_max": 1.0},
	"point_blank": {"icon": "ab_rivet_special", "cooldown": 6.0, "charge_max": 1.0},
	"shockwave_skid": {"icon": "ab_rivet_smash", "cooldown": 0.0, "flavour": "skid"},
	"sticky_charge": {"icon": "ab_kest_weapon", "cooldown": 0.6, "charge_max": 0.6, "lob": 1, "bolts": false},
	"sticky_rain": {"icon": "ab_kest_weapon", "cooldown": 0.6, "charge_max": 0.6, "lob": 3, "pattern": "sticky_charge", "bolts": false},
	"smoke_blink": {"icon": "ab_kest_move", "cooldown": 4.0, "augments": ["blink", "glide"], "rocket": true, "cloak": true},
	"detonation_line": {"icon": "ab_kest_special", "cooldown": 6.0, "charge_max": 0.8},
	"demo_slam": {"icon": "ab_kest_smash", "cooldown": 0.0, "flavour": "demo"},
	"claw_sweep": {"icon": "ab_tarn_weapon", "cooldown": 0.0},
	"claw_rake": {"icon": "ab_tarn_weapon", "cooldown": 0.0, "pattern": "claw_sweep", "mutation": "claw_rake"},
	"claw_pull": {"icon": "ab_tarn_move", "cooldown": 3.0, "augments": ["claw_pull"]},
	"clamp": {"icon": "ab_tarn_special", "cooldown": 6.0, "charge_max": 0.8},
	"rend_slam": {"icon": "ab_tarn_smash", "cooldown": 0.0, "flavour": "rend"},
	"rend_drag": {"icon": "ab_tarn_smash", "cooldown": 0.0, "flavour": "rend", "mutation": "rend_drag"},
	# Tally's slot 1, chip rows and smash; her bar and Q rows sit in her P-C block below.
	"flywheel_surge": {"icon": "ab_tally_move", "cooldown": 4.0, "augments": ["surge"]},
	"stamp_slam": {"icon": "ab_tally_smash", "cooldown": 0.0, "flavour": "stamp"},
	"stamp_ink": {"icon": "ab_tally_smash", "cooldown": 0.0, "flavour": "stamp", "mutation": "stamp_ink"},
	"cannon_lane": {"icon": "ab_cannon_weapon", "cooldown": 0.0, "family": "lane", "bolts": false},
	"cannon_lane_walk": {"icon": "ab_cannon_weapon", "cooldown": 0.0, "family": "lane", "pattern": "cannon_lane", "mutation": "cannon_lane_walk", "bolts": false},
	"cannon_recoil": {"icon": "ab_cannon_move", "cooldown": 3.5, "augments": ["recoil"], "family": "split_lane"},
	"cannon_plate": {"icon": "ab_cannon_special", "cooldown": 6.0, "charge_max": 0.8, "family": "plate"},
	"cannon_rush": {"icon": "ab_cannon_smash", "cooldown": 0.0, "flavour": "rush", "family": "rush"},
	"cannon_rush_wake": {"icon": "ab_cannon_smash", "cooldown": 0.0, "flavour": "rush", "family": "rush", "mutation": "cannon_rush_wake"},
	# The shared placeholders until wave P-C: one line skill (a 4 m yank on a body, a reel
	# burst on the world) and one ultimate (B3 builds its set piece).
	"line_reel": {"icon": "ab_sable_reel", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
	"ult_default": {"icon": "ab_sable_reel", "cooldown": 0.0, "paths": ["line", "arc"], "beats": 0},
	# --- P-C Sable rows (line skill, ultimate, depth-3 variants) -------------------------
	"bank_shot": {"icon": "ab_sable_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
	"cable_run": {"icon": "ab_sable_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"]},
	"ball_lightning": {"icon": "ab_sable_ult", "cooldown": 0.0, "paths": ["arc"], "variant_of": "cable_run", "cast": VARIANT_CAST},
	"outpost": {"icon": "ab_sable_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "cable_run", "cast": VARIANT_CAST},
	# --- end Sable ---
	# --- P-C Rivet rows ------------------------------------------------------------------
	"line_drive": {"icon": "ab_rivet_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
	"foundry_cutter": {"icon": "ab_rivet_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"]},
	"prism_cutter": {"icon": "ab_rivet_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "foundry_cutter", "cast": VARIANT_CAST},
	"juggernaut_drive": {"icon": "ab_rivet_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "foundry_cutter", "cast": VARIANT_CAST},
	# --- end Rivet ---
	# --- P-C Kest rows -------------------------------------------------------------------
	# 2026-10-11 (PC-KEST round 3): fourteen seconds preserves both fixed bands after the contact cap.
	"cable_charge": {"icon": "ab_kest_line", "cooldown": 14.0, "line": true, "load_seconds": 4.0},
	"windhover": {"icon": "ab_kest_ult", "cooldown": 0.0, "paths": ["arc", "line", "rail"], "hold_beats": 2},
	"air_raid": {"icon": "ab_kest_ult", "cooldown": 0.0, "paths": ["arc", "line", "rail"], "variant_of": "windhover", "cast": VARIANT_CAST},
	"minelayer": {"icon": "ab_kest_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "windhover", "cast": VARIANT_CAST},
	# --- end Kest ---
	# --- P-C Tarn rows -------------------------------------------------------------------
	"claw_drag": {"icon": "ab_tarn_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
	"redjaw_rend": {"icon": "ab_tarn_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"]},
	"rake_run": {"icon": "ab_tarn_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "redjaw_rend", "cast": VARIANT_CAST, "plant": true},
	"vice_leap": {"icon": "ab_tarn_ult", "cooldown": 0.0, "paths": ["arc", "line", "rail"], "variant_of": "redjaw_rend", "cast": VARIANT_CAST, "plant": true},
	# --- end Tarn ---
	# --- P-C Tally rows ------------------------------------------------------------------
	# pilots/tally.md section 3: Balance Due alone spends pressure; Gather Plate and the Ledger
	# Clip keep their own cooldowns and pay into it; Q's meter is Plate Return's charge.
	"ledger_reader": {"icon": "ab_tally_weapon", "cooldown": 0.0, "cards": ["balance_due"], "pressure": 3, "bolts": false},
	"gather_plate": {"icon": "ab_tally_gather", "cooldown": 6.0, "cast": 0.3},
	"link_clips": {"icon": "ab_tally_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
	"link_double": {"icon": "ab_tally_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0, "mutation": "link_double"},
	"plate_return": {"icon": "ab_tally_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"]},
	"plate_audit": {"icon": "ab_tally_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "plate_return", "cast": VARIANT_CAST},
	"plate_flywheel": {"icon": "ab_tally_ult", "cooldown": 0.0, "paths": ["arc", "rail", "line"], "variant_of": "plate_return", "cast": VARIANT_CAST},
	# --- end Tally ---
	# --- P-C Cannon rows -----------------------------------------------------------------
	"cannon_lane_charge": {"icon": "ab_cannon_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0, "family": "lane"},
	"cannon_fire_mission": {"icon": "ab_cannon_ult", "paths": ["arc", "line", "rail"], "beats": 0},
	"cannon_creeping_barrage": {"icon": "ab_cannon_ult", "paths": ["line", "rail", "arc"], "beats": 0, "variant_of": "cannon_fire_mission", "cast": VARIANT_CAST, "plant": true},
	"cannon_plate_mortar": {"icon": "ab_cannon_ult", "paths": ["arc"], "beats": 6, "variant_of": "cannon_fire_mission", "cast": VARIANT_CAST, "plant": true},
	# --- end Cannon ---
}
const ICON_DIR := "res://assets/icons/"


# The one hold-gauge-release rule. Hold fills the gauge linearly over charge_max; the
# key coming up fires at the fraction reached, and a gauge held full fires by itself
# GRACE seconds later. Cancelling leaves nothing spent and nothing fired.
class Gauge:
	extends RefCounted

	const GRACE := 0.5

	var charge_max := 1.0
	var charging := false
	var held := 0.0
	# The fraction the last shot left at, and whether the grace fired it.
	var fired_fraction := 0.0
	var auto := false

	func _init(seconds := 1.0) -> void:
		charge_max = maxf(0.05, seconds)

	func begin() -> void:
		charging = true
		held = 0.0
		auto = false

	func fraction() -> float:
		return clampf(held / charge_max, 0.0, 1.0) if charging else 0.0

	# One tick of the key. True on the tick the shot goes. Only ticks with the key down
	# fill the gauge, so a tap fires at exactly the floor.
	func step(delta: float, key_held: bool) -> bool:
		if not charging:
			return false
		if key_held:
			held += delta
			if held < charge_max + GRACE:
				return false
		fired_fraction = clampf(held / charge_max, 0.0, 1.0)
		auto = key_held
		charging = false
		held = 0.0
		return true

	# True when there was a charge to drop.
	func cancel() -> bool:
		var was := charging
		charging = false
		held = 0.0
		return was

	# A shot's size from a floor, so a tap still does something.
	static func scaled(f: float, floor_value: float, full_value: float) -> float:
		return lerpf(floor_value, full_value, clampf(f, 0.0, 1.0))


class Slot:
	extends RefCounted

	var id := ""
	var icon := ""
	var cooldown := 0.0
	var cooldown_scale := 1.0
	# duration is the row's base_duration over the state's attack speed (SR3).
	var base_duration := 0.0
	var duration := 0.0
	var priority := PRIORITY
	var cancels_sprint := false
	var max_charges := 1
	var _charges := 1
	# Fractional pressure storage for pressure slots (0.0 .. float(max_charges)).
	# Non-pressure slots keep integer charges; assigning `charges` syncs `pressure_val`
	# so existing callers and tests stay exact.
	var is_pressure := false
	var pressure_val := 1.0
	var charges: int:
		get:
			if is_pressure:
				return clampi(int(floor(pressure_val + PRESSURE_EPS)), 0, max_charges)
			return _charges
		set(value):
			_charges = value
			if is_pressure:
				pressure_val = clampf(float(value), 0.0, float(max_charges))
	# Seconds into the charge now recharging.
	var recharge := 0.0
	var active := false
	var available := true
	var gauge: Gauge = null
	# What the item layer (item_effects.apply_abilities) last added on top: extra charges
	# and its cooldown multiplier. Upgrade-tree picks add to the same cap and scale, so
	# items re-apply as a delta and never overwrite a pick.
	var item_charges := 0
	var item_scale := 1.0
	# What a pressure row lifted the cap by, so a swap away hands back only the slot's own cap.
	var pressure_bonus := 0
	# Combat refund seconds landed on the charge now recharging (REFUND_CYCLE_SHARE).
	var cycle_refunded := 0.0
	# Seconds from the press to the effect (the row's `cast`); 0 casts on the press.
	var cast := 0.0

	func clamp_to_max() -> void:
		if is_pressure:
			pressure_val = minf(pressure_val, float(max_charges))
		_charges = mini(_charges, max_charges)


# The key the movement chip shows: Shift for every pilot (player_ball sets it).
var movement_key: String = KEYS[MOVEMENT]
var _slots := {}
# The bar slot left click casts (SKILL-BAR section 1). Exactly one is selected at every tick;
# the weapon is home. Only the player's router changes it, through select() and snap_back().
var selected := WEAPON
# Seconds since the pick with no cast begun; the router snaps back at SELECT_TIMEOUT.
var _select_held := 0.0
# The ultimate in Q's place, and its meter. B3's UltimateMeter (src/core/ultimate_meter.gd)
# fills `meter`; until then it is null and the ultimate reads as charging at 0.
var ultimate_id := ""
var meter = null
# Combat refund seconds handed out this stage (STAGE_REFUND_CAP), and the refund records not
# yet read: {kind, slot, id, source, seconds}, oldest first.
var stage_refunded := 0.0
var _refunds := []
# The interrupt record (SR3): the attack speed durations divide by, the slot whose ability state
# runs ("" when idle) and its seconds left, state changes so far, sprint cancels so far, the
# requests waiting for the next tick and the sprint cancel the kit has not read.
var attack_speed := 1.0
var running := ""
var running_left := 0.0
var state_changes := 0
var sprint_cancels := 0
var _requests := []
var _sprint_cancel := false
# The cast running ("" when none), its seconds left, and the slot whose cast just finished
# (read once through take_cast_done). Seconds of jam left, and jams taken, for tests and HUD.
var casting := UNSTARTED
var cast_left := 0.0
var _cast_done := UNSTARTED
var _swap_dropped := ""
var jam_left := 0.0
var jams := 0
var _buffs = null
var _running_buff_id := ""


func _init() -> void:
	for name in SLOTS:
		_slots[name] = Slot.new()


func bind_buffs(ledger) -> void:
	if _buffs == ledger:
		return
	_clear_running_buff()
	_buffs = ledger


# Fills the five slots and the ultimate from a class row. Charges start full; a stage entry
# refills them. The selection goes home.
func fit(def) -> void:
	var ids := {WEAPON: "", MOVEMENT: "", SPECIAL: "", SMASH: "", LINE: ""}
	ultimate_id = ""
	if def != null:
		ids = {WEAPON: def.weapon_id, MOVEMENT: def.movement_id, SPECIAL: def.special_id, SMASH: def.smash_id,
			LINE: def.line_id}
		ultimate_id = def.ultimate_id
	for name in SLOTS:
		_slots[name] = Slot.new()
		swap(name, ids[name])
	selected = WEAPON
	_select_held = 0.0


# Puts ability `id` in a slot, full, with its row's cooldown, duration and gauge. The
# slot's stockpile cap and cooldown scale stay: items and picks raise the slot, not the
# ability in it, so an upgrade swap never drops a charge upgrade bought earlier. A cast the
# swap drops is held for take_swap_dropped, so combat clears its tell.
func swap(name: String, id: String) -> void:
	var row: Dictionary = ABILITIES.get(id, {})
	var old: Slot = _slots[name]
	# A cast belongs to the ability that began it: a new ability in the slot drops it rather
	# than finishing on the new row's cast time.
	if casting == name and old.id != id:
		_swap_dropped = cancel_cast()
	var s := Slot.new()
	s.max_charges = maxi(1, old.max_charges - old.pressure_bonus)
	s.charges = s.max_charges
	s.cooldown_scale = old.cooldown_scale
	s.item_charges = old.item_charges
	s.item_scale = old.item_scale
	s.id = id
	s.icon = row.get("icon", "")
	s.cooldown = row.get("cooldown", 0.0)
	s.base_duration = row.get("duration", 0.0)
	s.duration = s.base_duration / attack_speed
	s.priority = priority_of(id)
	s.cancels_sprint = cancels_sprint_of(id)
	s.cast = maxf(0.0, float(row.get("cast", 0.0)))
	var charge_max: float = row.get("charge_max", 0.0)
	if charge_max > 0.0:
		s.gauge = Gauge.new(charge_max)
	if row.has("pressure"):
		var own: int = s.max_charges
		s.max_charges = maxi(old.max_charges, int(row["pressure"]))
		s.pressure_bonus = s.max_charges - own
		s.is_pressure = true
		s.charges = s.max_charges
	_slots[name] = s


# The id of a cast the last swap dropped, once; "" when none.
func take_swap_dropped() -> String:
	var id := _swap_dropped
	_swap_dropped = ""
	return id


# A capability of the ability in a slot (see ABILITIES), or `fallback`.
func cap(name: String, key: String, fallback = null):
	return ABILITIES.get((_slots[name] as Slot).id, {}).get(key, fallback)


func slot(name: String) -> Slot:
	return _slots[name]


func id_of(name: String) -> String:
	return (_slots[name] as Slot).id


func gauge(name: String) -> Gauge:
	return (_slots[name] as Slot).gauge


static func floored(base: float, scale: float) -> float:
	if base <= 0.0:
		return 0.0
	return maxf(COOLDOWN_FLOOR, base * scale)


func cooldown_of(name: String) -> float:
	var s: Slot = _slots[name]
	return floored(s.cooldown, s.cooldown_scale)


# The slot whose charges `name` spends: its row's pool, else itself.
func pool_of(name: String) -> String:
	var pool := String(cap(name, "pool", ""))
	return pool if pool != "" and pool != name and _slots.has(pool) else name


func pressure_of(name: String) -> float:
	var payer: Slot = _slots[pool_of(name)]
	return payer.pressure_val if payer.is_pressure else float(payer.charges)


func ready(name: String, cost := 1.0) -> bool:
	var s: Slot = _slots[name]
	var payer: Slot = _slots[pool_of(name)]
	if payer.is_pressure:
		return s.available and payer.pressure_val + PRESSURE_EPS >= cost and not silenced(name)
	return s.available and payer.charges > 0 and not silenced(name)


func spend(name: String, cost := 1.0) -> bool:
	if not ready(name, cost):
		return false
	var payer: Slot = _slots[pool_of(name)]
	if payer.is_pressure:
		payer.pressure_val = maxf(0.0, payer.pressure_val - maxf(cost, 0.0))
		if payer.pressure_val <= PRESSURE_EPS:
			payer.pressure_val = 0.0
		return true
	payer.charges -= 1
	return true


# The stomp and rebound refresh: one charge back, never past the cap.
func grant(name: String, count := 1) -> void:
	if count <= 0:
		return
	var s: Slot = _slots[name]
	if s.is_pressure:
		grant_amount(name, float(count))
		return
	s.charges = mini(s.max_charges, s.charges + count)
	if s.charges == s.max_charges:
		s.recharge = 0.0
		s.cycle_refunded = 0.0


# Fractional grant for pressure slots (continuous cruise refill and PAID stamp refunds).
func grant_amount(name: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var s: Slot = _slots[name]
	if not s.is_pressure:
		grant(name, int(floor(amount)))
		return
	s.pressure_val = minf(float(s.max_charges), s.pressure_val + amount)
	if s.pressure_val + PRESSURE_EPS >= float(s.max_charges):
		s.pressure_val = float(s.max_charges)
		s.recharge = 0.0
		s.cycle_refunded = 0.0


# Moves the recharging charge along by this many seconds (the skid's refund).
func refund(name: String, seconds: float) -> void:
	_recharge(_slots[name], seconds)


# The slot combat refunds feed: the first REFUND_SLOTS slot whose ability has a cooldown, or "".
func refund_slot() -> String:
	for name in REFUND_SLOTS:
		if cooldown_of(name) > 0.0 and not ABILITIES.get(id_of(name), {}).has("pressure"):
			return name
	return ""


# A hit landed or taken (a REFUNDS source) moves the refund slot's recharging charge along,
# through refund(). Returns the seconds granted: REFUND_MIN to REFUND_MAX, or 0 when the slot is
# full, the source is unknown, or the cycle share or the stage cap has too little left. A grant
# queues one cooldown_refunded record for drain_refunds().
func combat_refund(source: String) -> float:
	var row: Dictionary = REFUNDS.get(source, {})
	var name := refund_slot()
	if row.is_empty() or name == "":
		return 0.0
	var s: Slot = _slots[name]
	if s.charges >= s.max_charges:
		return 0.0
	var cd := cooldown_of(name)
	var grant: float = minf(float(row["seconds"]), REFUND_MAX)
	grant = minf(grant, cd * REFUND_CYCLE_SHARE - s.cycle_refunded)
	grant = minf(grant, STAGE_REFUND_CAP - stage_refunded)
	if grant < REFUND_MIN:
		return 0.0
	var before := s.charges
	s.cycle_refunded += grant
	stage_refunded += grant
	refund(name, grant)
	# A grant that finishes a charge carries its overflow into the next one; that overflow
	# counts against the next charge's share.
	if s.charges > before:
		s.cycle_refunded = minf(s.recharge, grant) if s.charges < s.max_charges else 0.0
	_refunds.append({"kind": REFUND_KIND, "slot": name, "id": s.id, "source": source, "seconds": grant})
	return grant


# The refund records since the last call, oldest first; the queue empties.
func drain_refunds() -> Array:
	var out := _refunds
	_refunds = []
	return out


func refill() -> void:
	stage_refunded = 0.0
	casting = UNSTARTED
	cast_left = 0.0
	_cast_done = UNSTARTED
	_swap_dropped = ""
	jam_left = 0.0
	running = ""
	running_left = 0.0
	_clear_running_buff()
	_requests = []
	_sprint_cancel = false
	for name in SLOTS:
		var s: Slot = _slots[name]
		s.charges = s.max_charges
		s.recharge = 0.0
		s.cycle_refunded = 0.0
		s.active = false
		if s.gauge != null:
			s.gauge.cancel()


# Items raise charges; charges above the new cap are dropped, never kept.
func set_max_charges(name: String, count: int) -> void:
	var s: Slot = _slots[name]
	s.max_charges = maxi(1, count)
	s.clamp_to_max()


func set_cooldown_scale(name: String, scale: float) -> void:
	(_slots[name] as Slot).cooldown_scale = maxf(0.0, scale)


func tick(delta: float) -> void:
	if _buffs != null:
		_buffs.step(delta)
	_resolve(delta)
	_tick_cast(delta)
	jam_left = maxf(0.0, jam_left - delta)
	for name in SLOTS:
		_recharge(_slots[name], delta)


# --- Interrupt priority (SR3) ----------------------------------------------------------

static func priority_of(id: String) -> int:
	return int(ABILITIES.get(id, {}).get("priority", PRIORITY))


static func cancels_sprint_of(id: String) -> bool:
	return bool(ABILITIES.get(id, {}).get("cancels_sprint", false))


# The one interrupt rule, shared with the Fleet counters: the index of the first strongest of
# `priorities` when it is strictly stronger than `current`, else -1.
static func strongest(current: int, priorities: Array) -> int:
	var win := -1
	for i in priorities.size():
		if int(priorities[i]) > current and (win < 0 or int(priorities[i]) > int(priorities[win])):
			win = i
	return win


# Every running state lasts its base duration over this; picks and items set it.
func set_attack_speed(speed: float) -> void:
	attack_speed = maxf(MIN_ATTACK_SPEED, speed)
	for name in SLOTS:
		var s: Slot = _slots[name]
		s.duration = s.base_duration / attack_speed


func duration_of(name: String) -> float:
	return (_slots[name] as Slot).base_duration / attack_speed


func running_priority() -> int:
	return IDLE_PRIORITY if running == "" else (_slots[running] as Slot).priority


# Asks to start the ability in `name`; the next tick decides.
func request(name: String) -> void:
	if _slots.has(name):
		_requests.append(name)


# True once after an activation whose row cancels the sprint.
func take_sprint_cancel() -> bool:
	var was := _sprint_cancel
	_sprint_cancel = false
	return was


# At most one state change: the strongest ready request replaces a weaker running state (spending
# its charge), or else the running state counts down and ends.
func _resolve(delta: float) -> void:
	if _requests.is_empty() and running == "":
		return
	var names := []
	var priorities := []
	for name in _requests:
		if ready(name):
			names.append(name)
			priorities.append((_slots[name] as Slot).priority)
	_requests = []
	var win := strongest(running_priority(), priorities)
	if win >= 0:
		var name: String = names[win]
		spend(name)
		running = name
		running_left = duration_of(name)
		state_changes += 1
		if (_slots[name] as Slot).cancels_sprint:
			_sprint_cancel = true
			sprint_cancels += 1
		_post_running_buff()
		return
	if running != "":
		running_left -= delta
		if running_left <= RUN_EPSILON:
			running = ""
			running_left = 0.0
			state_changes += 1
			_clear_running_buff()


func _post_running_buff() -> void:
	if _buffs == null:
		return
	var s: Slot = _slots.get(running)
	if s == null or running_left <= RUN_EPSILON:
		_clear_running_buff()
		return
	var buff_id := "ability_" + s.id
	if _running_buff_id != "" and _running_buff_id != buff_id:
		_buffs.clear_id(_running_buff_id)
	_running_buff_id = buff_id
	_buffs.post(buff_id, {
		"icon": s.icon,
		"tone": Palette.AMBER,
		"duration_s": running_left,
		"kind": BuffLedger.KIND_TIMER,
		"stacks": 1,
		"max_stacks": 1,
	})


func _clear_running_buff() -> void:
	if _buffs != null and _running_buff_id != "":
		_buffs.clear_id(_running_buff_id)
	_running_buff_id = ""


# One charge at a time: time only ever fills the charge now recharging.
func _recharge(s: Slot, seconds: float) -> void:
	# Pressure is refilled by rolling and contact, never by time.
	if ABILITIES.get(s.id, {}).has("pressure"):
		s.recharge = 0.0
		return
	if s.charges >= s.max_charges:
		s.recharge = 0.0
		return
	var cd := floored(s.cooldown, s.cooldown_scale)
	if cd <= 0.0:
		s.charges = s.max_charges
		s.recharge = 0.0
		return
	s.recharge += seconds
	while s.recharge >= cd and s.charges < s.max_charges:
		s.recharge -= cd
		s.charges += 1
		s.cycle_refunded = 0.0
	if s.charges >= s.max_charges:
		s.recharge = 0.0


func charging() -> bool:
	if casting != UNSTARTED:
		return true
	for name in SLOTS:
		var g: Gauge = (_slots[name] as Slot).gauge
		if g != null and g.charging:
			return true
	return false


# Drops every charging gauge and the running cast; returns the ability ids that were charging.
func cancel_gauges() -> Array:
	var dropped := []
	for name in SLOTS:
		var s: Slot = _slots[name]
		if s.gauge != null and s.gauge.cancel():
			dropped.append(s.id)
	var cast := cancel_cast()
	if cast != UNSTARTED:
		dropped.append(cast)
	return dropped


# --- Cast times and the jam (FIELDS-AND-CASTS sections 3 and 4) ------------------------

func cast_of(name: String) -> float:
	return (_slots[name] as Slot).cast


# Starts the cast for a slot whose ability has a cast time. Nothing is spent until it finishes.
# False when another cast runs, the slot has no cast time or it is not ready.
func begin_cast(name: String) -> bool:
	if casting != UNSTARTED or cast_of(name) <= 0.0 or not ready(name):
		return false
	casting = name
	cast_left = cast_of(name)
	return true


# The share of the running cast done, 0 to 1; 0 with none.
func cast_fraction() -> float:
	if casting == UNSTARTED:
		return 0.0
	return clampf(1.0 - cast_left / maxf(0.001, cast_of(casting)), 0.0, 1.0)


# Drops the running cast with nothing spent; returns its ability id, or "" with none.
func cancel_cast() -> String:
	if casting == UNSTARTED:
		return UNSTARTED
	var id := id_of(casting)
	casting = UNSTARTED
	cast_left = 0.0
	return id


# The slot whose cast finished since the last call, once; "" otherwise. Its owner fires it.
func take_cast_done() -> String:
	var done := _cast_done
	_cast_done = UNSTARTED
	return done


func _tick_cast(delta: float) -> void:
	if casting == UNSTARTED:
		return
	cast_left -= delta
	if cast_left <= RUN_EPSILON:
		_cast_done = casting
		casting = UNSTARTED
		cast_left = 0.0


# A field's pulse: the SILENCED slots shut for `seconds`. A jam refreshes, never stacks.
func jam(seconds: float) -> void:
	jam_left = maxf(jam_left, seconds)
	jams += 1


func jammed() -> bool:
	return jam_left > 0.0


func silenced(name: String) -> bool:
	return jam_left > 0.0 and name in SILENCED


func state_of(name: String) -> String:
	var s: Slot = _slots[name]
	if not s.available or silenced(name):
		return UNAVAILABLE
	if s.active or (s.gauge != null and s.gauge.charging) or casting == name:
		return ACTIVE
	return READY if (_slots[pool_of(name)] as Slot).charges > 0 else COOLING


# --- The selection (SKILL-BAR sections 1 and 2) ----------------------------------------
# These change the record only; the player's router publishes slot_selected.

# Picks a bar slot. Returns "" when it took, else the refusal: "unavailable" for a slot that
# is not on the bar or not available, "jammed" for one a field's pulse shut, "cooling" for one
# with no charge in.
func select(name: String) -> String:
	if not name in BAR or not _slots.has(name):
		return UNAVAILABLE
	var s: Slot = _slots[name]
	if s.id == "" or not s.available:
		return UNAVAILABLE
	if silenced(name):
		return JAMMED
	if name != WEAPON and not ready(name):
		return COOLING
	selected = name
	_select_held = 0.0
	return ""


# Sends the selection home to slot 1. True when it moved.
func snap_back(_reason := "") -> bool:
	_select_held = 0.0
	if selected == WEAPON:
		return false
	selected = WEAPON
	return true


# One tick of the pick's clock. It pauses while a gauge charges (`charging`); true on the tick
# a pick with no cast reaches SELECT_TIMEOUT, so the router snaps it back.
func tick_selection(delta: float, charging: bool) -> bool:
	if selected == WEAPON or charging:
		return false
	_select_held += delta
	return _select_held >= SELECT_TIMEOUT


# The share of the pick's timeout still to run, 1 at the pick, 0 at the snap; 0 at home.
func select_left() -> float:
	if selected == WEAPON:
		return 0.0
	return clampf(1.0 - _select_held / SELECT_TIMEOUT, 0.0, 1.0)


# Q's record for the HUD and bots: {id, icon, key, fill, state}, state charging, ready or
# active. The meter is B3's; with none the ultimate reads as charging at 0.
func ultimate() -> Dictionary:
	var fill := 0.0
	var state := "charging"
	if meter != null:
		fill = float(meter.fraction())
		if meter.get("locked") == true:
			state = ACTIVE
		elif meter.full():
			state = READY
	return {"id": ultimate_id, "icon": String(ABILITIES.get(ultimate_id, {}).get("icon", "")),
		"key": Bindings.label("ultimate"), "fill": fill, "state": state}


# The key a slot publishes now, read through the glyph lookup: the table's label while the
# keyboard keeps its default key (LMB, F), else the lookup's glyph id (key_g, pad_rt).
func slot_key(name: String) -> String:
	var label: String = movement_key if name == MOVEMENT else KEYS[name]
	for verb in Bindings.VERBS:
		if Bindings.label(verb) == label:
			var glyph := Glyphs.of(verb)
			return label if glyph == Bindings.glyph(verb) else glyph
	return label


# W1's Ability slots contract: one record per slot, in SLOTS order. cooldown_frac is the
# share of the recharging charge still to go, 0 when every charge is in. number is 1 to 3 on
# the bar and 0 for a chip; group is bar or chip; selected and select_left are the pick.
# pool is the slot whose charges this one spends (itself unless the row names another), and
# refill says how that pool comes back: "time" for a cooldown, "contact" for pressure that
# only rolling and contact refill, so the bar can show an empty charge instead of a clock.
func slots() -> Array:
	var out := []
	for name in SLOTS:
		var s: Slot = _slots[name]
		var cd := floored(s.cooldown, s.cooldown_scale)
		var frac := 0.0
		if s.charges < s.max_charges and cd > 0.0:
			frac = clampf(1.0 - s.recharge / cd, 0.0, 1.0)
		var full_charges := s.charges
		var charge_frac := 0.0
		if s.is_pressure and full_charges < s.max_charges:
			charge_frac = clampf(s.pressure_val - float(full_charges), 0.0, 1.0)
		var record := {"slot": name, "id": s.id, "icon": s.icon, "key": slot_key(name), "cooldown_frac": frac,
			"charges": full_charges, "max_charges": s.max_charges, "state": state_of(name),
			"gauge": s.gauge.fraction() if s.gauge != null else (cast_fraction() if name == casting else 0.0),
			"number": int(NUMBER.get(name, 0)), "group": "bar" if name in BAR else "chip",
			"selected": name == selected, "select_left": select_left() if name == selected else 0.0,
			"pool": pool_of(name), "refill": "contact" if ABILITIES.get(id_of(pool_of(name)), {}).has("pressure") else "time"}
		if s.is_pressure:
			record["charge_frac"] = charge_frac
		out.append(record)
	return out
