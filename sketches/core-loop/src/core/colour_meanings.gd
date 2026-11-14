extends RefCounted

# What each palette colour means (VISUAL-LANGUAGE.md section 2, "Palette roles"), as rows the
# effects read and colour_meanings_test checks. palette.gd owns the hex values; this file owns
# what a colour is allowed to say. UI colours are src/ui/ui_tokens.gd's.
#
# A new effect asks for a meaning, not a colour: ColourMeanings.of("danger"). A new world's
# effects are rows that name meanings, so a colour change is one row here.

const Palette := preload("res://src/core/palette.gd")

# One meaning, one palette constant. "yours" is the pilot's class colour (class_def.gd rows),
# so it is not a constant; "reward" is the item ladder, by rung.
const MEANINGS := {
	"danger": "HAZARD",
	"live": "ARC",
	"ancient": "ANCIENT",
	"loss": "RUST",
	"boss": "BRASS",
}
const REWARD_RUNGS := {
	"common": "ARC",
	"rare": "COBALT",
	"relic": "AMBER",
}

# Colours whose meaning is reserved, and the kinds of code that must never draw them.
# A domain is a kind of code: what the player's own verbs make, an enemy's body and parts,
# or a reward. colour_meanings_test fails a reserved colour in a forbidden domain unless a
# KNOWN row below names that file and colour.
const RESERVED := {
	"HAZARD": {"meaning": "danger", "never": ["player", "reward"]},
	"ANCIENT": {"meaning": "ancient", "never": ["player", "reward"]},
	"BRASS": {"meaning": "boss", "never": ["player"]},
	"ARC": {"meaning": "live", "never": ["enemy"]},
	"COBALT": {"meaning": "reward", "never": ["enemy"]},
}

# Which source files belong to a domain. `extends` names base scripts: every script whose
# extends chain reaches one is in the domain, so a new enemy or pilot kit joins by itself.
const DOMAINS := {
	"player": {
		"extends": ["res://src/combat/ultimate.gd"],
		"dirs": ["res://src/combat/actives/"],
		"files": ["res://src/combat/ultimate.gd", "res://src/combat/rivet_kit.gd", "res://src/combat/tarn_claw.gd",
			"res://src/presentation/player_fx.gd", "res://src/presentation/damage_numbers.gd",
			"res://src/presentation/pilot_antics.gd", "res://src/build/maker_bonuses.gd", "res://src/build/called_shot.gd",
			"res://src/build/shot_bits.gd", "res://src/build/element_field.gd", "res://src/build/item_effects.gd",
			"res://src/build/synergies.gd"],
	},
	"enemy": {
		"extends": ["res://src/combat/enemy.gd", "res://src/boss/stub_boss.gd"],
		"dirs": [],
		"files": ["res://src/combat/enemy.gd", "res://src/boss/boss.gd", "res://src/boss/boss_model.gd",
			"res://src/boss/stub_boss.gd", "res://src/boss/requisition.gd", "res://src/boss/weak_part.gd",
			"res://src/boss/boss_target.gd"],
	},
	"reward": {
		"extends": [],
		"dirs": [],
		"files": ["res://src/build/reward_gates.gd", "res://src/build/item_gen.gd", "res://src/build/items.gd",
			"res://src/build/parts.gd", "res://src/build/relics.gd", "res://src/build/shop.gd", "res://src/build/accretion.gd",
			"res://src/ui/reward_view.gd", "res://src/ui/shop_tile.gd", "res://src/ui/shop_counter.gd",
			"res://src/presentation/reward_ceremony.gd"],
	},
}

