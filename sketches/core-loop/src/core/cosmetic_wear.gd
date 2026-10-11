extends RefCounted

const Cosmetics := preload("res://src/core/cosmetics.gd")

# The profile read for cosmetics. cosmetics.gd is a pure data table and names no profile;
# this module asks the profile (anything with has_cosmetic and equipped) and the table.


static func owns(profile, id: String) -> bool:
	var data := Cosmetics.row(id)
	return profile != null and not data.is_empty() and (data["starter"] or profile.has_cosmetic(id))


# The id worn in a slot, or "" when nothing fitting and owned is equipped. The one copy of
# the ownership rule: the customize page, cosmetic_presentation.gd and hero_assets.gd ask it.
static func worn(profile, owner: String, slot: String) -> String:
	if profile == null:
		return ""
	var id: String = profile.equipped(owner, slot)
	return id if id != "" and owns(profile, id) and Cosmetics.fits(id, owner, slot) else ""
