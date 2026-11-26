shader_type canvas_item;
render_mode unshaded;

// water_acid_refraction.gdshader
// Water / acid pool surface: animated refraction of the scene beneath,
// caustic ripples, and acid dissolution tinting for pool hazards.

group_uniforms WaterAcidRefraction;
uniform sampler2D scene_tex : source_color;
uniform vec4 water_tint : source_color = vec4(0.10, 0.35, 0.62, 1.0);
uniform vec4 acid_tint : source_color = vec4(0.30, 0.75, 0.20, 1.0);
uniform bool is_acid : hint_normal = false;
uniform float ripple_speed : hint_normal = 1.0;
uniform float ripple_amplitude : hint_normal = 0.02;
uniform float refraction_strength : hint_normal = 0.03;
uniform float caustic_intensity : hint_normal = 0.5;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    float t = float(TIME) * ripple_speed;

    // Two counter-rotating ripple fields.
    float r1 = sin(uv.x * 18.0 + t * 2.1) * cos(uv.y * 14.0 - t * 1.6);
    float r2 = sin(uv.x * 11.0 - t * 1.4) * cos(uv.y * 17.0 + t * 2.4);
    float ripple = (r1 * 0.6 + r2 * 0.4) * ripple_amplitude;

    // Perspective-style refraction offset.
    vec2 offset = vec2(ripple, ripple * 0.6);
    offset += vec2(sin(t * 0.8 + uv.y * 6.0), cos(t * 0.7 + uv.x * 6.0)) * 0.006;

    vec4 sampled = texture(scene_tex, uv + offset * refraction_strength * 10.0);

    // Caustic light bands on the surface.
    float caustic = pow(abs(sin((uv.x + uv.y) * 26.0 + t * 3.0)), 8.0) * caustic_intensity;
    caustic += pow(abs(sin((uv.x * 2.0 - uv.y) * 22.0 - t * 2.6)), 10.0) * caustic_intensity * 0.5;

    vec3 tint = mix(water_tint.rgb, acid_tint.rgb, float(is_acid));
    vec3 color = mix(sampled.rgb, sampled.rgb * tint + tint * 0.25, 0.45);
    color += caustic * vec3(1.0, 0.95, 0.8);

    float surface_alpha = 0.75 + caustic * 0.25;
    COLOR = vec4(color, surface_alpha * sampled.a);
}
