shader_type canvas_item;
// SpriteCache's second pass: a SubViewport's transparent output is premultiplied; this writes it
// back as ordinary (straight) alpha, with blending off so it lands in the target as it is.
// A clear pixel takes the colour of its most opaque neighbour, so filtering at a picture's edge
// fades it out instead of darkening it (what Image.fix_alpha_edges does, here for free).
render_mode blend_disabled, unshaded;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.0) {
		COLOR = vec4(c.rgb / c.a, c.a);
	} else {
		vec4 best = vec4(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec4 n = texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE);
				if (n.a > best.a) {
					best = n;
				}
			}
		}
		COLOR = best.a > 0.0 ? vec4(best.rgb / best.a, 0.0) : vec4(0.0);
	}
}
