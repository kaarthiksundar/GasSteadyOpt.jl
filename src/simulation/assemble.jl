"""function assembles the residuals"""
function assemble_residual!(ss::SteadySimulator, x_dof::AbstractArray, residual_dof::AbstractArray)
    _eval_junction_equations!(ss, x_dof, residual_dof)
    _eval_pipe_equations!(ss, x_dof, residual_dof)
    _eval_resistor_equations!(ss, x_dof, residual_dof)
    _eval_loss_resistor_equations!(ss, x_dof, residual_dof)
    _eval_compressor_equations!(ss, x_dof, residual_dof)
    _eval_control_valve_equations!(ss, x_dof, residual_dof)
    _eval_short_pipe_equations!(ss, x_dof, residual_dof)
    _eval_valve_equations!(ss, x_dof, residual_dof)
end

"""function assembles the Jacobians"""
function assemble_mat!(ss::SteadySimulator, x_dof::AbstractArray, J::AbstractArray)
    fill!(J, 0)
    _eval_junction_equations_mat!(ss, x_dof, J)
    _eval_pipe_equations_mat!(ss, x_dof, J)
    _eval_resistor_equations_mat!(ss, x_dof, J)
    _eval_loss_resistor_equations_mat!(ss, x_dof, J)
    _eval_compressor_equations_mat!(ss, x_dof, J)
    _eval_control_valve_equations_mat!(ss, x_dof, J)
    _eval_short_pipe_equations_mat!(ss, x_dof, J)
    _eval_valve_equations_mat!(ss, x_dof, J)
end

"""residual computation for junctions"""
function _eval_junction_equations!(ss::SteadySimulator, x_dof::AbstractArray, residual_dof::AbstractArray)
    @inbounds for (id, junction) in ref(ss, :node)
        eqn_no = junction["dof"]
        ctrl_type, val = control(ss, :node, id) # val is injection or pressure

        if ctrl_type == pressure_control
            coeff = (is_pressure_node(ss, id, is_ideal(ss))) ? val : get_potential(ss, val)
            residual_dof[eqn_no] = x_dof[eqn_no] - coeff
        end

        if  ctrl_type == flow_control
            r = val # inflow is positive convention
            out_edge = ref(ss, :outgoing_dofs, id)
            in_edge = ref(ss, :incoming_dofs, id)
            r -= sum(x_dof[e] for e in out_edge; init=0.0) 
            r += sum(x_dof[e] for e in in_edge; init=0.0)
            residual_dof[eqn_no] = r
        end
    end
end

"""residual computation for pipes"""
function _eval_pipe_equations!(ss::SteadySimulator, x_dof::AbstractArray, residual_dof::AbstractArray)
    @inbounds for (_, pipe) in ref(ss, :pipe)
        eqn_no = pipe["dof"]
        f = x_dof[eqn_no]
        fr_node = pipe["fr_node"]  
        to_node = pipe["to_node"]
        fr_dof = ref(ss, :node, fr_node, "dof")
        to_dof = ref(ss, :node, to_node, "dof")
        is_fr_pressure_node = is_pressure_node(ss, fr_node, is_ideal(ss))
        is_to_pressure_node = is_pressure_node(ss, to_node, is_ideal(ss))
        pi_fr = (is_fr_pressure_node) ? get_potential(ss, x_dof[fr_dof]) : x_dof[fr_dof] 
        pi_to = (is_to_pressure_node) ? get_potential(ss, x_dof[to_dof]) : x_dof[to_dof] 
        c = nominal_values(ss, :mach_num)^2 / nominal_values(ss, :euler_num) 

        resistance = pipe["friction_factor"] * pipe["length"] * c / (2 * pipe["diameter"] * pipe["area"]^2)
        residual_dof[eqn_no] = pi_fr - pi_to - f * abs(f) * resistance
    end
end

"""residual computation for resistors"""
function _eval_resistor_equations!(ss::SteadySimulator, x_dof::AbstractArray, residual_dof::AbstractArray)
    (!haskey(ref(ss), :resistor)) && (return)
    @inbounds for (_, resistor) in ref(ss, :resistor)
        eqn_no = resistor["dof"]
        f = x_dof[eqn_no]
        fr_node = resistor["fr_node"]  
        to_node = resistor["to_node"]
        fr_dof = ref(ss, :node, fr_node, "dof")
        to_dof = ref(ss, :node, to_node, "dof")
        is_fr_pressure_node = is_pressure_node(ss, fr_node, is_ideal(ss))
        is_to_pressure_node = is_pressure_node(ss, to_node, is_ideal(ss))
        pi_fr = (is_fr_pressure_node) ? get_potential(ss, x_dof[fr_dof]) : x_dof[fr_dof] 
        pi_to = (is_to_pressure_node) ? get_potential(ss, x_dof[to_dof]) : x_dof[to_dof] 
        c = nominal_values(ss, :mach_num)^2 / nominal_values(ss, :euler_num) 

        resistance = resistor["drag"] * c / (2 * resistor["area"]^2)
        residual_dof[eqn_no] = pi_fr - pi_to - f * abs(f) * resistance
    end
