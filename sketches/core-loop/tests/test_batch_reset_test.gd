extends SceneTree

const Driver := preload("res://tools/test_batch_driver.gd")
const Game := preload("res://src/game.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const BossPlate := preload("res://src/ui/boss_plate.gd")
const CallerTile := preload("res://src/ui/caller_tile.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const MossBubble := preload("res://src/ui/moss_bubble.gd")
const RewardView := preload("res://src/ui/reward_view.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const FlourishPlayer := preload("res://src/presentation/flourish_player.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const PilotAntics := preload("res://src/presentation/pilot_antics.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const WorldFxKit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const WorldFxWord := preload("res://src/presentation/world_fx/world_fx_word.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const SettingsPages := preload("res://src/ui/settings_pages.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const EnemyClips := preload("res://src/presentation/enemy_clips.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Palette := preload("res://src/core/palette.gd")
const Synth := preload("res://src/presentation/synth.gd")
const Footings := preload("res://src/world/park/footings.gd")
const RescueSite := preload("res://src/world/rescue_site.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const T := preload("res://tests/support/t.gd")

# W46-T1: tools/test_batch_driver.gd _reset() clears reduced-motion and other process-wide
# statics between tests in a warm batch so no test leaks state into a later test.

func _initialize() -> void:
	var t := T.new("test_batch_reset_test")
	var driver := Driver.new(self, [])

	# Game.set_motion_statics(true) flips every reduced-motion static, including CallerTile and EnemyMotion.
	Game.set_motion_statics(true)
	t.check("Game.set_motion_statics(true) sets every reduced-motion static",
		is_zero_approx(EnemyMotion.motion_scale)
		and HighdraftFx.preferred and WorldFx.preferred and WorldFxKit.reduced_motion
		and AbilityBar.reduced_motion and UiTokens.reduced_motion and AimReticle.reduced_motion
		and RewardView.reduced_motion and MossBubble.reduced_motion and CallerTile.reduced_motion
		and ClassCard.reduced_motion and PilotAntics.reduced_motion and ClassPreview.reduced_motion
		and BossPlate.reduced_motion and FlourishPlayer.reduced_motion)

	# Dirty other single-field process-wide statics that tests in the repo flip.
	FlashGuard.on = true
	GraphicsPreset.apply("low")
	SimClock.ticks = true
	Glyphs.device = "pad"
	SettingsPages.last_page = 2
	StageLocks.active = false
	Synergies.table = AlphaDefs
	EnemyMotion.headless_idle = true
	EnemyClips.headless = true
	Enemy.rim_color = Color.RED
	WorldFxWord.quiet(true)
	var hushed_word := WorldFxWord.stamp(root, "QUIET", Vector3.ZERO)
	t.check("WorldFxWord.quiet(true) hides newly stamped words", not hushed_word.visible)
	Synth.score_transpose = 3
	Footings.plant_ignore_lines = true
	RescueSite.model_path = "res://assets/models/__missing_cage__.glb"
	MusicRows.stem_dir = "user://no_stems"

	driver._reset()

	t.near("EnemyMotion.motion_scale resets to 1.0", EnemyMotion.motion_scale, 1.0)
	t.check("HighdraftFx.preferred resets to false", not HighdraftFx.preferred)
	t.check("WorldFx.preferred resets to false", not WorldFx.preferred)
	t.check("WorldFxKit.reduced_motion resets to false", not WorldFxKit.reduced_motion)
	t.check("AbilityBar.reduced_motion resets to false", not AbilityBar.reduced_motion)
	t.check("UiTokens.reduced_motion resets to false", not UiTokens.reduced_motion)
	t.check("AimReticle.reduced_motion resets to false", not AimReticle.reduced_motion)
	t.check("RewardView.reduced_motion resets to false", not RewardView.reduced_motion)
	t.check("MossBubble.reduced_motion resets to false", not MossBubble.reduced_motion)
	t.check("CallerTile.reduced_motion resets to false", not CallerTile.reduced_motion)
	t.check("ClassCard.reduced_motion resets to false", not ClassCard.reduced_motion)
	t.check("PilotAntics.reduced_motion resets to false", not PilotAntics.reduced_motion)
	t.check("ClassPreview.reduced_motion resets to false", not ClassPreview.reduced_motion)
	t.check("BossPlate.reduced_motion resets to false", not BossPlate.reduced_motion)
	t.check("FlourishPlayer.reduced_motion resets to false", not FlourishPlayer.reduced_motion)

	t.check("FlashGuard.on resets to false", not FlashGuard.on)
	t.eq("GraphicsPreset.current resets to high", GraphicsPreset.current, "high")
	t.check("SimClock.ticks resets to false", not SimClock.ticks)
	t.eq("Glyphs.device resets to kbm", Glyphs.device, "kbm")
	t.eq("SettingsPages.last_page resets to 0", SettingsPages.last_page, 0)
	t.check("StageLocks.active resets to true", StageLocks.active)
	t.eq("Synergies.table resets to null", Synergies.table, null)
	t.check("EnemyMotion.headless_idle resets to false", not EnemyMotion.headless_idle)
	t.check("EnemyClips.headless resets to false", not EnemyClips.headless)
	t.eq("Enemy.rim_color resets to Palette.ARC", Enemy.rim_color, Palette.ARC)
	var after_word := WorldFxWord.stamp(root, "LOUD", Vector3.ZERO)
	t.check("WorldFxWord un-hushes after reset", after_word.visible)
	after_word.free()
	t.eq("Synth.score_transpose resets to 0", Synth.score_transpose, 0)
	t.check("Footings.plant_ignore_lines resets to false", not Footings.plant_ignore_lines)
	t.eq("RescueSite.model_path resets to MODEL", RescueSite.model_path, RescueSite.MODEL)
	t.eq("MusicRows.stem_dir resets to empty", MusicRows.stem_dir, "")

	quit(t.verdict())
