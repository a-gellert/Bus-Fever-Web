#version 140

in mediump vec3 var_normal;
in mediump vec2 var_texcoord0;

out vec4 out_fragColor;

uniform mediump sampler2D tex0;

uniform fs_uniforms
{
    mediump vec4 tint;
};

void main()
{
    vec4 tex = texture(tex0, var_texcoord0.xy);
    // Cell (0,0) in palette_3d.png (u < 0.25, v > 0.75) is the tintable body mask
    float is_paint = step(var_texcoord0.x, 0.25) * step(0.75, var_texcoord0.y);
    vec3 base = tex.rgb * mix(vec3(1.0), tint.rgb, is_paint);

    vec3 n = normalize(var_normal);
    vec3 sun_dir = normalize(vec3(-0.35, 0.52, 0.78));
    float ndotl = dot(n, sun_dir);
    float wrap = clamp(ndotl * 0.5 + 0.5, 0.0, 1.0);

    // Bright casual hemisphere bounce + soft sunlit wrap
    vec3 hemi = mix(vec3(0.56, 0.62, 0.74), vec3(1.0, 0.99, 0.96), clamp(n.y * 0.5 + 0.5, 0.0, 1.0));
    vec3 lit = base * (hemi * 0.64 + vec3(0.45) * wrap);

    // Subtle candy-gloss specular on curved roofs and windows
    vec3 half_vec = normalize(sun_dir + vec3(0.0, 0.0, 1.0));
    float spec = pow(max(dot(n, half_vec), 0.0), 28.0) * 0.24;
    lit += vec3(spec);

    float a = tex.a * tint.a;
    out_fragColor = vec4(lit * a, a);
}
