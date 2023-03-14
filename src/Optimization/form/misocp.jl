function create_misocp!(sopt::SteadyOptimizer)
    opt_model = sopt.misoc_relaxation

    _add_variables!(sopt, opt_model; nlp=false, misocp=true)
    _add_constraints!(sopt, opt_model; nlp=false, misocp=true)
    _add_objective!(sopt, opt_model)
end 