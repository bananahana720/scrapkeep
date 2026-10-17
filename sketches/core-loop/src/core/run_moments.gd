extends Node

# The run-end comic page's moments (Andrew's Q11, 17 Oct 2026: "Page plus camp scrapbook").
# It listens to the bus, keeps the best candidate of each moment kind with a viewport still,
# and at run_ended folds them into one page document of 4 to 6 panels in run order. The camp
# thread owns drawing pages and the scrapbook store; this file owns what goes on a page.
#
# Page document (schema 1), the contract the scrapbook reads:
#   {schema, run_id, ended_unix, pilot, pilot_name, won, stage_reached, world, world_name,
#    title, panels: [4..6 panel rows in run order]}
#   panel: {kind, t, stage, world, world_name, caption, sfx, size, facts, shot}
# kind is one of KINDS. caption is the narrator box (TONE-BIBLE: deadpan words, loud
# pictures), sfx the drawn sound word ("" for none), size a layout hint (wide, tall,
# square), facts a small dict of numbers, shot an Image (SHOT_WIDTH wide, null headless or
# when no still was taken). save() writes the page JSON with each shot as a PNG beside it
# ("shot" becomes the PNG's file name) under <storage_dir>/scrapbook/<run_id>/.
#
# Every run has an opening and a finale; the middle takes up to four of the rest by PRIORITY,
# and the ledger and top speed always exist, so a page is never under four panels.

const Worlds := preload("res://src/core/worlds.gd")
const Parts := preload("res://src/build/parts.gd")
const SafeStore := preload("res://src/core/safe_store.gd")

const SCHEMA := 1
const DIR := "scrapbook"
const PAGE_FILE := "page.json"
const MIN_PANELS := 4
const MAX_PANELS := 6
const SHOT_WIDTH := 480
# A still is a frame readback; keep them rare. A better candidate of the same kind replaces
# the held one only by this margin, and never sooner than SHOT_GAP seconds after any still.
const SHOT_GAP := 1.0
const BETTER_BY := 1.25
# The opening still waits this long into the first stage so the ball is in the world.
const OPENING_AFTER := 1.5
# A hit that leaves the hull at or under this share is a near-death.
const NEAR_DEATH := 0.35
const FINALE_RUNUP := 3.0
const SAME_BEAT := 3.0
# Whole-run tallies, not beats: never crowded out by the same-beat rule.
const SUMMARY_KINDS := ["top_speed", "ledger"]
const KINDS := ["opening", "key_item", "biggest_hit", "set_piece", "near_death", "boss_stagger", "top_speed", "ledger", "finale"]
# Middle panels, most wanted first.
const PRIORITY := ["boss_stagger", "biggest_hit", "near_death", "key_item", "set_piece", "top_speed", "ledger"]
const SIZES := {"opening": "wide", "finale": "wide", "boss_stagger": "tall"}

# Narrator boxes: a tired comic-book narrator over loud pictures. One line per kind is
# picked by the run id, so a run's page reads the same every time it is opened.
# TONE-READ: run-end captions, every line awaits Andrew's read.
const CAPTIONS := {
	"opening": ["Meanwhile, at %s.", "%s. Another shift.", "Our story begins at %s. Again."],
	"key_item": ["%s acquired. It fit. Mostly.", "%s. Nobody read the manual.", "Found: %s. Signed for it."],
	"biggest_hit": ["Impact %s. Paperwork to follow.", "%s units of opinion.", "Hit %s. Somebody felt that."],
	"set_piece": ["%s caught in one go. Show-off.", "%s at once. Nobody counted. We counted."],
	"near_death": ["Hull at %s. This is the tense part.", "%s hull. Moss packed a spare.", "Down to %s. Totally fine."],
	"retried": ["Scrapped. Retried. Nobody mentions it.", "That didn't happen. Next take."],
	"boss_stagger": ["%s, staggered.", "%s wobbled. Write it down.", "%s, briefly reconsidering."],
	"top_speed": ["%s m/s. Over the posted limit.", "Clocked at %s m/s. No ticket issued."],
	"ledger": ["%s machines clocked out early.", "Ledger: %s off shift."],
	"won": ["And that was that. For now.", "Run complete. Somebody make tea.", "The end. Probably."],
	"lost": ["This is the sad part.", "Tragic, right?", "To be continued. Unfortunately."],
}
const SFX := {
	"opening": "", "key_item": "KA-CHUNK", "biggest_hit": "KLANG!", "set_piece": "KRA-KOOM!",
	"near_death": "CREAK", "retried": "clonk", "boss_stagger": "WOBBLE", "top_speed": "FWOOSH",
	"ledger": "", "won": "TA-DA", "lost": "fzzt",
}

