function change_nominal_velocity!(data::Dict)
    data["params"]["nominal_velocity"] = 0.1 
end 

function strengthen_flow_bounds!(data::Dict)
    total_withdrawal = 0.0 
    for (_, nomination) in get(data, "exit_nominations", [])
        q = nomination["max_withdrawal"]
        (q > 0.0) && (total_withdrawal += q)
    end 
    edge_types = ["pipes", "short_pipes", "resistors", "loss_resistors", "compressors", "control_valves", "valves"]
    for edge_type in edge_types 
        edges = get(data, edge_type, [])
        for (i, edge) in edges 
            if haskey(edge, "max_flow") && total_withdrawal < edge["max_flow"]
                data[edge_type][i]["max_flow"] = total_withdrawal
            end 
            if haskey(edge, "min_flow") && (-1.0 * total_withdrawal) > edge["min_flow"]
                data[edge_type][i]["min_flow"] = -total_withdrawal
            end
        end 
    end 
end 

function modify_entry_nominations!(data::Dict)
    for (i, nomination) in get(data, "entry_nominations", [])
        if (nomination["max_injection"] > 0.0)
            data["entry_nominations"][i]["min_injection"] = 0.0 
            data["entry_nominations"][i]["max_injection"] += (data["entry_nominations"][i]["max_injection"] * 0.05)
        end 
    end 
    non_zero_injectors = filter(x -> last(x)["max_injection"] > 0.0, get(data, "entry_nominations", [])) 
    sorted_injectors = sort(non_zero_injectors |> collect, by = x -> -last(x)["max_injection"])
    b = (sorted_injectors |> last |> last)["max_injection"]
    a = (sorted_injectors |> first |> last)["max_injection"]
    c = 1.0
    d = 5.0 

    f(t) = c + (d - c)/(b - a) * (t - a)
    (isempty(non_zero_injectors)) && (return)
    for (i, _) in non_zero_injectors
        data["entry_nominations"][i]["cost"] = f(data["entry_nominations"][i]["max_injection"])
    end 
    return 
end 