function _add_components_to_ref!(ref::Dict{Symbol,Any}, data::Dict{String,Any})

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
    end

    for (i, compressor) in get(data, "compressors", [])
        name = :compressor
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
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
    end

    for (i, control_valve) in get(data, "control_valves", [])
        name = :control_valve
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
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
    end 

    for (i, valve) in get(data, "valves", [])
        name = :valve
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == valve["id"]
        ref[name][id]["id"] = id
        ref[name][id]["fr_node"] = valve["fr_node"]
        ref[name][id]["to_node"] = valve["to_node"]
        ref[name][id]["min_flow"] = get(valve, "min_flow", NaN)
        ref[name][id]["max_flow"] = get(valve, "max_flow", NaN)
        ref[name][id]["max_pressure_differential"] = get(valve, "max_pressure_differential", NaN)
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
    end 

    for (i, entry) in get(data, "entries", [])
        name = :entry
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == entry["id"]
        ref[name][id]["id"] = id
        ref[name][id]["node_id"] = entry["node_id"]
        ref[name][id]["min_injection"] = data["entry_nominations"][i]["min_injection"]
        ref[name][id]["max_injection"] = data["entry_nominations"][i]["max_injection"]
        ref[name][id]["cost"] = data["entry_nominations"][i]["cost"]
    end 

    for (i, exit) in get(data, "exits", [])
        name = :exit
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == exit["id"]
        ref[name][id]["id"] = id
        ref[name][id]["node_id"] = exit["node_id"] 
        ref[name][id]["min_withdrawal"] = data["exit_nominations"][i]["min_withdrawal"]
        ref[name][id]["max_withdrawal"] = data["exit_nominations"][i]["max_withdrawal"]
        ref[name][id]["cost"] = data["exit_nominations"][i]["cost"]
    end 
    return
end

function _add_decision_groups!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    for (i, dg) in get(data, "decision_groups", [])
        name = :decision_group 
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        ref[name][id]["decisions"] = Dict()
        ref[name][id]["num_decisions"] = length(dg["decisions"])
        for (j, dec) in get(dg, "decisions", [])
            id_j = parse(Int64, j)
            ref[name][id]["decisions"][id_j] = Dict()
            for entry in dec 
                for (key, value) in entry
                    (key == "component_type" || key == "id") && (continue)  
                    component_type = Symbol(entry["component_type"])
                    component_id = entry["id"]
                    new_key = (component_type, component_id)
                    if (!haskey(ref[name][id]["decisions"][id_j], new_key))
                        ref[name][id]["decisions"][id_j][new_key] = Dict()
                    end 
                    if key == "value"
                        ref[name][id]["decisions"][id_j][new_key]["on_off"] = 
                            Bool(parse(Int64, value)) 
                    elseif key == "flow_direction"
                        ref[name][id]["decisions"][id_j][new_key][key] = 
                            parse(Int64, value)
                    else 
                        ref[name][id]["decisions"][id_j][new_key][key] = value
                    end
                end                
            end 
        end 
    end 
    for (_, dg) in get(ref, :decision_group, [])
        components = collect(keys(dg["decisions"][1]))
        dg["compressors"] = map(it -> last(it), filter(it -> first(it) == :compressor, components))
        dg["valves"] = map(it -> last(it), filter(it -> first(it) == :valve, components))
        dg["control_valves"] =  map(it -> last(it), filter(it -> first(it) == :control_valve, components))
        dg["num_components"] = length(components)
    end     
end 


function _add_pipe_info_at_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:incoming_pipes] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )
    ref[:outgoing_pipes] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )

    for (id, pipe) in ref[:pipe]
        push!(ref[:incoming_pipes][pipe["to_node"]], id)
        push!(ref[:outgoing_pipes][pipe["fr_node"]], id)
    end
    return
end

function _add_compressor_info_at_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:incoming_compressors] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )
    ref[:outgoing_compressors] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )

    for (id, compressor) in get(ref, :compressor, [])
        push!(ref[:incoming_compressors][compressor["to_node"]], id)
        push!(ref[:outgoing_compressors][compressor["fr_node"]], id)
    end
    return
end

function _add_control_valve_info_at_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:incoming_control_valves] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )
    ref[:outgoing_control_valves] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )

    for (id, control_valve) in get(ref, :control_valve, [])
        push!(ref[:incoming_control_valves][control_valve["to_node"]], id)
        push!(ref[:outgoing_control_valves][control_valve["fr_node"]], id)
    end
    return
end

function _add_valve_info_at_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:incoming_valves] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )
    ref[:outgoing_valves] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )
    
    for (id, valve) in get(ref, :valve, [])
        push!(ref[:incoming_valves][valve["to_node"]], id)
        push!(ref[:outgoing_valves][valve["fr_node"]], id)
    end
    return
end

function _add_resistor_info_at_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:incoming_resistors] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )
    ref[:outgoing_resistors] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )
    
    for (id, resistor) in get(ref, :resistor, [])
        push!(ref[:incoming_resistors][resistor["to_node"]], id)
        push!(ref[:outgoing_resistors][resistor["fr_node"]], id)
    end
    return
end

function _add_loss_resistor_info_at_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:incoming_loss_resistors] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )
    ref[:outgoing_loss_resistors] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )
    
    for (id, loss_resistor) in get(ref, :loss_resistor, [])
        push!(ref[:incoming_loss_resistors][loss_resistor["to_node"]], id)
        push!(ref[:outgoing_loss_resistors][loss_resistor["fr_node"]], id)
    end
    return
end

function _add_short_pipe_info_at_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:incoming_short_pipes] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )
    ref[:outgoing_short_pipes] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )

    for (id, short_pipe) in get(ref, :short_pipe, [])
        push!(ref[:incoming_short_pipes][short_pipe["to_node"]], id)
        push!(ref[:outgoing_short_pipes][short_pipe["fr_node"]], id)
    end
    return
end


function _add_entries_at_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:entries_at_node] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )

    for (id, entry) in get(ref, :entry, [])
        push!(ref[:entries_at_node][entry["node_id"]], id)
    end 
    return
end 

function _add_exits_at_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:exits_at_node] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )

    for (id, exit) in get(ref, :exit, [])
        push!(ref[:exits_at_node][exit["node_id"]], id)
    end 
    return
end 

function _add_compressor_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:compressor_nodes] = [] 

    for (_, compressor) in get(ref, :compressor, [])
        push!(ref[:compressor_nodes], compressor["fr_node"])
        push!(ref[:compressor_nodes], compressor["to_node"])
    end 
end 

function _add_control_valve_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:control_valve_nodes] = [] 

    for (_, control_valve) in get(ref, :control_valve, [])
        push!(ref[:control_valve_nodes], control_valve["fr_node"])
        push!(ref[:control_valve_nodes], control_valve["to_node"])
    end 
end 

function _add_valve_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:valve_nodes] = [] 

    for (_, valve) in get(ref, :valve, [])
        push!(ref[:valve_nodes], valve["fr_node"])
        push!(ref[:valve_nodes], valve["to_node"])
    end 
end 

function _add_loss_resistor_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:loss_resistor_nodes] = [] 

    for (_, loss_resistor) in get(ref, :loss_resistor, [])
        push!(ref[:loss_resistor_nodes], loss_resistor["fr_node"])
        push!(ref[:loss_resistor_nodes], loss_resistor["to_node"])
    end 
end 

function build_ref(data::Dict{String,Any};
    ref_extensions=[])::Dict{Symbol,Any}

    ref = Dict{Symbol,Any}()
    _add_components_to_ref!(ref, data)

    for extension in ref_extensions
        extension(ref, data)
    end

    return ref
end