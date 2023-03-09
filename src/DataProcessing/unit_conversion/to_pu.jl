function _si_to_pu!(data::Dict{String,Any},
    params::Dict{Symbol,Any}, nominal_values::Dict{Symbol,Any})

    rescale_mass_flow = x -> x/nominal_values[:mass_flow]
    rescale_mass_flux = x -> x/nominal_values[:mass_flux]
    rescale_pressure = x -> x/nominal_values[:pressure]
    rescale_length = x -> x/nominal_values[:length]
    rescale_density = x -> x/nominal_values[:density]
    rescale_diameter = x -> x/nominal_values[:length]
    rescale_area = x -> x/nominal_values[:area]
    rescale_cost = x -> x/nominal_values[:gas_cost]

    rescale_functions = [rescale_mass_flow, rescale_mass_flux, rescale_pressure, rescale_length, rescale_density, 
        rescale_diameter, rescale_area, rescale_cost]
    
    _rescale_data!(data, params, rescale_functions)
end 