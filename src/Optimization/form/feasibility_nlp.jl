function create_feasibility_nlp!(sopt::SteadyOptimizer; 
    lp_solution::Bool = true,
    misocp_solution::Bool = false)
    
    @assert lp_solution && misocp_solution == false 
    opt_model = sopt.feasibility_nlp

    _add_feasibility_variables!(sopt, opt_model, 
        lp = lp_solution, misocp = misocp_solution)
    _add_feasibility_constraints!(sopt, opt_model, 
        lp = lp_solution, misocp = misocp_solution)
end 

function _add_feasibility_variables!(sopt::SteadyOptimizer, 
    opt_model::OptModel; lp::Bool = true, misocp::Bool = false)
    control = (lp) ? sopt.solution_linear.control : sopt.solution_misoc.control
    _add_nodal_potential_variables!(sopt, opt_model)
    _add_nodal_pressure_variables!(sopt, opt_model)
    _add_pipe_variables!(sopt, opt_model)
    _add_compressor_variables!(sopt, opt_model, control)
    _add_valve_variables!(sopt, opt_model, control)
    _add_control_valve_variables!(sopt, opt_model, control)
    _add_short_pipe_variables!(sopt, opt_model)
    _add_loss_resistor_feasibility_variables!(sopt, opt_model)
    _add_resistor_variables!(sopt, opt_model)
end 

""" flow variables for each compressor in the network """ 
function _add_compressor_variables!(sopt::SteadyOptimizer, 
    opt_model::OptModel, control::Dict)
    sol = control[:compressor]
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :compressor))
    (isempty(ids)) && (return)
    var[:compressor_flow] = @variable(m, [i in ids], base_name = "fc")
    for i in ids 
        f_min = ref(sopt, :compressor, i, "min_flow") 
        f_max = ref(sopt, :compressor, i, "max_flow")
        if ref(sopt, :compressor, i, "internal_bypass_required") == true
            JuMP.set_lower_bound(var[:compressor_flow][i], f_min * sol[i]["bypass"])
            JuMP.set_upper_bound(var[:compressor_flow][i], f_max * sol[i]["active"])
        else 
            JuMP.set_lower_bound(var[:compressor_flow][i], f_min * sol[i]["status"])
            JuMP.set_upper_bound(var[:compressor_flow][i], f_max * sol[i]["status"])
        end 
    end 
end 

""" flow variables for each valve in the network """ 
function _add_valve_variables!(sopt::SteadyOptimizer, 
    opt_model::OptModel, control::Dict)
    sol = control[:valve]
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :valve))
    (isempty(ids)) && (return)
    var[:valve_flow] = @variable(m, [i in ids],
        lower_bound = ref(sopt, :valve, i, "min_flow") * sol[i]["status"],
        upper_bound = ref(sopt, :valve, i, "max_flow") * sol[i]["status"], 
        base_name = "fv"
    )
end 

""" flow variables for each control valve in the network """ 
function _add_control_valve_variables!(sopt::SteadyOptimizer, 
    opt_model::OptModel, control::Dict)
    sol = control[:control_valve]
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :control_valve))
    (isempty(ids)) && (return)
    var[:control_valve_flow] = @variable(m, [i in ids], base_name = "fcv")
    for i in ids 
        f_min = ref(sopt, :control_valve, i, "min_flow") 
        f_max = ref(sopt, :control_valve, i, "max_flow")
        if ref(sopt, :control_valve, i, "internal_bypass_required") == true
            JuMP.set_lower_bound(var[:control_valve_flow][i], f_min * sol[i]["bypass"])
            JuMP.set_upper_bound(var[:control_valve_flow][i], f_max * sol[i]["active"])
        else 
            JuMP.set_lower_bound(var[:control_valve_flow][i], f_min * sol[i]["status"])
            JuMP.set_upper_bound(var[:control_valve_flow][i], f_max * sol[i]["status"])
        end 
    end 
end 

""" flow variables for each loss resistor in the network """ 
function _add_loss_resistor_feasibility_variables!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :loss_resistor))
    (isempty(ids)) && (return)
    var[:loss_resistor_flow] = @variable(m, [i in ids], 
        lower_bound = ref(sopt, :loss_resistor, i, "min_flow"),
        upper_bound = ref(sopt, :loss_resistor, i, "max_flow"), 
        base_name = "fls"
    )
end 

function _add_feasibility_constraints!(sopt::SteadyOptimizer, 
    opt_model::OptModel; 
    lp::Bool = true, 
    misocp::Bool = true)

    control = lp ? sopt.solution_linear.control : sopt.solution_misoc.control
    _add_slack_node_constraints!(sopt, opt_model)
    _add_potential_pressure_map_constraints!(sopt, opt_model)
    _add_pipe_constraints!(sopt, opt_model)
    _add_compressor_constraints!(sopt, opt_model, control)
    _add_valve_constraints!(sopt, opt_model, control)
    _add_control_valve_constraints!(sopt, opt_model, control)
    _add_short_pipe_constraints!(sopt, opt_model)
    _add_loss_resistor_feasibility_constraints!(sopt, opt_model)
    _add_resistor_constraints!(sopt, opt_model)
    _add_nodal_balance_constraints!(sopt, opt_model, control)
