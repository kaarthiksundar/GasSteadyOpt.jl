""" potential variables for each node in the network """
function _add_nodal_potential_variables!(sopt::SteadyOptimizer, opt_model::OptModel) 
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :node))
    var[:potential] = @variable(m, [i in ids], 
        lower_bound = get_potential(sopt, ref(sopt, :node, i, "min_pressure")), 
        upper_bound = get_potential(sopt, ref(sopt, :node, i, "min_pressure")), 
        base_name = "pi"
    )
end 

""" pressure variables for each node in the network incident on a compressor if EOS is non-ideal """
function _add_nodal_pressure_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    _, b2 = get_eos_coeffs(sopt)
    is_ideal = isapprox(b2, 0.0)
    if (is_ideal)
        ids = union(
            Set(ref(sopt, :control_valve_nodes)), 
            Set(ref(sopt, :loss_resistor_nodes))
        ) |> collect
        var[:pressure] = @variable(m, [i in ids], 
            lower_bound = ref(sopt, :node, i, "min_pressure"), 
            upper_bound = ref(sopt, :node, i, "max_pressure"),
            base_name = "p"
        )
    else 
        ids = union(
            Set(ref(sopt, :control_valve_nodes)), 
            Set(ref(sopt, :loss_resistor_nodes)),
            Set(ref(sopt, :compressor_nodes))
        ) |> collect 
        var[:pressure] = @variable(m, [i in ids], 
            lower_bound = ref(sopt, :node, i, "min_pressure"), 
            upper_bound = ref(sopt, :node, i, "max_pressure"),
            base_name = "p"
        )
    end 
    
end 

""" flow variables for each pipe in the network """ 
function _add_pipe_flow_variables!(sopt::SteadyOptimizer, 
    opt_model::OptModel; 
    nlp::Bool=true
)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :pipe))
    var[:pipe_flow] = @variable(m, [i in ids],
        lower_bound = ref(sopt, :pipe, i, "min_flow"),
        upper_bound = ref(sopt, :pipe, i, "max_flow"), 
        base_name = "fp"
    )
    (nlp == true) && (return)
    var[:pipe_flow_lifted] = @variable(m, [i in ids], 
        lower_bound = sign(ref(sopt, :pipe, i, "min_flow")) * ref(sopt, :pipe, i, "min_flow")^2,
        upper_bound = sign(ref(sopt, :pipe, i, "max_flow")) * ref(sopt, :pipe, i, "max_flow")^2,
        base_name = "f_mod_f"
    )
end 

""" flow variables for each compressor in the network """ 
function _add_compressor_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :compressor))
    var[:compressor_flow] = @variable(m, [i in ids],
        base_name = "fc"
    )
    var[:compressor_status] = @variable(m, [i in ids],
        binary = true, base_name = "xc"
    )
    var[:compressor_active] = @variable(m, 
        [i in ids; ref(sopt, :compressor, i, "internal_bypass_required") == true], 
        binary = true, base_name = "xc_ac"
    )
    var[:compressor_bypass] = @variable(m, 
        [i in ids; ref(sopt, :compressor, i, "internal_bypass_required") == true], 
        binary = true, base_name = "xc_bp"
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
function _add_variables!(sopt::SteadyOptimizer, 
    opt_model::OptModel; 
    nlp::Bool=true
)
    _add_nodal_potential_variables!(sopt, opt_model)
    _add_nodal_pressure_variables!(sopt, opt_model)
    _add_pipe_flow_variables!(sopt, opt_model, nlp=nlp)
    _add_compressor_variables!(sopt, opt_model)
end 