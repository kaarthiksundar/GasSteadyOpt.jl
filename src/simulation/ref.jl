function _add_components_to_ref!(ref::Dict{Symbol,Any}, data::Dict{String,Any}, control::Dict{Symbol,Any})

    ref[:slack_nodes] = isa(data["slack_node"], AbstractString) ? [parse(Int64, data["slack_node"])] : map(x -> parse(Int64, x), data["slack_node"])
    for (i, node) in get(data, "nodes", [])
        name = :node
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == node["id"]
        ref[name][id]["id"] = id
        ref[name][id]["is_slack"] = id in ref[:slack_nodes]
        ref[name][id]["slack_pressure"] = (id in ref[:slack_nodes]) ? data["slack_pressure"] : NaN
        ref[name][id]["min_pressure"] = node["min_pressure"]
        ref[name][id]["max_pressure"] = node["max_pressure"]
        ref[name][id]["pressure"] = NaN
        ref[name][id]["density"] = NaN 
        ref[name][id]["withdrawal"] = NaN
        ref[name][id]["potential"] = NaN
    end

    for (i, pipe) in get(data, "pipes", [])
        name = :pipe
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == pipe["id"]
        ref[name][id]["id"] = id
        ref[name][id]["fr_node"] = pipe["fr_node"]
        ref[name][id]["to_node"] = pipe["to_node"]
        ref[name][id]["diameter"] = pipe["diameter"]
        ref[name][id]["area"] = pipe["area"]
        ref[name][id]["length"] = pipe["length"]
        ref[name][id]["friction_factor"] = pipe["friction_factor"]
        ref[name][id]["min_flow"] = get(pipe, "min_flow", NaN)
        ref[name][id]["max_flow"] = get(pipe, "max_flow", NaN)
        ref[name][id]["flow"] = NaN
    end

    for (i, compressor) in get(data, "compressors", [])
        name = :compressor
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        (control[:compressor][id]["status"] == 0) && (continue)
        ref[name][id] = Dict()
        @assert id == compressor["id"]
        ref[name][id]["id"] = id
        ref[name][id]["to_node"] = compressor["to_node"]
        ref[name][id]["fr_node"] = compressor["fr_node"]
        ref[name][id]["min_c_ratio"] = compressor["min_c_ratio"]
        ref[name][id]["max_c_ratio"] = compressor["max_c_ratio"]
        ref[name][id]["min_flow"] = get(compressor, "min_flow", NaN)
        ref[name][id]["max_flow"] = get(compressor, "max_flow", NaN)
        ref[name][id]["internal_bypass_required"] = get(compressor, "internal_bypass_required", 0)
        ref[name][id]["c_ratio"] = control[:compressor][id]["ratio"]
        ref[name][id]["flow"] = NaN   
    end

    for (i, control_valve) in get(data, "control_valves", [])
        name = :control_valve
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        (control[:control_valve][id]["status"] == 0) && (continue)
        ref[name][id] = Dict()
        @assert id == control_valve["id"]
        ref[name][id]["id"] = id
        ref[name][id]["fr_node"] = control_valve["fr_node"]
        ref[name][id]["to_node"] = control_valve["to_node"]
        ref[name][id]["min_flow"] = get(control_valve, "min_flow", NaN)
        ref[name][id]["max_flow"] = get(control_valve, "max_flow", NaN)
        ref[name][id]["internal_bypass_required"] = get(control_valve, "internal_bypass_required", 0)
        ref[name][id]["max_pressure_differential"] = control_valve["max_pressure_differential"]
        ref[name][id]["min_pressure_differential"] = control_valve["min_pressure_differential"]
        ref[name][id]["min_inlet_pressure"] = control_valve["min_inlet_pressure"]
        ref[name][id]["max_outlet_pressure"] = control_valve["max_outlet_pressure"]
        ref[name][id]["pressure_differential"] = control[:control_valve][id]["differential"]
        ref[name][id]["flow"] = NaN   
    end 

    for (i, valve) in get(data, "valves", [])
        name = :valve
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        (control[:valve][id]["status"] == 0) && (continue)
        ref[name][id] = Dict()
        @assert id == valve["id"]
        ref[name][id]["id"] = id
        ref[name][id]["fr_node"] = valve["fr_node"]
        ref[name][id]["to_node"] = valve["to_node"]
        ref[name][id]["min_flow"] = get(valve, "min_flow", NaN)
        ref[name][id]["max_flow"] = get(valve, "max_flow", NaN)
        ref[name][id]["max_pressure_differential"] = get(valve, "max_pressure_differential", NaN)
        ref[name][id]["flow"] = NaN  
    end 

    for (i, short_pipe) in get(data, "short_pipes", [])
        name = :short_pipe
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == short_pipe["id"]
        ref[name][id]["id"] = id
        ref[name][id]["fr_node"] = short_pipe["fr_node"]
        ref[name][id]["to_node"] = short_pipe["to_node"]
        ref[name][id]["min_flow"] = get(short_pipe, "min_flow", NaN)
        ref[name][id]["max_flow"] = get(short_pipe, "max_flow", NaN)
        ref[name][id]["flow"] = NaN   
    end 

    for (i, resistor) in get(data, "resistors", [])
        name = :resistor
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == resistor["id"]
        ref[name][id]["id"] = id
        ref[name][id]["fr_node"] = resistor["fr_node"]
        ref[name][id]["to_node"] = resistor["to_node"]
        ref[name][id]["min_flow"] = get(resistor, "min_flow", NaN)
        ref[name][id]["max_flow"] = get(resistor, "max_flow", NaN)
        ref[name][id]["drag"] = resistor["drag"]
        ref[name][id]["diameter"] = resistor["diameter"]
        ref[name][id]["area"] = resistor["area"]
        ref[name][id]["flow"] = NaN   
    end 

    for (i, loss_resistor) in get(data, "loss_resistors", [])
        name = :loss_resistor
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == loss_resistor["id"]
        ref[name][id]["id"] = id
        ref[name][id]["fr_node"] = loss_resistor["fr_node"]
        ref[name][id]["to_node"] = loss_resistor["to_node"]
        ref[name][id]["min_flow"] = get(loss_resistor, "min_flow", NaN)
        ref[name][id]["max_flow"] = get(loss_resistor, "max_flow", NaN)
        ref[name][id]["pressure_loss"] = loss_resistor["pressure_loss"]
        ref[name][id]["flow"] = NaN   
    end 

    return
