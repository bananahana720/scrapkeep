extends RefCounted


const PATHS := {
	"rules": "res://src/boss/boss_rules.gd",
	"hazard": "res://src/boss/hazard.gd",
	"wa": "res://src/boss/waking_attacks.gd",
	"waking": "res://src/boss/waking.gd",
	"ma": "res://src/boss/mind_attacks.gd",
	"mind": "res://src/boss/mind.gd",
	"hand": "res://src/combat/mind_hand.gd",
	"wmind": "res://src/combat/warden_mind.gd",
	"posture": "res://src/combat/boss_posture.gd",
	"mini": "res://src/combat/miniboss.gd",
	"rec": "res://src/combat/telegraph_record.gd",
	"events": "res://src/core/event_kinds.gd",
	"roster": "res://src/combat/roster.gd",
	"affix": "res://src/combat/elite_affixes.gd",
	"threat": "res://src/combat/threat_grammar.gd",
	"run": "res://src/core/run_state.gd",
	"class": "res://src/core/class_def.gd",
	"audio": "res://src/presentation/audio.gd",
}

const MOB_TYPE := {
	"chaser": "LANE", "lobber": "PROJECTILE", "plated_brute": "INSTANT", "reactor_relic": "INSTANT", "kite_drone": "INSTANT",
	"swatter": "INSTANT", "drill_crew": "INSTANT", "burrower": "INSTANT", "pit_jaw": "INSTANT", "line_cutter": "PROJECTILE",
	"bola_thrower": "PROJECTILE", "dispatcher": "PROJECTILE", "splitter_pod": "INSTANT", "ballast_heavy": "INSTANT",
	"hooker": "LANE", "mag_trapper": "INSTANT", "netcaster": "INSTANT", "winch_drone": "LANE", "gyro_jammer": "INSTANT",
	"deflector": "LANE", "ramp_flipper": "INSTANT", "catch_trap": "INSTANT", "anchor_crew": "LANE", "gap_net": "LANE",
	"jolt_layer": "INSTANT", "boom_tender": "LANE",
}
const NO_VOICE := ["chaser", "lobber"]
const DIRECTOR_SCALED := ["Mind hand", "Swarm", "Miniboss", "Elite affixes", "Mobs"]
const STAGE_DIALLED := ["Swarm", "Miniboss", "Elite affixes", "Mobs"]
const STAGES := 6

const LETHAL_FLAG := "LETHAL TELL < 0.6 s"
const LETHAL_FLOOR := 0.6
const EPS := 0.000001
const BOSS_GROUPS := ["Brindle", "Waking", "Mind"]
const GROUP_ORDER := ["Brindle", "Waking", "Mind", "Mind hand", "Wardens", "Swarm", "Miniboss", "Elite affixes", "Mobs"]

var problems: Array = []
var _consts := {}
var _scripts := {}
var _sources: Array = []


static func _hz(spec: Array) -> Dictionary:
	return {"tight": [spec, null, null, [["hazard", "MIN_WARN"]]]}


