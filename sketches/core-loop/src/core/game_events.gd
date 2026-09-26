extends Node

# The one bus. Every gameplay fact is published here after it has been committed, so
# presentation, audio, the HUD and the field notes read the same record and never ask
# a module directly. A signal reports what happened; it applies nothing (TADR-008).
# Each signal has a row in event_kinds.gd keyed by its name, and CONTRACTS.md names
# the one owner allowed to emit it.

# Flow (spine).
signal run_started(class_id: String)
signal flow_changed(state: String)
signal stage_entered(stage: int, retry: bool)
signal stage_cleared(stage: int)
signal run_ended(won: bool)
signal beacon_charge_changed(fraction: float)

# Run state (spine; emitted by run_state.gd's mutators, called by the modules).
signal scrap_collected(amount: int, at: Vector3, total: int)
signal part_gained(part_id: String, source: String)
signal player_hit(amount: float, source: String)
signal player_died
signal enemy_killed(kind: String, at: Vector3, scrap_value: int)
signal milestone_won(event_id: String)

# Movement (spine; emitted by player_ball.gd).
signal jumped(air: bool)
signal boosted(direction: Vector3)
signal dashed(direction: Vector3)
signal landed(impact: float)
signal slammed(at: Vector3, strength: float, flatness: float)
signal grapple_fired(anchor: Vector3)
signal grapple_released
signal mounted(at: Vector3, banked_speed: float)
signal dismounted(velocity: Vector3)

# Combat (writer A).
signal enemy_spawned(enemy: Node3D, kind: String)
signal enemy_struck(enemy: Node3D, kind: String, force: float)
signal shot_fired(weapon_id: String, from: Vector3, to: Vector3)
signal special_used(special_id: String, at: Vector3)

# Build (writer B).
signal reward_offered(offers: Array)
signal reward_chosen(part_id: String)

# World (writer D).
signal event_announced(event_id: String, seconds_until: float)
signal event_started(event_id: String)
signal event_ended(event_id: String, outcome: String)
signal launched(velocity: Vector3)
signal pressure_changed(pressure: float)


static func signal_names() -> PackedStringArray:
	var names := PackedStringArray()
	var script: Script = load("res://src/core/game_events.gd")
	for info in script.get_script_signal_list():
		names.append(info["name"])
	return names