end

"""residual computation for loss resistors"""
function _eval_loss_resistor_equations!(ss::SteadySimulator, x_dof::AbstractArray, residual_dof::AbstractArray)
    (!haskey(ref(ss), :loss_resistor)) && (return)
    @inbounds for (_, loss_resistor) in ref(ss, :resistor)
        eqn_no = loss_resistor["dof"]
        f = x_dof[eqn_no]
        fr_node = loss_resistor["fr_node"]  
        to_node = loss_resistor["to_node"]
        fr_dof = ref(ss, :node, fr_node, "dof")
        to_dof = ref(ss, :node, to_node, "dof")
        residual_dof[eqn_no] = x_dof[fr_dof] - x_dof[to_dof] - sign(f) * loss_resistor["pressure_loss"]
    end
end

"""residual computation for compressor"""
function _eval_compressor_equations!(ss::SteadySimulator, x_dof::AbstractArray, residual_dof::AbstractArray)
    (!haskey(ref(ss), :compressor)) && (return)
    @inbounds for (id, comp) in ref(ss, :compressor)
        eqn_no = comp["dof"] 
        _, cmpr_val = control(ss, :compressor, id)
        to_node = comp["to_node"]
        fr_node = comp["fr_node"]
        is_pressure_eq = is_pressure_node(ss, fr_node, is_ideal(ss)) || is_pressure_node(ss, to_node, is_ideal(ss))
        val = (is_pressure_eq) ? cmpr_val : cmpr_val^2
        residual_dof[eqn_no] = val * x_dof[ref(ss, :node, fr_node, "dof")] -  x_dof[ref(ss, :node, to_node, "dof")]
    end
end

"""residual computation for control_valves"""
function _eval_control_valve_equations!(ss::SteadySimulator, x_dof::AbstractArray, residual_dof::AbstractArray)
    (!haskey(ref(ss), :control_valve)) && (return)
    @inbounds for (cv_id, cv) in ref(ss, :control_valve)
        eqn_no = cv["dof"] 
        _, cv_val = control(ss, :control_valve, cv_id)
        to_node = cv["to_node"]
        fr_node = cv["fr_node"]
        residual_dof[eqn_no] = x_dof[ref(ss, :node, fr_node, "dof")]  - x_dof[ref(ss, :node, to_node, "dof")] - cv_val 
    end
end

"""residual computation for short pipes"""
function _eval_short_pipe_equations!(ss::SteadySimulator, x_dof::AbstractArray, residual_dof::AbstractArray)
    @inbounds for (_, pipe) in get(ref(ss), :short_pipe, [])
        eqn_no = pipe["dof"]
        f = x_dof[eqn_no]
        fr_node = pipe["fr_node"]  
        to_node = pipe["to_node"]
        fr_dof = ref(ss, :node, fr_node, "dof")
        to_dof = ref(ss, :node, to_node, "dof")
        is_fr_pressure_node = is_pressure_node(ss, fr_node, is_ideal(ss))
        is_to_pressure_node = is_pressure_node(ss, to_node, is_ideal(ss))
        pi_fr = (is_fr_pressure_node) ? get_potential(ss, x_dof[fr_dof]) : x_dof[fr_dof] 
        pi_to = (is_to_pressure_node) ? get_potential(ss, x_dof[to_dof]) : x_dof[to_dof]  

        resistance = 1e-7
        residual_dof[eqn_no] = pi_fr - pi_to - f * abs(f) * resistance
    end
end

"""residual computation for valve"""
function _eval_valve_equations!(ss::SteadySimulator, x_dof::AbstractArray, residual_dof::AbstractArray)
    (!haskey(ref(ss), :valve)) && (return)
    @inbounds for (_, valve) in ref(ss, :valve)
        eqn_no = valve["dof"]
        fr_node = valve["fr_node"]
        to_node = valve["to_node"]
        fr_dof = ref(ss, :node, fr_node, "dof")
        to_dof = ref(ss, :node, to_node, "dof")
        is_fr_pressure_node = is_pressure_node(ss, fr_node, is_ideal(ss))
        is_to_pressure_node = is_pressure_node(ss, to_node, is_ideal(ss))
        if (is_fr_pressure_node && is_to_pressure_node)
            residual_dof[eqn_no] = x_dof[fr_dof] - x_dof[to_dof]
        else
            pi_fr = (is_fr_pressure_node) ? get_potential(ss, x_dof[fr_dof]) : x_dof[fr_dof] 
            pi_to = (is_to_pressure_node) ? get_potential(ss, x_dof[to_dof]) : x_dof[to_dof] 
            residual_dof[eqn_no] = pi_fr - pi_to
        end 
    end 
