extends RefCounted

const Groups := preload("res://src/core/groups.gd")
const TelegraphScript := preload("res://src/combat/telegraph.gd")
const TelegraphRecord := preload("res://src/combat/telegraph_record.gd")


const CONFIG_FILE := "scripts/challenge/fairness.json"

static var _config := {}

var game
var boss_hazards := Callable()
var _clock := 0.0
var _seen := {}
var _prev: Array = []
var _published := {}
var _hull := {"telegraphed": 0.0, "untelegraphed": 0.0, "contact": 0.0, "unknown": 0.0}
var _sources := {}
var _scrap := {"telegraphed": 0.0, "untelegraphed": 0.0, "contact": 0.0, "unknown": 0.0}
var _scrap_sources := {}
var _slow_scrap := 0.0
var _fast_scrap := 0.0
var _killing = null
var _slow_s := 0.0
var _fast_s := 0.0
var _slow_hull := 0.0
var _fast_hull := 0.0
var _fast := false
var _segment := ""
var _segments := {}
var _hull_spent := {"tick": {}, "stood": {}}
var _scrap_spent := {"tick": {}, "stood": {}}


static func _walk_up_config(start_dir: String) -> String:
	var dir := start_dir
	for _depth in range(7):
		var candidate := dir.path_join(CONFIG_FILE).simplify_path()
		if FileAccess.file_exists(candidate):
			return candidate
		var parent := dir.path_join("..").simplify_path()
		if parent == dir:
			break
		dir = parent
	return ""


static func resolve_config_path(env_root := "", res_root := "", cwd_root := "") -> String:
	var fallback := ""
	if env_root != "":
		var from_env := env_root.path_join(CONFIG_FILE).simplify_path()
		if FileAccess.file_exists(from_env):
			return from_env
		fallback = from_env
	if res_root != "":
		var from_res := res_root.path_join("../../" + CONFIG_FILE).simplify_path()
		if FileAccess.file_exists(from_res):
			return from_res
		if fallback == "":
			fallback = from_res
	if cwd_root != "":
		var found := _walk_up_config(cwd_root)
		if found != "":
			return found
		if fallback == "":
			fallback = cwd_root.path_join(CONFIG_FILE).simplify_path()
	return fallback if fallback != "" else CONFIG_FILE


static func config() -> Dictionary:
	if _config.is_empty():
		var env_root := OS.get_environment("SCRAPKEEP_REPO_ROOT")
		var res_root := ProjectSettings.globalize_path("res://")
		var cwd_dir := DirAccess.open(".")
		var cwd_root := cwd_dir.get_current_dir() if cwd_dir != null else ProjectSettings.globalize_path(".")
		var path := resolve_config_path(env_root, res_root, cwd_root)
		if not FileAccess.file_exists(path):
			var exe_dir := OS.get_executable_path().get_base_dir()
			if exe_dir != "" and exe_dir != cwd_root:
				var from_exe := resolve_config_path("", "", exe_dir)
				if FileAccess.file_exists(from_exe):
					path = from_exe
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if parsed is Dictionary:
			_config = parsed
		else:
			push_error("bot_fairness: cannot read %s" % path)
	return _config


func setup(game_ref, boss_hazards_call: Callable) -> void:
	game = game_ref
	boss_hazards = boss_hazards_call


func tick(delta: float) -> void:
	_clock += delta
	_hull_spent["tick"].clear()
	_scrap_spent["tick"].clear()
	var flow = game.flow
	var in_boss: bool = flow.state_name() == "boss"
	if not (flow.in_stage() or in_boss) or not game.run.alive():
		_prev = []
		_hull_spent["stood"].clear()
		_scrap_spent["stood"].clear()
		return
	_open_segment("boss" if in_boss else "s%d" % int(game.run.stage))
	_fast = game.player.planar_velocity().length() >= game.player.tuning.f("cruise")
	if _fast:
		_fast_s += delta
	else:
		_slow_s += delta
	_prev = _scan(true)
	var seg: Dictionary = _segments[_segment]
	if seg["contact_s"] == null and _enemy_near():
		seg["contact_s"] = _clock


