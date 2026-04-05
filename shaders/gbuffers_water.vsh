#version 330 compatibility

uniform float frameTimeCounter;

in vec2 mc_Entity;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;

void main() {
	vec4 pos = ftransform();

	if (mc_Entity == 1) {
		float t = frameTimeCounter * 1.5;
		float wave1 = sin((pos.x * 0.10) + (pos.z * 0.08) + t) * 0.040;
		float wave2 = sin((pos.x * 0.18) - (pos.z * 0.12) + t * 1.3) * 0.025;
		float wave3 = cos((pos.x * 0.07) + (pos.z * 0.15) - t * 0.9) * 0.015;

		pos.y += wave1 + wave2 + wave3 - 0.08;
	}

	gl_Position = pos;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	normal = gl_Normal * 0;
}