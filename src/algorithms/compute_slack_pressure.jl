function compute_slack_pressure(
    zip_file::AbstractString,
    nomination_case::AbstractString;
    apply_on_data::Vector{Function} = [strengthen_flow_bounds!, modify_entry_nominations!], 
    eos = :ideal, 
    delta = 0.01
)::NamedTuple 
    
    net = create_network(zip_file, nomination_case, apply_on_data = apply_on_data, eos = eos)
    slack_node_id = ref(net, :slack_nodes) |> first
    sopt, ss, sr = _run_lp_with_simulation(net)

    while true 
        if sr.status == unique_physical_solution 
            updated, is_feasible = _run_unique_physical_solution_update!(net, sopt, ss, sr, slack_node_id, delta = delta)
            (updated == false) && (return (slack_pressure = NaN, net = net))
            (updated == true && is_feasible == true) && (return (slack_pressure = ref(net, :node, slack_node_id, "slack_pressure"), net = net))
            @info "slack_pressure: $(ref(net, :node, slack_node_id, "slack_pressure"))"
            sopt, ss, sr = _run_lp_with_simulation(net)
        elseif sr.status in [unique_unphysical_solution, unphysical_solution]
            updated = _run_unphysical_solution_update!(net, sopt, ss, sr, slack_node_id, delta = delta) 
            (updated == false) && (return (slack_pressure = NaN, net = net))
            @info "slack_pressure: $(ref(net, :node, slack_node_id, "slack_pressure"))"
            sopt, ss, sr = _run_lp_with_simulation(net)
        else 
            return (slack_pressure = NaN, net = net)
        end 
    end 
end 

function _run_lp_with_simulation(net::NetworkData)::NamedTuple
    sopt = initialize_optimizer(net)
    run_lp!(sopt)
    ss, sr = run_simulation_with_lp_solution!(net, sopt)
    return (sopt = sopt, ss = ss, sr = sr)
end 

function _run_unique_physical_solution_update!(net::NetworkData, 
    sopt::SteadyOptimizer, 
    ss::SteadySimulator, 
    sr::SolverReturn, 
    slack_node_id::Int;
    delta::Float64 = 0.01
)::NamedTuple
    @assert sr.status == unique_physical_solution
    is_feasible, lb, ub = is_solution_feasible!(ss)
    if !isempty(lb) && !isempty(ub) 
        @warn "both max and min pressure bounds violated"
        return (updated = false, is_feasible = false)
    end 
    
    # get the current slack pressure
    p = sopt.solution_linear.control[:node][slack_node_id]["pressure"] 

    # if the simulation solution is feasible, then update network and return output
    if is_feasible
        ref(net, :node, slack_node_id)["slack_pressure"] = p
        return (updated = true, is_feasible = true)
    end 

    # update slack pressure by delta = 0.02 
    if isempty(lb)
        ref(net, :node, slack_node_id)["slack_pressure"] = max(p - delta, ref(net, :node, slack_node_id, "min_pressure"))
    else 
        ref(net, :node, slack_node_id)["slack_pressure"] = min(p + delta, ref(net, :node, slack_node_id, "max_pressure"))
    end 
    
    return (updated = true, is_feasible = false)
end 

function _run_unphysical_solution_update!(net::NetworkData, 
    sopt::SteadyOptimizer, 
    ss::SteadySimulator, 
    sr::SolverReturn, 
    slack_node_id::Int;
    delta::Float64 = 0.01
)::Bool
    @assert sr.status in [unique_unphysical_solution, unphysical_solution]
    # ensure infeasibility due to negative potential in nodes 
    if isempty(sr.negative_potentials_in_nodes)
        @warn "infeasibility due to negative compressor flow or pressure not in correct domain"
        return false 
    end 

    # get the current slack pressure
    p = sopt.solution_linear.control[:node][slack_node_id]["pressure"] 
    
    # update slack pressure by delta = 0.02 
    ref(net, :node, slack_node_id)["slack_pressure"] = min(p + delta, ref(net, :node, slack_node_id, "max_pressure"))
    
    return true 
end 