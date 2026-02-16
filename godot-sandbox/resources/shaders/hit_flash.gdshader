shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D sprite_texture : source_color;

void fragment() {
	ALBEDO = vec3(1.0);
	ALPHA = texture(sprite_texture, UV).a * flash_amount;
}
