// NOTE: Shader automatically converted from Godot Engine 4.3.stable's CanvasItemMaterial.

shader_type canvas_item;
render_mode blend_mix;

uniform vec4 color: source_color = vec4(1, 1, 1, 0);
uniform vec4 ignore_color: source_color = vec4(0.188235, 0.188235, 0.188235, 1.0);

void fragment() {
	if (color.a > 0.0 && dot(abs(ignore_color.rgb - COLOR.rgb), vec3(1)) > 1e-4)
		COLOR.rgb = mix(COLOR.rgb, color.rgb, color.a);
}