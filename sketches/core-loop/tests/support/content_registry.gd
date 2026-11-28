extends RefCounted

const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Events := preload("res://src/core/event_kinds.gd")
const Objectives := preload("res://src/core/objectives.gd")
const Lore := preload("res://src/core/lore_rows.gd")
const Music := preload("res://src/presentation/music_rows.gd")
const Windup := preload("res://src/presentation/windup_rows.gd")
const PhaseMusic := preload("res://src/presentation/phase_music.gd")
const TuneMoments := preload("res://src/presentation/tune_moments.gd")
const Trees := preload("res://src/core/upgrade_tree.gd")
const CombatCodex := preload("res://src/combat/codex_entries.gd")
const BossCodex := preload("res://src/boss/codex_entries.gd")
const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Roster := preload("res://src/combat/roster.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const Icons := preload("res://src/ui/icons.gd")
const Worlds := preload("res://src/core/worlds.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const PartDef := preload("res://src/build/part_def.gd")

const RULES := ["well_formed", "references", "reachable", "minimum_rows", "golden_hash"]
const NUMBER := -1
const EVENT_SCHEMA := {"group": TYPE_STRING, "color": TYPE_COLOR, "shape": TYPE_STRING,
	"sound": TYPE_STRING, "hud": TYPE_STRING, "objective": TYPE_STRING, "priority": TYPE_INT}
const STATE_SCHEMA := {"color": TYPE_STRING, "motion": TYPE_STRING, "shape": TYPE_STRING,
	"sound": TYPE_STRING, "verb": TYPE_STRING, "word": TYPE_STRING}
const ACTIVITY_SCHEMA := {"color": TYPE_STRING, "motion": TYPE_STRING, "shape": TYPE_STRING,
	"sound": TYPE_STRING, "word": TYPE_STRING}
const TREE_SCHEMA := {"id": TYPE_STRING, "name": TYPE_STRING, "effect": TYPE_STRING,
	"key": TYPE_STRING, "icon": TYPE_STRING, "tags": TYPE_ARRAY}

const TABLES := {
	"achievements.ROWS": {"kind": "achievements", "minimum": 8, "schema": {"name": TYPE_STRING, "text": TYPE_STRING, "on": TYPE_STRING, "count": TYPE_INT, "reward": TYPE_DICTIONARY}},
	"cosmetics.ROWS": {"kind": "cosmetics", "minimum": 6, "schema": {"slot": TYPE_STRING, "pilot": TYPE_STRING, "name": TYPE_STRING, "starter": TYPE_BOOL}},
	"event_kinds.ROWS": {"kind": "signals", "minimum": 1, "schema": EVENT_SCHEMA},
	"event_kinds.LINE_ROWS": {"kind": "states", "minimum": 1, "schema": STATE_SCHEMA},
	"event_kinds.STATE_ROWS": {"kind": "states", "minimum": 1, "schema": STATE_SCHEMA},
	"event_kinds.CAUSE_ROWS": {"kind": "causes", "minimum": 1, "schema": {"color": TYPE_STRING, "shape": TYPE_STRING, "motif": TYPE_ARRAY}},
	"event_kinds.ACTIVITY_ROWS": {"kind": "activities", "minimum": 1, "schema": ACTIVITY_SCHEMA},
	"event_kinds.LOOT_ROWS": {"kind": "events", "minimum": 1, "schema": EVENT_SCHEMA},
	"event_kinds.UI_ROWS": {"kind": "events", "minimum": 1, "schema": EVENT_SCHEMA},
	"event_kinds.WORLD_ROWS": {"kind": "events", "minimum": 1, "schema": EVENT_SCHEMA},
	"event_kinds.THREAT_ROWS": {"kind": "events", "minimum": 4, "schema": EVENT_SCHEMA},
	"event_kinds.ATTACK_ROWS": {"kind": "attacks", "minimum": 1, "schema": {"label": TYPE_STRING, "group": TYPE_STRING, "owner_kind": TYPE_STRING, "owner": TYPE_STRING, "allegiance": TYPE_STRING, "threat": TYPE_STRING, "glyph": TYPE_STRING, "color": TYPE_COLOR, "pose": TYPE_STRING, "warn": TYPE_STRING, "release": TYPE_STRING, "floor": TYPE_STRING, "open": TYPE_ARRAY}},
	"event_kinds.IMPACT": {"kind": "impact", "minimum": 1, "schema": {"knock": NUMBER, "lift": NUMBER, "stop": TYPE_STRING, "shake": NUMBER, "react": TYPE_STRING}},
	"event_kinds.REACTIONS": {"kind": "reactions", "minimum": 3, "schema": {"angle": NUMBER, "rise": NUMBER, "hold": NUMBER, "recover": NUMBER, "overshoot": NUMBER, "tumble": NUMBER, "limit": NUMBER}},
	"event_kinds.CODEX_CATEGORIES": {"kind": "categories", "minimum": 1, "schema": {"label": TYPE_STRING, "color": TYPE_COLOR, "shape": TYPE_STRING, "reserved": TYPE_BOOL}},
	"objectives.ROWS": {"kind": "objectives", "minimum": 1, "schema": {"glyph": TYPE_STRING, "words": TYPE_STRING}},
	"lore_rows.ROWS": {"kind": "lore", "minimum": 1, "schema": {"id": TYPE_STRING, "kind": TYPE_STRING, "zone": TYPE_STRING, "text": TYPE_STRING}},
	"music_rows.ROWS": {"kind": "music", "minimum": 1, "schema": {"synth_theme": TYPE_INT, "ace_manifest": TYPE_STRING}},
	"windup_rows.ROWS": {"kind": "windup", "minimum": 1, "schema": {"color_role": TYPE_STRING, "shape": TYPE_STRING, "sound": TYPE_STRING, "attacks": TYPE_DICTIONARY}},
	"upgrade_tree.TREES": {"kind": "trees", "minimum": 4, "schema": TREE_SCHEMA},
	"upgrade_tree.WORLD_ONE_NODES": {"kind": "world_one_trees", "minimum": 4, "schema": TREE_SCHEMA},
	"combat.codex_entries.ENTRIES": {"kind": "codex", "minimum": 1, "schema": {"id": TYPE_STRING, "name": TYPE_STRING, "hint": TYPE_STRING, "clue": TYPE_STRING, "text": TYPE_STRING}},
	"boss.codex_entries.ENTRIES": {"kind": "codex", "minimum": 4, "schema": {"id": TYPE_STRING, "name": TYPE_STRING, "hint": TYPE_STRING, "clue": TYPE_STRING, "text": TYPE_STRING}},
	"boss.codex_entries.WAKING": {"kind": "codex", "minimum": 4, "schema": {"id": TYPE_STRING, "name": TYPE_STRING, "hint": TYPE_STRING, "clue": TYPE_STRING, "text": TYPE_STRING}},
	"boss.codex_entries.MIND": {"kind": "codex", "minimum": 4, "schema": {"id": TYPE_STRING, "name": TYPE_STRING, "hint": TYPE_STRING, "clue": TYPE_STRING, "text": TYPE_STRING}},
	"parts.rows": {"kind": "parts", "minimum": 1, "schema": {"name": TYPE_STRING, "text": TYPE_STRING, "verb": TYPE_STRING, "rarity": TYPE_STRING, "tier": TYPE_INT, "family": TYPE_STRING, "tags": TYPE_ARRAY}},
	"item_gen.RARITY": {"kind": "rarity", "minimum": 4, "schema": {"color": TYPE_COLOR, "weight": NUMBER, "stamp": TYPE_STRING, "rung": TYPE_INT, "tier": TYPE_INT, "affix": NUMBER}},
}

const GOLDEN_HASHES := {
	"achievements.ROWS": "2fe66bab0c3ad97443d08468976d42efe9a837880a997861530bee798893485e",
	"cosmetics.ROWS": "2230dc95ee1c1fc6033e8ff830be418a43a7618288b62bbafddc9ad2d7769359",
	"event_kinds.ROWS": "93dbd24ce202521707e54731ae4d19195ae0a64507eab35e1d59254e40c3c8ae",
	"event_kinds.LINE_ROWS": "f4a74391a5a9053d404b6ed61a11599d0eace6ae64fd4156611bdbd5daf8d15f",
	"event_kinds.STATE_ROWS": "3593d9d4f1a83b2869b23f84f4075ebb33a27a4e57cce85846153c1ef54acb85",
	"event_kinds.CAUSE_ROWS": "9d20bee7f3e2a23dd09db3c08ab99e3fa0aab0f99d4373ef3398fff8601e0812",
	"event_kinds.ACTIVITY_ROWS": "dfdeb0c80b6c19754fafca7f979a60bee5cf039679370dcb5178d6ec0fc004de",
	"event_kinds.LOOT_ROWS": "d4c8f52197ece082a337887a4d5358e6b611be8856bd10b61d534e43b53c76b3",
	"event_kinds.UI_ROWS": "f55665747f58469dffcb49e883f38f31e671630e6667b9259e637d1ce1a3fd73",
	"event_kinds.WORLD_ROWS": "5625bfb2bbde40b9a2cd039346d7973b16c983d893b1627c15cd8c6776c5deb2",
	"event_kinds.THREAT_ROWS": "416e903fae944310bd492312f6fb7630c62b3f16f9f05f2789d7206019d431ad",
	"event_kinds.ATTACK_ROWS": "7f6b2d705f4406089d12c5e015aa105846e8e59015b58dcf04c18a8b5aa53c54",
	"event_kinds.IMPACT": "5f6e775fb137e380a441ece806c938f58ccd524dd7fc613e9aa3d0fa9700f4e1",
	"event_kinds.REACTIONS": "d69f61edda9075f25e0724226f87be0d35cb9688f1d840b76da4003371b92189",
	"event_kinds.CODEX_CATEGORIES": "4a61092895a1a12b1981249a32217abfacddc1bdec293c03948ca9f245700016",
	"objectives.ROWS": "26ebd270968a8e6f336b69df3798b3ad49e31e4c214f6afe55c8d6c86e193072",
	"lore_rows.ROWS": "5d8ad2b4450a20aadfa841794e5370ed26f93ec06cb06b8228da11cd6df61882",
	"music_rows.ROWS": "6ae91061fe62a58b8935f508c4b253ffc8c8bb1cbe2d9167eddbb7c3c3126329",
	"windup_rows.ROWS": "39e7378aeb4b997e7efac2e48e06d54d78d6ea117448bfb1cd1d92742ddbdb7e",
	"upgrade_tree.TREES": "a8c6e6dc2f1c3ce596d84dcb20f2cb2ca66bbd07cfe496897aada6a1c0b47976",
	"upgrade_tree.WORLD_ONE_NODES": "774dc725900becaf4ee671e855515b69af7a483e32ffe22927b4ad9fc69e1200",
	"combat.codex_entries.ENTRIES": "2d8af222c22f740e02811fe4f3d0cf56abb2faaaf633a4eb557a4035be8c9474",
	"boss.codex_entries.ENTRIES": "af05664d7996e33b627540ccdcfb68e2639bced90ef24adb219023a105843b88",
	"boss.codex_entries.WAKING": "cf77e5e481614790c0c581cf2ffc7cc7ad206802fb7f7adf41ca682c345e808f",
	"boss.codex_entries.MIND": "6acfd19449f8802b806ba76093fe15bd0c938c0a2f110230d9d38a5cbd004d87",
	"parts.rows": "6e06ff9132fb53cb33ab9e4cd200ebb86473e7cd792f5fb6b190b00663d06b81",
	"item_gen.RARITY": "2d1781de2528d605c781d9dbb96366c3fec9b75ec0944e75e35997bd31f6ebab",
}


static func _static_init() -> void:
	assert(TABLES.size() == GOLDEN_HASHES.size(), "ContentRegistry TABLES and GOLDEN_HASHES must match")


static func snapshot() -> Dictionary:
	var world_one := {}
	for pilot in Trees.WORLD_ONE_TABLES:
		world_one[pilot] = Trees.nodes(pilot, true).slice(0, Trees.WORLD_ONE_SIZE)
	return {
		"achievements.ROWS": Achievements.ROWS, "cosmetics.ROWS": Cosmetics.ROWS,
		"event_kinds.ROWS": Events.ROWS, "event_kinds.LINE_ROWS": Events.LINE_ROWS,
		"event_kinds.STATE_ROWS": Events.STATE_ROWS, "event_kinds.CAUSE_ROWS": Events.CAUSE_ROWS,
		"event_kinds.ACTIVITY_ROWS": Events.ACTIVITY_ROWS, "event_kinds.LOOT_ROWS": Events.LOOT_ROWS,
		"event_kinds.UI_ROWS": Events.UI_ROWS, "event_kinds.WORLD_ROWS": Events.WORLD_ROWS,
		"event_kinds.THREAT_ROWS": Events.THREAT_ROWS, "event_kinds.ATTACK_ROWS": Events.ATTACK_ROWS,
		"event_kinds.IMPACT": Events.IMPACT, "event_kinds.REACTIONS": Events.REACTIONS,
		"event_kinds.CODEX_CATEGORIES": Events.CODEX_CATEGORIES, "objectives.ROWS": Objectives.ROWS,
		"lore_rows.ROWS": Lore.ROWS, "music_rows.ROWS": Music.ROWS,
		"windup_rows.ROWS": Windup.ROWS, "upgrade_tree.TREES": Trees.TREES,
		"upgrade_tree.WORLD_ONE_NODES": world_one, "combat.codex_entries.ENTRIES": CombatCodex.ENTRIES,
		"boss.codex_entries.ENTRIES": BossCodex.ENTRIES, "boss.codex_entries.WAKING": BossCodex.WAKING,
		"boss.codex_entries.MIND": BossCodex.MIND, "parts.rows": Parts.rows(),
		"item_gen.RARITY": ItemGen.RARITY,
	}.duplicate(true)


static var _pass_depth := 0
static var _pass := {}


static func reset_for_tests() -> void:
	_pass_depth = 0
	_pass.clear()


static func _begin_pass() -> void:
	_pass_depth += 1


static func _end_pass() -> void:
	_pass_depth -= 1
	if _pass_depth == 0:
		_pass.clear()


static func _cached(key: String, make: Callable):
	if not _pass.has(key):
		_pass[key] = make.call()
	return _pass[key]


static func _pilot_ids() -> Array:
	return _cached("pilots", func(): return ClassDef.all().map(func(p): return p.id))


static func _bus() -> Dictionary:
	return _cached("bus", func(): return Achievements.bus_signals())


static func validate(tables: Dictionary, check_hashes := true) -> Array:
	_begin_pass()
	var issues := []
	for name in TABLES:
		issues.append_array(validate_table(name, tables.get(name), tables, check_hashes))
	for name in tables:
		if not TABLES.has(name):
			_issue(issues, str(name), "well_formed", "table", "unregistered table")
	_end_pass()
	return issues


static func validate_table(name: String, rows, tables: Dictionary, check_hash := true) -> Array:
	_begin_pass()
	var issues := _validate_table(name, rows, tables, check_hash)
	_end_pass()
	return issues


static func _validate_table(name: String, rows, tables: Dictionary, check_hash: bool) -> Array:
	var issues := []
	if not TABLES.has(name):
		_issue(issues, name, "well_formed", "table", "unregistered table")
		return issues
	var spec: Dictionary = TABLES[name]
	if not (rows is Dictionary or rows is Array):
		_issue(issues, name, "well_formed", "table", "expected a row dictionary or array")
		_issue(issues, name, "minimum_rows", "table", "registered table is absent")
		return issues
	var array_table: bool = spec.kind in ["lore", "codex"]
	if (rows is Array) != array_table:
		_issue(issues, name, "well_formed", "table", "wrong table container")
		return issues
	if rows.size() < spec.minimum:
		_issue(issues, name, "minimum_rows", "table", "has %d rows, needs %d" % [rows.size(), spec.minimum])
	if spec.kind in ["trees", "world_one_trees"]:
		_validate_trees(name, rows, spec, issues)
	else:
		var seen := {}
		for key in rows.size() if rows is Array else rows.keys():
			var row = rows[key]
			var id = row.get("id", "") if array_table and row is Dictionary else key
			if not (id is String) or id.strip_edges() == "" or seen.has(id):
				_issue(issues, name, "well_formed", str(key), "missing, non-string or repeated id")
			seen[id] = true
			if not _shape(name, str(id), row, spec.schema, issues):
				continue
			_validate_row(name, str(id), row, spec.kind, tables, issues)
		if spec.kind == "music" and not rows.has("default"):
			_issue(issues, name, "reachable", "default", "resolver requires a fallback row")
	if check_hash and digest(rows) != GOLDEN_HASHES.get(name, ""):
		_issue(issues, name, "golden_hash", "table", "observed %s" % digest(rows))
	return issues


static func _shape(name: String, id: String, row, schema: Dictionary, issues: Array) -> bool:
	if not row is Dictionary:
		_issue(issues, name, "well_formed", id, "row must be a dictionary")
		return false
	var ok := true
	for field in schema:
		if not row.has(field) or not _type_matches(row[field], schema[field]):
			_issue(issues, name, "well_formed", id, "%s missing or wrong type" % field)
			ok = false
	return ok


static func _type_matches(value, type: int) -> bool:
	if type == NUMBER:
		return (value is int or value is float) and is_finite(float(value))
	if type == TYPE_COLOR and value is Color:
		return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
	return typeof(value) == type


static func _validate_row(name: String, id: String, row: Dictionary, kind: String, tables: Dictionary, issues: Array) -> void:
	var pilots := _pilot_ids()
	var bus := _bus()
	match kind:
		"achievements":
			_ref(issues, name, id, "on", row.on, bus)
			for arg in row.get("where", {}) if row.get("where", {}) is Dictionary else {}:
				_ref(issues, name, id, "where", arg, bus.get(row.on, []))
			if row.has("sum"):
				_ref(issues, name, id, "sum", row.sum, bus.get(row.on, []))
			for reward in row.reward:
				var targets = (pilots + Achievements.PENDING_PILOTS) if reward == "pilot" else _ids(tables.get("cosmetics.ROWS", {}))
				if reward == "world":
					targets = Worlds.ROWS.map(func(w): return str(w.id))
				elif reward == "option":
					targets = MetaOptions.ids()
				elif reward == "item":
					targets = Parts.rows().keys()
				_ref(issues, name, id, "reward kind", reward, Achievements.REWARD_KINDS)
				_ref(issues, name, id, "reward", row.reward[reward], targets)
			for problem in Achievements.validate({id: row}, bus, pilots, _ids(tables.get("cosmetics.ROWS", {}))):
				if not str(problem).begins_with("table:"):
					_issue(issues, name, "well_formed", id, problem)
			if row.has("min") and row.has("max") and _type_matches(row.min, NUMBER) and _type_matches(row.max, NUMBER) and row.min > row.max:
				_issue(issues, name, "reachable", id, "minimum exceeds maximum")
		"cosmetics":
			_ref(issues, name, id, "slot", row.slot, Cosmetics.SLOTS)
			if row.pilot != "":
				_ref(issues, name, id, "pilot", row.pilot, pilots)
			for problem in Cosmetics.validate({id: row}, pilots):
				if not str(problem).begins_with("table:"):
					_issue(issues, name, "well_formed", id, problem)
			var earned: bool = row.starter
			var achievement_rows = tables.get("achievements.ROWS", {})
			if achievement_rows is Dictionary:
				for achievement in achievement_rows.values():
					if achievement is Dictionary and achievement.get("reward") is Dictionary:
						earned = earned or achievement.reward.get("cosmetic", "") == id
			if not earned:
				_issue(issues, name, "reachable", id, "neither starter nor achievement reward")
		"signals", "events":
			_ref(issues, name, id, "group", row.group, Events.GROUPS)
			_ref(issues, name, id, "shape", row.shape, Events.SHAPES)
			if kind == "signals":
				_ref(issues, name, id, "signal", id, bus)
			if row.priority < 0:
				_issue(issues, name, "well_formed", id, "negative priority")
		"states", "activities", "causes":
			_ref(issues, name, id, "color", row.color, Events.COLOR_ROLES)
			_ref(issues, name, id, "shape", row.shape, Events.SHAPES)
			if kind != "causes":
				_ref(issues, name, id, "motion", row.motion, Events.MOTIONS)
				_words(issues, name, id, row.word, 0, Events.MAX_WORDS)
			else:
				_ref(issues, name, id, "synergy", id, Synergies.ROWS)
				if row.motif.size() != 3 or not row.motif.all(func(note): return note is String and note != ""):
					_issue(issues, name, "well_formed", id, "motif needs three note names")
			if kind == "states" and row.verb != Events.NONE:
				_ref(issues, name, id, "verb", row.verb, Bindings.VERBS)
		"impact":
			_ref(issues, name, id, "stop", row.stop, Events.IMPACT_STOPS)
			_ref(issues, name, id, "react", row.react, _ids(tables.get("event_kinds.REACTIONS", {})))
			_nonnegative(issues, name, id, row, ["knock", "lift", "shake"])
		"reactions":
			_ref(issues, name, id, "reaction", id, Events.IMPACT_REACTS)
			_nonnegative(issues, name, id, row, TABLES[name].schema.keys())
		"categories":
			_ref(issues, name, id, "shape", row.shape, Events.SHAPES)
			_words(issues, name, id, row.label, 1, 3)
		"attacks":
			_ref(issues, name, id, "group", row.group, Events.ATTACK_GROUPS)
			_ref(issues, name, id, "allegiance", row.allegiance, ["hostile", "player", "neutral"])
			_ref(issues, name, id, "glyph", row.glyph, Events.SHAPES)
			if row.floor != Events.PLACEHOLDER:
				_ref(issues, name, id, "floor", row.floor, Events.FLOOR_MODES)
			if row.threat != "":
				_ref(issues, name, id, "threat", row.threat, _ids(tables.get("event_kinds.THREAT_ROWS", {})))
			var owners := {"roster": Roster.ROWS.keys(), "faction": Roster.FACTIONS.keys(), "class": pilots,
				"boss": Worlds.BOSSES.keys(), "pilot_any": ["any"], "rogue": Rogue.ROWS.keys()}
			_ref(issues, name, id, "owner_kind", row.owner_kind, owners)
			_ref(issues, name, id, "owner", row.owner, owners.get(row.owner_kind, []))
		"objectives":
			_ref(issues, name, id, "glyph", row.glyph, Icons.IDS)
			_words(issues, name, id, row.words, 1, Objectives.MAX_WORDS)
			if not _cached("objectives", func(): return _objective_ids()).has(id):
				_issue(issues, name, "reachable", id, "chooser cannot select this id")
		"lore":
			_ref(issues, name, id, "kind", row.kind, ["exchange", "field_note", "intro"])
			_ref(issues, name, id, "zone", row.zone, ["1-1", "1-2", "2-1", "2-2", "3-1", "3-2"])
			var cap: int = Lore.FIELD_NOTE_WORD_CAP
			if row.kind == "exchange":
				cap = Lore.EXCHANGE_LINE_WORD_CAP
				_shape(name, id, row, {"exchange": TYPE_STRING, "speaker": TYPE_STRING, "skippable": TYPE_BOOL}, issues)
			elif row.kind == "intro":
				cap = Lore.INTRO_LINE_WORD_CAP
				_ref(issues, name, id, "subject", row.get("subject", ""), ["warden"] + Worlds.BOSSES.keys())
				_intro_zone(issues, name, id, row)
			_words(issues, name, id, row.text, 1, cap)
		"music":
			_ref(issues, name, id, "theme", row.synth_theme, range(Music.THEME_COUNT))
			_ref(issues, name, id, "music id", id, ["default", "title", "title-a", "title-b", "title-c", "camp", "summary", "1-1", "1-2", "2-1", "2-2", "3-1", "3-2"] + Worlds.BOSSES.keys()
				+ PhaseMusic.TRACKS + PhaseMusic.PICKED.values() + TuneMoments.TUNES.keys())
			if row.ace_manifest != "" and not (row.ace_manifest.begins_with("res://assets/music_ace/") and row.ace_manifest.ends_with("/manifest.json") and not ".." in row.ace_manifest):
				_issue(issues, name, "references", id, "manifest outside optional ACE pack root")
		"windup":
			_ref(issues, name, id, "roster", id, Roster.ROWS.keys() + Rogue.ROWS.keys())
			_ref(issues, name, id, "color_role", row.color_role, Events.COLOR_ROLES)
			_ref(issues, name, id, "shape", row.shape, Events.SHAPES)
			for attack in row.attacks:
				if attack != Events.NONE:
					_ref(issues, name, id, "attack", attack, _ids(tables.get("event_kinds.ATTACK_ROWS", {})))
				if not row.attacks[attack] is Array or not row.attacks[attack].all(func(field): return field is String and field != ""):
					_issue(issues, name, "well_formed", id, "attack timing fields must be an array of names")
		"codex":
			for field in ["name", "hint", "clue", "text"]:
				if row[field].strip_edges() == "":
					_issue(issues, name, "well_formed", id, "%s is empty" % field)
			_ref(issues, name, id, "category", CombatCodex.CATEGORY if name.begins_with("combat.") else BossCodex.CATEGORY, _ids(tables.get("event_kinds.CODEX_CATEGORIES", {})))
		"parts":
			_ref(issues, name, id, "rarity", row.rarity, _ids(tables.get("item_gen.RARITY", {})))
			if row.get("class_id", "") != "":
				_ref(issues, name, id, "class_id", row.class_id, pilots)
			for tag in row.tags:
				_ref(issues, name, id, "tag", tag, PartDef.TAGS)
			if row.tags.is_empty() or row.tier < 1:
				_issue(issues, name, "well_formed", id, "needs tags and a positive tier")
		"rarity":
			_ref(issues, name, id, "rarity", id, ItemGen.RARITIES)
			_nonnegative(issues, name, id, row, ["weight", "rung", "tier", "affix"])


static func _validate_trees(name: String, rows: Dictionary, spec: Dictionary, issues: Array) -> void:
	var pilots := _pilot_ids()
	var size: int = Trees.WORLD_ONE_SIZE if spec.kind == "world_one_trees" else Trees.SIZE
	for pilot in rows:
		_ref(issues, name, str(pilot), "pilot", pilot, pilots)
		if not rows[pilot] is Array:
			_issue(issues, name, "well_formed", str(pilot), "tree must be an ordered node array")
			continue
		var nodes: Array = rows[pilot]
		if nodes.size() < size:
			_issue(issues, name, "minimum_rows", str(pilot), "has %d nodes, needs %d" % [nodes.size(), size])
		var reach: Array[bool] = []
		for index in nodes.size():
			reach.append(index < size and _selectable_node(nodes[index]) and (index < 2 or reach[(index - 2) / 2]))
		var seen := {}
		for index in nodes.size():
			var id := "%s/%d" % [pilot, index]
			var node = nodes[index]
			if not _shape(name, id, node, spec.schema, issues):
				continue
			if node.id == "" or seen.has(node.id):
				_issue(issues, name, "well_formed", id, "missing or repeated node id")
			seen[node.id] = true
			_words(issues, name, id, node.name, 1, Trees.NAME_WORDS)
			_words(issues, name, id, node.effect, 1, Trees.EFFECT_WORDS)
			_ref(issues, name, id, "key", node.key, Trees.KEYS)
			_ref(issues, name, id, "icon", node.icon, Icons.IDS.keys() + Icons.EXTRA.keys())
			for tag in node.tags:
				_ref(issues, name, id, "tag", tag, Trees.TAGS)
			if node.tags.is_empty() or not Trees.OPS.any(func(op): return node.has(op)):
				_issue(issues, name, "well_formed", id, "needs a tag and an op")
			for op in Trees.OPS:
				if node.has(op) and not _type_matches(node[op], TYPE_ARRAY if op == "proc" else TYPE_DICTIONARY):
					_issue(issues, name, "well_formed", id, "%s has wrong container" % op)
					continue
				match op:
					"knob":
						for knob in node.get(op, {}):
							_ref(issues, name, id, "knob", knob, Trees.KNOBS)
					"swap", "charges", "cooldown":
						for slot in node.get(op, {}):
							_ref(issues, name, id, "slot", slot, AbilityState.SWAPPABLE if op == "swap" else AbilityState.SLOTS)
							if op == "swap":
								_ref(issues, name, id, "ability", node[op][slot], AbilityState.ABILITIES)
							elif not _type_matches(node[op][slot], NUMBER) or node[op][slot] <= 0:
								_issue(issues, name, "well_formed", id, "%s must be positive numbers" % op)
					"pattern":
						for weapon in node.get(op, {}):
							_ref(issues, name, id, "weapon", weapon, Weapons.ALL)
					"proc":
						for proc in node.get(op, []):
							if _shape(name, id, proc, {"on": TYPE_STRING, "do": TYPE_STRING}, issues):
								_ref(issues, name, id, "proc on", proc.on, _bus())
								_ref(issues, name, id, "proc do", proc.do, Trees.ACTIONS)
			var parent: int = (index - 2) / 2
			if index >= size or (index >= 2 and not reach[parent]):
				_issue(issues, name, "reachable", id, "outside selectable heap or missing parent")


static func _selectable_node(node) -> bool:
	return node is Dictionary and node.get("id") is String and node.id.strip_edges() != ""


static func _intro_zone(issues: Array, name: String, id: String, row: Dictionary) -> void:
	var parts := String(row.zone).split("-")
	var world := int(parts[0]) if parts.size() == 2 and parts[0].is_valid_int() else 0
	var local := int(parts[1]) if parts.size() == 2 and parts[1].is_valid_int() else 0
	var found := false
	for stage in StageDefs.COUNT:
		if StageDefs.world_of(stage + 1) == world and StageDefs.local(stage + 1) == local:
			found = true
	if not found:
		_issue(issues, name, "references", id, "intro zone '%s' has no stage" % row.zone)
		return
	var subject: String = row.get("subject", "")
	if subject != "warden" and subject != String(Worlds.row(world).get("boss", "")):
		_issue(issues, name, "reachable", id, "second intro line needs a boss row for world %d; '%s' is not it" % [world, subject])
	if not row.has("pilot"):
		return
	_ref(issues, name, id, "pilot", row.pilot, _pilot_ids())
	var last := 0
	for stage in StageDefs.COUNT:
		if StageDefs.world_of(stage + 1) == world:
			last = maxi(last, StageDefs.local(stage + 1))
	if subject == "warden" or local != last:
		_issue(issues, name, "reachable", id, "pilot line '%s' needs the boss at world %d's arena zone" % [row.pilot, world])


static func _objective_ids() -> Array:
	var ids := []
	for state in ["stage", "beacon", "gates", "launch", "boss"]:
		for fight in ["plating", "posture"]:
			for mask in 256:
				for lesson in ["plate", "caps", "magnet", "unknown"]:
					for extra in [{}, {"mount": "dam_face"}, {"mount": "flume"},
							{"phase": 1}, {"phase": 2}, {"phase": 3}, {"phase": 3, "open": true}, {"phase": 4}]:
						var reading := {"state": state, "fight": fight, "sealed": bool(mask & 1),
							"engaged": bool(mask & 2), "staggered": bool(mask & 4), "struggling": bool(mask & 8),
							"distance": 5.0 if mask & 16 else 90.0, "card": bool(mask & 32), "lesson": lesson, "site_at_hand": bool(mask & 32),
							"yard_locked": bool(mask & 64), "clamp_shut": bool(mask & 128)}
						reading.merge(extra, true)
						var id := Objectives.choose(reading)
						if id != "" and not ids.has(id):
							ids.append(id)
	return ids


static func _ids(rows) -> Array:
	if rows is Dictionary:
		return rows.keys()
	if rows is Array:
		return rows.filter(func(r): return r is Dictionary).map(func(r): return r.get("id", ""))
	return []


static func _ref(issues: Array, name: String, id: String, field: String, value, targets) -> void:
	if not targets.has(value):
		_issue(issues, name, "references", id, "%s '%s' does not resolve" % [field, value])


static func _words(issues: Array, name: String, id: String, value: String, minimum: int, maximum: int) -> void:
	var count := value.split(" ", false).size()
	if count < minimum or count > maximum:
		_issue(issues, name, "well_formed", id, "text has %d words, needs %d..%d" % [count, minimum, maximum])


static func _nonnegative(issues: Array, name: String, id: String, row: Dictionary, fields: Array) -> void:
	for field in fields:
		if row[field] < 0:
			_issue(issues, name, "well_formed", id, "%s must be nonnegative" % field)


static func _issue(issues: Array, name: String, rule: String, id: String, detail: String) -> void:
	issues.append({"table": name, "rule": rule, "row": id, "detail": detail})


static func canonical(value) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a, b): return a < b if a is String and b is String else canonical(a) < canonical(b))
		var pairs := []
		for key in keys:
			pairs.append([canonical(key), canonical(value[key])])
		return JSON.stringify(["dictionary", pairs])
	if value is Array:
		return JSON.stringify(["array", value.map(func(item): return canonical(item))])
	return var_to_bytes(value).hex_encode()


static func digest(rows) -> String:
	return canonical(rows).sha256_text()
