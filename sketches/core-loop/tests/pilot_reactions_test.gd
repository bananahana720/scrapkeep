extends SceneTree

const Game := preload("res://src/game.gd")
const Hero := preload("res://src/presentation/hero_assets.gd")
const Reactions := preload("res://src/presentation/pilot_reactions.gd")
const ClassDef := preload("res://src/core/class_def.gd")

var failures := 0
var game
var ticks := 0
var policy_only := false


func check(label: String, condition: bool) -> void:
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		failures += 1


func _initialize() -> void:
	policy_only = "--policy-only" in OS.get_cmdline_user_args()
	if not policy_only:
		check_assets()
	else:
		print("POLICY FIXTURE MODE: synthetic clip aliases; does not verify delivered GLBs")
	game = Game.new()
	game.test_mode = true
	root.add_child(game)


func check_assets() -> void:
	for class_id in Hero.PILOTS:
		var pilot: Node = load(Hero.PILOTS[class_id]).instantiate()
		var animator := pilot.find_child("AnimationPlayer", true, false) as AnimationPlayer
		check(class_id + " has AnimationPlayer", animator != null)
		if animator == null:
			pilot.free()
			continue
		for event in Reactions.ROWS:
			var clip := Reactions.clip_for(Reactions.ROWS[event], class_id)
			check("%s / %s -> %s exists (including pending rows)" % [class_id, event, clip], animator.has_animation(clip))
		for clip in animator.get_animation_list():
			if clip == "RESET":
				continue
			var animation := animator.get_animation(clip)
			check("%s / %s does not loop" % [class_id, clip], animation.loop_mode == Animation.LOOP_NONE)
			var bone_tracks_only := true
			for track in animation.get_track_count():
				var path := animation.track_get_path(track)
				var kind := animation.track_get_type(track)
				bone_tracks_only = bone_tracks_only and path.get_subname_count() == 1 and kind in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]
			check("%s / %s only animates skeleton bones" % [class_id, clip], bone_tracks_only)
		pilot.free()


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
		print("pilot_reactions_test%s: %s" % [" (policy fixture only)" if policy_only else "", "PASS" if failures == 0 else "FAIL"])
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
			for clip in ["big_cheer", "wince", "slump", "phew"]:
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
		check(class_id + " pending event cannot fire", not hero.react(player, "missed_drop"))
		check(class_id + " unknown event cannot fire", not hero.react(player, "not_an_event"))
		check(class_id + " near miss starts", hero.react(player, "near_miss"))
		finish(rec)
		check(class_id + " clip finishes seated", rec.reaction == "" and not animator.is_playing())
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
