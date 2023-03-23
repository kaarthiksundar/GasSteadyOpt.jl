function adjust_slack_pressure!(net::NetworkData, 
    sopt::SteadyOptimizer; delta = 0.01 
)::NamedTuple
    slack_node_id = ref(net, :slack_nodes) |> first  
    
    # run simulation once with LP solution 
    ss, sr = run_simulation_with_lp_solution!(net, sopt) 
    is_feasible, lb_violation, ub_violation = is_solution_feasible!(ss)
    
    # warning message 
    if lb_violation > 0.0 && ub_violation > 0.0
        @warn "first simulation run has both max and min pressure bounds violated"
    end 

    # slack pressures 
    n = 4
    sp = CircularDeque{Float64}(4)
    push!(sp, sopt.solution_linear.control[:node][slack_node_id]["pressure"])
    # time tracker 
    total_time = 0.0 
    
    # function will not be invoked if this assertion failed
    @assert is_feasible == false 

    iterations = 0
    while true 
        iterations += 1
        if sr.status == unique_physical_solution 
            # get slack pressure from solution 
            p = sopt.solution_linear.control[:node][slack_node_id]["pressure"] 
            
            # decrease slack pressure if condition is satisfied 
            if ub_violation > lb_violation
                new_p = max(p - delta, ref(net, :node, slack_node_id, "min_pressure"))
                if new_p == p
                    @warn "failed to compute feasible solution, pressure cannot be decreased further"
                    return (success = false, time = total_time)
                end 
                if length(sp) > 2 && (new_p == sp[length(sp) - 1])
                    p_1 = new_p 
                    p_2 = last(p)
                    success, t = bisect!(net, sopt, p_1, p_2)
                    (success == false) && (return (success = false, time = total_time + t))
                end 
                ref(net, :node, slack_node_id)["slack_pressure"] = new_p 
                sopt.solution_linear.control[:node][slack_node_id]["pressure"] = new_p 
                (length(sp) == n) && (popfirst!(sp))
                push!(sp, new_p)
                @info new_p
            end 

            # increase slack pressure if condition is satisfied 
            if  lb_violation > ub_violation
                new_p = min(p + delta, ref(net, :node, slack_node_id, "max_pressure"))
                if new_p == p
                    @warn "failed to compute feasible solution, pressure cannot be increased further"
                    return (success = false, time = total_time)
                end 
                if length(sp) > 2 && (new_p == sp[length(sp) - 1])
                    p_1 = new_p 
                    p_2 = last(p)
                    success, t = bisect!(net, sopt, p_1, p_2)
                    (success == false) && (return (success = false, time = total_time + t))
                end 
                ref(net, :node, slack_node_id)["slack_pressure"] = new_p 
                sopt.solution_linear.control[:node][slack_node_id]["pressure"] = new_p
                (length(sp) == n) && (popfirst!(sp))
                push!(sp, new_p)
                @info new_p
            end 

            ss, sr = run_simulation_with_lp_solution!(net, sopt)
            total_time += sr.time 
            
            is_feasible, lb_violation, ub_violation = is_solution_feasible!(ss)
            
            # return success if feasible 
            (is_feasible) && (return (success = true, time = total_time))
        
        elseif sr.status in [unique_unphysical_solution, unphysical_solution]
            # if failure not due to negative potentials declare defeat 
            if isempty(sr.negative_potentials_in_nodes)
                @warn "infeasibility due to negative compressor flow/pressure not in correct domain"
                @warn "failed to compute feasible solution"
                return (success = false, time = total_time)
            end 

            # get the slack pressure from solution 
            p = sopt.solution_linear.control[:node][slack_node_id]["pressure"] 
            
            # increase slack pressure by delta
            new_p = min(p + delta, ref(net, :node, slack_node_id, "max_pressure"))
            if new_p == p
                @warn "failed to compute feasible solution, pressure cannot be increased further"
                return (success = false, time = total_time)
            end 
            if length(sp) > 2 && (new_p == sp[length(sp) - 1])
                p_1 = new_p 
                p_2 = last(p)
                success, t = bisect!(net, sopt, p_1, p_2)
                (success == false) && (return (success = false, time = total_time + t))
            end 
            ref(net, :node, slack_node_id)["slack_pressure"] = new_p 
            sopt.solution_linear.control[:node][slack_node_id]["pressure"] = new_p
            (length(sp) == n) && (popfirst!(sp))
            push!(sp, new_p)
            @info new_p

            ss, sr = run_simulation_with_lp_solution!(net, sopt)
            total_time += sr.time 
            
            is_feasible, lb_violation, ub_violation = is_solution_feasible!(ss)

            # return success if feasible 
            (is_feasible) && (return (success = true, time = total_time))

        else 
            @warn "simulation failed to converge"
            return (success = false, time = total_time)
        end 
        (iterations > 15) && (return (success = false, time = total_time))
    end 
