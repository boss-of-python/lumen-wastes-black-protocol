shader_type canvas_item;
render_mode unshaded, blend_preadd;

// stasis_gold_freeze.gdshader
// Black Myth: Wukong "Stasis Lock" freeze effect.
// Encases a frozen target in a golden crystalline shell with crackling
// veins of light and a slow pulsing energy core.

group_uniforms StasisGoldFreeze;
uniform vec4 gold_tint : source_color = vec4(1.0, 0.82, 0.32, 1.0);
uniform float freeze_progress : hint_normal = 1.0;
uniform float freeze_time : hint_normal = 3.2;
uniform float crack_density : hint_normal = 8.0;
uniform float pulse_speed : hint_normal = 1.5;
uniform float intensity : hint_normal = 1.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p);
        p *= 2.1;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    vec2 uv = UV;
    // Center the effect on the frozen sprite.
    vec2 center = vec2(0.5);
    vec2 p = uv - center;

    // Crystalline facet field.
    float facets = fbm(p * crack_density);
    float shell = smoothstep(0.25, 0.75, 1.0 - length(p) * 2.0);

    // Crackling gold veins.
    float cracks = pow(smoothstep(0.55, 0.85, facets), 2.0);
    float t = float(TIME) * pulse_speed;
    cracks *= 0.7 + 0.3 * sin(t * 2.0 + hash(floor(p * crack_density * 4.0)) * 30.0);

    // Slow rotating energy core.
    float angle = atan(p.y, p.x);
    float core = pow(max(cos(angle * 6.0 + t), 0.0), 8.0);
    core *= smoothstep(0.5, 0.0, length(p));

    float shell_mask = clamp(shell * freeze_progress, 0.0, 1.0);
    float glow = (cracks * 0.8 + core * 1.2) * shell_mask;

    vec3 color = gold_tint.rgb * glow * intensity;
    // Add a hard crystal rim.
    float rim = smoothstep(0.3, 0.32, length(p)) * smoothstep(0.34, 0.3, length(p));
    color += gold_tint.rgb * rim * shell_mask * 1.5;

    float alpha = clamp(glow * 0.9 + rim * shell_mask, 0.0, 1.0);
    COLOR = vec4(color, alpha);
}
