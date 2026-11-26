shader_type canvas_item;
render_mode unshaded;

// reactive_foliage_cloth.gdshader
// Reactive swaying foreground foliage / cloth / cables.
// Verlet-style sway driven by wind + a player-proximity reactive impulse,
// with depth-based parallax offset passed via a uniform.

group_uniforms ReactiveFoliageCloth;
uniform sampler2D foliage_tex : source_color;
uniform vec4 wind_vector : source_color = vec4(0.12, 0.03, 0.0, 1.0);
uniform float wind_speed : hint_normal = 1.0;
uniform float sway_amplitude : hint_normal = 0.02;
uniform float proximity_strength : hint_normal = 0.05;
uniform vec2 player_pos = vec2(0.5, 0.5);
uniform float time_scale : hint_normal = 1.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    float t = float(TIME) * time_scale * wind_speed;

    // Layered sinusoidal sway — different frequencies per depth band.
    float sway = sin(t * 1.7 + uv.y * 8.0) * 0.55
               + sin(t * 2.9 + uv.y * 14.0 + uv.x * 3.0) * 0.28
               + sin(t * 0.6 + uv.y * 4.0) * 0.17;
    sway *= sway_amplitude;

    // Reactive push away from the player (local space, normalized).
    vec2 to_player = player_pos - uv;
    float proximity = smoothstep(0.22, 0.0, length(to_player));
    sway += normalize(to_player + vec2(0.0001)) * proximity * proximity_strength;

    vec2 distorted = uv + vec2(sway, sin(t * 2.3 + uv.x * 10.0) * sway_amplitude * 0.4);
    vec4 tex = texture(foliage_tex, distorted);

    // Subtle wind-driven alpha shimmer on leaf edges.
    float edge = smoothstep(0.15, 0.45, tex.a);
    float shimmer = 0.5 + 0.5 * sin(t * 3.1 + hash(floor(distorted * 64.0)) * 30.0);
    tex.a *= mix(1.0, edge * shimmer * 0.6 + 0.6, 0.3);

    COLOR = tex;
}
