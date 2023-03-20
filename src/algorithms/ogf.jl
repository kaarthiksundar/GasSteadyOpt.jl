function create_network(zip_file::AbstractString,
    nomination_case::AbstractString;
    apply_on_data::Vector{Function} = [strengthen_flow_bounds!, upper_bound_c_ratios!, modify_entry_nominations!], 
)::NetworkData   
    return parse_network_data(zip_file, nomination_case, apply_on_data = apply_on_data)
end 

get_optimizer(net::NetworkData) = initialize_optimizer(net)

function run_lp(sopt::SteadyOptimizer)
    JuMP.set_optimizer(sopt.linear_relaxation.model, CPLEX.Optimizer)
    optimize!(sopt.linear_relaxation.model)
    populate_linear_relaxation_solution!(sopt)
    return
end 

function run_misoc(sopt::SteadyOptimizer)
    JuMP.set_optimizer(sopt.misoc_relaxation.model, CPLEX.Optimizer)
    optimize!(sopt.misoc_relaxation.model)
    populate_misoc_relaxation_solution!(sopt)
    return
end 

function run_minlp(sopt::SteadyOptimizer)
    JuMP.set_optimizer(sopt.nonlinear_full.model, minlp_solver)
    optimize!(sopt.nonlinear_full.model)
    populate_nonlinear_model_solution!(sopt)
    return
end 

function run_simulation_with_lp_solution(net::NetworkData, sopt::SteadyOptimizer)
    ss = initialize_simulator(net, sopt.solution_linear)
    sr = run_simulator!(ss; show_trace = true)
    return ss, sr
end 

function run_simulation_with_misoc_solution(net::NetworkData, sopt::SteadyOptimizer)
    ss = initialize_simulator(net, sopt.solution_misoc)
    sr = run_simulator!(ss; show_trace = true)
    return ss, sr
end 