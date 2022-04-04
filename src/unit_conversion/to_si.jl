function _pu_to_si!(data::Dict{String,Any},
    params::Dict{Symbol,Any}, nominal_values::Dict{Symbol,Any})

    rescale_mass_flow = x -> x * nominal_values[:mass_flow]
    rescale_mass_flux = x -> x * nominal_values[:mass_flux]
    rescale_pressure = x -> x * nominal_values[:pressure]
    rescale_length = x -> x * nominal_values[:length]
    rescale_density = x -> x * nominal_values[:density]
    rescale_diameter = x -> x * nominal_values[:length]
    rescale_area = x -> x * nominal_values[:area]
    rescale_cost = x -> x * nominal_values[:gas_cost]

    rescale_functions = [rescale_mass_flow, rescale_mass_flux, 
        rescale_pressure, rescale_length, rescale_density, 
        rescale_diameter, rescale_area, rescale_cost]
    
    _rescale_data!(data, params, rescale_functions)
end 

function _english_to_si!(data::Dict{String,Any},
    params::Dict{Symbol,Any}, nominal_values::Dict{Symbol,Any})

    rescale_mass_flow = x -> x * get_mmscfd_to_kgps_conversion_factor(params)
    rescale_mass_flux = x -> x * get_mmscfd_to_kgps_conversion_factor(params)
    rescale_pressure = x -> psi_to_pascal(x)
    rescale_length = x -> miles_to_m(x)
    rescale_density = x -> x
    rescale_diameter = x -> inches_to_m(x)
    rescale_area = x -> sq_inches_to_sq_m(x)
    rescale_cost = x -> x / get_mmscfd_to_kgps_conversion_factor(params)

    rescale_functions = [rescale_mass_flow, rescale_mass_flux, 
        rescale_pressure, rescale_length, rescale_density, 
        rescale_diameter, rescale_area, rescale_cost]
    
    _rescale_data!(data, params, rescale_functions)
end 