""" slack node constraints """ 
function _add_slack_node_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = ref(sopt, :slack_nodes)
    (isempty(ids)) && (return)
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

""" potential definition """ 
function _add_potential_pressure_map_constraints!(
    sopt::SteadyOptimizer, 
    opt_model::OptModel; 
    nlp::Bool = true
)
    m = opt_model.model 
    var = opt_model.variables
    ids = ref(sopt, :nodes)
    (isempty(ids)) && (return)
    b1, b2 = get_eos_coeffs(sopt)
    is_ideal = isapprox(b2, 0.0)

    if nlp 
        for i in ids 
            (is_pressure_node(sopt, i, is_ideal) == false) && (continue)
            p = var[:pressure][i]
            potential = var[:potential][i]
            @NLconstraint(m, potential == (b1/2) * p^2 + (b2/3) * p^3 )
        end 
    end 
    (nlp) && (return)
    f = x -> (b1/2) * x^2 + (b2/3) * x^3
    fdash = x -> b1 * x + b2 * x^2
    for i in ids 
        (is_pressure_node(sopt, i, is_ideal) == false) && (continue)
        p_min = ref(sopt, :node, i, "min_pressure") 
        p_max = ref(sopt, :node, i, "min_pressure")
        partition = [p_min, (p_min + p_max) * 0.5, p_max]
        PolyhedralRelaxations.construct_univariate_relaxation!(m, f, 
            var[:pressure][i], var[:potential][i], partition, false; f_dash = fdash)
    end 
end 

""" nodal balance constraints """ 
function _add_nodal_balance_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :node))
    (isempty(ids)) && (return)
    @constraint(m, [i in ids], 
        sum(var[:pipe_flow][j] for j in ref(sopt, :incoming_pipes, i); init=0.0) + 
        sum(var[:short_pipe_flow][j] for j in ref(sopt, :incoming_short_pipes, i); init=0.0) + 
        sum(var[:resistor_flow][j] for j in ref(sopt, :incoming_resistors, i); init=0.0) + 
        sum(var[:loss_resistor_flow][j] for j in ref(sopt, :incoming_loss_resistors, i); init=0.0) + 
        sum(var[:valve_flow][j] for j in ref(sopt, :incoming_valves, i); init=0.0) + 
        sum(var[:control_valve_flow][j] for j in ref(sopt, :incoming_control_valves, i); init=0.0) +
        sum(var[:compressor_flow][j] for j in ref(sopt, :incoming_compressors, i); init=0.0) + 
        sum(var[:injection][j] for j in ref(sopt, :entries_at_node, i); init=0.0) 
        ==
        sum(var[:pipe_flow][j] for j in ref(sopt, :outgoing_pipes, i); init=0.0) + 
        sum(var[:short_pipe_flow][j] for j in ref(sopt, :outgoing_short_pipes, i); init=0.0) + 
        sum(var[:resistor_flow][j] for j in ref(sopt, :outgoing_resistors, i); init=0.0) + 
        sum(var[:loss_resistor_flow][j] for j in ref(sopt, :outgoing_loss_resistors, i); init=0.0) + 
        sum(var[:valve_flow][j] for j in ref(sopt, :outgoing_valves, i); init=0.0) + 
        sum(var[:control_valve_flow][j] for j in ref(sopt, :outgoing_control_valves, i); init=0.0) +
        sum(var[:compressor_flow][j] for j in ref(sopt, :outgoing_compressors, i); init=0.0) + 
        sum([ref(sopt, :exit, j, "max_withdrawal") for j in ref(sopt, :exits_at_node, i)]; init=0.0)
    )
end 