static func rows() -> Array:
	var r: Array = []
	r.append(["Brindle", "crane sweep (phase 1)", _hz(["rules", "CRANE_WARN"]), ["rules", "CRANE_SWEEP"], null, null, "zero",
		{"id": "B01", "type": "WAVE", "event": true}, "Steals a share of mass (STEAL_SHARE, clamped) and tugs; no hull damage. Period CRANE_PERIOD.", {"dial": ["brindle", 1]}])
	r.append(["Brindle", "slag ring (phase 2)", _hz(["rules", "SLAG_WARN"]), ["rules", "SLAG_LIVE"], ["rules", "SLAG_GAP"], ["rules", "QUENCH_SECONDS"], ["rules", "SLAG_DAMAGE"],
		{"id": "B02", "type": "INSTANT", "event": true}, "Punish is the quench the pilot lays (QUENCH_SECONDS), not a boss opening. Recovery is the gap before the next ring.", {"dial": ["brindle", 2]}])
	r.append(["Brindle", "drone pad (phase 2)", _hz(["rules", "DRONE_WARN"]), ["rules", "DRONE_WAIT"], null, null, "zero",
		{"id": "B04", "none": "amber marker is not hostile, so it joins no threat group and plays no threat sound"}, "A marker for the lobber drone's arrival; the drone's shell is the lobber row."])
	r.append(["Brindle", "charge (phase 3)", _hz(["rules", "CHARGE_WARN"]), {"text": "length / %s + 0.2 (geometry)", "args": [["rules", "CHARGE_SPEED"]]}, ["rules", "CHARGE_RECOVER"], ["rules", "WALL_STUN"], ["rules", "CHARGE_DAMAGE"],
		{"id": "B03", "type": "LANE", "event": true}, "Active is travel over the committed length plus 0.2 s (boss.gd _commit_charge). Punish is the wall stun when the nose buries; CHARGE_REST follows.", {"dial": ["brindle", 3]}])
	r.append(["Brindle", "eject (finale)", ["rules", "EJECT_FLIGHT"], null, null, null, "zero",
		{"id": "B05", "none": "published as boss_attack_telegraphed only; no hazard is laid"}, "A 2.5 s arc to the ring then a chase; no direct damage."])
	for family in [["burrow", "BURROW_WARN", "BURROW_LIVE", "LANE", "Seam on adds a second lane"],
			["cave_in", "CAVE_WARN", "CAVE_LIVE", "INSTANT", "three holes, each warning GAP after the last"],
			["bore", "BORE_WARN", "BORE_LIVE", "INSTANT", "the pit adds a spray of lanes"]]:
		var punish = ["waking", "BORE_JAM"] if family[0] == "bore" else null
		r.append(["Waking", "%s (%s)" % [family[0], family[4]], {"tight": [["wa", family[1]], ["wa", "PHASE_TIGHTEN"], ["wa", "TIGHTEN_PHASES"], [["hazard", "MIN_WARN"]]]},
			["wa", family[2]], {"gap": [["waking", "ATTACK_PERIOD"], {"tight": [["wa", family[1]], ["wa", "PHASE_TIGHTEN"], ["wa", "TIGHTEN_PHASES"], [["hazard", "MIN_WARN"]]]}, ["wa", family[2]]]}, punish, ["wa", "DAMAGE", family[0]], {"type": family[3], "event": true},
			"Lands once, only on a ball on the floor. Recovery is the cadence gap (ATTACK_PERIOD minus tell minus active); the pit uses PIT_PERIOD, see cadence_gap_pit_s." + (" Punish is the drill jam (BORE_JAM), which cuts the Waking's plating." if punish != null else ""),
			{"cadence_pit": {"gap": [["waking", "PIT_PERIOD"], {"tight": [["wa", family[1]], ["wa", "PHASE_TIGHTEN"], ["wa", "TIGHTEN_PHASES"], [["hazard", "MIN_WARN"]]]}, ["wa", family[2]]]}}])
	r.append(["Waking", "floor drop", ["waking", "FLOOR_WARN"], null, null, ["waking", "BREACH_WINDOW"], "zero",
		{"none": "waking.gd _warned publishes the event; no hazard node, so no threat group sound"}, "Sinks a tier; no damage. Punish is the breach-slam window after the drop."])
	for family in [["lane", "LANE_WARN", "LANE_LIVE", "LANE"], ["split_lane", "SPLIT_WARN", "SPLIT_LIVE", "LANE"],
			["rush", "RUSH_WARN", "RUSH_LIVE", "INSTANT"], ["plate", "PLATE_WARN", "PLATE_LIVE", "WAVE"]]:
		var punish = ["ma", "PLATE_WINDOW"] if family[0] == "plate" else null
		r.append(["Mind", family[0], {"tight": [["ma", family[1]], ["ma", "PHASE_TIGHTEN"], ["ma", "TIGHTEN_PHASES"], [["ma", "WARN_FLOOR"], ["hazard", "MIN_WARN"]]]},
			["ma", family[2]], {"gap": [["mind", "ATTACK_PERIOD"], {"tight": [["ma", family[1]], ["ma", "PHASE_TIGHTEN"], ["ma", "TIGHTEN_PHASES"], [["ma", "WARN_FLOOR"], ["hazard", "MIN_WARN"]]]}, ["ma", family[2]]]}, punish, ["mind", "ATTACK_DAMAGE"], {"type": family[3], "event": true},
			"Recovery is the cadence gap (ATTACK_PERIOD minus tell minus active)." + (" Punish is the weak window after the plate (PLATE_WINDOW)." if punish != null else "")])
	r.append(["Mind hand", "strike", ["hand", "WARN"], null, ["rec", "RECOVERY"], null, ["hand", "STRIKE_DAMAGE"], {"id": "E18", "type": "LANE", "voice": "counter"}, "A roster enemy the Mind sends from phase 2."])
	for w in [["Reactor Warden pulse", "W01", null, "faction"], ["Hive Warden pulse", "W02", null, "faction"], ["Mind Warden pulse", "W04", ["wmind", "ROWS", "pulse", "recovery"], "none"]]:
		r.append(["Wardens", w[0], ["warden", "PULSE_TELEGRAPH"], null, w[2], ["posture", "STAGGER_SECONDS"], ["warden", "PULSE_DAMAGE"],
			{"id": w[1], "type": "INSTANT", "voice": w[3]}, "Cycle PULSE_CYCLE. Punish is the stagger that opens the core (STAGGER_SECONDS). Damage only inside the core ring (CORE_RADIUS). Only the Mind driver states a pulse recovery."])
	r.append(["Wardens", "meltdown slag lane", ["warden", "SLAG_WARN"], ["warden", "SLAG_SECONDS"], null, null, ["warden", "SLAG_DAMAGE"],
		{"type": "LANE"}, "Damage is per second burned on a grounded ball."])
	r.append(["Wardens", "Mind Warden tilt", ["wmind", "ROWS", "tilt", "charge"], null, ["wmind", "ROWS", "tilt", "recovery"], null, "zero", {"id": "W04", "none": "attack_cue only, no threat node (warden_mind.gd emits attack_cue)"}, "Swings the island; no hit."])
	r.append(["Wardens", "Mind Warden knock-down", ["wmind", "ROWS", "knock_down", "charge"], null, ["wmind", "ROWS", "knock_down", "recovery"], null, "zero", {"id": "W04", "none": "attack_cue only, no threat node (warden_mind.gd emits attack_cue)"}, "The fall; no hit."])
	r.append(["Wardens", "Mind Warden adaptation", null, ["warden", "ADAPT_CYCLE"], null, null, "zero", {"id": "W06", "none": "neutral read: no threat node"}, "A neutral field that moves the open lens every ADAPT_CYCLE; no hit. Active is that cycle."])
	r.append(["Wardens", "caught-pulse crater", null, null, null, null, "zero", {"id": "W07", "none": "ATTACK_ROWS declares no threat: a crater with no advance warning"}, "Reactor Warden aftermath. No script constant gives a crater damage or window, so this row is a placeholder (damage 0); the nearest number is reactor_relic.gd BURN."])
	r.append(["Swarm", "Hive guard dive (formation)", ["swarm", "LOCK_WARN"], ["swarm", "DIVE_TIME"], ["swarm", "REST"], null, ["swarm_remnant", "DIVE_DAMAGE"], {"id": "W03", "type": "LANE", "voice": "remnant"}, "One sting per dive for the whole rack."])
	r.append(["Swarm", "free remnant dive", ["rec", "ROWS", "E17", "pre_shoot"], ["swarm", "DIVE_TIME"], ["rec", "RECOVERY"], null, ["swarm_remnant", "DIVE_DAMAGE"], {"id": "E17", "type": "LANE", "voice": "remnant"}, "The same formation, free of a Warden."])
	r.append(["Miniboss", "leap slam", {"sum": [["mini", "SLAM_CROUCH"], ["mini", "SLAM_LEAP"]]}, null, null, ["mini", "WEAK_SECONDS"], ["mini", "SLAM_DAMAGE"], {"id": "E03", "type": "PROJECTILE", "voice": "none"}, "Tell is crouch plus leap; punish is the weak window after either attack."])
	r.append(["Miniboss", "charge", ["mini", "CHARGE_BRACE"], ["mini", "CHARGE_TIME"], null, ["mini", "WEAK_SECONDS"], ["mini", "CHARGE_DAMAGE"], {"id": "E04", "type": "LANE", "voice": "none"}, ""])
	for id in ["stamp", "rail", "rearblast"]:
		r.append(["Elite affixes", id, ["affix", "ROWS", id, "warn_seconds"], null, ["rec", "RECOVERY"], null, ["affix", "ROWS", id, "damage"], {"elite": id, "owner": "plated_brute"},
			"A plated brute with this attack added; the affix tightens a stat, not the warn."])
	var mobs := [
		["chaser", "E01", "lunge", ["chaser", "LUNGE_TIME"], ["chaser", "DAMAGE"], null, null, "The wind-up is the tell; a hard hit in it breaks the lunge."],
		["lobber", "E02", "shell", null, ["projectile", "DAMAGE"], null, ["lobber", "TELEGRAPH"], "The record's pre_shoot is the shell's flight. The ring commits at release, after the body charge (TELEGRAPH), so sound lags the body's sight."],
		["plated_brute", "E09", "slam", null, ["plated_brute", "SLAM_DAMAGE"], null, null, ""],
		["reactor_relic", "E16", "eruption", null, ["reactor_relic", "ERUPT_DAMAGE"], null, null, ""],
		["kite_drone", "E24", "dive", ["kite_drone", "DIVE"], ["kite_drone", "DIVE_DAMAGE"], null, null, ""],
		["swatter", "E13", "swing", null, "zero", null, null, "The paddle never damages; it knocks."],
		["drill_crew", "E20", "breach", null, ["drill_crew", "BORE_DAMAGE"], null, null, ""],
		["burrower", "E19", "burst", null, ["burrower", "BURST_DAMAGE"], null, null, ""],
		["pit_jaw", "E30", "bite", null, ["pit_jaw", "BITE_DAMAGE"], null, null, "A hold; the bite is the damage."],
		["line_cutter", "E22", "throw", null, ["line_cutter", "LANDING_DAMAGE"], ["line_cutter", "FLIGHT"], null, "Ring commits at the start of the cock and stands through the flight (record pre_shoot plus FLIGHT); a rebite adds a sting (STING)."],
		["bola_thrower", "E08", "bola", null, ["bola_thrower", "STING"], ["bola_thrower", "FLIGHT"], null, "Ring commits at the start of the whirl and stands through the flight (record pre_shoot plus FLIGHT); the sting is the wrap's damage."],
		["dispatcher", "E26", "tube drop", null, ["dispatcher", "DROP_DAMAGE"], null, null, ""],
		["splitter_pod", "E25", "fuse blast", ["splitter_pod", "FUSE"], ["splitter_pod", "BLAST_DAMAGE"], null, null, ""],
		["prop_crew", "E31", "roof drop", null, ["prop_crew", "ROOF_BALL_DAMAGE"], null, null, "Player-started; ROOF_DAMAGE hurts enemies, ROOF_BALL_DAMAGE the pilot."],
		["ballast_heavy", "E32", "brace slam", null, ["ballast_heavy", "SLAM_DAMAGE"], null, null, ""],
		["hooker", "E06", "harpoon", null, "zero", null, null, "A hold: it reels the ball; no direct damage."],
		["mag_trapper", "E05", "pit", null, "zero", null, null, "A hold: it pulls to the centre; no direct damage."],
		["netcaster", "E07", "air net", null, "zero", null, null, "A hold: it pins in the air; no direct damage."],
		["winch_drone", "E11", "pull", null, "zero", null, null, "A hold: it winches the ball; no direct damage."],
		["gyro_jammer", "E12", "field", null, "zero", null, null, "A field that jams steering; no direct damage."],
		["deflector", "E10", "brace", null, "zero", null, null, "Turns the ball at restitution; no direct damage."],
		["ramp_flipper", "E14", "flip", null, "zero", null, null, "Flings the ball; no direct damage."],
		["catch_trap", "E15", "cup", null, "zero", null, null, "A hold; no direct damage."],
		["lamp_swarm", "E21", "lure bloom", null, "zero", null, null, "A lure that pulls the ball; no direct damage."],
		["anchor_crew", "E23", "winch", null, "zero", null, null, "A hold: it winches the ball; no direct damage."],
		["gap_net", "E33", "net charge", null, "zero", null, null, "A net that holds; no direct damage."],
		["jolt_layer", "E27", "mat", null, "zero", null, null, "A static jam field; no direct damage."],
		["boom_tender", "E40", "boom sweep", null, ["boom_tender", "STING_DAMAGE"], null, null, "A hold: the pin stings once; a FAST ball pops the floats instead."],
		["linker", "", "link", null, "zero", null, null, "No attack row and no telegraph: a cable relay with no direct damage."],
		["foreman", "", "wipe horn", null, "zero", null, null, "No attack row: a horn that wipes the field on the beat; no direct damage."],
	]
	for m in mobs:
		var id: String = m[1]
		var tell = null
		var recovery = null
		var extra := {}
		var sound: Dictionary = {"none": "no attack row, so no threat is declared"}
		if id != "":
			tell = ["rec", "ROWS", id, "pre_shoot"]
			extra = {"cooldown": ["rec", "ROWS", id, "cooldown"]}
			if m[5] != null:
				extra["wind_up"] = tell
				tell = {"sum": [tell, m[5]]}
			recovery = ["rec", "RECOVERY"]
			sound = {"id": id, "voice": "none" if m[0] in NO_VOICE else "counter", "owner": m[0]}
			if MOB_TYPE.has(m[0]):
				sound["type"] = MOB_TYPE[m[0]]
			if m[6] != null:
				sound["lag"] = m[6]
		r.append(["Mobs", "%s %s" % [m[0], m[2]], tell, m[3], recovery, null, m[4], sound, m[7], extra])
	return r


