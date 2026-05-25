"""
    add_callback_cuts(model, stat, scflp, ...)

Register lazy constraint and (optionally) user cut callbacks on the model.
Precomputes mode-specific data (mat_d for ZLP, indIs for submodular modes)
shared across all callback invocations.
"""
function add_callback_cuts(model, stat, scflp, nClient, nFacility, utility, demand, p, r, param, dict_subsetF, dict_setL)
	mode = param._string["mode"]
	mat_d = nothing

	# Precompute ratio matrix mat_d[i,k,j] = u_{ik} / (u_{ij} + u_{ik}) for ZLP,
	# or facility sort order indIs for submodular modes
	if mode == "ZLP"
		utility_3d = reshape(utility, nClient, nFacility, 1)
		mat_d = utility_3d ./ (utility_3d .+ permutedims(utility_3d, (1, 3, 2)))
		indIs = nothing
	else
		indIs = GetSortedIndex(utility; dim = 1, val_rev = true)
	end

	CutVector = Vector{ScalarConstraint{AffExpr, MathOptInterface.LessThan{Float64}}}(undef, 1)

	# Define lazy constraint and user cut callbacks, both delegating to CallbackCommon
	function Cuts_LC(cb_data)
		is_lazy = true
        CallbackCommon(cb_data, is_lazy, model, param, scflp, nClient, nFacility, utility, demand, p, r, CutVector, stat, dict_subsetF, dict_setL; mat_d, indIs)
	end

	function Cuts_UC(cb_data)
		is_lazy = false
        CallbackCommon(cb_data, is_lazy, model, param, scflp, nClient, nFacility, utility, demand, p, r, CutVector, stat, dict_subsetF, dict_setL; mat_d, indIs)
	end

	MOI.set(model, MOI.LazyConstraintCallback(), Cuts_LC)

	if param._bool["is_usercut"] == 1
		MOI.set(model, MOI.UserCutCallback(), Cuts_UC)
	end

end

"""
    CallbackCommon(cb_data, is_lazy, model, param, scflp, ...)

Shared logic for both lazy constraint and user cut callbacks.
Queries the current node count, incumbent solution, and variable values from CPLEX,
then calls BuildCuts to generate violated cuts and submits them via SubmitCuts_CB.
Skips user cuts at sub-nodes when uc_only_rootnode is enabled.
"""
function CallbackCommon(cb_data, is_lazy, model, param, scflp, nClient, nFacility, utility, demand, p, r, CutVector, stat, dict_subsetF, dict_setL; mat_d, indIs)
	mode = param._string["mode"]
	nodecount = Ref{CPXLONG}()
	# Query current node count to distinguish root node (r) from sub-nodes (s)
	if param._string["solver"] == "cplex"
		status = CPXcallbackgetinfolong(cb_data, CPXCALLBACKINFO_NODECOUNT, nodecount)
		@assert status == 0
	end

	num_node = nodecount[]
	str_node = num_node == 0 ? "r" : "s"
	str_cbstage = is_lazy ? "LC" : "UC"
	phase = str_node * str_cbstage

	# Allocate buffers for querying incumbent solution from CPLEX
	valueP = Ref{Cdouble}()
	if mode == "ZLP"
		x_p = Vector{Cdouble}(undef, nFacility + nClient * nFacility + 1)
	else
		x_p = Vector{Cdouble}(undef, nFacility + 1)
	end
	obj_p = Ref{Cdouble}()

	# Retrieve current LP relaxation values
	x_vals = callback_value.(cb_data, scflp.x)
	eta_vals = callback_value.(cb_data, scflp.eta)
	if scflp.z !== nothing
		z_vals = callback_value.(cb_data, scflp.z)
	else
		z_vals = nothing
	end
	# Query best bound and incumbent objective from CPLEX
	if param._string["solver"] == "cplex"
		ret = CPXcallbackgetinfodbl(cb_data, CPXCALLBACKINFO_BEST_BND, valueP)
		if mode == "ZLP"
			ret = CPXcallbackgetincumbent(cb_data, x_p, 0, nFacility + nClient * nFacility, obj_p)
		else
			ret = CPXcallbackgetincumbent(cb_data, x_p, 0, nFacility, obj_p)
		end
	end
	
	best_bound = valueP[]
	best_integer = obj_p[]

	# Record root node bounds for reporting
	if num_node == 0
		stat.Bound["root_best_bound"] = best_bound
		stat.Bound["root_best_integer"] = best_integer
	end
	

	vals = SCFLP(x_vals, z_vals, eta_vals)
	uc_only_rootnode = param._bool["uc_only_rootnode"]
	#Do not add user cut only when uc_only_rootnode=1 and trigger user cut and at subnode

	if (!(uc_only_rootnode && (!is_lazy) && (num_node > 0)))
        cut_info = BuildCuts(scflp, vals, phase, nClient, nFacility, utility, demand, p, r, CutVector, stat, dict_subsetF, dict_setL; is_lazy=is_lazy, is_frac=!is_lazy, mat_d, indIs)
		Record(stat, cut_info, phase; best_bound = best_bound, best_integer = best_integer, node = num_node)
		SubmitCuts_CB(model, CutVector, cb_data, is_lazy)
	end
