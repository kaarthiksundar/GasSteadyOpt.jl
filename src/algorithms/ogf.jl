function run_ogf(net::NetworkData; 
    objective_type::ObjectiveType = MIN_GENERATION_COST, 
    nonlinear_model::Bool = true, 
    linear_relaxation::Bool = true, 
    misoc_relaxation::Bool = true, 
    solve_nl::Bool = true, 
    solve_misoc::Bool = true, 
    lp_solver = highs, 
    misoc_solver = scip, 
    minlp_solver = scip
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

    if solve_nl
        run_minlp!(sopt, solver = minlp_solver)
        stats["minlp_solve_time"] = JuMP.solve_time(sopt.nonlinear_full.model)
        stats["minlp_status"] = JuMP.termination_status(sopt.nonlinear_full.model)
        stats["minlp_objective"] = JuMP.objective_value(sopt.nonlinear_full.model)
    end 


    if solve_misoc
        run_misoc!(sopt, solver = misoc_solver)
        stats["misoc_solve_time"] = solve_time(sopt.misoc_relaxation.model)
        stats["misoc_status"] = JuMP.termination_status(sopt.misoc_relaxation.model)
        stats["misoc_objective"] = JuMP.objective_value(sopt.misoc_relaxation.model)
    end 

    run_lp!(sopt, solver = lp_solver)
    stats["lp_solve_time"] = solve_time(sopt.linear_relaxation.model)
    stats["lp_status"] = JuMP.termination_status(sopt.linear_relaxation.model)
    stats["lp_objective"] = JuMP.objective_value(sopt.linear_relaxation.model)

    return (sopt = sopt, stats = stats)
end 

function run_lp_based_algorithm!(net::NetworkData; 
    objective_type::ObjectiveType = MIN_GENERATION_COST, 
    solver = highs, 
    slack_pressure_increment = 0.01 
)::NamedTuple
    sopt = initialize_optimizer(net, 
        objective_type = objective_type, 
        nonlinear_model = false, 
        linear_relaxation = true, 
        misoc_relaxation = false
    )
    stats = Dict{String,Any}("total_time" => NaN, "status" => "unknown", "relaxation_time" => NaN, "nl_time" => NaN)

    run_lp!(sopt, solver = solver)
    total_time = solve_time(sopt.linear_relaxation.model) 
    stats["relaxation_time"] = solve_time(sopt.linear_relaxation.model) 

    # LP infeasibity case
    if (JuMP.termination_status(sopt.linear_relaxation.model) == INFEASIBLE)
        stats["total_time"] = total_time
        stats["status"] = "relaxation_infeasible"
        return (sopt = sopt, stats = stats)
    end 

    create_feasibility_nlp!(sopt)

    solve_feasibility_problem!(sopt)
    total_time += solve_time(sopt.feasibility_nlp.model) 
    stats["nl_time"] = solve_time(sopt.feasibility_nlp.model) 

    if (JuMP.termination_status(sopt.feasibility_nlp.model) == INFEASIBLE)
        stats["total_time"] = total_time
        stats["status"] = "feasible_solution_recovery_failure"
        return (sopt = sopt, stats = stats)
    end 

    populate_feasibility_model_solution!(sopt)

    stats["total_time"] = total_time 
    stats["status"] = "globally_optimal"
    
    return (sopt = sopt, stats = stats)

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

function run_misoc_based_algorithm!(net::NetworkData; 
    objective_type::ObjectiveType = MIN_GENERATION_COST, 
    solver = highs, 
    slack_pressure_increment = 0.01 
)::NamedTuple
    sopt = initialize_optimizer(net, 
        objective_type = objective_type, 
        nonlinear_model = false, 
        linear_relaxation = false, 
        misoc_relaxation = true
    )
    stats = Dict{String,Any}("total_time" => NaN, "status" => "unknown")

    run_misoc!(sopt, solver = solver)
    total_time = solve_time(sopt.misoc_relaxation.model) 

    # MISOC infeasibity case
    if (JuMP.termination_status(sopt.misoc_relaxation.model) == INFEASIBLE)
        stats["total_time"] = total_time
        stats["status"] = "infeasible"
        return (sopt = sopt, stats = stats)
    end 

    # first simulation run 
    ss, sr = run_simulation_with_misoc_solution!(net, sopt)
    is_feasible, _, _ = is_solution_feasible!(ss)
    if is_feasible 
        total_time += sr.time 
        stats["total_time"] = total_time
        stats["status"] = "globally_optimal"
        return (sopt = sopt, stats = stats)
    end 

    success, t = adjust_slack_pressure!(net, sopt; delta = slack_pressure_increment, linear = false)
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