shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 32.0, 0.1) = 4.0;
uniform bool dithering_enabled = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.5;
uniform int color_levels : hint_range(2, 32) = 8;
uniform int dither_matrix_size : hint_range(0, 2) = 1;
uniform bool grayscale = false;
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

float bayer2(vec2 p) {
	float m[4] = float[4](0.0, 2.0, 3.0, 1.0);
	int x = int(mod(p.x, 2.0));
	int y = int(mod(p.y, 2.0));
	return m[y * 2 + x] / 4.0 - 0.5;
}

float bayer4(vec2 p) {
	float m[16] = float[16](
		 0.0, 8.0,  2.0, 10.0,
		12.0, 4.0, 14.0,  6.0,
		 3.0, 11.0, 1.0,  9.0,
		15.0, 7.0, 13.0,  5.0
	);
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return m[y * 4 + x] / 16.0 - 0.5;
}

float bayer8(vec2 p) {
	float m[64] = float[64](
		 0.0, 32.0,  8.0, 40.0,  2.0, 34.0, 10.0, 42.0,
		48.0, 16.0, 56.0, 24.0, 50.0, 18.0, 58.0, 26.0,
		12.0, 44.0,  4.0, 36.0, 14.0, 46.0,  6.0, 38.0,
		60.0, 28.0, 52.0, 20.0, 62.0, 30.0, 54.0, 22.0,
		 3.0, 35.0, 11.0, 43.0,  1.0, 33.0,  9.0, 41.0,
		51.0, 19.0, 59.0, 27.0, 49.0, 17.0, 57.0, 25.0,
		15.0, 47.0,  7.0, 39.0, 13.0, 45.0,  5.0, 37.0,
		63.0, 31.0, 55.0, 23.0, 61.0, 29.0, 53.0, 21.0
	);
	int x = int(mod(p.x, 8.0));
	int y = int(mod(p.y, 8.0));
	return m[y * 8 + x] / 64.0 - 0.5;
}

float get_dither_value(vec2 pixel_coord) {
	if (dither_matrix_size == 0) {
		return bayer2(pixel_coord);
	} else if (dither_matrix_size == 1) {
		return bayer4(pixel_coord);
	} else {
		return bayer8(pixel_coord);
	}
}

void fragment() {
	vec2 screen_res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 pixelated_uv = floor(SCREEN_UV * screen_res / pixel_size) * pixel_size / screen_res;
	pixelated_uv += (pixel_size * 0.5) / screen_res;

	vec4 col = texture(screen_texture, pixelated_uv);
	vec3 color = col.rgb;

	color = (color - 0.5) * contrast + 0.5 + brightness;
	color = clamp(color, 0.0, 1.0);

	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, saturation);

	if (grayscale) {
		color = vec3(luma);
	}

	if (dithering_enabled) {
		vec2 dither_coord = floor(SCREEN_UV * screen_res / pixel_size);
		float dither_val = get_dither_value(dither_coord);
		float lvl = float(color_levels - 1);
		color += dither_strength * dither_val / lvl;
		color = clamp(color, 0.0, 1.0);
	}

	float levels = float(color_levels - 1);
	color = floor(color * levels + 0.5) / levels;

	COLOR = vec4(color, 1.0);
}