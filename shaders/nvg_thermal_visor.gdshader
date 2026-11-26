shader_type canvas_item;
render_mode unshaded;

// nvg_thermal_visor.gdshader
// Switchable head-mounted visor overlay:
//   mode 0 = Modern Warfare Green Phosphor NVG (night-vision)
//   mode 1 = Thermal FLIR (heat-signature vision)
// Applied as a full-screen post overlay on the camera viewport.

group_uniforms NVGThermalVisor;
uniform sampler2D scene_tex : source_color;
uniform int visor_mode : hint_range(0, 1) = 0;
uniform float visor_intensity : hint_normal = 1.0;
uniform vec4 phosphor_tint : source_color = vec4(0.12, 1.0, 0.30, 1.0);
uniform float phosphor_gain : hint_normal = 1.6;
uniform float scanline_strength : hint_normal = 0.25;
uniform float vignette_strength : hint_normal = 0.55;
uniform float thermal_contrast : hint_normal = 1.8;
uniform vec4 thermal_hot : source_color = vec4(1.0, 0.25, 0.05, 1.0);
uniform vec4 thermal_cold : source_color = vec4(0.03, 0.10, 0.55, 1.0);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec4 scene = texture(scene_tex, UV);
    float luminance = dot(scene.rgb, vec3(0.299, 0.587, 0.114));

    vec3 color;
    if (visor_mode == 0) {
        // ---- Green Phosphor NVG ----
        float nvg = pow(clamp(luminance * phosphor_gain, 0.0, 1.0), 0.8);
        color = phosphor_tint.rgb * nvg;

        // Fixed scanline grid.
        float scanline = 0.5 + 0.5 * sin(UV.y * 800.0);
        color *= 1.0 - scanline_strength * scanline;

        // Rolling VT ribbing.
        float ribbing = 0.92 + 0.08 * sin(UV.y * 200.0 + float(TIME) * 4.0);
        color *= ribbing;
    } else {
        // ---- Thermal FLIR ----
        float heat = clamp(luminance * thermal_contrast, 0.0, 1.0);
        // Invert so dark/cold areas show cold blue, bright/hot areas hot red.
        heat = pow(1.0 - heat, 0.9);
        color = mix(thermal_cold.rgb, thermal_hot.rgb, heat);

        // Heat-signature edge enhancement.
        float edge = abs(luminance - smoothstep(0.0, 1.0, luminance));
        color += vec3(1.0, 0.9, 0.7) * edge * 0.3;
    }

    // Visor vignette.
    float vig = smoothstep(1.1, 0.35, length(UV - vec2(0.5)));
    color *= mix(1.0, vig, vignette_strength);

    // Chromatic edge fringing for optical character.
    float fringing = 0.06 * (1.0 - vig);
    color.r += fringing;
    color.b -= fringing * 0.5;

    COLOR = vec4(color * visor_intensity, 1.0);
}
