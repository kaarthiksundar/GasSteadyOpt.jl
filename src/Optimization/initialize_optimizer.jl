function initialize_optimizer(net::NetworkData; 
    objective_type::ObjectiveType = MIN_GENERATION_COST, 
    nonlinear_model::Bool = true, 
    linear_relaxation::Bool = true, 
    misoc_relaxation::Bool = true
)::SteadyOptimizer 

    sopt = SteadyOptimizer(net, 
        objective_type, 
        OptModel(), 
        OptModel(), 
        OptModel(), 
        Solution(), 
        Solution(), 
        Solution()
    )    

    _initialize_solution!(sopt)
    (nonlinear_model) && (create_nlp!(sopt))
    (linear_relaxation) && (create_lp!(sopt))
    (misoc_relaxation) && (create_misocp!(sopt))

    return sopt
end 