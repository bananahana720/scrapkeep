extends Node

# The one bus. Every gameplay fact is published here after it has been committed, so
# presentation, audio, the HUD and the field notes read the same record and never ask
# a module directly. A signal reports what happened; it applies nothing (TADR-008).
# Each signal has a row in event_kinds.gd keyed by its name, and CONTRACTS.md names
# the one owner allowed to emit it.

# Flow (spine).
signal run_started(class_id: String)
signal flow_changed(state: String)
# Emitted at run start and whenever the stage entered is in a new world, before that
# stage's stage_entered. Never on a retry.
signal world_entered(world: int)
signal stage_entered(stage: int, retry: bool)
signal stage_cleared(stage: int)
signal run_ended(won: bool)
signal beacon_charge_changed(fraction: float)
signal beacon_unsealed(stage: int)
signal warden_engaged(stage: int)
signal stage_content_cleared(reason: String)

# Run state (spine; emitted by run_state.gd's mutators, called by the modules).
signal scrap_collected(amount: int, at: Vector3, total: int)
# A gear pickup filled the wallet (build.gd): the amount just banked and the wallet after it.
signal cogs_collected(amount: int, total: int)
signal part_gained(part_id: String, source: String)
# An evolution fires (build.gd), announced before its Evolved part is granted.
signal evolution_fired(part_id: String)
signal player_hit(amount: float, source: String)
# Run state committed the companion's once-per-zone escape charge and brief window.
signal escape_window(seconds: float)
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
# The slam's shockwave resolved (player_ball.gd): it threw hit_count enemies, or none.
signal drop_landed(hit_count: int)
signal missed_drop
signal grapple_fired(anchor: Vector3)
signal grapple_released
# The harpoon (player_ball.gd): a line bitten into an enemy, and a committed haul landing on
# one, at the speed the line closed at.
signal harpoon_bit(enemy: Node3D, at: Vector3)
signal harpoon_smashed(enemy: Node3D, at: Vector3, speed: float)
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
# A Highdraft enemy knocked off an island edge (enemy.gd ring_out); enemy_killed follows.
signal enemy_ringed_out(kind: String, at: Vector3)
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
# The upgrade tree (upgrade_tree.gd, emitted by the player's tree): a pick opened with
# its two node ids, and a pick taken.
signal tree_offered(class_id: String, depth: int, choices: Array)
signal tree_picked(class_id: String, node_id: String, depth: int)

# v2 W6 world. Moss's bay and the gorge's contraptions (world publishes all three).
# bay_entered fires when the cradle catches the ball and banks its speed; bay_left
# when the exit pad fires it back out, or it rolls off the deck. world_fact carries every contraption, terrain, layer, ride and toy fact as a
# kind that keys event_kinds.WORLD_ROWS, so one signal serves the whole family.
signal bay_entered(banked_speed: float)
signal bay_left(velocity: Vector3)
signal world_fact(kind: String, at: Vector3)

# v2 W7 enemies: the counters' holds and tenacity, pack arrivals, and the ancients'
# facts. Combat emits every one (src/combat/holds.gd, fleet.gd and the units). kind is
# the holding unit's mechanic (roster.gd); method is the player's own action that broke
# it ("jump", "boost", "smash", "glide", "speed"); faction is "fleet", "reactor",
# "swarm" or "mind"; point_id names a family Warden's weak point.
signal hold_started(kind: String, at: Vector3)
signal hold_broken(kind: String, method: String)
signal hold_ended(kind: String, reason: String)
signal tenacity_gained(seconds: float)
signal pack_arrived(faction: String, at: Vector3, kinds: Array)
signal shield_vaulted(at: Vector3, speed: float)
signal vent_charging(at: Vector3, seconds: float)
signal vent_erupted(at: Vector3)
signal swarm_scattered(at: Vector3, drones: int)
signal mind_adapted(habit: String, icon: String)
signal weak_point_opened(point_id: String, at: Vector3, seconds: float)

