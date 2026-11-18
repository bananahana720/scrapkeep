extends RefCounted

const TelegraphScript := preload("res://src/combat/telegraph.gd")
const TelegraphRecord := preload("res://src/combat/telegraph_record.gd")

# The bot record's fairness numbers (project-guide/handoff/shared/world1/difficulty-plan.md rows F1 to F3), read from what the
# simulation already publishes. It steers nothing, draws no random number and writes nothing in the game: the driver calls
# tick() once a physics tick, hit() on every player_hit and record() once into the run's row. The pass lines, the tell time and
# the source lists live once, in scripts/challenge/fairness.json, which scripts/challenge/lib.mjs reads too.
#
# F1 splits hull lost by the hit's own source (hit(), classify()). Each bucket has one positive condition; unknown is the rest:
#   untelegraphed a planted source (plantSources), or a source with a telegraph owner and none of its own over the ball in time
#   contact       a source on contactSources (body contact and ram, no telegraph by design): beside F1, outside its share
#   telegraphed   a source with a telegraph owner, and a telegraph of its own covered the ball, up for at least tellS
#   unknown       anything else: no telegraph owner to match, so F1 loses its mark when this is over unknownMaxShare
# A source has a telegraph owner when it is a boss attack on bossAttacks (matched to hazards of that attack only), an
# unownedSources name (matched to telegraphs nothing claims), a kind seen publishing this run, or a TelegraphRecord row.
# Hit sources carry only the enemy kind, so two machines of one kind share one owner: a chaser hit under another chaser's
# old lane reads telegraphed.
# Scrap taken through run.lose_scrap is read the same way (loss()), by the cause lose_scrap carries, into its own buckets beside
# the hull's: worldCauses (lightning, impact, boiler_burst, reactor_blow, flood, cave_in) are matched to the telegraph of that
# cause that world events publish (their telegraphs(ball), group world_telegraphs: a natural mark, an industrial Hazard, a
# rubble fall's disc, a flood's water, the storm's sought ring), and a boss cause (crane) to the boss hazard of that attack. A
# scrap point counts as one hull point. Nothing pooled may make a line easier (ruling cu), so each line is two readings and
# fails when either is under it: F1 telegraph_share stays hull only and pooled_share adds scrap; F2 stop_tax stays hull only and
# pooled_stop_tax adds the scrap lost slow and fast (slow_scrap, fast_scrap); F3 counts a theft as a hit, so a stage's first hit
# is the earlier of the first hull hit and the first theft. The hull buckets sum to hull_lost; scrap has its own buckets.
# One cause serves two lightning tells, the fixed strike circle and the storm's sought ring. That is safe: the circle counts
# only while the ball is inside it, where it has stood drawn since the row's announcement, and a sought ring covers the ball
# from its own age, so a sought strike under a young ring reads untelegraphed unless the ball stood inside the fixed circle,
# where it was told anyway.
# F1 = telegraphed / (telegraphed + untelegraphed). A telegraph's age is how long it has stood, so a lane entered late is judged
# on the lane's age as it is now. Every published telegraph is read, the steering's own filters (amber, wider than the field
# radius) do not apply here.

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


# The shared lines. A missing or unreadable file is an error, not a default: a reading on guessed lines is worse than none.
static func config() -> Dictionary:
	if _config.is_empty():
		var path := ProjectSettings.globalize_path("res://").path_join("../../" + CONFIG_FILE).simplify_path()
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if parsed is Dictionary:
			_config = parsed
		else:
			push_error("bot_fairness: cannot read %s" % path)
	return _config


func setup(game_ref, boss_hazards_call: Callable) -> void:
	game = game_ref
	boss_hazards = boss_hazards_call


# --- once a tick ---------------------------------------------------------------------------

func tick(delta: float) -> void:
	_clock += delta
	var flow = game.flow
	var in_boss: bool = flow.state_name() == "boss"
	if not (flow.in_stage() or in_boss) or not game.run.alive():
		_prev = []
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
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if ball.distance_to(node.global_position) <= reach:
			return true
	return false


