shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture;

uniform float rain_amount : hint_range(0.0, 1.0) = 0.5;
uniform float speed : hint_range(0.0, 5.0) = 1.0;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;

uniform vec2 uv_scale = vec2(2.0, -1.0);

// 磨砂玻璃相关参数
uniform float frosted_blur : hint_range(0.0, 5.0) = 0.5; // 基础磨砂模糊
uniform float distance_blur_scale : hint_range(0.0, 2.0) = 0.1; // 随距离增加的模糊比例
uniform float refraction_strength : hint_range(0.0, 1.0) = 0.05; // 磨砂引起的折射强度影响
uniform float frosted_noise_scale : hint_range(1.0, 1000.0) = 200.0; // 噪声缩放

// SSRM 核心参数
uniform float glass_thickness : hint_range(0.001, 2.0) = 0.2; // 模拟玻璃厚度或射线步进长度
uniform float ior : hint_range(1.0, 2.0) = 1.45; // 折射率 (玻璃约为 1.5)

vec3 N13(float p) {
   vec3 p3 = fract(vec3(p) * vec3(.1031,.11369,.13787));
   p3 += dot(p3, p3.yzx + 19.19);
   return fract(vec3((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1103, .1097));
    p3 += dot(p3, p3.yzx+19.19);
    return fract((p3.xx+p3.yz)*p3.zy);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash22(i).x;
    float b = hash22(i + vec2(1.0, 0.0)).x;
    float c = hash22(i + vec2(0.0, 1.0)).x;
    float d = hash22(i + vec2(1.0, 1.0)).x;
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float N(float t) {
    return fract(sin(t*12345.564)*7658.76);
}

float Saw(float b, float t) {
	return smoothstep(0., b, t)*smoothstep(1., b, t);
}

vec2 DropLayer2(vec2 uv, float t) {
    vec2 UV = uv;
    uv.y += t*0.75;
    vec2 a = vec2(6., 1.);
    vec2 grid = a*2.;
    vec2 id = floor(uv*grid);
    
    float colShift = N(id.x); 
    uv.y += colShift;
    
    id = floor(uv*grid);
    vec3 n = N13(id.x*35.2+id.y*2376.1);
    vec2 st = fract(uv*grid)-vec2(.5, 0);
    
    float x = n.x-.5;
    
    float y = UV.y*20.;
    float wiggle = sin(y+sin(y));
    x += wiggle*(.5-abs(x))*(n.z-.5);
    x *= .7;
    float ti = fract(t+n.z);
    y = (Saw(.85, ti)-.5)*.9+.5;
    vec2 p = vec2(x, y);
    
    float d = length((st-p)*a.yx);
    
    float mainDrop = smoothstep(.4, .0, d);
    
    float r = sqrt(smoothstep(1., y, st.y));
    float cd = abs(st.x-x);
    float trail = smoothstep(.23*r, .15*r*r, cd);
    float trailFront = smoothstep(-.02, .02, st.y-y);
    trail *= trailFront*r*r;
    
    y = UV.y;
    float trail2 = smoothstep(.2*r, .0, cd);
    float droplets = max(0., (sin(y*(1.-y)*120.)-st.y))*trail2*trailFront*n.z;
    y = fract(y*10.)+(st.y-.5);
    float dd = length(st-vec2(x, y));
    droplets = smoothstep(.3, 0., dd);
    float m = mainDrop+droplets*r*trailFront;
    
    return vec2(m, trail);
}

float StaticDrops(vec2 uv, float t) {
	uv *= 40.;
    vec2 id = floor(uv);
    uv = fract(uv)-.5;
    vec3 n = N13(id.x*107.45+id.y*3543.654);
    vec2 p = (n.xy-.5)*.7;
    float d = length(uv-p);
    
    float fade = Saw(.025, fract(t+n.z));
    float c = smoothstep(.3, 0., d)*fract(n.z*10.)*fade;
    return c;
}

vec2 Drops(vec2 uv, float t, float l0, float l1, float l2) {
    float s = StaticDrops(uv, t)*l0; 
    vec2 m1 = DropLayer2(uv, t)*l1;
    vec2 m2 = DropLayer2(uv*1.85, t)*l2;
    
    float c = s+m1.x+m2.x;
    c = smoothstep(.3, 1., c);
    
    return vec2(c, max(m1.y*l0, m2.y*l1));
}

void fragment() {
    vec2 uv = UV * uv_scale; 

    float T = TIME * speed;
    float t = T * .2;
    
    float staticDrops = smoothstep(-.5, 1., rain_amount)*2.;
    float layer1 = smoothstep(.25, .75, rain_amount);
    float layer2 = smoothstep(.0, .5, rain_amount);
    
    vec2 c = Drops(uv, t, staticDrops, layer1, layer2);
    
    vec2 e = vec2(.001, 0.);
    float cx = Drops(uv+e, t, staticDrops, layer1, layer2).x;
    float cy = Drops(uv+e.yx, t, staticDrops, layer1, layer2).x;
    vec2 n_offset = vec2(cx-c.x, cy-c.x); 
    
    // 磨砂噪声
    float n_val = noise(UV * frosted_noise_scale);
    float n_val2 = noise(UV * frosted_noise_scale + vec2(15.2, 31.7));
    vec2 frosted_n = (vec2(n_val, n_val2) * 2.0 - 1.0) * refraction_strength;
    
    // 雨滴覆盖处减弱磨砂
    frosted_n *= (1.0 - smoothstep(0.1, 0.5, c.x));
    
    // 总法线偏移
    vec2 total_n_offset = n_offset + frosted_n;
    
    // --- SSRM (Screen Space Raymarching) 逻辑 ---
    
    // 获取当前片段的视空间位置
    vec4 view_pos_raw = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, FRAGCOORD.z, 1.0);
    vec3 view_pos = view_pos_raw.xyz / view_pos_raw.w;
    vec3 view_dir = normalize(view_pos);
    
    // 构造法线
    vec3 perturbed_normal = normalize(NORMAL + vec3(total_n_offset * 10.0, 0.0));
    
    // 计算折射方向
    vec3 refract_dir = refract(view_dir, perturbed_normal, 1.0 / ior);
    
    // 开始步进
    vec2 hit_uv = SCREEN_UV;
    vec3 current_ray_pos = view_pos;
    float step_size = glass_thickness / 32.0;
    
    for (int i = 0; i < 32; i++) {
        current_ray_pos += refract_dir * step_size;
        
        vec4 proj = PROJECTION_MATRIX * vec4(current_ray_pos, 1.0);
        vec2 sample_uv = (proj.xy / proj.w) * 0.5 + 0.5;
        
        if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) break;
        
        float scene_depth_val = texture(depth_texture, sample_uv).r;
        vec4 scene_pos_raw = INV_PROJECTION_MATRIX * vec4(sample_uv * 2.0 - 1.0, scene_depth_val, 1.0);
        vec3 scene_view_pos = scene_pos_raw.xyz / scene_pos_raw.w;
        
        if (current_ray_pos.z < scene_view_pos.z) {
            hit_uv = sample_uv;
            break;
        }
        hit_uv = sample_uv; 
    }
    
    float depth = texture(depth_texture, hit_uv).r;
    vec4 v_pos = INV_PROJECTION_MATRIX * vec4(hit_uv * 2.0 - 1.0, depth, 1.0);
    float linear_depth = -(v_pos.xyz / v_pos.w).z;
    float current_depth = -view_pos.z;
    float distance_to_bg = max(0.0, linear_depth - current_depth);
    
    float dynamic_blur = frosted_blur + (distance_to_bg * distance_blur_scale);
    float final_blur = mix(dynamic_blur, 0.0, smoothstep(0.1, 0.5, c.x));
    final_blur = max(final_blur, blur_amount * c.y); 
    
    vec3 col = textureLod(screen_texture, hit_uv, final_blur).rgb;
    
    float fresnel = pow(1.0 + dot(view_dir, perturbed_normal), 5.0);
    col += fresnel * 0.2; 
    
    
    ALBEDO = col;
}
