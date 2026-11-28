extends RefCounted
class_name PilotStory


const LoreRows := preload("res://src/core/lore_rows.gd")
const WordBudget := preload("res://src/core/word_budget.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Rows := preload("res://src/core/pilot_story_rows.gd")

const CAST_ORDER: Array[String] = [
	"pylon_engineer",
	"runner_gunner",
	"demolitions_caster",
	"tarn",
	"tally",
	"remembered_cannon",
	"moss",
	"patch",
]
const PILOT_CAST: Array[String] = [
	"pylon_engineer",
	"runner_gunner",
	"demolitions_caster",
	"tarn",
	"tally",
	"remembered_cannon",
]
const SHORT_TOKENS := {
	"pylon_engineer": "sable",
	"runner_gunner": "rivet",
	"demolitions_caster": "kest",
	"tarn": "tarn",
	"tally": "tally",
	"remembered_cannon": "cannon",
}
const TOKEN_TO_CLASS := {
	"sable": "pylon_engineer",
	"rivet": "runner_gunner",
	"kest": "demolitions_caster",
	"tarn": "tarn",
	"tally": "tally",
	"cannon": "remembered_cannon",
}

const CHAPTERS_PER_CAST := 5
const TITLE_WORDS := 3
const PAYOFF_NAME_WORDS := 4
const CALL_WORD_CAP := 12
const EXCHANGE_WORD_CAP := 14
const STAGE_MEMO_WORD_CAP := 8
const LOSS_MEMO_WORD_CAP := 14
const NOTE_WORDS := 40
const HABIT_MIN_RUNS := 3
const FOREMAN_AXIS_COOLDOWN := 2
const STAT_OVERTIME_PREFIX := "story.overtime."
const SETTLE_EXCHANGE_PREFIX := "camp.ex."

const FOREMAN_AXIS_ORDER: Array[String] = [
	"chronic_gambler",
	"kindness_regular",
	"cursed_runner",
	"speed_demon",
	"heavy_roller",
	"sig_circuit",
	"sig_burst",
]

const BANNED_SUBSTRINGS := ["!", "\u2014", "\u2013", "...", "\u2026", "\u00b7", "\u2018", "\u2019", "\u201c", "\u201d"]
const BANNED_WORDS := [
	"class", "classes", "epic", "powerful", "unleash", "unleashes", "master", "legendary",
	"salvage", "foes", "miniboss", "grapple", "rebound", "rebounds", "stockpile", "stockpiles",
	"stockpiled", "mats", "mixtapes", "tunes", "badge", "badges", "remix",
]
const BANNED_PHRASES := ["scrap mass", "set piece", "q becomes", "hands back", "give back", "gives back", "latch on", "restart run", "run again", "the gauge", "radio song"]

const CHAPTERS := Rows.CHAPTERS
const PAIRS := Rows.PAIRS
const PATCH_TRAIL := Rows.PATCH_TRAIL
const FOREMAN_AXES := Rows.FOREMAN_AXES


static func chapters_for(cast_id: String) -> Array:
	var out: Array = []
	for row in CHAPTERS:
		if String(row["cast"]) == cast_id:
			out.append(row.duplicate(true))
	return out


static func chapter(chapter_id: String) -> Dictionary:
	for row in CHAPTERS:
		if String(row["id"]) == chapter_id:
			return row.duplicate(true)
	return {}


static func punch_mask(cast_id: String, profile, codex = null) -> Array[bool]:
	var mask: Array[bool] = []
	for row in CHAPTERS:
		if String(row["cast"]) == cast_id:
			mask.append(_chapter_punched(row, profile, codex))
	return mask


static func punched_count(cast_id: String, profile, codex = null) -> int:
	var n := 0
	for hit in punch_mask(cast_id, profile, codex):
		if hit:
			n += 1
	return n


static func card_visible(cast_id: String, profile, sitting := false, codex = null) -> bool:
	if not cast_id in CAST_ORDER:
		return false
	var rows := chapters_for(cast_id)
	if rows.is_empty():
		return false
	if bool(rows[0].get("hidden", false)):
		return sitting or punched_count(cast_id, profile, codex) > 0
	return true


static func card_for(cast_id: String, profile, sitting := false, codex = null) -> Dictionary:
	if not cast_id in CAST_ORDER:
		return {}
	var rows := chapters_for(cast_id)
	var mask := punch_mask(cast_id, profile, codex)
	var visible := card_visible(cast_id, profile, sitting, codex)
	var count := 0
	var decorated: Array = []
	var chase := {}
	for i in rows.size():
		var item: Dictionary = rows[i]
		var punched: bool = i < mask.size() and mask[i]
		item["punched"] = punched
		if punched:
			count += 1
		elif chase.is_empty() and visible:
			chase = item.duplicate(true)
		decorated.append(item)
	return {
		"cast": cast_id,
		"visible": visible,
		"mask": mask,
		"punched": count,
		"total": CHAPTERS_PER_CAST,
		"overtime": overtime_rung(cast_id, profile),
		"chapters": decorated,
		"next_chase": chase,
	}


static func next_chase(pilot_id: String, profile, sitting := false, codex = null) -> Dictionary:
	if not card_visible(pilot_id, profile, sitting, codex):
		return {}
	var rows := chapters_for(pilot_id)
	var mask := punch_mask(pilot_id, profile, codex)
	for i in rows.size():
		if i < mask.size() and not mask[i]:
			return (rows[i] as Dictionary).duplicate(true)
	return {}


static func chapters_matching_trigger(trigger_id: String, profile, codex = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if trigger_id == "":
		return out
	var candidates := [trigger_id, "order:" + trigger_id, "codex:" + trigger_id]
	for row in CHAPTERS:
		if _accepts_mentions(row.get("accepts", []), candidates) and _chapter_punched(row, profile, codex):
			out.append({
				"cast": String(row["cast"]),
				"num": int(row["num"]),
				"id": String(row["id"]),
			})
	return out


static func record_overtime(pilot_id: String, run_tier: int, profile) -> bool:
	if profile == null or not pilot_id in CAST_ORDER or run_tier <= 0:
		return false
	var clamped := clampi(run_tier, 0, 5)
	if clamped <= overtime_rung(pilot_id, profile):
		return false
	profile.set_stat(STAT_OVERTIME_PREFIX + pilot_id, float(clamped))
	return true


static func overtime_rung(pilot_id: String, profile) -> int:
	if profile == null or pilot_id == "":
		return 0
	return clampi(int(profile.stat(STAT_OVERTIME_PREFIX + pilot_id)), 0, 5)


static func _accepts_mentions(accepts: Array, candidates: Array) -> bool:
	for expr in accepts:
		var raw := String(expr)
		if raw in candidates:
			return true
		if raw.contains("+"):
			for part in raw.split("+", false):
				if part in candidates:
					return true
	return false


static func _chapter_punched(row: Dictionary, profile, codex = null) -> bool:
	for expr in row.get("accepts", []):
		if _condition_met(String(expr), profile, codex):
			return true
	return false


static func _condition_met(expr: String, profile, codex = null) -> bool:
	if expr == "":
		return false
	if expr.contains("+"):
		for part in expr.split("+", false):
			if not _condition_met(part, profile, codex):
				return false
		return true
	if expr.begins_with("codex:"):
		var cid := expr.trim_prefix("codex:")
		return codex != null and bool(codex.known(cid))
	if profile == null:
		return false
	if expr.begins_with("pilot:"):
		var pid := expr.trim_prefix("pilot:")
		return profile.last_pilot() == pid or profile.stat("habit.pilot_runs." + pid) >= 1.0
	if expr.begins_with("order:") or expr.begins_with("patch.wire.") or expr.begins_with(SETTLE_EXCHANGE_PREFIX):
		return bool(profile.is_settled(expr))
	return bool(profile.earned(expr)) or bool(profile.is_settled(expr))


static func codex_declarations() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pid in pair_ids():
		var pair: Dictionary = PAIRS[pid]
		var payoff: Dictionary = pair["payoff"]
		out.append({
			"id": "pair.%s.3" % pid,
			"category": "coop",
			"name": String(payoff["name"]),
			"hint": Rows.PAIR_CODEX_META["hint"],
			"clue": Rows.PAIR_CODEX_META["clue"],
			"text": String(payoff["codex_text"]),
		})
	for node_id in PATCH_TRAIL:
		var node: Dictionary = PATCH_TRAIL[node_id]
		out.append({
			"id": String(node["id"]),
			"category": String(node["category"]),
			"name": String(node["name"]),
			"hint": String(node["hint"]),
			"clue": String(node["clue"]),
			"text": String(node["log"]),
		})
	return out


static func entry_visible(entry_id: String, known: Callable) -> bool:
	var is_known := func(id: String) -> bool: return known.is_valid() and bool(known.call(id))
	if entry_id.begins_with("pair."):
		var parts := entry_id.split(".")
		if parts.size() == 3 and PAIRS.has(parts[1]):
			var pid := parts[1]
			var beat := int(parts[2])
			if is_known.call(entry_id):
				return true
			if beat == 2:
				return is_known.call("pair.%s.1" % pid)
			if beat == 3:
				return is_known.call("pair.%s.2" % pid)
			return false
	if PATCH_TRAIL.has(entry_id):
		if is_known.call(entry_id):
			return true
		var node: Dictionary = PATCH_TRAIL[entry_id]
		var req := String(node.get("requires", ""))
		return req != "" and is_known.call(req)
	return true


static func synthesis_margin(entry_id: String, known: Callable) -> String:
	if not entry_id.begins_with("pair.") or not entry_id.ends_with(".3"):
		return ""
	var parts := entry_id.split(".")
	if parts.size() != 3 or not PAIRS.has(parts[1]):
		return ""
	var payoff: Dictionary = PAIRS[parts[1]]["payoff"]
	var target := String(payoff.get("links_to", ""))
	var note := String(payoff.get("margin_note", ""))
	if target == "" or note == "":
		return ""
	if known.is_valid() and bool(known.call(target)):
		return "\nMargin note: confirmed in the field."
	return "\nMargin note: " + note


static func pair_id(class_a: String, class_b: String) -> String:
	if class_a == class_b:
		return ""
	if not SHORT_TOKENS.has(class_a) or not SHORT_TOKENS.has(class_b):
		return ""
	var ta := String(SHORT_TOKENS[class_a])
	var tb := String(SHORT_TOKENS[class_b])
	return "%s_%s" % [ta, tb] if ta < tb else "%s_%s" % [tb, ta]


static func pair_ids() -> Array[String]:
	var out: Array[String] = []
	for key in PAIRS:
		out.append(String(key))
	out.sort()
	return out


static func pair_stage(pid: String, known: Callable) -> int:
	if not PAIRS.has(pid) or not known.is_valid():
		return 0
	if bool(known.call("pair.%s.3" % pid)):
		return 3
	if bool(known.call("pair.%s.2" % pid)):
		return 2
	if bool(known.call("pair.%s.1" % pid)):
		return 1
	return 0


static func pick_camp_beat(
	flying_class: String, approached_class: String, standing_ids: Array,
	profile, codex, pages: Array, walks: int, pair_played_this_walk: bool
) -> Dictionary:
	var known_fn := func(id: String) -> bool: return codex != null and bool(codex.known(id))
	if not pair_played_this_walk:
		var pid := pair_id(flying_class, approached_class)
		if pid != "" and PAIRS.has(pid) and _pilot_unlocked(flying_class, profile) and _pilot_unlocked(approached_class, profile):
			var stage := pair_stage(pid, known_fn)
			var pair: Dictionary = PAIRS[pid]
			if stage == 0:
				return {
					"kind": "pair_spark",
					"id": "pair.%s.1" % pid,
					"pair_id": pid,
					"beat": 1,
					"codex_id": "pair.%s.1" % pid,
					"lines": (pair["spark"] as Array).duplicate(true),
					"consumes_pair_budget": true,
				}
			if stage == 2 and _boss_cleared(profile, pages):
				var payoff: Dictionary = pair["payoff"]
				return {
					"kind": "pair_payoff",
					"id": "pair.%s.3" % pid,
					"pair_id": pid,
					"beat": 3,
					"codex_id": "pair.%s.3" % pid,
					"lines": (payoff["lines"] as Array).duplicate(true),
					"consumes_pair_budget": true,
				}
		for ex in LoreRows.CAMP_EXCHANGES:
			var ex_id := String(ex["id"])
			var settle_key := SETTLE_EXCHANGE_PREFIX + ex_id
			if profile != null and profile.is_settled(settle_key):
				continue
			var pilots: Array = ex.get("pilots", [])
			if not approached_class in pilots:
				continue
			if not _all_present(pilots, flying_class, standing_ids):
				continue
			var req_ch := String(ex.get("requires_chapter", ""))
			if req_ch != "":
				var ch_row := chapter(req_ch)
				if ch_row.is_empty() or not _chapter_punched(ch_row, profile, codex):
					continue
			return {
				"kind": "camp_exchange",
				"id": ex_id,
				"settle_key": settle_key,
				"lines": (ex["lines"] as Array).duplicate(true),
				"consumes_pair_budget": true,
			}
	var tiered: Dictionary = LoreRows.CAMP_QUIPS_BY_CHAPTER.get(approached_class, {})
	if not tiered.is_empty():
		var mask := punch_mask(approached_class, profile, codex)
		for tier in [5, 4, 2]:
			if tiered.has(tier) and tier - 1 < mask.size() and mask[tier - 1]:
				var lines: Array = tiered[tier]
				if not lines.is_empty():
					var qid := "camp.quip.%s.ch%d" % [String(SHORT_TOKENS.get(approached_class, approached_class)), tier]
					var text := String(lines[posmod(absi(hash(qid)) + walks, lines.size())])
					var speaker := String(SHORT_TOKENS.get(approached_class, approached_class))
					return {
						"kind": "solo_quip",
						"id": qid,
						"speaker": speaker,
						"text": text,
						"lines": [{"speaker": speaker, "text": text}],
						"consumes_pair_budget": false,
					}
	var base_quip := LoreRows.camp_quip(approached_class)
	if base_quip.is_empty():
		return {}
	var base_text := LoreRows.camp_quip_text(base_quip, walks)
	var base_speaker := String(base_quip["speaker"])
	return {
		"kind": "solo_quip",
		"id": String(base_quip["id"]),
		"speaker": base_speaker,
		"text": base_text,
		"lines": [{"speaker": base_speaker, "text": base_text}],
		"consumes_pair_budget": false,
	}


static func pick_run_call(
	event: String, args: Array, world: int, flying_class: String, run_seed: int,
	unlocked_classes: Array, profile, codex, played_ids: Dictionary, pair_call_used: bool
) -> Dictionary:
	if event == "enemy_killed" and args.size() > 0:
		var rogue_id := patch_rogue_for_kind(String(args[0]))
		if rogue_id != "":
			if played_ids.has(rogue_id):
				return {}
			var node: Dictionary = PATCH_TRAIL[rogue_id]
			var speaker := "unsigned" if rogue_id == "patch.rogue.w1" and not _chapter_punched(chapter("patch.ch2"), profile, codex) else "patch"
			return {
				"kind": "patch_trail",
				"id": rogue_id,
				"codex_id": rogue_id,
				"speaker": speaker,
				"text": LoreRows.call_text({"id": rogue_id, "text": node["call"]}, run_seed),
				"consumes_pair_budget": false,
			}
	if event == "world_fact" and args.size() > 0:
		var fact_id := String(args[0])
		if PATCH_TRAIL.has(fact_id) and String(PATCH_TRAIL[fact_id].get("kind", "")) == "wire" and not played_ids.has(fact_id):
			var node: Dictionary = PATCH_TRAIL[fact_id]
			return {
				"kind": "patch_trail",
				"id": fact_id,
				"codex_id": fact_id,
				"speaker": "patch",
				"text": LoreRows.call_text({"id": fact_id, "text": node["call"]}, run_seed),
				"consumes_pair_budget": false,
			}
	if not pair_call_used and SHORT_TOKENS.has(flying_class):
		var known_fn := func(id: String) -> bool: return codex != null and bool(codex.known(id))
		for pid in pair_ids():
			var pair: Dictionary = PAIRS[pid]
			var pilots: Array = pair["pilots"]
			if not flying_class in pilots:
				continue
			var other := String(pilots[0] if String(pilots[1]) == flying_class else pilots[1])
			if other == flying_class:
				continue
			if not (other in unlocked_classes or _pilot_unlocked(other, profile)):
				continue
			var beat1_id := "pair.%s.1" % pid
			var beat2_id := "pair.%s.2" % pid
			if played_ids.has(beat2_id) or not known_fn.call(beat1_id) or known_fn.call(beat2_id):
				continue
			var field_row: Dictionary = pair["field"]
			if not LoreRows.call_matches(field_row, event, args):
				continue
			var variants: Dictionary = field_row.get("variants", {})
			if not variants.has(flying_class):
				continue
			return {
				"kind": "pair_field",
				"id": beat2_id,
				"pair_id": pid,
				"codex_id": beat2_id,
				"speaker": String(SHORT_TOKENS[other]),
				"pilot": other,
				"text": LoreRows.call_text({"id": beat2_id, "text": variants[flying_class]}, run_seed),
				"consumes_pair_budget": true,
			}
	var chapter_pilots: Array = []
	var pilot_rows: Array = []
	for row in LoreRows.WORLD_CALLS:
		var cid := String(row["id"])
		if played_ids.has(cid):
			continue
		if int(row.get("world", 0)) != world:
			continue
		if not LoreRows.call_matches(row, event, args):
			continue
		if row.has("requires_chapter"):
			var req := chapter(String(row["requires_chapter"]))
			if req.is_empty() or not _chapter_punched(req, profile, codex):
				continue
		if row.has("pilot"):
			var p := String(row["pilot"])
			if p == flying_class:
				continue
			if not (p in unlocked_classes or _pilot_unlocked(p, profile)):
				continue
			if row.has("requires_chapter"):
				chapter_pilots.append(row)
			else:
				pilot_rows.append(row)
			continue
		return {
			"kind": "world_call",
			"id": cid,
			"speaker": String(row["speaker"]),
			"text": LoreRows.call_text(row, run_seed),
			"consumes_pair_budget": false,
		}
	var pool: Array = chapter_pilots if not chapter_pilots.is_empty() else pilot_rows
	if not pool.is_empty():
		var chosen: Dictionary = pool[posmod(absi(hash([run_seed, world, event])), pool.size())]
		return {
			"kind": "world_call",
			"id": String(chosen["id"]),
			"speaker": String(chosen["speaker"]),
			"pilot": String(chosen["pilot"]),
			"text": LoreRows.call_text(chosen, run_seed),
			"consumes_pair_budget": false,
		}
	return {}


static func _pilot_unlocked(class_id: String, profile) -> bool:
	var def := ClassDef.by_id(class_id)
	if def == null:
		return false
	if bool(def.starter):
		return true
	if profile == null:
		return false
	return bool(profile.has_pilot(class_id)) or ClassDef.unlock_open(def.unlock, Callable(profile, "earned"))


static func _boss_cleared(profile, pages: Array) -> bool:
	if profile != null:
		if profile.earned("brindle_routed") or profile.earned("waking_stilled") or profile.earned("mind_quieted"):
			return true
	for page in pages:
		if page is Dictionary:
			var outcome := String((page as Dictionary).get("outcome", ""))
			if outcome == "won" or (outcome == "" and bool((page as Dictionary).get("won", false))):
				return true
	return false


static func _all_present(pilots: Array, flying_class: String, standing_ids: Array) -> bool:
	for p in pilots:
		if String(p) != flying_class and not String(p) in standing_ids:
			return false
	return true


static func patch_node(node_id: String) -> Dictionary:
	if not PATCH_TRAIL.has(node_id):
		return {}
	return (PATCH_TRAIL[node_id] as Dictionary).duplicate(true)


static func patch_spot(wire_id: String, run_seed: int) -> Dictionary:
	var node: Dictionary = PATCH_TRAIL.get(wire_id, {})
	var spots: Array = node.get("spots", [])
	if spots.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [wire_id, run_seed])
	return (spots[rng.randi_range(0, spots.size() - 1)] as Dictionary).duplicate(true)


static func patch_rogue_for_kind(rogue_kind: String) -> String:
	for node_id in PATCH_TRAIL:
		var node: Dictionary = PATCH_TRAIL[node_id]
		if String(node.get("rogue_kind", "")) == rogue_kind:
			return String(node_id)
	return ""


static func foreman_axis_index(axis: String) -> int:
	var idx := FOREMAN_AXIS_ORDER.find(axis)
	return idx + 1 if idx >= 0 else 0


static func foreman_axis_name(idx: int) -> String:
	if idx < 1 or idx > FOREMAN_AXIS_ORDER.size():
		return ""
	return FOREMAN_AXIS_ORDER[idx - 1]


static func record_foreman_axis(axis: String, run_number: int, profile) -> void:
	if profile == null:
		return
	var idx := foreman_axis_index(axis)
	if idx <= 0:
		return
	profile.set_stat("habit.foreman_last_axis", float(idx))
	profile.set_stat("habit.foreman_last_run", float(run_number))


static func classify_habits(profile, pages: Array, run = null) -> Dictionary:
	var total_runs := _total_runs(profile, pages)
	if profile == null or total_runs < HABIT_MIN_RUNS:
		return {
			"dormant": true,
			"total_runs": total_runs,
			"axis": "",
			"score": 0.0,
			"suppressed": false,
			"scores": {},
		}
	var risk := float(profile.stat("habit.trade_risk"))
	var safe := float(profile.stat("habit.trade_safe"))
	var cursed := float(profile.stat("habit.runs_cursed"))
	if run != null and run.has_method("cursed") and bool(run.cursed()):
		cursed += 1.0
	var blazing := float(profile.stat("habit.runs_blazing"))
	var heft := float(profile.stat("habit.runs_heft_high"))
	var circuit := float(profile.stat("habit.sig.circuit")) + float(profile.stat("habit.sig.arc"))
	var burst := float(profile.stat("habit.sig.burst")) + float(profile.stat("habit.sig.kinetic"))

	var scores := {
		"chronic_gambler": maxf(0.0, risk - safe * 0.5) if risk >= 2.0 and risk > safe else 0.0,
		"kindness_regular": maxf(0.0, safe - risk * 0.5) if safe >= 2.0 and safe >= risk else 0.0,
		"cursed_runner": cursed * 1.2 if cursed >= 1.0 else 0.0,
		"speed_demon": blazing * 1.1 if blazing >= 2.0 else 0.0,
		"heavy_roller": heft * 1.1 if heft >= 2.0 else 0.0,
		"sig_circuit": circuit * 1.0 if circuit >= 2.0 else 0.0,
		"sig_burst": burst * 1.0 if burst >= 2.0 else 0.0,
	}

	var last_axis := _read_last_axis(profile)
	var last_run := int(profile.stat("habit.foreman_last_run"))
	var on_cooldown := last_axis != "" and last_run > 0 and total_runs >= last_run and (total_runs - last_run) < FOREMAN_AXIS_COOLDOWN

	var best_axis := ""
	var best_score := 0.0
	var suppressed := false
	for axis in FOREMAN_AXIS_ORDER:
		var s := float(scores[axis])
		if s <= 0.0:
			continue
		if on_cooldown and axis == last_axis:
			suppressed = true
			continue
		if s > best_score:
			best_score = s
			best_axis = axis
	return {
		"dormant": false,
		"total_runs": total_runs,
		"axis": best_axis,
		"score": best_score,
		"suppressed": suppressed,
		"scores": scores,
	}


static func foreman_stage_memo(run_seed: int, stage: int, profile, pages: Array, run = null) -> String:
	var read := classify_habits(profile, pages, run)
	var axis := String(read["axis"])
	if bool(read["dormant"]) or axis == "":
		return ""
	if posmod(absi(hash([run_seed, stage, "foreman_adapt"])), 2) != 0:
		return ""
	var lines: Array = FOREMAN_AXES[axis]["stage_memos"]
	return String(lines[posmod(absi(hash([run_seed, stage, axis, "foreman_stage"])), lines.size())])


static func foreman_loss_memo(run_seed: int, source: String, profile, pages: Array, run = null) -> String:
	var read := classify_habits(profile, pages, run)
	var axis := String(read["axis"])
	if bool(read["dormant"]) or axis == "":
		return ""
	var lines: Array = FOREMAN_AXES[axis]["loss_memos"]
	return String(lines[posmod(absi(hash([run_seed, source, axis, "foreman_loss"])), lines.size())])


static func foreman_crown_line(run_seed: int, profile, pages: Array, run = null) -> String:
	var read := classify_habits(profile, pages, run)
	var axis := String(read["axis"])
	if bool(read["dormant"]) or axis == "":
		return ""
	var lines: Array = FOREMAN_AXES[axis]["crown_lines"]
	return String(lines[posmod(absi(hash([run_seed, axis, "foreman_crown"])), lines.size())])


static func _total_runs(profile, pages: Array) -> int:
	var total := pages.size()
	if profile == null:
		return total
	var pilot_sum := 0
	for cid in PILOT_CAST:
		pilot_sum += int(profile.stat("habit.pilot_runs." + cid))
	total = maxi(total, pilot_sum)
	total = maxi(total, int(profile.stat("deaths")) + int(profile.stat("runs_won")))
	total = maxi(total, int(profile.stat("door.runs_started")))
	total = maxi(total, int(profile.stat("habit.runs_total")))
	return total


static func _read_last_axis(profile) -> String:
	if profile == null:
		return ""
	var raw = profile.stat("habit.foreman_last_axis")
	if raw is String:
		return raw if FOREMAN_AXES.has(raw) else ""
	return foreman_axis_name(int(raw))


static func validate(class_ids: Array, signal_names: Array, speaker_ids: Array) -> Array[String]:
	return validate_tables(
		CHAPTERS, PAIRS, PATCH_TRAIL, FOREMAN_AXES,
		LoreRows.WORLD_CALLS, LoreRows.CAMP_EXCHANGES, LoreRows.CAMP_QUIPS_BY_CHAPTER,
		class_ids, signal_names, speaker_ids
	)


static func validate_tables(
	chapters: Array, pairs: Dictionary, patch_trail: Dictionary, foreman_axes: Dictionary,
	world_calls: Array, camp_exchanges: Array, camp_quips_by_chapter: Dictionary,
	class_ids: Array, signal_names: Array, speaker_ids: Array
) -> Array[String]:
	var problems: Array[String] = []
	if "patch" in class_ids:
		problems.append("patch must not be in ClassDef class_ids")
	if chapters.size() != CAST_ORDER.size() * CHAPTERS_PER_CAST:
		problems.append("chapters: expected %d, got %d" % [CAST_ORDER.size() * CHAPTERS_PER_CAST, chapters.size()])
	var ch_ids := {}
	var per_cast := {}
	for cid in CAST_ORDER:
		per_cast[cid] = []
	for row in chapters:
		var id := String(row.get("id", ""))
		var cast := String(row.get("cast", ""))
		var num := int(row.get("num", 0))
		if id == "" or ch_ids.has(id):
			problems.append("chapter: missing or duplicate id %s" % id)
		ch_ids[id] = true
		if not cast in CAST_ORDER:
			problems.append("chapter %s: unknown cast %s" % [id, cast])
		else:
			if cast != "moss" and cast != "patch" and not cast in class_ids:
				problems.append("chapter %s: pilot cast %s not in class_ids" % [id, cast])
			(per_cast[cast] as Array).append(num)
		if id != "%s.ch%d" % [cast, num]:
			problems.append("chapter %s: id does not match <cast>.ch<num>" % id)
		if num < 1 or num > CHAPTERS_PER_CAST:
			problems.append("chapter %s: num %d out of range" % [id, num])
		var world := int(row.get("world", 0))
		if world < 1 or world > 3:
			problems.append("chapter %s: world %d out of 1..3" % [id, world])
		var is_tally := cast == "tally"
		_check_text(problems, "chapter %s title" % id, String(row.get("title", "")), TITLE_WORDS, is_tally)
		_check_text(problems, "chapter %s note" % id, String(row.get("note", "")), NOTE_WORDS, is_tally)
		if (row.get("accepts", []) as Array).is_empty():
			problems.append("chapter %s: empty accepts" % id)
		if id == "patch.ch1" and not bool(row.get("hidden", false)):
			problems.append("chapter patch.ch1: must have hidden: true")
		elif id != "patch.ch1" and bool(row.get("hidden", false)):
			problems.append("chapter %s: only patch.ch1 may be hidden" % id)
	for cid in CAST_ORDER:
		var nums: Array = per_cast[cid]
		nums.sort()
		if nums != [1, 2, 3, 4, 5]:
			problems.append("cast %s: chapters %s != [1, 2, 3, 4, 5]" % [cid, str(nums)])

	var expected_pairs := {}
	for i in PILOT_CAST.size():
		for j in range(i + 1, PILOT_CAST.size()):
			expected_pairs[pair_id(PILOT_CAST[i], PILOT_CAST[j])] = true
	if pairs.size() != expected_pairs.size():
		problems.append("pairs: expected %d pairs, got %d" % [expected_pairs.size(), pairs.size()])
	for ep in expected_pairs:
		if not pairs.has(ep):
			problems.append("pairs: missing pair %s" % ep)
	for pid in pairs:
		var pair: Dictionary = pairs[pid]
		var pilots: Array = pair.get("pilots", [])
		if pilots.size() != 2 or String(pilots[0]) == String(pilots[1]):
			problems.append("pair %s: invalid or self pair %s" % [pid, str(pilots)])
			continue
		var canon := pair_id(String(pilots[0]), String(pilots[1]))
		if canon != String(pid):
			problems.append("pair %s: key mismatch canonical %s" % [pid, canon])
		for p in pilots:
			if not String(p) in class_ids:
				problems.append("pair %s: pilot %s not in class_ids" % [pid, str(p)])
		var spark: Array = pair.get("spark", [])
		if spark.size() != 2:
			problems.append("pair %s: spark must have 2 lines" % pid)
		for line in spark:
			var sp := String((line as Dictionary).get("speaker", ""))
			if not sp in speaker_ids:
				problems.append("pair %s spark: unknown speaker %s" % [pid, sp])
			_check_text(problems, "pair %s spark" % pid, String((line as Dictionary).get("text", "")), EXCHANGE_WORD_CAP, sp == "tally")
		var field: Dictionary = pair.get("field", {})
		var sig := String(field.get("on", ""))
		if not sig in signal_names:
			problems.append("pair %s field: unknown signal %s" % [pid, sig])
		var variants: Dictionary = field.get("variants", {})
		for p in pilots:
			var p_str := String(p)
			if not variants.has(p_str):
				problems.append("pair %s field: missing variant for flying %s" % [pid, p_str])
				continue
			var other := String(pilots[0] if String(pilots[1]) == p_str else pilots[1])
			var other_tok := String(SHORT_TOKENS.get(other, ""))
			for vline in variants[p_str]:
				_check_text(problems, "pair %s field (%s)" % [pid, p_str], String(vline), CALL_WORD_CAP, other_tok == "tally")
		var payoff: Dictionary = pair.get("payoff", {})
		var pname := String(payoff.get("name", ""))
		_check_text(problems, "pair %s payoff name" % pid, pname, PAYOFF_NAME_WORDS, false)
		if pname.contains(":"):
			problems.append("pair %s payoff name: must not contain colon" % pid)
		var plines: Array = payoff.get("lines", [])
		if plines.size() != 2:
			problems.append("pair %s payoff: must have 2 lines" % pid)
		for line in plines:
			var sp := String((line as Dictionary).get("speaker", ""))
			if not sp in speaker_ids:
				problems.append("pair %s payoff: unknown speaker %s" % [pid, sp])
			_check_text(problems, "pair %s payoff" % pid, String((line as Dictionary).get("text", "")), EXCHANGE_WORD_CAP, sp == "tally")
		_check_text(problems, "pair %s codex_text" % pid, String(payoff.get("codex_text", "")), NOTE_WORDS, "tally" in pilots)
		_check_text(problems, "pair %s margin_note" % pid, String(payoff.get("margin_note", "")), EXCHANGE_WORD_CAP, "tally" in pilots)
		if String(payoff.get("links_to", "")) == "":
			problems.append("pair %s payoff: missing links_to" % pid)

	if patch_trail.size() != 6:
		problems.append("patch_trail: expected 6 nodes, got %d" % patch_trail.size())
	for w in [1, 2, 3]:
		var rid := "patch.rogue.w%d" % w
		var wid := "patch.wire.w%d" % w
		if not patch_trail.has(rid) or not patch_trail.has(wid):
			problems.append("patch_trail: missing world %d pair" % w)
			continue
		var rnode: Dictionary = patch_trail[rid]
		var wnode: Dictionary = patch_trail[wid]
		if String(rnode.get("reveals", "")) != wid:
			problems.append("patch_trail %s: must reveal %s" % [rid, wid])
		if String(wnode.get("requires", "")) != rid:
			problems.append("patch_trail %s: must require %s" % [wid, rid])
		if (wnode.get("spots", []) as Array).size() < 2:
			problems.append("patch_trail %s: needs at least 2 seeded spots" % wid)
		for nid in [rid, wid]:
			var n: Dictionary = patch_trail[nid]
			_check_text(problems, "patch %s log" % nid, String(n.get("log", "")), NOTE_WORDS, false)
			for cline in n.get("call", []):
				_check_text(problems, "patch %s call" % nid, String(cline), CALL_WORD_CAP, false)

	if foreman_axes.size() != FOREMAN_AXIS_ORDER.size():
		problems.append("foreman_axes: expected %d axes, got %d" % [FOREMAN_AXIS_ORDER.size(), foreman_axes.size()])
	for axis in FOREMAN_AXIS_ORDER:
		if not foreman_axes.has(axis):
			problems.append("foreman_axes: missing axis %s" % axis)
			continue
		var arow: Dictionary = foreman_axes[axis]
		var smemos: Array = arow.get("stage_memos", [])
		var lmemos: Array = arow.get("loss_memos", [])
		var clines: Array = arow.get("crown_lines", [])
		if smemos.is_empty() or lmemos.is_empty() or clines.is_empty():
			problems.append("foreman_axes %s: missing stage/loss/crown lines" % axis)
		for m in smemos:
			_check_text(problems, "foreman %s stage_memo" % axis, String(m), STAGE_MEMO_WORD_CAP, false)
		for m in lmemos:
			_check_text(problems, "foreman %s loss_memo" % axis, String(m), LOSS_MEMO_WORD_CAP, false)
		for m in clines:
			_check_text(problems, "foreman %s crown_line" % axis, String(m), CALL_WORD_CAP, false)

	if world_calls.size() < 13:
		problems.append("world_calls: expected at least 13 rows, got %d" % world_calls.size())
	var wc_ids := {}
	for row in world_calls:
		var cid := String(row.get("id", ""))
		if cid == "" or wc_ids.has(cid):
			problems.append("world_calls: missing or duplicate id %s" % cid)
		wc_ids[cid] = true
		var sp := String(row.get("speaker", ""))
		if not sp in speaker_ids:
			problems.append("world_calls %s: unknown speaker %s" % [cid, sp])
		var sig := String(row.get("on", ""))
		if not sig in signal_names:
			problems.append("world_calls %s: unknown signal %s" % [cid, sig])
		var lines: Array = row.get("text", []) if row.get("text") is Array else [row.get("text", "")]
		for line in lines:
			_check_text(problems, "world_calls %s" % cid, String(line), CALL_WORD_CAP, sp == "tally")

	var ex_ids := {}
	for ex in camp_exchanges:
		var eid := String(ex.get("id", ""))
		if eid == "" or ex_ids.has(eid):
			problems.append("camp_exchanges: missing or duplicate id %s" % eid)
		ex_ids[eid] = true
		for line in ex.get("lines", []):
			var sp := String((line as Dictionary).get("speaker", ""))
			if not sp in speaker_ids:
				problems.append("camp_exchanges %s: unknown speaker %s" % [eid, sp])
			_check_text(problems, "camp_exchanges %s" % eid, String((line as Dictionary).get("text", "")), EXCHANGE_WORD_CAP, sp == "tally")

	for pilot in camp_quips_by_chapter:
		if not String(pilot) in class_ids:
			problems.append("camp_quips_by_chapter: unknown pilot %s" % str(pilot))
		var tiers: Dictionary = camp_quips_by_chapter[pilot]
		for tier in tiers:
			for line in tiers[tier]:
				_check_text(problems, "camp_quips_by_chapter %s ch%s" % [pilot, str(tier)], String(line), CALL_WORD_CAP, String(pilot) == "tally")

	return problems


static func _check_text(problems: Array[String], label: String, text: String, max_words: int, forbid_paid: bool) -> void:
	var words := WordBudget.words_in(text)
	if words < 1 or words > max_words:
		problems.append("%s: %d words (cap %d): %s" % [label, words, max_words, text])
	for sub in BANNED_SUBSTRINGS:
		if text.contains(sub):
			problems.append("%s: banned token '%s'" % [label, sub])
	var lower := text.to_lower()
	for phrase in BANNED_PHRASES:
		if lower.contains(phrase):
			problems.append("%s: banned phrase '%s'" % [label, phrase])
	for raw_tok in lower.split(" ", false):
		var tok := _strip_punct(raw_tok)
		if tok in BANNED_WORDS:
			problems.append("%s: banned word '%s'" % [label, tok])
		if forbid_paid and tok == "paid":
			problems.append("%s: forbidden PAID token in Tally copy" % label)


static func _strip_punct(token: String) -> String:
	var s := token
	while s.length() > 0 and not _is_alnum(s.unicode_at(0)):
		s = s.substr(1)
	while s.length() > 0 and not _is_alnum(s.unicode_at(s.length() - 1)):
		s = s.substr(0, s.length() - 1)
	return s


static func _is_alnum(c: int) -> bool:
	return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
