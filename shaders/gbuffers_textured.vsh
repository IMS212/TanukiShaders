#version 120

#define LavaSpeed 0.25 //[0.25 0.5 0.75 1]
#define WaveAmount 0.5 //[0.25 0.5 0.75 1]
#define WaveSpeed 0.75 //[0.5 0.75 1 1.25 1.5]
#define Lava   		10010.0
#define Water		10008.0

attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;

uniform vec3 CameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform float frameTimeCounter;

varying vec2 lmcoord;
varying vec2 TexCoords;
varying vec2 LightmapCoords;
varying vec3 Normal;
varying vec4 Color;
varying vec3 VWorldPos;

void main() {
    TexCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vec4 Position = gl_ModelViewMatrix * gl_Vertex;
    vec4 VPos = gbufferModelViewInverse*Position;
    VWorldPos = VPos.xyz + CameraPosition;
    float WaveDisplacement = 0.0;

	if(mc_Entity.x == Water) {
		float FractY = fract(VWorldPos.y + 0.001);
		float Waves = 0.05 * sin(3.14 * (frameTimeCounter * WaveSpeed + VWorldPos.x/5 + VWorldPos.z/6)) + 0.10 * sin(frameTimeCounter * WaveSpeed + VWorldPos.x/2.5 + VWorldPos.z/10);
		WaveDisplacement = clamp(Waves, -FractY, 1.0-FractY);
		VPos.y += WaveDisplacement * WaveAmount;
	}

    if (mc_Entity.x == Lava) {
        float FractY = fract(VWorldPos.y + 0.001);
        float Waves = 0.05 * sin(3.14 * (frameTimeCounter * LavaSpeed + VWorldPos.x/10 + VWorldPos.z/12)) + 0.15 * sin(frameTimeCounter * LavaSpeed + VWorldPos.x/5 + VWorldPos.z/15);
        WaveDisplacement = clamp(Waves, -FractY, 1.0-FractY);
        VPos.y += WaveDisplacement * WaveAmount;
    }

    VPos = gbufferModelView * VPos;
    gl_Position = gl_ProjectionMatrix * VPos;
//    gl_Position = ftransform();
    TexCoords = gl_MultiTexCoord0.st;

    LightmapCoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    LightmapCoords = (LightmapCoords * 33.05f / 32.0f) - (1.05f / 32.0f);

    Normal = gl_NormalMatrix * gl_Normal;
    Color = gl_Color;
    }