shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// Wave parameters
uniform float wave_speed : hint_range(0.1, 3.0) = 0.8;
uniform float wave_height : hint_range(0.0, 2.0) = 0.25;
uniform float wave_frequency : hint_range(0.5, 8.0) = 2.5;
uniform float wave_direction : hint_range(0.0, 6.28) = 0.5;
uniform float secondary_wave_scale : hint_range(0.0, 1.0) = 0.4;

// Water colors
uniform vec4 shallow_color : source_color = vec4(0.25, 0.65, 0.72, 0.75);
uniform vec4 deep_color : source_color = vec4(0.05, 0.18, 0.32, 0.92);
uniform float depth_distance : hint_range(0.5, 20.0) = 5.0;

// Foam
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 0.9);
uniform float foam_threshold : hint_range(0.0, 2.0) = 0.6;
uniform float foam_softness : hint_range(0.01, 1.0) = 0.3;
uniform float foam_scale : hint_range(1.0, 30.0) = 12.0;

// Surface
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float metallic : hint_range(0.0, 1.0) = 0.3;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.6;
uniform float refraction_strength : hint_range(0.0, 0.5) = 0.08;

// Reflection
uniform float fresnel_power : hint_range(0.5, 8.0) = 4.0;
uniform vec4 reflect_color : source_color = vec4(0.6, 0.8, 0.95, 1.0);

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

varying vec3 world_pos;
varying float vertex_height;

// Simple hash-based noise
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
	for (int i = 0; i < 3; i++) {
		value += amplitude * noise(p);
		p *= 2.1;
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Primary wave
	vec2 wave_dir = vec2(cos(wave_direction), sin(wave_direction));
	float phase = dot(world_pos.xz, wave_dir) * wave_frequency + TIME * wave_speed;
	float primary_wave = sin(phase) * wave_height;

	// Secondary wave (cross direction for complexity)
	vec2 wave_dir2 = vec2(cos(wave_direction + 1.3), sin(wave_direction + 1.3));
	float phase2 = dot(world_pos.xz, wave_dir2) * wave_frequency * 1.7 + TIME * wave_speed * 1.2;
	float secondary_wave = sin(phase2) * wave_height * secondary_wave_scale;

	// Noise-based micro-waves
	float micro = fbm(world_pos.xz * 0.8 + TIME * wave_speed * 0.3) * wave_height * 0.15;

	float total_height = primary_wave + secondary_wave + micro;
	VERTEX.y += total_height;
	vertex_height = total_height;

	// Compute normals from wave derivatives
	float dx = cos(phase) * wave_height * wave_frequency * wave_dir.x
			 + cos(phase2) * wave_height * secondary_wave_scale * wave_frequency * 1.7 * wave_dir2.x;
	float dz = cos(phase) * wave_height * wave_frequency * wave_dir.y
			 + cos(phase2) * wave_height * secondary_wave_scale * wave_frequency * 1.7 * wave_dir2.y;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	// Depth-based color blending
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec4 world_depth = INV_PROJECTION_MATRIX * ndc;
	world_depth /= world_depth.w;
	float depth_diff = VERTEX.z - world_depth.z;
	float depth_factor = clamp(depth_diff / depth_distance, 0.0, 1.0);

	vec3 water_color = mix(shallow_color.rgb, deep_color.rgb, depth_factor);
	float water_alpha = mix(shallow_color.a, deep_color.a, depth_factor);

	// Fresnel reflection
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float fresnel = pow(1.0 - max(dot(n, v), 0.0), fresnel_power);
	water_color = mix(water_color, reflect_color.rgb, fresnel * 0.5);

	// Foam at shallow edges
	float foam_noise = fbm(world_pos.xz * foam_scale + TIME * wave_speed * 0.5);
	float foam_factor = smoothstep(foam_threshold + foam_softness, foam_threshold - foam_softness, depth_diff);
	foam_factor *= smoothstep(0.3, 0.6, foam_noise);
	water_color = mix(water_color, foam_color.rgb, foam_factor * foam_color.a);

	// Animated surface normal perturbation
	vec2 uv_offset1 = world_pos.xz * 0.15 + TIME * vec2(0.02, 0.03);
	vec2 uv_offset2 = world_pos.xz * 0.25 - TIME * vec2(0.015, 0.025);
	float n1 = fbm(uv_offset1 * 8.0);
	float n2 = fbm(uv_offset2 * 8.0);
	vec3 perturbed_normal = normalize(vec3(
		(n1 - 0.5) * normal_strength,
		1.0,
		(n2 - 0.5) * normal_strength
	));

	ALBEDO = water_color;
	ALPHA = water_alpha;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	NORMAL_MAP = perturbed_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;
}
