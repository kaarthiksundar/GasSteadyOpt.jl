function adjust_slack_pressure!(net::NetworkData, 
    sopt::SteadyOptimizer; delta = 0.01, linear::Bool = true
)::NamedTuple
    slack_node_id = ref(net, :slack_nodes) |> first  
    control = (linear == true) ? sopt.solution_linear.control : sopt.solution_misoc.control
    f = (linear == true) ? run_simulation_with_lp_solution! : run_simulation_with_misoc_solution!
    # run simulation once with solution 
    ss, sr = f(net, sopt) 
    is_feasible, lb_violation, ub_violation = is_solution_feasible!(ss)
    
    # warning message 
    if lb_violation > 0.0 && ub_violation > 0.0
        @warn "first simulation run has both max and min pressure bounds violated"
    end 

    # slack pressures 
    n = 4
    sp = CircularDeque{Float64}(4)
    push!(sp, control[:node][slack_node_id]["pressure"])
    # time tracker 
    total_time = 0.0 
    
    # function will not be invoked if this assertion failed
    @assert is_feasible == false 

    iterations = 0
    while true 
        iterations += 1
        if sr.status == unique_physical_solution 
            # get slack pressure from solution 
            p = control[:node][slack_node_id]["pressure"] 
            
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
                control[:node][slack_node_id]["pressure"] = new_p 
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
                control[:node][slack_node_id]["pressure"] = new_p
                (length(sp) == n) && (popfirst!(sp))
                push!(sp, new_p)
                @info new_p
            end 

            ss, sr = f(net, sopt)
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
            p = control[:node][slack_node_id]["pressure"] 
            
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
            control[:node][slack_node_id]["pressure"] = new_p
            (length(sp) == n) && (popfirst!(sp))
            push!(sp, new_p)
            @info new_p

            ss, sr = f(net, sopt)
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
    a::Float64, b::Float64;
    linear::Bool = true
)::NamedTuple
    slack_node_id = ref(net, :slack_nodes) |> first  
    control = (linear == true) ? sopt.solution_linear.control : sopt.solution_misoc.control
    f = (linear == true) ? run_simulation_with_lp_solution! : run_simulation_with_misoc_solution!
    lb = min(a, b)
    ub = max(a, b)

    # find violation type for lb 
    ref(net, :node, slack_node_id)["slack_pressure"] = lb
    control[:node][slack_node_id]["pressure"] = lb
    ss, sr = f(net, sopt) 
    is_feasible, lb_violation, ub_violation = is_solution_feasible!(ss)
    lb_violation_type = (lb_violation > ub_violation) ? :lb : :ub 

    # find violation type for ub 
    ref(net, :node, slack_node_id)["slack_pressure"] = ub
    control[:node][slack_node_id]["pressure"] = ub
    ss, sr = f(net, sopt) 
    is_feasible, lb_violation, ub_violation = is_solution_feasible!(ss)
    ub_violation_type = (lb_violation > ub_violation) ? :lb : :ub 

    @assert lb_violation_type != ub_violation_type

    iterations = 0 
    total_time = 0.0 
    while iterations < 10
        mp = (lb + ub) * 0.5  
        @info mp
        ref(net, :node, slack_node_id)["slack_pressure"] = mp
        control[:node][slack_node_id]["pressure"] = mp
        ss, sr = f(net, sopt) 
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
    sopt::SteadyOptimizer; num_tries = 200, linear::Bool = true
)::NamedTuple
    slack_node_id = ref(net, :slack_nodes) |> first  
    control = (linear == true) ? sopt.solution_linear.control : sopt.solution_misoc.control
    f = (linear == true) ? run_simulation_with_lp_solution! : run_simulation_with_misoc_solution!
    min_pressure = ref(net, :node, slack_node_id, "min_pressure")
    max_pressure = ref(net, :node, slack_node_id, "max_pressure")
    sp = range(min_pressure, max_pressure; length = num_tries)
    total_time = 0.0 

    for p in sp 
        @show p
        ref(net, :node, slack_node_id)["slack_pressure"] = p
        control[:node][slack_node_id]["pressure"] = p
        ss, sr = f(net, sopt) 
        total_time += sr.time
        (sr.status != unique_physical_solution) && (continue)
        is_feasible, _, _ = is_solution_feasible!(ss)
        if is_feasible 
            return (success = true, time = total_time)
        end 
    end 

    return (success = false, time = total_time)
end 