func _path(key: String) -> String:
	return String(PATHS[key]) if PATHS.has(key) else "res://src/combat/%s.gd" % key


func _constants(path: String) -> Dictionary:
	if _consts.has(path):
		return _consts[path]
	var script = load(path)
	var map := {}
	if script == null:
		problems.append("cannot load %s" % path)
	else:
		_scripts[path] = script
		map = script.get_script_constant_map()
	_consts[path] = map
	return map


func _short(path: String) -> String:
	return path.trim_prefix("res://src/")


func value(spec) -> float:
	if spec == null:
		return NAN
	if spec is Dictionary:
		if spec.has("sum"):
			var total := 0.0
			for part in spec["sum"]:
				total += value(part)
			return total
		if spec.has("gap"):
			var g: Array = spec["gap"]
			return value(g[0]) - value(g[1]) - value(g[2])
		if spec.has("text"):
			for a in spec["args"]:
				value(a)
			return NAN
		if spec.has("tight"):
			var t: Array = spec["tight"]
			var base := value(t[0])
			var tightened := base
			if t[1] != null and t[2] != null:
				tightened = base - value(t[1]) * (value(t[2]) - 1.0)
			for floor_spec in t[3]:
				tightened = maxf(tightened, value(floor_spec))
			return tightened
		problems.append("unknown value spec %s" % str(spec))
		return NAN
	var key := String(spec[0])
	var path := _path(key)
	var cell = _constants(path).get(spec[1], null)
	var label := "%s:%s" % [_short(path), spec[1]]
	if cell == null:
		problems.append("missing constant %s" % label)
		return NAN
	for i in range(2, spec.size()):
		label += ".%s" % str(spec[i])
		if cell is Dictionary and cell.has(spec[i]):
			cell = cell[spec[i]]
		elif cell is Array and int(spec[i]) < cell.size():
			cell = cell[int(spec[i])]
		else:
			problems.append("missing key %s" % label)
			return NAN
	if not (cell is float or cell is int):
		problems.append("not a number: %s" % label)
		return NAN
	if not _sources.has(label):
		_sources.append(label)
	return float(cell)


