shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

uniform sampler2D sprite_texture : source_color, filter_nearest;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(sprite_texture, UV);
	ALBEDO = mix(tex.rgb, vec3(1.0), flash_amount);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
