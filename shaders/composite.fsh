#version 330 compatibility

#include "/lib/shadows.glsl"
#include "/lib/coordinates.glsl"

/* Constants */
/* const int colortex0Format = RGB16; */

const int shadowMapResolution = 2048;

const float timeMidday = 18000.0 / 24000.0;  // 0.75

const vec3 blocklightColor 	= 	vec3(0.929, 0.788, 0.431);
const vec3 skylightColor 	= 	vec3(0.518, 0.631, 0.812);
const vec3 sunlightColor 	= 	vec3(0.969, 0.925, 0.882);
const vec3 moonlightColor 	= 	vec3(0.027, 0.067, 0.122);
const vec3 waterColor		= 	vec3(0.035, 0.039, 0.110);

const int FOG_DENSITY = 5;

/* Uniforms */
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform float viewHeight;
uniform float viewWidth;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;
vec3 eyeCameraPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

uniform vec3 skyColor;
uniform vec3 fogColor;

uniform int worldTime;
uniform float ambientLight;
uniform vec3 shadowLightPosition;

uniform float near;
uniform float far;

uniform int isEyeInWater;
uniform float nightVision;

/* Inputs */
in vec2 texcoord;

/* Outputs */
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	/* Coordinate Spaces */
	vec3 screenPos0 = vec3(texcoord, texture2D(depthtex0, texcoord));
	vec3 screenPos1 = vec3(texcoord, texture2D(depthtex1, texcoord));

	vec3 texelPos0 = screenPos0 * vec3(viewWidth, viewHeight, 1.0);
	vec3 texelPos1 = screenPos1 * vec3(viewWidth, viewHeight, 1.0);

	vec3 ndcPos0 = screenPos0 * 2.0 - 1.0;
	vec3 ndcPos1 = screenPos1 * 2.0 - 1.0;

	vec3 viewPos0 = projectAndDivide(gbufferProjectionInverse, ndcPos0);
	vec3 viewPos1 = projectAndDivide(gbufferProjectionInverse, ndcPos1);

	vec4 clipPos0 = gbufferProjection * vec4(viewPos0, 1.0);
	vec4 clipPos1 = gbufferProjection * vec4(viewPos1, 1.0);

	vec3 eyePlayerPos0 = mat3(gbufferModelViewInverse) * viewPos0;
	vec3 eyePlayerPos1 = mat3(gbufferModelViewInverse) * viewPos1;

	vec3 feetPlayerPos0 = eyePlayerPos0 + gbufferModelViewInverse[3].xyz;
	vec3 feetPlayerPos1 = eyePlayerPos1 + gbufferModelViewInverse[3].xyz;

	vec3 worldPos0 = eyePlayerPos0 + eyeCameraPosition;
	vec3 worldPos1 = eyePlayerPos1 + eyeCameraPosition;

	vec3 shadowViewPos0 = (shadowModelView * vec4(feetPlayerPos0, 1.0)).xyz;
	vec3 shadowViewPos1 = (shadowModelView * vec4(feetPlayerPos1, 1.0)).xyz;

	vec4 shadowClipPos0 = shadowProjection * vec4(shadowViewPos0, 1.0);
	vec4 shadowClipPos1 = shadowProjection * vec4(shadowViewPos1, 1.0);

	shadowClipPos0.z -= 0.001;
	shadowClipPos0.xyz = distortShadowClipPos(shadowClipPos0.xyz);

	shadowClipPos1.z -= 0.001;
	shadowClipPos1.xyz = distortShadowClipPos(shadowClipPos1.xyz);

	vec3 shadowNdcPos0 = shadowClipPos0.xyz / shadowClipPos0.w;
	vec3 shadowNdcPos1 = shadowClipPos1.xyz / shadowClipPos1.w;

	vec3 shadowScreenPos0 = shadowNdcPos0 * 0.5 + 0.5;
	vec3 shadowScreenPos1 = shadowNdcPos1 * 0.5 + 0.5;

	vec3 shadowTexelPos0 = shadowScreenPos0 * vec3(shadowMapResolution, shadowMapResolution, 1.0);
	vec3 shadowTexelPos1 = shadowScreenPos1 * vec3(shadowMapResolution, shadowMapResolution, 1.0);

	/* Textures */
	color = texture(colortex0, texcoord);
	vec2 lightmap = texture(colortex1, texcoord).xy;
	vec3 normal = mat3(gbufferModelViewInverse) * (texture(colortex2, texcoord).rgb * 2.0 - 1.0);
	vec4 typeData = texture(colortex3, texcoord);

	float depth0 = texture(depthtex0, texcoord).r;
	float depth1 = texture(depthtex1, texcoord).r;
	if (depth0 == 1.0) {
		return;
	}

	/* Lighting */
	vec3 shadow = getShadow(shadowtex0, shadowtex1, shadowcolor0, shadowScreenPos0);

	vec3 lightVector = normalize(shadowLightPosition);
	vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;

	float normalizedWorldTime = mod(float(worldTime), 24000.0) / 24000.0;
	float distanceToMidday = min(abs(normalizedWorldTime - timeMidday), 1.0 - abs(normalizedWorldTime - timeMidday));
	float worldLightIntensity = clamp((distanceToMidday - 0.25) / 0.25, 0.0, 1.0);

	vec3 blocklight = lightmap.x * blocklightColor;
	vec3 skylight = lightmap.y * skylightColor * worldLightIntensity;
	vec3 sunlight = sunlightColor * clamp(dot(worldLightVector, normal), 0.0, 1.0) * shadow * worldLightIntensity;
	vec3 moonlight = moonlightColor * clamp(dot(worldLightVector, normal), 0.0, 1.0) * shadow * (1.0 - worldLightIntensity);

	color.rgb *= blocklight + skylight + sunlight + moonlight + vec3((depth1 - 0.9) / 0.3 * nightVision);
	color.rgb = clamp((color.rgb - 0.5) / 0.9 + 0.5, 0.0, 1.0); // darken the darks and brighten the brights

	/* Water */
	if (isEyeInWater == 1) {
		float fogFactor = 1.0 - exp(-0.05 * ((2.0 * near * far) / (far + near - (depth0 * 2.0 - 1.0) * (far - near)) - depth0));
		color.rgb = mix(color.rgb, vec3(0.0), fogFactor);
	} else if (typeData.r == 1.0) {
		color.rgb = mix(color.rgb, waterColor / 4.0 + fogColor / 24.0, 0.2);
		color.rgb = mix(color.rgb, color.rgb * clamp((1.0 - depth1) * far, 0.0, 1.0), clamp(length(worldPos0 - worldPos1) / 8.0, 0.0, 1.0));
		float fogFactor = clamp(length(worldPos0 - worldPos1) / 16.0, 0.0, 1.0);
		color.rgb = mix(color.rgb, vec3(0.0), fogFactor);
	}

	/* Fog */
	float distanceToWorldFog = length(viewPos0) / far;
	float worldFogFactor = exp(-FOG_DENSITY * (1.0 - distanceToWorldFog));

	color.rgb = mix(color.rgb, pow((skyColor * ambientLight + fogColor), vec3(2.2)), clamp(worldFogFactor, 0.0, 1.0));

	float distanceToHeightFog = clamp((worldPos0.y - 48) / 128, 0.0, 1.0);
	float heightFogFactor = exp(-FOG_DENSITY * (1.0 - distanceToHeightFog));

	color.rgb = mix(color.rgb, vec3(1.0), clamp(heightFogFactor, 0.0, 0.5));
}
