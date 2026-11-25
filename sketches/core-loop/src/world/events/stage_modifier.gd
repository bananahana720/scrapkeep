extends RefCounted

const ShiftVariants := preload("res://src/core/shift_variants.gd")

# Stage modifiers (SI3; W13-INTEGRATION-3.md SI3; comps/isaac/pacing-and-trades.md:84). At most one
# per stage, picked from the run seed and the stage number alone, so the stage card that shows it
# before the stage starts and the pocket draw that applies it read the same row, and a retry gets
# the same one. A row scales the drawn pocket count, scales how far the drawn pockets' beacons
# read, or keeps the draw to the farthest few anchors. It is a stage-start parameter, never a
# durable field (TADR-010:47), and nothing here reads or writes ball tuning, physics or input.

# Every park stage draws at least this many pockets, so every stage has a draw for a row to act
# on. Only the dam needs it: its four authored sites already pass stage 1's count of three, so it
# drew nothing and never had a modifier. It now draws the flume's one pocket and joins the same
# roll (ruling bu, 2026-11-09). Stages 2 to 6 already draw more and are unchanged.
const MIN_DRAWN := 1
const CHANCE := 0.4
# The drawn-plus-authored pocket cap (comps/isaac/floor-generation.md, cap 8).
const CAP := 8
# Far Haul keeps this many anchors, farthest from the main line first. Anchors are lattice nodes
# (about 700 to 1,900 a map); 250 keeps whole far areas rather than one cluster, so even the
# Crown's few anchors still fit its five pockets (150 fit about one a stage there).
const FAR_ANCHORS := 250
# The only effect keys a row may carry; a row with any other key is rejected by valid().
const EFFECTS := ["count_scale", "sight_scale", "far"]
# Presentation-only keys: fx is the world-effects overlay kind (WORLD-FX.md, PR #47).
const LOOKS := ["id", "word", "line", "fx"]
const WORLD_FX := "res://src/presentation/world_fx/world_fx.gd"
const WORLD_FX_ANCHOR := "res://src/presentation/world_fx/world_fx_anchor.gd"
# The lines are the Foreman's memos (STORY-MAP.md, the Foreman's voice): dry optimiser talk that
# is pleased with itself, and each still ends on what the stage does. The card is up for about two
# seconds over a launch, so a line stays inside eight short words (stage_modifier_test).
const ROWS := [
	{"id": "surplus", "word": "Surplus Yard", "line": "A forecasting win. More pockets.", "fx": "plenty", "count_scale": 2.0},
	{"id": "lean", "word": "Lean Haul", "line": "More with less. Mostly less. Fewer pockets.", "fx": "scarce", "count_scale": 0.5},
	{"id": "floodlit", "word": "Floodlit", "line": "Transparency is a value. Beacons read far.", "sight_scale": 1.75},
	{"id": "blackout", "word": "Blackout", "line": "Lighting, right-sized. Beacons read near.", "fx": "hidden", "sight_scale": 0.5},
	{"id": "far_haul", "word": "Far Haul", "line": "Value was relocated to the edges.", "far": true},
]
# A stage with no modifier still gets the Foreman's memo, so it shows up on every card (W1-75):
# the same voice with nothing to announce, which is its own small joke. No word goes before it,
# because there is no condition to name; a card with a word on it is a stage that plays different.
# The seed and the stage pick one, from a stream of its own (memo), so the draw never moves.
const NOMINAL := [
	"Conditions nominal. Morale is optional.",
	"Nothing to report. That is the report.",
	"No changes. Stability is our product.",
	"Everything is aligned. Proceed as scheduled.",
	"This stage is fully optimised. You're welcome.",
	"Conditions nominal. Gratitude is appreciated in advance.",
]


static func valid(row: Dictionary) -> bool:
	for key in row:
		if not key in LOOKS and not key in EFFECTS:
			return false
	return true


# The authored sites a stage's draw counts against. A card 2 extra (PARK.md 2.12: the completionist card's added
# activities) stands beside the draw, not in place of it, so it is not counted.
static func authored(map) -> int:
	return map.activity_sites.filter(func(s: Dictionary) -> bool: return s.get("extra", "") != "card_2").size()


# The drawn slots a stage has before any modifier (pocket_draw.gd draw: 3 to 5 rising one a stage),
# never under MIN_DRAWN while the cap has room.
static func base_slots(stage: int, authored: int) -> int:
	var room := maxi(0, CAP - authored)
	return clampi(mini(CAP, stage + 2) - authored, mini(MIN_DRAWN, room), room)