func _open_segment(key: String) -> void:
	if key == _segment:
		return
	_segment = key
	if not _segments.has(key):
		_segments[key] = {"contact_s": null, "first_hit_s": null, "opened_by_hit": false}


func _enemy_near() -> bool:
	var ball: Vector3 = game.player.ball_position()
	var reach: float = float(config()["contactM"])
	for node in game.get_tree().get_nodes_in_group(Groups.ENEMY):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if ball.distance_to(node.global_position) <= reach:
			return true
	return false


func _scan(mark: bool) -> Array:
	var out: Array = []
	var ids := {}
	var ball: Vector3 = game.player.ball_position()
	for node in game.get_tree().get_nodes_in_group(Groups.ENEMY):
		if is_instance_valid(node) and node.has_method("telegraph"):
			var t = node.telegraph()
			if t != null:
				_add(out, ids, t, String(node.get("kind")), ball, mark)
	for child in game.get_children():
		if child.is_queued_for_deletion():
			continue
		if child.get_script() == TelegraphScript:
			_add(out, ids, child, "", ball, mark)
		elif child.get_script() != null and String(child.get_script().resource_path).ends_with("projectile.gd"):
			var ring = child.get("ring")
			if ring != null and is_instance_valid(ring):
				_add(out, ids, ring, "lobber", ball, mark)
	for node in game.get_tree().get_nodes_in_group(Groups.WORLD_TELEGRAPHS):
		if is_instance_valid(node) and node.has_method("telegraphs"):
			for t in node.telegraphs(ball):
				_add_row(out, ids, int(t["id"]), "world", String(t["cause"]), bool(t["covers"]), mark)
	if boss_hazards.is_valid():
		for h in boss_hazards.call():
			if is_instance_valid(h) and h.has_method("contains"):
				_add(out, ids, h, "boss", ball, mark, String(h.get("attack_id")))
	if mark and _seen.size() > 64:
		for id in _seen.keys():
			if not ids.has(id):
				_seen.erase(id)
	if mark:
		for spent in [_hull_spent, _scrap_spent]:
			var stood: Dictionary = spent["stood"]
			for id in stood.keys():
				if not ids.has(id):
					stood.erase(id)
	return out


func _add(out: Array, ids: Dictionary, t: Object, owner: String, ball: Vector3, mark: bool, attack := "") -> void:
	_add_row(out, ids, t.get_instance_id(), owner, attack, t.has_method("contains") and t.contains(ball), mark)


func _add_row(out: Array, ids: Dictionary, id: int, owner: String, attack: String, covers: bool, mark: bool) -> void:
	if ids.has(id):
		return
	ids[id] = true
	if not _seen.has(id):
		if not mark:
			return
		_seen[id] = _clock
	if owner != "":
		_published[owner] = true
	out.append({"id": id, "owner": owner, "attack": attack, "age_s": _clock - float(_seen[id]), "covers": covers})


func hit(source: String, hull: float, warning_id := 0) -> void:
	var bucket := _charge(source, warning_id, _hull_spent)
	_hull[bucket] = float(_hull[bucket]) + hull
	_sources[source] = float(_sources.get(source, 0.0)) + hull
	_killing = {"source": source, "bucket": bucket}
	if _fast:
		_fast_hull += hull
	else:
		_slow_hull += hull
	_note_first_hit()


func _charge(source: String, warning_id: int, spent: Dictionary) -> String:
	var matched := classify_with_id(source, _scan(false), _prev, _published, {}, warning_id, spent["tick"], spent["stood"])
	var matched_id := int(matched["matched_id"])
	if matched_id != 0:
		spent["tick"][matched_id] = true
		spent["stood"][matched_id] = true
	return String(matched["bucket"])


func _note_first_hit() -> void:
	if _segment != "":
		var seg: Dictionary = _segments[_segment]
		if seg["first_hit_s"] == null:
			if seg["contact_s"] == null:
				seg["opened_by_hit"] = true
				seg["contact_s"] = _clock
			seg["first_hit_s"] = _clock


