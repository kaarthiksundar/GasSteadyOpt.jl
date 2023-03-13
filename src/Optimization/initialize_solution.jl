function _initialize_solution!(net::NetworkData, solution::Solution) 
    state = solution.state 
    control = solution.control
    
    for (i, _) in ref(net, :node)
        state[:node][i] = Dict("pressure" =>  NaN, "potential" => NaN) 
        control[:node][i] = Dict("injection" => NaN)
    end     
    
    flow_components = [:pipe, :resistor, :loss_resistor, :short_pipe, :compressor, :control_valve, :valve]
    for comp in flow_components 
        for (i, _) in ref(net, comp)
            state[comp][i] = Dict("flow" => NaN) 
        end 
    end 

    control_components = [:compressor, :control_valve, :valve]
    for comp in control_components 
        for (i, _) in ref(net, comp)
            control[comp][i] = Dict() 
        end 
    end 
end 

function _initialize_solution!(sopt::SteadyOptimizer)
    _initialize_solution!(sopt.net, sopt.solution_nonlinear)
    _initialize_solution!(sopt.net, sopt.solution_linear)
    _initialize_solution!(sopt.net, sopt.solution_misoc)
end 