""" potential variables for each node in the network """
function _add_nodal_potential_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :node))
    var[:potential] = @variable(m, [i in ids], 
        lower_bound = ref(sopt, :node, i, "min_potential"), 
        upper_bound = ref(sopt, :node, i, "max_potential"), 
        base_name = "pi"
    )
end 

""" pressure variables for each node in the network incident on a compressor if EOS is non-ideal """
function _add_nodal_pressure_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(filter(it -> last(it), ref(sopt, :is_node_incident_on_compressor)))
    _, b2 = get_eos_coeffs(sopt)
    isapprox(b2, 0.0) && (return)
    var[:pressure] = @variable(m, [i in ids], 
        lower_bound = ref(sopt, :node, i, "min_pressure"), 
        upper_bound = ref(sopt, :node, i, "max_pressure"),
        base_name = "p"
    )
end 

""" flow variables for each pipe in the network """ 
function _add_pipe_flow_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :pipe))
    var[:pipe_flow] = @variable(m, [i in ids],
        lower_bound = ref(sopt, :pipe, i, "min_flow"),
        upper_bound = ref(spot, :pipe, i, "max_flow"), 
        base_name = "fp"
    )
    (opt_model.model_type != lp_relaxation) && (return)
    var[:pipe_flow_lifted] = @variable(m, [i in ids], 
        lower_bound = sign(ref(sopt, :pipe, i, "min_flow")) * ref(sopt, :pipe, i, "min_flow")^2,
        upper_bound = sign(ref(sopt, :pipe, i, "max_flow")) * ref(sopt, :pipe, i, "max_flow")^2
        base_name = "f_mod_f"
    )
end 

""" flow variables for each compressor in the network """ 
function _add_compressor_flow_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :compressor))
    var[:compressor_flow] = @variable(m, [i in ids],
        lower_bound = ref(sopt, :compressor, i, "min_flow"),
        upper_bound = ref(spot, :compressor, i, "max_flow"), 
        base_name = "fc"
    )
end 

""" auxiliary potential/pressure (ideal/non-ideal) variable for each compressor in the network """ 
function _add_compressor_auxiliary_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :compressor))
    var[:compressor_auxiliary] = @variable(m, [i in ids],
        lower_bound = ref(sopt, :compressor, i, "min_flow"),
        upper_bound = ref(spot, :compressor, i, "max_flow"),
        base_name = "aux_c"
    )
end 

""" injection variables for each receipt in the network """ 
function _add_receipt_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :receipt))
    var[:injection] = @variable(m, [i in ids], 
        lower_bound = ref(sopt, :receipt, i, "min_injection"), 
        upper_bound = ref(sopt, :receipt, i, "max_injection"), 
        base_name = "s"
    )
end 

""" withdrawal variables for each delivery in a network """ 
function _add_delivery_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :delivery))
    var[:withdrawal] = @variable(m, [i in ids], 
        lower_bound = ref(sopt, :delivery, i, "min_withdrawal"),
        upper_bound = ref(sopt, :delivery, i, "max_withdrawal"),
        base_name = "d"
    )
end

""" add all variables to the model """
function _add_variables(sopt::SteadyOptimizer, opt_model::OptModel)
    _add_nodal_potential_variables!(sopt, opt_model)
    _add_nodal_pressure_variables!(sopt, opt_model)
    _add_pipe_flow_variables!(sopt, opt_model)
    _add_compressor_flow_variables!(sopt, opt_model)
    _add_compressor_auxiliary_variables!(sopt, opt_model)
    _add_receipt_variables!(sopt, opt_model)
    _add_delivery_variables!(sopt,opt_model)
end 