end

"""
    BuildCuts(scflp, vals, phase, nClient, nFacility, utility, demand, p, r, ...)

Generate and collect violated cuts for the current LP/MIP solution `vals`.
Dispatches to the appropriate separation routine based on `mode`:

| mode             | algorithm | description                                                        |
|:-----------------|:----------|:-------------------------------------------------------------------|
| "ZLP"            | B&C+EF    | B&C based on the extended formulation (EF); computes ratio         |
|                  |           | coefficients from z values and solves the follower PMP via Benders.|
| "OldSubmodular"  | B&C+SF    | B&C based on the classic submodular formulation (SF); evaluates    |
|                  |           | submodular cuts over the stored follower set F, then calls PMP.    |
| "NewSubmodular"  | B&C+GSF   | B&C based on the generalized submodular formulation (GSF); uses    |
|                  |           | the linearized S-cut parameterized by K = FindMaxK(x), then falls  |
|                  |           | back to PMP for fractional points when no S-cut is violated.       |

Cuts are pushed into CutVector; statistics are recorded in cut_info.
		# Compute ratio d_{ik} = sum_j z*_{ij} * u_{ik}/(u_{ij}+u_{ik}) for the separation problem
"""
function BuildCuts(scflp, vals, phase, nClient, nFacility, utility, demand, p, r, CutVector, stat, dict_subsetF, dict_setL; is_lazy=false, is_frac=false, dict_cons=nothing, dict_coef=nothing, model=nothing, mat_d, indIs)
	EPS = param._float["EPS"]
	mode = param._string["mode"]
	cut_info = Dict(cutname => Stat_Cut([phase]) for cutname in [mode, "PMP"])
	cutname = mode
	status = "optimal"
	flag_cut_vio = false

	sum_demand = sum(demand[i] for i in 1:nClient)

	if mode == "ZLP"
		start = time()
		if is_frac == false
			solutionX_nonzero = [j for j in 1:nFacility if (vals.x)[j] > EPS]

			ind_I, ind_J, val_z = findnz(sparse(vals.z))
			Z_nonzero = [[ind_J[j] for j in 1:length(ind_J) if ind_I[j] == i] for i in 1:nClient]
			ratio = [sum(vals.z[i, j] * mat_d[i, k, j] for j in Z_nonzero[i]) for i in 1:nClient, k in 1:nFacility]
		else
			ind_I, ind_J, val_z = findnz(sparse(vals.z))
			Z_nonzero = [[ind_J[j] for j in 1:length(ind_J) if ind_I[j] == i && val_z[j] > EPS] for i in 1:nClient]
			
			for i in 1:nClient
				if isempty(Z_nonzero[i]) Z_nonzero[i] = [1]
				end
			end

			ratio = [sum(vals.z[i, j] * mat_d[i, k, j] for j in Z_nonzero[i]) for i in 1:nClient, k in 1:nFacility]
		end
		# Solve follower PMP to find a high-quality feasible Y
		start_PMP = time()
            status, solutionY, objPMP_min = Benders_PMP(stat, demand, -ratio, r, nClient, nFacility)
			objPMP = -objPMP_min
			cut_info["PMP"].Time[phase] += time() - start_PMP
			cut_info["PMP"].Num[phase] += 1
		# Check if the ZLP cut is violated: eta > sum_demand - objPMP
		if status == "optimal"
			for Y in [solutionY]
				accumulated = sum_demand - objPMP
				vio = (vals.eta) - accumulated
				if vio > EPS_vio
					flag_cut_vio = true
					break
				end
			end
		end
		# Build and register the violated ZLP cut
		if flag_cut_vio
			solutionY_max = maximum(utility[:, solutionY], dims = 2)
			ratio = utility ./ (utility .+ solutionY_max)
			cons = @build_constraint((scflp.eta) <= dot(demand, [dot(ratio[i, :], (scflp.z)[i, :]) for i in 1:nClient]))
			cut_info[cutname].Num[phase] += 1
			push!(CutVector, cons)
            if !isnothing(dict_cons) && !isnothing(model)
                Y_key = solutionY
                dict_cons[Y_key] = add_constraint(model, cons)
            end
		end

		duration = time() - start
		cut_info[cutname].Time[phase] += duration

	# --- OldSubmodular (B&C+SF) ---
	elseif mode == "OldSubmodular"
		start = time()
		solutionX = []
		solutionY = []
		numF = length(dict_subsetF)
		is_PMP = true
        is_add_all_yinF = param._bool["is_add_all_yinF"]
		sum_demand = sum(demand[i] for i in 1:nClient)
		min_rhs_smod = sum_demand
		solutionX_nonzero = [j for j in 1:nFacility if (vals.x)[j] > EPS]

		# Evaluate submodular function f(x*, y) for each Y in the stored follower set F
		vec_Submodular = zeros(numF)
		if is_frac == false
			solutionX = [j for j in 1:nFacility if abs(vals.x[j] - 1) < EPS]
			for q in eachindex(dict_subsetF)
				y_ind = [dict_subsetF[q][findmax(utility[i, dict_subsetF[q]])[2]] for i in 1:nClient]
				vec_Submodular[q] = Cal_OldSubmodular(solutionX, y_ind, utility, demand)
			end
		else
            indices = sortperm(vals.x, rev=true)
            x_prime = zeros(Int, nFacility)
            x_prime[indices[1:p]] .= 1
            solutionX = [j for j in 1:nFacility if abs(x_prime[j] - 1) < EPS] 
			
            for q in eachindex(dict_subsetF)
				y_ind = [dict_subsetF[q][findmax(utility[i, dict_subsetF[q]])[2]] for i in 1:nClient]
				vec_Submodular[q] =
					Cal_OldSubmodular(solutionX, y_ind, utility, demand) +
					(isempty(intersect(setdiff(1:nClient, solutionX), solutionX_nonzero)) ? 0 : sum(Gain_marginal(solutionX, y_ind, k, utility, demand) * vals.x[k] for k in intersect(setdiff(1:nClient, solutionX), solutionX_nonzero)))
			end 
			# Handle the edge case where S = emptyset by appending a fallback entry
            if vals.eta <= min_rhs_smod + EPS_vio
                solutionX = Int64[]
                for q in eachindex(dict_subsetF)
                    y_ind = [dict_subsetF[q][findmax(utility[i, dict_subsetF[q]])[2]] for i in 1:nClient]
                    vec_Submodular[q] =
                        Cal_OldSubmodular(solutionX, y_ind, utility, demand) +
                        (isempty(intersect(setdiff(1:nClient, solutionX), solutionX_nonzero)) ? 0 : sum(Gain_marginal(solutionX, y_ind, k, utility, demand) * vals.x[k] for k in intersect(setdiff(1:nClient, solutionX), solutionX_nonzero)))
                end
            end
		end
		# Check violation and add submodular cut for each (or the most violated) Y in F
        if (!isempty(vec_Submodular))
            if is_add_all_yinF
                for q in eachindex(dict_subsetF)
                    min_index = q
                    min_rhs_smod = vec_Submodular[min_index]
                    solutionY = dict_subsetF[min_index]
                    if vals.eta > min_rhs_smod + EPS_vio
                        y_ind = [solutionY[findmax(utility[i, solutionY])[2]] for i in 1:nClient]
                        cons = @build_constraint(scflp.eta <= Cal_OldSubmodular(solutionX, y_ind, utility, demand) + sum(Gain_marginal(solutionX, y_ind, k, utility, demand) * scflp.x[k] for k in setdiff(1:nClient, solutionX)))
                        cut_info[cutname].Num[phase] += 1
                        push!(CutVector, cons)
                        is_PMP = false
                        if !isnothing(dict_cons) && !isnothing(model)
                            Y_key = solutionY
                            if !haskey(dict_cons, Y_key)
                                dict_cons[Y_key] = Dict()
                            end
                            dict_cons[Y_key][solutionX] = add_constraint(model, cons)
                        end
                    end
                end
            else
			# Select only the most violated cut among all Y in F
                min_rhs_smod, min_index = findmin(vec_Submodular)
                solutionY = dict_subsetF[min_index]
                if vals.eta > min_rhs_smod + EPS_vio
                    y_ind = [solutionY[findmax(utility[i, solutionY])[2]] for i in 1:nClient]
                    cons = @build_constraint(scflp.eta <= Cal_OldSubmodular(solutionX, y_ind, utility, demand) + sum(Gain_marginal(solutionX, y_ind, k, utility, demand) * scflp.x[k] for k in setdiff(1:nClient, solutionX)))
                    cut_info[cutname].Num[phase] += 1
                    push!(CutVector, cons)
                    is_PMP = false
                    if !isnothing(dict_cons) && !isnothing(model)
                        Y_key = solutionY
                        if !haskey(dict_cons, Y_key)
                            dict_cons[Y_key] = Dict()
                        end
                        dict_cons[Y_key][solutionX] = add_constraint(model, cons)
                    end
                end
            end
        end

		# No cut found from F: solve PMP to find a new Y and add it to F
		if is_PMP && is_frac == false
			ratio = utility ./ (utility .+ [maximum(utility[i, j] * vals.x[j] for j in solutionX_nonzero) for i in 1:nClient])
			start_PMP = time()
                status, solutionY, objPMP_min = Benders_PMP(stat, demand, -ratio, r, nClient, nFacility)
				objPMP = -objPMP_min
				cut_info["PMP"].Time[phase] += time() - start_PMP
				cut_info["PMP"].Num[phase] += 1
			accumulated = sum_demand - objPMP
			if status == "optimal"
			# Violation confirmed: add new Y to F and build the submodular cut
				if vals.eta - accumulated > EPS_vio
					dict_subsetF[numF+1] = solutionY
					y_ind = [solutionY[findmax(utility[i, solutionY])[2]] for i in 1:nClient]
					cons = @build_constraint(scflp.eta <= Cal_OldSubmodular(solutionX, y_ind, utility, demand) + sum(Gain_marginal(solutionX, y_ind, k, utility, demand) * scflp.x[k] for k in setdiff(1:nClient, solutionX)))
					cut_info[cutname].Num[phase] += 1
					push!(CutVector, cons)
                    if !isnothing(dict_cons) && !isnothing(model)
                        Y_key = dict_subsetF[numF+1]
                        if !haskey(dict_cons, Y_key)
                            dict_cons[Y_key] = Dict()
                        end
                        dict_cons[Y_key][solutionX] = add_constraint(model, cons)
                    end
				end
			end
		end

		duration = time() - start
		cut_info[cutname].Time[phase] += duration
	# --- NewSubmodular (B&C+GSF) ---
	elseif mode == "NewSubmodular"
		start = time()
		solutionX = []
		solutionY = []
		numF = length(dict_subsetF)
		is_PMP = true
		is_sift = param._bool["is_S_cut"]
		K = FindMaxK(indIs, nClient, nFacility, vals.x)
		is_add_all_yinF = param._bool["is_add_all_yinF"]

		# Lazy cut branch: x* is integer
		if is_frac == false
			solutionX = [j for j in 1:nFacility if vals.x[j] == 1]

			K = FindMaxK(indIs, nClient, nFacility, vals.x)
			if is_sift
				numF = length(dict_subsetF)
				accumulated = zeros(numF + 1)
				val = zeros(numF, nClient)
				if is_add_all_yinF
					for q in eachindex(dict_subsetF)
						for i in 1:nClient
							C_y = maximum(utility[i, dict_subsetF[q]])
							val[q, i] = utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y)
						end
						accumulated[q] = vals.eta - sum(demand[i] * val[q, i] for i in 1:nClient)
						if accumulated[q] > EPS_vio	
							C_y = [maximum(utility[i, dict_subsetF[q]]) for i in 1:nClient]
							cons = @build_constraint(
								scflp.eta <=
								-sum(demand[i] * (utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y[i]) .- utility[i, indIs[i, 1:K[i]-1]] ./ (utility[i, indIs[i, 1:K[i]-1]] .+ C_y[i]))' * scflp.x[indIs[i, 1:K[i]-1]] for i in 1:nClient) +
								sum(demand[i] * utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y[i]) for i in 1:nClient)
							)
							cut_info[cutname].Num[phase] += 1
							push!(CutVector, cons)

                            is_PMP = false 
                            if !isnothing(dict_cons) && !isnothing(model)
                                Y_key = dict_subsetF[q]
                                if !haskey(dict_cons, Y_key)
                                    dict_cons[Y_key] = Dict()
                                end
                                dict_cons[Y_key][K] = add_constraint(model, cons)
                            end
						end
					end
				else
					for q in eachindex(dict_subsetF)
						for i in 1:nClient
							C_y = maximum(utility[i, dict_subsetF[q]])
							val[q, i] = utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y)
						end
						accumulated[q] = vals.eta - sum(demand[i] * val[q, i] for i in 1:nClient)
					end
					viomin, qmin = findmax(accumulated)
					if viomin > EPS_vio
						C_y = [maximum(utility[i, dict_subsetF[qmin]]) for i in 1:nClient]
						cons = @build_constraint(
							scflp.eta <=
							-sum(demand[i] * (utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y[i]) .- utility[i, indIs[i, 1:K[i]-1]] ./ (utility[i, indIs[i, 1:K[i]-1]] .+ C_y[i]))' * scflp.x[indIs[i, 1:K[i]-1]] for i in 1:nClient) +
							sum(demand[i] * utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y[i]) for i in 1:nClient)
						)
						cut_info[cutname].Num[phase] += 1
						push!(CutVector, cons)

                        is_PMP = false
						if !isnothing(dict_cons) && !isnothing(model)
                            Y_key = dict_subsetF[qmin]
                            if !haskey(dict_cons, Y_key)
                                dict_cons[Y_key] = Dict()
                            end
                            dict_cons[Y_key][K] = add_constraint(model, cons) 
                        end
					end
				end
			end

			# Fallback: PMP-based cut 
			if is_PMP
				vec_u_k_star = [utility[i, indIs[i, K[i]]] for i in 1:nClient]
				ratio = utility ./ (vec_u_k_star .+ utility)
				start_PMP = time()
					status, solutionY, objPMP_min = Benders_PMP(stat, demand, -ratio, r, nClient, nFacility)
					objPMP = -objPMP_min
					cut_info["PMP"].Time[phase] += time() - start_PMP
					cut_info["PMP"].Num[phase] += 1
				accumulated = sum(demand[i] for i in 1:nClient) - objPMP
				if status == "optimal"
					if vals.eta - accumulated > EPS_vio
						dict_subsetF[numF+1] = solutionY
						y_ind = [solutionY[findmax(utility[i, solutionY])[2]] for i in 1:nClient]
						C_y = [maximum(utility[i, solutionY]) for i in 1:nClient]

                        cons = @build_constraint(
                            scflp.eta <=
                            -sum(demand[i] * (utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y[i]) .- utility[i, indIs[i, 1:K[i]-1]] ./ (utility[i, indIs[i, 1:K[i]-1]] .+ C_y[i]))' * scflp.x[indIs[i, 1:K[i]-1]] for i in 1:nClient) +
                            sum(demand[i] * utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y[i]) for i in 1:nClient)
                        )
                        cut_info[cutname].Num[phase] += 1
                        push!(CutVector, cons)
                        if !isnothing(dict_cons) && !isnothing(model)
                            Y_key = dict_subsetF[numF+1]
                            if !haskey(dict_cons, Y_key)
                                dict_cons[Y_key] = Dict()
                            end
                            dict_cons[Y_key][K] = add_constraint(model, cons)
                        end
					end
				end
			end
		else
			# Compute k_i(x*): index of the binding facility for each customer under the current x*
			solutionX_nonzero_inds = [[j for j in 1:K[i]-1 if vals.x[indIs[i, j]] > EPS] for i in 1:nClient]
			if is_sift
				numF = length(dict_subsetF)
				accumulated = zeros(numF + 1)
				val = zeros(numF, nClient)

				if is_add_all_yinF
					for q in eachindex(dict_subsetF)
						for i in 1:nClient
							C_y = maximum(utility[i, dict_subsetF[q]])
							val[q, i] =
								utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y) -
								(utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y) .- utility[i, indIs[i, 1:K[i]-1]] ./ (utility[i, indIs[i, 1:K[i]-1]] .+ C_y))' * vals.x[indIs[i, 1:K[i]-1]]
						end
						accumulated[q] = vals.eta - sum(demand[i] * val[q, i] for i in 1:nClient)

						if accumulated[q] > EPS_vio
							C_y = [maximum(utility[i, dict_subsetF[q]]) for i in 1:nClient]
							cons = @build_constraint(
								scflp.eta <=
								-sum(demand[i] * (utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y[i]) .- utility[i, indIs[i, 1:K[i]-1]] ./ (utility[i, indIs[i, 1:K[i]-1]] .+ C_y[i]))' * scflp.x[indIs[i, 1:K[i]-1]] for i in 1:nClient) +
								sum(demand[i] * utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y[i]) for i in 1:nClient)
							)
							cut_info[cutname].Num[phase] += 1
							push!(CutVector, cons)

							# Register K in dict_setL if not already present
                            if !any(v -> v == K, values(dict_setL))
                                dict_setL[length(dict_setL)+1] = K
                            end

							is_PMP = false
                            if !isnothing(dict_cons) && !isnothing(model)
                                Y_key = dict_subsetF[q]
                                if !haskey(dict_cons, Y_key)
                                    dict_cons[Y_key] = Dict()
                                end
                                dict_cons[Y_key][K] = add_constraint(model, cons)
                            end
						end
					end
				else
				# Violation check: add S-cut for each Y in F
					for q in eachindex(dict_subsetF)
						for i in 1:nClient
							C_y = maximum(utility[i, dict_subsetF[q]])
							val[q, i] =
								utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y) -
								(utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y) .- utility[i, indIs[i, 1:K[i]-1]] ./ (utility[i, indIs[i, 1:K[i]-1]] .+ C_y))' * vals.x[indIs[i, 1:K[i]-1]]
						end
						accumulated[q] = vals.eta - sum(demand[i] * val[q, i] for i in 1:nClient)
					end
					viomin, qmin = findmax(accumulated)
					if viomin > EPS_vio
						C_y = [maximum(utility[i, dict_subsetF[qmin]]) for i in 1:nClient]
						cons = @build_constraint(
							scflp.eta <=
							-sum(demand[i] * (utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y[i]) .- utility[i, indIs[i, 1:K[i]-1]] ./ (utility[i, indIs[i, 1:K[i]-1]] .+ C_y[i]))' * scflp.x[indIs[i, 1:K[i]-1]] for i in 1:nClient) +
							sum(demand[i] * utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y[i]) for i in 1:nClient)
						)
						cut_info[cutname].Num[phase] += 1
						push!(CutVector, cons)
						
						is_PMP = false
						if !isnothing(dict_cons) && !isnothing(model)
                            Y_key = dict_subsetF[qmin]
                            if !haskey(dict_cons, Y_key)
                                dict_cons[Y_key] = Dict()
                            end
                            dict_cons[Y_key][K] = add_constraint(model, cons)
                        end
					end
				end
			end

			# Fallback: PMP-based cut 
			if is_PMP
				ratio_frac = [
					((1 - (K[i] - 1 == 0 ? 0 : sum(vals.x[indIs[i, k]] for k in 1:K[i]-1))) * utility[i, j]) / (utility[i, indIs[i, K[i]]] + utility[i, j]) +
					(isempty(solutionX_nonzero_inds[i]) ? 0 : sum(vals.x[indIs[i, k]] * utility[i, j] / (utility[i, indIs[i, k]] + utility[i, j]) for k in solutionX_nonzero_inds[i])) for i in 1:nClient, j in 1:nFacility
				]
				# Compute fractional ratio for PMP separation
				start_PMP = time()
					status, solutionY, objPMP_min = Benders_PMP(stat, demand, -ratio_frac, r, nClient, nFacility)
					objPMP = -objPMP_min
					cut_info["PMP"].Time[phase] += time() - start_PMP
					cut_info["PMP"].Num[phase] += 1
				accumulated = sum(demand[i] for i in 1:nClient) - objPMP
				# Violation confirmed: add new Y to F and build the GSF cut
				if status == "optimal"
					if vals.eta - accumulated > EPS_vio
						dict_subsetF[numF+1] = solutionY
						C_y = [maximum(utility[i, solutionY]) for i in 1:nClient]
                        cons = @build_constraint(
                            scflp.eta <=
                            -sum(demand[i] * (utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y[i]) .- utility[i, indIs[i, 1:K[i]-1]] ./ (utility[i, indIs[i, 1:K[i]-1]] .+ C_y[i]))' * scflp.x[indIs[i, 1:K[i]-1]] for i in 1:nClient) +
                            sum(demand[i] * utility[i, indIs[i, K[i]]] / (utility[i, indIs[i, K[i]]] + C_y[i]) for i in 1:nClient)
                        )
                        cut_info[cutname].Num[phase] += 1
                        push!(CutVector, cons)
                        if !isnothing(dict_cons) && !isnothing(model)
                            Y_key = dict_subsetF[numF+1]
                            if !haskey(dict_cons, Y_key)
                                dict_cons[Y_key] = Dict()
                            end
                            dict_cons[Y_key][K] = add_constraint(model, cons)
                        end
					end
				end
			end
		end
		duration = time() - start
		cut_info[cutname].Time[phase] += duration
	else
		@info "unknown mode: $(mode)"
	end
	stat.PMP["last_status"] = status
	return cut_info
