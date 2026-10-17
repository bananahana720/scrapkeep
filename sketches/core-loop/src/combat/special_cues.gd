extends RefCounted

# The four kill-first specials' cues (ENEMY-PRIORITY.md 4, 4a; design-v3/sound/INTEGRATION.md
# section 7 item 5). Andrew, 17 Oct 00:45Z: like Left 4 Dead 2's specials, each one has a
# presence loop while it lives, a wind-up tell whose sound starts on the frame its picture
# does, and a death sting. A missing cue is a placeholder at wave 20.
#
# This is the one hook the behaviours call. Combat attaches every special at spawn, so its
# presence and its death need no call; a behaviour calls tell(self) on its tell's first
# frame and emits nothing itself. tell() emits the body's special_tell("tell") once, and
# every listener hears that one emit: audio.gd plays the sound, special_rig.gd starts the
# clip, machine_fx.gd fires the effects and the word. Picture and sound share a start frame
# by construction. Cue ids are <special>_<moment>, the specials.py renders sfx_bank.gd loads.

const TELL := "tell"
const PRESENCE := "presence"
const SPAWN := "spawn"
# What the three cues Andrew named are, per special: one presence, one tell, one death or more.
const CUES := ["presence", "tell", "death"]

const SPECIALS := {
	"foreman": {"breaks": ["break"]},
	"dispatcher": {"breaks": ["break"]},
	# Rammed at ground level it splits (break_split); from above or range it dies clean.
	"splitter": {"breaks": ["break_split", "break_clean"]},
	"linker": {"breaks": ["break"]},
}


# The special a body is, by kind, by an explicit "special" meta, or by the elite affix it
# carries (ENEMY-PRIORITY.md 4 plans the Foreman as an affix); "" for none.
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


# The death moment a dying body plays. A Splitter rammed at ground level says so through
# rammed_at_ground (a property or a method, the contract special_audio.gd reads) or a
# "split" meta; audio and machine_fx both read this, so the sting and the burst agree.
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


# The three cues per special, each with every sound id it may play.
static func cues(special: String) -> Dictionary:
	if not SPECIALS.has(special):
		return {}
	return {"presence": [sound(special, PRESENCE)], "tell": [sound(special, TELL)],
		"death": (SPECIALS[special]["breaks"] as Array).map(func(m: String): return sound(special, m))}


# Every sound id the four specials play, spawn answers included.
static func all_sounds() -> Array:
	var out := []
	for special in SPECIALS:
		out.append(sound(special, SPAWN))
		for cue in CUES:
			out.append_array(cues(special)[cue])
	return out


# Gives a special the special_tell signal its listeners connect to on enemy_spawned. Combat
# calls this before it emits enemy_spawned; a body that declares the signal keeps its own.
static func attach(enemy: Node) -> bool:
	if special_of(enemy) == "":
		return false
	if not enemy.has_signal("special_tell"):
		enemy.add_user_signal("special_tell", [{"name": "moment", "type": TYPE_STRING}])
	return true


# The hook: call on the tell's first frame. Emits special_tell("tell") once. Returns the
# tell's sound id, or "" (with a warning) for a body nobody listens to, which never went
# through attach() before enemy_spawned.
static func tell(enemy: Node) -> String:
	if not attach(enemy):
		return ""
	if enemy.get_signal_connection_list("special_tell").is_empty():
		push_warning("SpecialCues.tell: %s has no special_tell listeners; attach() it before enemy_spawned" % enemy.name)
		return ""
	enemy.emit_signal("special_tell", TELL)
	return sound(special_of(enemy), TELL)
