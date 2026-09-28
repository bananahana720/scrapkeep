extends RefCounted

# The game's whole shape, in one table (Andrew, 2026-09-28: "scaffold the rest of the
# systems ... leave it as question marks or placeholders ... in case we might have to
# change certain parts of the game"). The home screen, every list, every placeholder
# page and the victory teaser read this table; nothing else names an entry. Filling one
# in later means flipping its status to live, pointing its route at a real screen, and
# dropping its "???".
#
# Each entry:
#   id        unique name; nesting goes through parent ("" is the home screen)
#   title     what the button and page show ("???" while the thing is a secret)
#   status    live (the game has it today) or placeholder (a page, not a feature)
#   parent    the entry it nests under, "" for the home screen
#   key       the menu key on its screen (unique per level; never Space, H, L, G, M, or a
#             key the dead, summary or class-select screens use: R N C T Enter 1 to 3 are
#             their keys, so a level with digits is only ever reached from the title)
#   teaser    one player-facing line, at most TEASER_WORDS words
#   route     live leaves only: "start" opens class select, the run flow as it stands
#   note      dev-only: what the entry will become. Players never see it.
#   avenues   dev-only: zero to three directions a design run could explore
#   touches   dev-only: the systems and files it affects once built, as paths under
#             sketches/core-loop (the blast-radius list a design run starts from)

const LIVE := "live"
const PLACEHOLDER := "placeholder"
const TEASER_WORDS := 8
const HOME := ""
const HOME_TITLE := "HOME"
const UNKNOWN := "???"
# The entry the victory screen teases once Brindle is routed.
const AFTER_BRINDLE := "world_2"

