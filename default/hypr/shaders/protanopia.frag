#version 300 es
// Settings → Accessibility → Colour filter → Red-blind (decoration.screen_shader). Daltonisation: the colour as a
// red-blind eye sees it is simulated in LMS space, and what is lost is moved into green and blue, where it can be seen.
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 c = texture(tex, v_texcoord);
    vec3 rgb = c.rgb;
    float L = dot(rgb, vec3(17.8824, 43.5161, 4.11935));
    float M = dot(rgb, vec3(3.45565, 27.1554, 3.86714));
    float S = dot(rgb, vec3(0.0299566, 0.184309, 1.46709));
    L = 2.02344 * M - 2.52581 * S;   // no L cones
    vec3 lms = vec3(L, M, S);
    vec3 sim = vec3(dot(lms, vec3(0.0809444479, -0.130504409, 0.116721066)),
                    dot(lms, vec3(-0.0102485335, 0.0540193266, -0.113614708)),
                    dot(lms, vec3(-0.000365296938, -0.00412161469, 0.693511405)));
    vec3 err = rgb - sim;
    vec3 fix = vec3(0.0, 0.7 * err.r + err.g, 0.7 * err.r + err.b);
    fragColor = vec4(clamp(rgb + fix, 0.0, 1.0), c.a);
}
