Texture2D gDiffuseMap : register(t0);
Texture2D gAlbedoBuffer : register(t0);
Texture2D gNormalBuffer : register(t1);
Texture2D gDepthBuffer : register(t2);
Texture2D gLightingBuffer : register(t0);

SamplerState gSampler : register(s0);

cbuffer cbPerObject : register(b0)
{
    float4x4 mWorldViewProj;
    float2 uvTiling;
    float2 uvOffset;
    float4 padding;
};

struct DirectionalLightGpu
{
    float4 directionIntensity;
    float4 color;
};

struct PointLightGpu
{
    float4 positionRange;
    float4 colorIntensity;
};

struct SpotLightGpu
{
    float4 positionRange;
    float4 directionAngle;
    float4 colorIntensity;
};

cbuffer cbFrame : register(b0)
{
    float4x4 gInvViewProj;
    float4x4 gViewProj;
    float4 gCameraPosition;
    float4 gLightCounts;
    float4 gScreenSize;
    DirectionalLightGpu gDirectionalLights[1];
    SpotLightGpu gSpotLights[2];
};

cbuffer cbPointLight : register(b1)
{
    float4 gPointLightPositionRange;
    float4 gPointLightColorIntensity;
};

struct VSInput
{
    float3 Pos : POSITION;
    float3 Normal : NORMAL;
    float2 Tex : TEXCOORD;
};

struct GeometryPSInput
{
    float4 PosH : SV_POSITION;
    float3 NormalW : NORMAL;
    float2 TexC : TEXCOORD;
};

struct GeometryPSOutput
{
    float4 Albedo : SV_Target0;
    float4 Normal : SV_Target1;
};

struct FullscreenPSInput
{
    float4 PosH : SV_POSITION;
    float2 TexC : TEXCOORD;
};

struct PointLightVolumeInput
{
    float3 Pos : POSITION;
};

struct PointLightVolumePSInput
{
    float4 PosH : SV_POSITION;
};

GeometryPSInput GeometryVS(VSInput vin)
{
    GeometryPSInput vout;
    vout.PosH = mul(float4(vin.Pos, 1.0f), mWorldViewProj);
    vout.NormalW = normalize(vin.Normal);
    vout.TexC = vin.Tex;
    return vout;
}

GeometryPSOutput GeometryPS(GeometryPSInput pin)
{
    GeometryPSOutput output;
    float2 uv = pin.TexC * uvTiling + uvOffset;
    float4 albedo = gDiffuseMap.Sample(gSampler, uv);
    clip(albedo.a - 0.1f);

    output.Albedo = albedo;
    output.Normal = float4(normalize(pin.NormalW), 1.0f);
    return output;
}

FullscreenPSInput LightingVS(uint vertexId : SV_VertexID)
{
    FullscreenPSInput vout;

    float2 positions[3] =
    {
        float2(-1.0f, -1.0f),
        float2(-1.0f,  3.0f),
        float2( 3.0f, -1.0f)
    };

    float2 texcoords[3] =
    {
        float2(0.0f, 1.0f),
        float2(0.0f, -1.0f),
        float2(2.0f, 1.0f)
    };

    vout.PosH = float4(positions[vertexId], 0.0f, 1.0f);
    vout.TexC = texcoords[vertexId];
    return vout;
}

float3 ReconstructWorldPosition(float2 uv, float depth)
{
    float4 clipPos = float4(uv * 2.0f - 1.0f, depth, 1.0f);
    clipPos.y *= -1.0f;

    float4 worldPos = mul(clipPos, gInvViewProj);
    worldPos /= worldPos.w;
    return worldPos.xyz;
}

float3 ComputeDirectionalLight(float3 normal, float3 viewDir, float3 albedo, float3 worldPos)
{
    float3 color = 0.0f;

    [unroll]
    for (int i = 0; i < (int)gLightCounts.x; ++i)
    {
        float3 lightDir = normalize(-gDirectionalLights[i].directionIntensity.xyz);
        float intensity = gDirectionalLights[i].directionIntensity.w;
        float3 lightColor = gDirectionalLights[i].color.xyz;

        float ndl = saturate(dot(normal, lightDir));
        float3 halfVec = normalize(lightDir + viewDir);
        float spec = pow(saturate(dot(normal, halfVec)), 32.0f);

        color += albedo * lightColor * ndl * intensity;
        color += lightColor * spec * intensity * 0.35f;
    }

    return color;
}

