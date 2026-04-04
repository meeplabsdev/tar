#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightLevelData;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 typeData;

void main() {
	color = texture(gtexture, texcoord) * glcolor * 0.48;
//	color *= texture(lightmap, lmcoord);

	lightLevelData = vec4(lmcoord, 0.0, 1.0);
	encodedNormal = vec4((normal + 1) / 2, 1.0);
	typeData = vec4(1.0, 0.0, 0.0, 1.0);

	if (color.a < alphaTestRef) {
		discard;
	}
}