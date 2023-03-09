function parse_network_data(data_folder::AbstractString, 
    nomination_case::AbstractString; 
    slack_pressure::Float64 = NaN, 
    apply_on_data::Vector{Function} = Function[],
    apply_on_ref::Vector{Function} = Function[],
    eos::Symbol=:ideal
)
    data = _parse_network_data(
        data_folder, nomination_case; 
        slack_pressure = slack_pressure
    )
    
    # fixes some inconsistencies in the GasLib data sets 
    _fix_data!(data)

    # applies user defined functions on the parsed data  
    for f in apply_on_data 
        f(data)
    end 

    # creates the nominal values and parameters dictionaries
    params, nominal_values = _process_data!(data)
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
        _add_loss_resistor_nodes!, 
        _add_valve_nodes!, 
        apply_on_ref...
        ]
    )

    return NetworkData(
        data, ref, nominal_values, params, _get_eos(eos)...
    )
end 