func loss(cause: String, amount: float, warning_id := 0) -> void:
	if amount <= 0.0:
		return
	var bucket := _charge(cause, warning_id, _scrap_spent)
	_scrap[bucket] = float(_scrap[bucket]) + amount
	_scrap_sources[cause] = float(_scrap_sources.get(cause, 0.0)) + amount
	if _fast:
		_fast_scrap += amount
	else:
		_slow_scrap += amount
	if _segment != "" and _segments[_segment]["contact_s"] != null:
		_note_first_hit()


static func classify_with_id(
	source: String,
	now: Array,
	before: Array,
	published: Dictionary,
	cfg := {},
	warning_id := 0,
	consumed_ids := {},
	credited_ids := {}
) -> Dictionary:
	if cfg.is_empty():
		cfg = config()
	if source in cfg.get("plantSources", []):
		return {"bucket": "untelegraphed", "matched_id": 0}
	if source in cfg.get("contactSources", []):
		return {"bucket": "contact", "matched_id": 0}
	var mine := _owner_match(source, published, cfg)
	if not mine.is_valid():
		return {"bucket": "unknown", "matched_id": 0}
	var tell: float = float(cfg["tellS"])
	var young_id := 0
	var credited_id := 0
	for row in now + before:
		var row_id := int(row.get("id", 0))
		if warning_id != 0 and row_id != warning_id:
			continue
		if warning_id == 0 and row_id != 0 and consumed_ids.has(row_id):
			continue
		if not (mine.call(row) and bool(row["covers"])):
			continue
		var credited: bool = warning_id == 0 and row_id != 0 and credited_ids.has(row_id)
		if float(row["age_s"]) >= tell:
			if not credited:
				return {"bucket": "telegraphed", "matched_id": row_id}
			if credited_id == 0:
				credited_id = row_id
		elif not credited and young_id == 0:
			young_id = row_id
	if young_id != 0 and warning_id == 0:
		return {"bucket": "untelegraphed", "matched_id": young_id}
	if credited_id != 0:
		return {"bucket": "telegraphed", "matched_id": credited_id}
	return {"bucket": "untelegraphed", "matched_id": 0}


static func classify(
	source: String,
	now: Array,
	before: Array,
	published: Dictionary,
	cfg := {},
	warning_id := 0,
	consumed_ids := {},
	credited_ids := {}
) -> String:
	return String(classify_with_id(source, now, before, published, cfg, warning_id, consumed_ids, credited_ids)["bucket"])


static func _owner_match(source: String, published: Dictionary, cfg: Dictionary) -> Callable:
	var attacks: Dictionary = cfg.get("bossAttacks", {})
	if attacks.has(source):
		var prefixes: Array = attacks[source]
		return func(row: Dictionary) -> bool:
			if row["owner"] != "boss":
				return false
			for prefix in prefixes:
				if String(row.get("attack", "")).begins_with(String(prefix)):
					return true
			return false
	if source in cfg.get("worldCauses", []):
		return func(row: Dictionary) -> bool: return row["owner"] == "world" and row["attack"] == source
	if source in cfg.get("unownedSources", []):
		return func(row: Dictionary) -> bool: return row["owner"] == ""
	if source != "" and (published.has(source) or not TelegraphRecord.row_of(source).is_empty()):
		return func(row: Dictionary) -> bool: return row["owner"] == source
	return Callable()


