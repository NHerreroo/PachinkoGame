shader_type canvas_item;

// Color configuration
uniform vec3 color1 : source_color = vec3(1.0, 0.4, 0.2); // Orange
uniform vec3 color2 : source_color = vec3(0.2, 0.6, 1.0); // Blue  
uniform vec3 color3 : source_color = vec3(0.8, 0.2, 0.8); // Purple
uniform vec3 color4 : source_color = vec3(0.2, 0.8, 0.4); // Green

// Animation controls
uniform float speed : hint_range(0.1, 2.0) = 0.5;
uniform float wave_frequency : hint_range(1.0, 10.0) = 3.0;
uniform float wave_amplitude : hint_range(0.1, 1.0) = 0.3;

// Grain effect
uniform float grain_strength : hint_range(0.0, 0.2) = 0.05;
uniform float grain_scale : hint_range(10.0, 100.0) = 50.0;

// Gradient controls
uniform float gradient_scale : hint_range(0.5, 3.0) = 1.5;
uniform float blend_smoothness : hint_range(0.1, 1.0) = 0.6;

// Simple noise function for grain
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Smooth noise function
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Fractal noise for more complex patterns
float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 0.0;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(st);
        st *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * speed;
    
    // Create flowing movement
    vec2 distorted_uv = uv;
    distorted_uv.x += sin(uv.y * wave_frequency + time) * wave_amplitude * 0.1;
    distorted_uv.y += cos(uv.x * wave_frequency + time * 0.8) * wave_amplitude * 0.1;
    
    // Generate multiple noise layers for vintage gradient effect
    float noise1 = fbm(distorted_uv * gradient_scale + time * 0.3);
    float noise2 = fbm(distorted_uv * gradient_scale * 0.7 + time * 0.2);
    float noise3 = fbm(distorted_uv * gradient_scale * 1.3 - time * 0.1);
    
    // Create smooth transitions between colors
    float blend1 = smoothstep(0.0, blend_smoothness, noise1);
    float blend2 = smoothstep(0.3, 0.3 + blend_smoothness, noise2);
    float blend3 = smoothstep(0.6, 0.6 + blend_smoothness, noise3);
    
    // Mix colors based on noise values
    vec3 mixed_color = mix(color1, color2, blend1);
    mixed_color = mix(mixed_color, color3, blend2);
    mixed_color = mix(mixed_color, color4, blend3);
    
    // Add some additional color variation
    float color_variation = sin(time + uv.x * 3.14159) * 0.1 + cos(time * 0.7 + uv.y * 3.14159) * 0.1;
    mixed_color += color_variation;
    
    // Add grain effect
    float grain = random(uv * grain_scale + time * 10.0) - 0.5;
    mixed_color += grain * grain_strength;
    
    // Ensure colors stay in valid range
    mixed_color = clamp(mixed_color, 0.0, 1.0);
    
    COLOR = vec4(mixed_color, 1.0);
}
