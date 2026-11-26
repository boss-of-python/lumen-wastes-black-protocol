shader_type canvas_item;
render_mode unshaded, blend_preadd;

// transition_wipes.gdshader
// Scene transition wipes:
//   mode 0 = Black Ops neural-glitch wipe (RGB-split, scan tearing)
//   mode 1 = Wukong ink-wash / gold dissolve (soft gold dissolve)

group_uniforms TransitionWipes;
uniform sampler2D scene_tex : source_color;
uniform int wipe_mode : hint_range(0, 1) = 0;
uniform float wipe_progress : hint_normal = 0.0;
uniform float glitch_intensity : hint_normal = 0.35;
uniform vec4 gold_tint : source_color = vec4(1.0, 0.84, 0.36, 1.0);
uniform float ink_softness : hint_normal = 0.08;
uniform float scan_speed : hint_normal = 1.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    float t = float(TIME) * scan_speed;
    vec4 scene = texture(scene_tex, uv);

    // Edge position of the wipe front.
    float front = wipe_progress;

    if (wipe_mode == 0) {
        // ---- Black Ops neural-glitch wipe ----
        // RGB channel split driven by the wipe front.
        float split = glitch_intensity * (1.0 - abs(uv.x * 2.0 - 1.0)) * step(0.0, 1.0 - wipe_progress);
        vec2 offset = vec2(split * 0.02, 0.0);
        vec3 glitch = vec3(
            texture(scene_tex, uv + offset).r,
            texture(scene_tex, uv).g,
            texture(scene_tex, uv - offset).b
        );

        // Horizontal scan tearing.
        float tear = step(0.8, hash(vec2(floor(uv.y * 300.0), floor(t * 30.0))));
        float tear_y = floor(uv.y * 30.0) / 30.0;
        float tear_mask = smoothstep(0.02, 0.0, abs(uv.y - tear_y - fract(t * 0.4)));
        glitch += vec3(tear_mask * tear * 0.6);

        // Wipe reveal with hard scanline edge.
        float reveal = smoothstep(front - 0.02, front, uv.x) * (1.0 - step(0.98, hash(vec2(floor(uv.y * 500.0), floor(t * 20.0)))));
        vec3 color = mix(glitch, vec3(0.0), reveal);
        COLOR = vec4(color, 1.0);
    } else {
        // ---- Wukong ink-wash / gold dissolve ----
        float noise_field = hash(floor(uv * 40.0) + floor(t * 2.0));
        float dissolve_edge = front + (noise_field - 0.5) * ink_softness * 2.0;
        float dissolve = smoothstep(dissolve_edge - ink_softness, dissolve_edge + ink_softness, uv.x);

        vec3 color = scene.rgb;
        // Dissolved edge glows gold.
        float edge_glow = smoothstep(dissolve_edge - ink_softness * 2.0, dissolve_edge, uv.x)
                        * smoothstep(dissolve_edge, dissolve_edge + ink_softness * 2.0, uv.x);
        color += gold_tint.rgb * edge_glow * 1.4;
        color *= (1.0 - dissolve);

        COLOR = vec4(color, 1.0);
    }
}
