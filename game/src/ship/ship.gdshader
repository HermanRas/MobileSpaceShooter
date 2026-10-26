// The ship shader (PLAN.md 6.2). One mesh per ship; every tile is a triangle fan.
//
// Per-vertex data, packed into the two channels a 2D mesh has:
//   COLOR.rgb  paint colour
//   COLOR.a    distance to this triangle's outer edge, in U (0 on the edge)
//   UV.x       atlas column * PACK + LOCAL_OFFSET + x
//   UV.y       (wear step * variants + variant) * PACK + LOCAL_OFFSET + y
// x, y are ship-local in U, so one seamless material covers every shape and size; for the core
// they're tile-local instead (-0.5..0.5 across the tile's box), so its design is drawn once.
// LOCAL_OFFSET keeps the packed value positive, so floor() recovers the right cell for tiles
// left of the origin. PACK and LOCAL_OFFSET match ShipMesh.
//
// The atlas (tools/slice_sheets.py) has a column per tile type and a row per variant, each cell
// padded by 1/18 of its stride so mipmaps never read a neighbour. `damage` is a row of overlays,
// one per wear step, multiplied over the tile (white = untouched).
shader_type canvas_item;

const float PACK = 100.0;
const float LOCAL_OFFSET = 50.5;
const float WEAR_STEPS = 4.0;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D damage : filter_linear_mipmap, repeat_disable;
uniform float columns = 6.0;
uniform float variants = 3.0;
uniform float pad_frac = 0.0555556;
uniform float core_column = 0.0;
uniform float u_per_repeat = 1.0;
uniform float outline_u = 0.03;
uniform float bevel_u = 0.09;
uniform vec3 trim_color : source_color = vec3(0.75, 0.95, 1.0);
uniform vec3 outline_color : source_color = vec3(0.04, 0.04, 0.06);
// 0 = normal; the hangar ghost uses a tint and transparency.
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float opacity = 1.0;
uniform vec3 ember_color : source_color = vec3(1.0, 0.4, 0.08);

// A cell's texel for `t` (0..1 inside the cell), with the gradient of the unwrapped coordinate,
// so the mip level doesn't jump where fract() wraps.
vec4 cell_texel(sampler2D tex, vec2 cell, vec2 grid, vec2 t, vec2 dx, vec2 dy) {
	float inner = 1.0 - 2.0 * pad_frac;
	vec2 uv = (cell + pad_frac + t * inner) / grid;
	return textureGrad(tex, uv, dx * inner / grid, dy * inner / grid);
}

void fragment() {
	float column = floor(UV.x / PACK);
	float code = floor(UV.y / PACK);
	float wear_step = floor(code / variants + 0.001);
	float variant = code - wear_step * variants;
	vec2 local = vec2(UV.x - column * PACK, UV.y - code * PACK) - vec2(LOCAL_OFFSET - 0.5);
	bool core = abs(column - core_column) < 0.5;
	vec2 at = core ? local : local / u_per_repeat;
	vec2 t = core ? clamp(at, 0.0, 1.0) : fract(at);
	vec2 dx = dFdx(at);
	vec2 dy = dFdy(at);
	vec4 s = cell_texel(atlas, vec2(column, variant), vec2(columns, variants), t, dx, dy);

	vec3 col = COLOR.rgb * (0.45 + 0.75 * s.r);
	col = mix(col, trim_color * (0.6 + 0.4 * s.r), s.g);

	float d = COLOR.a;
	col *= mix(1.3, 1.0, smoothstep(0.0, bevel_u, d));
	col = mix(outline_color, col, smoothstep(outline_u * 0.6, outline_u, d));
	if (wear_step > 0.0) {
		// Damage: the painted overlay for this step, shifted per variant so neighbours differ,
		// and near the end the deepest marks smoulder.
		float wear = wear_step / WEAR_STEPS;
		vec2 dt = fract(t + variant * vec2(0.37, 0.61));
		float mark = cell_texel(damage, vec2(wear_step - 1.0, 0.0), vec2(WEAR_STEPS, 1.0), dt, dx, dy).r;
		col *= (1.0 - 0.12 * wear) * mix(1.0, mark, 0.95);
		col += ember_color * smoothstep(0.3, 0.08, mark) * smoothstep(0.5, 1.0, wear) * 0.6;
	}
	col = mix(col, tint.rgb, tint.a);
	COLOR = vec4(col, opacity);
}
