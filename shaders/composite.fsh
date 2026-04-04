#version 330 compatibility

#include "/lib/shadowDistort.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

/* const int colortex0Format = RGB16; */

uniform vec3 shadowLightPosition;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform float ambientLight;
uniform float near;
uniform float far;
uniform int worldTime;
uniform int isEyeInWater;
uniform float nightVision;

const vec3 blocklightColor 	= 	vec3(0.929, 0.788, 0.431);
const vec3 skylightColor 	= 	vec3(0.518, 0.631, 0.812);
const vec3 sunlightColor 	= 	vec3(0.969, 0.925, 0.882);
const vec3 moonlightColor 	= 	vec3(0.027, 0.067, 0.122);
const vec3 waterColor		= 	vec3(0.035, 0.039, 0.110);
const int FOG_DENSITY = 5;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
	vec4 homPos = projectionMatrix * vec4(position, 1.0);
	return homPos.xyz / homPos.w;
}

vec3 getShadow(vec3 shadowScreenPos){
	float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r); // sample the shadow map containing everything

	// A value of 1.0 means 100% of sunlight is getting through.
	if (transparentShadow == 1.0){
		// No shadow at all - easy enough!
		return vec3(1.0);
	}

	float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r); // sample the shadow map containing only opaque stuff

	if(opaqueShadow == 0.0){
		// There is a shadow cast by something fully opaque (e.g. a stone block) - we're fully in shadow.
		return vec3(0.0);
	}

	// contains the color and alpha (transparency) of the thing casting a shadow
	vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);

	// We use (1.0 - alpha) to get how much light is let through, and multiply that light by the color of the thing that's
	// casting the shadow.
	return shadowColor.rgb * (1.0 - shadowColor.a);
}

void main() {
	vec2 lightmap = texture(colortex1, texcoord).xy;
	vec3 encodedNormal = texture(colortex2, texcoord).rgb;
	vec4 typeData = texture(colortex3, texcoord).xyzw;
	vec3 normal = mat3(gbufferModelViewInverse) * (encodedNormal * 2 - 1);
	vec3 lightVector = normalize(shadowLightPosition);
	vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;

	color = texture(colortex0, texcoord);

	float depth0 = texture(depthtex0, texcoord).r;
	float depth1 = texture(depthtex1, texcoord).r;
	if (depth0 == 1.0) {
		return;
	}

	vec3 ndcPos = vec3(texcoord.xy, depth0) * 2.0 - 1.0; // normalized device coordinates (NDC); [-1.0, 1.0]
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos); // position in view space
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz; // position relative to the feet of the player
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
	shadowClipPos.z -= 0.001;
	shadowClipPos.xyz = distortShadowClipPos(shadowClipPos.xyz);

	vec3 shadowNdcPos = shadowClipPos.xyz / shadowClipPos.w;
	vec3 shadowScreenPos = shadowNdcPos * 0.5 + 0.5;
	vec3 shadow = getShadow(shadowScreenPos);

	float normalized = mod(float(worldTime), 24000.0) / 24000.0;
	float zero_pos = 18000.0 / 24000.0;  // 0.75
	float dist2 = min(abs(normalized - zero_pos), 1.0 - abs(normalized - zero_pos));
	float value = clamp((dist2 - 0.25) / 0.25, 0.0, 1.0);

	vec3 blocklight = lightmap.x * blocklightColor;
	vec3 skylight = lightmap.y * skylightColor * value;
	vec3 sunlight = sunlightColor * clamp(dot(worldLightVector, normal), 0.0, 1.0) * shadow * value;
	vec3 moonlight = moonlightColor * clamp(dot(worldLightVector, normal), 0.0, 1.0) * shadow * (1.0 - value);

	color.rgb *= blocklight + skylight + sunlight + moonlight + vec3((depth0 - 0.9) / 0.3 * nightVision);
	color.rgb = clamp((color.rgb - 0.5) / 0.9 + 0.5, 0.0, 1.0); // darken the darks and brighten the brights

	if (isEyeInWater == 1) {
		float fogFactor = 1.0 - exp(-0.05 * ((2.0 * near * far) / (far + near - (depth0 * 2.0 - 1.0) * (far - near)) - depth0));
		color.rgb = mix(color.rgb, waterColor, fogFactor);
	} else if (typeData.r == 1.0) {
		color *= 0.8;
		color.rgb = mix(color.rgb, waterColor, 0.4);
		color.rgb *= clamp((1.0 - depth1) * far, 0.0, 1.0);
	}

	float dist = length(viewPos) / far;
	float fogFactor = exp(-FOG_DENSITY * (1.0 - dist));

	color.rgb = mix(color.rgb, pow((skyColor * ambientLight + fogColor), vec3(2.2)), clamp(fogFactor, 0.0, 1.0));
}
