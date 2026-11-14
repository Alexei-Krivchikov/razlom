shader_type canvas_item;

// Chromatic split grows toward the screen edges: the rift bleeding into the frame.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float aberration = 0.012;

void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	vec2 shift = d * dot(d, d) * aberration;
	float r = texture(screen_tex, SCREEN_UV + shift).r;
	float g = texture(screen_tex, SCREEN_UV).g;
	float b = texture(screen_tex, SCREEN_UV - shift).b;
	float vignette = smoothstep(0.85, 0.35, length(d * vec2(1.0, 0.8)));
	COLOR = vec4(vec3(r, g, b) * mix(0.55, 1.0, vignette), 1.0);
}
