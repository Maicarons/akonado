shader_type canvas_item;

// 转场进度：
// 0 = 黑暗，眼睛完全闭上
// 1 = 目标画面，眼睛完全睁开且清晰
uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D current_texture : hint_default_black;
uniform sampler2D target_texture : hint_default_black;


// ==============================
// 可调参数
// ==============================

// 眼皮颜色
uniform vec4 eyelid_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

uniform float edge_softness : hint_range(0.001, 0.15) = 0.045;
uniform float eye_width : hint_range(0.3, 1.5) = 1.05;
uniform float open_height : hint_range(0.5, 1.5) = 1.10;
uniform float closed_height : hint_range(0.0, 0.1) = 0.005;
uniform float blur_strength : hint_range(0.0, 0.03) = 0.0055;
uniform float darkness : hint_range(0.0, 1.0) = 0.70;
uniform float clear_start : hint_range(0.6, 1.0) = 0.78;


// ==============================
// 工具函数
// ==============================

float smootherstep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / max(edge1 - edge0, 0.0001), 0.0, 1.0);
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

vec4 sample_safe(sampler2D tex, vec2 uv) {
    return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

// 简单 9 点模糊
vec4 blur_texture(sampler2D tex, vec2 uv, float amount) {
    vec2 o = vec2(amount);

    vec4 col = vec4(0.0);

    col += sample_safe(tex, uv + vec2(-1.0, -1.0) * o) * 0.0625;
    col += sample_safe(tex, uv + vec2( 0.0, -1.0) * o) * 0.125;
    col += sample_safe(tex, uv + vec2( 1.0, -1.0) * o) * 0.0625;

    col += sample_safe(tex, uv + vec2(-1.0,  0.0) * o) * 0.125;
    col += sample_safe(tex, uv + vec2( 0.0,  0.0) * o) * 0.25;
    col += sample_safe(tex, uv + vec2( 1.0,  0.0) * o) * 0.125;

    col += sample_safe(tex, uv + vec2(-1.0,  1.0) * o) * 0.0625;
    col += sample_safe(tex, uv + vec2( 0.0,  1.0) * o) * 0.125;
    col += sample_safe(tex, uv + vec2( 1.0,  1.0) * o) * 0.0625;

    return col;
}


// ==============================
// 困倦睁眼曲线
//
// 参数：
// p = progress，范围 0.0 ~ 1.0
//
// 返回值：
// 0.0 = 完全睁开
// 1.0 = 完全闭上
//
// 节奏：
// 0.00 ~ 0.22  从黑暗中第一次慢慢睁开
// 0.22 ~ 0.40  困意反扑，眼皮重新沉下去
// 0.40 ~ 0.56  勉强半睁一下
// 0.56 ~ 0.70  再次闭上
// 0.70 ~ 1.00  最后缓慢完全睁开
// ==============================

float get_sleepy_blink(float p) {
    float blink = 0.9;

    if (p < 0.22) {
        // 开头：从完全闭眼慢慢张开
        // 不要直接睁太大，只睁到半开，像刚醒
        blink = mix(
            1.0,
            0.38,
            smootherstep(0.00, 0.22, p)
        );

    } else if (p < 0.40) {
        // 困意反扑：眼皮重新沉下去
        blink = mix(
            0.38,
            0.92,
            smootherstep(0.22, 0.40, p)
        );

    } else if (p < 0.56) {
        // 勉强再睁开一点
        // 这里不要完全睁开，否则会像普通眨眼
        blink = mix(
            0.92,
            0.48,
            smootherstep(0.40, 0.56, p)
        );

    } else if (p < 0.70) {
        // 再次闭上
        blink = mix(
            0.48,
            1.0,
            smootherstep(0.56, 0.70, p)
        );

    } else {
        // 最后阶段：真正慢慢完全睁开
        blink = mix(
            1.0,
            0.0,
            smootherstep(0.70, 1.00, p)
        );
    }

    return clamp(blink, 0.0, 1.0);
}
// ==============================
// 上下眼皮形成的椭圆形视野
//
// 关键点：
// 这里不是中间圆形缩放，
// 而是上下眼皮向中间闭合。
// 椭圆只用于决定眼皮边缘的弧度。
// ==============================

float get_eyelid_mask(vec2 uv, float blink_amount) {
    // 横向归一化：
    // 中心为 0，左右两侧逐渐接近 1
    float x = (uv.x - 0.5) / eye_width;

    // 椭圆上半部分曲线：
    // 中间最高，左右两侧变窄
    float ellipse_curve = sqrt(max(0.0, 1.0 - x * x));

    // 当前眼睛开合高度
    // blink_amount = 0 时，高度最大
    // blink_amount = 1 时，高度接近 closed_height
    float half_open = mix(open_height, closed_height, blink_amount) * 0.5;

    // 上眼皮边缘
    float upper_lid = 0.5 - half_open * ellipse_curve;

    // 下眼皮边缘
    float lower_lid = 0.5 + half_open * ellipse_curve;

    // 在 upper_lid 和 lower_lid 之间的是可见区域
    float visible_top = smoothstep(
        upper_lid - edge_softness,
        upper_lid + edge_softness,
        uv.y
    );

    float visible_bottom = 1.0 - smoothstep(
        lower_lid - edge_softness,
        lower_lid + edge_softness,
        uv.y
    );

    float visible = visible_top * visible_bottom;

    // 当眼睛几乎全开时，不显示任何眼皮，避免画面左右边缘出现黑色残留
    float eyelid_presence = smootherstep(0.03, 0.18, blink_amount);

    // mask = 1 表示被眼皮遮挡
    float mask = 1.0 - visible;

    return clamp(mask * eyelid_presence, 0.0, 1.0);
}


void fragment() {
    vec2 uv = UV;

    if (progress >= 1.0) {
        COLOR = texture(target_texture, uv);
    } else {
        // 眨眼开合程度
        float blink_amount = get_sleepy_blink(progress);

        // 纹理切换：
        // 建议放在第二次闭眼附近切换。
        // 这样从 current_texture 到 target_texture 不会突兀。
        float texture_mix = smootherstep(0.58, 0.76, progress);

        // 最后阶段逐渐清晰
        float clear_factor = 1.0 - smootherstep(clear_start, 1.0, progress);

        // 过程中保持轻微模糊，闭眼时更模糊
        float process_blur = smootherstep(0.02, 0.12, progress) * clear_factor;
        float blink_blur = blink_amount * clear_factor;

        float blur_amount = blur_strength * mix(0.45, 1.0, blink_blur) * process_blur;

        vec4 current_color = blur_texture(current_texture, uv, blur_amount);
        vec4 target_color = blur_texture(target_texture, uv, blur_amount);

        vec4 scene_color = mix(current_color, target_color, texture_mix);

        // 闭眼时压暗
        float dark_factor = blink_amount * darkness;
        scene_color.rgb = mix(scene_color.rgb, scene_color.rgb * 0.25, dark_factor);

        // 上下眼皮遮罩
        float eyelid_mask = get_eyelid_mask(uv, blink_amount);

        // 叠加眼皮
        COLOR = mix(scene_color, eyelid_color, eyelid_mask);
    }
}