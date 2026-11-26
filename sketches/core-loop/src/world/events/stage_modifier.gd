extends RefCounted

const ShiftVariants := preload("res://src/core/shift_variants.gd")
const PilotStory := preload("res://src/core/pilot_story.gd")


const MIN_DRAWN := 1
const CHANCE := 0.4
const CAP := 8
const FAR_ANCHORS := 250
const EFFECTS := ["count_scale", "sight_scale", "far"]
const LOOKS := ["id", "word", "line", "fx"]
const WORLD_FX := "res://src/presentation/world_fx/world_fx.gd"
const WORLD_FX_ANCHOR := "res://src/presentation/world_fx/world_fx_anchor.gd"
const ROWS := [
	{"id": "surplus", "word": "Surplus Yard", "line": "Synergistic forecasting win. More pockets.", "fx": "plenty", "count_scale": 2.0},
	{"id": "lean", "word": "Lean Haul", "line": "More with less. Mostly less. Fewer pockets.", "fx": "scarce", "count_scale": 0.5},
	{"id": "floodlit", "word": "Floodlit", "line": "Radical transparency deployed. Beacons read far.", "sight_scale": 1.75},
	{"id": "blackout", "word": "Blackout", "line": "Lighting right-sized for alignment. Beacons read near.", "fx": "hidden", "sight_scale": 0.5},
	{"id": "far_haul", "word": "Far Haul", "line": "Value relocated to synergistic outer edges.", "far": true},
	{"id": "overstock", "word": "Overstock", "line": "Inventory scaled to the rims. More pockets.", "fx": "plenty", "count_scale": 1.5, "far": true},
	{"id": "audit_flare", "word": "Audit Flare", "line": "Full metric visibility mandated. Beacons read far.", "fx": "plenty", "sight_scale": 2.25, "far": true},
	{"id": "brownout", "word": "Brownout", "line": "Sunsetting redundant light and supply. Fewer pockets.", "fx": "hidden", "count_scale": 0.5, "sight_scale": 0.7},
]
const NOMINAL := [
	"Conditions nominal. Morale remains optional.",
	"Synergistic efficiencies achieved. No action required.",
	"Everything is aligned. Grateful for your metrics.",
	"This stage is fully optimised. You're welcome.",
	"Nothing to report. That is the report.",
	"Sunsetting friction today. Proceed as scheduled.",
	"No changes. Stability is our flagship product.",
	"Alignment up four percent. Gratitude noted.",
	"Conditions nominal. Thank you for scaling smoothly.",
]


static func valid(row: Dictionary) -> bool:
	for key in row:
		if not key in LOOKS and not key in EFFECTS:
			return false
	return true


static func authored(map) -> int:
	return map.activity_sites.filter(func(s: Dictionary) -> bool: return s.get("extra", "") != "card_2").size()


static func base_slots(stage: int, authored: int) -> int:
	var room := maxi(0, CAP - authored)
	return clampi(mini(CAP, stage + 2) - authored, mini(MIN_DRAWN, room), room)


static func slots(row: Dictionary, stage: int, authored: int) -> int:
	var base := base_slots(stage, authored)
	if base == 0 or not row.has("count_scale"):
		return base
	return clampi(ceili(base * float(row.count_scale)), 1, maxi(0, CAP - authored))


static func max_slots(stage: int, authored: int) -> int:
	var most := base_slots(stage, authored)
	for row in ROWS:
		most = maxi(most, slots(row, stage, authored))
	return most


static func _eligible(row: Dictionary, stage: int, authored: int) -> bool:
	if base_slots(stage, authored) == 0:
		return false
	return not row.has("count_scale") or slots(row, stage, authored) != base_slots(stage, authored)


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


static func for_stage(run, terrain, stage: int) -> Dictionary:
	var map = _park_map(terrain, stage)
	if run == null or map == null:
		return {}
	return pick(int(run.run_seed), stage, authored(map))


static func _park_map(terrain, stage: int):
	if terrain == null or not terrain.has_method("map_for") or not "maps" in terrain:
		return null
	if stage < 1 or stage > terrain.maps.size():
		return null
	var map = terrain.map_for(stage)
	if map == null or not "park" in map or map.park.is_empty() or not "activity_sites" in map:
		return null
	return map


static func far_anchors(prepared: Dictionary) -> Array:
	var anchors: Array = prepared.get("anchors", []).duplicate()
	var line: PackedFloat32Array = prepared.from_line
	anchors.sort_custom(func(a, b): return line[a.node] > line[b.node] or (line[a.node] == line[b.node] and a.node < b.node))
	return anchors.slice(0, FAR_ANCHORS)


static func caption(row: Dictionary) -> String:
	return "" if row.is_empty() else "%s: %s" % [row.word, row.line]


static func memo(run_seed: int, stage: int, row: Dictionary) -> String:
	if not row.is_empty():
		return caption(row)
	return String(NOMINAL[absi(hash([run_seed, stage, "memo"])) % NOMINAL.size()])


const CURSE := {"id": "curse", "word": "Cursed Run", "line": "You shook on it. Nobody made you."}


static func card_line(run, terrain, stage: int, profile = null, pages: Array = []) -> String:
	var lines := []
	if run != null and run.cursed():
		lines.append(caption(CURSE))
	for row in ShiftVariants.card_rows(run, stage):
		lines.append(caption(row))
	if run != null and _park_map(terrain, stage) != null:
		var row := for_stage(run, terrain, stage)
		var adaptive := PilotStory.foreman_stage_memo(int(run.run_seed), stage, profile, pages, run) if row.is_empty() and profile != null else ""
		lines.append(adaptive if adaptive != "" else memo(int(run.run_seed), stage, row))
	return "  /  ".join(lines)


static func announce(at: Vector3) -> void:
	if ResourceLoader.exists(WORLD_FX):
		load(WORLD_FX).fire("modifier_shown", at)


static func set_air(row: Dictionary) -> void:
	if not ResourceLoader.exists(WORLD_FX):
		return
	var current = load(WORLD_FX).current
	if is_instance_valid(current):
		current.set_overlay(String(row.get("fx", "")))


static func mark_far(row: Dictionary, site: Node3D) -> void:
	if row.get("far", false) and ResourceLoader.exists(WORLD_FX_ANCHOR):
		site.add_child(load(WORLD_FX_ANCHOR).make("mod_far"))
