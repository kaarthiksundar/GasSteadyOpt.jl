function populate_nonlinear_model_solution!(sopt::SteadyOptimizer)
    m = sopt.nonlinear_full.model
    var = sopt.nonlinear_full.variables
    net = sopt.net 
    if termination_status(m) == OPTIMIZE_NOT_CALLED 
        @warn "OPTIMIZE_NOT_CALLED on non-linear model"
        return 
    end 
    if termination_status(m) == INFEASIBLE 
        @warn "Nonlinear model is infeasible"
        return 
    end 
    state = sopt.solution_nonlinear.state 
    control = sopt.solution_nonlinear.control
    populate_nodal_injection!(control, var, net)
    populate_valve_status!(control, var, net)
    populate_compressor_control_valve_status!(control, var, net)
    populate_decision_group_selector!(control, var, net)
end 

function populate_linear_relaxation_solution!(sopt::SteadyOptimizer)
    m = sopt.linear_relaxation.model 
    var = sopt.linear_relaxation.variables 
    net = sopt.net 
    if termination_status(m) == OPTIMIZE_NOT_CALLED 
        @warn "OPTIMIZE_NOT_CALLED on linear relaxation"
        return 
    end 
    if termination_status(m) == INFEASIBLE 
        @warn "Linear relaxation is infeasible"
        return 
    end 
    state = sopt.solution_linear.state_guess
    control = sopt.solution_linear.control
    populate_nodal_injection!(control, var, net)
    populate_valve_status!(control, var, net)
    populate_compressor_control_valve_status!(control, var, net)
    populate_decision_group_selector!(control, var, net)
end 

function populate_misoc_relaxation_solution!(sopt::SteadyOptimizer)
    m = sopt.misoc_relaxation.model 
    var = sopt.misoc_relaxation.variables 
    net = sopt.net 
    if termination_status(m) == OPTIMIZE_NOT_CALLED 
        @warn "OPTIMIZE_NOT_CALLED on MISOC relaxation"
        return 
    end 
    if termination_status(m) == INFEASIBLE 
        @warn "MISOC relaxation is infeasible"
        return 
    end 
    state = sopt.solution_misoc.state_guess
    control = sopt.solution_misoc.control
    populate_nodal_injection!(control, var, net)
    populate_valve_status!(control, var, net)
    populate_compressor_control_valve_status!(control, var, net)
    populate_decision_group_selector!(control, var, net)
end 

function populate_nodal_injection!(control, var, net)
    for i in get(control, :node, Dict()) |> keys 
        entries_at_node = ref(net, :entries_at_node, i)
        exits_at_node = ref(net, :exits_at_node, i)
        (isempty(entries_at_node) && isempty(exits_at_node)) && (continue)
        injection = get(var, "injection", Dict())
        withdrawal = get(var, "withdrawal", Dict())
        total_injection = 0.0 
        total_withdrawal = 0.0
        for id in entries_at_node 
            if isempty(injection)
                total_injection += ref(net, :entry, id, "max_injection")
            else 
                total_injection += JuMP.value(injection[id])
            end 
        end 
        for id in exits_at_node 
            if isempty(withdrawal)
                total_withdrawal += ref(net, :exit, id, "max_injection")
            else 
                total_withdrawal += JuMP.value(withdrawal[id])
            end 
        end 
        control[:node][i]["injection"] = total_injection - total_withdrawal
    end 
end 

function populate_valve_status!(control, var, net)
    for i in ref(net, :valve) |> keys 
        x = var[:valve_status][i]
        control[:valve][i]["status"] = (JuMP.value(x) > 0.9) ? 1 : 0 
    end 
end 

function populate_compressor_control_valve_status!(control, var, net)
    component = [:compressor, :control_valve]
    for comp in component 
        for i in ref(net, comp) |> keys 
            status = string(comp) * "_status" |> Symbol
            x = var[status][i]
            control[comp][i]["status"] = (JuMP.value(x) > 0.9) ? 1 : 0 
            active_status = string(comp) * "_active" |> Symbol
            bypass_status = string(comp) * "_bypass" |> Symbol
            if haskey(var[active_status], i)
                control[comp][i]["active"] = (JuMP.value(x) > 0.9) ? 1 : 0 
            end 
            if haskey(var[bypass_status], i)
                control[comp][i]["bypass"] = (JuMP.value(x) > 0.9) ? 1 : 0 
            end 
        end 
    end 
end 

function populate_decision_group_selectors!(control, var, net)
    ids = ref(net, :decision_group) |> keys
    (isempty(ids)) && (return)
    for i in ids 
        x = JuMP.value.(var[:decision_group_selector][i])
        chosen_index = findfirst(y -> y > 0.9, x)
        control[:decision_group][i] = chosen_index
    end 
end 