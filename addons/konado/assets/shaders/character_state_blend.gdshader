shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 target_origin;
uniform vec2 target_size;
uniform sampler2D old_texture : source_color, repeat_disable;
uniform sampler2D new_texture : source_color, repeat_disable;
uniform vec4 old_inverse_basis;
uniform vec2 old_inverse_origin;
uniform vec4 new_inverse_basis;
uniform vec2 new_inverse_origin;
uniform vec4 old_region;
uniform vec4 new_region;
uniform vec4 old_clip_region;
uniform vec4 new_clip_region;
uniform bool old_filter_clip = false;
uniform bool new_filter_clip = false;
uniform vec2 old_texture_size;
uniform vec2 new_texture_size;
uniform vec2 old_flip;
uniform vec2 new_flip;
uniform vec4 old_modulate : source_color = vec4(1.0);
uniform vec4 new_modulate : source_color = vec4(1.0);


vec2 transform_point(vec2 point, vec4 basis, vec2 origin) {
	return vec2(
		basis.x * point.x + basis.z * point.y,
		basis.y * point.x + basis.w * point.y
	) + origin;
}


vec4 sample_frame(
	sampler2D frame_texture,
	vec2 target_point,
	vec4 inverse_basis,
	vec2 inverse_origin,
	vec4 region,
	vec4 clip_region,
	bool filter_clip,
	vec2 texture_size,
	vec2 flip,
	vec4 frame_modulate
) {
	vec2 local_point = transform_point(target_point, inverse_basis, inverse_origin);
	if (
		local_point.x < 0.0 || local_point.y < 0.0
		|| local_point.x >= region.z || local_point.y >= region.w
	) {
		return vec4(0.0);
	}
	if (flip.x > 0.5) {
		local_point.x = region.z - local_point.x - 0.0001;
	}
	if (flip.y > 0.5) {
		local_point.y = region.w - local_point.y - 0.0001;
	}
	vec2 frame_uv = (region.xy + local_point) / texture_size;
	if (filter_clip) {
		vec2 region_min = (clip_region.xy + vec2(0.5)) / texture_size;
		vec2 region_max = (clip_region.xy + clip_region.zw - vec2(0.5)) / texture_size;
		frame_uv = clamp(frame_uv, region_min, region_max);
	}
	return texture(frame_texture, frame_uv) * frame_modulate;
}


void fragment() {
	vec2 target_point = target_origin + UV * target_size;
	vec4 old_color = sample_frame(
		old_texture,
		target_point,
		old_inverse_basis,
		old_inverse_origin,
		old_region,
		old_clip_region,
		old_filter_clip,
		old_texture_size,
		old_flip,
		old_modulate
	);
	vec4 new_color = sample_frame(
		new_texture,
		target_point,
		new_inverse_basis,
		new_inverse_origin,
		new_region,
		new_clip_region,
		new_filter_clip,
		new_texture_size,
		new_flip,
		new_modulate
	);

	// 在线性插值前转为预乘 Alpha，避免两个半透明图层叠加时背景透出，
	// 也避免透明边缘在转场结束时突然消失。
	float mixed_alpha = mix(old_color.a, new_color.a, progress);
	vec3 mixed_premultiplied = mix(
		old_color.rgb * old_color.a,
		new_color.rgb * new_color.a,
		progress
	);
	vec3 mixed_rgb = mixed_alpha > 0.00001 ? mixed_premultiplied / mixed_alpha : vec3(0.0);
	COLOR = vec4(mixed_rgb, mixed_alpha) * COLOR;
}
