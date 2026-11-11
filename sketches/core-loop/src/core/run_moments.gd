extends Node

# The run-end comic page's moments (Andrew's Q11, 17 Oct 2026: "Page plus camp scrapbook").
# It listens to the bus, keeps the best candidate of each moment kind with a viewport still,
# and at run_ended folds them into one page document of 4 to 6 panels in run order. The camp
# thread owns drawing pages and the scrapbook store; this file owns what goes on a page.
#
# Page document (schema 1), the contract the scrapbook reads:
#   {schema, run_id, ended_unix, pilot, pilot_name, won, outcome, stage_reached, world,
#    world_name, title, panels: [4..6 panel rows in run order]}
# outcome is "won" or "lost": a page folds only at run_ended, so a run abandoned mid-way
# makes none.
#   panel: {kind, t, stage, world, world_name, caption, sfx, size, facts, shot}
# kind is one of KINDS. caption is the narrator box (TONE-BIBLE: deadpan words, loud
# pictures), sfx the drawn sound word ("" for none), size a layout hint (wide, tall,
# square), facts a small dict of numbers, shot an Image (SHOT_WIDTH wide, null headless or
# when no still was taken). save() hands the page to the scrapbook; page_ready tells the
# summary screen it can draw it. At run_ended the save runs on a worker: writing the stills and
# the page took 78 to 82 ms of the 4080's 316 ms victory frame (scrapkeep#241), and the summary
# draws the page from memory. saved_path() waits for it.
#
# A Continued run starts its moments at the resume (run_started resets them), so its opening
# is the stage it resumed on.
#
# Every run has an opening and a finale; the middle takes up to four of the rest by PRIORITY,
# and the ledger and top speed always exist, so a page is never under four panels.

signal page_ready(page: Dictionary)

const AppShell := preload("res://src/core/app_shell.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Roster := preload("res://src/combat/roster.gd")
const Parts := preload("res://src/build/parts.gd")
const SafeStore := preload("res://src/core/safe_store.gd")

const SCHEMA := 1
const DIR := "scrapbook"
# The camp's scrapbook store and page drawing (camp hub thread); both optional until merged.
const STORE_PATH := "res://src/core/scrapbook_store.gd"
const MIN_PANELS := 4
const MAX_PANELS := 6
const SHOT_WIDTH := 480
# A still is a frame readback; keep them rare. A better candidate of the same kind replaces
# the held one only by this margin, and never sooner than SHOT_GAP seconds after any still.
const SHOT_GAP := 1.0
# The share of the frame a still keeps, clear of the HUD's bars (top 12%, bottom 22%).
const SHOT_CROP := Rect2(0.08, 0.12, 0.84, 0.66)
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
# Stills need a renderer; tests may switch them off on a display, and --no-stills (a user arg
# after --) switches them off for a timing run: each still reads the whole frame back from the GPU.
var stills := not ("--no-stills" in OS.get_cmdline_user_args())
# Stills read back so far, so a timing run can show the switch fired (lesson 34).
var shots_taken := 0
# The last page finished by run_ended, and where save() put it ("" when unsaved, or until the
# save's worker is done: read it through saved_path()).
var last_page := {}
var last_page_path := ""
# The run_ended save's WorkerThreadPool task (-1 for none) and the path it returns.
var _save_task := -1
var _save_out := {}

var _best := {}
var _staggered := {}
var _pending_death := {}
var _boss_down := {}
var _opening_due := false
var _shot_wait := 0.0
# Stills asked for and not yet read back (frame_post_draw).
var _grabs_pending := 0
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
	saved_path()
	_best.clear()
	_staggered.clear()
	_pending_death = {}
	_boss_down = {}
	_opening_due = false
	_shot_wait = 0.0
	_top_speed = 0.0
	last_page = {}
	last_page_path = ""


func _physics_process(delta: float) -> void:
	if _save_task >= 0 and WorkerThreadPool.is_task_completed(_save_task):
		saved_path()
	_shot_wait = maxf(0.0, _shot_wait - delta)
	if run == null or run.over or run.class_def == null:
		return
	if _opening_due and run.stage_time >= OPENING_AFTER:
		_opening_due = false
		_offer("opening", 1.0, {}, true)
	if player != null and player.state != null:
		var v: Vector3 = player.state.velocity
		var planar := Vector2(v.x, v.z).length()
		if planar > _top_speed:
			_top_speed = planar
			# The still waits for a lead worth framing, not every new decimal.
			_offer("top_speed", planar, {"speed": snappedf(planar, 0.1)})


# Whether a still has been asked for and not yet read back: the frame it photographs has not
# drawn. The summary screen waits on this, so a death's picture is of the death.
func still_pending() -> bool:
	return _grabs_pending > 0


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
	# A still asked for this frame (the final death's) lands after it draws; fold after that.
	if _grabs_pending > 0:
		await RenderingServer.frame_post_draw
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
	var ledger := _moment("ledger", 1.0, {"kills": int(run.kills), "scrap": int(run.scrap)})
	ledger["t"] = minf(float(ledger["t"]), float(finale["t"]))
	_keep("ledger", ledger)
	last_page = build_page(won, finale)
	_save_later(last_page)
	page_ready.emit(last_page)


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
	# Starting parts can land before the opening still; the opening still opens the page.
	if not middle.is_empty() and float(middle[0]["t"]) < float(rows[0]["t"]):
		rows[0] = rows[0].merged({"t": float(middle[0]["t"])}, true)
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
		"outcome": "won" if won else "lost",
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


# Where the last run_ended page was saved, waiting for its worker if it is still writing.
func saved_path() -> String:
	if _save_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_save_task)
		_save_task = -1
		last_page_path = String(_save_out.get("path", ""))
		_save_out = {}
	return last_page_path


