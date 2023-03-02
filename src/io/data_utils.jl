function _parse_data(data_folder::AbstractString, 
    nomination_case::AbstractString; 
    slack_pressure::Float64=NaN,
    case_name::AbstractString="", 
    case_types::Vector{Symbol}=Symbol[])
    
    # check for zip file
    if endswith(data_folder, ".zip")
        zip_reader = ZipFile.Reader(data_folder) 
        file_paths = [x.name for x in zip_reader.files]
        fids = _get_fids(file_paths, case_name, case_types)
        network_data = _parse_json_file_from_zip(zip_reader, fids.network)
        params_data = _parse_json_file_from_zip(zip_reader, fids.params)
        nominations = _parse_json_file_from_zip(zip_reader, fids.nominations)
        slack_nodes = _parse_json_file_from_zip(zip_reader, fids.slack_nodes)
        if !haskey(nominations, nomination_case) || !haskey(slack_nodes, nomination_case)
            error("the nominations case \"$nomination_case\" is not present in the nominations or the slack nodes files")
        end 
        nominations_data = nominations[nomination_case]
        slack_nodes_data = Dict{String,Any}("slack_node" => slack_nodes[nomination_case])
        decision_group_data = (!isnothing(fids.decision_group)) ? _parse_json_file_from_zip(zip_reader, fids.decision_group) : Dict{String,Any}()
        slack_pressure_data = Dict{String,Any}("slack_pressure" => slack_pressure)
        if (isempty(decision_group_data))
            return merge(network_data, params_data, nominations_data, slack_nodes_data, slack_pressure_data)
        end  
        
        return merge(network_data, params_data, nominations_data, slack_nodes_data, slack_pressure_data, decision_group_data)
    end

    network_file = data_folder * "network.json"
    params_file = data_folder * "params"
    nominations_file = data_folder * "nominations"
    slack_nodes_file = data_folder * "slack_nodes"
    decision_group_file = data_folder * "decision_groups.json"

    params_file = 
        if (:params in case_types) 
            params_file * "_" * case_name * ".json"
        else 
            params_file * ".json"
        end
        
    nominations_file = 
        if (:nominations in case_types)
            nominations_file * "_" * case_name * ".json"
        else 
            nominations_file * ".json"
        end 

    slack_nodes_file = 
        if (:slack_nodes in case_types) 
            slack_nodes_file * "_" * case_name * ".json"
        else 
            slack_nodes_file * ".json"
        end 

    network_data = _parse_json(network_file)
    params_data = _parse_json(params_file)
    nominations = _parse_json(nominations_file)
    slack_nodes = _parse_json(slack_nodes_file)
    if !haskey(nominations, nomination_case) || !haskey(slack_nodes, nomination_case)
        error("the nominations case \"$nomination_case\" is not present in the nominations or the slack nodes files")
    end 
    nominations_data = nominations[nomination_case]
    slack_nodes_data = Dict{String,Any}("slack_node" => slack_nodes[nomination_case])
    decision_group_data = _parse_json(decision_group_file)
    slack_pressure_data = Dict{String,Any}("slack_pressure" => slack_pressure)

    if (isempty(decision_group_data))
        return merge(network_data, 
        params_data, 
        nominations_data, 
        slack_nodes_data, 
        slack_pressure_data)
    end  
    
    return merge(network_data, 
        params_data, 
        nominations_data, 
        slack_nodes_data, 
        slack_pressure_data,
        decision_group_data)
end 

function _get_fids(file_paths::Vector, 
    case_name::AbstractString, 
    case_types::Vector{Symbol}
)::NamedTuple 
    network_fid = findfirst(x -> occursin("network.json", x), file_paths)
    
    params_file_match_str = 
        if (:params in case_types) 
            "params_" * case_name * ".json"
        else 
            "params.json"
        end
    params_fid = findfirst(x -> occursin(params_file_match_str, x), file_paths)
    
    nominations_file_match_str = 
        if (:nominations in case_types)
            "nominations_" * case_name * ".json"
        else 
            "nominations.json"
        end 
    nominations_fid = findfirst(x -> occursin(nominations_file_match_str, x), file_paths)
    
    slack_nodes_file_match_str = 
        if (:slack_nodes in case_types) 
            "slack_nodes_" * case_name * ".json"
        else 
            "slack_nodes.json"
        end 
    slack_nodes_fid = findfirst(x -> occursin(slack_nodes_file_match_str, x), file_paths)

    decision_group_fid = findfirst(x -> occursin("decision_groups.json", x), file_paths)

    return (network = network_fid, params = params_fid, nominations = nominations_fid, 
        slack_nodes = slack_nodes_fid, decision_group = decision_group_fid)
end 

function _get_nominal_pressure(data::Dict{String,Any}, units)
    if isnan(data["slack_pressure"])
        data["slack_pressure"] = data["nodes"][data["slack_node"]]["max_pressure"]
    end 
    (units == 1) && (return data["slack_pressure"] *  6894.75729)
    return data["slack_pressure"]
end 

