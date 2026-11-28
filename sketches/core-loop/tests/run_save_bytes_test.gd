extends SceneTree

const RunState := preload("res://src/core/run_state.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("run_save_bytes_test")


func _initialize() -> void:
	var written := _text(_written_run().to_entrance_doc())
	_t.check("a run writes the pinned save bytes", written == WRITTEN, "" if written == WRITTEN else "\n" + written)

	var parsed = JSON.parse_string(LOADED)
	_t.check("the pinned save parses", parsed is Dictionary and not parsed.is_empty())
	_t.eq("the pinned save validates", RunState.validate_entrance_doc(parsed), "")
	var back := RunState.new(null)
	_t.check("the pinned save loads", back.from_entrance_doc(parsed))
	var again := _text(back.to_entrance_doc())
	_t.check("the loaded save writes the same bytes", again == LOADED, "" if again == LOADED else "\n" + again)
	quit(_t.verdict())


func _text(doc: Dictionary) -> String:
	return JSON.stringify(doc, "  ", true, true)


func _written_run() -> RunState:
	var r := RunState.new(null)
	r.run_id = "1760000000-004242"
	r.run_seed = 123456789
	r._loaded_class_id = "rivet"
	r.stage = 5
	r.world = 2
	r.max_hp = 120.0
	r.hp = 87.5
	r.mass = 431.25
	r.scrap = 77
	r._heft_class = 2
	r._wear_accum = 0.375
	r.bonus_cores = 1
	r.class_rewarded = 2
	r.parts.assign(["plate", "coil", "plate", "arm"])
	r.kills = 19
	r.events_won.assign(["vault_a", "crane"])
	r.run_time = 301.125
	r.retries = 3
	r.tree_picks.assign(["a1", "b2"])
	r.tree_allowed = 3
	r.retries_spent = {1: 2, 2: 1}
	r.cogs = 14
	r.snapshot(Vector3(1.5, -2.25, 3.125), Vector3(0.125, 0.25, -30.5), 1.75)
	return r


const WRITTEN := """{
  "bonus_cores": 1,
  "camera_yaw": 1.75,
  "class_id": "rivet",
  "class_rewarded": 2,
  "cogs": 14,
  "companion": {},
  "death_save_spent": false,
  "entry_position": [
    1.5,
    -2.25,
    3.125
  ],
  "entry_velocity": [
    0.125,
    0.25,
    -30.5
  ],
  "events_won": [
    "vault_a",
    "crane"
  ],
  "heft_class": 2,
  "hp": 87.5,
  "kills": 19,
  "mass": 431.25,
  "max_hp": 120.0,
  "parts": [
    "plate",
    "coil",
    "plate",
    "arm"
  ],
  "pocket_draw_cache": {},
  "relics": {},
  "retries": 3,
  "retries_spent": {
    "1": 2,
    "2": 1
  },
  "run_id": "1760000000-004242",
  "run_tallies": {
    "deaths": 0,
    "kills": 0,
    "stages_cleared": 0,
    "time": 301.125,
    "wardens_seen": 0
  },
  "run_time": 301.125,
  "schema": 1,
  "scrap": 77,
  "seed": 123456789,
  "seen_wardens": [],
  "settled": [],
  "stage": 5,
  "start_pick": {},
  "trade_memory": {
    "decisions": {},
    "last_appeared": -100,
    "last_refused": -100,
    "last_seen": -100,
    "offers": {},
    "risk_taken": false,
    "seen": []
  },
  "tree_allowed": 3,
  "tree_late_skipped": false,
  "tree_picks": [
    "a1",
    "b2"
  ],
  "wear_accum": 0.375,
  "world": 2
}"""

const LOADED := """{
  "bonus_cores": 1,
  "camera_yaw": 1.75,
  "class_id": "rivet",
  "class_rewarded": 2,
  "cogs": 14,
  "companion": {},
  "consumable_slots": 2,
  "consumables": [
    "cap_charge"
  ],
  "death_save_spent": false,
  "entry_position": [
    1.5,
    -2.25,
    3.125
  ],
  "entry_velocity": [
    0.125,
    0.25,
    -30.5
  ],
  "events_won": [
    "vault_a",
    "crane"
  ],
  "heft_class": 2,
  "hp": 87.5,
  "kills": 19,
  "mass": 431.25,
  "max_hp": 120.0,
  "panels": [
    "vent_louvre",
    "punch_rivet"
  ],
  "parts": [
    "plate",
    "coil",
    "plate",
    "arm"
  ],
  "pocket_draw_cache": {},
  "relics": {},
  "retries": 3,
  "retries_spent": {
    "1": 2,
    "2": 1
  },
  "run_id": "1760000000-004242",
  "run_tallies": {
    "deaths": 0,
    "kills": 0,
    "stages_cleared": 0,
    "time": 301.125,
    "wardens_seen": 0
  },
  "run_time": 301.125,
  "schema": 1,
  "scrap": 77,
  "scrap_ingots": {
    "1": 2,
    "2": 1,
    "3": 0
  },
  "seed": 123456789,
  "seen_wardens": [],
  "settled": [],
  "stage": 5,
  "start_pick": {},
  "trade_memory": {
    "decisions": {},
    "last_appeared": -100,
    "last_refused": -100,
    "last_seen": -100,
    "offers": {},
    "risk_taken": false,
    "seen": []
  },
  "tree_allowed": 3,
  "tree_late_skipped": false,
  "tree_picks": [
    "a1",
    "b2"
  ],
  "wear_accum": 0.375,
  "world": 2
}"""