""" pipe physics constraints """
function _add_pipe_constraints!(
    sopt::SteadyOptimizer, 
    opt_model::OptModel; 
    nlp::Bool = true, 
    misocp::Bool = false
)
    m = opt_model.model  
    var = opt_model.variables 
    ids = keys(ref(sopt, :pipe))
    (isempty(ids)) && (return)
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
        var[:potential][pipe[i]["fr_node"]] - var[:potential][pipe[i]["to_node"]] == 
        resistance[i] * var[:pipe_flow_lifted][i]
    )
    if (misocp == false)
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
                var[:pipe_flow][i], var[:pipe_flow_lifted][i], partition, false; f_dash = fdash)
        end  
    else 
        @constraint(m, [i in ids], var[:pipe_flow_square][i] >= var[:pipe_flow][i] * var[:pipe_flow][i])
        f_hat = var[:pipe_flow_lifted]
        f_sqr = var[:pipe_flow_square]
        z = var[:pipe_flow_direction]
        @constraint(m, [i in ids], f_hat[i] >= (-1)*f_sqr[i] + (2*z[i]-1)*lower_bound(f_sqr[i]) - (-1)*lower_bound(f_sqr[i]))
        @constraint(m, [i in ids], f_hat[i] >= (+1)*f_sqr[i] + (2*z[i]-1)*upper_bound(f_sqr[i]) - (+1)*upper_bound(f_sqr[i]))
        @constraint(m, [i in ids], f_hat[i] <= (+1)*f_sqr[i] + (2*z[i]-1)*lower_bound(f_sqr[i]) - (+1)*lower_bound(f_sqr[i]))
        @constraint(m, [i in ids], f_hat[i] <= (-1)*f_sqr[i] + (2*z[i]-1)*upper_bound(f_sqr[i]) - (-1)*upper_bound(f_sqr[i]))
    end 
end 

""" add compressor constraints """
function _add_compressor_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables 
    ids = keys(ref(sopt, :compressor))
    (isempty(ids)) && (return)
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
                @constraints(m, begin 
                    flow >= x * compressor[i]["min_flow"]
                    flow <= x * compressor[i]["max_flow"]
                    pi_j >= alpha_min * pi_i - (1 - x) * (alpha_min * pi_i_max - pi_j_min)
                    pi_j <= alpha_max * pi_i + (1 - x) * (pi_j_max - alpha_max * pi_i_min)
                end)
            else 
                x_ac = var[:compressor_active][i]
                x_bp = var[:compressor_bypass][i]
                @constraints(m, begin 
                    x == x_ac + x_bp 
                    flow >= x_bp * compressor[i]["min_flow"]
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
                @constraints(m, begin 
                    flow <= x * compressor[i]["min_flow"]
                    flow <= x * compressor[i]["max_flow"]
                    p_j >= alpha_min * p_i - (1 - x) * (alpha_min * p_i_max - p_j_min)
                    p_j <= alpha_max * p_i + (1 - x) * (p_j_max - alpha_max * p_i_min)
                end)
            else 
                x_ac = var[:compressor_active][i]
                x_bp = var[:compressor_bypass][i]
                @constraints(m, begin 
                    x == x_ac + x_bp 
                    flow >= x_bp * compressor[i]["min_flow"]
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
    (isempty(ids)) && (return)
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
    (isempty(ids)) && (return)
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
        flow_min = cv[i]["min_flow"]
        internal_bypass_required = cv[i]["internal_bypass_required"] == true
        if !internal_bypass_required
            @constraints(m, begin 
                flow >= x * flow_min
                flow <= x * flow_max
                p_i - p_j >= (p_i_min - p_j_max) + x * (delta_p_min - p_i_min + p_j_max)
                p_i - p_j <= (p_i_max - p_j_min) - x * (p_i_max - p_j_min - delta_p_max)
            end)
        else 
            x_ac = var[:control_valve_active][i]
            x_bp = var[:control_valve_bypass][i]
            @constraints(m, begin 
                x == x_ac + x_bp 
                flow >= x_bp * flow_min
                flow <= x * flow_max
                p_i - p_j >= (p_i_min - p_j_max) + x_ac * (delta_p_min - p_i_min + p_j_max)
                p_i - p_j <= (p_i_max - p_j_min) - x_ac * (p_i_max - p_j_min - delta_p_max)
                p_i - p_j >= (1 - x_bp) * (p_i_min - p_j_max)
                p_i - p_j <= (1 - x_bp) * (p_i_max - p_j_min)
            end)
        end 
    end 
end 

""" add short pipe constraints """
function _add_short_pipe_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :short_pipe))
    (isempty(ids)) && (return)
    sp = ref(sopt, :short_pipe)
    _, b2 = get_eos_coeffs(sopt)
    is_ideal = isapprox(b2, 0.0)
    
    @constraint(m, [i in ids], 
        var[:potential][sp[i]["fr_node"]] == 
        var[:potential][sp[i]["to_node"]]
    )
    
    for i in ids 
        fr_node = sp[i]["fr_node"]
        to_node = sp[i]["to_node"]
        fr_pressure_node = is_pressure_node(sopt, fr_node, is_ideal)
        to_pressure_node = is_pressure_node(sopt, to_node, is_ideal)

        if fr_pressure_node && to_pressure_node 
            @constraint(m, var[:pressure][fr_node] == var[:pressure][to_node])
        end 
    end 
