invert_positive_potential(ss::SteadySimulator, val::Float64) = invert_positive_potential(ss.net, val)

function calculate_slack_withdrawal(ss::SteadySimulator, id::Int, x_dof::Array)::Float64
    slack_withdrawal = 0.0
    for i in ref(ss, :incoming_dofs)[id]
        slack_withdrawal += x_dof[i]
    end 
    for i in ref(ss, :outgoing_dofs)[id]
        slack_withdrawal -= x_dof[i]
    end 
    return slack_withdrawal
end 


function update_solution_fields_in_ref!(ss::SteadySimulator, x_dof::Array)::NamedTuple
    flow_direction = true
    negative_flow_in_compressors = Int[]
    negative_nodal_potentials = Int[]
    nodal_pressures_not_in_domain = Int[]

    for i in 1:length(x_dof)
        sym, local_id = ref(ss, :dof, i)
        if sym == :node
            
            ctrl_type, val = control(ss, :node, local_id)
            if ctrl_type == ControlType(2)
                ref(ss, sym, local_id)["withdrawal"] = val
            elseif ctrl_type == ControlType(3)
                ref(ss, sym, local_id)["withdrawal"] = calculate_slack_withdrawal(ss, local_id, x_dof)
            end 

            pi_val = (is_pressure_node(ss, local_id)) ? get_potential(ss, x_dof[i]) : x_dof[i] 
            if (pi_val < 0)
                push!(negative_nodal_potentials, local_id)
                ref(ss, sym, local_id)["potential"] = pi_val 
                ref(ss, sym, local_id)["pressure"] = NaN 
                ref(ss, sym, local_id)["density"] = NaN
                continue 
            end

            if (pi_val == 0.0)
                ref(ss, sym, local_id)["potential"] = 0.0
                ref(ss, sym, local_id)["pressure"] = 0.0
                ref(ss, sym, local_id)["density"] = 0.0
                continue
            end 

            p_val = (is_pressure_node(ss, local_id)) ? x_dof[i] : invert_positive_potential(ss, x_dof[i])

            # pi_val > 0 is always true when we get to this point 
            if (p_val < 0 && pi_val > 0)
                push!(nodal_pressures_not_in_domain, local_id)
                ref(ss, sym, local_id)["potential"] = pi_val 
                ref(ss, sym, local_id)["pressure"] = NaN 
                ref(ss, sym, local_id)["density"] = NaN
            else  
                ref(ss, sym, local_id)["potential"] = pi_val
                ref(ss, sym, local_id)["pressure"] = p_val
                ref(ss, sym, local_id)["density"] = get_density(ss, p_val)
            end
        end

        if sym == :pipe
            ref(ss, sym, local_id)["flow"] = x_dof[i]
            (x_dof[i] < 0) && (flow_direction = false)
        end

        if sym == :compressor
            ref(ss, sym, local_id)["flow"] = x_dof[i]
            ctrl_type, val = control(ss, :compressor, local_id)
            ref(ss, sym, local_id)["control_type"] = ctrl_type
            to_node = ref(ss, sym, local_id)["to_node"]
            fr_node = ref(ss, sym, local_id)["fr_node"]
            ref(ss, sym, local_id)["c_ratio"] = 
                ref(ss, :node, to_node)["pressure"] / ref(ss, :node, fr_node)["pressure"]  
            if x_dof[i] < 0 && ref(ss, sym, local_id)["c_ratio"] > 1.0
                push!(negative_flow_in_compressors, local_id)
            end
        end

        if sym == :control_valve 
            ref(ss, sym, local_id)["flow"] = x_dof[i]
            ctrl_type, val = control(ss, :control_valve, local_id)
            ref(ss, sym, local_id)["control_type"] = ctrl_type
            to_node = ref(ss, sym, local_id)["to_node"]
            fr_node = ref(ss, sym, local_id)["fr_node"]
            ref(ss, sym, local_id)["pressure_differential"] = 
                ref(ss, :node, fr_node)["pressure"] - ref(ss, :node, to_node)["pressure"] 
        end 

        (sym == :valve) && (ref(ss, sym, local_id)["flow"] = x_dof[i])
        (sym == :resistor) && (ref(ss, sym, local_id)["flow"] = x_dof[i])
        (sym == :loss_resistor) && (ref(ss, sym, local_id)["flow"] = x_dof[i])
        (sym == :short_pipe) && (ref(ss, sym, local_id)["flow"] = x_dof[i])
    end

    return (
            pipe_flow_dir = flow_direction, 
            compressors_with_neg_flow = negative_flow_in_compressors, 
            nodes_with_neg_potential = negative_nodal_potentials, 
            nodes_with_pressure_not_in_domain = nodal_pressures_not_in_domain
        )
