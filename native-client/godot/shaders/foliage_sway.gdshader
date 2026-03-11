shader_type spatial;

render_mode diffuse_toon, specular_toon, cull_disabled;

// Base appearance
uniform vec4 albedo_color : source_color = vec4(0.35, 0.65, 0.25, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

// Color variation
uniform vec4 tip_color : source_color = vec4(0.55, 0.78, 0.3, 1.0);
uniform float color_variation_amount : hint_range(0.0, 1.0) = 0.4;
uniform float color_variation_scale : hint_range(0.1, 20.0) = 3.0;

// Wind parameters
uniform vec2 wind_direction = vec2(1.0, 0.3);
uniform float wind_speed : hint_range(0.1, 5.0) = 1.2;
uniform float wind_strength : hint_range(0.0, 2.0) = 0.3;
uniform float wind_turbulence : hint_range(0.0, 1.0) = 0.35;
uniform float wind_frequency : hint_range(0.5, 8.0) = 2.0;

// Sway tuning
uniform float sway_height_influence : hint_range(0.0, 1.0) = 0.8;
uniform float sway_phase_variation : hint_range(0.0, 5.0) = 2.0;
uniform float trunk_stiffness : hint_range(0.0, 1.0) = 0.7;

// Subsurface scattering approximation
uniform float subsurface_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec4 subsurface_color : source_color = vec4(0.6, 0.8, 0.2, 1.0);

varying vec3 world_pos;
varying float height_factor;

// Simple noise
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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Height factor: vertices higher up sway more (use local Y or vertex color)
	// Using local vertex Y position, normalized. Assumes foliage geometry has
	// its base near Y=0 in local space.
	height_factor = clamp(VERTEX.y * sway_height_influence, 0.0, 1.0);

	// Trunk stiffness: bottom vertices barely move
	float sway_mask = pow(height_factor, mix(1.0, 3.0, trunk_stiffness));

	// Wind calculation
	vec2 wind_dir = normalize(wind_direction);
	float time_offset = TIME * wind_speed;

	// Per-instance phase offset based on world position (so each tree sways differently)
	float phase_offset = hash(floor(world_pos.xz * 0.1)) * sway_phase_variation * 6.28;

	// Primary sway: large slow movement
	float primary_sway = sin(
		dot(world_pos.xz, wind_dir) * wind_frequency + time_offset + phase_offset
	);

	// Secondary sway: faster turbulent detail
	float turbulence = noise(world_pos.xz * 2.0 + time_offset * 1.5) * 2.0 - 1.0;
	float detail_sway = sin(time_offset * 2.7 + world_pos.x * 3.0 + phase_offset) * 0.3;

	// Combined displacement
	float total_sway = primary_sway + turbulence * wind_turbulence + detail_sway;
	total_sway *= wind_strength * sway_mask;

	// Apply displacement in wind direction (XZ) and a slight Y bounce
	VERTEX.x += total_sway * wind_dir.x;
	VERTEX.z += total_sway * wind_dir.y;
	VERTEX.y += abs(total_sway) * -0.05; // slight droop when pushed sideways
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 base = albedo_color.rgb * tex.rgb;

	// Color variation: blend toward tip color based on height and noise
	float variation_noise = noise(world_pos.xz * color_variation_scale);
	float blend_factor = mix(height_factor, variation_noise, 0.5) * color_variation_amount;
	base = mix(base, tip_color.rgb, blend_factor);

	ALBEDO = base;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;

	// Alpha cutoff for leaf billboards / grass cards
	float alpha = albedo_color.a * tex.a;
	if (alpha < alpha_scissor) {
		discard;
	}

	// Backface lighting (subsurface approximation handled in light())
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float wrapped = (ndotl + 1.0) * 0.5;

	// 3-band toon stepping
	float stepped = floor(wrapped * 3.0) / 3.0;
	float blend = smoothstep(stepped - 0.04, stepped + 0.04, wrapped);
	float next_step = ceil(wrapped * 3.0) / 3.0;
	float intensity = mix(stepped, next_step, blend);
	intensity = mix(0.45, 1.0, intensity);

	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * intensity;

	// Subsurface scattering: light passing through foliage from behind
	float back_light = max(dot(-NORMAL, LIGHT), 0.0);
	float subsurface = pow(back_light, 2.0) * subsurface_strength;
	DIFFUSE_LIGHT += subsurface_color.rgb * LIGHT_COLOR * ATTENUATION * subsurface;
}
