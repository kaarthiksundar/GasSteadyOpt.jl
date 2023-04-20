using ArgParse 

include("../../src/NGSteady.jl")

include("cli_parser.jl")

input_cli_args = get_cli_args()
cli_args = map(k -> "$k -> $(input_cli_args[k])\n", keys(input_cli_args) |> collect) 

using SCIP 
using CPLEX 
using JSON

scip_opt = SCIP.Optimizer()
# MOI.set(scip_opt, MOI.RawOptimizerAttribute("display/verblevel"), 0)
cplex_opt = optimizer_with_attributes(CPLEX.Optimizer, "CPX_PARAM_SCRIND"=>0)

for arg in cli_args 
    @info arg
end 

function create_result_file_with_path()
    result_folder = input_cli_args["resultfolder"]
    (!isdir(result_folder)) && (mkdir(result_folder))
    file = input_cli_args["nominationcase"] * ".json"
    (isfile(result_folder * "/" * file)) && (return nothing)
    return result_folder * "/" * file
end 

function run_precompile_case()
    zip_file = "GasLib-data/json/GasLib-11.zip"
    nomination_case = "GasLib-11"
    apply_on_data= [strengthen_flow_bounds!, modify_entry_nominations!]

    net = parse_network_data(zip_file, nomination_case,
        apply_on_data = apply_on_data, 
        eos = :ideal 
    )
    run_ogf(net)
    @info "ran precompiling case"
end 

function run_case()
    run_precompile_case()
    @info "run started"
    apply_on_data= [strengthen_flow_bounds!, modify_entry_nominations!]
    net = parse_network_data(input_cli_args["zipfile"], input_cli_args["nominationcase"], apply_on_data = apply_on_data, eos=:simple_cnga)
    sopt = initialize_optimizer(net)

    stats = Dict{String,Any}(
        "minlp_solve_time" => NaN, 
        "misoc_solve_time" => NaN, 
        "lp_solve_time" => NaN, 
    )   

    # set time limits for cplex and scip 
    MOI.set(scip_opt, MOI.RawOptimizerAttribute("limits/time"), input_cli_args["timelimit"])
    MOI.set(cplex_opt, MOI.RawOptimizerAttribute("CPX_PARAM_TILIM"), input_cli_args["timelimit"])

    # solve lp 
    @info "lp started"
    JuMP.set_optimizer(sopt.linear_relaxation.model, cplex_opt)
    JuMP.set_silent(sopt.linear_relaxation.model)
    JuMP.optimize!(sopt.linear_relaxation.model)
    @info "lp ended"

    stats["lp_solve_time"] = solve_time(sopt.linear_relaxation.model)
    stats["lp_status"] = JuMP.termination_status(sopt.linear_relaxation.model)
    if (stats["lp_status"] == MOI.INFEASIBLE) 
        stats["lp_objective"] = NaN 
        stats["minlp_solve_time"] = NaN 
        stats["minlp_status"] = MOI.INFEASIBLE 
        stats["minlp_objective"] = NaN 
        stats["misoc_status"] = MOI.INFEASIBLE 
        stats["misoc_objective"] = NaN 
        stats["misoc_solve_time"] = NaN
        return stats
    else 
        stats["lp_objective"] = JuMP.objective_value(sopt.linear_relaxation.model)
    end 

    # solve misocp 
    @info "misoc started"
    JuMP.set_optimizer(sopt.misoc_relaxation.model, cplex_opt)
    JuMP.set_silent(sopt.misoc_relaxation.model)
    JuMP.optimize!(sopt.misoc_relaxation.model)
    @info "misoc ended"

    stats["misoc_solve_time"] = solve_time(sopt.misoc_relaxation.model)
    stats["misoc_status"] = JuMP.termination_status(sopt.misoc_relaxation.model)
    @info stats
    if (stats["misoc_status"] == MOI.INFEASIBLE) 
        stats["misoc_objective"] = NaN 
        stats["minlp_solve_time"] = NaN 
        stats["minlp_status"] = MOI.INFEASIBLE 
        stats["minlp_objective"] = NaN 
        return stats
    elseif (stats["misoc_status"] == MOI.TIME_LIMIT)
        stats["misoc_objective"] = NaN
    else 
        stats["misoc_objective"] = JuMP.objective_value(sopt.misoc_relaxation.model)
    end 
    @info stats
    

    # solve minlp 
    @info "minlp started"
    JuMP.set_optimizer(sopt.nonlinear_full.model, () -> scip_opt)
    JuMP.optimize!(sopt.nonlinear_full.model)
    @info "minlp ended"

    stats["minlp_solve_time"] = JuMP.solve_time(sopt.nonlinear_full.model)
    stats["minlp_status"] = JuMP.termination_status(sopt.nonlinear_full.model)
    if (stats["minlp_status"] == MOI.TIME_LIMIT)
        stats["minlp_objective"] = NaN 
    elseif (stats["minlp_status"] == MOI.INFEASIBLE) 
        stats["minlp_objective"] = NaN 
    else 
        stats["minlp_objective"] = JuMP.objective_value(sopt.nonlinear_full.model)
    end 
    return stats 
end 

function write_results_to_file(file::AbstractString, stats::Dict)
    open(file, "w") do f
        JSON.print(f, stats, 4)
      end
end 

file = create_result_file_with_path()
(isnothing(file) == true) && (@info "solution file already exists")
(isnothing(file) == false) && (write_results_to_file(file, run_case()))
@info "run ended"

