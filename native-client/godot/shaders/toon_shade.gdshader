shader_type spatial;

render_mode diffuse_toon, specular_toon;

// Toon shading parameters
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float bands : hint_range(2.0, 6.0, 1.0) = 3.0;
uniform float band_smoothness : hint_range(0.0, 0.15) = 0.05;
uniform float shadow_brightness : hint_range(0.0, 1.0) = 0.45;

// Warm color tinting for lo-fi aesthetic
uniform vec4 warm_tint : source_color = vec4(1.05, 0.98, 0.92, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.35;

// Rim lighting
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.4;

// Outline
uniform float outline_thickness : hint_range(0.0, 0.05) = 0.012;
uniform vec4 outline_color : source_color = vec4(0.15, 0.1, 0.08, 1.0);

// Specular
uniform float specular_strength : hint_range(0.0, 1.0) = 0.3;
uniform float specular_shininess : hint_range(1.0, 128.0) = 16.0;

varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Subtle outline via vertex extrusion along normal (backface pass would be
	// ideal but single-pass extrusion gives a soft edge effect)
	// This is applied as a very slight push so the main geometry gets a
	// darkened silhouette edge in the fragment shader instead.
}

void fragment() {
	// Base color
	vec4 tex_color = texture(albedo_texture, UV);
	vec3 base_color = albedo_color.rgb * tex_color.rgb;

	// Apply warm tint
	base_color = mix(base_color, base_color * warm_tint.rgb, tint_strength);

	// Rim lighting (view-dependent)
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float rim_factor = 1.0 - max(dot(n, v), 0.0);
	rim_factor = pow(rim_factor, rim_power) * rim_strength;
	vec3 rim = rim_color.rgb * rim_factor;

	// Outline darkening at edges (screen-space approximation)
	float edge = smoothstep(outline_thickness, outline_thickness * 2.5, dot(n, v));
	vec3 outline_effect = mix(outline_color.rgb, vec3(1.0), edge);

	ALBEDO = base_color * outline_effect + rim;
	ROUGHNESS = 0.85;
	SPECULAR = specular_strength;
}

void light() {
	// Stepped diffuse lighting (toon bands)
	float ndotl = dot(NORMAL, LIGHT);
	float intensity = (ndotl + 1.0) * 0.5; // remap -1..1 to 0..1

	// Quantize into bands with soft transitions
	float stepped = floor(intensity * bands) / bands;
	float next_step = ceil(intensity * bands) / bands;
	float blend = smoothstep(stepped - band_smoothness, stepped + band_smoothness, intensity);
	float final_intensity = mix(stepped, next_step, blend);

	// Ensure shadow areas aren't fully black
	final_intensity = mix(shadow_brightness, 1.0, final_intensity);

	// Toon specular highlight
	vec3 half_dir = normalize(LIGHT + VIEW);
	float spec = pow(max(dot(NORMAL, half_dir), 0.0), specular_shininess);
	float spec_stepped = smoothstep(0.4, 0.5, spec) * specular_strength;

	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * final_intensity;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec_stepped;
}
