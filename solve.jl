
using TOML: parsefile


function name_to_path(registry_path::String)::Dict{String, String}
    registry = parsefile(joinpath(registry_path, "Registry.toml"))

    nameToPath = Dict()
    for (uuid, info) in registry["packages"]
        nameToPath[info["name"]] = info["path"]
    end
    return nameToPath
end

function name_to_version_info(registry_path::String)
    nameToPath = name_to_path(registry_path)

    nameToVersionInfo = Dict()
    for (name, path) in nameToPath
        nameToVersionInfo[name] = sort(map(VersionNumber, collect(keys(parsefile(joinpath(registry_path, path, "Versions.toml"))))))
    end
    return nameToVersionInfo
end

function solve(name::String)

end
