
include("./BuildDicts.jl")

registry_path = "/home/tom/tools/General/"

julia_version = VersionNumber("1.8")

all_bounds = name_to_bounds(registry_path)
println("Total versions: $(length(all_bounds))")

# Filter all_bounds to compatible julia
bounds = Dict{NameAndVersion, Dict{String, Constraints}}()
for (nv, constraints) in all_bounds
    if haskey(constraints, "julia")
        if all([julia_version in vs for vs in constraints["julia"]])
            bounds[nv] = delete!(constraints, "julia")
        end
    else
        bounds[nv] = constraints
    end
end
println("Versions compatible with Julia $julia_version: $(length(bounds))")

name_to_versions = Dict{String, Vector{VersionNumber}}()
for (nv, constraints) in bounds
    if !haskey(name_to_versions, nv.name)
        name_to_versions[nv.name] = []
    end
    push!(name_to_versions[nv.name], nv.version)
end
latest_versions = Vector{NameAndVersion}()
for (name, versions) in name_to_versions
    push!(latest_versions, NameAndVersion(name, first(findmax(versions))))
end
println("Number of distinct packages: $(length(latest_versions))")

include("./Solve.jl")
(ctx, solver, nv_to_const, model) = run_solver(bounds, name_to_versions, latest_versions)

import Z3
chosen = []
for (nv, c) in nv_to_const
    if is_true(Z3.eval(model, c))
        # println(nv)
        push!(chosen, nv)
    end
end
