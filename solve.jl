
import Pkg

using Base: UUID
using Pkg.Types: VersionRange, VersionSpec
using TOML: parsefile


function name_to_path(registry_path::String)::Dict{String, String}
    registry = parsefile(joinpath(registry_path, "Registry.toml"))

    nameToPath = Dict()
    for (uuid, info) in registry["packages"]
        nameToPath[info["name"]] = info["path"]
    end
    return nameToPath
end

const VersionsDict = Dict{String, Vector{VersionNumber}}
function name_to_versions(registry_path::String)::VersionsDict
    nameToPath = name_to_path(registry_path)

    nameToVersionInfo = Dict()
    for (name, path) in nameToPath
        nameToVersionInfo[name] = joinpath(registry_path, path, "Versions.toml") |> parsefile |> keys |> collect |> (x -> map(VersionNumber, x)) |> sort
    end
    return nameToVersionInfo
end

function name_to_latest_version(registry_path::String)::Dict{String, VersionNumber}
    nameToVersionInfo = name_to_versions(registry_path)

    ret = Dict()
    for (name, versions) in nameToVersionInfo
        ret[name] = first(findmax(versions))
    end
    return ret
end

const Constraints = Vector{Any}
struct NameAndVersion
    name::String
    version::VersionNumber
end
const BoundsDict = Dict{NameAndVersion, Dict{String, Constraints}}
function name_to_bounds(registry_path::String)::BoundsDict
    nameToPath = name_to_path(registry_path)

    nameToVersions = name_to_versions(registry_path)

    nameToBounds = Dict()
    for (name, path) in nameToPath
        # Taken from Pkg.jl/src/Registry/registry_instance.jl
        compat_path = joinpath(registry_path, path, "Compat.toml")
        compat_data_toml = isfile(compat_path) ? parsefile(compat_path) : Dict{String, Any}()
        # The Compat.toml file might have string or vector values
        compat_data_toml = convert(Dict{String, Dict{String, Union{String, Vector{String}}}}, compat_data_toml)
        compat = Dict{VersionRange, Dict{String, VersionSpec}}()
        for (v, data) in compat_data_toml
            vr = VersionRange(v)
            d = Dict{String, VersionSpec}(dep => VersionSpec(vr_dep) for (dep, vr_dep) in data)
            compat[vr] = d
        end

        deps_path = joinpath(registry_path, path, "Deps.toml")
        deps_data_toml = isfile(deps_path) ? parsefile(deps_path) : Dict{String, Any}()
        # But the Deps.toml only have strings as values
        deps_data_toml = convert(Dict{String, Dict{String, String}}, deps_data_toml)
        deps = Dict{VersionRange, Dict{String, UUID}}()
        for (v, data) in deps_data_toml
            vr = VersionRange(v)
            d = Dict{String, UUID}(dep => UUID(uuid) for (dep, uuid) in data)
            deps[vr] = d
        end

        for version in nameToVersions[name]
            spec = NameAndVersion(name, version)

            constraintDict = Dict{String, Constraints}("julia" => [])

            for (range, nameToUuid) in deps
                if in(version, range)
                    for (k, uuid) in nameToUuid
                        constraintDict[k] = []
                    end
                end
            end

            nameToBounds[spec] = constraintDict;

            for (range, nameToConstraint) in compat
                if in(version, range)
                    for (name, constraint) in nameToConstraint
                        push!(nameToBounds[spec][name], constraint)
                    end
                end
            end
        end
    end

    return nameToBounds
end
