extends RefCounted


static func resolve(row: Dictionary, site: Dictionary) -> Dictionary:
	if row.kind != "collapse" or not row.effect.has("face"):
		return site
	var face: Dictionary = row.effect.face
	var resolved := site.duplicate(true)
	resolved.at = face.at
	resolved.size = face.size
	resolved.yaw_deg = face.yaw_deg
	resolved.y = null
	return resolved