end

"""
    Benders_PMP(stat, demand, cost, r, nClient, nFacility; dict_setL)

Solve the follower's p-median problem (PMP) via Benders decomposition.
The objective is min sum_i theta_i subject to sum(y) == r, with Benders cuts
added via lazy/user callbacks (myCallbackPMP_BD).
Cost is scaled by demand before solving: cost[i,j] *= demand[i].
Returns (status, solutionY, objPMP_min, dict_setL).
"""
function Benders_PMP(stat, demand, cost, r, nClient, nFacility; dict_setL=nothing)

	start = time()
	duration = time() - stat.AllTime["start"]
	status = ""

	# Scale cost by demand and sort facilities per customer
	cost = cost .* demand
	V = SortCost(cost)
	model = SelectSolver("Cplex")
	model.ext[:submitted_cuts] = []

	timeleft = TIME_LIMITS - duration
	if timeleft < EPS
		solutionY = zeros(nFacility)
		objPMP_min = 0
		status = "nonsolve"
	else
		# Configure solver and build PMP model variables and constraints
		set_time_limit_sec(model, timeleft)
		set_optimizer_attribute(model, "CPXPARAM_MIP_Tolerances_MIPGap", 0.0)
        set_optimizer_attribute(model, "CPXPARAM_Threads", 1)
		@variable(model, cost[i, V[i, 1]] <= theta[i in 1:nClient] <= cost[i, V[i, nFacility]])
		@variable(model, y[j in 1:nFacility], Bin)
		# Modeled as minimization; caller negates cost so that max capture = -min(-cost)
		@objective(model, Min, sum(theta))
		@constraint(model, pmed_1, sum(y) == r)

		# Register Benders cut callbacks
		function lazyCons(cb_data)
			isLazy = true
			myCallbackPMP_BD(cb_data, model, theta, y, isLazy, V, nClient, nFacility, cost)
        end

		function UserCons(cb_data)
			isLazy = false
			myCallbackPMP_BD(cb_data, model, theta, y, isLazy, V, nClient, nFacility, cost)
        end
           
		MOI.set(model, MOI.LazyConstraintCallback(), lazyCons)
		MOI.set(model, MOI.UserCutCallback(), UserCons)

		set_silent(model)

		optimize!(model)

		# Extract solution
		solutionY = []
		value_theta = nothing  
		if primal_status(model) == MOI.FEASIBLE_POINT
			valueY = round.(Int, value.(y))
			value_theta = value.(theta)
			solutionY = [j for j in 1:nFacility if valueY[j] == 1]
            objPMP_min = sum(value_theta)
		else
			objPMP_min = 0
		end

		if termination_status(model) == MOI.OPTIMAL && primal_status(model) == MOI.FEASIBLE_POINT
			status = "optimal"
		else
			status = "nonoptimal"
		end
		stat.PMP["num"] += 1
		stat.PMP["time"] += time() - start
	end

	return status, solutionY, objPMP_min, dict_setL
