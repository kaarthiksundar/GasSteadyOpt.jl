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
    objective_type=profit,
    relaxation_type::Symbol=:lp, 
    )::SteadyOptimizer
    params, nominal_values = process_data!(data)
    make_per_unit!(data, params, nominal_values)
    ref = build_ref(data, ref_extensions= [
        _add_pipe_info_at_nodes!,
        _add_compressor_info_at_nodes!,
        _add_receipts_at_nodes!,
        _add_deliveries_at_nodes!
        ]
    )

    relaxation = (relaxation_type == :lp) ? lp_relaxation : unknown_model
    sopt = SteadyOptimizer(
        data, 
        ref, 
        _initialize_solution(data), 
        nominal_values, 
        params, 
        (populate_nlp) ? OptModel(nlp, objective_type) : OptModel(), 
        OptModel(relaxation, objective_type), 
        _get_eos(eos)...
    )

    _add_nodal_potential_bounds_to_ref!(sopt)
    _add_pipe_flow_bounds_to_ref!(sopt)
    _add_compressor_flow_bounds_to_ref!(sopt)

    return sopt
end
