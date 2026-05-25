"""
    Distance(p1, p2)

Euclidean distance between two 2D points.
"""
function Distance(p1::Tuple{Float64, Float64}, p2::Tuple{Float64, Float64})
    return sqrt((p1[1] - p2[1])^2 + (p1[2] - p2[2])^2)
end

"""
    Utility_PBL(x, beta)

Partially binary logit rule utility: exp(-beta * x).
"""
function Utility_PBL(x::Float64, beta)
    return exp(-beta * x)
end

"""
    Utility_Biesinger(x)

Utility function from Biesinger et al. (2016): 1 / (x + 1).
"""
function Utility_Biesinger(x::Float64)
    return 1 / (x + 1)
end

"""
    Utility_Qi(x)

Utility function from Qi (2022): exp(-0.1 * x).
"""
function Utility_Qi(x::Float64)
    return exp(-0.1 * x)
end

"""
    ReadScflp_Biesinger(filename, beta)

Read a Biesinger-format instance file. Parses customer locations and demands,
then computes the utility matrix using Utility_PBL (if visualization mode) or
Utility_Biesinger otherwise.
"""
function ReadScflp_Biesinger(finename, beta)
    f = readlines(finename)
    str = split(f[2], (' '), keepempty=false)
    nClient = parse(Int, str[1])
    nFacility = parse(Int, str[1])
    location = Array{Tuple{Float64, Float64}}(undef, nClient)
    D = Array{Any}(undef, 4)
    demand = Array{Int}(undef, nClient)
    utility = Array{Float64}(undef, nClient, nFacility)
    for i in 8:(nClient + 7)
        str = split(f[i], '\t', keepempty=false)
        D[1] = parse(Int, str[1])
        D[2] = parse(Float64, str[2])
        D[3] = parse(Float64, str[3])
        D[4] = parse(Int, str[4])
        demand[D[1]+1] = D[4]
        location[D[1]+1] = (D[2], D[3])
    end

    if param._bool["is_visualization"]
        for i in 1:nClient, j in 1:nFacility
            utility[i, j] = Utility_PBL(Distance(location[i], location[j]), beta)
        end
    else
        for i in 1:nClient, j in 1:nFacility
            utility[i, j] = Utility_Biesinger(Distance(location[i], location[j]))
        end
    end

    return utility, demand
end

"""
    ReadScflp_Qi(filename)

Read a Qi-format instance file. Parses separate customer and facility location
blocks, then computes the utility matrix using Utility_Qi.
"""
function ReadScflp_Qi(finename)
    f = readlines(finename)
    str = split(f[1], (','), keepempty=false)
    nClient = parse(Int, str[1])
    nFacility = parse(Int, str[2])
    location_C = Array{Tuple{Float64, Float64}}(undef, nClient)
    location_F = Array{Tuple{Float64, Float64}}(undef, nFacility)
    D = Array{Any}(undef, 4)
    demand = Array{Int}(undef, nClient)
    utility = Array{Float64}(undef, nClient, nFacility)

    for i in 2:(nClient+1)
        str = split(f[i], ',', keepempty=false)
        D[1] = parse(Float64, str[1])
        D[2] = parse(Float64, str[2])
        D[3] = parse(Float64, str[3])
        demand[i-1] = D[3]
        location_C[i-1] = (D[1], D[2])
    end

    for i in (nClient+2):(nClient+nFacility+1)
        str = split(f[i], ',', keepempty=false)
        D[1] = parse(Float64, str[1])
        D[2] = parse(Float64, str[2])
        location_F[i-(nClient+1)] = (D[1], D[2])
    end

    for i in 1:nClient, j in 1:nFacility
        utility[i, j] = Utility_Qi(Distance(location_C[i], location_F[j]))
    end

    return utility, demand
end
