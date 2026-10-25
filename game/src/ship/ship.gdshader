// The ship shader (PLAN.md 6.2). One mesh per ship; every tile is a triangle fan.
//
// Per-vertex data, packed into the two channels a 2D mesh has:
//   COLOR.rgb  paint colour
//   COLOR.a    distance to this triangle's outer edge, in U (0 on the edge)
//   UV.x       atlas cell * 1000 + LOCAL_OFFSET + ship-local x in U
//   UV.y       LOCAL_OFFSET + ship-local y in U
// LOCAL_OFFSET keeps the packed value positive, so floor() recovers the right cell for tiles
// left of the origin. It matches ShipMesh.LOCAL_OFFSET.
// The material is sampled in ship space, so one seamless texture covers every shape and size.
shader_type canvas_item;

const float LOCAL_OFFSET = 100.5;

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

void fragment() {
	float cell = floor(UV.x / 1000.0);
	// Keep the half-repeat shift (only the whole part was added to stay positive).
	vec2 local = vec2(UV.x - cell * 1000.0, UV.y) - vec2(LOCAL_OFFSET - 0.5);
	// Inset slightly so linear filtering never reads the neighbouring cell.
	vec2 t = mix(vec2(0.004), vec2(0.996), fract(local / u_per_repeat));
	vec4 s = texture(atlas, vec2((cell + t.x) / cells, t.y));

	vec3 col = COLOR.rgb * (0.45 + 0.75 * s.r);
	col = mix(col, trim_color * (0.6 + 0.4 * s.r), s.g);

	float d = COLOR.a;
	col *= mix(1.3, 1.0, smoothstep(0.0, bevel_u, d));
	col = mix(outline_color, col, smoothstep(outline_u * 0.6, outline_u, d));
	col = mix(col, tint.rgb, tint.a);
	COLOR = vec4(col, opacity);
}
