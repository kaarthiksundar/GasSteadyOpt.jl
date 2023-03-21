struct ControlData 
    data::Dict{String,Any}
    nominal_values::Dict{Symbol,Any}
    params::Dict{Symbol,Any}
end 

struct StateGuessData 
    data::Dict{String,Any}
    nominal_values::Dict{Symbol,Any}
    params::Dict{Symbol,Any}
end 

struct NetworkData 
    data::Dict{String,Any}
    ref::Dict{Symbol,Any}
    nominal_values::Dict{Symbol,Any}
    params::Dict{Symbol,Any}
    pu_eos_coeffs::Function
    pu_pressure_to_pu_density::Function 
    pu_density_to_pu_pressure::Function
end 

ref(net::NetworkData) = net.ref
ref(net::NetworkData, key::Symbol) = get(net.ref, key, Dict())
ref(net::NetworkData, key::Symbol, id::Int64) = net.ref[key][id]
ref(net::NetworkData, key::Symbol, id::Int64, field) = net.ref[key][id][field]

params(net::Union{NetworkData,ControlData,StateGuessData}) = net.params
params(net::Union{NetworkData,ControlData,StateGuessData}, key::Symbol) = net.params[key]

nominal_values(net::Union{NetworkData,ControlData,StateGuessData}) = net.nominal_values
nominal_values(net::Union{NetworkData,ControlData,StateGuessData}, key::Symbol) = net.nominal_values[key]

get_eos_coeffs(net::NetworkData) = 
    net.pu_eos_coeffs(nominal_values(net), params(net))
get_pressure(net::NetworkData, density) = 
    net.pu_density_to_pu_pressure(density, nominal_values(net), params(net))
get_density(net::NetworkData, pressure) = 
    net.pu_pressure_to_pu_density(pressure, nominal_values(net), params(net))

is_ideal(net::NetworkData) = last(get_eos_coeffs(net)) ≈ 0.0

function get_potential(net::NetworkData, pressure)
    b1, b2 = get_eos_coeffs(net)
    return (b1/2) * pressure^2 + (b2/3) * pressure^3
end 

function get_potential_derivative(net::NetworkData, pressure) 
    b1, b2 = get_eos_coeffs(net)
    return b1 * pressure + b2 * pressure^2
end 

is_pressure_node(net::NetworkData, node_id) = ref(net, :is_pressure_node, node_id)

function find_ub(net::NetworkData, val::Float64, ub::Float64)::Float64
    @assert ub > 0
    while get_potential(net, ub) < val
        ub = 1.5 * ub
    end 
    return ub
end 

function find_lb(net::NetworkData, val::Float64, lb::Float64)::Float64
    @assert lb < 0
    while get_potential(net, lb) > val
        lb = 1.5 * lb
    end 
    return lb
end 

function bisect(net::NetworkData, lb::Float64, ub::Float64, val::Float64)::Float64  
    @assert ub > lb
    mb = 1.0
    while (ub - lb) > TOL
        mb = (ub + lb) / 2.0
        if get_potential(net, mb) > val
            ub = mb
        else
            lb = mb 
        end
    end
    return mb
end

invert_positive_potential(net::NetworkData, val::Float64) = bisect(net, 0.0, find_ub(net, val, 1.0), val)