func _collect(spec, into: Array) -> void:
	if spec == null or spec is String:
		return
	if spec is Dictionary:
		var parts: Array = spec.get("sum", spec.get("gap", spec.get("args", [])))
		if spec.has("tight"):
			parts = [spec["tight"][0], spec["tight"][1], spec["tight"][2]] + spec["tight"][3]
		for p in parts:
			_collect(p, into)
		return
	var label := "%s:%s" % [_short(_path(String(spec[0]))), spec[1]]
	for i in range(2, spec.size()):
		label += ".%s" % str(spec[i])
	if not into.has(label):
		into.append(label)


func hulls() -> Dictionary:
	var script = load(_path("class"))
	var out := {"min": INF, "max": 0.0, "min_id": "", "max_id": ""}
	if script == null:
		problems.append("cannot load class_def.gd")
		return out
	for def in script.all():
		var hp := float(def.base_hp)
		if hp < out["min"]:
			out["min"] = hp
			out["min_id"] = String(def.id)
		if hp > out["max"]:
			out["max"] = hp
			out["max_id"] = String(def.id)
	return out


func header() -> Dictionary:
	var run := _constants(_path("run"))
	var h := hulls()
	var tier := _constants("res://src/core/run_tier.gd")
	if not tier.has("DAMAGE_DIAL_CAP"):
		problems.append("missing constant core/run_tier.gd:DAMAGE_DIAL_CAP")
	var need := ["SCRAP_PER_HP", "REGEN_DELAY", "REGEN_RATE", "MAX_HP", "SPILL_SHARE"]
	for n in need:
		if not run.has(n):
			problems.append("missing constant run_state.gd:%s" % n)
	var audio := FileAccess.get_file_as_string(_path("audio"))
	var checks := {
		"declare_frame": audio.contains("_warn_threat.call_deferred(node)") and audio.contains("warns on the game frame it is declared"),
		"telegraph_unquantized": audio.contains("Danger is never quantized: the telegraph sounds the frame the boss winds up"),
		"atk_cues_played": audio.contains("attack_warn_cue"),
	}
	if not checks["declare_frame"]:
		problems.append("audio.gd no longer warns a threat on its declaring frame (_warn_threat); the sound column is stale")
	if not checks["telegraph_unquantized"]:
		problems.append("audio.gd _on_boss_telegraph no longer plays unquantized; the sound column is stale")
	return {"hull_min": h["min"], "hull_min_id": h["min_id"], "hull_max": h["max"], "hull_max_id": h["max_id"],
		"scrap_per_hp": run.get("SCRAP_PER_HP", NAN), "spill_share": run.get("SPILL_SHARE", NAN),
		"damage_dial_cap": tier.get("DAMAGE_DIAL_CAP", NAN), "regen_delay": run.get("REGEN_DELAY", NAN), "regen_rate": run.get("REGEN_RATE", NAN), "run_max_hp": run.get("MAX_HP", NAN),
		"audio": checks}


