shader_type spatial;
// 湿地面：淋湿变暗 + 积水(噪声遮罩)镜面反射(配合环境 SSR) + 动态涟漪。
// 配 wetness 0..1 随暴雨淡入淡出。只作用于朝上面（地面/平台），墙保持原样。

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.0078;
uniform float wetness : hint_range(0.0, 1.0) = 1.0;
uniform float puddle_scale = 0.0016;
uniform vec3 base_tint = vec3(1.7, 1.55, 1.2);

varying vec3 w_pos;
varying vec3 w_nrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float a = 0.0;
	float amp = 0.5;
	for (int k = 0; k < 4; k++) {
		a += amp * vnoise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return a;
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = w_pos.xz * uv_scale;
	vec3 base = texture(albedo_tex, uv).rgb * base_tint;

	float up = clamp(w_nrm.y, 0.0, 1.0);
	float up_hard = smoothstep(0.6, 0.85, w_nrm.y);

	// 积水遮罩：世界 XZ 上的 fbm 噪声，只在朝上面
	float n = fbm(w_pos.xz * puddle_scale);
	float puddle = smoothstep(0.5, 0.62, n) * up_hard * wetness;

	// 非积水处的湿润光泽：变暗 + 略微光滑
	float sheen = wetness * up;
	vec3 wet_alb = base * mix(1.0, 0.6, sheen);
	ALBEDO = mix(wet_alb, base * 0.16, puddle);

	float rough = mix(0.95, 0.5, sheen);
	rough = mix(rough, 0.04, puddle);  // 积水=近镜面 → SSR 反射场景
	ROUGHNESS = rough;
	SPECULAR = mix(0.5, 0.95, puddle);

	// 积水涟漪：扰动世界向上法线（转到视图空间写 NORMAL）
	float t = TIME * 1.3;
	vec2 rp = w_pos.xz * 0.06;
	float rip = sin(rp.x + t) * 0.5 + sin(rp.y * 1.3 - t * 1.2) * 0.5;
	float rip2 = sin((rp.x + rp.y) * 0.7 + t * 1.7);
	vec3 perturb = normalize(vec3((rip + rip2) * 0.12, 1.0, (rip - rip2) * 0.12));
	vec3 perturb_view = (VIEW_MATRIX * vec4(perturb, 0.0)).xyz;
	NORMAL = normalize(mix(NORMAL, perturb_view, puddle * 0.6));
}
