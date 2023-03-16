function _initialize_solution!(net::NetworkData, solution::Solution) 
    state = solution.state 
    control = solution.control
    state_guess = solution.state_guess
    
    for (i, _) in ref(net, :node)
        state[:node][i] = Dict("pressure" =>  NaN, "potential" => NaN) 
        state_guess[:node][i] = Dict("pressure" =>  NaN, "potential" => NaN) 
        control[:node][i] = Dict("injection" => NaN, "pressure" => NaN)
    end     

    for (i, _) in ref(net, :entry)
        control[:entry][i] = Dict("injection" => NaN)
    end 

    for (i, _) in ref(net, :exit)
        control[:exit][i] = Dict("withdrawal" => NaN)
    end 
    
    flow_components = [:pipe, :resistor, :loss_resistor, :short_pipe, :compressor, :control_valve, :valve]
    for comp in flow_components 
        for (i, _) in ref(net, comp)
            state[comp][i] = Dict("flow" => NaN) 
            state_guess[comp][i] = Dict("flow" => NaN) 
        end 
    end 

    control_components = [:compressor, :control_valve, :valve]
    for comp in control_components 
        for (i, _) in ref(net, comp)
            control[comp][i] = Dict() 
        end 
    end 

    for (i, _) in ref(net, :decision_group) 
        control[:decision_group][i] = nothing 
    end 
end 

function _initialize_solution!(sopt::SteadyOptimizer)
    _initialize_solution!(sopt.net, sopt.solution_nonlinear)
    _initialize_solution!(sopt.net, sopt.solution_linear)
    _initialize_solution!(sopt.net, sopt.solution_misoc)
end 