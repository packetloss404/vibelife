shader_type sky;

// Time of day: 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset, 1.0 = midnight
uniform float time_of_day : hint_range(0.0, 1.0) = 0.35;

// Sun / moon
uniform vec3 sun_direction = vec3(0.0, 0.5, -1.0);
uniform float sun_size : hint_range(0.001, 0.1) = 0.02;
uniform float sun_intensity : hint_range(0.0, 10.0) = 5.0;
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float moon_size : hint_range(0.001, 0.1) = 0.015;
uniform vec4 moon_color : source_color = vec4(0.75, 0.82, 0.92, 1.0);

// Atmosphere
uniform vec4 day_zenith_color : source_color = vec4(0.25, 0.5, 0.85, 1.0);
uniform vec4 day_horizon_color : source_color = vec4(0.55, 0.75, 0.95, 1.0);
uniform vec4 sunset_color : source_color = vec4(0.95, 0.5, 0.2, 1.0);
uniform vec4 night_zenith_color : source_color = vec4(0.02, 0.02, 0.06, 1.0);
uniform vec4 night_horizon_color : source_color = vec4(0.05, 0.06, 0.12, 1.0);
uniform float rayleigh_strength : hint_range(0.0, 2.0) = 1.0;

// Clouds
uniform float cloud_speed : hint_range(0.0, 0.5) = 0.02;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_height : hint_range(0.0, 0.5) = 0.15;
uniform vec4 cloud_color_day : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_color_sunset : source_color = vec4(1.0, 0.7, 0.45, 1.0);
uniform vec4 cloud_color_night : source_color = vec4(0.12, 0.13, 0.18, 1.0);

// Stars
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;
uniform float star_density : hint_range(0.0, 1.0) = 0.5;

// Lo-fi warm tint
uniform vec4 warm_tint : source_color = vec4(1.04, 0.98, 0.93, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.2;

// ── Noise helpers ───────────────────────────────────────────────────────────

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm_cloud(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * value_noise(p);
		p = rot * p * 2.0;
		a *= 0.5;
	}
	return v;
}

// ── Sun direction from time ─────────────────────────────────────────────────

vec3 compute_sun_dir(float t) {
	// Sun follows an arc: rises at t=0.25, sets at t=0.75
	float angle = (t - 0.25) * TAU; // full rotation
	return normalize(vec3(sin(angle) * 0.3, -cos(angle), sin(angle) * 0.8));
}

// ── Star field ──────────────────────────────────────────────────────────────

float star_field(vec3 dir) {
	// Grid-based star placement
	vec3 cell = floor(dir * 80.0);
	float r = hash3(cell);

	// Only show some cells as stars based on density
	float threshold = 1.0 - star_density * 0.08;
	float star = step(threshold, r);

	// Twinkle effect
	float twinkle = sin(r * 100.0 + TIME * (r * 2.0 + 0.5)) * 0.5 + 0.5;
	star *= 0.6 + twinkle * 0.4;

	// Vary brightness
	star *= smoothstep(threshold, threshold + 0.005, r);

	return star;
}

// ── Main sky ────────────────────────────────────────────────────────────────

