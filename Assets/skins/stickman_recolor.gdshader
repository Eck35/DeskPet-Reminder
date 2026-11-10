shader_type canvas_item;

uniform vec4 head_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool recolor_lines = true;
uniform float tolerance = 0.05;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (color.a > 0.0) {
		if (distance(color.rgb, vec3(1.0)) <= tolerance) {
			color.rgb = head_color.rgb;
		} else if (recolor_lines && distance(color.rgb, vec3(0.0)) <= tolerance) {
			color.rgb = line_color.rgb;
		}
	}
	COLOR = color;
}
