#version 120
#include "distort.glsl"

#define ShadowMapResolution 4096 //[1024 2048 3092 4096 5120 6144 7168 8192 9216 10240]
#define ShadowSamples 2 //[0.5 1 1.5 2 2.5 3 3.5 4 4.5 5 5.5 6 6.5 7 7.5 8]
#define TransparentShadowHardness 2 // [0.5 1 2 3 4 5]
#define noiseTextureResolution = 64; // [16 32 64 128 256]

varying vec2 TexCoords;

uniform vec3 shadowLightPosition;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform sampler2D depthtex0;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

uniform sampler2D noisetex;

uniform sampler2D shadowcolor0;

uniform int worldTime;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

/*
const int colortex0Format = RGB16;
const int colortex1Format = RGB16;
const int colortex2Format = RGB16;
*/

const float sunPathRotation = 30.0f;

const float Ambient = 0.025f;

float AdjustLightmapTorch(in float torch) {
    const float K = 2.0f;
    const float P = 5.06f;
    return K * pow(torch, P);
}

float AdjustLightmapSky(in float sky) {
    float sky_2 = sky * sky;
    return sky_2 * sky_2;
}

vec2 AdjustLightmap(in vec2 Lightmap) {
    vec2 NewLightMap;
    NewLightMap.x = AdjustLightmapTorch(Lightmap.x);
    NewLightMap.y = AdjustLightmapSky(Lightmap.y);
    return NewLightMap;
}

vec3 GetLightmapColor(in vec2 Lightmap) {
    Lightmap = AdjustLightmap(Lightmap);
    //const vec3 TorchColor = vec3(1.0f, 0.25f, 0.08f);
    const vec3 TorchColor = vec3(2.0f, 1.25f, 1.08f);
    vec3 SkyColor = vec3(0.05f, 0.15f, 0.3f);
    if (worldTime > 13200) {
        SkyColor = vec3(0.2, 0.325, 0.7);
    }
    if (worldTime > 13250) {
        SkyColor = vec3(0.1, 0.225, 0.6);
    }
    if (worldTime > 13300) {
        SkyColor = vec3(0.075, 0.2, 0.5);
    }
    if (worldTime > 13350) {
        SkyColor = vec3(0.075, 0.1975, 0.4);
    }
    if (worldTime > 13400 && worldTime < 23800) {
        SkyColor = vec3(0.0625, 0.1875, 0.375);
    }
    if (worldTime > 23850) {
        SkyColor = vec3(0.075, 0.1975, 0.4);
    }
    if (worldTime > 0 && worldTime < 51) {
        SkyColor = vec3(0.075, 0.2, 0.5);
    }
    if (worldTime > 50 && worldTime < 101) {
        SkyColor = vec3(0.1, 0.225, 0.6);
    }
    if (worldTime > 100 && worldTime < 151) {
        SkyColor = vec3(0.2, 0.325, 0.7);
    }
    vec3 TorchLighting = Lightmap.x * TorchColor;
    vec3 SkyLighting = Lightmap.y * SkyColor;
    vec3 LightmapLighting = TorchLighting + SkyLighting;
    return LightmapLighting;
}

float Visibility(in sampler2D ShadowMap, in vec3 SampleCoords) {
    return step(SampleCoords.z - 0.001f, texture2D(ShadowMap, SampleCoords.xy).r);
}

vec3 TransparentShadow(in vec3 SampleCoords) {
    float ShadowVisibility0 = Visibility(shadowtex0, SampleCoords);
    float ShadowVisibility1 = Visibility(shadowtex1, SampleCoords);
    vec4 ShadowColor0 = texture2D(shadowcolor0, SampleCoords.xy);
    vec3 TransmittedColor = ShadowColor0.rgb * (TransparentShadowHardness - ShadowColor0.r);
    return mix(TransmittedColor * ShadowVisibility1, vec3(1.0f), ShadowVisibility0);
}

const int ShadowSamplesPerSize = 2 * ShadowSamples + 1;
const int TotalSamples = ShadowSamplesPerSize * ShadowSamplesPerSize;

vec3 GetShadow(float depth) {
    vec3 ClipSpace = vec3(TexCoords, depth) * 2.0f - 1.0f;
    vec4 ViewW = gbufferProjectionInverse * vec4(ClipSpace, 1.0f);
    vec3 View = ViewW.xyz / ViewW.w;

    vec4 World = gbufferModelViewInverse * vec4(View, 1.0f) ;
    vec4 ShadowSpace = shadowProjection * shadowModelView * World;

    ShadowSpace.xy = DistortPosition(ShadowSpace.xy);
    vec3 SampleCoords = ShadowSpace.xyz * 0.5f + 0.5f;

    vec3 ShadowAccum = vec3(0.0f);

    float RandomAngle = texture2D(noisetex, TexCoords * 20.0f).r * 100.0f;
    float cosTheta = cos(RandomAngle);
    float sinTheta = sin(RandomAngle);
    mat2 Rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta) / ShadowMapResolution;
    for(int x = -ShadowSamples; x <= ShadowSamples; x++) {
        for (int y = -ShadowSamples; y <= ShadowSamples; y++) {
            vec2 Offset = Rotation * vec2(x, y);
            vec3 CurrentSampleCoordinate = vec3(SampleCoords.xy + Offset, SampleCoords.z);
            ShadowAccum += TransparentShadow(CurrentSampleCoordinate);
        }
    }
    ShadowAccum /= TotalSamples;
    return ShadowAccum;
}

void main() {
    vec3 Albedo = pow(texture2D(colortex0, TexCoords).rgb, vec3(2.2f));
    float Depth = texture2D(depthtex0, TexCoords).r;
    if (Depth == 1.0f) {
        gl_FragData[0] = vec4(Albedo, 1.0f);
        return;
    }
    vec2 Lightmap = texture2D(colortex2, TexCoords).rg;
    vec3 LightmapColor = GetLightmapColor(Lightmap);
    vec3 Normal = normalize(texture2D(colortex1, TexCoords).rgb * 2.0f - 1.0f);
    float NdotL = max(dot(Normal, normalize(shadowLightPosition)), 0.0f);
    vec3 Diffuse = Albedo * (LightmapColor + NdotL + GetShadow(Depth) + Ambient);

    if (worldTime > 13200 && worldTime < 23500) {
        Normal = normalize(texture2D(colortex1, vec2(0.0,1.0)).rgb * 2.0f - 1.0f);
        NdotL = 0.15f;
        Diffuse = Albedo * (LightmapColor + NdotL * GetShadow(Depth) + Ambient);
    }

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(Diffuse, 1.0f);

}