end     

""" add loss resistor constraints """
function _add_loss_resistor_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables 
    ids = keys(ref(sopt, :loss_resistor))
    (isempty(ids)) && (return)
    lr = ref(sopt, :loss_resistor)
    for i in ids 
        flow = var[:loss_resistor_flow][i]
        x = var[:loss_resistor_flow_direction][i]
        delta_p = lr[i]["pressure_loss"]
        i_node = lr[i]["fr_node"]
        j_node = lr[i]["to_node"] 
        p_i = var[:pressure][i_node]
        p_j = var[:pressure][j_node]
        flow_min = lr[i]["min_flow"]
        flow_max = lr[i]["max_flow"]
        @constraints(m, begin
            p_i - p_j == (2 * x - 1) * delta_p
            flow <= x * flow_max 
            flow >= (1 - x) * flow_min
        end)
    end 
end 

""" resistor physics constraints """
function _add_resistor_constraints!(
    sopt::SteadyOptimizer, 
    opt_model::OptModel; 
    nlp::Bool = true, 
    misocp::Bool = true
)
    m = opt_model.model  
    var = opt_model.variables 
    ids = keys(ref(sopt, :resistor))
    (isempty(ids)) && (return)
    resistor = ref(sopt, :resistor)
    c = nominal_values(sopt, :mach_num)^2 / nominal_values(sopt, :euler_num) 
    resistance = Dict(i => 
        val["drag"] * c / (2 * val["area"]^2) for (i, val) in resistor)
    if nlp
        @NLconstraint(m, [i in ids],
            var[:potential][resistor[i]["fr_node"]] - var[:potential][resistor[i]["to_node"]] == 
            resistance[i] * var[:resistor_flow][i] * abs(var[:resistor_flow][i])
        )
    end 
    (nlp) && (return)
    @constraint(m, [i in ids], 
        var[:potential][resistor[i]["fr_node"]] - var[:potential][resistor[i]["to_node"]] == 
        resistance[i] * var[:resistor_flow_lifted][i]
    )
    if (misocp == false)
        f = x -> x * abs(x)
        fdash = x -> 2.0 * x * sign(x)
        for i in ids 
            partition = 
                if resistor[i]["min_flow"] >= 0.0 || resistor[i]["max_flow"] <= 0.0 
                    [resistor[i]["min_flow"], resistor[i]["max_flow"]]
                else
                    [resistor[i]["min_flow"], 0.0, resistor[i]["max_flow"]] 
                end 
            PolyhedralRelaxations.construct_univariate_relaxation!(m, f, 
                var[:resistor_flow][i], var[:resistor_flow_lifted][i], partition, false; f_dash = fdash)
        end
    else
        @constraint(m, [i in ids], var[:resistor_flow_square][i] >= var[:resistor_flow][i] * var[:resistor_flow][i])
        f_hat = var[:resistor_flow_lifted]
        f_sqr = var[:resistor_flow_square]
        z = var[:resistor_flow_direction]
        @constraint(m, [i in ids], f_hat[i] >= (-1)*f_sqr[i] + (2*z[i]-1)*lower_bound(f_sqr[i]) - (-1)*lower_bound(f_sqr[i]))
        @constraint(m, [i in ids], f_hat[i] >= (+1)*f_sqr[i] + (2*z[i]-1)*upper_bound(f_sqr[i]) - (+1)*upper_bound(f_sqr[i]))
        @constraint(m, [i in ids], f_hat[i] <= (+1)*f_sqr[i] + (2*z[i]-1)*lower_bound(f_sqr[i]) - (+1)*lower_bound(f_sqr[i]))
        @constraint(m, [i in ids], f_hat[i] <= (-1)*f_sqr[i] + (2*z[i]-1)*upper_bound(f_sqr[i]) - (-1)*upper_bound(f_sqr[i]))
    end  
