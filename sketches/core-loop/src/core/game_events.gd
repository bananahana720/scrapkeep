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
signal beacon_unsealed(stage: int)
signal warden_engaged(stage: int)
signal stage_content_cleared(reason: String)

# Run state (spine; emitted by run_state.gd's mutators, called by the modules).
signal scrap_collected(amount: int, at: Vector3, total: int)
signal part_gained(part_id: String, source: String)
signal player_hit(amount: float, source: String)
signal player_died
signal enemy_killed(kind: String, at: Vector3, scrap_value: int)
signal milestone_won(event_id: String)
signal heft_class_changed(heft_class: int, heft: float)
signal heft_class_dropped(heft_class: int, heft: float)
signal scrap_lost(amount: int, at: Vector3, total: int, cause: String)
signal core_gained(source: String, at: Vector3, count: int)

# Codex (spine; emitted by codex.gd's mutators, called by the modules).
signal synergy_discovered(synergy_id: String, category: String, first_time: bool)
signal interaction_found(description: String)

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
signal strike_deflected(enemy: Node3D, kind: String, punch: float, plating: float)

# Build (writer B).
signal reward_offered(offers: Array)
signal reward_chosen(part_id: String)
signal element_resolved(element_id: String, material_id: String, behaviour: String, at: Vector3)

# World (writer D).
signal event_announced(event_id: String, seconds_until: float)
signal event_started(event_id: String)
signal event_ended(event_id: String, outcome: String)
signal event_progress(event_id: String, fraction: float)
signal launched(velocity: Vector3)
signal pressure_changed(pressure: float)
signal threat_rose(tier: int)

# Boss (wave 4, writer E's src/boss/).
signal boss_arena_entered
signal boss_phase_changed(phase: int, name: String)
signal boss_attack_telegraphed(attack_id: String, seconds_until: float)
signal boss_weak_point_hit(point_id: String)
signal boss_defeated

# v2 W3 characters: the class abilities and the shared bowling-ball contact. Movement
# (player_ball) emits the contact, vault, sprint, blink, smash-flavour, slingshot-gauge
# and cc_ignored facts; combat emits pins, the specials' gauges, the cloak, stickies
# and rocket jumps. ability_id is the slot's ability id, or "slingshot".
signal enemy_rebounded(enemy: Node3D, speed: float)
signal enemy_pinned(enemy: Node3D, damage: float)
signal vault_kicked(at: Vector3, speed: float)
signal gauge_charging(ability_id: String)
signal gauge_released(ability_id: String, fraction: float)
signal gauge_cancelled(ability_id: String, reason: String)
signal sprint_started(direction: Vector3)
signal cc_ignored(kind: String)
signal cloak_started(seconds: float)
signal cloak_broken(reason: String)
signal sticky_detonated(at: Vector3, crit: bool)
signal rocket_jumped(at: Vector3, speed: float)
signal blink_used(from: Vector3, to: Vector3)
signal arc_slammed(at: Vector3, faces: int)
signal skid_smashed(at: Vector3, hits: int)
signal demo_slammed(at: Vector3)


static func signal_names() -> PackedStringArray:
	var names := PackedStringArray()
	var script: Script = load("res://src/core/game_events.gd")
	for info in script.get_script_signal_list():
		names.append(info["name"])
	return names