func _threat_sound(kind: String) -> String:
	var rows: Dictionary = _constants(_path("events")).get("THREAT_ROWS", {})
	var snd := String(rows.get(kind, {}).get("sound", ""))
	if snd == "":
		problems.append("no THREAT_ROWS sound for threat kind '%s'" % kind)
	return snd


func _kind_of_type(type_name: String) -> String:
	var kinds: Array = _constants(_path("threat")).get("KINDS", [])
	var types: Dictionary = _constants(_path("threat")).get("Type", {})
	if not types.has(type_name):
		problems.append("unknown Threat.Type %s" % type_name)
		return ""
	var i := int(types[type_name])
	if i < 0 or i >= kinds.size():
		problems.append("threat_grammar.gd KINDS has no entry %d for Type.%s" % [i, type_name])
		return ""
	return String(kinds[i])


func sound(spec: Dictionary) -> Dictionary:
	var arow: Dictionary = {}
	var notices: Array = []
	if spec.has("id"):
		arow = _constants(_path("events")).get("ATTACK_ROWS", {}).get(spec["id"], {})
		if arow.is_empty():
			problems.append("missing ATTACK_ROWS %s" % spec["id"])
	var declared := String(arow.get("threat", ""))
	if spec.has("none"):
		return {"text": "none", "sync": "n/a", "detail": String(spec["none"]), "notices": notices}
	var kind := ""
	var unverified := false
	var layers: Array = []
	if spec.has("elite"):
		var erow: Dictionary = _constants(_path("affix")).get("ROWS", {}).get(spec["elite"], {})
		if erow.is_empty():
			problems.append("missing elite row %s" % spec["elite"])
			return {"text": "?", "sync": "?", "detail": "", "notices": notices}
		var tkinds: Array = _constants(_path("threat")).get("KINDS", [])
		var ti := int(erow["telegraph"])
		if ti < 0 or ti >= tkinds.size():
			problems.append("threat_grammar.gd KINDS has no entry %d (elite %s)" % [ti, spec["elite"]])
			return {"text": "?", "sync": "?", "detail": "", "notices": notices}
		kind = String(tkinds[ti])
		layers = [_counter_voice(String(spec["owner"])), String(erow.get("mechanic_tag", ""))]
	elif spec.has("type"):
		kind = _kind_of_type(String(spec["type"]))
		if declared != "" and kind != "" and kind != declared:
			notices.append("committed %s but ATTACK_ROWS %s declares %s" % [kind, spec["id"], declared])
	else:
		kind = declared
		unverified = true
	match String(spec.get("voice", "none")):
		"counter":
			var owner := String(spec.get("owner", arow.get("owner", "")))
			layers = _counter_layers(owner)
		"remnant":
			layers = _counter_layers("swarm_remnant")
		"faction":
			var factions: Dictionary = _constants(_path("roster")).get("FACTIONS", {})
			if not factions.has(arow.get("owner", "")):
				problems.append("no faction '%s' for voice of %s" % [arow.get("owner", ""), spec.get("id", "")])
			else:
				layers = [_voiced(String(factions[arow["owner"]].get("voice", "")))]
	var parts: Array = []
	if kind != "":
		parts.append(_threat_sound(kind))
	for l in layers:
		if String(l) != "" and not parts.has(String(l)):
			parts.append(String(l))
	if spec.get("event", false):
		parts.append("boss_attack_telegraphed")
	if parts.is_empty():
		return {"text": "none", "sync": "n/a", "detail": "the attack declares no threat", "notices": notices}
	var sync := "declare frame"
	var lag := NAN
	if spec.has("lag"):
		lag = value(spec["lag"])
		sync = "lags body wind-up %.2f s" % lag
	var text := "+".join(parts)
	if unverified:
		text += " [declared kind, unverified]"
	return {"text": text, "sync": sync, "lag": lag, "detail": "threat kind %s" % kind, "notices": notices}


