#pragma once
#include <d3d12.h>
#include <d3dcompiler.h>
#include <wrl/client.h>
#include <string>
#include <vector>

namespace d3dUtil
{
    Microsoft::WRL::ComPtr<ID3DBlob> LoadOrCompileShader(
        const std::wstring& sourceFilename,
        const std::wstring& bytecodeFilename,
        const D3D_SHADER_MACRO* defines,
        const std::string& entrypoint,
        const std::string& target);

    Microsoft::WRL::ComPtr<ID3DBlob> CompileShader(
        const std::wstring& filename,
        const D3D_SHADER_MACRO* defines,
        const std::string& entrypoint,
        const std::string& target);

    UINT CalcConstantBufferByteSize(UINT byteSize);
}
