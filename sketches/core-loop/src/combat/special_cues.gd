extends RefCounted

const TELL := "tell"
const PRESENCE := "presence"
const SPAWN := "spawn"
const CUES := ["presence", "tell", "death"]

const SPECIALS := {
	"foreman": {"breaks": ["break"]},
	"dispatcher": {"breaks": ["break"]},
	"splitter": {"breaks": ["break_split", "break_clean"]},
	"linker": {"breaks": ["break"]},
}


static func special_of(enemy: Node) -> String:
	if not is_instance_valid(enemy):
		return ""
	var kind := String(enemy.get("kind")) if enemy.get("kind") != null else ""
	if SPECIALS.has(kind):
		return kind
	for key in ["special", "elite_affix"]:
		var tagged := String(enemy.get_meta(key, ""))
		if SPECIALS.has(tagged):
			return tagged
	return ""


static func sound(special: String, moment: String) -> String:
	if not SPECIALS.has(special):
		return ""
	if moment in [PRESENCE, SPAWN, TELL] or moment in SPECIALS[special]["breaks"]:
		return "%s_%s" % [special, moment]
	return ""


static func break_moment(enemy: Node) -> String:
	var special := special_of(enemy)
	if special == "splitter":
		return "break_split" if rammed(enemy) else "break_clean"
	return "break" if special != "" else ""


static func rammed(enemy: Object) -> bool:
	if enemy == null:
		return false
	if enemy.has_method("rammed_at_ground"):
		return bool(enemy.rammed_at_ground())
	var value = enemy.get("rammed_at_ground")
	return (value is bool and value) or bool(enemy.get_meta("split", false))


static func cues(special: String) -> Dictionary:
	if not SPECIALS.has(special):
		return {}
	return {"presence": [sound(special, PRESENCE)], "tell": [sound(special, TELL)],
		"death": (SPECIALS[special]["breaks"] as Array).map(func(m: String): return sound(special, m))}


static func attach(enemy: Node) -> bool:
	if special_of(enemy) == "":
		return false
	if not enemy.has_signal("special_tell"):
		enemy.add_user_signal("special_tell", [{"name": "moment", "type": TYPE_STRING}])
	return true


static func tell(enemy: Node) -> String:
	if not attach(enemy):
		return ""
	if enemy.get_signal_connection_list("special_tell").is_empty():
		push_warning("SpecialCues.tell: %s has no special_tell listeners; attach() it before enemy_spawned" % enemy.name)
		return ""
	enemy.emit_signal("special_tell", TELL)
	return sound(special_of(enemy), TELL)
