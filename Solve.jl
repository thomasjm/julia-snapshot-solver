
using Combinatorics: combinations
using ProgressMeter
using Z3
using Z3: ExprAllocated, OptimizeAllocated


function show_version_number(vn::VersionNumber)::String
    io = IOBuffer()
    print(io, vn)
    return String(take!(io))
end

function add_nway_resolvability_constraints(versions::VersionsDict, nv_to_const, s::OptimizeAllocated, nvs::Vector{NameAndVersion}, n::Int64)::Int64
    subsets_iterator = combinations(nvs, n)

    num_added = 0

    p = Progress(binomial(length(nvs), n), 1)
    counter = 0

    for subset in subsets_iterator
        # Find the deps shared by all subsets
        shared_deps = reduce(intersect, map(nv -> keys(bounds[nv]), subset))
        if length(shared_deps) == 0
            continue
        end

        # Build up the full set of bounds
        relevant_bounds = Dict{String, Constraints}()
        for nv in subset
            relevant_bounds = merge(vcat, relevant_bounds, bounds[nv])
        end

        constraints_to_add = []
        resolution_failure = false
        for (dep_name, specs) in relevant_bounds
            if !haskey(versions, dep_name); continue; end

            compatible_versions = filter(v -> all([v in spec for spec in specs]), versions[dep_name])
            if length(compatible_versions) == 0
                # Guess this subset isn't resolvable at all
                # @warn "$subset: Couldn't find a compatible version for $dep_name with specs $specs (available: $(versions[dep_name]))"
                resolution_failure = true
                break
            else
                push!(constraints_to_add, reduce(or, [nv_to_const[NameAndVersion(dep_name, v)] for v in compatible_versions]))
            end
        end

        if !resolution_failure
            for c in constraints_to_add
                add(s, c)
                num_added += 1
            end
        end

        counter += 1
        update!(p, counter)
    end

    finish!(p)

    return num_added
end

function has_more_than_n_nontrivial_constraints(nv, bs::Dict{String, Constraints}, n)::Bool
    num_nontrivial = 0
    for (dep_name, constraints) in bs
        if length(constraints) > 0
            num_nontrivial += 1
        end
    end

    return num_nontrivial > n
end

function run_solver(bounds::BoundsDict, versions::VersionsDict, latest_versions::Vector{NameAndVersion})
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

    # Packages with more than 1 dependency?
    latest_versions_with_nontrivial_bounds = filter(nv -> has_more_than_n_nontrivial_constraints(nv, bounds[nv], 0), latest_versions)

    # Every package we just added must be 1-resolvable
    @info "Adding 1-way resolvability constraints ($(binomial(length(latest_versions), 1)) packages)"
    added = add_nway_resolvability_constraints(versions, nv_to_const, s, latest_versions, 1)
    @info "Added $added constraints"

    @info "Adding 2-way resolvability constraints (max possible $(binomial(length(latest_versions_with_nontrivial_bounds), 2)) package subsets)"
    added = add_nway_resolvability_constraints(versions, nv_to_const, s, latest_versions, 2)
    @info "Added $added constraints"

    @info "Ready to solve!"
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
