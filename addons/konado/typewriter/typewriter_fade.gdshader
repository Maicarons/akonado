shader_type canvas_item;

// Reveal progress: 0.0 = nothing visible, 1.0+ = everything visible.
uniform float progress : hint_range(0.0, 1.2) = 0.0;
// Fade softness in normalised units (larger = wider gradient band).
uniform float softness : hint_range(0.001, 0.5) = 0.08;
// Sweep direction angle in radians (0 = left-to-right).
uniform float angle_rad : hint_range(-3.14159, 3.14159) = 0.0;
// Blend between pure character-order (0) and spatial-direction (1).
uniform float spatial_blend : hint_range(0.0, 1.0) = 0.15;
// Control rect size in pixels – updated every frame by the script.
uniform vec2 rect_size = vec2(400.0, 200.0);

varying float v_reveal_time;
varying float v_spatial;

void vertex() {
	// COLOR.a is encoded as the character's normalised reveal-time (index/total).
	v_reveal_time = COLOR.a;

	// Project the vertex position onto the sweep direction to get a spatial reveal value.
	vec2 dir = vec2(cos(angle_rad), sin(angle_rad));
	vec2 norm_pos = VERTEX / max(rect_size, vec2(1.0));
	float max_proj = abs(dir.x) + abs(dir.y);
	v_spatial = dot(norm_pos, dir) / max(max_proj, 0.001);
}

void fragment() {
	// Blend character-order reveal with spatial reveal.
	float reveal_val = mix(v_reveal_time, v_spatial, spatial_blend);

	// Smooth alpha ramp: fully transparent when progress is well below reveal_val,
	// fully opaque when progress exceeds reveal_val + softness.
	float a = smoothstep(reveal_val, reveal_val + softness, progress);

	// Sample the glyph / primitive texture.
	vec4 tex = texture(TEXTURE, UV);

	// Final output – vertex RGB carries the intended text colour.
	COLOR = vec4(COLOR.rgb * tex.rgb, tex.a * a);
}
