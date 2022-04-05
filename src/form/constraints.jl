""" slack node constraints """ 
function _add_slack_node_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    con = opt_model.constraints
    var = opt_model.variables
    ids = ref(sopt, :slack_nodes)
    _, b2 = get_eos_coeffs(sopt)
    is_ideal = isapprox(b2, 0.0)
    
    con[:slack_potential_fixing] = @constraint(m, [i in ids], 
        var[:potential][i] == ref(sopt, :node, i, "slack_potential"))
    
    (is_ideal) && (return)
    
    con[:slack_pressure_fixing] = @constraint(m, [i in ids; ref(sopt, :is_node_incident_on_compressor, i) == true], 
        var[:pressure][i] == ref(sopt, :node, i, "slack_pressure"))
end 

""" nodal balance constraints """ 
function _add_nodal_balance_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    con = opt_model.constraints
    var = opt_model.variables
    ids = keys(ref(sopt, :node))
    con[:nodal_balance] = @constraint(m, [i in ids], 
        sum(var[:pipe_flow][j] for j in ref(sopt, :incoming_pipes, i)) + 
        sum(var[:compressor_flow][j] for j in ref(sopt, :incoming_compressors, i)) + 
        sum(var[:injection][j] for j in ref(sopt, receipts_at_node, i)) ==
        sum(var[:pipe_flow][j] for j in ref(sopt, :outgoing_pipes, i)) + 
        sum(var[:compressor_flow][j] for j in ref(sopt, :outgoing_compressors, i)) +
        sum(var[:withdrawal][j] for j in ref(sopt, deliveries_at_node, i)) 
    )
end 

""" pipe physics constraints """
function _add_pipe_physics_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    con = opt_model.constraints 
    var = opt_model.variables 
    ids = keys(ref(sopt, :pipe))
    pipe = ref(sopt, :pipe)
    c = nominal_values(sopt, :mach_num)^2 / nominal_values(sopt, :euler_num) 
    resistance = Dict(i => val["friction_factor"] * val["length"] * c / (2 * val["diameter"] * val["area"]^2) for (i, val) in pipe)
    if (opt_model.model_type == nlp)
        con[:pipe_physics] = @constraint(m, [i in ids],
            var[:potential][pipe[i]["fr_node"]] - var[:potential][pipe[i]["to_node"]] == 
            resistance[i] * var[:pipe_flow][i] * abs(var[:pipe_flow][i])
        )
    end 
    if (opt_model.model_type == lp_relaxation)
        return
    end 
end 


""" add all constraints to the model """
function _add_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    _add_slack_node_constraints!(sopt, opt_model)
    _add_nodal_balance_constraints!(sopt, opt_model)
    _add_pipe_physics_constraints!(sopt, opt_model)
    _add_compressor_physics_constraints!(sopt, opt_model)
end 