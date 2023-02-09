function compare_resistor_models(data::Dict; num_samples = 10)
    params, nominal_values = process_data!(data)

    TOL = 1e-6
    function get_rho(p, eos)
        (eos == :ideal) && (return p / nominal_values[:sound_speed]^2)
        a_sqr = nominal_values[:sound_speed]^2
        if eos == :simple_cnga 
            b1 = 1.00300865  
            b2 = 2.96848838e-8
            return (b1 * p + b2 * p^2)/a_sqr 
        end
        p_atm = 101350.0
        G, T = params[:gas_specific_gravity], params[:temperature]
        a1, a2, a3 = 344400.0, 1.785, 3.825 
        b1 = 1.0 + a1 * (p_atm/6894.75729) * ( 10 ^ (a2 * G) ) / (1.8 * T) ^ a3 
        b2 = a1 * (10.0 ^ (a2 * G) ) / (6894.75729 * (1.8 * T)^a3 ) 
        return (b1 * p + b2 * p^2)/a_sqr 
    end 

    function get_pi(p, eos)
        (eos == :ideal) && (return p^2 / 2.0)
        if eos == :simple_cnga 
            b1 = 1.00300865  
            b2 = 2.96848838e-8
            return (b1 * p^2/2.0 + b2 * p^3/3.0)
        end
        p_atm = 101350.0
        G, T = params[:gas_specific_gravity], params[:temperature]
        a1, a2, a3 = 344400.0, 1.785, 3.825 
        b1 = 1.0 + a1 * (p_atm/6894.75729) * ( 10 ^ (a2 * G) ) / (1.8 * T) ^ a3 
        b2 = a1 * (10.0 ^ (a2 * G) ) / (6894.75729 * (1.8 * T)^a3 ) 
        return (b1 * p^2/2.0 + b2 * p^3/3.0)
    end 

    function find_ub(val::Float64, ub::Float64, eos::Symbol)::Float64
        @assert ub > 0
        while get_pi(ub, eos) < val
            ub = 1.5 * ub
        end 
        return ub
    end 
    
    function find_lb(val::Float64, lb::Float64, eos::Symbol)::Float64
        @assert lb < 0
        while get_pi(lb, eos) > val
            lb = 1.5 * lb
        end 
        return lb
    end 
    
    function bisect(lb::Float64, ub::Float64, val::Float64, eos::Symbol)::Float64  
        @assert ub > lb
        mb = 1.0
        while (ub - lb) > TOL
            mb = (ub + lb) / 2.0
            if get_pi(mb, eos) > val
                ub = mb
            else
                lb = mb 
            end
        end
        return mb
    end
    
    invert_positive_potential(val::Float64, ub::Float64, eos::Symbol) = bisect(0.0, ub, val, eos)

    resistors = data["resistors"]
    ideal_error = [] 
    simple_cnga_error = [] 
    full_cnga_error = [] 
    a_sqr = nominal_values[:sound_speed]^2
    
    for (_, resistor) in resistors 
        drag = resistor["drag"]
        diameter = resistor["diameter"]
        area = pi * 0.25 * diameter^2
        max_flow = 100.0
        fr_node = resistor["fr_node"]
        p_fr = (data["nodes"][string(fr_node)]["min_pressure"], data["nodes"][string(fr_node)]["max_pressure"])
        for _ in 1:num_samples
            lambda = rand() 
            f = max_flow * (1 - lambda)
            p_in =  first(p_fr) * lambda + last(p_fr) * (1 - lambda)
            
            # compute based on true resistor model: p_in - p_out = 0.5 * drag * f^2 / A^2 / rho_in
            p_out_true_ideal = p_in - 0.5 * drag * f * f / (area^2 * get_rho(p_in, :ideal))
            p_out_true_simple_cnga = p_in - 0.5 * drag * f * f / (area^2 * get_rho(p_in, :simple_cnga))
            p_out_true_full_cnga = p_in - 0.5 * drag * f * f / (area^2 * get_rho(p_in, :full_cnga))
            
            # compute based on potential type model 
            pi_out_ideal = get_pi(p_in, :ideal) - 0.5 * drag * f * f * a_sqr / area^2
            pi_out_simple_cnga = get_pi(p_in, :simple_cnga) - 0.5 * drag * f * f * a_sqr / area^2 
            pi_out_full_cnga = get_pi(p_in, :full_cnga) - 0.5 * drag * f * f * a_sqr / area^2 
            
            # compute pressure using potential
            p_out_ideal = invert_positive_potential(pi_out_ideal, last(p_fr), :ideal)
            p_out_simple_cnga = invert_positive_potential(pi_out_simple_cnga, last(p_fr), :simple_cnga)
            p_out_full_cnga = invert_positive_potential(pi_out_full_cnga, last(p_fr), :full_cnga)
            
            # compute errors 
            push!(ideal_error, abs(p_out_ideal - p_out_true_ideal) / p_out_true_ideal)
            push!(simple_cnga_error, abs(p_out_simple_cnga - p_out_true_simple_cnga) / p_out_true_simple_cnga)
            push!(full_cnga_error, abs(p_out_full_cnga - p_out_true_full_cnga) / p_out_true_full_cnga)
        end 
    end 

    relative_errors = [] 
    for i in eachindex(ideal_error) 
        row = Vector{Float64}()
        append!(row, [ideal_error[i], simple_cnga_error[i], full_cnga_error[i]])
        push!(relative_errors, row)
    end 

    return relative_errors    
end 

