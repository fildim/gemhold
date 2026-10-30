shader_type canvas_item;
// The map's ground, drawn in one pass so terrain has no tile edges. The texture holds one pixel
// per tile (plus a border) with how much of each terrain it is: r moss, g frost, b ash, a high
// ground; whatever is left is the lair's stone. Linear filtering plus noise turns those pixels
// into rounded, ragged zones whose borders still fall on the tile edges.

uniform vec2 grid;   // columns and rows of the level

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}

// Thin bright lines where noise crosses 0.5: cracks and veins.
float ridge(vec2 p, float width) {
	return 1.0 - smoothstep(0.0, width, abs(fbm(p) - 0.5));
}

// Terrain mix at tile position p (in tiles), roughened so borders wander.
vec4 zones(sampler2D tex, vec2 p) {
	vec2 warp = vec2(fbm(p * 1.6), fbm(p * 1.6 + vec2(9.2, 4.7))) - 0.5;
	vec2 uv = (p + warp * 0.45 + 1.0) / (grid + 2.0);
	vec4 m = texture(tex, uv);
	float n = (fbm(p * 3.1) - 0.5) * 0.3;
	return smoothstep(vec4(0.45), vec4(0.55), m + n);
}

vec3 moss(vec2 p) {
	float f = fbm(p * 1.3);
	vec3 c = mix(vec3(0.24, 0.34, 0.15), vec3(0.36, 0.47, 0.21), f);
	c *= 0.88 + 0.24 * noise(p * 9.0);
	c = mix(c, vec3(0.42, 0.40, 0.20), smoothstep(0.62, 0.8, fbm(p * 0.7 + 5.0)) * 0.35);
	return c;
}

vec3 frost(vec2 p) {
	float f = fbm(p * 1.1 + 3.0);
	vec3 c = mix(vec3(0.66, 0.75, 0.81), vec3(0.86, 0.91, 0.94), f);
	c = mix(c, vec3(0.97, 0.98, 1.0), smoothstep(0.6, 0.75, fbm(p * 2.5)) * 0.6);
	c = mix(c, vec3(0.45, 0.58, 0.66), ridge(p * 0.9 + 7.0, 0.012) * 0.35);
	return c;
}

vec3 ash(vec2 p) {
	float f = fbm(p * 1.4 + 11.0);
	vec3 c = mix(vec3(0.24, 0.16, 0.14), vec3(0.38, 0.27, 0.23), f);
	c *= 0.9 + 0.2 * noise(p * 8.0);
	float crack = ridge(p * 1.2 + 2.0, 0.03);
	float glow = 0.55 + 0.45 * sin(fbm(p * 3.0) * 6.0);
	c = mix(c, vec3(0.1, 0.06, 0.05), crack * 0.8);
	c += vec3(1.0, 0.35, 0.08) * crack * smoothstep(0.55, 0.7, fbm(p * 0.8)) * glow * 0.55;
	return c;
}

vec3 stone(vec2 p) {
	float f = fbm(p * 2.0 + 21.0);
	vec3 c = mix(vec3(0.42, 0.39, 0.35), vec3(0.58, 0.54, 0.48), f);
	c = mix(c, vec3(0.3, 0.27, 0.24), ridge(p * 2.2, 0.03) * 0.6);
	return c;
}

void fragment() {
	vec2 p = UV * (grid + 2.0) - 1.0;
	// High ground stands up: the lowest LIFT of each outcrop is drawn as a cliff face under the
	// rock top, so rocks look raised without spilling off their tiles.
	const float LIFT = 0.3;
	vec4 top = zones(TEXTURE, p + vec2(0.0, LIFT));
	vec4 here = zones(TEXTURE, p);
	float rock = min(top.a, here.a);
	float cliff = clamp(here.a - rock, 0.0, 1.0);
	vec3 low_w = here.rgb;
	float lair_w = clamp(1.0 - here.r - here.g - here.b - here.a, 0.0, 1.0);
	float sum = low_w.r + low_w.g + low_w.b + lair_w + 0.0001;
	vec3 ground = (moss(p) * low_w.r + frost(p) * low_w.g + ash(p) * low_w.b + stone(p) * 0.7 * lair_w) / sum;
	// Shadow the rocks cast down and to the right.
	float shade = zones(TEXTURE, p - vec2(0.18, 0.5)).a * (1.0 - here.a);
	ground *= 1.0 - shade * 0.45;
	// Cliff face: dark rock with vertical streaks, lighter at the top.
	float fy = fract(p.y);
	vec3 face = vec3(0.17, 0.14, 0.12) * (0.8 + 0.4 * noise(vec2(p.x * 14.0, p.y * 2.0)));
	face = mix(face, vec3(0.36, 0.31, 0.26), smoothstep(0.55, 0.75, fy) * 0.5);
	// Rock top with a lit rim along its edge.
	float rim = rock * (1.0 - zones(TEXTURE, p + vec2(0.0, LIFT + 0.08)).a);
	vec3 crown = stone(p) + vec3(0.2, 0.18, 0.14) * rim;
	vec3 col = mix(ground, face, cliff);
	col = mix(col, crown, rock);
	COLOR = vec4(col, 1.0);
}
