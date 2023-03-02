""" potential variables for each node in the network """
function _add_nodal_potential_variables!(sopt::SteadyOptimizer, opt_model::OptModel) 
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :node))
    (isempty(ids)) && (return)
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
            Set(ref(sopt, :loss_resistor_nodes)), 
            Set(ref(sopt, :valve_nodes))
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
            Set(ref(sopt, :compressor_nodes)), 
            Set(ref(sopt, :valve_nodes))
        ) |> collect 
        var[:pressure] = @variable(m, [i in ids], 
            lower_bound = ref(sopt, :node, i, "min_pressure"), 
            upper_bound = ref(sopt, :node, i, "max_pressure"),
            base_name = "p"
        )
    end 
    
end 

""" flow variables for each pipe in the network """ 
function _add_pipe_variables!(sopt::SteadyOptimizer, 
    opt_model::OptModel; 
    nlp::Bool=true
)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :pipe))
    (isempty(ids)) && (return)
    var[:pipe_flow] = @variable(m, [i in ids],
        lower_bound = ref(sopt, :pipe, i, "min_flow"),
        upper_bound = ref(sopt, :pipe, i, "max_flow"), 
        base_name = "fp"
    )
    (nlp == true) && (return)
    var[:pipe_flow_lifted] = @variable(m, [i in ids], 
        lower_bound = sign(ref(sopt, :pipe, i, "min_flow")) * ref(sopt, :pipe, i, "min_flow")^2,
        upper_bound = sign(ref(sopt, :pipe, i, "max_flow")) * ref(sopt, :pipe, i, "max_flow")^2,
        base_name = "fp_mod_fp"
    )
end 

""" flow variables for each compressor in the network """ 
function _add_compressor_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :compressor))
    (isempty(ids)) && (return)
    var[:compressor_flow] = @variable(m, [i in ids],
        lower_bound = ref(sopt, :compressor, i, "min_flow"),
        upper_bound = ref(sopt, :compressor, i, "max_flow"), 
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

""" flow variables for each valve in the network """ 
function _add_valve_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :valve))
    (isempty(ids)) && (return)
    var[:valve_flow] = @variable(m, [i in ids],
        lower_bound = ref(sopt, :valve, i, "min_flow"),
        upper_bound = ref(sopt, :valve, i, "max_flow"), 
        base_name = "fv"
    )
    var[:valve_status] = @variable(m, [i in ids],
        binary = true, base_name = "xv"
    )
end 

""" flow variables for each control valve in the network """ 
function _add_control_valve_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :control_valve))
    (isempty(ids)) && (return)
    var[:control_valve_flow] = @variable(m, [i in ids],
        lower_bound = ref(sopt, :control_valve, i, "min_flow"),
        upper_bound = ref(sopt, :control_valve, i, "max_flow"), 
        base_name = "fcv"
    )
    var[:control_valve_status] = @variable(m, [i in ids],
        binary = true, base_name = "xcv"
    )
    var[:control_valve_active] = @variable(m, 
        [i in ids; ref(sopt, :control_valve, i, "internal_bypass_required") == true], 
        binary = true, base_name = "xcv_ac"
    )
    var[:control_valve_bypass] = @variable(m, 
        [i in ids; ref(sopt, :control_valve, i, "internal_bypass_required") == true], 
        binary = true, base_name = "xcv_bp"
    )
end 

""" flow variables for each short pipe in the network """ 
function _add_short_pipe_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :short_pipe))
    (isempty(ids)) && (return)
    var[:short_pipe_flow] = @variable(m, [i in ids], 
        lower_bound = ref(sopt, :short_pipe, i, "min_flow"),
        upper_bound = ref(sopt, :short_pipe, i, "max_flow"), 
        base_name = "fsp"
    )
end 

""" flow and direction variables for each loss resistor in the network """ 
function _add_loss_resistor_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :loss_resistor))
    (isempty(ids)) && (return)
    var[:loss_resistor_flow] = @variable(m, [i in ids], 
        lower_bound = ref(sopt, :loss_resistor, i, "min_flow"),
        upper_bound = ref(sopt, :loss_resistor, i, "max_flow"), 
        base_name = "fls"
    )
    var[:loss_resistor_flow_direction] = @variable(m, [i in ids], 
        binary = true, base_name = "xls"
    )
end 

""" flow and lifted flow variables for each resistor in the network """ 
function _add_resistor_variables!(sopt::SteadyOptimizer, 
    opt_model::OptModel; 
    nlp::Bool=true
)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :resistor))
    (isempty(ids)) && (return)
    var[:resistor_flow] = @variable(m, [i in ids],
        lower_bound = ref(sopt, :resistor, i, "min_flow"),
        upper_bound = ref(sopt, :resistor, i, "max_flow"), 
        base_name = "fr"
    )
    (nlp == true) && (return)
    var[:resistor_flow_lifted] = @variable(m, [i in ids], 
        lower_bound = sign(ref(sopt, :resistor, i, "min_flow")) * ref(sopt, :resistor, i, "min_flow")^2,
        upper_bound = sign(ref(sopt, :resistor, i, "max_flow")) * ref(sopt, :resistor, i, "max_flow")^2,
        base_name = "fr_mod_fr"
    )
end

""" variables for decision groups """ 
function _add_decision_group_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables 
    ids = keys(ref(sopt, :decision_group))
    (isempty(ids)) && (return)
    dg = ref(sopt, :decision_group)
    var[:decision_group_selector] = Dict{Int,Any}()
    for id in ids 
        num_decisions = dg[id]["num_decisions"]
        if num_decisions != 1 
            var[:decision_group_selector][id] = @variable(m, 
                [1:num_decisions], binary = true, base_name = "xdg_$id")
        end 
    end 
end 

""" injection variables for each receipt in the network """ 
function _add_receipt_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :receipt))
    (isempty(ids)) && (return)
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
    (isempty(ids)) && (return)
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
    _add_pipe_variables!(sopt, opt_model, nlp=nlp)
    _add_compressor_variables!(sopt, opt_model)
    _add_valve_variables!(sopt, opt_model)
    _add_control_valve_variables!(sopt, opt_model)
    _add_short_pipe_variables!(sopt, opt_model)
    _add_loss_resistor_variables!(sopt, opt_model)
    _add_resistor_variables!(sopt, opt_model, nlp=nlp)
    _add_decision_group_variables!(sopt, opt_model)
end 