float3 ComputeSinglePointLight(float3 normal, float3 viewDir, float3 albedo, float3 worldPos)
{
    float3 lightVector = gPointLightPositionRange.xyz - worldPos;
    float distanceToLight = length(lightVector);
    float range = gPointLightPositionRange.w;

    if (distanceToLight > range)
        return 0.0f;

    float attenuation = 1.0f - saturate(distanceToLight / range);
    attenuation *= attenuation;
    float3 lightDir = normalize(lightVector);
    float ndl = saturate(dot(normal, lightDir));
    float3 halfVec = normalize(lightDir + viewDir);
    float spec = pow(saturate(dot(normal, halfVec)), 32.0f);

    float3 lightColor = gPointLightColorIntensity.xyz;
    float intensity = gPointLightColorIntensity.w;

    return albedo * lightColor * ndl * intensity * attenuation +
        lightColor * spec * intensity * attenuation * 0.35f;
}

float3 ComputeSpotLights(float3 normal, float3 viewDir, float3 albedo, float3 worldPos)
{
    float3 color = 0.0f;

    [unroll]
    for (int i = 0; i < (int)gLightCounts.z; ++i)
    {
        float3 lightVector = gSpotLights[i].positionRange.xyz - worldPos;
        float distanceToLight = length(lightVector);
        float range = gSpotLights[i].positionRange.w;

        if (distanceToLight > range)
            continue;

        float3 lightDir = normalize(lightVector);
        float3 spotDir = normalize(-gSpotLights[i].directionAngle.xyz);
        float cone = saturate(dot(lightDir, spotDir));
        float cutoff = gSpotLights[i].directionAngle.w;

        if (cone < cutoff)
            continue;

        float attenuation = (1.0f - saturate(distanceToLight / range)) * smoothstep(cutoff, 1.0f, cone);
        float ndl = saturate(dot(normal, lightDir));
        float3 halfVec = normalize(lightDir + viewDir);
        float spec = pow(saturate(dot(normal, halfVec)), 32.0f);

        float3 lightColor = gSpotLights[i].colorIntensity.xyz;
        float intensity = gSpotLights[i].colorIntensity.w;

        color += albedo * lightColor * ndl * intensity * attenuation;
        color += lightColor * spec * intensity * attenuation * 0.35f;
    }

    return color;
}

float4 LightingPS(FullscreenPSInput pin) : SV_Target
{
    float2 uv = pin.TexC;
    float4 albedoSample = gAlbedoBuffer.Sample(gSampler, uv);
    float3 normal = normalize(gNormalBuffer.Sample(gSampler, uv).xyz);
    float depth = gDepthBuffer.Sample(gSampler, uv).r;

    float3 worldPos = ReconstructWorldPosition(uv, depth);
    float3 viewDir = normalize(gCameraPosition.xyz - worldPos);
    float3 albedo = albedoSample.rgb;

    float3 color = albedo * 0.05f;
    color += ComputeDirectionalLight(normal, viewDir, albedo, worldPos);
    color += ComputeSpotLights(normal, viewDir, albedo, worldPos);

    return float4(color, 1.0f);
}

PointLightVolumePSInput PointLightVolumeVS(PointLightVolumeInput vin)
{
    PointLightVolumePSInput vout;
    float3 worldPos = vin.Pos * gPointLightPositionRange.w + gPointLightPositionRange.xyz;
    vout.PosH = mul(float4(worldPos, 1.0f), gViewProj);
    return vout;
}

float4 PointLightVolumePS(PointLightVolumePSInput pin) : SV_Target
{
    float2 uv = pin.PosH.xy * gScreenSize.zw;
    if (any(uv < 0.0f) || any(uv > 1.0f))
        discard;

    float4 albedoSample = gAlbedoBuffer.Sample(gSampler, uv);
    float3 normal = normalize(gNormalBuffer.Sample(gSampler, uv).xyz);
    float depth = gDepthBuffer.Sample(gSampler, uv).r;

    if (depth >= 0.99999f)
        discard;

    float3 worldPos = ReconstructWorldPosition(uv, depth);
    float3 viewDir = normalize(gCameraPosition.xyz - worldPos);
    if (length(gPointLightPositionRange.xyz - worldPos) > gPointLightPositionRange.w)
        discard;

    float3 color = ComputeSinglePointLight(normal, viewDir, albedoSample.rgb, worldPos);
    return float4(color, 1.0f);
}

FullscreenPSInput FinalVS(uint vertexId : SV_VertexID)
{
    return LightingVS(vertexId);
}

float4 FinalPS(FullscreenPSInput pin) : SV_Target
{
    return gLightingBuffer.Sample(gSampler, pin.TexC);
}
