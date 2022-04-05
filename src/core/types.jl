export MODEL_TYPE, OBJECTIVE_TYPE

@enum MODEL_TYPE begin 
    unknown_model = 0
    nlp = 1
    lp_relaxation = 2 
end

@enum OBJECTIVE_TYPE begin 
    unknown_obj = 0
    profit = 1
end 

struct OptModel 
    model::JuMP.AbstractModel
    variables::Dict{Symbol,Any}
    constraints::Dict{Symbol,Any}
    model_type::MODEL_TYPE 
    objective_type::OBJECTIVE_TYPE
end 

function OptModel(model_type::MODEL_TYPE, objective_type::OBJECTIVE_TYPE)
    return OptModel(JuMP.Model(), 
        Dict{Symbol,Any}(), Dict{Symbol,Any}(), 
        model_type, objective_type)
end

OptModel() = OptModel(JuMP.Model(), 
    Dict{Symbol,Any}(), Dict{Symbol,Any}(), 
    MODEL_TYPE::unknown_model, OBJECTIVE_TYPE::unknown_obj)


struct SteadyOptimizer
    data::Dict{String,Any}
    ref::Dict{Symbol,Any}
    sol::Dict{String,Any}
    nominal_values::Dict{Symbol,Any}
    params::Dict{Symbol,Any}
    nlp::OptModel 
    relaxation::OptModel
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