end 

function bisect!(net::NetworkData, 
    sopt::SteadyOptimizer, 
    a::Float64, b::Float64
)::NamedTuple
    slack_node_id = ref(net, :slack_nodes) |> first  
    lb = min(a, b)
    ub = max(a, b)

    # find violation type for lb 
    ref(net, :node, slack_node_id)["slack_pressure"] = lb
    sopt.solution_linear.control[:node][slack_node_id]["pressure"] = lb
    ss, sr = run_simulation_with_lp_solution!(net, sopt) 
    is_feasible, lb_violation, ub_violation = is_solution_feasible!(ss)
    lb_violation_type = (lb_violation > ub_violation) ? :lb : :ub 

    # find violation type for ub 
    ref(net, :node, slack_node_id)["slack_pressure"] = ub
    sopt.solution_linear.control[:node][slack_node_id]["pressure"] = ub
    ss, sr = run_simulation_with_lp_solution!(net, sopt) 
    is_feasible, lb_violation, ub_violation = is_solution_feasible!(ss)
    ub_violation_type = (lb_violation > ub_violation) ? :lb : :ub 

    @assert lb_violation_type != ub_violation_type

    iterations = 0 
    total_time = 0.0 
    while iterations < 10
        mp = (lb + ub) * 0.5  
        @info mp
        ref(net, :node, slack_node_id)["slack_pressure"] = mp
        sopt.solution_linear.control[:node][slack_node_id]["pressure"] = mp
        ss, sr = run_simulation_with_lp_solution!(net, sopt) 
        total_time += sr.time
        is_feasible, lb_violation, ub_violation = is_solution_feasible!(ss)
        (is_feasible) && (return (success = true, time = total_time))
        mp_violation_type = (lb_violation > ub_violation) ? :lb : :ub 
        if (lb_violation_type != mp_violation_type)
            (abs(lb-mp) < 1E-5) && (break)
            ub = mp 
            ub_violation_type = mp_violation_type
        else 
            (abs(ub-mp) < 1E-5) && (break)
            lb = mp 
            lb_violation_type = mp_violation_type
        end 
        iterations += 1 
    end 

    return (success = false, time = total_time)
end 


function compute_slack_pressure!(net::NetworkData, 
    sopt::SteadyOptimizer; num_tries = 200
)::NamedTuple
    slack_node_id = ref(net, :slack_nodes) |> first  
    min_pressure = ref(net, :node, slack_node_id, "min_pressure")
    max_pressure = ref(net, :node, slack_node_id, "max_pressure")
    sp = range(min_pressure, max_pressure; length = num_tries)
    total_time = 0.0 

    for p in sp 
        @show p
        ref(net, :node, slack_node_id)["slack_pressure"] = p
        sopt.solution_linear.control[:node][slack_node_id]["pressure"] = p
        ss, sr = run_simulation_with_lp_solution!(net, sopt) 
        total_time += sr.time
        (sr.status != unique_physical_solution) && (continue)
        is_feasible, _, _ = is_solution_feasible!(ss)
        if is_feasible 
            return (success = true, time = total_time)
        end 
    end 

    return (success = false, time = total_time)
end 

# function compute_slack_pressure(
#     zip_file::AbstractString,
#     nomination_case::AbstractString;
#     apply_on_data::Vector{Function} = [strengthen_flow_bounds!, modify_entry_nominations!], 
#     eos = :ideal, 
#     delta = 0.01
# )::NamedTuple 
    
