function compute_slack_pressure(
    zip_file::AbstractString,
    nomination_case::AbstractString;
    apply_on_data::Vector{Function} = [strengthen_flow_bounds!, upper_bound_c_ratios!, modify_entry_nominations!], 
    eos = :ideal
)::NamedTuple 
    net = create_network(zip_file, nomination_case, apply_on_data = apply_on_data, eos = eos)
    slack_node_id = ref(net, :slack_nodes) |> first
    sopt = initialize_optimizer(net)
    run_lp!(sopt)
    ss, sr = run_simulation_with_lp_solution!(net, sopt)
    @assert sr.status == unique_physical_solution
    is_feasible, lb, ub = is_solution_feasible!(ss)
    if !isempty(lb) && !isempty(ub) 
        @warn "both max and min pressure bounds violated"
        return (slack_pressure = NaN, net = net)
    end 
    p = sopt.solution_linear.control[:node][slack_node_id]["pressure"] 
    @show p
    ref(net, :node, slack_node_id)["slack_pressure"] = p
    (is_feasible) && (return (slack_pressure = p, net = net))
    while true
        if isempty(lb)
            ref(net, :node, slack_node_id)["slack_pressure"] = p - 0.02
        else 
            ref(net, :node, slack_node_id)["slack_pressure"] = p + 0.02
        end 
        sopt = initialize_optimizer(net)
        run_lp!(sopt)
        ss, sr = run_simulation_with_lp_solution!(net, sopt)
        @assert sr.status == unique_physical_solution
        is_feasible, lb, ub = is_solution_feasible!(ss)
        p = sopt.solution_linear.control[:node][slack_node_id]["pressure"]
        @show p
        (is_feasible) && (return (slack_pressure = p, net = net))
    end 
    return (slack_pressure = p, net = net)
end 