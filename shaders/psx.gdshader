shader_type spatial;
// PS1-style surface: vertex snapping (jitter), affine texture warping,
// nearest-filtered low-res textures. Fog comes from the Environment.
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float uv_scale = 1.0;
uniform float snap_res = 160.0;
uniform float emission = 0.0;
uniform bool affine = true;

varying vec2 aff_uv;
varying float aff_w;

void vertex() {
	vec4 p = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec2 grid = vec2(snap_res, snap_res * 0.75);
	p.xy = floor((p.xy / p.w) * grid + 0.5) / grid * p.w;
	POSITION = p;
	vec2 uv = UV * uv_scale;
	if (affine) {
		aff_uv = uv * p.w;
		aff_w = p.w;
	} else {
		aff_uv = uv;
		aff_w = 1.0;
	}
}

void fragment() {
	vec2 uv = aff_uv / aff_w;
	vec3 c = texture(albedo_tex, uv).rgb * albedo_color.rgb;
	ALBEDO = c;
	EMISSION = c * emission;
}
