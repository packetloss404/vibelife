shader_type spatial;

render_mode diffuse_toon, specular_toon;

// Terrain texture layers
uniform sampler2D tex_grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_sand : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_stone : source_color, filter_linear_mipmap, repeat_enable;

// Normal maps for each layer
uniform sampler2D normal_grass : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_dirt : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_sand : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_stone : hint_normal, filter_linear_mipmap, repeat_enable;

// Splatmap (R=grass, G=dirt, B=sand, A=stone)
uniform sampler2D splatmap : filter_linear_mipmap;

// Procedural splatmap fallback colors (used when no textures are assigned)
uniform vec4 color_grass : source_color = vec4(0.32, 0.55, 0.28, 1.0);
uniform vec4 color_dirt : source_color = vec4(0.45, 0.33, 0.2, 1.0);
uniform vec4 color_sand : source_color = vec4(0.76, 0.7, 0.5, 1.0);
uniform vec4 color_stone : source_color = vec4(0.5, 0.48, 0.45, 1.0);

// Terrain parameters
uniform float texture_scale : hint_range(0.1, 20.0) = 8.0;
uniform float terrain_size : hint_range(1.0, 200.0) = 60.0;
uniform float height_scale : hint_range(0.0, 5.0) = 0.8;
uniform float triplanar_sharpness : hint_range(1.0, 16.0) = 4.0;
uniform float slope_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float detail_fade_start : hint_range(5.0, 80.0) = 20.0;
uniform float detail_fade_end : hint_range(10.0, 120.0) = 50.0;

// Noise for height displacement and procedural splatmap
uniform float noise_frequency : hint_range(0.01, 0.5) = 0.08;
uniform float noise_frequency2 : hint_range(0.01, 1.0) = 0.2;

