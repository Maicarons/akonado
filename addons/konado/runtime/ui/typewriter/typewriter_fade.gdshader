shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.2) = 0.0;
uniform float softness : hint_range(0.001, 0.5) = 0.08;
uniform float angle_rad : hint_range(-3.14159, 3.14159) = 0.0;
uniform float spatial_blend : hint_range(0.0, 1.0) = 0.15;
uniform vec2 rect_size = vec2(400.0, 200.0);

// 新增：多行支持参数
uniform int line_count = 1;
uniform float line_height = 20.0;

varying float v_reveal_time;
varying float v_spatial;

void vertex() {
    // 从顶点颜色 alpha 读取字符的顺序归一化时间 (index/total)
    v_reveal_time = COLOR.a;

    // 计算当前顶点所在的行索引（0 起始）
    // 使用 line_height 划分垂直坐标，并钳位到有效范围
    float line_index = floor(VERTEX.y / line_height);
    line_index = clamp(line_index, 0.0, float(line_count - 1));

    // 在行内计算空间方向投影（与原逻辑一致）
    vec2 dir = vec2(cos(angle_rad), sin(angle_rad));
    vec2 norm_pos = VERTEX / max(rect_size, vec2(1.0));
    float proj_in_line = dot(norm_pos, dir) / max(abs(dir.x) + abs(dir.y), 0.001);

    // 将行索引纳入空间值：每行占据 1/line_count 的区间，并连续排列
    // 例如：第 0 行 → [0, 1/line_count]，第 1 行 → [1/line_count, 2/line_count]
    v_spatial = (line_index + proj_in_line) / float(line_count);
}

void fragment() {
    // 混合字符顺序和空间方向
    float reveal_val = mix(v_reveal_time, v_spatial, spatial_blend);

    // 平滑淡入边缘
    float a = smoothstep(reveal_val, reveal_val + softness, progress);

    // 采样字形纹理
    vec4 tex = texture(TEXTURE, UV);

    // 最终颜色：顶点 RGB 为文字颜色，alpha 为透明度
    COLOR = vec4(COLOR.rgb * tex.rgb, tex.a * a);
}