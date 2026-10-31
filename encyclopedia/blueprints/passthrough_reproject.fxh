// passthrough_reproject.fxh — ReShade FX template for guest->host color reprojection.
//
// LIMIT (read this first): as of the ReShade 6.x effect runtime (2026-10), an
// effect is a full-screen post-process pass and the game depth texture is
// read-only. It can read host depth and reject guest pixels behind host geometry,
// but it cannot write that depth or inject geometry into the host scene. A
// ReShade *add-on* (C++ API) can issue draw calls; a D3D11 draw/depth hook is the
// engine-level route. If a future runtime exposes writable depth, update this
// header and encyclopedia/CLAIMS.md instead of repeating the old limit.
//
// Inputs: the guest writes its latest frame header through ipc_seqlock.h and its
// color/depth through shared textures or CPU-mapped buffers. A bridge copies the
// matrices and depth into the uniforms below once per frame.

#include "ReShade.fxh"

uniform float4x4 GuestInvViewProj;
uniform float4x4 GuestCameraDelta;  // current -> previous frame
uniform float4x4 HostViewProj;
uniform float3 HostCameraPos;
uniform float HostNear < ui_min = 0.01; ui_max = 10.0; > = 0.1;
uniform float HostFar < ui_min = 10.0; ui_max = 100000.0; > = 1000.0;
uniform int HostDepthReversed < ui_type = "combo"; ui_items = "No\0Yes\0"; > = 1;
uniform float PoseLag < ui_min = 0.0; ui_max = 1.0; > = 0.0;
uniform float OcclusionBias < ui_min = 0.0; ui_max = 0.1; > = 0.002;
uniform float AmbientStrength < ui_min = 0.0; ui_max = 1.0; > = 0.15;
uniform int RaySteps < ui_min = 1; ui_max = 64; > = 16;
uniform float4 GuestTint < ui_type = "color"; > = float4(1, 1, 1, 1);

// Host depth: ReShade binds the game's depth buffer to DEPTH.
texture DepthBuffer { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R32F; };
sampler DepthBufferSampler { Texture = DepthBuffer; };

// Guest color and depth are shared textures bound by the bridge. If the bridge
// uses a CPU RGBA copy instead, replace these with 1x1 textures updated per frame.
texture GuestColorTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler GuestColorSampler { Texture = GuestColorTex; };
texture GuestDepthTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = R32F; };
sampler GuestDepthSampler { Texture = GuestDepthTex; };

float LinearizeHostDepth(float raw) {
    // Standard: z = near*far / (far - raw*(far-near)).
    // Reversed:  z = near*far / (near + raw*(far-near)).
    float denom = HostDepthReversed
        ? (HostNear + raw * (HostFar - HostNear))
        : (HostFar - raw * (HostFar - HostNear));
    return (HostNear * HostFar) / max(denom, 1e-6);
}

float3 GuestWorldFromUv(float2 uv, float raw_depth) {
    float2 ndc = uv * 2.0 - 1.0;
    float4 clip = float4(ndc, raw_depth, 1.0);
    float4 world = mul(GuestInvViewProj, clip);
    return world.xyz / max(world.w, 1e-6);
}

float2 HostUvFromWorld(float3 world) {
    float4 clip = mul(HostViewProj, float4(world, 1.0));
    float2 ndc = clip.xy / max(clip.w, 1e-6);
    return ndc * 0.5 + 0.5;
}

// One-frame pose lag: GuestCameraDelta maps the current world point back to the
// previous frame. PoseLag = 1 uses the previous position; 0 uses the current.
float3 ApplyPoseLag(float3 world) {
    if (PoseLag <= 0.0) return world;
    float3 previous = mul(GuestCameraDelta, float4(world, 1.0)).xyz;
    return lerp(world, previous, PoseLag);
}

// Ray-march the host depth buffer between the host camera and the guest point.
// This is a screen-space approximation; it does not occlude the host with guest
// geometry and it is not a substitute for a real depth-tested draw.
bool OccludedByHost(float3 guest_world) {
    float3 delta = guest_world - HostCameraPos;
    float distance = length(delta);
    if (distance <= 0.001) return false;
    float3 dir = delta / distance;
    float step_size = distance / float(max(RaySteps, 1));
    [loop] for (int i = 1; i <= RaySteps; ++i) {
        float t = step_size * float(i);
        float2 uv = HostUvFromWorld(HostCameraPos + dir * t);
        if (any(uv < 0.0) || any(uv > 1.0)) continue;
        float host_depth = LinearizeHostDepth(tex2D(DepthBufferSampler, uv).r);
        if (host_depth > 0.0 && host_depth < t - OcclusionBias) return true;
    }
    return false;
}

float4 PS_Passthrough(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float4 guest = tex2D(GuestColorSampler, uv);
    if (guest.a <= 0.001) return 0.0;

    float raw_guest = tex2D(GuestDepthSampler, uv).r;
    float3 guest_world = GuestWorldFromUv(uv, raw_guest);
    guest_world = ApplyPoseLag(guest_world);

    if (OccludedByHost(guest_world)) return 0.0;

    float2 host_uv = HostUvFromWorld(guest_world);
    if (any(host_uv < 0.0) || any(host_uv > 1.0)) return 0.0;

    float3 host_color = tex2D(ReShade::BackBuffer, host_uv).rgb;
    float host_luma = dot(host_color, float3(0.2126, 0.7152, 0.0722));
    float3 tinted = guest.rgb * GuestTint.rgb * lerp(1.0, host_luma, AmbientStrength);
    return float4(tinted, guest.a);
}

void VS_Passthrough(in uint id : SV_VertexID, out float4 pos : SV_POSITION, out float2 uv : TEXCOORD) {
    uv = float2((id << 1) & 2, id & 2);
    pos = float4(uv * float2(2, -2) + float2(-1, 1), 0, 1);
}

technique PassthroughReproject < ui_label = "Passthrough reprojection"; >
{
    pass
    {
        VertexShader = VS_Passthrough;
        PixelShader = PS_Passthrough;
    }
}