# v3 W11 juice. Combat's near-miss watch (src/combat/near_miss.gd): the ball was inside
# a committed threat while it warned and outside it when it landed, or left within the
# grace unhurt. kind is the threat's type kind (threat_instant, threat_lane, ...).
signal near_miss(kind: String, at: Vector3)
# v3 interact (LOOP-REDESIGN section 9; world's interact system and its devices publish
# all four). family keys world/interactables.gd FAMILIES and device_id names the device.
# interact_armed: consent given (E in a travel lane, a hold completed, a press).
# interact_fired: the device acted (a launch, a pack arriving, a chest opening, a bet's
# needle stopping). ambush_ended: an altar's pack cleared in time (won) or not.
# bet_resolved: a double-or-nothing landed; stake is the cores it put up.
signal interact_armed(family: String, device_id: String, at: Vector3)
signal interact_fired(family: String, device_id: String, at: Vector3)
signal ambush_ended(device_id: String, won: bool, at: Vector3)
signal bet_resolved(device_id: String, won: bool, stake: int, at: Vector3)

# The legibility grammar (design-v3/LEGIBILITY.md). line_state_changed names a LINE_ROWS id;
# cause is "" except on "broke", where it says what cut the line. verb_failed names a
# Bindings.VERBS id and why the press could not succeed, at the place it would have landed.
# cause_armed and cause_fired name a build/synergies.gd id: armed when it becomes live, fired
# each time its effect happens (target is null where no one body is struck). posture_changed
# carries the Warden's posture bar.
signal line_state_changed(state: String, target: Node3D, at: Vector3, cause: String)
signal verb_failed(verb: String, reason: String, at: Vector3)
# A key prompt (ui/key_glyphs.gd) began to be drawn: once per rising edge, not per frame. verb is
# the prompt id, LET GO included. The run log counts them as prompts_shown.
signal prompt_shown(verb: String)
signal cause_armed(id: String)
signal cause_fired(id: String, target: Node3D, at: Vector3)
signal posture_changed(enemy: Node3D, posture: float, staggered: bool)
# A standing activity (world/activities.gd) finished: id keys EventKinds.ACTIVITY_ROWS, at is
# where its pay appears. Once per activity per stage attempt.
signal activity_done(id: String, at: Vector3)
# progress.gd earned an achievement and saved the profile (or tried to). id keys Achievements.ROWS.
signal achievement_earned(id: String)
# A world rescue finished (a stranded pilot freed). quest_id names it: "rivet" for world one's
# runner, "dig" for the later dig rescue. achievements.gd rows key on it to unlock pilots.
signal rescue_completed(quest_id: String)

# The skill bar and the ultimate (design-v3/SKILL-BAR.md section 7). All ten are declared
# here at once so only one unit edits the bus.
# slot_selected (player_ball's router): the selection changed. reason is "pick", or the snap
# back's cause: cast, deselect, cancel, swap, timeout, ultimate or reset.
signal slot_selected(slot: String, reason: String)
# Combat: slot 2 or 3 committed a cast. The cast's own signal (special_used,
# line_skill_fired) carries its presentation.
signal slot_cast(slot: String, ability_id: String, at: Vector3)
# Combat's line skill: a cast with no line loaded the next bite for `seconds`; the flavour
# fired along the line (on is "body" or "world"); a load ran out with no bite.
signal line_skill_loaded(ability_id: String, seconds: float)
signal line_skill_fired(ability_id: String, target: Node3D, at: Vector3, on: String)
signal line_skill_expired(ability_id: String)
# The set piece (src/combat/ultimate.gd, wave P-B's ultimate unit): the meter reached full;
# Q committed the planned path (seconds is wind-up plus flight); the flight's middle beat;
# the landing strike resolved; a cancel (recall, bail, stage or death) and whether it refunded.
signal ultimate_ready(ultimate_id: String)
signal ultimate_started(ultimate_id: String, path: String, from: Vector3, to: Vector3, seconds: float)
signal ultimate_peak(ultimate_id: String, at: Vector3)
signal ultimate_landed(ultimate_id: String, at: Vector3, hits: int, damage: float)
signal ultimate_cancelled(ultimate_id: String, reason: String, refunded: bool)


static func signal_names() -> PackedStringArray:
	var names := PackedStringArray()
	var script: Script = load("res://src/core/game_events.gd")
	for info in script.get_script_signal_list():
		names.append(info["name"])
	return names
