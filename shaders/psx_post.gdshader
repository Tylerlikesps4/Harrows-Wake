shader_type canvas_item;
// Full-screen PS1 post effect: 15-bit color with Bayer dithering,
// optional scanlines, vignette, and a panic wobble/red tint.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float color_depth = 31.0;
uniform float scanlines = 0.12;
uniform float panic = 0.0;
uniform float fade = 0.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[y * 4 + x] / 16.0 - 0.5;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (panic > 0.01) {
		uv.x += sin(uv.y * 30.0 + TIME * 7.0) * 0.003 * panic;
	}
	vec3 c = texture(screen_tex, uv).rgb;
	c += bayer4(FRAGCOORD.xy) / color_depth;
	c = floor(c * color_depth + 0.5) / color_depth;
	c = mix(c, c * vec3(1.25, 0.55, 0.5), panic * 0.55);
	if (mod(FRAGCOORD.y, 2.0) < 1.0) {
		c *= 1.0 - scanlines;
	}
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * 1.3;
	c *= 1.0 - fade;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
