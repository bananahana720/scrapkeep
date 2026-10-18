extends SceneTree

# Partial tables allowed 2026-10-18: a partial table lists the new roles its pilot ships (required_for).
# Re-pinned 2026-10-11 (PE-0b): table existence selects 18 or seven clips for each pilot.
# Re-pinned 2026-10-11 (PE-0, design-v3/PILOT-CLIPS.md section 8): the rows now name the eleven
# new clips, which today's GLBs lack, so the asset check follows the roster instead of the rows: a
# pilot whose src/presentation/clips/<pilot>.json exists carries all 18 roster clips, one without
# carries the seven kept ones. Fix round 2026-10-11: the table fact is the file's existence (the
# same file hero_assets.gd reads), not a roster flag; six new checks: the roster carries no flag,
# and a positive control with a probe table under user:// requires 18 and fails a seven-clip GLB. Loops are allowed only for names ending in _loop. After a one-shot the base
# loop idle_loop plays when the GLB has it, else the animator is stopped (the transitional branch;
# PE-INT removes it once all six carry 18). A row may name its bus signal under "signal", so the
# bus check reads signal_of(). The check count changes with the row and clip counts.

const Trigger := preload("res://tests/support/pilot_clip_trigger.gd")
const Game := preload("res://src/game.gd")
const Hero := preload("res://src/presentation/hero_assets.gd")
const Reactions := preload("res://src/presentation/pilot_reactions.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const ClassDef := preload("res://src/core/class_def.gd")

var failures := 0
var game
var ticks := 0
var policy_only := false
var probed := false


func check(label: String, condition: bool) -> void:
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		failures += 1


func _initialize() -> void:
	policy_only = "--policy-only" in OS.get_cmdline_user_args()
	var bus_names: Array = GameEvents.signal_names()
	for event in Reactions.ROWS:
		check(event + " carries no pending flag", not Reactions.ROWS[event].has("pending"))
		check(event + " names a signal on the bus", bus_names.has(Reactions.signal_of(event)))
	if not policy_only:
		check_assets()
	else:
		print("POLICY FIXTURE MODE: synthetic clip aliases; does not verify delivered GLBs")
	game = Game.new()
	game.test_mode = true
	root.add_child(game)



# The table fact has one source, the file. The roster carries no flag, and a probe table written
# under user:// (never res://, which parallel tests read) flips the rule for a seven-clip GLB.
func check_table_rule(animator: AnimationPlayer, stem: String) -> void:
	var flagged := []
	for name in Trigger.roster().get("pilots", {}):
		if Trigger.roster()["pilots"][name].has("has_table"):
			flagged.append(name)
	check("roster.json carries no has_table flag " + str(flagged), flagged.is_empty())
	check("probe: a missing pilot table reads as absent", not Trigger.has_table("__missing_pilot_table__"))
	var dir := "user://pilot-clips-table-probe"
	DirAccess.make_dir_recursive_absolute(dir)
	var probe := FileAccess.open(dir.path_join(stem + ".json"), FileAccess.WRITE)
	probe.store_string("{}")
	probe.close()
	var with_table := Trigger.has_table(stem, dir)
	check("probe: " + stem + " with a pose table file reads as having one", with_table)
	check("probe: a pose table requires 18 clips", Trigger.required_clips(with_table).size() == 18)
	# A seven-clip animator built from the GLB's kept clips, so the probe holds after a pilot unit
	# ships its 18-clip GLB.
	var seven := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	for clip in Trigger.required_clips(false):
		if animator.has_animation(clip):
			library.add_animation(clip, animator.get_animation(clip))
	seven.add_animation_library("", library)
	check("probe: a seven-clip GLB fails with a pose table (11 missing)", Trigger.missing_clips(seven, with_table).size() == 11)
	seven.free()
	DirAccess.remove_absolute(dir.path_join(stem + ".json"))
	check("probe: removing the file removes the table", not Trigger.has_table(stem, dir))


# Godot's scene importer strips a "_loop" suffix from animation names when name suffixes are on, so
# idle_loop would import as idle (PE-RIVET and PE-CANNON round 2, 2026-10-11). Every pilot GLB's
# import keeps names as exported and sets each roster _loop clip to loop explicitly.
func check_import_keeps_loop_names(class_id: String) -> void:
	var settings := ConfigFile.new()
	var path: String = Hero.PILOTS[class_id] + ".import"
	check(class_id + " import settings load", settings.load(path) == OK)
	check(class_id + " import keeps _loop names (nodes/use_name_suffixes=false)", settings.get_value("params", "nodes/use_name_suffixes", true) == false)
	var animations: Dictionary = settings.get_value("params", "_subresources", {}).get("animations", {})
	for clip in Trigger.required_clips(true):
		if String(clip).ends_with("_loop"):
			var mode: int = animations.get(clip, {}).get("settings/loop_mode", Animation.LOOP_NONE)
			check("%s import loops %s" % [class_id, clip], mode == Animation.LOOP_LINEAR)


func check_assets() -> void:
	for class_id in Hero.PILOTS:
		check_import_keeps_loop_names(class_id)
		var pilot: Node = load(Hero.PILOTS[class_id]).instantiate()
		var animator := pilot.find_child("AnimationPlayer", true, false) as AnimationPlayer
		check(class_id + " has AnimationPlayer", animator != null)
		if animator == null:
			pilot.free()
			continue
		root.add_child(pilot)
		var stem := Trigger.stem_of(class_id)
		check(class_id + " has a roster row", stem != "")
		if not probed:
			probed = true
			check_table_rule(animator, stem)
		var has_table := Trigger.has_table(stem)
		var required: Array = Trigger.required_for(stem)
		# A table with "partial": true ships only the roles it lists; any other table means all 18.
		check("%s carries %d roster clips (pose table %s)" % [class_id, required.size(), "present" if has_table else "absent"], required.size() >= 8 if has_table else required.size() == 7)
		for clip in required:
			check("%s / %s exists" % [class_id, clip], animator.has_animation(clip))
		for clip in animator.get_animation_list():
			if clip == "RESET":
				continue
			var animation := animator.get_animation(clip)
			var loops := animation.loop_mode != Animation.LOOP_NONE
			check("%s / %s loops only as a _loop name" % [class_id, clip], loops == String(clip).ends_with("_loop"))
			var bone_tracks_only := true
			for track in animation.get_track_count():
				var path := animation.track_get_path(track)
				var kind := animation.track_get_type(track)
				bone_tracks_only = bone_tracks_only and path.get_subname_count() == 1 and kind in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]
			check("%s / %s only animates skeleton bones" % [class_id, clip], bone_tracks_only)
		for clip in ["brace", "heave"]:
			if not animator.has_animation(clip):
				check(class_id + " / " + clip + " delivered", false)
				continue
			var animation := animator.get_animation(clip)
			var bounds := Vector2(0.5, 0.7) if clip == "brace" else Vector2(0.6, 0.9)
			check(class_id + " / " + clip + " duration in range", animation.length >= bounds.x and animation.length <= bounds.y)
			animator.play(clip)
			animator.advance(0.0)
			check(class_id + " / " + clip + " starts at rest", bones_at_rest(pilot))
			animator.advance(animation.length)
			check(class_id + " / " + clip + " ends at rest", bones_at_rest(pilot))
		pilot.free()