# Every published telegraph as {id, owner, attack, age_s, covers}. owner is the enemy kind or "lobber" for a shell's ring,
# "boss" for a boss hazard and "" for one nothing publishes an owner for; attack is a boss hazard's attack_id, else "".
# mark records first sightings (a hit's scan does not).
func _scan(mark: bool) -> Array:
	var out: Array = []
	var ids := {}
	var ball: Vector3 = game.player.ball_position()
	for node in game.get_tree().get_nodes_in_group("enemy"):
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
	for node in game.get_tree().get_nodes_in_group("world_telegraphs"):
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
	return out


func _add(out: Array, ids: Dictionary, t: Object, owner: String, ball: Vector3, mark: bool, attack := "") -> void:
	_add_row(out, ids, t.get_instance_id(), owner, attack, t.has_method("contains") and t.contains(ball), mark)


func _add_row(out: Array, ids: Dictionary, id: int, owner: String, attack: String, covers: bool, mark: bool) -> void:
	if ids.has(id):
		# An enemy's own telegraph is also a child of the game: the owner read first wins.
		return
	ids[id] = true
	if not _seen.has(id):
		if not mark:
			return
		_seen[id] = _clock
	if owner != "":
		_published[owner] = true
	out.append({"id": id, "owner": owner, "attack": attack, "age_s": _clock - float(_seen[id]), "covers": covers})


# --- a hit ---------------------------------------------------------------------------------

func hit(source: String, hull: float) -> void:
	var now: Array = _scan(false)
	var bucket := classify(source, now, _prev, _published)
	_hull[bucket] = float(_hull[bucket]) + hull
	_sources[source] = float(_sources.get(source, 0.0)) + hull
	_killing = {"source": source, "bucket": bucket}
	if _fast:
		_fast_hull += hull
	else:
		_slow_hull += hull
	_note_first_hit()


# The stage's (or boss fight's) first hit: a hull hit or a theft of scrap, whichever comes first.
func _note_first_hit() -> void:
	if _segment != "":
		var seg: Dictionary = _segments[_segment]
		if seg["first_hit_s"] == null:
			if seg["contact_s"] == null:
				seg["opened_by_hit"] = true
				seg["contact_s"] = _clock
			seg["first_hit_s"] = _clock


# Scrap taken from the ball, from the run's scrap_lost fact (amount actually taken, cause). The same rule as a hit, with the cause
# as the source. Nothing taken is nothing lost.
func loss(cause: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var bucket := classify(cause, _scan(false), _prev, _published)
	_scrap[bucket] = float(_scrap[bucket]) + amount
	_scrap_sources[cause] = float(_scrap_sources.get(cause, 0.0)) + amount
	if _fast:
		_fast_scrap += amount
	else:
		_slow_scrap += amount
	_note_first_hit()


# The bucket for one hit. `now` and `before` are _scan() rows (this tick's read and the last tick's, because a telegraph can
# free itself as it lands); `published` is the set of owners seen to publish a telegraph this run. `cfg` is the shared file's
# lines unless a fixture passes its own. Pure: the fixtures call it. The order is the rule (see the file header):
#   1. a planted source is untelegraphed
#   2. a source on contactSources is contact
#   3. a source with a telegraph owner is telegraphed when a row of its own covers the ball and is tellS old, else untelegraphed
#   4. anything else is unknown
static func classify(source: String, now: Array, before: Array, published: Dictionary, cfg := {}) -> String:
	if cfg.is_empty():
		cfg = config()
	if source in cfg.get("plantSources", []):
		return "untelegraphed"
	if source in cfg.get("contactSources", []):
		return "contact"
	var mine := _owner_match(source, published, cfg)
	if not mine.is_valid():
		return "unknown"
	var tell: float = float(cfg["tellS"])
	for row in now + before:
		if mine.call(row) and bool(row["covers"]) and float(row["age_s"]) >= tell:
			return "telegraphed"
	return "untelegraphed"


# (row) -> bool: whether a _scan() row is the hit source's own telegraph, or an invalid Callable when the source has no
# telegraph owner to match. A boss attack owns only hazards of that attack (bossAttacks: attack_id prefixes), an unowned
# source owns the telegraphs nothing claims, and an enemy kind owns the rows published under its kind.
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


# --- the record ----------------------------------------------------------------------------

# died: whether the run ended in death. The killing hit is null on a death with no hit behind it.
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


static func _round_all(by: Dictionary) -> Dictionary:
	var out := {}
	for k in by:
		out[k] = snappedf(float(by[k]), 0.1)
	return out