func _voiced(id: String) -> String:
	return "mind_<motif>" if id == "mind_quote" else id


func _counter_voice(owner: String) -> String:
	var roster = load(_path("roster"))
	var row: Dictionary = roster.row(owner) if roster != null else {}
	var factions: Dictionary = _constants(_path("roster")).get("FACTIONS", {})
	if row.is_empty() or not factions.has(row.get("faction", "")):
		problems.append("no roster row or faction voice for '%s'" % owner)
		return ""
	return _voiced(String(factions[row["faction"]].get("voice", "")))


func _counter_layers(owner: String) -> Array:
	var roster = load(_path("roster"))
	var row: Dictionary = roster.row(owner) if roster != null else {}
	if row.is_empty():
		problems.append("no roster row for '%s'" % owner)
		return []
	return [_counter_voice(owner), _voiced(String(row.get("tag", "")))]


func build() -> Dictionary:
	problems.clear()
	_sources.clear()
	var head := header()
	var out_rows: Array = []
	for r in rows():
		var tell := value(r[2])
		var active := value(r[3])
		var recovery := value(r[4])
		var punish := value(r[5])
		var damage := 0.0 if r[6] is String else value(r[6])
		var snd := sound(r[7])
		var extra: Dictionary = r[9] if r.size() > 9 else {}
		var base_tell := tell
		var base_damage := damage
		if extra.has("dial"):
			var boss := String(extra["dial"][0])
			if not is_nan(tell):
				tell = ChallengeDials.tell(boss, tell, value(["hazard", "MIN_WARN"]))
			if damage > 0.0:
				damage = ChallengeDials.damage(boss, damage, int(extra["dial"][1]))
		var refs: Array = []
		for i in range(2, 7):
			if not (r[i] is String):
				_collect(r[i], refs)
		var flags: Array = []
		if damage > 0.0 and not is_nan(tell) and tell < LETHAL_FLOOR - EPS:
			flags.append(LETHAL_FLAG)
		if damage > 0.0 and is_nan(tell):
			flags.append("NO TELL DATA")
		var lag := float(snd.get("lag", NAN))
		var row := {
			"group": r[0], "attack": r[1],
			"tell_s": _num(tell), "active_s": _num(active), "recovery_s": _num(recovery), "punish_s": _num(punish),
			"damage": damage, "tell_base_s": _num(base_tell), "damage_base": base_damage,
			"pct_hull_min": _num(damage / head["hull_max"] * 100.0) if damage > 0.0 else 0.0,
			"pct_hull_max": _num(damage / head["hull_min"] * 100.0) if damage > 0.0 else 0.0,
			"hits_to_kill": int(ceil(head["hull_min"] / damage - EPS)) if damage > 0.0 else null,
			"sound": snd["text"], "sound_sync": snd["sync"], "sound_lag_s": _num(lag),
			"sound_detail": snd["detail"],
			"source": ", ".join(refs), "flags": flags, "note": r[8],
		}
		var notices: Array = []
		if damage > 0.0 and STAGE_DIALLED.has(r[0]):
			var by_stage := {}
			for stage in range(1, STAGES + 1):
				var mult := ChallengeDials.stage_mult("mobs.damage", stage)
				if absf(mult - 1.0) <= EPS:
					continue
				var hit := damage * mult
				by_stage[str(stage)] = {"mult": _num(mult), "damage": _num(hit), "pct_hull_max": _num(hit / head["hull_min"] * 100.0),
					"hits_to_kill": int(ceil(head["hull_min"] / hit - EPS))}
				notices.append("stage %d (mobs.damage x%s): %s damage, %s%% of the smallest hull, %d hits to kill" % [
					stage, _fmt(mult, 2), _fmt(hit, 1), _fmt(hit / head["hull_min"] * 100.0, 1), int(ceil(head["hull_min"] / hit - EPS))])
			if not by_stage.is_empty():
				row["stage_damage"] = by_stage
		if extra.has("cooldown"):
			row["cooldown_s"] = _num(value(extra["cooldown"]))
			_collect(extra["cooldown"], refs)
			row["source"] = ", ".join(refs)
		if extra.has("wind_up"):
			var wind_up := value(extra["wind_up"])
			row["wind_up_s"] = _num(wind_up)
			if damage > 0.0 and wind_up < LETHAL_FLOOR - EPS:
				notices.append("wind-up alone %s s is under %s s; the committed ring stands %s s" % [_fmt(wind_up), _fmt(LETHAL_FLOOR, 1), _fmt(tell)])
		for n in snd.get("notices", []):
			notices.append(n)
		row["notices"] = notices
		if r[7].has("id"):
			row["attack_id"] = r[7]["id"]
		if r[3] is Dictionary and r[3].has("text"):
			var shown: Array = []
			for a in r[3]["args"]:
				shown.append(_fmt(value(a)))
			row["active_text"] = String(r[3]["text"]) % shown
		if r[4] is Dictionary and r[4].has("gap"):
			row["recovery_kind"] = "cadence gap"
		if extra.has("cadence_pit"):
			row["cadence_gap_pit_s"] = _num(value(extra["cadence_pit"]))
			_collect(extra["cadence_pit"], refs)
			row["source"] = ", ".join(refs)
		row["director_scaled"] = DIRECTOR_SCALED.has(r[0])
		out_rows.append(row)
	return {"header": head, "rows": out_rows, "problems": problems.duplicate()}


