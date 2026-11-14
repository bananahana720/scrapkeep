extends SceneTree
# Scratch only: render the stagger chord cues alone (cause_note_62/65/69/74 and boss_weak_hit) from SfxBank.
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
func _initialize() -> void:
	var out := OS.get_environment("WFORM_OUT")
	for id in ["cause_note_62", "cause_note_65", "cause_note_69", "cause_note_74", "boss_weak_hit"]:
		var s: AudioStreamWAV = SfxBank.stream(id)
		var err := s.save_to_wav("%s/cue_%s.wav" % [out, id])
		print(id, " ", s.mix_rate, " ", s.data.size(), " ", err)
	quit(0)