function process_data!(data::Dict{String,Any})
    nominal_values = Dict{Symbol,Any}()
    params = Dict{Symbol,Any}()

    params_exhaustive = ["temperature", 
        "gas_specific_gravity",
        "specific_heat_capacity_ratio", 
        "nominal_length", 
        "nominal_velocity", 
        "nominal_pressure",
        "nominal_density",
        "units"]

    defaults_exhaustive = [288.706, 0.6, 1.4, 5000.0, NaN, NaN, NaN, 0]

    optimization_params = data["params"]
    
    key_map = Dict{String,String}()
    for k in keys(optimization_params)
        occursin("Temperature", k) && (key_map["temperature"] = k)
        occursin("Gas", k) && (key_map["gas_specific_gravity"] = k)
        occursin("Specific heat", k) &&
            (key_map["specific_heat_capacity_ratio"] = k)
        occursin("length", k) && (key_map["nominal_length"] = k)
        occursin("velocity", k) && (key_map["nominal_velocity"] = k)
        occursin("pressure", k) && (key_map["nominal_pressure"] = k)
        occursin("density", k) && (key_map["nominal_density"] = k)
        occursin("units", k) && (key_map["units"] = k)
    end

    # add "area" key to pipes in data
    for (_, pipe) in get(data, "pipes", [])
        pipe["area"] = pi * pipe["diameter"] * pipe["diameter"] * 0.25
    end

        # add "area" key to resistors in data
        for (_, resistor) in get(data, "resistors", [])
            resistor["area"] = pi * resistor["diameter"] * resistor["diameter"] * 0.25
        end

    # populating parameters
    for i in eachindex(params_exhaustive)
        param = params_exhaustive[i]
        default = defaults_exhaustive[i]
        if param == "units"
            if haskey(key_map, param)
                value = Int(optimization_params[key_map[param]])
                if (value == 0)
                    params[:units] = 0
                    params[:is_si_units] = 1
                    params[:is_english_units] = 0
                    params[:is_per_unit] = 0
                else
                    params[:units] = 1
                    params[:is_is_units] = 0
                    params[:is_english_units] = 1
                    params[:is_per_unit] = 0
                end
            else
                params[:units] = 0
                params[:is_si_units] = 1
                params[:is_english_units] = 0
                params[:is_per_unit] = 0
            end
            continue
        end
        
        key = get(key_map, param, false)
        if key != false
            value = optimization_params[key]
            params[Symbol(param)] = value
        else
            params[Symbol(param)] = default
        end
    end

    # other parameter calculations
    # universal gas constant (J/mol/K)
    params[:R] = 8.314
    # molecular mass of natural gas (kg/mol): M_g = M_a * G
    params[:gas_molar_mass] = 0.02896 * params[:gas_specific_gravity]
    params[:warning] = "R, temperature are in SI units. Rest are dimensionless"

    # sound speed (m/s): v = sqrt(R_g * T); 
    # R_g = R/M_g = R/M_a/G; R_g is specific gas constant; g-gas, a-air
    nominal_values[:sound_speed] = sqrt(params[:R] * params[:temperature] / params[:gas_molar_mass])
    nominal_values[:velocity] = params[:nominal_velocity] # choose based on mass flows
    nominal_values[:length] = params[:nominal_length]
    nominal_values[:area] = 1.0
    nominal_values[:pressure] = 
    if isnan(params[:nominal_pressure]) 
        _get_nominal_pressure(data, params[:units]) 
    else 
        params[:nominal_pressure]
    end
    nominal_values[:density] = 
    if isnan(params[:nominal_density]) 
        nominal_values[:pressure] / (nominal_values[:sound_speed]^2)
    else 
        params[:nominal_density]
    end 
    nominal_values[:velocity] =
    if isnan(params[:nominal_velocity])
       floor(nominal_values[:sound_speed]/100)
    else
        params[:nominal_velocity]
    end
    nominal_values[:mass_flux] = nominal_values[:density] * nominal_values[:velocity]
    nominal_values[:mass_flow] = nominal_values[:mass_flux] * nominal_values[:area]
    nominal_values[:gas_cost] = 1/nominal_values[:mass_flow]
    nominal_values[:euler_num] = nominal_values[:pressure] / (nominal_values[:density] * nominal_values[:sound_speed]^2)
    nominal_values[:mach_num] = nominal_values[:velocity] / nominal_values[:sound_speed]
    
    return params, nominal_values
end

""" fixes internal_bypass_required flags for compressors and control valves using DGs"""
function _fix_data!(data::Dict{String,Any})
    for (_, dg) in data["decision_groups"]
        decisions = dg["decisions"]
        for (_, decision) in decisions 
            for component in decision 
                if component["component_type"] == "compressor"
                    id = component["id"]
                    if haskey(component, "flow_direction") || haskey(component, "mode")
                        data["compressors"][string(id)]["internal_bypass_required"] = 1
                    end 
                end 
                if component["component_type"] == "control_valve"
                    id = component["id"]
                    if haskey(component, "flow_direction") || haskey(component, "mode")
                        data["control_valves"][string(id)]["internal_bypass_required"] = 1
                    end 
                end 
            end 
        end 
    end 
end 