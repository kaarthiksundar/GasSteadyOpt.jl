function initialize_optimizer(data_folder::AbstractString;
    case_name::AbstractString="", 
    case_types::Vector{Symbol}=Symbol[],
    kwargs...)::SteadyOptimizer
    data = _parse_data(data_folder; 
        case_name=case_name, 
        case_types=case_types
    )
    return initialize_optimizer(data; kwargs...)
end

function initialize_optimizer(data::Dict{String,Any}; 
    eos::Symbol=:ideal, 
    populate_nlp::Bool=true, 
    objective_type::OBJECTIVE_TYPE=profit,
    relaxation_type::Symbol=:lp, 
    perform_obbt::Bool=false, 
    obbt_relaxation_type::Symbol=:lp
    )::SteadyOptimizer
    params, nominal_values = process_data!(data)
    make_per_unit!(data, params, nominal_values)
    # create ref 
    ref = build_ref(data, ref_extensions= [
        _add_pipe_info_at_nodes!,
        _add_compressor_info_at_nodes!,
        _add_receipts_at_nodes!,
        _add_deliveries_at_nodes!,
        _add_nodes_incident_on_compressors!
        ]
    )

    # create relaxation types
    relaxation = (relaxation_type == :lp) ? lp_relaxation : unknown_model
    obbt_relaxation = (obbt_relaxation_type == :lp) ? lp_relaxation : unknown_model

    # construction optimizer object
    sopt = SteadyOptimizer(
        data, 
        ref, 
        _initialize_solution(data), 
        nominal_values, 
        params, 
        (populate_nlp) ? OptModel(nlp, objective_type) : OptModel(), 
        OptModel(relaxation, objective_type), 
        OptModel(relaxation, power_surrogate),
        (perform_obbt) ? OptModel(obbt_relaxation) : OptModel(),
        Dict{Symbol,Any}(),
        _get_eos(eos)...
    )

    # add additional bounds to ref
    _add_nodal_potential_bounds_to_ref!(sopt)
    _add_pipe_flow_bounds_to_ref!(sopt)
    _add_compressor_flow_bounds_to_ref!(sopt)

    (populate_nlp) && (create_nlp_model(sopt))

    return sopt
end
