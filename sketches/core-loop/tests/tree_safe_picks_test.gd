extends SceneTree

# 2026-10-11 (PC-TARN ruling 1): world-one alone bans knobs/swaps; depths 3/4 require safe picks.
# 2026-10-11 (PC-TALLY): the same ruling for Tally, with a planted world-one swap.
# Expected: 60 checks, including a planted world-one knob through Tarn's ruling predicate and a
# planted world-one swap through Tally's.

const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Icons := preload("res://src/ui/icons.gd")
const WorldOneCards := preload("res://src/core/trees/world_one_cards.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Relics := preload("res://src/build/relics.gd")

class AbilityFixture extends RefCounted:


	const SWAPPABLE := AbilityState.SWAPPABLE
	const SLOTS := AbilityState.SLOTS
	const ULTIMATE := AbilityState.ULTIMATE
	const COOLDOWN_FLOOR := AbilityState.COOLDOWN_FLOOR
	static var ABILITIES := AbilityState.ABILITIES.duplicate(true)

# Rule: four safe growth picks cannot replace an ability, disable it, lower a knob's
# default, or undo an earlier pick. Validate all 180 distinct nodes (six pilots' own trees).
# Tarn's nodes and relics are also checked for dead offers (STRATEGY-SPINE.md:175).
# Existing tradeoffs are findings, not permission to change content.
# Decision 3 is pending: numerical decreases are conservatively flagged even when
# they help. These tests prove detection, not that the present trees are all safe.
# No Game, wall clock, save writes, or runtime/feel claim is needed for this rule.

const UNSAFE := {
	"pylon_engineer": ["s_face_runner", "s_crater"],
	"runner_gunner": ["r_run_gun", "r_ram_fins", "r_point_blank", "r_skyline"],
	"demolitions_caster": ["k_ghost", "k_heavy_charge", "k_sticky_rain"],
	"tarn": [],
	"tally": [],
	"remembered_cannon": [],
}

var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	var checked := 0
	var distinct := {}
	var pilots := []
	for def in ClassDef.all():
		pilots.append(def.id)
		var list := UpgradeTree.nodes(def.id)
		var before := list.duplicate(true)
		var flagged := []
		var findings: Array[String] = []
		var safe_routes := 0
		for i in list.size():
			checked += 1
			distinct[list[i]["id"]] = true
			var earlier := _earlier(list, i)
			var issues := UpgradeTree.safe_pick_problems(def.id, list[i], earlier)
			findings.append_array(issues)
			if not issues.is_empty():
				flagged.append(list[i]["id"])
			if UpgradeTree.depth_of(i) == UpgradeTree.DEPTHS:
				var route_ok := issues.is_empty()
				var prior: Array = []
				for n in earlier:
					route_ok = route_ok and UpgradeTree.safe_pick_problems(def.id, n, prior).is_empty()
					prior.append(n)
				if route_ok:
					safe_routes += 1
		_report(def.display_name, list.size() == 30 and flagged == UNSAFE.get(def.id, []),
			"30 nodes; flagged %s; %d four-pick routes preserve swaps/knobs" % [flagged, safe_routes])
		_report("%s whole-tree validator" % def.display_name,
			UpgradeTree.safe_growth_problems(def.id) == findings, "%d findings" % findings.size())
		for finding in findings:
			print("FINDING %s: %s" % [def.display_name, finding])
		var world_one: Array[String] = []
		for i in UpgradeTree.WORLD_ONE_SIZE:
			var profile := UpgradeTree.nodes(def.id, true)
			world_one.append_array(UpgradeTree.safe_pick_problems(def.id, profile[i], _earlier(profile, i)))
		_report("%s world one" % def.display_name,
			UpgradeTree.safe_growth_problems(def.id, true) == world_one, "%d reachable-node findings" % world_one.size())
		_report("%s data preserved" % def.display_name, list == before, "validator never edits nodes")
	_report("all six pilots", pilots == UNSAFE.keys() and checked == 30 * UNSAFE.size() and distinct.size() == 180,
		"%d rows, %d distinct nodes, pilots %s" % [checked, distinct.size(), pilots])
	_dead_offers()
	_fixtures()
	_tarn_rows()
	_tally_rows()
	_cannon_rows()
	print("tree_safe_picks_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _earlier(list: Array, index: int) -> Array:
	var out: Array = []
	var parent: int = (index - 2) / 2 if index >= 2 else -1
	while parent >= 0:
		out.push_front(list[parent])
		parent = (parent - 2) / 2 if parent >= 2 else -1
	return out


# Bus facts every class's own special or slam emits (combat.gd special_used after any gauge release,
# player_ball.gd slammed for every slam), so a proc on them is live whatever the kit.
# 2026-10-05 (alpha wave 15 tally-tree): every class movement appends dashed (augments.gd vault,
# sprint, blink, claw pull, surge) and holds.gd emits hold_broken for any pilot, so Tally's own
# procs on them no longer make Tarn's read as another pilot's token.
const KIT_AGNOSTIC_ON := ["special_used", "slammed", "dashed", "hold_broken"]


func _class_kit(pilot: String) -> Dictionary:
	var def: Resource = ClassDef.by_id(pilot)
	return {"weapon": def.weapon_id, "movement": def.movement_id, "special": def.special_id, "smash": def.smash_id,
		"line": def.line_id, "ultimate": def.ultimate_id}


# The class row's six ids with the swaps of every earlier node on the route applied.
func _kit_before(pilot: String, node_id: String, world_one: bool) -> Dictionary:
	var kit := _class_kit(pilot)
	var path := UpgradeTree.path_to(pilot, node_id, world_one)
	for id in path.slice(0, path.size() - 1):
		for slot in UpgradeTree.node(pilot, id, world_one).get("swap", {}):
			kit[slot] = UpgradeTree.node(pilot, id, world_one)["swap"][slot]
	return kit


# Other pilots' (slot, class ability) pairs for every node that sets a knob or proc token.
func _token_pairs(pilot: String, token: String) -> Array:
	var pairs := []
	for other in UpgradeTree.TREES:
		if other == pilot:
			continue
		var kit := _class_kit(other)
		for m in UpgradeTree.TREES[other]:
			var uses: bool = m.get("knob", {}).has(token)
			for p in m.get("proc", []):
				uses = uses or "proc:" + String(p["on"]) == token
			if uses:
				pairs.append([String(m["key"]), kit[m["key"]]])
	return pairs


func _token_live(pilot: String, token: String, kit: Dictionary) -> bool:
	var pairs := _token_pairs(pilot, token)
	if pairs.is_empty():
		return true
	return pairs.any(func(pr): return kit[pr[0]] == pr[1])


func _op_live(pilot: String, n: Dictionary, kit: Dictionary, rows: Dictionary = AbilityState.ABILITIES) -> bool:
	for slot in n.get("swap", {}):
		var replacement = n["swap"][slot]
		if slot == AbilityState.ULTIMATE and String(rows.get(replacement, {}).get("variant_of", "")) != String(kit[slot]):
			continue
		if replacement != kit[slot]:
			return true
	for op in ["charges", "cooldown"]:
		for slot in n.get(op, {}):
			if float(rows[kit[slot]]["cooldown"]) > 0.0:
				return true
	var row: Dictionary = rows[kit["weapon"]]
	for w in n.get("pattern", {}):
		if w == row.get("pattern", kit["weapon"]) or w == row.get("mounted", ""):
			return true
	for name in n.get("knob", {}):
		if _token_live(pilot, name, kit):
			return true
	for p in n.get("proc", []):
		if String(p["on"]) in UpgradeTree.DAMAGE_FACTS or String(p["on"]) in KIT_AGNOSTIC_ON or _token_live(pilot, "proc:" + String(p["on"]), kit):
			return true
	return false


# A relic's swap, charges or cooldown is live under the class kit; one that also fits Rivet is a
# stale alias unless Tarn's slot ability is Rivet's. Relic parts are not judged.
func _relic_live(pilot: String, id: String) -> bool:
	var r: Dictionary = Relics.row(id)
	var kit := _class_kit(pilot)
	var slot := String(r["slot"])
	var as_node := {}
	if r.has("swap"):
		as_node["swap"] = {slot: r["swap"]}
	if r.has("cooldown"):
		as_node["cooldown"] = {slot: r["cooldown"]}
	if r.has("charges"):
		as_node["charges"] = {slot: r["charges"]}
	if not as_node.is_empty() and Relics.fits(id, "runner_gunner") and kit[slot] != _class_kit("runner_gunner")[slot]:
		return false
	return _op_live(pilot, as_node, kit)


func _dead_offers() -> void:
	var dead := []
	var checked := 0
	for world_one in [false, true]:
		for n in UpgradeTree.nodes("tarn", world_one).slice(0, 6 if world_one else 30):
			checked += 1
			if not _op_live("tarn", n, _kit_before("tarn", n["id"], world_one)):
				dead.append("%s%s" % [n["id"], " (world one)" if world_one else ""])
	_report("Tarn no dead tree rows", checked == 36 and dead.is_empty(), "%d nodes checked (30 full, 6 world one); dead %s" % [checked, dead])
	var fitting := Relics.ids().filter(func(id): return Relics.fits(id, "tarn"))
	var dead_relics := fitting.filter(func(id): return not _relic_live("tarn", id))
	_report("Tarn no dead relics", not fitting.is_empty() and dead_relics.is_empty(),
		"%d fitting relics %s; dead %s; relic parts not judged" % [fitting.size(), fitting, dead_relics])


func _fixtures() -> void:
	_slot_fixtures()
	var tarn_kit := _class_kit("tarn")
	var laser_kit := tarn_kit.duplicate()
	laser_kit["weapon"] = "rapid_laser"
	_report("dead-row fixtures",
		not _op_live("tarn", {"key": "movement", "knob": {"sprint_punch": 9.0}}, tarn_kit)
		and not _op_live("tarn", {"key": "weapon", "swap": {"weapon": "claw_sweep"}}, tarn_kit)
		and not _op_live("tarn", {"key": "weapon", "charges": {"weapon": 1}}, laser_kit)
		and not _op_live("tarn", {"key": "weapon", "pattern": {"sticky_charge": {"add": {"count": 1}}}}, tarn_kit)
		and not _op_live("tarn", {"key": "movement", "proc": [{"on": "sprint_started", "do": "blast"}]}, tarn_kit)
		and _op_live("tarn", {"key": "special", "proc": [{"on": "slammed", "do": "blast"}]}, tarn_kit)
		and _op_live("tarn", {"key": "weapon", "knob": {"tarn_only_fixture": 2.0}}, tarn_kit),
		"under Tarn's kit a foreign knob, identity swap, charges on a zero-cooldown weapon, a foreign pattern and a proc on Rivet's sprint fact are dead; a proc on slammed and a Tarn-owned knob are live")
	var pilot := "pylon_engineer"
	var bad := {"id": "bad_fixture", "swap": {"movement": "rapid_laser"}, "knob": {"mount_reach": 0.5}}
	var issues := UpgradeTree.safe_pick_problems(pilot, bad)
	_report("bad fixture rejected", issues.size() == 2 and issues[0].contains("replaces ability grapple")
		and issues[1].contains("lowers default"), str(issues))
	_report("additive fixture accepted", UpgradeTree.safe_pick_problems(pilot,
		{"id": "safe_fixture", "swap": {"movement": "grapple"}, "knob": {"mount_reach": 2.0, "vault_air": true}}).is_empty(),
		"identity swap, increased reach, new air jump")
	_report("earlier numeric pick preserved", not UpgradeTree.safe_pick_problems(pilot,
		{"knob": {"mount_reach": 1.5}}, [{"knob": {"mount_reach": 2.0}}]).is_empty(), "above default still undoes earlier growth")
	_report("earlier ability preserved", not UpgradeTree.safe_pick_problems(pilot,
		{"knob": {"vault_air": false}}, [{"knob": {"vault_air": true}}]).is_empty(), "false removes the earlier air jump")
	_report("replacement with richer kit rejected", not UpgradeTree.safe_pick_problems("demolitions_caster",
		{"swap": {"movement": "grapple"}}).is_empty(), "more augments cannot compensate for losing blink, glide, rocket and cloak")
	_report("unknown swap rejected", not UpgradeTree.safe_pick_problems(pilot,
		{"swap": {"weapon": "missing_ability"}}).is_empty(), "missing ability row")
	_report("unknown knob rejected", not UpgradeTree.safe_pick_problems(pilot,
		{"knob": {"missing_knob": 1.0}}).is_empty(), "missing default cannot be certified safe")
	_report("boolean type checked", not UpgradeTree.safe_pick_problems(pilot,
		{"knob": {"vault_air": 0}}).is_empty(), "numeric zero cannot disguise a disabled boolean")
	_report("numeric type checked", not UpgradeTree.safe_pick_problems(pilot,
		{"knob": {"mount_reach": "two"}}).is_empty(), "string cannot disguise a lower number")
	_report("finite number checked", not UpgradeTree.safe_pick_problems(pilot,
		{"knob": {"mount_reach": NAN}}).is_empty(), "NaN cannot evade comparison")


func _slot_fixtures() -> void:
	for def in ClassDef.all():
		var kit := _class_kit(def.id)
		_report("%s six-slot kit" % def.display_name, kit.keys() == UpgradeTree.KEYS
			and kit["line"] == def.line_id and kit["ultimate"] == def.ultimate_id, str(kit))
	var pilot := "tarn"
	var kit := _class_kit(pilot)
	_report("own line knob is live", _op_live(pilot,
		{"key": "line", "knob": {"tarn_only_fixture": 1.0}}, kit), "fixture token owned by this pilot")
	_report("line swap is live", "line" in AbilityState.SWAPPABLE and _op_live(pilot,
		{"key": "line", "swap": {"line": "link_clips"}}, kit), "existing line row differs from the held line_reel")
	var variant := "fixture_ultimate_growth"
	var foreign := "fixture_foreign_ultimate"
	var fixture_tree := GDScript.new()
	fixture_tree.source_code = FileAccess.get_file_as_string("res://src/core/upgrade_tree.gd").replace("const AbilityState :=", "static var AbilityState: Variant =")
	var compiled := fixture_tree.reload()
	_report("ultimate fixture compiles", compiled == OK, str(compiled))
	if compiled != OK:
		return
	fixture_tree.AbilityState = AbilityFixture
	AbilityFixture.ABILITIES[variant] = {"cooldown": 0.0, "variant_of": kit["ultimate"]}
	AbilityFixture.ABILITIES[foreign] = {"cooldown": 0.0}
	var growth := {"key": "ultimate", "swap": {"ultimate": variant}}
	var replacement := {"key": "ultimate", "swap": {"ultimate": foreign}}
	var issues: Array = fixture_tree.safe_pick_problems(pilot, growth)
	_report("ultimate variant is growth", issues.is_empty() and _op_live(pilot, growth, kit, AbilityFixture.ABILITIES), str(issues))
	_report("foreign ultimate is dead", not _op_live(pilot, replacement, kit, AbilityFixture.ABILITIES)
		and not fixture_tree.safe_pick_problems(pilot, replacement).is_empty(), "fixture row has no variant_of relationship")
	AbilityFixture.ABILITIES.erase(variant)
	AbilityFixture.ABILITIES.erase(foreign)


func _tarn_rows() -> void:
	var tarn := UpgradeTree.nodes("tarn")
	var ids := tarn.map(func(n): return String(n["id"]))
	var own := ids.all(func(i): return i.begins_with("t_"))
	var profile := UpgradeTree.nodes("tarn", true)
	var shared := UpgradeTree.nodes("runner_gunner").filter(func(n): return n["id"] in ids)
	_report("Tarn's own tree", own and profile.size() == 30 and profile[0]["id"] == "t_saw_flurry" and shared.is_empty(),
		"%d world-one nodes, first %s, %d shared with Rivet" % [profile.size(), profile[0]["id"] if not profile.is_empty() else "-", shared.size()])
	var bad := []
	var allowed := func(n: Dictionary, world_one: bool, earlier: Array) -> bool:
		var ok: bool = not world_one or (not n.has("knob") and not n.has("swap"))
		if not world_one and (n.has("knob") or n.has("swap")):
			ok = ok and UpgradeTree.safe_pick_problems("tarn", n, earlier).is_empty()
		for weapon in n.get("pattern", {}):
			ok = ok and weapon == "claw_sweep" and float(n["pattern"][weapon].get("mul", {}).get("damage", 1.0)) <= 1.0
		ok = ok and not String(n["effect"]).to_lower().contains("plating")
		ok = ok and (Icons.IDS.has(n["icon"]) or Icons.EXTRA.has(n["icon"]))
		return ok
	for i in tarn.size():
		if not allowed.call(tarn[i], false, _earlier(tarn, i)):
			bad.append(tarn[i]["id"])
	for i in UpgradeTree.WORLD_ONE_SIZE:
		if not allowed.call(profile[i], true, _earlier(profile, i)):
			bad.append("%s (world one)" % profile[i]["id"])
	_report("Tarn rulings", bad.is_empty(), "world-one bans knobs/swaps; later picks safe; claw-only, no damage gain, plating or unknown icon; bad %s" % [bad])
	var planted: Dictionary = profile[0].duplicate(true)
	planted["knob"] = {"ult_beats": 3.0}
	_report("Tarn planted world-one knob rejected", not allowed.call(planted, true, []), "world-one knob must remain banned")
	var first_six := profile.slice(0, UpgradeTree.WORLD_ONE_SIZE).map(func(n): return String(n["id"]))
	var cards_ok: bool = first_six.size() == 6 and first_six.all(func(i): return WorldOneCards.has_row(i) and not WorldOneCards.UNFITTED_ROWS.has(i))
	_report("Tarn world-one cards", cards_ok, "%s" % [first_six])


func _tally_rows() -> void:
	var tally := UpgradeTree.nodes("tally")
	var ids := tally.map(func(n): return String(n["id"]))
	var own := ids.all(func(i): return i.begins_with("tl_"))
	var profile := UpgradeTree.nodes("tally", true)
	var shared := []
	for other in UpgradeTree.TREES:
		if other != "tally":
			shared.append_array(UpgradeTree.TREES[other].filter(func(n): return n["id"] in ids).map(func(n): return n["id"]))
	_report("Tally's own tree", own and profile.size() == 30 and profile[0]["id"] == "tl_petty_cash" and shared.is_empty(),
		"%d world-one nodes, first %s, shared with other pilots %s" % [profile.size(), profile[0]["id"] if not profile.is_empty() else "-", shared])
	# 2026-10-11 (PC-TALLY, design-v3/pilots/tally.md section 3): as Tarn's ruling, world one alone
	# bans knobs and swaps. Depth 3 may swap Q to Audit Trail or Flywheel Throw and depth 4 may turn
	# one ult_ knob, each a safe pick; 2026-11-24 (W46 E2-09, PILOT-CADENCE §6.1): the two world-one
	# depth-1 keystones (tl_petty_cash, tl_compound_interest) tune ledger_reader cadence via pattern.
	var actions := ["blast", "air", "grant_move", "grant_special", "refund_move", "refund_special"]
	var variants := ["plate_audit", "plate_flywheel"]
	var knobs := ["ult_encore", "ult_beats", "ult_radius", "ult_volley", "ult_settle"]
	var allowed := func(n: Dictionary, world_one: bool, earlier: Array) -> bool:
		var is_wo_keystone: bool = world_one and String(n["id"]) in ["tl_petty_cash", "tl_compound_interest"]
		var ok: bool = (not n.has("pattern")) or (is_wo_keystone and n["pattern"].keys() == ["ledger_reader"])
		ok = ok and (not world_one or (not n.has("knob") and not n.has("swap")))
		for slot in n.get("swap", {}):
			ok = ok and slot == AbilityState.ULTIMATE and String(n["swap"][slot]) in variants
		for knob in n.get("knob", {}):
			ok = ok and String(knob) in knobs
		if n.has("knob") or n.has("swap"):
			ok = ok and UpgradeTree.safe_pick_problems("tally", n, earlier).is_empty()
		for p in n.get("proc", []):
			ok = ok and String(p["do"]) in actions
			ok = ok and not (String(p["do"]) == "blast" and String(p["on"]) in UpgradeTree.DAMAGE_FACTS)
		ok = ok and (Icons.IDS.has(n["icon"]) or Icons.EXTRA.has(n["icon"]))
		return ok
	var bad := []
	for i in tally.size():
		if not allowed.call(tally[i], false, _earlier(tally, i)):
			bad.append(tally[i]["id"])
	for i in UpgradeTree.WORLD_ONE_SIZE:
		if not allowed.call(profile[i], true, _earlier(profile, i)):
			bad.append("%s (world one)" % profile[i]["id"])
	var depth_two := tally.slice(2, 6).map(func(n): return String(n["name"]))
	_report("Tally rulings", bad.is_empty() and depth_two == ["Through Feed", "Line Feed", "Spring Vent", "Corner Plate"],
		"world one bans knobs and swaps; depth 3 swaps Q to %s, depth 4 turns %s, each safe; procs only %s; no blast on a damage fact; known icons; bad %s; depth 2 %s" % [variants, knobs, actions, bad, depth_two])
	var planted: Dictionary = profile[0].duplicate(true)
	planted["swap"] = {AbilityState.ULTIMATE: "plate_audit"}
	_report("Tally planted world-one swap rejected", not allowed.call(planted, true, []), "world-one swap must remain banned")
	var first_six := profile.slice(0, UpgradeTree.WORLD_ONE_SIZE).map(func(n): return String(n["id"]))
	var cards_ok: bool = first_six.size() == 6 and first_six.all(func(i): return WorldOneCards.has_row(i) and not WorldOneCards.UNFITTED_ROWS.has(i))
	_report("Tally world-one cards", cards_ok, "%s" % [first_six])


func _cannon_rows() -> void:
	# 2026-10-12 (PC-CANNON): world-one bans knobs/swaps; later picks use the shared safety rule.
	# 2026-11-24 (W46 E2-09, PILOT-CADENCE §6.1): world-one depth-1 keystones (c_snap_battery,
	# c_siege_rail) tune cannon_lane lock cadence fields directly read by the lane driver.
	var cannon := UpgradeTree.nodes("remembered_cannon")
	var ids := cannon.map(func(n): return String(n["id"]))
	var own := ids.all(func(i): return i.begins_with("c_"))
	var profile := UpgradeTree.nodes("remembered_cannon", true)
	var shared := []
	for other in UpgradeTree.TREES:
		if other != "remembered_cannon":
			shared.append_array(UpgradeTree.TREES[other].filter(func(n): return n["id"] in ids).map(func(n): return n["id"]))
	_report("Cannon's own tree", own and profile.size() == 30 and profile[0]["id"] == "c_snap_battery" and shared.is_empty(),
		"%d world-one nodes, first %s, shared with other pilots %s" % [profile.size(), profile[0]["id"] if not profile.is_empty() else "-", shared])
	var weapon := String(ClassDef.by_id("remembered_cannon").weapon_id)
	var bad := []
	var allowed := func(n: Dictionary, world_one: bool, earlier: Array) -> bool:
		var is_wo_keystone: bool = world_one and String(n["id"]) in ["c_snap_battery", "c_siege_rail"]
		var ok: bool = not world_one or (not n.has("knob") and not n.has("swap"))
		if not world_one and (n.has("knob") or n.has("swap")):
			ok = ok and UpgradeTree.safe_pick_problems("remembered_cannon", n, earlier).is_empty()
		var pattern: Dictionary = n.get("pattern", {})
		var shapes_bolts := false
		for key in pattern:
			ok = ok and String(key) == weapon
			var t: Dictionary = pattern[key]
			ok = ok and float(t.get("mul", {}).get("damage", 1.0)) <= 1.0
			for part in ["set", "add", "mul", "min"]:
				ok = ok and not t.get(part, {}).has("range_m")
				for k in t.get(part, {}):
					if not is_wo_keystone:
						shapes_bolts = shapes_bolts or String(k) != "rate"
		if shapes_bolts:
			# Lane honesty (D3): the lane reads only rate, so a row that shapes bolts needs a volley above it.
			var above := UpgradeTree.path_to("remembered_cannon", n["id"])
			above.pop_back()
			var volley := false
			for a in cannon.filter(func(m): return m["id"] in above):
				for p in a.get("proc", []):
					volley = volley or String(p["do"]) == "volley"
			ok = ok and volley
		ok = ok and (Icons.IDS.has(n["icon"]) or Icons.EXTRA.has(n["icon"]))
		return ok
	for i in cannon.size():
		if not allowed.call(cannon[i], false, _earlier(cannon, i)):
			bad.append(cannon[i]["id"])
	for i in UpgradeTree.WORLD_ONE_SIZE:
		if not allowed.call(profile[i], true, _earlier(profile, i)):
			bad.append("%s (world one)" % profile[i]["id"])
	_report("Cannon rulings", bad.is_empty(),
		"world-one bans knobs/swaps; later picks safe; patterns on %s only; no damage mul above 1.0; no range_m; non-rate rows under a volley; known icons; bad %s" % [weapon, bad])
	var planted: Dictionary = profile[0].duplicate(true)
	planted["knob"] = {"ult_beats": 3.0}
	_report("Cannon planted world-one knob rejected", not allowed.call(planted, true, []), "world-one knob must remain banned")
	var first_six := profile.slice(0, UpgradeTree.WORLD_ONE_SIZE).map(func(n): return String(n["id"]))
	var cards_ok: bool = first_six.size() == 6 and first_six.all(func(i): return WorldOneCards.has_row(i) and not WorldOneCards.UNFITTED_ROWS.has(i))
	_report("Cannon world-one cards", cards_ok, "%s" % [first_six])
