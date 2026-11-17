extends RefCounted

# UI principle P9 (design-v3/ui-audit/principles.json): no fact arrives by sound alone. This file
# classifies every place the game decides to make a sound that carries information, and
# tests/sound_twins_test.gd holds it. A row is a FACT (the source that decides to make the sound),
# never a bare cue id, because one cue serves several facts and a cue's status belongs to the fact
# (ratchet_cue is a warning at Brindle's hook turn and at the rogue's chained attack, and the
# beacon_hum fallback is a warning at the Warden's charge and the weak point's opening). The test builds the list of facts
# from the game's own tables and call sites (its header says how); this file only judges them.
#
# The rule for "act on". A fact is act-on when its sound tells the player to do something, or tells
# them something changed that they must respond to: an attack about to land, a boss turning phase,
# a hit taken, an ability ready to press, a gate or yard now open or shut, a timer running down. It
# is NOT act-on when it only echoes what the player just did (a hop, a hit, a pickup), pays a
# reward, scores a moment (stingers, music, a near miss, which is a reward), or lands after a
# warning that already sounded and showed (the slam after its tell). A cue in sfx_bank.gd's
# DANGER_SOUNDS is act-on by definition; a not-act row for one is printed with its reason.
#
# Row kinds:
#   ACT     act-on with a twin. "script", "fn" and "token": the token must sit inside function fn of
#           that script, on a line that is code (not a declaration or a comment), so a renamed
#           function or a deleted drawing call fails the test. "toast" names an event kind the HUD
#           must toast. "traced" says the code path was read, not only the row.
#   OPEN    act-on and NO twin found. "plays" names the file and line that plays it; "severity"
#           "fairness" means the sound shortens the warning a muted player gets. The test prints
#           these and pins their count, so none can be added silently.
#   RELAY   a shared row or emitter whose facts are judged at their callers.
#   NOT_ACT not act-on, one reason per group.
# World 1. The test derives the facts that can fire in world 1 (the dam and flume park files' forms and
# music cues, the roster units those files name or mark world 1, the scanned sites in WORLD1_FILES, and
# every table fact with a firing site) and FAILS any of them marked not traced. A not-act row counts as
# traced when its firing site was found; its reason was judged from the row and the site, not by reading
# each consequence. A row outside the world 1 check (world 2 and 3 forms, bank sounds with no fact) may be
# untraced, and the count is pinned.
#
# The toast rule. A toast is a twin only for the fact that IS that toast's event (event_announced's klaxon
# and event_ended's "lost" toast). The toast and the edge marker that the park director's announced fact
# shows name an event, not a place on the ground, so for a world warning the player must move for (a park
# telegraph, a siren) the twin must be a mark in the world; a toast alone leaves the row OPEN, severity
# info, with a note that the toast shows.
#
# Moving a row to ACT means building the twin first; the test cannot see game changes that add a
# new warning, only that the new fact is listed.

const OPEN_PINNED := 6
# Rows read only by name, not traced through code. This number may only go down.
const UNTRACED_PINNED := 305
# Not-act rows for a cue in DANGER_SOUNDS (printed by the test with their reasons).
const DANGER_NOT_ACT_PINNED := 1

# Files whose scanned call sites are world 1's own (Brindle, the yard locks and overtime, the called shot,
# the Wardens, the Spillway rogue and miniboss) or core audio and effects that play in every world.
const WORLD1_FILES := ["boss.gd", "stage_locks.gd", "overtime.gd", "called_shot.gd", "warden.gd", "stub_boss.gd", "miniboss.gd", "rogue.gd", "audio.gd", "juice.gd", "panel_fx.gd", "projectile.gd"]
# Facts that can fire in world 1 and no rule finds: fact id -> why (none today).
const WORLD1_EXTRA := {}
# Table facts with no firing site found by the emit scan (their signal is emitted some other way). They
# sit outside the world 1 check; this number may only go down.
const UNSITED_PINNED := 130  # +2 (wave 43 sound part 4): guard_critical and the beacon_open state fire from audio.gd with no bus signal of their own