func bones_at_rest(pilot: Node) -> bool:
	for skeleton in pilot.find_children("*", "Skeleton3D", true, false):
		for bone in skeleton.get_bone_count():
			if not skeleton.get_bone_pose(bone).is_equal_approx(skeleton.get_bone_rest(bone)):
				return false
	return true


func _physics_process(_delta: float) -> bool:
	if game.ctx == null or game.presentation == null:
		return false
	ticks += 1
	if ticks == 1:
		game.ctx.calm = true
		game.flow.press_start()
		game.flow.choose_class(1)
		return false
	if ticks == 3:
		run_policy()
		print("pilot_reactions_test: %s%s" % ["PASS" if failures == 0 else "FAIL", " (policy fixture only)" if policy_only else ""])
		game.queue_free()
		quit(0 if failures == 0 else 1)
	return false


func finish(rec: Dictionary) -> void:
	var animator: AnimationPlayer = rec.animator
	if animator.is_playing():
		animator.advance(animator.current_animation_length + 0.1)


func run_policy() -> void:
	var hero = game.presentation.hero_assets
	var player = game.player
	for class_id in Hero.PILOTS:
		player.fit_class(ClassDef.by_id(class_id))
		hero._process(0.0)
		var rec: Dictionary = hero.shell_of(player)
		var animator: AnimationPlayer = rec.animator
		check(class_id + " has one animated pilot", rec.pod.find_children("AnimatedPilot", "", true, false).size() == 1)
		if policy_only:
			var library := AnimationLibrary.new()
			for clip in ["big_cheer", "wince", "slump", "phew", "brace", "heave"]:
				var fixture := animator.get_animation("drop_land").duplicate() as Animation
				library.add_animation(clip, fixture)
			# Empty imported library contains drop_land; add fixtures into that library.
			var imported := animator.get_animation_library("")
			for clip in library.get_animation_list():
				if not animator.has_animation(clip):
					imported.add_animation(clip, library.get_animation(clip))
		var before_body: Vector3 = Vector3(13, -2, 7)
		var before_state: Vector3 = Vector3(12, -1, 8)
		player.body().linear_velocity = before_body
		player.state.velocity = before_state
		check(class_id + " unknown event cannot fire", not hero.react(player, "not_an_event"))
		check(class_id + " near miss starts", hero.react(player, "near_miss"))
		finish(rec)
		if animator.has_animation("idle_loop"):
			check(class_id + " clip hands back to idle_loop", rec.reaction == "" and animator.is_playing() and animator.current_animation == "idle_loop")
		else:
			finish(rec)  # the clip end eases to the runtime rest clip first
			check(class_id + " clip finishes seated (no idle_loop yet)", rec.reaction == "" and not animator.is_playing())
		check(class_id + " shared cooldown blocks hold_broken after near_miss", not hero.react(player, "hold_broken"))
		hero._process(4.01)
		check(class_id + " cooldown expires", hero.react(player, "near_miss"))
		check(class_id + " hit interrupts relief", hero.react(player, "player_hit"))
		hero._process(4.01)
		check(class_id + " lower priority is dropped", not hero.react(player, "near_miss"))
		check(class_id + " victory interrupts hit", hero.react(player, "boss_defeated"))
		# Let the clip cooldown expire without advancing playback, isolating priority.
		hero._process(4.01)
		check(class_id + " equal priority is dropped", not hero.react(player, "stage_cleared"))
		check(class_id + " death interrupts victory", hero.react(player, "player_died"))
		finish(rec)
		var neutral := true
		for skeleton in rec.pilot.find_children("*", "Skeleton3D", true, false):
			for bone in skeleton.get_bone_count():
				neutral = neutral and skeleton.get_bone_pose(bone).is_equal_approx(skeleton.get_bone_rest(bone))
		check(class_id + " returns every bone to seated rest", neutral)
		check(class_id + " reaction playback preserves physical velocity", player.body().linear_velocity == before_body)
		check(class_id + " reaction playback preserves state velocity", player.state.velocity == before_state)
		hero._process(20.0)
		game.events.near_miss.emit("chaser", Vector3.ZERO)
		check(class_id + " real two-argument signal wired", rec.reaction == "phew")
		finish(rec)
		hero._process(20.0)
		game.events.harpoon_bit.emit(null, Vector3(1, 2, 3))
		check(class_id + " real harpoon_bit plays brace", rec.reaction == "brace" and animator.current_animation == "brace" and animator.is_playing())
		game.events.player_hit.emit(1.0, "test")
		check(class_id + " real player_hit interrupts brace with wince", rec.reaction == "wince" and animator.current_animation == "wince" and animator.is_playing())
		finish(rec)
		hero._process(2.0)
		game.events.harpoon_bit.emit(null, Vector3.ZERO)
		check(class_id + " brace available after cooldown", rec.reaction == "brace")
		game.events.harpoon_smashed.emit(null, Vector3(1, 2, 3), 30.0)
		check(class_id + " real harpoon_smashed plays heave over brace", rec.reaction == "heave" and animator.current_animation == "heave" and animator.is_playing())
		game.events.player_hit.emit(1.0, "test")
		check(class_id + " real player_hit interrupts heave with wince", rec.reaction == "wince" and animator.current_animation == "wince" and animator.is_playing())
		finish(rec)
		check(class_id + " harpoon reactions preserve physical velocity", player.body().linear_velocity == before_body)
		check(class_id + " harpoon reactions preserve state velocity", player.state.velocity == before_state)
		hero._process(20.0)
		game.events.evolution_fired.emit("wrecking_ball")
		check(class_id + " evolution_fired plays big_cheer", rec.reaction == "big_cheer" and animator.is_playing())
		game.events.drop_landed.emit(2)
		check(class_id + " drop_landed does not interrupt the higher evolution beat", rec.reaction == "big_cheer")
		finish(rec)
		hero._process(20.0)
		game.events.drop_landed.emit(2)
		check(class_id + " drop_landed plays drop_land", rec.reaction == "drop_land" and animator.current_animation == "drop_land" and animator.is_playing())
		game.events.missed_drop.emit()
		check(class_id + " missed_drop interrupts drop_land with wince", rec.reaction == "wince" and animator.current_animation == "wince")
		finish(rec)
		game.events.drop_landed.emit(1)
		check(class_id + " drop_land cooldown holds", rec.reaction == "")
		hero._process(1.6)
		game.events.drop_landed.emit(1)
		check(class_id + " drop_land returns after its cooldown", rec.reaction == "drop_land")
		finish(rec)
		hero._process(1.6)
		game.events.missed_drop.emit()
		check(class_id + " missed_drop alone plays wince", rec.reaction == "wince")
		finish(rec)
		check(class_id + " slam reactions preserve physical velocity", player.body().linear_velocity == before_body)
