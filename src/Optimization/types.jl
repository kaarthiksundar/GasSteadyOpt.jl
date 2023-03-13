struct OptModel 
    model::JuMP.AbstractModel
    variables::Dict{Symbol,Any}
end 

OptModel() = OptModel(JuMP.Model(), Dict{Symbol,Any}())

@enum ObjectiveType MIN_GENERATION_COST MIN_COMPRESSION 

struct SteadyOptimizer 
    net::NetworkData 
    objective_type::ObjectiveType 
    nonlinear_full::OptModel 
    linear_relaxation::OptModel 
    misoc_relaxation::OptModel 
    solution_nonlinear::Solution
    solution_linear::Solution
    solution_misoc::Solution
end 

