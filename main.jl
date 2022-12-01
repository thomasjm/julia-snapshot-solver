
include("./BuildDicts.jl")

latest = name_to_latest_version("/home/tom/tools/General/")
versions = name_to_versions("/home/tom/tools/General")
bounds = name_to_bounds("/home/tom/tools/General/")
all_versions = keys(bounds)
latest_versions = [NameAndVersion(name, version) for (name, version) in latest]

include("./Solve.jl")
(ctx, solver, nv_to_const, model) = run_solver(bounds, versions, latest_versions)

import Z3
for (nv, c) in nv_to_const
    println("$nv: $(Z3.eval(model, c))")
end
