extends Resource

const Palette := preload("res://src/core/palette.gd")

# A class is data (TADR-008): which weapon and special its slots yield. Both classes
# share the whole mobility base, so a class never changes how the ball moves; combat
# reads weapon_id and special_id and owns what they do. The names are candidates.

@export var id := ""
@export var display_name := ""
@export var pitch := ""
@export var weapon_id := ""
@export var special_id := ""
@export var color := Color.WHITE
@export var bible_home := ""


static func make(id_value: String, name_value: String, pitch_value: String, weapon: String,
		special: String, tint: Color, home: String) -> Resource:
	var def: Resource = load("res://src/core/class_def.gd").new()
	def.id = id_value
	def.display_name = name_value
	def.pitch = pitch_value
	def.weapon_id = weapon
	def.special_id = special
	def.color = tint
	def.bible_home = home
	return def


static func all() -> Array[Resource]:
	var list: Array[Resource] = [
		make("pylon_engineer", "Pylon engineer",
			"Plant on any steep face and become an arc turret. A faster plant banks a bigger opening burst; Space slingshots you off along the face.",
			"arc_caster", "pylon_turret", Palette.ARC, "Rivet's beam or Sable's anchor"),
		make("runner_gunner", "Runner-gunner",
			"Never stop. Rapid tight laser shots on the move, with an overdrive burst when you are surrounded.",
			"rapid_laser", "overdrive", Palette.AMBER, "Fuse"),
	]
	return list


static func by_id(wanted: String) -> Resource:
	for def in all():
		if def.id == wanted:
			return def
	return null
