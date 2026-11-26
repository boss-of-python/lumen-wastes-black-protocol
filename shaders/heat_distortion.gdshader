shader_type canvas_item;
render_mode unshaded;

// heat_distortion.gdshader
// Heat-haze / fire distortion overlay. Samples the underlying scene with a
// turbulent UV displacement that intensifies with proximity to a heat source.

group_uniforms HeatDistortion;
uniform sampler2D scene_tex : source_color;
uniform float distortion_strength : hint_normal = 0.03;
uniform float heat_source_y : hint_normal = 0.5;
uniform float heat_radius : hint_normal = 0.35;
uniform float scroll_speed : hint_normal = 2.0;
uniform float turbulence_scale : hint_normal = 6.0;
uniform float intensity_falloff : hint_normal = 1.5;

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
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.03;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    vec2 uv = UV;
    float t = float(TIME) * scroll_speed;

    // Vertical falloff: strongest near the heat source band.
    float vertical = exp(-pow((uv.y - heat_source_y) / heat_radius, 2.0));

    vec2 displaced_uv = uv;
    displaced_uv.x += (fbm(vec2(uv.x * turbulence_scale, uv.y * turbulence_scale + t)) - 0.5)
                     * distortion_strength * vertical * intensity_falloff * 4.0;
    displaced_uv.y += (fbm(vec2(uv.x * turbulence_scale * 1.3 + 10.0, uv.y * turbulence_scale - t * 0.7)) - 0.5)
                     * distortion_strength * vertical * intensity_falloff * 2.0;

    vec4 scene = texture(scene_tex, displaced_uv);

    // Subtle iridescence at the hottest band.
    float shimmer = sin(uv.x * 40.0 + t * 5.0) * vertical * 0.04;
    scene.rgb += vec3(shimmer, shimmer * 0.4, shimmer * 0.7);

    COLOR = scene;
}