const ACT := [
	{"facts": ["ROWS:event_announced"], "traced": true, "what": "the toast \"<event> incoming\"",
		"script": "res://src/ui/hud.gd", "fn": "_on_event_announced", "token": "_on_field_fact(called if called != \"\" else event_id, \"event_announced\""},
	{"facts": ["ROWS:event_ended"], "traced": true, "what": "the toast \"<event> lost\" in the hazard colour",
		"script": "res://src/ui/hud.gd", "fn": "_on_event_ended", "token": "toast(toast_text(\"event_ended\", {"},
	{"facts": ["ROWS:boss_phase_changed"], "traced": true, "what": "the boss's phase burst and word, fired on the same call",
		"script": "res://src/presentation/machine_fx.gd", "fn": "boss_phase", "token": "fire(row[\"phase\"], at + lift, row[\"tint\"], \"P1\")"},
	{"facts": ["ROWS:player_hit"], "traced": true, "what": "the screen-edge flash toward the hit",
		"script": "res://src/presentation/juice.gd", "fn": "_on_player_hit", "token": "vfx.edge_flash(_screen_direction(from)"},
	{"facts": ["ROWS:threat_rose"], "traced": true, "what": "the threat tier drawn on the run status line (hud.gd setup stores it from threat_rose; _process hands it to set_status)",
		"script": "res://src/ui/hud.gd", "fn": "_process", "token": "_status.set_status(tbl.local(run.stage), world_stages, has_boss, flow.in_arena, _threat)"},
	{"facts": ["ROWS:beacon_unsealed"], "traced": true, "what": "the done-line tick that the Warden goal is finished",
		"script": "res://src/ui/hud.gd", "fn": "setup", "token": "_done.note(Objectives.done_words(\"warden\"))"},
	{"facts": ["ROWS:scrap_lost"], "traced": true, "what": "the toast \"Chase your scrap\"",
		"script": "res://src/ui/hud.gd", "fn": "toast_kind", "token": "toast(toast_text(kind, fields), EventKinds.color(kind)", "toast": "scrap_lost"},
	{"facts": ["ROWS:player_died"], "traced": true, "what": "the toast \"Scrapped\"",
		"script": "res://src/ui/hud.gd", "fn": "toast_kind", "token": "toast(toast_text(kind, fields), EventKinds.color(kind)", "toast": "player_died"},
	{"facts": ["ROWS:reward_offered"], "traced": true, "what": "the objective line \"Roll through a gate\"",
		"script": "res://src/core/flow.gd", "fn": "objective_text", "token": "EventKinds.objective(\"reward_offered\")"},
	{"facts": ["ROWS:pack_arrived"], "traced": true, "what": "the pack's edge marker with its faction icon",
		"script": "res://src/ui/edge_markers.gd", "fn": "targets", "token": "\"kind\": \"pack_arrived\""},
	{"facts": ["ROWS:vent_charging"], "traced": true, "what": "the Reactor Warden's own core ring laid on the ground at warden.gd:746 where it will blow (and the counter ring at :776; reactor_relic.gd also commits a vent ring)",
		"script": "res://src/combat/warden.gd", "fn": "_step_pulse", "token": "_core_ring = Telegraph.ring(world_root, terrain, Threat.Type.INSTANT, global_position, CORE_RADIUS)",
		"also": [{"what": "the counter ring the Warden lays on its second emit", "script": "res://src/combat/warden.gd", "fn": "_step_counter", "token": "_counter_ring = Telegraph.ring(world_root, terrain, Threat.Type.INSTANT, global_position, CORE_RADIUS)"}, {"what": "the relic's own vent ring", "script": "res://src/combat/reactor_relic.gd", "fn": "_commit", "token": "_commit_ring(Threat.Type.INSTANT, aim, VENT_RADIUS"}]},
	{"facts": ["ROWS:line_skill_loaded", "LINE_ROWS:locked"], "traced": true, "what": "the lock bracket drawn on the target in the lock colour (the HOOK word on the key retires after the first bite, so the bracket is the lasting twin)",
		"script": "res://src/presentation/line_view.gd", "fn": "_draw_lock", "token": "_bracket_material.albedo_color = EventKinds.line_color(\"locked\")"},
	{"facts": ["ROWS:ultimate_ready", "UI_ROWS:ability_ready"], "traced": true, "what": "the slot's ready swell on the ability bar",
		"script": "res://src/ui/ability_bar.gd", "fn": "update_slots", "token": "_pulses[id] = PULSE_SECONDS"},
	{"facts": ["THREAT_ROWS:threat_instant", "THREAT_ROWS:threat_wave", "THREAT_ROWS:threat_projectile", "THREAT_ROWS:threat_lane"], "traced": true, "what": "a boss Hazard's floor mark, repainted each step in the shared threat grammar",
		"script": "res://src/boss/hazard.gd", "fn": "step", "token": "_paint(reshaped)",
		"also": [{"what": "the combat Telegraph's fill advanced each step (the Warden's pulse ring and the crews' telegraphs; audio.gd _warn_threat sounds both kinds)", "script": "res://src/combat/telegraph.gd", "fn": "step", "token": "set_progress(age / maxf(warn_seconds, 0.001))"}]},
	{"facts": ["WORLD_ROWS:flood_rising", "WORLD_ROWS:trestle_groan", "WORLD_ROWS:lightning_charge"], "traced": true, "what": "the telegraph mark the natural family lays on the ground at the telegraph action",
		"script": "res://src/world/events/natural.gd", "fn": "handle", "token": "\"mark\": _mark(row, state.geometry)"},
	{"facts": ["WORLD_ROWS:ground_slump", "WORLD_ROWS:crust_crack", "WORLD_ROWS:lightning_mark", "WORLD_ROWS:impact_incoming"], "traced": false, "what": "the same natural-family telegraph mark",
		"script": "res://src/world/events/natural.gd", "fn": "handle", "token": "\"mark\": _mark(row, state.geometry)"},
	{"facts": ["WORLD_ROWS:fleet_inbound"], "traced": true, "what": "the dropship vessel drawn on the telegraph action",
		"script": "res://src/world/events/fleet.gd", "fn": "handle", "token": "active[row.id] = {\"mark\": _vessel(row)}"},
	{"facts": ["WORLD_ROWS:cage_rising"], "traced": false, "what": "the lift cage's own handler",
		"script": "res://src/world/events/fleet.gd", "fn": "handle", "token": "_lift(action, row, ctx)"},
	{"facts": ["WORLD_ROWS:zipline_inbound"], "traced": false, "what": "the zipline trolley's own handler",
		"script": "res://src/world/events/fleet.gd", "fn": "handle", "token": "_zipline(action, row, ctx)"},
	{"facts": ["WORLD_ROWS:boiler_pressure", "WORLD_ROWS:reactor_overload"], "traced": true, "what": "the industrial hazard committed at the telegraph action and painted through its warning",
		"script": "res://src/world/events/industrial.gd", "fn": "_telegraph", "token": "hazard.commit_annulus(row.id, Threat.Type.INSTANT, at"},
	{"facts": ["WORLD_ROWS:cave_in_crumble"], "traced": false, "what": "the committed floor warning under the falling slab",
		"script": "res://src/world/events/rubble_fall.gd", "fn": "_commit", "token": "hazard.commit_annulus(id, Threat.Type.INSTANT, centre"},
	{"facts": ["WORLD_ROWS:cinder_glow", "WORLD_ROWS:cinder_burn"], "traced": false, "what": "the floor's cinder glow",
		"script": "res://src/world/contraptions.gd", "fn": "set_cinder_glow", "token": "_cinder_glow = glow"},
	{"facts": ["tele@boss.gd:_commit_crane:crane_sweep"], "traced": true, "what": "Brindle's crane sweep floor sector, committed in the same function",
		"script": "res://src/boss/boss.gd", "fn": "_commit_crane", "token": "h.commit_sector(\"crane_%d\" % i"},
	{"facts": ["tele@boss.gd:_commit_slag:id"], "traced": true, "what": "Brindle's slag ring, committed in the same function",
		"script": "res://src/boss/boss.gd", "fn": "_commit_slag", "token": "h.commit_annulus(id, Hazard.Threat.Type.INSTANT, arena.global_position"},
	{"facts": ["tele@boss.gd:_commit_charge:charge_wall"], "traced": true, "what": "Brindle's charge lane, committed in the same function",
		"script": "res://src/boss/boss.gd", "fn": "_commit_charge", "token": "h.commit_lane(\"charge\""},
	{"facts": ["bank:tele_crane_sweep"], "traced": true, "what": "Brindle's crane sweep wind-up, heard with the sector committed in the same function",
		"script": "res://src/boss/boss.gd", "fn": "_commit_crane", "token": "h.commit_sector(\"crane_%d\" % i"},
	{"facts": ["bank:tele_slag_ring"], "traced": true, "what": "Brindle's slag ring wind-up, heard with the ring committed in the same function",
		"script": "res://src/boss/boss.gd", "fn": "_commit_slag", "token": "h.commit_annulus(id, Hazard.Threat.Type.INSTANT, arena.global_position"},
	{"facts": ["bank:tele_charge", "bank:tele_charge_wall"], "traced": true, "what": "Brindle's charge and wall-charge wind-ups, heard with the lane committed in the same function",
		"script": "res://src/boss/boss.gd", "fn": "_commit_charge", "token": "h.commit_lane(\"charge\""},
	{"facts": ["bank:tele_eject"], "traced": true, "what": "Brindle's eject wind-up, heard with the landing mark from the same call",
		"script": "res://src/boss/boss.gd", "fn": "_begin_eject", "token": "_commit_eject_mark(land)"},
	{"facts": ["tele@mind.gd:_commit_attack:String"], "traced": false, "what": "the Mind's committed hazard, laid before the publish",
		"script": "res://src/boss/mind.gd", "fn": "_commit_attack", "token": "laid.append(h)"},
	{"facts": ["cued@boss.gd:_run_charge:charge"], "traced": true, "what": "the hull swings its bow round after the ball through the cue lead",
		"script": "res://src/boss/boss.gd", "fn": "_step_charges", "token": "_turn_ship(_aim_at(ball), Rules.CHARGE_TURN_RATE, delta)"},
	{"facts": ["cued@miniboss.gd:_after_slam:E04"], "traced": true, "what": "the miniboss raises its fists through the cue lead",
		"script": "res://src/combat/miniboss.gd", "fn": "_model_pose", "token": "fists = Vector3(0.0, 0.2, -0.5) * t"},
	{"facts": ["emit:arena_locked@stage_locks.gd:_lock"], "traced": true, "what": "the yard wall rises",
		"script": "res://src/world/stage_locks.gd", "fn": "_lock", "token": "_build_wall(radius)"},
	{"facts": ["emit:arena_unlocked@stage_locks.gd:_unlock"], "traced": true, "what": "the yard wall drops",
		"script": "res://src/world/stage_locks.gd", "fn": "_unlock", "token": "_drop_wall()"},
	{"facts": ["emit:warden_gate_refused@stage_locks.gd:_on_enemy_struck"], "traced": true, "what": "the objective line \"The Warden's clamp is shut: break N crews\"",
		"script": "res://src/world/stage_locks.gd", "fn": "objective", "token": "\"The Warden's clamp is shut: break %d crews"},
	{"facts": ["emit:warden_gate_opened@stage_locks.gd:_step_gate"], "traced": true, "what": "the Warden's collar drops away",
		"script": "res://src/world/stage_locks.gd", "fn": "_step_gate", "token": "_drop_collar()"},
	{"facts": ["emit:arena_wave@overtime.gd:_land_wave"], "traced": true, "what": "the registry's hazard cross holds at each drop spot of the landing crew (wave_cross.gd), shown before the emit",
		"script": "res://src/world/overtime.gd", "fn": "_land_wave", "token": "WaveCross.mark(self, drops"},
	{"facts": ["emit:arena_wave@stage_locks.gd:_step_lock"], "traced": true, "what": "the registry's hazard cross at each spot the next wave lands on, closing until the crew lands (wave_cross.gd, shown before the emit)",
		"script": "res://src/world/stage_locks.gd", "fn": "_mark_wave", "token": "WaveCross.mark(self, _wave_spots(_wave + 1)"},
	{"facts": ["cued@rogue.gd:_finish_strike:emit"], "traced": true, "what": "the rogue's core swells and burns brass from the same call that emits the cue",
		"script": "res://src/combat/rogue.gd", "fn": "_finish_strike", "token": "_show_core()"},
	{"facts": ["site:audio.gd:_tend_kettle:heat_kettle"], "traced": true, "what": "the shell's rim beats to full heat in the hazard colour over the same last Redline.KETTLE_S as the whistle",
		"script": "res://src/presentation/player_fx.gd", "fn": "_draw_overdrive", "token": "red.kettle_pulse()"},
	{"facts": ["site:audio.gd:_connect_redline:heat_rise", "site:audio.gd:_tend_heat:heat_cool"], "traced": true, "what": "the shell's rim turns from green toward amber as it climbs to the hot line and back as it cools",
		"script": "res://src/presentation/player_fx.gd", "fn": "_draw_overdrive", "token": "shell_color(red)"},
	{"facts": ["tele@boss.gd:_begin_eject:eject"], "traced": true, "what": "the scooter's landing spot is marked on the ground in the harmless bone style from the same call that publishes the telegraph (W1-107)",
		"script": "res://src/boss/boss.gd", "fn": "_begin_eject", "token": "_commit_eject_mark(land)"},
	{"facts": ["emit:sluice_warning@overtime.gd:open_sluice"], "traced": true, "what": "the water shows at the warning",
		"script": "res://src/world/overtime.gd", "fn": "open_sluice", "token": "_show_water(true)"},
	{"facts": ["emit:sluice_open@overtime.gd:_step_sluice"], "traced": true, "what": "the flood water shows as the sluice opens",
		"script": "res://src/world/overtime.gd", "fn": "_step_sluice", "token": "_show_water(true)"},
	{"facts": ["roster:hooker.tag", "roster:ramp_flipper.tag"], "traced": true, "what": "the unit's telegraph floor mark carries the tag, set on the same object",
		"script": "res://src/combat/counter.gd", "fn": "_voice", "token": "tele.mechanic_tag = Roster.voiced("},
	{"facts": ["roster:mag_trapper.tag", "roster:netcaster.tag", "roster:bola_thrower.tag", "roster:plated_brute.tag", "roster:deflector.tag", "roster:winch_drone.tag", "roster:gyro_jammer.tag", "roster:swatter.tag", "roster:catch_trap.tag", "roster:reactor_relic.tag", "roster:mind_hand.tag"], "traced": true, "what": "the unit's telegraph floor mark carries the tag, set on the same object",
		"script": "res://src/combat/counter.gd", "fn": "_voice", "token": "tele.mechanic_tag = Roster.voiced("},
	{"facts": ["roster:swarm_remnant.tag"], "traced": false, "what": "the swarm's formation lane carries the tag",
		"script": "res://src/combat/swarm_remnant.gd", "fn": "commit_formation_lane", "token": "lane.mechanic_tag = String("},
	{"facts": ["affix:stamp", "affix:rail", "affix:rearblast"], "traced": false, "what": "the elite brute's telegraph carries the affix tag",
		"script": "res://src/combat/plated_brute.gd", "fn": "_voice", "token": "tele.mechanic_tag = String(affix.mechanic_tag)"},
	{"facts": ["windup:lobber", "windup:hooker", "windup:ramp_flipper", "windup:boom_tender"], "traced": true, "what": "the enemy's windup glyph in its shape and hazard colour, drawn on the same call as the sound",
		"script": "res://src/presentation/presentation.gd", "fn": "_show_windup", "token": "vfx.glyph(\"enemy_spawned\", facts.at"},
	{"facts": ["windup:burrower", "windup:drill_crew", "windup:lamp_swarm", "windup:line_cutter", "windup:anchor_crew", "windup:kite_drone"], "traced": false, "what": "the enemy's windup glyph in its shape and hazard colour, drawn on the same call as the sound",
		"script": "res://src/presentation/presentation.gd", "fn": "_show_windup", "token": "vfx.glyph(\"enemy_spawned\", facts.at"},
	{"facts": ["windup:jolt_layer"], "traced": true, "what": "the telegraph's lead fill before each pulse",
		"script": "res://src/combat/jolt_layer.gd", "fn": "_live", "token": "tele.set_progress(field.lead_fraction())"},
	{"facts": ["special:foreman.tell", "special:dispatcher.tell"], "traced": true, "what": "the special's tell effects and word, fired from the same special_tell signal",
		"script": "res://src/presentation/machine_fx.gd", "fn": "special_moment", "token": "fire(row[moment], top, tint, cls)"},
	{"facts": ["special:linker.tell", "special:splitter.tell"], "traced": false, "what": "the special's tell effects and word, fired from the same special_tell signal",
		"script": "res://src/presentation/machine_fx.gd", "fn": "special_moment", "token": "fire(row[moment], top, tint, cls)"},
	{"facts": ["pressure:flank_call", "pressure:boil_rumble"], "traced": true, "what": "a hazard chevron over the caller until the telegraph",
		"script": "res://src/presentation/presentation.gd", "fn": "_on_pressure_cue", "token": "vfx.glyph(\"enemy_spawned\", at + Vector3.UP * 2.5"},
	{"facts": ["warn_sound:prop_crew_strain@prop_crew.gd:knock_prop", "warn_sound:cave_in_rumble@cave_ins.gd:surface_at"], "traced": false, "what": "the committed floor warning under the falling slab",
		"script": "res://src/world/events/rubble_fall.gd", "fn": "_commit", "token": "hazard.commit_annulus(id, Threat.Type.INSTANT, centre"},
	{"facts": ["site:fleet.gd:_step_line:zipline_whine"], "traced": false, "what": "the trolley itself, riding the line the whine is attached to",
		"script": "res://src/world/events/fleet.gd", "fn": "_step_line", "token": "FoleyAudio.player(\"zipline_whine\", trolley)"},
	{"facts": ["site:fleet.gd:_lift:lift_cage_arrive"], "traced": false, "what": "the cage's landing mark the clank is placed on",
		"script": "res://src/world/events/fleet.gd", "fn": "_lift", "token": "FoleyAudio.one_shot(\"lift_cage_arrive\", self, state.mark"},
	{"facts": ["site:waking.gd:top:seal_ratchet"], "traced": false, "what": "the crew casting's seam strip brightens with seal progress",
		"script": "res://src/combat/crew_fitter.gd", "fn": "_update_cue", "token": "energy = lerpf(SEAM_LIT, SEAM_SEALING"},
	{"facts": ["site:projectile.gd:top:vault_rise"], "traced": true, "what": "the incoming shell's rim lights when the ball can bat it",
		"script": "res://src/combat/projectile.gd", "fn": "_build_rim", "token": "_rim_quad.size = Vector2.ONE * RIM_SIZE"},
	{"facts": ["music:riser_natural", "music:riser_dam_siren"], "traced": true, "what": "the natural family's telegraph mark, laid while the riser plays",
		"script": "res://src/world/events/natural.gd", "fn": "handle", "token": "\"mark\": _mark(row, state.geometry)"},
	{"facts": ["music:riser_fleet"], "traced": true, "what": "the dropship vessel, drawn while the riser plays",
		"script": "res://src/world/events/fleet.gd", "fn": "handle", "token": "active[row.id] = {\"mark\": _vessel(row)}"},
	{"facts": ["music:riser_industrial"], "traced": true, "what": "the industrial hazard, painted while the riser plays",
		"script": "res://src/world/events/industrial.gd", "fn": "_telegraph", "token": "hazard.commit_annulus(row.id, Threat.Type.INSTANT, at"},
	{"facts": ["family:cause_note_"], "traced": false, "what": "the Warden ring's arcs light with posture (the posture phrase); the same notes also spell a synergy motif, which is a reward",
		"script": "res://src/presentation/warden_ring.gd", "fn": "_sync", "token": "visible = active()"},
	{"facts": ["tele@waking.gd:_warned:id"], "traced": false, "what": "the Mind-arena hazard laid before the publish (the floor-drop warning at waking.gd:239 shares this emit and is not traced)",
		"script": "res://src/boss/waking.gd", "fn": "_lay_pending", "token": "ctx.root.add_child(h)"},
	{"facts": ["bank:sable_ready", "bank:rivet_ready", "bank:kest_ready", "bank:tarn_ready", "bank:tally_ready", "bank:cannon_ready"], "traced": true, "what": "the slot's ready swell on the ability bar (heard through UI_ROWS:ability_ready as the class's own ready pulse)",
		"script": "res://src/ui/ability_bar.gd", "fn": "update_slots", "token": "_pulses[id] = PULSE_SECONDS"},
	{"facts": ["bank:verb_fail_select"], "traced": true, "what": "the refused slot shakes and flashes slate",
		"script": "res://src/ui/ability_bar.gd", "fn": "refuse", "token": "_refusals[slot] = SHAKE_TIME"},
	{"facts": ["bank:threat_tear"], "traced": true, "what": "the lane's mark repaints live as the fill ends",
		"script": "res://src/boss/hazard.gd", "fn": "step", "token": "_paint(reshaped)"},
	{"facts": ["sig:weak_point_opened@warden.gd:_begin_stagger", "sig:weak_point_opened@stub_boss.gd:_publish_posture"], "traced": true, "what": "the Warden ring's lit arcs take the plate's open colour while the Warden is staggered",
		"script": "res://src/presentation/warden_ring.gd", "fn": "_sync", "token": "_arc_materials[i].albedo_color = arc_color(i)"},
	{"facts": ["sig:weak_point_opened@stub_boss.gd:_open_weak"], "traced": true, "what": "the opened part is redrawn on the same call",
		"script": "res://src/boss/stub_boss.gd", "fn": "_open_weak", "token": "_sync_part(id)"},
	{"facts": ["roster:hooker.hold", "roster:mag_trapper.hold", "roster:netcaster.hold", "roster:bola_thrower.hold", "roster:winch_drone.hold", "roster:gyro_jammer.hold", "roster:catch_trap.hold"], "traced": true, "what": "holds.gd draws the striped binding line from the holder to the ball and a bracket on the ball for as long as the hold lasts",
		"script": "res://src/combat/holds.gd", "fn": "_process", "token": "_stripes(mesh, from, ball)",
		"also": [{"what": "the bracket on the held ball", "script": "res://src/combat/holds.gd", "fn": "_process", "token": "_draw_bracket(ball)"}]},
]

