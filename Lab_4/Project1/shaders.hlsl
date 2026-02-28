Texture2D gDiffuseMap : register(t0);
SamplerState gSampler : register(s0);

cbuffer cbPerObject : register(b0)
{
    float4x4 mWorldViewProj;

    float2 uvTiling;
    float2 uvOffset;

    float4 padding;
};

struct VSInput
{
    float3 Pos : POSITION;
    float3 Normal : NORMAL;
    float2 Tex : TEXCOORD;
};

struct PSInput
{
    float4 PosH : SV_POSITION;
    float2 TexC : TEXCOORD;
};

PSInput VS(VSInput vin)
{
    PSInput vout;
    vout.PosH = mul(float4(vin.Pos, 1.0f), mWorldViewProj);
    vout.TexC = vin.Tex * uvTiling + uvOffset;
    return vout;
}

float4 PS(PSInput pin) : SV_Target
{
    float2 uv = pin.TexC * uvTiling + uvOffset;

    float4 tex = gDiffuseMap.Sample(gSampler, uv);

    clip(tex.a - 0.1f);

    return tex;
}