end

function _add_index_info!(ref::Dict{Symbol, Any}, data::Dict{String, Any})
    dofid = 1
    ref[:dof] = Dict{Int64, Any}()
    
    for (i, node) in ref[:node]
        node["dof"] = dofid
        ref[:dof][dofid] = (:node, i)
        dofid += 1
    end

    for (i, pipe) in ref[:pipe]
        pipe["dof"] = dofid
        ref[:dof][dofid] = (:pipe, i)
        dofid += 1
    end

    for (i, compressor) in get(ref, :compressor, [])
        compressor["dof"] = dofid
        ref[:dof][dofid] = (:compressor, i)
        dofid += 1
    end

    for (i, control_valve) in get(ref, :control_valve, [])
        control_valve["dof"] = dofid
        ref[:dof][dofid] = (:control_valve, i)
        dofid += 1
    end

    for (i, valve) in get(ref, :valve, [])
        valve["dof"] = dofid
        ref[:dof][dofid] = (:valve, i)
        dofid += 1
    end

    for (i, resistor) in get(ref, :resistor, [])
        resistor["dof"] = dofid
        ref[:dof][dofid] = (:resistor, i)
        dofid += 1
    end

    for (i, loss_resistor) in get(ref, :loss_resistor, [])
        loss_resistor["dof"] = dofid
        ref[:dof][dofid] = (:loss_resistor, i)
        dofid += 1
    end

    for (i, short_pipe) in get(ref, :short_pipe, [])
        short_pipe["dof"] = dofid
        ref[:dof][dofid] = (:short_pipe, i)
        dofid += 1
    end
end

function _add_incident_dofs_info_at_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:incoming_dofs] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )
    ref[:outgoing_dofs] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )

    for (_, pipe) in ref[:pipe]
        push!(ref[:incoming_dofs][pipe["to_node"]], pipe["dof"])
        push!(ref[:outgoing_dofs][pipe["fr_node"]], pipe["dof"])
    end

    for (_, compressor) in get(ref, :compressor, [])
        push!(ref[:incoming_dofs][compressor["to_node"]], compressor["dof"])
        push!(ref[:outgoing_dofs][compressor["fr_node"]], compressor["dof"])
    end

    for (_, control_valve) in get(ref, :control_valve, [])
        push!(ref[:incoming_dofs][control_valve["to_node"]], control_valve["dof"])
        push!(ref[:outgoing_dofs][control_valve["fr_node"]], control_valve["dof"])
    end

    for (_, valve) in get(ref, :valve, [])
        push!(ref[:incoming_dofs][valve["to_node"]], valve["dof"])
        push!(ref[:outgoing_dofs][valve["fr_node"]], valve["dof"])
    end

    for (_, resistor) in get(ref, :resistor, [])
        push!(ref[:incoming_dofs][resistor["to_node"]], resistor["dof"])
        push!(ref[:outgoing_dofs][resistor["fr_node"]], resistor["dof"])
    end

    for (_, loss_resistor) in get(ref, :loss_resistor, [])
        push!(ref[:incoming_dofs][loss_resistor["to_node"]], loss_resistor["dof"])
        push!(ref[:outgoing_dofs][loss_resistor["fr_node"]], loss_resistor["dof"])
    end

    for (_, short_pipe) in get(ref, :short_pipe, [])
        push!(ref[:incoming_dofs][short_pipe["to_node"]], short_pipe["dof"])
        push!(ref[:outgoing_dofs][short_pipe["fr_node"]], short_pipe["dof"])
    end

    return
end

function _build_ref!(net::NetworkData, solution::Solution;
    ref_extensions=[])::Dict{Symbol,Any}

    ref = Dict{Symbol,Any}()
    _add_components_to_ref!(ref, net.data, solution.control)

    for extension in ref_extensions
        extension(ref, net.data)
    end

    return ref
end