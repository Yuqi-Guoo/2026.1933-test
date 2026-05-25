
struct Param
    _bool::Dict{String,Bool}
    _int::Dict{String,Int}
    _float::Dict{String,Float64}
    _string::Dict{String,String}

    # Initialize Param with default values
    function Param()
        dict_bool = Dict(
            #parameter for cuts
            "is_start_value"    => 1,  # whether to set a feasible solution before solving
            "is_usercut"        => 1,  # whether to add user cuts
            "uc_only_rootnode"  => 0,  # whether to add user cuts only at the root node
            "is_add_all_yinF"   => 1,  # whether to add all violated cuts (vs. only the most violated)
            "is_S_cut"          => 1,  # whether to add S-cuts (submodular cuts) to filter
            
            "is_visualization"   => 0,  # whether to print visualization information under partially binary logit (PBL) rule
        )
        dict_int = Dict(
            "p" => 0,  # number of leader facilities to open
            "r" => 0,  # number of follower facilities to open
        )
        dict_float = Dict(
            "gap"       => 0.0,   # MIP optimality gap tolerance
            "nodelimit" => Inf,   # node limit for the B&C tree
            "timelimit" => 7200,  # time limit in seconds
            "EPS"       => 1e-6,  # numerical tolerance for integrality and feasibility checks
            "EPS_vio"   => 1e-4,  # tolerance for declaring a cut violated
            "beta"      => 0.1,   # the sensitivity of the customer to the distance: u_{ij} = exp(-beta * d_{ij}) under PBL rule (default: 0.1)
        )
        dict_string = Dict(
            "mode"   => "ZLP",    # formulation mode: ZLP | OldSubmodular | NewSubmodular
            "fn"     => "",       # path to the instance data file
            "solver" => "cplex",  # solver to use: cplex 
            "data"   => "Qi",     # instance dataset: Qi | Biesinger
        )
        new(copy(dict_bool), copy(dict_int), copy(dict_float), copy(dict_string))
    end

    # Initialize Param by copying another Param object
    function Param(_param::Param)
        new(copy(_param._bool), copy(_param._int), copy(_param._float), copy(_param._string))
    end
end


"""
    read_param(ARGS)

Parse command-line arguments of the form `key=value` and override the corresponding
default parameter values. Prints all active parameters after parsing.
"""
function read_param(ARGS)
    param = Param()

    if length(ARGS) >= 1
        for ind in 1:(length(ARGS))
            paraName, paraVal = split(ARGS[ind], '=', keepempty=false)
            if haskey(param._bool, paraName)
                param._bool[paraName] = parse(Bool, paraVal)
            elseif haskey(param._int, paraName)
                param._int[paraName] = parse(Int, paraVal)
            elseif haskey(param._float, paraName)
                param._float[paraName] = parse(Float64, paraVal)
            elseif haskey(param._string, paraName)
                param._string[paraName] = paraVal
            else
                @printf("Undefined parameter: %s!\n", ARGS[ind])
            end
        end
    end

    @printf("@Parameters: \n")
    for key_i in sort!(collect(keys(param._bool)))
        @printf("%-40s%s\n", key_i, param._bool[key_i])
    end
    @printf("\n")

    for key_i in sort!(collect(keys(param._string)))
        @printf("%-40s%s\n", key_i, param._string[key_i])
    end
    @printf("\n")

    for key_i in sort!(collect(keys(param._int)))
        @printf("%-40s%d\n", key_i, param._int[key_i])
    end
    @printf("\n")

    for key_i in sort!(collect(keys(param._float)))
        if occursin("EPS", key_i)
            @printf("%-40s%.1e\n", key_i, param._float[key_i])
        else
            @printf("%-40s%.2f\n", key_i, param._float[key_i])
        end
    end
    @printf("\n")
    return param
end
