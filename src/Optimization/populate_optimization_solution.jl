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
end 

function populate_linear_relaxation_solution(sopt::SteadyOptimizer)

end 

function populate_misoc_relaxation_solution!(sopt::SteadyOptimizer)

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