end 

""" add compressor feasibility constraints """
function _add_compressor_constraints!(sopt::SteadyOptimizer, 
    opt_model::OptModel, control::Dict)
    sol = control[:compressor]
    m = opt_model.model 
    var = opt_model.variables 
    ids = keys(ref(sopt, :compressor))
    (isempty(ids)) && (return)
    compressor = ref(sopt, :compressor)
    for i in ids 
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
        x = sol[i]["status"]
        internal_bypass_required = compressor[i]["internal_bypass_required"] == true
        if !internal_bypass_required
            @constraints(m, begin 
                p_j >= alpha_min * p_i - (1 - x) * (alpha_min * p_i_max - p_j_min)
                p_j <= alpha_max * p_i + (1 - x) * (p_j_max - alpha_max * p_i_min)
            end)
        else 
            x_ac = sol[i]["active"]
            x_bp = sol[i]["bypass"]
            @constraints(m, begin 
                p_j >= alpha_min * p_i - (2 - x - x_ac) * (alpha_min * p_i_max - p_j_min)
                p_j <= alpha_max * p_i + (2 - x - x_ac) * (p_j_max - alpha_max * p_i_min)
                p_i - p_j >= (1 - x_bp) * (p_i_min - p_j_max)
                p_i - p_j <= (1 - x_bp) * (p_i_max - p_j_min)
            end)
        end 
    end 
end 

""" add valve feasibility constraints """ 
function _add_valve_constraints!(sopt::SteadyOptimizer, 
    opt_model::OptModel, control::Dict)
    sol = control[:valve]
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
        x = sol[i]["status"]          
        @constraints(m, begin 
            p_i - p_j >= -delta_p 
            p_i - p_j <= delta_p 
            p_i - p_j >= (1 - x) * (p_i_min - p_j_max)
            p_i - p_j <= (1 - x) * (p_i_max - p_j_min)
        end)
    end 
end 

""" add control valve feasibility constraints """ 
function _add_control_valve_constraints!(sopt::SteadyOptimizer, 
    opt_model::OptModel, control::Dict)
    sol = control[:control_valve]
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
        x = sol[i]["status"]
        internal_bypass_required = cv[i]["internal_bypass_required"] == true
        if !internal_bypass_required
            @constraints(m, begin 
                p_i - p_j >= (p_i_min - p_j_max) + x * (delta_p_min - p_i_min + p_j_max)
                p_i - p_j <= (p_i_max - p_j_min) - x * (p_i_max - p_j_min - delta_p_max)
            end)
        else 
            x_ac = sol[i]["active"]
            x_bp = sol[i]["bypass"]
            @constraints(m, begin 
                p_i - p_j >= (p_i_min - p_j_max) + x_ac * (delta_p_min - p_i_min + p_j_max)
                p_i - p_j <= (p_i_max - p_j_min) - x_ac * (p_i_max - p_j_min - delta_p_max)
                p_i - p_j >= (1 - x_bp) * (p_i_min - p_j_max)
                p_i - p_j <= (1 - x_bp) * (p_i_max - p_j_min)
            end)
        end 
    end 
end 

""" loss resistor feasibility constraints """
function _add_loss_resistor_feasibility_constraints!(sopt, opt_model)
    function ∇sign(g::AbstractVector, x) 
        g[1] = 0.0 
        return 
    end 
    function ∇²sign(H::AbstractMatrix, x)
        H[1, 1] = 0.0
        return 
    end 
    m = opt_model.model 
    register(m, :sign, 1, sign, ∇sign, ∇²sign)
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
        @NLconstraint(m, p_i - p_j == sign(flow) * delta_p)
    end 
end 


""" nodal balance feasibility constraints """ 
function _add_nodal_balance_constraints!(sopt::SteadyOptimizer, 
    opt_model::OptModel, control::Dict)
    entry = control[:entry]
    exit = control[:exit]
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
        sum([entry[j]["injection"] for j in ref(sopt, :entries_at_node, i)]; init=0.0) 
        ==
        sum(var[:pipe_flow][j] for j in ref(sopt, :outgoing_pipes, i); init=0.0) + 
        sum(var[:short_pipe_flow][j] for j in ref(sopt, :outgoing_short_pipes, i); init=0.0) + 
        sum(var[:resistor_flow][j] for j in ref(sopt, :outgoing_resistors, i); init=0.0) + 
        sum(var[:loss_resistor_flow][j] for j in ref(sopt, :outgoing_loss_resistors, i); init=0.0) + 
        sum(var[:valve_flow][j] for j in ref(sopt, :outgoing_valves, i); init=0.0) + 
        sum(var[:control_valve_flow][j] for j in ref(sopt, :outgoing_control_valves, i); init=0.0) +
        sum(var[:compressor_flow][j] for j in ref(sopt, :outgoing_compressors, i); init=0.0) + 
        sum([exit[j]["withdrawal"] for j in ref(sopt, :exits_at_node, i)]; init=0.0)
    )
end 