# save() on a worker. The store is made here (it loads a script); the worker writes a copy of the
# page, whose stills it only reads.
func _save_later(page: Dictionary) -> void:
	saved_path()
	var store = load(STORE_PATH).new(storage_dir) if ResourceLoader.exists(STORE_PATH) else null
	var copy := page.duplicate(true)
	var out := {}
	_save_out = out
	_save_task = WorkerThreadPool.add_task(func(): out["path"] = save(copy, store), false, "run_moments save")


func _exit_tree() -> void:
	saved_path()


# Saves through the camp's scrapbook store (scrapbook_store.gd) when the build has it; until
# then the same layout by hand: <storage_dir>/scrapbook/<run_id>.json, each still beside it as
# <run_id>_<i>.png named in its panel's shot. Returns the JSON's path, or "". store is one made
# ahead on the main thread (a worker save), or null to make it here.
func save(page: Dictionary, store = null) -> String:
	if store == null and ResourceLoader.exists(STORE_PATH):
		store = load(STORE_PATH).new(storage_dir)
	if store != null:
		var saved := String(store.save(page))
		if saved == "":
			push_warning("run_moments: scrapbook refused the page: %s" % store.last_error)
		return saved
	var id := String(page.get("run_id", "")).validate_filename()
	var dir := storage_dir.path_join(DIR)
	if id == "" or DirAccess.make_dir_recursive_absolute(dir) != OK:
		push_warning("run_moments: could not save page %s in %s" % [id, dir])
		return ""
	var doc := page.duplicate(true)
	for i in doc["panels"].size():
		var panel: Dictionary = doc["panels"][i]
		var shot = page["panels"][i].get("shot")
		panel["shot"] = ""
		if shot is Image and (shot as Image).save_png(dir.path_join("%s_%d.png" % [id, i])) == OK:
			panel["shot"] = "%s_%d.png" % [id, i]
	var path := dir.path_join(id + ".json")
	if SafeStore.write_atomic(path, JSON.stringify(doc, "\t")) != OK:
		push_warning("run_moments: could not write %s" % path)
		return ""
	return path


# A candidate of one kind: kept when it beats the held one (by BETTER_BY when the held one
# already has a still), and given a still when the gap allows.
func _offer(kind: String, score: float, facts: Dictionary, rare := false) -> void:
	var held: Dictionary = _best.get(kind, {})
	if not held.is_empty():
		var stilled: bool = held.get("shot") != null or held.get("grabbing", false)
		var need := float(held["score"]) * (BETTER_BY if stilled and not rare else 1.0)
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
	if not stills or (_shot_wait > 0.0 and not rare) or AppShell.headless() or not is_inside_tree():
		return
	_shot_wait = SHOT_GAP
	_grabs_pending += 1
	row["grabbing"] = true
	RenderingServer.frame_post_draw.connect(func():
		_grabs_pending = maxi(0, _grabs_pending - 1)
		row.erase("grabbing")
		if not is_inside_tree():
			return
		var image := get_viewport().get_texture().get_image()
		shots_taken += 1
		if image == null or image.is_empty():
			return
		# The HUD's top and bottom bands are not part of the picture.
		var size := Vector2(image.get_size())
		image = image.get_region(Rect2i(Vector2i(size * SHOT_CROP.position), Vector2i(size * SHOT_CROP.size)))
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
	if family == null or String(family) == "":
		return "The Warden"
	var variant = enemy.get("variant")
	return "The %s" % Roster.warden_name(String(family), String(variant) if variant != null else "")


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
