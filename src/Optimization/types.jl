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

ref(sopt::SteadyOptimizer) = ref(sopt.net)
ref(sopt::SteadyOptimizer, key::Symbol) = ref(sopt.net, key) 
ref(sopt::SteadyOptimizer, key::Symbol, id::Int64) = ref(sopt.net, key, id)
ref(sopt::SteadyOptimizer, key::Symbol, id::Int64, field) = ref(sopt.net, key, id, field)
params(sopt::SteadyOptimizer) = params(sopt.net)
params(sopt::SteadyOptimizer, key::Symbol) = params(sopt.net, key)

nominal_values(sopt::SteadyOptimizer) = nominal_values(sopt.net)
nominal_values(sopt::SteadyOptimizer, key::Symbol) = nominal_values(sopt.net, key)

get_eos_coeffs(sopt::SteadyOptimizer) = get_eos_coeffs(sopt.net)
get_pressure(sopt::SteadyOptimizer, density) = get_pressure(sopt.net, density)
get_density(sopt::SteadyOptimizer, pressure) = get_density(sopt.net, pressure)

get_potential(sopt::SteadyOptimizer, pressure) = get_potential(sopt.net, pressure)

is_pressure_node(sopt::SteadyOptimizer, node_id, is_ideal) = is_pressure_node(sopt.net, node_id, is_ideal)

