function populate_nonlinear_model_solution!(sopt::SteadyOptimizer)
    m = sopt.nonlinear_full.model 
    if termination_status(m) == OPTIMIZE_NOT_CALLED 
        @warn "OPTIMIZE_NOT_CALLED on non-linear model"
        return 
    end 
    state = sopt.solution_nonlinear.state 
    control = sopt.solution_nonlinear.control 
end 

function populate_linear_relaxation_solution(sopt::SteadyOptimizer)

end 

function populate_misoc_relaxation_solution!(sopt::SteadyOptimizer)

end 

