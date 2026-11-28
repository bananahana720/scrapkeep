extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const Juice := preload("res://src/presentation/juice.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")
const HitStopBudget := preload("res://src/core/hit_stop_budget.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const Fx := preload("res://src/presentation/fx_library.gd")
const Events := preload("res://src/core/game_events.gd")
const Windup := preload("res://src/presentation/windup_rows.gd")
const Posture := preload("res://src/core/boss_posture.gd")
const Audio := preload("res://src/presentation/audio.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Palette := preload("res://src/core/palette.gd")
const CLASSES := ["none", "hit", "heavy", "massive", "climax"]
const FIELDS := ["stop_ms", "shake", "kick", "punch_fov", "fx_scale", "body", "body_st"]
const EXPECTED_CHECKS := 36
# The shared slam's body floor: 967af1e4's band held it within 3 dB of the slam_boom recipe
# (rms -10.97 dB), so about -13.97; fixed here on 2026-10-17 when slam_boom became a file.
const SLAM_RMS_FLOOR_DB := -14.0
const OWNER := {
	"enemy_struck": "neutral", "enemy_killed": "neutral", "gauge_released": "neutral",
	"posture_changed": "neutral", "posture_break": "neutral", "ultimate_landed": "neutral",
	"boss_defeated": "neutral", "boss_weak_point_hit": "neutral", "slammed": "neutral",
	"sticky_detonated": "demolitions_caster", "enemy_rebounded": "neutral",
	"cloak_broken": "demolitions_caster", "hold_broken": "neutral", "swarm_scattered": "neutral",
	"enemy_pinned": "neutral", "enemy_ringed_out": "neutral", "arc_slammed": "pylon_engineer", "skid_smashed": "runner_gunner",
	"demo_slammed": "demolitions_caster", "cloak_started": "demolitions_caster", "cc_ignored": "runner_gunner",
}
const SAME_FRAME_PAIRS := [
	["slammed", "arc_slammed"], ["slammed", "skid_smashed"],
	["slammed", "demo_slammed"], ["slammed", "ultimate_landed"],
	["enemy_struck", "enemy_killed"],
	["slammed", "harpoon_smashed"], ["slammed", "line:smash_lands"],
	["ultimate_landed", "vault_kill"],
	["arc_slammed", "line:smash_lands"], ["skid_smashed", "line:smash_lands"],
	["demo_slammed", "line:smash_lands"],
]

class AudioCtx:
	extends RefCounted
	var events: Node
	var player = null
	var run = null
	var flow = null
	var spawner = null
	var calm := false

var event_script: Script = Rows
var _measure_cache := {}
const PRESENTATION := ["juice", "vfx", "audio"]
const RULES := ["strike", "death_parts", "amount", "gauge", "posture"]


func run(t) -> void:
	var before: int = t.checks
	var constants: Dictionary = event_script.get_script_constant_map()
	var present := constants.has("WEIGHT") and constants.has("WEIGHTED") and constants.has("WEIGHT_EXEMPT") and event_script.has_method("weigh")
	t.check("weight contract present", present, "WEIGHT, WEIGHTED, WEIGHT_EXEMPT and weigh required")
	if not present:
		t.eq("weight case check count", t.checks - before + 1, EXPECTED_CHECKS)
		return
	var weights: Dictionary = constants.WEIGHT
	var facts: Dictionary = constants.WEIGHTED
	var exemptions: Dictionary = constants.WEIGHT_EXEMPT
	t.eq("exact weight classes", _sorted(weights.keys()), _sorted(CLASSES))
	var bad_fields := []
	for key in weights:
		if FIELDS.any(func(field): return not weights[key].has(field)):
			bad_fields.append(key)
	t.eq("weight fields", bad_fields, [])
	var band_ok: bool = weights.hit.stop_ms == "hit" and weights.heavy.stop_ms == "heavy"
	for damage in [0.0, 10.0, 30.0, 60.0]:
		band_ok = band_ok and is_equal_approx(_record("hit", damage).stop_ms, EventJuice.stop_ms_for(damage))
		band_ok = band_ok and is_equal_approx(_record("heavy", damage).stop_ms, EventJuice.stop_ms_for(damage, false, true))
	t.check("stops resolve through EventJuice", band_ok, "hit and heavy delegate at damage 0, 10, 30, 60")
	t.check("strict stop order", _stop_order(weights), "none < hit < heavy < massive < climax <= 60")
	t.check("strict shake order", _scalar_order(weights, "shake", Juice.SHAKE_CAP), "none through climax within SHAKE_CAP")
	t.check("strict fx order", _scalar_order(weights, "fx_scale"), "fx_scale increases through all five classes")
	t.check("body presence and bake", _bodies(weights), "none/hit empty; heavy/massive/climax bake nonempty samples")
	var measurements := _body_measurements(weights)
	t.check("baked register and length order", _body_order(measurements), str(measurements))
	var db_ok := true
	for key in CLASSES:
		db_ok = db_ok and _record(key).get("body_db", -1.0) == 0.0 and is_equal_approx(_record(key).body_ratio, pow(2.0, float(weights[key].body_st) / 12.0))
	t.check("body layers use db zero", db_ok, "bank priority trims remain in charge")
	var bad := coverage(facts, weights)
	t.eq("weighted coverage", bad, [])
	var sound_drift := []
	for fact in facts:
		var record: Dictionary = event_script.call("weigh", fact, {})
		if facts[fact].has("sound") or record.sound != Rows.sound(fact):
			sound_drift.append(fact)
	t.eq("weighted sound matches Rows", sound_drift, [])
	var release_drift := []
	var releases := {"kest": ["kest_low_thump"], "rivet": ["rivet_hihat_roll"]}
	for motif in releases:
		if Rows.releases(motif) != releases[motif]:
			release_drift.append([motif, Rows.releases(motif)])
	t.eq("pilot release candidates exclude primary cues", release_drift, [])
	t.eq("player weighted owner coverage", facts.keys().filter(func(fact): return facts[fact].allegiance == "player" and not OWNER.has(fact)), [])
	var identity := _identity_errors(facts)
	t.eq("player cue hostile identity", identity.hostile, [])
	t.eq("player cue class identity", identity.voiced, [])
	var audibility := _audibility_errors(facts)
	t.eq("massive and climax cue audibility", audibility.weight, [])
	t.eq("player cue onset at most 20 ms", audibility.onset, [])
	t.eq("trimmed cue peak ceiling", audibility.ceiling, [])
	var listeners := connected_signals()
	var uncovered := uncovered_listeners(listeners, facts, exemptions)
	t.eq("presentation listener coverage", uncovered, [])
	t.eq("grammar has no presentation listener", EventKinds.GRAMMAR_SIGNALS.filter(func(fact): return fact in listeners), [])
	var planted := facts.duplicate(true)
	planted["planted_impact"] = {"class": "none", "allegiance": "player", "visual": ""}
	t.eq("coverage positive control", coverage(planted, weights), ["planted_impact"])
	var swapped := weights.duplicate(true)
	swapped.heavy = weights.massive
	swapped.massive = weights.heavy
	t.check("order positive control", not _stop_order(swapped) and not _scalar_order(swapped, "shake"), "swapping heavy and massive fails")
	var hostile_ok: bool = facts.get("player_hit", {}).get("allegiance") == "hostile" and facts.get("player_died", {}).get("allegiance") == "hostile"
	for fact in facts:
		if facts[fact].allegiance == "hostile" or fact in ["player_hit", "player_died"]:
			for strength in [0.0, 0.5, 1.0]:
				var record: Dictionary = event_script.call("weigh", fact, {"strength": strength, "amount": 24.0})
				hostile_ok = hostile_ok and record.allegiance == "hostile" and record.stop_ms == 0.0 and record.shake == 0.0 and record.kick == 0.0
	t.check("hostile clamp", hostile_ok, "every hostile at strengths 0, 0.5, 1; player damage cannot become player allegiance")
	var no_stop := true
	for fact in facts:
		if facts[fact].allegiance in ["motion", "reward"]:
			for strength in [0.0, 0.5, 1.0]:
				no_stop = no_stop and event_script.call("weigh", fact, {"strength": strength}).stop_ms == 0.0
	for fact in ["landed", "beacon_unsealed"]:
		no_stop = no_stop and event_script.call("weigh", fact, {}).stop_ms == 0.0
	t.check("motion and reward stop clamp", no_stop, "motion and rewards never freeze")
	var audio_script: Script = Audio
	var audio_constants := audio_script.get_script_constant_map()
	t.check("vault kill cue constant", audio_constants.has("VAULT_KILL_SOUND") and Bank.has_recipe(String(audio_constants.get("VAULT_KILL_SOUND", ""))), "audio.gd owns the vault kill cue")
	t.eq("same frame sound collision", _same_frame_collisions(), [])
	t.check("same frame collision planted control", not _same_frame_collisions({"slammed": "smash_crack"}).is_empty(), "slammed bound to smash_crack collides with the harpoon crack")
	var frame := _harpoon_smash_frame()
	t.check("harpoon smash frame cues", frame.ok, str(frame))
	var shared_slam := _measure(Rows.sound("slammed"))
	var kest_slam := _measure("slam_boom")
	# 2026-10-17 SOUND-INT: slam_boom is now the event-set file (rms -15.3 dB), not the recipe
	# 967af1e4 wrote this check against (rms -11.0 dB, so a floor of about -14 dB). The shared
	# slam is held to that fixed floor (SLAM_RMS_FLOOR_DB), not to the file, so re-rendering
	# slam_boom cannot loosen it, and a heavier shared slam (added layers) passes.
	t.check("shared slam acoustic weight", _slam_weight_ok(shared_slam), str([shared_slam, kest_slam]))
	var light_body := shared_slam.duplicate()
	light_body.rms_db = _measure("ui_tick").get("rms_db", 0.0)
	t.check("shared slam weight planted light control", not _slam_weight_ok(_measure("ui_tick")) and not _slam_weight_ok(light_body), "a tick, or the slam's peak with a tick's body, fails")
	var ultimate: Dictionary = event_script.call("weigh", "ultimate_landed", {})
	var slam_cue := _measure(Rows.sound("slammed"))
	var ultimate_cue := _measure(ultimate.sound)
	t.check("ultimate cue lower and longer than heavy slam", not ultimate_cue.is_empty() and not slam_cue.is_empty() and ultimate_cue.zcr < slam_cue.zcr and ultimate_cue.seconds >= slam_cue.seconds, str([slam_cue, ultimate_cue]))
	t.eq("class rule boundaries", _rule_errors(), [])
	var bounded := true
	for strength in [-1.0, 0.0, 0.5, 1.0, 2.0]:
		var record: Dictionary = event_script.call("weigh", "slammed", {"strength": strength})
		bounded = bounded and is_equal_approx(record.strength, clampf(strength, 0.0, 1.0))
	t.check("strength bounded", bounded, "explicit strength clamps to 0..1")
	var args := {"kind": "ram", "damage": 30.0, "strength": 0.5}
	var snapshot := args.duplicate(true)
	var first: Dictionary = event_script.call("weigh", "enemy_struck", args)
	first.shake = 999.0
	t.check("weigh is pure", args == snapshot and event_script.call("weigh", "enemy_struck", args).shake != 999.0, "arguments and shared rows remain unchanged")
	t.eq("weight case check count", t.checks - before + 1, EXPECTED_CHECKS)


func _frame_ids(fact: String, overrides: Dictionary) -> Array:
	if fact == "vault_kill":
		return [Rows.sound("enemy_killed"), Audio.VAULT_KILL_SOUND]
	if fact == "line:smash_lands":
		return [EventKinds.line_sound("smash_lands"), "smash_crack"]
	if fact == "harpoon_smashed":
		return [Rows.sound(fact), "smash_crack"]
	var record: Dictionary = event_script.call("weigh", fact, {})
	if overrides.has(fact):
		record.sound = overrides[fact]
	return _bank_ids(record)


func _same_frame_collisions(overrides := {}) -> Array:
	var collisions := []
	for pair in SAME_FRAME_PAIRS:
		var right := _frame_ids(pair[1], overrides)
		var shared := _frame_ids(pair[0], overrides).filter(func(id): return id in right)
		if not shared.is_empty():
			collisions.append([pair[0], pair[1], shared])
	return collisions


func _harpoon_smash_frame() -> Dictionary:
	var events := Events.new()
	var ctx := AudioCtx.new()
	ctx.events = events
	var audio := Audio.new()
	audio.setup(ctx)
	audio.sound_ready = true
	var frame := Engine.get_process_frames()
	# player_ball._finish_landing emits these three facts synchronously in this order.
	events.slammed.emit(Vector3.ZERO, 1.0, 1.0)
	events.harpoon_smashed.emit(null, Vector3.ZERO, 30.0)
	events.line_state_changed.emit("smash_lands", null, Vector3.ZERO, "")
	var counts := {}
	for cue in audio.cue_log:
		if cue[2] == "now":
			counts[cue[1]] = int(counts.get(cue[1], 0)) + 1
	var ok: bool = frame == Engine.get_process_frames() and counts.size() == 3 and counts.get("smash_crack", 0) == 1 and counts.values().all(func(n): return n == 1) and counts.get(Rows.sound("slammed"), 0) == 1 and counts.get("womp", 0) == 1
	var result := {"ok": ok, "counts": counts, "cue_log": audio.cue_log.duplicate(true)}
	audio.free()
	events.free()
	return result


func _record(key: String, damage := 0.0) -> Dictionary:
	var kinds := {"none": "arc_slammed", "hit": "enemy_pinned", "heavy": "slammed", "massive": "ultimate_landed", "climax": "boss_defeated"}
	return event_script.call("weigh", kinds[key], {"damage": damage})


func _stop(row: Dictionary, damage: float) -> float:
	if row.get("stop_ms") is String:
		return EventJuice.stop_ms_for(damage, false, row.stop_ms == "heavy")
	return float(row.get("stop_ms", -1.0))


func _stop_order(weights: Dictionary) -> bool:
	for damage in [0.0, 10.0, 30.0, 60.0]:
		var previous := -1.0
		for key in CLASSES:
			var stop := _stop(weights.get(key, {}), damage)
			if stop <= previous or stop > HitStopBudget.SPINE_CAP_MS or (key == "none" and stop != 0.0):
				return false
			previous = stop
	return true


func _scalar_order(weights: Dictionary, field: String, cap := INF) -> bool:
	var previous := -1.0
	for key in CLASSES:
		var value := float(weights.get(key, {}).get(field, -1.0))
		if value <= previous or value > cap:
			return false
		previous = value
	return true


func _bodies(weights: Dictionary) -> bool:
	for key in CLASSES:
		var id := String(weights.get(key, {}).get("body", ""))
		if key in ["none", "hit"]:
			if id != "":
				return false
		elif not Bank.has_recipe(id) or Bank.samples(id).is_empty():
			return false
	return true


func _body_measurements(weights: Dictionary) -> Array:
	var out := []
	for key in ["heavy", "massive", "climax"]:
		var row: Dictionary = weights.get(key, {})
		var id := String(row.get("body", ""))
		if not Bank.has_recipe(id):
			return []
		var measured := _measure(id, float(_record(key).body_ratio))
		measured["class"] = key
		out.append(measured)
	return out


func _slam_weight_ok(shared: Dictionary) -> bool:
	return not shared.is_empty() and shared.peak_db >= -3.0 and shared.rms_db >= SLAM_RMS_FLOOR_DB and shared.onset_ms <= 20.0


func _measure(id: String, ratio := 1.0) -> Dictionary:
	var cache_key := "%s|%.9f" % [id, ratio]
	if _measure_cache.has(cache_key):
		return (_measure_cache[cache_key] as Dictionary).duplicate()
	if not Bank.has_recipe(id):
		return {}
	var samples := Bank.samples(id)
	if samples.is_empty():
		return {}
	var crosses := 0
	var peak := 0.0
	var sum_squares := 0.0
	var onset_ms := INF
	var gain := db_to_linear(Bank.trim_db(id))
	var onset_thresh := db_to_linear(-30.0)
	var prev_neg := samples[0] < 0.0
	for i in samples.size():
		var raw := samples[i]
		var sample := raw * gain
		var mag := absf(sample)
		peak = maxf(peak, mag)
		sum_squares += sample * sample
		if onset_ms == INF and mag > onset_thresh:
			onset_ms = 1000.0 * i / Bank.RATE / ratio
		if i > 0:
			var neg := raw < 0.0
			if neg != prev_neg:
				crosses += 1
			prev_neg = neg
	var seconds := float(samples.size()) / Bank.RATE / ratio
	var out := {"zcr": crosses / seconds, "seconds": seconds, "peak_db": linear_to_db(peak),
		"rms_db": linear_to_db(sqrt(sum_squares / samples.size())), "onset_ms": onset_ms}
	_measure_cache[cache_key] = out
	return out.duplicate()


func _identity_errors(facts: Dictionary) -> Dictionary:
	var hostile := []
	var voiced := []
	var hostile_cues := []
	for fact in EventKinds.ROWS:
		if facts.get(fact, {}).get("allegiance", "") == "hostile" or EventKinds.ROWS[fact].color == Palette.HAZARD:
			hostile_cues.append(Rows.sound(fact))
	for fact in facts:
		if facts[fact].allegiance != "player":
			continue
		var cue := Rows.sound(fact)
		if cue != "" and cue in hostile_cues:
			hostile.append([fact, cue])
		var voices := []
		for pilot in ClassDef.all():
			if cue.ends_with("_" + pilot.motif) or cue == pilot.sound or cue.begins_with(pilot.id + "_") or cue.begins_with(pilot.motif + "_"):
				voices.append(pilot.id)
		if voices.is_empty() and ["ally_", "mind_", "near_miss_whip_"].any(func(prefix): return cue.begins_with(prefix)):
			voices.append("unknown")
		var owner := String(OWNER.get(fact, "neutral"))
		if not voices.is_empty() and (owner == "neutral" or voices.any(func(voice): return voice != owner)):
			voiced.append([fact, cue, owner, voices])
	return {"hostile": hostile, "voiced": voiced}


func _audibility_errors(facts: Dictionary) -> Dictionary:
	var weight := []
	var onset := []
	var ceiling := []
	var floor_db: float = _measure("slam_boom").peak_db - 6.0
	for fact in facts:
		var cue := Rows.sound(fact)
		var measured := _measure(cue)
		var classes: Array = [facts[fact].get("class", "")] if facts[fact].has("class") else _rule_classes(String(facts[fact].get("rule", "")))
		if classes.any(func(key): return key in ["massive", "climax"]) and (measured.is_empty() or measured.peak_db < floor_db - 0.0001):
			weight.append([fact, cue, measured.get("peak_db", -INF), floor_db])
		if facts[fact].allegiance == "player" and (measured.is_empty() or measured.onset_ms > 20.0):
			onset.append([fact, cue, measured.get("onset_ms", INF)])
		if not measured.is_empty() and measured.peak_db > -0.5:
			ceiling.append([fact, cue, measured.peak_db])
	return {"weight": weight, "onset": onset, "ceiling": ceiling}


func _body_order(measurements: Array) -> bool:
	if measurements.size() != 3:
		return false
	for i in range(1, measurements.size()):
		if measurements[i].zcr >= measurements[i - 1].zcr or measurements[i].seconds < measurements[i - 1].seconds:
			return false
	return true


func coverage(facts: Dictionary, weights: Dictionary) -> Array:
	var bus := Events.new()
	var bad := []
	for fact in facts:
		var row: Dictionary = facts[fact]
		var real: bool = bus.has_signal(fact) or fact == "posture_break"
		var class_ok: bool = weights.has(row.get("class", "")) or row.get("rule", "") in RULES
		var allegiance_ok: bool = row.get("allegiance", "") in ["player", "motion", "hostile", "reward"]
		var visual := String(row.get("visual", ""))
		var visual_ok: bool = not Fx.effects(fact).is_empty() or Rows.shape(fact) != "none" or not Fx.spec(visual).is_empty()
		var sound := String(row.get("sound", Rows.sound(fact)))
		var possible: Array = [row.get("class", "")] if row.has("class") else _rule_classes(String(row.get("rule", "")))
		var sound_ok := not possible.is_empty()
		for key in possible:
			sound_ok = sound_ok and (Bank.has_recipe(sound) or Bank.has_recipe(String(weights.get(key, {}).get("body", ""))))
		if not real or not class_ok or not allegiance_ok or not visual_ok or not sound_ok:
			bad.append(fact)
	bus.free()
	bad.sort()
	return bad


func _rule_classes(rule: String) -> Array:
	match rule:
		"strike": return ["none", "hit", "heavy"]
		"death_parts": return ["hit", "heavy", "massive", "climax"]
		"amount": return ["hit", "heavy", "massive"]
		"gauge": return ["hit", "heavy"]
		"posture": return ["none", "heavy", "massive"]
	return []


# Read direct connections, optional helpers and the arrays used by dynamic listeners.
func connected_signals(source_overrides := {}) -> Array:
	var found := []
	for node in PRESENTATION:
		var path := "res://src/presentation/%s.gd" % node
		var source := String(source_overrides.get(node, FileAccess.get_file_as_string(path)))
		var patterns := [r"events\.([a-z_]+)\.connect\(", r'_listen\(events,\s*"([a-z_]+)"', r'events\.connect\("([a-z_]+)"']
		for pattern in patterns:
			var regex := RegEx.create_from_string(pattern)
			for hit in regex.search_all(source):
				if not hit.get_string(1) in found:
					found.append(hit.get_string(1))
		var arrays := RegEx.create_from_string(r'for (?:signal_name|kind) in \[([^\]]+)\]')
		for hit in arrays.search_all(source):
			for literal in RegEx.create_from_string(r'"([a-z_]+)"').search_all(hit.get_string(1)):
				if not literal.get_string(1) in found:
					found.append(literal.get_string(1))
		if node == "audio":
			var audio_constants: Dictionary = load(path).get_script_constant_map()
			for key in ["CHARACTER_KINDS", "ENEMY_KINDS"]:
				for fact in audio_constants[key]:
					if not fact in found:
						found.append(fact)
	found.sort()
	return found


func uncovered_listeners(listeners: Array, facts: Dictionary, exemptions: Dictionary) -> Array:
	return listeners.filter(func(fact): return not facts.has(fact) and String(exemptions.get(fact, "")).strip_edges().is_empty())


func _bank_ids(record: Dictionary) -> Array:
	var ids := []
	for field in ["sound", "body"]:
		var id := String(record.get(field, ""))
		if id != "":
			ids.append(id)
	return ids


func _rule_errors() -> Array:
	var errors := []
	var examples := [
		["gauge_released", {"fraction": 0.999}, "hit"], ["gauge_released", {"fraction": 1.0}, "heavy"],
		["player_hit", {"amount": 9.99}, "hit"], ["player_hit", {"amount": 10.0}, "heavy"],
		["player_hit", {"amount": 19.99}, "heavy"], ["player_hit", {"amount": 20.0}, "massive"],
		["posture_changed", {"staggered": false}, "none"], ["posture_changed", {"staggered": true}, "massive"],
		["posture_changed", {"chunks_lost": 1}, "heavy"], ["posture_break", {"staggered": true}, "massive"],
	]
	for kind in Windup.ROWS:
		var parts: int = Windup.ROWS[kind].death.parts
		var expected := "climax" if kind == "warden" else ("massive" if parts >= 8 else ("heavy" if parts >= 5 else "hit"))
		examples.append(["enemy_killed", {"kind": kind}, expected])
	for kind in EventKinds.IMPACT:
		examples.append(["enemy_struck", {"kind": kind}, EventKinds.IMPACT[kind].stop])
	for fact in ["slammed", "sticky_detonated", "enemy_rebounded", "boss_weak_point_hit"]:
		examples.append([fact, {}, "heavy"])
	for fact in ["cloak_broken", "hold_broken", "swarm_scattered", "enemy_pinned"]:
		examples.append([fact, {}, "hit"])
	for fact in ["arc_slammed", "skid_smashed", "demo_slammed", "cloak_started", "sprint_started", "cc_ignored", "blink_used", "vault_kicked"]:
		examples.append([fact, {}, "none"])
	for fact in ["ultimate_landed", "player_died"]:
		examples.append([fact, {}, "massive"])
	examples.append(["boss_defeated", {}, "climax"])
	for example in examples:
		var record: Dictionary = event_script.call("weigh", example[0], example[1])
		if record.weight != example[2]:
			errors.append([example, record.weight])
	var chunk: Dictionary = event_script.call("weigh", "posture_changed", {"chunks_lost": 1})
	if not is_equal_approx(chunk.strength, 1.0 / Posture.CHUNKS):
		errors.append(["chunk strength", chunk.strength])
	return errors


func _sorted(values: Array) -> Array:
	var out := values.duplicate()
	out.sort()
	return out
