#pragma once

#include <vector>
#include <string>
#include "Vertex.h"
#include "Submesh.h"

bool LoadOBJ(
    const std::string& filename,
    std::vector<Vertex>& outVertices,
    std::vector<uint32_t>& outIndices,
    std::vector<Submesh>& outSubmeshes);

struct ParsedMaterial
{
    std::string Name;
    std::string DiffuseMap;
};

bool LoadMTL(
    const std::string& filename,
    std::vector<ParsedMaterial>& materials);