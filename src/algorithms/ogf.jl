function run_ogf(net::NetworkData; 
    objective_type::ObjectiveType = MIN_GENERATION_COST, 
    nonlinear_model::Bool = true, 
    linear_relaxation::Bool = true, 
    misoc_relaxation::Bool = true, 
    solve_nl::Bool = true, 
    solve_misoc::Bool = true, 
    lp_solver = cplex, 
    misoc_solver = cplex, 
    minlp_solver = juniper_cplex
)
    sopt = initialize_optimizer(net, 
        objective_type = objective_type, 
        nonlinear_model = nonlinear_model, 
        linear_relaxation = linear_relaxation, 
        misoc_relaxation = misoc_relaxation 
    )
    stats = Dict{String,Any}(
        "minlp_solve_time" => NaN, 
        "misoc_solve_time" => NaN, 
        "lp_solve_time" => NaN, 
    )

    (solve_nl) && (run_minlp!(sopt, solver = minlp_solver)) 

    (solve_misoc) && (run_misoc!(sopt, solver = misoc_solver))

    run_lp!(sopt, solver = lp_solver)
    stats["lp_solve_time"] = solve_time(sopt.linear_relaxation.model)

    (solve_nl) && (stats["minlp_solve_time"] = solve_time(sopt.nonlinear_full.model))
    (solve_nl) && (stats["misoc_solve_time"] = solve_time(sopt.misoc_relaxation.model))
    return (sopt = sopt, ss = ss, sim_return = sr, stats = stats)
end 

function run_lp_based_algorithm!(net::NetworkData; 
    objective_type::ObjectiveType = MIN_GENERATION_COST, 
    lp_solver = cplex, 
    slack_pressure_increment = 0.01 
)::NamedTuple
    sopt = initialize_optimizer(net, 
        objective_type = objective_type, 
        nonlinear_model = false, 
        linear_relaxation = true, 
        misoc_relaxation = false
    )
    stats = Dict{String,Any}("total_time" => NaN, "status" => "unknown")

    run_lp!(sopt, solver = lp_solver)
    total_time = solve_time(sopt.linear_relaxation.model) 

    # LP infeasibity case
    if (JuMP.termination_status(sopt.linear_relaxation.model) == INFEASIBLE)
        stats["total_time"] = total_time
        stats["status"] = "infeasible"
        return (sopt = sopt, stats = stats)
    end 

    # first simulation run 
    ss, sr = run_simulation_with_lp_solution!(net, sopt)
    is_feasible, _, _ = is_solution_feasible!(ss)
    if is_feasible 
        total_time += sr.time 
        stats["total_time"] = total_time
        stats["status"] = "globally_optimal"
        return (sopt = sopt, stats = stats)
    end 

    success, t = adjust_slack_pressure!(net, sopt; delta = slack_pressure_increment)
    total_time += t
    if (success == false)
        stats["total_time"] = total_time
        stats["status"] = "feasible_solution_recovery_failure"
        return (sopt = sopt, stats = stats)
    end 

    stats["total_time"] = total_time 
    stats["status"] = "globally_optimal"
    return (sopt = sopt, stats = stats)
end 
