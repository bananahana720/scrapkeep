extends RefCounted

# The four kill-first specials' cues (ENEMY-PRIORITY.md 4, 4a; design-v3/sound/INTEGRATION.md
# section 7 item 5). Andrew, 17 Oct 00:45Z: like Left 4 Dead 2's specials, each one has a
# presence loop while it lives, a wind-up tell whose sound starts on the frame its picture
# does, and a death sting. A missing cue is a placeholder at wave 20.
#
# This is the one hook the behaviours call. Combat attaches every special at spawn, so its
# presence and its death need no call; a behaviour calls tell(self) on its tell's first
# frame. tell() starts the body's tell clip and emits the body's special_tell(moment), and
# every listener (special_voice.gd for the sound, machine_fx.gd for the effects and the word)
# hears that one emit, so picture and sound share a start frame by construction.
#
# Each row names the body's tell clip (the rigs on PR #44 start each clip on the frame its
# sound starts) and the death moments. Cue ids are also the file names under SOUND_DIR
# (specials.py on PR #12 renders them; the audio gate on PR #41 counts a missing one as a
# placeholder).

const SOUND_DIR := "res://assets/audio/specials/"
const SOUND_EXT := [".wav", ".ogg"]
const TELL := "tell"
const PRESENCE := "presence"
const SPAWN := "spawn"
# What the three cues Andrew named are, per special: one presence, one tell, one death or more.
const CUES := ["presence", "tell", "death"]

const SPECIALS := {
	"foreman": {"tell_clip": "tell", "breaks": ["break"]},
	"dispatcher": {"tell_clip": "tell", "breaks": ["break"]},
	# Rammed at ground level it splits (break_split); from above or range it dies clean.
	"splitter": {"tell_clip": "tell", "breaks": ["break_split", "break_clean"]},
	# The tell is the cable going taut while the dish braces.
	"linker": {"tell_clip": "brace", "breaks": ["break"]},
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


# The death moment a dying body plays. A behaviour marks a ground-level ram with
# set_meta("split", true) before the Splitter dies.
static func break_moment(enemy: Node) -> String:
	var special := special_of(enemy)
	if special == "splitter":
		return "break_split" if bool(enemy.get_meta("split", false)) else "break_clean"
	return "break" if special != "" else ""


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


static func sound_path(id: String) -> String:
	for ext in SOUND_EXT:
		if ResourceLoader.exists(SOUND_DIR + id + ext):
			return SOUND_DIR + id + ext
	return ""


# Gives a special the special_tell signal its listeners connect to on enemy_spawned. Combat
# calls this before it emits enemy_spawned; a body that declares the signal keeps its own.
static func attach(enemy: Node) -> bool:
	if special_of(enemy) == "":
		return false
	if not enemy.has_signal("special_tell"):
		enemy.add_user_signal("special_tell", [{"name": "moment", "type": TYPE_STRING}])
	return true


# The hook: call on the tell's first frame. Starts the body's tell clip at 0, then emits
# special_tell("tell") once. Returns the tell's sound id, or "" (with a warning) for a body
# nobody listens to, which never went through attach() before enemy_spawned.
static func tell(enemy: Node) -> String:
	if not attach(enemy):
		return ""
	if enemy.get_signal_connection_list("special_tell").is_empty():
		push_warning("SpecialCues.tell: %s has no special_tell listeners; attach() it before enemy_spawned" % enemy.name)
		return ""
	var special := special_of(enemy)
	play_clip(enemy, String(SPECIALS[special]["tell_clip"]))
	enemy.emit_signal("special_tell", TELL)
	return sound(special, TELL)


static func play_clip(enemy: Node, clip: String) -> bool:
	if clip == "" or not is_instance_valid(enemy):
		return false
	for player in enemy.find_children("*", "AnimationPlayer", true, false):
		if player.has_animation(clip):
			player.play(clip)
			player.seek(0.0, true)
			return true
	return false
