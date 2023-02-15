""" slack node constraints """ 
function _add_slack_node_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = ref(sopt, :slack_nodes)
    _, b2 = get_eos_coeffs(sopt)
    is_ideal = isapprox(b2, 0.0)
    
    @constraint(m, [i in ids], 
        var[:potential][i] == 
        get_potential(sopt, ref(sopt, :node, i, "slack_pressure"))
    )

    @constraint(m, 
        [i in ids; is_pressure_node(sopt, i, is_ideal) == true], 
        var[:pressure][i] == ref(sopt, :node, i, "slack_pressure")
    )
end 

""" nodal balance constraints """ 
function _add_nodal_balance_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :node))
   @constraint(m, [i in ids], 
        sum(var[:pipe_flow][j] for j in ref(sopt, :incoming_pipes, i)) + 
        sum(var[:compressor_flow][j] for j in ref(sopt, :incoming_compressors, i)) + 
        sum(var[:injection][j] for j in ref(sopt, receipts_at_node, i)) ==
        sum(var[:pipe_flow][j] for j in ref(sopt, :outgoing_pipes, i)) + 
        sum(var[:compressor_flow][j] for j in ref(sopt, :outgoing_compressors, i)) +
        sum(var[:withdrawal][j] for j in ref(sopt, deliveries_at_node, i)) 
    )
end 

""" pipe physics constraints """
function _add_pipe_constraints!(
    sopt::SteadyOptimizer, 
    opt_model::OptModel; 
    nlp::Bool = true
)
    m = opt_model.model  
    var = opt_model.variables 
    ids = keys(ref(sopt, :pipe))
    pipe = ref(sopt, :pipe)
    c = nominal_values(sopt, :mach_num)^2 / nominal_values(sopt, :euler_num) 
    resistance = Dict(i => 
        val["friction_factor"] * val["length"] * c / (2 * val["diameter"] * val["area"]^2) for (i, val) in pipe)
    if nlp
        @NLconstraint(m, [i in ids],
            var[:potential][pipe[i]["fr_node"]] - var[:potential][pipe[i]["to_node"]] == 
            resistance[i] * var[:pipe_flow][i] * abs(var[:pipe_flow][i])
        )
    end 
    (nlp) && (return)
    @constraint(m, [i in ids], 
        var[:potential][pipe[i]]["fr_node"] - var[:potential][pipe[i]["to_node"]] == 
        resistance[i] * var[:pipe_flow_lifted][i]
    )
    f = x -> x * abs(x)
    fdash = x -> 2.0 * x * sign(x)
    for i in ids 
        partition = 
            if pipe[i]["min_flow"] >= 0.0 || pipe[i]["max_flow"] <= 0.0 
                [pipe[i]["min_flow"], pipe[i]["max_flow"]]
            else
                [pipe[i]["min_flow"], 0.0, pipe[i]["max_flow"]] 
            end 
        PolyhedralRelaxations.construct_univariate_relaxation!(m, f, 
            var[:pipe_flow][i], var[:pipe_flow_lifted][i], partition, milp; f_dash = fdash)
    end  
end 

""" add compressor constraints """
function _add_compressor_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables 
    ids = keys(ref(sopt, :compressor))
    compressor = ref(sopt, :compressor)
    _, b2 = get_eos_coeffs(sopt)
    is_ideal = isapprox(b2, 0.0)
    if is_ideal
        for i in ids 
            flow = var[:compressor_flow][i]
            i_node = compressor[i]["fr_node"]
            j_node = compressor[i]["to_node"] 
            pi_i = var[:potential][i_node]
            pi_i_min = get_potential(sopt, ref(sopt, :node, i_node, "min_pressure"))
            pi_i_max = get_potential(sopt, ref(sopt, :node, i_node, "max_pressure"))
            pi_j = var[:potential][j_node]
            pi_j_min = get_potential(sopt, ref(sopt, :node, j_node, "min_pressure"))
            pi_j_max = get_potential(sopt, ref(sopt, :node, j_node, "max_pressure"))
            alpha_min = compressor[i]["min_c_ratio"]^2
            alpha_max = compressor[i]["max_c_ratio"]^2
            x = var[:compressor_status][i]
            internal_bypass_required = compressor[i]["internal_bypass_required"] == true
            if !internal_bypass_required
                set_lower_bound(flow, 0.0)
                @constraints(m, begin 
                    flow <= x * compressor[i]["max_flow"]
                    pi_j >= alpha_min * pi_i - (1 - x) * (alpha_min * pi_i_max - pi_j_min)
                    pi_j <= alpha_max * pi_i + (1 - x) * (pi_j_max - alpha_max * pi_i_min)
                end)
            else 
                x_ac = var[:compressor_active][i]
                x_bp = var[:compressor_bypass][i]
                @constraints(m, begin 
                    x == x_ac + x_bp 
                    flow >= -1.0 * x_bp * compressor[i]["max_flow"]
                    flow <= x * compressor[i]["max_flow"]
                    pi_j >= alpha_min * pi_i - (2 - x - x_ac) * (alpha_min * pi_i_max - pi_j_min)
                    pi_j <= alpha_max * pi_i + (2 - x - x_ac) * (pi_j_max - alpha_max * pi_i_min)
                    pi_i - pi_j >= (1 - x_bp) * (pi_i_min - pi_j_max)
                    pi_i - pi_j <= (1 - x_bp) * (pi_i_max - pi_j_min)
                end)
            end 
        end 
    else 
        for i in ids 
            flow = var[:compressor_flow][i]
            i_node = compressor[i]["fr_node"]
            j_node = compressor[i]["to_node"] 
            p_i = var[:pressure][i_node]
            p_i_min = ref(sopt, :node, i_node, "min_pressure")
            p_i_max = ref(sopt, :node, i_node, "max_pressure")
            p_j = var[:pressure][j_node]
            p_j_min = ref(sopt, :node, j_node, "min_pressure")
            p_j_max = ref(sopt, :node, j_node, "max_pressure")
            alpha_min = compressor[i]["min_c_ratio"]
            alpha_max = compressor[i]["max_c_ratio"]
            x = var[:compressor_status][i]
            internal_bypass_required = compressor[i]["internal_bypass_required"] == true
            if !internal_bypass_required
                set_lower_bound(flow, 0.0)
                @constraints(m, begin 
                    flow <= x * compressor[i]["max_flow"]
                    p_j >= alpha_min * p_i - (1 - x) * (alpha_min * p_i_max - p_j_min)
                    p_j <= alpha_max * p_i + (1 - x) * (p_j_max - alpha_max * p_i_min)
                end)
            else 
                x_ac = var[:compressor_active][i]
                x_bp = var[:compressor_bypass][i]
                @constraints(m, begin 
                    x == x_ac + x_bp 
                    flow >= -1.0 * x_bp * compressor[i]["max_flow"]
                    flow <= x * compressor[i]["max_flow"]
                    p_j >= alpha_min * p_i - (2 - x - x_ac) * (alpha_min * p_i_max - p_j_min)
                    p_j <= alpha_max * p_i + (2 - x - x_ac) * (p_j_max - alpha_max * p_i_min)
                    p_i - p_j >= (1 - x_bp) * (p_i_min - p_j_max)
                    p_i - p_j <= (1 - x_bp) * (p_i_max - p_j_min)
                end)
            end 
        end 
    end 
