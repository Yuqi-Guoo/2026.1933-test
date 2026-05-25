"""
    BuildModel(mode, nClient, nFacility, utility, demand, p, r, ContRelax)

Build the SCFLP optimization model for the given formulation mode.

- `mode = "ZLP"`: extended formulation with z variables (z[i,j] = fraction of
  customer i's demand captured by facility j). Adds constraints z[i,j] <= x[j]
  and sum_j z[i,j] == 1 for each customer i.
- `mode = "OldSubmodular"` / `"NewSubmodular"`: submodular-cut formulation with
  only x variables; cuts are added dynamically via callbacks.

In all modes, eta is the single continuous variable representing total captured
demand, and the objective is to maximize eta subject to sum(x) == p.
`ContRelax = true` relaxes binary variables to [0,1] for LP relaxation.
"""
function BuildModel(mode, nClient, nFacility, utility, demand, p, r, ContRelax = false)
	
    # Initialize solver and configure time limit, optimality gap, and thread count
    model = SelectSolver("Cplex")
    set_time_limit_sec(model, param._float["timelimit"])
    set_optimizer_attribute(model, "CPXPARAM_MIP_Tolerances_MIPGap", 0.0)
    set_optimizer_attribute(model, "CPXPARAM_Threads", 1)  # single-threaded for reproducibility

    # Define variables and linking constraints based on formulation mode
    if mode == "ZLP"
        if ContRelax
            @variable(model, 0 <= x[j in 1:nFacility] <= 1)
            @variable(model, 0 <= z[i in 1:nClient, j in 1:nFacility] <= 1)
        else
            @variable(model, x[j in 1:nFacility], Bin)
            @variable(model, 0 <= z[i in 1:nClient, j in 1:nFacility] <= 1)
        end
        @constraint(model, cons_b[i in 1:nClient, j in 1:nFacility], z[i, j] <= x[j])
        @constraint(model, cons_c[i in 1:nClient], sum(z[i, j] for j in 1:nFacility) == 1)
    elseif (mode == "OldSubmodular") || (mode == "NewSubmodular")
        z = nothing 
        if ContRelax
            @variable(model, 0 <= x[j in 1:nFacility] <= 1)
        else
            @variable(model, x[j in 1:nFacility], Bin)
        end
    else
        @info "unknown mode: $(mode)"
    end

    # Objective variable, cardinality constraint, and objective function
    @variable(model, 0 <= eta <= sum(demand))
    @constraint(model, cons_a, sum(x) == p)
    @objective(model, Max, eta)

    # Initialize cut dictionaries for callback use
    dict_subsetF = Dict{Int, Vector{Int}}()
    dict_setL = Dict{Int, Vector{Int}}()

    return model, SCFLP(x, z, eta), dict_subsetF, dict_setL
end
