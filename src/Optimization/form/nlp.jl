function create_nlp!(sopt::SteadyOptimizer)
    opt_model = sopt.nonlinear_full

    _add_variables!(sopt, opt_model; nlp=true, misocp=false)
    _add_constraints!(sopt, opt_model; nlp=true, misocp=false)
    _add_objective!(sopt, opt_model)
end 