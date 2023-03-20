function create_network(zip_file::AbstractString,
    nomination_case::AbstractString;
    apply_on_data::Vector{Function} = [strengthen_flow_bounds!, upper_bound_c_ratios!, modify_entry_nominations!], 
)::NetworkData   
    return parse_network_data(zip_file, nomination_case, apply_on_data = apply_on_data)
end 

function run_lp(net::NetworkData)
    sopt = initialize_optimizer(net)
    JuMP.set_optimizer(sopt.linear_relaxation.model, CPLEX.Optimizer)
    optimize!(sopt.linear_relaxation.model)
    populate_linear_relaxation_solution!(sopt)
    return sopt
end 

function run_simulation(net::NetworkData, sopt::SteadyOptimizer)
    ss = initialize_simulator(net, sopt.solution_linear)
    sr = run_simulator(ss; show_trace = true)
    return ss, sr
end 