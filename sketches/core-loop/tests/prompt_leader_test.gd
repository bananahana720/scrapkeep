extends SceneTree

# A band prompt (a fabricator's price, the vault) is placed as it always was, and keeps its type size. A reward
# gate's name is no band prompt: its gate places it (reward_gate_nameplate_test).

const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const Hud := preload("res://src/ui/hud.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("prompt_leader_test")


func _initialize() -> void:
	var size := Vector2(1600.0, 900.0)
	# Another prompt's place does not move: a band prompt lands where the band gave it before signs
	# (clamp_prompt, then free_spot in the band) and keeps its type size.
	var band_prompt := WorldPrompt.new()
	band_prompt.set_parts("Fabricating...", "3 cogs")
	var band := ScreenRegions.rect("prompts", size)
	var at := Vector2(800.0, 1000.0)
	var old_way: Rect2 = Hud.free_spot(Rect2(ScreenRegions.clamp_prompt(at, band_prompt.shown_extent(), size), band_prompt.shown_extent()), [] as Array[Rect2], band)
	var now: Rect2 = Hud.prompt_spot(band_prompt, at, size, [] as Array[Rect2])
	_t.check("a band prompt lands where it did before signs", old_way.size != Vector2.ZERO and now == old_way, "%s vs %s" % [now, old_way])
	_t.check("a band prompt keeps its type size", not band_prompt.owner_placed and band_prompt.title_size() == WorldPrompt.TITLE_SIZE and band_prompt.detail_size() == WorldPrompt.DETAIL_SIZE)
	band_prompt.free()
	quit(_t.verdict())