var events
var run
var player
var flow
var stages
var storage_dir := "user://"
# Stills need a renderer; tests may switch them off on a display.
var stills := true
# The last page finished by run_ended, and where save() put it ("" when unsaved).
var last_page := {}
var last_page_path := ""

var _best := {}
var _staggered := {}
var _pending_death := {}
var _boss_down := {}
var _opening_due := false
var _shot_wait := 0.0
var _shot_for := ""
var _top_speed := 0.0


func setup(events_ref, run_ref, player_ref, flow_ref, stages_ref, dir: String) -> void:
	name = "RunMoments"
	events = events_ref
	run = run_ref
	player = player_ref
	flow = flow_ref
	stages = stages_ref
	storage_dir = dir
	events.run_started.connect(func(_class_id: String): _reset())
	events.stage_entered.connect(_on_stage_entered)
	events.enemy_struck.connect(_on_enemy_struck)
	events.ultimate_landed.connect(_on_ultimate_landed)
	events.player_hit.connect(_on_player_hit)
	events.player_died.connect(_on_player_died)
	events.part_gained.connect(func(part_id: String, _source: String): _on_part(part_id, 0))
	events.evolution_fired.connect(func(part_id: String): _on_part(part_id, 1))
	events.posture_changed.connect(_on_posture_changed)
	events.boss_defeated.connect(_on_boss_defeated)
	events.run_ended.connect(_on_run_ended)


func _reset() -> void:
	_best.clear()
	_staggered.clear()
	_pending_death = {}
	_boss_down = {}
	_opening_due = false
	_shot_wait = 0.0
	_shot_for = ""
	_top_speed = 0.0
	last_page = {}
	last_page_path = ""


func _physics_process(delta: float) -> void:
	_shot_wait = maxf(0.0, _shot_wait - delta)
	if run == null or run.over or run.class_def == null:
		return
	if _opening_due and run.stage_time >= OPENING_AFTER:
		_opening_due = false
		_offer("opening", 1.0, {})
	if player != null and player.state != null:
		var v: Vector3 = player.state.velocity
		var planar := Vector2(v.x, v.z).length()
		if planar > _top_speed:
			_top_speed = planar
			# The still waits for a lead worth framing, not every new decimal.
			_offer("top_speed", planar, {"speed": snappedf(planar, 0.1)})


func _on_stage_entered(stage: int, retry: bool) -> void:
	if retry and not _pending_death.is_empty():
		_pending_death["caption_kind"] = "retried"
		_keep("near_death", _pending_death)
	_pending_death = {}
	if not _best.has("opening") and stage == _first_stage():
		_opening_due = true


func _on_enemy_struck(_enemy: Node3D, kind: String, force: float) -> void:
	_offer("biggest_hit", force, {"force": roundi(force), "strike": kind})


func _on_ultimate_landed(ultimate_id: String, _at: Vector3, hits: int, damage: float) -> void:
	if hits >= 2:
		_offer("set_piece", float(hits), {"hits": hits, "damage": roundi(damage), "ultimate": ultimate_id})


func _on_player_hit(_amount: float, _source: String) -> void:
	if run.max_hp <= 0.0 or run.hp <= 0.0:
		return
	var share: float = run.hp / run.max_hp
	if share <= NEAR_DEATH:
		# Lower is better: the score is how close to zero it came.
		_offer("near_death", 1.0 - share, {"hull": roundi(share * 100.0)})


func _on_player_died() -> void:
	_pending_death = _moment("near_death", 1.0, {"hull": 0})
	_grab_into(_pending_death, true)


func _on_part(part_id: String, evolved: int) -> void:
	var d: Resource = Parts.def(part_id)
	var tier: int = d.tier if d != null else 1
	_offer("key_item", float(tier + evolved * 3), {"part": part_id, "name": Parts.display_name(part_id), "tier": tier, "evolved": evolved == 1})


