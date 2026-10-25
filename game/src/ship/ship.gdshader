// The ship shader (PLAN.md 6.2). One mesh per ship; every tile is a triangle fan.
//
// Per-vertex data, packed into the two channels a 2D mesh has:
//   COLOR.rgb  paint colour
//   COLOR.a    distance to this triangle's outer edge, in U (0 on the edge)
//   UV.x       atlas cell * 1000 + LOCAL_OFFSET + ship-local x in U
//   UV.y       wear step * 1000 + LOCAL_OFFSET + ship-local y in U (wear 0..WEAR_STEPS, 4.2)
// LOCAL_OFFSET keeps the packed value positive, so floor() recovers the right cell for tiles
// left of the origin. It matches ShipMesh.LOCAL_OFFSET.
// The material is sampled in ship space, so one seamless texture covers every shape and size.
shader_type canvas_item;

const float LOCAL_OFFSET = 100.5;
const float WEAR_STEPS = 4.0;

uniform sampler2D atlas : filter_linear, repeat_disable;
uniform float cells = 5.0;
uniform float u_per_repeat = 1.0;
uniform float outline_u = 0.03;
uniform float bevel_u = 0.09;
uniform vec3 trim_color : source_color = vec3(0.75, 0.95, 1.0);
uniform vec3 outline_color : source_color = vec3(0.04, 0.04, 0.06);
// 0 = normal; the hangar ghost uses a tint and transparency.
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float opacity = 1.0;
uniform vec3 scorch_color : source_color = vec3(0.08, 0.05, 0.04);
uniform vec3 ember_color : source_color = vec3(1.0, 0.4, 0.08);

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Distance to the nearest Voronoi border (F2 - F1), and a random value for the nearest cell.
vec2 cracks(vec2 p) {
	vec2 cell = floor(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			vec2 h = hash2(c);
			float d = length(c + h - p);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				id = h.x;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec2(f2 - f1, id);
}

void fragment() {
	float cell = floor(UV.x / 1000.0);
	float wear_step = floor(UV.y / 1000.0);
	// Keep the half-repeat shift (only the whole part was added to stay positive).
	vec2 local = vec2(UV.x - cell * 1000.0, UV.y - wear_step * 1000.0) - vec2(LOCAL_OFFSET - 0.5);
	// Inset slightly so linear filtering never reads the neighbouring cell.
	vec2 t = mix(vec2(0.004), vec2(0.996), fract(local / u_per_repeat));
	vec4 s = texture(atlas, vec2((cell + t.x) / cells, t.y));

	vec3 col = COLOR.rgb * (0.45 + 0.75 * s.r);
	col = mix(col, trim_color * (0.6 + 0.4 * s.r), s.g);

	float d = COLOR.a;
	col *= mix(1.3, 1.0, smoothstep(0.0, bevel_u, d));
	col = mix(outline_color, col, smoothstep(outline_u * 0.6, outline_u, d));
	if (wear_step > 0.0) {
		// Damage: blotchy scorching, then cracks that spread and, near the end, glow.
		float wear = wear_step / WEAR_STEPS;
		vec2 blot = cracks(local * 1.7 + 13.0);
		col *= 1.0 - wear * (0.25 + 0.35 * blot.y);
		vec2 crack = cracks(local * 2.6);
		float shown = step(crack.y, wear * 1.1);  // more of the network appears as wear grows
		float line = 1.0 - smoothstep(0.015 + 0.03 * wear, 0.03 + 0.05 * wear, crack.x);
		col = mix(col, scorch_color, line * shown * 0.9);
		col += ember_color * line * shown * smoothstep(0.5, 1.0, wear) * 0.7;
	}
	col = mix(col, tint.rgb, tint.a);
	COLOR = vec4(col, opacity);
}
