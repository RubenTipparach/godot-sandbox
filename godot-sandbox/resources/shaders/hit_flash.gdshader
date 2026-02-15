shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	ALBEDO = vec3(1.0);
	ALPHA = tex.a * flash_amount;
}
