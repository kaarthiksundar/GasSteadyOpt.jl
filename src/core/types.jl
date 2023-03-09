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
    nonlinear_full_model::OptModel
    relaxation_options::Dict{Symbol,Any}
    pu_eos_coeffs::Function
    pu_pressure_to_pu_density::Function
    pu_density_to_pu_pressure::Function
end

ref(sopt::SteadyOptimizer) = sopt.ref
ref(sopt::SteadyOptimizer, key::Symbol) = get(sopt.ref, key, Dict())
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

function get_potential(sopt::SteadyOptimizer, pressure)
    b1, b2 = get_eos_coeffs(sopt)
    return (b1/2) * pressure^2 + (b2/3) * pressure^3
end 

function is_pressure_node(sopt::SteadyOptimizer, node_id, is_ideal)
    ids = union(
            Set(ref(sopt, :control_valve_nodes)), 
            Set(ref(sopt, :loss_resistor_nodes)),
            Set(ref(sopt, :valve_nodes))
        ) 
    if (is_ideal)
        return node_id in ids
    else 
        return node_id in union(ids, Set(ref(sopt, :compressor_nodes)))
    end 
end 
    