func record(died: bool) -> Dictionary:
	var shown: float = float(_hull["telegraphed"])
	var hidden: float = float(_hull["untelegraphed"])
	var pooled_shown: float = shown + float(_scrap["telegraphed"])
	var pooled_hidden: float = hidden + float(_scrap["untelegraphed"])
	var first := {}
	for key in _segments:
		var seg: Dictionary = _segments[key]
		var after = null
		if seg["first_hit_s"] != null and not seg["opened_by_hit"]:
			after = snappedf(float(seg["first_hit_s"]) - float(seg["contact_s"]), 0.01)
		first[key] = {"contact": seg["contact_s"] != null, "first_hit_s": after, "opened_by_hit": seg["opened_by_hit"], "hit": seg["first_hit_s"] != null}
	var total := 0.0
	for k in _hull:
		total += float(_hull[k])
	return {
		"hull": {"telegraphed": snappedf(shown, 0.1), "untelegraphed": snappedf(hidden, 0.1), "contact": snappedf(float(_hull["contact"]), 0.1), "unknown": snappedf(float(_hull["unknown"]), 0.1)},
		"telegraph_share": snappedf(shown / (shown + hidden), 0.001) if shown + hidden > 0.0 else null,
		"pooled_share": snappedf(pooled_shown / (pooled_shown + pooled_hidden), 0.001) if pooled_shown + pooled_hidden > 0.0 else null,
		"killing_hit": _killing if died and _killing != null else null,
		"hit_sources": _round_all(_sources),
		"scrap": {"telegraphed": snappedf(float(_scrap["telegraphed"]), 0.1), "untelegraphed": snappedf(float(_scrap["untelegraphed"]), 0.1), "contact": snappedf(float(_scrap["contact"]), 0.1), "unknown": snappedf(float(_scrap["unknown"]), 0.1)},
		"scrap_sources": _round_all(_scrap_sources),
		"slow_s": snappedf(_slow_s, 0.01), "fast_s": snappedf(_fast_s, 0.01),
		"slow_hull": snappedf(_slow_hull, 0.1), "fast_hull": snappedf(_fast_hull, 0.1),
		"stop_tax": snappedf((_slow_hull / _slow_s) / (_fast_hull / _fast_s), 0.001) if _slow_s > 0.0 and _fast_s > 0.0 and _fast_hull > 0.0 else null,
		"slow_scrap": snappedf(_slow_scrap, 0.1), "fast_scrap": snappedf(_fast_scrap, 0.1),
		"pooled_stop_tax": snappedf(((_slow_hull + _slow_scrap) / _slow_s) / ((_fast_hull + _fast_scrap) / _fast_s), 0.001) if _slow_s > 0.0 and _fast_s > 0.0 and _fast_hull + _fast_scrap > 0.0 else null,
		"first_hit": first,
		"hull_lost": snappedf(total, 0.1),
	}


static func baseline(f: Dictionary) -> Dictionary:
	var tax = f.get("stop_tax")
	var out := {"share": share_of(f), "stop_tax": -1.0, "first_hit": first_hit_of(f), "miss": ""}
	if tax == null:
		out["miss"] = "plain baseline measured no stop tax"
	else:
		out["stop_tax"] = float(tax)
	return out


static func share_of(f: Dictionary) -> float:
	var v = f.get("telegraph_share")
	return float(v) if v != null else -1.0


static func first_hit_of(f: Dictionary) -> float:
	var hits = f.get("first_hit")
	var seg = hits.get("s1") if hits is Dictionary else null
	if not seg is Dictionary or seg.get("first_hit_s") == null:
		return -1.0
	return float(seg["first_hit_s"])


