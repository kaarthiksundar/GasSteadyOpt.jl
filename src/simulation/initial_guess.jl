function _create_initial_guess_dof!(ss::SteadySimulator)::Array
    ndofs = length(ref(ss, :dof))
    x_guess = 0.5 * ones(Float64, ndofs) 
    dofs_updated = 0
    state_guess = ss.solution.state_guess

    _, b2 = get_eos_coeffs(ss)
    is_ideal = isapprox(b2, 0.0)

    for (i, guess) in state_guess[:node]
        dof = ref(ss, :node, i, "dof")
        if is_pressure_node(ss, i, is_ideal) 
            (isnan(guess["pressure"])) && (continue)
            x_guess[dof] = guess["pressure"]
            dofs_updated += 1 
        else 
            (isnan(guess["potential"])) && (continue)
            x_guess[dof] = guess["potential"]
            dofs_updated += 1
        end 
    end 

    components = [:pipe, :resistor, :loss_resistor, :short_pipe, :compressor, :control_valve, :valve]

    for component in components
        for (i, val) in get(ref(ss), component, Dict())
            (isnan(state_guess[component][i]["flow"])) && (continue)
            dof = val["dof"]
            x_guess[dof] = state_guess[component][i]["flow"]
            dofs_updated += 1
        end 
    end 

    return x_guess
end