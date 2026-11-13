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
# The ball first came within SIGHT_SHARE of the beacon ring's radius of a sealed Warden it has not
# engaged: the moment before the fight, when intro lines and reveal cards play (flow.gd).
signal warden_sighted(stage: int)
signal warden_engaged(stage: int)
signal stage_content_cleared(reason: String)

# Run state (spine; emitted by run_state.gd's mutators, called by the modules).
signal scrap_collected(amount: int, at: Vector3, total: int)
# A gear pickup filled the wallet (build.gd): the amount just banked and the wallet after it.
signal cogs_collected(amount: int, total: int)
signal part_gained(part_id: String, source: String)
# A grey panel bolted on (build/panels.gd): its id, how many of it the run now holds, where
# it was picked up, and whether a reel or dunk kill dropped it (the jackpot chime).
signal panel_gained(panel_id: String, count: int, at: Vector3, jackpot: bool)
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
# The ball met a world face that is not a floor (a wall, cliff, structure side or ceiling) at
# `speed` m/s of closing, Contact.BUMP_MIN_SPEED or more: `at` on the face, `normal` face to ball.
signal bumped(at: Vector3, normal: Vector3, speed: float)
signal slammed(at: Vector3, strength: float, flatness: float)
# A carve ended (rigid_ball.gd through the kit's facts): the ball rode banked ground steeper
# than Tuning.CARVE_DOT at grip speed for `seconds`, and left it at `speed` m/s from `at`.
# Carves shorter than RigidBall.CARVE_MIN_S (0.3 s) are seam hops and publish nothing.
signal carved(at: Vector3, seconds: float, speed: float)
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
# `at` is where the event lands, on the ground, or Vector3.INF for one with no single place
# (the weather, the flood, a squall).
signal event_announced(event_id: String, seconds_until: float, at: Vector3)
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
# Fight phases (combat/fight_phases.gd): any boss or mini-boss fight entering phase `phase` of
# `phases`. The music swaps that fight's anthem on the next downbeat.
signal fight_phase_changed(fight_id: String, phase: int, phases: int)
# A cued follow-up: its hazard is drawn in FightPhases.CUE_LEAD and lands seconds_until from now.
signal attack_cued(fight_id: String, attack_id: String, seconds_until: float)
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
# A knocked enemy thrown into a world face at `speed` m/s into it (enemy.gd): it stops on the
# face instead of gliding along it. `at` is on the face, `normal` points face to enemy. No damage.
signal enemy_walled(enemy: Node3D, at: Vector3, normal: Vector3, speed: float)
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
# it ("jump", "boost", "smash", "glide", "speed", "ultimate", "hook"); faction is "fleet", "reactor",
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
# The first-win secret paint rows (secrets.gd PAINT_ROWS) earn silently and never emit it.
signal achievement_earned(id: String)
# A world rescue finished (a stranded pilot freed). quest_id names it: "rivet" for world one's
# runner, "dig" for the later dig rescue, "isles" for Tally's cage in the Highdraft. achievements.gd
# rows key on it to unlock pilots.
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
# The active slot (src/combat/actives): F fired the racked active at `at`; count is how many
# pieces left (rockets in a volley). Maker sets and sounds read it; its strikes are enemy_struck.
signal active_fired(active_id: String, at: Vector3, count: int)
# An active building toward a strike on one machine (the Cutting Torch's heat on a plate):
# fraction climbs 0 to 1 in steps; presentation glows and sizzles it. No damage of its own.
signal active_heat(active_id: String, at: Vector3, fraction: float)
# The set piece (src/combat/ultimate.gd, wave P-B's ultimate unit): the meter reached full;
# Q committed the planned path (seconds is wind-up plus flight); the flight's middle beat;
# the landing strike resolved; a cancel (recall, bail, stage or death) and whether it refunded.
signal ultimate_ready(ultimate_id: String)
signal ultimate_started(ultimate_id: String, path: String, from: Vector3, to: Vector3, seconds: float)
signal ultimate_peak(ultimate_id: String, at: Vector3)
signal ultimate_landed(ultimate_id: String, at: Vector3, hits: int, damage: float)
signal ultimate_cancelled(ultimate_id: String, reason: String, refunded: bool)

# Achievements refresh (w20): facts the player sees that had no bus signal. special_broken: a
# kill-first special (Roster.SPECIALS) fell. radio_take_found: a take was filed; source is its
# found rule's "on" ("cache" for a Signal cache). relay_stake_paid: a relay won with a stake of
# `stakes` stacks. maker_set_completed: a set turned on for the run. overflow_cashed: an active
# fired carrying `pieces` banked overflow pieces.
signal special_broken(kind: String)
signal radio_take_found(take_id: String, tier: String, source: String)
signal relay_stake_paid(stakes: int)
# A trade spot's offer was taken: kind is the site's ("trade_risk" the keeper's gamble,
# "trade_safe" the foreman's kindness). A trade is no activity, so activity_done never names it.
signal trade_taken(kind: String, at: Vector3)
signal maker_set_completed(maker: String, bonus: String)
signal overflow_cashed(active_id: String, pieces: int)


static func signal_names() -> PackedStringArray:
	var names := PackedStringArray()
	var script: Script = load("res://src/core/game_events.gd")
	for info in script.get_script_signal_list():
		names.append(info["name"])
	return names
