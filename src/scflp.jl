# Stochastic Competitive Facility Location Problem (SCFLP) -- Main Entry Point
#
# Problem:
#   A leader opens p facilities to maximize captured demand under competition
#   from a follower who opens r facilities after observing the leader's decision.
#   Customer i patronizes the facility (leader or follower) with the highest utility.
#   Utility u_{ij} = Utility_Biesinger(d_{ij}) or Utility_Qi(d_{ij}) depending on dataset.
#
# Formulations (controlled by param "mode"):
#   ZLP           (B&C+EF)  -- extended formulation with z variables
#   OldSubmodular (B&C+SF)  -- classic submodular cut formulation
#   NewSubmodular (B&C+GSF) -- generalized submodular cut formulation
#
# Usage Example:
# julia src/scflp.jl fn=data/Biesinger/111_n100_std p=5 r=10 data=Biesinger mode=NewSubmodular is_visualization=0 beta=0.1 solver=cplex timelimit=7200 gap=0.0  
# Parameters (see param.jl for full list):
#   fn                path to the instance data file
#   p                 number of leader facilities to open
#   r                 number of follower facilities to open
#   data              dataset format: Qi | Biesinger
#   mode              formulation:  OldSubmodular | NewSubmodular | ZLP 
#   is_visualization   whether to print visualization information under partially binary logit (PBL) rule  (default: 0)
#   beta              the sensitivity of the customer to the distance: u_{ij} = exp(-beta * d_{ij}) under PBL rule (default: 0.1)
#   solver            solver: cplex
#   timelimit         time limit in seconds (default: 7200)
#   gap               MIP optimality gap tolerance (default: 0.0)


# Include internal dependency modules
include("startup.jl")
include("param.jl")
include("read_data.jl")
include("model.jl")
include("cuts_prep.jl")
include("cuts_each.jl")

push!(LOAD_PATH, ".")


function scflp(param)

	p = param._int["p"]
	r = param._int["r"]

	if param._string["data"] == "Qi"
		utility, demand = ReadScflp_Qi(param._string["fn"])
	elseif param._string["data"] == "Biesinger"
        utility, demand = ReadScflp_Biesinger(param._string["fn"], param._float["beta"])
	else
		println("Unknown instance data !")
	end

	nClient = size(utility, 1)
	nFacility = size(utility, 2)

	stat = Stat()
	mode = param._string["mode"]
	model, scflp, dict_subsetF, dict_setL = BuildModel(mode, nClient, nFacility, utility, demand, p, r, false)
    # set solver parameters
    set_time_limit_sec(model, param._float["timelimit"])
	
	start_x_vals, start_z_vals = nothing, nothing
	stat.AllTime["start"] = time() 
	status = true

	# set start value for MIP 
    if param._bool["is_start_value"]
		if start_x_vals === nothing

            # Solve PMP without follower (r=p) to construct a start value x
			status, solutionX, objPMP_min,_ = Benders_PMP(stat, demand, -utility, p, nClient, nFacility; dict_setL=nothing)
            start_solX = solutionX 
            start_x_vals = zeros(nFacility)
            start_x_vals[start_solX] .= 1

		end

		if scflp.z !== nothing
			if start_z_vals === nothing
				start_z_vals, _ = GetZvalue(start_x_vals, utility, nClient, nFacility)
			end
		end 
		# Set start values
		set_start_value.(scflp.x, start_x_vals)
		if scflp.z !== nothing
			set_start_value.(scflp.z, start_z_vals)
		end
	end

	add_callback_cuts(model, stat, scflp, nClient, nFacility, utility, demand, p, r, param, dict_subsetF, dict_setL)

    if param._float["timelimit"] - (time() - stat.AllTime["start"]) < 1
        return model, stat, nothing 
    else
        optimize!(model)

    	valueX = nothing
		if primal_status(model) == MOI.FEASIBLE_POINT
			valueX = value.(scflp.x)
        	valueeta = value.(scflp.eta)
        	is_frac_sol = !all(isinteger.(valueX))

		end

        # Extract leader and follower solutions and compute objective
        if primal_status(model) == MOI.FEASIBLE_POINT 

            val_piX = [j for j in 1:nFacility if round.(Int, value.(scflp.x)[j]) == 1]
            valueeta = value.(scflp.eta)
            obj = sum(valueeta)

            mat_d = nothing
            if mode == "ZLP"
                indIs = GetSortedIndex(utility; dim=1, val_rev=true)
                utility_3d = reshape(utility, nClient, nFacility, 1)
                mat_d = utility_3d ./ (utility_3d .+ permutedims(utility_3d, (1, 3, 2)))
            end

            if mode == "ZLP"
                # Given x*, assign z*[i,j]=1 to the highest-utility open facility for each customer
                z_fea, Z_nonzero = GetZvalue(valueX, utility, nClient, nFacility)
                ratio = [sum(z_fea[i, j] * mat_d[i, k, j] for j in Z_nonzero[i]) for i in 1:nClient, k in 1:nFacility]
            else
                z_fea = nothing
                ratio = utility ./ (utility .+ maximum(utility[:, val_piX], dims=2))
            end

            # Solve follower PMP to compute a lower bound on the objective
            _, val_piY, objPMP_min = Benders_PMP(stat, demand, -ratio, r, nClient, nFacility)

            if param._bool["is_visualization"]

            println("Solution X: $val_piX")
            println("Solution Y: $val_piY")


            # ==================== Compute per-facility captured demand ====================

            # Initialize per-facility demand accumulators
            leader_captured = zeros(Float64, nFacility)
            follower_captured = zeros(Float64, nFacility)

            for i in 1:nClient
                # Find the highest-utility leader facility for customer i
                max_leader_utility = -Inf
                nearest_leader = 0
                for j in val_piX
                    if utility[i, j] > max_leader_utility
                        max_leader_utility = utility[i, j]
                        nearest_leader = j
                    end
                end

                # Find the highest-utility follower facility for customer i
                max_follower_utility = -Inf
                nearest_follower = 0
                for k in val_piY
                    if utility[i, k] > max_follower_utility
                        max_follower_utility = utility[i, k]
                        nearest_follower = k
                    end
                end

                # Compute customer i's probability of patronizing the leader: h_i = u_X / (u_X + u_Y)
                h_i = max_leader_utility / (max_leader_utility + max_follower_utility)

                # Allocate customer i's demand between leader and follower
                leader_demand_i = demand[i] * h_i
                follower_demand_i = demand[i] * (1 - h_i)

                # Accumulate demand to the respective facilities
                leader_captured[nearest_leader] += leader_demand_i
                follower_captured[nearest_follower] += follower_demand_i
            end

            # Extract captured demand for open facilities
            leader_capture_demand = [leader_captured[j] for j in val_piX]
            follower_capture_demand = [follower_captured[k] for k in val_piY]

            # Print per-facility demand summary
            println("\nleader_capture_demand: $leader_capture_demand")
            println("follower_capture_demand: $follower_capture_demand")

            println("\n========== Summary ==========")
            println("Total Demand: $(sum(demand))")
            println("Total Leader Captured: $(sum(leader_capture_demand))")
            println("Total Follower Captured: $(sum(follower_capture_demand))")
        end
        end


        return status, model, stat, valueX
    end