static func pool(records: Array) -> Dictionary:
	var hull := {"telegraphed": 0.0, "untelegraphed": 0.0, "contact": 0.0, "unknown": 0.0}
	var scrap := {"telegraphed": 0.0, "untelegraphed": 0.0, "contact": 0.0, "unknown": 0.0}
	var hit_sources := {}
	var scrap_sources := {}
	var slow_s := 0.0
	var fast_s := 0.0
	var slow_hull := 0.0
	var fast_hull := 0.0
	var slow_scrap := 0.0
	var fast_scrap := 0.0
	var hull_lost := 0.0
	var seg_hits := {}
	for rec in records:
		if not rec is Dictionary:
			continue
		var rh: Dictionary = rec.get("hull", {})
		for k in hull:
			hull[k] = float(hull[k]) + float(rh.get(k, 0.0))
		var rs: Dictionary = rec.get("scrap", {})
		for k in scrap:
			scrap[k] = float(scrap[k]) + float(rs.get(k, 0.0))
		var hs: Dictionary = rec.get("hit_sources", {})
		for k in hs:
			hit_sources[k] = float(hit_sources.get(k, 0.0)) + float(hs[k])
		var ss: Dictionary = rec.get("scrap_sources", {})
		for k in ss:
			scrap_sources[k] = float(scrap_sources.get(k, 0.0)) + float(ss[k])
		slow_s += float(rec.get("slow_s", 0.0))
		fast_s += float(rec.get("fast_s", 0.0))
		slow_hull += float(rec.get("slow_hull", 0.0))
		fast_hull += float(rec.get("fast_hull", 0.0))
		slow_scrap += float(rec.get("slow_scrap", 0.0))
		fast_scrap += float(rec.get("fast_scrap", 0.0))
		hull_lost += float(rec.get("hull_lost", 0.0))
		var fh = rec.get("first_hit", {})
		if fh is Dictionary:
			for seg_key in fh:
				var seg = fh[seg_key]
				if not seg is Dictionary:
					continue
				if not seg_hits.has(seg_key):
					seg_hits[seg_key] = {"contact": false, "hit": false, "opened_by_hit": false, "values": []}
				var acc: Dictionary = seg_hits[seg_key]
				acc["contact"] = bool(acc["contact"]) or bool(seg.get("contact", false))
				acc["hit"] = bool(acc["hit"]) or bool(seg.get("hit", false))
				acc["opened_by_hit"] = bool(acc["opened_by_hit"]) or bool(seg.get("opened_by_hit", false))
				if seg.get("first_hit_s") != null:
					(acc["values"] as Array).append(float(seg["first_hit_s"]))
	var first := {}
	for seg_key in seg_hits:
		var acc: Dictionary = seg_hits[seg_key]
		var vals: Array = acc["values"]
		var med = null
		if not vals.is_empty():
			vals.sort()
			var n := vals.size()
			med = snappedf(float(vals[n / 2]) if n % 2 == 1 else (float(vals[n / 2 - 1]) + float(vals[n / 2])) * 0.5, 0.01)
		first[seg_key] = {
			"contact": acc["contact"],
			"first_hit_s": med,
			"opened_by_hit": acc["opened_by_hit"],
			"hit": acc["hit"],
		}
	var shown := float(hull["telegraphed"])
	var hidden := float(hull["untelegraphed"])
	var pooled_shown := shown + float(scrap["telegraphed"])
	var pooled_hidden := hidden + float(scrap["untelegraphed"])
	return {
		"seeds": records.size(),
		"hull": {"telegraphed": snappedf(shown, 0.1), "untelegraphed": snappedf(hidden, 0.1), "contact": snappedf(float(hull["contact"]), 0.1), "unknown": snappedf(float(hull["unknown"]), 0.1)},
		"telegraph_share": snappedf(shown / (shown + hidden), 0.001) if shown + hidden > 0.0 else null,
		"pooled_share": snappedf(pooled_shown / (pooled_shown + pooled_hidden), 0.001) if pooled_shown + pooled_hidden > 0.0 else null,
		"hit_sources": _round_all(hit_sources),
		"scrap": {"telegraphed": snappedf(float(scrap["telegraphed"]), 0.1), "untelegraphed": snappedf(float(scrap["untelegraphed"]), 0.1), "contact": snappedf(float(scrap["contact"]), 0.1), "unknown": snappedf(float(scrap["unknown"]), 0.1)},
		"scrap_sources": _round_all(scrap_sources),
		"slow_s": snappedf(slow_s, 0.01), "fast_s": snappedf(fast_s, 0.01),
		"slow_hull": snappedf(slow_hull, 0.1), "fast_hull": snappedf(fast_hull, 0.1),
		"stop_tax": snappedf((slow_hull / slow_s) / (fast_hull / fast_s), 0.001) if slow_s > 0.0 and fast_s > 0.0 and fast_hull > 0.0 else null,
		"slow_scrap": snappedf(slow_scrap, 0.1), "fast_scrap": snappedf(fast_scrap, 0.1),
		"pooled_stop_tax": snappedf(((slow_hull + slow_scrap) / slow_s) / ((fast_hull + fast_scrap) / fast_s), 0.001) if slow_s > 0.0 and fast_s > 0.0 and fast_hull + fast_scrap > 0.0 else null,
		"first_hit": first,
		"hull_lost": snappedf(hull_lost, 0.1),
	}


static func _round_all(by: Dictionary) -> Dictionary:
	var out := {}
	for k in by:
		out[k] = snappedf(float(by[k]), 0.1)
	return out
