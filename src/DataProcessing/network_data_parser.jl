function _parse_network_data(data_folder::AbstractString, 
    nomination_case::AbstractString; 
    slack_pressure::Float64=NaN
)
    # check for zip file
    if endswith(data_folder, ".zip")
        zip_reader = ZipFile.Reader(data_folder) 
        file_paths = [x.name for x in zip_reader.files]
        fids = _get_fids(file_paths)
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
    params_file = data_folder * "params.json"
    nominations_file = data_folder * "nominations.json"
    slack_nodes_file = data_folder * "slack_nodes.json"
    decision_group_file = data_folder * "decision_groups.json"

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

function _get_fids(file_paths::Vector)::NamedTuple 
    network_fid = findfirst(x -> occursin("network.json", x), file_paths)
    
    params_file_match_str = "params.json"
    params_fid = findfirst(x -> occursin(params_file_match_str, x), file_paths)
    
    nominations_file_match_str = "nominations.json"
    nominations_fid = findfirst(x -> occursin(nominations_file_match_str, x), file_paths)
    
    slack_nodes_file_match_str = "slack_nodes.json"
    slack_nodes_fid = findfirst(x -> occursin(slack_nodes_file_match_str, x), file_paths)

    decision_group_fid = findfirst(x -> occursin("decision_groups.json", x), file_paths)

    return (network = network_fid, params = params_fid, nominations = nominations_fid, 
        slack_nodes = slack_nodes_fid, decision_group = decision_group_fid)
end 