const OPEN := [
	{"fact": "WORLD_ROWS:ancient_stirring", "traced": true, "plays": "src/world/event_director.gd:_advance_park", "pattern": "_park_world(selected, selected.row.telegraph.form, \"telegraph\")",
		"what": "the ancient family's telegraph only prepares an overlay (ancient.gd handle, _prepare); nothing is drawn in the world until the land action. The announce toast and the edge marker do show, but name no place on the ground, so under the rule in this file the row stays open. Fires in the dam (toe_vents_wake) and the flume (bend_relic_wakes)", "severity": "info"},
	{"fact": "music:riser_ancient", "traced": true, "plays": "src/world/event_director.gd:_advance_park", "pattern": "_park_world(selected, selected.row.telegraph.form, \"telegraph\")",
		"what": "the riser that plays under ancient_stirring: the same missing mark in the world", "severity": "info"},
	{"fact": "music:riser_mind_quote", "traced": false, "plays": "src/world/event_director.gd:_advance_park", "pattern": "_park_world(selected, selected.row.telegraph.form, \"telegraph\")",
		"what": "the Mind's riser, ancient family: same missing mark (world 3, not traced)", "severity": "info"},
	{"fact": "WORLD_ROWS:sluice_siren", "traced": true, "plays": "src/world/event_director.gd:_advance_park", "pattern": "_park_world(selected, selected.row.telegraph.form, \"telegraph\")",
		"what": "the flume head gate's siren: industrial.gd handle returns for sluice_surge so no mark is laid; the toast and edge marker show. The water chases but never hurts, hence info. The sound is sluice_siren_two_tone, shared with no other row", "severity": "info"},
	{"fact": "cued@boss.gd:_step_reprise:slag_ring_a", "traced": true, "plays": "src/boss/boss.gd:_step_reprise", "pattern": "_phases.cue(",
		"what": "Brindle's slag ring reprise: the cue sounds, the ring commits CUE_LEAD later with the shorter CUED_WARN because the cue paid for it; nothing is drawn during the lead, so a muted player gets a shorter warning and no tell", "severity": "fairness"},
	{"fact": "sig:weak_point_opened@mind_hand.gd:_go_live", "traced": false, "plays": "src/combat/mind_hand.gd:_go_live", "pattern": "weak_point_opened.emit(",
		"what": "the Mind hand's lens opens on go-live; world 3, no twin traced", "severity": "info"},
]