end 

""" constraints for all decision group where there is only one possible decision """ 
function _add_single_decision_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    dg = ref(sopt, :decision_group)
    single_decision_dg = filter(x -> last(x)["num_decisions"] == 1, dg)
    for entry in single_decision_dg 
        decision = last(entry)["decisions"][1]
        for (component_info, operating_mode) in decision 
            component = first(component_info)
            component_id = last(component_info)
            on_off = operating_mode["on_off"]
            mode = get(operating_mode, "mode", "unknown")
            flow_direction = get(operating_mode, "flow_direction", -1)
            if component == :valve 
                JuMP.fix(var[:valve_status][component_id], Int(on_off); force = true)
                if flow_direction != -1 
                    (flow_direction == 0) && (@constraint(m, var[:valve_flow][component_id] >= 0))
                    (flow_direction == 1) && (@constraint(m, var[:valve_flow][component_id] <= 0))
                end 
            elseif component == :compressor 
                JuMP.fix(var[:compressor_status][component_id], Int(on_off); force = true)
                if flow_direction != -1 
                    (flow_direction == 0) && (@constraint(m, var[:compressor_flow][component_id] >= 0))
                    (flow_direction == 1) && (@constraint(m, var[:compressor_flow][component_id] <= 0))
                    if flow_direction == 1 && ref(sopt, :compressor, component_id, "min_flow") == 0.0
                        @warn "flow in $component_info will be 0 in decision group $(first(entry))"
                    end 
                end 
                if mode != "unknown"
                    (mode == "active") && (JuMP.fix(var[:compressor_active][component_id], 1))
                    (mode == "bypass") && (JuMP.fix(var[:compressor_bypass][component_id], 1))
                end 
            else 
                JuMP.fix(var[:control_valve_status][component_id], Int(on_off); force = true)
                if flow_direction != -1 
                    (flow_direction == 0) && (@constraint(m, var[:control_valve_flow][component_id] >= 0))
                    (flow_direction == 1) && (@constraint(m, var[:control_valve_flow][component_id] <= 0))
                    if flow_direction == 1 && ref(sopt, :control_valve, component_id, "min_flow") == 0.0
                        @warn "flow in $component_info will be 0 in decision group $(first(entry))"
                    end 
                end 
                if mode != "unknown"
                    (mode == "active") && (JuMP.fix(var[:control_valve_active][component_id], 1))
                    (mode == "bypass") && (JuMP.fix(var[:control_valve_bypass][component_id], 1))
                end 
            end 
        end 
    end 
end 

""" One decision for each decision group has to be chosen """ 
function _add_decision_sum!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables 
    for (_, xs) in get(var, :decision_group_selector, [])
        @constraint(m, sum(xs) == 1)
    end 
end 

""" Turn components on or off based on each decision and set active/bypass status for compressors and control valves """ 
function _add_decision_status!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    dg = ref(sopt, :decision_group)
    for (id, group) in dg 
        (group["num_decisions"] == 1) && (continue)
        num_decisions = group["num_decisions"]
        xdg = var[:decision_group_selector][id]
        for i in 1:num_decisions 
            decision = group["decisions"][i]
            for (k, val) in decision
                component_type = k |> first 
                component_id = k |> last
                on_off = val["on_off"]
                if on_off == true
                    (component_type == :valve) && (@constraint(m, xdg[i] <= var[:valve_status][component_id]))
                    (component_type == :control_valve) && (@constraint(m, xdg[i] <= var[:control_valve_status][component_id]))
                    (component_type == :compressor) && (@constraint(m, xdg[i] <= var[:compressor_status][component_id]))
                    mode = get(val, "mode", "unknown")
                    if mode == "active"
                        (component_type == :control_valve) && (@constraint(m, xdg[i] <= var[:control_valve_active][component_id]))
                        (component_type == :compressor) && (@constraint(m, xdg[i] <= var[:compressor_active][component_id]))
                    end 
                    if mode == "bypass"
                        (component_type == :control_valve) && (@constraint(m, xdg[i] <= var[:control_valve_bypass][component_id]))
                        (component_type == :compressor) && (@constraint(m, xdg[i] <= var[:compressor_bypass][component_id]))
                    end 
                else 
                    (component_type == :valve) && (@constraint(m, xdg[i] <= 1 - var[:valve_status][component_id]))
                    (component_type == :control_valve) && (@constraint(m, xdg[i] <= 1 - var[:control_valve_status][component_id]))
                    (component_type == :compressor) && (@constraint(m, xdg[i] <= 1 - var[:compressor_status][component_id]))
                end 
            end 
        end     
    end 
