function initialize_optimizer(data_folder::AbstractString, 
    nomination_case::AbstractString;
    case_name::AbstractString="", 
    case_types::Vector{Symbol}=Symbol[],
    slack_pressure::Float64 = NaN,
    kwargs...)::SteadyOptimizer
    data = _parse_data(data_folder, nomination_case; 
        slack_pressure=slack_pressure,
        case_name=case_name, 
        case_types=case_types
    )
    return initialize_optimizer(data; kwargs...)
end

function initialize_optimizer(data::Dict{String,Any}; 
    eos::Symbol=:ideal)::SteadyOptimizer
    # process data
    params, nominal_values = process_data!(data)
    make_per_unit!(data, params, nominal_values)
    # create ref 
    ref = build_ref(data, ref_extensions= [
        _add_pipe_info_at_nodes!,
        _add_compressor_info_at_nodes!,
        _add_control_valve_info_at_nodes!,
        _add_valve_info_at_nodes!,
        _add_resistor_info_at_nodes!,
        _add_loss_resistor_info_at_nodes!,
        _add_short_pipe_info_at_nodes!,
        _add_entries_at_nodes!,
        _add_exits_at_nodes!,
        _add_decision_groups!,
        _add_compressor_nodes!, 
        _add_control_valve_nodes!, 
        _add_loss_resistor_nodes!
        ]
    )

    # construction optimizer object
    sopt = SteadyOptimizer(
        data, 
        ref, 
        _initialize_solution(data), 
        nominal_values, 
        params, 
        OptModel(), 
        OptModel(),
        Dict{Symbol,Any}(),
        _get_eos(eos)...
    )

    return sopt
end
