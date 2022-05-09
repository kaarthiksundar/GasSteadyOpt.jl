function _add_components_to_ref!(ref::Dict{Symbol,Any}, data::Dict{String,Any})

    ref[:slack_nodes] = []
    for (i, node) in get(data, "nodes", [])
        name = :node
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == node["node_id"]
        ref[name][id]["id"] = id
        ref[name][id]["is_slack"] = node["slack_bool"]
        (node["slack_bool"] == 1) && (push!(ref[:slack_nodes], id))
        ref[name][id]["slack_pressure"] = (node["slack_bool"] == 1) ? data["slack_pressure"][i] : NaN
        ref[name][id]["min_pressure"] = node["min_pressure"]
        ref[name][id]["max_pressure"] = node["max_pressure"]
        ref[name][id]["pressure"] = NaN
        ref[name][id]["density"] = NaN
        ref[name][id]["potential"] = NaN
    end

    for (i, pipe) in get(data, "pipes", [])
        name = :pipe
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == pipe["pipe_id"]
        ref[name][id]["id"] = id
        ref[name][id]["fr_node"] = pipe["from_node"]
        ref[name][id]["to_node"] = pipe["to_node"]
        ref[name][id]["diameter"] = pipe["diameter"]
        ref[name][id]["area"] = pipe["area"]
        ref[name][id]["length"] = pipe["length"]
        ref[name][id]["friction_factor"] = pipe["friction_factor"]
        ref[name][id]["flow"] = NaN
        ref[name][id]["min_flow"] = get(pipe, "min_flow", NaN)
        ref[name][id]["max_flow"] = get(pipe, "max_flow", NaN)
    end

    for (i, compressor) in get(data, "compressors", [])
        name = :compressor
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == compressor["compressor_id"]
        ref[name][id]["id"] = id
        ref[name][id]["to_node"] = compressor["to_node"]
        ref[name][id]["fr_node"] = compressor["from_node"]
        ref[name][id]["flow"] = NaN
        ref[name][id]["min_c_ratio"] = compressor["c_ratio_min"]
        ref[name][id]["max_c_ratio"] = compressor["c_ratio_max"]
        ref[name][id]["min_flow"] = get(pipe, "min_flow", NaN)
        ref[name][id]["max_flow"] = get(pipe, "max_flow", NaN)
    end

    for (i, receipt) in get(data, "receipts", [])
        name = :receipt 
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == receipt["receipt_id"]
        ref[name][id]["id"] = id
        ref[name][id]["node_id"] = receipt["node_id"]
        ref[name][id]["min_injection"] = 0.0
        ref[name][id]["max_injection"] = data["receipt_nominations"][i]["max_injection"]
        ref[name][id]["cost"] = data["receipt_nominations"][i]["cost"]
        ref[name][id]["injection"] = NaN
    end 

    for (i, delivery) in get(data, "deliveries", [])
        name = :delivery 
        (!haskey(ref, name)) && (ref[name] = Dict())
        id = parse(Int64, i)
        ref[name][id] = Dict()
        @assert id == delivery["delivery_id"]
        ref[name][id]["id"] = id
        ref[name][id]["node_id"] = delivery["node_id"]
        ref[name][id]["min_withdrawal"] = 0.0
        ref[name][id]["max_withdrawal"] = data["delivery_nominations"][i]["max_withdrawal"]
        ref[name][id]["cost"] = data["delivery_nominations"][i]["cost"]
        ref[name][id]["withdrawal"] = NaN
    end 

    return
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

function _add_receipts_at_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:receipts_at_node] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )

    for (id, receipt) in get(ref, :receipt, [])
        push!(ref[:receipts_at_node][receipt["node_id"]], id)
    end 
    return
end 

function _add_deliveries_at_nodes!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:deliveries_at_node] = Dict{Int64, Vector{Int64}}(
        i => [] for i in keys(ref[:node])
    )

    for (id, delivery) in get(ref, :delivery, [])
        push!(ref[:deliveries_at_node][delivery["node_id"]], id)
    end 
    return
end 

function _add_nodes_incident_on_compressors!(ref::Dict{Symbol,Any}, data::Dict{String,Any})
    ref[:is_pressure_node] = Dict{Int64,Bool}(
        i => false for i in keys(ref[:node])
    )

    for (_, compressor) in get(ref, :compressor, [])
        ref[:is_pressure_node][compressor["to_node"]] = true 
        ref[:is_pressure_node][compressor["fr_node"]] = true 
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