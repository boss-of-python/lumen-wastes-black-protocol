shader_type canvas_item;
render_mode unshaded, blend_preadd;

// volumetric_godrays.gdshader
// Volumetric god-ray / mist volume overlay for monumental biome backdrops.
// Applied to a full-screen quad above the midground; samples a ray-marched
// light-shaft field modulated by radial falloff and scene height fog.

group_uniforms VolumetricGodrays;
uniform vec4 ray_color : source_color = vec4(1.0, 0.92, 0.66, 0.55);
uniform vec2 ray_origin = vec2(0.5, -0.2);
uniform float ray_intensity : hint_normal = 0.8;
uniform float ray_sharpness : hint_normal = 6.0;
uniform float mist_density : hint_normal = 0.25;
uniform float time_scale : hint_normal = 0.15;
uniform float scroll_speed : hint_normal = 0.02;

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
        p *= 2.02;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    vec2 uv = UV;
    // Slow drifting volumetric field.
    vec2 drift = vec2(time_scale * float(TIME) * 0.1, 0.0);
    float field = fbm((uv * 6.0) + drift + vec2(0.0, scroll_speed * float(TIME)));

    // Radial falloff from the light shaft origin (above the scene).
    float dist = distance(uv, ray_origin);
    float radial = exp(-dist * ray_sharpness);

    // Vertical shaft mask — strongest near top, fading downward.
    float vertical = smoothstep(1.0, 0.25, uv.y);

    float rays = pow(clamp(field * radial * vertical, 0.0, 1.0), 1.6) * ray_intensity;
    // Mist layer across the lower scene.
    float mist = fbm(uv * 3.0 - drift * 2.0) * mist_density * (1.0 - vertical);

    float alpha = clamp(rays + mist, 0.0, 1.0);
    COLOR = ray_color * (rays + mist * 0.6) + ray_color * vec4(0.0, 0.0, 0.0, mist);
    // Pre-add blend keeps the overlay additive over the scene.
    COLOR.a = alpha;
}
