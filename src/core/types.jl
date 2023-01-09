struct OptModel 
    model::JuMP.AbstractModel
    variables::Dict{Symbol,Any}
end 

OptModel() = OptModel(JuMP.Model(), Dict{Symbol,Any}())

struct SteadyOptimizer
    data::Dict{String,Any}
    ref::Dict{Symbol,Any}
    sol::Dict{String,Any}
    nominal_values::Dict{Symbol,Any}
    params::Dict{Symbol,Any}
    linear_relaxation::OptModel
    relaxation_options::Dict{Symbol,Any}
    pu_eos_coeffs::Function
    pu_pressure_to_pu_density::Function
    pu_density_to_pu_pressure::Function
end

ref(sopt::SteadyOptimizer) = sopt.ref
ref(sopt::SteadyOptimizer, key::Symbol) = sopt.ref[key]
ref(sopt::SteadyOptimizer, key::Symbol, id::Int64) = sopt.ref[key][id]
ref(sopt::SteadyOptimizer, key::Symbol, id::Int64, field) = sopt.ref[key][id][field]

params(sopt::SteadyOptimizer) = sopt.params
params(sopt::SteadyOptimizer, key::Symbol) = sopt.params[key]

nominal_values(sopt::SteadyOptimizer) = sopt.nominal_values
nominal_values(sopt::SteadyOptimizer, key::Symbol) = sopt.nominal_values[key]

get_eos_coeffs(sopt::SteadyOptimizer) = 
    sopt.pu_eos_coeffs(nominal_values(sopt), params(sopt))
get_pressure(sopt::SteadyOptimizer, density) = 
    sopt.pu_density_to_pu_pressure(density, nominal_values(sopt), params(sopt))
get_density(sopt::SteadyOptimizer, pressure) = 
    sopt.pu_pressure_to_pu_density(pressure, nominal_values(sopt), params(sopt))
