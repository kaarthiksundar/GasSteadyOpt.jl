module Optimization

    using JuMP 
    
    # submodule import
    include("../DataProcessing/DataProcessing.jl")
    using .DataProcessing: NetworkData, ref, params, nominal_values, get_eos_coeffs, get_pressure, get_density, get_potential, is_pressure_node
    
    include("types.jl")
end 