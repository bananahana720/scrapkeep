extends SceneTree

const TuneRows := preload("res://src/core/tune_rows.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const Roster := preload("res://src/combat/roster.gd")
const T := preload("res://tests/support/t.gd")

# PF-51: the radio listed "Shelf Warden" and "Reach Warden" beside the boss bar's "Reactor
# Warden" and "Meltdown Warden", so a first-time reader counted four Wardens. No track display
# name holds the word Warden or equals a boss bar name (the names come from Roster).

var _t := T.new("track_names_test")


func _initialize() -> void:
	var boss_names := []
	for family in Roster.WARDEN_NAMES:
		for variant in Roster.WARDEN_NAMES[family]:
			boss_names.append(String(Roster.WARDEN_NAMES[family][variant]))
	_t.check("the boss bar names were read from the roster", boss_names.size() >= 6, str(boss_names))
	# The radio shows jukebox records and the takes in assets/radio/catalogue.json; both reach the player
	# through RadioTakes.track(), so every name is read there.
	var ids: Array = TuneRows.ids().duplicate()
	ids.append_array(RadioTakes.take_ids())
	var seen := 0
	var takes := 0
	var names := {}
	for id in ids:
		var tname := String(RadioTakes.track(id).get("name", ""))
		seen += 1
		takes += 1 if RadioTakes.is_take(id) else 0
		_t.check("track %s has a name" % id, tname != "", tname)
		_t.check("track %s name has no Warden" % id, not tname.containsn("warden"), tname)
		_t.check("track %s name is no boss bar name" % id, not boss_names.has(tname) and not boss_names.has("The " + tname), tname)
		_t.check("track %s name is unique" % id, not names.has(tname), tname)
		names[tname] = true
	_t.check("the loop saw every record and every take", seen == TuneRows.ROWS.size() + RadioTakes.take_ids().size() and takes > 0, "%d seen, %d takes" % [seen, takes])
	quit(_t.verdict())
