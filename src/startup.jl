using JuMP
using CPLEX
using HiGHS
using LinearAlgebra
using Printf
using SparseArrays
using Combinatorics
using Random

import MathOptInterface
const MOI = MathOptInterface

mutable struct SCFLP
    x
    z
    eta
end

"""
    SelectSolver(solver)

Initialize and return an optimization model using the specified solver.
Supported options: `"Cplex"`, `"Gurobi"`, `"Scip"`, `"Glpk"`, `"HiGHS"`.
"""
function SelectSolver(solver)
    if solver == "Cplex"
        return direct_model(CPLEX.Optimizer())
    elseif solver == "Gurobi"
        return Model(Gurobi.Optimizer)
    elseif solver == "Scip"
        return direct_model(SCIP.Optimizer())
    elseif solver == "Glpk"
        return direct_model(GLPK.Optimizer())
    elseif solver == "HiGHS"
        return Model(HiGHS.Optimizer)
    else
        println("Please set the correct solver!")
    end
end

"""
    PrintInfos(model)

Print solution information for a solved CPLEX model:
iteration count, optimality gap, termination status, solve time, objective value, and node count.
"""
function PrintInfos(model)
    @printf("\n@PrintInfos\n")
    cplex_model = backend(model)
    env, lp = cplex_model.env, cplex_model.lp
    itcnt = CPXgetmipitcnt(env, lp)
    gaps = Ref{Cdouble}(0.0)
    status = CPXgetmiprelgap(env, lp, gaps)
    @printf("ItCnt: %d\n", itcnt)
    @printf("Current gap: %.2f %%\n", gaps[] * 100)
    @printf("Termination Status: %s\n", termination_status(model))
    @printf("Primal Status: %s\n", primal_status(model))
    @printf("Solve Time: %.2f sec\n", solve_time(model))
    if termination_status(model) == MOI.OPTIMAL || primal_status(model) == MOI.FEASIBLE_POINT
        @printf("Objective Value: %.6f\n", objective_value(model))
    elseif termination_status(model) == MOI.TIME_LIMIT && has_values(model)
        @printf("Objective Value: %.6f\n", objective_value(model))
    elseif termination_status(model) != MOI.INFEASIBLE
        error("The model was not solved correctly !!!")
    end
    @printf("Number of Nodes: %6d\n\n", node_count(model))
end

"""
    Stat_Cut

Store cut statistics (count and CPU time) for each B&C phase.
Phases: `"phase1"`, `"rLC"`, `"rUC"`, `"sLC"`, `"sUC"`.
"""
struct Stat_Cut
    Phase::Vector{String}
    Num::Dict{String,Int}
    Time::Dict{String,Float64}

    function Stat_Cut(arr_phase::Vector{String})
        new(arr_phase, Dict(phase => 0 for phase in arr_phase), Dict(phase => 0 for phase in arr_phase))
    end

    function Stat_Cut(phase::String, num::Int, time::Float64)
        arr_phase = [phase]
        new(arr_phase, Dict(phase => num), Dict(phase => time))
    end
end

"""
    Stat

Aggregate solver statistics across all B&C phases, including cut counts,
separation times, PMP call info, and bound tracking.
"""
struct Stat
    Phase::Vector{String}
    CutName::Vector{String}
    CutInfo::Dict{String,Stat_Cut}
    Round::Dict{String,Int}
    Sol::Dict{String,SCFLP}
    Bound::Dict{String,Float64}
    PMP::Dict{String,Any}
    AllTime::Dict{String,Any}

    function Stat()
        arr_phase = ["phase1", "rLC", "rUC", "sLC", "sUC"]
        arr_cutname = ["ZLP", "OldSubmodular", "NewSubmodular", "PMP"]
        cutinfo = Dict(each_cutname => Stat_Cut(arr_phase) for each_cutname in arr_cutname)
        roundinfo = Dict(phase => 0 for phase in arr_phase)
        roundinfo["lp_not_improved"] = 0
        roundinfo["last_num_node"] = 0
        roundinfo["num_round"] = 0
        roundinfo["count_down"] = 0
        roundinfo["count_up"] = 0
        roundinfo["bound_no_impro"] = 0
        sol = Dict{String,SCFLP}()
        bound = Dict("root_best_integer" => 0.0, "root_best_bound" => 0.0, "best_bound" => 0.0, "best_integer" => 0.0)
        pmp = Dict("num" => 0, "time" => 0.0, "last_status" => "", "t_sepa" => 0.0)
        alltime = Dict("start" => 0.0)
        new(arr_phase, arr_cutname, cutinfo, roundinfo, sol, bound, pmp, alltime)
    end
end

"""
    PrintStatCut(stat_cut)

Print cut count and CPU time for each phase in a `Stat_Cut` object.
"""
function PrintStatCut(stat_cut::Stat_Cut)
    for phase in stat_cut.Phase
        @printf("%5s %5d / %4.2f ", "[" * phase * "]", stat_cut.Num[phase], stat_cut.Time[phase])
    end
    @printf("\n")
end

"""
    PrintStat(stat; obj)

Print a summary of solver statistics: PMP call info, cut counts per algorithm and phase,
separation round counts, and (if `obj` is provided) root/final bounds.
"""
function PrintStat(stat::Stat; obj=nothing)
    @printf("CutInfo: [phase] num / time (sec) \n")
    for each_cutname in stat.CutName
        @printf("%-15s ", each_cutname)
        PrintStatCut(stat.CutInfo[each_cutname])
    end
    @printf("Separation Round: ")
    for each_phase in stat.Phase
        if each_phase != "init"
            @printf("%7s %d", "[" * each_phase * "]", stat.Round[each_phase])
        end
    end
    @printf("\n")
    if obj !== nothing
        rub = stat.Bound["root_best_bound"]
        rlb = stat.Bound["root_best_integer"]
        ub = stat.Bound["best_bound"]
        lb = stat.Bound["best_integer"]
        if termination_status(model) == MOI.OPTIMAL
            ub, lb = obj, obj
            if node_count(model) <= 3
                rub, rlb = obj, obj
            end
        end
        @printf("Root Best Bound %f\n", rub)
        @printf("Root Best Integer: %f\n", rlb)
        @printf("Best Bound: %f\n", ub)
        @printf("Best Integer: %f\n", lb)
    end
    @printf("\n")
end

"""
    Record(stat, dict_cutinfo, phase; val, best_bound, best_integer, node)

Accumulate cut statistics from `dict_cutinfo` into `stat` for the given `phase`.
Optionally records a feasible solution and updates bound tracking.
"""
function Record(stat::Stat, dict_cutinfo, phase; val=nothing, best_bound=-Inf, best_integer=Inf, node=0)
    for cutname in stat.CutName
        if haskey(dict_cutinfo, cutname)
            stat_cut = dict_cutinfo[cutname]
            for cut_phase in stat_cut.Phase
                stat.CutInfo[cutname].Num[cut_phase] += stat_cut.Num[cut_phase]
                stat.CutInfo[cutname].Time[cut_phase] += stat_cut.Time[cut_phase]
            end
        end
    end
    stat.Round[phase] += 1
    if val !== nothing
        stat.Sol["fea"] = val
    end
    if best_integer < best_bound
        stat.Bound["best_bound"] = best_bound
        stat.Bound["best_integer"] = best_integer
        if node <= 3
            stat.Bound["root_best_bound"] = best_bound
            stat.Bound["root_best_integer"] = best_integer
        end
    end
end
