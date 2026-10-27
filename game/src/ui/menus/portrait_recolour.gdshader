shader_type canvas_item;
// Repaints a player portrait's key-hue regions in the player's colours (PLAN.md 6.5, A.7). The
// mask (R hair, G eyes, B outfit, A trim, cut by tools/slice_sheets.py) says where each region
// is; there the hue becomes the chosen colour's, and the painted shading is kept by scaling the
// colour's value by the pixel's value over the region's mean (`ref_v`, from the slicer). The
// saturation follows the paint, so a pale highlight stays pale.

uniform sampler2D mask : filter_linear;
uniform vec4 hair = vec4(0.35, 0.23, 0.13, 1.0);
uniform vec4 eyes = vec4(0.23, 0.44, 0.69, 1.0);
uniform vec4 outfit = vec4(0.18, 0.31, 0.5, 1.0);
uniform vec4 trim = vec4(1.0, 0.82, 0.48, 1.0);
uniform vec4 ref_v = vec4(0.55);

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-6)), d / (q.x + 1e-6), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// The key colours are painted fully saturated; a pixel at this saturation or above takes
// the target's whole saturation.
const float KEY_SAT = 0.85;

vec3 repaint(vec3 paint, vec4 target, float ref) {
	vec3 t = rgb2hsv(target.rgb);
	float v = clamp(t.z * paint.z / max(ref, 0.05), 0.0, 1.0);
	float s = t.y * clamp(paint.y / KEY_SAT, 0.0, 1.0);
	return hsv2rgb(vec3(t.x, s, v));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 m = texture(mask, UV);
	vec3 paint = rgb2hsv(c.rgb);
	vec3 rgb = mix(c.rgb, repaint(paint, hair, ref_v.x), m.r);
	rgb = mix(rgb, repaint(paint, eyes, ref_v.y), m.g);
	rgb = mix(rgb, repaint(paint, outfit, ref_v.z), m.b);
	rgb = mix(rgb, repaint(paint, trim, ref_v.w), m.a);
	COLOR = vec4(rgb, c.a);
}
