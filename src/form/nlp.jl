function create_nlp!(sopt::SteadyOptimizer)
    opt_model = sopt.nlp 

    _add_variables!(sopt, opt_model)
    _add_constraints!(sopt, opt_model)


end 