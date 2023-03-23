""" add objective model """
function _add_objective!(sopt::SteadyOptimizer, 
    opt_model::OptModel; 
)
    m = opt_model.model 
    var = opt_model.variables
    entry = ref(sopt, :entry)
    ids = keys(ref(sopt, :entry))
    regularizer = 0 
    for i in ids 
        node_id = entry[i]["node_id"]
        if is_pressure_node(sopt, node_id)
            regularizer += var[:pressure][node_id]
        else 
            regularizer += var[:potential][node_id]
        end 
    end 
    @objective(m, Min, sum(entry[i]["cost"] * var[:injection][i] for i in ids))
end 