"""
    GetSortedIndex(mat; dim, val_rev)

Return a matrix of sorted indices of `mat` along the given dimension.
`dim=1` sorts each row; `dim=2` sorts each column.
`val_rev=true` sorts in descending order.
"""
function GetSortedIndex(mat; dim=1, val_rev=true)
    n = size(mat, 1)
    m = size(mat, 2)
    IndSorted = zeros(Int, n, m)
    if dim == 1
        for i in 1:n
            IndSorted[i, :] = sortperm(mat[i, :], rev=val_rev)
        end
    elseif dim == 2
        for j in 1:m
            IndSorted[:, j] = sortperm(mat[:, j], rev=val_rev)
        end
    end
    return IndSorted
end

"""
    SubmitCuts_CB(model, CutVector, cb_data, is_lazy)

Submit all pending cuts in CutVector via CPLEX callback.
Cuts are submitted as lazy constraints or user cuts depending on `is_lazy`.
"""
function SubmitCuts_CB(model, CutVector, cb_data, is_lazy)
    Cons = is_lazy ? MOI.LazyConstraint : MOI.UserCut
    while length(CutVector) > 1
        cut = pop!(CutVector)
        MOI.submit(model, Cons(cb_data), cut)
    end
end

"""
    SubmitCuts_LP(model, CutVector)

Add all pending cuts in CutVector directly to the model (used for initial cuts outside callbacks).
"""
function SubmitCuts_LP(model, CutVector)
    while length(CutVector) > 1
        cut = pop!(CutVector)
        add_constraint(model, cut)
    end
end

"""
    GetZvalue(x_fea, utility, nClient, nFacility)

Given a feasible x solution, compute the optimal z assignment under the ZLP formulation.
For each customer i, assign z[i,j] = 1 to the highest-utility open facility j (x[j] = 1).
Returns z_fea (nClient x nFacility matrix) and Z_nonzero (list of nonzero column indices per customer).
"""
function GetZvalue(x_fea, utility, nClient, nFacility)
    z_fea = zeros(nClient, nFacility)
    Z_nonzero = [Int[] for _ in 1:nClient]

    # Sort facilities by utility in descending order for each customer
    indIs = GetSortedIndex(utility; dim=1, val_rev=true)

    # Assign each customer to the best open facility
    for i in 1:nClient
        for j in 1:nFacility
            if x_fea[indIs[i, j]] == 1
                z_fea[i, indIs[i, j]] = 1
                push!(Z_nonzero[i], indIs[i, j])
                break
            end
        end
    end

    return z_fea, Z_nonzero
end

"""
    is_integer_vector(x)

Return true if all entries of x are within EPS of an integer.
"""
function is_integer_vector(x::Vector{T}) where T
    return all(abs.(x .- round.(x)) .< EPS)
end

"""
    SortCost(cost)

Return a matrix V where V[i,:] is the permutation that sorts facilities
by cost in ascending order for customer i.
"""
function SortCost(cost)
    nClient = size(cost, 1)
    nFacility = size(cost, 2)
    V = Array{Int}(undef, nClient, nFacility)
    for i in 1:nClient
        V[i, :] = sortperm(cost[i, :])
    end
    return V
end

"""
    FindMaxK(V, nClient, nFacility, y_vals)

For each customer i, find the index k such that the first k facilities
(sorted by cost via V) have cumulative y_vals >= 1.
Used to identify the binding facility in the submodular cut separation.
"""
function FindMaxK(V, nClient, nFacility, y_vals)
    maxk = ones(Int, nClient)
    for i in 1:nClient
        sumy = 0
        for t in 1:nFacility
            sumy += y_vals[V[i, t]]
            if sumy - 1 > -EPS
                maxk[i] = t
                break
            end
        end
    end
    return maxk
end


"""
    Cal_OldSubmodular(S, y_ind, utility, demand)

Evaluate the submodular objective f(S, y) under the classic SF formulation.
For each customer i, computes the leader's capture probability as
max_{j in S} u_{ij} / (max_{j in S} u_{ij} + u_{i, y_ind[i]}),
then returns the demand-weighted sum over all customers.
Used in BuildCuts (OldSubmodular mode) to evaluate the cut right-hand side
for a given leader solution S and follower best-response y_ind.
"""
function Cal_OldSubmodular(S::Vector{Int64}, y_ind::Vector{Int64}, utility, demand)
    nClient = size(utility, 1)
    if isempty(S)
        max_utility_S = 0
    else
        max_utility_S = maximum(utility[:, S], dims=2)
    end
    max_utility_Y = [y_ind[i] == -1 ? 0 : utility[i, y_ind[i]] for i in 1:nClient]
    return dot(demand, max_utility_S ./ (max_utility_S .+ max_utility_Y))
end

"""
    Gain_marginal(S, y_ind, k, utility, demand)

Compute the marginal gain of adding facility k to leader set S, i.e.,
f(S ∪ {k}, y) - f(S, y), where f is the submodular objective Cal_OldSubmodular.
"""
function Gain_marginal(S::Vector{Int64}, y_ind::Vector{Int64}, k::Int, utility, demand)
    return Cal_OldSubmodular([S; k], y_ind, utility, demand) - Cal_OldSubmodular(S, y_ind, utility, demand)
end

