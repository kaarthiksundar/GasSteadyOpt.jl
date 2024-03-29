function create_lp!(sopt::SteadyOptimizer)
    opt_model = sopt.linear_relaxation

    _add_variables!(sopt, opt_model; nlp=false, misocp=false)
    _add_constraints!(sopt, opt_model; nlp=false, misocp=false)
    _add_objective!(sopt, opt_model)
end 