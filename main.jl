
include("./BuildDicts.jl")

registry_path = "/home/tom/tools/General/"

latest = name_to_latest_version(registry_path)
versions = name_to_versions(registry_path)
bounds = name_to_bounds(registry_path)
all_versions = keys(bounds)
latest_versions = [NameAndVersion(name, version) for (name, version) in latest]

include("./Solve.jl")
(ctx, solver, nv_to_const, model) = run_solver(bounds, versions, latest_versions)

import Z3
chosen = []
for (nv, c) in nv_to_const
    if is_true(Z3.eval(model, c))
        println(nv)
        push!(chosen, nv)
    end
end