// Warm tint for lo-fi aesthetic consistency
uniform vec4 warm_tint : source_color = vec4(1.04, 0.98, 0.93, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;
varying vec3 world_normal_v;
varying float vert_height;

// Simple hash-based noise functions (no texture dependency)
float hash2d(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep

	float a = hash2d(i);
	float b = hash2d(i + vec2(1.0, 0.0));
	float c = hash2d(i + vec2(0.0, 1.0));
	float d = hash2d(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (int i = 0; i < octaves; i++) {
		value += amplitude * value_noise(p * frequency);
		amplitude *= 0.5;
		frequency *= 2.0;
	}
	return value;
}

float get_height(vec2 pos) {
	float h = fbm(pos * noise_frequency, 4) * height_scale;
	// Add smaller detail bumps
	h += fbm(pos * noise_frequency2, 3) * height_scale * 0.3;
	// Flatten near center (spawn area)
	float center_dist = length(pos) / (terrain_size * 0.5);
	float flatten = smoothstep(0.0, 0.4, center_dist);
	return h * flatten;
}

void vertex() {
	// Compute world position for noise sampling
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Apply height displacement
	float h = get_height(wp.xz);
	VERTEX.y += h;

	// Recalculate normal from height field via finite differences
	float eps = 0.5;
	float hL = get_height(wp.xz + vec2(-eps, 0.0));
	float hR = get_height(wp.xz + vec2(eps, 0.0));
	float hD = get_height(wp.xz + vec2(0.0, -eps));
	float hU = get_height(wp.xz + vec2(0.0, eps));
	vec3 computed_normal = normalize(vec3(hL - hR, 2.0 * eps, hD - hU));
	NORMAL = computed_normal;

	// Pass to fragment
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal_v = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vert_height = h;
}

vec4 triplanar_texture(sampler2D tex, vec3 pos, vec3 normal, float scale) {
	vec3 blend_weights = pow(abs(normal), vec3(triplanar_sharpness));
	blend_weights /= (blend_weights.x + blend_weights.y + blend_weights.z);

	vec4 x_proj = texture(tex, pos.yz * scale);
	vec4 y_proj = texture(tex, pos.xz * scale);
	vec4 z_proj = texture(tex, pos.xy * scale);

	return x_proj * blend_weights.x + y_proj * blend_weights.y + z_proj * blend_weights.z;
}

void fragment() {
	vec2 uv_world = world_pos.xz / terrain_size + 0.5;
	vec2 uv_tex = world_pos.xz / texture_scale;
	vec3 n = normalize(world_normal_v);

	// Determine slope factor (0 = flat, 1 = vertical)
	float slope = 1.0 - abs(n.y);
	float use_triplanar = smoothstep(slope_threshold - 0.1, slope_threshold + 0.1, slope);

	// Distance-based detail fade
	float cam_dist = length(world_pos - CAMERA_POSITION_WORLD);
	float detail_factor = 1.0 - smoothstep(detail_fade_start, detail_fade_end, cam_dist);

	// Procedural splatmap based on height and noise
	float splat_noise = fbm(world_pos.xz * 0.05, 3);
	float height_norm = clamp(vert_height / max(height_scale, 0.01), 0.0, 1.0);

	// Blend weights: grass on flats, dirt on mid slopes, sand low areas, stone on steep/high
	float w_grass = smoothstep(0.1, 0.4, 1.0 - slope) * smoothstep(0.0, 0.3, splat_noise + 0.3);
	float w_dirt = smoothstep(0.2, 0.5, slope) * (1.0 - smoothstep(0.6, 0.9, slope));
	w_dirt += splat_noise * 0.3;
	float w_sand = smoothstep(0.3, 0.0, height_norm) * smoothstep(0.3, 0.0, slope);
	w_sand *= smoothstep(0.4, 0.6, splat_noise);
	float w_stone = smoothstep(0.5, 0.8, slope) + smoothstep(0.6, 0.9, height_norm) * 0.5;

	// Try to read splatmap texture; add to procedural weights
	vec4 splat = texture(splatmap, uv_world);
	if (splat.r + splat.g + splat.b + splat.a > 0.01) {
		w_grass += splat.r;
		w_dirt += splat.g;
		w_sand += splat.b;
		w_stone += splat.a;
	}

	// Normalize weights
	float w_total = w_grass + w_dirt + w_sand + w_stone;
	w_total = max(w_total, 0.001);
	w_grass /= w_total;
	w_dirt /= w_total;
	w_sand /= w_total;
	w_stone /= w_total;

	// Sample textures (planar for flat, triplanar for slopes)
	vec4 c_grass_p = texture(tex_grass, uv_tex);
	vec4 c_dirt_p = texture(tex_dirt, uv_tex);
	vec4 c_sand_p = texture(tex_sand, uv_tex);
	vec4 c_stone_p = texture(tex_stone, uv_tex);

	vec4 c_grass_t = triplanar_texture(tex_grass, world_pos, n, 1.0 / texture_scale);
	vec4 c_dirt_t = triplanar_texture(tex_dirt, world_pos, n, 1.0 / texture_scale);
	vec4 c_sand_t = triplanar_texture(tex_sand, world_pos, n, 1.0 / texture_scale);
	vec4 c_stone_t = triplanar_texture(tex_stone, world_pos, n, 1.0 / texture_scale);

	vec4 c_grass_tex = mix(c_grass_p, c_grass_t, use_triplanar);
	vec4 c_dirt_tex = mix(c_dirt_p, c_dirt_t, use_triplanar);
	vec4 c_sand_tex = mix(c_sand_p, c_sand_t, use_triplanar);
	vec4 c_stone_tex = mix(c_stone_p, c_stone_t, use_triplanar);

	// If textures appear blank (all near-white from default), use procedural colors
	float tex_validity = length(c_grass_tex.rgb - vec3(1.0));
	vec3 grass_final = mix(color_grass.rgb, c_grass_tex.rgb, step(0.05, tex_validity)) ;
	vec3 dirt_final = mix(color_dirt.rgb, c_dirt_tex.rgb, step(0.05, length(c_dirt_tex.rgb - vec3(1.0))));
	vec3 sand_final = mix(color_sand.rgb, c_sand_tex.rgb, step(0.05, length(c_sand_tex.rgb - vec3(1.0))));
	vec3 stone_final = mix(color_stone.rgb, c_stone_tex.rgb, step(0.05, length(c_stone_tex.rgb - vec3(1.0))));

	// Blend layers
	vec3 terrain_color = grass_final * w_grass
		+ dirt_final * w_dirt
		+ sand_final * w_sand
		+ stone_final * w_stone;

	// Mix detail toward a simplified color at distance
	vec3 far_color = terrain_color;
	terrain_color = mix(far_color, terrain_color, detail_factor);

	// Normal map blending
	vec3 n_grass_s = texture(normal_grass, uv_tex).rgb * 2.0 - 1.0;
	vec3 n_dirt_s = texture(normal_dirt, uv_tex).rgb * 2.0 - 1.0;
	vec3 n_sand_s = texture(normal_sand, uv_tex).rgb * 2.0 - 1.0;
	vec3 n_stone_s = texture(normal_stone, uv_tex).rgb * 2.0 - 1.0;

	vec3 blended_normal = normalize(
		n_grass_s * w_grass +
		n_dirt_s * w_dirt +
		n_sand_s * w_sand +
		n_stone_s * w_stone
	);

	// Fade normal detail with distance
	blended_normal = mix(vec3(0.0, 0.0, 1.0), blended_normal, detail_factor);

	// Apply warm tint
	terrain_color = mix(terrain_color, terrain_color * warm_tint.rgb, tint_strength);

	ALBEDO = terrain_color;
	NORMAL_MAP = blended_normal * 0.5 + 0.5;
	ROUGHNESS = mix(0.92, 0.75, w_stone);
	SPECULAR = 0.15;
}
