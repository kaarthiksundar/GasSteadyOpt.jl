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

function get_potential(net::NetworkData, pressure)
    b1, b2 = get_eos_coeffs(net)
    return (b1/2) * pressure^2 + (b2/3) * pressure^3
end 

function is_pressure_node(net::NetworkData, node_id, is_ideal)
    ids = union(
            Set(ref(net, :control_valve_nodes)), 
            Set(ref(net, :loss_resistor_nodes)),
            Set(ref(net, :valve_nodes))
        ) 
    if (is_ideal)
        return node_id in ids
    else 
        return node_id in union(ids, Set(ref(net, :compressor_nodes)))
    end 
end 
    
