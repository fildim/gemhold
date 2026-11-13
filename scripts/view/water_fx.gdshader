shader_type canvas_item;
// Moving light on the water: soft drifting ripples on deep water, brighter flickers on shallows.
// Drawn over the baked ground; transparent where there is no water.

uniform vec2 grid;
uniform sampler2D water_mask : filter_linear;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * (grid + 2.0) - 1.0;
	vec2 m = texture(water_mask, UV).rg;
	float wa = smoothstep(0.5, 0.8, m.r + m.g);
	float t = TIME;
	float a = noise(p * 3.0 + vec2(t * 0.25, t * 0.13));
	float b = noise(p * 5.5 - vec2(t * 0.18, -t * 0.22));
	float lines = smoothstep(0.62, 0.7, a * 0.6 + b * 0.4) - smoothstep(0.7, 0.78, a * 0.6 + b * 0.4);
	vec3 col = mix(vec3(0.55, 0.75, 0.8), vec3(0.85, 0.9, 0.75), m.g);
	COLOR = vec4(col, lines * wa * (0.18 + 0.14 * m.g));
}
