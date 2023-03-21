function compute_slack_pressure(
    zip_file::AbstractString,
    nomination_case::AbstractString;
    apply_on_data::Vector{Function} = [strengthen_flow_bounds!, modify_entry_nominations!], 
    eos = :ideal
)::NamedTuple 
    net = create_network(zip_file, nomination_case, apply_on_data = apply_on_data, eos = eos)
    slack_node_id = ref(net, :slack_nodes) |> first
    sopt, ss, sr = _run_lp_with_simulation(net)
    if sr.status == unique_physical_solution
        is_feasible, lb, ub = is_solution_feasible!(ss)

        if !isempty(lb) && !isempty(ub) 
            @warn "both max and min pressure bounds violated"
            return (slack_pressure = NaN, net = net)
        end 
        p = sopt.solution_linear.control[:node][slack_node_id]["pressure"] 
        ref(net, :node, slack_node_id)["slack_pressure"] = p
        (is_feasible) && (return (slack_pressure = p, net = net))
        
        while true
            if isempty(lb)
                ref(net, :node, slack_node_id)["slack_pressure"] = max(p - 0.02, ref(net, :node, slack_node_id, "min_pressure"))
            else 
                ref(net, :node, slack_node_id)["slack_pressure"] = min(p + 0.02, ref(net, :node, slack_node_id, "max_pressure"))
            end 
            sopt = initialize_optimizer(net)
            run_lp!(sopt)
            ss, sr = run_simulation_with_lp_solution!(net, sopt)
            @assert sr.status == unique_physical_solution
            feasibility = is_solution_feasible!(ss)
            is_feasible = feasibility.is_feasible 
            lb = feasibility.lb_violation 
            ub = feasibility.ub_violation 
            p = sopt.solution_linear.control[:node][slack_node_id]["pressure"]
            (is_feasible) && (return (slack_pressure = p, net = net))
        end 
        return (slack_pressure = p, net = net)
    else 
        @assert sr.status == unique_unphysical_solution 
        if isempty(sr.negative_potentials_in_nodes)
            @warn "infeasibility due to negative compressor flow or pressure not in correct domain"
            return (slack_pressure = NaN, net = net)
        end 
        is_feasible = false
        lb = [] 
        ub = []
        p = sopt.solution_linear.control[:node][slack_node_id]["pressure"]
        while true 
            ref(net, :node, slack_node_id)["slack_pressure"] = min(p + 0.02, ref(net, :node, slack_node_id, "max_pressure"))
            sopt = initialize_optimizer(net)
            run_lp!(sopt)
            ss, sr = run_simulation_with_lp_solution!(net, sopt)
            if sr.status == unique_physical_solution 
                feasibility = is_solution_feasible!(ss)
                is_feasible = feasibility.is_feasible 
                lb = feasibility.lb_violation 
                ub = feasibility.ub_violation 
                p = sopt.solution_linear.control[:node][slack_node_id]["pressure"]
                @show p
                (is_feasible) && (return (slack_pressure = p, net = net))
            else 
                if isempty(sr.negative_potentials_in_nodes)
                    @warn "infeasibility due to negative compressor flow or pressure not in correct domain"
                    return (slack_pressure = NaN, net = net)
                end 
                p = sopt.solution_linear.control[:node][slack_node_id]["pressure"]
                @show p
            end 
        end     
    end 
    return (slack_pressure = NaN, net = net)
end 

function _run_lp_with_simulation(net::NetworkData)::NamedTuple
    sopt = initialize_optimizer(net)
    run_lp!(sopt)
    ss, sr = run_simulation_with_lp_solution!(net, sopt)
    return (sopt = sopt, ss = ss, sr = sr)
end 

function _run_unique_physical_solution_loop!(net::NetworkData, 
    sopt::SteadtyOptimizer, 
    ss::SteadySimulator, 
    sr::SolverReturn, 
    slack_node_id::Int
)::NamedTuple
    @assert sr.status == unique_physical_solution
    is_feasible, lb, ub = is_solution_feasible!(ss)
    if !isempty(lb) && !isempty(ub) 
        @warn "both max and min pressure bounds violated"
        return (slack_pressure = NaN, net = net)
    end 
    
    # get the current slack pressure
    p = sopt.solution_linear.control[:node][slack_node_id]["pressure"] 

    # if the simulation solution is feasible, then update network and return output
    if is_feasible
        ref(net, :node, slack_node_id)["slack_pressure"] = p
        return (slack_pressure = p, net = net)
    end 

end 