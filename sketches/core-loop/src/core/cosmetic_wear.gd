extends RefCounted

const Cosmetics := preload("res://src/core/cosmetics.gd")


static func owns(profile, id: String) -> bool:
	var data := Cosmetics.row(id)
	return profile != null and not data.is_empty() and (data["starter"] or profile.has_cosmetic(id))


static func worn(profile, owner: String, slot: String) -> String:
	if profile == null:
		return ""
	var id: String = profile.equipped(owner, slot)
	return id if id != "" and owns(profile, id) and Cosmetics.fits(id, owner, slot) else ""