#     net = create_network(zip_file, nomination_case, apply_on_data = apply_on_data, eos = eos)
#     slack_node_id = ref(net, :slack_nodes) |> first
#     sopt, ss, sr = _run_lp_with_simulation(net)
#     Δ = delta 

#     while true 
#         if sr.status == unique_physical_solution 
#             updated, is_feasible = _run_unique_physical_solution_update!(net, sopt, ss, sr, slack_node_id, delta = Δ)
#             if updated == false
#                 return (slack_pressure = NaN, net = net)
#             end 
#             (updated == true && is_feasible == true) && (return (slack_pressure = ref(net, :node, slack_node_id, "slack_pressure"), net = net))
#             @info "slack_pressure: $(ref(net, :node, slack_node_id, "slack_pressure"))"
#             sopt, ss, sr = _run_lp_with_simulation(net)
#         elseif sr.status in [unique_unphysical_solution, unphysical_solution]
#             updated = _run_unphysical_solution_update!(net, sopt, ss, sr, slack_node_id, delta = delta) 
#             (updated == false) && (return (slack_pressure = NaN, net = net))
#             @info "slack_pressure: $(ref(net, :node, slack_node_id, "slack_pressure"))"
#             sopt, ss, sr = _run_lp_with_simulation(net)
#         else 
#             return (slack_pressure = NaN, net = net)
#         end 
#     end 
# end 

# function _run_lp_with_simulation(net::NetworkData)::NamedTuple
#     sopt = initialize_optimizer(net)
#     run_lp!(sopt)
#     ss, sr = run_simulation_with_lp_solution!(net, sopt)
#     return (sopt = sopt, ss = ss, sr = sr)
# end 

# function _run_unique_physical_solution_update!(net::NetworkData, 
#     sopt::SteadyOptimizer, 
#     ss::SteadySimulator, 
#     sr::SolverReturn;
#     delta::Float64 = 0.01
# )::Bool
#     slack_node_id = ref(net, :slack_nodes) |> first
#     @assert sr.status == unique_physical_solution
#     is_feasible, lb, ub = is_solution_feasible!(ss)
#     if !isempty(lb) && !isempty(ub) 
#         @warn "both max and min pressure bounds violated"
#     end 
    
#     # get the current slack pressure
#     p = sopt.solution_linear.control[:node][slack_node_id]["pressure"] 

#     # if the simulation solution is feasible, then update network and return output
#     if is_feasible
#         ref(net, :node, slack_node_id)["slack_pressure"] = p
#         is_feasible 
#     end 

#     # update slack pressure by delta = 0.02 
#     if isempty(lb) || (length(ub) >= length(lb))
#         ref(net, :node, slack_node_id)["slack_pressure"] = 
#             max(p - delta, ref(net, :node, slack_node_id, "min_pressure"))
#     end 

#     if  isempty(ub) || (length(lb) > length(ub))
#         ref(net, :node, slack_node_id)["slack_pressure"] = 
#             min(p + delta, ref(net, :node, slack_node_id, "max_pressure"))
#     end 
    
#     return (updated = true, is_feasible = false)
# end 

# function _run_unphysical_solution_update!(net::NetworkData, 
#     sopt::SteadyOptimizer, 
#     ss::SteadySimulator, 
#     sr::SolverReturn;
#     delta::Float64 = 0.01
# )::Bool
#     slack_node_id = ref(net, :slack_nodes) |> first
#     @assert sr.status in [unique_unphysical_solution, unphysical_solution]
#     # ensure infeasibility due to negative potential in nodes 
#     if isempty(sr.negative_potentials_in_nodes)
#         @warn "infeasibility due to negative compressor flow or pressure not in correct domain"
#         return false 
#     end 

#     # get the current slack pressure
#     p = sopt.solution_linear.control[:node][slack_node_id]["pressure"] 
    
#     # update slack pressure by delta = 0.02 
#     ref(net, :node, slack_node_id)["slack_pressure"] = min(p + delta, ref(net, :node, slack_node_id, "max_pressure"))
    
#     return true 
# end 