static func _num(v: float):
	return null if is_nan(v) else snappedf(v, 0.0001)


static func _fmt(v, digits := 2) -> String:
	if v == null:
		return "-"
	return ("%." + str(digits) + "f") % float(v)


static func markdown(sheet: Dictionary) -> String:
	var h: Dictionary = sheet["header"]
	var lines: Array = []
	lines.append("# Attack sheets")
	lines.append("")
	lines.append("Generated by `sketches/core-loop/tools/attack_sheet.gd` from the game's own scripts. Do not edit by hand; rerun the tool.")
	lines.append("")
	lines.append("- Hull: smallest base hull %s (%s), largest %s (%s), from `class_def.gd` base_hp. Run baseline `run_state.gd` MAX_HP %s." % [
		_fmt(h["hull_min"], 0), h["hull_min_id"], _fmt(h["hull_max"], 0), h["hull_max_id"], _fmt(h["run_max_hp"], 0)])
	lines.append("- Scrap armour: %s scrap absorbs 1 HP (`run_state.gd` SCRAP_PER_HP); %s of removed scrap spills (SPILL_SHARE). The shares below ignore scrap armour." % [
		_fmt(h["scrap_per_hp"], 0), _fmt(h["spill_share"], 2)])
	lines.append("- Tier: the shares are base tier. Enemy hits (rows marked in the JSON `director_scaled`: Mind hand, Swarm, Miniboss, Elite affixes, Mobs) are multiplied by `director.damage_scale()` (combat.gd `_on_player_hit`) up to x%s (`run_tier.gd` DAMAGE_DIAL_CAP) on the hardest dial; boss hazard damage (Brindle, Waking, Mind) and Warden hits are unscaled by it. HARD ladder rungs 2 to 5 multiply mob hits, Brindle's damage and the Warden pulse further (`run_tier.gd` LADDER, through `challenge_dials.gd`)." % _fmt(h["damage_dial_cap"], 2))
	lines.append("- Regen: %s HP/s after %s s without damage (`run_state.gd` REGEN_RATE, REGEN_DELAY). Hits to kill ignore regen." % [_fmt(h["regen_rate"], 0), _fmt(h["regen_delay"], 1)])
	lines.append("- Tell is the tightest reachable: phase tightening applied (minus step per phase, capped at the family's TIGHTEN_PHASES) and clamped to hazard.gd MIN_WARN and mind_attacks.gd WARN_FLOOR.")
	lines.append("- Sound: `audio.gd` `_warn_threat` plays a threat's type sound (threat_tick instant, threat_whoosh wave, threat_whistle projectile, threat_hum lane) and the owner voice and mechanic tag on the game frame the threat is declared, not on the beat; a lane's hum holds until it goes live, where threat_tear plays; `boss_attack_telegraphed` is unquantized too. Sync says whether sound starts with the tell or later. The reserved `atk_*_warn` cues are %s." % (
		"played" if h["audio"]["atk_cues_played"] else "not played by audio.gd yet, so they are not in the sound column"))
	lines.append("- Stage dials: the tables show base hits. Swarm, Miniboss, Elite affixes and Mobs hits also take the mob dial (`mobs.damage_mult` x `mobs.damage_by_stage`, `challenge_dials.gd`); a stage whose dial is not 1 is listed under Notices with its own damage, share and hit count.")
	lines.append("- Rule (DECISIONS section 5): every lethal attack has a readable tell of at least %s s, for sight and sound. Rows with damage above 0 and a tightest tell under it carry `%s`." % [_fmt(LETHAL_FLOOR, 1), LETHAL_FLAG])
	var flagged: Array = []
	for row in sheet["rows"]:
		if not row["flags"].is_empty():
			flagged.append(row)
	lines.append("")
	lines.append("## Flagged rows (%d)" % flagged.size())
	lines.append("")
	if flagged.is_empty():
		lines.append("None.")
	for row in flagged:
		lines.append("- %s / %s: tell %s s, damage %s: %s" % [row["group"], row["attack"], _fmt(row["tell_s"]), _fmt(row["damage"], 0), ", ".join(row["flags"])])
	lines.append("")
	lines.append("Notices (not flags):")
	var any_notice := false
	for row in sheet["rows"]:
		for n in row.get("notices", []):
			lines.append("- %s / %s: %s" % [row["group"], row["attack"], n])
			any_notice = true
	if not any_notice:
		lines.append("- None.")
	for group in GROUP_ORDER:
		var in_group: Array = sheet["rows"].filter(func(x): return x["group"] == group)
		if in_group.is_empty():
			continue
		lines.append("")
		lines.append("## %s" % group)
		lines.append("")
		lines.append("| attack | tell s | active s | recovery s | punish s | damage | % hull min | % hull max | hits to kill | sound | sync | source | flag |")
		lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
		for row in in_group:
			lines.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [
				("[%s] " % row["attack_id"] if row.has("attack_id") else "") + row["attack"], _fmt(row["tell_s"]), String(row["active_text"]) if row.has("active_text") else _fmt(row["active_s"]),
				_fmt(row["recovery_s"]) + (" (%s)" % row["recovery_kind"] if row.has("recovery_kind") and row["recovery_s"] != null else ""), _fmt(row["punish_s"]), _fmt(row["damage"], 0),
				_fmt(row["pct_hull_min"], 1) if row["damage"] > 0.0 else "-", _fmt(row["pct_hull_max"], 1) if row["damage"] > 0.0 else "-",
				str(row["hits_to_kill"]) if row["hits_to_kill"] != null else "-", row["sound"], row["sound_sync"], row["source"], ", ".join(row["flags"])])
		lines.append("")
		for row in in_group:
			if row.has("cadence_gap_pit_s"):
				lines.append("- %s: in the pit the cadence gap is %s s (PIT_PERIOD)." % [row["attack"], _fmt(row["cadence_gap_pit_s"])])
			if String(row["note"]) != "" or String(row["sound_detail"]) != "":
				lines.append("- %s: %s %s" % [row["attack"], row["note"], ("Sound: " + row["sound_detail"] + ".") if row["sound"] == "none" else ""])
	if not sheet["problems"].is_empty():
		lines.append("")
		lines.append("## Problems")
		lines.append("")
		for p in sheet["problems"]:
			lines.append("- %s" % p)
	lines.append("")
	return "\n".join(lines)


func write(dir: String) -> Dictionary:
	var sheet := build()
	DirAccess.make_dir_recursive_absolute(dir)
	var md := FileAccess.open(dir.path_join("attack-sheet.md"), FileAccess.WRITE)
	if md != null:
		md.store_string(markdown(sheet))
	else:
		sheet["problems"].append("cannot write %s" % dir.path_join("attack-sheet.md"))
	var js := FileAccess.open(dir.path_join("attack-sheet.json"), FileAccess.WRITE)
	if js != null:
		js.store_string(JSON.stringify(sheet, "  ", false))
	else:
		sheet["problems"].append("cannot write %s" % dir.path_join("attack-sheet.json"))
	return sheet