end 

"""in place Jacobian computation for junctions"""
function _eval_junction_equations_mat!(ss::SteadySimulator, x_dof::AbstractArray, 
        J::AbstractArray)
    @inbounds for (id, junction) in ref(ss, :node)
        eqn_no = junction["dof"]
        ctrl_type, _ = control(ss, :node, id) # val is injection or pressure
        
        if ctrl_type == pressure_control
            J[eqn_no, eqn_no] = 1
            continue
        end

        if  ctrl_type == flow_control
            out_edge = ref(ss, :outgoing_dofs, id)
            in_edge = ref(ss, :incoming_dofs, id)
            for e in out_edge
                J[eqn_no, e] = -1
            end
            for e in in_edge
                J[eqn_no, e] = +1
            end
        end
    end
end

"""in place Jacobian computation for pipes"""
function _eval_pipe_equations_mat!(ss::SteadySimulator, x_dof::AbstractArray, 
        J::AbstractArray)
    @inbounds for (_, pipe) in ref(ss, :pipe)
        eqn_no = pipe["dof"] 
        f = x_dof[eqn_no]
        fr_node = pipe["fr_node"]  
        to_node = pipe["to_node"]

        eqn_fr = ref(ss, :node, fr_node, "dof")
        eqn_to = ref(ss, :node, to_node, "dof")
        is_fr_pressure_node = is_pressure_node(ss, fr_node, is_ideal(ss))
        is_to_pressure_node = is_pressure_node(ss, to_node, is_ideal(ss))
        
        c = nominal_values(ss, :mach_num)^2 / nominal_values(ss, :euler_num) 
        resistance = pipe["friction_factor"] * pipe["length"] * c / (2 * pipe["diameter"] * pipe["area"]^2)

        pi_dash_fr = (is_fr_pressure_node) ? get_potential_derivative(ss, x_dof[eqn_fr]) : 1.0 
        pi_dash_to = (is_to_pressure_node) ? get_potential_derivative(ss, x_dof[eqn_to]) : 1.0 

        J[eqn_no, eqn_fr] = pi_dash_fr
        J[eqn_no, eqn_to] = -pi_dash_to
        J[eqn_no, eqn_no] = -2.0 * f * sign(f) * resistance
    end
end

"""in place Jacobian computation for resistors"""
function _eval_resistor_equations_mat!(ss::SteadySimulator, x_dof::AbstractArray, 
        J::AbstractArray)
    (!haskey(ref(ss), :resistor)) && (return)
    @inbounds for (_, resistor) in ref(ss, :resistor)
        eqn_no = resistor["dof"] 
        f = x_dof[eqn_no]
        fr_node = resistor["fr_node"]  
        to_node = resistor["to_node"]

        eqn_fr = ref(ss, :node, fr_node, "dof")
        eqn_to = ref(ss, :node, to_node, "dof")
        is_fr_pressure_node = is_pressure_node(ss, fr_node, is_ideal(ss))
        is_to_pressure_node = is_pressure_node(ss, to_node, is_ideal(ss))
        
        c = nominal_values(ss, :mach_num)^2 / nominal_values(ss, :euler_num) 
        resistance = resistor["drag"] * c / (2 * resistor["area"]^2)

        pi_dash_fr = (is_fr_pressure_node) ? get_potential_derivative(ss, x_dof[eqn_fr]) : 1.0 
        pi_dash_to = (is_to_pressure_node) ? get_potential_derivative(ss, x_dof[eqn_to]) : 1.0 

        J[eqn_no, eqn_fr] = pi_dash_fr
        J[eqn_no, eqn_to] = -pi_dash_to
        J[eqn_no, eqn_no] = -2.0 * f * sign(f) * resistance
    end
end

"""in place Jacobian computation for loss resistors"""
function _eval_loss_resistor_equations_mat!(ss::SteadySimulator, x_dof::AbstractArray, 
        J::AbstractArray)
    (!haskey(ref(ss), :loss_resistor)) && (return)
    @inbounds for (_, loss_resistor) in ref(ss, :loss_resistor)
        eqn_no = loss_resistor["dof"] 
        f = x_dof[eqn_no]
        fr_node = loss_resistor["fr_node"]  
        to_node = loss_resistor["to_node"]

        eqn_fr = ref(ss, :node, fr_node, "dof")
        eqn_to = ref(ss, :node, to_node, "dof")

        J[eqn_no, eqn_fr] = 1
        J[eqn_no, eqn_to] = -1
        J[eqn_no, eqn_no] = 0.0
    end
