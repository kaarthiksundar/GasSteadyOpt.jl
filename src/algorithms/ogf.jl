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
        "simulation_time" => NaN, 
        "globally_optimal" => false
    )

    if solve_nl
        run_minlp!(sopt, solver = minlp_solver)
        t = round(solve_time(sopt.nonlinear_full.model); digits=4)
        stats["minlp_solve_time"] = t
    end 

    if solve_misoc 
        run_misoc!(sopt, solver = misoc_solver)
        t = round(solve_time(sopt.misoc_relaxation.model); digits=4)
        stats["misoc_solve_time"] = t
    end 

    run_lp!(sopt, solver = lp_solver)
    stats["lp_solve_time"] = round(solve_time(sopt.linear_relaxation.model); digits=4) 

    ss, sr = run_simulation_with_lp_solution!(net, sopt)
    stats["simulation_time"] = round(sr.time; digits=4) 

    feasibility = is_solution_feasible!(ss)
    stats["globally_optimal"] = feasibility.is_feasible 

    return (sopt = sopt, ss = ss, sim_return = sr, stats = stats)

end 
