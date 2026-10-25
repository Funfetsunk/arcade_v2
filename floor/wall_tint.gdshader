shader_type canvas_item;
// Recolours the wall art toward a theme's hue, keeping each pixel's brightness.

uniform vec3 tint = vec3(1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 toned = tint * luma(COLOR.rgb) / max(luma(tint), 0.001);
	COLOR.rgb = mix(COLOR.rgb, toned, strength);
}
