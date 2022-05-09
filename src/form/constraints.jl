""" slack node constraints """ 
function _add_slack_node_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables
    ids = ref(sopt, :slack_nodes)
    _, b2 = get_eos_coeffs(sopt)
    is_ideal = isapprox(b2, 0.0)
    
    @constraint(m, [i in ids], var[:potential][i] == ref(sopt, :node, i, "slack_potential"))
    (is_ideal) && (return)
    @constraint(m, [i in ids; ref(sopt, :is_pressure_node, i) == true], var[:pressure][i] == ref(sopt, :node, i, "slack_pressure"))
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
function _add_pipe_physics_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model  
    var = opt_model.variables 
    ids = keys(ref(sopt, :pipe))
    pipe = ref(sopt, :pipe)
    c = nominal_values(sopt, :mach_num)^2 / nominal_values(sopt, :euler_num) 
    resistance = Dict(i => val["friction_factor"] * val["length"] * c / (2 * val["diameter"] * val["area"]^2) for (i, val) in pipe)
    if (opt_model.model_type == nlp)
        @constraint(m, [i in ids],
            var[:potential][pipe[i]["fr_node"]] - var[:potential][pipe[i]["to_node"]] == 
            resistance[i] * var[:pipe_flow][i] * abs(var[:pipe_flow][i])
        )
    end 
    if (opt_model.model_type == lp_relaxation || opt_model.model_type == milp_relaxation)
        milp = (opt_model.model_type == milp_relaxation)
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
end 

""" add compressor physics constraints """
function _add_compressor_physics_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    m = opt_model.model 
    var = opt_model.variables 
    ids = keys(ref(sopt, :compressor))
    compressor = ref(sopt, :compressor)
    is_bidirectional = Dict( i => (val["min_flow"] < 0.0) for (i, val) in compressor)
    _, b2 = get_eos_coeffs(sopt)
    if isapprox(b2, 0.0)
        for i in ids 
            flow = var[:compressor_flow][i]
            pi_i = var[:potential][compressor[i]["fr_node"]]
            pi_j = var[:potential][compressor[i]["to_node"]]
            if is_bidirectional[i]
                pi_k = var[:compressor_auxiliary][i]    
                @constraints(m, begin
                    compressor[i]["min_c_ratio"]^2 * pi_i <= pi_k, 
                    pi_k <= compressor[i]["max_c_ratio"]^2 * pi_i,
                    compressor[i]["min_c_ratio"]^2 * pi_j <= pi_k,
                    pi_k <= compressor[i]["max_c_ratio"]^2 * pi_j,
                    flow * (pi_i - pi_k) <= 0, 
                    -flow * (pi_j - pi_k) <= 0
                end)
            else 
                @constraints(m, begin 
                    compressor[i]["min_c_ratio"]^2 * pi_i <= pi_j, 
                    pi_j <= compressor[i]["max_c_ratio"]^2 * pi_i,
                    
                )

            end 
        end 
    end 
end 


""" add all constraints to the model """
function _add_constraints!(sopt::SteadyOptimizer, opt_model::OptModel)
    _add_slack_node_constraints!(sopt, opt_model)
    _add_nodal_balance_constraints!(sopt, opt_model)
    _add_pipe_physics_constraints!(sopt, opt_model)
    _add_compressor_physics_constraints!(sopt, opt_model)
end 