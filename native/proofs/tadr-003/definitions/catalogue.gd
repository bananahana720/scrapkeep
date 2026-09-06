class_name ProofCatalogue
extends RefCounted

const SlotTreeDefinition = preload("res://proofs/tadr-003/definitions/slot_tree_definition.gd")

const ID_PREFIX: String = "proof."

var content_revision: int = 0
var diagnostics: PackedStringArray = PackedStringArray()
var _active: Dictionary[StringName, SlotTreeDefinition] = {}


func register(def: SlotTreeDefinition) -> Error:
	diagnostics = admission_problems(def)
	if not diagnostics.is_empty():
		return ERR_INVALID_DATA
	if _active.has(def.id):
		diagnostics.append("%s: duplicate_id: already registered from %s, refused %s" % [def.id, _active[def.id].resource_path, def.resource_path])
		return ERR_ALREADY_EXISTS
	_active[def.id] = def
	return OK


func resolve(id: StringName) -> SlotTreeDefinition:
	if not _active.has(id):
		return null
	return _active[id]


func stage(candidates: Array[SlotTreeDefinition]) -> Error:
	diagnostics = PackedStringArray()
	var staged: Dictionary[StringName, SlotTreeDefinition] = {}
	for def: SlotTreeDefinition in candidates:
		diagnostics.append_array(admission_problems(def))
		if staged.has(def.id):
			diagnostics.append("%s: duplicate_id: staged twice, from %s and %s" % [def.id, staged[def.id].resource_path, def.resource_path])
			continue
		staged[def.id] = def
	if not diagnostics.is_empty():
		return ERR_INVALID_DATA
	_active = staged
	content_revision += 1
	return OK


static func admission_problems(def: SlotTreeDefinition) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not String(def.id).begins_with(ID_PREFIX):
		out.append("%s: id_prefix: id must start with %s" % [def.id, ID_PREFIX])
	return out