end

"""
    myCallbackPMP_BD(cb_data, model, theta, y, isLazy, V, nClient, nFacility, cost)

Benders cut callback for the PMP subproblem (multi-cut variant).
For each customer i, checks whether the current (theta, y) violates the Benders optimality cut
and submits it as a lazy constraint or user cut.
"""
function myCallbackPMP_BD(cb_data, model, theta, y, isLazy, V, nClient, nFacility, cost)
	# Retrieve current variable values from the callback
	theta_vals = callback_value.(cb_data, theta)
	y_vals = callback_value.(cb_data, y)

	maxK = FindMaxK(V, nClient, nFacility, y_vals)

	for i in 1:nClient
		K = maxK[i]
		val = (cost[i, V[i, K]] .- cost[i, V[i, 1:K-1]])' * y_vals[V[i, 1:K-1]]
		accumulated = theta_vals[i] - cost[i, V[i, K]] + val
		# Submit Benders cut if violated
		if accumulated < -EPS
			cut = @build_constraint(theta[i] + (cost[i, V[i, K]] .- cost[i, V[i, 1:K-1]])' * y[V[i, 1:K-1]] >= cost[i, V[i, K]])

			Cons = isLazy == true ? MOI.LazyConstraint : MOI.UserCut
			MOI.submit(model, Cons(cb_data), cut)
		end
	end

end

