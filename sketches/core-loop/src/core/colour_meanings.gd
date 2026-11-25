extends RefCounted


const Palette := preload("res://src/core/palette.gd")

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

const RESERVED := {
	"HAZARD": {"meaning": "danger", "never": ["player", "reward"]},
	"ANCIENT": {"meaning": "ancient", "never": ["player", "reward"]},
	"BRASS": {"meaning": "boss", "never": ["player"]},
	"ARC": {"meaning": "live", "never": ["enemy"]},
	"COBALT": {"meaning": "reward", "never": ["enemy"]},
}

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

const KNOWN := [
	{"path": "res://src/presentation/damage_numbers.gd", "colour": "ANCIENT", "kind": "overload",
		"why": "frost damage numbers are ancient green; frost is ICE"},
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
	{"path": "res://src/presentation/player_fx.gd", "colour": "HAZARD", "kind": "ruled",
		"why": "the heat kettle's twin (W1-108): over the fuse's last 2 s the shell is about to cook off and hurt the player, so its rim beats in danger red"},
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
