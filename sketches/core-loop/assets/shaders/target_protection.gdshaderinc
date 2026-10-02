uniform int protected_count = 0;
uniform vec4 protected_rects[64];
bool dressing_protected(vec2 point) {
	for (int i = 0; i < protected_count; i++) {
		vec4 rect = protected_rects[i];
		if (point.x >= rect.x && point.y >= rect.y && point.x <= rect.z && point.y <= rect.w) { return true; }
	}
	return false;
}