end

"""in place Jacobian computation for compressors"""
function _eval_compressor_equations_mat!(ss::SteadySimulator, x_dof::AbstractArray, 
        J::AbstractArray)
    (!haskey(ref(ss), :compressor)) && (return)
    @inbounds for (id, comp) in ref(ss, :compressor)
        eqn_no = comp["dof"] 
        _, cmpr_val = control(ss, :compressor, id)
        to_node = comp["to_node"]
        fr_node = comp["fr_node"]
        eqn_to = ref(ss, :node, to_node, "dof")
        eqn_fr = ref(ss, :node, fr_node, "dof")
        is_pressure_eq = is_pressure_node(ss, fr_node, is_ideal(ss)) || is_pressure_node(ss, to_node, is_ideal(ss))

        J[eqn_no, eqn_to] = -1
        J[eqn_no, eqn_fr] = (is_pressure_eq) ? (cmpr_val) : (cmpr_val^2)
    end
end

"""in place Jacobian computation for control_valves"""
function _eval_control_valve_equations_mat!(ss::SteadySimulator, x_dof::AbstractArray, 
        J::AbstractArray)
    (!haskey(ref(ss), :control_valve)) && (return)
    @inbounds for (_, cv) in ref(ss, :control_valve)
        eqn_no = cv["dof"] 
        to_node = cv["to_node"]
        fr_node = cv["fr_node"]
        eqn_to = ref(ss, :node, to_node, "dof")
        eqn_fr = ref(ss, :node, fr_node, "dof")
        
        J[eqn_no, eqn_to] = -1
        J[eqn_no, eqn_fr] = 1
    end
end

"""in place Jacobian computation for short pipes"""
function _eval_short_pipe_equations_mat!(ss::SteadySimulator, x_dof::AbstractArray, 
        J::AbstractArray)
    @inbounds for (_, pipe) in get(ref(ss), :short_pipe, [])
        eqn_no = pipe["dof"] 
        f = x_dof[eqn_no]
        fr_node = pipe["fr_node"]  
        to_node = pipe["to_node"]

        eqn_fr = ref(ss, :node, fr_node, "dof")
        eqn_to = ref(ss, :node, to_node, "dof")
        is_fr_pressure_node = is_pressure_node(ss, fr_node, is_ideal(ss))
        is_to_pressure_node = is_pressire_node(ss, to_node, is_ideal(ss))
        
        resistance = 1e-7

        pi_dash_fr = (is_fr_pressure_node) ? get_potential_derivative(ss, x_dof[eqn_fr]) : 1.0 
        pi_dash_to = (is_to_pressure_node) ? get_potential_derivative(ss, x_dof[eqn_to]) : 1.0 

        J[eqn_no, eqn_fr] = pi_dash_fr
        J[eqn_no, eqn_to] = -pi_dash_to
        J[eqn_no, eqn_no] = -2.0 * f * sign(f) * resistance
    end
end

"""in place Jacobian computation for valves"""
function _eval_valve_equations_mat!(ss::SteadySimulator, x_dof::AbstractArray, 
        J::AbstractArray)
    (!haskey(ref(ss), :valve)) && (return)
    @inbounds for (_, valve) in ref(ss, :valve)
        eqn_no = valve["dof"]
        to_node = valve["to_node"]
        fr_node = valve["fr_node"]
        eqn_to = ref(ss, :node, to_node, "dof")
        eqn_fr = ref(ss, :node, fr_node, "dof")
        is_fr_pressure_node = is_pressure_node(ss, fr_node, is_ideal(ss))
        is_to_pressure_node = is_pressure_node(ss, to_node, is_ideal(ss))

        if (is_fr_pressure_node && is_to_pressure_node)
            J[eqn_no, eqn_to] = -1.0
            J[eqn_no, eqn_fr] = 1.0
        else
            pi_dash_fr = (is_fr_pressure_node) ? get_potential_derivative(ss, x_dof[eqn_fr]) : 1.0 
            pi_dash_to = (is_to_pressure_node) ? get_potential_derivative(ss, x_dof[eqn_to]) : 1.0
            J[eqn_no, eqn_to] = -pi_dash_to
            J[eqn_no, eqn_fr] = pi_dash_fr
        end  
    end 
end 