void sky() {
	vec3 dir = normalize(EYEDIR);
	float t = time_of_day;

	// Compute sun position from time of day
	vec3 sun_dir = compute_sun_dir(t);
	vec3 moon_dir = -sun_dir; // opposite side

	// How far sun is above horizon (positive = daytime)
	float sun_altitude = sun_dir.y;
	float day_factor = smoothstep(-0.15, 0.2, sun_altitude);

	// Sunset/sunrise factor - peaks when sun is near horizon
	float sunset_factor = smoothstep(0.2, 0.0, abs(sun_altitude)) * smoothstep(-0.15, 0.0, sun_altitude);

	// ── Rayleigh scattering approximation ───────────────────────────────

	float horizon_factor = 1.0 - max(dir.y, 0.0);
	horizon_factor = pow(horizon_factor, 1.5);

	// Scattering increases near the sun, especially at sunset
	float sun_dot = max(dot(dir, sun_dir), 0.0);
	float scatter = pow(sun_dot, 3.0) * rayleigh_strength;

	// ── Sky gradient ────────────────────────────────────────────────────

	// Interpolate zenith and horizon based on time
	vec3 zenith = mix(night_zenith_color.rgb, day_zenith_color.rgb, day_factor);
	vec3 horizon = mix(night_horizon_color.rgb, day_horizon_color.rgb, day_factor);

	// Base sky from zenith to horizon
	vec3 sky_col = mix(zenith, horizon, horizon_factor);

	// Add sunset color
	vec3 sunset_blend = sunset_color.rgb * sunset_factor * (horizon_factor * 0.7 + scatter * 0.5);
	sky_col += sunset_blend;

	// Rayleigh scatter tint near sun
	sky_col += sun_color.rgb * scatter * 0.15 * day_factor;

	// ── Sun disc ────────────────────────────────────────────────────────

	float sun_angular = acos(clamp(dot(dir, sun_dir), -1.0, 1.0));
	float sun_disc = smoothstep(sun_size, sun_size * 0.5, sun_angular);
	float sun_glow = smoothstep(sun_size * 8.0, sun_size, sun_angular) * 0.3;

	vec3 sun_contrib = sun_color.rgb * sun_intensity * (sun_disc + sun_glow) * day_factor;
	sky_col += sun_contrib;

	// ── Moon disc ───────────────────────────────────────────────────────

	float moon_angular = acos(clamp(dot(dir, moon_dir), -1.0, 1.0));
	float moon_disc = smoothstep(moon_size, moon_size * 0.4, moon_angular);
	float moon_glow = smoothstep(moon_size * 6.0, moon_size, moon_angular) * 0.15;

	float night_factor = 1.0 - day_factor;
	vec3 moon_contrib = moon_color.rgb * (moon_disc * 1.5 + moon_glow) * night_factor;
	sky_col += moon_contrib;

	// ── Stars ───────────────────────────────────────────────────────────

	float stars = star_field(dir) * star_brightness;
	// Only visible at night, fade out near horizon
	float star_vis = night_factor * smoothstep(0.0, 0.15, dir.y);
	// Fade stars near moon
	star_vis *= smoothstep(moon_size * 4.0, moon_size * 12.0, moon_angular);
	sky_col += vec3(stars) * star_vis;

	// ── Cloud layer ─────────────────────────────────────────────────────

	if (dir.y > 0.01) {
		// Project ray onto cloud plane
		float cloud_t = cloud_height / max(dir.y, 0.01);
		vec2 cloud_uv = dir.xz * cloud_t;

		// Animate
		cloud_uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.3);

		// Multi-octave noise
		float noise_val = fbm_cloud(cloud_uv * 2.5);

		// Shape clouds with coverage threshold
		float cloud_shape = smoothstep(cloud_coverage, cloud_coverage + 0.3, noise_val);
		cloud_shape *= cloud_density;

		// Fade clouds near horizon to avoid hard cutoff
		float cloud_horizon_fade = smoothstep(0.01, 0.15, dir.y);
		cloud_shape *= cloud_horizon_fade;

		// Cloud color based on time of day
		vec3 c_color = mix(cloud_color_night.rgb, cloud_color_day.rgb, day_factor);
		c_color = mix(c_color, cloud_color_sunset.rgb, sunset_factor * 0.7);

		// Simple cloud lighting - brighter side facing sun
		float cloud_light = max(dot(normalize(vec3(dir.x, 0.0, dir.z)), sun_dir), 0.0) * 0.3 + 0.7;
		c_color *= cloud_light;

		sky_col = mix(sky_col, c_color, cloud_shape);
	}

	// ── Ground fog / below-horizon ──────────────────────────────────────

	if (dir.y < 0.0) {
		vec3 ground_col = mix(horizon, night_horizon_color.rgb * 0.5, night_factor);
		float below = smoothstep(0.0, -0.3, dir.y);
		sky_col = mix(sky_col, ground_col, below);
	}

	// ── Lo-fi warm tint ─────────────────────────────────────────────────

	sky_col = mix(sky_col, sky_col * warm_tint.rgb, tint_strength);

	COLOR = sky_col;
}
