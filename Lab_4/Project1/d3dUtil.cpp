#include "d3dUtil.h"
#include "ThrowIfFailed.h"
#include <filesystem>

namespace fs = std::filesystem;

namespace d3dUtil
{
    Microsoft::WRL::ComPtr<ID3DBlob> LoadOrCompileShader(
        const std::wstring& sourceFilename,
        const std::wstring& bytecodeFilename,
        const D3D_SHADER_MACRO* defines,
        const std::string& entrypoint,
        const std::string& target)
    {
        if (fs::exists(bytecodeFilename))
        {
            Microsoft::WRL::ComPtr<ID3DBlob> cachedByteCode = nullptr;
            ThrowIfFailed(D3DReadFileToBlob(bytecodeFilename.c_str(), &cachedByteCode));
            return cachedByteCode;
        }

        Microsoft::WRL::ComPtr<ID3DBlob> byteCode =
            CompileShader(sourceFilename, defines, entrypoint, target);

        fs::create_directories(fs::path(bytecodeFilename).parent_path());
        ThrowIfFailed(D3DWriteBlobToFile(byteCode.Get(), bytecodeFilename.c_str(), TRUE));

        return byteCode;
    }

    Microsoft::WRL::ComPtr<ID3DBlob> CompileShader(
        const std::wstring& filename,
        const D3D_SHADER_MACRO* defines,
        const std::string& entrypoint,
        const std::string& target)
    {
        UINT compileFlags = D3DCOMPILE_ENABLE_STRICTNESS | D3DCOMPILE_WARNINGS_ARE_ERRORS;
#ifdef _DEBUG
        compileFlags |= D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION;
#else
        compileFlags |= D3DCOMPILE_OPTIMIZATION_LEVEL3;
#endif

        Microsoft::WRL::ComPtr<ID3DBlob> byteCode = nullptr;
        Microsoft::WRL::ComPtr<ID3DBlob> errors;

        HRESULT hr = D3DCompileFromFile(
            filename.c_str(),
            defines,
            D3D_COMPILE_STANDARD_FILE_INCLUDE,
            entrypoint.c_str(),
            target.c_str(),
            compileFlags,
            0,
            &byteCode,
            &errors
        );

        if (errors != nullptr)
        {
            std::string errorStr = "Shader Compile Error:\n";
            errorStr += static_cast<char*>(errors->GetBufferPointer());
            OutputDebugStringA(errorStr.c_str());
        }

        if (FAILED(hr))
        {
            if (errors)
            {
                MessageBoxA(
                    0,
                    static_cast<char*>(errors->GetBufferPointer()),
                    "Shader Compile Error",
                    MB_OK);
            }
            ThrowIfFailed(hr);
        }
        return byteCode;
    }

    UINT CalcConstantBufferByteSize(UINT byteSize)
    {
        return (byteSize + 255) & ~255;
    }
}