func _on_posture_changed(enemy: Node3D, _posture: float, staggered: bool) -> void:
	if enemy == null:
		return
	var id := enemy.get_instance_id()
	var was: bool = _staggered.get(id, false)
	_staggered[id] = staggered
	if not staggered or was:
		return
	var boss := flow != null and bool(flow.get("in_arena"))
	# An arena boss outranks any park Warden and a later world an earlier one; within one
	# fight the first stagger holds, the turn of the fight rather than the last blow.
	_offer("boss_stagger", (200.0 if boss else 100.0) + _world_of(int(run.stage)), {"boss": boss, "who": _stagger_name(enemy, boss)}, true)


func _on_boss_defeated() -> void:
	_boss_down = _moment("finale", 1.0, {"boss": _boss_name()})
	_grab_into(_boss_down, true)


func _on_run_ended(won: bool) -> void:
	var finale: Dictionary
	if won:
		finale = _boss_down if not _boss_down.is_empty() else _moment("finale", 1.0, {})
	else:
		finale = _pending_death if not _pending_death.is_empty() else _moment("finale", 1.0, {})
	finale = finale.duplicate()
	finale["kind"] = "finale"
	finale["caption_kind"] = "won" if won else "lost"
	# On a loss the last few hits before the end are the finale's own run-up, not a panel.
	if not won and _best.has("near_death") and float(finale["t"]) - float(_best["near_death"]["t"]) < FINALE_RUNUP:
		_best.erase("near_death")
	_keep("ledger", _moment("ledger", 1.0, {"kills": int(run.kills), "scrap": int(run.scrap)}))
	last_page = build_page(won, finale)
	last_page_path = save(last_page)


# The page from the held moments: opening and finale bracket up to four middle panels by
# PRIORITY, every panel in run order.
func build_page(won: bool, finale: Dictionary) -> Dictionary:
	var middle: Array = []
	# A candidate on the same beat as a chosen panel (a stagger and the hit that caused it,
	# a hit a breath before the finale) yields to the next kind, so the page has range.
	var taken: Array = [float(finale["t"])]
	for kind in PRIORITY:
		if _best.has(kind) and middle.size() < MAX_PANELS - 2:
			var t := float(_best[kind]["t"])
			if kind not in SUMMARY_KINDS and taken.any(func(other: float): return absf(other - t) < SAME_BEAT):
				continue
			taken.append(t)
			middle.append(_best[kind])
	# The ledger is always held; a run too short for anything else still clocked a top speed.
	if middle.size() < MIN_PANELS - 2 and not _best.has("top_speed"):
		middle.append(_moment("top_speed", 0.0, {"speed": snappedf(_top_speed, 0.1)}))
	middle.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	var rows: Array = []
	if _best.has("opening"):
		rows.append(_best["opening"])
	else:
		rows.append(_moment("opening", 1.0, {}).merged({"t": 0.0, "stage": _first_stage(), "world": _world_of(_first_stage())}, true))
	rows.append_array(middle)
	rows.append(finale)
	var panels: Array = []
	for row in rows:
		panels.append(_panel(row))
	var world := _world_of(int(run.stage))
	return {
		"schema": SCHEMA,
		"run_id": String(run.run_id),
		"ended_unix": Time.get_unix_time_from_system(),
		"pilot": run.class_id(),
		"pilot_name": _pilot_name(),
		"won": won,
		"stage_reached": int(run.stage),
		"world": world,
		"world_name": _world_name(world),
		"title": _title(world, won),
		"panels": panels,
	}


func _panel(row: Dictionary) -> Dictionary:
	var kind := String(row["kind"])
	var said := String(row.get("caption_kind", kind))
	return {
		"kind": kind,
		"t": snappedf(float(row["t"]), 0.01),
		"stage": int(row["stage"]),
		"world": int(row["world"]),
		"world_name": _world_name(int(row["world"])),
		"caption": _caption(said, row),
		"sfx": String(SFX.get(said, "")),
		"size": String(SIZES.get(kind, "square")),
		"facts": row["facts"],
		"shot": row.get("shot"),
	}


# Writes the page JSON and each panel's still as panel-<n>.png beside it. Returns the JSON's
# path, or "" when the folder or file could not be written.
func save(page: Dictionary) -> String:
	var id := String(page.get("run_id", ""))
	if id == "":
		id = "run-%d" % int(page.get("ended_unix", 0.0))
	var dir := storage_dir.path_join(DIR).path_join(id)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		push_warning("run_moments: could not make %s" % dir)
		return ""
	var doc := page.duplicate(true)
	for i in doc["panels"].size():
		var panel: Dictionary = doc["panels"][i]
		var shot = page["panels"][i].get("shot")
		panel["shot"] = ""
		if shot is Image:
			var file := "panel-%d.png" % (i + 1)
			if (shot as Image).save_png(dir.path_join(file)) == OK:
				panel["shot"] = file
	var path := dir.path_join(PAGE_FILE)
	if SafeStore.write_atomic(path, JSON.stringify(doc, "\t")) != OK:
		push_warning("run_moments: could not write %s" % path)
		return ""
	return path