end


function populate_solution!(ss::SteadySimulator)
    sol = ss.solution 

    function pressure_convertor(pu) 
        (units == 0) && (return pu * nominal_values(ss, :pressure)) 
        return pascal_to_psi(pu * nominal_values(ss, :pressure))
    end 

    function mass_flow_convertor(pu)
        kgps_to_mmscfd = get_kgps_to_mmscfd_conversion_factor(params(ss))
        (units == 0) && (return pu * nominal_values(ss, :mass_flow)) 
        return pu * nominal_values(ss, :mass_flow) * kgps_to_mmscfd
    end 

    function density_convertor(pu)
        return pu * nominal_values(ss, :density)
    end 
    
    for i in collect(keys(ref(ss, :node)))     
        sol.state[:node][i]["pressure"] =ref(ss, :node, i, "pressure")
        sol.state[:node][i]["potential"] =ref(ss, :node, i, "potential")
    end

    for i in collect(keys(ref(ss, :pipe)))
        sol.state[:pipe][i]["flow"] = ref(ss, :pipe, i, "flow")
    end
    
    if haskey(ref(ss), :compressor)
        for i in collect(keys(ref(ss, :compressor)))
            sol.state[:compressor][i]["flow"] = ref(ss, :compressor, i, "flow")
        end
    end

    if haskey(ref(ss), :control_valve)
        for i in collect(keys(ref(ss, :control_valve)))
            sol.state[:control_valve][i]["flow"] = ref(ss, :control_valve, i, "flow")
        end 
    end 


    if haskey(ref(ss), :valve)
        for i in collect(keys(ref(ss, :valve)))
            sol.state[:valve][i]["flow"] = ref(ss, :valve, i, "flow")
        end 
    end 


    if haskey(ref(ss), :resistor)
        for i in collect(keys(ref(ss, :resistor)))
            sol.state[:resistor][i]["flow"] = ref(ss, :resistor, i, "flow")
        end 
    end 

    if haskey(ref(ss), :loss_resistor)
        for i in collect(keys(ref(ss, :loss_resistor)))
            sol.state[:loss_resistor][i]["flow"] = ref(ss, :loss_resistor, i, "flow")
        end 
    end 

    if haskey(ref(ss), :short_pipe)
        for i in collect(keys(ref(ss, :short_pipe)))
            sol.state[:short_pipe][i]["flow"] = ref(ss, :short_pipe, i, "flow")
        end 
    end 
    return
end 

function is_solution_feasible!(ss::SteadySimulator)
    net = ss.net 
    sol = ss.solution
    min_pressure_bound = []
    max_pressure_bound = []
    for i in collect(keys(ref(ss, :node)))  
        p = sol.state[:node][i]["pressure"]
        p_min = ref(net, :node, i, "min_pressure")
        p_max = ref(net, :node, i, "max_pressure")
        (p > p_max) && (push!(max_pressure_bound, i))
        (p < p_min) && (push!(min_pressure_bound, i))
    end 
    return isempty(max_pressure_bound) && isempty(min_pressure_bound), min_pressure_bound, max_pressure_bound
end 

function is_solution_feasible!(net::NetworkData, sol::Solution)
    min_pressure_bound = []
    max_pressure_bound = []
    for i in collect(keys(ref(net, :node)))  
        p = sol.state[:node][i]["pressure"]
        p_min = ref(net, :node, i, "min_pressure")
        p_max = ref(net, :node, i, "max_pressure")
        (p > p_max) && (push!(max_pressure_bound, i))
        (p < p_min) && (push!(min_pressure_bound, i))
    end 
    return isempty(max_pressure_bound) && isempty(min_pressure_bound), min_pressure_bound, max_pressure_bound
end 