const RELAY := {
	"ROWS:boss_attack_telegraphed": "judged at each place that publishes it (the tele@ rows)",
	"ROWS:attack_cued": "judged at each place that cues it (the cued@ rows)",
	"ROWS:weak_point_opened": "judged at each emit site (the sig@ rows)",
	"ROWS:hold_started": "the heard sound is chosen per unit at the roster hold rows",
	"STATE_ROWS:held": "the heard sound is chosen per unit at the roster hold rows",
	"cued@fight_phases.gd:cue:emit": "the shared relay: its callers are the cued@ rows",
	"WORLD_ROWS:arena_locked": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:arena_wave": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:arena_unlocked": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:warden_gate_pip": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:warden_gate_refused": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:warden_gate_opened": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:overtime_offered": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:overtime_rung": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:overtime_paid": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:sluice_warning": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:sluice_open": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:call_window": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:shot_called": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:call_met": "judged at each world_fact.emit site (the emit@ rows)",
	"WORLD_ROWS:call_missed": "judged at each world_fact.emit site (the emit@ rows)",
}

const NOT_ACT := [
	{"why": "a stinger, music line or flow mark: a card, the HUD or the world already shows the same state", "traced": false,
		"facts": ["ROWS:run_started", "ROWS:flow_changed", "ROWS:world_entered", "ROWS:stage_entered", "ROWS:stage_cleared", "ROWS:run_ended", "ROWS:beacon_charge_changed", "ROWS:warden_sighted", "ROWS:warden_engaged", "ROWS:stage_content_cleared", "ROWS:milestone_won", "ROWS:event_started", "ROWS:event_progress", "ROWS:launched", "ROWS:pressure_changed", "ROWS:boss_arena_entered", "ROWS:fight_phase_changed", "ROWS:boss_defeated", "ROWS:vent_erupted", "ROWS:swarm_scattered", "ROWS:mind_adapted", "ROWS:bay_entered", "ROWS:bay_left", "ROWS:world_fact", "ROWS:line_state_changed", "UI_ROWS:run_timer", "WORLD_ROWS:layer_undercroft", "WORLD_ROWS:layer_shelf", "WORLD_ROWS:layer_sky", "WORLD_ROWS:layer_crown_hoodoos", "WORLD_ROWS:layer_crown_alcove", "WORLD_ROWS:layer_crown_toppled", "WORLD_ROWS:layer_crown_ramp", "WORLD_ROWS:layer_mind_quote_spillway", "WORLD_ROWS:landmark_hum"]},
	{"why": "a hit taken while the shell is hot: the same hit already sounds hurt and flashes, and this only adds the bite", "traced": true,
		"facts": ["site:audio.gd:_tend_heat:heat_hot_hit"]},
	{"why": "a reward, pickup, score or discovery: pays the player and asks nothing", "traced": false,
		"facts": ["ROWS:achievement_earned", "ROWS:rescue_completed", "ROWS:quick_break", "ROWS:scrap_collected", "ROWS:cogs_collected", "ROWS:part_gained", "ROWS:panel_gained", "ROWS:heft_class_changed", "ROWS:heft_class_dropped", "ROWS:core_gained", "ROWS:synergy_discovered", "ROWS:interaction_found", "ROWS:reward_chosen", "ROWS:tree_offered", "ROWS:tree_picked", "ROWS:ambush_ended", "ROWS:bet_resolved", "ROWS:activity_done", "ROWS:drop_landed", "ROWS:missed_drop", "ROWS:evolution_fired", "site:audio.gd:wire_optional:evolution_fired", "STATE_ROWS:beacon_open", "ROWS:radio_take_found", "ROWS:relay_stake_paid", "ROWS:maker_set_completed", "ROWS:overflow_cashed", "ROWS:trade_taken", "LOOT_ROWS:item_proc", "LOOT_ROWS:par_split", "WORLD_ROWS:ledger_returned"]},
	{"why": "echo of the player's own move, hit, press or ride; they see it as it happens", "traced": false,
		"facts": ["UI_ROWS:guard_critical", "ROWS:escape_window", "ROWS:enemy_killed", "ROWS:jumped", "ROWS:boosted", "ROWS:dashed", "ROWS:landed", "ROWS:bumped", "ROWS:slammed", "ROWS:carved", "ROWS:grapple_fired", "ROWS:grapple_released", "ROWS:mounted", "ROWS:dismounted", "ROWS:enemy_struck", "ROWS:shot_fired", "ROWS:special_used", "ROWS:strike_deflected", "ROWS:element_resolved", "ROWS:boss_weak_point_hit", "ROWS:boss_reeled", "ROWS:enemy_rebounded", "ROWS:enemy_pinned", "ROWS:enemy_walled", "ROWS:enemy_ringed_out", "ROWS:vault_kicked", "ROWS:gauge_charging", "ROWS:gauge_released", "ROWS:gauge_cancelled", "ROWS:sprint_started", "ROWS:cc_ignored", "ROWS:cloak_started", "ROWS:cloak_broken", "ROWS:sticky_detonated", "ROWS:rocket_jumped", "ROWS:blink_used", "ROWS:arc_slammed", "ROWS:skid_smashed", "ROWS:demo_slammed", "ROWS:hold_broken", "ROWS:hold_ended", "ROWS:tenacity_gained", "ROWS:shield_vaulted", "ROWS:near_miss", "ROWS:interact_armed", "ROWS:interact_fired", "ROWS:verb_failed", "ROWS:prompt_shown", "ROWS:cause_armed", "ROWS:cause_fired", "ROWS:posture_changed", "ROWS:slot_selected", "ROWS:slot_cast", "ROWS:line_skill_fired", "ROWS:line_skill_expired", "ROWS:active_fired", "ROWS:active_heat", "ROWS:ultimate_started", "ROWS:ultimate_peak", "ROWS:ultimate_landed", "ROWS:ultimate_cancelled", "ROWS:special_broken", "UI_ROWS:posture_break", "UI_ROWS:ability_cooling", "UI_ROWS:ability_active", "UI_ROWS:ability_unavailable", "UI_ROWS:cooldown_refunded", "UI_ROWS:key_glyph", "WORLD_ROWS:drain_gurgle", "WORLD_ROWS:shell_air_shift", "WORLD_ROWS:lift_fired", "WORLD_ROWS:launcher_charging", "WORLD_ROWS:cannon_fired", "WORLD_ROWS:trebuchet_fired", "WORLD_ROWS:glaze_skim", "WORLD_ROWS:cinder_cooled", "WORLD_ROWS:geyser_fired", "WORLD_ROWS:valve_smashed", "WORLD_ROWS:route_opened", "WORLD_ROWS:wall_crumbled", "WORLD_ROWS:steam_lift_fired", "WORLD_ROWS:breach_opened"]},
	{"why": "danger-listed enemy_arrive: the spawned body appears at the same call (combat.gd spawn_enemy adds it before the emit) and asks nothing until its windup, which is its own row", "traced": true,
		"facts": ["ROWS:enemy_spawned"]},
	{"why": "a menu, shop, camp, ride or tutorial sound: the screen in use shows it", "traced": false,
		"facts": ["UI_ROWS:callout_scrap", "UI_ROWS:callout_warden", "UI_ROWS:callout_gates", "UI_ROWS:callout_notes", "UI_ROWS:hint_wall_bait", "UI_ROWS:companion_ready", "UI_ROWS:companion_spent", "UI_ROWS:escape_acted", "LOOT_ROWS:shop_entered", "LOOT_ROWS:shop_left", "LOOT_ROWS:shop_bought", "LOOT_ROWS:shop_charge", "LOOT_ROWS:shop_rerolled", "LOOT_ROWS:shop_sold", "LOOT_ROWS:shop_refused", "LOOT_ROWS:moss_beat", "LOOT_ROWS:moss_relent", "LOOT_ROWS:reward_common", "LOOT_ROWS:reward_rare", "LOOT_ROWS:reward_reveal", "LOOT_ROWS:reward_ceremony", "LOOT_ROWS:reward_payoff", "LOOT_ROWS:armor_hit", "LOOT_ROWS:armor_reclaim", "LOOT_ROWS:armor_deflect", "WORLD_ROWS:crater_ride", "WORLD_ROWS:ride_grapple_line", "WORLD_ROWS:ride_glide_drop", "WORLD_ROWS:ride_skylight", "WORLD_ROWS:ride_chute", "WORLD_ROWS:ride_bowl", "WORLD_ROWS:ride_drop", "WORLD_ROWS:ride_ledge", "WORLD_ROWS:ride_hop", "WORLD_ROWS:ride_sheet", "WORLD_ROWS:hoist_ride", "WORLD_ROWS:pool_swell", "WORLD_ROWS:thermal_ride", "WORLD_ROWS:reactor_vented", "WORLD_ROWS:bay_bell", "WORLD_ROWS:bay_jukebox", "WORLD_ROWS:bay_marble_note", "WORLD_ROWS:bay_pins", "WORLD_ROWS:lap_started", "WORLD_ROWS:lap_checkpoint", "WORLD_ROWS:lap_finished"]},
	{"why": "a menu move, confirm or back: the page in use shows it, and audio.gd's one frame step (menu_sounds.gd) fires all three for every page", "traced": true,
		"facts": ["site:audio.gd:_step_menu_sounds:menu_move", "site:audio.gd:_step_menu_sounds:menu_confirm", "site:audio.gd:_step_menu_sounds:menu_back"]},
	{"why": "lands after its warning, which sounded and showed first; the result is already in view", "traced": false,
		"facts": ["WORLD_ROWS:ground_slump_landed", "WORLD_ROWS:flood_landed", "WORLD_ROWS:fleet_landed", "WORLD_ROWS:cage_landed", "WORLD_ROWS:zipline_landed", "WORLD_ROWS:ancient_erupted", "WORLD_ROWS:boiler_landed", "WORLD_ROWS:lightning_landed", "WORLD_ROWS:crust_crack_landed", "WORLD_ROWS:drain_landed", "WORLD_ROWS:trestle_landed", "WORLD_ROWS:lightning_mark_landed", "WORLD_ROWS:reactor_landed", "WORLD_ROWS:sluice_landed", "WORLD_ROWS:cave_in_swap", "WORLD_ROWS:impact_swap"]},
	{"why": "the harpoon line's own state, drawn by the line as the player works it", "traced": false,
		"facts": ["LINE_ROWS:dry_fire", "LINE_ROWS:latched_world", "LINE_ROWS:latched_body", "LINE_ROWS:smash_committed", "LINE_ROWS:smash_lands", "LINE_ROWS:rewinding", "LINE_ROWS:let_go", "LINE_ROWS:broke", "LINE_ROWS:chain_link", "LINE_ROWS:chain_end", "LINE_ROWS:chain_miss"]},
	{"why": "a visual state row: the state itself is the drawing, and its sound echoes the player's hit or break", "traced": false,
		"facts": ["STATE_ROWS:posture_step", "STATE_ROWS:chunk_shatter", "STATE_ROWS:open", "STATE_ROWS:glancing"]},
	{"why": "an activity site found: the site is a world object seen as the player approaches", "traced": false,
		"facts": ["ACTIVITY_ROWS:enemy_camp", "ACTIVITY_ROWS:surge_run", "ACTIVITY_ROWS:ambush_altar", "ACTIVITY_ROWS:cracked_cache", "ACTIVITY_ROWS:hauler_bounty", "ACTIVITY_ROWS:hold_the_relay"]},
	{"why": "echo of the player's own move, hit or press, or a pilot's own kit sound, seen as it happens (a refused press shows on its slot's cooling state)", "traced": false,
		"facts": ["bank:active_cutting_torch", "bank:active_glass_lance", "bank:active_lift_pulse", "bank:active_quake_knock", "bank:active_silo_battery", "bank:armor_shed_big", "bank:armor_shed_small", "bank:cable_kest_blast", "bank:cable_kest_fizz", "bank:cable_kest_set", "bank:cannon_recall", "bank:clip_tally", "bank:crit_ping", "bank:find_drip", "bank:find_radio", "bank:grown_crack", "bank:grown_rattle", "bank:grown_sub", "bank:grown_tail", "bank:kest_low_thump", "bank:line_claw_drag", "bank:line_hum", "bank:panel_cache", "bank:plate_tally", "bank:raid_kest_boom", "bank:raid_kest_roll", "bank:raid_kest_stinger", "bank:raid_kest_tick", "bank:rivet_hihat_roll", "bank:rivet_line_arrive", "bank:rivet_line_punch", "bank:sable_arpeggio", "bank:settle_tally", "bank:slow_dip", "bank:slow_rise", "bank:stroke_tally", "bank:swarm_buzz", "bank:tally_balance_due", "bank:tarn_latch_tear", "bank:tick_kest_53", "bank:tick_kest_57", "bank:tick_kest_62", "bank:verb_fail_active", "bank:verb_fail_boost", "bank:verb_fail_fire", "bank:verb_fail_haul", "bank:verb_fail_interact", "bank:verb_fail_jump", "bank:verb_fail_roll", "bank:verb_fail_special", "bank:verb_fail_ultimate"]},
	{"why": "a reward, discovery, companion or opt-in object: pays or colours, asks nothing; a near miss is a reward", "traced": false,
		"facts": ["bank:ally_hum_kest", "bank:ally_hum_rivet", "bank:ally_hum_sable", "bank:ally_wake", "bank:bet_clunk", "bank:bet_crack", "bank:bet_refusal", "bank:bet_roll", "bank:ceremony_resolve", "bank:fight_arm_stamp", "bank:hype_drop", "bank:kill_chain_tier", "bank:kill_chain_tier_1", "bank:kill_chain_tier_2", "bank:kill_chain_tier_3", "bank:kill_chain_tier_4", "bank:kill_chain_tier_5", "bank:lore_found", "bank:near_miss_whip_cannon", "bank:near_miss_whip_kest", "bank:near_miss_whip_rivet", "bank:near_miss_whip_sable", "bank:near_miss_whip_tally", "bank:near_miss_whip_tarn", "bank:pickup_fountain", "bank:pilot_unlocked", "bank:pilot_unlocked_cannon", "bank:pilot_unlocked_kest", "bank:pilot_unlocked_rivet", "bank:pilot_unlocked_sable", "bank:pilot_unlocked_tally", "bank:pilot_unlocked_tarn", "bank:rarity_bell_common", "bank:rarity_bell_epic", "bank:rarity_bell_rare", "bank:rung_coil", "bank:scrap_tick_1", "bank:scrap_tick_2", "bank:scrap_tick_3", "bank:scrap_tick_4", "bank:scrap_tick_5", "bank:sunken_bell", "bank:synergy_fired"]},
	{"why": "music, a class motif or a mood sound: the matching state is already on a card, the HUD or the world", "traced": false,
		"facts": ["bank:babble", "bank:cannon_break", "bank:crater_hold", "bank:door_tick", "bank:kest_break", "bank:lift_hiss", "bank:mind_cannon", "bank:mind_kest", "bank:mind_rivet", "bank:mind_tally", "bank:mind_tarn", "bank:mind_wrong_cannon", "bank:mind_wrong_kest", "bank:mind_wrong_rivet", "bank:mind_wrong_sable", "bank:mind_wrong_tally", "bank:mind_wrong_tarn", "bank:rivet_break", "bank:sable_break", "bank:stinger_world_down5", "bank:stinger_world_up5", "bank:tally_break", "bank:tarn_break"]},
	{"why": "a special's presence loop, spawn or death sting, or a landing after its warning: already in view or already warned", "traced": false,
		"facts": ["bank:ballast_brace_slam", "bank:boiler_burst", "bank:cave_in_debris", "bank:dispatcher_break", "bank:dispatcher_presence", "bank:dispatcher_spawn", "bank:fleet_anvil", "bank:foreman_break", "bank:foreman_presence", "bank:foreman_spawn", "bank:gap_net_charge_live", "bank:jolt_layer_break", "bank:jolt_layer_fizzle", "bank:jolt_layer_jam", "bank:jolt_layer_presence", "bank:linker_break", "bank:linker_presence", "bank:linker_spawn", "bank:prop_crew_collapse", "bank:splitter_break_clean", "bank:splitter_break_split", "bank:splitter_presence", "bank:splitter_spawn", "site:prop_crew.gd:_build_tool:prop_crew_presence"]},
	{"why": "in the bank but no code in src/ plays it (checked by literal search): not heard today", "traced": true,
		"facts": ["bank:ballast_brace_tell", "bank:gap_net_charge_tell"]},
	{"why": "a stand-in no scanned fact names since wave 44: its rows (demo_slammed, skid_smashed, arc_slammed) now hear their own sound_next and keep it as their `sound` fallback (own_sounds_test checks each row hears its own). zap_hum still plays outside the scan: rows.gd maps electric element reactions to it and roster.gd gives it as the netcaster's hold", "traced": true,
		"facts": ["bank:kest_demo_knock", "bank:rivet_skid_plate", "bank:zap_hum"]},
	{"why": "the called shot is the player's own wager; its stamp and the Warden mark are on screen", "traced": false,
		"facts": ["emit:call_met@called_shot.gd:settle", "emit:call_missed@called_shot.gd:settle", "emit:call_window@called_shot.gd:_on_engaged", "emit:shot_called@called_shot.gd:_release"]},
	{"why": "the overtime bell and pot are world props that offer and pay: a reward", "traced": false,
		"facts": ["emit:overtime_offered@overtime.gd:offer", "emit:overtime_paid@overtime.gd:cash", "emit:overtime_rung@overtime.gd:ring"]},
	{"why": "progress tick: the pip lights on the Warden's collar in the same step (stage_locks.gd _dress_collar)", "traced": true,
		"facts": ["emit:warden_gate_pip@stage_locks.gd:_count_packs", "emit:warden_gate_pip@stage_locks.gd:_unlock"]},
	{"why": "the companion's assist sting: the assist is on screen", "traced": false,
		"facts": ["family:companion_assist_"]},
	{"why": "a note placed on the band grid for a landing, a near miss, a dunk or a death: scores a moment", "traced": false,
		"facts": ["family:grid_note_"]},
	{"why": "the band's answer to a long kill chain: a reward", "traced": false,
		"facts": ["family:pilot_quote_"]},
	{"why": "character babble under a spoken line whose words are shown", "traced": false,
		"facts": ["family:say|"]},
	{"why": "the band's phrase answer: music", "traced": false,
		"facts": ["family:set_answer_"]},
	{"why": "lands after its riser and the telegraph mark: the result is in view", "traced": false,
		"facts": ["music:drop_ancient", "music:drop_boiler", "music:drop_cave_in", "music:drop_collapse", "music:drop_cracked_wall", "music:drop_drain", "music:drop_flash_flood", "music:drop_fleet", "music:drop_fleet_anvil", "music:drop_flood", "music:drop_flood_horn", "music:drop_impact", "music:drop_industrial", "music:drop_lightning", "music:drop_mind_wrong", "music:drop_natural", "music:drop_reactor_blow", "music:drop_relic_wake", "music:drop_sluice_surge", "music:drop_spill_boiler", "music:drop_spill_dropship", "music:stinger_lightning"]},
	{"why": "echo of the player's own hit or move, or a hit result, seen as it happens", "traced": false,
		"facts": ["site:audio.gd:_on_player_hit:armor_deflect", "site:audio.gd:_on_spill_recovered:armor_reclaim", "site:audio.gd:top:chain_crash", "site:audio.gd:top:chunk_low", "site:audio.gd:wire_optional:element_resolved", "site:audio.gd:_connect_dunk:smash_crack", "site:audio.gd:_connect_redline:smash_crack", "site:audio.gd:_connect_redline:smash_crack#2", "site:audio.gd:_connect_dunk:smash_whistle", "site:audio.gd:_connect_redline:smash_whistle", "site:audio.gd:_on_struck:synergy_hit", "site:audio.gd:top:vault_drop", "site:audio.gd:_on_struck:vault_rise", "site:audio.gd:_on_wear_patch:wear_sputter", "site:audio.gd:_on_slammed:womp", "site:juice.gd:_flush_kills:kill_pop", "site:panel_fx.gd:_on_panel_gained:panel_jackpot", "site:panel_fx.gd:_on_panel_gained:panel_note"]},
	{"why": "lands after its warning (the whine and the trolley) which sounded and showed first", "traced": false,
		"facts": ["site:fleet.gd:_zipline:zipline_snap", "site:fleet.gd:cut_line:zipline_snap"]},
]
