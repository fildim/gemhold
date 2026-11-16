shader_type canvas_item;
// The map's ground, drawn in one pass so terrain has no tile edges. The texture holds one pixel
// per tile (plus a border) with how much of each terrain it is: r moss, g frost, b ash, and a 1
// for a raised tile; whatever is left of rgb is the lair's stone. Linear filtering plus noise turns them
// into rounded, ragged zones whose borders still fall on the tile edges.

uniform vec2 grid;   // columns and rows of the level
// The masks: one pixel per tile plus a border. terrain_mask: r moss, g frost, b ash, a raised.
// water_mask: r deep water, g shallows. Declared as uniforms (not TEXTURE passed into functions).
uniform sampler2D terrain_mask : filter_linear;
uniform sampler2D water_mask : filter_linear;
// Chapter look: 0 lowland, 1 crusade autumn, 2 drowned marsh.
uniform int biome = 0;

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
vec4 zones(vec2 p) {
	vec2 warp = vec2(fbm(p * 1.6), fbm(p * 1.6 + vec2(9.2, 4.7))) - 0.5;
	vec2 uv = (p + warp * 0.45 + 1.0) / (grid + 2.0);
	vec4 m = texture(terrain_mask, uv);
	float n = (fbm(p * 3.1) - 0.5) * 0.3;
	return smoothstep(vec4(0.45), vec4(0.55), m + n);
}

// Water at p: x deep, y shallows, with wandering shores.
vec2 water(vec2 p) {
	vec2 warp = vec2(fbm(p * 1.9 + 3.3), fbm(p * 1.9 + vec2(1.2, 8.1))) - 0.5;
	vec2 uv = (p + warp * 0.3 + 1.0) / (grid + 2.0);
	vec2 m = texture(water_mask, uv).rg;
	float n = (fbm(p * 4.0) - 0.5) * 0.2;
	return smoothstep(vec2(0.42), vec2(0.58), m + n);
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

// How raised the ground is at p: 1 on a raised tile, 0 elsewhere. Each raised tile is a rounded
// square a little inside its own tile, its outline roughened so it reads as rock, not a box.
float raised(vec2 p) {
	vec2 cell = floor(p);
	float a = texture(terrain_mask, (cell + 1.5) / (grid + 2.0)).a;
	vec2 q = abs(p - cell - 0.5) - vec2(0.34);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.11;
	d += (fbm(p * 5.0) - 0.5) * 0.07;
	return a * (1.0 - smoothstep(-0.012, 0.012, d));
}

void fragment() {
	vec2 p = UV * (grid + 2.0) - 1.0;
	vec4 here = zones(p);
	float lair_w = clamp(1.0 - here.r - here.g - here.b, 0.0, 1.0);
	float sum = here.r + here.g + here.b + lair_w + 0.0001;
	vec3 ground = (moss(p) * here.r + frost(p) * here.g + ash(p) * here.b + stone(p) * 0.7 * lair_w) / sum;
	if (biome == 1) {   // the crusade's autumn: warmer, drier ground
		ground = mix(ground, ground * vec3(1.12, 0.98, 0.78), 0.55);
	} else if (biome == 2) {   // the drowned marches: dark, wet, peaty
		ground = mix(ground, ground * vec3(0.78, 0.9, 0.86), 0.6) * 0.92;
	} else if (biome == 3) {   // the siegeworks: churned brown mud and trampled earth
		float churn = fbm(p * 3.1 + 17.0);
		ground = mix(ground, vec3(0.33, 0.26, 0.18) * (0.75 + 0.5 * churn), 0.5) * vec3(1.02, 0.95, 0.86);
	} else if (biome == 4) {   // the radiant host: sunlit, pale gold-white fields
		ground = mix(ground, vec3(dot(ground, vec3(0.33))) * vec3(1.25, 1.15, 0.9), 0.4) * 1.08;
	}
	// Water: deep pools dark and still, shallows a clear, lighter blue-green with sand showing
	// through in patches (so they read as water, not as grey ground), a pale rim where it meets land.
	vec2 w = water(p);
	vec3 deep = mix(vec3(0.07, 0.17, 0.2), vec3(0.11, 0.24, 0.27), fbm(p * 1.2 + 9.0));
	vec3 shal = mix(vec3(0.17, 0.40, 0.43), vec3(0.25, 0.50, 0.51), fbm(p * 2.2 + 4.0));
	shal = mix(shal, vec3(0.56, 0.53, 0.38), smoothstep(0.5, 0.78, fbm(p * 1.7 + 13.0)) * 0.38);   // sandy bottom
	shal *= 0.94 + 0.12 * noise(p * 7.0);
	vec3 wet = mix(shal, deep, clamp(w.x / max(w.x + w.y, 0.001), 0.0, 1.0));
	float wa = clamp(w.x + w.y, 0.0, 1.0);
	ground = mix(ground * (1.0 - 0.35 * smoothstep(0.0, 0.5, wa)), wet, smoothstep(0.35, 0.65, wa));
	ground += vec3(0.16, 0.18, 0.15) * (smoothstep(0.3, 0.45, wa) - smoothstep(0.45, 0.62, wa));
	// A raised tile is a small mesa of its own ground: the top sits LIFT higher, the strip below
	// it is a cliff face, and it casts a shadow down and to the right.
	const float LIFT = 0.34;
	float base = raised(p);
	float top = min(base, raised(p + vec2(0.0, LIFT)));
	float cliff = clamp(base - top, 0.0, 1.0);
	float shade = raised(p - vec2(0.2, 0.3)) * (1.0 - base);
	vec3 col = ground * (1.0 - shade * 0.6);
	float fy = fract(p.y);
	vec3 face = vec3(0.2, 0.17, 0.14) * (0.8 + 0.4 * noise(vec2(p.x * 14.0, p.y * 2.0)));
	face = mix(face * 1.3, face * 0.7, smoothstep(0.72, 1.0, fy));
	col = mix(col, face, cliff);
	// A dark line round the whole outcrop so it stands off the ground around it.
	float outer = raised(p + vec2(0.05, 0.0)) + raised(p - vec2(0.05, 0.0)) + raised(p - vec2(0.0, 0.05));
	col = mix(col, vec3(0.08, 0.06, 0.05), clamp(outer, 0.0, 1.0) * (1.0 - base) * 0.85);
	// Lit rim along the top's front edge, and the top itself a touch brighter than low ground.
	float rim = top * (1.0 - raised(p + vec2(0.0, LIFT + 0.07)));
	// The same pale, gold-veined stone on every terrain, so a raised tile reads as "any tower".
	vec3 slab = mix(stone(p) * 1.35, vec3(0.78, 0.72, 0.58), 0.35);
	slab = mix(slab, vec3(0.95, 0.8, 0.45), ridge(p * 3.0 + 4.0, 0.02) * 0.45);
	vec3 crown = slab + vec3(0.25, 0.22, 0.15) * rim;
	col = mix(col, crown, top);
	COLOR = vec4(col, 1.0);
}
