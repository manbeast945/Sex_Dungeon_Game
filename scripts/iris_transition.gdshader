shader_type canvas_item;

uniform float radius = 2.0;

void fragment() {
	float distance_from_center = distance(UV, vec2(0.5));
	float black_outside = 1.0 - step(distance_from_center, radius);
	COLOR = vec4(0.0, 0.0, 0.0, black_outside);
}