const ENTRIES := [
	{
		"id": "play", "title": "Play", "status": LIVE, "parent": HOME, "key": "P",
		"teaser": "Pick how to roll.", "route": "",
		"note": "The mode list. Run is today's run flow; every other mode is a variation on it that reads the same run_state.",
		"avenues": [], "touches": ["src/core/flow.gd", "src/core/loop_mode.gd"],
	},
	{
		"id": "mode_run", "title": "Run", "status": LIVE, "parent": "play", "key": "1",
		"teaser": "World one: three stages, then Brindle.", "route": "start",
		"note": "Today's run, unchanged.", "avenues": [], "touches": [],
	},
	{
		"id": "mode_endless", "title": "Endless", "status": PLACEHOLDER, "parent": "play", "key": "2",
		"teaser": "How far can the momentum carry?", "route": "",
		"note": "No last stage: the stages repeat and harden until the run ends. Ranked by how far, so the score is stage time and depth.",
		"avenues": ["stages loop with plating and the director's packs scaled per lap, ended only by death", "Moss's bay after every third stage as the run's only shop"],
		"touches": ["src/core/flow.gd", "src/core/run_state.gd", "src/core/stage_defs.gd", "src/world/director.gd", "src/core/run_log.gd", "src/boss/boss.gd"],
	},
	{
		"id": "mode_daily", "title": "Daily seed", "status": PLACEHOLDER, "parent": "play", "key": "3",
		"teaser": "One seed a day, shared.", "route": "",
		"note": "Everyone gets the same seed for a day. Needs the run to be fully replayable from a seed, and somewhere to keep scores.",
		"avenues": ["one shared seed per day with a leaderboard of stage times", "the seed also fixes the item pool's draw order, so a route can be compared"],
		"touches": ["src/core/run_state.gd", "src/core/run_log.gd", "src/build/item_gen.gd", "src/build/items.gd", "src/world/director.gd", "src/build/run_clock.gd"],
	},
	{
		"id": "mode_mutated", "title": "Mutated seeds", "status": PLACEHOLDER, "parent": "play", "key": "4",
		"teaser": "Start hot-wired, with a readable catch.", "route": "",
		"note": "Hot-wired starting seeds (ROADMAP, Feedback and discovery): a run begins with a double-edged part or rule already in place.",
		"avenues": ["a starting part with a large upside and a readable downside, picked from a short list", "a seed field that biases the director's tags for the whole run"],
		"touches": ["src/build/items.gd", "src/build/item_gen.gd", "src/build/reward_gates.gd", "src/core/run_log.gd", "src/core/codex.gd", "tests/loop_coherence_test.gd", "tests/loop_bot_test.gd"],
	},
	{
		"id": "mode_challenge", "title": "Challenge", "status": PLACEHOLDER, "parent": "play", "key": "5",
		"teaser": "Little gear, or the clock.", "route": "",
		"note": "Constrained runs: a stripped loadout, or a hard timer. Two families, one page each once designed.",
		"avenues": ["little gear: no shop and a cap on parts held", "against a timer: the run clock as a hard limit with a bonus for early Wardens"],
		"touches": ["src/build/run_clock.gd", "src/build/shop.gd", "src/core/run_state.gd", "src/core/flow.gd", "src/core/run_log.gd"],
	},
	{
		"id": "worlds", "title": "Worlds", "status": LIVE, "parent": HOME, "key": "W",
		"teaser": "Where the run can go.", "route": "",
		"note": "The world list. Only world one is inside the alpha's scope.",
		"avenues": [], "touches": ["src/core/stage_defs.gd", "src/world/stage_map.gd"],
	},
	{
		"id": "world_1", "title": "World 1", "status": LIVE, "parent": "worlds", "key": "1",
		"teaser": "Three stages, three Wardens, Brindle.", "route": "start",
		"note": "Today's world.", "avenues": [], "touches": [],
	},
	{
		"id": "world_2", "title": UNKNOWN, "status": PLACEHOLDER, "parent": "worlds", "key": "2",
		"teaser": "World 2: ???", "route": "",
		"note": "The world after Brindle. Nothing is decided; the victory screen teases it from here.",
		"avenues": [],
		"touches": ["src/core/stage_defs.gd", "src/world/stage_map.gd", "src/world/terrain.gd", "src/combat/roster.gd", "src/core/codex.gd"],
	},
	{
		"id": "world_3", "title": UNKNOWN, "status": PLACEHOLDER, "parent": "worlds", "key": "3",
		"teaser": "World 3: ???", "route": "",
		"note": "A later world. Held open so the count can change.",
		"avenues": [], "touches": ["src/core/stage_defs.gd", "src/world/stage_map.gd"],
	},
	{
		"id": "world_final", "title": UNKNOWN, "status": PLACEHOLDER, "parent": "worlds", "key": "4",
		"teaser": "The last world: ???", "route": "",
		"note": "The final world and its ending. Held open so the count can change.",
		"avenues": [], "touches": ["src/core/stage_defs.gd", "src/boss/boss.gd", "src/core/flow.gd"],
	},
	{
		"id": "pilots", "title": "Pilots", "status": LIVE, "parent": HOME, "key": "I",
		"teaser": "Who is at the wheel.", "route": "",
		"note": "The pilot list. The live three are today's class select.",
		"avenues": [], "touches": ["src/core/class_def.gd", "src/ui/class_card.gd"],
	},
	{
		"id": "pilot_sable", "title": "Sable", "status": LIVE, "parent": "pilots", "key": "1",
		"teaser": "Pylon engineer.", "route": "start", "note": "Class select pick one.", "avenues": [], "touches": [],
	},
	{
		"id": "pilot_rivet", "title": "Rivet", "status": LIVE, "parent": "pilots", "key": "2",
		"teaser": "Runner and gunner.", "route": "start", "note": "Class select pick two.", "avenues": [], "touches": [],
	},
	{
		"id": "pilot_kest", "title": "Kest", "status": LIVE, "parent": "pilots", "key": "3",
		"teaser": "Demolitions caster.", "route": "start", "note": "Class select pick three.", "avenues": [], "touches": [],
	},
	{
		"id": "pilot_fourth", "title": UNKNOWN, "status": PLACEHOLDER, "parent": "pilots", "key": "4",
		"teaser": "Locked. Something is warming up.", "route": "",
		"note": "The glitchy, friendly ancient robot who transmogs to the tech it holds. Locked until the unlocks system exists.",
		"avenues": ["transmogs to the last part picked up", "its kit is one slot swap per pickup, using the tree's swap op"],
		"touches": ["src/core/class_def.gd", "src/core/upgrade_tree.gd", "src/core/trees/sable.gd", "src/core/ability_state.gd", "src/ui/class_card.gd", "src/presentation/hero_assets.gd", "src/core/codex.gd"],
	},
	{
		"id": "kit_tree", "title": "Kit tree", "status": PLACEHOLDER, "parent": HOME, "key": "K",
		"teaser": "Every branch, every end build.", "route": "",
		"note": "The tree's shape as a home page. The tiers reachable in world one are live in the run; the 8- and 16-way tiers stay unbuilt (ROADMAP, The end in mind). The children here draw as nodes on the page, not as buttons.",
		"avenues": ["the 8-way tier as paired end variants of a 4-way branch", "a finished branch earns a ceremony on the reward ceremony's own tier"],
		"touches": ["src/core/upgrade_tree.gd", "src/core/trees/sable.gd", "src/core/trees/rivet.gd", "src/core/trees/kest.gd", "src/ui/tree_pick.gd", "src/ui/tree_card.gd", "src/ui/growth_sheet.gd", "src/presentation/reward_ceremony.gd"],
	},
	{
		"id": "tier_2", "title": "2-way", "status": LIVE, "parent": "kit_tree", "key": "",
		"teaser": "The first pick.", "route": "", "note": "Live in the run at class select.", "avenues": [], "touches": [],
	},
	{
		"id": "tier_4", "title": "4-way", "status": LIVE, "parent": "kit_tree", "key": "",
		"teaser": "The second pick.", "route": "", "note": "Live in the run at Moss's workshop.", "avenues": [], "touches": [],
	},
	{
		"id": "tier_8", "title": UNKNOWN, "status": PLACEHOLDER, "parent": "kit_tree", "key": "",
		"teaser": "Eight ways.", "route": "", "note": "The 8-way tier's end variation. Unbuilt.", "avenues": [], "touches": [],
	},
	{
		"id": "tier_16", "title": UNKNOWN, "status": PLACEHOLDER, "parent": "kit_tree", "key": "",
		"teaser": "Sixteen ways.", "route": "", "note": "The 16-way end builds. Unbuilt.", "avenues": [], "touches": [],
	},
	{
		"id": "codex", "title": "Codex", "status": PLACEHOLDER, "parent": HOME, "key": "X",
		"teaser": "Everything you have found.", "route": "",
		"note": "The home-menu codex. The in-run Tab codex stays as it is.",
		"avenues": ["the same entries as the Tab codex, browsable by kind, with unfound ones as ???"],
		"touches": ["src/core/codex.gd", "src/combat/codex_entries.gd", "src/boss/codex_entries.gd", "src/presentation/codex_style.gd", "src/world/codex_world.gd", "src/core/run_log.gd"],
	},
	{
		"id": "unlocks", "title": "Unlocks", "status": PLACEHOLDER, "parent": HOME, "key": "U",
		"teaser": "Earn new ground and pilots.", "route": "",
		"note": "Area and pilot unlocks, tree-branch ceremonies and meta progression. Everything here needs something that persists between runs, which the sketch does not have yet.",
		"avenues": ["a pilot or a world opens the first time a Warden falls", "a branch-complete ceremony reusing the treasure-find ceremony's grammar"],
		"touches": ["src/core/run_state.gd", "src/core/run_log.gd", "src/core/class_def.gd", "src/core/stage_defs.gd", "src/presentation/reward_ceremony.gd", "src/ui/settings_store.gd"],
	},
	{
		"id": "bay_extras", "title": "Moss's bay extras", "status": PLACEHOLDER, "parent": HOME, "key": "B",
		"teaser": "Moss keeps the good junk here.", "route": "",
		"note": "The practice yard, the fidget toys and the mini-game, outside a run.",
		"avenues": ["a practice yard on the bay's own lap course, no stakes", "fidget toys that ride the ball's real physics"],
		"touches": ["src/world/bay.gd", "src/world/bay_lap.gd", "src/world/lap_course.gd", "src/ui/workshop.gd", "src/ui/moss_bubble.gd", "src/movement/rigid_ball.gd"],
	},
	{
		"id": "settings", "title": "Settings", "status": PLACEHOLDER, "parent": HOME, "key": "S",
		"teaser": "Sound, comfort, controls.", "route": "",
		"note": "Placeholder: the only settings UI is the pause menu (src/ui/pause_menu.gd), which another unit is editing, so the title cannot reach it without touching that file. Go live by opening the same panel from here.",
		"avenues": [], "touches": ["src/ui/pause_menu.gd", "src/ui/settings_store.gd", "src/ui/volume_row.gd"],
	},
	{
		"id": "credits", "title": "Credits", "status": PLACEHOLDER, "parent": HOME, "key": "Q",
		"teaser": "Who kept the scrap rolling.", "route": "",
		"note": "Credits and thanks.", "avenues": [], "touches": [],
	},
]


static func all() -> Array:
	return ENTRIES


static func entry(id: String) -> Dictionary:
	for e in ENTRIES:
		if e["id"] == id:
			return e
	return {}


static func children(parent: String) -> Array:
	return ENTRIES.filter(func(e): return e["parent"] == parent)


static func has_children(id: String) -> bool:
	return not children(id).is_empty()


static func is_live(id: String) -> bool:
	return entry(id).get("status", "") == LIVE


# What a press on an entry does: "list" (a live entry with children), "page" (a
# placeholder), or its route ("start") for a live leaf.
static func action(id: String) -> String:
	var e := entry(id)
	if e.is_empty():
		return ""
	if e["status"] == PLACEHOLDER:
		return "page"
	if has_children(id):
		return "list"
	return e["route"]


# The line the victory screen shows under Brindle's routing.
static func after_brindle() -> String:
	return entry(AFTER_BRINDLE).get("teaser", "")