# Today's overloads, counted on cand/w40 f4e04867 and widened by review (12 Nov 2026; effects-critique.md E6).
# kind "overload" is a row to burn down: fixing the file means deleting its row, and the test
# fails a row whose file no longer uses the colour. kind "ruled" is a standing exception with
# its source. Rows for AMBER and COPPER are listed overloads the domain scan cannot see (those
# colours carry several meanings by design); the test still checks each site exists.
const KNOWN := [
	{"path": "res://src/presentation/damage_numbers.gd", "colour": "ANCIENT", "kind": "overload",
		"why": "frost damage numbers are ancient green; frost is ICE"},
	{"path": "res://src/presentation/player_fx.gd", "colour": "ANCIENT", "kind": "overload",
		"why": "frost motes and part fountains are ancient green"},
	{"path": "res://src/combat/ultimate.gd", "colour": "ANCIENT", "kind": "overload",
		"why": "the Cannon's ultimate landing ring is ancient green"},
	{"path": "res://src/build/maker_bonuses.gd", "colour": "ANCIENT", "kind": "overload",
		"why": "the tremor bonus rings are ancient green, a player effect"},
	{"path": "res://src/build/item_gen.gd", "colour": "ANCIENT", "kind": "overload",
		"why": "the evolved rung is ancient green (DESIGN-NOTES unit RR1); VISUAL-LANGUAGE.md keeps it off rewards"},
	{"path": "res://src/build/accretion.gd", "colour": "ANCIENT", "kind": "overload",
		"why": "the evolved rung's growth colour, as item_gen"},
	{"path": "res://src/ui/shop_tile.gd", "colour": "ANCIENT", "kind": "overload",
		"why": "the evolved rung's frame, as item_gen"},
	{"path": "res://src/ui/shop_tile.gd", "colour": "HAZARD", "kind": "overload",
		"why": "the strike through a core's cost is danger red; a cost is loss"},
	{"path": "res://src/combat/actives/cutting_torch.gd", "colour": "HAZARD", "kind": "overload",
		"why": "the cutting torch, a player active, draws in danger red"},
	{"path": "res://src/presentation/player_fx.gd", "colour": "BRASS", "kind": "overload",
		"why": "heft up, fused and STRIKE words and the growth column are boss brass"},
	{"path": "res://src/combat/jolt_layer.gd", "colour": "ARC", "kind": "overload",
		"why": "the jolt layer's cable coil, an enemy part, is mint"},
	{"path": "res://src/build/maker_bonuses.gd", "colour": "BRASS", "kind": "overload",
		"why": "a maker set's rings around the ball are boss brass"},
	{"path": "res://src/build/called_shot.gd", "colour": "BRASS", "kind": "overload",
		"why": "the called shot's stamp is boss brass"},
	{"path": "res://src/build/shot_bits.gd", "colour": "BRASS", "kind": "overload",
		"why": "the split shot bit is boss brass"},
	{"path": "res://src/boss/requisition.gd", "colour": "ARC", "kind": "overload",
		"why": "Brindle's cockpit glass is mint, on an enemy part"},
	{"path": "res://src/combat/rogue.gd", "colour": "ARC", "kind": "ruled",
		"why": "Palette.live() on the open weak point: live means your verb works on this now"},
	{"path": "res://src/combat/miniboss.gd", "colour": "ARC", "kind": "ruled",
		"why": "Palette.live() on the open core, as rogue.gd"},
	{"path": "res://src/combat/enemy.gd", "colour": "ARC", "kind": "ruled",
		"why": "rim_color's default before a run sets the pilot's class colour (identity only)"},
	{"path": "res://src/core/event_kinds.gd", "colour": "COPPER", "kind": "overload",
		"why": "every pilot's hit and kill star is copper, Rivet's class colour; yours is the class colour"},
	{"path": "res://src/core/event_kinds.gd", "colour": "AMBER", "kind": "overload",
		"why": "amber is scrap and world rewards, the near miss, the kill-chain top rung and Kest"},
	{"path": "res://src/presentation/fx_library.gd", "colour": "AMBER", "kind": "overload",
		"why": "the stun halo is amber"},
	{"path": "res://src/combat/projectile.gd", "colour": "AMBER", "kind": "overload",
		"why": "a batted shell is amber"},
	{"path": "res://src/combat/actives/silo_battery.gd", "colour": "AMBER", "kind": "overload",
		"why": "the silo ring is amber drawn with the hostile threat code at hostile priority"},
]


# The colour a meaning draws in. "yours" needs the pilot's class row.
static func of(meaning: String, class_def = null) -> Color:
	if meaning == "yours":
		return class_def.color if class_def != null else Palette.live()
	var constant: String = MEANINGS.get(meaning, "")
	assert(constant != "", "colour_meanings: unknown meaning " + meaning)
	return _constant(constant)


static func rung(rung_id: String) -> Color:
	var constant: String = REWARD_RUNGS.get(rung_id, "")
	assert(constant != "", "colour_meanings: unknown reward rung " + rung_id)
	return _constant(constant)


static func _constant(name: String) -> Color:
	return (Palette as GDScript).get_script_constant_map().get(name, Palette.SAND)
