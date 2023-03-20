""" add objective model """
function _add_objective!(sopt::SteadyOptimizer, 
    opt_model::OptModel; 
)
    m = opt_model.model 
    var = opt_model.variables
    entry = ref(sopt, :entry)
    ids = keys(ref(sopt, :entry))
    @objective(m, Min, sum(entry[i]["cost"] * var[:injection][i] for i in ids))
end 