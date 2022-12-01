
include("./util.jl")

using Z3
using Z3: ExprAllocated

function run_solver(bounds, versions, latest_versions)
    ctx = Context()

    nv_to_const = Dict{NameAndVersion, ExprAllocated}()
    for (nv, bounds) in bounds
        nv_to_const[nv] = bool_const(ctx, nv.name * "-" * show_version_number(nv.version))
    end

    s = Optimize(ctx)

    # Add the latest version of every package
    for nv in latest_versions
        add(s, nv_to_const[nv] == true)
    end

    # Every package we just added must be 1-resolvable
    for nv in latest_versions
        relevant_bounds = bounds[nv]
        for (dep_name, specs) in relevant_bounds
            if dep_name == "julia"; continue; end
            if !haskey(versions, dep_name); continue; end

            compatible_versions = filter(v -> all(spec -> in(v, spec), specs), versions[dep_name])
            if length(compatible_versions) == 0
                # Guess nv isn't resolvable at all
                @warn "$nv: Couldn't find a compatible version for $dep_name with specs $specs (available: $(versions[dep_name]))"
            else
                add(s, reduce(or, [nv_to_const[NameAndVersion(dep_name, v)] for v in compatible_versions]))
            end
        end
    end

    # p = Params(ctx)
    # set(p, "priority", "pareto")
    # set(s, p)
    h = minimize(s, sum([ite(c, int_val(ctx, 1), int_val(ctx, 0)) for (_, c) in nv_to_const]))

    if Z3.sat == check(s)
        println("Finished check! Lower: $(lower(s, h)). Upper: $(upper(s, h))")
        return (ctx, s, nv_to_const, get_model(s));
    else
        println("Couldn't find solution :(")
        return (ctx, s, nothing, nothing);
    end
end
