""" add objective model """
function _add_objective!(sopt::SteadyOptimizer, 
    opt_model::OptModel; 
    slack_pressure_regualizer::Bool=true
)
    m = opt_model.model 
    var = opt_model.variables
    ids = keys(ref(sopt, :entry))
    entry = ref(sopt, :entry)
    slack_nodes = ref(sopt, :slack_nodes)
    regularizer = 0 
    for i in slack_nodes 
        if is_pressure_node(sopt, i, is_ideal(sopt)) 
            regularizer += var[:pressure][i]
        else 
            regularizer += var[:potential][i]
        end 
    end 
    if (slack_pressure_regualizer)
        @objective(m, Min, sum(entry[i]["cost"] * var[:injection][i] for i in ids) - 1e-3 * regularizer)
    else 
        @objective(m, Min, sum(entry[i]["cost"] * var[:injection][i] for i in ids))
    end 
end 