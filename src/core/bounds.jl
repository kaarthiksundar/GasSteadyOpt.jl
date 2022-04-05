function _add_pipe_flow_bounds_to_ref!(sopt::SteadyOptimizer)
    max_withdrawal = sum([w["max_withdrawal"] for (_, w) in ref(sopt)[:delivery]])
    for (_, pipe) in ref(sopt, :pipe)
        fr_node = pipe["fr_node"]
        to_node = pipe["to_node"]
        fr_node_p_min = ref(sopt, :node, fr_node, "min_pressure")
        fr_node_p_max = ref(sopt, :node, fr_node, "max_pressure")
        to_node_p_min = ref(sopt, :node, to_node, "min_pressure")
        to_node_p_max = ref(sopt, :node, to_node, "max_pressure")
        c = nominal_values(sopt, :mach_num)^2 / nominal_values(sopt, :euler_num) 
        b1, b2 = get_eos_coeffs(sopt)
        resistance = pipe["friction_factor"] * pipe["length"] * c / (2 * pipe["diameter"] * pipe["area"]^2)
    
        beta = 1/resistance
        if isinf(beta) 
            beta = 1e5
        end
        p_sqr_max = fr_node_p_max^2 - to_node_p_min^2 
        p_cube_max = fr_node_p_max^3 - to_node_p_min^3 

        p_sqr_min = to_node_p_max^2 - fr_node_p_min^2 
        p_cube_min = to_node_p_max^3 - fr_node_p_min^3 

        if isnan(pipe["max_flow"])
            pipe["max_flow"] = min(sqrt(beta * ((b1/2) * p_sqr_max + (b2/3) * p_cube_max)), max_withdrawal)
        end 
        if isnan(pipe["min_flow"])
            pipe["min_flow"] = max(-sqrt(beta * ((b1/2) * p_sqr_min + (b2/3) * p_cube_min)), -max_withdrawal)
        end
    end 
end 

function _add_nodal_potential_bounds_to_ref!(sopt::SteadyOptimizer)
    for (_, node) in ref(sopt, :node)
        p_min = node["min_pressure"]
        p_max = node["max_pressure"]
        b1, b2 = get_eos_coeffs(sopt) 

        p_sqr_max = p_max^2 
        p_cube_max = p_max^3 

        p_sqr_min = p_min^2 
        p_cube_min = p_min^3 
        
        node["min_potential"] = (b1/2) * p_sqr_min + (b2/3) * p_cube_min
        node["max_potential"] = (b1/2) * p_sqr_max + (b2/3) * p_cube_max

        if ~isnan(node["slack_pressure"])
            p = node["slack_pressure"]
            node["slack_potential"] = (b1/2) * p^2 + (b2/3) * p^3
        else 
            node["slack_potential"] = NaN
        end 
    end 
end 

function _add_compressor_flow_bounds_to_ref!(sopt::SteadyOptimizer)
    max_withdrawal = sum([w["max_withdrawal"] for (_, w) in ref(sopt)[:delivery]])
    for (_, compressor) in ref(sopt, :compressor)
        isnan(compressor["min_flow"]) && (compressor["min_flow"] = -max_withdrawal)
        isnan(compressor["max_flow"]) && (compressor["max_flow"] = max_withdrawal)
    end 
end 