# A candidate of one kind: kept when it beats the held one (by BETTER_BY when the held one
# already has a still), and given a still when the gap allows.
func _offer(kind: String, score: float, facts: Dictionary, rare := false) -> void:
	var held: Dictionary = _best.get(kind, {})
	if not held.is_empty():
		var need := float(held["score"]) * (1.0 if rare or held.get("shot") == null else BETTER_BY)
		if score <= need:
			return
	var row := _moment(kind, score, facts)
	_keep(kind, row)
	_grab_into(row, rare)


func _keep(kind: String, row: Dictionary) -> void:
	_best[kind] = row


func _moment(kind: String, score: float, facts: Dictionary) -> Dictionary:
	var stage := int(run.stage)
	return {"kind": kind, "score": score, "t": float(run.run_time), "stage": stage, "world": _world_of(stage),
		"facts": facts, "shot": null}


# The still is read after the frame that shows the moment has drawn. A rare moment (a
# stagger, a death, a boss down) skips the gap.
func _grab_into(row: Dictionary, rare := false) -> void:
	if not stills or (_shot_wait > 0.0 and not rare) or DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	_shot_wait = SHOT_GAP
	RenderingServer.frame_post_draw.connect(func():
		var image := get_viewport().get_texture().get_image()
		if image == null or image.is_empty():
			return
		var h := maxi(1, roundi(float(SHOT_WIDTH) * image.get_height() / maxf(1.0, image.get_width())))
		image.resize(SHOT_WIDTH, h, Image.INTERPOLATE_BILINEAR)
		row["shot"] = image, CONNECT_ONE_SHOT)


func _caption(said: String, row: Dictionary) -> String:
	var pool: Array = CAPTIONS.get(said, [""])
	var line: String = pool[absi(hash(String(run.run_id) + said)) % pool.size()]
	if not line.contains("%s"):
		return line
	var facts: Dictionary = row["facts"]
	match said:
		"opening":
			return line % _world_name(int(row["world"]))
		"key_item":
			return line % String(facts.get("name", "A part"))
		"biggest_hit":
			return line % str(facts.get("force", 0))
		"set_piece":
			return line % ("%d machines" % int(facts.get("hits", 0)))
		"near_death":
			return line % ("%d%%" % int(facts.get("hull", 0)))
		"boss_stagger":
			return line % String(facts.get("who", "The Warden"))
		"top_speed":
			return line % str(facts.get("speed", 0))
		"ledger":
			return line % str(facts.get("kills", 0))
	return line.replace("%s", "")


func _title(world: int, won: bool) -> String:
	var place := _world_name(world).to_upper().trim_prefix("THE ")
	var count := 1 + absi(hash(String(run.run_id))) % 99
	return "SCRAPKEEP #%d: %s" % [count, ("THE %s JOB" % place) if won else ("TROUBLE AT %s" % place)]


func _stagger_name(enemy: Node3D, boss: bool) -> String:
	if boss:
		return _boss_name()
	var family = enemy.get("family")
	return "The %s Warden" % String(family).capitalize() if family != null and String(family) != "" else "The Warden"


func _boss_name() -> String:
	var world := _world_of(int(run.stage))
	var row: Dictionary = flow.boss_row(world) if flow != null and flow.has_method("boss_row") else Worlds.boss_of(world)
	return String(row.get("name", "The boss"))


func _pilot_name() -> String:
	var def: Resource = run.class_def
	return String(def.display_name) if def != null and String(def.display_name) != "" else run.class_id().capitalize()


func _first_stage() -> int:
	return int(stages.DEFS[0]["stage"]) if stages != null and not stages.DEFS.is_empty() else 1


func _world_of(stage: int) -> int:
	return int(stages.world_of(stage)) if stages != null else 1


func _world_name(world: int) -> String:
	for row in Worlds.ROWS:
		if int(row["id"]) == world:
			return String(row["name"])
	return "the works"