end 

""" enforce flow directions if they are specified for each decision """ 
function _add_decision_flow_direction!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model
    var = opt_model.variables
    dg = ref(sopt, :decision_group)
    for (id, group) in dg 
        (group["num_decisions"] == 1) && (continue)
        num_decisions = group["num_decisions"]
        xdg = var[:decision_group_selector][id]
        valve_expr = Dict( i => Dict("min" => AffExpr(0), "max" => AffExpr(0)) for i in group["valves"] )
        control_valve_expr = Dict( i => Dict("min" => AffExpr(0), "max" => AffExpr(0)) for i in group["control_valves"] )
        compressor_expr = Dict( i => Dict("min" => AffExpr(0), "max" => AffExpr(0)) for i in group["compressors"] )
        for i in 1:num_decisions 
            decision = group["decisions"][i]
            for (k, val) in decision 
                component_type = k |> first 
                component_id = k |> last
                (component_type == :valve) && (expr_dict = valve_expr[component_id])
                (component_type == :control_valve) && (expr_dict = control_valve_expr[component_id])
                (component_type == :compressor) && (expr_dict = compressor_expr[component_id])
                flow_min = ref(sopt, component_type, component_id, "min_flow")
                flow_max = ref(sopt, component_type, component_id, "max_flow")
                on_off = val["on_off"] 
                (on_off == false) && (continue)
                flow_direction = get(val, "flow_direction", -1)
                if flow_direction == -1
                   expr_dict["min"] += (flow_min * xdg[i])
                   expr_dict["max"] += (flow_max * xdg[i])
                elseif flow_direction == 0 
                    expr_dict["max"] += (flow_max * xdg[i])
                else 
                    expr_dict["min"] += (flow_min * xdg[i])
                end 
            end  
        end 
        @constraint(m, [i in group["valves"]], var[:valve_flow][i] <= valve_expr[i]["max"])
        @constraint(m, [i in group["valves"]], var[:valve_flow][i] >= valve_expr[i]["min"])

        @constraint(m, [i in group["control_valves"]], var[:control_valve_flow][i] <= control_valve_expr[i]["max"])
        @constraint(m, [i in group["control_valves"]], var[:control_valve_flow][i] >= control_valve_expr[i]["min"])

        @constraint(m, [i in group["compressors"]], var[:compressor_flow][i] <= compressor_expr[i]["max"])
        @constraint(m, [i in group["compressors"]], var[:compressor_flow][i] >= compressor_expr[i]["min"])
    end 
end 

""" add decision group constraints """ 
function _add_decision_group_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    _add_single_decision_constraints!(sopt, opt_model)
    _add_decision_sum!(sopt, opt_model)
    _add_decision_status!(sopt, opt_model)
    _add_decision_flow_direction!(sopt, opt_model)
end 


""" add all constraints to the model """
function _add_constraints!(
    sopt::SteadyOptimizer, 
    opt_model::OptModel; 
    nlp::Bool=true, 
    misocp::Bool=false
)
    _add_slack_node_constraints!(sopt, opt_model)
    _add_potential_pressure_map_constraints!(sopt, opt_model; nlp=nlp)
    _add_pipe_constraints!(sopt, opt_model, nlp=nlp, misocp=misocp)
    _add_compressor_constraints!(sopt, opt_model)
    _add_valve_constraints!(sopt, opt_model)
    _add_control_valve_constraints!(sopt, opt_model)
    _add_short_pipe_constraints!(sopt, opt_model)
    _add_loss_resistor_constraints!(sopt, opt_model)
    _add_resistor_constraints!(sopt, opt_model, nlp=nlp, misocp=misocp)
    _add_decision_group_constraints!(sopt, opt_model)
    _add_nodal_balance_constraints!(sopt, opt_model)
end 