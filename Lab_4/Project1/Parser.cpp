#include "Parser.h"
#include "Vertex.h"
#define NOMINMAX
#include <windows.h>
#include <fstream>
#include <vector>
#include <string>
#include <algorithm>
#include <unordered_map>

using namespace DirectX;

bool LoadOBJ(
    const std::string& filename,
    std::vector<Vertex>& outVertices,
    std::vector<uint32_t>& outIndices,
    std::vector<Submesh>& outSubmeshes)
{
    outSubmeshes.clear();
    std::vector<Submesh> submeshes;
    std::string currentMaterial = "";
    uint32_t currentStartIndex = 0;

    std::ifstream file(filename);
    if (!file.is_open())
        return false;

    constexpr float OBJ_SCALE = 0.01f;

    std::vector<XMFLOAT3> positions;
    std::vector<XMFLOAT3> normals;
    std::vector<XMFLOAT2> texcoords;

    std::string line;

    while (std::getline(file, line))
    {
        if (line.rfind("v ", 0) == 0)
        {
            XMFLOAT3 p;
            sscanf_s(line.c_str(), "v %f %f %f", &p.x, &p.y, &p.z);

            p.x *= OBJ_SCALE;
            p.y *= OBJ_SCALE;
            p.z *= OBJ_SCALE;

            positions.push_back(p);
        }
        else if (line.rfind("vt ", 0) == 0)
        {
            XMFLOAT2 uv;
            sscanf_s(line.c_str(), "vt %f %f", &uv.x, &uv.y);
            uv.y = 1.0f - uv.y;
            texcoords.push_back(uv);
        }
        else if (line.rfind("vn ", 0) == 0)
        {
            XMFLOAT3 n;
            sscanf_s(line.c_str(), "vn %f %f %f", &n.x, &n.y, &n.z);
            normals.push_back(n);
        }

        else if (line.rfind("usemtl ", 0) == 0)
        {
            // если уже был материал Ч закрываем предыдущий submesh
            if (!currentMaterial.empty())
            {
                Submesh sm;
                sm.MaterialName = currentMaterial;
                sm.IndexStart = currentStartIndex;
                sm.IndexCount = (uint32_t)outIndices.size() - currentStartIndex;
                outSubmeshes.push_back(sm);
            }

            currentMaterial = line.substr(7);
            currentStartIndex = (uint32_t)outIndices.size();
        }

        else if (line.rfind("f ", 0) == 0)
        {
            int pi[3]{}, ti[3]{}, ni[3]{};

            int matched = sscanf_s(line.c_str(),
                "f %d/%d/%d %d/%d/%d %d/%d/%d",
                &pi[0], &ti[0], &ni[0],
                &pi[1], &ti[1], &ni[1],
                &pi[2], &ti[2], &ni[2]);

            if (matched != 9)
                continue;

            for (int i = 0; i < 3; i++)
            {
                Vertex v{};

                int posIndex = pi[i] - 1;
                int texIndex = ti[i] - 1;
                int normIndex = ni[i] - 1;

                if (posIndex >= 0 && posIndex < (int)positions.size())
                    v.position = positions[posIndex];

                if (normIndex >= 0 && normIndex < (int)normals.size())
                    v.normal = normals[normIndex];
                else
                    v.normal = XMFLOAT3(0, 1, 0);

                if (texIndex >= 0 && texIndex < (int)texcoords.size())
                    v.texcoord = texcoords[texIndex];
                else
                    v.texcoord = XMFLOAT2(0, 0);

                outVertices.push_back(v);
                outIndices.push_back((uint32_t)outVertices.size() - 1);
            }
        }
    }

    if (outVertices.empty())
        return false;

    // ==============================
    //        CENTER MODEL
    // ==============================

    XMFLOAT3 minP = outVertices[0].position;
    XMFLOAT3 maxP = outVertices[0].position;

    for (const auto& v : outVertices)
    {
        minP.x = std::min(minP.x, v.position.x);
        minP.y = std::min(minP.y, v.position.y);
        minP.z = std::min(minP.z, v.position.z);

        maxP.x = std::max(maxP.x, v.position.x);
        maxP.y = std::max(maxP.y, v.position.y);
        maxP.z = std::max(maxP.z, v.position.z);
    }

    XMFLOAT3 center =
    {
        (minP.x + maxP.x) * 0.5f,
        (minP.y + maxP.y) * 0.5f,
        (minP.z + maxP.z) * 0.5f
    };

    for (auto& v : outVertices)
    {
        v.position.x -= center.x;
        v.position.y -= center.y;
        v.position.z -= center.z;
    }

    if (!currentMaterial.empty())
    {
        Submesh sm;
        sm.MaterialName = currentMaterial;
        sm.IndexStart = currentStartIndex;
        sm.IndexCount = (uint32_t)outIndices.size() - currentStartIndex;
        outSubmeshes.push_back(sm);
    }

    return true;
}

bool LoadMTL(
    const std::string& filename,
    std::vector<ParsedMaterial>& materials)
{
    std::ifstream file(filename);
    if (!file.is_open())
        return false;

    std::string line;
    ParsedMaterial current;

    while (std::getline(file, line))
    {
        if (line.rfind("newmtl ", 0) == 0)
        {
            if (!current.Name.empty())
                materials.push_back(current);

            current = ParsedMaterial{};
            current.Name = line.substr(7);
        }
        else if (line.rfind("map_Kd ", 0) == 0)
        {
            current.DiffuseMap = line.substr(7);
        }
    }

    if (!current.Name.empty())
        materials.push_back(current);

    return true;
}