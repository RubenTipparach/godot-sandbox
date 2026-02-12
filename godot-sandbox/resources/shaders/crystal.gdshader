shader_type spatial;
render_mode cull_disabled;
uniform vec4 crystal_color : source_color = vec4(0.2, 0.4, 0.95, 1.0);
uniform float refraction_strength = 0.08;
void fragment() {
	float t = TIME;
	float facet = abs(sin(VERTEX.x * 2.0 + VERTEX.y * 3.0 + t * 0.5));
	float shimmer = sin(t * 2.0 + VERTEX.y * 4.0) * 0.5 + 0.5;
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float fresnel = pow(edge, 2.5);
	ALBEDO = crystal_color.rgb * (0.3 + 0.2 * facet);
	METALLIC = 0.1;
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	EMISSION = crystal_color.rgb * (fresnel * 1.5 + shimmer * 0.3 + facet * 0.2);
	ALPHA = 0.85 + fresnel * 0.15;
	RIM = 0.6;
	RIM_TINT = 0.3;
}