# The drawn slots with the row applied: scaled, at least one, and never past the cap.
static func slots(row: Dictionary, stage: int, authored: int) -> int:
	var base := base_slots(stage, authored)
	if base == 0 or not row.has("count_scale"):
		return base
	return clampi(ceili(base * float(row.count_scale)), 1, maxi(0, CAP - authored))


# The most drawn slots any row can give the stage, for checking a saved draw.
static func max_slots(stage: int, authored: int) -> int:
	var most := base_slots(stage, authored)
	for row in ROWS:
		most = maxi(most, slots(row, stage, authored))
	return most


# A row is offered only where it changes something: a count row only where its count differs.
static func _eligible(row: Dictionary, stage: int, authored: int) -> bool:
	if base_slots(stage, authored) == 0:
		return false
	return not row.has("count_scale") or slots(row, stage, authored) != base_slots(stage, authored)


# The stage's modifier, or {} for none, from its own stream (no shared RNG is touched).
static func pick(run_seed: int, stage: int, authored: int) -> Dictionary:
	if stage < 1:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, stage, "stage_modifier"])
	if rng.randf() >= CHANCE:
		return {}
	var offered := ROWS.filter(func(row): return _eligible(row, stage, authored))
	if offered.is_empty():
		return {}
	return offered[rng.randi_range(0, offered.size() - 1)].duplicate(true)


# The modifier for a stage of a terrain's table: only park maps draw pockets.
static func for_stage(run, terrain, stage: int) -> Dictionary:
	var map = _park_map(terrain, stage)
	if run == null or map == null:
		return {}
	return pick(int(run.run_seed), stage, authored(map))


# The stage's park map, or null when the stage has none (nothing to draw, no modifier, no memo).
static func _park_map(terrain, stage: int):
	if terrain == null or not terrain.has_method("map_for") or not "maps" in terrain:
		return null
	if stage < 1 or stage > terrain.maps.size():
		return null
	var map = terrain.map_for(stage)
	if map == null or not "park" in map or map.park.is_empty() or not "activity_sites" in map:
		return null
	return map


# The farthest anchors a Far Haul draw may use, farthest first.
static func far_anchors(prepared: Dictionary) -> Array:
	var anchors: Array = prepared.get("anchors", []).duplicate()
	var line: PackedFloat32Array = prepared.from_line
	anchors.sort_custom(func(a, b): return line[a.node] > line[b.node] or (line[a.node] == line[b.node] and a.node < b.node))
	return anchors.slice(0, FAR_ANCHORS)


static func caption(row: Dictionary) -> String:
	return "" if row.is_empty() else "%s: %s" % [row.word, row.line]


# The Foreman's memo on a stage card: the modifier's caption when one rolled, else a nominal line.
static func memo(run_seed: int, stage: int, row: Dictionary) -> String:
	if not row.is_empty():
		return caption(row)
	return String(NOMINAL[absi(hash([run_seed, stage, "memo"])) % NOMINAL.size()])


# The run-long cursed state shares the card: its own card when the deal is taken, then a line
# on every later stage card beside the stage's modifier. The deal was a keeper's gamble, so the
# line is the crew's, the door sign's "Nobody makes you." come due (trade_pockets.gd DOOR_WORDS).
const CURSE := {"id": "curse", "word": "Cursed Run", "line": "You shook on it. Nobody made you."}


static func card_line(run, terrain, stage: int) -> String:
	var lines := []
	if run != null and run.cursed():
		lines.append(caption(CURSE))
	for row in ShiftVariants.card_rows(run, stage):
		lines.append(caption(row))
	if run != null and _park_map(terrain, stage) != null:
		lines.append(memo(int(run.run_seed), stage, for_stage(run, terrain, stage)))
	return "  /  ".join(lines)


# World effects (WORLD-FX.md hooks). Each call does nothing until that kit is in the build and a
# WorldFx is installed for the stage, so the modifier works with or without it.
static func announce(at: Vector3) -> void:
	if ResourceLoader.exists(WORLD_FX):
		load(WORLD_FX).fire("modifier_shown", at)


# The stage's overlay air: plenty, scarce or hidden for the rows that name one, cleared otherwise.
static func set_air(row: Dictionary) -> void:
	if not ResourceLoader.exists(WORLD_FX):
		return
	var current = load(WORLD_FX).current
	if is_instance_valid(current):
		current.set_overlay(String(row.get("fx", "")))


# A brass flare (mod_far) on each Far Haul pocket.
static func mark_far(row: Dictionary, site: Node3D) -> void:
	if row.get("far", false) and ResourceLoader.exists(WORLD_FX_ANCHOR):
		site.add_child(load(WORLD_FX_ANCHOR).make("mod_far"))
