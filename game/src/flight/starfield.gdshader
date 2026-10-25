shader_type canvas_item;
// A procedural starfield (PLAN.md Phase 3.5): three layers of hashed stars, each scrolling at
// its own fraction of the camera's movement for parallax, drawn in screen space behind the
// world. No textures, so it costs nothing to load and never shows a seam.

uniform vec2 camera_position = vec2(0.0);   // world pixels
uniform float camera_zoom = 1.0;
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform vec4 background : source_color = vec4(0.01, 0.015, 0.035, 1.0);
uniform float time_scale = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// One layer: a grid of cells, at most one star per cell, at a random spot within it.
vec3 layer(vec2 world, float cell, float density, float star_size, vec3 tint, float t) {
	vec2 grid = world / cell;
	vec2 id = floor(grid);
	vec2 local = fract(grid) - 0.5;
	float present = step(1.0 - density, hash(id));
	vec2 offset = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
	float d = length(local - offset * 0.8) * cell;
	float twinkle = 0.75 + 0.25 * sin(t * (1.0 + hash(id + 1.3) * 3.0) + hash(id) * 6.28);
	float glow = smoothstep(star_size, 0.0, d) * present * twinkle;
	return tint * glow * (0.5 + hash(id + 9.9));
}

void fragment() {
	vec2 screen = (SCREEN_UV - 0.5) * screen_size / camera_zoom;
	float t = TIME * time_scale;
	vec3 color = background.rgb;
	// Far, middle, near: scrolling at 10%, 30% and 60% of the camera.
	color += layer(screen + camera_position * 0.1, 90.0, 0.35, 2.0, vec3(0.55, 0.6, 0.8), t) * 0.9;
	color += layer(screen + camera_position * 0.3, 160.0, 0.25, 3.0, vec3(0.8, 0.85, 1.0), t);
	color += layer(screen + camera_position * 0.6, 260.0, 0.18, 4.2, vec3(1.0, 0.95, 0.85), t);
	COLOR = vec4(color, 1.0);
}