end 

""" add valve constraints """ 
function _add_valve_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables 
    ids = keys(ref(sopt, :valve))
    valve = ref(sopt, :valve)
    for i in ids
        i_node = valve[i]["fr_node"]
        j_node = valve[i]["to_node"]
        p_i = var[:pressure][i_node]
        p_i_min = ref(sopt, :node, i_node, "min_pressure")
        p_i_max = ref(sopt, :node, i_node, "max_pressure")
        p_j = var[:pressure][j_node]
        p_j_min = ref(sopt, :node, j_node, "min_pressure")
        p_j_max = ref(sopt, :node, j_node, "max_pressure")
        delta_p = valve[i]["max_pressure_differential"]
        flow = var[:valve_flow][i]
        flow_min = valve[i]["min_flow"]
        flow_max = valve[i]["max_flow"]
        x = var[:valve_status][i]            
        @constraints(m, begin 
            flow >= flow_min * x 
            flow <= flow_max * x 
            p_i - p_j >= -delta_p 
            p_i - p_j <= delta_p 
            p_i - p_j >= (1 - x) * (p_i_min - p_j_max)
            p_i - p_j <= (1 - x) * (p_i_max - p_j_min)
        end)
    end 
end 

""" add control valve constraints """ 
function _add_control_valve_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables 
    ids = keys(ref(sopt, :control_valve))
    cv = ref(sopt, :control_valve)
    for i in ids
        flow = var[:control_valve_flow][i]
        i_node = cv[i]["fr_node"]
        j_node = cv[i]["to_node"] 
        p_i = var[:pressure][i_node]
        p_i_min = ref(sopt, :node, i_node, "min_pressure")
        p_i_max = ref(sopt, :node, i_node, "max_pressure")
        p_j = var[:pressure][j_node]
        p_j_min = ref(sopt, :node, j_node, "min_pressure")
        p_j_max = ref(sopt, :node, j_node, "max_pressure")
        delta_p_min = cv[i]["min_pressure_differential"]
        delta_p_max = cv[i]["max_pressure_differential"]
        x = var[:control_valve_status][i]
        flow_max = cv[i]["max_flow"]
        internal_bypass_required = cv[i]["internal_bypass_required"] == true
        if !internal_bypass_required
            set_lower_bound(flow, 0.0)
            @constraints(m, begin 
                flow <= x * flow_max
                p_i - p_j >= (p_i_min - p_j_max) + x * (delta_p_min - p_i_min + p_j_max)
                p_i - p_j <= (p_i_max - p_j_min) - x * (p_i_max - p_j_min - delta_p_max)
            end)
        else 
            x_ac = var[:control_valve_active][i]
            x_bp = var[:control_valve_bypass][i]
            @constraints(m, begin 
                x == x_ac + x_bp 
                flow >= -1.0 * x_bp * flow_max
                flow <= x * flow_max
                p_i - p_j >= (p_i_min - p_j_max) + x_ac * (delta_p_min - p_i_min + p_j_max)
                p_i - p_j <= (p_i_max - p_j_min) - x_ac * (p_i_max - p_j_min - delta_p_max)
                p_i - p_j >= (1 - x_bp) * (p_i_min - p_j_max)
                p_i - p_j <= (1 - x_bp) * (p_i_max - p_j_min)
            end)
        end 
    end 
end 


""" add all constraints to the model """
function _add_constraints!(
    sopt::SteadyOptimizer, 
    opt_model::OptModel; 
    nlp::Bool=true
)
    _add_slack_node_constraints!(sopt, opt_model)
    _add_pipe_constraints!(sopt, opt_model)
    _add_compressor_constraints!(sopt, opt_model)
    _add_valve_constraints!(sopt, opt_model)
    _add_control_valve_constraints!(sopt, opt_model)
end 