end

param = read_param(ARGS) #input indetail
EPS = param._float["EPS"]
EPS_vio = param._float["EPS_vio"]
TIME_LIMITS = param._float["timelimit"]

# Precompile
function main(param)
    model = SelectSolver("Cplex")
    if param._string["data"] == "Qi"
        utility, demand = ReadScflp_Qi(param._string["fn"])
    elseif param._string["data"] == "Biesinger"
        utility, demand = ReadScflp_Biesinger(param._string["fn"], param._float["beta"])
    end
    nClient = size(utility, 1)
	nFacility = size(utility, 2)
	p=1 
	r=1
    val_x = zeros(nFacility)
    val_z = zeros(nClient, nFacility)
	val_eta = 0
    vals = SCFLP(val_x, val_z, val_eta)
    stat = Stat()
    mode = param._string["mode"]
    model, scflp, dict_subsetF, dict_setL = BuildModel(mode, nClient, nFacility, utility, demand, p, r, false)
    
    CutVector = Vector{ScalarConstraint{AffExpr,MathOptInterface.LessThan{Float64}}}(undef, 1)
    
    set_silent(model)  # suppress solver log output
    time_left_for_MILP = 1
    indIs = ones(Int, size(utility))
    mat_d = ones(Int, nClient, nFacility, nFacility)
	ratio = ones(Int, nClient, nFacility)
    Benders_PMP(stat, demand, -ratio, r, nClient, nFacility)
    cut_info = BuildCuts(scflp, vals, "phase1", nClient, nFacility, utility, demand, p, r, CutVector, stat, dict_subsetF, dict_setL; is_lazy=false, is_frac=true, dict_cons=nothing, dict_coef=nothing, model=model, mat_d=mat_d, indIs=indIs)
end

main(param)

result_data = scflp(param) 

if result_data[1] == "stopped"
    status, fea_sol, dict_setL, UB_1, LB_1, time_1, model, stat = result_data
    @printf("\n@PrintInfos: Stopped in pahse one\n")
    @printf("Solve Time: %.2f sec\n", time_1)
    @printf("Objective Value: %.6f\n", LB_1)
    @printf("Current gap: %.2f %%\n", (UB_1 - LB_1) / UB_1 * 100)
    @printf("Best Bound: %f\n", UB_1)
    @printf("Best Integer: %f\n", LB_1)
    PrintStat(stat; obj=LB_1)
else
    status, model, result_stat, valueX = result_data
    PrintInfos(model)
    obj = nothing
    if primal_status(model) == MOI.FEASIBLE_POINT
        obj = objective_value(model)
    end
    PrintStat(result_stat; obj=obj)
end


