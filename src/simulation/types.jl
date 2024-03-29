struct SteadySimulator 
    net::NetworkData 
    sim_ref::Dict{Symbol,Any}
    solution::Solution 
end 

ref(ss::SteadySimulator) = ss.sim_ref
ref(ss::SteadySimulator, key::Symbol) = ss.sim_ref[key] 
ref(ss::SteadySimulator, key::Symbol, id::Int64) = ss.sim_ref[key][id]
ref(ss::SteadySimulator, key::Symbol, id::Int64, field) = ss.sim_ref[key][id][field]
params(ss::SteadySimulator) = params(ss.net)
params(ss::SteadySimulator, key::Symbol) = params(ss.net, key)

nominal_values(ss::SteadySimulator) = nominal_values(ss.net)
nominal_values(ss::SteadySimulator, key::Symbol) = nominal_values(ss.net, key)

get_eos_coeffs(ss::SteadySimulator) = get_eos_coeffs(ss.net)
get_pressure(ss::SteadySimulator, density) = get_pressure(ss.net, density)
get_density(ss::SteadySimulator, pressure) = get_density(ss.net, pressure)

get_potential(ss::SteadySimulator, pressure) = get_potential(ss.net, pressure)
get_potential_derivative(ss::SteadySimulator, pressure) = get_potential_derivative(ss.net, pressure)

is_pressure_node(ss::SteadySimulator, node_id) = is_pressure_node(ss.net, node_id)
is_ideal(ss::SteadySimulator) = is_ideal(ss.net)

initial_pipe_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:pipe][id]["flow"] 
initial_resistor_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:resistor][id]["flow"] 
initial_loss_resistor_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:loss_resistor][id]["flow"] 
initial_short_pipe_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:short_pipe][id]["flow"] 
initial_compressor_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:compressor][id]["flow"]
initial_control_valve_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:control_valve][id]["flow"]
initial_valve_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:valve][id]["flow"]
initial_nodal_pressure(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:node][id]["pressure"]

function control(ss::SteadySimulator,
    key::Symbol, id::Int64)::Tuple{ControlType,Float64}
    (key == :node) && (return get_nodal_control(ss, id))
    (key == :compressor) && (return get_compressor_control(ss, id))
    (key == :control_valve) && (return get_control_valve_control(ss, id))
    @error "control available only for nodes, compressors, and control_valves"
    return ControlType(100), NaN
end

is_compressor_off(ss::SteadySimulator, id::Int64)::Bool = ss.solution.control[:compressor][id]["status"] == 0
is_control_valve_off(ss::SteadySimulator, id::Int64)::Bool = ss.solution.control[:control_valve][id]["status"] == 0
is_valve_off(ss::SteadySimulator, id::Int64)::Bool = ss.solution.control[:valve][id]["status"] == 0

function get_nodal_control(ss::SteadySimulator,
    id::Int64)::Tuple{ControlType,Float64}
    injection = ss.solution.control[:node][id]["injection"]
    pressure = ss.solution.control[:node][id]["pressure"]
    (isnan(injection) && isnan(pressure)) && (return ControlType(2), 0.0)
    (isnan(injection)) && (return ControlType(3), pressure)
    return ControlType(2), injection 
end

function get_compressor_control(ss::SteadySimulator,
    id::Int64)::Tuple{ControlType,Float64}
    ratio = ss.solution.control[:compressor][id]["ratio"]
    return ControlType(0), ratio
end

function get_control_valve_control(ss::SteadySimulator,
    id::Int64)::Tuple{ControlType,Float64}
    differential = ss.solution.control[:control_valve][id]["differential"]
    return ControlType(1), differential
end

@enum SolverStatus begin 
    unique_physical_solution = 0 
    nl_solve_failure = 1 
    unique_unphysical_solution = 2 
    unphysical_solution = 3
end

struct SolverReturn 
    status::SolverStatus
    iterations::Int 
    residual_norm::Float64 
    time::Float64 
    solution::Vector{Float64}
    negative_flow_in_compressors::Vector{Int64}
    negative_potentials_in_nodes::Vector{Int64}
    pressure_domain_not_satisfied_in_nodes::Vector{Int64}
end 